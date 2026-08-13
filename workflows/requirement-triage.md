# Requirement Triage And Role Dispatch

Run this pre-step for new requirements, behavior changes, API/contract changes, and bug fixes before the route's normal workflow. It selects a processing role; it does not replace the project's own task routing, bug, or planning workflows.

## Read First

- `rules/role-boundaries.md` for L1/L2 gates, authority, and context depth
- `references/role-catalog.md` to select a role and enforce its routine context limit
- `doc-ownership.yaml` and the project's system map for static owners and affected surfaces

## 1. Build The Request Envelope

Record the smallest complete C0-C1 envelope in the current task context:

- request type: `new_requirement | behavior_change | bug | contract | docs | release`
- exact goal or symptom, current behavior, target outcome, acceptance check, and non-goals
- affected surface or `unknown`; explicit user constraints and external-action authorization
- known evidence, source-of-truth pointers, assumptions, and unresolved decisions

Do not create a new workflow-state directory. Persist the envelope only when the existing artifact chain already requires a SPEC, plan, task/issue, change-delta record, or handoff.

## 2. Match Existing Route And Owner

1. Match the project's own task routing and continue to its declared workflow after this pre-step.
2. Identify the user-action surface from the project's system map.
3. Resolve static owner IDs from `doc-ownership.yaml`; use `not_applicable` for governance-only work, or `unmapped` for a new surface and force L2 plus an owner-map update before implementation. Never infer ownership from the role catalog.
4. If the request conflicts with an active source of truth, surface the conflict before dispatch.

## 3. Choose L1 Or L2

Identify the routing role first, then apply the L1 Direct Gate in
`rules/role-boundaries.md`:

1. Run the matcher: `references/role-matcher.md` for the protocol, or
   `bash scripts/select-role.sh < request.txt` for the executable table
   (`--self-test` after edits).
2. Reconcile the matcher output against the request envelope and the default
   routing table below. The matcher narrows; the coordinator decides.
3. Apply the L1 Direct Gate:

- All conditions pass -> select one L1 role, record the compact L1 receipt below, and continue directly.
- Any condition fails -> select exactly one L2 coordinator, let it produce bounded L1 packets, and apply the L2 subagent execution requirement in `rules/role-boundaries.md`.

After selection, the active role reads `knowledge/<role-id>.md` and follows
`workflows/role-self-maintenance.md` (self-audit before work, self-update
after work). An L2 coordinator reads its own snapshot first, then gives each
child only that child's relevant snapshot pointers; role knowledge is not
permission to skip current source verification.

| Request shape | Default routing |
|---|---|
| Clear single-output requirement or SPEC wording | `product-analyst` L1 |
| Design-only single-surface interaction/copy decision | `experience-designer` L1 |
| Accepted single-surface copy/UI tweak that requires code and tests | `frontend-engineer` L1 |
| Clear single-owner frontend or backend change under an accepted contract | `frontend-engineer` or `backend-engineer` L1 |
| Ambiguous, cross-surface, or multi-role feature/change | `change-coordinator` L2 |
| Public API, shared type/state, schema, auth, billing, privacy, or multi-end change | `contract-coordinator` L2 |
| Reproducible bug with a known single owner and no shared-contract impact | Owning L1 engineer; `quality-engineer` L1 when the request is diagnosis/verification only |
| Unknown, intermittent, cross-owner, production, auth, billing, or data-risk bug | `incident-coordinator` L2 |
| Accepted wording/index/reference maintenance only | `docs-governor` L1 |
| Task routing configuration, role definitions, or activation semantics change | `change-coordinator` L2 with `docs-governor` packet |
| Explicitly authorized single-boundary release | `release-engineer` L1; coordinate when multiple runtime/evidence owners are required |

## 4. Record L1 Or Issue An L2 Task Packet

L1 direct work uses a compact receipt in the active context; do not expand it
into coordination boilerplate:

```md
- Role: <role-id>
- Goal: <one observable outcome>
- Surface / Owner: <surface>; <owner id>
- Acceptance: <one verification path>
- Non-goals: <explicit exclusions or none>
```

Every L2 dispatch uses the full packet contract below. Keep it in the active
task unless an existing artifact chain already requires persistence.

