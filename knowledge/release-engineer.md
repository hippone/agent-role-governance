---
role_id: release-engineer
tier: L1
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Release Engineer

## Current Knowledge

- This repository is the distributable role-governance skill itself, not a host product; there is no deployable application binary. The release-engineer role here governs skill packaging, CI validation, and upgrade procedures for host projects that vendor this skill.
- CI pipeline (.github/workflows/ci.yml) runs three sequential steps on every push and PR: (1) `bash tests/run.sh` (matcher and ledger self-tests plus doc-sync integration fixture), (2) `bash scripts/doctor.sh --strict` (wiring validation; exits non-zero when manifest, catalog, or knowledge directory is missing), (3) `bash scripts/check-doc-sync.sh --dirty` (doc-ownership gate on the full worktree).
- The commit-msg git hook (.githooks/commit-msg) runs `check-doc-sync.sh --staged` on every commit. It searches for the checker at the repo root and under vendored install paths (skills/*/, .agents/skills/*/, .claude/skills/*/). Activation requires `git config core.hooksPath .githooks`; doctor.sh detects and reports the inert state with the fix command.
- doctor.sh (--strict, --json) is the readiness probe: it verifies manifest presence, catalog/knowledge directory, ledger directory, hook wiring (active vs. inert .githooks), and counts stale/current knowledge snapshots. --strict exits 1 when status is not-ready; --json emits machine-readable output for automation.
- UPGRADING.md defines three file classes for host-project migration: Class A (overwrite -- mechanism files like scripts/, tests/, .githooks/commit-msg), Class B (merge -- files with host context like SKILL.md, rules/role-boundaries.md), Class C (keep -- host data like doc-ownership.yaml, knowledge/*.md, ledger/*.jsonl). The post-upgrade verification sequence is: `bash tests/run.sh`, then `bash scripts/doctor.sh --strict`, then `bash scripts/check-doc-sync.sh --dirty`.
- The doc-sync gate (check-doc-sync.sh) operates in three modes: --dirty (worktree), --staged (index only), --hook-commit (JSON hook input filtering for git commit commands). Waiver markers [docs-na] and [knowledge-na] exist but [knowledge-na] requires [docs-na] and is limited to one feature surface.
- All scripts auto-detect their install location relative to the git root (via ROLE_GOVERNANCE_DIR env var or path arithmetic from BASH_SOURCE), so the same scripts work at the repo root and when vendored under a subdirectory in a host project.

## Source Pointers

- `.github/workflows/ci.yml`
- `scripts/doctor.sh`
- `scripts/check-doc-sync.sh`
- `.githooks/commit-msg`
- `UPGRADING.md`
- `SKILL.md`
- `tests/run.sh`
- `doc-ownership.yaml`

## Known Drift And Unknowns

- No actual release/packaging mechanism (e.g. GitHub Releases, npm publish, versioning tags) exists in the repository yet; the SKILL.md frontmatter declares version 1.0 but there is no automated release workflow or changelog.
- The CI pipeline has no deploy or publish step -- it is purely validation (tests, doctor, doc-sync); any distribution to host projects is manual (git subtree pull or file copy per UPGRADING.md).
- doctor.sh agent-config hook detection (.claude, .codex, .cursor, AGENTS.md, CLAUDE.md) counts file presence as wiring without verifying actual activation -- only git-hook wiring is verified against the resolved hooks directory.

## Update Triggers

- CI workflow (.github/workflows/ci.yml) steps, runners, or permissions change.
- New scripts added to scripts/ or existing script interfaces change (flags, exit codes).
- UPGRADING.md file classification or migration procedure changes.
- Git hook (.githooks/commit-msg) search paths or gate behavior changes.
- A release/packaging workflow (GitHub Releases, tags, changelog) is introduced.

## Recent Deltas

- 2026-08-16: initial snapshot bootstrapped from CI pipeline, scripts, git hook, and UPGRADING.md at baseline ba715e3.
