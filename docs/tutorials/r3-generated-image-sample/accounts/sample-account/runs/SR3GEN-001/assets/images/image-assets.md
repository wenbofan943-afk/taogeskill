# Image Asset Set

```yaml
image_asset_set:
  image_asset_set_id: IMGSET-SR3GEN-001
  visual_plan_id: VP-SR3GEN-001
  source_research_run_id: R-SAMPLE-R3GEN-001
  account: sample-account
  required_count: 1
  optional_count: 0
  generated_count: 1
  pending_count: 0
  failed_count: 0
  rejected_count: 0
  image_assets_status: all_generated
  source_of_truth:
    visual_plan_path: ../../intermediate/05-visual-plan.md
    prompt_set_path: ../../intermediate/05-visual-plan.md
    generation_records_dir: generation-records/
    metadata_dir: metadata/
  assets:
    - image_asset_id: IMG-SR3GEN-001-001
      image_task_id: IMGTASK-SR3GEN-001-001
      beat_id: VB-SR3GEN-001-001
      source_prompt_id: PROMPT-SR3GEN-001-001
      generation_run_id: GEN-SR3GEN-001
      generation_attempt_ids:
        - GEN-SR3GEN-001-001
      provider: codex_builtin_imagegen
      model: builtin
      provider_mode: codex_builtin
      input_schema_version: imagegen-skill-v1
      asset_path: IMG-SR3GEN-001-001.png
      metadata_sidecar_path: metadata/IMG-SR3GEN-001-001.metadata.yaml
      asset_mime: image/png
      width: 1672
      height: 941
      aspect_ratio: "16:9"
      asset_version: 1
      parent_asset_id: none
      supersedes_asset_id: none
      insert_after_text: "现在二手车商最难的，不是车源少，而是客户越来越不轻易相信你。"
      insert_before_text: "你说车况没问题，客户会问：证据在哪？"
      prompt_used: generation-records/GEN-SR3GEN-001-001.md
      prompt_used_full_path: generation-records/GEN-SR3GEN-001-001.md
      image_status: generated
      asset_status_detail: local_file_exists_and_checksum_recorded
      failure_reason: none
      human_action_required: none
      risk_check_notes: no_people_no_plate_no_logo_no_real_product_ui
      quality_gate_status: pass
  artifact_path: assets/images/image-assets.md
  next_skill: final-delivery-builder
```
