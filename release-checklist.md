# Release Checklist

```yaml
release_check_id: P8REL-20260716-001
checked_at: 2026-07-16
public_release_path: releases/v0.1.0-alpha.8/public_release/
source_commit: pending_release_commit
release_state: release_candidate_preparing
publish_status: not_published
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P8CHK-001 | 版本一致性 | pending | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest must agree on 0.1.0-alpha.8 | run public validator |
| P8CHK-002 | 社区健康文件 | pending | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT required | run public validator |
| P8CHK-003 | 安装更新说明 | pending | INSTALL / UPDATE reviewed for Alpha.8 | run public entry review |
| P8CHK-004 | 联系与反馈入口 | pending | CONTACT and public-safe Issues path must remain available | run public validator |
| P8CHK-005 | 发布状态诚实 | pending | L2.8 / Alpha limits must remain explicit until publication | run alpha-expression gate |
| P8CHK-006 | GitHub 动作边界 | pass | user explicitly authorized a new release on 2026-07-16 |  |
| P8CHK-007 | 样例入口 | pending | examples and clean candidate must pass | build and validate |
| P8CHK-008 | 校验入口 | pending | 58 public checks expected | run public validator |
| P8CHK-009 | 图片能力边界 | pending | Image 2 base, derived final assets, source capture, reuse and prompt-only paths must remain distinct | run H7 gate |
| P8CHK-010 | 外部 dry-run | warn | external tester installation and acceptance remain a beta/stable follow-up | invite tester after Alpha.8 |
| P8CHK-011 | CI | pending | exact release commit must complete all required jobs | push candidate commit |
| P8CHK-012 | Alpha expression | pending | Alpha/L2.8 wording must pass | run public entry and alpha-expression gates |
| P8CHK-013 | Release gate | pending | clean candidate and release gate required | build and validate |
| P8CHK-014 | Public source boundary | pending | tag tree and GitHub Source archives must contain no private production paths or markers | audit after publication |
| P8CHK-015 | Windows clean-room matrix | pending | local PS5.1 six-case matrix and hosted source/ZIP matrices required | run matrix and Actions |
| P8CHK-016 | Archive integrity | pending | archive manifest and uploaded ZIP SHA256 parity required | build, upload and redownload |
| P8CHK-017 | 扩展 Windows 环境认证 | pending | required hosted jobs must succeed on exact commit | verify Actions jobs |
| P8CHK-018 | H7 final delivery | pending | final asset, business HTML, viewport and acceptance contract must pass | run P3REL-054 |
| P8CHK-019 | R7 exit code | pending | failed child checker exit codes must remain observable | run P3REL-055 |

## Human Approval Gates

```text
release commit: pending
tag v0.1.0-alpha.8: not_created
remote configuration: origin_https confirmed
push: pending
GitHub Actions Alpha.8 run: pending
GitHub Release: pending
```
