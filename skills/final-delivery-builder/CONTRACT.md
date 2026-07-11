# Final Delivery Builder Contract

> 状态：active_with_p0_h4_evidence_runtime_v0_2
> contract_version：0.9.0
> contract_set_version：p0-evidence-runtime-v0.2
> 对应 skill：`skills/final-delivery-builder/SKILL.md`  
> 编译门禁：涛哥已确认 R3-C01 到 R3-C70，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: final-delivery-builder
skill_name: 最终交付页构建
contract_version: 0.9.0
contract_set_version: p0-evidence-runtime-v0.2
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-12
renderer_id: final_delivery_renderer
renderer_version: final-delivery-renderer-v0.2
legacy_renderer_version: 0.1.0
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
    - visual_text_plan
    - visual_text_quality_gate
    - final-platform-package 或 platform_package
    - cover_design_package
    - cover_composition
    - cover_quality_gate
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
    - cover_quality_gate_status = pass
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
    - visual_text_plan
    - visual_text_quality_gate
    - image_asset_set
    - image_generation_record
    - image_metadata_sidecar
    - quality_review
    - cover_design_package
    - cover_composition
    - cover_quality_gate
  source_path:
    - deliverables/content-delivery-record.md
    - intermediate/08-platform-package-draft.md
    - intermediate/04-draft.md
    - intermediate/05-visual-plan.md
    - intermediate/06-quality-review.md
    - intermediate/08-cover-design-package.md
    - intermediate/09-cover-compositions.md
    - intermediate/09-cover-quality-review.md
    - assets/images/image-assets.md
  required_fields:
    - topic_title
    - content_goal
    - script
    - image_assets_status
    - visual_text_plan_id
    - visual_text_quality_gate_status
    - platform_materials
    - recommended_cover_title
    - cover_design_package_id
    - cover_composition_id
    - cover_composition_status
    - platform_cover_strategy
    - cover_text_render_strategy
    - upload_readiness_status
    - cover_image_source
    - cover_layout
    - recommended_video_title
    - recommended_publish_description
    - recommended_hashtags
    - human_prompt
    - human_reply_examples
    - html_embed_manifest
  validation_rules:
    - 最终给人 HTML，不是一堆 MD
    - 图片缺失必须标状态
    - project_local 不能冒充可转交包
    - 平台物料必须分开展示封面标题、视频标题、发布描述和话题标签
    - 封面设计必须独立展示封面图来源、版式、安全区、平台差异和可下载图片 / 可复制 prompt
    - 不得用泛化“标题”替代封面标题或视频标题
    - R1CHK-019：manifest、execution_trace、image_asset_set 和实际文件对图片生成能力的记录必须一致
    - R3CHK：generated 图片必须有 asset_path 和 metadata_sidecar，pending / failed / manual 必须诚实展示
    - html_embed_manifest 每张图必须携带 visual_text_plan_id、visual_text_task_id、visual_text_decision、visual_text_unit_ids、visual_text_render_strategy 和 visual_text_quality_gate_status
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
    - visual_text_plan_id
    - visual_text_quality_gate_status
    - visual_text_delivery_summary
    - cover_design_package_id
    - cover_design_manifest
    - cover_composition_ids
    - cover_embeds
    - upload_ready_cover_count
    - prompt_only_cover_count
    - html_builder_mode
    - html_template_source
    - html_link_check_result
    - html_asset_check_result
    - html_embed_manifest_status
    - cover_quality_gate_status
    - static_visual_quality_gate_status
    - visual_text_quality_gate_status
    - asset_trace_quality_gate_status
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
| 重做封面 / 封面字不对 / 再加封面 / 某平台封面不满意 | `back_to_cover_composition` | `cover-design-compiler` | 只重跑封面合成、cover_review 和 final_delivery |
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
    recovery_action: html_embed_manifest_status = embed_needs_fix，回 image-asset-producer 补 generation_record
  pending_rendered_as_generated:
    recovery_action: trace_consistency_status = fail，修 HTML 展示为占位
  cover_background_rendered_as_final:
    recovery_action: final_delivery_status = blocked，改为底图标识或回 cover-design-compiler
  composition_ready_missing_output:
    recovery_action: final_delivery_status = blocked，回 cover-design-compiler
  cover_quality_not_pass:
    recovery_action: 回 copywriting-quality-review(cover_review)
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
    - cover_design_package 展示
    - export 包构建
    - 交付状态更新
    - R2 final checkpoint 写入
    - run_lock 释放
    - R3 html_embed_manifest 构建
    - R3 图片状态诚实展示
    - R3 封面设计包诚实展示
    - R3 cover_composition / cover_embeds 诚实展示
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
final_delivery_status = blocked；如不阻断，则只能写 final_delivery_status = html_ready，并在 execution_trace / workflow_check_report 中记录 warning
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
| cover_ready | composition_ready + gate pass | HTML 展示平台成品预览与下载 |
| cover_background_only | 只有底图 | 标记非成品，不显示可上传 |
| cover_prompt_only | 无法合成 | 展示可复制 prompt、版式和人工动作 |

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

