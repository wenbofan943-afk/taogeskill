# Final Delivery Builder Contract

```yaml
skill_id: final-delivery-builder
contract_version: 0.16.0
contract_status: confirmed
contract_set_version: r7-direct-v0.5+r7-hotspot-v0.5+delivery-v0.9
plan_schema_id: taoge://schemas/p0/session-execution-plan/v1.0
render_input_schema_id: taoge://schemas/final-delivery/typed-components/v0.9
renderer_version: final-delivery-renderer-v0.9
viewport_contract: r7-viewport-acceptance-v0.2
business_acceptance_contract: r7-business-delivery-acceptance-v0.1
template_version: final-delivery-template-v0.9
template_source: templates/final-delivery/final-delivery.v0.5.template.html+plan_pinned_fragment
candidate_producer: deterministic_compiler_only
legacy_policy: p0_v0.1_v0.2_v0.3_v0.4_v0.5_and_r7_plan_v0.6_readonly_replay_and_reproduction
```

Current new sessions use blueprint v0.4, plan v1.0 and candidate / renderer / template v0.9. Direct origin consumes its required current pointer set; hotspot additionally requires current research, selection and freshness objects. Both require `image_asset_delivery_set`, independent `delivery_title`, final-asset visual review and a separate business acceptance. v0.8 and earlier remain historical replay branches.

`visual_task_id` expresses semantic coverage while `occurrence_id` expresses one physical appearance. For an occurrence covering adjacent beats, the compiler assigns the occurrence only to the earliest covered beat and retains the task reference on every covered beat. Missing, duplicate, non-contiguous or task-external covered beats fail with `candidate_occurrence_contract_error`; non-adjacent reuse requires a distinct occurrence.

Failure categories are `cross_artifact_binding_error`, `asset_review_binding_error`, `candidate_occurrence_contract_error`, `candidate_integration_error`, `enum_registry_error` and `render_compile_error`. A failed compiler or renderer writes no success event and cannot advance the projection.

For v0.8, `visual_route_summary[]` is compiled from current visual plan / coverage / asset / evidence records. It exposes `source_class`, base asset, parent hash, provider or capture outcome, postprocess, reuse authorization and evidence parity without claiming an unobservable Image 2 runtime profile. `revision_context` records the current delivery revision, superseded delivery and active request binding. A semantic parity blocker, missing Image 2 base, invalid reuse authorization or active incomplete revision prevents publish-ready delivery.

H7 technical viewport acceptance verifies final-delivery and HTML hashes, executes real desktop 1440×1000 and mobile 390×844 browser measurements, and binds screenshots by SHA256. It has no `visual_acceptance_status`. The business acceptance must view those screenshots and the actual delivery images, score six dimensions, and block final acceptance on a failed dimension. Normal final human review does not reduce autonomy; a hand-authored candidate, HTML, viewport report or business acceptance does.
