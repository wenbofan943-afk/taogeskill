# Gate Check Report

```yaml
check_run_id: GATE-20260711-141531
gates_checked: sample_only_gate
overall_result: pass
exit_code: 0
fail_count: 0
blocked_count: 0
```

| Check ID | Status | Evidence | Remediation |
|---|---|---|---|
| SAMPLE-001 | pass | sample_dirs=5 | Sample directories available. |
| SAMPLE-002 | warning | accounts/ exists in test profile | Ensure test runs only use examples/, not real accounts. |
