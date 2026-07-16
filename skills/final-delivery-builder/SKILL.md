---
name: final-delivery-builder
description: "Compile and render the current R7 v0.9 business-first delivery for direct or hotspot input from finalized image assets, then run technical viewport acceptance separately from business delivery acceptance. Use only after current content, final assets, covers, and reviews are hash-bound; never hand-author the candidate or HTML."
---

# Final Delivery Builder

## Current plan-pinned contracts

Run `tools/invoke-r7-semantic-workflow.ps1 -Mode run_deterministic`. New direct/hotspot v0.4 plans produce delivery v0.9; v0.3 / delivery v0.8 and earlier are historical replay. Do not hand-author candidate, event, pointer, receipt, manifest, HTML, viewport report, business acceptance, or screenshots.

The source set is derived from the plan and origin registry, never a universal hardcoded count. Direct uses twelve current pointers. Hotspot adds request, research set, panel, decision, current selected source and current freshness review, and requires the selected source to be `ready_for_delivery`. Candidate v0.7 keeps source URLs, claim evidence, fact/propagation/risk and checked time distinct, and records network reads, source capture attempts, image-provider attempts and external side-effect steps separately.

Treat a visual task, its covered beats, and each physical occurrence as separate identities. One occurrence may span adjacent beats, but project its ID only onto the earliest covered beat; keep the visual task reference on every covered beat. Reject missing, duplicate, non-contiguous, or task-external covered beats before writing the candidate. Never duplicate one occurrence ID across beat cards.

The renderer consumes only the current compiler-produced candidate. Candidate v0.9 requires an independent `delivery_title` and a finalized `image_asset_delivery_set`; every visual card must bind its unique `delivery_asset_ref`, never a provisional base. Prebuilt run-specific HTML remains forbidden.

The v0.9 page primary layer is ordered: delivery header, formal script, final picture-in-picture assets, platform materials, warnings, actions. Structure, beats, routes, trace and execution counts remain available in one collapsed audit section. When a cover and its technical preview are the same physical hash, render the file once.

The H7 viewport node verifies only geometry, resources and screenshot hashes at desktop 1440×1000 and mobile 390×844. It never emits a visual-quality pass. A separate `business-delivery-acceptance` task must inspect the screenshots and actual images across six business dimensions before the final human gate.

## Required closure

- Brief, structure plan, draft, structure-bound beat map, script review/decision, visual analysis/coverage, asset set, alignment, platform package and cover composition are current and hash-bound.
- Every materialized visual task maps to exactly one asset with a verified file hash and rendering metadata.
- Every visual occurrence has one deterministic owner beat; non-adjacent reuse is represented by a new occurrence, not a duplicate projection.
- Every cover rendition maps to a unique review with the same rendition ID, output hash, preview hash and surface profile.
- Action cards use only active codes in `routes/r7-action-registry.yaml`; labels and instructions come from `routes/r7-delivery-presentation-registry.yaml`.

The primary HTML must show in business language:

1. one readable delivery title and honest readiness;
2. the formal script;
3. final downloadable visual inserts and exact use positions;
4. platform-specific materials;
5. unresolved warnings and executable next actions.

Detailed structure, beat, route, provenance and execution contribution stay in the collapsed audit layer.

Use the plan-pinned compiler/renderer plus H5 viewport acceptance. v0.1-v0.5 are read-only replay/reproduction contracts. `asset_review_binding_error` returns to the owning cover producer; `candidate_integration_error` returns to the smallest stale producer or compiler mapping; `visual_acceptance_fail` returns to final render after evidence is preserved. Do not generate strategy, call providers, log in, auto-publish, or move Git/Release state.
