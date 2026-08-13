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
    "review": "quality-engineer subagent, run 3f9a2c1d"
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

Never record secrets, credentials, personal data, user content, or unredacted
logs.

## 3. Append

```bash
echo '<entry json>' | bash skills/project-rules/scripts/quality-ledger.sh --add
```

The entry lands in `<skill-dir>/ledger/YYYY-MM.jsonl`. Ledger files are
committed like any other durable record — git is the audit trail, so entries
are append-only and never edited in place.

## 4. Aggregate

```bash
bash skills/project-rules/scripts/quality-ledger.sh --summary      # human-readable
bash skills/project-rules/scripts/quality-ledger.sh --summary --json
bash skills/project-rules/scripts/quality-ledger.sh --routes       # unverified routes
```

The summary reports:

- **GO rate** — share of independent reviews that passed. This is the core
  quality signal. A dropping GO rate means process or implementation quality
  is degrading before defects reach users.
- **issue count** — problems found by independent review across entries.
- **route-verify rate** — share of tasks with a human AAR confirming the
  routing role. Low verify rate means routing quality is unmeasured, not good.
- **role distribution** — where work actually lands; drift from expectation
  signals the routing table or matcher needs tuning.

## 5. Reading The Signals

- GO rate consistently high + high verify rate: the process is producing
  acceptable work; keep sampling.
- NO-GO or PARTIAL on the same role repeatedly: that role's packet inputs,
  acceptance criteria, or the matcher's T2 rules need a fix, not more process.
- Unverified routes accumulating: schedule AAR sampling on the next tasks
  (10-20%) before trusting the routing layer.
- Role distribution diverging from the project's work mix: check whether the
  matcher keywords match the actual request vocabulary in this repo.

## 6. Self-Test

```bash
bash skills/project-rules/scripts/quality-ledger.sh --self-test
```

Runs a fixed 3-entry ledger through add/summary/routes and fails loudly on any
mismatch. Run after editing the script.

## Completion Criteria

- [ ] Every L2 task has a ledger entry with an honest `qa.status`
- [ ] Routing `verified` reflects the actual AAR state; false entries carry an `expected_role`
- [ ] Ledger files are committed; no in-place edits
- [ ] Summary is checked at least weekly and per-release
