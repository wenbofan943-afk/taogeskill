# Branch Summary

> parent_session_id: SR2DR-PARENT  
> branch_request_id: BR-SR2DR-001  
> fan_in_status: fan_in_ready  
> sample_only: yes

---

## Child Runs

| child_session_id | content_run_id | topic_id | run_status | final_delivery_path | blocked_reason |
|---|---|---|---|---|---|
| SR2DR-001 | CR-SR2DR-001 | T-SAMPLE-001 | run_completed | children/SR2DR-001/deliverables/final-delivery-placeholder.md | |
| SR2DR-002 | CR-SR2DR-002 | T-SAMPLE-002 | run_blocked | | topic_card_incomplete |
| SR2DR-003 | CR-SR2DR-003 | T-SAMPLE-003 | run_planned | | |

## Counts

```yaml
child_count: 3
completed_count: 1
blocked_count: 1
archived_count: 0
planned_count: 1
```

## Fan-in Rule

```text
This summary only references child outputs.
It must not merge child scripts, visuals, reviews, or final delivery pages.
```

## Recommended Next Action

```text
Review SR2DR-002 blocked reason, then decide whether to fix T-SAMPLE-002 or keep fan-in as partial.
```
