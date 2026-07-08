# Copywriting Quality Review Contract

> 状态：confirmed_with_r3_asset_runtime
> contract_version：0.3.0
> contract_set_version：r3-asset-runtime-v0.1
> 对应 skill：`skills/copywriting-quality-review/SKILL.md`
> 编译门禁：涛哥已确认 R3-C01 到 R3-C25，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: copywriting-quality-review
skill_name: 文案与视觉联合质检
contract_version: 0.3.0
contract_set_version: r3-asset-runtime-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-07
```

一句话职责：

```text
检查口播草案和画中画资产链的事实、产品承诺、涛哥味、Hook 路由、正文信息密度、共鸣兑现、口播流畅度、视觉贴合度和图片资产可追溯性，决定通过、返工或阻断。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 检查文案
    - 能不能发
    - 有没有 AI 味
    - 画中画合不合适
  upstream_artifact_status:
    - draft_status = draft_created
    - visual_plan_status = visual_plan_pass
  allowed_manual_commands:
    - 按建议改口播
    - 重做首屏画中画
    - 回到 Brief
```

不得触发：

```text
没有 draft。
需要画中画但 visual_plan 缺失。
用户要求直接发布。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - content_brief
    - draft
    - visual_plan
    - image_asset_set
  required_fields:
    - draft_id
    - script
    - recommended_hook
    - hook_score
    - hook_route
    - content_promise
    - body_payoff
    - segment_map
    - body_information_density_score
    - core_mechanism
    - visual_plan_id
    - beats
    - product_claim_boundary
  required_status:
    - draft_status = draft_created
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - content_brief
    - draft
    - visual_plan
  source_path:
    - intermediate/03-content-brief.md
    - intermediate/04-draft.md
    - intermediate/05-visual-plan.md
  required_fields:
    - core_point
    - product_claim_boundary
    - must_not_say
    - script
    - hook_route
    - body_payoff
    - segment_map
    - core_mechanism
    - image_prompts
    - image_generation_record
    - image_asset_set
    - retention_task
    - prompt_integrity_check
    - acceptance_criteria
  validation_rules:
    - 不重写全文
    - 不新增产品承诺
    - 不把质检通过等同于已发布
    - R1CHK-018：有图不等于通过，画中画必须服务留存任务并贴合口播当下语义
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type: quality_review
  target_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/06-quality-review.md
    - docs/explanation/dbskill质检记录.md
  required_fields:
    - review_id
    - draft_id
    - visual_plan_id
    - review_status
    - blocking_issues
    - hook_route_score
    - promise_payoff_status
    - body_information_density_score
    - logic_continuity_status
    - core_mechanism_status
    - resonance_status
    - stance_consistency_status
    - segment_density_issues
    - must_fix_segments
    - copy_suggestions
    - visual_suggestions
    - visual_quality_gate_status
    - prompt_integrity_status
    - image_asset_trace_status
    - html_embed_readiness_status
    - risk_notes
    - recommended_action
    - human_prompt
    - human_reply_examples
    - next_skill
  status_field: review_status
  downstream_artifact: platform_package_input
```

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - intermediate/04-draft.md
    - intermediate/05-visual-plan.md
  output_paths:
    - intermediate/06-quality-review.md
  index_paths:
    - docs/explanation/dbskill质检记录.md
```

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - review_status = review_pass
    - blocking_issues = empty
    - promise_payoff_status = pass
    - body_information_density_score >= 7
    - core_mechanism_status = pass
  next_skill:
    review_pass: platform-packaging-adapter
  forbidden_human_prompt:
    - 是否继续做分发包？
    - 是否进入平台包装？
