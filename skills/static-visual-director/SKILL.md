---
name: static-visual-director
description: Compile an approved Chinese talking-head draft into traceable static visual tasks and per-image visual-text decisions. Use internally after draft creation when taogeskill must decide picture-in-picture roles, no-text versus text-required behavior, evidence source binding, and visual task IDs before image prompts are written.
---

# Static Visual Director

## Position

Act as an internal producer behind `talking-head-image-pip`. Do not present this as a second user workflow and do not ask the user to continue.

Read, in order:

1. `交接物字段词典.md` sections `static_visual_director_plan`, `visual_plan`, and `visual_text_plan`.
2. `docs/reference/R3-图片资产执行规范.md`, searching for `C54-C70` and `visual_text_tasks`.
3. The current session draft, brief, manifest, and available source records.

## Atomic Planning Transaction

Write these three sections into `intermediate/05-visual-plan.md` in one transaction:

```text
static_visual_director_plan
visual_plan.required_visuals[] / optional_visuals[]
visual_text_plan.visual_text_tasks[]
```

Reserve all IDs before filling content. Every created `image_task_id` must have exactly one `visual_text_task`. If any section fails, preserve the draft and trace but mark the planning bundle not pass.

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
all image tasks map one-to-one to visual_text_tasks
forbidden tasks contain no text units
required tasks contain usable units
optional/required text has a specific information delta
source-required units have resolvable type, id, and path
all IDs and source_research_run_id remain traceable
```

On pass, set `next_skill: image-prompt-compiler`. On needs-fix or blocked, keep recovery local unless the draft claim itself lacks support.

Always update `intermediate/00-execution-trace.md` with `skill_defined`, `agent_orchestrated`, `source_binding`, and any compatibility migration used.
