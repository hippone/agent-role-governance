---
role_id: incident-coordinator
tier: L2
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Incident Coordinator

## Current Knowledge

- T1 hard signals route to incident-coordinator: unstable reproduction, unknown owner, data-loss risk, or production-only failure. These always override T2 request shape.
- L2 ordering for incidents: reproduce/observe → isolate owner or rank hypotheses → bounded fix → regression → authorized release evidence. Must not authorize speculative production mutation or ask fixers to code before owner isolation.
- In this repository, "incidents" are governance-tool failures: a script producing wrong results, doc-sync gate false positives/negatives, matcher misrouting, ledger corruption, or snapshot validation bypass.
- The incident-coordinator's context is relevant sanitized C0-C4. Required return: incident scope, root cause or ranked hypotheses, dispatched fixes, evidence, residual risk.
- Independent `quality-engineer` review is mandatory after fixes that change product code, public contracts, or persistence. The mutation owner cannot self-certify.
- Risk escalation: if a child discovers a higher-risk boundary during investigation, it returns `needs_reroute` with evidence; the coordinator issues a replacement packet instead of silently continuing.

## Source Pointers

- `references/role-catalog.md` (incident-coordinator row)
- `references/role-matcher.md` (T1 hard signals: unknown owner, data-loss, production)
- `workflows/requirement-triage.md` (incident ordering)
- `rules/role-boundaries.md` (L2 subagent requirement, risk reroute)
- `scripts/select-role.sh` (T1 incident triggers)

## Known Drift And Unknowns

- No incident playbook or runbook exists for governance-tool failures specific to this repository.
- No monitoring or alerting mechanism exists for detecting governance-tool failures in host projects.

## Update Triggers

- T1 hard signal additions for incident-domain routing.
- New failure modes discovered in governance scripts.
- Incident ordering or authority limit changes in `rules/role-boundaries.md`.

## Recent Deltas

- 2026-08-16: initial bootstrap — snapshot populated from T1 incident-domain routing signals, L2 incident ordering protocol, and risk escalation mechanism.
