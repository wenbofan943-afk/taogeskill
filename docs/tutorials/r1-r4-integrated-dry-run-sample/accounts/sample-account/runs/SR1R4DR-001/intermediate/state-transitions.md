# State Transitions

| at | actor | action | from_status | to_status | output |
|---|---|---|---|---|---|
| 2026-07-07 | agent | acquire_run_lock | run_planned | run_active | manifest.yaml |
| 2026-07-07 | agent | complete_research | run_active | research_completed | intermediate/01-research-run.md |
| 2026-07-07 | agent | select_topic_for_sample | research_completed | topic_selected_for_brief | intermediate/02-topic-card.md |
| 2026-07-07 | agent | compile_brief | topic_selected_for_brief | brief_ready | intermediate/03-content-brief.md |
| 2026-07-07 | agent | write_draft | brief_ready | draft_ready | intermediate/04-draft.md |
| 2026-07-07 | agent | build_visual_assets_pending_external | draft_ready | visual_plan_ready | intermediate/05-visual-plan.md |
| 2026-07-07 | agent | quality_review | visual_plan_ready | review_pass_with_warnings | intermediate/06-quality-review.md |
| 2026-07-07 | agent | package_platforms | review_pass_with_warnings | platform_package_ready | intermediate/08-platform-package.md |
| 2026-07-07 | agent | build_final_delivery | platform_package_ready | html_ready | deliverables/final-delivery.html |
| 2026-07-07 | agent | release_run_lock | html_ready | run_completed_with_warnings | manifest.yaml |

