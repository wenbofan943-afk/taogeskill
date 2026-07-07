# Checkpoint

```yaml
checkpoint_id: CKPT-SR2DR-002-blocked-topic-card-20260707-001
session_id: SR2DR-002
content_run_id: CR-SR2DR-002
stage: topic_card
checkpoint_reason: error_before_retry
input_artifacts:
  - sample_topic_pool#T-SAMPLE-002
output_artifacts:
  - children/SR2DR-002/intermediate/checkpoints/latest.md
last_completed_stage: child_session_created
current_stage: topic_card
failed_stage: topic_card
resume_from: sample_topic_pool#T-SAMPLE-002
resume_action: manual_fix_required
state_transition_id: ST-SR2DR-002-001
created_at: 2026-07-07T10:06:00+08:00
```

## Resume Hint

```text
Fix missing topic_card fields before content-brief-compiler.
Do not recreate SR2DR-002 unless parent ledger is also repaired.
```
