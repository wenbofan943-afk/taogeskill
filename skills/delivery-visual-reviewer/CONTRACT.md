# Delivery Visual Reviewer Contract

```yaml
skill_id: delivery-visual-reviewer
contract_version: 0.1.0
status: active_h2_compiled
role: delivery_reviewer
inputs: current delivery assets + final HTML + desktop/mobile screenshots
output_schema: taoge://schemas/r3/delivery-visual-review/v0.1
runtime: tools/invoke-r7-visual-semantic.ps1
runtime_mode: finalize_delivery_review
next_on_pass: business-delivery-acceptance
```

The reviewer must inspect final, revision-scoped evidence. Producer and reviewer roles are disjoint. A revision verdict names the minimal target, owning producer and stale scope; the reviewer never mutates the delivery.
