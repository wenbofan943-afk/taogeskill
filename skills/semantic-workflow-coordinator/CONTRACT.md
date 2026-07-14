# Semantic Workflow Coordinator Contract

## Contract identity

```yaml
contract_id: r7-semantic-workflow-coordinator
contract_version: 0.1
compile_batch: R7-H1
implementation_status: contract_only_h1
runtime_activation: pending_R7-H2
```

## Reads

- `workflow_blueprint` version `0.1`
- `workflow_node_registry` version `0.1`
- `contract_status_registry` version `0.1`
- `action_registry` version `0.1`
- P0 plan, event tail, and projection
- current materialized input artifacts

## Produces

- exactly one `semantic_task_envelope` v0.1, or a typed contract/wait/legacy result
- accepts a `semantic_artifact_submission` v0.1 only for validation and handoff

## Does not produce in H1

```text
artifact revision
current pointer
event
projection
lineage commit
final-delivery-render-candidate
render input
final HTML
viewport report
autonomous completion count
```

## Invariants

1. P0 event/projection remains the sole runtime state source.
2. A projection yields at most one next node unless the blueprint explicitly supports parallelism; R7 v0.1 does not.
3. Every input binding is current, materialized, relative to the session root, and SHA256-bound.
4. Every action comes from `r7-action-registry-v0.1`; labels never substitute for codes.
5. A submission cannot request writes to pointer, event, projection, candidate, or delivery state.
6. Historic v0.1-v0.5 sessions are replay/render-only under their original contract and receive no R7 autonomy backfill.
7. H1 validation cannot be presented as H2 runtime execution or H4 candidate compilation.

## Failure categories

```text
blueprint_contract_error
task_envelope_error
semantic_submission_error
cross_artifact_binding_error
enum_registry_error
legacy_replay_only
```

## Downstream

`R7-H2` compiles deterministic task preparation, submission reconciliation, immutable revision commit, pointer-last, event write, and projection rebuild. `R7-H4` compiles the final delivery candidate.
