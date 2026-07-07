# Sample Check Report

```yaml
check_run_id: CHECKRUN-SAMPLE-20260708-003821
sample_id: sample-01-onboarding
command_name: validate-sample-run
command_version: p3-validator-v0.1
exit_code: 0
overall_result: pass
machine_readable_report_path: sample-check-report.json
human_readable_report_path: check-report.md
```

| Check ID | Group | Severity | Status | Evidence | Remediation |
|---|---|---|---|---|---|
| P3SAMPLE-001 | sample_structure | blocker | pass |  | Add missing sample files. |
| P3SAMPLE-002 | privacy | blocker | pass |  | Replace real data with sample placeholders. |
| P3SAMPLE-003 | link_check | blocker | pass |  | Fix relative links inside sample. |
| P3SAMPLE-004 | sample_behavior | blocker | pass | expected-agent-behavior.md | Add clear expected behavior and recovery notes. |
| P3SAMPLE-007 | sample_metadata | blocker | pass |  | Add Sample Card metadata to README and manifest.yaml. |
| P3SAMPLE-005 | sample_behavior | warn | pass | README.md; expected-agent-behavior.md; check-report.md | Add failure case and expected recovery. |
| P3SAMPLE-006 | image_asset | warn | pass | expected-artifacts.md; check-report.md | Mark generated / pending_external / prompt-only / not_applicable honestly. |

## Result

Sample is ready for review. This is still not a real production run.
