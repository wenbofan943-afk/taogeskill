# Sample Quality Review

```yaml
review_id: QR-SR3DR-001
draft_id: D-SR3DR-001
static_visual_director_plan_id: SVDP-SR3DR-001
visual_plan_id: VP-SR3DR-001
review_status: review_pass
visual_quality_gate_status: pass
static_visual_quality_gate_status: pass
cover_quality_gate_status: pass
prompt_integrity_status: pass
image_asset_trace_status: pass
asset_trace_quality_gate_status: pass
html_embed_readiness_status: pass
next_skill: final-delivery-builder
```

## Review Notes

本样本只检查 R3 图片资产链，不评价真实图片质量。  
由于 `image_status = pending_external`，HTML 必须展示占位、插入位置和可复制提示词，不得显示为已生成图片。
本样本已区分 `picture_in_picture_image` 与 `cover_image`，并使用 `image_production_path = seedream_prompt_delivery` 作为非 Codex 降级路径。
