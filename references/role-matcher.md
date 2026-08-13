# Role Matcher

Deterministic role selection from the request envelope, so role dispatch does
not depend on the main agent's memory of `references/role-catalog.md`. It is a
protocol first and an optional script second: the three tiers below define the
decision procedure. `scripts/select-role.sh --envelope` executes the rules from
a structured JSON request envelope. Plain-text mode remains a compatibility
candidate generator and marks L1 results `needs_envelope_recheck`; it must not
be treated as final authorization or scope proof.

## Inputs

Envelope mode accepts a JSON object with signals already resolved during
`workflows/requirement-triage.md` step 1:

- request type: `new_requirement | behavior_change | bug | contract | docs | release`
- affected surface and static owner (`id | not_applicable | unmapped`)
- contract / auth / billing / privacy impact
- ambiguity, root-cause stability, production exposure
- scope width (how many functional roles the work would need)

Canonical fields are `request_type`, `goal` or `text`, `owner_status`,
`scope_width`, `functional_roles`, `ambiguous`, `contract_impact`,
`auth_impact`, `billing_impact`, `privacy_impact`, `identity_impact`,
`schema_impact`, `shared_state_impact`, `production_exposure`,
`data_loss_risk`, `root_cause_unknown`, `docs_only`, `diagnosis_only`,
`design_only`, and `release_authorized`. Boolean impact fields express actual
semantic impact, not mere keyword presence.

```bash
printf '%s\n' '{
  "request_type": "behavior_change",
  "goal": "show refund state on account page",
  "billing_impact": true,
  "scope_width": 2,
  "functional_roles": ["backend-engineer", "frontend-engineer"]
}' | bash scripts/select-role.sh --envelope
```

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

Text-mode failsafe: a protected-domain term (auth, billing, payment, privacy,
identity, schema, shared contract) whose action verb the matcher does not
recognize still routes to `contract-coordinator` (medium confidence) unless
the request is docs-only, presentation-only, diagnosis-only, or design-only.
An unparseable action in a protected domain over-escalates to a coordinator;
it never falls through to an L1 candidate. Envelope mode does not use this
fallback — its boolean impact fields carry the semantic answer directly.

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

Both script modes emit these fields as JSON. Envelope mode can return a final
`pass` or promotion result. Text mode includes candidates but reports
`needs_envelope_recheck` for an apparent L1 route, so a coordinator cannot
mistake keyword matching for a completed L1 Direct Gate.

## Self-Test

`bash scripts/select-role.sh --self-test` runs English, Chinese, negation,
multi-candidate, protected-domain, noun-fallback, release-authorization, and
structured envelope cases against expected roles. Run it after editing
matching rules.
