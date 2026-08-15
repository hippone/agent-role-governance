#!/usr/bin/env bash
# benefit-report.sh — collect governance metrics and generate a visual HTML
# dashboard that validates the skill's real-world benefit.
#
# Usage:
#   bash scripts/benefit-report.sh [output.html]
#   open benefit-report.html

set -euo pipefail

REPORT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPORT_SKILL_DIR="$(cd "$REPORT_SCRIPT_DIR/.." && pwd -P)"
OUTPUT="${1:-$REPORT_SKILL_DIR/benefit-report.html}"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# --- Data Collection ---

collect_doctor() {
  bash "$REPORT_SKILL_DIR/scripts/doctor.sh" --json 2>/dev/null || echo '{"status":"error","problems":["doctor.sh failed"]}'
}

collect_ledger() {
  bash "$REPORT_SKILL_DIR/scripts/quality-ledger.sh" --summary --json 2>/dev/null || echo '{"total":0,"qa":{},"go_rate":0,"issues":0}'
}

collect_snapshots() {
  bash "$REPORT_SKILL_DIR/scripts/role-snapshot-audit.sh" --json 2>/dev/null || echo '[]'
}

collect_matcher() {
  local out
  out="$(bash "$REPORT_SKILL_DIR/scripts/select-role.sh" --self-test 2>&1)" || true
  # Extract "N cases" from output like "select-role: self-test passed (50 cases)"
  local cases
  cases="$(echo "$out" | grep -oE '[0-9]+ cases' | head -1 || echo "0 cases")"
  local passed="false"
  echo "$out" | grep -q "passed" && passed="true"
  printf '{"passed":%s,"cases":"%s","output":"%s"}' "$passed" "$cases" "$(echo "$out" | tr '"' "'" | tr '\n' ' ')"
}

collect_docsync() {
  local out exitcode=0
  out="$(bash "$REPORT_SKILL_DIR/scripts/check-doc-sync.sh" --dirty 2>&1)" || exitcode=$?
  local clean="false"
  echo "$out" | grep -q "clean" && clean="true"
  printf '{"clean":%s,"exit_code":%d,"output":"%s"}' "$clean" "$exitcode" "$(echo "$out" | tr '"' "'" | tr '\n' ' ')"
}

collect_tests() {
  local out exitcode=0
  out="$(bash "$REPORT_SKILL_DIR/tests/run.sh" 2>&1)" || exitcode=$?
  local passed="false"
  echo "$out" | grep -q "all tests passed" && passed="true"
  printf '{"passed":%s,"exit_code":%d,"output":"%s"}' "$passed" "$exitcode" "$(echo "$out" | tr '"' "'" | tr '\n' ' ')"
}

collect_external_facts() {
  local out
  out="$(bash "$REPORT_SKILL_DIR/scripts/check-external-facts.sh" "$REPORT_SKILL_DIR" 2>&1)" || true
  local markers all_fresh="false" stale
  markers="$(echo "$out" | grep -oE 'Markers checked: [0-9]+' | grep -oE '[0-9]+' || true)"
  [ -z "$markers" ] && markers="0"
  echo "$out" | grep -q "within the freshness window" && all_fresh="true"
  stale="$(echo "$out" | grep -c "STALE" || true)"
  [ -z "$stale" ] && stale="0"
  printf '{"markers":%s,"stale":%s,"all_fresh":%s}' "$markers" "$stale" "$all_fresh"
}

collect_git_history() {
  cd "$REPORT_SKILL_DIR"
  git log --format='{"date":"%cs","subject":"%s"}' --all 2>/dev/null | python3 -c "
import sys, json
commits = []
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        commits.append(json.loads(line))
    except: pass
print(json.dumps(commits))
" 2>/dev/null || echo '[]'
}

collect_git_numstat() {
  cd "$REPORT_SKILL_DIR"
  git log --numstat --format='COMMIT|%cs|%s' --all 2>/dev/null | python3 -c "
import sys, json
commits = []
current = None
for line in sys.stdin:
    line = line.rstrip()
    if line.startswith('COMMIT|'):
        parts = line.split('|', 2)
        current = {'date': parts[1], 'subject': parts[2], 'added': 0, 'deleted': 0, 'files': 0}
        commits.append(current)
    elif current and line.strip():
        parts = line.split('\t')
        if len(parts) == 3:
            a = int(parts[0]) if parts[0] != '-' else 0
            d = int(parts[1]) if parts[1] != '-' else 0
            current['added'] += a
            current['deleted'] += d
            current['files'] += 1
print(json.dumps(commits))
" 2>/dev/null || echo '[]'
}

collect_ownership() {
  python3 -c "
import json, sys
owners = []
current = None
list_key = None
in_owners = False
with open('$REPORT_SKILL_DIR/doc-ownership.yaml') as f:
    for raw in f:
        if not raw.strip() or raw.lstrip().startswith('#'): continue
        stripped = raw.strip()
        if not raw.startswith(' '):
            in_owners = stripped == 'owners:'
            continue
        if not in_owners: continue
        if raw.startswith('  - '):
            current = {}
            owners.append(current)
            list_key = None
            item = stripped[2:].strip()
            if ':' in item:
                k, v = item.split(':', 1)
                current[k.strip()] = v.strip()
            continue
        if current is None: continue
        if raw.startswith('      - '):
            if list_key:
                current.setdefault(list_key, []).append(stripped[2:].strip())
            continue
        if raw.startswith('    ') and ':' in stripped:
            k, v = stripped.split(':', 1)
            k, v = k.strip(), v.strip()
            if v == '':
                list_key = k
                current.setdefault(k, [])
            else:
                current[k] = v
                list_key = None
print(json.dumps(owners))
" 2>/dev/null || echo '[]'
}

echo "Collecting governance metrics..."

DOCTOR_JSON="$(collect_doctor)"
LEDGER_JSON="$(collect_ledger)"
SNAPSHOT_JSON="$(collect_snapshots)"
MATCHER_JSON="$(collect_matcher)"
DOCSYNC_JSON="$(collect_docsync)"
TESTS_JSON="$(collect_tests)"
FACTS_JSON="$(collect_external_facts)"
GIT_HISTORY="$(collect_git_history)"
GIT_NUMSTAT="$(collect_git_numstat)"
OWNERSHIP_JSON="$(collect_ownership)"

echo "Generating dashboard..."


# --- Generate HTML dashboard ---

python3 "$REPORT_SKILL_DIR/scripts/_gen_html.py" \
  "$OUTPUT" "$TIMESTAMP" \
  "$DOCTOR_JSON" "$LEDGER_JSON" "$SNAPSHOT_JSON" \
  "$MATCHER_JSON" "$DOCSYNC_JSON" "$TESTS_JSON" "$FACTS_JSON" \
  "$GIT_HISTORY" "$GIT_NUMSTAT" "$OWNERSHIP_JSON"

echo "benefit-report: dashboard written to $OUTPUT"
