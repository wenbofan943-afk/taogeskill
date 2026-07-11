---
name: final-delivery-builder
description: 涛哥创作工作流最终交付构建 skill。Use when the content, platform package, cover compositions, cover quality gate, and image assets are ready, and Codex must render a human-readable final-delivery.html or export a portable_bundle / standalone_html. It displays upload-ready covers, cover backgrounds, platform variants, prompt-only fallbacks, scripts, picture-in-picture assets, and platform materials without generating new strategy, auto-publishing, logging in, or calling external image APIs.
---

# Final Delivery Builder

## R2 Contract Runtime

```yaml
contract_set_version: r2-runtime-v0.1
contract_version: 0.2.0
contract_status: confirmed
skill_type: builder
primary_input: content_delivery_record(delivery_status=delivery_ready)
primary_output: final_delivery / export_bundle
next_skill_on_pass: human_final_review
```

## R3 Asset Delivery Runtime

```yaml
contract_set_version: r3-asset-runtime-v0.2
contract_version: 0.6.0
contract_status: confirmed
skill_type: asset_delivery_builder
primary_input: content_delivery_record + visual_text_plan + visual_text_quality_gate + image_asset_set + cover_design_package + cover_composition + cover_quality_gate
primary_output: final_delivery + html_embed_manifest + visual_text_delivery_summary + cover_embeds + cover_design_manifest / export_bundle
next_skill_on_pass: human_final_review
reference: docs/reference/R3-图片资产执行规范.md
renderer_id: final_delivery_renderer
renderer_version: 0.1.0
html_template_source: templates/final-delivery/final-delivery.template.html
template_checker: tools/validate-final-delivery-template.ps1
```

执行口径：

```text
R3 下，本 skill 不是图片事实源，只负责把 image_asset_set 诚实展示到 final-delivery.html。
必须读取 `docs/reference/R3-图片资产执行规范.md` 的 HTML 嵌入规则、状态边界和 R3CHK 检查项。
generated 图片展示预览和下载；pending_external 展示占位、Seedream 格式可复制 prompt（含画幅/尺寸参数）和去豆包/即梦生成指引；generation_failed 展示失败原因和重试建议；manual_required 展示人工任务；rejected 默认隐藏到追溯区。
cover_background_asset、cover_composited_asset、platform_cover_asset 必须在封面区分开；picture_in_picture_image 必须展示在画中画区。不得把封面标题或封面底图当作可上传成品。
含字画中画必须展示可复制视觉文字、文字角色和必要来源；无字画中画不得展示空文字字段。详细决策链接回 visual_text_plan。
```

R3 交接块：

```text
每次输出必须包含：
contract_set_version：r3-asset-runtime-v0.2
final_delivery_id：
image_asset_set_id：
visual_text_plan_id：
visual_text_quality_gate_status：pass / fail / not_applicable / not_run
visual_text_delivery_summary：
cover_design_package_id：
cover_composition_ids：
html_embed_manifest_status：embed_ready / embed_needs_fix / embed_blocked
image_assets_status：all_generated / partially_generated / pending_external / generation_failed / manual_required / mixed / not_required
cover_quality_gate_status：pass / fail / not_applicable / not_run
upload_ready_cover_count：
prompt_only_cover_count：
static_visual_quality_gate_status：pass / fail / not_applicable / not_run
asset_trace_quality_gate_status：pass / fail / not_applicable / not_run
generated_image_count：
pending_image_count：
failed_image_count：
manual_required_count：
rejected_image_count：
missing_sidecar_count：
trace_consistency_status：
r3_check_summary：
artifact_path：
next_skill：
```

执行口径：

