---
name: visual-asset-finalizer
description: Deterministically validate and finalize one reviewed delivery image per accepted visual task. Use after image asset production and before script-visual alignment to reject provisional bases, missing postprocess evidence, stale hashes, wrong parents, or review records that do not bind the actual output.
---

# Visual Asset Finalizer

Read the current `image_asset_set` v0.3 only. Run `tools/invoke-r7-h7-finalize-assets.ps1` or the registered `visual_asset_finalize` deterministic node; do not edit pixels, invent evidence, or repair invalid producer output here.

For every task, verify the base file, all selected derived evidence, required postprocess, parent binding, delivery file, sidecar, generation record, postprocess record and visual review by SHA256. The review must bind the delivery output hash and have `visual_review_status=pass`.

Write one immutable `asset_finalize_record` per task, then write `image_asset_delivery_set` last. The upstream `finalize_requested_at` is inherited verbatim so identical input is byte-stable. A repeated call reuses identical outputs; a changed asset or review requires a new upstream revision.

Success hands `image_asset_delivery_set` to `copywriting-quality-review`. Failure returns `final_asset_binding_error` to `image-asset-producer` without advancing the workflow.
