#!/usr/bin/env bash
# select-role.sh — deterministic role selection for a request description.
# Implements the matching tiers in references/role-matcher.md.
#
# Usage:
#   echo "change the public API schema" | bash scripts/select-role.sh
#   bash scripts/select-role.sh --json < request.txt
#   bash scripts/select-role.sh --self-test
#
# The matcher is keyword/signal based on purpose: it narrows candidates and
# records confidence so the coordinator applies judgment; it never decides
# alone. Output is the same fields as the role-matcher.md output contract.

set -euo pipefail

self_test() {
  local failures=0
  local cases=(
    "change the public api schema and auth|contract-coordinator"
    "add a billing rule|contract-coordinator"
    "user data is lost in production|incident-coordinator"
    "production incident on payments|incident-coordinator"
    "bug reproduces only intermittently|incident-coordinator"
    "ambiguous feature across dashboard and settings|change-coordinator"
    "new requirement: define acceptance criteria for the onboarding flow|product-analyst"
    "spec wording and non-goals for the export page|product-analyst"
    "design the checkout interaction copy and error states|experience-designer"
    "tweak the settings page copy and add a component test|frontend-engineer"
    "implement the api client on the frontend|frontend-engineer"
    "update the backend service persistence logic|backend-engineer"
    "review the diff for evidence before we ship|quality-engineer"
    "verify the regression test matrix|quality-engineer"
    "design the dto shape, no consumers yet|contract-architect"
    "fix a reproducible bug in the dashboard owned by web-app|frontend-engineer"
    "fix a reproducible bug in the api client|backend-engineer"
    "rewrite the docs wording only|docs-governor"
    "deploy the authorized release|release-engineer"
  )
  for case in "${cases[@]}"; do
    local text="${case%%|*}"
    local expected="${case##*|}"
    local got
    got="$(printf '%s' "$text" | run_matcher | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["role"])')"
    if [ "$got" != "$expected" ]; then
      echo "FAIL: expected $expected got $got | $text" >&2
      failures=$((failures + 1))
    fi
  done
  if [ "$failures" -eq 0 ]; then
    echo "select-role: self-test passed ($((${#cases[@]})) cases)"
  else
    echo "select-role: self-test failed ($failures cases)" >&2
    return 1
  fi
}

run_matcher() {
  local text="${1:-}"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<'PY'
import json
import re
import sys

text = (sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else sys.stdin.read()).lower()

def has(*patterns):
    return any(re.search(p, text) for p in patterns)

signals = []

# T1 hard signals; incident signals outrank contract signals.
if has(r"data loss", r"data-loss", r"data.{0,20}lost", r"production incident", r"production fault", r"outage", r"unstable reproduction", r"intermittent"):
    signals.append(("T1", "incident-coordinator", "high", "production or unstable-root-cause signal"))
if has(r"public api", r"api schema", r"shared type", r"state machine", r"\bdtos?\b", r"contract", r"\bschema\b") and not has(r"no consumers", r"design[- ]only"):
    signals.append(("T1", "contract-coordinator", "high", "public/shared contract signal"))
if has(r"authentication|authorization|\bauth\b|billing|payment|refund|privacy|identity|entitlement"):
    signals.append(("T1", "contract-coordinator", "high", "auth/billing/privacy/identity signal"))
if has(r"ambiguous", r"second surface", r"multi[- ]surface", r"cross[- ]surface", r"multiple roles", r"multi[- ]role"):
    signals.append(("T1", "change-coordinator", "high", "ambiguity or cross-surface signal"))
if has(r"docs only", r"wording only", r"index maintenance", r"references maintenance", r"rewrite the docs", r"docs wording"):
    signals.append(("T1", "docs-governor", "high", "docs-only signal"))
if has(r"release", r"deploy", r"rollout"):
    if has(r"authorized"):
        signals.append(("T1", "release-engineer", "high", "authorized release signal"))
    else:
        signals.append(("T1", "release-engineer", "low", "release signal without explicit authorization"))
if has(r"unmapped surface", r"new surface"):
    signals.append(("T1", "change-coordinator", "high", "unmapped surface signal"))

# T2 request shape (only if no T1 result chosen yet)
if not signals:
    if has(r"requirement", r"acceptance criteria", r"non[- ]goal", r"spec wording", r"scope of"):
        signals.append(("T2", "product-analyst", "high", "requirement-shape signal"))
    if has(r"design the .*interaction", r"interaction copy", r"error states", r"ux", r"design-only"):
        signals.append(("T2", "experience-designer", "high", "interaction-design signal"))
    if has(r"frontend", r"page", r"component", r"\bui\b", r"client state", r"component test"):
        signals.append(("T2", "frontend-engineer", "medium", "frontend-shape signal"))
    if has(r"backend", r"service", r"persistence", r"repository", r"api client.*server"):
        signals.append(("T2", "backend-engineer", "medium", "backend-shape signal"))
    if has(r"verify", r"review.*evidence", r"regression", r"test matrix", r"reproduce", r"go/no[- ]go", r"diagnos"):
        signals.append(("T2", "quality-engineer", "medium", "verification-only signal"))
    if has(r"design the dto", r"design the schema", r"contract design", r"no consumers"):
        signals.append(("T2", "contract-architect", "medium", "bounded design-only signal"))
    if has(r"reproducible bug") and has(r"dashboard"):
        signals.append(("T2", "frontend-engineer", "medium", "reproducible single-owner bug"))
    if has(r"reproducible bug") and has(r"api"):
        signals.append(("T2", "backend-engineer", "medium", "reproducible single-owner bug"))

if not signals:
    result = {
        "role": "change-coordinator",
        "tier": "T2",
        "confidence": "low",
        "reason": "no signal matched; default to coordinator and ask the user",
    }
else:
    tier_order = {"T1": 0, "T2": 1}
    signals.sort(key=lambda s: (tier_order[s[0]], 0 if s[2] == "high" else 1))
    chosen = signals[0]
    result = {
        "role": chosen[1],
        "tier": chosen[0],
        "confidence": chosen[2],
        "reason": chosen[3],
        "candidates": [
            {"tier": s[0], "role": s[1], "confidence": s[2], "signal": s[3]}
            for s in signals
        ],
    }

print(json.dumps(result))
PY
  python3 "$tmp" "$text"
  rm -f "$tmp"
}

case "${1:-}" in
  --self-test)
    self_test
    ;;
  --json)
    shift
    run_matcher "$@"
    ;;
  *)
    run_matcher ""
    ;;
esac
