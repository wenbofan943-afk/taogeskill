# HTML Embed Manifest

```yaml
html_embed_manifest_id: HEM-SR3DR-001
image_asset_set_id: IMGSET-SR3DR-001
visual_text_plan_id: VTP-SR3DR-001
visual_text_quality_gate_status: pass
cover_design_package_id: CDP-SR3DR-001
html_embed_manifest_status: embed_ready
```

| embed_id | image_asset_id | image_asset_type | visual_text_task_id | visual_text_decision | visual_text_unit_ids | visual_text_render_strategy | visual_text_quality_gate_status | display_mode | source_prompt_path | generation_record_path | status_label | human_note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| EMB-SR3DR-001-001 | IMG-SR3DR-001-001 | picture_in_picture_image | VTT-SR3DR-001-001 | forbidden | none | no_text | pass | placeholder_prompt | ../intermediate/05-visual-plan.md#PROMPT-SR3DR-001-001 | ../assets/images/generation-records/GEN-SR3DR-001-001.md | 待外部生成 | 本图按计划无字；当前样本展示占位和提示词 |
| EMB-SR3DR-001-COVER | COVER-SR3DR-001-001 | cover_image | not_applicable | forbidden | none | prompt_only | not_applicable | cover_prompt | ../intermediate/09-cover-compositions.md | ../assets/images/generation-records/GEN-SR3DR-001-001.md | 待外部生成 | 封面图只交付 Seedream 入参，不冒充实际图片 |

## cover_embeds

| platform | cover_composition_id | platform_cover_strategy | cover_background_asset_id | cover_composited_asset_id | platform_cover_asset_id | display_path | download_path | cover_title | video_title | cover_composition_status | quality_gate_status | prompt_path_if_not_generated | trace_path |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sample_platform | CC-SR3DR-001 | prompt_only | COVER-SR3DR-001-001 |  |  |  |  | 画中画不是装饰 | 为什么画中画不能只看数量 | prompt_only | pass | ../intermediate/09-cover-compositions.md | ../intermediate/09-cover-quality-review.md |
