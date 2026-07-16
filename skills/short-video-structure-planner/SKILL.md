---
name: short-video-structure-planner
description: Plan or diagnose the macro structure of a Chinese short-video talking-head script. Use after a hotspot Brief passes and before drafting, or after a user-supplied baseline draft has a semantic-only beat map. Produces versioned structure candidates and a selected current plan without forcing a fixed template or duration.
---

# Short Video Structure Planner

## Read

1. Read the current Brief, account snapshot, platform context, and `routes/content-structure-strategies.yaml`.
2. For `diagnose_existing_draft`, also read the current baseline draft and `semantic_only` beat map.
3. Read `docs/product/R6-口播脚本与视觉协同编排.md` only when a field or recovery rule is unclear.

## Choose the Mode

- Use `design_before_draft` only for `hotspot_selected_topic`. Do not bind a draft or beat map.
- In current R7 hotspot v0.5, consume the current hotspot Brief plus current selected topic source only. `content_source_id` remains the selected source ID, and `source_draft_ref` / `source_beat_map_ref` must both be null; a future draft or beat map is a hard `future_artifact_reference` failure.
- Use `diagnose_existing_draft` for every `user_supplied_draft`. Require the current draft and semantic-only beat map.
- Reject unregistered origins. Do not silently reinterpret them.

## Build the Plan

Derive 1..N candidates from audience entry/exit state, core promise, material, evidence, account voice, platform context, and depth reasoning. Use the strategy registry; use `custom` only when registered strategies do not fit and record why.

For direct content, always include `keep_current`. Do not select a semantic change that exceeds the intake revision policy without current-revision authorization. Waiting for a choice is `selection_status=waiting_human` and `plan_status=pending_selection`, not a workflow failure.

For a selected plan, create 1..N stages with contiguous order beginning at 1. Every stage must state its function, audience transition, content obligation, evidence requirement, transition contract, and necessity. Do not force a Hook, three acts, CTA, stage count, word count, or duration.

## Write

Write an immutable revision to:

`accounts/{account}/runs/{session_id}/intermediate/contracts/revisions/short_video_structure_plan/{structure_plan_id}.json`

Validate it against `templates/schema/r6/short-video-structure-plan.v0.1.schema.json`. Only after the revision is durable, update:

`accounts/{account}/runs/{session_id}/intermediate/contracts/short-video-structure-plan.current.json`

The pointer must conform to `content-analysis-current-pointer.v0.1` and bind the revision path and SHA-256.

## Route

- `design_before_draft` ready → `copywriting-draft-writer`.
- `diagnose_existing_draft` ready → `content-beat-mapper` in `structure_bound` mode.
- `pending_selection` → wait for the smallest missing authorization; preserve all candidates.
- Broken registry, lineage, or required input → block and return to the producer that owns it.

Never write the draft, beat map, visual plan, or final HTML.
