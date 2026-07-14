# Copywriting Draft Writer Contract

```yaml
skill_id: copywriting-draft-writer
contract_version: 0.3.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
output: draft@0.3.0
revision_path: intermediate/contracts/revisions/draft/{draft_id}.json
human_projection: intermediate/04-draft.md
```

| Mode | Required input | Pass route |
|---|---|---|
| `materialize_user_baseline` | direct original artifact/digest + Brief | `content-beat-mapper(semantic_only)` |
| `generated` | hotspot Brief + current selected structure | `content-beat-mapper(structure_bound)` |
| `revision` | current draft + structure + review + scoped decision/authorization | `content-beat-mapper(structure_bound)` |

The baseline permits only deterministic line-ending normalization and metadata wrapping. Generated/revision modes preserve all source and authorization lineage. A single Hook, density, or virality score is never the pass gate; `spoken-script-review` owns script readiness.
