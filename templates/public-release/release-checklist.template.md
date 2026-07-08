# Release Checklist

```yaml
release_check_id: R4REL-YYYYMMDD-001
checked_at: YYYY-MM-DD
public_release_path: public_release/
source_commit: pending
release_status: blocked
blocking_items:
  - license_status_pending
warning_items: []
release_check_report_path:
release_record_path:
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| R4CHK-001 | 入口完整 | not_run |  |  |
| R4CHK-002 | 社区健康文件 | not_run |  |  |
| R4CHK-003 | AI 可读入口 | not_run |  |  |
| R4CHK-004 | sample 完整 | not_run |  |  |
| R4CHK-005 | 链接闭合 | not_run |  |  |
| R4CHK-006 | 隐私净化 | not_run |  |  |
| R4CHK-007 | 密钥净化 | not_run |  |  |
| R4CHK-008 | 本机路径净化 | not_run |  |  |
| R4CHK-009 | 成熟度诚实 | not_run |  |  |
| R4CHK-010 | 发布边界 | not_run |  |  |

## Result

```text
当前模板默认 blocked。只有实际 public_release 生成并通过检查后，才能改为 pass 或 pass_with_warnings。
```

