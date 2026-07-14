# Content Brief Compiler Contract

> 状态：confirmed_for_compilation
> contract_version：0.2.0
> contract_set_version：r1-contract-set-v0.1
> 对应 skill：`skills/content-brief-compiler/SKILL.md`
> 编译门禁：涛哥已确认 R1，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: content-brief-compiler
skill_name: 内容 Brief 编译
contract_version: 0.2.0
contract_set_version: r1-contract-set-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-06
```

一句话职责：

```text
把用户已选择的 topic_card 或已验证的 direct_content_card 编译成写文案前的 content_brief，锁定内容来源、账号、事实 / 观点边界、产品边界、内容目标、CTA 和禁区。
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
    - direct_content_status = direct_content_ready
  allowed_manual_commands:
    - 回到选题卡补字段
    - 只做行业趋势
```

不得触发：

```text
既没有已选择 topic_card，也没有已验证 direct_content_card。
热点入口缺 source_research_run_id；直供入口缺原稿 digest、revision_policy 或 claim_map。
账号或产品对象边界缺失。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - topic_card 或 direct_content_card
    - account_profile
    - product_profile 或 campaign_profile
  required_fields:
    - content_source_id
    - content_origin
    - account
    - product_claim_boundary
    - must_not_say
  alternative_source_contracts:
    hotspot: topic_id + source_research_run_id + topic_status=topic_selected_for_brief + core_hotspot_fact + derivation_chain + weakest_jump
    direct: direct_content_status=direct_content_ready + original_draft.sha256 + revision_policy + claim_map
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - topic_card
    - direct_content_card
    - account_profile
    - product_profile
    - campaign_profile
  source_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/02-topic-card.md
    - accounts/{account_slug}/runs/{session_id}/intermediate/01-direct-content-card.json
    - accounts/{account_slug}/account_profile.md
    - objects/products/{product_profile_id}.md
    - objects/campaigns/{campaign_profile_id}.md
  required_fields:
    - content_source_id
    - content_origin
    - content_position
    - hotspot_freshness_status
    - target_audience
    - mother_topic
    - strategy
    - risk_notes
  validation_rules:
    - 热点入口不重新选题或新增热点事实
    - 直供入口不伪造 topic_id / source_research_run_id
    - 直供入口继承原稿改写边界和主张地图
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
    - content_source_id
    - content_origin
    - account
    - content_goal
    - target_audience
    - core_point
    - product_claim_boundary
    - must_not_say
    - content_format
    - cta
    - human_gate
    - brief_status
    - next_skill
  source_specific_fields:
    hotspot_selected_topic: topic_id + source_research_run_id + hotspot_fact + derivation_chain
    user_supplied_draft: original_draft_artifact_id + original_draft_digest + revision_policy + claim_map
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
    - intermediate/01-direct-content-card.json
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
    recommended_action: 回到当前 content source（topic_card / direct_content_card）或 product_profile 补字段
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
  direct_content_invalid:
    recovery_action: 回到 direct-content-intake 修复原稿 digest、改写边界、主张地图或 lineage
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
    - direct_content_card -> content_brief 编译
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
| direct_happy_path | direct_content_ready 且原稿 digest / 改写边界 / 主张地图齐全 | 不伪造 topic_id / research_run_id，输出 content_brief 并自动进入 draft |
| direct_fake_topic | 直供入口携带伪造的 topic_id / source_research_run_id | 阻断并回 direct-content-intake |
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

## 13. 已确认口径

| 问题 | 推荐结论 |
|---|---|
| Brief 通过后是否停给用户 | 否 |
| Brief 是否可以补新热点事实 | 否 |
| Brief 的核心职责是否是锁上下文 | 是 |
| 直供稿是否必须伪造选题或研究 ID | 否；使用 content_source_id / content_origin |
