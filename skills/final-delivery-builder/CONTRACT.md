# Final Delivery Builder Contract

```yaml
skill_id: final-delivery-builder
contract_version: 0.13.1
contract_status: confirmed
contract_set_version: r7-single-semantic-workflow-v0.2+p0-delivery-v0.6
plan_schema_id: taoge://schemas/p0/session-execution-plan/v0.7
render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.6
renderer_version: final-delivery-renderer-v0.6
viewport_contract: r7-viewport-acceptance-v0.1
template_version: final-delivery-template-v0.6
template_source: templates/final-delivery/final-delivery.v0.5.template.html+templates/final-delivery/final-delivery.v0.6.execution-fragment.html
candidate_producer: deterministic_compiler_only
legacy_policy: p0_v0.1_v0.2_v0.3_v0.4_v0.5_and_r7_plan_v0.6_readonly_replay_and_reproduction
```

New delivery consumes twelve current R7 semantic/artifact pointers. Candidate compile verifies current hashes, visual files, task-to-asset bindings, platform cardinality and unique hash-bound cover reviews before writing a v0.6 candidate. Renderer uses the compiler payload only, writes synchronized views plus v0.6 receipt/manifest, and commits a distinct final-delivery artifact. Business-visible readiness is re-derived; upstream labels are never trusted without closure checks.

`visual_task_id` expresses semantic coverage while `occurrence_id` expresses one physical appearance. For an occurrence covering adjacent beats, the compiler assigns the occurrence only to the earliest covered beat and retains the task reference on every covered beat. Missing, duplicate, non-contiguous or task-external covered beats fail with `candidate_occurrence_contract_error`; non-adjacent reuse requires a distinct occurrence.

Failure categories are `cross_artifact_binding_error`, `asset_review_binding_error`, `candidate_occurrence_contract_error`, `candidate_integration_error`, `enum_registry_error` and `render_compile_error`. A failed compiler or renderer writes no success event and cannot advance the projection.

H5 adds deterministic viewport acceptance. It verifies final-delivery and HTML hashes, executes real desktop 1440×1000 and mobile 390×844 browser measurements, binds screenshots by SHA256, and records deterministic/semantic/human/external contribution separately. `workflow_autonomous_completion_count=1` requires every declared semantic/external step, compiler-produced candidate/final delivery, zero manual patch and a viewport pass. Normal final human review does not reduce that count.
