---
name: semantic-workflow-coordinator
description: "Prepare and commit exactly one R7 semantic workflow task from the current P0 projection. Use after propagation-router selects direct_delivery_single_v0.1, or when resuming a pending R7 submission. The H2 runtime resolves versioned inputs, emits an immutable task envelope, validates a v0.2 semantic submission, writes revision and lineage, commits the current pointer last, appends the event, and rebuilds projection. H3 producer adapters and H4/H5 delivery compilation remain separate capabilities."
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
3. Invoke only the task's `skill_ref`. The semantic producer may return one v0.2 submission and may not request machine writes.
4. `-Mode submit -SubmissionPath ...` validates the submission, rechecks every input hash, writes the immutable revision and lineage, commits the current pointer last, appends the event, and rebuilds projection.
5. If an interruption leaves a receipt before `projection_rebuilt`, use `-Mode reconcile -SubmissionId ...`. Never prepare a new task first.
6. Repeating an already completed submission must return `duplicate_reused` without a new event or changed revision.

## Hard boundaries

- P0 plan/event/projection is the only runtime state source.
- Never invent a selector, path, status, action, artifact ID field, or retry rule.
- Never let a semantic submission write revisions, pointers, events, projection, candidate, HTML, or receipts.
- Never advance pointer before revision and lineage are durable.
- Never resume v0.1-v0.5 sessions into R7 v0.6; use their original replay/render contract.
- H2 does not claim producer-adapter completeness, candidate v0.6 compilation, HTML v0.6 rendering, viewport acceptance, provider use, or full autonomous completion.

## Result semantics

```text
session_initialized
task_prepared
task_reused
semantic_artifact_committed
duplicate_reused
submission_reconciled
pending_submission_requires_reconcile
semantic_submission_error
cross_artifact_binding_error
immutable_revision_conflict
current_pointer_revision_conflict
workflow_completed
```

## Output

Report the result code, task/submission ID, artifact revision and pointer paths, producer event ID, route class, and next step ID. A successful H2 commit proves state advancement only; H3-H5 remain required before a direct session can complete end to end.
