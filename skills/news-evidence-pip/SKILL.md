---
name: news-evidence-pip
description: Bind a selected factual claim, quotation, or statistic to a public source, persist a recoverable browser capture, and render a traceable evidence picture-in-picture asset with visibly separate source facts and creator interpretation. Use when R3 selects a source-bound evidence visual; never use Image 2 to imitate a news or data screenshot.
---

# News Evidence PIP

## Role

Produce a source-derived evidence PIP for one selected `factual_claim`, `quote`, or `statistic`. This skill is a branch of R3 visual production, not a hotspot crawler, general fact-checker, browser archive service, or image-generation skill.

## Read First

1. Read the selected claim card, visual task, account snapshot, and `evidence_visual_grammar`.
2. Read the R6 product contract and `skills/talking-head-image-pip/CONTRACT.md` evidence branch.
3. Validate against `templates/schema/r6/news-evidence-pip.v0.1.schema.json`.
4. Use `tools/invoke-r6-source-capture.ps1` for public-page capture and `tools/invoke-r6-content-evidence.ps1` for validation/rendering.

## Preconditions

Require one precise claim, one public `http` or `https` source, publisher, canonical URL, access time, a visible target or quote, and a selected R3 task with `disposition=use_source_evidence`. Do not capture login, paywalled, private, personal-profile, or bulk-list pages. `capture_mode=new_capture` uses the capture runtime; `reuse_verified_capture` requires an existing current claim/source binding, capture hash, captured time, freshness verdict, and rights/privacy eligibility, and does not create a new capture task or attempt.

## Separate Four Decisions

Record these independently:

```text
source_access_status      whether the page was accessible at capture time
capture_integrity_status whether screenshot, URL, target, time, and hash are bound
claim_evidence_status    supported / refuted / not_enough_info / contested / not_checked
publish_risk_status      approved / review_required / blocked
```

A successful screenshot is not proof that a claim is true. `not_enough_info` is a valid result and must not be promoted to `evidence_support`.

## Capture With Reconciliation

Before opening the browser, persist `capture_attempt` with source ID, URL, output path, viewport, and start time. After the browser returns, persist outcome, file path, file hash, and error category before cropping, overlay, or copy operations.

On retry, reconcile an existing successful record and matching file hash first. Reuse it byte-for-byte; do not blindly revisit the source. A changed or missing completed file must create a new revision, not overwrite a completed record invisibly. Failed or interrupted attempts increment `attempt_number` and remain summarized in `attempt_history[]` after a successful recovery.

## Rights And Privacy

Keep the smallest necessary visible region, retain source identity, and avoid unrelated personal information. `copyright_review_status` and `privacy_review_status` must both be `approved` before a screenshot can become `evidence_support`. A disclaimer such as “来自网络” never bypasses these gates.

If rights or privacy are unresolved, downgrade to a text source card or omit the screenshot. Do not treat user publication responsibility as permission to mislabel the asset.

## Render Deterministically

Render from the captured source asset; never call Image 2 for a news, announcement, quote, or data screenshot. The result must visibly contain:

```text
source fact area and source strip: publisher, title/date, capture date
creator interpretation strip: explicitly labeled with the account's commentary label
trace data in the sidecar: claim, source, capture, binding, output hash
```

The account grammar controls typography and color roles but cannot hide the publisher, alter the evidence relation, or make creator commentary look like source text.

## Validate And Route

Run the deterministic validator before and after render. Only an eligible `evidence_support` bundle may produce the evidence SVG. Unsupported, contested-without-context, unverified, rights-blocked, privacy-blocked, or generated-image inputs must fail or downgrade honestly.

After success, update the R3 visual plan and asset record, then route to `copywriting-quality-review`. The final delivery card must reference the evidence asset, capture record, binding, and source record; it must not claim that Image 2 generated the source.

## Completion

Complete only when the capture record, binding, rendered asset, sidecar, hashes, status projection, and execution trace agree. A browser exit code of zero without a verified screenshot file is `capture_integrity_error`, not success.

Real captures remain under private account runs and must never enter public fixtures, Git history, release archives, or generated source-code packages.
