# Release Notes

## 0.1.0-alpha.2

This is a published GitHub alpha pre-release that fixes the public source boundary from `0.1.0-alpha.1`.

Use this package for sample dry-run, readonly validation, and human review. Do not treat it as a production workflow engine or an automated publishing tool.

```yaml
version: 0.1.0-alpha.2
github_search_keyword: taogeskill
recommended_repo_name: taogeskill
tag_name_when_published: v0.1.0-alpha.2
release_state: github_release_published
publish_status: published_to_github
human_approval_required: false
```

## Included

- AI-readable project entrypoints.
- Skill contracts and field dictionary.
- Checker templates for workflow, sample, and release checks.
- Public sample structure.
- Clean public Git source boundary: real root `accounts/` and `indexes/` are no longer tracked by the public tag.
- Final delivery HTML concept and image fallback rules.
- Support log export for alpha tester feedback.
- `VERSION`, `CHANGELOG.md`, `INSTALL.md`, `UPDATE.md`, `NOTICE.md`, and `release-record.json`.
- Issue templates for sample problems, workflow feedback, and security/privacy reports.

## Not Included

- Platform publishing automation.
- Platform login.
- Comment, private message, or interaction automation.
- External image API integration.
- Real account production runs in public release.
- Real account profiles in public Git source, release tag source zip, or release assets.

## Upgrade Notes

```text
Prefer this release over `0.1.0-alpha.1`.
Do not overwrite private accounts/ or generated deliverables.
Reconfirm account profiles before using private accounts with this alpha package.
If you previously downloaded GitHub's automatic Source code zip from `0.1.0-alpha.1`, switch to the uploaded public-release zip from this release.
```

## Known Limits

```text
Validation-only GitHub Actions workflow exists; remote Actions results should be checked separately after each push.
GitHub release, tag, remote, and release commit exist for this alpha pre-release.
No external tester dry-run acceptance yet.
Image generation depends on the user's AI environment; prompt-only fallback is supported.
Feedback logs can be exported with: 导出反馈日志包。
GitHub automatic Source code archives are now expected to be clean of real root accounts/, but the uploaded public-release zip remains the recommended download.
```