```text
本 skill 是人类验收入口构建器，只生成 final-delivery.html、图片资产记录和可选转交包。
按 `docs/reference/R1-skill渐进读取与长文边界.md` 执行渐进读取；先读当前 Runtime、输入、输出形态、状态写入和交接块，导出细节按需读取。
最终交付给人看优先 HTML；Markdown、generation_record 和 metadata_sidecar 只做追溯材料，不替代 final-delivery.html。
project_local、portable_bundle、standalone_html 必须区分清楚。
默认必须使用 `templates/final-delivery/final-delivery.template.html` 渲染 project_local HTML，并记录 `html_builder_mode=skill_template_rendered`。只有模板缺失、字段严重不足或人工临场修复时，才允许降级为 `agent_handcrafted_html`，且必须在 trace / review 中标 warning。
P0 runtime 已确认时，renderer 只能读取 `deliverables/p0/final-delivery-render-input.json`；先由上游 agent_required 步骤编译该输入，再运行 `tools/invoke-workflow-runtime.ps1 -Mode render_final_delivery`。不得由 renderer 临场解析或补写上游 Markdown。
R1CHK-019：最终交付收口时必须检查 manifest、execution_trace、image_asset_set 和实际图片文件是否自洽。
R1CHK-020：最终交付完成后，manifest + execution_trace 必须足以判断是否已到 human_final_review，断流恢复时不得重跑已完成内容链路。
R2：最终交付完成时必须写 latest_checkpoint、state_transition、run_lock 释放记录和 resume_report；如果是 child session，还要更新 branch-summary 或等待 fan-in。
```

读、取、传规则：

```text
读：manifest、content_delivery_record、draft、visual_plan、visual_text_plan、quality_review、visual_text_quality_gate、platform_package、cover_design_package、cover_composition、cover_quality_gate、image_asset_set。
取：只从 session 内标准产物取文案、图片、插入位置、平台物料和追溯链接；`visual_text_delivery_summary` 由本 skill 根据 visual_text_plan、visual_text_quality_gate 和 image_asset_set 计算，不得要求上游预先提供。
传：final_delivery 必须带 final_delivery_id、delivery_id、source_research_run_id、entrypoint_path、delivery_page_mode、final_delivery_status、image_assets_status、visual_text_plan_id、visual_text_quality_gate_status、visual_text_delivery_summary、cover_composition_ids、cover_embeds、upload_ready_cover_count、prompt_only_cover_count、html_embed_manifest_status、export_status、artifact_path、next_skill。
传：还必须带 trace_consistency_status、recovery_evidence_status；如发现 trace 与实际产物冲突，先回写 trace，不把冲突样本说成完整通过。
传：R2 场景还必须带 task_context_type、content_run_id、parent_session_id、branch_request_id、fan_in_status、latest_checkpoint、state_transition_id、run_lock、resume_report。
```

验收门禁：

```text
final_delivery_status=html_ready / bundle_ready / standalone_ready 后，进入 human_final_review。
允许用户 approve / edit / archive / export / publish_record / cancel。
不允许自动发布、登录平台、自动评论、私信或互动。
human_final_review 不是“问用户要不要继续”，而是给最终验收处理菜单。
用户提出 edit 时，必须写 revision_path、delivery_status=delivery_needs_fix 和 next_skill；返工完成后自动回到 final-delivery-builder 重建 HTML，不要求用户再说“继续”。
```

R2 交接块：

```text
每次输出必须包含：
contract_set_version：r2-runtime-v0.1
final_delivery_id：
delivery_id：
package_id：
image_asset_set_id：
account：
source_research_run_id：
delivery_page_mode：
entrypoint_path：
final_delivery_status：
image_assets_status：
export_status：
artifact_path：
next_skill：
human_gate：yes
allowed_decisions：approve / edit / archive / export / publish_record / cancel
execution_trace_update：
r2_runtime_status：
latest_checkpoint：
state_transition_id：
run_lock：
resume_report：
```

## 使命

把已经通过选题确认并完成内容链路的内容，从后台 Markdown 交接物整理成人类可用的交付结果。

本 skill 解决：

```text
用户能不能直接看懂。
文案能不能直接复制。
图片能不能预览和下载。
平台物料能不能直接拿走。
HTML 离开项目目录后会不会断链。
AI 能不能从 manifest 恢复来源。
```

## 边界

不做：

```text
自动发布。
平台登录。
自动评论、私信或互动。
外部图片 API 接入。
Seedream API 调用。
视频剪辑、渲染或上传。
```

## 输入

必须读取：

