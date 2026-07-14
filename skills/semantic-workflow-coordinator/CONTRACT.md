# Semantic Workflow Coordinator Contract

```yaml
contract_id: r7-semantic-workflow-coordinator
contract_version: 0.2
compile_batch: R7-H2
implementation_status: coordinator_submitter_active
runtime_activation: direct_blueprint_state_runtime_active_producers_pending_H3
```

## Reads

- R7 blueprint, node, selector, commit, status-route, task-guidance, contract-status, and action registries v0.1
- P0 plan v0.6, event v0.2, projection, and current materialized inputs
- semantic task envelope v0.1 and semantic artifact submission v0.2

## Produces

- one immutable task envelope for the unique next semantic/human/external node
- one immutable artifact revision plus P0 lineage v0.2
- one current pointer v0.1 committed after revision and lineage
- one append-only semantic result event and rebuilt projection
- one phase receipt v0.1 supporting bounded reconcile

## Invariants

1. P0 event/projection remains the sole runtime state source.
2. The direct blueprint has at most one current next node.
3. Inputs are materialized and hash-bound when the task is created and immediately before commit.
4. Semantic submissions request no machine writes and use only envelope statuses/actions.
5. Revision and lineage precede pointer; pointer precedes event; projection follows the event.
6. A completed duplicate is byte/event stable. An incomplete receipt blocks new task preparation until reconcile.
7. Historic v0.1-v0.5 sessions remain replay/render-only under their original contract.
8. H2 evidence cannot be presented as H3 producer, H4 candidate, H5 viewport, provider, publication, or autonomous end-to-end evidence.

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

R7-H3 compiles direct semantic producer adapters. R7-H4 compiles candidate v0.6 and renderer v0.6. R7-H5 compiles viewport evidence, transparency accounting, and the final human gate.
