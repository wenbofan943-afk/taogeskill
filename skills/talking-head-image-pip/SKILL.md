---
name: talking-head-image-pip
description: Orchestrate the current Taoge talking-head visual pipeline after script readiness. Use for 口播配图、画中画、全屏视觉、证据截图、确定性信息卡 or Image 2 generation while preserving full beat coverage and producer-specific evidence.
---

# Talking Head Image PIP

Act as the user-facing facade; internal producer transitions are automatic. Require current matching draft, selected structure plan, structure-bound beat map, review/decision, and script readiness.

Run:

1. `static-visual-director` creates the coverage ledger, intent decision, exclusive source route and generated-context prompt brief.
2. `image-prompt-compiler` deterministically merges the brief with the registered operation, canvas, safe-area, text and provider contracts.
3. Dispatch every accepted task by its exclusive source class and the operation registry.
4. Persist external attempt/outcome/output references before copying, overlays, crops, or platform renditions; reconcile before retry.
5. `visual-asset-reviewer` inspects each current final-candidate raster; `visual-asset-finalizer` binds only a passing current review.
6. `delivery-visual-reviewer` later inspects final assets plus final HTML desktop/mobile evidence before business acceptance.
7. Run `copywriting-quality-review(script_visual_alignment)` after current assets/wait states are recorded.

Dispatch:

- `generated_context` → `generate_visual` → `image-prompt-compiler` → Image 2 base through `image-asset-producer`; exact text/graphics are deterministic child layers.
- `source_bound_evidence` → `use_source_evidence` → `news-evidence-pip`; real capture plus deterministic annotation, never Image 2.
- `explicit_existing_asset` → `use_existing_asset`; require exact scoped authorization plus provenance, rights, semantic, currentness, canvas, and quality checks.
- `reuse_visual_task` → add an occurrence only.
- `talking_head_intentional` → no asset task.
- `evidence_blocked` → downgrade the claim or remain blocked.
- `manual_visual_required` is historical/non-current; a new accepted non-evidence visual without authorization is generated context, not a deterministic/manual substitute.

Do not ask which accepted images to generate. Image count remains 0..N with no cap; all accepted Image 2 tasks run when the user has asked to execute the production chain and capability is available. An unregistered operation yields `waiting_capability`; never invent a one-off helper. Do not alter the script, let a producer self-review, fabricate evidence, auto-publish, or hide waiting/failed states.
