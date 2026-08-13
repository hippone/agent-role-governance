# Role Boundaries

Use functional roles to control task handling, decision scope, and context disclosure. Roles are temporary responsibility lenses, not persistent personas, people, tool-specific agent types, or code owners.

## Authority Model

- `doc-ownership.yaml` remains the only static map from product surfaces or infrastructure to code and owned docs. Role documents must reference owner IDs or affected surfaces; they must not duplicate file globs.
- Explicit user decisions, active product specs, and the project's source-of-truth order outrank role recommendations.
- A role assignment does not grant new authority to deploy, mutate production, spend money, access private data, or contact external people.
- A coordinator may choose routing, dependency order, and the minimum context for each task packet. It may not silently resolve a product, privacy, payment, or release decision that requires the user.
- Verification roles may block a completion or release claim when evidence is insufficient. They may not redefine the requested behavior.

## Processing Levels

Level describes coordination width, not seniority, trust, permission, or information clearance.

| Level | Name | Processing rule |
|---|---|---|
| L1 | Direct role | Receives one bounded outcome, executes it within one functional boundary, verifies it, and returns the result directly. |
| L2 | Coordinating role | Normalizes the request, resolves or exposes ambiguity, decomposes work, gives each L1 role minimum sufficient context, orders dependencies, and reconciles returned evidence. |

## L1 Direct Gate

An L1 role may handle the request directly only when every condition is true:

- The request type, affected user-action surface, current behavior, target outcome, and acceptance check are clear.
- One functional role and one static owner boundary can complete the requested outcome.
- A `kind: infra` owner has no dependents outside the packet; otherwise use L2 unless the task is read-only or explicitly behavior-preserving and one role can verify every affected downstream boundary.
- The work does not introduce or change a public contract, shared state machine, persistence schema, identity rule, billing rule, privacy boundary, or cross-surface route.
- No unresolved product tradeoff, external claim, security decision, or production authorization is required.
- The role can run the required verification and report skipped evidence honestly.

If any condition fails, use an L2 coordinator. A small diff is not automatically an L1 task: changes to shared contexts, public DTOs, database schema, auth, billing, or routing are coordinated work even when the code edit is short.

For L1 work, keep coordination lightweight: record only the selected role, goal,
affected surface/owner, acceptance check, and non-goals in the active context. Do
not expand the full L2 packet template, create a durable artifact, or dispatch a
subagent unless the task itself needs one.

## L2 Coordination Duties

An L2 coordinator must:

1. Preserve the user's actual goal, constraints, explicit authorization, and unresolved choices.
2. Identify the existing task route and static owner IDs before inventing a work breakdown.
3. Separate facts, decisions, assumptions, and proposals.
4. Create one bounded packet per L1 role with an explicit output and acceptance check.
5. Pass only the context needed for that packet; do not forward the full conversation or unrelated project history.
6. Order contract and skeleton decisions before dependent implementation, then place verification after the mutation owner.
7. Reconcile contradictions and return one integrated status with evidence gates kept separate.

## L2 Subagent Execution Requirement

- An L2 task must dispatch at least one bounded L1 packet through a real subagent or equivalent isolated subtask tool. Naming a role, changing voice, or performing an ordered role pass in the same agent does not satisfy this requirement.
- **Real-subagent dispatch is the default, not an upgrade.** All mainstream coding tools (Claude Code, opencode, Codex, Antigravity CLI, Grok Build, Cursor) provide native isolated-context subagents, and cheap model tiers make independent execution affordable. Same-agent role-switching (`degraded-same-agent`) is accepted only when the runtime genuinely lacks a subagent capability and the environment constraint is recorded in the packet receipt and the quality ledger; it is never the quiet default for cost convenience.
- When an L2 task changes product code, a public contract, persistence, identity, billing, privacy behavior, or runtime configuration, a `quality-engineer` subagent must independently inspect the resulting diff and relevant test evidence after the mutation owner finishes. The mutation owner cannot self-certify this packet.
- The mandatory post-implementation `quality-engineer` review satisfies the one-subagent minimum. Do not add a second exploratory or documentation subagent only to satisfy the count; dispatch another packet only when it has an independent output that changes a decision, implementation, or evidence gate.
- Use subagents for independent exploration, implementation with non-overlapping ownership, testing, log analysis, and review. Do not parallelize writes to overlapping files or dispatch work whose dependency is unresolved.
- When the host exposes per-subagent tool permissions, read-only modes, sandbox
  profiles, or isolated worktrees, encode Forbidden Zones there instead of
  relying on prose alone. A `quality-engineer` review packet is read-only by
  default; mutation tools are enabled only when test edits were explicitly
  assigned. Record the effective host restriction in the delegation receipt.
