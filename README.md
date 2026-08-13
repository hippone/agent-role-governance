# role-governance

A governance layer for AI coding agents: functional roles with explicit
authority, context-depth, and risk boundaries — enforced by a deterministic
commit gate, not vibes.

Roles are temporary responsibility lenses, not persistent personas. This skill
decides **how work is handled**, not what your product does: who may touch
what, how much context each role sees, which subagent model runs each packet,
and how durable per-role knowledge stays in sync with code changes.

## Concepts

- **L1 / L2 processing levels.** L1 direct roles execute one bounded outcome.
  L2 coordinators decompose ambiguous or cross-surface work into bounded L1
  packets with a real subagent per packet — same-agent role switching is an
  explicit, recorded degradation, never silent "delegation".
- **Automatic role identification.** `references/role-matcher.md` defines a
  three-tier matching protocol (hard signals -> request shape -> gate
  recheck); `scripts/select-role.sh` executes it with confidence scores and a
  self-test table. Roles are matched, not guessed.
- **Self-maintaining role knowledge.** Each role follows
  `workflows/role-self-maintenance.md`: it audits its snapshot before work,
  fetches what it needs from canonical sources during work, and updates its
  own snapshot after work — `scripts/role-snapshot-audit.sh` finds snapshots
  whose owners' code moved without an update, so staleness is caught
  proactively instead of at commit time.
- **L1 Direct Gate.** A checklist, not vibes. If any condition fails, the task
  must go through an L2 coordinator, even when the diff is small.
- **C0-C4 context depth.** Explicit disclosure slices per packet: C0 request,
  C1 behavior, C2 contract, C3 implementation, C4 release. Each role has a
  routine upper limit in `references/role-catalog.md`.
- **R0-R3 risk routing.** Subagent model and reasoning effort are chosen from
  packet risk (blast radius, ambiguity, error cost), not role titles. Receipts
  record what was requested, what fell back, and what actually ran.
- **Role knowledge snapshots.** Each role keeps one derived
  `knowledge/<role-id>.md` with current facts, source pointers, unknowns, and
  at most five recent deltas. Git history is the audit trail.
- **Doc-sync commit gate.** `scripts/check-doc-sync.sh` blocks commits where
  mapped code changed but no owned doc and no eligible role snapshot moved.
  Narrow `[docs-na]` / `[knowledge-na]` waivers exist; they are checked, not
  trusted.

## Repository Layout

```
SKILL.md                        skill entry; core loop and file map
rules/role-boundaries.md        authority model, L1/L2 gates, C0-C4, R0-R3,
                                subagent execution requirements, knowledge duty
references/role-catalog.md      8 L1 + 3 L2 roles with decision scope and
                                routine context limits
references/role-matcher.md      deterministic role identification protocol
workflows/requirement-triage.md request envelope -> owner resolution ->
                                role matching -> task packet contract
workflows/role-self-maintenance.md
                                per-role self-audit / self-fetch / self-update
workflows/update-role-knowledge.md
                                manual snapshot refresh (legacy lane)
knowledge/*.md                  11 role snapshot templates (ship empty)
scripts/check-doc-sync.sh       deterministic doc/knowledge sync gate
scripts/select-role.sh          executable role matcher with self-test
scripts/role-snapshot-audit.sh  expired-snapshot sweep
templates/doc-ownership.example.yaml
                                example ownership manifest; copy and adapt
```

## Install

### Claude Code

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/hippone/agent-role-governance ~/.claude/skills/role-governance
```

Then ask the agent to "run role triage for this change" or add the skill to
your project's instructions so it activates on every task.

### opencode

```bash
mkdir -p ~/.config/opencode/skills
git clone https://github.com/hippone/agent-role-governance ~/.config/opencode/skills/role-governance
```

### Codex

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/hippone/agent-role-governance ~/.codex/skills/role-governance
```

## Wire Up A Project

The role prompts and packet rules work from any install location (including
global skill dirs). The **doc-sync commit gate only works when the skill lives
inside your project repository**, because it inspects git change sets — global
installations skip the gate silently.

1. Copy `templates/doc-ownership.example.yaml` into the skill directory inside
   your repo as `doc-ownership.yaml`, and adapt owners, code globs, docs, and
   `knowledge_roles` to your repo. Code globs are repository-root-relative;
   the example's `skills/project-rules/...` governance globs match the default
   install location — adjust the prefix if you install elsewhere. Every catalog
   role must appear in at least one owner.
2. Optional: add `references/system-map.md` and a `system_map_checks` section
   in `doc-ownership.yaml` to require registering new files/modules (see the
   template header for the schema). The checker skips these checks entirely
   when the system map file does not exist.
3. Run from the repository root:

   ```bash
   bash skills/project-rules/scripts/check-doc-sync.sh --dirty
   ```

   If the skill is installed elsewhere, point the checker at it:

   ```bash
   ROLE_GOVERNANCE_DIR=.agents/skills/role-governance \
     bash .agents/skills/role-governance/scripts/check-doc-sync.sh --dirty
   ```

4. Optional commit hook: register `scripts/check-doc-sync.sh --hook-commit` as
   a PreToolUse hook for `git commit` in your agent of choice. The checker
   reads the hook's JSON input on stdin and only acts on commit commands.

## How It Compares

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

- Roles never grant deploy, production-mutation, spending, private-data, or
  external-contact authority.
- Verification roles block completion claims on missing evidence; they never
  redefine requested behavior.
- Facts, decisions, assumptions, and proposals are kept separate in packets.
- `implemented`, `tested`, `built`, `deployed`, `browser-verified`,
  `payment-verified`, `provider-verified` stay separate claims.

## License

MIT
