# Final Delivery Builder Contract

```yaml
skill_id: final-delivery-builder
contract_version: 0.10.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
plan_schema_id: taoge://schemas/p0/session-execution-plan/v0.5
render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.5
renderer_version: final-delivery-renderer-v0.5
template_version: final-delivery-template-v0.5
template_source: templates/final-delivery/final-delivery.v0.5.template.html
legacy_policy: v0.2_v0.3_v0.4_readonly_replay_and_reproduction
```

New delivery consumes current structure, beat, script review/decision, coverage ledger, alignment, platform, cover, and asset revisions. It writes all synchronized views from one typed revision and writes the physical delivery commit marker last. Business-visible readiness is re-derived; upstream labels are never trusted without closure checks.
