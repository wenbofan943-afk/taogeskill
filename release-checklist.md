# Release Checklist

```yaml
release_check_id: P5REL-20260712-003
checked_at: 2026-07-12
public_release_path: releases/v0.1.0-alpha.3/public_release/
source_commit: v0.1.0-alpha.3
release_state: github_release_published
publish_status: published_to_github
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P5CHK-001 | 版本一致性 | pass | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest all use 0.1.0-alpha.3 |  |
| P5CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P5CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE present |  |
| P5CHK-004 | 联系与反馈入口 | pass | CONTACT present; README links CONTACT / SECURITY; WeChat `fwb99520` recorded for alpha trial communication; Issues remain public-safe feedback path |  |
| P5CHK-005 | 发布状态诚实 | pass | release_state=github_release_published; publish_status=published_to_github |  |
| P5CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P5CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P5CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P5CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P5CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P5CHK-011 | CI | pass | validation-only workflow and public package checks passed in GitHub Actions run 29181897332 |  |
| P5CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P5CHK-013 | Release gate | pass | release commit、tag、remote、push、GitHub Release、assets、页面审计、本地扫地全部纳入发版完成定义 |  |
| P5CHK-014 | Public source boundary | pass | alpha.3 tag tree and downloaded Source zip: 568 files, 0 private paths, 0 private/local-path/token-signature hits |  |

## Human Approval Gates

```text
release commit: done
tag v0.1.0-alpha.3: done
remote configuration: done
push: done
GitHub Release: published as prerelease; zip / sha256 assets and external pages audited
```

