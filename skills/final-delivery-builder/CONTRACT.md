# Final Delivery Builder Contract

> 状态：confirmed_with_r3_asset_runtime  
> contract_version：0.3.0  
> contract_set_version：r3-asset-runtime-v0.1  
> 对应 skill：`skills/final-delivery-builder/SKILL.md`  
> 编译门禁：涛哥已确认 R3-C01 到 R3-C25，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: final-delivery-builder
skill_name: 最终交付页构建
contract_version: 0.3.0
contract_set_version: r3-asset-runtime-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-07
renderer_id: final_delivery_renderer
renderer_version: 0.1.0
html_template_source: templates/final-delivery/final-delivery.template.html
```

一句话职责：

```text
把已完成内容链路和图片资产链构建成人类可验收的 final-delivery.html，并按需生成 portable_bundle 或 standalone_html。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 生成最终交付
    - 构建 HTML
    - 导出转交包
    - 单文件 HTML
  upstream_artifact_status:
    - delivery_status = delivery_ready
    - package_status = package_pass
  allowed_manual_commands:
    - 导出转交包
    - 导出单文件 HTML
    - 记录发布结果
    - 归档今天不发
```

不得触发：

```text
没有 content_delivery_record。
平台包未完成。
用户要求自动发布。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - manifest.yaml
    - content_delivery_record
    - final-script 或 draft
    - final-visual-plan 或 visual_plan
    - final-platform-package 或 platform_package
    - docs/reference/R2-运行模型执行规范.md
  required_fields:
    - delivery_id
    - package_id
    - draft_id
    - visual_plan_id
    - topic_id
    - account
    - target_platforms
  required_status:
    - delivery_status = delivery_ready
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - content_delivery_record
    - platform_package
    - draft
    - visual_plan
    - image_asset_set
    - image_generation_record
    - image_metadata_sidecar
    - quality_review
  source_path:
    - deliverables/content-delivery-record.md
    - intermediate/08-platform-package-draft.md
    - intermediate/04-draft.md
    - intermediate/05-visual-plan.md
    - assets/images/image-assets.md
  required_fields:
    - topic_title
    - content_goal
    - script
    - image_assets_status
    - platform_materials
    - human_prompt
    - human_reply_examples
    - html_embed_manifest
  validation_rules:
    - 最终给人 HTML，不是一堆 MD
    - 图片缺失必须标状态
    - project_local 不能冒充可转交包
    - R1CHK-019：manifest、execution_trace、image_asset_set 和实际文件对图片生成能力的记录必须一致
    - R3CHK：generated 图片必须有 asset_path 和 metadata_sidecar，pending / failed / manual 必须诚实展示
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type:
    - final_delivery
    - portable_bundle
    - standalone_html
  target_path:
    - accounts/{account_slug}/runs/{session_id}/deliverables/final-delivery.html
    - accounts/{account_slug}/runs/{session_id}/deliverables/final-script.md
    - accounts/{account_slug}/runs/{session_id}/deliverables/final-visual-plan.md
    - accounts/{account_slug}/runs/{session_id}/deliverables/final-platform-package.md
    - accounts/{account_slug}/runs/{session_id}/deliverables/export/{session_id}/
  required_fields:
    - final_delivery_id
    - delivery_page_mode
    - final_delivery_status
    - image_assets_status
    - html_builder_mode
    - html_template_source
    - html_link_check_result
    - html_asset_check_result
    - html_embed_manifest_status
    - generated_image_count
    - pending_image_count
    - failed_image_count
    - manual_required_count
    - rejected_image_count
    - missing_sidecar_count
    - export_status
    - human_prompt
    - human_reply_examples
    - task_after_navigation
    - trace_consistency_status
    - recovery_evidence_status
    - r2_runtime_status
    - latest_checkpoint
    - state_transition_id
    - run_lock
    - resume_report
  status_field:
    - final_delivery_status
    - export_status
  downstream_artifact: human_confirm / done
