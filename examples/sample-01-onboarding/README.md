# Sample 01 - Onboarding

> sample_only: true  
> contains_real_account: false  
> goal: 验证没有账号时，总控能引导用户新建账号档案，而不是要求用户填写字段表。
> alpha_note: 本样例只验证首次建档入口，不验证真实内容生产或自动发布。

## How To Run

使用 `input-prompt.md` 的话术启动。

预期总控先生成 `entry_router_request`，再路由到 `account-onboarding`。账号档案确认后，回到 `propagation-router` 检查产品 / 活动对象。

## Sample Card

```yaml
sample_persona: 第一次下载 workflow 的创作者或外部 AI
sample_type: tutorial
sample_level: beginner
estimated_time: 5-8 minutes
prerequisites: none
run_mode: human_interactive
golden_path_prompt: 使用涛哥创作工作流，帮我新建一个汽车观察账号，并准备后续做一条内容。
failure_prompt: 帮我做内容。
expected_output_summary: 生成 entry_router_request，并提出 3 个以内口语化建档问题。
success_criteria: 不进入热点搜索；不要求用户填字段表；能说明为什么先建账号。
known_limitations: 本样例不验证真实热点调研、文案生成或最终 HTML。
validator_command: .\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-01-onboarding
```

## Expected Result

样例通过时，应能看到：

```text
entry_case=first_use_no_account
account_resolution_status=account_missing
entry_route=account-onboarding
human_prompt 是口语化问题
```

## Failure And Recovery

如果用户只说“帮我做内容”，系统也应识别为 `first_use_no_account` 或 `unknown_entry`，并给出安全启动方式：

```text
先建账号。
或先跑 sample。
或让用户选择已有账号。
```
