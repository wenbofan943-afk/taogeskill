---
name: business-delivery-acceptance
description: Inspect the rendered final HTML and its actual images as a business delivery, separately from technical viewport checks. Use after viewport v0.2 to verify hierarchy, title, final-asset binding, readiness truthfulness, visual quality, and action usability before the final human gate.
---

# Business Delivery Acceptance

Consume the current `final_delivery`, `viewport_acceptance_report` v0.2, and the exact desktop/mobile screenshots named by that report. Open the screenshots and every delivery image actually shown; do not infer visual quality from dimensions, filenames, DOM measurements, or a prior review summary.

Record six dimensions: information hierarchy, delivery title quality, final asset binding, readiness truthfulness, visual human review, and action usability. Bind the exact HTML and screenshot hashes, set `actual_images_viewed=true` only after real visual inspection, and derive the overall status from dimension results.

`business_delivery_rejected` returns to the smallest owning producer or renderer. `pass` and `pass_with_warnings` proceed to `final_human_gate_h7`. This skill does not publish, modify the HTML, or conceal warnings.
