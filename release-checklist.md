# Release Checklist

```yaml
release_check_id: P8REL-20260716-001
checked_at: 2026-07-16
public_release_path: releases/v0.1.0-alpha.8/public_release/
source_commit: d7fb323afeb08c6fe3138bf12b5cceb7ea416032
release_state: github_release_published
publish_status: published_to_github
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P8CHK-001 | 版本一致性 | pass | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest agree on 0.1.0-alpha.8 |  |
| P8CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P8CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE reviewed for Alpha.8 |  |
| P8CHK-004 | 联系与反馈入口 | pass | CONTACT and public-safe Issues path remain available |  |
| P8CHK-005 | 发布状态诚实 | pass | GitHub prerelease, tag and two assets are public; L2.8 / Alpha limits remain explicit |  |
| P8CHK-006 | GitHub 动作边界 | pass | user explicitly authorized a new release on 2026-07-16 |  |
| P8CHK-007 | 样例入口 | pass | examples are present and the clean candidate passed the public validator |  |
| P8CHK-008 | 校验入口 | pass | 58 public checks passed with 0 blockers and 0 warnings |  |
| P8CHK-009 | 图片能力边界 | pass | Image 2 base, derived final assets, source capture, reuse and prompt-only paths remain distinct |  |
| P8CHK-010 | 外部 dry-run | warn | external tester installation and acceptance remain a beta/stable follow-up | invite tester after Alpha.8 |
| P8CHK-011 | CI | pass | exact release commit `d7fb323` run `29495417416` completed success 4/4 |  |
| P8CHK-012 | Alpha expression | pass | Alpha/L2.8 wording passed the public entry and alpha-expression gates |  |
| P8CHK-013 | Release gate | pass | clean candidate and release gate passed; human approval was explicit |  |
| P8CHK-014 | Public source boundary | pass | tag tree, downloaded Source ZIP and Source tar.gz have zero root private paths, real account names or date-shaped private session IDs |  |
| P8CHK-015 | Windows clean-room matrix | pass | local PS5.1 six-case matrix and hosted source/ZIP matrices passed |  |
| P8CHK-016 | Archive integrity | pass | 848-file archive manifest passed; uploaded ZIP re-download matched `395b318c9050e46b2c9d1d18794191ac382e53a79149c4fa180c7518488c293d` |  |
| P8CHK-017 | 扩展 Windows 环境认证 | pass | public candidate, Server 2022, Server 2025 and Windows 11 ARM64 succeeded on exact commit |  |
| P8CHK-018 | H7 final delivery | pass | P3REL-054 passed final asset, business HTML, viewport and acceptance closure |  |
| P8CHK-019 | R7 exit code | pass | P3REL-055 preserved failed child checker exit codes |  |

## Human Approval Gates

```text
release commit: d7fb323afeb08c6fe3138bf12b5cceb7ea416032
tag v0.1.0-alpha.8: created and published
remote configuration: origin_https confirmed
push: completed through verified Git Data API after local Git TLS transport failure
GitHub Actions Alpha.8 run: 29495417416 success 4/4
GitHub Release: published at https://github.com/wenbofan943-afk/taogeskill/releases/tag/v0.1.0-alpha.8
```
