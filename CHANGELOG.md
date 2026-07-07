# Changelog

This project follows a Keep a Changelog style structure and semantic versioning vocabulary, while still treating `0.1.0-alpha.1` as a local public release candidate until GitHub publication is completed.

## 0.1.0-alpha.1

```text
Status: local alpha candidate
Publish: not_published
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

This version is not a GitHub release until `release_record.publish_status=published_to_github`.

- No remote, tag, push, GitHub Release page, or CI runner has been created.
- External tester dry-run acceptance is still pending.
- External image provider APIs are not bundled.
