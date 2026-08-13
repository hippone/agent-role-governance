#!/usr/bin/env bash
# check-doc-sync.sh — enforce docs and persistent role knowledge from
# doc-ownership.yaml.
#
# Modes:
#   --dirty        staged + unstaged + untracked, using the worktree post-image
#   --staged       staged paths and index configuration only
#   --hook-commit  PreToolUse JSON mode; acts only on git commit commands
#
# [docs-na] waives only the owned-doc update check. [knowledge-na] additionally
# waives role knowledge only for one feature owner and only with [docs-na].
# Configuration, unowned-code, and registration violations always block.

set -euo pipefail

MODE="${1:---dirty}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  echo "doc-sync: skipped (not inside a git repository)"
  exit 0
fi
ROOT="$(cd "$ROOT" && pwd -P)"
ROOT_CMP="$(printf '%s' "$ROOT" | tr '[:upper:]' '[:lower:]')"

DOC_SYNC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOC_SYNC_SKILL_DIR="$(cd "$DOC_SYNC_SCRIPT_DIR/.." && pwd -P)"
DOC_SYNC_SKILL_CMP="$(printf '%s' "$DOC_SYNC_SKILL_DIR" | tr '[:upper:]' '[:lower:]')"
if [ -n "${ROLE_GOVERNANCE_DIR:-}" ]; then
  DOC_SYNC_BASE_DIR="${ROLE_GOVERNANCE_DIR%/}"
  DOC_SYNC_BASE_CMP="$(printf '%s' "$DOC_SYNC_BASE_DIR" | tr '[:upper:]' '[:lower:]')"
  case "$DOC_SYNC_BASE_CMP" in
    "$ROOT_CMP") DOC_SYNC_BASE_DIR="." ;;
    "$ROOT_CMP"/*) DOC_SYNC_BASE_DIR="${DOC_SYNC_BASE_DIR#"$ROOT"/}" ;;
    /*)
      echo "doc-sync: 1 violation(s), 0 warning(s)"
      echo "VIOLATION CONFIG: ROLE_GOVERNANCE_DIR must be inside repository: $ROOT"
      exit 1
      ;;
  esac
elif [ "$DOC_SYNC_SKILL_CMP" = "$ROOT_CMP" ]; then
  DOC_SYNC_BASE_DIR="."
elif [[ "$DOC_SYNC_SKILL_CMP" == "$ROOT_CMP"/* ]]; then
  DOC_SYNC_BASE_DIR="${DOC_SYNC_SKILL_DIR#"$ROOT"/}"
else
  echo "doc-sync: skipped (global skill is outside repository; copy it into the project and add doc-ownership.yaml)"
  exit 0
fi
export ROLE_GOVERNANCE_DIR="$DOC_SYNC_BASE_DIR"

run_python() {
  python3 - "$ROOT" "$1" "${DOC_SYNC_DOCS_NA:-0}" "${DOC_SYNC_KNOWLEDGE_NA:-0}" <<'PY'
import fnmatch
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path, PurePosixPath

root = Path(sys.argv[1])
mode = sys.argv[2]
docs_na = sys.argv[3] == "1"
knowledge_na = sys.argv[4] == "1"

if mode == "hook":
    try:
        payload = json.loads(os.environ.get("DOC_SYNC_HOOK_INPUT", "") or "{}")
    except Exception:
        sys.exit(0)
    command = str(payload.get("tool_input", {}).get("command", ""))
    if not re.search(r"(^|[;&|(]\s*)git\s+(-\S+\s+)*commit\b", command):
        sys.exit(0)
    docs_na = docs_na or "[docs-na]" in command
    knowledge_na = knowledge_na or "[knowledge-na]" in command
    mode = "staged"

config_from_index = mode == "staged"
base_dir = os.environ.get("ROLE_GOVERNANCE_DIR", "skills/project-rules").rstrip("/")
base_prefix = "" if base_dir in {"", "."} else base_dir + "/"
manifest_path = base_prefix + "doc-ownership.yaml"
catalog_path = base_prefix + "references/role-catalog.md"
system_map_path = base_prefix + "references/system-map.md"
knowledge_prefix = base_prefix + "knowledge/"


class GateError(RuntimeError):
    pass


def run_git(*args):
    proc = subprocess.run(
        ["git", "-C", str(root), *args],
        capture_output=True,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", "replace").strip()
        raise GateError(
            f"git {' '.join(args)} failed: {stderr or 'unknown error'}"
        )
    return proc.stdout


def git_paths(*args):
    return [
        item.decode("utf-8", "surrogateescape")
        for item in run_git(*args).split(b"\0")
        if item
    ]


def read_index(path):
    proc = subprocess.run(
        ["git", "-C", str(root), "show", f":{path}"],
        capture_output=True,
    )
    if proc.returncode != 0:
        return None
    try:
        return proc.stdout.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise GateError(f"index file is not UTF-8 text: {path}: {exc}") from exc


try:
    index_paths = set(git_paths("ls-files", "--cached", "-z"))
    head_probe = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--verify", "HEAD"],
        capture_output=True,
    )
    has_head = head_probe.returncode == 0
    head_paths = (
        set(git_paths("ls-tree", "-r", "--name-only", "-z", "HEAD"))
        if has_head
        else set()
    )
    staged = set(
        git_paths("diff", "--cached", "--no-renames", "--name-only", "-z")
    )
    unstaged = set(
        git_paths("diff", "--no-renames", "--name-only", "-z")
    )
    untracked = set(
        git_paths("ls-files", "--others", "--exclude-standard", "-z")
    )
    staged_added = set(
        git_paths(
            "diff",
            "--cached",
            "--no-renames",
            "--name-only",
            "--diff-filter=A",
            "-z",
        )
    )
except GateError as exc:
    print("doc-sync: 1 violation(s), 0 warning(s)")
    print(f"VIOLATION CONFIG: {exc}")
    sys.exit(1)


def read_head_configuration(path):
    if path not in head_paths:
        return None
    proc = subprocess.run(
        ["git", "-C", str(root), "show", f"HEAD:{path}"],
        capture_output=True,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", "replace").strip()
        raise GateError(
            f"cannot read HEAD configuration {path}: {stderr or 'unknown error'}"
        )
    try:
        return proc.stdout.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise GateError(f"HEAD file is not UTF-8 text: {path}: {exc}") from exc


def read_configuration(path):
    if config_from_index:
        return read_index(path)
    target = root / path
    if not target.is_file():
        return None
    try:
        return target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise GateError(f"cannot read configuration file {path}: {exc}") from exc


def configuration_exists(path):
    return path in index_paths if config_from_index else (root / path).is_file()


def configuration_paths(prefix):
    if config_from_index:
        return {
            path
            for path in index_paths
            if path.startswith(prefix)
            and "/" not in path[len(prefix) :]
            and path.endswith(".md")
        }
    directory = root / prefix
    if not directory.is_dir():
        return set()
    return {
        path.relative_to(root).as_posix()
        for path in directory.glob("*.md")
        if path.is_file()
    }


violations = []
warnings = []
notes = []

try:
    manifest_text = read_configuration(manifest_path)
    head_manifest_text = read_head_configuration(manifest_path) or "owners:\n"
    catalog_text = read_configuration(catalog_path)
    system_map_text = read_configuration(system_map_path)
except GateError as exc:
    print("doc-sync: 1 violation(s), 0 warning(s)")
    print(f"VIOLATION CONFIG: {exc}")
    sys.exit(1)

if manifest_text is None:
    print("doc-sync: 1 violation(s), 0 warning(s)")
    print(f"VIOLATION CONFIG: required manifest does not exist: {manifest_path}")
    sys.exit(1)
if catalog_text is None:
    violations.append(f"CONFIG: required role catalog does not exist: {catalog_path}")
    catalog_text = ""
if system_map_text is None:
    system_map_text = ""


def parse_owners(text):
    owners = []
    current = None
    list_key = None
    in_owners = False
    for raw in text.splitlines():
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
    return owners


def parse_required_bool(owner):
    raw = str(owner.get("docs_required", "true")).lower()
    if raw in {"true", "yes", "1"}:
        return True
    if raw in {"false", "no", "0"}:
        return False
    violations.append(
        f"CONFIG: owner {owner['id']} has invalid docs_required value: "
        f"{owner.get('docs_required')}"
    )
    return True


snapshot_fields = {
    "role_id",
    "tier",
    "knowledge_status",
    "captured_on",
    "repository_baseline",
    "evidence_scope",
    "context_contract",
}
snapshot_sections = (
    "Current Knowledge",
    "Source Pointers",
    "Known Drift And Unknowns",
    "Update Triggers",
    "Recent Deltas",
)


def parse_snapshot(path, text):
    if text is None:
        violations.append(f"CONFIG: knowledge snapshot cannot be read: {path}")
        return {}
    frontmatter = re.match(r"\A---\s*\n(.*?)\n---\s*(?:\n|\Z)", text, re.S)
    fields = {}
    if frontmatter:
        for raw in frontmatter.group(1).splitlines():
            if ":" in raw:
                key, value = raw.split(":", 1)
                fields[key.strip()] = value.strip()
    for field in sorted(snapshot_fields):
        if not fields.get(field):
            violations.append(
                f"CONFIG: knowledge snapshot is missing {field}: {path}"
            )
    status = fields.get("knowledge_status")
    if status and status not in {"current", "partial", "stale"}:
        violations.append(
            f"CONFIG: knowledge snapshot has invalid knowledge_status: "
            f"{path}: {status}"
        )
    for section in snapshot_sections:
        section_match = re.search(
            rf"(?ms)^## {re.escape(section)}\s*\n(.*?)(?=^## |\Z)", text
        )
        if not section_match:
            violations.append(
                f"CONFIG: knowledge snapshot is missing section '{section}': {path}"
            )
        elif not section_match.group(1).strip():
            violations.append(
                f"CONFIG: knowledge snapshot section is empty '{section}': {path}"
            )
        elif section == "Recent Deltas":
            delta_count = len(
                re.findall(r"(?m)^\s*-\s+\S", section_match.group(1))
            )
            if delta_count > 5:
                violations.append(
                    f"CONFIG: knowledge snapshot has {delta_count} Recent Deltas; "
                    f"maximum is 5: {path}"
                )
    return fields


owners = parse_owners(manifest_text)
for owner_id, count in sorted(
    Counter(owner.get("id", "") for owner in owners).items()
):
    if not owner_id:
        violations.append("CONFIG: owner entry is missing id")
    elif not re.fullmatch(r"[a-z0-9][a-z0-9-]*", owner_id):
        violations.append(f"CONFIG: owner id has invalid format: {owner_id}")
    elif count > 1:
        violations.append(f"CONFIG: duplicate owner id: {owner_id}")

catalog_role_list = []
catalog_role_tiers = {}
active_catalog_tier = None
for raw in catalog_text.splitlines():
    stripped = raw.strip()
    if stripped == "## L1 Direct Roles":
        active_catalog_tier = "L1"
        continue
    if stripped == "## L2 Coordinating Roles":
        active_catalog_tier = "L2"
        continue
    if stripped.startswith("## "):
        active_catalog_tier = None
        continue
    role_match = re.match(r"^\|\s*`([a-z0-9][a-z0-9-]*)`\s*\|", stripped)
    if not role_match:
        continue
    role = role_match.group(1)
    catalog_role_list.append(role)
    if active_catalog_tier is None:
        violations.append(
            f"CONFIG: catalog role is outside an L1/L2 role table: {role}"
        )
    else:
        catalog_role_tiers.setdefault(role, active_catalog_tier)
catalog_roles = set(catalog_role_list)
for role, count in sorted(Counter(catalog_role_list).items()):
    if count > 1:
        violations.append(f"CONFIG: duplicate role id in catalog: {role}")
if not catalog_roles:
    violations.append("CONFIG: role catalog declares no role IDs")

knowledge_paths = configuration_paths(knowledge_prefix)
knowledge_roles = {PurePosixPath(path).stem for path in knowledge_paths}
snapshot_metadata = {}
snapshot_texts = {}
for role in sorted(catalog_roles - knowledge_roles):
    violations.append(
        f"CONFIG: catalog role has no knowledge snapshot: "
        f"{knowledge_prefix}{role}.md"
    )
for role in sorted(knowledge_roles - catalog_roles):
    violations.append(
        f"CONFIG: knowledge snapshot has no catalog role: "
        f"{knowledge_prefix}{role}.md"
    )
for path in sorted(knowledge_paths):
    try:
        snapshot_text = read_configuration(path)
        fields = parse_snapshot(path, snapshot_text)
        snapshot_metadata[path] = fields
        snapshot_texts[path] = snapshot_text or ""
    except GateError as exc:
        violations.append(f"CONFIG: {exc}")
        continue
    declared_role = fields.get("role_id")
    declared_tier = fields.get("tier")
    expected_role = PurePosixPath(path).stem
    if declared_role and declared_role != expected_role:
        violations.append(
            f"CONFIG: knowledge snapshot role_id mismatch: {path} "
            f"declares {declared_role}"
        )
    expected_tier = catalog_role_tiers.get(expected_role)
    if declared_tier and expected_tier and declared_tier != expected_tier:
        violations.append(
            f"CONFIG: knowledge snapshot tier mismatch: {path} "
            f"declares {declared_tier}, catalog requires {expected_tier}"
        )


def snapshot_is_initialized(path):
    fields = snapshot_metadata.get(path, {})
    text = snapshot_texts.get(path, "")
    if fields.get("captured_on") in {None, "", "pending"}:
        return False
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", fields.get("captured_on", "")):
        return False
    if fields.get("repository_baseline") in {None, "", "pending"}:
        return False
    placeholders = (
        "No captured facts yet",
        "_None yet._",
        "Add compact, current facts",
    )
    if any(placeholder in text for placeholder in placeholders):
        return False
    recent = re.search(r"(?ms)^## Recent Deltas\s*\n(.*?)(?=^## |\Z)", text)
    return bool(recent and re.search(r"(?m)^\s*-\s+\d{4}-\d{2}-\d{2}:", recent.group(1)))

all_owner_roles = set()
for owner in owners:
    owner_id = owner.get("id", "<missing>")
    kind = owner.get("kind")
    if kind not in {"feature", "infra", "contract", "governance"}:
        violations.append(f"CONFIG: owner {owner_id} has invalid kind: {kind}")
    code = owner.get("code", [])
    if not isinstance(code, list) or not code:
        violations.append(f"CONFIG: owner {owner_id} has no code patterns")
        owner["code"] = []
    roles = owner.get("knowledge_roles", [])
    if not isinstance(roles, list) or not roles:
        violations.append(f"CONFIG: owner {owner_id} has no knowledge_roles")
        roles = []
        owner["knowledge_roles"] = []
    for role, count in sorted(Counter(roles).items()):
        if count > 1:
            violations.append(
                f"CONFIG: owner {owner_id} repeats knowledge role: {role}"
            )
    for role in sorted(set(roles) - catalog_roles):
        violations.append(
            f"CONFIG: owner {owner_id} references unknown knowledge role: {role}"
        )
    all_owner_roles.update(roles)
    owner["_docs_required"] = parse_required_bool(owner)
    docs = owner.get("docs", [])
    if not isinstance(docs, list):
        violations.append(f"CONFIG: owner {owner_id} docs must be a list")
        docs = []
        owner["docs"] = []
    if owner["_docs_required"] and not docs:
        violations.append(f"CONFIG: owner {owner_id} requires docs but lists none")
    for doc in docs:
        if not configuration_exists(doc):
            violations.append(
                f"CONFIG: doc listed for {owner_id} does not exist: {doc}"
            )
for role in sorted(catalog_roles - all_owner_roles):
    violations.append(f"CONFIG: catalog role is not assigned to any owner: {role}")

head_owners = parse_owners(head_manifest_text)
for owner in head_owners:
    owner["_docs_required"] = str(
        owner.get("docs_required", "true")
    ).lower() not in {"false", "no", "0"}

change_set = staged if mode == "staged" else staged | unstaged | untracked
new_files = staged_added if mode == "staged" else staged_added | untracked


def is_test(path):
    parts = set(PurePosixPath(path).parts)
    if parts.intersection({"__tests__", "test", "tests"}):
        return True
    return bool(
        re.search(
            r"(?:^|[.-])(?:test|spec)\.[^/]+$",
            PurePosixPath(path).name,
        )
    )


code_set = {path for path in change_set if not is_test(path)}


def matches(path, pattern):
    if pattern.endswith("/**"):
        return path.startswith(pattern[:-2])
    if "*" in pattern:
        return fnmatch.fnmatchcase(path, pattern)
    return path == pattern


def changed_post_image_exists(path):
    return path in change_set and configuration_exists(path)


def shown_paths(paths):
    result = ", ".join(paths[:3])
    if len(paths) > 3:
        result += f" (+{len(paths) - 3} more)"
    return result


touched = []
waived_doc_owners = []
waived_knowledge_owners = []
post_image_paths = {path for path in code_set if configuration_exists(path)}
deleted_paths = code_set - post_image_paths

for owner_set, candidate_paths in (
    (owners, post_image_paths),
    (head_owners, deleted_paths),
):
    for owner in owner_set:
        hits = sorted(
            path
            for path in candidate_paths
            if any(matches(path, pattern) for pattern in owner.get("code", []))
        )
        if not hits:
            continue
        touched.append((owner, hits))
        if owner.get("_docs_required", True):
            docs_satisfied = any(
                changed_post_image_exists(doc) for doc in owner.get("docs", [])
            )
            if not docs_satisfied and docs_na:
                waived_doc_owners.append(owner["id"])
            elif not docs_satisfied:
                violations.append(
                    f"{owner['id']}: code changed ({shown_paths(hits)}) "
                    f"but none of its docs touched -> update one of: "
                    + ", ".join(owner.get("docs", []))
                )

        eligible_snapshots = [
            f"{knowledge_prefix}{role}.md"
            for role in owner.get("knowledge_roles", [])
            if role in catalog_roles
        ]
        changed_snapshots = [
            path for path in eligible_snapshots if changed_post_image_exists(path)
        ]
        initialized_snapshots = [
            path for path in changed_snapshots if snapshot_is_initialized(path)
        ]
        knowledge_satisfied = bool(initialized_snapshots)
        if eligible_snapshots and not knowledge_satisfied:
            if changed_snapshots:
                violations.append(
                    f"{owner['id']}: touched knowledge snapshot is still a "
                    "placeholder or lacks captured_on, repository_baseline, "
                    "source facts, and a dated Recent Delta: "
                    + ", ".join(changed_snapshots)
                )
            elif knowledge_na and docs_na and owner.get("kind") == "feature":
                waived_knowledge_owners.append(owner["id"])
            else:
                violations.append(
                    f"{owner['id']}: code changed ({shown_paths(hits)}) "
                    "but none of its eligible role knowledge snapshots touched "
                    "-> update one of: "
                    + ", ".join(eligible_snapshots)
                )

feature_ids = list(
    dict.fromkeys(
        owner["id"] for owner, _ in touched if owner.get("kind") == "feature"
    )
)
touched_owner_shapes = {
    owner["id"]: owner.get("kind") for owner, _ in touched
}
if len(feature_ids) >= 2:
    warnings.append(
        "mixed feature surfaces in one change set: "
        + ", ".join(feature_ids)
        + " — do not mix surfaces in one patch without explicit scope"
    )
if knowledge_na and (
    len(touched_owner_shapes) != 1
    or next(iter(touched_owner_shapes.values()), None) != "feature"
):
    shape = ", ".join(
        f"{owner_id} ({kind})"
        for owner_id, kind in sorted(touched_owner_shapes.items())
    ) or "none"
    violations.append(
        "[knowledge-na] requires exactly one affected feature owner; "
        f"affected owners: {shape}"
    )
if knowledge_na and not docs_na:
    violations.append(
        "[knowledge-na] requires [docs-na]; the two waivers must share the same "
        "no-durable-change justification"
    )
if len(set(waived_knowledge_owners)) > 1:
    violations.append(
        "[knowledge-na] is limited to one feature surface, but would waive: "
        + ", ".join(sorted(set(waived_knowledge_owners)))
    )
if knowledge_na and not waived_knowledge_owners:
    violations.append(
        "[knowledge-na] was requested but no eligible single-feature knowledge "
        "check was waived; remove the marker or update the required snapshot"
    )
seen_infra_notes = set()
for owner, _hits in touched:
    if owner.get("kind") == "infra" and owner.get("dependents"):
        deps = owner["dependents"]
        label = "all feature surfaces" if deps == "all" else ", ".join(deps)
        note_key = (owner["id"], label)
        if note_key not in seen_infra_notes:
            seen_infra_notes.add(note_key)
            notes.append(
                f"infra {owner['id']} touched — review dependent surfaces' docs: {label}"
            )
if waived_doc_owners:
    notes.append(
        "[docs-na] waived owned-doc checks only for: "
        + ", ".join(sorted(waived_doc_owners))
    )
if waived_knowledge_owners:
    notes.append(
        "[knowledge-na] waived role knowledge only for: "
        + ", ".join(sorted(set(waived_knowledge_owners)))
    )

# Deleted files need no owner mapping; a removal is not new unowned code.
unowned_roots = []
for match in re.finditer(
    r"(?m)^unowned_code_roots:\s*\n((?:^\s+-\s+[^\n]+\n)+)",
    manifest_text or "",
):
    unowned_roots.extend(
        raw.strip()[2:].strip()
        for raw in match.group(1).splitlines()
        if raw.strip().startswith("-")
    )
for path in sorted(code_set - deleted_paths):
    owner_set = owners if configuration_exists(path) else head_owners
    path_patterns = [
        pattern for owner in owner_set for pattern in owner.get("code", [])
    ]
    if (
        any(path.startswith(root.rstrip("/") + "/") for root in unowned_roots)
        and not any(matches(path, pattern) for pattern in path_patterns)
    ):
        violations.append(
            f"unowned code change: {path} "
            f"— add it to {manifest_path}"
        )

def parse_system_map_checks(text):
    checks = {"require": [], "warn": [], "modules": []}
    in_section = False
    subkey = None
    for raw in text.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not raw.startswith(" "):
            if stripped == "system_map_checks:":
                in_section = True
                subkey = None
            else:
                in_section = False
            continue
        if not in_section:
            continue
        if raw.startswith("  ") and not raw.startswith("    ") and stripped.endswith(":"):
            subkey = stripped[:-1]
            continue
        if raw.startswith("    - ") and subkey in checks:
            checks[subkey].append(stripped[3:].strip())
    return checks


if system_map_text:
    smap_checks = parse_system_map_checks(manifest_text or "")
    smap_module_tokens = {
        module_root: re.findall(
            re.escape(module_root.rstrip("/") + "/") + r"[^\s`,)]+",
            system_map_text,
        )
        for module_root in smap_checks["modules"]
    }
    for path in sorted(new_files):
        if is_test(path):
            continue
        name = PurePosixPath(path).stem
        for pattern in smap_checks["require"]:
            if fnmatch.fnmatchcase(path, pattern) and name not in system_map_text:
                violations.append(
                    f"new file not registered in references/system-map.md: {path}"
                )
        for pattern in smap_checks["warn"]:
            if fnmatch.fnmatchcase(path, pattern) and name not in system_map_text:
                warnings.append(
                    f"new file not named in references/system-map.md: {path}"
                    " (register it if it owns a surface, state, or client)"
                )

    for module_root in smap_checks["modules"]:
        prefix = module_root.rstrip("/") + "/"
        depth = len(prefix.split("/"))
        new_module_dirs = {
            path.split("/")[depth - 1]
            for path in new_files
            if path.startswith(prefix)
            and len(path.split("/")) > depth
            and not is_test(path)
        }
        for module in sorted(new_module_dirs):
            module_path = prefix + module + "/"
            if not any(
                fnmatch.fnmatchcase(module_path, token)
                or fnmatch.fnmatchcase(module_path, token + "*")
                for token in smap_module_tokens.get(module_root, [])
            ):
                violations.append(
                    f"new module not registered in references/system-map.md: "
                    f"{module_path}"
                )

if not (violations or warnings or notes):
    print("doc-sync: clean")
    sys.exit(0)
print(f"doc-sync: {len(violations)} violation(s), {len(warnings)} warning(s)")
for item in violations:
    print(f"VIOLATION {item}")
for item in warnings:
    print(f"WARNING {item}")
for item in notes:
    print(f"NOTE {item}")
sys.exit(1 if violations else 0)
PY
}

case "$MODE" in
  --dirty)
    run_python dirty
    ;;
  --staged)
    run_python staged
    ;;
  --hook-commit)
    INPUT="$(cat 2>/dev/null || true)"
    case "$INPUT" in
      *"git commit"*) ;;
      *) exit 0 ;;
    esac
    set +e
    OUT="$(DOC_SYNC_HOOK_INPUT="$INPUT" run_python hook)"
    RC=$?
    set -e
    if [ "$RC" -eq 1 ]; then
      {
        echo "doc-sync gate blocked this commit:"
        echo "$OUT"
        echo ""
        echo "Update the listed docs and eligible role knowledge snapshots"
        echo "(ownership map: ${ROLE_GOVERNANCE_DIR:-skills/project-rules}/doc-ownership.yaml)."
        echo "[docs-na] waives docs; [knowledge-na] additionally requires"
        echo "[docs-na] and is limited to one feature surface."
      } >&2
      exit 2
    fi
    exit "$RC"
    ;;
  *)
    echo "Usage: check-doc-sync.sh [--dirty|--staged|--hook-commit]" >&2
    exit 64
    ;;
esac
