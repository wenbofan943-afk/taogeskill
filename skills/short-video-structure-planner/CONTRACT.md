# Short Video Structure Planner Contract

```yaml
skill_id: short-video-structure-planner
contract_version: 0.1.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
producer: short-video-structure-planner
output: short_video_structure_plan@0.1.0
schema: templates/schema/r6/short-video-structure-plan.v0.1.schema.json
strategy_registry: routes/content-structure-strategies.yaml@0.1.0
revision_path: intermediate/contracts/revisions/short_video_structure_plan/{structure_plan_id}.json
current_pointer: intermediate/contracts/short-video-structure-plan.current.json
```

## Inputs and routes

| Mode | Required input | Pass route |
|---|---|---|
| `design_before_draft` | passed hotspot Brief + account snapshot | `copywriting-draft-writer` |
| `diagnose_existing_draft` | direct baseline draft + semantic-only beat map + intake policy | `content-beat-mapper(structure_bound)` |

Candidate and stage counts are content-derived 1..N with no product upper bound. Direct-content candidates always include `keep_current`. A human wait is `pending_selection`; only missing/invalid input, registry, authorization integrity, or lineage is `blocked`.

The revision file is immutable. The current pointer is the physical commit marker and must be written last. A pointer or source digest mismatch makes consumers stale.
