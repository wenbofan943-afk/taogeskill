# propagation-router contract

```yaml
contract_id: propagation-router-v0.7
user_entry: true
input_artifact_type: entry_router_request
output_artifact_type: router_decision
allowed_intents: [start, resume, next_action]
max_selected_next_nodes: 1
owned_node_ids: []
reads:
  - current_workflow_ir_session_generation_policy
  - committed_session_runtime_binding
  - active_workflow_plan
  - current_workflow_state
  - current_artifact
writes:
  - router_decision
deterministic_delegates:
  - tools/invoke-workflow-session-entry.ps1
forbidden_outputs:
  - topic_selection_decision
  - final_delivery_human_decision
  - workflow_session_record
  - business_content
  - checker_result
```

The router selects but does not execute one registered next node. Human choices
are delegated to their internal gate Skills; deterministic recorders own state
writes. The session-entry delegate alone may commit a new session's immutable
runtime binding. Resume never rewrites that binding; a version-pinned legacy
plan without a binding is routed read-only to `legacy_r7`.
