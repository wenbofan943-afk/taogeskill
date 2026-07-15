# Semantic Workflow Coordinator Contract

```yaml
contract_id: r7-semantic-workflow-coordinator
contract_version: 0.8
compile_batch: R7-joint-R6-R3-R7
implementation_status: direct_v03_and_hotspot_v03_plan_v09_human_scoped_replan_delivery_v08_compiled
runtime_activation: offline_fixture_active_h6c_private_real_hotspot_regression_pending
```

## Reads

- R7 blueprint registry v0.3 plus node, selector, commit, status-route, task-guidance, contract-status, action, and presentation registries v0.2
- current direct/hotspot P0 plan v0.9, historical v0.7/v0.8/v0.6 plans, event v0.2, projection, and current materialized inputs
- current semantic task envelope v0.3, historical envelopes v0.1/v0.2, and semantic artifact submission v0.2
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
- one registry-bound final human revision request with 1..N scoped current targets, one plan revision, and a nonterminal restart
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
13. New direct sessions use `direct_delivery_single_v0.2`; v0.1 remains historical and cannot be silently migrated.
14. Direct structure diagnosis may bind only a materialized baseline draft and current `semantic_only` beat map. The downstream map is a new `structure_bound` revision.
15. Submission `output_revision` is derived from the registered payload revision field. A second current artifact of the same type must advance monotonically; hardcoded revision 1 is invalid.
16. Adapter phase constraints fail before submission build, and no structure plan may contain a future artifact reference.
17. An unassessed freshness read commits no current review and cannot advance candidate compilation.
18. Monitoring-only apply preserves content semantic digest; material update restarts at hotspot Brief; reversal/identity change restarts at research.
19. Replan writes plan revision and commit marker before active replacement. Skipped stale steps are terminal for routing but not counted as new succeeded work.
20. One active delivery revision request exists at a time. Restart is the earliest owning node; invalidation is the union of all change-item dependency closures. Old artifacts and HTML remain immutable audit evidence.

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

R7-H6B compiles and fixture-tests freshness, apply, two-stage replan and hotspot delivery v0.7. R7-H6C owns the new private real hotspot regression and L3 evidence.
