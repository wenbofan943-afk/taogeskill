# Release Checklist

```yaml
release_check_id: P7REL-20260716-001
checked_at: 2026-07-16
public_release_path: releases/v0.1.0-alpha.7/public_release/
source_commit: 98764ba0752fb997442d42cc9e96293035a6218a
release_state: github_release_published
publish_status: published_to_github
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P7CHK-001 | 版本一致性 | pass | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest agree on 0.1.0-alpha.7 |  |
| P7CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P7CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE reviewed for Alpha.7 |  |
| P7CHK-004 | 联系与反馈入口 | pass | CONTACT and public-safe Issues path remain available |  |
| P7CHK-005 | 发布状态诚实 | pass | GitHub prerelease, tag and two uploaded assets are public; L2.8 / Alpha limits remain explicit |  |
| P7CHK-006 | GitHub 动作边界 | pass | user explicitly authorized Alpha.7 release on 2026-07-16 |  |
| P7CHK-007 | 样例入口 | pass | examples are present and the clean candidate passed the public validator |  |
| P7CHK-008 | 校验入口 | pass | 56 public checks passed with 0 blockers and 0 warnings |  |
| P7CHK-009 | 图片能力边界 | pass | Image 2, source capture, reuse and prompt-only paths are distinguished |  |
| P7CHK-010 | 外部 dry-run | warn | external tester installation and acceptance remain a beta/stable follow-up | invite tester after Alpha.7 |
| P7CHK-011 | CI | pass | exact release commit `98764ba` run `29474934908` completed success |  |
| P7CHK-012 | Alpha expression | pass | Alpha/L2.8 wording passed the public entry and alpha-expression gates |  |
| P7CHK-013 | Release gate | pass | clean candidate and release gate passed; human approval was already explicit |  |
| P7CHK-014 | Public source boundary | pass | tag tree, downloaded Source ZIP and Source tar.gz have zero root private paths, real account names or date-shaped private session IDs |  |
| P7CHK-015 | Windows clean-room matrix | pass | local PS5.1 six-case matrix and hosted source/ZIP matrices passed |  |
| P7CHK-016 | Archive integrity | pass | 824-file archive manifest passed; uploaded ZIP re-download matched its published SHA256 asset |  |
| P7CHK-017 | 扩展 Windows 环境认证 | pass | public candidate, Server 2022, Server 2025 and Windows 11 ARM64 all succeeded on exact commit |  |

## Human Approval Gates

```text
release commit: 98764ba0752fb997442d42cc9e96293035a6218a
tag v0.1.0-alpha.7: created and pushed
remote configuration: origin_https confirmed
push: completed
GitHub Actions Alpha.7 run: 29474934908 success 4/4
GitHub Release: published at https://github.com/wenbofan943-afk/taogeskill/releases/tag/v0.1.0-alpha.7
```
