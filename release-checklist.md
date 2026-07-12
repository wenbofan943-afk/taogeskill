# Release Checklist

```yaml
release_check_id: P5REL-20260712-004
checked_at: 2026-07-13
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
| P5CHK-005 | 发布状态诚实 | pass | release_state=release_candidate_built; publish_status=not_published; alpha.4 publication is authorized but not complete until remote audit closes |  |
| P5CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P5CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P5CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P5CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P5CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P5CHK-011 | CI | pending | temporary-branch certification passed; the final alpha.4 release commit still requires a matching completed/success run | push final release commit and verify its head SHA |
| P5CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P5CHK-013 | Release gate | pending | publication authorized; release commit、tag、push、GitHub Release and page audit are in progress | complete the authorized release closure |
| P5CHK-014 | Public source boundary | pending | local Git-index package is privacy-scanned; alpha.4 tag tree and GitHub Source zip do not exist yet | audit after tag is published |
| P5CHK-015 | Windows clean-room matrix | pass | local full matrix 12/12; 5.1/7 × short/space-unicode/over-budget × source/zip |  |
| P5CHK-016 | Archive integrity | pass | internal manifest, required files, count/size/SHA256 and secure extraction pass locally |  |
| P5CHK-017 | 扩展 Windows 环境认证 | warn | loopback SMB、GitHub-hosted Server 2022/2025 和 Windows 11 ARM64 已按同 commit 认证；OneDrive、case-sensitive NTFS、enterprise policy、non-NTFS 缺真实基础设施 | 保持 known limits，不把 hosted evidence 外推到 self-hosted environments |

## Human Approval Gates

```text
release commit: authorized by user; pending clean-head candidate rebuild
tag v0.1.0-alpha.4: not created
remote configuration: existing; main/tag/Release publication authorized for v0.1.0-alpha.4
push: not done
GitHub Actions alpha.4 run: not run
GitHub Release: not created; assets and external pages not audited
```

