# Release Checklist

```yaml
release_check_id: P5REL-20260712-004
checked_at: 2026-07-12
public_release_path: releases/v0.1.0-alpha.4/public_release/
source_commit: pending_release_commit
release_state: release_candidate_built
publish_status: not_published
human_approval_required: true
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P5CHK-001 | 版本一致性 | pass | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest all use 0.1.0-alpha.4 |  |
| P5CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P5CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE present |  |
| P5CHK-004 | 联系与反馈入口 | pass | CONTACT present; README links CONTACT / SECURITY; WeChat `fwb99520` recorded for alpha trial communication; Issues remain public-safe feedback path |  |
| P5CHK-005 | 发布状态诚实 | pass | release_state=release_candidate_built; publish_status=not_published; alpha.3 remains the latest published Release |  |
| P5CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P5CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P5CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P5CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P5CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P5CHK-011 | CI | pending | local workflow validator and full 12-case matrix pass; alpha.4 remote Actions run not started because no push was authorized | push only after approval, then require completed/success |
| P5CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P5CHK-013 | Release gate | pending | local candidate can be checked; release commit、tag、push、GitHub Release and page audit are not done | wait for explicit release authorization |
| P5CHK-014 | Public source boundary | pending | local Git-index package is privacy-scanned; alpha.4 tag tree and GitHub Source zip do not exist yet | audit after tag is published |
| P5CHK-015 | Windows clean-room matrix | pass | local full matrix 12/12; 5.1/7 × short/space-unicode/over-budget × source/zip |  |
| P5CHK-016 | Archive integrity | pass | internal manifest, required files, count/size/SHA256 and secure extraction pass locally |  |
| P5CHK-017 | 扩展 Windows 环境认证 | pending | loopback SMB、Server 2022/2025、Windows ARM64、OneDrive、case-sensitive NTFS、enterprise policy、non-NTFS 分轴取证；探针本身不算认证 | 完成同 host/root/commit/hash 的 full matrix + public validator；缺基础设施保持 blocked_external_infrastructure |

## Human Approval Gates

```text
release commit: pending after final candidate review
tag v0.1.0-alpha.4: not created
remote configuration: existing, but no write authorized
push: not done
GitHub Actions alpha.4 run: not run
GitHub Release: not created; assets and external pages not audited
```

