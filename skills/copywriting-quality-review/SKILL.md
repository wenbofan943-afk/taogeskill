---
name: copywriting-quality-review
description: Review the current script and visual coverage/assets as one aligned delivery, or review final cover renditions. Use after visual tasks are resolved enough for alignment, and after cover composition for surface review. Route only the failed layer; never silently rewrite copy or approve visuals from structure checks alone.
---

# Copywriting Quality Review

## script_visual_alignment

Require current matching draft, selected structure, structure-bound beat map, script review/decision, visual need analysis, coverage ledger, and asset records. Check beat binding, visual-job fit, factual consistency, evidence presentation, redundancy, adjacent sequence, cognitive load, mobile readability, asset traceability, and readiness binding.

For every visual-text task, preserve `visual_text_quality_gate_status`, `information_delta_status`, and `source_binding_status`. A failed field must name its owning layer and `recovery_action`; do not collapse text accuracy, evidence binding, or information increment into a generic visual pass.

Write immutable `script_visual_alignment_review@0.1.0` and its current pointer last. Use only:

`pass`, `pass_with_warnings`, `needs_script_revision`, `needs_visual_revision`, `blocked`, or `stale`.

Structural checkers may prove completeness and reference closure. Actual narrative/visual quality requires a reasoned Codex or human observation. A generated scene cannot serve as evidence; source evidence must retain claim/source/capture/hash/freshness binding. A draft or beat digest mismatch is stale, not a warning.

Route:

- pass / pass_with_warnings → `platform-packaging-adapter`.
- needs script revision → `copywriting-draft-writer(revision)` and invalidate affected downstream bindings.
- needs visual revision → return only affected tasks to their producer.
- waiting assets/authorization → preserve the normal waiting state; do not call it blocked.

## cover_review

Review each platform-specific composited cover, surface preview, rendered text, safe areas, crop/adaptation, mobile readability, and asset lineage. A title or background alone is not an upload-ready cover. Only a reasoned Codex/human visual review may write visual pass.

Do not publish, generate a platform package, rewrite the script, or mutate the read-only review to obtain a pass.
