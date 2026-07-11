---
name: talking-head-image-pip
description: Orchestrate static picture-in-picture planning, visual-text decisions, provider-ready prompts, image generation or honest fallback, and traceable image assets for approved Chinese talking-head scripts. Use when a user asks for 口播配图、画中画、静态视觉方案、用 Codex image 出图、非 Codex Seedream 提示词交付，或在 taogeskill 主链进入最终图片交付。
---

# Talking Head Image PIP

## Role

Act as the user-facing facade for the R3 static image chain. Keep the user in one workflow; do not expose internal skill choreography or ask them to say “继续生成提示词/图片”.

This skill does not write copy, perform final quality approval, package platforms, or compose cover finals.

## Read Progressively

1. Read the current `draft`, `content_brief`, manifest, and `交接物字段词典.md`.
2. Read `docs/reference/R3-图片资产执行规范.md` sections for the standard chain, C54-C70, provider route, and status rules.
3. Read internal skills only when entering their stage:
   - `skills/static-visual-director/SKILL.md`
   - `skills/image-prompt-compiler/SKILL.md`
   - `skills/image-asset-producer/SKILL.md`

Do not reload detailed prompt craft while only deciding visual tasks.

## Preconditions

Require:

```text
draft_status=draft_created
brief_id and draft_id
account and source_research_run_id
session root under accounts/{account_slug}/runs/{session_id}/
```

Never infer missing P0 identifiers from chat memory. Return to the owning upstream artifact if they are absent.

## Orchestration

Run the chain automatically:

```text
1. static-visual-director
   -> atomically write static_visual_director_plan, visual_plan tasks, visual_text_plan
2. image-prompt-compiler
   -> compile complete Codex / Seedream prompt cards
3. image-asset-producer
   -> detect environment, generate or downgrade, overlay approved PIP text, record immutable assets
4. copywriting-quality-review(content_visual_review + visual_text_quality_gate)
```

The physical planning source is always `intermediate/05-visual-plan.md`.

## Visual Budget

```text
under 30 seconds: 1 required + 1 optional
30-60 seconds: 2 required + 1-2 optional
60-90 seconds: 3 required + 1-2 optional
over 90 seconds: 3-4 required; additions need a retention reason
```

This table is a default envelope, not a fixed delivery count. Persist `default_required_min / max`, `default_optional_min / max`, `final_required_count`, `final_optional_count`, `selected_optional_count`, and any reduction or expansion reason. Covers are counted separately. Required and optional task counts must equal their arrays; provider calls are derived only from tasks explicitly selected with `generation_intent=render_now`.

Every image needs one primary retention task, an insert range, a visual role, an image task ID, and an honest production status.

## Visual Text Contract

Every planned image maps to one `visual_text_task`:

```text
forbidden -> no visual text units and no text in the prompt or image
optional -> text adds a distinct second layer
required -> text resolves role, comparison, mechanism, evidence, data, or source
```

Visual text is not subtitles. It may express inner voice, role position, mechanism, context, evidence, or subtext, but must add `information_delta`.

Generated scenes cannot serve as evidence. Evidence units require resolvable source type, ID, path, and `source_bound`.

## Environment Behavior

```text
Codex image capability available at final delivery -> generate required assets and place them under assets/images/.
Capability unavailable -> deliver complete Seedream-compatible prompts, exact text, placement, and human action.
Generation failure -> record generation_failed and recovery guidance.
```

Do not call external image APIs or ask the user to repeat account, topic, brief, or draft information.

## Status And Handoff

Output the standard handoff block:

```text
contract_set_version: r3-asset-runtime-v0.2
static_visual_director_plan_id
visual_plan_id
visual_text_plan_id
image_prompt_set_id
image_asset_set_id
required_count / optional_count
generated_count / pending_count / failed_count / rejected_count
image_assets_status
visual_text_plan_status
visual_text_quality_gate_status
artifact_path
next_skill: copywriting-quality-review
execution_trace_update
```

Pass only when planning IDs and task mappings are complete, prompt cards pass integrity, and every required asset is generated or honestly downgraded.

## Human Gates And Revision

Do not stop for routine image count, text/no-text decisions, provider fallback, or transition to quality review.

Stop only for unresolved high-risk evidence, privacy/copyright risk, or a user-owned aesthetic choice that materially changes the output. Give one recommended action and natural reply examples.

After final HTML, requests such as “再加一张画中画”, “这张不要字”, or “改成内心想法” are local R3 revisions. Preserve upstream topic, brief, and draft unless the requested meaning changes them.

Always update `intermediate/00-execution-trace.md` with internal skill stages, environment capability, generated files, fallbacks, and agent assistance.
