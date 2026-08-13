# Model Capability Baseline (2026-07/08)

Facts about the model and tool landscape as of July-August 2026. This file is
the grounding for every design decision in this skill: context-depth slicing,
risk routing, delegation requirements, and knowledge-snapshot mechanics.
Claims are marked with `external-fact` markers; `scripts/check-external-facts.sh`
flags markers older than 180 days. Re-verify before changing design based on
any fact below.

<!-- external-fact: verified=2026-08-13 source=https://developers.openai.com/api/docs/models -->

## Provider Landscape

### OpenAI — GPT-5.6 tier family

| Model | Positioning | Role in this skill |
|---|---|---|
| `gpt-5.6-sol` | Flagship; complex reasoning and coding | R2/R3 packets (coordinated / critical) |
| `gpt-5.6-terra` | Balanced intelligence and cost | R0/R1 packets (mechanical / bounded) |
| `gpt-5.6-luna` | Cost-sensitive, high-volume workloads | Batch mechanical work, large parallel fan-out |

Context window: 1M class for the family; pricing is tiered (input tokens are
metered per request, so full-context prompts are materially more expensive
than pointer-based prompts).

### Anthropic — Claude 5 family

<!-- external-fact: verified=2026-08-13 source=https://docs.anthropic.com/en/docs/about-claude/models -->

| Model | Context window | Notes |
|---|---|---|
| Claude Fable 5 | 1M tokens | Long-context handling rated top-tier in provider docs |
| Claude Opus 5 | 1M tokens | — |
| Claude Sonnet 5 | 1M tokens | — |
| Claude Haiku 4.5 | 200k tokens | Cost tier; 1M is NOT available on the cheap tier |

### Google — Gemini 3.5/3.6 family

<!-- external-fact: verified=2026-08-13 source=https://ai.google.dev/gemini-api/docs/models -->

| Model | Context window | Notes |
|---|---|---|
| Gemini 3.6 Flash | 1,048,576 input / 65,536 output | Thinking, code execution, function calling |
| Gemini 3.5 Flash | 1M class | — |
| Gemini 3.5 Flash-Lite | 1M class | Cheap tier for high-volume work |

## Agent Tool Landscape (2026-07/08)

<!-- external-fact: verified=2026-08-13 source=https://docs.anthropic.com/en/docs/claude-code/sub-agents -->
<!-- external-fact: verified=2026-08-13 source=https://opencode.ai/docs/agents/ -->
<!-- external-fact: verified=2026-08-13 source=https://developers.openai.com/codex/agent-configuration/subagents -->
<!-- external-fact: verified=2026-08-13 source=https://google.github.io/gemini-cli/ -->

| Tool | Subagent isolation | Skills | Rules format | Commit-time hooks | Model control |
|---|---|---|---|---|---|
| **Claude Code** | Native: each subagent runs in its own context window, custom system prompt, specific tool access, independent permissions | Native (`.claude/skills`, user/project scope) | `CLAUDE.md` (+ subagent dirs) | Native lifecycle hooks (`PreToolUse`, `Stop`, `PostToolUse`, HTTP or shell) | Per-subagent `model` field; `Explore` inherits main model |
| **opencode** | Native: primary agents (Build/Plan) + subagents (General/Explore/Scout), switch with Tab or `@mention` | Native (skills dir) | `AGENTS.md` | Plugin event system (JS/TS plugins, `--hook-commit` compatible) | Per-agent model config; permissions gate tools |
| **Codex (local CLI)** | Native: subagents run parallel workflows, spawn specialized agents, each with own model and tools | Native (skills + plugins) | `AGENTS.md` (global `~/.codex` + project, layered) | `AGENTS.md`-driven; hooks via plugins | Per-agent model config; sandbox agents |
| **Gemini CLI** | Subagents supported | Skills supported | `GEMINI.md` custom context files | Hook support | Gemini 3 models, 1M context |
| **Qwen Code** | SubAgents + Agent Teams, dynamic workflows | Auto-Skills, built-in skills | `AGENTS.md` | Hooks | Multi-provider (OpenAI/Anthropic/Gemini/Qwen/any local), runtime switch |
| **Pi (badlogic)** | Extension-based: subagent extension (own context), custom via TS extensions | Skills + prompt templates, Pi packages | `AGENTS.md`/custom | Extension events (permission gates, path protection, SSH, sandbox) | 15+ providers, hundreds of models, mid-session `/model` switch |
| **Cursor (IDE)** | Subagents native | Native skills | Rules (`.cursor/rules`) + `AGENTS.md` | Hooks | IDE-managed models |

