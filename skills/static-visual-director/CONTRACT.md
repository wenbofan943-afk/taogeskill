# Static Visual Director Contract

```yaml
skill_id: static-visual-director
contract_version: 0.5.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
inputs: current draft + selected structure + structure_bound beat map + script readiness
outputs:
  - visual_need_analysis@0.4.0
  - visual_coverage_ledger@0.1.0
schemas:
  - templates/schema/r3/visual-need-analysis.v0.4.schema.json
  - templates/schema/r3/visual-coverage-ledger.v0.1.schema.json
human_projection: intermediate/05-visual-plan.md
```

Coverage is complete only when every current beat has one valid primary disposition and all references close. Content asset count is 0..N and unbounded. Counts for unique current tasks/assets, Image 2 tasks/attempts, capture tasks/attempts, occurrences, renditions, and covers are independent and deterministically derived.

The current account visual identity is bound by `identity_id`. Any justified departure records `identity_override_reason`; account identity constrains expression but cannot set image count.

For newly activated account assets, the identity and selected column template use the v0.2 account-bound contracts and must match the session `account_identity_id` / `account_technical_slug`. A v0.1 historical draft may replay, but it is not a current cross-account activation proof.
