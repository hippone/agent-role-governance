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
- **Measurable quality evidence.** `workflows/quality-ledger.md` records an
  append-only JSONL receipt per L2 task — independent QA GO/NO-GO, issues,
  routing verification — and `scripts/quality-ledger.sh` aggregates it into a
  GO rate, issue counts, and route-verify rate. The process proves itself
  instead of claiming it.
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
workflows/quality-ledger.md     append-only quality receipts and how to read them
workflows/update-role-knowledge.md
                                manual snapshot refresh (legacy lane)
knowledge/*.md                  11 role snapshot templates (ship empty)
scripts/check-doc-sync.sh       deterministic doc/knowledge sync gate
scripts/select-role.sh          executable role matcher with self-test
scripts/role-snapshot-audit.sh  expired-snapshot sweep
scripts/quality-ledger.sh       aggregates GO rate, issues, route-verify rate
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

## Walkthrough: One Task End To End

A payment-flow feature lands in a project wired up as described above. This
is what the governance layer actually does at each step.

### 1. The request arrives

> "Add webhook handling for refunds and show the refund receipt on the
> account page."

### 2. The role matcher identifies the routing role

```bash
echo "add webhook handling for refunds and show the refund receipt" \
  | bash skills/project-rules/scripts/select-role.sh
```

```json
{
  "role": "contract-coordinator",
  "tier": "T1",
  "confidence": "high",
  "reason": "auth/billing/privacy/identity signal",
  "candidates": [
    {"tier": "T1", "role": "contract-coordinator", "confidence": "high", "signal": "auth/billing/privacy/identity signal"}
  ]
}
```

`contract-coordinator` L2 wins because the T1 hard signal (billing) beats the
frontend-looking phrasing — a small diff in one file would not have changed
this, which is the point of the gate.

### 3. The L2 coordinator decomposes into bounded L1 packets

```
Task Packet: PKT-01  Role: contract-architect  Mode: subagent (run a1b2c3)
  Context: C0 + C2 contract slices
  Output: refund webhook contract, migration boundary
Task Packet: PKT-02  Role: backend-engineer     Mode: subagent (run d4e5f6)
  Context: C1 behavior + C2 contract + C3 implementation
  Output: webhook handler, idempotency, tests
Task Packet: PKT-03  Role: frontend-engineer    Mode: subagent (run g7h8i9)
  Context: C1 + frontend C3
  Output: receipt UI consuming the new state
Task Packet: PKT-04  Role: quality-engineer     Mode: subagent, after PKT-02/03
  Context: diff + test evidence
  Output: GO/NO-GO on the integrated change set
```

Each packet records its delegation receipt, risk route, and fork strategy.
PKT-04 is the mandatory independent review — the mutation owners cannot
self-certify.

### 4. Roles self-maintain their knowledge

Before working, `backend-engineer` runs its self-audit (did anything it
depends on change since `captured_on`?). After implementing, it updates its
own snapshot:

```diff
## Recent Deltas
+- 2026-08-13: refund webhook v1 lands; idempotency keyed on event id;
+  no refund auto-approval without explicit operator action.
```

### 5. The deterministic gate catches the half-done commit

The coordinator tries to commit code + backend snapshot, but the frontend
snapshot is missing:

```bash
$ bash skills/project-rules/scripts/check-doc-sync.sh --dirty
doc-sync: 1 violation(s), 0 warning(s)
VIOLATION web-app: code changed (src/pages/account.tsx) but none of its
eligible role knowledge snapshots touched -> update one of:
skills/project-rules/knowledge/frontend-engineer.md
```

The commit is blocked until the frontend snapshot moves. No reviewer needed
for this kind of drift — the gate is structural.

### 6. Quality evidence is recorded, not claimed

After reconciliation, the coordinator appends the receipt:

```bash
echo '{"id":"T-104","routing":{"role":"contract-coordinator","tier":"T1",
  "verified":true},"qa":{"status":"GO","issues":0,"review":"subagent run k1l2m3"}}' \
  | bash skills/project-rules/scripts/quality-ledger.sh --add
```

Two weeks later, the monthly summary says what the process produced:

```bash
$ bash skills/project-rules/scripts/quality-ledger.sh --summary
quality-ledger: 24 entries
  QA: GO=20 NO-GO=2 PARTIAL=2
  GO rate: 83.3%
  issues: 7 across 4 entries
  route verified: 18/24 (75.0%)
  roles: contract-coordinator=6, frontend-engineer=5, change-coordinator=4, ...
```

A repeated NO-GO on the same role would now be visible and fixable — the
loop is closed.

### 7. The smaller L1 path, for contrast

> "Fix the typo on the settings page and add a component test."

The matcher returns `frontend-engineer` (T2, no hard signal), the L1 Direct
Gate passes, and the task executes directly with a compact receipt — no
packets, no subagents. Governance scales down to a single line of context
instead of adding ceremony to every task.

## How It Compares| | This skill | Subagent packs (e.g. awesome-claude-code-subagents) | Orchestration frameworks (e.g. maestro) | Methodology kits (e.g. BMAD) |
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
