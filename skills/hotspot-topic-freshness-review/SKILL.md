---
name: hotspot-topic-freshness-review
description: "Revalidate one selected hotspot immediately before delivery. Use only at the R7 delivery_topic_freshness_review node to classify monitoring-only refresh, material fact change, reversal/identity change, or an unassessed external wait without reranking the topic."
---

# Hotspot Topic Freshness Review

## Purpose

Recheck the current selected hotspot at the delivery boundary and produce one typed review. This Skill reads sources; it never updates the selected source, plan, candidate, or HTML itself.

For current `hotspot_to_delivery_single_v0.5` / plan v1.2, an unassessed read remains on the same task. Deterministic apply owns monitoring-only continuation, Brief restart for material updates, and a new revalidation request plus research restart for reversal or identity change.

## Procedure

1. Read the current `selected_topic_source` and its `freshness_policy` from the task bindings.
2. Persist each source read/capture attempt before interpreting the result. Reconcile an `outcome_unknown` attempt before any retry.
3. Compare the current evidence with the selected source and choose exactly one `change_class`:
   - `no_material_change`: no source-record delta and no semantic change.
   - `observation_refresh`: source observations changed, but the content semantic digest must remain unchanged.
   - `material_fact_update`: same topic identity, semantic evidence changed, and a complete replacement evidence packet is supplied.
   - `topic_reversal_or_identity_change`: the topic identity changed or a relied-on fact reversed; supply a complete replacement evidence packet.
4. If the read cannot be assessed, return `waiting_external` or `blocked` with `change_class=not_assessed`, `topic_identity_status=not_assessed`, and no current review artifact.
5. Submit one `topic_freshness_review` v0.1. Deterministic apply owns selected-source revision and any replan.

## Hard boundaries

- Do not rerank candidates or select a different topic.
- Do not turn propagation, risk, screenshots, or source availability into a fact verdict.
- Do not use a partial replacement packet for a material change or reversal.
- Do not change the semantic digest for `no_material_change` or `observation_refresh`.
- Do not call an external source twice after an unknown outcome; reconcile first.

## Result

Report the review ID, checked time, source attempt refs, change class, identity status, replacement packet digest when required, and the allowed result status: `review_complete`, `waiting_external`, or `blocked`.
