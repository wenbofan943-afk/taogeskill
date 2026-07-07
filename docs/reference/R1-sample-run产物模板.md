# R1 Sample Run 产物模板

> 状态：R1 编译补强模板  
> 主责：给 R1 单篇 sample run 提供 manifest、execution trace、trace check 和人工决策恢复的最小模板。  
> 边界：本模板只服务 R1 单篇链路；不覆盖 R2 多篇 fan-out、R3 图片资产数量合同、R4 开源发布包。

---

## 一、使用时机

开始 R1 sample run 前，必须先新建 session 目录，并按本模板生成：

```text
manifest.yaml
intermediate/00-execution-trace.md
```

R1 sample run 不能复用旧 session。

---

## 二、manifest.yaml 模板

```yaml
contract_set_version: r1-contract-set-v0.1
sample_run_type: r1_single_content
legacy_session: false
not_for_r1_acceptance: false

session_id:
account:
account_slug:
product_profile_id:
campaign_profile_id:
started_at:
updated_at:
current_stage: account_profile
current_artifact:
source_research_run_id:
next_skill: propagation-router
session_status: session_active

account_profile_confirmed_for_session: pending
account_profile_confirmed_at:

artifacts:
  account_profile:
    id:
    path:
    status:
  product_profile:
    id:
    path:
    status:
  research_run:
    id:
    path: intermediate/01-research-run.md
    status:
  topic_card:
    id:
    path: intermediate/02-topic-card.md
    status:
  content_brief:
    id:
    path: intermediate/03-content-brief.md
    status:
  draft:
    id:
    path: intermediate/04-draft.md
    status:
  visual_plan:
    id:
    path: intermediate/05-visual-plan.md
    status:
  quality_review:
    id:
    path: intermediate/06-quality-review.md
    status:
  platform_package_input:
    id:
    path: intermediate/07-platform-package-input.md
    status:
  platform_package:
    id:
    path: intermediate/08-platform-package-draft.md
    status:
  content_delivery_record:
    id:
    path: deliverables/content-delivery-record.md
    status:
  final_delivery:
    id:
    path: deliverables/final-delivery.html
    status:

human_deliverables:
  final_delivery:
    path:
    status:
  export_bundle:
    path:
    status: not_requested

media_assets:
  image_asset_set_id:
  image_assets_status:
  assets: []

execution_trace:
  path: intermediate/00-execution-trace.md
  trace_status: active
  agent_assist_level:
  skill_maturity_summary:

trace_check:
  trace_check_id:
  overall_result:
  blocking_count:
  warning_count:

last_decision:
blocked_reason:
next_recommended_actions:
```

---

## 三、execution trace 模板

```markdown
# Execution Trace

## 本轮摘要
- contract_set_version：r1-contract-set-v0.1
- sample_run_type：r1_single_content
- legacy_session：false
- session_id：
- account：
- started_at：
- current_stage：
- trace_status：active
- agent_assist_level：

## 执行动作表
| step | action | expected_skill | input_artifact | output_artifact | artifact_path | next_skill | execution_source | check_ids | evidence | agent_intervention | result |
|---|---|---|---|---|---|---|---|---|---|---|---|

## Human Decisions
| decision_at | gate_id | user_reply | decision_type | state_updates | next_skill | handled |
|---|---|---|---|---|---|---|

## Skill 成熟度观察
| skill | maturity_level | 本轮表现 | 需要反写的规则 |
|---|---|---|---|

## Agent 扶跑清单
| 缺口 | agent 怎么补的 | 是否已反写到规则 | 下轮验收方式 |
|---|---|---|---|

## R1 Trace Check
- trace_check_id：
- overall_result：
- blocking_issues：
- warnings：
- next_action：

## 发布风险
- 如果现在发布 skill，用户可能卡在哪里：
- 哪些步骤还依赖 Codex agent 临场判断：
- 哪些能力其实来自环境，不来自 skill：
```

---

## 四、trace check 输出模板

```yaml
trace_check_id:
session_id:
contract_set_version: r1-contract-set-v0.1
overall_result: pass / pass_with_warnings / fail
checks:
  - check_id: R1CHK-001
    result:
    severity: BLOCKER
    evidence:
    failure_message:
    required_backwrite:
blocking_issues:
warnings:
info:
r1_candidate_status: not_ready / candidate_with_warnings / candidate_pass
next_action:
```

---

## 五、人工决策恢复模板

每次用户回复后，必须写入 `Human Decisions`，并同步 manifest。

```yaml
decision_record:
  gate_id:
  user_reply:
  decision_type:
  state_updates:
    current_stage:
    current_artifact:
    last_decision:
    blocked_reason:
    next_skill:
    session_status:
  handled: yes / no
```

恢复时：

```text
handled=yes：不得重复执行同一人工决定。
handled=no：先完成 state_updates，再进入 next_skill。
```

---

## 六、测试前 preflight 输出

进入 sample run 前，`propagation-router` 必须输出：

```yaml
r1_preflight:
  contract_set_version: r1-contract-set-v0.1
  result: pass / fail
  checks:
    contracts_confirmed:
    skill_runtime_present:
    compatibility_entry_safe:
    reference_backwrites_present:
    new_session_required:
    manifest_template_ready:
    trace_template_ready:
    long_skill_progressive_reading:
  blocking_issues:
  next_action:
```

`result=fail` 时，不得开始 sample run。

