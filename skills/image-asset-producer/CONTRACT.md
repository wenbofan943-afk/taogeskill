# Image Asset Producer Contract

```yaml
skill_id: image-asset-producer
contract_version: 0.1.0
owner_project: taoge-creative-workflow
status: active
confirmed_scope: R3-C54-R3-C70
skill_type: internal_asset_producer
```

## Inputs

```yaml
required_artifacts:
  - image_prompt_set
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
next_skill: copywriting-quality-review
```

## Invariants

```text
No generated status without a local file.
No generated asset without generation record and sidecar.
No overwrite; rework increments asset version.
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
Image capability unavailable -> prompt_only without asking the user to repeat inputs.
High-risk manual source decision -> human_confirm.
```

## Acceptance Cases

```text
Codex generated no-text PIP with sidecar
deterministic overlay PIP with exact approved text
model text error falls back to deterministic overlay
non-Codex prompt_only contains exact text and placement
generated pseudo-evidence is rejected
```

## Open Source Boundary

Publish scripts and redacted fixtures. Do not publish real account assets, prompts, source screenshots, run records, or provider response IDs.
