# Quality Ledger

Turn task-level receipts into measurable quality signals. The ledger is a
JSONL file — one JSON object per line, appended after each L2 task — and it is
the only place where the process proves itself instead of claiming it.

## 1. When To Record

Append one entry after every completed L2 task, and optionally for L1 tasks
that had a `quality-engineer` review:

- the mandatory post-implementation `quality-engineer` subagent review
  finished (GO / NO-GO / PARTIAL);
- or the L2 coordinator reconciled the packets and an independent review was
  skipped or degraded (record that honestly);
- or a human AAR confirmed or corrected the routing role.

## 2. Entry Schema

```json
{
  "id": "T-104",
  "date": "2026-08-13",
  "routing": {
    "role": "change-coordinator",
    "tier": "T2",
    "verified": true,
    "expected_role": "backend-engineer"
  },
  "qa": {
    "status": "NO-GO",
    "issues": 2,
    "severity": "high",
    "review": "quality-engineer subagent",
    "review_verified": true,
    "review_ref": "3f9a2c1d.json"
  },
  "metrics": {
    "input_tokens": 12000,
    "output_tokens": 2400,
    "cycle_seconds": 900,
    "human_review_minutes": 8,
    "rework_count": 1,
    "escaped_defects": 0
  }
}
```

Fields:

- `id` (required): task or packet identifier.
- `date` (optional, defaults to today).
- `routing.role` (required): the routing role that was dispatched.
- `routing.tier`: T1 | T2 | T3.
- `routing.verified`: `true` after a human AAR confirmed the route; `false`
  plus `expected_role` when the AAR found a better role. Absent when no AAR
  ran yet.
- `qa.status` (required): `GO` | `NO-GO` | `PARTIAL`.
- `qa.issues`: count of issues the review found.
- `qa.severity`: low | medium | high | critical.
- `qa.review`: how the review was performed (subagent run id, degraded, skipped).
- `qa.review_verified`: whether the referenced receipt was checked against a
  runtime transcript or another host-exposed record. Omit or set false when
  the runtime cannot verify it.
- `qa.review_ref`: transcript/run reference; required when
  `review_verified: true`. It must be a safe relative file path under the
  host-provided `QUALITY_LEDGER_RECEIPT_DIR`; the ledger refuses a verified
  claim when that file does not exist.
- `metrics` (optional): non-negative cost/outcome observations. Supported
  fields are `input_tokens`, `output_tokens`, `cost_usd`, `cycle_seconds`,
  `human_review_minutes`, `rework_count`, `escaped_defects`, and
  `rollback_count`.

Never record secrets, credentials, personal data, user content, or unredacted
logs.

## 3. Append

```bash
export QUALITY_LEDGER_RECEIPT_DIR=.workflow/subagent-receipts
echo '<entry json>' | bash scripts/quality-ledger.sh --add
```

The entry lands in `<skill-dir>/ledger/YYYY-MM.jsonl`. IDs are unique across
all ledger files; invalid schema, duplicate IDs, and existing corrupt rows
block append. Ledger files are
committed like any other durable record — git is the audit trail, so entries
are append-only and never edited in place.

## 4. Aggregate

```bash
bash scripts/quality-ledger.sh --summary      # human-readable
bash scripts/quality-ledger.sh --summary --json
bash scripts/quality-ledger.sh --routes       # false or not-yet-reviewed routes
```

The summary reports:

- **GO rate** — share of recorded reviews that passed. This is a process
  signal, not proof of product quality. A drop is a prompt to investigate;
  interpret it with task risk, receipt verification, rework, and escaped defects.
- **issue count** — problems found by independent review across entries.
- **route-verify rate** — share of tasks with a human AAR confirming the
  routing role. Low verify rate means routing quality is unmeasured, not good.
- **role distribution** — where work actually lands; drift from expectation
  signals the routing table or matcher needs tuning.
- **receipt verification** — how many review references were actually checked.
- **optional cost/outcome totals** — evidence for whether avoided rework and
  defects outweigh orchestration cost. GO rate alone is not an outcome KPI.

## 5. Reading The Signals

- GO rate consistently high + high route/receipt verification: the recorded
  review process is stable; confirm with rework and escaped-defect outcomes.
- NO-GO or PARTIAL on the same role repeatedly: that role's packet inputs,
  acceptance criteria, or the matcher's T2 rules need a fix, not more process.
- Unverified routes accumulating: schedule AAR sampling on the next tasks
  (10-20%) before trusting the routing layer.
- Role distribution diverging from the project's work mix: check whether the
  matcher keywords match the actual request vocabulary in this repo.

## 6. Self-Test

```bash
bash scripts/quality-ledger.sh --self-test
```

Runs a fixed ledger through add/summary/routes and verifies rejection of an
invalid tier, non-numeric issue count, and duplicate ID.

## Completion Criteria

- [ ] Every L2 task has a ledger entry with an honest `qa.status`
- [ ] Invalid schema, duplicate IDs, missing verified receipts, and corrupt
      existing rows fail loudly
- [ ] Routing `verified` reflects the actual AAR state; false entries carry an `expected_role`
- [ ] `qa.review_verified: true` is used only when the referenced receipt file
      exists under `QUALITY_LEDGER_RECEIPT_DIR`
- [ ] Ledger files are committed; no in-place edits
- [ ] Summary is checked with cost, rework, and escaped-defect outcomes; GO rate
      is not used alone as a quality KPI
