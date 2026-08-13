# Role Matcher

Deterministic role selection from the request envelope, so role dispatch does
not depend on the main agent's memory of `references/role-catalog.md`. It is a
protocol first and an optional script second: the three tiers below define the
decision procedure; `scripts/select-role.sh` executes the same rules against a
request text for agents that support scripted routing.

## Inputs

Only signals that are already in the request envelope (see
`workflows/requirement-triage.md` step 1):

- request type: `new_requirement | behavior_change | bug | contract | docs | release`
- affected surface and static owner (`id | not_applicable | unmapped`)
- contract / auth / billing / privacy impact
- ambiguity, root-cause stability, production exposure
- scope width (how many functional roles the work would need)

## Matching Tiers

Evaluate in order; the first tier that produces a result wins.

### T1 — Hard Signals (always decisive)

| Signal in the envelope | Route |
|---|---|
| Public API, shared type/state, schema, auth, billing, privacy, identity, or multi-end contract change | `contract-coordinator` L2 |
| Unstable reproduction, unknown owner, data-loss risk, or production-only failure | `incident-coordinator` L2 |
| Ambiguous scope, second surface, or more than one functional role required | `change-coordinator` L2 |
| Accepted wording/index/reference maintenance only | `docs-governor` L1 |
| Explicitly authorized single-boundary release | `release-engineer` L1 |
| New unmapped surface (`unmapped`) | `change-coordinator` L2, then owner-map update |

### T2 — Request Shape (when no hard signal fired)

| Request shape | Role |
|---|---|
| Requirement wording, scope, acceptance criteria, non-goals, spec delta | `product-analyst` L1 |
| Design-only single-surface interaction/copy decision | `experience-designer` L1 |
| Single-surface copy/UI tweak that requires code and tests | `frontend-engineer` L1 |
| Single-owner frontend or backend change under an accepted contract | `frontend-engineer` / `backend-engineer` L1 |
| Diagnosis or verification request only (reproduce, test design, evidence review) | `quality-engineer` L1 |
| Bounded API/DTO/schema/state design only, no consumers mutated | `contract-architect` L1 |
| Reproducible bug, known single owner, no shared-contract impact | owning L1 engineer |

### T3 — L1 Direct Gate Recheck

Run the candidate through the L1 Direct Gate in `rules/role-boundaries.md`.
If any condition fails, promote to the matching L2 coordinator from the
escalation map in `references/role-catalog.md`.

## Priority And Conflict Rules

1. T1 beats T2: a contract change is coordinated even when the code edit looks
   like one role's work.
2. Two or more distinct T2 candidates for one request -> L2
   (`change-coordinator`; `contract-coordinator` when a contract signal is
   present).
3. `unmapped` surface always forces L2 plus an owner-map update before
   implementation.
4. When no tier produces a confident result, default to `change-coordinator`
   L2 and surface the open decision to the user — do not guess an L1 role.
5. `quality-engineer` never becomes the routing role for implementation work;
   it is the routing role only for diagnosis/verification-only requests.

## Output Contract

Every dispatch records:

```
- Role: <role-id>
- Tier: T1 | T2 | T3
- Signal: <the decisive envelope signal>
- Confidence: high | medium | low
- Reason: <one line>
- L1 Gate: pass | fail -> promoted to <L2 role>
```

Script mode (`scripts/select-role.sh`) emits the same fields as JSON with all
candidate matches and their confidence, so a coordinator can reconcile
instead of trusting one hardcoded answer.

## Self-Test

`bash scripts/select-role.sh --self-test` runs a fixed table of request texts
against expected roles and fails loudly on any mismatch. Run it after editing
the matching rules.
