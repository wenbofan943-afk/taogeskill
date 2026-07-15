---
name: content-brief-compiler
description: Compile a selected hotspot topic or validated user-supplied draft into the current content Brief for the Taoge workflow. Use to lock source identity, audience, promise, evidence, account voice, product boundary, forbidden claims, and downstream route before structure or draft work.
---

# Content Brief Compiler

## Contract

```yaml
contract_version: 0.3.0
contract_set_version: r6-content-brief-v0.4+r6-script-structure-v0.1+r7-hotspot-entry-v0.2
input: topic_card | direct_content_card
output: content_brief
```

Read the current source object, account snapshot, product/campaign boundary, session manifest, and relevant source records. Never reconstruct source facts from chat memory.

Compile the content origin, source IDs, target audience, audience entry/exit state, core promise, core point, material inventory, evidence availability, account voice constraints, platform context, depth reasoning, risks, forbidden claims, and CTA. Preserve source-specific identity:

- hotspot: consume only the current `selected_topic_source` whose status is `ready_for_brief`; do not read the panel, event, candidate, research Markdown, or directory order as an alternate source.
- direct: require original artifact/digest, revision policy, claim map, and account binding; never invent topic or research IDs.

Write `accounts/{account}/runs/{session_id}/intermediate/03-content-brief.md`. `brief_pass` requires every downstream structure input to be present and traceable.

Route by origin:

- `hotspot_selected_topic` → `short-video-structure-planner(design_before_draft)`.

For R7 hotspot tasks, output `templates/schema/r6/content-brief.v0.4.schema.json`. Set `content_origin=hotspot_selected_topic`, `content_source_id=selected_topic_source_id`, bind the exact current source revision/hash, copy `content_semantic_digest`, keep `original_draft_ref=null`, and set `next_skill=short-video-structure-planner`. A `ready_for_delivery` or `revalidation_required` source is not a valid Brief input.
- `user_supplied_draft` → `copywriting-draft-writer(materialize_user_baseline)`.

Do not write the script, choose visual count, generate images, or add an approval gate after a complete Brief.
