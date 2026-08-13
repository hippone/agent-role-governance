#!/usr/bin/env bash
# doctor.sh — report whether role-governance is actually wired into the active
# repository. Read-only by default. --strict exits non-zero when hard wiring is
# incomplete; --json emits machine-readable output.

set -euo pipefail

DOCTOR_JSON=0
DOCTOR_STRICT=0
for doctor_arg in "$@"; do
  case "$doctor_arg" in
    --json) DOCTOR_JSON=1 ;;
    --strict) DOCTOR_STRICT=1 ;;
    *)
      echo "Usage: doctor.sh [--json] [--strict]" >&2
      exit 64
      ;;
  esac
done

DOCTOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DOCTOR_SKILL_DIR="$(cd "$DOCTOR_SCRIPT_DIR/.." && pwd -P)"
DOCTOR_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [ -z "$DOCTOR_ROOT" ]; then
  if [ "$DOCTOR_JSON" -eq 1 ]; then
    printf '%s\n' '{"status":"not-ready","repository":false,"installation_mode":"unknown","problems":["not inside a git repository"]}'
  else
    echo "role-governance doctor: NOT READY"
    echo "  repository: missing"
  fi
  [ "$DOCTOR_STRICT" -eq 0 ] || exit 1
  exit 0
fi
DOCTOR_ROOT="$(cd "$DOCTOR_ROOT" && pwd -P)"

