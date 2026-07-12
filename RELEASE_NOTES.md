# Release Notes

## 0.1.0-alpha.3

### Summary

This GitHub alpha pre-release upgrades the project from documented orchestration to an executable single-content P0 chain with versioned contracts, deterministic final-delivery rendering, failure/recovery fixtures, evidence projection, content-derived 0-to-N visuals, and a creator-facing publication workbench.

Use it to study or locally validate the workflow with redacted fixtures. Do not treat it as a production workflow engine or an automated publishing tool.

```yaml
version: 0.1.0-alpha.3
tag_name_when_published: v0.1.0-alpha.3
release_state: release_candidate_built
publish_status: not_published
status: alpha_prerelease_candidate
```

### What changed

#### Added

- P0-H1 to H7 versioned plans, typed render inputs, deterministic runtime, receipts, lineage, projection/recovery commands, and independent failure fixtures.
- `typed_components_v0.3` delivery revisions that generate final HTML, script, visual plan, platform package, and delivery record from one revision.
- Platform delivery units binding each platform's text to its actual rendered cover.
- Exact picture-in-picture insertion windows, human-readable warnings, honest duration status, and H7 semantic validation.
- Content-derived 0-to-N visual analysis: every accepted visual task is generated in Codex Image 2 without a product call-count or cost gate.
- Public H7 fixtures and release check `P3REL-025`.

#### Fixed

- Prevented template changes from incorrectly reusing stale HTML.
- Prevented fixed regression counts and uncalibrated speech-rate constants from becoming product rules.
- Fixed checker text/path confusion, PowerShell automatic-variable collisions, state projection drift, and desktop card overflow.
- Removed real local session identifiers from tracked product/status documents.
- Sanitized the HTTPS remote so credentials are no longer stored in Git configuration.

### Known limits

- Single-content runtime only; no automatic multi-content parallel execution.
- No platform login, automatic publishing, comments, private messages, or post-publication analytics.
- Real distribution effect and external tester acceptance remain unproven.
- Runtime model profile is reported only when observable.
- Validation-only GitHub Actions workflow exists; the alpha.3 remote run must succeed before publication is considered complete.

### Install / Upgrade

Download `taoge-creative-workflow-0.1.0-alpha.3-public-release.zip`, verify the accompanying `.sha256`, extract it, and let the AI read the project entrypoints. Preserve private `accounts/`, generated assets, and local state when upgrading.

### Assets and checks

- Public release zip contains no real `accounts/`, `indexes/`, private runs, credentials, or local check caches.
- Uploaded zip and `.sha256` are validated together.
- H7 fixtures: 10/10; real private semantic regression: 20/20 `pass_with_warnings`.
- Public release validator target: 0 blockers and 0 warnings before publish.

### Feedback

Use GitHub Issues or the project `CONTACT.md` entry. Support logs remain opt-in and exclude real content by default.

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