```

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - deliverables/content-delivery-record.md
    - intermediate/
    - assets/images/
  output_paths:
    - deliverables/final-delivery.html
    - deliverables/export/{session_id}/
  index_paths:
    - 工作流状态记录.md
    - accounts/{account_slug}/index.md
    - indexes/all_runs.md
    - intermediate/checkpoints/latest.md
    - intermediate/branch-summary.md
```

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - final_delivery_status = html_ready
  next_skill:
    html_ready: human_final_review
  forbidden_human_prompt:
    - 是否发布？
    - 是否自动发布？
```

HTML 完成后停给用户验收，给认可、人工发布记录、局部返工、归档或导出选项。
局部返工不是新 session，也不是让用户再说“继续”；必须写入 `delivery_status=delivery_needs_fix`、`revision_path`、`next_skill`，返工完成后自动重新生成 final-delivery.html。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: final_delivery_review
    trigger: final-delivery.html 已生成
    reason: 人需要验收最终可读交付物
    recommended_action: 人工发布或局部返工
    human_reply_examples:
      - 认可
      - 记录为已确认
      - 记录发布结果
      - 只改抖音标题
      - 回到口播改前 5 秒
      - 回到画中画改首屏图
      - 导出转交包
      - 归档今天不发
    auto_next_after_reply: publish_record / local_revision / export_bundle / archive
```

局部返工映射：

| 用户说法 | revision_path | next_skill | 自动收口 |
|---|---|---|---|
| 只改抖音标题 / 只改小红书标题 / 平台包装重来 | `back_to_platform_package` | `platform-packaging-adapter` | 重新生成 platform_package、content_delivery_record、final_delivery |
| 回到口播改前 5 秒 / 正文信息密度不够 | `back_to_draft` | `copywriting-draft-writer` | 重跑 draft 后续链路并重新生成 final_delivery |
| 回到画中画改首屏图 / 图片不行 / 插入位置不对 | `back_to_visual_plan` | `talking-head-image-pip` | 重跑 visual_plan 后续链路并重新生成 final_delivery |
| 事实风险 / 产品承诺风险 / 不能这么说 | `back_to_quality_review` | `copywriting-quality-review` | 重跑 review 后续链路并重新生成 final_delivery |
| 选题方向不对 | `back_to_topic_card` | `hotspot-topic-research` | 回到选题链路，不复用旧 final_delivery |

---

## 9. 失败处理

```yaml
failure_modes:
  missing_delivery_record:
    recovery_action: 回到 platform-packaging-adapter
  missing_image:
    recovery_action: 标记 pending_external / manual_required，不阻塞无图 HTML
  generated_missing_sidecar:
    recovery_action: final_delivery_status = blocked 或把该图改为 generation_failed，补 sidecar 后再展示为 generated
  generation_record_missing:
    recovery_action: html_embed_manifest_status = embed_needs_fix，回 talking-head-image-pip 补 generation_record
  pending_rendered_as_generated:
    recovery_action: trace_consistency_status = fail，修 HTML 展示为占位
  broken_project_local_link:
    recovery_action: 修相对链接
  export_link_broken:
    recovery_action: export_status = export_needs_fix
  user_requests_publish:
    recovery_action: 拦截自动发布，只记录人工发布结果
  r2_missing_checkpoint:
    recovery_action: 回写 latest_checkpoint 和 state_transition 后再收口
  r2_lock_conflict:
    recovery_action: final_delivery_status = blocked，先由 propagation-router 输出 resume_report
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - final-delivery.html 构建
    - 图片状态标记
    - export 包构建
    - 交付状态更新
    - R2 final checkpoint 写入
    - run_lock 释放
    - R3 html_embed_manifest 构建
    - R3 图片状态诚实展示
  environment_capability:
    - image_generation
    - local_file_render
```

最终交付完成时必须写入 trace 收口摘要：

