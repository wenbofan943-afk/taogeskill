# Release Notes

> Current compatibility is limited to Windows PowerShell 5.1. PowerShell 7 results preserved in older notes are historical evidence, not a current support claim or release prerequisite.

## 0.1.0-alpha.10

### Summary

This GitHub alpha pre-release repairs Alpha.9's public-package verification gap. The uploaded ZIP now includes the public-redacted hotspot delivery E2E checker, its fixture catalog, and the visual-semantic helper it directly requires. Both direct and hotspot routes are rechecked from a freshly extracted package through final HTML, viewport evidence, and the final human-decision wait.

```yaml
version: 0.1.0-alpha.10
tag_name_when_published: v0.1.0-alpha.10
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease
human_approval_required: false
```

### Fixed

- Public build closure now includes the complete offline hotspot delivery verification surface instead of relying on a source-only checker.
- `P3REL-042` verifies that the builder and validator share this required hotspot fixture, helper, and E2E entrypoint.

### Known limits

- These checks remain offline and synthetic. They do not certify real accounts, real hotspot freshness, network research, image providers, publishing, semantic quality, visual quality, or project-wide L3 autonomy.
- No automatic source collection, platform login, publishing, comments, private messages or post-publication analytics.

### Install / Upgrade

Use the uploaded `taoge-creative-workflow-0.1.0-alpha.10-public-release.zip` and verify its accompanying `.sha256`. Preserve private `accounts/`, generated assets and local state; do not overwrite a private working repository with the public ZIP.

## 0.1.0-alpha.9

### Summary

This GitHub alpha pre-release makes the two verified entry routes easier to audit as delivery paths. A public-redacted hotspot fixture now uses one session for source lineage, candidate compilation, final HTML, desktop/mobile technical viewport evidence, delivery review, business acceptance, and the final human decision wait. The direct route remains covered by its corresponding offline delivery regression.

```yaml
version: 0.1.0-alpha.9
tag_name_when_published: v0.1.0-alpha.9
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease
human_approval_required: false
```

### Added

- Public-redacted hotspot delivery E2E fixture and its same-session final-human-wait evidence.

### Fixed

- H4 candidate and H5 seed validation roots are shortened for deep GitHub Actions workspaces without weakening path-budget preflight.
- R6 content/source evidence gate is revalidated with capture recovery, immutable annotation conflict rejection, and deterministic evidence rendering.

### Known limits

- The fixture is offline and synthetic: it does not certify real hotspot freshness, real accounts, image providers, real publishing, semantic quality, visual quality, or project-wide L3 autonomy.
- No automatic source collection, platform login, publishing, comments, private messages or post-publication analytics.
- External tester installation/acceptance, OneDrive, case-sensitive NTFS, enterprise Group Policy and non-NTFS remain follow-up evidence scopes.

### Install / Upgrade

Use the uploaded `taoge-creative-workflow-0.1.0-alpha.9-public-release.zip` and verify its accompanying `.sha256`. Preserve private `accounts/`, generated assets and local state; do not overwrite a private working repository with the public ZIP.

## 0.1.0-alpha.8

### Summary

This Alpha pre-release closes the current R7 final-delivery contract. It distinguishes generated base assets from immutable delivery assets, renders the creator-facing HTML in business order, keeps viewport measurements separate from visual judgment, and requires an explicit business-delivery acceptance record before propagation.

It also fixes portrait picture-in-picture placement and makes child-process failures observable through their real exit codes. The project remains human supervised and stays at L2.8; this release does not claim project-wide L3 autonomy.

```yaml
version: 0.1.0-alpha.8
tag_name_when_published: v0.1.0-alpha.8
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease
human_approval_required: false
```

### Added

- Immutable final-asset delivery set and explicit visual-asset finalization records.
- Business-first final HTML v0.9 with the script, visual inserts, platform package, warnings and actions ahead of the collapsed audit layer.
- Separate technical viewport v0.2 and business-delivery acceptance v0.1 contracts.
- Public release gates for the H7 delivery closure and child-process exit-code propagation.

### Fixed

- Portrait PIP assets now use contained placement inside the remaining 9:16 canvas.
- Standalone acceptance tasks include their required dependency instead of failing submission construction.
- R7 wrappers preserve failed checker exit codes instead of allowing false-success interpretation.

### Known limits

- Alpha, single-content runtime only; no automatic multi-content parallel execution.
- No automatic source collection, platform login, publishing, comments, private messages or post-publication analytics.
- Semantic payloads, visual decisions and prompts still use Codex judgment; project-wide L3 autonomy is not proven.
- External tester installation/acceptance, OneDrive, case-sensitive NTFS, enterprise Group Policy and non-NTFS remain follow-up evidence scopes.

### Install / Upgrade

