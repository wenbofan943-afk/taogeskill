# Content Brief Compiler Contract

> 状态：confirmed_for_compilation
> contract_version：0.1.0
> contract_set_version：r1-contract-set-v0.1
> 对应 skill：`skills/content-brief-compiler/SKILL.md`
> 编译门禁：涛哥已确认 R1，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: content-brief-compiler
skill_name: 内容 Brief 编译
contract_version: 0.1.0
contract_set_version: r1-contract-set-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-06
```

一句话职责：

```text
把用户已选择的 topic_card 编译成写文案前的 content_brief，锁定账号、热点事实、推导链、产品边界、内容目标、CTA 和禁区。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 选 T{topic_id}
    - 选题确认
    - 准备写文案
  upstream_artifact_status:
    - topic_status = topic_selected_for_brief
  allowed_manual_commands:
    - 回到选题卡补字段
    - 只做行业趋势
```

不得触发：

```text
没有已选择 topic_card。
topic_card 缺 source_research_run_id。
账号或产品对象边界缺失。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - topic_card
    - account_profile
    - product_profile 或 campaign_profile
  required_fields:
    - topic_id
    - source_research_run_id
    - topic_status
    - account
    - core_hotspot_fact
    - derivation_chain
    - weakest_jump
    - product_claim_boundary
    - must_not_say
  required_status:
    - topic_status = topic_selected_for_brief
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - topic_card
    - account_profile
    - product_profile
    - campaign_profile
  source_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/02-topic-card.md
    - accounts/{account_slug}/account_profile.md
    - objects/products/{product_profile_id}.md
    - objects/campaigns/{campaign_profile_id}.md
  required_fields:
    - topic_id
    - source_research_run_id
    - content_position
    - hotspot_freshness_status
    - target_audience
    - mother_topic
    - strategy
    - risk_notes
  validation_rules:
    - 不重新选题
    - 不新增热点事实
    - 不扩大产品能力
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type: content_brief
  target_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/03-content-brief.md
    - docs/reference/内容Brief记录.md
  required_fields:
    - brief_id
    - topic_id
    - source_research_run_id
    - account
    - content_goal
    - target_audience
    - core_point
    - hotspot_fact
    - derivation_chain
    - product_claim_boundary
    - must_not_say
    - content_format
    - cta
    - human_gate
    - brief_status
    - next_skill
  status_field: brief_status
  downstream_artifact: draft
```

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - intermediate/02-topic-card.md
  output_paths:
    - intermediate/03-content-brief.md
  index_paths:
    - docs/reference/内容Brief记录.md
```

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - brief_status = brief_pass
    - human_gate = no
  next_skill:
    brief_pass: copywriting-draft-writer
  forbidden_human_prompt:
    - 是否继续写口播？
    - 请回复继续写口播。
```

Brief 通过后不是人工门禁，必须自动进入口播草案。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: brief_blocked
    trigger: Brief 无法定住核心观点、事实风险、产品边界或 CTA
    reason: 写稿前上下文不稳会导致串号、硬卖或事实越界
    recommended_action: 回到 topic_card 或 product_profile 补字段
    human_reply_examples:
      - 回到选题卡补来源
      - 这条不带产品
      - CTA 改成关注账号
    auto_next_after_reply: content-brief-compiler
```

---

## 9. 失败处理

```yaml
failure_modes:
  topic_missing:
    recovery_action: 回到 hotspot-topic-research
  topic_not_selected:
    recovery_action: 等用户选择 topic_id
  missing_research_id:
    recovery_action: 补 source_research_run_id，不写 Brief
  product_boundary_unclear:
    recovery_action: 补 product_profile / campaign_profile
  core_point_unclear:
    recovery_action: brief_status = brief_blocked，给一句话观点补齐建议
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - topic_card -> content_brief 编译
    - Brief 自检
    - brief_pass 后自动推进
  agent_orchestrated:
    - 临时补核心观点或 CTA
```

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | topic_selected_for_brief 且字段齐全 | 输出 content_brief，brief_pass，自动进入 draft |
| missing_topic | 用户只说写文案 | 回到热点选题，不写 Brief |
| missing_research_id | topic_card 无 source_research_run_id | 阻断，要求补来源链 |
| product_risk | 产品边界不清 | brief_blocked，回补对象档案 |
| no_human_gate | Brief 通过 | 不问“继续写口播” |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - sample content_brief
  must_redact:
    - 真实账号策略
    - 真实产品未公开能力
  sample_required:
    - examples/sample-run/intermediate/03-content-brief.md
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| Brief 通过后是否停给用户 | 否 |
| Brief 是否可以补新热点事实 | 否 |
| Brief 的核心职责是否是锁上下文 | 是 |
