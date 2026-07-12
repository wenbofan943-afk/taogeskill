# Changelog

This project follows a Keep a Changelog style structure and semantic versioning vocabulary.

## 0.1.0-alpha.3

```text
Status: published alpha pre-release
Publish: published_to_github
```

### Added

- Executable P0-H1 to H7 single-content workflow contracts, runtime, evidence commands, failure/recovery fixtures, and deterministic final delivery.
- Content-derived 0-to-N visual analysis with automatic generation of all accepted Codex Image 2 tasks.
- Delivery revision v0.3 with platform-cover binding, exact PIP placement, human warnings, honest duration status, and same-revision final views.
- H7 public fixtures, semantic checker, state finalizer, and `P3REL-025` release validation.

### Changed

- Final HTML is now a creator-facing publication workbench rather than an engineering result page.
- Release build tooling reads `VERSION` dynamically and keeps candidate packages in `release_candidate_built / not_published` state until GitHub publication completes.
- Tracked real session identifiers are replaced by private regression aliases.

### Fixed

- Template-aware render idempotency, state projection drift, checker text/path confusion, PowerShell runtime pitfalls, responsive card overflow, CI version drift, Unicode Git paths, and hashed SVG line-ending drift.

### Known Limits

- Alpha, single-content, no automatic platform publishing or post-publication effect validation.

## 0.1.0-alpha.2

```text
Status: published alpha pre-release
Publish: published_to_github
```

### Fixed

- Removed real root `accounts/` account profiles from public Git tracking so GitHub automatic Source code archives do not make the project look like a single automotive creator workflow.
- Added `.gitignore` boundaries for root `accounts/` and `indexes/`.
- Reworked README examples away from automotive-specific first-screen prompts and private account links.
- Added AGENTS rules requiring public tag source boundary checks, not only uploaded release zip checks.

### Changed

- GitHub repository description and topics are now set for content creator discoverability.
- `0.1.0-alpha.2` supersedes `0.1.0-alpha.1` for public testing.

### Known Limits

This is still an alpha package, not a production workflow engine.

- External tester dry-run acceptance is still pending.
- External image provider APIs are not bundled.
- GitHub automatic Source code archives are cleaner in this release, but the uploaded public-release zip remains the recommended download.

## 0.1.0-alpha.1

```text
Status: superseded alpha pre-release
Publish: published_to_github
```

### Added

Initial alpha candidate for the Taoge creative workflow skill kit:

- Router, account onboarding, hotspot research, brief, draft, image plan, quality review, platform packaging, and final delivery builder docs.
- R1-R4 workflow governance, checker rules, image asset rules, and public release boundaries.
- P1-P5 productization pass for topic selection, quickstart, checker, samples, and release packaging.
- Public release package structure with `VERSION`, `public-manifest.yaml`, `release-checklist.md`, `INSTALL.md`, `UPDATE.md`, `RELEASE_NOTES.md`, and `NOTICE.md`.
- Community health files: `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, and issue templates.

### Changed

- Release package generation now writes `release-record.json` before zipping, so the record is included in the candidate package.
- `release-record.json` uses relative package paths and explicit `release_state=release_candidate_built`.
- Release validation checks version consistency and prevents early GitHub publication claims.

### Known Limits

- Superseded by `0.1.0-alpha.2` because the public Git tag source still contained real root account profile examples.
- External tester dry-run acceptance is still pending.
- External image provider APIs are not bundled.

