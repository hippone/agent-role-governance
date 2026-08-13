#!/usr/bin/env bash
# quality-ledger.sh — validate, append, and aggregate quality evidence.
#
# Usage:
#   echo '<json>' | bash scripts/quality-ledger.sh --add
#   bash scripts/quality-ledger.sh --summary [--json]
#   bash scripts/quality-ledger.sh --routes
#   bash scripts/quality-ledger.sh --self-test
#
# Env: ROLE_GOVERNANCE_DIR overrides the detected skill directory;
#      QUALITY_LEDGER_DIR overrides the ledger location;
#      QUALITY_LEDGER_RECEIPT_DIR is required for verified review receipts.

set -euo pipefail

LEDGER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LEDGER_SKILL_DIR="$(cd "$LEDGER_SCRIPT_DIR/.." && pwd -P)"
BASE_DIR="${ROLE_GOVERNANCE_DIR:-$LEDGER_SKILL_DIR}"
LEDGER_DIR="${QUALITY_LEDGER_DIR:-$BASE_DIR/ledger}"
RECEIPT_DIR="${QUALITY_LEDGER_RECEIPT_DIR:-}"

run_python() {
  local ledger_action="$1"
  local ledger_extra="${2:-}"
  local ledger_tmp
  ledger_tmp="$(mktemp)"
  cat > "$ledger_tmp" <<'PY'
import json
import re
import sys
from datetime import datetime
from pathlib import Path

base_dir = Path(sys.argv[1])
ledger_dir = Path(sys.argv[2])
action = sys.argv[3]
extra = sys.argv[4] if len(sys.argv) > 4 else ""
receipt_dir = Path(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else None

VALID_QA = {"GO", "NO-GO", "PARTIAL"}
VALID_TIERS = {"T1", "T2", "T3"}
VALID_CONF = {"high", "medium", "low"}
VALID_SEVERITY = {"low", "medium", "high", "critical"}
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
ROLE_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
NONNEGATIVE_METRICS = {
    "input_tokens", "output_tokens", "cost_usd", "cycle_seconds",
    "human_review_minutes", "rework_count", "escaped_defects",
    "rollback_count",
}


def catalog_roles():
    catalog = base_dir / "references" / "role-catalog.md"
    if not catalog.is_file():
        return set()
    return set(
        re.findall(
            r"(?m)^\|\s*`([a-z0-9][a-z0-9-]*)`\s*\|",
            catalog.read_text(encoding="utf-8"),
        )
    )


VALID_ROLES = catalog_roles()


def validate_role(value, field, errors, required=False):
    if value is None or value == "":
        if required:
            errors.append(f"{field} is required")
        return
    if not isinstance(value, str) or not ROLE_RE.fullmatch(value):
        errors.append(f"{field} has invalid format")
    elif VALID_ROLES and value not in VALID_ROLES:
        errors.append(f"{field} is not declared in role-catalog.md: {value}")


def validate_entry(entry, source="entry"):
    errors = []
    if not isinstance(entry, dict):
        return [f"{source}: entry must be a JSON object"]

    entry_id = entry.get("id")
    if not isinstance(entry_id, str) or not ID_RE.fullmatch(entry_id):
        errors.append(f"{source}: id is required and must match {ID_RE.pattern}")

    date_value = entry.get("date")
    if date_value is not None:
        if not isinstance(date_value, str):
            errors.append(f"{source}: date must be YYYY-MM-DD")
        else:
            try:
                datetime.strptime(date_value, "%Y-%m-%d")
            except ValueError:
                errors.append(f"{source}: date must be a real YYYY-MM-DD value")

    routing = entry.get("routing")
    if not isinstance(routing, dict):
        errors.append(f"{source}: routing must be an object")
        routing = {}
    validate_role(routing.get("role"), f"{source}: routing.role", errors, required=True)
    tier = routing.get("tier")
    if tier is not None and tier not in VALID_TIERS:
        errors.append(f"{source}: routing.tier must be one of {sorted(VALID_TIERS)}")
    confidence = routing.get("confidence")
    if confidence is not None and confidence not in VALID_CONF:
        errors.append(f"{source}: routing.confidence must be one of {sorted(VALID_CONF)}")
    verified = routing.get("verified", routing.get("route_verified"))
    if verified is not None and not isinstance(verified, bool):
        errors.append(f"{source}: routing.verified must be boolean")
    expected_role = routing.get("expected_role")
    if verified is False and not expected_role:
        errors.append(f"{source}: routing.expected_role is required when verified is false")
    validate_role(expected_role, f"{source}: routing.expected_role", errors)

    qa = entry.get("qa")
    if not isinstance(qa, dict):
        errors.append(f"{source}: qa must be an object")
        qa = {}
    status = qa.get("status")
    if status not in VALID_QA:
        errors.append(f"{source}: qa.status must be one of {sorted(VALID_QA)}")
    issues = qa.get("issues", 0)
    if isinstance(issues, bool) or not isinstance(issues, int) or issues < 0:
        errors.append(f"{source}: qa.issues must be a non-negative integer")
    severity = qa.get("severity")
    if severity is not None and severity not in VALID_SEVERITY:
        errors.append(f"{source}: qa.severity must be one of {sorted(VALID_SEVERITY)}")
    review = qa.get("review")
    if review is not None and (not isinstance(review, str) or not review.strip()):
        errors.append(f"{source}: qa.review must be a non-empty string")
    review_verified = qa.get("review_verified")
    if review_verified is not None and not isinstance(review_verified, bool):
        errors.append(f"{source}: qa.review_verified must be boolean")
    review_ref = qa.get("review_ref")
    if review_verified is True and (not isinstance(review_ref, str) or not review_ref.strip()):
        errors.append(f"{source}: qa.review_ref is required when review_verified is true")
    elif review_verified is True:
        review_path = Path(review_ref)
        if review_path.is_absolute() or ".." in review_path.parts:
            errors.append(f"{source}: qa.review_ref must be a safe relative path")
        elif receipt_dir is None:
            errors.append(
                f"{source}: QUALITY_LEDGER_RECEIPT_DIR is required when "
                "qa.review_verified is true"
            )
        elif not (receipt_dir / review_path).is_file():
            errors.append(
                f"{source}: verified review receipt does not exist: "
                f"{receipt_dir / review_path}"
            )

    metrics = entry.get("metrics")
    if metrics is not None:
        if not isinstance(metrics, dict):
            errors.append(f"{source}: metrics must be an object")
        else:
            for key in NONNEGATIVE_METRICS:
                if key not in metrics:
                    continue
                value = metrics[key]
                if isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0:
                    errors.append(f"{source}: metrics.{key} must be a non-negative number")
    return errors


def read_all():
    rows = []
    errors = []
    seen_ids = {}
    for ledger_path in sorted(ledger_dir.glob("*.jsonl")):
        try:
            lines = ledger_path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeDecodeError) as exc:
            errors.append(f"{ledger_path}: cannot read ledger: {exc}")
            continue
        for line_number, line in enumerate(lines, 1):
            line = line.strip()
            if not line:
                continue
            source = f"{ledger_path}:{line_number}"
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                errors.append(f"{source}: invalid JSON: {exc}")
                continue
            row_errors = validate_entry(row, source)
            errors.extend(row_errors)
            row_id = row.get("id") if isinstance(row, dict) else None
            if isinstance(row_id, str):
                if row_id in seen_ids:
                    errors.append(f"{source}: duplicate id {row_id}; first seen at {seen_ids[row_id]}")
                else:
                    seen_ids[row_id] = source
            if not row_errors:
                rows.append(row)
    return rows, errors, seen_ids


def fail_errors(errors):
    print(f"quality-ledger: {len(errors)} integrity error(s)", file=sys.stderr)
    for error in errors:
        print(f"ERROR {error}", file=sys.stderr)
    raise SystemExit(1)


rows, integrity_errors, seen_ids = read_all()

if action == "add":
    if integrity_errors:
        fail_errors(integrity_errors)
    raw = sys.stdin.read().strip()
    try:
        entry = json.loads(raw)
    except json.JSONDecodeError as exc:
        fail_errors([f"entry: invalid JSON: {exc}"])
    if isinstance(entry, dict) and "date" not in entry:
        entry["date"] = datetime.now().strftime("%Y-%m-%d")
    entry_errors = validate_entry(entry)
    entry_id = entry.get("id") if isinstance(entry, dict) else None
    if isinstance(entry_id, str) and entry_id in seen_ids:
        entry_errors.append(f"entry: duplicate id {entry_id}; first seen at {seen_ids[entry_id]}")
    if entry_errors:
        fail_errors(entry_errors)
    month = entry["date"][:7]
    output_path = ledger_dir / f"{month}.jsonl"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("a", encoding="utf-8") as ledger_file:
        ledger_file.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")
    print(f"quality-ledger: appended to {output_path}")
    raise SystemExit(0)

if integrity_errors:
    fail_errors(integrity_errors)

if action == "routes":
    unverified = []
    for row in rows:
        routing = row["routing"]
        verified = routing.get("verified", routing.get("route_verified"))
        if verified is not True:
            unverified.append((
                row.get("date", "?"), row["id"], routing["role"],
                routing.get("expected_role", "?"), verified,
            ))
    if not unverified:
        print("quality-ledger: no unverified or mismatched routes")
    else:
        print(f"quality-ledger: {len(unverified)} unverified/mismatched route(s)")
        for date_value, row_id, role, expected, verified in unverified:
            state = "mismatch" if verified is False else "not-reviewed"
            print(f"  {date_value} {row_id} state={state} routed={role} expected={expected or '?'}")
    raise SystemExit(0)

total = len(rows)
if total == 0:
    print(f"quality-ledger: no entries (ledger dir: {ledger_dir})")
    raise SystemExit(0)

qa_counts = {}
issues = 0
issue_rows = 0
verified = 0
routed_total = 0
review_verified = 0
review_total = 0
role_dist = {}
metric_totals = {key: 0 for key in NONNEGATIVE_METRICS}
metric_counts = {key: 0 for key in NONNEGATIVE_METRICS}

for row in rows:
    qa = row["qa"]
    routing = row["routing"]
    status = qa["status"]
    qa_counts[status] = qa_counts.get(status, 0) + 1
    issue_count = qa.get("issues", 0)
    if issue_count:
        issue_rows += 1
        issues += issue_count
    role_dist[routing["role"]] = role_dist.get(routing["role"], 0) + 1
    route_state = routing.get("verified", routing.get("route_verified"))
    if route_state is not None:
        routed_total += 1
        if route_state is True:
            verified += 1
    if qa.get("review"):
        review_total += 1
        if qa.get("review_verified") is True:
            review_verified += 1
    for key, value in (row.get("metrics") or {}).items():
        if key in metric_totals:
            metric_totals[key] += value
            metric_counts[key] += 1

go_count = qa_counts.get("GO", 0)
go_rate = go_count / total * 100
verify_rate = verified / routed_total * 100 if routed_total else None
review_verify_rate = review_verified / review_total * 100 if review_total else None
metrics_output = {
    key: {"total": metric_totals[key], "entries": metric_counts[key]}
    for key in sorted(NONNEGATIVE_METRICS)
    if metric_counts[key]
}

summary = {
    "total": total,
    "qa": qa_counts,
    "go_rate": round(go_rate, 1),
    "issues": issues,
    "issue_rows": issue_rows,
    "route_verified": verified,
    "route_verified_total": routed_total,
    "route_verify_rate": round(verify_rate, 1) if verify_rate is not None else None,
    "review_verified": review_verified,
    "review_total": review_total,
    "review_verify_rate": round(review_verify_rate, 1) if review_verify_rate is not None else None,
    "role_distribution": role_dist,
    "metrics": metrics_output,
}

if extra == "--json":
    print(json.dumps(summary, indent=2, ensure_ascii=False, sort_keys=True))
else:
    print(f"quality-ledger: {total} entries")
    print(f"  QA: GO={qa_counts.get('GO', 0)} NO-GO={qa_counts.get('NO-GO', 0)} PARTIAL={qa_counts.get('PARTIAL', 0)}")
    print(f"  GO rate: {go_rate:.1f}%")
    if issues:
        print(f"  issues: {issues} across {issue_rows} entries")
    if routed_total:
        print(f"  route verified: {verified}/{routed_total} ({verify_rate:.1f}%)")
    else:
        print("  route verified: unmeasured")
    if review_total:
        print(f"  review receipts verified: {review_verified}/{review_total} ({review_verify_rate:.1f}%)")
    if role_dist:
        top = sorted(role_dist.items(), key=lambda item: (-item[1], item[0]))[:5]
        print("  roles: " + ", ".join(f"{role}={count}" for role, count in top))
    for key, metric in metrics_output.items():
        print(f"  metric {key}: total={metric['total']} entries={metric['entries']}")
PY
  python3 "$ledger_tmp" "$BASE_DIR" "$LEDGER_DIR" "$ledger_action" "$ledger_extra" "$RECEIPT_DIR"
  rm -f "$ledger_tmp"
}

