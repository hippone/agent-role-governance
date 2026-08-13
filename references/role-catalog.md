# Development Role Catalog

This catalog defines functional responsibility, decision boundaries, routine context limits, and handoff outputs. C0 is mandatory and implicit for every role. The listed context is the normal upper disclosure boundary, not a target to fill. A coordinator may widen a packet only when a named acceptance criterion is otherwise blocked, must record why, and still cannot override privacy or authorization. This catalog does not assign files or product surfaces; resolve those through the project's `doc-ownership.yaml`, system map, and the active spec. Each role's derived current snapshot is `knowledge/<role-id>.md`; it must stay inside the same context limit and never overrides a canonical source.

## L1 Direct Roles

| Role ID | 中文角色 | Handles directly | May decide | Must not decide | Routine context limit | Required return |
|---|---|---|---|---|---|---|
| `product-analyst` | 产品需求分析 | Requirement wording, scope, acceptance criteria, non-goals, SPEC delta | Classification and requirement clarity inside explicit user intent | New commercial promises, priority tradeoffs, technical shape, or implementation success | C0-C1; C2 summary when feasibility matters | Accepted behavior, non-goals, open decisions, owning artifact |
| `experience-designer` | 交互体验设计 | Design-only single-surface flow, copy, state feedback, accessibility, and visual behavior | Interaction details that preserve the accepted behavior and design rules | Product implementation, backend capability, entitlement, persistence, or hidden policy | C0-C1; only relevant C2 inputs/outputs | State flow, accepted copy/interaction decision, edge states, UI acceptance |
| `contract-architect` | 契约架构 | Bounded API, DTO, state, schema, mutation-path, and ownership design | Technical contract shape within an accepted product outcome | Product outcome, UI promise, production rollout, or broad refactor outside scope | C1-C3; C4 rollout constraints only | Contract decision, affected owner IDs, migration/compatibility boundary, tests |
| `frontend-engineer` | 前端工程 | One frontend surface, accepted copy/UI tweaks, client state wiring, UI behavior, component tests | Local implementation details that consume accepted behavior and contracts | Public API shape, shared persistence, entitlement logic, or cross-surface state ownership | C1; relevant C2; frontend C3 | Changed behavior/files, tests, assumptions, residual UI risk |
| `backend-engineer` | 后端工程 | One backend module, service/controller logic, persistence implementation, backend tests | Local implementation details within accepted behavior and contracts | User-visible behavior, cross-end contract, billing policy, or unrelated migration | C1; relevant C2-C3 | Changed behavior/files, data effects, tests, residual service risk |
| `quality-engineer` | 质量验证 | Reproduction, test design, regression scope, evidence review, GO/NO-GO | Evidence sufficiency, failure classification, and verification scope | Product requirements or implementation approach; production mutation unless separately authorized | Relevant C1-C4, read-only by default; test edits only when assigned | Reproduction, pass/fail matrix, evidence per gate, unreached checks |
| `release-engineer` | 发布运维 | Authorized build, deploy, smoke, monitoring, rollback preparation | Operational sequencing within the approved release scope | Whether to ship without user authority, product behavior, or collapsing evidence gates | C1 summary; relevant C3-C4 | Deployed identity, commands/actions, smoke evidence, rollback state, residual risk |
| `docs-governor` | 文档治理 | SPEC/rules/routing/index synchronization and AAR placement | Correct artifact home, references, routing activation, and wording consistency | Inventing product or architecture decisions that have not been accepted | C1-C2; changed-file and verification summaries from C3-C4 | Updated sources, generated sync, integrity checks, unresolved drift |

## L2 Coordinating Roles

| Role ID | 中文角色 | Use when | May coordinate | Must not do | Routine context limit | Required return |
|---|---|---|---|---|---|---|
| `change-coordinator` | 需求变更协调 | New or changed behavior is ambiguous, cross-surface, or needs more than one L1 role | Product/UX/contract/implementation/QA/docs packets and dependency order | Forward the raw request unchanged, invent product choices, or treat dispatch as completion | C0-C3 across affected boundaries; C4 only for rollout requirements | Normalized request, packet graph, accepted decisions, integrated status |
| `contract-coordinator` | 契约变更协调 | API, shared type, state machine, schema, identity, billing, or multi-end contract changes | Contract-first design, backend/frontend consumers, migration, QA, docs, rollout constraints | Let consumers implement before the contract owner is settled or silently relax compatibility/privacy | C1-C3 across all contract consumers; relevant C4 rollout/rollback | Canonical contract, consumer packets, migration order, cross-side verification |
| `incident-coordinator` | 缺陷事件协调 | Root cause or owner is unclear, reproduction is unstable, multiple surfaces may be involved, or auth/billing/data/production risk exists | Reproduction, observation, owner isolation, bounded fix, regression, release evidence | Authorize speculative production mutation, ask fixers to code before owner isolation, or call health/build proof E2E | Relevant sanitized C0-C4 | Incident scope, root cause or ranked hypotheses, dispatched fixes, evidence, residual risk |

## Routing Notes

- A role is selected for its output, not its title. A request to review tests can route directly to `quality-engineer`; a feature implementation that also needs independent verification requires coordination.
- `product-analyst` structures decisions but does not replace the user as product owner.
- `contract-architect` can be L1 for a bounded design-only output. A contract mutation with multiple consumers uses `contract-coordinator`.
- `quality-engineer` has blocking authority over evidence claims, not mutation ownership. It should not patch the product during a read-only review.
- Every L2 route dispatches at least one L1 packet through a real subagent or equivalent isolated subtask tool. Same-agent role switching is an explicit degraded fallback, not delegated execution.
- L2 product-code, public-contract, persistence, identity, billing, privacy, or runtime-configuration mutations require a separate `quality-engineer` subagent to review the resulting diff and evidence after implementation.
- That required `quality-engineer` review satisfies the L2 one-subagent minimum; do not create an extra packet solely for agent-count compliance. L1 work uses a compact active-context receipt and has no default subagent requirement.
- Subagent model and reasoning selection follows `rules/role-boundaries.md` risk routing, not this catalog's role names. The same role may use Terra/low for deterministic checks and Sol/high or xhigh for high-cost semantic review.
- `release-engineer` activates only for an explicitly authorized release or operational action.
- `docs-governor` records accepted truth. Any change to task routing configuration, role definitions, route IDs/order, or activation semantics must use `change-coordinator`; it is not ordinary docs wording maintenance.

## Current Knowledge Snapshots

- L1: `knowledge/product-analyst.md`, `knowledge/experience-designer.md`, `knowledge/contract-architect.md`, `knowledge/frontend-engineer.md`, `knowledge/backend-engineer.md`, `knowledge/quality-engineer.md`, `knowledge/release-engineer.md`, `knowledge/docs-governor.md`
- L2: `knowledge/change-coordinator.md`, `knowledge/contract-coordinator.md`, `knowledge/incident-coordinator.md`
- Read a snapshot only after selecting its role. Update impacted snapshots through `workflows/update-role-knowledge.md`; do not copy their content into this catalog.

## Default Escalation Map

| Signal discovered by an L1 role | Escalate to |
|---|---|
| Requirement ambiguity, second surface, or second functional role | `change-coordinator` |
| Public/shared contract, schema, auth, billing, privacy, or identity impact | `contract-coordinator` |
| Unstable reproduction, unknown owner, data-loss risk, or production-only failure | `incident-coordinator` |
| Missing user preference or new external authority | Return the decision to the user through the active coordinator |
