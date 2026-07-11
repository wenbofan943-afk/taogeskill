---
name: static-visual-director
description: Analyze an approved Chinese talking-head draft beat by beat, prove which picture-in-picture interventions are genuinely needed, and compile every accepted need into traceable visual and visual-text tasks. Use internally before image prompts are written; image count is content-derived from 0 to N with no cap.
---

# Static Visual Director

## Position

Act as an internal producer behind `talking-head-image-pip`. Do not present this as a second user workflow and do not ask the user to continue.

Read, in order:

1. `交接物字段词典.md` sections `static_visual_director_plan`, `visual_need_analysis`, `visual_plan`, and `visual_text_plan`.
2. `docs/reference/R3-图片资产执行规范.md`, searching for `content_derived_unbounded`, `visual_need_analysis`, and `visual_text_tasks`.
3. The current session draft, brief, manifest, and available source records.

## Atomic Planning Transaction

Write these four sections into `intermediate/05-visual-plan.md` in one transaction:

```text
static_visual_director_plan
visual_need_analysis
visual_plan.accepted_visual_tasks[] / rejected_visual_candidates[]
visual_text_plan.visual_text_tasks[]
```

Reserve all IDs before filling content. Every accepted `image_task_id` must have exactly one `visual_text_task`. If any section fails, preserve the draft and trace but mark the planning bundle not pass.

## Visual Need Analysis

Read the account audience, prior knowledge, platform viewing context, brief, and draft. Split the script into semantic/event beats; never derive image count from duration.

For every candidate, record:

```text
viewer_problem_without_visual
primary_visual_job + supporting_visual_jobs
expected_viewer_change
information_added
why_image_is_better_than_talking_head
attention / comprehension risk
emotion congruence, evidence binding, redundancy, cognitive load, misleading risk
visual_need_decision: generate / reject
```

Allowed jobs are `attention_reset`, `hook_amplification`, `concept_explanation`, `evidence_support`, `process_demonstration`, `emotion_amplification`, and `memory_anchor`.

The policy is `content_derived_unbounded`: 0 to N, no minimum, no maximum. `attention_reset` requires a specific content risk, not elapsed time. Emotion must align with the event; evidence must be source-bound. Reject decorative, repetitive, overloaded, misleading, or unprovable candidates.

Every `generate` candidate becomes exactly one `accepted_visual_task` with `generation_intent=render_now` and `provider_route=codex_builtin_image2`. There is no optional-by-cost state. If the count is zero, write a concrete `zero_visual_reason`.

For every passing analysis, write `accepted_task_dispatch_policy=auto_continue_all_accepted_without_human_confirmation`, `human_confirmation_required=false`, `generation_dispatch_status=ready_for_prompt_compile`, and `next_skill=image-prompt-compiler`. Do not stop for the user to approve task IDs, count, or aesthetic direction. If evidence, privacy, copyright, or claim risk is unresolved, reject the candidate or repair it locally before pass; never leave it accepted and waiting.

## Per-Image Decision

For every image task, choose exactly one:

```text
forbidden: the image communicates accurately without text; units must be empty.
optional: text adds a distinct second layer but the image remains understandable without it.
required: text is necessary to disambiguate roles, comparison, mechanism, evidence, data, or source.
```

Do not use one plan-level decision for multiple images.

Apply the role matrix:

| Visual role | Default | Visual text |
|---|---|---|
| emotion_amplifier / scene_context / memory_symbol / metaphor | forbidden or optional | inner_voice, subtext, context_marker |
| hook_conflict / comparison | optional or required | role_label, comparison_label, inner_voice |
| mechanism_explainer | required unless the relation is obvious | mechanism_label, visual_narration |
| evidence_support | required | source_native_text, data_point, evidence_label, source_note |

Generated scenes are not evidence. Downgrade them to scene, metaphor, or emotion roles unless a real source asset is bound.

## Three Tracks

Use `draft_script_text` as the narration source. A subtitle source is optional and must be marked `available / not_available / not_applicable` with an optional path.

Visual text must add `information_delta`; it must not merely repeat narration or subtitles.

## Text Budget

Use 1-3 text units per image by default. Allow up to four mechanism nodes and one extra source note for evidence. Follow the role budgets in the R3 reference. If exceeded, write `overflow_reason` and mark cognitive load for review.

## Evidence Binding

For every evidence, data, quote, screenshot, or factual label, write in the text unit:

```text
is_source_required: true
evidence_source_type
evidence_source_id
evidence_source_path
source_binding_status: source_bound
```

If the source cannot be resolved, use `source_missing` and block or downgrade the visual role. Never invent a source or turn a generated illustration into proof.

## Output Gate

Pass only when:

```text
visual_need_analysis passes and derived_visual_count equals accepted_visual_tasks length
every generate candidate maps to one accepted task; every reject candidate maps to none
all accepted image tasks map one-to-one to visual_text_tasks
forbidden tasks contain no text units
required tasks contain usable units
optional/required text has a specific information delta
source-required units have resolvable type, id, and path
all IDs, audience context, and source_research_run_id remain traceable
```

On pass, set `next_skill: image-prompt-compiler`. On needs-fix or blocked, keep recovery local unless the draft claim itself lacks support.

Always update `intermediate/00-execution-trace.md` with `skill_defined`, `agent_orchestrated`, `source_binding`, and any compatibility migration used.
