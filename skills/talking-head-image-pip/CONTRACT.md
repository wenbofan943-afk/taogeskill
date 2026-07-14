# Talking Head Image PIP Contract

```yaml
skill_id: talking-head-image-pip
contract_set_version: r3-asset-runtime-v0.3+r6-source-evidence-v0.1
contract_version: 0.8.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C01-R3-C80
skill_type: user_facing_orchestrator
```

## Triggers

```yaml
user_intent:
  - 口播配图
  - 画中画
  - 静态视觉方案
  - Codex image 出图
  - Seedream 提示词交付
upstream_artifact_status: draft_status=draft_created
auto_trigger: copywriting-draft-writer pass
```

## Inputs

```yaml
required_artifacts:
  - content_brief
  - draft
  - manifest.yaml
required_fields:
  - brief_id
  - draft_id
  - account
  - content_source_id
  - content_origin
  - script_text
source_paths:
  - intermediate/03-content-brief.md
  - intermediate/04-draft.md
```

## Internal Stages

```yaml
stages:
  - static-visual-director
  - image-prompt-compiler
  - image-asset-producer
  - news-evidence-pip (source-bound evidence branch only)
downstream_skill: copywriting-quality-review
```

Internal stages are automatic and are not user gates.

## Outputs

```yaml
planning_path: intermediate/05-visual-plan.md
asset_index_path: assets/images/image-assets.md
generation_records_path: assets/images/generation-records/
metadata_path: assets/images/metadata/
required_artifacts:
  - static_visual_director_plan
  - visual_need_analysis
  - visual_plan
  - visual_text_plan
  - image_prompt_set
  - image_generation_record
  - image_asset_set
status_fields:
  - static_visual_director_status
  - visual_need_analysis_status
  - visual_plan_status
  - visual_text_plan_status
  - image_assets_status
next_skill: copywriting-quality-review
```

## Core Invariants

```text
All artifacts preserve draft_id, account, content_source_id, and content_origin; hotspot artifacts also preserve source_research_run_id.
Planning objects are written atomically to intermediate/05-visual-plan.md.
Image count is 0 to N from content-derived need; no duration, cost, or call-count cap.
Every generate candidate maps to one accepted task; every accepted task maps to exactly one visual_text_task.
Every accepted image task maps to one complete prompt card and a generation record.
Codex built-in Image 2 generates all accepted non-evidence tasks; source-bound evidence tasks use news-evidence-pip and image_production_path=source_capture.
Passing visual need analysis has accepted_task_dispatch_policy=auto_continue_all_accepted_without_human_confirmation and human_confirmation_required=false.
generated requires local asset and sidecar.
prompt_only/pending/failed/manual states remain honest.
Generated illustration cannot satisfy evidence_support. Evidence support requires claim/source/capture/binding and a deterministic source-derived asset.
```

## Auto Next

```text
draft pass -> run all internal stages.
planning pass -> split by production path: generated context to image-prompt-compiler; source-bound evidence to news-evidence-pip.
prompt pass -> image-asset-producer.
assets generated or honestly downgraded -> copywriting-quality-review.
Never ask the user to confirm accepted tasks, image count, aesthetic direction, or continuation between these stages.
```

## Human Gates

```text
unresolved evidence ownership or claim risk in the draft/source itself
privacy/copyright uncertainty that cannot be resolved by rejecting the candidate
```

These risks are resolved before analysis pass; no accepted task may remain waiting at a human gate. Aesthetic preference is post-generation revision input, not a pre-generation confirmation gate. Routine provider fallback, image count, and visual text decisions are not human gates. Cost and call count are never gates for Codex built-in Image 2.

## Failure Recovery

| Failure | Recovery |
|---|---|
| missing draft P0 field | return to draft owner |
| planning mapping/source failure | static-visual-director |
| prompt integrity failure | image-prompt-compiler |
| source capture / binding / rights failure | news-evidence-pip downgrade or block; never Image 2 fallback |
| generation/overlay failure | image-asset-producer fallback |
| visual text quality failure | route by recovery_action |
| cover issue | cover-design-compiler, not this skill |

## Trace And Open Source

Write every internal stage, environment capability, tool call, fallback, and output path to `intermediate/00-execution-trace.md`.

Publish contracts, tools, and redacted fixtures only. Never publish real account runs, source screenshots, prompts, or generated production assets.

## Acceptance Cases

```text
ordinary no-text scene runs end-to-end without a user pause
zero accepted tasks passes with zero_visual_reason
required mechanism text is preserved through prompt and asset
evidence source failure is blocked or downgraded
Codex environment creates local traceable assets
non-Codex environment creates complete prompt_only delivery
post-delivery request adds or removes one PIP without restarting upstream content
five accepted generated-context tasks all enter Image 2; none are skipped after task four
mixed generated/evidence tasks dispatch to separate producers and rejoin quality review with traceable asset roles
```

## R3-C111-C124 Visual Insert Contract

```text
visual_insert is the current umbrella object; speaker_plus_visual is the only narrow PIP mode.
accepted tasks require presentation_mode, platform_surface_profile_id, video_canvas, visual_asset_canvas, placement_slot, protected speaker/caption/UI regions and aspect_ratio_verification_status.
coordinates are normalized [0,1] on the target video canvas with top-left origin.
the prompt compiler pins target pixels and reduced ratio; the asset producer records actual pixels and rejects mismatches.
cover assets remain a separate cover job owned by cover-design-compiler and must never be derived by blind center crop from a body visual.
visual-need-analysis v0.3 is current; older visual-need contracts are replay-only.
```