```md
## Task Packet: <id>
- Mode: L2-coordinated
- Role: <role-id>
- Parent / Return To: <request-or-coordinator>
- Execution Mode / Delegation Receipt: subagent (default) | main-agent | human-handoff | degraded-same-agent; <tool/run id | not-required | handoff reference | unavailable reason + ledger record>
- Risk Route / Model Plan: R0 | R1 | R2 | R3; inherit | override; <model>; <reasoning effort>; <fork_turns>; <routing rationale>
- Affected Surface / Owner Status: <surface>; <owner ids | not_applicable | unmapped>
- Knowledge File / Impact: <knowledge/role-id.md>; <owner ids whose durable knowledge may change>
- Context Depth: C0 + named C1-C4 slices
- Dependencies: <packet ids or none>
- Decision State / Open Decisions / Assumptions: decided | assumed | needs_decision; <explicit list or none>
- Required Evidence Gates: <test/build/deploy/browser/payment/provider subset>

### Goal
<one observable outcome>

### Inputs
<minimum source pointers, facts, decisions, and relevant evidence>

### Outputs
<artifact, code, diagnosis, review, or evidence to return>

### Forbidden Zones
<out-of-scope files, decisions, mutations, data, and evidence claims>

### Acceptance Criteria
<commands, scenarios, review rules, and required status gates>
```

L2 coordinators must tailor Inputs by role: behavior plus relevant client contracts for frontend; behavior plus contract/persistence for backend; current-versus-target scenarios and risk for QA; accepted decisions and artifact impact for docs. Do not copy the complete parent context into every packet.

During an L2 task, dispatch at least one L1 packet through a real subagent or equivalent isolated subtask tool before completion and record its receipt. Real-subagent dispatch is the default: mainstream tools provide native isolated-context subagents and cheap tiers make it affordable (see `rules/role-boundaries.md` and `references/model-capabilities-2026.md`). Respect packet dependencies; for mutation work covered by the independent-review rule, the mandatory `quality-engineer` subagent runs after the relevant implementation and tests and may satisfy the L2 dispatch requirement. If delegation is genuinely unavailable in the runtime, announce the degradation before same-agent execution, preserve the unavailable reason in every affected packet, and record the environment constraint in the quality ledger.

Do not dispatch an additional packet merely to increase agent count. Add a
second subagent only when it owns a distinct decision, non-overlapping
implementation slice, investigation, or evidence gate.

## 5. Order And Reconcile L2 Work

- Change: product outcome -> interaction when needed -> contract/skeleton -> implementation -> QA -> docs.
- Contract: canonical contract and owner -> migration/backend -> consumers -> cross-side tests -> docs -> authorized rollout.
- Incident: reproduce/observe -> isolate owner or rank hypotheses -> bounded fix -> regression -> authorized release evidence.
- Parallelize only packets with independent files, no unresolved dependency, and independently testable outputs.

Each return packet states `done | blocked | needs_decision | needs_reroute`, execution mode and delegation receipt, outputs or changes, evidence by gate, assumptions, residual risk, and the next recipient. Its model-route receipt must include `requested model/effort`, `fork_turns`, `fallback: none | inherit + reason`, `effective: <model/effort> | not_exposed`, and `reroute: none | <old risk -> new risk + trigger>`. The coordinator rejects results that exceed Forbidden Zones, lack required evidence, or contradict the accepted contract. The integrated return lists all receipts and states whether independent QA was completed, not required, or degraded.

If a child returns `needs_reroute`, preserve its evidence, reclassify the risk,
and issue a replacement packet. Do not let the child silently raise its own
authority, model cost, context depth, or mutation scope.

## Completion Checklist

- [ ] Request envelope preserves the user's goal, constraints, and authority
- [ ] Existing route, affected surface, and owner status (`id | not_applicable | unmapped`) are named
- [ ] Matcher ran (or its tiers were applied manually); one routing role is explicit with tier, signal, confidence
- [ ] L1 Direct Gate was applied; the chosen role survives it or was promoted
- [ ] L1 used the compact receipt, or every L2 child received minimum sufficient context and a complete packet
- [ ] Every L2 task has at least one real subagent receipt, or an explicit pre-execution degradation record
- [ ] Every subagent packet records its risk route, model/effort plan, fork strategy, and any fallback or reroute
- [ ] Covered L2 mutation work received independent `quality-engineer` subagent review, or the missing independence is reported
- [ ] Returned results were reconciled in dependency order
- [ ] Implemented, tested, built, deployed, browser, payment, and provider evidence remain separate
- [ ] Impacted snapshots were refreshed or marked stale through `workflows/role-self-maintenance.md`
- [ ] The project's own workflow for the matched route was completed
