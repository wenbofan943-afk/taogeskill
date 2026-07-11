---
name: image-asset-producer
description: Materialize approved image prompt cards into traceable picture-in-picture assets, deterministic visual-text overlays, or honest Seedream/manual fallback packages. Use internally after image prompt compilation when taogeskill must detect Codex image capability, generate or downgrade assets, version files, and write generation records and metadata sidecars.
---

# Image Asset Producer

## Position

Execute approved tasks without changing content strategy. Consume prompt cards from `intermediate/05-visual-plan.md` and produce assets under the current session only.

Read `docs/reference/R3-图片资产执行规范.md` for C54-C70, status semantics, provider routing, and asset trace rules.

## Environment Route

```text
Codex image capability available -> render required assets with the approved prompt.
Capability unavailable -> deliver Seedream-compatible prompt_only assets.
Provider or render fails -> record generation_failed and a retry or manual action.
```

Never call an external image API, log in to a platform, or claim generated when no local file exists.

## Visual Text Rendering

Respect each task:

```text
forbidden -> no text in raster and no overlay.
model_text_in_image -> validate exact text; failure falls back to deterministic_overlay.
deterministic_overlay -> compose approved units onto the generated base image using the declared placement and budget.
source_native_text -> preserve original screenshot/evidence text; annotate without replacing the source.
prompt_only -> deliver exact text, placement, and provider instructions in HTML and Markdown.
```

For picture-in-picture deterministic overlay, use `scripts/compose-visual-text.ps1`. Cover composition remains owned by `cover-design-compiler`.

## Asset Records

Every attempt writes `image_generation_record`. Every generated image writes an immutable `image_asset_id`, local `asset_path`, checksum, and metadata sidecar. Rework creates a new asset version and never overwrites the old file.

Record `expected_provider_call_count` before execution and actual provider calls after execution. Count only selected base tasks whose generation intent is `render_now`. Deterministic overlays, cover text composition, crop/retitle variants, and other derived assets are not provider calls and must link to their parent asset instead of increasing the call count.

Include `visual_text_plan_id`, `visual_text_unit_ids`, `image_task_id`, prompt ID, provider, model, status, and quality gate placeholders in asset metadata.

## Gate And Recovery

```text
generated requires a readable local file and sidecar.
prompt_only requires a complete prompt, exact text, placement, and human action.
forbidden with rendered text is blocked.
required with missing text is blocked.
source-bound evidence may not be replaced by a generated lookalike.
```

On completion, set `next_skill: copywriting-quality-review`. Update execution trace with environment capability, tool calls, fallback, generated paths, and agent assistance.
