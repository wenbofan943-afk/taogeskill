# Static Visual Director Contract

```yaml
skill_id: static-visual-director
contract_version: 0.4.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C54-R3-C80
newly_confirmed_scope: R3-C71-R3-C80
skill_type: internal_producer
```

## Triggers

```yaml
user_intent: indirect through talking-head-image-pip
upstream_artifact_status: draft_status=draft_created
forbidden_direct_gate: do not ask the user to invoke this skill separately
```

## Preconditions And Inputs

```yaml
required_artifacts:
  - content_brief
  - draft
  - session manifest
required_fields:
  - brief_id
  - draft_id
  - content_source_id
  - content_origin
  - account
  - script_text
optional_artifacts:
  - subtitle source
  - source assets
  - account_visual_identity
  - column_visual_template
```

## Outputs

```yaml
target_path: accounts/{account_slug}/runs/{session_id}/intermediate/05-visual-plan.md
artifacts:
  - static_visual_director_plan
  - visual_need_analysis
  - visual_plan
  - visual_text_plan
status_fields:
  - static_visual_director_status
  - visual_need_analysis_status
  - visual_plan_status
  - visual_text_plan_status
downstream_artifact: image_prompt_set | evidence_screenshot_pip
next_skill: image-prompt-compiler
```

## Invariants

```text
visual_count_policy=content_derived_unbounded; generation_policy=generate_all_accepted; cost_gate=not_applicable; provider_call_limit=null.
accepted_task_dispatch_policy=auto_continue_all_accepted_without_human_confirmation; human_confirmation_required=false.
derived_visual_count equals accepted_visual_tasks[] count and generate candidate count; zero is valid with zero_visual_reason and there is no maximum.
Every candidate records audience-aware no-visual loss, one primary visual job, expected viewer change, information delta, image advantage, decision, and risk evidence.
attention_reset cannot use elapsed_time_only; emotion must align; evidence must be source_bound; duplicate/high-load/high-misleading generate candidates are invalid.
Every generate candidate maps to exactly one accepted task using render_now; generated context uses codex_builtin_image2 and source-bound evidence uses news_evidence_pip/source_capture. Reject candidates map to no task.
Cover generation tasks are excluded from derived_visual_count.
accepted_visual_tasks[] image_task_id set equals visual_text_tasks[] image_task_id set.
Each image_task_id appears exactly once in visual_text_tasks[].
forbidden means visual_text_units is empty.
required means at least one valid visual_text_unit exists.
Evidence units require source type, id, path, and source_bound.
All four planning objects share draft_id, content_source_id, and content_origin; hotspot runs additionally preserve source_research_run_id.
The single physical source of truth is intermediate/05-visual-plan.md.
When an active `visual_identity_ref` is available, static_visual_director_plan records identity_id, identity_version, applicable_column_template_id, and any identity_override_reason. Identity governs evidence grammar, hierarchy, tone direction and prohibitions only; it cannot set image count, a provider-call cap, or a mandatory logo/overlay.
```

Legacy visual-budget sinks were `superseded_pending_recompile` by R3-C71 to C80 and are now history-only compatibility. New artifacts must not emit `visual_budget / required_visuals / optional_visuals / default_* / final_* / selected_optional_count / reduction_reason / expansion_reason / expected_provider_call_count`.

## Auto Next And Human Gates

```text
All four plans pass -> keep generation_dispatch_status=ready_for_prompt_compile and next_skill=image-prompt-compiler. The R6-aware compiler compiles only generated-context prompts and dispatches source-bound tasks to news-evidence-pip without a user pause.
Ordinary text/no-text decisions are not human gates.
`pass_must_auto_continue_to_image_prompt_compiler`: a passing analysis may never emit human_confirm or wait for aesthetic preference.
Unresolved evidence, privacy, copyright, or claim risk must be rejected or routed to local recovery before the candidate becomes accepted; it cannot leave an accepted task waiting for confirmation.
Never ask “是否继续生成提示词”.
```

## Failure And Recovery

| Failure | Status | Recovery |
|---|---|---|
| task mapping mismatch | blocked | rebuild the atomic planning bundle |
| visual text repeats narration | needs_fix | remove text or rewrite information_delta |
| evidence source missing | blocked | bind source or downgrade visual role |
| text budget overflow | needs_fix | reduce units or record overflow_reason for review |
| old visual role enum | needs_fix | apply the field-dictionary compatibility map |
| zero images without concrete reason | needs_fix | write zero_visual_reason from audience/content evidence |
| elapsed-time-only attention task | needs_fix | identify a specific content risk or reject the candidate |
| accepted task skipped by cap/cost | blocked | remove the cap and generate all accepted tasks |

## Trace And Open Source

```text
Write execution trace labels for skill_defined, agent_orchestrated, source_binding, and compatibility migration.
Contracts and redacted fixtures are publishable.
Real drafts, source assets, account names, and run paths must remain under ignored accounts/.
```

## Acceptance Cases

```text
no-text scene -> forbidden and zero units
fully sufficient talking head -> zero accepted tasks with zero_visual_reason
inner thought -> optional and non-redundant
mechanism -> required and concise labels
evidence -> required and source_bound
generated pseudo-evidence -> blocked or downgraded
seven independent accepted needs -> seven tasks; no max trimming
```

## R3-C111–C124 Visual Presentation Contract

Accepted output is `visual_insert`, not an untyped picture request. Every task must carry `visual_insert_task_id`, `presentation_mode`, versioned `platform_surface_profile_id`, `video_canvas`, `visual_asset_canvas`, normalized `placement_slot`, protected speaker/caption/UI regions, and `aspect_ratio_verification_status`. Only `speaker_plus_visual` is narrow picture-in-picture; `full_frame_replace`, split screen, floating/source cards, and background plates retain their own semantics. Coordinates use the target video canvas with a top-left origin and `[0,1]` bounds.
