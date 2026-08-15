---
role_id: quality-engineer
tier: L1
knowledge_status: current
captured_on: 2026-08-16
repository_baseline: ba715e3
evidence_scope: repository_only
context_contract: references/role-catalog.md
---

# Role Knowledge: Quality Engineer

## Current Knowledge

- This repository is the role-governance skill itself, not a host product. The quality-engineer role here validates the skill's own scripts, test suite, and ledger integrity rather than product code.
- Test orchestration lives in `tests/run.sh`: it syntax-checks all scripts (`bash -n`), then runs `select-role.sh --self-test` (50 cases: 46 text + 4 envelope), `quality-ledger.sh --self-test`, `test-doc-sync.sh` (integration fixture with temp git repo), and `check-external-facts.sh`. All four must pass for a green gate.
- quality-ledger.sh validates, appends, and aggregates JSONL quality entries. `--self-test` exercises add/summary/routes and rejects invalid tier, non-numeric issues, duplicate IDs, missing verified receipts, and corrupt existing ledger rows. Entries land in `ledger/YYYY-MM.jsonl`; IDs are globally unique across all ledger files.
- select-role.sh is the deterministic role matcher. `--self-test` runs 50 cases (46 text-mode, 4 envelope-mode) comparing actual role output against expected. Text mode is a compatibility candidate generator; envelope mode is authoritative. Protected-domain terms without a recognized action verb route to a coordinator, never fall through to L1.
- test-doc-sync.sh builds a temporary git fixture with `doc-ownership.yaml`, tests clean-baseline pass, code-only-change fail, placeholder-knowledge-update fail, and valid-knowledge-co-change pass. It also verifies the global-only installation detection path.
- The quality-engineer has blocking authority over evidence claims but not mutation ownership. L2 product-code, public-contract, persistence, identity, billing, privacy, or runtime-configuration mutations require a separate quality-engineer subagent to review the resulting diff and evidence after implementation.
- The quality ledger entry schema requires `id`, `routing.role`, and `qa.status` (GO/NO-GO/PARTIAL). `qa.review_verified: true` demands a `review_ref` path that must exist under `QUALITY_LEDGER_RECEIPT_DIR`. Summary reports GO rate, issue count, route-verify rate, role distribution, and optional cost/outcome metrics.

## Source Pointers

- `tests/run.sh`
- `tests/test-doc-sync.sh`
- `scripts/quality-ledger.sh`
- `scripts/select-role.sh`
- `workflows/quality-ledger.md`
- `references/role-catalog.md (quality-engineer row and routing notes)`
- `SKILL.md (core loop step 4, file map)`

## Known Drift And Unknowns

- No ledger entries exist yet in this repository; summary/routes aggregation is tested only via --self-test fixture data, not production records.
- Receipt verification (`qa.review_verified`) depends on the host setting `QUALITY_LEDGER_RECEIPT_DIR`; the skill repository itself has no persistent receipt directory or sample receipts outside the self-test temp dir.
- check-external-facts.sh is called in the test suite but its behavior and failure modes have not been examined in this snapshot.

## Update Triggers

- Changes to quality-ledger.sh validation rules, entry schema fields, or summary metrics.
- Changes to the self-test cases in select-role.sh or quality-ledger.sh --self-test.
- New test files added to tests/ or changes to test-doc-sync.sh fixture structure.
- Changes to the quality-engineer row in references/role-catalog.md (authority, context limit, required return).
- New scripts added to scripts/ that introduce additional gates or validation.

## Recent Deltas

- 2026-08-16: initial snapshot bootstrap from canonical sources at baseline ba715e3.
