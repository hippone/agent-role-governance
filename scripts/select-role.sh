#!/usr/bin/env bash
# select-role.sh — deterministic role selection from request text or a JSON
# request envelope. The envelope mode is authoritative; text mode is a
# compatibility candidate generator and reports when the L1 gate still needs
# an envelope recheck.
#
# Usage:
#   echo "change the public API schema" | bash scripts/select-role.sh
#   bash scripts/select-role.sh --json < request.txt
#   bash scripts/select-role.sh --envelope < request-envelope.json
#   bash scripts/select-role.sh --self-test

set -euo pipefail

run_matcher() {
  local input_mode="${1:-text}"
  local request_text="${2:-}"
  local matcher_tmp
  matcher_tmp="$(mktemp)"
  cat > "$matcher_tmp" <<'PY'
import json
import re
import sys

mode = sys.argv[1]
argument_text = sys.argv[2] if len(sys.argv) > 2 else ""


def read_input():
    if mode == "envelope":
        raw = sys.stdin.read().strip()
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"select-role: invalid envelope JSON: {exc}")
        if not isinstance(value, dict):
            raise SystemExit("select-role: envelope must be a JSON object")
        return value
    return {"text": argument_text or sys.stdin.read()}


envelope = read_input()
text = str(envelope.get("text") or envelope.get("goal") or "").lower()


def has(*patterns):
    return any(re.search(pattern, text, re.I) for pattern in patterns)


def true_field(name):
    value = envelope.get(name)
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value or "").strip().lower() in {
        "true", "yes", "1", "changed", "change", "required", "high",
    }


def int_field(name, default=0):
    try:
        return int(envelope.get(name, default) or default)
    except (TypeError, ValueError):
        return default


request_type = str(envelope.get("request_type") or "").lower()
owner_status = str(envelope.get("owner_status") or "").lower()
functional_roles = envelope.get("functional_roles") or []
if not isinstance(functional_roles, list):
    functional_roles = []
functional_roles = [str(role).lower() for role in functional_roles]

explicit_docs_only = true_field("docs_only") or request_type == "docs"
explicit_diagnosis_only = true_field("diagnosis_only")
explicit_design_only = true_field("design_only")
explicit_release_authorized = true_field("release_authorized")

docs_only = explicit_docs_only or has(
    r"\b(?:docs?|documentation|wording|release notes?|policy|readme)\b.{0,24}\b(?:only|仅|只)\b",
    r"\b(?:only|仅|只)\b.{0,24}\b(?:docs?|documentation|wording|release notes?|readme)\b",
    r"(?:仅|只)(?:修改|更新|审查)?.{0,12}(?:文档|文案|措辞|说明)",
    r"(?:文档|文案|措辞|说明).{0,12}(?:而已|即可|仅|只)",
)
# Copy/UI classification is judged from the user's perspective, not an
# engineering-internal one: a surface change counts as presentation-only when
# the end user can perceive it (visible copy, headings, labels, button text,
# colors, fonts, icons, typos). Status/state-feedback terms ("提示当前状态"
# style: empty state, error message, toast, tooltip, confirmation, 状态提示,
# 错误提示, 提示语, 弹窗文字) are forbidden as copy/UI signals: they describe
# dynamic state feedback, not static user-facing surface, and must not route
# a request into the copy/UI lane on their own. Engineering-internal
# artifacts users never see (comments, internal naming, CSS variable/design
# token definitions, component-internal structure) are never presentation-only
# on their own. The keywords below are surface-context hints used to keep
# copy/UI work from being mis-escalated by protected-domain words (e.g. a
# payment-page heading is copy work, not a billing-contract change); the
# operative judgment stays user-visible impact, never engineering internals.
presentation_only = docs_only or has(
    r"\b(?:typo|copy|heading|label|button text|colou?r|font|icon|comment|css|style|design tokens?)\b",
    r"(?:错别字|文案|标题|标签|按钮文字|颜色|配色|字体|字号|图标|注释|样式|设计令牌)",
)
negated_release = has(
    r"\b(?:do not|don't|dont|never|no)\s+(?:deploy|release|rollout)\b",
    r"(?:不要|不允许|禁止)(?:部署|发布|上线)",
)
negated_mutation = has(
    r"\b(?:do not|don't|dont|never|without)\s+(?:implement|change|update|modify|fix|edit|write)\b",
    r"(?:不要|不|禁止|无需)(?:实现|新增|添加|修改|更新|迁移|删除|修复|写入)",
)
implementation_action = has(
    r"\b(?:implement|add|change|update|modify|migrate|remove|delete|fix|wire|create|refactor|rework|rewrite|rename|restructure|redesign|overhaul|harden)\b",
    r"(?:实现|新增|添加|修改|更新|迁移|删除|修复|接入|创建|重构|重写|重命名|调整|优化|改成|改为|换成)",
) and not presentation_only and not negated_mutation
diagnosis_only = explicit_diagnosis_only or (
    has(r"\b(?:diagnos|verify|review|reproduce|test matrix|go/no-go)\w*\b", r"(?:诊断|验证|复现|排查|审查)")
    and not implementation_action
)
design_only = explicit_design_only or has(
    r"\b(?:design[- ]only|no consumers?|contract design)\b",
    r"(?:仅设计|只设计|没有消费者|不改消费者)",
)

