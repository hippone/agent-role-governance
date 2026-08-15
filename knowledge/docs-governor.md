---
role_id: docs-governor
tier: L1
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Docs Governor

## Current Knowledge

- This repository is the distributable role-governance skill, not a host product repository.
- README and README.zh-CN.md are the bilingual project docs; README links to the Chinese edition and vice versa. `doc-ownership.yaml` lists both as governed files.
- `doc-ownership.yaml` self-governs the skill implementation; host projects copy and adapt the template manifest.
- Matcher text mode is a compatibility candidate generator; JSON request-envelope mode is the precise routing interface. In text mode a protected-domain term with an unrecognized action verb routes to `contract-coordinator`, never to an L1 candidate.
- Copy/UI classification is judged from the user's perspective — status/state-feedback terms are forbidden as copy/UI signals and never route a request into the frontend/design lane on their own.
- Doc-sync auto-detects an in-repository install and explicitly reports a global-only installation as unwired.
- `doctor.sh` distinguishes active hook wiring (the directory `git rev-parse --git-path hooks` resolves) from an inert `.githooks` directory, and reports the `core.hooksPath` activation command for the inert case.
- `.githooks/commit-msg` locates the checker at the repo root or under `skills/*/`, `.agents/skills/*/`, `.claude/skills/*/`, so the same hook file works for self-bootstrap and vendored host installs.
- `benefit-report.sh` + `_gen_html.py` generate a self-contained HTML dashboard collecting metrics from all governance scripts; output is gitignored.

## Source Pointers

- `SKILL.md`
- `references/role-matcher.md`
- `scripts/select-role.sh`
- `scripts/check-doc-sync.sh`
- `scripts/doctor.sh`
- `scripts/benefit-report.sh`
- `.githooks/commit-msg`
- `doc-ownership.yaml`

## Known Drift And Unknowns

- Agent-config hook detection (`.claude`, `.codex`, `.cursor`, `AGENTS.md`, `CLAUDE.md`) still counts file presence as wiring; only git-hook activation is verified against the resolved hooks directory.
- Production benefit remains unverified until a host project records comparative cost and outcome metrics.

## Update Triggers

- Role catalog, matcher protocol, install layout, manifest schema, hook behavior, or evidence-claim semantics change.
- New scripts or documentation files added to the project.

## Recent Deltas

- 2026-08-16: refresh — added `benefit-report.sh` + `_gen_html.py` awareness; updated copy/UI classification note; all 8 placeholder snapshots bootstrapped in this session.
- 2026-08-14: README restructured for scanability (both editions): TOC, concept table with one-line meanings, condensed walkthrough, one-line layout comments; content preserved.
- 2026-08-14: README is now bilingual — `README.zh-CN.md` carries the full Simplified Chinese translation and README links between the two editions; `doc-ownership.yaml` and the docs-governor snapshot cover the new file.
- 2026-08-13: `UPGRADING.md` documents the three-class migration procedure (overwrite mechanism / merge host-context / keep host data), legacy-format snapshot migration path, and the optional `git subtree` sync; README links it.
- 2026-08-13: matcher adds `readme` to the docs-only word list, broader bilingual verb/surface vocabulary (50 self-test cases); doctor verifies git-hook activation via `rev-parse --git-path hooks` and flags inert `.githooks` with the fix command.
