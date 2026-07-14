---
name: talking-head-image-pip
description: Orchestrate the current Taoge talking-head visual pipeline after script readiness. Use for 口播配图、画中画、全屏视觉、证据截图、确定性信息卡 or Image 2 generation while preserving full beat coverage and producer-specific evidence.
---

# Talking Head Image PIP

Act as the user-facing facade; internal producer transitions are automatic. Require current matching draft, selected structure plan, structure-bound beat map, review/decision, and script readiness.

Run:

1. `static-visual-director` creates v0.4 need analysis and full coverage ledger.
2. Dispatch every accepted task by disposition.
3. Persist external attempt/outcome/output references before copying, overlays, crops, or platform renditions.
4. Reconcile existing provider/capture output after interruption; never blindly repeat an external call.
5. Run `copywriting-quality-review(script_visual_alignment)` after current assets/wait states are recorded.

Dispatch:

- `generate_visual` → `image-prompt-compiler` → Image 2 through `image-asset-producer`.
- `create_deterministic_visual` → deterministic renderer; no provider task.
- `use_source_evidence` → `news-evidence-pip`; never Image 2.
- `use_existing_asset` → validate provenance, rights, semantic and canvas fit; no provider/capture task.
- `reuse_visual_task` → add an occurrence only.
- `talking_head_intentional` → no asset task.
- `evidence_blocked` → downgrade the claim or remain blocked.
- `manual_visual_required` → wait for a named manual asset and acceptance condition.

Do not ask which accepted images to generate. Image count remains 0..N with no cap; all accepted Image 2 tasks run when the user has asked to execute the production chain and capability is available. Do not alter the script, fabricate evidence, auto-publish, or hide waiting/failed states.
