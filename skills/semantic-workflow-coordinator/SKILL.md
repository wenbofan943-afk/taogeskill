---
name: semantic-workflow-coordinator
description: "Prepare, commit, and recover exactly one R7 semantic, deterministic, or human-gate workflow task from the current P0 projection. Use for current direct_delivery_single_v0.5, hotspot_to_delivery_single_v0.5, human-scoped delivery revision, and version-pinned historical resume."
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

## Current procedure

Current direct sessions use plan v1.1 and blueprint `direct_delivery_single_v0.5`; current hotspot sessions use plan v1.2 and blueprint `hotspot_to_delivery_single_v0.5`. Both routes execute the registered current visual-semantic stages after `visual_need_analysis`. A stage `waiting_capability` or `revision_required` remains on the same task and commits no current pointer. Both v0.4 blueprints are historical replay only.

1. `-Mode initialize` creates the blueprint-pinned plan once: v1.1 for current direct v0.5 and v1.2 for current hotspot v0.5. A conflicting existing plan is a hard failure; older plans remain version-pinned historical replay.
2. `-Mode prepare_task` rebuilds projection, reconciles no unresolved receipt, resolves every declared selector, verifies SHA256, and writes the envelope version pinned by the plan.
3. Invoke only the task's `skill_ref`. The semantic producer returns one payload conforming to the node's registered payload schema; it does not hand-author a submission envelope.
   For current hotspot v0.5, the chain starts from current account identity, account snapshot, and radar policy, commits a hash-bound research request, then runs research set -> panel -> immutable Topic Gate decision -> selected source -> Brief -> structure -> draft -> current visual-semantic production -> freshness review/apply -> candidate. Do not prefill future research/source/topic artifacts, collapse artifacts, or skip Topic Gate.
4. Run `tools/new-r7-semantic-submission.ps1` with the task ID, payload path, and one allowed result status. The deterministic builder derives artifact ID, native status mapping, source IDs, quality, idempotency, and the v0.2 submission.
5. `-Mode submit -SubmissionPath ...` validates the submission, rechecks every input hash, writes the immutable revision and lineage, commits the current pointer last, appends the event, and rebuilds projection. A waiting result writes no current artifact and leaves the cursor on the same node.
6. If an interruption leaves a receipt before `projection_rebuilt`, use `-Mode reconcile -SubmissionId ...`. Never prepare a new task first.
7. Repeating an already completed submission must return `duplicate_reused` without a new event or changed revision.
8. When `prepare_task` returns `deterministic_node_ready`, run `-Mode run_deterministic`; never create a semantic submission for candidate compile, final render, viewport acceptance, or visual finalization.
9. At `final_human_gate_h7` for either current v0.5 route, or the version-pinned historical final gate, only an explicit user decision may invoke `tools/new-r7-final-human-decision.ps1`. A revision supplies one change-items file with 1..N current hash-bound targets. The runtime first commits one typed `delivery_revision_request`, derives the earliest owning node and union stale closure, activates a new plan revision under the same contract version, and projects that producer as the next step. It never marks `revision_requested` completed.
10. For a new direct session, require blueprint `direct_delivery_single_v0.5`: baseline draft first, then `semantic_only` beat map, then direct structure diagnosis, then a new `structure_bound` beat-map revision. Never predeclare future draft or beat IDs.
11. At `delivery_topic_freshness_review`, invoke only `hotspot-topic-freshness-review`. A wait writes attempts/failure evidence but no current review. At apply, monitoring-only changes preserve the semantic digest and continue; a material update activates a new plan revision from `hotspot_content_brief`; reversal/identity change restarts from `hotspot_research` without reusing the old decision.
12. Replan is two-stage: selected-source revision first, then request/plan-revision/plan-commit, then active-plan replacement and `workflow.replanned.v1`. Resume an incomplete transaction under the same idempotency key; do not duplicate external reads or count carried-forward artifacts as new succeeded work.

## Hard boundaries

- P0 plan/event/projection is the only runtime state source.
- Never invent a selector, path, status, action, artifact ID field, or retry rule.
- Never let a semantic submission write revisions, pointers, events, projection, candidate, HTML, or receipts.
- Never advance pointer before revision and lineage are durable.
- Never resume v0.1-v0.5 sessions into R7 v0.6; use their original replay/render contract.
- Never start a new direct session with `direct_delivery_single_v0.1`; it is retained only as historical contract-defect evidence. Do not migrate an unfinished v0.1 plan in place.
- Never submit `semantic_beat_map` with `mapping_phase=structure_bound`, or the downstream `content_beat_map` with `mapping_phase=semantic_only`.
- Historical direct v0.2 remains pinned to delivery v0.6. Current hotspot v0.5 uses its pinned delivery contract only after a complete freshness review and `ready_for_delivery` selected source. H4 does not authorize real provider use, public-network execution, private-account regression, or publication.

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

Report the result code, task/submission ID, artifact revision and pointer paths, producer event ID, route class, active plan revision, and next step ID. H3/H4 redacted route fixtures do not replace a later authorized private real regression required before L3 assessment.
