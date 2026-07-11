# Static Visual Director Contract

```yaml
skill_id: static-visual-director
contract_version: 0.1.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C54-R3-C70
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
  - visual_plan
  - visual_text_plan
status_fields:
  - static_visual_director_status
  - visual_plan_status
  - visual_text_plan_status
downstream_artifact: image_prompt_set
next_skill: image-prompt-compiler
```

## Invariants

```text
visual_budget includes default_required_min/max, default_optional_min/max, final_required_count, final_optional_count, selected_optional_count, reduction_reason, expansion_reason, and cover_count_excluded=true.
final_required_count equals required_visuals[] count; final_optional_count equals optional_visuals[] count; selected_optional_count equals optional tasks selected_for_generation.
Below-policy counts require reduction_reason; above-policy counts require expansion_reason.
Cover generation tasks are not included in picture-in-picture counts.
required_visuals[] + optional_visuals[] image_task_id set equals visual_text_tasks[] image_task_id set.
Each image_task_id appears exactly once in visual_text_tasks[].
forbidden means visual_text_units is empty.
required means at least one valid visual_text_unit exists.
Evidence units require source type, id, path, and source_bound.
All three planning objects share draft_id and source_research_run_id.
The single physical source of truth is intermediate/05-visual-plan.md.
```

Machine field names are fixed as `default_required_min`, `default_required_max`, `default_optional_min`, `default_optional_max`, `final_required_count`, `final_optional_count`, `selected_optional_count`, and `cover_count_excluded`; do not collapse the budget into a prose string such as “3 required + 1 cover”.

## Auto Next And Human Gates

```text
All three plans pass -> automatically invoke image-prompt-compiler.
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

## Trace And Open Source

```text
Write execution trace labels for skill_defined, agent_orchestrated, source_binding, and compatibility migration.
Contracts and redacted fixtures are publishable.
Real drafts, source assets, account names, and run paths must remain under ignored accounts/.
```

## Acceptance Cases

```text
no-text scene -> forbidden and zero units
inner thought -> optional and non-redundant
mechanism -> required and concise labels
evidence -> required and source_bound
generated pseudo-evidence -> blocked or downgraded
```