```text
accounts/{账号名}/runs/{session_id}/manifest.yaml
docs/reference/R2-运行模型执行规范.md
deliverables/content-delivery-record.md
deliverables/final-script.md
deliverables/final-visual-plan.md
deliverables/final-platform-package.md
assets/images/image-assets.md
assets/images/generation-records/
assets/images/metadata/
intermediate/02-topic-card.md
intermediate/03-content-brief.md
intermediate/05-visual-plan.md
intermediate/06-quality-review.md
intermediate/08-cover-design-package.md
intermediate/09-cover-compositions.md
intermediate/09-cover-quality-review.md
```

如果图片资产不存在：

```text
1. 先按 visual_plan 和 R3 图片资产执行规范检查 required 图片资产链。
2. 如果当前环境可出图，回到 image-asset-producer 按完整 prompt_card 生成必要图片，写入 assets/images/，并写 generation_record 与 metadata_sidecar。
3. 如果当前环境不能出图，写 image_status = pending_external / generation_failed / manual_required。
3. 不得假装图片已经生成。
```

## 输出形态

### 1. project_local

默认输出：

```text
deliverables/final-delivery.html
```

用途：

```text
项目内验收。
AI 恢复。
深度追溯。
```

链接规则：

```text
允许用相对路径链接 session 内 intermediate、assets、deliverables。
必须标记 delivery_page_mode = project_local。
不得把 project_local 页面单独说成可转交包。
```

### 2. portable_bundle

当用户说“发给别人 / 传网盘 / 交付客户 / 拿到别的电脑看”时输出：

```text
deliverables/export/{session_id}/
├── final-delivery.html
├── assets/images/
├── sources/
│   ├── generation-records/
│   └── metadata/
├── export-manifest.json
└── manifest-sha256.txt
```

链接规则：

```text
HTML 内所有图片和来源链接必须指向 export 包内部。
不得链接回原 session 目录。
```

### 3. standalone_html

当用户明确要单文件交付时输出：

```text
deliverables/export/{session_id}/final-delivery-standalone.html
```

规则：

```text
图片用 data URI 或等价方式内嵌。
关键追溯材料用摘要或折叠区内嵌。
必须提示：standalone_html 适合人类验收，不替代完整后台链路。
```

## HTML 必备内容

```text
1. 选题与切口：选题、为什么做、目标、热点来源、时效、内容定位。
2. 正式文案：推荐标题、Hook、完整口播、一键复制。
3. 画中画：实际图片或诚实占位、下载入口、插入位置、对应口播段落、可复制视觉文字、文字角色、必要来源、生成记录和 sidecar 追溯；无字图不展示空文字字段。
4. 封面设计：按平台展示封面标题、视频标题、底图、可上传成品、平台变体、下载、版式、安全区、平台策略、prompt_only 降级和追溯链接。
5. 发布物料：各平台封面标题、视频标题、描述、标签、人工发布备注。
6. 追溯材料：topic_card、content_brief、draft、visual_plan、visual_text_plan、visual_text_quality_gate、quality_review、platform_package、cover_design_package、delivery_record。
```

页面顶部必须明确：

```text
选题已确认，内容链路已自动完成。
未自动发布。
不登录平台。
不自动评论、私信或互动。
delivery_page_mode。
```

## 状态写入

更新：

```text
manifest.yaml
content-delivery-record.md
工作流状态记录.md
accounts/{账号名}/README.md
accounts/{账号名}/index.md
indexes/all_runs.md
intermediate/checkpoints/latest.md
intermediate/branch-summary.md
```

必须写入：

