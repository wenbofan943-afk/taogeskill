# Delivery Visual Reviewer Contract

```yaml
skill_id: delivery-visual-reviewer
contract_version: 0.2.0
status: active_h3_direct_v05
role: delivery_reviewer
inputs: current delivery assets + final HTML + desktop/mobile screenshots
output_schema: taoge://schemas/r3/delivery-visual-review/v0.1
runtime: tools/invoke-r7-visual-semantic.ps1
runtime_mode: finalize_delivery_review
next_on_pass: business-delivery-acceptance
blueprint_node: delivery_visual_review
```

The reviewer must inspect final, revision-scoped evidence. Producer and reviewer roles are disjoint. A revision verdict names the minimal target, owning producer and stale scope; the reviewer never mutates the delivery.
