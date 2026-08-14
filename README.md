# role-governance

> English | [简体中文](README.zh-CN.md)

**A governance layer for AI coding agents**: functional roles with explicit
authority, context-depth, and risk boundaries — enforced by a deterministic
commit gate, not vibes.

## Table of Contents

- [How it works](#how-it-works)
- [Install](#install)
- [Wire up a project](#wire-up-a-project)
- [Walkthrough: one task end to end](#walkthrough-one-task-end-to-end)
- [Repository layout](#repository-layout)
- [How it compares](#how-it-compares)
- [Principles](#principles)

## How it works

Roles are temporary responsibility lenses, not persistent personas. This skill
decides **how work is handled**, not what your product does.

| Concept | What it means |
|---|---|
| **L1 / L2 levels** | L1 roles execute one bounded outcome; L2 coordinators decompose ambiguous/cross-surface work into bounded L1 packets, each run by a real subagent. Same-agent role switching is a recorded degradation, never silent "delegation". |
| **Automatic role ID** | `references/role-matcher.md` defines three-tier matching (hard signals -> request shape -> gate recheck); `scripts/select-role.sh --envelope` executes it from structured request facts. |
| **L1 Direct Gate** | A deterministic checklist. If any condition fails, the task must go through an L2 coordinator — even for small diffs. |
| **C0-C4 context depth** | Explicit disclosure slices per packet: C0 request, C1 behavior, C2 contract, C3 implementation, C4 release. Each role has a routine upper limit in `references/role-catalog.md`. |
| **R0-R3 risk routing** | Subagent model and reasoning effort come from packet risk (blast radius, ambiguity, error cost), not role titles. Receipts record what was requested, what fell back, what ran. |
| **Self-maintaining knowledge** | Each role audits its `knowledge/<role-id>.md` snapshot before work, fetches from canonical sources during, updates after — `scripts/role-snapshot-audit.sh` catches stale snapshots proactively. |
| **Quality ledger** | `workflows/quality-ledger.md` records append-only JSONL receipts per L2 task (QA GO/NO-GO, issues, routing verification); `scripts/quality-ledger.sh` aggregates GO rate. Evidence, not claims. |
| **Doc-sync commit gate** | `scripts/check-doc-sync.sh` blocks commits where mapped code changed but no owned doc or eligible role snapshot moved. Narrow `[docs-na]` / `[knowledge-na]` waivers exist; they are checked, not trusted. |

## Install

**Claude Code**

```bash
mkdir -p ~/.claude/skills && git clone https://github.com/hippone/agent-role-governance ~/.claude/skills/role-governance
```

**opencode**

```bash
mkdir -p ~/.config/opencode/skills && git clone https://github.com/hippone/agent-role-governance ~/.config/opencode/skills/role-governance
```

**Codex**

```bash
mkdir -p ~/.codex/skills && git clone https://github.com/hippone/agent-role-governance ~/.codex/skills/role-governance
```

Then ask the agent to "run role triage for this change", or add the skill to
your project instructions so it activates on every task.

## Wire up a project

Role prompts and packet rules work anywhere. **The doc-sync commit gate only
works when the skill lives inside the project repository** — its manifest and
snapshots must be in the same Git change set. A global-only invocation reports
it is unwired; a repo-local invocation with a missing manifest fails loudly.

1. Copy `templates/doc-ownership.example.yaml` into the skill dir inside your
   repo as `doc-ownership.yaml`; adapt owners, code globs, docs, and
   `knowledge_roles`. Code globs are repo-root-relative — adjust the
   `skills/role-governance/...` prefix if you install elsewhere. Every catalog
   role must appear in at least one owner. Reset or replace every upstream
   snapshot with host-project facts before marking it current.
2. Optional: add `references/system-map.md` + a `system_map_checks` section in
   `doc-ownership.yaml` to require registering new files/modules. The checker
   skips these checks when the file doesn't exist.
3. Run from the repo root:

   ```bash
   bash skills/role-governance/scripts/check-doc-sync.sh --dirty
   ```

4. Enable at least one commit-gate path (a hook file that merely exists does
   nothing):

   - **Repo git hook** (covers terminal, IDE, and agent commits): copy
     `.githooks/commit-msg` to your repo root, then
     `git config core.hooksPath .githooks`. The hook finds the checker at the
     root or under `skills/*/`, `.agents/skills/*/`, `.claude/skills/*/`.
   - **Agent hook**: register `scripts/check-doc-sync.sh --hook-commit` as a
     PreToolUse hook for `git commit` (see this repo's `.claude/settings.json`).
5. Verify wiring before relying on it:

   ```bash
   bash skills/role-governance/scripts/doctor.sh --strict
   ```

## Walkthrough: one task end to end

A payment-flow feature lands in a wired-up project.

1. **The request arrives** — *"Add webhook handling for refunds and show the refund receipt on the account page."*
2. **The matcher identifies the routing role** —

   ```bash
   printf '%s\n' '{"request_type":"behavior_change","goal":"add webhook handling for refunds and show the refund receipt","billing_impact":true,"scope_width":2,"functional_roles":["backend-engineer","frontend-engineer"]}' \
     | bash skills/role-governance/scripts/select-role.sh --envelope
   ```

   Result: `contract-coordinator` (T1, `billing` hard signal) — the T1 signal
   beats the frontend-looking phrasing, even for a small diff. That's the point
   of the gate.
3. **The L2 coordinator decomposes into bounded L1 packets** — `contract-architect` (contract + migration boundary), `backend-engineer` (handler, idempotency, tests), `frontend-engineer` (receipt UI), `quality-engineer` (independent GO/NO-GO after the rest). Each packet records its delegation receipt, risk route, and fork strategy; the mutation owners cannot self-certify.
4. **Roles self-maintain knowledge** — before working, `backend-engineer` audits its snapshot; after implementing, it appends a delta:

   ```diff
   ## Recent Deltas
   +- 2026-08-13: refund webhook v1 lands; idempotency keyed on event id;
   +  no refund auto-approval without explicit operator action.
   ```

5. **The gate catches the half-done commit** — code + backend snapshot, but no frontend snapshot:

   ```bash
   $ bash skills/role-governance/scripts/check-doc-sync.sh --dirty
   doc-sync: 1 violation(s), 0 warning(s)
   VIOLATION web-app: code changed (src/pages/account.tsx) but none of its
   eligible role knowledge snapshots touched -> update one of:
   skills/role-governance/knowledge/frontend-engineer.md
   ```

   Blocked until the snapshot moves — no reviewer needed, the gate is structural.
6. **Quality evidence is recorded, not claimed** — the coordinator appends a
   receipt; weeks later `--summary` shows GO rate, issues, route verification.
   A repeated NO-GO on the same role becomes visible — a process signal, not
   proof of product quality; compare with rework, escaped defects, cycle time,
   and cost before changing routing rules.
7. **The smaller L1 path, for contrast** — *"Fix the typo on the settings page and add a component test."* → matcher returns `frontend-engineer` (T2, no hard signal), L1 Direct Gate passes, executes directly with a compact receipt. No packets, no subagents — governance scales down instead of adding ceremony to every task.

## Repository layout

```
SKILL.md                        skill entry; core loop and file map
rules/role-boundaries.md        authority model, L1/L2 gates, C0-C4, R0-R3
references/role-catalog.md      8 L1 + 3 L2 roles with decision scope and context limits
references/role-matcher.md      deterministic role identification protocol
references/model-capabilities-2026.md
                                grounded 2026-07/08 model facts (context windows, tiers)
workflows/requirement-triage.md request envelope -> owner resolution -> packet contract
workflows/role-self-maintenance.md
                                per-role self-audit / self-fetch / self-update
workflows/quality-ledger.md     append-only quality receipts and how to read them
workflows/update-role-knowledge.md
                                manual snapshot refresh (legacy lane)
knowledge/*.md                  11 role snapshots; host roles start as stale templates
scripts/check-doc-sync.sh       deterministic doc/knowledge sync gate
scripts/select-role.sh          executable role matcher with self-test
scripts/role-snapshot-audit.sh  expired-snapshot sweep
scripts/quality-ledger.sh       aggregates GO rate, issues, route-verify rate
scripts/check-external-facts.sh flags stale external-fact markers (180 days)
scripts/doctor.sh               reports whether manifest, hooks, ledger are wired
tests/                          matcher, ledger, and doc-sync integration checks
doc-ownership.yaml              self-governance map for this repository
templates/doc-ownership.example.yaml
                                example ownership manifest; copy and adapt
```

## How it compares

| | This skill | Subagent packs (e.g. awesome-claude-code-subagents) | Orchestration frameworks (e.g. maestro) | Methodology kits (e.g. BMAD) |
|---|---|---|---|---|
| Role definitions | Yes, with decision scope | Persona prompts only | Implicit | Yes, fixed SDLC phases |
| Direct-vs-coordinate gate | Deterministic checklist | No | No | Workflow-size heuristics |
| Context disclosure limits | C0-C4 per role | No | No | Partial |
| Subagent model routing | Risk-based R0-R3 with receipts | No | Fixed model | No |
| Delegation accountability | Real-subagent receipts; degradation must be declared | No | No | No |
| Durable role memory | Snapshots + sync gate | No | No | Partial (briefs/artifacts) |
| Plugs into existing workflow | Yes; pre-step only | Yes | Replaces workflow | Replaces workflow |

## Principles

- Roles never grant deploy, production-mutation, spending, private-data, or external-contact authority.
- Verification roles block completion claims on missing evidence; they never redefine requested behavior.
- Facts, decisions, assumptions, and proposals stay separate in packets.
- `implemented`, `tested`, `built`, `deployed`, `browser-verified`, `payment-verified`, `provider-verified` stay separate claims.

## Upgrading

See [UPGRADING.md](UPGRADING.md) for the three-class migration procedure
(overwrite / merge / keep), legacy snapshot format migration, and optional
`git subtree` sync.

## License

MIT
