# Role Knowledge Update Workflow

Use this workflow whenever mapped application code, contracts, release mechanics, or project-governance rules change. Role knowledge is a compact, derived current-state view; canonical rules, SPECs, code, and authorized runtime evidence still win.

## 1. Resolve Knowledge Receivers

1. List the changed paths and resolve every matching owner in `doc-ownership.yaml`.
2. For each owner, read its `knowledge_roles`. These are eligible knowledge receivers, not code owners or permissions.
3. Update at least one eligible role snapshot per triggered owner. The active routing role owns semantic completeness: the executing role in L1-direct mode or the coordinator in L2 mode. When an accepted decision, contract, implementation assumption, evidence gate, or rollout state changed for additional roles, it updates those snapshots too.
4. Unmapped application code is a blocker: use `change-coordinator`, add the static owner mapping, then select receivers.

The deterministic gate checks the minimum "at least one eligible receiver per owner." It does not replace the active routing role's semantic review across all affected roles.

### Controlled No-Knowledge-Delta Lane

Use `[knowledge-na]` only when all of these are true:

- exactly one `kind: feature` owner is affected;
- the change is formatting, comments, or presentation-only
  wording/style with no changed user action, state transition, contract,
  persistence, ownership, accepted assumption, or evidence status;
- `[docs-na]` is also present, because the same reasoning establishes that no
  owned behavior document changed;
- no `kind: infra`, `contract`, or `governance` owner is affected.

The commit gate validates the structural conditions, while the active role owns
the semantic assertion. Record the reason in the task return; do not edit a
snapshot merely to say that nothing changed. For a manual dirty-worktree check,
run:

```bash
DOC_SYNC_DOCS_NA=1 DOC_SYNC_KNOWLEDGE_NA=1 \
  bash scripts/check-doc-sync.sh --dirty
```

Never use this lane for new behavior, bug fixes, route changes, shared helpers,
API/types/schema, auth, billing, privacy, runtime configuration, release
evidence, or a change spanning multiple feature surfaces.

### Evidence-Only Lane

When current evidence changes without a repository owner path, update role knowledge directly: `quality-engineer` for test/build/CI/browser/payment/provider/database gates, `release-engineer` for deploy/runtime/rollback/backup state, and `incident-coordinator` for production faults, alerts, or recovery evidence. Add any role whose accepted assumptions changed. No synthetic code owner is required. If the active task is explicitly read-only or forbids file writes, return the exact proposed snapshot delta as an unreached closure item instead of violating that constraint.

## 2. Respect The Context Ceiling

- Keep the snapshot within the role's routine context limit in `references/role-catalog.md`.
- Store short conclusions and source pointers, not complete request history or copied source documents.
- Do not retain secrets, credentials, personal data, user content, hidden prompts, or unredacted logs.
- A one-task context widening does not permanently widen the snapshot.

## 3. Refresh The Snapshot

Keep the fixed sections in each `knowledge/<role-id>.md`:

- `Current Knowledge`: current, reusable facts required by the role.
- `Source Pointers`: canonical or implementation paths that support those facts.
- `Known Drift And Unknowns`: conflicts, stale sources, assumptions, and unreached evidence gates.
- `Update Triggers`: changes that require this role to refresh again.
- `Recent Deltas`: at most five concise awareness notes; replace the oldest when full. Git history is the complete audit log.

Replace obsolete statements instead of appending contradictory history. Set `knowledge_status` to `stale` when known sources conflict, `partial` when required evidence is missing, and `current` only when the stated evidence scope has no known gap. Update `captured_on` and `repository_baseline` when the snapshot is refreshed; if the current work is uncommitted, retain the last repository commit and say so in the delta.

## 4. Preserve Evidence Boundaries

- Repository reading may establish `implemented` facts only for the inspected tree.
- Test output, build output, deployed identity, authenticated browser behavior, payment completion, provider attribution, and database evidence are independent gates.
- If the task did not reach a gate, state `unknown` or `not verified`; do not inherit a historical pass as current proof.
- Knowledge refresh never grants deploy, production mutation, private-data access, spending, or external-contact authority.

## 5. Run The Gate

Run from the repository root. Adjust the script path when the skill is
installed elsewhere:

```bash
bash scripts/check-doc-sync.sh --dirty
```

Before a commit, stage both the implementation/docs and every selected knowledge snapshot. `--staged` and the commit hook intentionally ignore unstaged files, so an unstaged snapshot cannot create a false pass. `[docs-na]` may waive only the owned-doc requirement. `[knowledge-na]` additionally waives the role receiver only when the controlled lane above passes; otherwise it is blocking misuse.

## Completion Criteria

- Every changed mapped owner has at least one eligible snapshot in the same change set, unless the controlled single-feature `[knowledge-na]` lane passes.
- All semantically affected roles, not merely the minimum needed for the script, were considered by the active routing role.
- Evidence-only changes reached the appropriate quality, release, or incident snapshot even when no owner path changed, unless an explicit read-only constraint left the exact update as a reported closure item.
- Each updated snapshot stays within its context ceiling, points to sources, removes superseded facts, and records unknowns honestly.
- The checker passes in the mode matching the intended change set.
