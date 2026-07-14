---
name: static-visual-director
description: Analyze every current structure-bound beat of a Chinese talking-head script and compile a complete visual coverage ledger. Use internally after spoken-script readiness, before provider prompts, source capture, deterministic rendering, or manual asset work.
---

# Static Visual Director

Require current matching draft, selected structure plan, `structure_bound` beat map, script review/decision, and `script_readiness=ready|ready_with_warnings`. Reject semantic-only or stale input.

For every beat choose exactly one primary disposition:

`generate_visual`, `create_deterministic_visual`, `use_source_evidence`, `use_existing_asset`, `reuse_visual_task`, `talking_head_intentional`, `evidence_blocked`, or `manual_visual_required`.

For every current visual task prove at least one value: attention, understanding, evidence, demonstration, emotion, or memory. Record viewer loss without it, expected change, information increment, and why its production path is appropriate. Analyze viewer need before choosing presentation mode, slot, canvas, ratio, or prompt.

Rules:

- Bind the account-scoped visual identity by `identity_id`. If the current content needs a justified departure, record `identity_override_reason`; an account identity guides expression but cannot set image count.
- Image count is content-derived 0..N with no upper, cost, or provider-call gate.
- Every accepted `generate_visual` creates one Image 2 provider task.
- Deterministic, evidence, existing, and manual paths never masquerade as Image 2.
- `use_source_evidence(reuse_verified_capture)` retains claim/source/hash/time/freshness binding and creates no new capture task.
- Historical non-evidence assets become current `use_existing_asset` tasks. Reusing a current task creates only a new occurrence.
- Zero assets are ready only when every beat is valid `talking_head_intentional` and no supplemental task exists.
- `evidence_blocked` and `manual_visual_required` may complete analysis but cannot be reported as ready assets.

Derive and validate all nine count axes from task, attempt, occurrence, rendition, and cover records. Do not accept supplied totals without recomputation.

For every accepted asset-producing task, preserve the existing visual-text contract as `visual_text_tasks`: record the decision, approved units, information delta, render strategy, and source binding. Set `is_source_required=true` for evidence-bound text and require `evidence_source_path`; generated context must never impersonate this route.

Write immutable `visual_need_analysis@0.4.0` and `visual_coverage_ledger@0.1.0` revisions under `intermediate/contracts/revisions/`, project them into `intermediate/05-visual-plan.md`, and update both current pointers last.

Dispatch by disposition. Send only `generate_visual` to `image-prompt-compiler` and write `next_skill: image-prompt-compiler` for that subset; send source evidence to `news-evidence-pip`; deterministic/existing/manual tasks to their declared producer or waiting state. Continue without a routine human confirmation. Do not generate assets or alter the script.
