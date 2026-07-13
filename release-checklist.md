# Release Checklist

```yaml
release_check_id: P5REL-20260712-004
checked_at: 2026-07-13
public_release_path: releases/v0.1.0-alpha.4/public_release/
source_commit: a7bc2763979b93a4c213aff0fb3523a2a9df91b8
release_state: github_release_published
publish_status: published_to_github
human_approval_required: false
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P5CHK-001 | 版本一致性 | pass | VERSION / CHANGELOG / RELEASE_NOTES / public-manifest all use 0.1.0-alpha.4 |  |
| P5CHK-002 | 社区健康文件 | pass | LICENSE / CONTRIBUTING / SECURITY / CODE_OF_CONDUCT present |  |
| P5CHK-003 | 安装更新说明 | pass | INSTALL / UPDATE present |  |
| P5CHK-004 | 联系与反馈入口 | pass | CONTACT present; README links CONTACT / SECURITY; WeChat `fwb99520` recorded for alpha trial communication; Issues remain public-safe feedback path |  |
| P5CHK-005 | 发布状态诚实 | pass | `github_release_published`; alpha.4 is a GitHub prerelease, not a stable release |  |
| P5CHK-006 | GitHub 动作边界 | pass | commit / tag / remote / push all require human approval |  |
| P5CHK-007 | 样例入口 | pass | examples README and sample manifests present |  |
| P5CHK-008 | 校验入口 | pass | tools/validate-public-release.ps1 and tools/validate-sample-run.ps1 present |  |
| P5CHK-009 | 图片能力边界 | pass | RELEASE_NOTES / INSTALL describe Codex vs prompt-only fallback |  |
| P5CHK-010 | 外部 dry-run | warn | not completed by external tester | invite tester and record result |
| P5CHK-011 | CI | pass | run `29206932433` completed/success on exact release commit `a7bc276…`; all four required jobs passed |  |
| P5CHK-012 | Alpha expression | pass | README / INSTALL / samples / RELEASE_NOTES have alpha boundary and `P3REL-011` passes |  |
| P5CHK-013 | Release gate | pass | main and annotated tag pushed; prerelease published with ZIP and SHA256 assets; GitHub repo, Release and tag pages opened |  |
| P5CHK-014 | Public source boundary | pass | tag tree and downloaded GitHub Source ZIP contain no root private production directories or real account/session markers; tutorial-internal sample paths are intentional |  |
| P5CHK-015 | Windows clean-room matrix | pass | local full matrix 12/12; 5.1/7 × short/space-unicode/over-budget × source/zip |  |
| P5CHK-016 | Archive integrity | pass | internal manifest, required files, count/size/SHA256 and secure extraction pass locally |  |
| P5CHK-017 | 扩展 Windows 环境认证 | warn | loopback SMB、GitHub-hosted Server 2022/2025 和 Windows 11 ARM64 已按同 commit 认证；OneDrive、case-sensitive NTFS、enterprise policy、non-NTFS 缺真实基础设施 | 保持 known limits，不把 hosted evidence 外推到 self-hosted environments |

## Human Approval Gates

```text
release commit: a7bc2763979b93a4c213aff0fb3523a2a9df91b8
tag v0.1.0-alpha.4: created and pushed (annotated tag object 11f0287…)
remote configuration: origin_https; main and tag pushed
push: completed
GitHub Actions alpha.4 run: 29206932433, completed/success, four required jobs passed
GitHub Release: published as prerelease; ZIP and SHA256 uploaded, downloaded, and audited
```

