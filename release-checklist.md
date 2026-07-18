# Release Checklist

```yaml
release_check_id: P10REL-20260718-001
checked_at: 2026-07-18
version: 0.1.0-alpha.10
tag_name_when_published: v0.1.0-alpha.10
public_release_path: releases/v0.1.0-alpha.10/public_release/
source_commit: pending_release_commit
release_state: release_candidate_built
publish_status: not_published
human_approval_required: true
```

| Check ID | Item | Status | Evidence | Fix |
|---|---|---|---|---|
| P10CHK-001 | 版本与入口 | pass | VERSION、README、INSTALL、UPDATE、CHANGELOG、RELEASE_NOTES 与公开入口审查合同均指向 Alpha.10 |  |
| P10CHK-002 | 热点验收闭包 | pass | hotspot E2E entrypoint、fixture catalog、visual-semantic helper 均登记在唯一 public build closure，P3REL-042 约束其存在 |  |
| P10CHK-003 | 本地公开候选 | pass | clean HEAD 候选通过 60 public checks，0 blocker、0 warning |  |
| P10CHK-004 | 解包端到端验收 | pass | 新 ZIP 的直供 12/12 与热点同 session HTML / viewport / human-wait 均通过；network/provider/publishing 均为 false |  |
| P10CHK-005 | 隐私与能力边界 | pass | 只使用公开脱敏 fixture；未读取真实账号、生产数据或 provider 输出；不包含自动发布能力 |  |
| P10CHK-006 | 远端发布 | waiting | 需 push 后核对 exact-commit GitHub Actions，再创建不可覆盖的 Alpha.10 tag 与 prerelease | wait for remote gate |

## Release Boundary

```text
Alpha.10 is a corrective prerelease for the Alpha.9 public-package hotspot verification gap.
It does not certify real accounts, network freshness, providers, publishing, semantic quality,
visual quality, or project-wide L3 autonomy.
```
