# Static Visual Director Contract

```yaml
skill_id: static-visual-director
contract_version: 0.8.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.5+p0-delivery-v0.8
inputs: current draft + selected structure + structure_bound beat map + script readiness
outputs:
  - visual_need_analysis@0.5.0
  - visual_coverage_ledger@0.2.0
  - visual_intent_decision@0.1
  - visual_source_route_decision@0.1
  - visual_prompt_brief@0.1 (generated_context only)
  - visual_stage_set@0.1 (current direct/hotspot v0.5 aggregation)
schemas:
  - templates/schema/r3/visual-need-analysis.v0.5.schema.json
  - templates/schema/r3/visual-coverage-ledger.v0.2.schema.json
  - templates/schema/r3/visual-source-routing.v0.1.schema.json
  - templates/schema/r3/asset-reuse-authorization.v0.1.schema.json
  - templates/schema/r3/visual-intent-decision.v0.1.schema.json
  - templates/schema/r3/visual-source-route-decision.v0.1.schema.json
  - templates/schema/r3/visual-prompt-brief.v0.1.schema.json
  - templates/schema/r3/visual-stage-set.v0.1.schema.json
human_projection: intermediate/05-visual-plan.md
```

Coverage is complete only when every current beat has one valid primary disposition and all references close. Content asset count is 0..N and unbounded. Counts for unique current tasks/assets, Image 2 tasks/attempts, capture tasks/attempts, occurrences, renditions, and covers are independent and deterministically derived.

Current tasks use the exclusive source-class union. Source evidence uses a real capture plus R6 deterministic annotation; exact existing assets require scoped authorization; every other accepted visual is generated context with an Image 2 base. Deterministic primary visuals are historical replay only.

The current account visual identity is bound by `identity_id`. Any justified departure records `identity_override_reason`; account identity constrains expression but cannot set image count.

For newly activated account assets, the identity and selected column template use the v0.2 account-bound contracts and must match the session `account_identity_id` / `account_technical_slug`. A v0.1 historical draft may replay, but it is not a current cross-account activation proof.

The visual director owns semantic intent, source classification and generated-context brief only. Provider/operation compilation is deterministic. Asset and delivery reviews belong to separate reviewer task envelopes.
