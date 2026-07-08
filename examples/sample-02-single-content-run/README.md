# Sample 02 - Single Content Run

> sample_only: true  
> contains_real_account: false  
> goal: 验证选题确认后，内容链路能自动走到最终 HTML，而不是反复要求用户说“继续”。
> alpha_note: 本样例只验证脱敏主链路和降级口径，不证明真实热点质量、真实图片质量或真实发布效果。

## How To Run

使用 `input-prompt.md` 启动。样例假设账号档案和产品对象已确认。

## Sample Card

```yaml
sample_persona: 想确认主链路是否能自动到底的维护者或外部 AI
sample_type: regression
sample_level: intermediate
estimated_time: 8-12 minutes
prerequisites: sample account and sample product are treated as confirmed
run_mode: agent_simulated
golden_path_prompt: 给示例行业观察号做一条内容。账号档案认可，产品对象用 sample-public-interaction-tool。生成候选选题后，我选择 T-SAMPLE-001。
failure_prompt: 选题确认后，环境不能直接出图。
expected_output_summary: 选题确认后自动生成 Brief、draft、visual_plan、quality_review、platform_package 和 final-delivery.html。
success_criteria: 不要求用户回复继续写口播；图片不可生成时用 pending_external 和可复制 prompt 兜底。
known_limitations: 本样例不证明真实热点质量、真实图片美术质量或真实人工发布效果。
validator_command: .\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-02-single-content-run
```

## Expected Result

确认选题后，系统应按以下顺序自动推进：

```text
topic_card
-> content_brief
-> draft
-> visual_plan
-> quality_review
-> platform_package_input
-> platform_package
-> content_delivery_record
-> final-delivery.html
```

## Failure And Recovery

非 Codex 环境或不可出图时，不阻塞最终 HTML。预期结果是：

```text
image_status=pending_external
prompt_delivery_mode=html_copyable_prompt
HTML 展示插入位置、图片用途和可复制 prompt
```

