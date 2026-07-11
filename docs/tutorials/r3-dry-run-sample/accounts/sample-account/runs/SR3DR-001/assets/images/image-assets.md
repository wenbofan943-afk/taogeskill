# Image Asset Set

```yaml
image_asset_set_id: IMGSET-SR3DR-001
visual_plan_id: VP-SR3DR-001
source_research_run_id: R-SR3DR-001
account: sample-account
required_count: 1
optional_count: 1
generated_count: 0
pending_count: 1
failed_count: 0
rejected_count: 0
image_assets_status: pending_external
source_of_truth: this_file
artifact_path: assets/images/image-assets.md
next_skill: copywriting-quality-review
```

## Assets

| image_asset_id | image_asset_type | cover_asset_role | source_cover_composition_id | target_platforms | image_production_path | visual_text_plan_id | visual_text_unit_ids | image_task_id | source_prompt_id | generation_run_id | image_status | insert_after_text | insert_before_text | asset_path | metadata_sidecar_path |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| IMG-SR3DR-001-001 | picture_in_picture_image | not_applicable | not_applicable | sample_platform | seedream_prompt_delivery | VTP-SR3DR-001 | none | IMGTASK-SR3DR-001-001 | PROMPT-SR3DR-001-001 | GEN-SR3DR-001 | pending_external | 别急着给短视频加图，先问一句： | 如果一张图只是好看，但和这句话没关系 |  |  |
| COVER-SR3DR-001-001 | cover_image | cover_background_asset | CC-SR3DR-001 | sample_platform | seedream_prompt_delivery | VTP-SR3DR-001 | none | COVER-TASK-SR3DR-001-001 | PROMPT-SR3DR-001-001 | GEN-SR3DR-001 | pending_external | 封面设计区 | 封面设计区 |  |  |

## Fallback

```yaml
image_asset_id: IMG-SR3DR-001-001
image_asset_type: picture_in_picture_image
image_production_path: seedream_prompt_delivery
image_generation_decision: deliver_prompt_only
prompt_delivery_mode: html_copyable_prompt
fallback_status: pending_external
human_action_required: 使用内置 image 或外部图片工具按完整 prompt 生成图片后，补写 asset_path、metadata_sidecar_path 和 checksum
prompt_used_full_path: intermediate/05-visual-plan.md#PROMPT-SR3DR-001-001
generation_record_path: assets/images/generation-records/GEN-SR3DR-001-001.md
```
