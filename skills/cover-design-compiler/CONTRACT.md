# Cover Design Compiler Contract

> 状态：active
> contract_version：0.2.0
> contract_set_version：r3-cover-composition-v0.2
> 对应 skill：`skills/cover-design-compiler/SKILL.md`
> 编译门禁：涛哥已确认 R3-C46 到 R3-C70，允许进入字段、Skill、模板和 checker 编译。

## 1. 身份

```yaml
skill_id: cover-design-compiler
skill_name: 封面设计与成品合成
contract_version: 0.2.0
contract_set_version: r3-cover-composition-v0.2
owner_project: taoge-creative-workflow
status: active
confirmed_by: taoge
confirmed_at: 2026-07-11
```

一句话职责：把平台包装的封面标题和视觉资产编译为 `cover_design_package -> cover_composition -> cover_composited_asset / platform_cover_asset`，无法合成时诚实交付 `prompt_only`。

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 做封面成品
    - 给封面加字
    - 重做某个平台封面
  upstream_artifact_status:
    - package_status = package_pass
    - visual_plan_status = visual_plan_pass
  allowed_manual_commands:
    - 重做抖音封面
    - 再加一个封面方案
    - 改封面字但不改视频标题
```

不得触发：平台包未通过、封面标题缺失、用户要求自动发布或视频渲染。

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - platform_package
    - cover_variant_set
    - visual_plan
    - image_asset_set
  required_fields:
    - package_id
    - source_research_run_id
    - target_platforms
    - recommended_cover_title
    - visual_plan_id
    - image_asset_set_id
  required_status:
    - package_status = package_pass
    - visual_plan_status = visual_plan_pass
```

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - platform_package
    - cover_variant_set
    - visual_plan
    - image_asset_set
  source_path:
    - intermediate/08-platform-package-draft.md
    - intermediate/05-visual-plan.md
    - assets/images/image-assets.md
  required_fields:
    - recommended_cover_title
    - recommended_video_title
    - platform_notes
    - cover_variant_set_id
    - cover_visual_entry_type
    - cover_variant_difference_type
    - materially_distinct_variant_count
    - image_asset_id
    - image_asset_type
    - cover_asset_role
    - asset_path
  validation_rules:
    - 封面标题和视频标题分开
    - 背景资产必须属于当前 session
    - source_research_run_id 不变
    - 不覆盖已有 image_asset_id
    - 旧 variant_role 只读迁移，不与 cover_visual_entry_type 双写
    - title_only 不计 materially_distinct_variant_count
    - 设计合同、真实渲染和平台预览状态不得互相矛盾
```

## 5. 输出合同

```yaml
outputs:
  artifact_type:
    - cover_design_package
    - cover_composition
    - image_asset_set
  target_path:
    - intermediate/08-cover-design-package.md
    - intermediate/09-cover-compositions.md
    - assets/images/covers/
    - assets/images/image-assets.md
    - assets/images/generation-records/
    - assets/images/metadata/
  required_fields:
    - cover_design_package_id
    - cover_composition_id
    - cover_asset_role
    - cover_text_render_strategy
    - platform_cover_strategy
    - cover_composition_status
    - source_background_asset_id
    - output_asset_id
    - output_path
    - next_skill
    - thumbnail_readability_status
    - cover_contract_render_alignment_status
    - platform_preview_status
    - platform_preview_evidence_path
  status_field:
    - cover_design_status
    - cover_composition_status
  downstream_artifact: cover_quality_gate
```

`prompt_only` 允许没有 output asset，但必须有完整 prompt、layout、安全区、目标平台和人工动作。

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - intermediate/08-platform-package-draft.md
    - intermediate/05-visual-plan.md
    - assets/images/image-assets.md
  output_paths:
    - intermediate/08-cover-design-package.md
    - intermediate/09-cover-compositions.md
    - assets/images/covers/{image_asset_id}.png
    - assets/images/generation-records/{cover_composition_id}.md
    - assets/images/metadata/{image_asset_id}.md
```

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - cover_design_status = cover_design_pass
    - cover_composition_status = composition_ready / prompt_only
  next_skill:
    composition_ready: copywriting-quality-review
    prompt_only: copywriting-quality-review
  next_mode: cover_review
  forbidden_human_prompt:
    - 是否继续做封面质检？
    - 是否生成最终 HTML？
```

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: cover_creative_choice
    trigger: 两个封面方向存在真实传播取舍且无默认优胜方案
    reason: 点击入口和账号风格需要人判断
    recommended_action: 默认推荐一个，同时允许用户选另一个
    human_reply_examples:
      - 按推荐继续
      - 选冲突型
      - 选证据型
    auto_next_after_reply: cover-design-compiler
```

## 9. 失败处理

```yaml
failure_modes:
  missing_platform_title:
    recovery_action: 回到 platform-packaging-adapter
  missing_background_asset:
    recovery_action: Codex 回 image-asset-producer；非 Codex 转 prompt_only
  text_accuracy_failed:
    recovery_action: 改 deterministic_overlay / manual_design
  output_exists:
    recovery_action: 新建 image_asset_id，禁止覆盖
  composition_unavailable:
    recovery_action: cover_composition_status=prompt_only
  safe_area_failed:
    recovery_action: 只返工 cover_composition
  misleading_or_privacy_risk:
    recovery_action: composition_needs_fix，不进入 final delivery
```

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - cover_design_package 编译
    - platform_cover_strategy 判定
    - cover_text_render_strategy 判定
    - deterministic overlay
    - cover_composition 记录
    - image_asset_set 更新
  environment_capability:
    - local_image_composition
  manual_fallback:
    - prompt_only
    - manual_design
```

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | package_pass + 本地底图 | 输出合成 PNG 和 composition_ready |
| reuse | 抖音 / 快手可共用 | 一张 composited asset，策略为 reuse |
| platform_variant | 小红书需改标题和比例 | 新 platform_cover_asset，不覆盖主封面 |
| bad_model_text | 模型含字错字 | 改 deterministic_overlay，不进 final |
| no_composer | 非 Codex / 无合成器 | prompt_only，保留完整提示词和版式 |
| output_exists | 输出路径已存在 | 新建 image_asset_id |
| privacy_risk | 图中含联系方式 | composition_needs_fix，阻断 |
| title_only_variants | 只换标题却计为两个视觉方案 | variant set needs_fix |
| render_mismatch | 设计合同和成品主体 / 版式不一致 | alignment needs_fix |
| preview_unavailable | 无平台预览工具 | unavailable/not_checked，诚实 warning |

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - SKILL / CONTRACT
    - compose-cover.ps1
    - 脱敏封面样例
  must_redact:
    - 真实账号封面
    - 真实运行图片
    - 未授权字体和品牌资产
  sample_required:
    - docs/tutorials/r3-dry-run-sample/
  external_dependency:
    - Windows System.Drawing for deterministic overlay; otherwise prompt_only
```
