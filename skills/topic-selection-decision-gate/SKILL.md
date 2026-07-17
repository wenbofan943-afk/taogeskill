---
name: topic-selection-decision-gate
description: "Interpret an explicit user reply to the current hotspot topic-selection panel and produce exactly one typed topic_selection_decision. Use only when the current R7 node is topic_human_gate; never rerank candidates, alter the panel, conduct new research, or create the selected topic source."
---

# Topic Selection Decision Gate

## Purpose

Convert the user's explicit choice on the current topic panel into one versioned
`topic_selection_decision`. This Skill is an internal human gate, not a user entry
router and not a topic recommender.

## Preconditions

Proceed only when all are true:

1. The current task envelope names `topic_human_gate`.
2. The bound `topic_selection_panel` is current and materialized.
3. The task binds action registry v0.3.
4. The user's reply is explicit enough to select one visible action and, when
   required, one visible candidate.

If the reply is ambiguous, return `waiting_human` and ask only for the missing
choice. Do not infer a candidate from ranking, tone, or prior conversation.

## Decision procedure

1. Read only the current task envelope, bound panel, action registry, and typed
   user reply.
2. Match the reply to exactly one allowed action:
   `select_topic`, `rerun_hotspot_research`, `broaden_hotspot_scope`,
   `attach_manual_hotspot_source`, `branch_selected_topics`, or
   `archive_session`.
3. For `select_topic`, bind exactly one candidate that is visible in the current
   panel. Preserve its identifier; do not rewrite or re-rank it.
4. Produce a payload conforming to
   `taoge://schemas/r7/topic-selection-decision/v0.1`.
5. Submit the semantic payload to the deterministic recorder. The recorder owns
   validation, revision storage, current-pointer replacement, lineage, event,
   projection, and resume state.

## Boundaries

- Do not modify the topic panel or research set.
- Do not perform research or create `selected_topic_source`.
- Do not choose for the user.
- Do not write current pointers, events, lineage, or projections.
- Do not continue into the next workflow node.

## Result

Return the typed decision submission reference and one status:
`decision_committed`, `waiting_human`, or `blocked`.
