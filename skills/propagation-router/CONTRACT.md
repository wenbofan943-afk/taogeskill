# propagation-router contract

```yaml
contract_id: propagation-router-v0.6
user_entry: true
input_artifact_type: entry_router_request
output_artifact_type: router_decision
allowed_intents: [start, resume, next_action]
max_selected_next_nodes: 1
owned_node_ids: []
reads:
  - active_workflow_plan
  - current_workflow_state
  - current_artifact
writes:
  - router_decision
forbidden_outputs:
  - topic_selection_decision
  - final_delivery_human_decision
  - workflow_session_record
  - business_content
  - checker_result
```

The router selects but does not execute one registered next node. Human choices
are delegated to their internal gate Skills; deterministic recorders own state
writes.
