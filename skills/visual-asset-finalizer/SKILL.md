---
name: visual-asset-finalizer
description: Deterministically validate and finalize one reviewed delivery image per accepted visual task. Use after image asset production and before script-visual alignment to reject provisional bases, missing postprocess evidence, stale hashes, wrong parents, or review records that do not bind the actual output.
---

# Visual Asset Finalizer

For current direct or hotspot v0.5, run registered node `visual_asset_finalize_l3`. It consumes `image_asset_set@0.4` plus the independent `visual_asset_review_set@0.1`, and writes `image_asset_delivery_set@0.2`. It joins review records by visual task and exact delivery-asset hash. A valid zero-visual pair finalizes as `finalized_no_visual` with zero delivery assets and zero finalize records.

Historical direct/hotspot v0.4 reads `image_asset_set@0.3` and uses `tools/invoke-r7-h7-finalize-assets.ps1` or registered node `visual_asset_finalize`. Do not edit pixels, invent evidence, or repair invalid producer output in either path.

For every task, verify the base file, all selected derived evidence, required postprocess, parent binding, delivery file, sidecar, generation record, postprocess record and visual review by SHA256. The review must bind the delivery output hash and have `visual_review_status=pass`.

Write one immutable `asset_finalize_record` per task, then write `image_asset_delivery_set` last. The upstream `finalize_requested_at` is inherited verbatim so identical input is byte-stable. A repeated call reuses identical outputs; a changed asset or review requires a new upstream revision.

Success hands `image_asset_delivery_set` to `copywriting-quality-review`. Failure returns `final_asset_binding_error` to `image-asset-producer` without advancing the workflow.