## SAMPLE-SESSION-001 后新增字段

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
  renderer_version: final-delivery-renderer-v0.2
  legacy_renderer_version: 0.1.0
  default_template: templates/final-delivery/final-delivery.template.html
  checker: tools/validate-final-delivery-template.ps1
  target_builder_mode: skill_template_rendered
  p0_runtime_renderer: tools/invoke-workflow-runtime.ps1 -Mode render_final_delivery
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

## 15. P0-H4 v0.2 编译、渲染与过程证据合同

```yaml
p0_contract_status: h4_evidence_runtime_active
workflow_definition_version: p0-single-runtime-v0.2
contract_bundle_version: p0-contract-bundle-v0.2
render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.2
renderer_version: final-delivery-renderer-v0.2
schema_root: templates/schema/p0/
contract_checker: tools/validate-p0-h1-contracts.ps1
runtime_checker: tools/validate-p0-h2-runtime.ps1
fixture_root: examples/p0-runtime-v0.2-fixture/
h3_fixture_root: examples/p0-h3-recovery-fixtures/
h3_checker: tools/validate-p0-h3-fixtures.ps1
h4_evidence_runtime: tools/P0EvidenceRuntime.ps1
h4_command_entry: tools/invoke-p0-evidence.ps1
h4_fixture_root: examples/p0-h4-evidence-fixture/
h4_checker: tools/validate-p0-h4-evidence.ps1
```

H1 已编译版本钉住、event envelope、retry policy、artifact lineage / check 和 `typed_components_v0.2` 数据合同；H2 已激活 compiler / renderer：

```text
invoke-workflow-runtime.ps1 按 plan 版本分流；examples/p0-runtime-fixture 继续固定为 v0.1 legacy。
不得把 v0.1 的 *_html fragment 与 v0.2 typed cards 混用。
上游 agent 写 final-delivery-render-candidate.json；compile_render_input 重算 delivery_readiness 并生成官方 typed input。
renderer 只消费官方 typed input，内部完成上下文转义、相对链接、卡片排序和模板替换，并写 render receipt。
新 v0.2 plan 必须固定 schema / renderer / template 版本和 single cardinality。
外部副作用不自动重试；outcome_unknown 必须先 reconciliation。
materialized、quality pass、delivery eligibility 分开记录。
相同 input / renderer / template 必须生成相同 HTML digest；重复执行复用既有产物且不追加伪成功事件。
```

P0-H3 进入门禁已通过：`validate-p0-h1-contracts.ps1`、`validate-p0-h2-runtime.ps1`、`validate-field-schema.ps1`、旧 P0 runtime validate / resume 均通过。H3 已补 P0-F03 至 F19 的独立失败 / 恢复 fixture；每案必须独立提供 plan、events、最小状态 / 产物证据和 expected result，统一输出 `fixture_id / expected_state / actual_state / failure_category / resume_advice / fixture_result`。

H4 已实现统一 event writer、projection rebuild、orphan reconciliation 和五个 P0-E02 evidence commands：

```text
create_session_plan
record_agent_result
record_human_choice
record_external_result
build_resume_summary
```

两个维护操作：

```text
rebuild_projection
reconcile_orphan_artifact
```

所有事实 event 必须经同一个 writer 追加，使用 `event_type + idempotency_key` 去重、`expected_last_sequence_no` 并发保护、严格 sequence / previous event 校验。重复同 payload 返回 `duplicate_reused`；同 key 不同 payload 返回 `idempotency_conflict`；过期 event tail 返回 `concurrent_append_conflict`。

`state-projection.json` 与 `resume-summary.json` 是可重建投影，不是第二事实源。投影落后自动重建；投影领先或同尾号 digest 不一致返回 `state_projection_conflict`，只有显式 `rebuild_projection` 才能把旧投影保留到 session 内 quarantine 后重建。孤儿产物必须核对 plan、文件 digest、input digest 和 tool version，再采用或隔离；旧 event 永不改写。

`record_external_result` 只登记真实已发生、明确失败、结果未知或未获授权的外部动作，不主动联网、出图或发布。H4 通过不代表真实账号、真实图片、多篇并行或发布已测试；这些边界继续进入 H5 / H6。

