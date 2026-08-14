# role-governance

> [English](README.md) | 简体中文

**AI 编程代理的治理层**：具有明确权限、上下文深度和风险边界的职能角色——由确定性的提交门禁强制执行，而非靠「感觉」。

## 目录

- [工作原理](#工作原理)
- [安装](#安装)
- [接入项目](#接入项目)
- [演练：一个任务全流程](#演练一个任务全流程)
- [仓库布局](#仓库布局)
- [对比](#对比)
- [原则](#原则)

## 工作原理

角色是临时的责任透镜，而不是持久的人格。该技能决定的是**工作如何被处理**，而不是你的产品做什么。

| 概念 | 含义 |
|---|---|
| **L1 / L2 层级** | L1 角色执行一个有边界的结果；L2 协调者把模糊/跨面工作分解为有边界的 L1 任务包，每个任务包由真实子代理运行。同代理角色切换是记录在案的降级，绝不是静默的「委派」。 |
| **自动角色识别** | `references/role-matcher.md` 定义三级匹配（硬信号 -> 请求形态 -> 门禁复核）；`scripts/select-role.sh --envelope` 根据结构化请求事实执行它。 |
| **L1 直接门禁** | 确定性清单。任何条件不满足，任务必须走 L2 协调者——即使 diff 很小。 |
| **C0-C4 上下文深度** | 每个任务包明确披露信息切片：C0 请求、C1 行为、C2 契约、C3 实现、C4 发布。每个角色在 `references/role-catalog.md` 中有常规上限。 |
| **R0-R3 风险路由** | 子代理模型和推理强度由任务包风险决定（影响半径、模糊度、错误代价），而非角色头衔。凭据记录请求了什么、回退了什么、实际运行了什么。 |
| **自我维护的知识** | 每个角色工作前审计 `knowledge/<role-id>.md` 快照，工作中从权威来源获取，工作后更新——`scripts/role-snapshot-audit.sh` 主动捕获过期快照。 |
| **质量账本** | `workflows/quality-ledger.md` 为每个 L2 任务记录只追加的 JSONL 凭据（QA GO/NO-GO、问题、路由核验）；`scripts/quality-ledger.sh` 汇总 GO 率。证据，而非宣称。 |
| **文档同步提交门禁** | `scripts/check-doc-sync.sh` 阻止「映射代码已变更但无所属文档、也无合格角色快照随之更新」的提交。存在窄化的 `[docs-na]` / `[knowledge-na]` 豁免；它们被检查，而非被信任。 |

## 安装

**Claude Code**

```bash
mkdir -p ~/.claude/skills && git clone https://github.com/hippone/agent-role-governance ~/.claude/skills/role-governance
```

**opencode**

```bash
mkdir -p ~/.config/opencode/skills && git clone https://github.com/hippone/agent-role-governance ~/.config/opencode/skills/role-governance
```

**Codex**

```bash
mkdir -p ~/.codex/skills && git clone https://github.com/hippone/agent-role-governance ~/.codex/skills/role-governance
```

然后让代理「为这次变更执行角色分诊」，或把该技能加入项目的指令，使其在每个任务上自动激活。

## 接入项目

角色提示词和任务包规则在任何位置都可用。**文档同步提交门禁只有在技能位于项目仓库内部时才会生效**——它的清单和快照必须参与同一套 Git 变更集。仅全局调用时会报告未接线；仓库内调用但缺少清单时会大声报错。

1. 把 `templates/doc-ownership.example.yaml` 复制为仓库内技能目录下的 `doc-ownership.yaml`；适配所有者、代码 glob、文档和 `knowledge_roles`。代码 glob 相对于仓库根目录——安装到别处请调整 `skills/role-governance/...` 前缀。目录中的每个角色必须至少出现在一个所有者里。标记为「当前」之前，请把每个上游快照重置或替换为宿主项目的事实。
2. 可选：添加 `references/system-map.md` 并在 `doc-ownership.yaml` 中加 `system_map_checks` 一节，要求登记新文件/模块。该文件不存在时检查器会完全跳过这些检查。
3. 在仓库根目录运行：

   ```bash
   bash skills/role-governance/scripts/check-doc-sync.sh --dirty
   ```

4. 至少启用一条提交门禁路径（仅仅存在的钩子文件不做任何事）：

   - **仓库 Git 钩子**（终端、IDE、代理提交一并覆盖）：把 `.githooks/commit-msg` 复制到仓库根目录，然后运行 `git config core.hooksPath .githooks`。钩子会在根目录或 `skills/*/`、`.agents/skills/*/`、`.claude/skills/*/` 下自动找到检查器。
   - **代理钩子**：把 `scripts/check-doc-sync.sh --hook-commit` 注册为 `git commit` 的 PreToolUse 钩子（见本仓库的 `.claude/settings.json`）。
5. 依赖前先验证接线：

   ```bash
   bash skills/role-governance/scripts/doctor.sh --strict
   ```

## 演练：一个任务全流程

一个支付流程功能落在已接线的项目里。

1. **请求到达** ——「为退款添加 webhook 处理，并在账户页展示退款回执。」
2. **匹配器识别路由角色** ——

   ```bash
   printf '%s\n' '{"request_type":"behavior_change","goal":"add webhook handling for refunds and show the refund receipt","billing_impact":true,"scope_width":2,"functional_roles":["backend-engineer","frontend-engineer"]}' \
     | bash skills/role-governance/scripts/select-role.sh --envelope
   ```

   结果：`contract-coordinator`（T1，`billing` 硬信号）——T1 硬信号压过看似前端的措辞，即使 diff 很小也如此。这正是门禁的意义。
3. **L2 协调者分解为有边界的 L1 任务包** —— `contract-architect`（契约 + 迁移边界）、`backend-engineer`（处理器、幂等、测试）、`frontend-engineer`（回执 UI）、`quality-engineer`（其余完成后的独立 GO/NO-GO）。每个任务包记录委派凭据、风险路由和分支策略；变更所有者不能自我认证。
4. **角色自我维护知识** —— 工作前，`backend-engineer` 审计自己的快照；实现后，追加一条增量：

   ```diff
   ## Recent Deltas
   +- 2026-08-13: refund webhook v1 lands; idempotency keyed on event id;
   +  no refund auto-approval without explicit operator action.
   ```

5. **门禁拦住半成品提交** —— 代码 + 后端快照，但前端快照缺失：

   ```bash
   $ bash skills/role-governance/scripts/check-doc-sync.sh --dirty
   doc-sync: 1 violation(s), 0 warning(s)
   VIOLATION web-app: code changed (src/pages/account.tsx) but none of its
   eligible role knowledge snapshots touched -> update one of:
   skills/role-governance/knowledge/frontend-engineer.md
   ```

   提交被拦截，直到快照移动——不需要评审者，门禁是结构性的。
6. **质量证据被记录，而非宣称** —— 协调者追加凭据；数周后 `--summary` 展示 GO 率、问题数、路由核验率。同一角色反复 NO-GO 会暴露出来——这是流程信号，不是产品质量的证明；修改路由规则前，请对照返工、漏网缺陷、周期时间和成本。
7. **更小的 L1 路径，作为对照** ——「修复设置页的拼写错误，并加一个组件测试。」→ 匹配器返回 `frontend-engineer`（T2，无硬信号），L1 直接门禁通过，直接执行并带紧凑凭据。没有任务包、没有子代理——治理随任务缩放，而不是给每个任务都加仪式。

## 仓库布局

```
SKILL.md                        技能入口；核心循环与文件地图
rules/role-boundaries.md        权限模型、L1/L2 门禁、C0-C4、R0-R3
references/role-catalog.md      8 个 L1 + 3 个 L2 角色，含决策范围与上下文上限
references/role-matcher.md      确定性的角色识别协议
references/model-capabilities-2026.md
                                基于事实的 2026-07/08 模型信息（上下文窗口、层级）
workflows/requirement-triage.md 请求信封 -> 所有者解析 -> 任务包契约
workflows/role-self-maintenance.md
                                每个角色的自审计 / 自获取 / 自更新
workflows/quality-ledger.md     只追加的质量凭据及其解读方式
workflows/update-role-knowledge.md
                                手动快照刷新（旧通道）
knowledge/*.md                  11 个角色快照；宿主角色初始为过期模板
scripts/check-doc-sync.sh       确定性的文档/知识同步门禁
scripts/select-role.sh          可执行的角色匹配器，含自测
scripts/role-snapshot-audit.sh  过期快照清扫
scripts/quality-ledger.sh       汇总 GO 率、问题数、路由核验率
scripts/check-external-facts.sh 标记过期的外部事实标记（180 天）
scripts/doctor.sh               报告清单、钩子、账本是否接线
tests/                          匹配器、账本与文档同步集成检查
doc-ownership.yaml              本仓库的自我治理映射
templates/doc-ownership.example.yaml
                                所有权清单示例；复制并适配
```

## 对比

| | 本技能 | 子代理包（如 awesome-claude-code-subagents） | 编排框架（如 maestro） | 方法论套件（如 BMAD） |
|---|---|---|---|---|
| 角色定义 | 有，含决策范围 | 仅人格提示词 | 隐含 | 有，固定 SDLC 阶段 |
| 直接执行 vs 协调门禁 | 确定性清单 | 无 | 无 | 按工作量大小的启发式 |
| 上下文披露上限 | 按角色 C0-C4 | 无 | 无 | 部分 |
| 子代理模型路由 | 基于风险的 R0-R3，含凭据 | 无 | 固定模型 | 无 |
| 委派可问责性 | 真实子代理凭据；降级必须声明 | 无 | 无 | 无 |
| 持久角色记忆 | 快照 + 同步门禁 | 无 | 无 | 部分（简报/工件） |
| 融入现有工作流 | 可以；仅作为前置步骤 | 可以 | 替换工作流 | 替换工作流 |

## 原则

- 角色从不授予部署、生产环境变更、花钱、访问私有数据或对外联络的权限。
- 核验角色在证据缺失时阻止完成声明；它们从不重新定义被请求的行为。
- 事实、决策、假设和提案在任务包中保持分离。
- `implemented`、`tested`、`built`、`deployed`、`browser-verified`、`payment-verified`、`provider-verified` 是互相独立的声明。

## 升级

参见 [UPGRADING.md](UPGRADING.md) 了解三类迁移流程（覆盖 / 合并 / 保留）、旧格式快照迁移，以及可选的 `git subtree` 同步。

## 许可证

MIT