contract_term = False
contract_impact = any(
    true_field(field)
    for field in (
        "contract_impact", "auth_impact", "billing_impact", "privacy_impact",
        "identity_impact", "schema_impact", "shared_state_impact",
    )
)
if mode != "envelope":
    contract_term = has(
        r"\b(?:public api|api schema|shared type|state machine|dtos?|contract|schema|authentication|authorization|auth|billing|payment|refund|privacy|identity|entitlement|login)\b",
        r"(?:公开\s*api|接口契约|共享类型|状态机|数据结构|表结构|数据表|鉴权|认证|计费|支付|退款|结算|对账|订阅|隐私|身份|登录)",
    )
    contract_impact = contract_term and implementation_action and not design_only

production_risk = any(
    true_field(field)
    for field in ("production_exposure", "data_loss_risk", "root_cause_unknown")
) or owner_status == "unknown"
if mode != "envelope":
    production_risk = has(
        r"\b(?:data loss|data-loss|data.{0,20}lost|production incident|production fault|outage)\b",
        r"(?:数据丢失|生产事故|线上事故|服务中断)",
    ) or (
        has(r"\b(?:intermittent|unstable reproduction)\b", r"(?:间歇性|无法稳定复现)")
        and has(r"\b(?:production|prod|live)\b", r"(?:生产|线上)")
    )

ambiguous = true_field("ambiguous") or owner_status == "unmapped"
scope_width = int_field("scope_width", len(set(functional_roles)))
multi_role = scope_width > 1 or len(set(functional_roles)) > 1
if mode != "envelope":
    ambiguous = has(r"\bambiguous\b", r"(?:需求不清|范围不清|有歧义)")


def result(role, tier, confidence, reason, candidates=None, gate=None):
    if gate is None:
        if role.endswith("coordinator"):
            gate = f"fail -> promoted to {role}"
        elif mode == "envelope":
            gate = "pass"
        else:
            gate = "needs_envelope_recheck"
    payload = {
        "role": role,
        "tier": tier,
        "signal": reason,
        "confidence": confidence,
        "reason": reason,
        "l1_gate": gate,
        "input_mode": mode,
    }
    if candidates:
        payload["candidates"] = candidates
    print(json.dumps(payload, ensure_ascii=False))
    raise SystemExit(0)


# T1 hard signals. Explicit docs-only semantics win over incidental risk words.
if docs_only:
    result("docs-governor", "T1", "high", "accepted docs-only signal")
if production_risk:
    result("incident-coordinator", "T1", "high", "production, data-loss, or unstable-root-cause signal")
if contract_impact:
    result("contract-coordinator", "T1", "high", "public/shared contract or protected-domain change")
# Text-mode failsafe: a protected-domain term whose action verb the matcher
# does not recognize must still land on a coordinator, never fall through to
# an L1 candidate. Envelope mode carries semantic impact fields instead.
if contract_term and not (
    presentation_only or diagnosis_only or design_only or negated_mutation
):
    result(
        "contract-coordinator", "T1", "medium",
        "protected-domain term without a recognized action; coordinate rather than guess L1",
    )
if ambiguous or multi_role:
    result("change-coordinator", "T1", "high", "ambiguity, unmapped owner, or multi-role scope")