- Every packet records its execution mode and a delegation receipt with mode-specific evidence: a subagent tool/run identifier, a human handoff reference, an unavailable reason for `degraded-same-agent`, or `not-required` for L1 main-agent execution. The coordinator includes these receipts in its integrated return so subagent use can be distinguished from same-agent role passes.
- If no real subagent or isolated subtask tool is available, state the limitation before continuing, mark the affected packets `degraded-same-agent`, report the missing independence in the final evidence, and record the environment constraint in the quality ledger. Never silently present same-agent role switching as delegated or independent work. Given the 2026 tool landscape (see `references/model-capabilities-2026.md`), a tool without any subagent capability is the exception; treat repeated degraded runs as a configuration problem to fix, not a routine state.

An L2 coordinator may avoid or stop subagent dispatch only after re-running the L1 Direct Gate, reclassifying the task as `L1-direct`, recording a replacement compact L1 receipt, and marking the previous L2 packet superseded. Human handoffs remain valid when explicitly requested, but do not count as a subagent receipt.

## Subagent Risk Routing

Choose a subagent model and reasoning effort from the packet's risk, not its
role title. User-specified models win. Otherwise inherit the parent by default
and override only when the expected quality or cost difference is material.
Model tiers below are placeholders: read the actual three-tier family of the
active runtime (e.g. 2026-07/08: OpenAI Sol/Terra/Luna, Claude 5 family /
Haiku 4.5, Gemini 3.6 Flash family, Grok 4.5 tiering — see
`references/model-capabilities-2026.md`). Never hardcode a model slug; the
runtime exposes what is available.

| Risk | Signals | Preferred route |
|---|---|---|
| R0 Mechanical | Deterministic lookup, file inventory, command execution, or formatting check; no product judgment | cheapest available tier, `low` |
| R1 Bounded | One owner, accepted behavior/contract, reversible implementation or focused tests | cheapest available tier, `medium` |
| R2 Coordinated | Cross-surface behavior, shared contract/state, ambiguous root cause, or semantic QA over cross-owner/shared behavior | most capable available tier, `high` |
| R3 Critical | Identity, payment, privacy, data loss, production incident, irreversible migration, or final review where a miss has high cost | most capable available tier, `xhigh` |

Apply these constraints:

- Difficulty alone does not force the capable tier. Escalate for ambiguity, blast
  radius, evidence independence, or error cost; de-escalate deterministic work
  even when it processes many files.
- Use only models and effort values exposed by the current runtime. If a
  preferred route is unavailable, inherit the parent and record the fallback;
  never invent a model slug.
- A model or effort override requires a self-contained packet and
  `fork_turns: "none"` or a bounded positive turn count (a subagent fork capped
  at a finite number of turns). A full-history fork inherits the parent route
  and cannot be presented as an override.
- Prefer `fork_turns: "none"` when the packet contains all required C0-C4
  slices. Use a bounded recent-turn fork only when an exact recent decision is
  costly to restate. Use full history only when continuity is more valuable
  than model routing, and accept inheritance explicitly.
- Do not select the highest-cost reasoning mode by default. It requires
  explicit user direction or representative-task evidence that `xhigh` is
  insufficient.
- Record the requested route and fallback in the packet receipt. Claim an
  effective model or effort only when the subagent/tool response exposes it.

Risk can change after dispatch. If the child discovers a higher-risk boundary,
it returns `needs_reroute` with the triggering evidence; the coordinator issues
a replacement packet instead of silently continuing under the lower route.

Model-route receipt examples:

- Override requested, runtime value hidden: `requested=capable/high; fork=none;
  fallback=none; effective=not_exposed; reroute=none`.
- Preferred route unavailable: `requested=cheap/low; fork=none;
  fallback=inherit (preferred route unavailable); effective=not_exposed`.
- Full-history continuity: `requested=inherit; fork=all; fallback=none;
  effective=not_exposed`; never label this an override.
