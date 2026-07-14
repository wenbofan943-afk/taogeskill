---
name: content-brief-compiler
description: Compile a selected hotspot topic or validated user-supplied draft into the current content Brief for the Taoge workflow. Use to lock source identity, audience, promise, evidence, account voice, product boundary, forbidden claims, and downstream route before structure or draft work.
---

# Content Brief Compiler

## Contract

```yaml
contract_version: 0.3.0
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
input: topic_card | direct_content_card
output: content_brief
```

Read the current source object, account snapshot, product/campaign boundary, session manifest, and relevant source records. Never reconstruct source facts from chat memory.

Compile the content origin, source IDs, target audience, audience entry/exit state, core promise, core point, material inventory, evidence availability, account voice constraints, platform context, depth reasoning, risks, forbidden claims, and CTA. Preserve source-specific identity:

- hotspot: require selected topic, research run, event/topic binding, facts, derivation chain, and risk boundaries.
- direct: require original artifact/digest, revision policy, claim map, and account binding; never invent topic or research IDs.

Write `accounts/{account}/runs/{session_id}/intermediate/03-content-brief.md`. `brief_pass` requires every downstream structure input to be present and traceable.

Route by origin:

- `hotspot_selected_topic` → `short-video-structure-planner(design_before_draft)`.
- `user_supplied_draft` → `copywriting-draft-writer(materialize_user_baseline)`.

Do not write the script, choose visual count, generate images, or add an approval gate after a complete Brief.
