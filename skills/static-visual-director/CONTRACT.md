# Static Visual Director Contract

```yaml
skill_id: static-visual-director
contract_version: 0.2.0
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
  - source_research_run_id
  - account
  - script_text
optional_artifacts:
  - subtitle source
  - source assets
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
downstream_artifact: image_prompt_set
next_skill: image-prompt-compiler
```

## Invariants

```text
visual_count_policy=content_derived_unbounded; generation_policy=generate_all_accepted; cost_gate=not_applicable; provider_call_limit=null.
derived_visual_count equals accepted_visual_tasks[] count and generate candidate count; zero is valid with zero_visual_reason and there is no maximum.
Every candidate records audience-aware no-visual loss, one primary visual job, expected viewer change, information delta, image advantage, decision, and risk evidence.
attention_reset cannot use elapsed_time_only; emotion must align; evidence must be source_bound; duplicate/high-load/high-misleading generate candidates are invalid.
Every generate candidate maps to exactly one accepted task using codex_builtin_image2 and render_now; reject candidates map to no task.
Cover generation tasks are excluded from derived_visual_count.
accepted_visual_tasks[] image_task_id set equals visual_text_tasks[] image_task_id set.
Each image_task_id appears exactly once in visual_text_tasks[].
forbidden means visual_text_units is empty.
required means at least one valid visual_text_unit exists.
Evidence units require source type, id, path, and source_bound.
All four planning objects share draft_id and source_research_run_id.
The single physical source of truth is intermediate/05-visual-plan.md.
```

Legacy visual-budget sinks were `superseded_pending_recompile` by R3-C71 to C80 and are now history-only compatibility. New artifacts must not emit `visual_budget / required_visuals / optional_visuals / default_* / final_* / selected_optional_count / reduction_reason / expansion_reason / expected_provider_call_count`.

## Auto Next And Human Gates

```text
All four plans pass -> automatically invoke image-prompt-compiler.
Ordinary text/no-text decisions are not human gates.
Only unresolved high-risk evidence or user-owned visual preference may reach human_confirm.
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
