#!/usr/bin/env bash
# quality-ledger.sh — aggregate quality evidence from task-level receipts.
#
# The ledger is a JSONL file (<skill-dir>/ledger/YYYY-MM.jsonl), one JSON
# object per line, appended by the active routing role after each L2 task
# (see workflows/quality-ledger.md). This script aggregates it into
# measurable signals: QA GO/NO-GO rate, routing-verification rate, issue
# counts, and per-role distribution.
#
# Usage:
#   echo '<json>' | bash scripts/quality-ledger.sh --add
#   bash scripts/quality-ledger.sh --summary [--json]
#   bash scripts/quality-ledger.sh --routes          # unverified/mismatched routes
#   bash scripts/quality-ledger.sh --self-test
#
# Env: ROLE_GOVERNANCE_DIR (default skills/project-rules), QUALITY_LEDGER_DIR
#      to override the ledger location.

set -euo pipefail

BASE_DIR="${ROLE_GOVERNANCE_DIR:-skills/project-rules}"
LEDGER_DIR="${QUALITY_LEDGER_DIR:-$BASE_DIR/ledger}"

run_python() {
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<'PY'
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

base_dir = sys.argv[1]
ledger_dir = sys.argv[2]
action = sys.argv[3]
extra = sys.argv[4] if len(sys.argv) > 4 else ""

VALID_QA = {"GO", "NO-GO", "PARTIAL"}
VALID_TIERS = {"T1", "T2", "T3"}
VALID_CONF = {"high", "medium", "low"}


def ledger_path(month=None):
    month = month or datetime.now().strftime("%Y-%m")
    return Path(ledger_dir) / f"{month}.jsonl"


def read_all():
    rows = []
    for path in sorted(Path(ledger_dir).glob("*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def record_id(ts):
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", ts or "")
    return f"{m.group(1)}-{m.group(2)}" if m else None


if action == "add":
    raw = sys.stdin.read().strip()
    try:
        entry = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"quality-ledger: invalid JSON: {exc}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(entry, dict) or "id" not in entry:
        print("quality-ledger: entry requires an 'id' field", file=sys.stderr)
        sys.exit(1)
    qa = entry.get("qa") or {}
    routing = entry.get("routing") or {}
    errors = []
    if "status" not in qa:
        errors.append("qa.status is required")
    elif qa.get("status") not in VALID_QA:
        errors.append(f"qa.status must be one of {sorted(VALID_QA)}")
    if "role" not in routing:
        errors.append("routing.role is required")
    if "date" not in entry:
        entry["date"] = datetime.now().strftime("%Y-%m-%d")
    if errors:
        for err in errors:
            print(f"quality-ledger: {err}", file=sys.stderr)
        sys.exit(1)
    month = record_id(entry.get("date")) or datetime.now().strftime("%Y-%m")
    path = ledger_path(month)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"quality-ledger: appended to {path}")
    sys.exit(0)

rows = read_all()

if action == "routes":
    bad = []
    for row in rows:
        routing = row.get("routing") or {}
        if routing.get("verified") is False or routing.get("route_verified") is False:
            bad.append((row.get("date", "?"), row.get("id"), routing.get("role", "?"),
                        routing.get("expected_role", "?")))
    if not bad:
        print("quality-ledger: no unverified or mismatched routes")
    else:
        print(f"quality-ledger: {len(bad)} unverified/mismatched route(s)")
        for date, rid, role, expected in bad:
            print(f"  {date} {rid} routed={role} expected={expected or '?'}")
    sys.exit(0)

# --summary
total = len(rows)
if total == 0:
    print("quality-ledger: no entries (ledger dir: %s)" % ledger_dir)
    sys.exit(0)

qa_counts = {}
issues = 0
issue_rows = 0
verified = 0
routed_total = 0
role_dist = {}

for row in rows:
    qa = row.get("qa") or {}
    routing = row.get("routing") or {}
    status = qa.get("status", "?")
    qa_counts[status] = qa_counts.get(status, 0) + 1
    n_issues = int(qa.get("issues") or 0)
    if n_issues:
        issue_rows += 1
        issues += n_issues
    role_dist[routing.get("role", "?")] = role_dist.get(routing.get("role", "?"), 0) + 1
    if routing.get("route_verified") is not None or routing.get("verified") is not None:
        routed_total += 1
        if routing.get("route_verified") is True or routing.get("verified") is True:
            verified += 1

go_count = qa_counts.get("GO", 0)
go_rate = go_count / total * 100 if total else 0
verify_rate = verified / routed_total * 100 if routed_total else 0

if extra == "--json":
    print(json.dumps({
        "total": total,
        "qa": qa_counts,
        "go_rate": round(go_rate, 1),
        "issues": issues,
        "issue_rows": issue_rows,
        "route_verified": verified,
        "route_verified_total": routed_total,
        "route_verify_rate": round(verify_rate, 1) if routed_total else None,
        "role_distribution": role_dist,
    }, indent=2))
else:
    print(f"quality-ledger: {total} entries")
    print(f"  QA: GO={qa_counts.get('GO', 0)} NO-GO={qa_counts.get('NO-GO', 0)} "
          f"PARTIAL={qa_counts.get('PARTIAL', 0)}")
    print(f"  GO rate: {go_rate:.1f}%")
    if issues:
        print(f"  issues: {issues} across {issue_rows} entries")
    if routed_total:
        print(f"  route verified: {verified}/{routed_total} ({verify_rate:.1f}%)")
    if role_dist:
        top = sorted(role_dist.items(), key=lambda kv: -kv[1])[:5]
        print("  roles: " + ", ".join(f"{r}={c}" for r, c in top))
PY
  python3 "$tmp" "$BASE_DIR" "$LEDGER_DIR" "$1" "$2"
  rm -f "$tmp"
}

case "${1:-}" in
  --add)
    run_python add ""
    ;;
  --summary)
    run_python summary "${2:-}"
    ;;
  --routes)
    run_python routes ""
    ;;
  --self-test)
    TMP="$(mktemp -d)"
    OLD="${QUALITY_LEDGER_DIR:-}"
    export QUALITY_LEDGER_DIR="$TMP"
    echo '{"id":"t1","date":"2026-08-01","routing":{"role":"frontend-engineer","tier":"T2","verified":true},"qa":{"status":"GO","issues":0}}' | bash "$0" --add > /dev/null
    echo '{"id":"t2","date":"2026-08-02","routing":{"role":"contract-coordinator","tier":"T1","verified":true},"qa":{"status":"NO-GO","issues":2}}' | bash "$0" --add > /dev/null
    echo '{"id":"t3","date":"2026-08-03","routing":{"role":"change-coordinator","tier":"T2","verified":false,"expected_role":"backend-engineer"},"qa":{"status":"PARTIAL","issues":1}}' | bash "$0" --add > /dev/null
    OUT="$(bash "$0" --summary)"
    echo "$OUT" | grep -q "3 entries" || { echo "FAIL: entry count" >&2; exit 1; }
    echo "$OUT" | grep -q "GO rate: 33.3%" || { echo "FAIL: GO rate" >&2; exit 1; }
    echo "$OUT" | grep -q "route verified: 2/3 (66.7%)" || { echo "FAIL: verify rate" >&2; exit 1; }
    ROUTES="$(bash "$0" --routes)"
    echo "$ROUTES" | grep -q "1 unverified" || { echo "FAIL: routes count" >&2; exit 1; }
    export QUALITY_LEDGER_DIR="$OLD"
    rm -rf "$TMP"
    echo "quality-ledger: self-test passed"
    ;;
  *)
    echo "Usage: quality-ledger.sh [--add|--summary [--json]|--routes|--self-test]" >&2
    exit 64
    ;;
esac
