---
role_id: change-coordinator
tier: L2
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Change Coordinator

## Current Knowledge

- T1 hard signals route to change-coordinator: ambiguous scope, second surface, more than one functional role required, unmapped surface, and the catch-all when no tier produces a confident result. Also triggered when T2 produces two or more distinct candidates.
- L2 coordination duties (`rules/role-boundaries.md`): preserve user goal, identify existing route and owner IDs, separate facts/decisions/assumptions/proposals, create bounded L1 packets, pass minimum context per packet, order dependencies (product→interaction→contract→implementation→QA→docs), reconcile contradictions.
- L2 subagent execution requirement: at least one real subagent per L2 task. Same-agent role-switching is `degraded-same-agent`, accepted only when runtime genuinely lacks subagent capability. Real-subagent dispatch is the default per 2026 tool landscape.
- For L2 mutations (product-code, public-contract, persistence, identity, billing, privacy, runtime-configuration), a separate `quality-engineer` subagent must review after implementation. This satisfies the one-subagent minimum.
- Task routing configuration, role definitions, route IDs/order, or activation semantics changes must use change-coordinator; they are not ordinary docs maintenance.
- Risk routing (R0-R3) selects subagent model/effort by packet risk, not role title. Receipts record requested, fallback, effective, and reroute fields.
- Context depth C0-C3 across affected boundaries; C4 only for rollout requirements. Each L1 packet gets minimum sufficient context, not the full conversation.

## Source Pointers

- `rules/role-boundaries.md` (L2 duties, subagent requirement, risk routing)
- `references/role-catalog.md` (change-coordinator row)
- `references/role-matcher.md` (T1 hard signals, T2 conflict rules)
- `workflows/requirement-triage.md` (L2 packet contract, ordering)
- `scripts/select-role.sh` (T1 triggers)

## Known Drift And Unknowns

- Quality ledger has only 1 entry (change-coordinator, PARTIAL); not enough data to validate routing accuracy or process effectiveness.
- No automated mechanism to track L2→L1 decomposition quality or packet dependency satisfaction.

## Update Triggers

- L2 coordination duties or subagent requirement changes in `rules/role-boundaries.md`.
- T1 hard signal additions or priority changes in `references/role-matcher.md`.
- L2 packet contract format changes in `workflows/requirement-triage.md`.
- Risk routing table changes (R0-R3 signals or preferred routes).

## Recent Deltas

- 2026-08-16: initial bootstrap — snapshot populated from L2 coordination rules, subagent requirements, T1 routing signals, packet contract format, and risk routing protocol.
