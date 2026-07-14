---
name: copywriting-draft-writer
description: Materialize a user-supplied Chinese talking-head draft without semantic edits, generate a new script from a selected structure plan, or create an authorized revision. Use only after the current Brief and the mode-specific source contract are complete.
---

# Copywriting Draft Writer

## Contract

```yaml
contract_version: 0.3.0
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
output: draft@0.3.0
modes: materialize_user_baseline | generated | revision
```

## Choose Exactly One Mode

### materialize_user_baseline

Use only for `user_supplied_draft`. Preserve the original meaning and expression. Allow deterministic LF normalization and metadata wrapping only. Store both original and normalized digests; the normalized draft body digest must equal the normalized original body digest. Set revision 1. Do not polish, reorder, strengthen, weaken, or fix claims.

Route the baseline to `content-beat-mapper(semantic_only)`.

### generated

Use only for `hotspot_selected_topic` after a current `design_before_draft` structure plan is ready. Implement every required stage, the Brief promise, account voice, and evidence boundary. Hook and density scores may be diagnostic but cannot independently pass or block the draft.

Route to `content-beat-mapper(structure_bound)`.

### revision

Require a current draft, selected structure, review issues, and a decision/authorization whose scope covers every semantic change. Make the smallest authorized change. Never overwrite an earlier revision.

Route to `content-beat-mapper(structure_bound)` and rebuild downstream review/visual bindings.

## Write

Write the immutable machine revision under:

`intermediate/contracts/revisions/draft/{draft_id}.json`

Project it for humans to `intermediate/04-draft.md`. Validate ID, revision, source identity, normalized digest, mode, authorization scope, and selected structure binding. Update the draft current pointer last.

Do not choose a new topic, invent evidence, plan visuals, run provider calls, or claim the script is ready before `spoken-script-review` derives readiness.
