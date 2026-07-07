# Release Check Report

```yaml
release_check_report:
  check_report_id: RELEASE-CHECK-YYYYMMDD-001
  check_scope: public_release
  check_run_id: CHECKRUN-YYYYMMDD-001
  command_name: validate-public-release
  command_version: p3-validator-contract-v0.2
  exit_code: 2
  severity_policy: blocker_fails
  checked_at: YYYY-MM-DD
  checked_by: human_or_agent
  input_path: public_release/
  overall_result: blocked
  blocker_count: 0
  warning_count: 0
  blockers: []
  warnings: []
  info_items: []
  evidence_paths: []
  remediation_items: []
  machine_readable_report_path: release-check-report.yaml
  human_readable_report_path: release-check-report.md
  artifact_manifest_path: public-manifest.yaml
  reproducibility_status: not_run
  privacy_scan_result: not_run
  link_check_result: not_run
  field_gate_result: not_run
  contract_sync_result: not_run
  image_asset_check_result: not_run
  release_state_result: not_run
  zip_path:
  sha256_path:
  artifact_path:
  next_action:
```

## Checks

| Check | Result | Evidence | Fix |
|---|---|---|---|
| README / AGENTS / PROJECT_MAP / public-manifest exist | not_run |  |  |
| LICENSE / CONTRIBUTING / CHANGELOG / SECURITY / CODE_OF_CONDUCT exist | not_run |  |  |
| Public package has no real account runs or private data | not_run |  |  |
| No API key, cookie, token, `.env`, or login state | not_run |  |  |
| No local absolute path required by public entrypoints | not_run |  |  |
| Markdown and HTML links are readable inside package | not_run |  |  |
| Field dictionary, contracts, templates, samples are in sync | not_run |  |  |
| Image generation capability is described honestly | not_run |  |  |
| Zip and sha256 match current candidate | not_run |  |  |

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
This template defaults to blocked. A release candidate must fill evidence before pass / pass_with_warnings.
```
