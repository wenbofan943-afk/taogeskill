# Spoken Script Review Contract

```yaml
skill_id: spoken-script-review
contract_version: 0.1.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
producer: spoken-script-review
outputs:
  - script_design_review@0.1.0
  - content_revision_decision@0.1.0
schemas:
  - templates/schema/r6/script-design-review.v0.1.schema.json
  - templates/schema/r6/content-revision-decision.v0.1.schema.json
revision_paths:
  - intermediate/contracts/revisions/script_design_review/{script_design_review_id}.json
  - intermediate/contracts/revisions/content_revision_decision/{content_revision_decision_id}.json
```

The review is immutable and read-only. Decisions are append-only and current-revision scoped. Readiness is derived from the current draft, structure, beat map, review, decision, accepted advisory issues, authorizations, and hard boundaries; it is never derived from a Hook or density score alone.
