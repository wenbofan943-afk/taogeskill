# final-delivery-decision-gate contract

```yaml
contract_id: final-delivery-decision-gate-v0.1
current_node: final_human_decision_gate
input_contracts:
  - final-delivery-v0.9
  - viewport-acceptance-report-v0.2
  - delivery-visual-review-v0.1
  - business-delivery-acceptance-v0.1
  - typed-human-reply-v0.1
output_artifact_type: final_delivery_human_decision
output_schema_ref: taoge://schemas/r7/final-delivery-human-decision/v0.1
allowed_result_statuses:
  - decision_recorded
  - waiting_human
  - blocked
commit_owner: deterministic_submitter
apply_owner: final_delivery_decision_apply
```

Conditional fields:

- `request_revision` requires `delivery_revision_request_ref`; `export_mode`
  must be null.
- `request_export` requires `export_mode`; revision request must be null.
- `adopt_delivery` and `archive_session` require both to be null.

The Skill never edits delivery artifacts or performs the selected action.
