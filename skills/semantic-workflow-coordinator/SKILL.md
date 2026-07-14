---
name: semantic-workflow-coordinator
description: "Validate the R7 single-content workflow blueprint and prepare exactly one typed semantic task for the current projection. Use after propagation-router has selected direct_delivery_single_v0.1 or hotspot_to_delivery_single_v0.1, when Codex must stop guessing the next Skill, inputs, statuses, actions, or recovery context. R7-H1 is contract-only: do not commit revisions, pointers, events, projections, candidates, or final HTML until the H2/H4 runtimes exist."
---

# Semantic Workflow Coordinator

## Purpose

Turn a routed single-content session into one contract-bound semantic task. The blueprint and registries decide the node, Skill, input selectors, status values, action codes, and recovery boundary; Codex performs only the named semantic judgment.

This Skill is the R7-H1 contract surface. It does not yet implement the H2 coordinator or submitter.

## Required inputs

Read only the minimum current state needed for the task:

```text
routes/r7-workflow-blueprints.yaml
routes/r7-node-registry.yaml
routes/r7-contract-status-registry.yaml
routes/r7-action-registry.yaml
state/current-state.yaml
current session plan / event tail / projection
current materialized artifacts selected by the node
the node's skill_ref/SKILL.md and CONTRACT.md
```

Require:

```text
one blueprint_id
one current projection
zero or one declared next node
all selected inputs materialized and current
pending submission status = none or reconciled
registered contract, status, and action versions
```

If any item is ambiguous, return a contract error. Do not choose a plausible alternative.

## H1 procedure

1. Resolve the blueprint and its pinned node registry.
2. Verify the projection points to one registered node. More than one active next node is `blueprint_contract_error`.
3. Resolve every `input_selector` to an existing current artifact and verify ID, relative path, SHA256, and status.
4. Verify pending submissions were reconciled before preparing a new task.
5. Load the node's `skill_ref`, output contract, allowed statuses, and allowed action codes from the registries.
6. Prepare one `semantic_task_envelope` conforming to `taoge://schemas/r7/semantic-task-envelope/v0.1`.
7. Hand the envelope to the named semantic Skill. The Skill may return only a `semantic_artifact_submission` conforming to `taoge://schemas/r7/semantic-artifact-submission/v0.1`.
8. Stop at submission validation in H1. Do not write runtime state.

## Hard boundaries

- Never invent a node, input path, status, action code, output schema, or retry rule.
- Never reference an input that is expected later but is not materialized now.
- Never allow a semantic submission to write a current pointer, event, projection, final candidate, or delivery marker.
- Never treat a submission as committed or current.
- Never resume a v0.1-v0.5 session into R7 v0.6; use its original replay/render contract.
- Never use `regenerate_visual`; choose a registered action or return `enum_registry_error` with the legal codes.
- Never claim the coordinator/runtime is autonomous in H1. H2 compiles commit and state advancement; H4 compiles the candidate.

## Result semantics

```text
task_ready_contract_only
no_next_node
waiting_human
blueprint_contract_error
task_envelope_error
enum_registry_error
legacy_replay_only
```

`task_ready_contract_only` means the envelope is valid for Skill handoff. It does not mean a revision, event, projection, candidate, HTML, provider call, publication, or autonomous workflow completion occurred.

## Output

Return:

```text
blueprint_id
blueprint_version
node_id
skill_ref
task_envelope_id
task_contract_version
input_binding_digest
allowed_statuses
allowed_actions
result
failure_category
next_runtime_requirement
```

Until H2 exists, `next_runtime_requirement` must be `r7_h2_coordinator_submitter` for a valid task.
