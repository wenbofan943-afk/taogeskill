# Metadata Directory

本 dry-run 选择 `pending_external` 路径，因此没有 generated 图片，也没有 metadata sidecar。

如果后续把样本升级为 generated 路径，必须新增：

```text
IMG-SR3DR-001-001.json
```

并包含 `image_asset_id`、`asset_path`、`source_prompt_id`、`generation_run_id`、`prompt_used_full_path`、`generation_record_path`、`visual_plan_path`、`quality_gate_path`、`checksum` 等字段。

