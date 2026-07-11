# Field Schema Check Report

```yaml
check_run_id: FIELD-SCHEMA-20260711-141532
schema_version: 0.1.0
exit_code: 0
overall_result: pass
blocker_count: 0
```

| Check ID | Group | Status | Evidence | Remediation |
|---|---|---|---|---|
| SCHEMA-REL-FILE | release_record | warning | release-record.json missing | Build public release before release schema validation. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-sample_id | sample_record | pass | sample-01-onboarding:sample_id | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-sample_goal | sample_record | pass | sample-01-onboarding:sample_goal | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-sample_status | sample_record | pass | sample-01-onboarding:sample_status | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-sample_persona | sample_record | pass | sample-01-onboarding:sample_persona | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-sample_type | sample_record | pass | sample-01-onboarding:sample_type | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-sample_level | sample_record | pass | sample-01-onboarding:sample_level | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-estimated_time | sample_record | pass | sample-01-onboarding:estimated_time | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-prerequisites | sample_record | pass | sample-01-onboarding:prerequisites | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-run_mode | sample_record | pass | sample-01-onboarding:run_mode | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-golden_path_prompt | sample_record | pass | sample-01-onboarding:golden_path_prompt | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-failure_prompt | sample_record | pass | sample-01-onboarding:failure_prompt | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-expected_output_summary | sample_record | pass | sample-01-onboarding:expected_output_summary | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-success_criteria | sample_record | pass | sample-01-onboarding:success_criteria | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-known_limitations | sample_record | pass | sample-01-onboarding:known_limitations | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-validator_command | sample_record | pass | sample-01-onboarding:validator_command | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-input_prompt_path | sample_record | pass | sample-01-onboarding:input_prompt_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-expected_behavior_path | sample_record | pass | sample-01-onboarding:expected_behavior_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-expected_artifacts_path | sample_record | pass | sample-01-onboarding:expected_artifacts_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-execution_trace_path | sample_record | pass | sample-01-onboarding:execution_trace_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-check_report_path | sample_record | pass | sample-01-onboarding:check_report_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-01-onboarding-machine_readable_report_path | sample_record | pass | sample-01-onboarding:machine_readable_report_path | Add required sample_record field. |
| SCHEMA-SAMPLE-ENUM-sample-01-onboarding-sample_status | sample_record | pass | sample-01-onboarding:sample_status=draft | Use allowed sample_status value. |
| SCHEMA-SAMPLE-ENUM-sample-01-onboarding-sample_type | sample_record | pass | sample-01-onboarding:sample_type=tutorial | Use allowed sample_type value. |
| SCHEMA-SAMPLE-ENUM-sample-01-onboarding-sample_level | sample_record | pass | sample-01-onboarding:sample_level=beginner | Use allowed sample_level value. |
| SCHEMA-SAMPLE-ENUM-sample-01-onboarding-run_mode | sample_record | pass | sample-01-onboarding:run_mode=human_interactive | Use allowed run_mode value. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-sample_id | sample_record | pass | sample-02-single-content-run:sample_id | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-sample_goal | sample_record | pass | sample-02-single-content-run:sample_goal | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-sample_status | sample_record | pass | sample-02-single-content-run:sample_status | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-sample_persona | sample_record | pass | sample-02-single-content-run:sample_persona | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-sample_type | sample_record | pass | sample-02-single-content-run:sample_type | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-sample_level | sample_record | pass | sample-02-single-content-run:sample_level | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-estimated_time | sample_record | pass | sample-02-single-content-run:estimated_time | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-prerequisites | sample_record | pass | sample-02-single-content-run:prerequisites | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-run_mode | sample_record | pass | sample-02-single-content-run:run_mode | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-golden_path_prompt | sample_record | pass | sample-02-single-content-run:golden_path_prompt | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-failure_prompt | sample_record | pass | sample-02-single-content-run:failure_prompt | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-expected_output_summary | sample_record | pass | sample-02-single-content-run:expected_output_summary | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-success_criteria | sample_record | pass | sample-02-single-content-run:success_criteria | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-known_limitations | sample_record | pass | sample-02-single-content-run:known_limitations | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-validator_command | sample_record | pass | sample-02-single-content-run:validator_command | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-input_prompt_path | sample_record | pass | sample-02-single-content-run:input_prompt_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-expected_behavior_path | sample_record | pass | sample-02-single-content-run:expected_behavior_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-expected_artifacts_path | sample_record | pass | sample-02-single-content-run:expected_artifacts_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-execution_trace_path | sample_record | pass | sample-02-single-content-run:execution_trace_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-check_report_path | sample_record | pass | sample-02-single-content-run:check_report_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-02-single-content-run-machine_readable_report_path | sample_record | pass | sample-02-single-content-run:machine_readable_report_path | Add required sample_record field. |
| SCHEMA-SAMPLE-ENUM-sample-02-single-content-run-sample_status | sample_record | pass | sample-02-single-content-run:sample_status=draft | Use allowed sample_status value. |
| SCHEMA-SAMPLE-ENUM-sample-02-single-content-run-sample_type | sample_record | pass | sample-02-single-content-run:sample_type=regression | Use allowed sample_type value. |
| SCHEMA-SAMPLE-ENUM-sample-02-single-content-run-sample_level | sample_record | pass | sample-02-single-content-run:sample_level=intermediate | Use allowed sample_level value. |
| SCHEMA-SAMPLE-ENUM-sample-02-single-content-run-run_mode | sample_record | pass | sample-02-single-content-run:run_mode=agent_simulated | Use allowed run_mode value. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-sample_id | sample_record | pass | sample-03-final-review-revision:sample_id | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-sample_goal | sample_record | pass | sample-03-final-review-revision:sample_goal | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-sample_status | sample_record | pass | sample-03-final-review-revision:sample_status | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-sample_persona | sample_record | pass | sample-03-final-review-revision:sample_persona | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-sample_type | sample_record | pass | sample-03-final-review-revision:sample_type | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-sample_level | sample_record | pass | sample-03-final-review-revision:sample_level | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-estimated_time | sample_record | pass | sample-03-final-review-revision:estimated_time | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-prerequisites | sample_record | pass | sample-03-final-review-revision:prerequisites | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-run_mode | sample_record | pass | sample-03-final-review-revision:run_mode | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-golden_path_prompt | sample_record | pass | sample-03-final-review-revision:golden_path_prompt | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-failure_prompt | sample_record | pass | sample-03-final-review-revision:failure_prompt | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-expected_output_summary | sample_record | pass | sample-03-final-review-revision:expected_output_summary | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-success_criteria | sample_record | pass | sample-03-final-review-revision:success_criteria | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-known_limitations | sample_record | pass | sample-03-final-review-revision:known_limitations | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-validator_command | sample_record | pass | sample-03-final-review-revision:validator_command | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-input_prompt_path | sample_record | pass | sample-03-final-review-revision:input_prompt_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-expected_behavior_path | sample_record | pass | sample-03-final-review-revision:expected_behavior_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-expected_artifacts_path | sample_record | pass | sample-03-final-review-revision:expected_artifacts_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-execution_trace_path | sample_record | pass | sample-03-final-review-revision:execution_trace_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-check_report_path | sample_record | pass | sample-03-final-review-revision:check_report_path | Add required sample_record field. |
| SCHEMA-SAMPLE-REQ-sample-03-final-review-revision-machine_readable_report_path | sample_record | pass | sample-03-final-review-revision:machine_readable_report_path | Add required sample_record field. |
| SCHEMA-SAMPLE-ENUM-sample-03-final-review-revision-sample_status | sample_record | pass | sample-03-final-review-revision:sample_status=draft | Use allowed sample_status value. |
| SCHEMA-SAMPLE-ENUM-sample-03-final-review-revision-sample_type | sample_record | pass | sample-03-final-review-revision:sample_type=failure_recovery | Use allowed sample_type value. |
| SCHEMA-SAMPLE-ENUM-sample-03-final-review-revision-sample_level | sample_record | pass | sample-03-final-review-revision:sample_level=intermediate | Use allowed sample_level value. |
| SCHEMA-SAMPLE-ENUM-sample-03-final-review-revision-run_mode | sample_record | pass | sample-03-final-review-revision:run_mode=agent_simulated | Use allowed run_mode value. |
| SCHEMA-REGSUITE-REQ-regression_suite_id | regression_suite | pass | regression_suite_id | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-suite_version | regression_suite | pass | suite_version | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-suite_status | regression_suite | pass | suite_status | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-suite_goal | regression_suite | pass | suite_goal | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-runner_id | regression_suite | pass | runner_id | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-runner_version | regression_suite | pass | runner_version | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-sample_validator | regression_suite | pass | sample_validator | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-replay_validator | regression_suite | pass | replay_validator | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-allowed_warning_policy | regression_suite | pass | allowed_warning_policy | Add required regression suite field. |
| SCHEMA-REGSUITE-REQ-maturity_target | regression_suite | pass | maturity_target | Add required regression suite field. |
| SCHEMA-REGSUITE-TEXT-fixture_id-_REG-001 | regression_suite | pass | fixture_id: REG-001 | Add required regression suite fixture text. |
| SCHEMA-REGSUITE-TEXT-fixture_id-_REG-002 | regression_suite | pass | fixture_id: REG-002 | Add required regression suite fixture text. |
| SCHEMA-REGSUITE-TEXT-fixture_id-_REG-003 | regression_suite | pass | fixture_id: REG-003 | Add required regression suite fixture text. |
| SCHEMA-REGSUITE-TEXT-allowed_warning_prefixes | regression_suite | pass | allowed_warning_prefixes | Add required regression suite fixture text. |
| SCHEMA-FD-TOKEN-html_builder_mode | final_delivery_template | pass | html_builder_mode | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-html_template_source | final_delivery_template | pass | html_template_source | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-final_delivery_status | final_delivery_template | pass | final_delivery_status | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-image_assets_status | final_delivery_template | pass | image_assets_status | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-source_research_run_id | final_delivery_template | pass | source_research_run_id | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-delivery_page_mode | final_delivery_template | pass | delivery_page_mode | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-cover_composition_status | final_delivery_template | pass | cover_composition_status | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-platform_cover_strategy | final_delivery_template | pass | platform_cover_strategy | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-cover_text_render_strategy | final_delivery_template | pass | cover_text_render_strategy | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-cover_asset_role | final_delivery_template | pass | cover_asset_role | Add required final_delivery template token. |
| SCHEMA-FD-TOKEN-cover_embeds | final_delivery_template | pass | cover_embeds | Add required final_delivery template token. |
| SCHEMA-FD-ENUMTOKENS-html_builder_mode | final_delivery_template | pass | html_builder_mode missing:  | Document all allowed html_builder_mode states in template. |
| SCHEMA-FD-ENUMTOKENS-final_delivery_status | final_delivery_template | pass | final_delivery_status missing:  | Document all allowed final_delivery_status states in template. |
| SCHEMA-FD-ENUMTOKENS-image_assets_status | final_delivery_template | pass | image_assets_status missing:  | Document all allowed image_assets_status states in template. |
| SCHEMA-PUBMAN-REQ-version | public_manifest | pass | version | Add required public manifest field. |
| SCHEMA-PUBMAN-REQ-release_channel | public_manifest | pass | release_channel | Add required public manifest field. |
| SCHEMA-PUBMAN-TEXT-release_state-_github_release_published | public_manifest | pass | release_state: github_release_published | Align public manifest publish state. |
| SCHEMA-PUBMAN-TEXT-publish_status-_published_to_github | public_manifest | pass | publish_status: published_to_github | Align public manifest publish state. |
| SCHEMA-PUBMAN-TEXT-human_approval_required-_false | public_manifest | pass | human_approval_required: false | Align public manifest publish state. |
