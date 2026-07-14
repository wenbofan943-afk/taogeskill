---
name: semantic-workflow-coordinator
description: "Prepare and commit exactly one R7 semantic, deterministic, or final-human workflow task from the current P0 projection. Use after propagation-router selects direct_delivery_single_v0.2, or when resuming a pending R7 submission under its original blueprint. H5A owns the direct baseline, semantic beat, structure, and structure-bound beat order; H4/H5 own deterministic delivery and viewport/final decisions."
---

# Semantic Workflow Coordinator

## Purpose

Turn the current P0 projection into one contract-bound semantic task, then commit the named Skill's typed result without asking Codex to invent paths, states, action codes, or recovery rules.

## Required inputs

Read the current session plan, event tail, projection, and only the files selected by:

```text
routes/r7-workflow-blueprints.yaml
routes/r7-node-registry.yaml
routes/r7-input-selector-registry.yaml
routes/r7-artifact-commit-registry.yaml
routes/r7-status-route-registry.yaml
routes/r7-task-guidance-registry.yaml
routes/r7-action-registry.yaml
```

Use `tools/invoke-r7-semantic-workflow.ps1`; do not reproduce its state writes manually.

## H2 procedure

1. `-Mode initialize` creates the v0.6 plan once. A conflicting existing plan is a hard failure.
2. `-Mode prepare_task` rebuilds projection, reconciles no unresolved receipt, resolves every declared selector, verifies SHA256, and writes exactly one v0.1 task envelope.
3. Invoke only the task's `skill_ref`. The semantic producer returns one payload conforming to the node's registered payload schema; it does not hand-author a submission envelope.
4. Run `tools/new-r7-semantic-submission.ps1` with the task ID, payload path, and one allowed result status. The deterministic builder derives artifact ID, native status mapping, source IDs, quality, idempotency, and the v0.2 submission.
5. `-Mode submit -SubmissionPath ...` validates the submission, rechecks every input hash, writes the immutable revision and lineage, commits the current pointer last, appends the event, and rebuilds projection. A waiting result writes no current artifact and leaves the cursor on the same node.
6. If an interruption leaves a receipt before `projection_rebuilt`, use `-Mode reconcile -SubmissionId ...`. Never prepare a new task first.
7. Repeating an already completed submission must return `duplicate_reused` without a new event or changed revision.
8. When `prepare_task` returns `deterministic_node_ready` for an H4/H5 node, run `-Mode run_deterministic`; never create a semantic submission for candidate compile, final render, or viewport acceptance.
9. At `final_human_gate`, only an explicit user decision may invoke `tools/new-r7-final-human-decision.ps1`. Decision/action pairs are fixed by contract. A copy/visual revision or export must name a hash-traceable target; never infer the target from casual wording when multiple objects match.
10. For a new direct session, require blueprint `direct_delivery_single_v0.2`: baseline draft first, then `semantic_only` beat map, then direct structure diagnosis, then a new `structure_bound` beat-map revision. Never predeclare future draft or beat IDs.

## Hard boundaries

- P0 plan/event/projection is the only runtime state source.
- Never invent a selector, path, status, action, artifact ID field, or retry rule.
- Never let a semantic submission write revisions, pointers, events, projection, candidate, HTML, or receipts.
- Never advance pointer before revision and lineage are durable.
- Never resume v0.1-v0.5 sessions into R7 v0.6; use their original replay/render contract.
- Never start a new direct session with `direct_delivery_single_v0.1`; it is retained only as historical contract-defect evidence. Do not migrate an unfinished v0.1 plan in place.
- Never submit `semantic_beat_map` with `mapping_phase=structure_bound`, or the downstream `content_beat_map` with `mapping_phase=semantic_only`.
- H4 candidate/HTML and H5 viewport/final-human runtime are active. This still does not claim provider use, publication, hotspot entry completion, or a new private real-session pass.

## Result semantics

```text
session_initialized
task_prepared
task_reused
semantic_artifact_committed
semantic_waiting
duplicate_reused
submission_reconciled
pending_submission_requires_reconcile
semantic_submission_error
cross_artifact_binding_error
immutable_revision_conflict
current_pointer_revision_conflict
workflow_completed
deterministic_artifact_committed
candidate_integration_error
asset_review_binding_error
render_compile_error
viewport_report_contract_error
visual_acceptance_fail
action_target_required
action_target_unknown
action_target_type_mismatch
decision_action_mismatch
```

## Output

Report the result code, task/submission ID, artifact revision and pointer paths, producer event ID, route class, and next step ID. H5A fixture success proves the corrected direct sequence mechanics; a new private real session remains required before L3 assessment.
