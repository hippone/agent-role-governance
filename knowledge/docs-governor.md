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
- Matcher text mode is a compatibility candidate generator; JSON request-envelope mode is the precise routing interface. In text mode a protected-domain term with an unrecognized action verb routes to `contract-coordinator`, never to an L1 candidate.
- Doc-sync auto-detects an in-repository install and explicitly reports a global-only installation as unwired.
- `doctor.sh` distinguishes active hook wiring (the directory `git rev-parse --git-path hooks` resolves) from an inert `.githooks` directory, and reports the `core.hooksPath` activation command for the inert case.
- `.githooks/commit-msg` locates the checker at the repo root or under `skills/*/`, `.agents/skills/*/`, `.claude/skills/*/`, so the same hook file works for self-bootstrap and vendored host installs.

## Source Pointers

- `SKILL.md`
- `references/role-matcher.md`
- `scripts/select-role.sh`
- `scripts/check-doc-sync.sh`
- `scripts/doctor.sh`
- `.githooks/commit-msg`
- `doc-ownership.yaml`

## Known Drift And Unknowns

- Agent-config hook detection (`.claude`, `.codex`, `.cursor`, `AGENTS.md`, `CLAUDE.md`) still counts file presence as wiring; only git-hook activation is verified against the resolved hooks directory.
- Production benefit remains unverified until a host project records comparative cost and outcome metrics.

## Update Triggers

- Role catalog, matcher protocol, install layout, manifest schema, hook behavior, or evidence-claim semantics change.

## Recent Deltas

- 2026-08-13: `check-doc-sync.sh` snapshot-initialization check now accepts legacy-format `Recent Deltas` (real content without date prefixes) alongside the dated format; blank placeholders still block. This is the documented migration path for host projects with pre-existing snapshots.
- 2026-08-13: matcher adds `readme` to the docs-only word list (`update the README only` -> `docs-governor`, 42 self-test cases); bare "update README" without an only/仅/只 qualifier still routes to the coordinator conservatively.
- 2026-08-13: matcher gains a protected-domain noun fallback (verb-gap requests like "refactor the auth ..." now coordinate), broader bilingual verb/surface vocabulary (41 self-test cases); doctor verifies git-hook activation via `rev-parse --git-path hooks` and flags inert `.githooks` with the fix command; commit-msg hook searches vendored install paths; README documents `core.hooksPath` activation. Work uncommitted at capture time; baseline is the prior commit.
- 2026-08-13: doctor.sh and check-doc-sync.sh compare repository paths case-insensitively (macOS `openSource` vs `opensource`); self-bootstrap install is now detected as `in-repository`. Commit-msg hook (`.githooks/`, `core.hooksPath`) plus Claude Code PreToolUse gate wired; doctor.sh is rg-free (grep) and detects hooks even when probe dirs are missing.
- 2026-08-13: repository self-wiring, structured matcher input, strict ledger validation, installation doctor, and CI fixtures added; no production verification claimed.
