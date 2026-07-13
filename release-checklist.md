# Release Checklist

```yaml
release_check_id: P6REL-20260713-006
checked_at: 2026-07-13
public_release_path: releases/v0.1.0-alpha.6/public_release/
source_commit: 36b46e8b7cff47b56a511b8b7ec9575077dfe658
release_state: github_release_published
publish_status: published_to_github
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P6CHK-001 | 版本一致性 | pass | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest all target 0.1.0-alpha.6; public validator passed |  |
| P6CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P6CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE present |  |
| P6CHK-004 | 联系与反馈入口 | pass | CONTACT present; README links CONTACT / SECURITY; Issues remain public-safe feedback path |  |
| P6CHK-005 | 发布状态诚实 | pass | tag, assets, Actions and GitHub Release verified as alpha prerelease |  |
| P6CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P6CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P6CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P6CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P6CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P6CHK-011 | CI | pass | Actions `29263113305` on exact commit `36b46e8`; public candidate, Windows 2022, Windows 2025 and Windows ARM64 all passed |  |
| P6CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P6CHK-013 | Release gate | pass | local gate ready; tag, pages, assets and external audit completed |  |
| P6CHK-014 | Public source boundary | pass | tag tree and downloaded GitHub Source ZIP: no root private production directory or private display name |  |
| P6CHK-015 | Windows clean-room matrix | pass | exact-commit hosted matrix passed on Windows Server 2022/2025 and Windows 11 ARM64 |  |
| P6CHK-016 | Archive integrity | pass | public validator passed; remote ZIP SHA256 `8ab48366c84a4f5f749809f9bc41f635efd3ee83e2dd02d520fd3f8a2950670f` matches uploaded asset |  |
| P6CHK-017 | 扩展 Windows 环境认证 | pass | exact-commit hosted Windows Server 2022/2025 and Windows 11 ARM64 evidence verified |  |

## Human Approval Gates

```text
release commit: 36b46e8b7cff47b56a511b8b7ec9575077dfe658
tag v0.1.0-alpha.6: created and pushed (annotated tag object a95b08c1544b74488faf96274d3a643d6de4448e)
remote configuration: origin_https confirmed; main and tag pushed
push: completed
GitHub Actions alpha.6 run: 29263113305, all required jobs success
GitHub Release: published as prerelease; ZIP and SHA256 uploaded and downloaded for verification
```