if [ -n "${ROLE_GOVERNANCE_DIR:-}" ]; then
  DOCTOR_BASE_DIR="${ROLE_GOVERNANCE_DIR%/}"
  case "$DOCTOR_BASE_DIR" in
    "$DOCTOR_ROOT") DOCTOR_BASE_DIR="." ;;
    "$DOCTOR_ROOT"/*) DOCTOR_BASE_DIR="${DOCTOR_BASE_DIR#"$DOCTOR_ROOT"/}" ;;
  esac
elif [ "$DOCTOR_SKILL_DIR" = "$DOCTOR_ROOT" ]; then
  DOCTOR_BASE_DIR="."
elif [[ "$DOCTOR_SKILL_DIR" == "$DOCTOR_ROOT"/* ]]; then
  DOCTOR_BASE_DIR="${DOCTOR_SKILL_DIR#"$DOCTOR_ROOT"/}"
else
  DOCTOR_BASE_DIR=""
fi

if [ -n "$DOCTOR_BASE_DIR" ] && [[ "$DOCTOR_BASE_DIR" != /* ]]; then
  DOCTOR_MODE="in-repository"
  DOCTOR_BASE_PATH="$DOCTOR_ROOT/$DOCTOR_BASE_DIR"
else
  DOCTOR_MODE="global-only"
  DOCTOR_BASE_PATH="$DOCTOR_SKILL_DIR"
fi

DOCTOR_MANIFEST=0
DOCTOR_CATALOG=0
DOCTOR_KNOWLEDGE=0
DOCTOR_LEDGER=0
DOCTOR_HOOK_HINT=0
DOCTOR_STALE_SNAPSHOTS=0
DOCTOR_CURRENT_SNAPSHOTS=0
[ -f "$DOCTOR_BASE_PATH/doc-ownership.yaml" ] && DOCTOR_MANIFEST=1
[ -f "$DOCTOR_BASE_PATH/references/role-catalog.md" ] && DOCTOR_CATALOG=1
[ -d "$DOCTOR_BASE_PATH/knowledge" ] && DOCTOR_KNOWLEDGE=1
[ -d "$DOCTOR_BASE_PATH/ledger" ] && DOCTOR_LEDGER=1
if [ "$DOCTOR_KNOWLEDGE" -eq 1 ]; then
  DOCTOR_STALE_SNAPSHOTS="$( (rg -l '^knowledge_status: stale$' "$DOCTOR_BASE_PATH/knowledge"/*.md 2>/dev/null || true) | wc -l | tr -d ' ')"
  DOCTOR_CURRENT_SNAPSHOTS="$( (rg -l '^knowledge_status: current$' "$DOCTOR_BASE_PATH/knowledge"/*.md 2>/dev/null || true) | wc -l | tr -d ' ')"
fi

if rg -l "check-doc-sync\.sh.*--hook-commit|--hook-commit.*check-doc-sync\.sh" \
  "$DOCTOR_ROOT/.claude" "$DOCTOR_ROOT/.codex" "$DOCTOR_ROOT/.cursor" \
  "$DOCTOR_ROOT/AGENTS.md" "$DOCTOR_ROOT/CLAUDE.md" >/dev/null 2>&1; then
  DOCTOR_HOOK_HINT=1
fi

DOCTOR_STATUS="ready"
DOCTOR_PROBLEMS=()
if [ "$DOCTOR_MODE" != "in-repository" ]; then
  DOCTOR_STATUS="not-ready"
  DOCTOR_PROBLEMS+=("skill is outside the repository")
fi
if [ "$DOCTOR_MANIFEST" -ne 1 ]; then
  DOCTOR_STATUS="not-ready"
  DOCTOR_PROBLEMS+=("doc-ownership.yaml is missing")
fi
if [ "$DOCTOR_CATALOG" -ne 1 ] || [ "$DOCTOR_KNOWLEDGE" -ne 1 ]; then
  DOCTOR_STATUS="not-ready"
  DOCTOR_PROBLEMS+=("catalog or knowledge directory is missing")
fi
if [ "$DOCTOR_HOOK_HINT" -ne 1 ]; then
  DOCTOR_PROBLEMS+=("commit-hook wiring was not detected; verify host configuration manually")
fi
if [ "$DOCTOR_STALE_SNAPSHOTS" -gt 0 ]; then
  DOCTOR_PROBLEMS+=("$DOCTOR_STALE_SNAPSHOTS knowledge snapshot(s) are stale or uninitialized")
fi
if [ "$DOCTOR_STATUS" = "ready" ] && [ "${#DOCTOR_PROBLEMS[@]}" -gt 0 ]; then
  DOCTOR_STATUS="ready-with-warnings"
fi

if [ "$DOCTOR_JSON" -eq 1 ]; then
  python3 - "$DOCTOR_STATUS" "$DOCTOR_ROOT" "$DOCTOR_MODE" "$DOCTOR_BASE_DIR" \
    "$DOCTOR_MANIFEST" "$DOCTOR_CATALOG" "$DOCTOR_KNOWLEDGE" "$DOCTOR_LEDGER" \
    "$DOCTOR_HOOK_HINT" "$DOCTOR_STALE_SNAPSHOTS" "$DOCTOR_CURRENT_SNAPSHOTS" \
    "${DOCTOR_PROBLEMS[@]}" <<'PY'
import json
import sys

print(json.dumps({
    "status": sys.argv[1],
    "repository": sys.argv[2],
    "installation_mode": sys.argv[3],
    "base_dir": sys.argv[4] or None,
    "manifest": sys.argv[5] == "1",
    "catalog": sys.argv[6] == "1",
    "knowledge": sys.argv[7] == "1",
    "ledger": sys.argv[8] == "1",
    "hook_hint_detected": sys.argv[9] == "1",
    "stale_snapshots": int(sys.argv[10]),
    "current_snapshots": int(sys.argv[11]),
    "problems": sys.argv[12:],
}, ensure_ascii=False, indent=2))
PY
else
  echo "role-governance doctor: $(printf '%s' "$DOCTOR_STATUS" | tr '[:lower:]' '[:upper:]')"
  echo "  repository: $DOCTOR_ROOT"
  echo "  installation: $DOCTOR_MODE"
  echo "  base dir: ${DOCTOR_BASE_DIR:-outside repository}"
  echo "  manifest: $([ "$DOCTOR_MANIFEST" -eq 1 ] && echo present || echo missing)"
  echo "  catalog/knowledge: $([ "$DOCTOR_CATALOG" -eq 1 ] && [ "$DOCTOR_KNOWLEDGE" -eq 1 ] && echo present || echo missing)"
  echo "  ledger: $([ "$DOCTOR_LEDGER" -eq 1 ] && echo present || echo no-data)"
  echo "  hook hint: $([ "$DOCTOR_HOOK_HINT" -eq 1 ] && echo detected || echo not-detected)"
  echo "  snapshots: current=$DOCTOR_CURRENT_SNAPSHOTS stale=$DOCTOR_STALE_SNAPSHOTS"
  for doctor_problem in "${DOCTOR_PROBLEMS[@]}"; do
    echo "  problem: $doctor_problem"
  done
fi

if [ "$DOCTOR_STRICT" -eq 1 ] && [ "$DOCTOR_STATUS" = "not-ready" ]; then
  exit 1
fi
