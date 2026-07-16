---
name: visual-asset-reviewer
description: Independently inspect a current raster asset and emit typed visual-quality evidence. Use after production and deterministic postprocess, before asset finalization; never use it to generate, edit, crop, overlay, or approve an unseen file.
---

# Visual Asset Reviewer

Require the current delivery-candidate raster, its SHA256, the visual task, intent, source route, prompt/postprocess evidence when applicable, account visual identity, and a reviewer task envelope distinct from every producer envelope.

Open the actual raster. Do not infer quality from a filename, prompt, dimensions, or producer summary. Record exactly these eight dimensions with `pass | revise | reject | not_applicable` and a concrete finding:

`task_alignment`, `attention_composition`, `truthfulness`, `text_number_accuracy`, `crop_safe_area`, `small_screen_readability`, `brand_fit`, `artifact_integrity`.

Write `visual_asset_review@0.1` through `tools/invoke-r7-visual-semantic.ps1 -Mode finalize_asset_review`. The runtime binds the current asset hash, derives the overall verdict, and rejects role overlap, unseen raster claims, stale evidence, incomplete dimensions, or reviewer mutation.

For `revise`, name the smallest revision target, the owning producer, and the exact stale scope. Do not repair the asset yourself. `pass` proceeds to `visual-asset-finalizer`; `reject` blocks; `not_applicable` is valid only when no asset exists by product decision.
