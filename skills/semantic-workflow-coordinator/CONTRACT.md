# Semantic Workflow Coordinator Contract

```yaml
contract_id: r7-semantic-workflow-coordinator
contract_version: 0.5
compile_batch: R7-H5
implementation_status: coordinator_submitter_direct_producers_candidate_renderer_viewport_final_human_gate_active
runtime_activation: direct_blueprint_through_final_human_gate_active_waiting_new_private_regression
```

## Reads

- R7 blueprint, node, selector, commit, status-route, task-guidance, contract-status, and action registries v0.1
- P0 plan v0.6, event v0.2, projection, and current materialized inputs
- semantic task envelope v0.1 and semantic artifact submission v0.2
- producer adapter registry v0.1 and node payload schemas

## Produces

- one immutable task envelope for the unique next semantic/human/external node
- one deterministically assembled v0.2 submission from a registered producer payload
- one immutable artifact revision plus P0 lineage v0.2
- one current pointer v0.1 committed after revision and lineage
- one append-only semantic result event and rebuilt projection
- one phase receipt v0.1 supporting bounded reconcile
- one deterministic v0.6 delivery candidate and one v0.6 final delivery when those nodes are current
- one deterministic viewport acceptance report with real desktop/mobile evidence when browser capability exists
- one registry-bound final human decision submission with a conditional scoped target

## Invariants

1. P0 event/projection remains the sole runtime state source.
2. The direct blueprint has at most one current next node.
3. Inputs are materialized and hash-bound when the task is created and immediately before commit.
4. Semantic submissions request no machine writes and use only envelope statuses/actions.
5. Business result status is converted to the payload's native status only by `status_value_map`; Codex never guesses the translation.
6. Waiting results create no current revision/pointer and cannot advance the cursor.
7. Revision and lineage precede pointer; pointer precedes event; projection follows the event.
8. A completed duplicate is byte/event stable. An incomplete receipt blocks new task preparation until reconcile.
9. Historic v0.1-v0.5 sessions remain replay/render-only under their original contract.
10. Candidate and renderer nodes are deterministic-only and reject agent-produced v0.6 machine artifacts.
11. H5 viewport pass cannot be presented as provider use, publication, hotspot-adapter completion, or a new private real-session pass.
12. Final human decision/action pairs are fixed. Scoped revision and export require a target that resolves to the current candidate source map or current final delivery and matches the action registry type.

## Failure categories

```text
plan_contract_failed
task_envelope_error
semantic_submission_error
cross_artifact_binding_error
immutable_revision_conflict
lineage_commit_error
current_pointer_revision_conflict
pending_submission_requires_reconcile
duplicate_evidence_conflict
```

## Downstream

R7-H6 runs a new private direct session with verified asset reuse, compiles the hotspot entry adapter, and evaluates L3 against real execution evidence.
