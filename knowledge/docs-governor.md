---
role_id: docs-governor
tier: L1
knowledge_status: current
captured_on: 2026-08-17
repository_baseline: 0f2441f
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
- `benefit-report.sh` + `_gen_html.py` generate a self-contained HTML dashboard collecting metrics from all governance scripts; output is gitignored. The dashboard includes an 8-system × 10-dimension horizontal comparison (5 governance + 5 execution dimensions, split Gov/Exec subtotals).
- `check-doc-sync.sh` excludes generated artifacts (`__pycache__/`, `*.pyc`, `*.pyo`, `.DS_Store`) from the change set and reports them as a note. Manifest `knowledge_roles` entries may be `role: glob` mappings: a mapped role's snapshot is required only when a changed file matches its globs; plain string roles are the catch-all when no mapping hits. This repo's manifest maps each script/workflow to its owning role; updating a snapshot's own file always satisfies that role's requirement.
- The governance-skill owner code list includes `.githooks/**` and `.gitignore`.

## Source Pointers

- `SKILL.md`
- `references/role-matcher.md`
- `scripts/select-role.sh`
- `scripts/check-doc-sync.sh`
- `scripts/doctor.sh`
- `scripts/benefit-report.sh`
- `.githooks/commit-msg`
- `doc-ownership.yaml`
- `templates/doc-ownership.example.yaml`
- `UPGRADING.md`

## Known Drift And Unknowns

- Agent-config hook detection (`.claude`, `.codex`, `.cursor`, `AGENTS.md`, `CLAUDE.md`) still counts file presence as wiring; only git-hook activation is verified against the resolved hooks directory.
- Production benefit remains unverified until a host project records comparative cost and outcome metrics.

## Update Triggers

- Role catalog, matcher protocol, install layout, manifest schema, hook behavior, or evidence-claim semantics change.
- New scripts or documentation files added to the project.

## Recent Deltas

- 2026-08-17: `check-doc-sync.sh` excludes generated artifacts (`__pycache__/`, `*.pyc`, `.DS_Store`); `knowledge_roles` gains optional `role: glob` mappings so the gate names the specific snapshot to update instead of any of 11; `doc-ownership.yaml` adopts mappings; `.gitignore` covers Python artifacts; template and `UPGRADING.md` document the additive syntax.
- 2026-08-16: refresh — added `benefit-report.sh` + `_gen_html.py` awareness; updated copy/UI classification note; all 8 placeholder snapshots bootstrapped in this session.
- 2026-08-14: README restructured for scanability (both editions): TOC, concept table with one-line meanings, condensed walkthrough, one-line layout comments; content preserved.
- 2026-08-14: README is now bilingual — `README.zh-CN.md` carries the full Simplified Chinese translation and README links between the two editions; `doc-ownership.yaml` and the docs-governor snapshot cover the new file.
- 2026-08-13: `UPGRADING.md` documents the three-class migration procedure (overwrite mechanism / merge host-context / keep host data), legacy-format snapshot migration path, and the optional `git subtree` sync; README links it.
