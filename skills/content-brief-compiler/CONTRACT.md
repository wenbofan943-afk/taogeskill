# Content Brief Compiler Contract

```yaml
skill_id: content-brief-compiler
contract_version: 0.3.0
contract_status: confirmed
contract_set_version: r6-content-brief-v0.4+r6-script-structure-v0.1+r7-hotspot-entry-v0.2
output: content_brief@0.3.0
target_path: intermediate/03-content-brief.md
```

| Origin | Required source identity | Pass route |
|---|---|---|
| `hotspot_selected_topic` | topic + event/research lineage | `short-video-structure-planner(design_before_draft)` |

R7 hotspot contract:

- Schema: `templates/schema/r6/content-brief.v0.4.schema.json`.
- The only content source is the current `selected_topic_source` with `selected_source_status=ready_for_brief`.
- `content_source_id` equals `selected_topic_source_id`; `selected_topic_source_ref` and `selected_topic_content_semantic_digest` are conditionally required.
- `original_draft_ref` is null and `next_skill=short-video-structure-planner`.
- Reading a panel, topic option, event, candidate, research report, or `ready_for_delivery` source directly is a contract failure.
| `user_supplied_draft` | original artifact/digest + revision policy + claim map | `copywriting-draft-writer(materialize_user_baseline)` |

The Brief locks audience entry/exit state, promise, point, material/evidence inventory, account voice, platform context, depth reasoning, product/claim boundary, risks, and CTA. Missing traceability returns to the owning upstream producer; it is never guessed in this skill.
