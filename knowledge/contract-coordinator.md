---
role_id: contract-coordinator
tier: L2
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Contract Coordinator

## Current Knowledge

- T1 hard signals route to contract-coordinator: public API, shared type/state, schema, auth, billing, privacy, identity, or multi-end contract change. These always override T2 request shape, even for small diffs.
- Text-mode failsafe: a protected-domain term (auth, billing, payment, privacy, identity, schema, shared contract) whose action verb the matcher does not recognize routes to contract-coordinator at medium confidence, unless the request is docs-only, presentation-only, diagnosis-only, or design-only. Envelope mode bypasses this — its boolean impact fields carry the semantic answer directly.
- L2 ordering for contract work: canonical contract and owner → migration/backend → consumers → cross-side tests → docs → authorized rollout. Contract and skeleton decisions must be settled before dependent implementation.
- Independent `quality-engineer` subagent review is mandatory after L2 mutations to product-code, public-contract, persistence, identity, billing, privacy, or runtime-configuration. The mutation owner cannot self-certify.
- In this repository, the "contracts" are the governance interfaces themselves: JSONL ledger schema, doc-ownership YAML format, snapshot frontmatter, matcher envelope JSON, and role-catalog table structure.
- Context depth C1-C3 across all contract consumers; relevant C4 rollout/rollback. Required return: canonical contract, consumer packets, migration order, cross-side verification.

## Source Pointers

- `references/role-catalog.md` (contract-coordinator row)
- `references/role-matcher.md` (T1 hard signals, text-mode failsafe)
- `workflows/requirement-triage.md` (contract ordering, L2 packet contract)
- `rules/role-boundaries.md` (independent QA requirement, subagent execution)
- `scripts/select-role.sh` (T1 contract/auth/billing/privacy triggers)

## Known Drift And Unknowns

- No formal backward-compatibility test exists for the governance contracts (ledger schema, ownership YAML, snapshot frontmatter); breaking changes are caught only by the self-tests.
- `UPGRADING.md` documents the merge procedure for host-context files but no automated migration tool exists.

## Update Triggers

- T1 hard signal additions or priority changes for contract-domain routing.
- Changes to governance interface schemas (ledger, ownership, snapshot, matcher envelope).
- L2 ordering or independent-review requirements changes in `rules/role-boundaries.md`.
- Text-mode failsafe logic changes in `scripts/select-role.sh`.

## Recent Deltas

- 2026-08-16: initial bootstrap — snapshot populated from T1 contract-domain routing signals, L2 ordering protocol, independent-QA requirement, and governance interface contracts.