```text
delivery_page_mode：project_local / portable_bundle / standalone_html
final_delivery_status：html_ready / bundle_ready / standalone_ready / needs_export / blocked
image_assets_status：all_generated / partially_generated / pending_external / generation_failed / manual_required / mixed / not_required
html_embed_manifest_status：embed_ready / embed_needs_fix / embed_blocked
cover_quality_gate_status：pass / fail / not_applicable / not_run
upload_ready_cover_count：整数
prompt_only_cover_count：整数
static_visual_quality_gate_status：pass / fail / not_applicable / not_run
asset_trace_quality_gate_status：pass / fail / not_applicable / not_run
export_status：not_requested / export_ready / export_needs_fix / export_blocked
trace_consistency_status：pass / fail / pass_with_warnings
recovery_evidence_status：sufficient / insufficient
r2_runtime_status：checkpoint_written / checkpoint_missing / lock_conflict / fan_in_waiting / fan_in_ready
latest_checkpoint：intermediate/checkpoints/latest.md
state_transition_id：ST{YYYYMMDD}-{序号}
run_lock：run_lock_released / run_lock_conflict
resume_report：最后可信节点、已完成节点、可安全继续动作、不能自动重跑动作
```

R2 收口规则：

```text
final_delivery_status=html_ready / bundle_ready / standalone_ready 时，必须写最终 checkpoint。
如果 manifest 显示 run_lock=run_lock_acquired，完成后改为 run_lock_released。
如果 parent_session_id 不为空，更新 child 的 branch-summary，并把父任务 fan_in_status 改为 fan_in_waiting_children 或 fan_in_ready。
如果 checkpoint 或 run_lock 信息缺失，不直接宣称完成；先补写 R2 运行证据。
```

## 质检

完成前必须检查：

```text
HTML 本地引用是否存在。
图片文件是否存在且非空。
image_asset_set、generation_records、metadata_sidecar、manifest 和 execution_trace 对图片状态的说法是否一致。
如果 image_assets_status = all_generated / partially_generated，execution_trace 不得写“未使用图片生成能力”。
如果图片是 pending_external / generation_failed，不得在 HTML 中展示为已生成。
如果 image_status = generated，但缺 metadata_sidecar_path，必须阻断或改为 generation_failed。
如果 image_status = rejected，默认不得进入主要画中画展示区。
如果 image_asset_type = cover_image，必须进入封面设计区或追溯区，不得只混在画中画列表里。
如果缺 cover_design_package / cover_composition / cover_quality_gate，不得把 recommended_cover_title 当作封面设计；默认 `final_delivery_status=blocked`。
如果 cover_composition_status=composition_ready，必须有 output_asset_id、output_path、cover_asset_role=cover_composited_asset / platform_cover_asset，且 cover_quality_gate_status=pass。
如果 cover_composition_status=prompt_only，HTML 必须显示完整 prompt、版式、安全区和人工动作，不得显示“成品可上传”。
如果只有 cover_background_asset，必须标“封面底图，非成品”。
每个平台必须展示 platform_cover_strategy：reuse / crop / retitle / independent_composition / prompt_only。
html_embed_manifest 是否能说明每张图的 display_mode、download_path、source_prompt_path、generation_record_path、metadata_sidecar_path、visual_text_task_id、visual_text_decision、visual_text_unit_ids、visual_text_render_strategy 和 visual_text_quality_gate_status。
manifest + execution_trace 是否足以支持断流后恢复判断。
复制按钮是否存在。
下载入口是否存在。
project_local 是否误称为可转交包。
portable_bundle 是否仍链接原 session 目录。
工作流链接检查 BROKEN_COUNT = 0。
图片-beat 对应关系验证：每张图片必须有对应的 beat_id、出现时间、口播文本和提示词，且图片文件名必须与 beat_id 一致。
```

trace 收口摘要必须写入 `intermediate/00-execution-trace.md`：

```text
final_delivery_builder_check：
  trace_consistency_status：
  image_generation_used：yes / no / not_available
  generated_image_count：
  pending_image_count：
  failed_image_count：
  manual_required_count：
  rejected_image_count：
  missing_sidecar_count：
  html_embed_manifest_status：
  linked_image_count：
  link_check_result：
  recovery_evidence_status：
  next_resume_action：
  r2_runtime_status：
  latest_checkpoint：
  state_transition_id：
  run_lock：
```

如果浏览器不能打开 `file://`，不绕过安全策略；改用静态引用检查和图片尺寸检查。

## 用户交互引导语

本 skill 生成的是最终人类验收入口，不是发布动作。完成后必须告诉用户当前 HTML 的可用范围，以及下一步怎么选。

