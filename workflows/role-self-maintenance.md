# Role Self-Maintenance

Roles own their knowledge instead of waiting for a gate to complain. Every
selected role runs three moments on its own: **self-audit** before work,
**self-fetch** during work, and **self-update** after work. The
`check-doc-sync.sh` gate then becomes a backstop for what the role already did,
not the primary enforcement.

## 1. Self-Audit (before work)

After role selection, the role reads its own `knowledge/<role-id>.md` and
checks whether it is still valid before executing:

1. Read the snapshot's `Update Triggers` and `Known Drift And Unknowns`.
2. Check whether any trigger fired since `captured_on`:
   - `git log --oneline -20` for commits touching the role's surfaces
     (its `Source Pointers` and the owners that list it in `knowledge_roles`);
   - evidence changes: new/regressed tests, builds, deploys, browser checks,
     payment/provider results reported by `quality-engineer`/`release-engineer`;
   - source-of-truth changes: specs, contracts, or routing that affect the role.
3. If a trigger fired and the snapshot is stale or partial, refresh it first
   (sections 3-4) and record the refresh in the task return. A role that
   starts from a stale snapshot must not silently use it.

Fast path: when nothing fired, continue. Running the audit is a few git
commands, not a ceremony.

## 2. Self-Fetch (during work)

The role gathers what it needs from canonical sources, not from memory:

- Behavior decisions: active spec, accepted decisions, user statement.
- Contracts: the contract owner's canonical docs and implementation types,
  not the snapshot's summary.
- Evidence: run or request the actual check (test, build, browser, provider);
  a snapshot's historical pass is never current proof.
- Commands and paths live in the project's own dev docs; the snapshot holds
  pointers, not copies.

Stay inside the role's routine context limit in `references/role-catalog.md`.
If the needed context exceeds it, request a widening from the coordinator
instead of silently pulling the whole repository into the packet.

## 3. Self-Update (after work)

When the role's work changed behavior, contracts, evidence, or assumptions,
the role updates its own snapshot before returning:

1. **Frontmatter**: set `knowledge_status` to `current`, `partial` (missing
   required evidence), or `stale` (conflicting sources); refresh
   `captured_on` and `repository_baseline` (keep the last commit when the
   work is uncommitted and say so in the delta).
2. **Current Knowledge**: replace superseded statements; add compact facts the
   role needs next time. Delete instead of appending contradictions.
3. **Source Pointers**: keep the canonical paths that support the facts.
4. **Known Drift And Unknowns**: record conflicts, stale sources, unreached
   evidence gates.
5. **Update Triggers**: adjust so the next audit fires on the right changes.
6. **Recent Deltas**: prepend a concise awareness note; keep at most five,
   dropping the oldest.

Rules:

- A role updates only its own snapshot. L2 coordinators reconcile all affected
  snapshots; they never let a child rewrite another role's file.
- The update records awareness, not completion. `implemented` and
  `verified` stay separate claims.
- Never persist raw request text, secrets, credentials, personal data, user
  content, hidden prompts, or unredacted logs.
- If the task is explicitly read-only or forbids file writes, return the exact
  proposed snapshot delta as an unreached closure item instead of writing.

## 4. Backstop And Waivers

After self-update, run the deterministic gate:

```bash
bash skills/project-rules/scripts/check-doc-sync.sh --dirty
```

- A failure means at least one affected owner has no eligible snapshot in the
  change set: the active routing role assigns the missing snapshot work to the
  right role (L1 executing role or L2 coordinator), not to whichever role
  happens to be in context.
- `[docs-na]` waives only the owned-doc check. `[knowledge-na]` requires
  `[docs-na]` plus exactly one `kind: feature` owner and a shared
  no-durable-change justification; it never applies to infra, contract,
  governance, or multi-surface work.

## 5. Expired-Snapshot Sweep

When several owners were touched across commits, run
`scripts/role-snapshot-audit.sh` to find snapshots whose code moved without a
snapshot update, and assign refreshes to the owning roles:

```bash
bash scripts/role-snapshot-audit.sh --json
```

The sweep reports, per role: the last snapshot commit, the newest code commit
on its owners' paths, and a `stale` verdict. It is advisory — the semantic
review by the active routing role still decides what actually changed.

## Completion Criteria

- [ ] Self-audit ran and no unstated stale snapshot was used
- [ ] Self-fetch stayed within the role's context limit and used canonical sources
- [ ] Self-update recorded awareness with separate evidence claims
- [ ] Only own snapshots were touched (L2 reconciles the rest)
- [ ] The deterministic gate passes or a controlled waiver was recorded
- [ ] Expired snapshots outside this task's owners were reported, not silently kept
