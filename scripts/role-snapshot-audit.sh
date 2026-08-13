#!/usr/bin/env bash
# role-snapshot-audit.sh — find role knowledge snapshots whose owners' code
# moved without a snapshot update.
#
# Usage:
#   bash scripts/role-snapshot-audit.sh            # human-readable
#   bash scripts/role-snapshot-audit.sh --json     # machine-readable
#   ROLE_GOVERNANCE_DIR=... bash scripts/role-snapshot-audit.sh
#
# For every role in the catalog, compare the last commit that touched the
# role's knowledge snapshot against the newest commit on any owner path that
# lists the role in knowledge_roles. If the code moved after the snapshot, the
# snapshot is stale. Advisory only: the active routing role decides what
# actually changed.

set -euo pipefail

JSON=0
if [ "${1:-}" = "--json" ]; then
  JSON=1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "role-snapshot-audit: not inside a git repository" >&2
  exit 1
fi
ROOT="$(cd "$ROOT" && pwd -P)"

SNAPSHOT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SNAPSHOT_SKILL_DIR="$(cd "$SNAPSHOT_SCRIPT_DIR/.." && pwd -P)"
if [ -n "${ROLE_GOVERNANCE_DIR:-}" ]; then
  BASE_DIR="${ROLE_GOVERNANCE_DIR%/}"
  case "$BASE_DIR" in
    "$ROOT") BASE_DIR="." ;;
    "$ROOT"/*) BASE_DIR="${BASE_DIR#"$ROOT"/}" ;;
    /*)
      echo "role-snapshot-audit: ROLE_GOVERNANCE_DIR must be inside repository: $ROOT" >&2
      exit 1
      ;;
  esac
elif [ "$SNAPSHOT_SKILL_DIR" = "$ROOT" ]; then
  BASE_DIR="."
elif [[ "$SNAPSHOT_SKILL_DIR" == "$ROOT"/* ]]; then
  BASE_DIR="${SNAPSHOT_SKILL_DIR#"$ROOT"/}"
else
  echo "role-snapshot-audit: skipped (global skill is outside repository and has no project manifest)"
  exit 0
fi

MANIFEST="$ROOT/$BASE_DIR/doc-ownership.yaml"
CATALOG="$ROOT/$BASE_DIR/references/role-catalog.md"
KNOWLEDGE_DIR="$ROOT/$BASE_DIR/knowledge"
if [ ! -f "$MANIFEST" ] || [ ! -d "$KNOWLEDGE_DIR" ]; then
  echo "role-snapshot-audit: manifest or knowledge dir missing under $BASE_DIR" >&2
  exit 1
fi

TMP="$(mktemp)"
cat > "$TMP" <<'PY'
import fnmatch
import json
import re
import subprocess
import sys

root = sys.argv[1]
base_dir = sys.argv[2]
base_prefix = "" if base_dir in {"", "."} else base_dir.rstrip("/") + "/"
manifest_path = sys.argv[3]
catalog_path = sys.argv[4]
knowledge_dir = sys.argv[5]
json_out = sys.argv[6] == "1"


def git(*args):
    proc = subprocess.run(
        ["git", "-C", root, *args], capture_output=True, text=True
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def last_commit(paths):
    if not paths:
        return None
    out = git("log", "-1", "--format=%H %ct %cs %s", "--", *paths)
    if not out:
        return None
    parts = out.split(maxsplit=3)
    return {
        "hash": parts[0],
        "epoch": int(parts[1]) if parts[1].isdigit() else 0,
        "date": parts[2],
        "subject": parts[3] if len(parts) > 3 else "",
    }


def matches(path, pattern):
    if pattern.endswith("/**"):
        return path.startswith(pattern[:-2])
    if "*" in pattern:
        return fnmatch.fnmatchcase(path, pattern)
    return path == pattern


# Parse manifest owners (same shape as check-doc-sync.sh).
owners = []
current = None
list_key = None
in_owners = False
with open(manifest_path, encoding="utf-8") as fh:
    for raw in fh:
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        stripped = raw.strip()
        if not raw.startswith(" "):
            in_owners = stripped == "owners:"
            continue
        if not in_owners:
            continue
        if raw.startswith("  - "):
            current = {}
            owners.append(current)
            list_key = None
            item = stripped[2:].strip()
            if ":" in item:
                key, value = item.split(":", 1)
                current[key.strip()] = value.strip()
            continue
        if current is None:
            continue
        if raw.startswith("      - "):
            if list_key:
                current.setdefault(list_key, []).append(stripped[2:].strip())
            continue
        if raw.startswith("    ") and ":" in stripped:
            key, value = stripped.split(":", 1)
            key, value = key.strip(), value.strip()
            if value == "":
                list_key = key
                current.setdefault(key, [])
            else:
                current[key] = value
                list_key = None

# Parse catalog role ids.
catalog_roles = []
with open(catalog_path, encoding="utf-8") as fh:
    for raw in fh:
        m = re.match(r"^\|\s*`([a-z0-9][a-z0-9-]*)`\s*\|", raw.strip())
        if m:
            catalog_roles.append(m.group(1))

# code globs per role from owners' knowledge_roles
role_patterns = {role: [] for role in catalog_roles}
for owner in owners:
    roles = owner.get("knowledge_roles", [])
    if not isinstance(roles, list):
        continue
    for role in roles:
        if role in role_patterns:
            role_patterns[role].extend(owner.get("code", []))

dirty_paths = set()
for diff_args in (
    ("diff", "--name-only"),
    ("diff", "--cached", "--name-only"),
    ("ls-files", "--others", "--exclude-standard"),
):
    dirty_paths.update(path for path in git(*diff_args).splitlines() if path)

results = []
for role in catalog_roles:
    snapshot = f"{base_prefix}knowledge/{role}.md"
    if not git("cat-file", "-e", f"HEAD:{snapshot}") and not __import__("os").path.exists(
        f"{root}/{snapshot}"
    ):
        results.append({"role": role, "status": "missing", "snapshot_commit": None, "code_commit": None})
        continue
    snap_commit = last_commit([snapshot])
    patterns = role_patterns.get(role, [])
    code_commit = last_commit(patterns) if patterns else None
    updated_in_worktree = snapshot in dirty_paths
    stale = False
    if not updated_in_worktree:
        if snap_commit and code_commit:
            stale = code_commit["epoch"] > snap_commit["epoch"]
        elif code_commit and not snap_commit:
            stale = True
    results.append({
        "role": role,
        "status": "updated-in-worktree" if updated_in_worktree else ("stale" if stale else "fresh"),
        "snapshot_commit": snap_commit,
        "code_commit": code_commit,
    })

if json_out:
    print(json.dumps(results, indent=2))
else:
    for r in results:
        if r["status"] == "missing":
            print(f"{r['role']:24s} MISSING snapshot")
        elif r["status"] == "stale":
            code = r["code_commit"] or {}
            print(
                f"{r['role']:24s} STALE  code moved {code.get('date', '?')} "
                f"{code.get('subject', '')[:50]}"
            )
        elif r["status"] == "updated-in-worktree":
            print(f"{r['role']:24s} updated in worktree (commit after verification)")
        else:
            print(f"{r['role']:24s} fresh (snapshot at {r['snapshot_commit']['date']})")
PY
python3 "$TMP" "$ROOT" "$BASE_DIR" "$MANIFEST" "$CATALOG" "$KNOWLEDGE_DIR" "$JSON"
rm -f "$TMP"
