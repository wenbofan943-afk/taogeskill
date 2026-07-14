# Image Prompt Compiler Contract

```yaml
skill_id: image-prompt-compiler
contract_version: 0.3.0
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
  - accepted_task_dispatch_policy=auto_continue_all_accepted_without_human_confirmation
  - human_confirmation_required=false
  - generation_dispatch_status=ready_for_prompt_compile
  - next_skill=image-prompt-compiler
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
  - content_source_id
  - content_origin
  - evidence_source_metadata_when_required
  - evidence_dispatch_set
next_skill: image-asset-producer
```

## Invariants

```text
One prompt card per accepted task whose provider_route is codex_builtin_image2; no generated prompt for news_evidence_pip.
Prompt task IDs plus evidence_dispatch_set task IDs equal accepted_visual_tasks[] exactly; the two sets are disjoint.
The prompt compiler starts automatically after analysis pass; human_confirm is invalid for accepted tasks.
No duration, optional, cost, or provider-call limit may truncate the prompt set.
Each prompt retains viewer_problem_without_visual, primary_visual_job, and expected_viewer_change.
forbidden never emits image text.
Required exact text matches the approved visual_text_units.
Evidence metadata is retained in evidence_dispatch_set and routed to news-evidence-pip; it is never fabricated into generated evidence.
Codex and Seedream payloads preserve the same semantic plan.
```

## Auto Next And Failure

```text
All prompt_integrity_check pass -> automatically invoke image-asset-producer for generated-context tasks and news-evidence-pip for source-bound evidence tasks.
Missing or contradictory visual plan -> static-visual-director.
Invalid provider syntax -> repair locally.
Unavailable provider -> prompt_only/manual_required, not a human “continue” gate.
```

## Acceptance Cases

```text
forbidden task produces no-text prompt
required mechanism preserves concise labels
source-native evidence produces no Image 2 prompt and enters news-evidence-pip
Codex route produces complete model parameters
five accepted generated-context tasks produce five complete Image 2 prompt cards
non-Codex route produces complete Seedream-compatible payload
```

## Open Source Boundary

Publish the contract and redacted prompt fixtures. Do not publish real prompts, source screenshots, account paths, or generated production assets.

## R3-C111–C124 Canvas Compilation

The compiler mirrors `presentation_mode`, target video canvas, asset canvas and `placement_slot` into both prose and provider payload. Ratio is a reduced integer pair plus exact pixel dimensions. A prompt without a typed target canvas is incomplete; provider defaults must never decide portrait/landscape/square implicitly. Cross-platform prompt reuse is allowed only when surface profile version, aspect ratio, safe area and title are equivalent.
