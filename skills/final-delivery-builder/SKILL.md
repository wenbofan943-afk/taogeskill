---
name: final-delivery-builder
description: Compile and verify the current approved R7 content chain as a deterministic v0.6 delivery candidate, synchronized final HTML, desktop/mobile viewport evidence, source map, and execution-contribution record. Use after all twelve current semantic/artifact pointers and per-rendition cover reviews are traceable. Earlier v0.1-v0.5 contracts are read-only replay paths.
---

# Final Delivery Builder

## Current v0.6 Contract

Run `tools/invoke-r7-semantic-workflow.ps1 -Mode run_deterministic`. The current node must be `delivery_candidate_compile`, `final_delivery_render`, or `viewport_acceptance`; do not hand-author the v0.6 candidate, event, pointer, receipt, revision manifest, HTML, viewport report, or screenshots.

The candidate compiler reads exactly twelve current R7 pointers, verifies every revision hash, validates visual assets and each unique per-rendition cover review, then derives card mapping, order, IDs, warnings, action codes, source map, source-binding digest and execution contribution. It wraps a strictly validated v0.5 presentation compatibility payload inside the incompatible `typed_components_v0.6` orchestration contract. This bridge is explicit and versioned; it is not a silent v0.5 mutation.

The v0.6 renderer consumes only the current compiler-produced candidate. It renders all synchronized views, adds the execution-transparency section, binds receipt and template-bundle digests, and commits a distinct final-delivery artifact. Prebuilt HTML fragments remain forbidden.

The H5 viewport node verifies the current final-delivery object and HTML hash, then uses the registered Node/Playwright/browser host to measure desktop 1440×1000 and mobile 390×844. A pass requires zero horizontal overflow, zero failed images, two measurement files and two hash-bound screenshots. Missing browser capability is `not_tested`, never pass; it is a warning only for ordinary content and a blocker for template, renderer, or release validation.

## Required closure

- Brief, structure plan, draft, structure-bound beat map, script review/decision, visual analysis/coverage, asset set, alignment, platform package and cover composition are current and hash-bound.
- Every materialized visual task maps to exactly one asset with a verified file hash and rendering metadata.
- Every cover rendition maps to a unique review with the same rendition ID, output hash, preview hash and surface profile.
- Action cards use only active codes in `routes/r7-action-registry.yaml`; labels and instructions come from `routes/r7-delivery-presentation-registry.yaml`.

The HTML must show in business language:

1. how the piece is structured and where each beat sits;
2. which script issues remain and how they were resolved;
3. where each beat uses or intentionally omits a visual and why;
4. the deterministic/semantic/human/external execution contribution without presenting tool steps as Skill autonomy.

Use v0.6 compiler/renderer plus H5 viewport acceptance for new R7 sessions. v0.1-v0.5 are read-only replay/reproduction contracts. `asset_review_binding_error` returns to the owning cover producer; `candidate_integration_error` returns to the smallest stale producer or compiler mapping; `visual_acceptance_fail` returns to final render after evidence is preserved. Do not generate strategy, call providers, log in, auto-publish, or move Git/Release state.
