# Release Checklist

```yaml
release_check_id: P5REL-20260713-005
checked_at: 2026-07-13
public_release_path: releases/v0.1.0-alpha.5/public_release/
source_commit: pending_release_commit
release_state: release_candidate_built
publish_status: not_published
human_approval_required: true
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P5CHK-001 | 版本一致性 | pending | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest target 0.1.0-alpha.5 | Build candidate and run public validator |
| P5CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P5CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE present |  |
| P5CHK-004 | 联系与反馈入口 | pass | CONTACT present; README links CONTACT / SECURITY; WeChat `fwb99520` recorded for alpha trial communication; Issues remain public-safe feedback path |  |
| P5CHK-005 | 发布状态诚实 | pending | alpha.5 is a local candidate until tag, assets, Actions and GitHub Release are verified | Complete remote release closure |
| P5CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P5CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P5CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P5CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P5CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P5CHK-011 | CI | pending | Must run on the exact alpha.5 release commit | Push tag and verify all required jobs |
| P5CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P5CHK-013 | Release gate | pending | Candidate build, tag, assets, pages and audit are not yet complete | Complete remote release closure |
| P5CHK-014 | Public source boundary | pending | Re-audit the alpha.5 tag tree and downloaded Source ZIP | Run public privacy audit after tag |
| P5CHK-015 | Windows clean-room matrix | pending | Run the local and hosted matrix on the exact alpha.5 release commit | Verify matrix evidence |
| P5CHK-016 | Archive integrity | pending | Build and verify alpha.5 archive manifest, ZIP and SHA256 | Run public validator and release gate |
| P5CHK-017 | 扩展 Windows 环境认证 | pending | Existing alpha.4 evidence is historical only | Verify same-commit hosted evidence or record not_certified |

## Human Approval Gates

```text
release commit: pending_release_commit
tag v0.1.0-alpha.5: not created
remote configuration: origin_https confirmed; no alpha.5 remote write yet
push: not run
GitHub Actions alpha.5 run: not run
GitHub Release: not created; ZIP and SHA256 not uploaded
```

