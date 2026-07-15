# Image Asset Producer Contract

```yaml
skill_id: image-asset-producer
contract_version: 0.4.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C54-R3-C80
skill_type: internal_asset_producer
```

## Inputs

```yaml
required_artifacts:
  - image_prompt_set
  - visual_need_analysis
  - visual_text_plan
  - session manifest
required_status: prompt_integrity_check=pass
source_path: accounts/{account_slug}/runs/{session_id}/intermediate/05-visual-plan.md
```

## Outputs

```yaml
artifacts:
  - image_generation_record
  - image_asset_set
  - image_metadata_sidecar
paths:
  - assets/images/generation-records/
  - assets/images/metadata/
  - assets/images/{asset_id}.png
status_fields:
  - image_status
  - image_assets_status
required_handoff_fields:
  - image_asset_set_id
  - visual_plan_id
  - visual_text_plan_id
  - content_source_id
  - content_origin
  - image_task_id
  - source_prompt_id
  - generation_attempt_id
  - provider_outcome_status
  - postprocess_status
  - reconciliation_status
  - interruption_recovery_policy
  - image_status
  - image_assets_status
  - artifact_path
  - next_skill
next_skill: copywriting-quality-review
```

## Invariants

```text
No generated status without a local file.
All accepted codex_builtin_image2 tasks receive one terminal generation record; news_evidence_pip tasks are owned by the sibling R6 producer and never enter Image 2.
actual_provider_execution_count is execution evidence, never a budget.
No generated asset without generation record and sidecar.
No overwrite; rework increments asset version.
Provider outcome is persisted before local post-processing starts.
Interrupted post-processing reconciles existing provider output before any retry; succeeded/outcome_unknown never blind-retries.
Checkers are read-only except for their own reports; manifest completion belongs to an explicit finalize command.
Observed regression counts never become product constants; expected counts derive from accepted tasks and selection/provenance.
forbidden has no rendered text.
required contains approved text or is blocked/prompt_only.
Evidence source-native assets remain linked to type, id, and path.
Cover final assets are not produced here.
```

## Auto Next And Failure

```text
Assets generated or honestly downgraded -> copywriting-quality-review.
Prompt contradiction -> image-prompt-compiler.
Visual decision/source contradiction -> static-visual-director.
Image capability unavailable for a current generated-context production task -> `waiting_assets` without asking the user to repeat inputs. `no_provider` and `reuse_only` are explicit test profiles only and cannot change the task source class or claim completion.
Unresolved source/claim risk -> return to static-visual-director and reject or repair the candidate before it can be accepted.
Aesthetic preference -> finish generation first, then handle it as revision input; it is not a pre-generation confirmation gate.
```

## Acceptance Cases

```text
Codex generated no-text PIP with sidecar
five accepted tasks create five generation records; no task is skipped after four
interrupted local copy finds the existing provider output and resumes without a second provider attempt
completed session prepare returns skipped_completed and does not regress manifest state
deterministic overlay PIP with exact approved text
model text error falls back to deterministic overlay
non-Codex prompt_only contains exact text and placement
generated pseudo-evidence is rejected
```

## Open Source Boundary

Publish scripts and redacted fixtures. Do not publish real account assets, prompts, source screenshots, run records, or provider response IDs.

## R3-C111–C124 Output Verification

Every returned asset records `actual_width_px`, `actual_height_px`, reduced actual ratio and `aspect_ratio_verification_status`. The producer verifies the result against the typed `visual_insert` canvas and `presentation_mode`; a mismatched asset cannot become delivery-ready. Provider task count covers external base-generation tasks only. Deterministic overlay, cover layout, crop and derived preview do not create new provider calls.
