# Semantic Workflow Coordinator Contract

```yaml
contract_id: r7-semantic-workflow-coordinator
contract_version: 1.3
compile_batch: M4
implementation_status: legacy_r7_only_after_session_generation_selection
runtime_activation: existing_version_pinned_sessions_and_new_sessions_selected_by_rollback_only
```

## Reads

- legacy R7 blueprint/node registry v0.3 plus selector, commit, status-route, task-guidance and contract-status registries; current action registry v0.3 and presentation registry v0.2
- `current-workflow-ir.json`, `component-catalog.json`, and `compatibility-catalog.json` are kernel machine truths. This coordinator reads the committed session generation decision and refuses `kernel_v1_current`
- current direct P0 plan v1.3, current hotspot plan v1.4, historical plans, event v0.2, projection, and current materialized inputs
- current direct semantic task envelope v0.7, current hotspot envelope v0.8, historical envelopes, and semantic artifact submission v0.2
- producer adapter registry v0.2 and node payload schemas

## Produces

- one immutable task envelope for the unique next semantic/human/external node
- one deterministically assembled v0.2 submission from a registered producer payload
- one immutable artifact revision plus P0 lineage v0.2
- one current pointer v0.1 committed after revision and lineage
- one append-only semantic result event and rebuilt projection
- one phase receipt v0.1 supporting bounded reconcile
- one deterministic direct v0.6 or hotspot v0.7 delivery candidate/final delivery, selected by the pinned plan
- one deterministic viewport acceptance report with real desktop/mobile evidence when browser capability exists
- one typed final human decision followed by deterministic `workflow_session_record v0.4` apply
- one hotspot artifact per semantic node plus a versioned selected-source freshness apply and recoverable plan revision

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
10. Candidate and renderer nodes are deterministic-only and reject agent-produced v0.6/v0.7 machine artifacts.
11. H5 viewport pass cannot be presented as provider use, publication, hotspot-adapter completion, or a new private real-session pass.
12. Final human decision/action pairs are fixed. Scoped revision and export require a target that resolves to the current candidate source map or current final delivery and matches the action registry type.
13. A session selected as `legacy_r7` uses direct v0.6 plan v1.3 or hotspot v0.6 plan v1.4. Older versions remain pinned and cannot be silently migrated.
14. Direct structure diagnosis may bind only a materialized baseline draft and current `semantic_only` beat map. The downstream map is a new `structure_bound` revision.
15. Submission `output_revision` is derived from the registered payload revision field. A second current artifact of the same type must advance monotonically; hardcoded revision 1 is invalid.
16. Adapter phase constraints fail before submission build, and no structure plan may contain a future artifact reference.
17. An unassessed freshness read commits no current review and cannot advance candidate compilation.
18. Monitoring-only apply preserves content semantic digest; material update restarts at hotspot Brief; reversal/identity change restarts at research.
19. Replan writes plan revision and commit marker before active replacement. Skipped stale steps are terminal for routing but not counted as new succeeded work.
20. One active delivery revision request exists at a time. Restart is the earliest owning node; invalidation is the union of all change-item dependency closures. Old artifacts and HTML remain immutable audit evidence.
21. Direct and hotspot v0.6 carry the five current visual semantic stages as 0..N stage sets. Waiting/revision results do not commit a pointer or advance; scoped visual-route revision restarts at the owning set and rebuilds every downstream delivery artifact.
22. Current hotspot sessions start from hash-bound account identity, account snapshot, and radar policy. External research wait reuses the same task; material updates restart at Brief; reversal/identity change commits a new revalidation request and restarts at research.
23. Topic and final human gates interpret explicit replies only. The deterministic recorder owns commit mechanics, and `final_delivery_decision_apply` alone mutates workflow session state.
24. M4 selects `kernel_v1_current` for new sessions and keeps existing sessions on their committed or version-pinned generation. This coordinator may initialize only after deterministic selection returns `legacy_r7`; it must reject a `kernel_v1_current` binding. M4 is not runtime certification.

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

R7-L3-H5 owns separately authorized private real regression, external/provider evidence, cohort construction, and L3 reassessment.
