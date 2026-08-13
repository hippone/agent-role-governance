---
name: role-governance
version: "1.0"
description: >
  Govern coding-agent work through functional roles: L1/L2 processing gates,
  C0-C4 context depth, R0-R3 risk-based subagent routing, delegation receipts,
  and per-role knowledge snapshots with a deterministic doc-sync commit gate.
  Activate when the task requires role triage, deciding whether work is
  L1-direct or L2-coordinated, decomposing work into bounded task packets,
  routing subagents by risk, enforcing context disclosure limits, or updating
  role knowledge after a change.
primary: true
---

# role-governance

Role-based governance layer for AI coding agents. Roles are temporary
responsibility lenses, not persistent personas, code owners, or tool-specific
agent types. This skill controls how tasks are handled, how decisions are
scoped, how much context each role may see, and how durable per-role knowledge
is kept in sync with code changes.

## Core Loop

Every non-trivial task:

1. Run `workflows/requirement-triage.md` first. Build the request envelope,
   resolve owners, and apply the L1 Direct Gate. Use
   `references/role-matcher.md` (or `scripts/select-role.sh`) to identify the
   routing role automatically instead of guessing.
2. Read `rules/role-boundaries.md` for gates, authority, context depth, and
   risk routing. Read `references/role-catalog.md` to select a role and its
   routine context limit.
3. The selected role follows `workflows/role-self-maintenance.md`: self-audit
   its snapshot before work, self-fetch from canonical sources during work,
   self-update its snapshot after work. L1: record a compact receipt and
   execute. L2: produce bounded L1 packets and dispatch at least one through a
   real subagent.
4. On change completion, run the deterministic gate
   (`scripts/check-doc-sync.sh`) before closing or committing, sweep for
   expired snapshots (`scripts/role-snapshot-audit.sh`), and append the task's
   quality receipt to the ledger (`scripts/quality-ledger.sh`) so the process
   produces measurable evidence instead of self-claims.

## File Map

| Path | Purpose |
|---|---|
| `rules/role-boundaries.md` | Authority model, L1/L2 gates, C0-C4 context depth, R0-R3 subagent risk routing, knowledge duty, completion boundary |
| `references/role-catalog.md` | 8 L1 + 3 L2 functional roles with decision scope and routine context limits |
| `references/role-matcher.md` | Deterministic role identification: T1 hard signals, T2 request shape, T3 gate recheck |
| `workflows/requirement-triage.md` | Pre-step: request envelope, owner resolution, L1/L2 selection, L2 task packet contract |
| `workflows/role-self-maintenance.md` | Roles self-audit / self-fetch / self-update their knowledge snapshots |
| `workflows/quality-ledger.md` | Append-only quality receipts: independent QA GO/NO-GO, routing verification |
| `workflows/update-role-knowledge.md` | Refresh `knowledge/<role-id>.md` snapshots when code/contracts/evidence change |
| `knowledge/*.md` | Derived per-role knowledge snapshots (templates ship empty) |
| `scripts/check-doc-sync.sh` | Deterministic commit gate over `doc-ownership.yaml` |
| `scripts/select-role.sh` | Executable role matcher with a self-test table |
| `scripts/role-snapshot-audit.sh` | Finds snapshots whose owners' code moved without an update |
| `scripts/quality-ledger.sh` | Aggregates the quality ledger into GO rate, issue counts, route-verify rate |
| `templates/doc-ownership.example.yaml` | Example ownership manifest: code globs, owned docs, eligible knowledge roles |

## Rule Priority

1. This `SKILL.md` and `rules/role-boundaries.md`
2. `references/role-catalog.md`
3. `workflows/`
4. The project's own source-of-truth docs and explicit user decisions
5. `knowledge/<role-id>.md` (derived snapshots; never outrank canonical sources)

## Boundaries

- Roles are functional lenses for one task; they do not grant deploy,
  production-mutation, spending, private-data, or external-contact authority.
- Verification roles may block a completion claim on missing evidence; they
  may not redefine the requested behavior.
- The skill governs process, not the project's product rules. The host
  project still supplies its own routing, coding standards, and domain docs.
