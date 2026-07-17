# topic-selection-decision-gate contract

```yaml
contract_id: topic-selection-decision-gate-v0.1
current_node: topic_human_gate
input_contracts:
  - topic-selection-panel-v0.1
  - typed-human-reply-v0.1
  - r7-action-registry-v0.3
output_artifact_type: topic_selection_decision
output_schema_ref: taoge://schemas/r7/topic-selection-decision/v0.1
allowed_result_statuses:
  - decision_committed
  - waiting_human
  - blocked
commit_owner: deterministic_submitter
forbidden_outputs:
  - topic_selection_panel
  - selected_topic_source
  - current_pointer
  - execution_event
```

The Skill maps an explicit reply to one allowed action. It cannot rerank or
mutate the current panel and cannot create the selected source.
