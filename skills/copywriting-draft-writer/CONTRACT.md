# Copywriting Draft Writer Contract

> 状态：confirmed_for_compilation  
> contract_version：0.2.0
> contract_set_version：r1-contract-set-v0.1  
> 对应 skill：`skills/copywriting-draft-writer/SKILL.md`  
> 编译门禁：涛哥已确认 R1，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: copywriting-draft-writer
skill_name: 短视频口播草案生成
contract_version: 0.2.0
contract_set_version: r1-contract-set-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-06
```

一句话职责：

```text
把通过的 content_brief 写成第一版短视频口播草案，并生成 Hook 路由、正文信息密度和五秒留存设计，达到画中画规划与联合质检的输入标准。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 写口播
    - 生成草案
  upstream_artifact_status:
    - brief_status = brief_pass
    - human_gate = no
  allowed_manual_commands:
    - 重写开头
    - 回到 Brief
```

不得触发：

```text
Brief 未通过。
内容形式不是短视频口播且未确认支持。
核心观点、事实、产品边界或 CTA 缺失。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - content_brief
  required_fields:
    - brief_id
    - content_source_id
    - content_origin
    - account
    - content_goal
    - target_audience
    - core_point
    - product_claim_boundary
    - must_not_say
    - cta
  source_specific_fields:
    hotspot_selected_topic: topic_id + source_research_run_id + hotspot_fact
    user_supplied_draft: original_draft_artifact_id + original_draft_digest + revision_policy + claim_map
  required_status:
    - brief_status = brief_pass
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type: content_brief
  source_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/03-content-brief.md
  required_fields:
    - content_format
    - core_point
    - account_tone
    - product_mention_level
    - forbidden_claims
  validation_rules:
    - 不重新选题
    - 不新增未经 Brief 支撑的事实
    - 不扩大产品能力
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type: draft
  target_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/04-draft.md
  required_fields:
    - draft_id
    - brief_id
    - content_source_id
    - content_origin
    - content_format
    - title_options
    - five_second_retention_design
    - hook_route
    - content_promise
    - credibility_source
    - body_payoff
    - recommended_hook
    - hook_score
    - segment_map
    - body_information_density_score
    - core_mechanism
    - memory_point
    - script
    - cta
    - product_mention
    - risk_notes
    - draft_status
    - next_skill
  source_specific_fields:
    hotspot_selected_topic: topic_id + source_research_run_id
    user_supplied_draft: original_draft_artifact_id + original_draft_digest + revision_policy
  status_field: draft_status
  downstream_artifact: visual_plan
```

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - intermediate/03-content-brief.md
  output_paths:
    - intermediate/04-draft.md
```

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - draft_status = draft_created
    - hook_score >= 7
    - body_information_density_score >= 7
    - body_payoff exists
    - core_mechanism exists
  next_skill:
    draft_created: talking-head-image-pip
  forbidden_human_prompt:
    - 是否做画中画？
    - 是否继续质检？
```

草案通过最低门槛后，自动进入画中画规划。最低门槛不是只有 Hook 分数，还包括正文能兑现 Hook 承诺、正文信息密度足够、核心机制清楚。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: hook_choice
    trigger: 多个 Hook 方案存在明显策略取舍，且评分接近
    reason: 开头方向会影响整条视频气质
    recommended_action: 推荐一个默认 Hook，允许用户选 A/B/C
    human_reply_examples:
      - 按推荐继续
      - 选 A
      - 重写开头
    auto_next_after_reply: talking-head-image-pip 或 copywriting-draft-writer

  - gate_id: draft_blocked
    trigger: hook_score < 7、body_information_density_score < 7、body_payoff 缺失，或 Brief 无法支撑正文
    reason: 前 5 秒不稳或正文撑不起承诺，继续做画中画会放大问题
    recommended_action: 重写开头、补正文信息增量，或回到 Brief
    human_reply_examples:
      - 重写开头
      - 补正文信息密度
      - 回到 Brief
    auto_next_after_reply: copywriting-draft-writer 或 content-brief-compiler
```

---

## 9. 失败处理

```yaml
failure_modes:
  missing_brief:
    recovery_action: 回到 content-brief-compiler
  unsupported_format:
    recovery_action: 标记为 reserved_route，不生成草案
  hook_low_score:
    recovery_action: draft_status = draft_blocked，重写前 5 秒
  body_low_density:
    recovery_action: draft_status = draft_needs_body_fix，补 segment_map 和信息增量
  promise_not_paid_off:
    recovery_action: draft_status = draft_needs_body_fix，补 body_payoff 或换 Hook 路由
  core_mechanism_unclear:
    recovery_action: draft_status = draft_needs_brief_fix，回到 Brief 定核心机制
  product_overclaim:
    recovery_action: 回到 Brief 修产品边界
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - content_brief -> draft
    - Hook 路由选择
    - 正文信息密度判断
    - 五秒留存设计
    - hook_score 判断
  agent_orchestrated:
    - 临时改变内容形式
```

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | brief_pass，短视频口播 | 输出 draft，hook_score >= 7，body_information_density_score >= 7，自动进入画中画 |
| low_hook | hook_score < 7 | draft_blocked，停在重写开头 |
| weak_body | Hook 强但正文重复 | draft_needs_body_fix，补正文信息密度 |
| no_payoff | 开头承诺 A 正文讲 B | draft_needs_body_fix 或换 Hook |
| missing_brief | 无 Brief | 回到 content-brief-compiler |
| unsupported_format | 用户要求长文 | 不生成，标 reserved_route |
| product_overclaim | 草案扩大产品能力 | 阻断，回 Brief |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - sample draft
  must_redact:
    - 真实账号未公开表达策略
  sample_required:
    - examples/sample-run/intermediate/04-draft.md
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| 第一阶段是否只支持短视频口播 | 是 |
| hook_score 低于 7 是否阻断 | 是 |
| 正文信息密度低于 7 是否阻断 | 是 |
| Hook 承诺没有正文兑现是否阻断 | 是 |
| 草案通过后是否自动进画中画 | 是 |
