# Release Notes

## 0.1.0-alpha.4

### Summary

This local GitHub alpha pre-release candidate hardens Windows installation and verification. It adds shared UTF-8 / process / SHA256 helpers, environment and path preflight, verified archive manifests, and a 12-case Windows clean-room matrix covering PowerShell 5.1/7, short or space/Unicode paths, over-budget blocking, Git-index source, and verified ZIP input.

Use it to evaluate a local candidate or, after a real GitHub Release exists, to download the uploaded public-release ZIP. Do not treat it as a production workflow engine or an automated publishing tool.

```yaml
version: 0.1.0-alpha.4
tag_name_when_published: v0.1.0-alpha.4
release_state: release_candidate_built
publish_status: not_published
status: alpha_prerelease_candidate
human_approval_required: true
```

### What changed

#### Added

- Environment doctor and preflight for Windows reserved names, root / reparse containment, path budget, cwd independence, writable same-volume temporary space, and free disk space.
- Internal `archive-manifest.json` with normalized paths, file count, size, required files, and SHA256 for public-release and support-log ZIPs.
- Secure archive extraction checks for zip-slip, case collisions, missing or changed payloads, and exit-code false success.
- Versioned 12-case Windows clean-room matrix plus `P3REL-026` through `P3REL-029` public gates.
- Evidence-bound extended Windows certification probe, `P3REL-031`, explicit Server 2022/2025 and Windows 11 ARM64 CI jobs, plus a 12/12 loopback SMB/UNC matrix.
- Validation-only GitHub Actions workflow calls the full PowerShell 5.1/7 matrix and preserves failed-case summaries, stderr tails, and machine diagnostics. Hosted certification is running only on an authorized temporary branch; main, tag, and Release remain unchanged.

#### Changed

- PowerShell 7 is the recommended host. Windows PowerShell 5.1 remains supported in the documented short-path compatibility tier.
- Public builds and support-log exports publish a ZIP only after manifest-based extraction verification.
- CI remains read-only and validation-only, but now runs both PowerShell hosts instead of a single `pwsh` path.

#### Fixed

- Preserved spaces, Chinese characters, quotes, empty arguments, and trailing backslashes across child-process boundaries.
- Removed host-default UTF-8 BOM behavior and silent checker module installation.
- Replaced `Get-FileHash` module-autoload dependency with shared pure .NET SHA256 after the 5.1 ZIP clean room exposed inherited `PSModulePath` differences.
- Prevented nested source packages from borrowing a parent Git index and included non-Git directory files plus archive verification roots in path budgeting.
- Fixed UNC free-space discovery, PowerShell provider-qualified path leakage, archive payload handling on shares, and network cases incorrectly requiring the local junction-creation fixture.
- Removed hosted-runner locale leakage by reading NUL-separated Git paths with explicit UTF-8 decoding and requiring UTF-8 BOM for PowerShell 5.1 scripts that contain non-ASCII literals.

### Known limits

- Alpha, single-content runtime only; no automatic multi-content parallel execution.
- No platform login, automatic publishing, comments, private messages, or post-publication analytics.
- Real distribution effect and external tester acceptance remain unproven.
- Loopback SMB/UNC is certified only for the observed local share and is not evidence for remote NAS, credential changes, or disconnect recovery. OneDrive, case-sensitive NTFS, enterprise Group Policy, and non-NTFS remain blocked on missing self-hosted infrastructure. Server and ARM64 jobs are compiled but not certified until a same-commit remote run succeeds.
- The alpha.4 GitHub tag, Release, assets, Source archive audit, and remote Actions run are not created by this local candidate task.

### Install / Upgrade

Verify the `.sha256`, keep the project installation root at 90 characters or fewer, and read `INSTALL.md` plus `docs/reference/Windows环境兼容性支持矩阵.md`. Preserve private `accounts/`, generated assets, and local state when upgrading from alpha.3. Do not overwrite a private working repository with the public ZIP.

### Assets and checks

- Intended asset names: `taoge-creative-workflow-0.1.0-alpha.4-public-release.zip` and its `.sha256`.
- Public candidate must contain no real `accounts/`, `indexes/`, private runs, credentials, or local check caches.
- Local full clean-room matrix: 12/12 expected outcomes; 8 positive checker paths and 4 expected preflight blocks.
- Runtime helper: 14/14 on Windows PowerShell 5.1 and PowerShell 7.6.3, including empty-`PSModulePath` SHA256, Unicode Git paths, PowerShell 5.1 source-encoding enforcement, the shared BOM writer, and a nonfatal non-Git root probe.
- Loopback SMB/UNC full matrix: 12/12, with source/ZIP and both PowerShell hosts; no global system configuration changed.
- Remote GitHub certification remains pending until every required job succeeds on the exact temporary-branch commit; failed diagnostic runs do not certify a platform.

### Feedback

Use GitHub Issues or `CONTACT.md`. Support-log export remains opt-in, manifest-verified, and excludes full content by default.

## 0.1.0-alpha.3

### Summary

This GitHub alpha pre-release upgrades the project from documented orchestration to an executable single-content P0 chain with versioned contracts, deterministic final-delivery rendering, failure/recovery fixtures, evidence projection, content-derived 0-to-N visuals, and a creator-facing publication workbench.

Use it to study or locally validate the workflow with redacted fixtures. Do not treat it as a production workflow engine or an automated publishing tool.

```yaml
version: 0.1.0-alpha.3
tag_name_when_published: v0.1.0-alpha.3
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease_published
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
- Made release CI version-aware, portable across PowerShell hosts, stable for Chinese Git paths, and byte-stable for hashed SVG fixtures.
- Removed machine-specific absolute paths from the GitHub Source archive.

### Known limits

- Single-content runtime only; no automatic multi-content parallel execution.
- No platform login, automatic publishing, comments, private messages, or post-publication analytics.
- Real distribution effect and external tester acceptance remain unproven.
- Runtime model profile is reported only when observable.
- Validation-only GitHub Actions run `29181897332` completed successfully before publication.

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

