# Release Checklist

```yaml
release_check_id: P7REL-20260716-001
checked_at: 2026-07-16
public_release_path: releases/v0.1.0-alpha.7/public_release/
source_commit: pending_release_commit
release_state: release_candidate_planned
publish_status: not_published
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P7CHK-001 | 版本一致性 | pending | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest target 0.1.0-alpha.7; awaiting clean-HEAD candidate build | build and validate the candidate |
| P7CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P7CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE reviewed for Alpha.7 |  |
| P7CHK-004 | 联系与反馈入口 | pass | CONTACT and public-safe Issues path remain available |  |
| P7CHK-005 | 发布状态诚实 | pass | candidate is not yet described as published |  |
| P7CHK-006 | GitHub 动作边界 | pass | user explicitly authorized Alpha.7 release on 2026-07-16 |  |
| P7CHK-007 | 样例入口 | pending | examples are present; awaiting public-package validator | run public validator |
| P7CHK-008 | 校验入口 | pending | release validators are present; awaiting candidate execution | run release gates |
| P7CHK-009 | 图片能力边界 | pass | Image 2, source capture, reuse and prompt-only paths are distinguished |  |
| P7CHK-010 | 外部 dry-run | warn | external tester installation and acceptance remain a beta/stable follow-up | invite tester after Alpha.7 |
| P7CHK-011 | CI | pending | exact Alpha.7 release commit has not yet run GitHub Actions | push candidate commit and verify required jobs |
| P7CHK-012 | Alpha expression | pending | Alpha/L2.8 wording updated; awaiting validator | run alpha-expression checker |
| P7CHK-013 | Release gate | pending | local candidate not built yet | build, validate and rerun release gate |
| P7CHK-014 | Public source boundary | pending | Git-index packaging policy active; tag/source ZIP audit waits for publication | audit tag tree and downloaded Source ZIP |
| P7CHK-015 | Windows clean-room matrix | pending | current release commit needs the full PS5.1 source/ZIP matrix | run local and hosted matrices |
| P7CHK-016 | Archive integrity | pending | Alpha.7 ZIP and internal manifest not built yet | build verified archive and compare SHA256 |
| P7CHK-017 | 扩展 Windows 环境认证 | pending | current release commit needs hosted Server 2022/2025 and ARM64 jobs | verify exact-commit Actions jobs |

## Human Approval Gates

```text
release commit: approved, pending creation
tag v0.1.0-alpha.7: approved, not created
remote configuration: origin_https confirmed
push: approved, pending
GitHub Actions Alpha.7 run: pending
GitHub Release: approved, pending candidate validation and exact-commit CI
```
