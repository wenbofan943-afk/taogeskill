# Final Delivery Builder Contract

```yaml
skill_id: final-delivery-builder
contract_version: 0.14.0
contract_status: confirmed
contract_set_version: r7-direct-v0.2-delivery-v0.6+r7-hotspot-v0.2-delivery-v0.7
plan_schema_id: taoge://schemas/p0/session-execution-plan/v0.7-or-v0.8
render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.6-or-v0.7
renderer_version: final-delivery-renderer-v0.6-or-v0.7
viewport_contract: r7-viewport-acceptance-v0.1
template_version: final-delivery-template-v0.6-or-v0.7
template_source: templates/final-delivery/final-delivery.v0.5.template.html+plan_pinned_fragment
candidate_producer: deterministic_compiler_only
legacy_policy: p0_v0.1_v0.2_v0.3_v0.4_v0.5_and_r7_plan_v0.6_readonly_replay_and_reproduction
```

Direct delivery consumes twelve current pointers and remains v0.6. Hotspot delivery derives seventeen required types from its origin contract and writes v0.7 only when the current selected source and freshness review bind exactly. Both verify hashes, assets, task-to-asset bindings, platform cardinality and unique cover reviews. Business-visible readiness is re-derived; upstream labels are never trusted without closure checks.

`visual_task_id` expresses semantic coverage while `occurrence_id` expresses one physical appearance. For an occurrence covering adjacent beats, the compiler assigns the occurrence only to the earliest covered beat and retains the task reference on every covered beat. Missing, duplicate, non-contiguous or task-external covered beats fail with `candidate_occurrence_contract_error`; non-adjacent reuse requires a distinct occurrence.

Failure categories are `cross_artifact_binding_error`, `asset_review_binding_error`, `candidate_occurrence_contract_error`, `candidate_integration_error`, `enum_registry_error` and `render_compile_error`. A failed compiler or renderer writes no success event and cannot advance the projection.

H5 adds deterministic viewport acceptance. It verifies final-delivery and HTML hashes, executes real desktop 1440×1000 and mobile 390×844 browser measurements, binds screenshots by SHA256, and records deterministic/semantic/human/external contribution separately. `workflow_autonomous_completion_count=1` requires every declared semantic/external step, compiler-produced candidate/final delivery, zero manual patch and a viewport pass. Normal final human review does not reduce that count.
