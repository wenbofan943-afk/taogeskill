# Expected Artifacts

```yaml
entry_router_request:
  entry_case: first_use_no_account
  entry_route: account-onboarding
  account_resolution_status: account_missing
  checker_requested: no
  resume_requested: no
```

```text
accounts/{sample_account_slug}/account_profile.md
```

账号档案落盘前必须等待用户确认。

```yaml
image_asset_status: not_applicable
reason: first-use onboarding sample only validates account profile confirmation and creation.
```
