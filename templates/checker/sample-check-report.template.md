# Sample Check Report

```yaml
sample_check_report:
  check_report_id: SAMPLE-CHECK-YYYYMMDD-001
  check_run_id: CHECKRUN-SAMPLE-YYYYMMDD-001
  sample_id:
  sample_goal:
  sample_status: draft
  command_name: validate-sample-run
  command_version: p3-validator-contract-v0.2
  exit_code: 2
  severity_policy: blocker_fails
  happy_path_result: not_run
  failure_case_result: not_run
  expected_recovery_result: not_run
  privacy_status: not_run
  link_status: not_run
  field_gate_status: not_run
  image_asset_status: not_run
  human_guidance_status: not_run
  evidence_paths: []
  remediation_items: []
  machine_readable_report_path: sample-check-report.yaml
  human_readable_report_path: check-report.md
  artifact_manifest_path: manifest.yaml
  reproducibility_status: not_run
  artifact_path:
  next_action:
```

## Scope

```text
sample_root:
sample_only: true
contains_real_account: false
contains_real_customer_data: false
```

## Checks

| Check | Result | Evidence | Fix |
|---|---|---|---|
| Happy path can be followed | not_run |  |  |
| Failure case has recovery guidance | not_run |  |  |
| No real account or customer data | not_run |  |  |
| Links are relative and readable | not_run |  |  |
| Fields match field dictionary | not_run |  |  |
| Image assets are marked generated / pending / prompt-only honestly | not_run |  |  |
| Human guidance tells the tester what to reply next | not_run |  |  |

## Evidence Items

| Check ID | Severity | Status | Evidence Paths | Summary | Remediation |
|---|---|---|---|---|---|
|  |  | not_run |  |  |  |

## Exit Code

```text
0 pass; 1 fail; 2 blocked; 3 tool_error; 4 usage_error.
```

## Result

```text
This template is not a pass. Fill evidence before changing sample_status.
```
