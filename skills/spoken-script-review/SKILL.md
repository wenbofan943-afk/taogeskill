---
name: spoken-script-review
description: Review the current Chinese talking-head script against its selected structure and structure-bound beat map before visual production. Use to produce a read-only issue report and a separate append-only revision decision; never use a single score as the pass gate.
---

# Spoken Script Review

## Read

Read the current draft, selected structure plan, structure-bound beat map, Brief, account snapshot, evidence bindings, and platform context. Require all IDs, revisions, and digests to match their current pointers.

## Review

Review audience value, structure implementation, progression, evidence placement, information release, spoken naturalness, emotion/stance, promise payoff, account voice, and visual handoff. Bind every issue to exact beats and explain viewer loss, recommended action, semantic impact, and gate:

- `advisory`: may continue only when the current-revision decision explicitly accepts it.
- `authorization_required`: wait for current-revision authorization before semantic change.
- `hard_boundary`: do not continue while unresolved.

Do not predict completion rate, virality, or guaranteed retention without real outcome data. Scores may be diagnostic signals only.

Write `script_design_review` as an immutable, read-only observation. Record user/system choice separately in append-only `content_revision_decision`; never edit the review to make it pass.

## Derive Readiness

- current `pass` + `accept_current` → `ready`.
- only accepted advisory issues remain → `ready_with_warnings`.
- authorization-required issue without matching authorization → `waiting_authorization`.
- revision chosen or review requires repair → `needs_revision`.
- hard boundary, broken required input, or lineage defect → `blocked`.
- any referenced current digest changed → `stale`.

Only `ready` and `ready_with_warnings` may enter visual coverage.

## Write

Write immutable revisions and their pointers last:

- `intermediate/contracts/revisions/script_design_review/{script_design_review_id}.json`
- `intermediate/contracts/script-design-review.current.json`
- `intermediate/contracts/revisions/content_revision_decision/{content_revision_decision_id}.json`
- `intermediate/contracts/content-revision-decision.current.json`

Validate against the matching R6 v0.1 schemas. Update the execution trace without altering draft or visual artifacts.

## Route

- ready / ready_with_warnings → `talking-head-image-pip` → `static-visual-director`.
- needs revision → `copywriting-draft-writer` in revision mode, then rebuild structure-bound beats.
- waiting authorization → preserve current artifacts and ask only for the unresolved decision.

Do not generate images, edit the draft silently, or write final delivery.
