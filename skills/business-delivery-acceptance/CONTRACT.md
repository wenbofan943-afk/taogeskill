# Business Delivery Acceptance Contract

```yaml
skill_id: business-delivery-acceptance
contract_version: 0.1.0
status: active
input_contracts:
  - taoge://schemas/final-delivery/final-delivery/v0.9
  - taoge://schemas/r7/viewport-acceptance/v0.2
output_schema: taoge://schemas/r7/business-delivery-acceptance/v0.1
next_skill: propagation-router
```

The reviewer must inspect the exact screenshot hashes and actual delivery images. Technical viewport pass is necessary but never sufficient. Any failed dimension derives `business_delivery_rejected`; warnings derive `pass_with_warnings`; otherwise the result is `pass`.
