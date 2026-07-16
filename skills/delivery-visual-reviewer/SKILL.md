---
name: delivery-visual-reviewer
description: Independently inspect final delivery assets, HTML, and desktop/mobile screenshots. Use after rendering and viewport capture; never judge from base images, DOM metrics, or a prior asset review alone.
---

# Delivery Visual Reviewer

Require the current final delivery assets, final HTML, desktop screenshot, mobile screenshot, their SHA256 values, and a reviewer task envelope distinct from all producers.

Open every final asset and both screenshots. Base-image-only review is invalid because typography, crop, insertion context, card/cover composition, duplication, and page hierarchy can change after base generation.

Record exactly these six dimensions with `pass | revise | reject | not_applicable` and a concrete finding:

`final_text_accuracy`, `crop_and_safe_area`, `insertion_context`, `platform_card_and_cover`, `duplicate_display`, `page_hierarchy`.

Write `delivery_visual_review@0.1` through `tools/invoke-r7-visual-semantic.ps1 -Mode finalize_delivery_review`. The runtime binds the current HTML and evidence hashes, derives the result, and rejects stale evidence, unseen screenshots/assets, base-only inspection, role overlap, or reviewer mutation.

For `revise`, return the smallest revision target to its owning producer and list stale evidence. Do not edit assets or HTML. `pass` proceeds to `business-delivery-acceptance`; `reject` blocks.