Use the uploaded `taoge-creative-workflow-0.1.0-alpha.8-public-release.zip` and verify its accompanying `.sha256`. Preserve private `accounts/`, generated assets and local state; do not overwrite a private working repository with the public ZIP.

## 0.1.0-alpha.7

### Summary

This Alpha pre-release turns the single-content project into a more explicit, auditable workflow runtime. It adds direct-content and news-evidence paths, script/visual coordination, typed direct/hotspot semantic workflows, deterministic delivery revisions, viewport evidence and bounded agent execution.

The project remains a human-supervised content workflow. Real regression reached final HTML and scoped revision, but semantic payloads, visual decisions and prompts still used Codex judgment; project-wide L3 autonomy is not claimed.

```yaml
version: 0.1.0-alpha.7
tag_name_when_published: v0.1.0-alpha.7
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease
human_approval_required: false
```

### Added

- R6 direct-content intake and news/data/quotation evidence PIP with source-capture attempt, recovery and creator-interpretation separation.
- R6 structure plan, content-beat map, spoken-script review, visual-coverage ledger and script/visual alignment review.
- R7 typed semantic coordinator, producer adapters, current pointers, deterministic candidate renderer, desktop/mobile viewport acceptance and human final gate.
- R7 hotspot freshness review, source revision, replan and delivery chain, plus scoped multi-item human revision.
- Project run-control profiles for bounded continuation, checkpoint-and-return, repeated-failure detection and explicit task/profile transitions.

### Changed

- Core Skill prose was reduced and detailed contracts moved behind indexed schemas, routes, fixtures and runtime helpers.
- Windows public compatibility is now stated only for Windows PowerShell 5.1; historical PowerShell 7 evidence no longer acts as a requirement or support promise.
- README remains a short public landing page instead of duplicating product history and third-party methodology.

### Fixed

- Evidence screenshots, reused verified assets and new Image 2 assets now use exclusive source routing and current-task lineage binding.
- Delivery revisions advance monotonically and rebuild from the earliest owning node without mutating completed candidates.
- Viewport evidence, source links, attempt ownership and PowerShell path/collection handling no longer drift across revisions.
- dev/test checks cannot silently escalate into a public build or keep repeating the same repair indefinitely.
- Public documentation no longer carries date-shaped private session identifiers; the release privacy gate now rejects that identifier shape generically instead of relying only on a historical allowlist.

### Known limits

- Alpha, single-content runtime only; no automatic multi-content parallel execution.
- No automatic source collection, platform login, publishing, comments, private messages or post-publication analytics.
- Project maturity remains L2.8; one direct path has an L3 sample, but repeatable project-wide autonomy is not proven.
- External tester installation/acceptance, OneDrive, case-sensitive NTFS, enterprise Group Policy and non-NTFS remain follow-up evidence scopes.

### Install / Upgrade

Use the uploaded `taoge-creative-workflow-0.1.0-alpha.7-public-release.zip` and verify its accompanying `.sha256`. Preserve private `accounts/`, generated assets and local state; do not overwrite a private working repository with the public ZIP.

## 0.1.0-alpha.6

### Summary

This corrective alpha pre-release removes a real private account display name from public R5 product documents. The public package retains only generic, account-scoped product contracts; real account identity bindings remain in the ignored private production area.

```yaml
version: 0.1.0-alpha.6
tag_name_when_published: v0.1.0-alpha.6
release_state: release_candidate_built
publish_status: not_published
status: alpha_prerelease
human_approval_required: false
```

### Fixed

- Public R5 product documentation no longer embeds a private account display name or directory key.

### Known limits

- Alpha, single-content runtime only; no automatic multi-content parallel execution.
- No automatic source collection, platform login, publishing, comments, private messages, or post-publication analytics.

## 0.1.0-alpha.5

### Summary

This GitHub alpha pre-release closes the public-package contract for R5: account-scoped visual identity, a used-car-first hotspot radar, auditable keyword exploration and feedback, and current cross-account technical identity binding. It also corrects the package whitelist so the account-startup tools described by the R5 Skills ship with the public candidate and are checked before release.

Use the uploaded public-release ZIP for local evaluation. It does not collect sources automatically, log into platforms, publish content, or prove real distribution effects.

```yaml
version: 0.1.0-alpha.5
tag_name_when_published: v0.1.0-alpha.5
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease
human_approval_required: false
```

### What changed

#### Added

- R5 H1–H6 public contracts and fixtures for account visual identity, account radar policy, four-layer radar objects, lexicon feedback, account-startup compatibility, and current identity binding.
- Public gates `P3REL-034` through `P3REL-037`; they run the R5 H3–H6 fixtures and require the H5/H6 public runtime dependencies.

#### Fixed

