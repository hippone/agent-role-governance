---
role_id: experience-designer
tier: L1
knowledge_status: current
captured_on: 2026-08-15
repository_baseline: 40c71f0
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Experience Designer

## Current Knowledge

- Copy/UI classification is judged from the user's perspective, never an
  engineering-internal one: a change is copy/UI work when the end user can
  perceive it (visible copy, headings, labels, button text, colors, fonts,
  icons). Status/state-feedback terms ("提示当前状态" style: empty state,
  error message, toast, tooltip, confirmation, 状态提示, 错误提示, 提示语,
  弹窗文字) are forbidden as copy/UI signals — dynamic state feedback never
  routes a request into the copy/UI lane on its own. Engineering-internal
  artifacts users never see (comments, internal naming, CSS
  variable/design-token definitions, component-internal structure) are not
  copy/UI work on their own.
- Matcher keyword hints (`scripts/select-role.sh` presentation_only) keep
  copy/UI work from being mis-escalated by protected-domain words; the
  operative judgment is user-visible impact, never styling internals.

## Source Pointers

- `scripts/select-role.sh` (presentation_only block and T2 frontend shape)
- `references/role-matcher.md` (T2 table and copy/UI classification note)
- `workflows/requirement-triage.md` (routing table and copy/UI note)

## Known Drift And Unknowns

- No known drift; matcher keyword coverage for new copy/UI surface terms is
  verified only by the self-test table.

## Update Triggers

- Matcher keyword or routing-table changes that affect copy/UI classification.
- New user-visible surface types (e.g. new component patterns) not yet in the
  matcher vocabulary.

## Recent Deltas

- 2026-08-15: user-perspective principle added to copy/UI classification;
  status/state-feedback terms (empty state, error message, toast, tooltip,
  confirmation, 提示语, 错误提示, 状态提示) forbidden as copy/UI signals
  (baseline 40c71f0, uncommitted).
