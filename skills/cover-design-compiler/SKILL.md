---
name: cover-design-compiler
description: Compile an approved Chinese short-video platform package and cover background assets into traceable platform-ready cover images, cover composition records, or Seedream-compatible prompt-only fallbacks. Use after platform-packaging-adapter has produced platform titles and cover variants, when Codex needs to create or revise Douyin, Kuaishou, Xiaohongshu, or WeChat Channels covers, distinguish cover backgrounds from upload-ready covers, add accurate Chinese title overlays, adapt platform crops, or deliver non-Codex cover prompts without pretending an image exists.
---

# Cover Design Compiler

## Runtime Contract

```yaml
contract_set_version: r3-cover-composition-v0.2
contract_version: 0.3.0
contract_status: active
skill_type: cover_asset_compiler
primary_input: platform_package + cover_variant_set + visual_plan + image_asset_set
primary_output: cover_design_package + cover_composition + updated image_asset_set
next_skill_on_pass: copywriting-quality-review(cover_review)
reference: docs/reference/R3-图片资产执行规范.md
composition_script: scripts/compose-cover.ps1
```

## Read First

Read only the task-relevant sections from:

```text
交接物字段词典.md
docs/reference/R3-图片资产执行规范.md
accounts/{account}/runs/{session_id}/intermediate/05-visual-plan.md
accounts/{account}/runs/{session_id}/intermediate/08-platform-package-draft.md
accounts/{account}/runs/{session_id}/assets/images/image-assets.md
```

Do not infer titles, asset IDs, or platform requirements from chat memory when session artifacts exist.

## Ownership

```text
platform-packaging-adapter：title options、recommended titles、platform strategy、cover_variant_set。
image-asset-producer：generation records、image assets、cover background assets。
cover-design-compiler：cover_design_package、cover_composition、composited/platform cover assets。
copywriting-quality-review：cover_review and cover_quality_gate。
final-delivery-builder：display、copy、download、trace only。
```

Do not rewrite the script, choose a new topic, change the recommended video title, or build final HTML.

## Preconditions

Require:

```text
package_status=package_pass
platform_package has recommended_cover_title for each target platform
visual_plan_status=visual_plan_pass
image_asset_set exists
cover background asset exists, or prompt-only fallback is possible
content_source_id / content_origin remain unchanged; hotspot runs additionally preserve source_research_run_id
```

If a cover background is missing in a Codex environment, route to `image-asset-producer` to create it. Do not silently invent an untracked image.

## Workflow

1. Build `cover_design_package` from platform titles, cover variants, visual concept, background assets, layout, safe areas, and target ratios.
   Use `cover_visual_entry_type`; migrate legacy `variant_role` only for reading. Keep `cover_variant_difference_type` and `materially_distinct_variant_count` traceable.
2. Set one `platform_cover_strategy` per platform:

```text
reuse / crop / retitle / independent_composition / prompt_only
```

3. Select `cover_text_render_strategy`:

```text
deterministic_overlay：default for final Chinese text accuracy.
model_text_in_image：short poster-like candidate only; verify every character.
manual_design：user/designer-owned composition.
prompt_only：composition unavailable; deliver prompt and layout contract.
```

4. For `deterministic_overlay`, run `scripts/compose-cover.ps1` with a session-local background and a new output path. Never overwrite an existing image asset.
5. Record each attempt as `cover_composition` and add the output to `image_asset_set.assets[]` with:

```text
image_asset_type=cover_image
cover_asset_role=cover_composited_asset / platform_cover_asset
source_cover_composition_id
target_platforms
image_status=generated
asset_path
metadata_sidecar_path
```

6. If composition is unavailable, set:

```text
cover_text_render_strategy=prompt_only
platform_cover_strategy=prompt_only
cover_composition_status=prompt_only
image_status=pending_external / manual_required
```

Include the complete prompt, negative prompt, target ratio, title text, layout, safe area, expected output, and human action. Do not label it generated.
7. Hand off automatically to `copywriting-quality-review` with `review_mode=cover_review`.

Before handoff, record:

```text
thumbnail_readability_status
cover_contract_render_alignment_status
platform_preview_status
platform_preview_evidence_path when available
```

`title_only` does not count as a materially distinct visual variant. When preview tooling is unavailable, write `unavailable / not_checked`; do not claim preview pass.

## Composition Rules

Creativity belongs to `cover_visual_concept` and the background asset. Composition protects readability and upload reliability.

```text
Keep cover title separate from video title.
Prefer 6-14 Chinese characters; split into at most 2-3 deliberate lines.
Keep the face / subject and platform UI safe areas clear.
Use enough contrast at mobile thumbnail size.
Do not add claims absent from the script.
Do not include phone numbers, WeChat IDs, private plates, or unauthorized personal data.
```

`model_text_in_image` may enter final delivery only when `text_accuracy_status=pass`. Any wrong character routes to deterministic overlay or manual design.

## Output Paths

```text
intermediate/08-cover-design-package.md
intermediate/09-cover-compositions.md
assets/images/covers/{image_asset_id}.png
assets/images/generation-records/{cover_composition_id}.md
assets/images/metadata/{image_asset_id}.md
assets/images/image-assets.md
intermediate/00-execution-trace.md
```

All paths are relative to `accounts/{account}/runs/{session_id}/`. Create a new `image_asset_id` for every revision.

## Required Handoff

```text
cover_design_package_id:
cover_composition_ids:
package_id:
image_asset_set_id:
content_source_id:
content_origin:
source_research_run_id: hotspot only; not_applicable for direct input
target_platforms:
cover_text_render_strategy_summary:
platform_cover_strategy_summary:
cover_composition_status_summary:
upload_ready_cover_count:
prompt_only_cover_count:
artifact_path:
next_skill: copywriting-quality-review
review_mode: cover_review
execution_trace_update:
```

## Failure And Recovery

```text
missing platform title -> platform-packaging-adapter
missing background asset in Codex -> image-asset-producer
output path already exists -> create a new image_asset_id; never overwrite
wrong model-rendered text -> deterministic_overlay / manual_design
composition tool unavailable -> prompt_only
safe-area or mobile-readability failure -> revise cover composition only
design/render mismatch -> revise cover composition or background asset without rewriting the script
platform preview unavailable -> record unavailable/not_checked and continue with an honest warning
privacy or misleading claim -> cover_composition_status=composition_needs_fix
```

Do not ask the user to say “continue” on a successful path. Only stop for a real creative choice, missing manual asset, or blocked risk.

## Execution Trace

Record:

```text
expected_skill=cover-design-compiler
execution_source=skill_defined / environment_capability / manual_fallback
cover_composition_id
input_background_asset_id
cover_text_render_strategy
platform_cover_strategy
output_asset_id
cover_composition_status
next_skill
```

## Boundaries

Do not call external Seedream APIs, log into platforms, auto-publish, render video, or put real account runs into public samples.
