---
role_id: contract-architect
tier: L1
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Contract Architect

## Current Knowledge

- This repository is the role-governance skill itself (not a host product). The single owner `governance-skill` (kind: governance, docs_required: false) covers all paths; contract-architect is listed in its `knowledge_roles`. There is no `kind: contract` owner in this repo -- the template example (`templates/doc-ownership.example.yaml`) shows a `public-api` contract owner as a model for host projects.
- contract-architect routes as L1 only for bounded design-only output with no consumer mutations. The matcher (`scripts/select-role.sh`) activates it via T2 shape ("bounded contract design-only signal") or when `request_type=contract` and `design_only=true`. Any contract change with multiple consumers, shared state, schema, auth, billing, or privacy impact escalates to `contract-coordinator` L2 at T1.
- The L1 Direct Gate (`rules/role-boundaries.md`) blocks L1 when the work introduces or changes a public contract, shared state machine, persistence schema, identity rule, billing rule, privacy boundary, or cross-surface route -- even when the diff is small. A small diff is explicitly not an automatic L1 qualifier for contract work.
- Routine context limit is C1-C3 with C4 rollout constraints only. C2 is the contract-architect's primary working depth: static owner IDs, state transitions, API/DTO/schema/persistence effects, mutation paths, and cross-surface dependencies. C3 adds relevant files, comparable patterns, tests, and implementation risks.
- Required return for contract-architect: contract decision, affected owner IDs, migration/compatibility boundary, and tests. The role must resolve affected owners through `doc-ownership.yaml` (never infer from the role catalog) and report them in the return.
- The `templates/doc-ownership.example.yaml` is the canonical reference for how host projects should declare `kind: contract` owners with `contract-architect` in `knowledge_roles`, code globs for API/types directories, and owned contract docs. This template is the contract-architect's primary deliverable-shape reference in this repo.
- The deterministic commit gate (`scripts/check-doc-sync.sh`) enforces that every triggered owner has at least one eligible knowledge snapshot updated. The `[knowledge-na]` waiver never applies to contract or governance owners -- only single-feature formatting-only changes qualify.

## Source Pointers

- `references/role-catalog.md (contract-architect row, escalation map, routing notes)`
- `references/role-matcher.md (T1 hard signals, T2 bounded-design shape, priority rules)`
- `rules/role-boundaries.md (L1 Direct Gate conditions, C2 contract depth, R0-R3 risk routing)`
- `workflows/requirement-triage.md (routing table, L2 packet contract, contract ordering)`
- `scripts/select-role.sh (design_only detection, contract-architect candidate logic, self-test cases)`
- `scripts/check-doc-sync.sh (commit gate, knowledge-na exclusions for contract/governance)`
- `doc-ownership.yaml (governance-skill owner, knowledge_roles list)`
- `templates/doc-ownership.example.yaml (kind: contract owner pattern, public-api example)`

## Known Drift And Unknowns

- No contract-kind owner exists in this repository's own `doc-ownership.yaml`; the contract-architect role is exercised here only through governance-skill ownership, not through actual API/DTO/schema design work. Real contract design patterns are documented only in the template example.
- The matcher self-test table has only two contract-architect cases (text: 'design the dto shape, no consumers yet'; envelope: contract+design_only). Coverage of edge cases (e.g., contract request without design_only, ambiguous consumer scope) is tested only via coordinator escalation paths.
- Production benefit of the L1 bounded-design lane vs always escalating to contract-coordinator is unverified -- no host-project quality-ledger data exists yet.

## Update Triggers

- Changes to T1 hard signals or T2 contract-architect shape in `references/role-matcher.md` or `scripts/select-role.sh`.
- Changes to the L1 Direct Gate conditions in `rules/role-boundaries.md` that affect contract work eligibility.
- New `kind: contract` owner added to `doc-ownership.yaml` (would give contract-architect actual in-repo scope).
- Changes to the contract-architect row in `references/role-catalog.md` (routine context limit, required return, decision boundaries).
- Changes to `templates/doc-ownership.example.yaml` contract-owner patterns or `knowledge_roles` assignments.

## Recent Deltas

- 2026-08-16: initial bootstrap from canonical sources at baseline ba715e3; no prior snapshot content existed.
