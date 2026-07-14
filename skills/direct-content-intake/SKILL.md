---
name: direct-content-intake
description: Register a user-supplied Chinese script as a traceable first-class content input, preserve its voice and revision boundary, classify key claims, and route it into the complete Taoge content workflow without fabricating hotspot research. Use when the user provides their own draft and asks to deliver, polish, enrich with evidence, or intentionally send it to the radar.
---

# Direct Content Intake

## Role

Turn a user-supplied draft into `direct_content_intake` and `direct_content_card`. Skip hotspot discovery only when the selected intent permits it; never skip account binding, Brief, claim handling, visual analysis, quality review, platform packaging, cover, final delivery, trace, or finalize.

Use the compiled R6-B01 chain after intake: materialize the user's baseline without silent rewriting, then bind structure, content beats, spoken-script review, revision decision, visual coverage, and script-visual alignment under their current contracts.

## Read First

1. Read the session manifest, account startup result, frozen account snapshot, and account identity binding.
2. Read `docs/product/R6-直供文案与新闻证据画中画.md` and `交接物字段词典.md` only at the R6 sections.
3. Read `skills/content-brief-compiler/SKILL.md` before handing off.
4. Use `templates/schema/r6/direct-content-intake.v0.1.schema.json` and `tools/invoke-r6-content-evidence.ps1` for deterministic validation.

## Preconditions

Require a session under `accounts/{account_slug}/runs/{session_id}/`, a passing account startup check, a frozen account snapshot, the literal user draft, and a stable draft digest. Never infer the account or draft from an earlier conversation.

## Select The Intent

Choose exactly one intent from the user's instruction:

```text
direct_delivery             make the supplied draft ready for the normal delivery chain
direct_polish               permit expression or structure improvements within the recorded policy
direct_evidence_enrichment  preserve the draft while checking selected factual claims
direct_to_radar             intentionally re-enter R5 discovery and topic selection
```

Do not run the radar for the first three intents. `direct_to_radar` is the only route to `hotspot-topic-research`.

## Preserve The Draft

Write the original text unchanged to `inputs/user-supplied-draft.md`. Record its artifact ID, SHA256, path, and character count in `inputs/00-direct-content-intake.json`.

Use `revision_policy=preserve_voice` by default. A structural rewrite that would change the thesis, audience, accusation strength, factual certainty, or call to action requires one human confirmation unless the user already granted `rewrite_allowed`. Necessary factual or compliance warnings do not silently grant rewrite permission.

## Build The Claim Map

Mark only material statements as `opinion`, `experience`, `factual_claim`, `quote`, `statistic`, or `prediction`. Set the initial evidence status honestly:

```text
opinion / experience / prediction -> not_required unless the wording contains a checkable fact
factual_claim / quote / statistic -> not_checked until evidence work actually runs
```

Do not convert forceful opinion into fact, and do not convert missing evidence into `refuted`.

## Produce And Validate

Write:

```text
inputs/00-direct-content-intake.json
inputs/user-supplied-draft.md
intermediate/01-direct-content-card.json
intermediate/00-execution-trace.md update
```

The card must preserve `intake_id`, `content_source_id`, `session_id`, account identity, original artifact ID/digest, intent, revision policy, content goal, audience, claim map, `content_origin=user_supplied_draft`, and `topic_origin=direct_user_input`.

Run:

```powershell
pwsh -NoProfile -File tools/invoke-r6-content-evidence.ps1 -Mode validate_direct_intake -InputPath <direct-content-card.json>
```

## Route

```text
direct_content_ready + direct_to_radar -> hotspot-topic-research
direct_content_ready + other intent    -> content-brief-compiler
needs_rewrite_confirmation             -> human_confirm
blocked                                -> repair the owning input; do not fabricate fields
```

For the normal direct route, `content_source_id` replaces the topic-card dependency. Do not create a fake `topic_id` or `source_research_run_id`.

## Completion

This skill completes when the validated card is physically committed, its digest and producer/consumer lineage are recorded, and `next_skill` is correct. It does not mean the content session is complete. `html_ready` also remains distinct from `session_completed`.

Keep real drafts and account runs in the private production area. Public source control may contain only redacted fixtures.