- Risk escalation: `status=needs_reroute; requested=cheap/medium;
  reroute=R1 -> R2 (shared contract discovered)`; stop mutation until the
  coordinator sends the replacement packet.

## Context Depth

Context depth controls **cost and attention quality, not access authorization**.
Grounding: 1M-token windows are now universal on flagship tiers, so
overflow is no longer the constraint — input-token metering makes full-context
packets expensive, and long windows degrade mid-context detail through
compaction and lost-in-the-middle. Use the lowest level that is sufficient for
the assigned output; pointer + conclusion beats pasted source.

Every L2 task packet includes C0. C1-C4 are explicitly selected slices, not cumulative clearance levels. The routine limit in `references/role-catalog.md` is an upper disclosure boundary; widening it requires the active coordinator to state the blocking need and does not override repository, privacy, or user authorization.

| Level | Contents |
|---|---|
| C0 Request | Exact user goal, observed symptom, constraints, explicit authorization, and requested outcome. |
| C1 Behavior | Affected surface, current and target behavior, acceptance criteria, non-goals, and owning product sources. |
| C2 Contract | Static owner IDs, state transitions, API/DTO/schema/persistence effects, mutation paths, and cross-surface dependencies. |
| C3 Implementation | Relevant files, comparable patterns, tests, commands, sanitized logs, risks, and known worktree state. |
| C4 Release | Build/CI, deployed version, authenticated browser evidence, payment/provider evidence, monitoring, rollback, and residual production risk. |

Context packets must prefer pointers and short evidence excerpts over copied documents. Never include secrets, credentials, raw personal data, unrelated user content, hidden prompts, or unredacted production logs. C4 evidence requires task relevance and the same authorization that the underlying production action requires.

## Role Knowledge Duty

Each catalog role has one derived snapshot at `knowledge/<role-id>.md`. The
snapshot is the **repository's shared fact layer**: a functional knowledge
lens readable by any agent, session, or tool — not a persistent persona, a
personal memory substitute (tool-native memory is better at that), a new
source of truth, code owner, permission grant, or substitute for reading the
task's canonical sources. What a snapshot stores survives context compaction;
what a model merely "remembers" does not.

- After role selection, read only the selected role snapshot and any snapshots an L2 coordinator needs to reconcile; do not preload all role knowledge into every packet.
- At task closure, resolve changed owner IDs through `doc-ownership.yaml`. For every triggered owner, update at least one snapshot named in that owner's `knowledge_roles`. The active routing role owns semantic completeness: the executing role for L1-direct work, or the coordinator for L2 work; it must add every other role whose accepted output or assumptions changed. A narrowly controlled `[knowledge-na]` waiver is available only through `workflows/update-role-knowledge.md` when one feature surface changed but no durable behavior, contract, evidence, ownership, or role fact changed; it never applies to infra, contract, governance, or multi-surface work.
- Keep facts within the role's routine context limit. Wider source reading for one task does not permanently widen what its snapshot may retain.
- Replace superseded facts, keep source pointers, mark conflicts or missing evidence under `Known Drift And Unknowns`, and retain at most five concise `Recent Deltas`; Git history is the full audit trail.
- Never persist the raw C0 request, secrets, credentials, personal data, user content, hidden prompts, or unredacted logs in role knowledge.
- A knowledge update records awareness, not completion. It must preserve separate implementation and evidence gates and may explicitly say that no production verification occurred.
- A test, build, deployment, browser, payment, provider, database, monitoring, or rollback evidence change can require a knowledge refresh even when no repository owner path changed; use the evidence-only lane in the workflow.

Follow `workflows/update-role-knowledge.md`; `scripts/check-doc-sync.sh` supplies
the deterministic minimum gate. A stale placeholder no longer satisfies the
gate: the touched snapshot needs a captured date, repository baseline,
source-backed facts, and a dated Recent Delta. A passing gate still proves only
this structural minimum, not that every statement is semantically correct;
high-risk owners still need independent review or sampling.

## Completion Boundary

- L1 closes only when its compact receipt acceptance check passes or it returns a concrete blocker with unreached checks.
- L2 closes only when all required packets are reconciled, cross-role conflicts are resolved or surfaced to the user, and the integrated verification state is explicit.
- Keep `implemented`, `tested`, `built`, `deployed`, `browser-verified`, `payment-verified`, and `provider-verified` as separate claims. One does not imply another.