if request_type == "release" or has(r"\b(?:release|deploy|rollout)\b", r"(?:发布|部署|上线)"):
    if explicit_release_authorized or (has(r"\bauthorized\b", r"(?:已授权|授权发布)") and not negated_release):
        result("release-engineer", "T1", "high", "explicitly authorized single-boundary release")
    if not docs_only:
        result("change-coordinator", "T1", "high", "release requested without explicit authorization")
if owner_status == "unmapped":
    result("change-coordinator", "T1", "high", "unmapped surface")

# T2 request-shape candidates.
candidates = []


def add_candidate(role, confidence, signal):
    if role not in {candidate["role"] for candidate in candidates}:
        candidates.append({
            "tier": "T2", "role": role, "confidence": confidence, "signal": signal,
        })


requirement_shape = request_type in {"new_requirement", "behavior_change"} or has(
    r"\b(?:requirement|acceptance criteria|non[- ]goal|spec wording|scope of)\b",
    r"(?:需求|验收标准|非目标|范围定义)",
)
interaction_design_shape = design_only or has(
    r"\b(?:design the .*interaction|interaction copy|error states|ux)\b",
    r"(?:交互设计|错误状态|体验设计)",
)
if requirement_shape:
    add_candidate("product-analyst", "high", "requirement-shape signal")
if interaction_design_shape:
    if has(r"\b(?:dto|schema|contract|api)\b", r"(?:契约|接口|数据结构)"):
        add_candidate("contract-architect", "medium", "bounded contract design-only signal")
    else:
        add_candidate("experience-designer", "medium", "interaction-design signal")
if diagnosis_only or request_type in {"diagnosis", "verification"}:
    add_candidate("quality-engineer", "high", "diagnosis or verification-only signal")
if not diagnosis_only and not requirement_shape and not interaction_design_shape:
    if "frontend-engineer" in functional_roles or has(
        r"\b(?:frontend|page|component|ui|client state|component test|dashboard|css|copy|heading|label|button|modal|dialog|layout|form field)\b",
        r"(?:前端|页面|组件|界面|客户端|仪表盘|样式|文案|标题|标签|错别字|按钮|弹窗|表单|输入框|图标|布局|导航|首页)",
    ):
        add_candidate("frontend-engineer", "medium", "frontend-shape signal")
    if "backend-engineer" in functional_roles or has(
        r"\b(?:backend|service|persistence|repository|server)\b",
        r"(?:后端|服务端|持久化|仓储层|数据库|缓存|队列|定时任务)",
    ):
        add_candidate("backend-engineer", "medium", "backend-shape signal")
if request_type == "contract" and design_only:
    add_candidate("contract-architect", "high", "bounded contract design-only signal")
if has(r"\breproducible bug\b", r"(?:可稳定复现|稳定复现的缺陷)") and not diagnosis_only:
    if has(r"\b(?:dashboard|frontend|page|component)\b", r"(?:前端|页面|组件)"):
        add_candidate("frontend-engineer", "medium", "reproducible frontend bug")
    if has(r"\b(?:api|backend|service|server)\b", r"(?:接口|后端|服务端)"):
        add_candidate("backend-engineer", "medium", "reproducible backend bug")
if has(r"\b(?:intermittent|flaky)\b", r"(?:间歇性|偶发|不稳定测试)") and not candidates:
    add_candidate("quality-engineer", "medium", "non-production flaky verification signal")

if len(candidates) > 1:
    result(
        "change-coordinator", "T2", "high",
        "multiple distinct T2 candidates require coordination",
        candidates=candidates,
        gate="fail -> promoted to change-coordinator",
    )
if len(candidates) == 1:
    candidate = candidates[0]
    result(
        candidate["role"], candidate["tier"], candidate["confidence"],
        candidate["signal"], candidates=candidates,
    )
result(
    "change-coordinator", "T2", "low",
    "no confident signal matched; coordinator must resolve the envelope",
    gate="fail -> promoted to change-coordinator",
)
PY
  python3 "$matcher_tmp" "$input_mode" "$request_text"
  rm -f "$matcher_tmp"
}

