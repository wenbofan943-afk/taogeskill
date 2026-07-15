---
name: final-delivery-builder
description: "Compile and verify a plan-pinned R7 delivery: direct v0.6 from twelve current pointers, or hotspot v0.7 with research/decision/selected-source/freshness bindings. Use only after current assets and per-rendition reviews are traceable; never hand-author the candidate or HTML."
---

# Final Delivery Builder

## Current plan-pinned contracts

Run `tools/invoke-r7-semantic-workflow.ps1 -Mode run_deterministic`. Direct v0.2 remains delivery v0.6; hotspot v0.2 is delivery v0.7. Do not hand-author candidate, event, pointer, receipt, manifest, HTML, viewport report, or screenshots.

The source set is derived from the plan and origin registry, never a universal hardcoded count. Direct uses twelve current pointers. Hotspot adds request, research set, panel, decision, current selected source and current freshness review, and requires the selected source to be `ready_for_delivery`. Candidate v0.7 keeps source URLs, claim evidence, fact/propagation/risk and checked time distinct, and records network reads, source capture attempts, image-provider attempts and external side-effect steps separately.

Treat a visual task, its covered beats, and each physical occurrence as separate identities. One occurrence may span adjacent beats, but project its ID only onto the earliest covered beat; keep the visual task reference on every covered beat. Reject missing, duplicate, non-contiguous, or task-external covered beats before writing the candidate. Never duplicate one occurrence ID across beat cards.

The renderer consumes only the current compiler-produced candidate. Hotspot v0.7 adds human-readable research, selection, current-source and freshness cards plus execution transparency. Direct v0.6 behavior remains replay-compatible. Prebuilt HTML fragments remain forbidden.

The H5 viewport node verifies the current final-delivery object and HTML hash, then uses the registered Node/Playwright/browser host to measure desktop 1440×1000 and mobile 390×844. A pass requires zero horizontal overflow, zero failed images, two measurement files and two hash-bound screenshots. Missing browser capability is `not_tested`, never pass; it is a warning only for ordinary content and a blocker for template, renderer, or release validation.

## Required closure

- Brief, structure plan, draft, structure-bound beat map, script review/decision, visual analysis/coverage, asset set, alignment, platform package and cover composition are current and hash-bound.
- Every materialized visual task maps to exactly one asset with a verified file hash and rendering metadata.
- Every visual occurrence has one deterministic owner beat; non-adjacent reuse is represented by a new occurrence, not a duplicate projection.
- Every cover rendition maps to a unique review with the same rendition ID, output hash, preview hash and surface profile.
- Action cards use only active codes in `routes/r7-action-registry.yaml`; labels and instructions come from `routes/r7-delivery-presentation-registry.yaml`.

The HTML must show in business language:

1. how the piece is structured and where each beat sits;
2. which script issues remain and how they were resolved;
3. where each beat uses or intentionally omits a visual and why;
4. the deterministic/semantic/human/external execution contribution without presenting tool steps as Skill autonomy.

Use the plan-pinned compiler/renderer plus H5 viewport acceptance. v0.1-v0.5 are read-only replay/reproduction contracts. `asset_review_binding_error` returns to the owning cover producer; `candidate_integration_error` returns to the smallest stale producer or compiler mapping; `visual_acceptance_fail` returns to final render after evidence is preserved. Do not generate strategy, call providers, log in, auto-publish, or move Git/Release state.
