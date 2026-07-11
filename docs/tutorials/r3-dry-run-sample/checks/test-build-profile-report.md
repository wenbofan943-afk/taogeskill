# Build Profile Boundary Check Report

```yaml
check_run_id: BUILD-PROFILE-20260711-141531
profile: test
task: test_run
overall_result: pass
exit_code: 0
fail_count: 0
```

| Check ID | Status | Evidence | Remediation |
|---|---|---|---|
| PROFILE-001 | pass | Profile: test | Valid build profile selected. |
| BOUNDARY-MUST-NOT-READ-accounts- | warning | accounts/ exists and is in must_not_read | Do not read from accounts/ while running the test profile. |
| BOUNDARY-MUST-NOT-READ-indexes- | warning | indexes/ exists and is in must_not_read | Do not read from indexes/ while running the test profile. |
| BOUNDARY-MUST-NOT-READ-support-logs- | warning | support-logs/ exists and is in must_not_read | Do not read from support-logs/ while running the test profile. |
| BOUNDARY-MAY-READ-examples- | pass | examples/ exists | Path is allowed to be read in test profile. |
| BOUNDARY-MAY-READ-docs-tutorials- | pass | docs/tutorials/ exists | Path is allowed to be read in test profile. |
| BOUNDARY-MAY-READ-templates- | pass | templates/ exists | Path is allowed to be read in test profile. |
| BOUNDARY-MAY-READ-tools- | pass | tools/ exists | Path is allowed to be read in test profile. |
| BOUNDARY-MAY-READ-docs- | pass | docs/ exists | Path is allowed to be read in test profile. |
| BOUNDARY-SAMPLE-001 | warning | accounts/ exists | Sample-only profile should not read real account data. |
| BOUNDARY-SAMPLE-002 | warning | indexes/ exists | Sample-only profile should not read real index data. |
