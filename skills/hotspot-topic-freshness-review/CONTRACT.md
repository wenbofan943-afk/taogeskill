# Hotspot Topic Freshness Review Contract

```yaml
contract_id: topic-freshness-review
contract_version: 0.1
compile_batch: R7-L3-H4
route_contract: hotspot_to_delivery_single_v0.5+session-execution-plan-v1.2+semantic-task-envelope-v0.6
input: current_selected_topic_source
output: topic_freshness_review
schema: taoge://schemas/r7/topic-freshness-review/v0.1
success_status: review_complete
waiting_status: waiting_external
failure_status: blocked
```

`complete` requires at least one persisted source attempt and an assessed change/identity class. Material update or reversal requires a complete replacement evidence packet whose canonical digest equals both `replacement_evidence_packet_digest` and its `component_digest_map` entry. Waiting/blocked produces no current artifact and cannot enter candidate compilation.
