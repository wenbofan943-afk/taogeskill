# News Evidence PIP Contract

```yaml
skill_id: news-evidence-pip
contract_set_version: r6-content-evidence-v0.2
contract_version: 0.2.0
owner_project: taoge-creative-workflow
status: compiled_local_validated
confirmed_scope: R6-C07-R6-C19+R6-C51-R6-C60
skill_type: source_asset_producer
```

## 1. Triggers

Trigger only for an accepted R3 visual task with `visual_job=evidence_support`, `evidence_requirement=source_bound`, and a claim type of `factual_claim`, `quote`, or `statistic`.

## 2. Preconditions

Require an exact claim span, public source URL and publisher, visible target/quote, account evidence visual grammar, and explicit screenshot rights/privacy review fields. No login, paywall, private page, or bulk collection.

## 3. Inputs

```yaml
required_artifacts: [claim_card, source_record, source_capture_record, evidence_claim_binding, evidence_anchor_annotation_request, evidence_anchor_annotation, semantic_fact_bindings, account_session_snapshot]
required_fields: [claim_id, source_id, capture_id, binding_id, canonical_url, selected_target, claim_evidence_status, attempt_number, attempt_history, semantic_parity_result]
```

## 4. Outputs

```yaml
artifacts: [evidence_screenshot_pip, evidence_sidecar, image_asset_record]
paths:
  - assets/images/source-captures/{capture_id}.png
  - assets/images/evidence-pip/{pip_id}.svg
  - assets/images/metadata/{pip_id}.json
status_field: evidence_pip_status
next_skill: copywriting-quality-review
```

## 5. Four-Layer Status

Keep `source_access_status`, `capture_integrity_status`, `claim_evidence_status`, and `publish_risk_status` independent. A browser or network success cannot set the other layers to pass.

## 6. Source Contract

`image_production_path=source_capture` is mandatory. Persist canonical URL, publisher, title, publication date when available, accessed/captured timestamps, viewport, target selector/quote, local path, and SHA256. Image 2 output is forbidden as a source capture.

## 7. Binding Contract

Each PIP binds exactly one claim, one source, and one capture. `evidence_support` requires a `supported` relation. `not_enough_info`, `refuted`, `not_checked`, or uncontextualized `contested` results must downgrade or block.

## 8. Render Contract

The deterministic asset visibly separates the source region/source strip from the creator commentary strip. Source identity and evidence relation cannot be hidden by account styling. Renderer/template digests participate in idempotency.

The immutable original capture is the parent of a deterministic annotated asset. Materialize that child through `materialize_evidence_annotation`; the producer computes its overlay digest and output hash after writing the asset, so callers may not prefill either value. Every emphasis region uses normalized coordinates and a declared style. Typed facts compare claim, visible quote, overlay, asset summary, and HTML summary; overall precedence is `mismatch > not_assessed > match`, and only all required `match` values are delivery eligible. OCR critical facts require a recorded Codex or human visual review before they may be `match`.

## 9. Rights And Privacy Gates

`copyright_review_status=approved` and `privacy_review_status=approved` are mandatory for screenshot evidence. A disclaimer does not satisfy either. Failed gates route to a text source card, omission, or human review.

## 10. Side Effects And Recovery

Persist capture attempt before browser launch and outcome/hash or error category immediately after return/start failure. Persist annotation `started` before writing its child asset, then outcome/output hash before any PIP or delivery derivation. Reconcile matching completed capture and annotation outputs before retry. A failed or interrupted attempt increments `attempt_number` and remains in `attempt_history[]`; it is not erased by recovery. Exit zero without a verified file is `capture_integrity_error`; do not blindly retry policy or rights failures.

## 11. Trace And Privacy

Record claim/source/capture/binding/PIP IDs, hashes, status transitions, browser outcome, and producer/consumer. Real captures stay in private runs and are excluded from Git and releases.

## 12. Acceptance

Positive fixtures prove public local-source capture, reconciliation, source-only rendering, source/commentary separation, and traceable handoff. Negative fixtures cover insufficient evidence, generated-image impersonation, missing source identity, rights/privacy blocks, and capture hash mismatch.