self_test() {
  local failures=0
  local test_cases=(
    "change the public api schema and auth|contract-coordinator"
    "add a billing rule|contract-coordinator"
    "user data is lost in production|incident-coordinator"
    "production incident on payments|incident-coordinator"
    "ambiguous feature across dashboard and settings|change-coordinator"
    "new requirement: define acceptance criteria for the onboarding flow|product-analyst"
    "spec wording and non-goals for the export page|product-analyst"
    "design the checkout interaction copy and error states|experience-designer"
    "tweak the settings page copy and add a component test|frontend-engineer"
    "implement the api client on the frontend|frontend-engineer"
    "update the backend service persistence logic|backend-engineer"
    "review the diff for evidence before we ship|quality-engineer"
    "verify the regression test matrix|quality-engineer"
    "design the dto shape, no consumers yet|contract-architect"
    "fix a reproducible bug in the dashboard owned by web-app|frontend-engineer"
    "fix a reproducible bug in the api client|backend-engineer"
    "rewrite the docs wording only|docs-governor"
    "deploy the authorized release|release-engineer"
    "update frontend page and backend service|change-coordinator"
    "fix a reproducible bug in the dashboard and api|change-coordinator"
    "verify backend regression without changing code|quality-engineer"
    "privacy policy wording only|docs-governor"
    "fix the payment page heading typo|frontend-engineer"
    "update CSS schema design tokens|frontend-engineer"
    "update the README only|docs-governor"
    "intermittent flaky unit test|quality-engineer"
    "do not deploy; only review the release notes|docs-governor"
    "refactor the auth token refresh implementation|contract-coordinator"
    "refactor the auth login page component|contract-coordinator"
    "the billing amount drifts after retry, cause unknown|contract-coordinator"
    "帮我把首页按钮改成蓝色|frontend-engineer"
    "调整鉴权令牌的刷新逻辑|contract-coordinator"
    "更新数据库索引和缓存逻辑|backend-engineer"
    "重构支付对账任务|contract-coordinator"
    "修改数据库表结构|contract-coordinator"
    "诊断后端回归问题，不要修改代码|quality-engineer"
    "修改公开 API schema 和鉴权逻辑|contract-coordinator"
    "修一下结算页面的错别字|frontend-engineer"
    "payment success page copy|frontend-engineer"
    "update the empty state|change-coordinator"
    "提示当前状态|change-coordinator"
    "fix the checkout empty state message|change-coordinator"
    "update the refund confirmation dialog text|contract-coordinator"
    "调整支付失败提示语的措辞|contract-coordinator"
    "把注册页面的按钮文字改成立即注册|frontend-engineer"
    "rename an internal helper comment in the payment module|change-coordinator"
  )
  local test_case request_text expected_role actual_role
  for test_case in "${test_cases[@]}"; do
    request_text="${test_case%%|*}"
    expected_role="${test_case##*|}"
    actual_role="$(printf '%s' "$request_text" | run_matcher text | python3 -c 'import json,sys; print(json.load(sys.stdin)["role"])')"
    if [ "$actual_role" != "$expected_role" ]; then
      echo "FAIL: expected $expected_role got $actual_role | $request_text" >&2
      failures=$((failures + 1))
    fi
  done

  local envelope_cases=(
    '{"request_type":"behavior_change","goal":"change account state","scope_width":2,"functional_roles":["frontend-engineer","backend-engineer"]}|change-coordinator'
    '{"request_type":"verification","goal":"检查回归证据","diagnosis_only":true,"owner_status":"web-app"}|quality-engineer'
    '{"request_type":"release","goal":"deploy release","release_authorized":false}|change-coordinator'
    '{"request_type":"contract","goal":"design DTO only","design_only":true,"contract_impact":false}|contract-architect'
  )
  local envelope_json
  for test_case in "${envelope_cases[@]}"; do
    envelope_json="${test_case%%|*}"
    expected_role="${test_case##*|}"
    actual_role="$(printf '%s' "$envelope_json" | run_matcher envelope | python3 -c 'import json,sys; print(json.load(sys.stdin)["role"])')"
    if [ "$actual_role" != "$expected_role" ]; then
      echo "FAIL envelope: expected $expected_role got $actual_role | $envelope_json" >&2
      failures=$((failures + 1))
    fi
  done

  if [ "$failures" -eq 0 ]; then
    echo "select-role: self-test passed ($((${#test_cases[@]} + ${#envelope_cases[@]})) cases)"
  else
    echo "select-role: self-test failed ($failures cases)" >&2
    return 1
  fi
}

case "${1:-}" in
  --self-test)
    self_test
    ;;
  --envelope)
    run_matcher envelope ""
    ;;
  --json)
    shift
    run_matcher text "$*"
    ;;
  *)
    run_matcher text ""
    ;;
esac
