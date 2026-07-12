# Release Checklist

```yaml
release_check_id: P5REL-20260712-003
checked_at: 2026-07-12
public_release_path: releases/v0.1.0-alpha.3/public_release/
source_commit: v0.1.0-alpha.3
release_state: release_candidate_built
publish_status: not_published
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P5CHK-001 | 版本一致性 | pending | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest must all use 0.1.0-alpha.3 | build and validate alpha.3 candidate |
| P5CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P5CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE present |  |
| P5CHK-004 | 联系与反馈入口 | pass | CONTACT present; README links CONTACT / SECURITY; WeChat `fwb99520` recorded for alpha trial communication; Issues remain public-safe feedback path |  |
| P5CHK-005 | 发布状态诚实 | pass | release_state=release_candidate_built; publish_status=not_published；发布完成后再更新 |  |
| P5CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P5CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P5CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P5CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P5CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P5CHK-011 | CI | pending | validation-only workflow exists and `P3REL-010` passes locally / in public_release | wait for alpha.3 GitHub Actions success |
| P5CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P5CHK-013 | Release gate | pass | release commit、tag、remote、push、GitHub Release、assets、页面审计、本地扫地全部纳入发版完成定义 |  |
| P5CHK-014 | Public source boundary | pending | root `accounts/` and `indexes/` are ignored; alpha.3 tag and Source zip require external scan | audit tag tree and downloaded Source zip |

## Human Approval Gates

```text
release commit: pending
tag v0.1.0-alpha.3: pending
remote configuration: done
push: authorized by user, pending execution
GitHub Release: pending draft, asset upload, publish and page audit
```