```

质检通过后自动进入平台包装，不停给用户。

自动推进还必须满足：

```text
prompt_integrity_status = pass
visual_quality_gate_status = pass
image_asset_trace_status = pass
html_embed_readiness_status = pass
```

如果图片存在但像泛素材、只装饰、不服务留存任务，`review_status` 必须为 `review_needs_visual_fix`，不得 `review_pass`。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: review_blocked
    trigger: review_status != review_pass
    reason: 发布风险、质量风险或产品误解风险未清
    recommended_action: 给最小返工路径
    human_reply_examples:
      - 按建议改口播
      - 重做首屏画中画
      - 回到 Brief
    auto_next_after_reply: copywriting-draft-writer / talking-head-image-pip / content-brief-compiler
```

---

## 9. 失败处理

```yaml
failure_modes:
  missing_visual_plan:
    recovery_action: 回到 talking-head-image-pip，除非 Brief 明确不需要画中画
  hook_low_score:
    recovery_action: review_needs_copy_fix
  hook_route_unclear:
    recovery_action: review_needs_copy_fix，回 draft 重定 Hook 路由
  promise_not_paid_off:
    recovery_action: review_needs_copy_fix，补正文兑现段或换 Hook
  body_low_density:
    recovery_action: review_needs_copy_fix，标 must_fix_segments
  core_mechanism_unclear:
    recovery_action: review_needs_brief_fix
  product_risk:
    recovery_action: review_blocked，回 Brief
  ai_tone_high:
    recovery_action: review_needs_copy_fix
  visual_mismatch:
    recovery_action: review_needs_visual_fix
  visual_generic_or_decorative:
    recovery_action: review_needs_visual_fix，回 talking-head-image-pip 重做画中画
  prompt_integrity_failed:
    recovery_action: review_needs_visual_fix，回 talking-head-image-pip 补完整 prompt 卡
  image_asset_trace_failed:
    recovery_action: review_needs_visual_fix，回 talking-head-image-pip 补 generation_record / sidecar / 状态
  html_embed_not_ready:
    recovery_action: review_needs_visual_fix，回 talking-head-image-pip 或 final-delivery-builder 补 html_embed_manifest
  generated_missing_sidecar:
    recovery_action: review_needs_visual_fix，generated 图片补 sidecar 或改 generation_failed
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - 联合质检
    - Hook 路由质检
    - 正文信息密度质检
    - 共鸣与兑现质检
    - review_status 判定
    - 通过后自动推进
    - R1CHK-018 视觉质检门
    - R3CHK 图片资产链检查
    - image_asset_trace_status 判定
    - html_embed_readiness_status 判定
  agent_orchestrated:
    - 临场新增质检维度
```

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | draft + visual_plan 均可用 | review_pass，自动平台包装 |
| product_risk | 暗示截流 / 自动私信 | review_blocked |
| weak_hook_route | Hook 类型不清，正文无法兑现 | review_needs_copy_fix |
| body_low_density | 正文重复、没有信息增量 | review_needs_copy_fix，标 must_fix_segments |
| core_unclear | 核心机制说不清 | review_needs_brief_fix |
| ai_tone | 太模板 | review_needs_copy_fix |
| visual_mismatch | 首屏图和 Hook 不接 | review_needs_visual_fix |
| visual_generic | 图片存在但像泛素材，不能帮助观众多停 2-5 秒 | review_needs_visual_fix |
| prompt_integrity_failed | visual_plan 的 prompt 卡不完整 | review_needs_visual_fix，回 talking-head-image-pip |
| image_asset_trace_failed | generated 缺 sidecar / pending 被当成 generated / 缺 generation_record | review_needs_visual_fix |
| html_embed_not_ready | final HTML 无法区分图片、占位、失败或 rejected 隐藏 | review_needs_visual_fix |
| missing_visual | 需要画中画但缺 plan | 回 talking-head-image-pip |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - sample quality_review
  must_redact:
    - 真实未公开质检记录
  sample_required:
    - examples/sample-run/intermediate/06-quality-review.md
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| 质检通过后是否自动平台包装 | 是 |
| 质检是否能直接改稿 | 否，只给建议和路由 |
| 产品承诺风险是否一票阻断 | 是 |
| Hook 承诺未兑现是否阻断 | 是 |
| 正文信息密度不足是否阻断 | 是 |
