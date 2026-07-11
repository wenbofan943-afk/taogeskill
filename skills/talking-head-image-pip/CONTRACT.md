# Talking Head Image PIP Contract

```yaml
skill_id: talking-head-image-pip
contract_set_version: r3-asset-runtime-v0.2
contract_version: 0.6.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C01-R3-C70
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
  - source_research_run_id
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
  - visual_plan
  - visual_text_plan
  - image_prompt_set
  - image_generation_record
  - image_asset_set
status_fields:
  - static_visual_director_status
  - visual_plan_status
  - visual_text_plan_status
  - image_assets_status
next_skill: copywriting-quality-review
```

## Core Invariants

```text
All artifacts preserve draft_id, account, and source_research_run_id.
Planning objects are written atomically to intermediate/05-visual-plan.md.
Every planned image task maps to exactly one visual_text_task.
Every produced image task maps to one complete prompt card and a generation record.
generated requires local asset and sidecar.
prompt_only/pending/failed/manual states remain honest.
Generated illustration cannot satisfy evidence_support without a bound source asset.
```

## Auto Next

```text
draft pass -> run all internal stages.
planning pass -> image-prompt-compiler.
prompt pass -> image-asset-producer.
assets generated or honestly downgraded -> copywriting-quality-review.
Never ask the user to continue between these stages.
```

## Human Gates

```text
unresolved evidence ownership or claim risk
privacy/copyright uncertainty
user-owned aesthetic preference with material impact
```

Routine provider fallback, image count, and visual text decisions are not human gates.

## Failure Recovery

| Failure | Recovery |
|---|---|
| missing draft P0 field | return to draft owner |
| planning mapping/source failure | static-visual-director |
| prompt integrity failure | image-prompt-compiler |
| generation/overlay failure | image-asset-producer fallback |
| visual text quality failure | route by recovery_action |
| cover issue | cover-design-compiler, not this skill |

## Trace And Open Source

Write every internal stage, environment capability, tool call, fallback, and output path to `intermediate/00-execution-trace.md`.

Publish contracts, tools, and redacted fixtures only. Never publish real account runs, source screenshots, prompts, or generated production assets.

## Acceptance Cases

```text
ordinary no-text scene runs end-to-end without a user pause
required mechanism text is preserved through prompt and asset
evidence source failure is blocked or downgraded
Codex environment creates local traceable assets
non-Codex environment creates complete prompt_only delivery
post-delivery request adds or removes one PIP without restarting upstream content
```