self_test() {
  local test_ledger_dir
  test_ledger_dir="$(mktemp -d)"
  local old_ledger_dir="${QUALITY_LEDGER_DIR:-}"
  local old_receipt_dir="${QUALITY_LEDGER_RECEIPT_DIR:-}"
  export QUALITY_LEDGER_DIR="$test_ledger_dir"
  export QUALITY_LEDGER_RECEIPT_DIR="$test_ledger_dir/receipts"
  mkdir -p "$QUALITY_LEDGER_RECEIPT_DIR"
  printf '%s\n' '{"run":"a1","status":"completed"}' > "$QUALITY_LEDGER_RECEIPT_DIR/a1.json"

  printf '%s\n' '{"id":"t1","date":"2026-08-01","routing":{"role":"frontend-engineer","tier":"T2","verified":true},"qa":{"status":"GO","issues":0,"review":"subagent run a1","review_verified":true,"review_ref":"a1.json"},"metrics":{"input_tokens":1000,"cycle_seconds":30}}' | bash "$0" --add >/dev/null
  printf '%s\n' '{"id":"t2","date":"2026-08-02","routing":{"role":"contract-coordinator","tier":"T1","verified":true},"qa":{"status":"NO-GO","issues":2}}' | bash "$0" --add >/dev/null
  printf '%s\n' '{"id":"t3","date":"2026-08-03","routing":{"role":"change-coordinator","tier":"T2","verified":false,"expected_role":"backend-engineer"},"qa":{"status":"PARTIAL","issues":1}}' | bash "$0" --add >/dev/null

  local summary_output routes_output
  summary_output="$(bash "$0" --summary)"
  echo "$summary_output" | grep -q "3 entries" || { echo "FAIL: entry count" >&2; return 1; }
  echo "$summary_output" | grep -q "GO rate: 33.3%" || { echo "FAIL: GO rate" >&2; return 1; }
  echo "$summary_output" | grep -q "route verified: 2/3 (66.7%)" || { echo "FAIL: verify rate" >&2; return 1; }
  routes_output="$(bash "$0" --routes)"
  echo "$routes_output" | grep -q "1 unverified" || { echo "FAIL: routes count" >&2; return 1; }

  if printf '%s\n' '{"id":"bad-tier","routing":{"role":"frontend-engineer","tier":"INVALID"},"qa":{"status":"GO","issues":0}}' | bash "$0" --add >/dev/null 2>&1; then
    echo "FAIL: invalid tier accepted" >&2
    return 1
  fi
  if printf '%s\n' '{"id":"bad-issues","routing":{"role":"frontend-engineer"},"qa":{"status":"GO","issues":"abc"}}' | bash "$0" --add >/dev/null 2>&1; then
    echo "FAIL: invalid issues accepted" >&2
    return 1
  fi
  if printf '%s\n' '{"id":"t1","routing":{"role":"frontend-engineer"},"qa":{"status":"GO","issues":0}}' | bash "$0" --add >/dev/null 2>&1; then
    echo "FAIL: duplicate id accepted" >&2
    return 1
  fi
  if printf '%s\n' '{"id":"missing-receipt","routing":{"role":"frontend-engineer"},"qa":{"status":"GO","issues":0,"review":"subagent","review_verified":true,"review_ref":"missing.json"}}' | bash "$0" --add >/dev/null 2>&1; then
    echo "FAIL: missing verified receipt accepted" >&2
    return 1
  fi

  local corrupt_ledger_dir="$test_ledger_dir-corrupt"
  mkdir -p "$corrupt_ledger_dir"
  printf '%s\n' '{not-json}' > "$corrupt_ledger_dir/2026-08.jsonl"
  if env QUALITY_LEDGER_DIR="$corrupt_ledger_dir" bash "$0" --summary >/dev/null 2>&1; then
    echo "FAIL: corrupt existing ledger was silently ignored" >&2
    return 1
  fi
  rm -rf "$corrupt_ledger_dir"

  export QUALITY_LEDGER_DIR="$old_ledger_dir"
  export QUALITY_LEDGER_RECEIPT_DIR="$old_receipt_dir"
  rm -rf "$test_ledger_dir"
  echo "quality-ledger: self-test passed"
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
    self_test
    ;;
  *)
    echo "Usage: quality-ledger.sh [--add|--summary [--json]|--routes|--self-test]" >&2
    exit 64
    ;;
esac
