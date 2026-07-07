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

| image_asset_id | image_task_id | beat_id | source_prompt_id | generation_run_id | image_status | insert_after_text | insert_before_text | asset_path | metadata_sidecar_path |
|---|---|---|---|---|---|---|---|---|---|
| IMG-SR3DR-001-001 | IMGTASK-SR3DR-001-001 | B-SR3DR-001-01 | PROMPT-SR3DR-001-001 | GEN-SR3DR-001 | pending_external | 别急着给短视频加图，先问一句： | 如果一张图只是好看，但和这句话没关系 |  |  |

## Fallback

```yaml
image_asset_id: IMG-SR3DR-001-001
fallback_status: pending_external
human_action_required: 使用内置 image 或外部图片工具按完整 prompt 生成图片后，补写 asset_path、metadata_sidecar_path 和 checksum
prompt_used_full_path: intermediate/05-visual-plan.md#PROMPT-SR3DR-001-001
generation_record_path: assets/images/generation-records/GEN-SR3DR-001-001.md
```

