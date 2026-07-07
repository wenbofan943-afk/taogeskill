# Branch Request Ledger

> parent_session_id: SR2DR-PARENT  
> branch_request_id: BR-SR2DR-001  
> mode: fan_out  
> sample_only: yes

---

```yaml
ledger_entry:
  entry_id: LEDGER-SR2DR-001
  branch_request_id: BR-SR2DR-001
  at: 2026-07-07T10:00:00+08:00
  actor_type: user
  action: branch_request_requested
  input:
    raw_user_reply: 三篇都做
    requested_items:
      - T-SAMPLE-001
      - T-SAMPLE-002
      - T-SAMPLE-003
  output:
    branch_request_status: branch_request_requested
  from_status: branch_request_none
  to_status: branch_request_requested
  affected_children: []
  note: User asked to run all three sample topics.
```

```yaml
ledger_entry:
  entry_id: LEDGER-SR2DR-002
  branch_request_id: BR-SR2DR-001
  at: 2026-07-07T10:02:00+08:00
  actor_type: skill
  action: fan_out_planned
  input:
    task_context_type: content_production
    source_artifact: sample_topic_pool
  output:
    branch_request_status: branch_request_confirmed
    fan_out_status: fan_out_planned
    planned_children:
      - SR2DR-001
      - SR2DR-002
      - SR2DR-003
  from_status: fan_out_none
  to_status: fan_out_planned
  affected_children:
    - SR2DR-001
    - SR2DR-002
    - SR2DR-003
  note: Parent only plans children; parent does not store child body text.
```

```yaml
ledger_entry:
  entry_id: LEDGER-SR2DR-003
  branch_request_id: BR-SR2DR-001
  at: 2026-07-07T10:05:00+08:00
  actor_type: skill
  action: child_completed
  input:
    child_session_id: SR2DR-001
  output:
    child_run_status: run_completed
    final_delivery_status: html_ready
  from_status: run_active
  to_status: run_completed
  affected_children:
    - SR2DR-001
  note: Completed child writes final checkpoint and releases run_lock.
```

```yaml
ledger_entry:
  entry_id: LEDGER-SR2DR-004
  branch_request_id: BR-SR2DR-001
  at: 2026-07-07T10:06:00+08:00
  actor_type: skill
  action: child_blocked
  input:
    child_session_id: SR2DR-002
  output:
    child_run_status: run_blocked
    blocked_reason: topic_card_incomplete
  from_status: run_planned
  to_status: run_blocked
  affected_children:
    - SR2DR-002
  note: T-SAMPLE-002 is blocked without affecting other children.
```

```yaml
ledger_entry:
  entry_id: LEDGER-SR2DR-005
  branch_request_id: BR-SR2DR-001
  at: 2026-07-07T10:08:00+08:00
  actor_type: skill
  action: fan_in_ready
  input:
    child_manifests:
      - children/SR2DR-001/manifest.yaml
      - children/SR2DR-002/manifest.yaml
      - children/SR2DR-003/manifest.yaml
  output:
    fan_in_status: fan_in_ready
    branch_summary: parent/intermediate/branch-summary.md
  from_status: fan_in_none
  to_status: fan_in_ready
  affected_children:
    - SR2DR-001
    - SR2DR-002
    - SR2DR-003
  note: Fan-in summarizes only; it does not merge child body text.
```