project_local 完成时使用：

```text
最终交付页已经生成，适合在本项目里验收。你可以打开 HTML 复制文案、下载图片、查看平台物料。

如果满意，回复“认可”或“记录为已确认”；如果要小修，回复“只改抖音标题”“只改小红书标题”“回到口播改前 5 秒”“回到画中画改首屏图”或“平台包装重来”，我会回到对应环节修完并重新生成 HTML；如果要发给别人，回复“导出转交包”；如果只想要一个文件，回复“导出单文件 HTML”；人工发布后，回复“记录发布结果”；如果今天不发，回复“归档今天不发”。
```

局部返工映射：

```text
只改抖音标题 / 只改小红书标题 / 平台包装重来 -> revision_path=back_to_platform_package，next_skill=platform-packaging-adapter
重做封面 / 封面字不对 / 再加一个封面 / 某平台封面不满意 -> revision_path=back_to_cover_composition，next_skill=cover-design-compiler
回到口播改前 5 秒 / 正文信息密度不够 -> revision_path=back_to_draft，next_skill=copywriting-draft-writer
回到画中画改首屏图 / 图片不行 / 插入位置不对 -> revision_path=back_to_visual_plan，next_skill=talking-head-image-pip
事实风险 / 不能这么说 / 产品承诺风险 -> revision_path=back_to_quality_review，next_skill=copywriting-quality-review
选题方向不对 -> revision_path=back_to_topic_card，next_skill=hotspot-topic-research
```

portable_bundle 完成时使用：

```text
可转交包已经生成，里面的 HTML、图片和来源都在同一个包里，离开项目目录也不会断链。你可以把这个包发给别人；人工发布后，回复“记录发布结果”。
```

standalone_html 完成时使用：

```text
单文件 HTML 已经生成，适合快速发给别人验收。它方便阅读和转发，但不替代完整后台链路；如果以后要复盘，仍以 session 目录和 manifest 为准。
```

## SAMPLE-SESSION-001 反写规则

真实大循环 `SAMPLE-SESSION-001` 暴露出：final-delivery.html 能被 agent 手工构建出来，但这不能自动证明本 skill 已达到 L3。后续必须区分：

```text
skill_template_rendered：按固定模板 / 模板清单生成，字段、链接、图片、平台包和追溯区可检查。
agent_handcrafted_html：agent 临场拼装 HTML，只能算本轮交付成功，不能算 skill 独立成熟。
```

从本规则生效后，`final_delivery` 必须额外记录：

```text
html_builder_mode：skill_template_rendered / agent_handcrafted_html / external_manual
html_template_source：模板路径或 none
html_link_check_result：pass / fail / not_run
html_asset_check_result：pass / fail / not_run
export_package_check_result：pass / fail / not_requested / not_run
```

判定：

```text
如果 html_builder_mode = agent_handcrafted_html，则 checker 至少给 warn，且本轮不得作为 L3 样本。
如果用户要发给别人，必须生成 portable_bundle，并检查 export 包内链接；project_local 页面不能冒充可转交包。
```

B 批模板化规则：

```text
默认模板：templates/final-delivery/final-delivery.template.html
模板检查：tools/validate-final-delivery-template.ps1
通过模板生成 project_local HTML 时：
  html_builder_mode = skill_template_rendered
  html_template_source = templates/final-delivery/final-delivery.template.html
  html_link_check_result = pass / fail / not_run
  html_asset_check_result = pass / fail / not_run
模板不可用或 agent 临场拼装时：
  html_builder_mode = agent_handcrafted_html
  html_template_source = none
  workflow_check_report 必须至少 warning
```

图片无法生成时使用：

```text
当前环境不能直接生成图片，我已经为每张画中画编译了 Seedream 格式的提示词。你可以在 HTML 页面中复制提示词，粘贴到豆包或即梦生成图片；如果不想等图，也可以回复”先交付无图版”。
```

输出交接物必须包含：

```text
human_prompt
human_reply_examples
recommended_action
auto_next_action
task_after_navigation
```

不要写：

```text
请确认。
是否导出？
下一步怎么做？
等待人工处理。
```