```text
是否调用 image_generation。
实际图片数量、路径和 image_status。
generation_record、metadata_sidecar、html_embed_manifest 状态。
HTML 链接检查结果。
final_delivery_status。
delivery_page_mode。
如果发生断流，manifest + execution_trace 是否足以判断当前阶段。
latest_checkpoint、state_transition_id、run_lock 和 resume_report。
```

如果任一文件显示 `image_assets_status = all_generated / partially_generated`，但 execution_trace 写“未使用图片生成能力”，必须标记：

```text
trace_consistency_status = fail
final_delivery_status = blocked 或 pass_with_warnings
required_backwrite = docs/reference/skill执行透明度与成熟度规范.md / 对应 execution_trace
```

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | delivery_ready，图片存在 | final-delivery.html，html_ready |
| missing_image | 图片未生成 | HTML 标 pending_external，不假装有图 |
| generated_missing_sidecar | generated 图片无 sidecar | 阻断或降级，不展示为 generated |
| missing_generation_record | 图片状态存在但无生成记录 | embed_needs_fix，回补记录 |
| pending_external | 只有 prompt，等待外部工具 | HTML 展示占位、插入位置和可复制 prompt |
| trace_conflict | 图片已生成但 trace 写未使用图片生成 | trace_consistency_status = fail，回写 trace 后再收口 |
| export_request | 用户说导出转交包 | 生成 export 包，链接闭合 |
| standalone_request | 用户要单文件 | 生成 standalone_html |
| publish_request | 用户要自动发 | 拦截，只支持人工发布记录 |
| r2_child_close | child session 完成最终 HTML | 写 latest_checkpoint，释放 run_lock，更新 branch-summary，进入 fan-in 等待或完成 |
| agent_handcrafted_html | HTML 由 agent 临场拼装 | final_delivery 可用于本轮验收，但必须记录 html_builder_mode=agent_handcrafted_html，不能作为 L3 独立样本 |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - sample final-delivery.html
  must_redact:
    - 真实图片
    - 真实发布链接
    - 真实客户信息
  sample_required:
    - examples/sample-run/deliverables/final-delivery.html
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| 最终产物是否以 HTML 为人类入口 | 是 |
| 图片缺失是否阻塞 HTML | 否，但必须标状态 |
| project_local 是否可直接转交 | 否 |

## S20260707-001 后新增字段

```text
html_builder_mode
html_template_source
html_link_check_result
html_asset_check_result
export_package_check_result
```

规则：

```text
html_builder_mode=skill_template_rendered 才能计入 skill 独立成熟度证据。
html_builder_mode=agent_handcrafted_html 时，必须在 execution_trace 和 workflow_check_report 中标 warn。
portable_bundle 必须带 export-manifest.json、assets/、sources/、manifest-sha256.txt，并且包内链接检查为 pass。
```

## 14. B 批模板化合同

```yaml
renderer:
  renderer_id: final_delivery_renderer
  renderer_version: 0.1.0
  default_template: templates/final-delivery/final-delivery.template.html
  checker: tools/validate-final-delivery-template.ps1
  target_builder_mode: skill_template_rendered
```

模板必须覆盖：

```text
delivery_meta
topic_rationale
final_script
picture_in_picture
platform_package
trace_links
human_final_review
```

生成 project_local HTML 时，默认输出：

```yaml
html_builder_mode: skill_template_rendered
html_template_source: templates/final-delivery/final-delivery.template.html
html_link_check_result: pass / fail / not_run
html_asset_check_result: pass / fail / not_run
final_delivery_status: html_ready / blocked
```

降级规则：

```text
模板缺失、模板检查失败、核心输入字段缺失、链接或图片状态无法判定时，不得宣称 skill_template_rendered。
如必须临场拼装 HTML，只能写 html_builder_mode=agent_handcrafted_html，并在 execution_trace / workflow_check_report 中标 warning。
```