### Design implications

- **Subagent isolation is now the norm, not the exception.** Every mainstream
  terminal/IDE agent ships real isolated-context subagents. The skill's
  `degraded-same-agent` fallback is only needed on unusual setups — but the
  receipt mechanism remains load-bearing: it is the only way to prove which
  mode actually ran.
- **Skills and AGENTS.md are universal.** The skill's markdown-first design
  (no runtime plugin required) installs on all seven tools above. Packaging
  as a skill pack is the zero-friction choice.
- **Commit-time gates differ.** Claude Code, opencode, Cursor and Qwen
  support commit-ish lifecycle hooks; Pi needs an extension; Gemini CLI and
  Codex are plugin/hook-driven. The `--hook-commit` mode is implemented once
  and adapter is a settings file per tool — keep the gate itself
  tool-agnostic (it only reads stdin JSON).
- **Model control is per-agent everywhere.** All tools let you pin a model
  per agent/subagent. R0-R3 routing is implementable on every target; the
  routing table stays in the skill, the model pin goes in each tool's agent
  config.

## Capability Boundaries That Shape This Design

1. **1M context is now universal on flagship tiers, but NOT on cheap tiers.**
   Claude Haiku 4.5 caps at 200k. Routing cheap work to cheap models means
   the cheap model cannot hold the full repo — pointer-based C0-C4 packets are
   what makes cheap-tier delegation viable at all.

2. **Context cost scales with input tokens.** At 1M windows, "just paste the
   file" is a real bill. The C0-C4 disclosure slicing is a cost lever, not a
   convenience: pointer + conclusion vs full source is a 10-100x input-token
   difference per request, multiplied across subagent fan-out.

3. **Compaction and lost-in-the-middle still apply at 1M.** Long tasks
   compress silently; mid-context detail is the first thing to degrade.
   Repository-side knowledge snapshots are the only durable truth that
   survives compression — they are not a memory aid, they are the record.

4. **Tiered families (Sol/Terra/Luna, Flash/Flash-Lite) make risk routing a
   real cost control.** Routing errors (Sol for R0, Luna for R3) are now
   measurable money waste in both directions. R0-R3 routing is a cost knob,
   not a style preference.

5. **Cheap tiers make independent review affordable.** Post-implementation
   `quality-engineer` subagents on cheap tiers cost little, so the L2
   mandatory-review rule is economically viable even for small teams.

6. **Subagent isolation is native in current coding tools.** Claude Code,
   opencode, and Codex all provide real isolated-context subagents. The
   `degraded-same-agent` fallback in `rules/role-boundaries.md` exists for
   environments that do not — with strong models, same-agent role-switching
   can look convincing while lacking true independence, so the receipt
   mechanism is what separates real delegation from theater.

## Design Implications Mapped To This Skill

| Skill mechanism | Grounded in |
|---|---|
| C0-C4 context depth + pointers | 1, 2 (cost lever; cheap-tier viability) |
| Knowledge snapshots as derived truth | 3 (compaction resistance) |
| R0-R3 risk routing with receipts | 4 (tiered cost control) |
| Mandatory independent QA subagent | 5 (affordable at scale) |
| Delegation receipts / degraded-same-agent marking | 6 (isolation is structural, not prompt-level) |
| Routinely limiting cheap-tier context in `role-catalog.md` | 1 (200k Haiku bound) |

## Verification Protocol

- Re-run the source checks when: a new model family ships, context windows
  change, or pricing structure changes.
- Update the `external-fact` marker dates when re-verified.
- Never change routing defaults or context limits from a stale fact; the
  marker date is the contract.
