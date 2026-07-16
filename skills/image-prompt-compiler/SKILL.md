---
name: image-prompt-compiler
description: Deterministically compile an approved generated-context visual brief into an immutable Image 2 prompt package and postprocess plan. Use after semantic visual direction; never use it for evidence capture, asset reuse, semantic redesign, or visual review.
---

# Image Prompt Compiler

## Position

Compile, do not redesign. For current H2 contracts consume `visual_prompt_brief@0.1`, its matching `visual_source_route_decision@0.1`, and `routes/r7-visual-operation-registry.yaml`. Historical v0.4/v0.5 plans are replay inputs only.

Run `tools/invoke-r7-visual-semantic.ps1 -Mode compile_prompt`. It writes `visual_postprocess_plan@0.1` before `visual_prompt_package@0.1`, binds both input hashes and the registry digest, and uses only the caller-materialized timestamp. Prompt text, negative constraints, provider payload, operation versions, target canvas and postprocess sequence are deterministic functions of the typed inputs.

Require `source_class=generated_context`, `production_path=codex_builtin_image2`, `brief_status=ready_for_deterministic_compile`, and matching task/revision bindings. A passing analysis invokes this compiler automatically; do not ask the user to approve the accepted set.

Read `docs/reference/R3-图片资产执行规范.md` for the content-derived visual need contract and provider fields. The typed brief owns semantics; the compiler owns engineering assembly only.

## Compile Each Image Task

For each current visual task with `disposition=generate_visual` and `production_path=image_generation`, emit one complete Image 2 prompt card containing:

```text
prompt_id
image_task_id
beat_id
visual_text_task_id
visual_text_decision
visual_text_units
image_asset_type
retention risk and task
viewer_problem_without_visual, primary_visual_job, expected_viewer_change
visual role and type
script context and insert range
why generate and no-visual loss
scene, subject, action, environment
camera, composition, lighting, style
constraints and negative prompt
provider payload and acceptance criteria
prompt_integrity_check
presentation_mode, platform_surface_profile_id, target canvas, and placement_slot
```

Persist the complete prompt text, not only a prompt ID, summary, acceptance note, or old asset path. Each card also carries `prompt_sha256`, calculated from the exact UTF-8 prompt text. A reused or regression task must retain its source prompt text, source prompt digest, and source session; reconstructing a prompt from the finished image is forbidden.

Do not shorten the prompt to keywords or reconstruct missing planning fields from chat memory. Write the target canvas as typed `width_px / height_px / ratio_width / ratio_height / orientation`; prose such as “vertical” or “9:16” is only a human-readable mirror. The complete raster prompt must explicitly state target orientation, ratio, composition protected regions, and intended placement mode.

## Text Compilation

```text
forbidden -> allow_text_in_image=false; do not leak exact text into the prompt.
optional -> include approved units only when they add information; preserve render strategy.
required -> include every approved unit exactly and retain source metadata outside the raster prompt.
```

Do not compile a raster-generation prompt for source evidence, deterministic visuals, existing assets, current-task reuse, talking-head decisions, blocked evidence, or manual assets. Those paths remain owned by their declared producers. Prefer `deterministic_overlay` when Chinese accuracy matters. Use `model_text_in_image` only for short creative text and preserve a fallback path.

## Provider Routes

```text
Codex available -> compile Image 2 prompt and generation parameters for every accepted generated-context task; do not cap that set.
Source-bound evidence -> leave it in the sibling `news-evidence-pip` dispatch; never send it to Image 2 or Seedream.
Codex unavailable -> compile Seedream-compatible prompt, negative prompt, ratio, reference paths, text overlay instructions, and human action.
Neither available -> compile prompt_only or manual_required without pretending an image exists.
```

Provider routing changes syntax, not the approved semantic plan. Do not ask the user to re-enter account, topic, draft, or product boundaries.

## Gate

Set `prompt_integrity_check=pass` only when complete generated-context prompts are present, visual need proof and text decisions are preserved, and every prompt carries the same `presentation_mode / target canvas / placement_slot` as its task. Prompt task IDs must equal exactly the current `generate_visual` subset; they must not equal the whole visual ledger. On pass, use `next_skill: image-asset-producer`.

If the visual task itself is contradictory, return to `static-visual-director`; if only provider syntax is invalid, fix locally.

Update execution trace with provider selection, compiled fields, fallback route, and any agent assistance.
