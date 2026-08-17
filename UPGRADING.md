# Upgrading A Host Project

How to move a host project (a repo that vendored this skill) to a newer
version of agent-role-governance.

## File Classification

Every file in the skill falls into one of three migration classes. The
classification is stable across versions; only the contents change.

### Class A — Overwrite (mechanism files, never host-specific)

Copy from upstream, replacing the host copy. These are pure mechanism: no
host knowledge, no host paths (they auto-detect install location).

| Path | Notes |
|---|---|
| `scripts/select-role.sh` | matcher; self-test guards behavior |
| `scripts/quality-ledger.sh` | ledger aggregator; self-test guards schema |
| `scripts/role-snapshot-audit.sh` | stale-snapshot sweep |
| `scripts/check-doc-sync.sh` | doc/knowledge gate; auto-detects base dir |
| `scripts/doctor.sh` | wiring doctor |
| `scripts/check-external-facts.sh` | external-fact freshness |
| `references/role-matcher.md` | matcher protocol |
| `references/model-capabilities-2026.md` | model/tool landscape facts |
| `workflows/quality-ledger.md` | ledger protocol |
| `tests/` | test suite; run after any upgrade |
| `.githooks/commit-msg` | git hook; merge with host-only additions if any |

### Class B — Merge (mechanism + host context)

Mechanism with host-specific wiring. Overwriting loses host references;
keeping old versions loses new mechanism. Merge by hand using the diff.

| Path | What to preserve from host |
|---|---|
| `workflows/requirement-triage.md` | references to host routing (`routing.yaml`, `task-routing.md`, project workflows), host packet conventions |
| `rules/role-boundaries.md` | host model slugs (e.g. `gpt-5.6-terra`/`sol`), project vocabulary (`learner` terms), host external-fact markers |
| `SKILL.md` | host routing summary, host gotchas, host rule priority |
| `workflows/role-self-maintenance.md` | host script path prefixes (`bash skills/project-rules/scripts/...`) |

### Class C — Keep (host-owned, never overwrite)

Host data files. Upstream may change the schema; migrate data, not files.

| Path | Notes |
|---|---|
| `doc-ownership.yaml` | host ownership map; upstream example is a template only |
| `knowledge/<role-id>.md` | host role snapshots; may need format migration (see below) |
| `ledger/*.jsonl` | host quality ledger; append-only, never rewrite |
| `references/system-map.md` | host system map |
| `references/api-surface.md`, `domain-model.md`, `gotchas.md`, `dev-commands.md`, `workflow-artifacts.md` | host references |
| `rules/project-rules.md`, `coding-standards.md`, `ui-design-system.md`, `repo-sync.md`, `external-grounding.md` | host rules |
| `workflows/*` except Class A/B listed | host workflows |
| `routing.yaml`, `conformance.yaml` | host config |

## Migration Procedure

1. **Diff first, overwrite second.** Run the matcher and ledger self-tests
   after every upgrade step; they fail loudly on mechanism regressions.

2. **Class A**: copy files from upstream (or `git pull` the vendored dir if
   the host tracks it as a subtree), then run:
   ```bash
   bash tests/run.sh                      # mechanism self-tests
   bash scripts/doctor.sh --strict        # wiring check
   bash scripts/check-doc-sync.sh --dirty # gate sanity (may list real violations)
   ```

3. **Class B**: merge by hand. The upstream `git log` messages name the
   mechanism change; apply the same semantic change to the host copy while
   keeping host references. When in doubt, keep the host wording and port the
   mechanism line.

4. **Class C**: never copy upstream files over host data. If a new version
   changes a schema (manifest, snapshot, ledger), migrate the host data:
   - manifest schema: add new optional top-level keys (`unowned_code_roots`,
     `system_map_checks`); the checker ignores absent keys.
     `knowledge_roles` entries may be `role: glob` mappings (targeted
     requirement) or plain role strings (catch-all); both forms coexist and
     no migration is required.
   - snapshot format: the `snapshot_is_initialized` check accepts both dated
     `Recent Deltas` (`- YYYY-MM-DD: ...`) and legacy real-content deltas
     without dates. Only blank placeholders block. Migration is optional and
     additive: prefix deltas with dates when you next touch each snapshot.
   - ledger schema: `--add` validates required fields; old rows are read
     leniently by `--summary`.

5. **Wiring**: re-run doctor after upgrading. New versions may add hook
   checks (e.g. `.githooks` activation verification) that report previously
   silent states. Enable with the reported command, e.g.
   `git config core.hooksPath .githooks`.

## Automated Sync (optional)

A host that tracks the skill as a git subtree can script Class A:

```bash
git subtree pull --prefix skills/project-rules https://github.com/hippone/agent-role-governance main
bash skills/project-rules/tests/run.sh
```

Class B merges and Class C migrations remain manual by design: they carry
host context that automation cannot safely guess.
