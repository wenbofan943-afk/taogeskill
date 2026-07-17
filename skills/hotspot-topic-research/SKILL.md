---
name: hotspot-topic-research
description: Use when a current R7 hotspot research request is ready and Codex must discover, verify, merge, rank, and submit one typed hotspot research set without rendering the selection panel or writing content.
---

# Hotspot Topic Research

## Current identity

Use this Skill only when the current task envelope belongs to
`hotspot_to_delivery_single_v0.5` and the bound node is `hotspot_research`.

```yaml
skill_contract_version: "0.3.0"
runtime_contract: "r7-hotspot-entry-v0.5+r5-radar-objects-v0.1"
required_input:
  artifact_type: "hotspot_research_request"
  schema: "templates/schema/r7/hotspot-research-request.v0.1.schema.json"
  status: "ready"
single_output:
  artifact_type: "hotspot_research_set"
  schema: "templates/schema/r7/hotspot-research-set.v0.1.schema.json"
current_node: "hotspot_research"
downstream_node: "topic_panel_projection"
```

The current request is the only source of account identity, account snapshot,
radar policy, requested time, research mode, scope delta, prior artifacts, and
manual-source references. Never reconstruct these values from chat.

## Conditional reading

Read only the references whose machine-evaluable condition matches the current
task. All references are one level below this entry.

| Reference | Load when | Owns |
|---|---|---|
| [source-and-query-strategy](./references/source-and-query-strategy.md) | `node_id == hotspot_research && mode in initial,same_policy_rerun,broaden_within_account_policy,manual_source_refresh,revalidation_after_reversal` | source pools, query expansion, direct used-car priority, spillover proof |
| [event-and-trend-model](./references/event-and-trend-model.md) | `node_id == hotspot_research && status in event_merge_required,trend_comparison_required` | signal/event/candidate/topic-option boundaries, event merge, comparable snapshots |
| [evidence-risk-scoring](./references/evidence-risk-scoring.md) | `node_id == hotspot_research && status in candidate_scoring_required,risk_review_required` | fact, propagation, risk, evidence sufficiency, ranking and expression limits |

Do not load [legacy-r1-r5-standalone](./references/legacy-r1-r5-standalone.md)
for current work. Load it only when the versioned task or session says
`contract_version in r1,r5 && mode in legacy,replay`. Never infer legacy mode
from chat wording.

## Current workflow

1. Resolve the current task and request through the registered selector. Reject
   a missing, non-current, non-ready, schema-invalid, or hash-mismatched request.
2. Read the request-bound account identity, account snapshot, and radar policy.
   Do not create or repair account data here.
3. Load the source/query reference. Load event/trend or evidence/risk guidance
   only when the current task reaches the corresponding status.
4. Discover source observations and preserve source URL, publication time,
   retrieval time, source type, support basis, and query provenance.
5. Materialize stable `signal -> event -> candidate -> topic_option` objects.
   Merge reports of one event; do not turn duplicate headlines into topics.
6. Keep fact status, propagation status, risk level, claim evidence, source
   independence, support basis, and allowed expression separate.
7. Rank only within the request-bound account policy. Preserve the R5 direct
   used-car priority and any required new-car spillover proof.
8. Build exactly one complete `hotspot_research_set`. Preserve component IDs,
   component digests, evidence packets, source records, ledger references, and
   the already-computed `panel_model` order and recommendation.
9. Submit the typed set to the coordinator. The deterministic panel projector,
   not this Skill, produces the human-facing panel.

## Result and commit semantics

Semantic result statuses:

```text
research_ready_for_panel
research_ready_no_recommendation
waiting_external
blocked
```

- `research_ready_for_panel` commits a set with at least one selectable topic
  and `research_set_status=ready_for_panel`.
- A complete search with zero selectable topics commits a set with
  `research_set_status=ready_no_recommendation`.
- `waiting_external` does not commit a partial current set. Preserve the current
  task and resumable external evidence.
- `blocked` does not fabricate missing request data, source evidence, digests,
  trend claims, or topic options.

After an interruption, first reconcile current request, pending task,
submission, attempts, and existing source outcomes. Resume the same task when
its dependencies and request revision are unchanged. A material scope change
requires a new request revision; do not silently widen the old request.

## Hard business invariants

- Direct, fact-verifiable used-car candidates are the hard priority.
- Enable new-car spillover only when the verified direct pool has fewer than
  three candidates, and require configured used-car transmission proof for
  every spillover candidate.
- Query expansion may explore freely inside account exclusions. Selection
  feedback changes assist counts and preference weights; it does not require
  per-term approval or prove single-term causality.
- Trend labels `rising`, `sustained`, and `cooling` require at least two
  same-scope, comparable snapshots. A single snapshot is `new_observation`.
- A user selecting a high-risk topic never upgrades an unsupported claim.
  `assert_as_fact` remains evidence- and risk-gated.

## Forbidden ownership

This Skill must not:

```text
create or migrate an account profile
rebuild radar scope from chat
render or mutate topic_selection_panel
record topic_selection_decision
produce selected_topic_source
write content_brief, a draft, visual assets, platform packages, or final HTML
publish or log in to a platform
commit more than one current output artifact type
```

The long Markdown panel/topic-card template is a legacy asset and is not a
current output contract. Current fields come from the request/set Schemas,
runtime validators, node registry, and submission contract.

## Machine truth and verification

Use these sources instead of copying their field lists:

```text
templates/schema/r7/hotspot-research-request.v0.1.schema.json
templates/schema/r7/hotspot-research-set.v0.1.schema.json
routes/r7-node-registry.yaml
routes/r7-semantic-task-registry.yaml
routes/r7-semantic-submission-registry.yaml
交接物字段词典.md
```

Before reporting completion, verify:

```text
current request ref and all bound digests match
one complete research set validates
component_digest_map matches referenced topic options
panel_model order and recommendation reference current components
result status maps to the correct commit/no-commit behavior
next owner is the deterministic panel projector
no forbidden artifact was submitted
```
