---
name: content-beat-mapper
description: Map every non-whitespace byte of a Chinese talking-head draft into ordered semantic beats, then optionally bind every current beat to one selected structure stage. Use for direct-draft diagnosis before structure selection and for the shared script/visual pipeline after a structure plan is current.
---

# Content Beat Mapper

## Read

Read the current draft revision, its normalized body digest, account snapshot, target audience, and platform context. In `structure_bound` mode, also read the current selected structure plan.

## Map

Use UTF-8 byte offsets and half-open intervals `[start_byte,end_byte)`. Cover every non-whitespace byte exactly once, in source order. Do not overlap, omit, reorder, or normalize away semantic text.

For each beat record its source digest, semantic function, audience state change, information increment, dependencies, claims/evidence, stance, emotion function, and spoken intent.

- `semantic_only`: use only to diagnose a user-supplied baseline before structure selection; `stage_id` and structure reference are null.
- `structure_bound`: require the current selected structure plan and bind each beat to exactly one current stage. Only this phase may enter spoken review or visual planning.

Beat count is content-derived 1..N. A missing conventional role is not itself a failure.

## Write

Write the immutable revision to:

`accounts/{account}/runs/{session_id}/intermediate/contracts/revisions/content_beat_map/{beat_map_id}.json`

Validate with `templates/schema/r6/content-beat-map.v0.1.schema.json`, then write the current pointer last at:

`accounts/{account}/runs/{session_id}/intermediate/contracts/content-beat-map.current.json`

Set `mapping_status=ready` only when coverage is complete, unresolved ranges are empty, IDs are unique, orders are contiguous, and all structure-bound stage references exist.

## Route

- semantic-only ready → `short-video-structure-planner`.
- structure-bound ready → `spoken-script-review`.
- anchor or digest defect → create a repaired beat-map revision.
- stale draft/structure binding → stop; never carry old beats into visual planning.

Do not rewrite the script or decide visual production paths.