- Public package construction now includes the R5 account-startup and identity-binding runtime tools rather than only a partial checker subset.
- R5 product indexes and status summaries now reflect the completed private identity migration / startup regression without claiming an actual public-source hotspot run.

### Known limits

- Alpha, single-content runtime only; no automatic multi-content parallel execution.
- No automatic source collection, platform login, publishing, comments, private messages, or post-publication analytics.
- Real hotspot retrieval and content production remain user-triggered operations, not release-time tests.

## 0.1.0-alpha.4

### Summary

This GitHub alpha pre-release hardens Windows installation and verification. It adds shared UTF-8 / process / SHA256 helpers, environment and path preflight, verified archive manifests, and a 12-case Windows clean-room matrix covering PowerShell 5.1/7, short or space/Unicode paths, over-budget blocking, Git-index source, and verified ZIP input.

Use the uploaded public-release ZIP for local evaluation. Do not treat it as a production workflow engine or an automated publishing tool.

```yaml
version: 0.1.0-alpha.4
tag_name_when_published: v0.1.0-alpha.4
release_state: github_release_published
publish_status: published_to_github
status: alpha_prerelease
human_approval_required: false
```

### What changed

#### Added

- Environment doctor and preflight for Windows reserved names, root / reparse containment, path budget, cwd independence, writable same-volume temporary space, and free disk space.
- Internal `archive-manifest.json` with normalized paths, file count, size, required files, and SHA256 for public-release and support-log ZIPs.
- Secure archive extraction checks for zip-slip, case collisions, missing or changed payloads, and exit-code false success.
- Versioned 12-case Windows clean-room matrix plus `P3REL-026` through `P3REL-029` public gates.
- Evidence-bound extended Windows certification probe, `P3REL-031`, explicit Server 2022/2025 and Windows 11 ARM64 CI jobs, plus a 12/12 loopback SMB/UNC matrix.
- Validation-only GitHub Actions workflow calls the full PowerShell 5.1/7 matrix and preserves failed-case summaries, stderr tails, and machine diagnostics. Hosted certification completed on an authorized temporary branch before the final release run.

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
- Allowed H7 semantic validation to preserve the declared `content_production`, `regression`, or `revision` run purpose instead of incorrectly requiring every delivery to be a regression.

### Known limits

- Alpha, single-content runtime only; no automatic multi-content parallel execution.
- No platform login, automatic publishing, comments, private messages, or post-publication analytics.
- Real distribution effect and external tester acceptance remain unproven.
- Loopback SMB/UNC is certified only for the observed local share and is not evidence for remote NAS, credential changes, or disconnect recovery. GitHub-hosted Server 2022/2025 and Windows 11 ARM64 passed the same-commit matrix and public validator in temporary-branch run `29201682178`; this does not certify arbitrary private servers or ARM64 devices. OneDrive, case-sensitive NTFS, enterprise Group Policy, and non-NTFS remain blocked on missing self-hosted infrastructure.
- OneDrive, case-sensitive NTFS, enterprise Group Policy, and non-NTFS remain unverified because matching self-hosted infrastructure is unavailable; they are not implied by the supported hosted environments.

### Install / Upgrade

Verify the `.sha256`, keep the project installation root at 90 characters or fewer, and read `INSTALL.md` plus `docs/reference/Windows环境兼容性支持矩阵.md`. Preserve private `accounts/`, generated assets, and local state when upgrading from alpha.3. Do not overwrite a private working repository with the public ZIP.

### Assets and checks

- Release assets: `taoge-creative-workflow-0.1.0-alpha.4-public-release.zip` and its `.sha256`, published with tag `v0.1.0-alpha.4`.
- Public candidate must contain no real `accounts/`, `indexes/`, private runs, credentials, or local check caches.
- Local full clean-room matrix: 12/12 expected outcomes; 8 positive checker paths and 4 expected preflight blocks.
- Runtime helper: 14/14 on Windows PowerShell 5.1 and PowerShell 7.6.3, including empty-`PSModulePath` SHA256, Unicode Git paths, PowerShell 5.1 source-encoding enforcement, the shared BOM writer, and a nonfatal non-Git root probe.
- Loopback SMB/UNC full matrix: 12/12, with source/ZIP and both PowerShell hosts; no global system configuration changed.
- Remote GitHub Actions run `29206932433` completed successfully for all four required jobs on the exact release commit `a7bc276…`. The uploaded ZIP was downloaded through the Release API and its SHA-256 was rechecked; the public tag tree and GitHub Source ZIP were also audited for private production roots and real-account markers.
- A private current-content run completed research, topic choice, Brief, copywriting, 5 Image 2 tasks, joint review, four platform packages, 3 covers, and H7 final delivery; the 20 semantic checks passed with documented non-blocking warnings. Private account and session data are not included.

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

