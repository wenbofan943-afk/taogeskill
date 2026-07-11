# Sample Quality Review

```yaml
review_id: QR-SR3DR-001
draft_id: D-SR3DR-001
static_visual_director_plan_id: SVDP-SR3DR-001
visual_plan_id: VP-SR3DR-001
review_status: review_pass
visual_quality_gate_status: pass
static_visual_quality_gate_status: pass
visual_text_quality_gate_status: pass
cover_quality_gate_status: not_applicable
prompt_integrity_status: pass
image_asset_trace_status: pass
asset_trace_quality_gate_status: pass
html_embed_readiness_status: pass
next_skill: final-delivery-builder
```

## Visual Text Quality Gate

```yaml
visual_text_quality_gate_id: VTQG-SR3DR-001-001
visual_text_plan_id: VTP-SR3DR-001
image_task_id: IMGTASK-SR3DR-001-001
image_asset_id: IMG-SR3DR-001-001
information_delta_status: pass
narration_redundancy_status: pass
subtitle_redundancy_status: not_available
glance_comprehension_score: 8
mobile_readability_score: 8
cognitive_load_status: pass
source_binding_status: not_required
text_accuracy_status: not_applicable
quality_gate_status: pass
blocking_issues: []
recovery_action: none
next_skill: platform-packaging-adapter
```

## Review Notes

本样本只检查 R3 图片资产链，不评价真实图片质量。  
由于 `image_status = pending_external`，HTML 必须展示占位、插入位置和可复制提示词，不得显示为已生成图片。
本样本已区分 `picture_in_picture_image` 与 `cover_image`，并使用 `image_production_path = seedream_prompt_delivery` 作为非 Codex 降级路径。
