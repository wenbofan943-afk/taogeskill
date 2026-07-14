# Content Beat Mapper Contract

```yaml
skill_id: content-beat-mapper
contract_version: 0.1.0
contract_status: confirmed
contract_set_version: r6-script-structure-v0.1+r3-visual-coverage-v0.4+p0-delivery-v0.5
producer: content-beat-mapper
output: content_beat_map@0.1.0
schema: templates/schema/r6/content-beat-map.v0.1.schema.json
revision_path: intermediate/contracts/revisions/content_beat_map/{beat_map_id}.json
current_pointer: intermediate/contracts/content-beat-map.current.json
anchor_unit: utf8_byte
anchor_interval: half_open
```

`semantic_only` is a temporary direct-draft diagnostic and cannot enter R3. `structure_bound` requires full non-whitespace coverage and exactly one valid stage per beat. Draft or structure semantic changes make the affected current map stale; recovery creates a new immutable revision and updates the pointer last.
