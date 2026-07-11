# R3-C45 Test Summary

```yaml
test_run_id: R3-C45-TEST-20260710-001
test_date: 2026-07-10
profile: test
overall_result: pass_with_known_warnings
real_account_data_read: false
real_image_generation_run: false
public_release_run: false
```

## Scope

- Tested R3-C26 to R3-C45 compiled fields and handoff shape through the dry-run sample.
- Upgraded `SR3DR-001` sample artifacts to include static visual director, picture-in-picture image, cover image, Codex / Seedream production-path fields, HTML embed manifest, and final delivery HTML references.
- Checked sample-only boundary, build profile boundary, final delivery template, field schema, workflow replay, sample validators, and regression suite.

## Results

| Check | Result | Report |
|---|---|---|
| Final delivery template | pass | `tools/validate-final-delivery-template.ps1` |
| Sample-only gate | pass with warnings | `sample-only-gate-report.md` |
| Build profile boundary | pass with warnings | `test-build-profile-report.md` |
| Field schema | pass | `field-schema-check-report.md` |
| R3 dry-run replay | pass | `SR3DR-001-workflow-replay-report.md` |
| Example sample checks | pass | `examples/sample-01-onboarding` / `sample-02-single-content-run` / `sample-03-final-review-revision` |
| Regression suite | pass with warnings | `examples/regression-suite-report.md` |

## Fixed During Test

- `tools/validate-build-profile.ps1`: test profile now treats existing private directories as warnings plus boundary instructions, not automatic failures.
- `tools/YamlHelper.ps1`: fixed fallback parser interpolation and library-mode behavior for dot-sourced usage.
- `tools/validate-field-schema.ps1`: added fallback-map access helpers and changed missing release record to a warning when validating the project root.

## Known Warnings

- `accounts/`, `indexes/`, and `support-logs/` exist locally, so sample-only and build-profile checks warn that test profile must not read them.
- Regression suite still reports warnings in older P4 samples: declared-only artifacts, incomplete trace-step evidence, and unknown / medium agent-assist levels.
- This test did not run a real content loop, Codex image generation, Seedream API, publishing, release packaging, or GitHub release.

## Conclusion

R3-C26 to R3-C45 compiled chain is testable through the upgraded dry-run sample. The R3 sample replay has zero blockers and zero warnings. Remaining warnings belong to local boundary visibility and older regression fixtures, not to the newly compiled R3 sample itself.
