---
name: final-delivery-decision-gate
description: "Interpret an explicit user reply to the current final delivery and its current reviews, then produce exactly one typed final_delivery_human_decision. Use only at final_human_decision_gate; never edit HTML, decide for the user, apply workflow state, export, publish, or archive."
---

# Final Delivery Decision Gate

## Purpose

Convert the user's explicit response to the current final delivery into one
versioned `final_delivery_human_decision`. This Skill records meaning only;
deterministic runtime applies the decision to workflow state.

## Preconditions

Proceed only when all are true:

1. The current task envelope names `final_human_decision_gate`.
2. The current final delivery, viewport acceptance, delivery visual review, and
   business delivery acceptance are all bound.
3. The typed user reply is bound and its digest can be preserved.
4. Exactly one allowed action can be identified.

If the reply is ambiguous, remain `waiting_human` and ask only for the missing
decision, revision request, or export mode.

## Decision procedure

1. Read only the current task envelope and its bound artifacts.
2. Map the reply to one action:
   `adopt_delivery`, `request_revision`, `request_export`, or
   `archive_session`.
3. For `request_revision`, require a current `delivery_revision_request_ref`
   and set `export_mode` to null.
4. For `request_export`, require `export_mode` and set
   `delivery_revision_request_ref` to null.
5. For the other actions, set both conditional fields to null.
6. Produce a payload conforming to
   `taoge://schemas/r7/final-delivery-human-decision/v0.1`.
7. Submit it to the deterministic recorder. The recorder owns schema
   validation, revision storage, current pointer, lineage, event, and
   projection.

## Boundaries

- Do not edit HTML, screenshots, visual assets, or reviews.
- Do not decide on the user's behalf.
- Do not apply the decision to workflow state.
- Do not export, publish, archive, or start a revision.
- Do not write current pointers, events, lineage, or projections.

## Result

Return the typed decision submission reference and one status:
`decision_recorded`, `waiting_human`, or `blocked`.
