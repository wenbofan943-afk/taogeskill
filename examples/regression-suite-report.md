# Regression Suite Report

```yaml
suite_id: sample-regression-suite-v0.1
suite_version: 0.1.0
runner_id: regression_suite_checker
exit_code: 0
overall_result: pass_with_warnings
fixture_count: 3
blocker_count: 0
warning_count: 9
maturity_impact: regression_fixture_ready_with_warnings
```

| Fixture | Sample | Result | Replay | Warnings | Blockers |
|---|---|---|---|---|---|
| REG-001 | sample-01-onboarding | pass_with_warnings | pass_with_warnings | declared_only_artifacts:1; trace_step_warnings:5; agent_assist_level_observed:unknown |  |
| REG-002 | sample-02-single-content-run | pass_with_warnings | pass_with_warnings | declared_only_artifacts:9; trace_step_warnings:10; agent_assist_level_observed:medium |  |
| REG-003 | sample-03-final-review-revision | pass_with_warnings | pass_with_warnings | declared_only_artifacts:3; trace_step_warnings:6; agent_assist_level_observed:unknown |  |

## Result

This suite is readonly. It runs sample checks and trace replay, but it does not execute AI writing, research, image generation, publishing, or artifact repair.
