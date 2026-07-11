# Content Delivery Record

```yaml
delivery_id: DEL-SR3DR-001
session_id: SR3DR-001
package_id: PKG-SR3DR-001
package_input_id: PIN-SR3DR-001
review_id: QR-SR3DR-001
draft_id: D-SR3DR-001
brief_id: B-SR3DR-001
topic_id: T-SR3DR-001
visual_plan_id: VP-SR3DR-001
visual_text_plan_id: VTP-SR3DR-001
image_asset_set_id: IMGSET-SR3DR-001
cover_variant_set_id: CVS-SR3DR-001
source_research_run_id: R-SR3DR-001
account: sample-account
cover_design_package_id: CDP-SR3DR-001
cover_composition_ids:
  - CC-SR3DR-001
cover_quality_gate_id: CQG-SR3DR-001
delivery_status: delivery_ready
image_assets_status: pending_external
visual_text_quality_gate_status: pass
final_delivery_status: html_ready
delivery_page_mode: project_local
approval_status: approval_pending
publish_status: publish_not_started
export_status: not_requested
artifact_path: deliverables/content-delivery-record.md
next_skill: final-delivery-builder
```

## Human Handling

本样本用于 R3 dry-run，不用于发布。  
如需升级成真实样本，先生成图片并补齐 metadata sidecar，再重新跑 R3DR 检查。
