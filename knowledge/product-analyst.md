---
role_id: product-analyst
tier: L1
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Product Analyst

## Current Knowledge

- This repository is the distributable role-governance skill itself, not a host product. Product-analyst work here means structuring requirements about governance rules, role definitions, matcher behavior, workflow semantics, context limits, and risk routing.
- The product-analyst routes at T2 on request_type in {new_requirement, behavior_change} or text matching requirement|acceptance criteria|non-goal|spec wording|scope of (and Chinese equivalents 需求|验收标准|非目标|范围定义). Two self-test cases cover this role: 'new requirement: define acceptance criteria...' and 'spec wording and non-goals for the export page'.
- Product-analyst may decide classification and requirement clarity inside explicit user intent. It must not decide new commercial promises, priority tradeoffs, technical shape, or implementation success. Required return: accepted behavior, non-goals, open decisions, owning artifact.
- Context limit is C0-C1; C2 summary only when feasibility matters. The L1 compact receipt format is: Role, Goal, Surface/Owner, Acceptance, Non-goals.
- The single owner in doc-ownership.yaml is governance-skill (kind: governance), covering all paths (SKILL.md, rules/**, workflows/**, references/**, knowledge/**, scripts/**, templates/**, tests/**). Product-analyst is listed as an eligible knowledge_role on this owner.
- T1 hard signals always preempt T2 product-analyst routing: contract/auth/billing/privacy impact, production risk, ambiguity, multi-role scope, or unmapped surface all promote to an L2 coordinator before product-analyst can activate.
- After work, the role must self-update knowledge/product-analyst.md and pass scripts/check-doc-sync.sh --dirty before closing. The doc-sync gate verifies at least one eligible snapshot per changed owner is in the change set.

## Source Pointers

- `references/role-catalog.md (product-analyst row, L1 table, routing notes, escalation map)`
- `references/role-matcher.md (T2 request-shape table, priority/conflict rules, output contract)`
- `workflows/requirement-triage.md (request envelope fields, L1/L2 selection, compact receipt format, routing table)`
- `scripts/select-role.sh (requirement_shape variable, add_candidate product-analyst block, self-test cases)`
- `workflows/role-self-maintenance.md (self-audit/self-fetch/self-update lifecycle)`
- `workflows/update-role-knowledge.md (snapshot refresh procedure and controlled no-knowledge-delta lane)`
- `doc-ownership.yaml (governance-skill owner, knowledge_roles list)`
- `SKILL.md (core loop, file map, rule priority)`

## Known Drift And Unknowns

- No existing product-analyst snapshot existed before this bootstrap; all facts are drawn from current canonical sources at baseline ba715e3.
- The self-test table has only two product-analyst cases; edge-case coverage for requirement-shape detection (e.g., Chinese-only phrasing, mixed requirement+implementation requests) is narrow.
- Product-analyst work in a governance-skill repository (as opposed to a host product repository) has no prior precedent in the self-test table or workflow examples -- the role's fit for governance-rule requirement structuring is inferred from the catalog description, not from recorded usage.

## Update Triggers

- Changes to the T2 requirement_shape keywords or product-analyst candidate logic in scripts/select-role.sh.
- Changes to the product-analyst row in references/role-catalog.md (scope, context limit, required return, or escalation map).
- Changes to the L1 compact receipt format or request envelope fields in workflows/requirement-triage.md.
- New self-test cases added for product-analyst routing in scripts/select-role.sh.
- Changes to doc-ownership.yaml that add or remove product-analyst from knowledge_roles or alter the governance-skill owner scope.

## Recent Deltas

- 2026-08-16: initial bootstrap of product-analyst snapshot from canonical sources at baseline ba715e3; no prior snapshot existed.
