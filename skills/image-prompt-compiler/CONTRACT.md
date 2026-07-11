# Image Prompt Compiler Contract

```yaml
skill_id: image-prompt-compiler
contract_version: 0.2.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C54-R3-C80
skill_type: internal_compiler
```

## Inputs

```yaml
source_path: accounts/{account_slug}/runs/{session_id}/intermediate/05-visual-plan.md
required_artifacts:
  - static_visual_director_plan
  - visual_need_analysis
  - visual_plan
  - visual_text_plan
required_status:
  - director_plan_pass
  - visual_need_analysis_status=pass
  - visual_plan_pass
  - visual_text_plan_pass
```

## Outputs

```yaml
artifact_type: image_prompt_set
target_path: accounts/{account_slug}/runs/{session_id}/intermediate/05-visual-plan.md
required_fields:
  - prompt_id
  - image_task_id
  - visual_text_task_id
  - visual_text_decision
  - visual_text_units
  - visual_text_render_strategy
  - allow_text_in_image
  - full_prompt
  - negative_prompt
  - provider_mode
  - provider
  - input_schema_version
  - acceptance_criteria
  - prompt_integrity_check
  - source_research_run_id
  - evidence_source_metadata_when_required
next_skill: image-asset-producer
```

## Invariants

```text
One prompt card per image task selected for production.
Prompt task IDs equal accepted_visual_tasks[] exactly; every generate candidate is included and every reject candidate is excluded.
No duration, optional, cost, or provider-call limit may truncate the prompt set.
Each prompt retains viewer_problem_without_visual, primary_visual_job, and expected_viewer_change.
forbidden never emits image text.
Required exact text matches the approved visual_text_units.
Evidence metadata is retained for trace and overlay but is not fabricated into generated evidence.
Codex and Seedream payloads preserve the same semantic plan.
```

## Auto Next And Failure

```text
All prompt_integrity_check pass -> automatically invoke image-asset-producer.
Missing or contradictory visual plan -> static-visual-director.
Invalid provider syntax -> repair locally.
Unavailable provider -> prompt_only/manual_required, not a human “continue” gate.
```

## Acceptance Cases

```text
forbidden task produces no-text prompt
required mechanism preserves concise labels
source-native evidence uses original asset instructions
Codex route produces complete model parameters
five accepted tasks produce five complete Image 2 prompt cards
non-Codex route produces complete Seedream-compatible payload
```

## Open Source Boundary

Publish the contract and redacted prompt fixtures. Do not publish real prompts, source screenshots, account paths, or generated production assets.
