---
role_id: docs-governor
tier: L1
knowledge_status: current
captured_on: 2026-08-13
repository_baseline: 7a71822
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Docs Governor

> Derived knowledge snapshot. Replace the placeholder bullets below with
> compact, current facts for this role, then set `knowledge_status`,
> `captured_on`, and `repository_baseline`. Keep everything within the
> role's routine context limit in `references/role-catalog.md`.

## Current Knowledge

- This repository is the distributable role-governance skill, not a host product repository.
- `doc-ownership.yaml` self-governs the skill implementation; host projects copy and adapt the template manifest.
- Matcher text mode is a compatibility candidate generator; JSON request-envelope mode is the precise routing interface.
- Doc-sync auto-detects an in-repository install and explicitly reports a global-only installation as unwired.

## Source Pointers

- `SKILL.md`
- `references/role-matcher.md`
- `scripts/select-role.sh`
- `scripts/check-doc-sync.sh`
- `scripts/doctor.sh`
- `doc-ownership.yaml`

## Known Drift And Unknowns

- Host-specific commit-hook registration remains tool-specific; `doctor.sh` reports only a detectable configuration hint.
- Production benefit remains unverified until a host project records comparative cost and outcome metrics.

## Update Triggers

- Role catalog, matcher protocol, install layout, manifest schema, hook behavior, or evidence-claim semantics change.

## Recent Deltas

- 2026-08-13: repository self-wiring, structured matcher input, strict ledger validation, installation doctor, and CI fixtures added; no production verification claimed.
