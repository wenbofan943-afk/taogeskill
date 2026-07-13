# Update

> 状态：public_release_candidate_instruction

## Version Policy

```text
current_version: 0.1.0-alpha.5
tag_name_when_published: v0.1.0-alpha.5
release_state: github_release_published
```

本项目使用语义化版本口径，但 `alpha` 版本仍可能调整字段、样例和 skill 合同。更新前必须先读 `CHANGELOG.md` 和 `RELEASE_NOTES.md`。

## Update Rule

Before replacing an existing local copy, keep your private data outside the public package:

```text
accounts/
offline_tester_packages/
real production runs
generated images
API keys or platform credentials
```

## Recommended Steps

1. Read `CHANGELOG.md`.
2. Compare `AGENTS.md`, `PROJECT_MAP.md`, `交接物字段词典.md`, and `skills/*/CONTRACT.md`.
3. Run or manually follow the release / sample check reports.
4. Reconfirm account profiles before using old accounts with new rules.
5. From alpha.4 to alpha.5, rerun `tools/invoke-environment-doctor.ps1`, the public validator and R5 account-identity fixtures; do not copy old release ZIPs or `state/checks/` reports into the new package.

Do not copy a public release over a private working repository without checking private runs first.

## Rollback

```text
If a new package breaks local workflow behavior, restore the previous folder copy.
Do not merge accounts/ or generated deliverables automatically.
Keep old VERSION, CHANGELOG.md, and release-record.json together for comparison.
```

## Migration Notes

```text
accounts/ is private data and is not included in public_release.
examples/ are teaching and regression samples, not production runs.
release-record.json describes package state, not GitHub publication state.
```
