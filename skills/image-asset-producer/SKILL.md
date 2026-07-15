---
name: image-asset-producer
description: Materialize approved image prompt cards into traceable picture-in-picture assets, deterministic visual-text overlays, or honest Seedream/manual fallback packages. Use internally after image prompt compilation when taogeskill must detect Codex image capability, generate or downgrade assets, version files, and write generation records and metadata sidecars.
---

# Image Asset Producer

## Position

Execute only approved `source_class=generated_context` and `disposition=generate_visual` tasks without changing content strategy. Consume their prompt cards from `intermediate/05-visual-plan.md` and produce Image 2 base assets under the current session only.

Read `docs/reference/R3-图片资产执行规范.md` for C54-C70, status semantics, provider routing, and asset trace rules.

## Environment Route

```text
Codex image capability available -> render all accepted current `generate_visual` tasks with the approved Image 2 prompts.
Capability unavailable in production -> persist `waiting_assets`; do not substitute SVG, a stale asset, or a prompt-only object for a completed base image.
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

Persist the provider attempt, outcome, and output reference before copying or composing locally. If the command is interrupted after the provider returns, reconcile the recorded output and filesystem first. Resume post-processing from the existing output; do not issue a second provider attempt unless the first is proven failed and a new attempt is explicitly authorized by retry policy.

There is no provider call limit for Codex built-in Image 2. Execute all accepted tasks; do not stop after an arbitrary count. Record `actual_provider_execution_count` after execution as evidence, not as a budget or gate. Deterministic overlays, cover text composition, crop/retitle variants, and other derived assets are not provider calls and must link to their parent asset instead of increasing the execution count.

The overlay tool writes a layout sidecar containing exact rectangles and hashes. Multi-column labels use explicit `left_third / center_third / right_third` placements; array index must not accidentally turn horizontal roles into vertical stacking.

The accepted generated-context subset arrives with `human_confirmation_required=false`. Begin Image 2 execution automatically after prompt integrity passes. Source capture, deterministic, existing, reuse, talking-head, blocked-evidence, and manual tasks are not inputs to this producer. Aesthetic preference is not a pre-generation confirmation gate; handle it as a versioned revision after the first generated result.

Include `visual_text_plan_id`, `visual_text_unit_ids`, `visual_insert_task_id`, `image_task_id`, prompt ID, provider, model, status, and quality gate placeholders in asset metadata. Persist `presentation_mode`, planned target canvas, `actual_width_px`, `actual_height_px`, reduced actual aspect ratio, and `aspect_ratio_verification_status` after the provider returns. A visually attractive image with the wrong ratio is not accepted; create a revision or route to an explicit rendition strategy.

## Gate And Recovery

```text
generated requires a readable local file and sidecar.
generated requires actual dimensions and aspect_ratio_verification_status=pass before downstream use.
all accepted generated-context tasks have one terminal generation record; none are skipped by cost or count.
prompt_only requires a complete prompt, exact text, placement, and human action.
forbidden with rendered text is blocked.
required with missing text is blocked.
source-bound evidence may not be replaced by a generated lookalike.
```

On completion, set `next_skill: copywriting-quality-review`. Update execution trace with environment capability, actual provider execution count, tool calls, fallback, generated paths, and agent assistance.
