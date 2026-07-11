---
name: image-prompt-compiler
description: Compile approved static visual and visual-text tasks into complete provider-ready image prompt cards for Codex image generation or Seedream-compatible prompt delivery. Use internally after static visual planning passes; do not use it to re-decide topic, copy, visual role, or evidence claims.
---

# Image Prompt Compiler

## Position

Compile, do not redesign. Consume the approved `static_visual_director_plan`, `visual_plan`, and `visual_text_plan` from `intermediate/05-visual-plan.md`.

Read `docs/reference/R3-图片资产执行规范.md` for `C54-C70`, provider fields, and the 14-layer prompt contract.

## Compile Each Image Task

For each required or optional `image_task_id`, emit one complete prompt card containing:

```text
prompt_id
image_task_id
beat_id
visual_text_task_id
visual_text_decision
visual_text_units
image_asset_type
retention risk and task
visual role and type
script context and insert range
why generate and no-visual loss
scene, subject, action, environment
camera, composition, lighting, style
constraints and negative prompt
provider payload and acceptance criteria
prompt_integrity_check
```

Persist the complete prompt text, not only a prompt ID, summary, acceptance note, or old asset path. Each card also carries `prompt_sha256`, calculated from the exact UTF-8 prompt text. A reused or regression task must retain its source prompt text, source prompt digest, and source session; reconstructing a prompt from the finished image is forbidden.

Do not shorten the prompt to keywords or reconstruct missing planning fields from chat memory.

## Text Compilation

```text
forbidden -> allow_text_in_image=false; do not leak exact text into the prompt.
optional -> include approved units only when they add information; preserve render strategy.
required -> include every approved unit exactly and retain source metadata outside the raster prompt.
```

Use `source_native_text` for screenshots and evidence assets. Prefer `deterministic_overlay` when Chinese accuracy matters. Use `model_text_in_image` only for short creative text and preserve a fallback path.

## Provider Routes

```text
Codex available -> compile gpt-image-2 prompt and generation parameters.
Codex unavailable -> compile Seedream-compatible prompt, negative prompt, ratio, reference paths, text overlay instructions, and human action.
Neither available -> compile prompt_only or manual_required without pretending an image exists.
```

Provider routing changes syntax, not the approved semantic plan. Do not ask the user to re-enter account, topic, draft, or product boundaries.

## Gate

Set `prompt_integrity_check=pass` only when the prompt card is complete, the text decision is preserved, and evidence source metadata remains traceable. On pass, set `next_skill: image-asset-producer`.

If the visual task itself is contradictory, return to `static-visual-director`; if only provider syntax is invalid, fix locally.

Update execution trace with provider selection, compiled fields, fallback route, and any agent assistance.
