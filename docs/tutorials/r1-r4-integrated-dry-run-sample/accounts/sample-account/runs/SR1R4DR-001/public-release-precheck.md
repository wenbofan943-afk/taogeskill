# Public Release Precheck

```yaml
release_check_id: R4PRE-SR1R4DR-001
checked_at: 2026-07-07
public_release_path: not_generated
source_commit: local_worktree_not_committed
release_status: blocked_for_real_release
blocking_items:
  - LICENSE not selected for real public_release
  - community health files not generated in public_release
  - GitHub remote/tag/release not confirmed
warning_items:
  - sample final-delivery.html uses local relative links
  - generated image path not verified
```

## R4CHK

| check | result | note |
|---|---|---|
| R4CHK-001 | sample_pass | sample has README and manifest; no real public_release generated |
| R4CHK-002 | blocked_for_real_release | License and community health files are not part of this sample |
| R4CHK-003 | sample_pass | README and PROJECT_MAP index this tutorial after sync |
| R4CHK-004 | sample_pass | sample-account and sample-run shape exists under tutorial |
| R4CHK-005 | sample_pass | local sample links checked separately |
| R4CHK-006 | sample_pass | sample contains no real account or customer data |
| R4CHK-007 | sample_pass | no API key, token, cookie, secret, or .env |
| R4CHK-008 | sample_pass_with_scope | tutorial paths are local project paths; public_release not generated |
| R4CHK-009 | sample_pass | maturity is stated as sample / warning, not stable release |
| R4CHK-010 | sample_pass | no auto publish, login, external API, or platform interaction |

## 结论

```text
本样本可作为 R4 precheck 形态验证。
不能作为真实 GitHub release candidate。
阻断项只记录，不在本轮修复。
```

