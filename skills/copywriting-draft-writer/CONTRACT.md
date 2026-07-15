# Copywriting Draft Writer Contract

```yaml
skill_id: copywriting-draft-writer
contract_version: 0.3.0
contract_status: confirmed
contract_set_version: r6-draft-v0.4+r6-script-structure-v0.1+r7-hotspot-entry-v0.2
output: draft@0.3.0
revision_path: intermediate/contracts/revisions/draft/{draft_id}.json
human_projection: intermediate/04-draft.md
```

| Mode | Required input | Pass route |
|---|---|---|
| `materialize_user_baseline` | direct original artifact/digest + Brief | `content-beat-mapper(semantic_only)` |
| `generated` | hotspot Brief + current selected structure | `content-beat-mapper(structure_bound)` |
| `revision` | current draft + structure + review + scoped decision/authorization | `content-beat-mapper(structure_bound)` |

R7 hotspot generated mode uses `templates/schema/r6/draft.v0.4.schema.json` and requires `content_origin=hotspot_selected_topic`, `draft_mode=generate_from_structure`, current Brief and structure refs, `content_source_id=selected_topic_source_id`, null original-draft fields, and `next_skill=content-beat-mapper`. Missing or future structure references fail before submission build.

The baseline permits only deterministic line-ending normalization and metadata wrapping. Generated/revision modes preserve all source and authorization lineage. A single Hook, density, or virality score is never the pass gate; `spoken-script-review` owns script readiness.
