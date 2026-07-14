# Direct Content Intake Contract

```yaml
skill_id: direct-content-intake
contract_set_version: r6-content-evidence-v0.1
contract_version: 0.1.0
owner_project: taoge-creative-workflow
status: compiled_local_validated
confirmed_scope: R6-C01-R6-C06,R6-C16-R6-C19
skill_type: producer
```

## 1. Triggers

Trigger when the user supplies a draft and requests direct delivery, polishing, evidence enrichment, or an explicit radar reconsideration. Do not trigger for a normal radar-selected topic.

## 2. Preconditions

Require a validated account identity binding, frozen session account snapshot, session root, literal source draft, and stable draft digest.

## 3. Inputs

```yaml
required_artifacts: [account_identity_binding, account_session_snapshot, user_supplied_draft]
required_fields: [session_id, account_id, account_slug, account_display_name, direct_intent, revision_policy]
```

## 4. Outputs

```yaml
artifacts: [direct_content_intake, original_draft, direct_content_card]
paths:
  - inputs/00-direct-content-intake.json
  - inputs/user-supplied-draft.md
  - intermediate/01-direct-content-card.json
status_field: direct_content_status
```

## 5. Field Contract

The card carries `intake_id`, `content_source_id`, account identity, original draft artifact ID/path/SHA256, `content_origin=user_supplied_draft`, `topic_origin=direct_user_input`, `direct_intent`, `revision_policy`, `claim_map`, `human_gate`, `next_skill`, and producer/consumer lineage.

## 6. Status Contract

```text
direct_content_ready
needs_rewrite_confirmation
blocked
```

Status is monotonic within a revision. A completed card is revised through a new revision marker, never silently overwritten.

## 7. Routing

`direct_to_radar` routes to `hotspot-topic-research`; other ready intents route to `content-brief-compiler`; a structural rewrite without recorded permission routes to `human_confirm`.

## 8. Human Gates

Ask once only when the requested structural rewrite can change the thesis, audience, accusation strength, factual certainty, or CTA and permission is absent. Do not gate routine full-chain continuation.

## 9. Invariants

Do not fabricate `topic_card`, `topic_id`, or `source_research_run_id`. Do not count this run as radar coverage. Preserve the original draft byte source and digest. Continue through the compiled R6-B01 structure, beat, script-review, revision-decision, visual-coverage, and alignment contracts.

## 10. Failure And Recovery

Missing account identity returns to account startup. Draft digest mismatch creates a new intake revision. Missing required direct fields blocks before Brief compilation. Repeated validation is read-only and byte-stable.

## 11. Trace And Privacy

Record producer, consumer, input/output IDs, digests, status, gate, and next skill in the execution trace. Real drafts and account data stay in ignored private production paths.

## 12. Acceptance

Positive fixtures cover direct delivery and explicit radar routing. Negative fixtures cover fake topic lineage, missing digest, and structural rewrite without a human gate. The dedicated R6 checker and field-schema gate must pass.
