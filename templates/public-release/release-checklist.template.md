# Release Checklist

```yaml
release_check_id: "{{RELEASE_CHECK_ID}}"
checked_at: not_run
version: "{{VERSION}}"
tag_name_when_published: "{{TAG_NAME}}"
public_release_path: public_release/
source_commit: "{{SOURCE_COMMIT}}"
release_state: release_candidate_built
publish_status: not_published
human_approval_required: true
validator_status: not_run
validator_check_count: not_run
blocking_items: []
warning_items: []
release_check_report_path:
release_record_path: release-record.json
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
当前文件只记录候选构建时的发布前状态，不预先宣称 validator、tag、push、Actions 或 GitHub Release 已完成。
实际检查数量和结论只写入候选包外的 release-check-report.json。
```
