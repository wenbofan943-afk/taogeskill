# Platform Packaging Adapter Contract

> 状态：confirmed_for_compilation  
> contract_version：0.1.0  
> contract_set_version：r1-contract-set-v0.1  
> 对应 skill：`skills/platform-packaging-adapter/SKILL.md`  
> 编译门禁：涛哥已确认 R1，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: platform-packaging-adapter
skill_name: 多平台分发包装
contract_version: 0.1.0
contract_set_version: r1-contract-set-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-06
```

一句话职责：

```text
把通过质检的同一条短视频内容编译为 platform_package_input，并生成抖音、快手、小红书、视频号的入口包装和 content_delivery_record。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 生成平台标题
    - 做分发包
    - 发抖音/快手/小红书/视频号
  upstream_artifact_status:
    - review_status = review_pass
  allowed_manual_commands:
    - 只改抖音标题
    - 重做小红书标题
```

不得触发：

```text
质检未通过。
用户要求改口播正文。
用户要求自动发布或登录平台。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - content_brief
    - draft
    - visual_plan
    - quality_review
  required_fields:
    - review_id
    - review_status
    - draft_id
    - visual_plan_id
    - target_platforms
  required_status:
    - review_status = review_pass
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - quality_review
    - draft
    - visual_plan
    - content_brief
  source_path:
    - intermediate/06-quality-review.md
    - intermediate/04-draft.md
    - intermediate/05-visual-plan.md
  required_fields:
    - recommended_hook
    - first_5_seconds_script
    - first_screen_visual_task
    - core_point
    - product_claim_boundary
    - risk_words
    - cta
  validation_rules:
    - 不改视频主体
    - 只改平台入口包装
    - 不承诺平台流量结果
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type:
    - platform_package_input
    - platform_package
    - content_delivery_record
  target_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/07-platform-package-input.md
    - accounts/{account_slug}/runs/{session_id}/intermediate/08-platform-package-draft.md
    - accounts/{account_slug}/runs/{session_id}/deliverables/content-delivery-record.md
  required_fields:
    - package_input_id
    - package_id
    - delivery_id
    - target_platforms
    - cover_title_options
    - video_title_options
    - publish_description_options
    - hashtag_sets
    - recommended_package
    - manual_publish_notes
    - package_status
    - delivery_status
    - next_skill
  status_field:
    - package_status
    - delivery_status
  downstream_artifact: final_delivery
```

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - intermediate/06-quality-review.md
  output_paths:
    - intermediate/07-platform-package-input.md
    - intermediate/08-platform-package-draft.md
    - deliverables/content-delivery-record.md
```

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - package_status = package_pass
    - delivery_status = delivery_ready
  next_skill:
    delivery_ready: final-delivery-builder
  forbidden_human_prompt:
    - 是否确认采用？
    - 是否生成最终交付？
    - 是否继续？
```

平台包完成后不再设置人工“确认采用”门禁，自动进入最终 HTML 构建。  
最终 HTML 才是人工验收点。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: package_blocked
    trigger: 平台包装输入不足或平台边界冲突
    reason: 入口包装可能误导平台或产品能力
    recommended_action: 回到 quality_review / draft 做最小返工
    human_reply_examples:
      - 只改抖音标题
      - 回到口播改前 5 秒
      - 弱化产品露出
    auto_next_after_reply: platform-packaging-adapter 或 copywriting-draft-writer
```

---

## 9. 失败处理

```yaml
failure_modes:
  review_not_pass:
    recovery_action: 回到 copywriting-quality-review
  rewrite_body_requested:
    recovery_action: 回到 copywriting-draft-writer
  platform_api_requested:
    recovery_action: 拦截，说明只支持人工发布物料
  package_missing_delivery_record:
    recovery_action: 先补 content_delivery_record
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - platform_package_input 编译
    - 多平台入口包装
    - content_delivery_record 生成
    - delivery_ready 后自动推进
```

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | review_pass | 生成 input、package、delivery_record，自动 final-delivery |
| no_review | 无质检 | 回到质检 |
| body_rewrite | 用户要改正文 | 回到 draft |
| api_request | 用户要自动发布 | 拦截 |
| missing_record | package 有但 delivery_record 无 | 补交付记录 |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - sample platform_package
  must_redact:
    - 真实平台账号
    - 真实发布链接
  sample_required:
    - examples/sample-run/intermediate/08-platform-package-draft.md
    - examples/sample-run/deliverables/content-delivery-record.md
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| 平台包是否改视频主体 | 否 |
| 平台包完成后是否问“确认采用” | 否 |
| 是否支持自动发布 | 否 |
