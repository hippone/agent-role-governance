---
role_id: backend-engineer
tier: L1
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Backend Engineer

## Current Knowledge

- This repository is the role-governance skill itself (rules, scripts, workflows, knowledge snapshots, tests), not a host product with backend services. There is no backend service, persistence layer, or controller logic to implement here; the backend-engineer role applies only when this skill is installed into a host project.
- Scripts are Bash wrappers around inline Python (quality-ledger.sh, check-doc-sync.sh, role-snapshot-audit.sh, select-role.sh, doctor.sh). Each embeds a Python script via heredoc and runs it with python3. Modifying script logic means editing the embedded Python, not separate .py files.
- quality-ledger.sh validates JSONL entries against a strict schema (id, date, routing{role,tier,confidence,verified,expected_role}, qa{status,issues,severity,review,review_verified,review_ref}, optional metrics), appends to ledger/YYYY-MM.jsonl, and aggregates GO rate, route-verify rate, and review-receipt verification. Role names are validated against references/role-catalog.md.
- check-doc-sync.sh is the deterministic commit gate. It parses doc-ownership.yaml for owner entries (id, kind, code globs, docs, knowledge_roles), matches changed files against code patterns, and blocks commits when owned docs or eligible knowledge snapshots are not co-updated. Waivers: [docs-na] for docs, [knowledge-na] additionally requires [docs-na] and is limited to one feature owner.
- select-role.sh implements deterministic role matching in three tiers: T1 hard signals (docs-only, production risk, contract impact, ambiguity/multi-role), T2 request-shape candidates (requirement, interaction-design, diagnosis, frontend/backend keywords, contract design-only), and a T3 fallback to change-coordinator. Backend-engineer matches on keywords: backend, service, persistence, repository, server, and Chinese equivalents. Multiple T2 candidates promote to change-coordinator.
- role-snapshot-audit.sh detects stale snapshots by comparing git log timestamps: for each catalog role, it finds the last commit touching knowledge/<role>.md versus the newest commit on any owner code glob that lists that role in knowledge_roles. If code moved after the snapshot, the snapshot is stale. Also detects worktree-dirty snapshots pending commit.
- doctor.sh is a read-only health check reporting installation mode (in-repository vs global-only), manifest/catalog/knowledge/ledger presence, hook wiring status (active git hooks vs inert .githooks vs agent-config files), and stale/current snapshot counts. --strict exits non-zero when hard wiring is incomplete; --json emits machine-readable output.

## Source Pointers

- `scripts/quality-ledger.sh`
- `scripts/check-doc-sync.sh`
- `scripts/role-snapshot-audit.sh`
- `scripts/select-role.sh`
- `scripts/doctor.sh`
- `doc-ownership.yaml`
- `references/role-catalog.md`
- `SKILL.md`

## Known Drift And Unknowns

- The backend-engineer role has no backend module to own in this repository; all scripts are governance infrastructure. The role's value here is understanding the script internals (embedded Python, JSONL schema, YAML parsing) for maintenance or bug fixes, not exercising its normal service/persistence authority.
- Agent-config hook detection in doctor.sh counts file presence in .claude/.codex/.cursor/AGENTS.md/CLAUDE.md as wiring; only git-hook activation is verified against the resolved hooks directory.
- No ledger data exists yet (ledger/ directory absent), so quality-ledger.sh aggregation paths are untested with real production data in this repository.

## Update Triggers

- Changes to any script under scripts/ (schema validation, parsing logic, embedded Python, CLI interface, self-test tables).
- Changes to doc-ownership.yaml owner structure, code globs, or knowledge_roles assignments.
- Changes to the JSONL ledger schema or validation rules in quality-ledger.sh.
- New scripts added to scripts/ or changes to the Bash-wraps-Python pattern.

## Recent Deltas

- 2026-08-16: initial bootstrap from canonical sources at baseline ba715e3; no prior snapshot content existed.
