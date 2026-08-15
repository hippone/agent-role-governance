#!/usr/bin/env bash

set -euo pipefail

DOC_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC_FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "$DOC_FIXTURE_ROOT"' EXIT

mkdir -p \
  "$DOC_FIXTURE_ROOT/skills/role-governance/scripts" \
  "$DOC_FIXTURE_ROOT/skills/role-governance/references" \
  "$DOC_FIXTURE_ROOT/skills/role-governance/knowledge" \
  "$DOC_FIXTURE_ROOT/src" \
  "$DOC_FIXTURE_ROOT/docs"

cp "$DOC_TEST_ROOT/scripts/check-doc-sync.sh" \
  "$DOC_FIXTURE_ROOT/skills/role-governance/scripts/check-doc-sync.sh"
cp "$DOC_TEST_ROOT/references/role-catalog.md" \
  "$DOC_FIXTURE_ROOT/skills/role-governance/references/role-catalog.md"
cp "$DOC_TEST_ROOT"/knowledge/*.md \
  "$DOC_FIXTURE_ROOT/skills/role-governance/knowledge/"

cat > "$DOC_FIXTURE_ROOT/skills/role-governance/doc-ownership.yaml" <<'YAML'
unowned_code_roots:
  - src/

owners:
  - id: web-app
    kind: feature
    label: Web application
    knowledge_roles:
      - product-analyst
      - experience-designer
      - contract-architect
      - frontend-engineer
      - backend-engineer
      - quality-engineer
      - release-engineer
      - docs-governor
      - change-coordinator
      - contract-coordinator
      - incident-coordinator
    code:
      - src/**
    docs:
      - docs/architecture.md
YAML

printf '%s\n' 'baseline page' > "$DOC_FIXTURE_ROOT/src/page.ts"
printf '%s\n' '# Architecture' > "$DOC_FIXTURE_ROOT/docs/architecture.md"

git -C "$DOC_FIXTURE_ROOT" init -q
git -C "$DOC_FIXTURE_ROOT" config user.email "role-governance-test@example.invalid"
git -C "$DOC_FIXTURE_ROOT" config user.name "role-governance-test"
git -C "$DOC_FIXTURE_ROOT" add .
git -C "$DOC_FIXTURE_ROOT" commit -qm "fixture baseline"

LOCAL_GATE="$DOC_FIXTURE_ROOT/skills/role-governance/scripts/check-doc-sync.sh"

CLEAN_OUTPUT="$(cd "$DOC_FIXTURE_ROOT" && bash "$LOCAL_GATE" --dirty)"
echo "$CLEAN_OUTPUT" | grep -q "doc-sync: clean" || {
  echo "FAIL: configured clean fixture did not pass" >&2
  exit 1
}

printf '%s\n' 'changed page' >> "$DOC_FIXTURE_ROOT/src/page.ts"
if (cd "$DOC_FIXTURE_ROOT" && bash "$LOCAL_GATE" --dirty >/dev/null 2>&1); then
  echo "FAIL: code-only change passed doc-sync" >&2
  exit 1
fi

cat > "$DOC_FIXTURE_ROOT/skills/role-governance/knowledge/frontend-engineer.md" <<'MARKDOWN'
---
role_id: frontend-engineer
tier: L1
knowledge_status: stale
captured_on: pending
repository_baseline: pending
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Frontend Engineer

## Current Knowledge

- _No captured facts yet. Add compact, current facts this role needs._

## Source Pointers

- _None yet._

## Known Drift And Unknowns

- _None yet._

## Update Triggers

- _None yet._

## Recent Deltas

- _None yet._
MARKDOWN
printf '%s\n' 'Changed behavior.' >> "$DOC_FIXTURE_ROOT/docs/architecture.md"
printf '%s\n' '- 2026-08-13: placeholder-only update.' >> \
  "$DOC_FIXTURE_ROOT/skills/role-governance/knowledge/frontend-engineer.md"
if (cd "$DOC_FIXTURE_ROOT" && bash "$LOCAL_GATE" --dirty >/dev/null 2>&1); then
  echo "FAIL: placeholder knowledge update satisfied doc-sync" >&2
  exit 1
fi

cat > "$DOC_FIXTURE_ROOT/skills/role-governance/knowledge/frontend-engineer.md" <<'MARKDOWN'
---
role_id: frontend-engineer
tier: L1
knowledge_status: current
captured_on: 2026-08-13
repository_baseline: fixture-baseline
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Frontend Engineer

## Current Knowledge

- The fixture page behavior changed with its architecture note.

## Source Pointers

- `src/page.ts`
- `docs/architecture.md`

## Known Drift And Unknowns

- No runtime verification was performed in this fixture.

## Update Triggers

- The fixture page behavior changes.

## Recent Deltas

- 2026-08-13: fixture page and architecture note changed together.
MARKDOWN
PASS_OUTPUT="$(cd "$DOC_FIXTURE_ROOT" && bash "$LOCAL_GATE" --dirty)"
echo "$PASS_OUTPUT" | grep -q "doc-sync: clean" || {
  echo "FAIL: valid docs and knowledge co-change did not pass" >&2
  exit 1
}

GLOBAL_OUTPUT="$(cd "$DOC_FIXTURE_ROOT" && bash "$DOC_TEST_ROOT/scripts/check-doc-sync.sh" --dirty)"
echo "$GLOBAL_OUTPUT" | grep -q "global skill is outside repository" || {
  echo "FAIL: global-only installation was not reported explicitly" >&2
  exit 1
}

echo "doc-sync: integration test passed"
