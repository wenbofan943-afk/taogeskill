---
name: propagation-router
description: "Route a user request to exactly one legal next node in the Taoge content workflow. Use when the user says to use Taoge Skill, start, resume, continue, or asks for the next step. Read current state and artifacts; never create business content, run checkers, interpret human choices, or commit workflow decisions."
---

# Propagation Router

## Role

This is the sole conversational entry for “用涛哥 Skill”, “开始”, “接着上次”,
and “下一步”. It performs navigation only.

## Routing procedure

1. Resolve the project root and read the current workflow state.
2. Identify one intent: new start, resume, or next action.
3. Read only the current artifact and the active version-pinned plan needed to
   determine legality.
4. Select exactly one legal next node or one human gate.
5. Return `router_decision`, `next_skill`, a concise reason, and any visible
   human prompt. Do not execute the selected node.

For an interrupted session, abnormal current pointer, or resume request, read
`references/resume-and-recovery.md`. For an explicitly version-pinned R1/R2
replay, read `references/legacy-r1-r2-routing.md`.

## Ownership boundaries

The router may:

- identify start, resume, and next-action intent;
- read workflow state, the active plan, and the current artifact;
- choose one registered legal next node;
- explain a missing prerequisite without manufacturing it.

The router must not:

- write Briefs, scripts, visual plans, reviews, or delivery artifacts;
- run a checker, renderer, provider, exporter, or publisher;
- interpret the user's topic or final-delivery choice;
- produce `topic_selection_decision` or `final_delivery_human_decision`;
- mutate a panel, workflow session record, pointer, lineage, event, or
  projection;
- route engineering work that belongs to project `AGENTS.md`.

Internal human gates own explicit choices:

- `topic_human_gate` -> `$topic-selection-decision-gate`
- `final_human_decision_gate` -> `$final-delivery-decision-gate`

Account startup and missing-account-field interaction remain owned by the
registered account startup coordinator.

## Output

Return only the smallest useful navigation result:

```yaml
router_decision:
  intent: start | resume | next_action
  current_session_ref: string | null
  current_node_id: string | null
  next_node_id: string
  next_skill: string
  reason: string
  human_prompt: string | null
  decision_status: routed | waiting_prerequisite | blocked
```

Never claim the next Skill has run merely because it was selected.
