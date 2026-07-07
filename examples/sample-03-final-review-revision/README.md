# Sample 03 - Final Review Revision

> sample_only: true  
> contains_real_account: false  
> goal: 验证最终 HTML 后的局部返工能力，例如只改标题、重做首屏图、加一张画中画或导出转交包。
> alpha_note: 本样例只验证最终交付后的局部返工路由，不代表真实生产 runner。

## How To Run

使用 `input-prompt.md`。样例假设 `final-delivery.html` 已经生成。

## Sample Card

```yaml
sample_persona: 想验证最终交付后局部返工的人或维护者
sample_type: failure_recovery
sample_level: intermediate
estimated_time: 8-12 minutes
prerequisites: final-delivery.html already exists
run_mode: agent_simulated
golden_path_prompt: 最终 HTML 我看了，文案可以。帮我再加一张画中画，放在第二段后面；抖音标题也换得更像观点一点。
failure_prompt: 画中画太少，再加一张。
expected_output_summary: 不重跑热点；新增 image_task / image_asset_id；局部更新平台标题；重建 final-delivery.html。
success_criteria: 旧图片资产不被覆盖；revision_path 指向 visual_plan / platform_package；HTML 重建后仍可追溯。
known_limitations: 本样例不验证真实生成图质量，只验证资产链路和局部返工路由。
validator_command: .\tools\validate-sample-run.ps1 -SamplePath .\examples\sample-03-final-review-revision
```

## Expected Result

系统应识别这是最终交付后的局部返工，不应重跑热点和选题。

## Failure And Recovery

用户只说“画中画太少”时，系统不能覆盖旧图，也不能重跑热点。预期恢复动作：

```text
新增 image_task
新增 prompt_card
新增 image_generation_record
新增 image_asset_id
重建 html_embed_manifest
重新生成 final-delivery.html
```
