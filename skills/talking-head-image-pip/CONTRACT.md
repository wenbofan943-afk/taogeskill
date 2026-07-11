# Talking Head Image Pip Contract

> 状态：confirmed_with_r3_static_visual_runtime
> contract_version：0.5.0
> contract_set_version：r3-asset-runtime-v0.1  
> 对应 skill：`skills/talking-head-image-pip/SKILL.md`  
> 编译门禁：涛哥已确认 R3-C01 到 R3-C53，允许按本合同编译对应 `SKILL.md`。

---

## 1. 身份

```yaml
skill_id: talking-head-image-pip
skill_name: 口播画中画视觉规划
contract_version: 0.5.0
contract_set_version: r3-asset-runtime-v0.1
owner_project: taoge-creative-workflow
status: confirmed
confirmed_by: taoge
confirmed_at: 2026-07-07
```

一句话职责：

```text
把通过最低门槛的口播草案先编译为静态视觉编导方案，再拆成留存任务驱动的画中画 / 封面底图资产链，并产出 `static_visual_director_plan -> visual_plan -> image_prompt_set -> image_generation_record -> image_asset_set`。
```

---

## 2. 触发条件

```yaml
triggers:
  user_intent:
    - 做画中画
    - 口播配图
    - 给这段口播出画面
  upstream_artifact_status:
    - draft_status = draft_created
    - hook_score >= 7
  allowed_manual_commands:
    - 重做首屏画中画
    - 外部工具生成
    - 先交付无图版
```

不得触发：

```text
没有 draft。
推荐 Hook 低于 7 分。
草案内容形式不是短视频口播。
```

---

## 3. 前置条件

```yaml
preconditions:
  required_artifacts:
    - draft
    - content_brief
  required_fields:
    - draft_id
    - brief_id
    - recommended_hook
    - five_second_retention_design
    - script
    - product_claim_boundary
  required_status:
    - draft_status = draft_created
```

---

## 4. 输入合同

```yaml
inputs:
  artifact_type:
    - draft
    - content_brief
  source_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/04-draft.md
    - accounts/{account_slug}/runs/{session_id}/intermediate/03-content-brief.md
  required_fields:
    - script
    - recommended_hook
    - first_screen_visual_task
    - product_claim_boundary
    - must_not_say
  validation_rules:
    - 画中画必须服务留存任务，不做装饰图
    - 首屏图必须优先服务前 5 秒
    - 不虚构产品界面或真实证据
    - R1CHK-017：生成图片的 prompt 不得缩水成短关键词，必须保留完整提示词结构
```

---

## 5. 输出合同

```yaml
outputs:
  artifact_type:
    - visual_plan
    - static_visual_director_plan
    - image_prompt_set
    - image_generation_record
    - image_asset_set
    - image_metadata_sidecar
  target_path:
    - accounts/{account_slug}/runs/{session_id}/intermediate/05-visual-plan.md
    - accounts/{account_slug}/runs/{session_id}/assets/images/image-assets.md
    - accounts/{account_slug}/runs/{session_id}/assets/images/generation-records/
    - accounts/{account_slug}/runs/{session_id}/assets/images/metadata/
    - accounts/{account_slug}/runs/{session_id}/assets/images/
  required_fields:
    - visual_plan_id
    - static_visual_director_plan_id
    - draft_id
    - image_prompt_set_id
    - image_asset_set_id
    - image_asset_type
    - cover_asset_role
    - image_production_path
    - image_generation_decision
    - prompt_delivery_mode
    - external_model_payload_path
    - visual_budget
    - beats
    - retention_task
    - insert_position
    - prompt
    - negative_prompt
    - prompt_integrity_check
    - prompt_used_full
    - acceptance_criteria
    - generation_run_id
    - generation_attempt_id
    - provider_mode
    - input_payload_path
    - image_status
    - image_assets_status
    - metadata_sidecar_path
    - visual_plan_status
    - next_skill
  status_field:
    - visual_plan_status
    - image_assets_status
  downstream_artifact: quality_review
```

---

## 6. 路径合同

```yaml
path_contract:
  session_root: accounts/{account_slug}/runs/{session_id}
  input_paths:
    - intermediate/04-draft.md
  output_paths:
    - intermediate/05-visual-plan.md
    - assets/images/image-assets.md
    - assets/images/{asset_id}.png
```

图片可以是已生成、待外部生成或生成失败，但状态必须明确。

### R3 图片资产合同

每篇口播必须先计算视觉预算：

```text
30 秒以内：1 required + 1 optional。
30-60 秒：2 required + 1-2 optional。
60-90 秒：3 required + 1-2 optional。
90 秒以上：3-4 required，超出必须说明留存任务。
```

每张 required 图片必须有：

```text
image_task_id
beat_id
retention_task
insert_after_text
insert_before_text
source_prompt_id
generation_run_id
image_status
```

每次生成 / 待外部生成 / 失败 / 人工上传必须有 `image_generation_record`。  
`image_status=generated` 时必须有本地 `asset_path` 和 `metadata_sidecar_path`。  
图片重做不得覆盖旧 `image_asset_id`，必须新建 asset，并用 `supersedes_asset_id` 追溯旧图。

### R3 静态视觉编导与生产路径合同

每篇内容必须先生成 `static_visual_director_plan`，再生成 prompt：

```text
static_visual_director_plan_id
visual_role_map
visual_language
style_anchor
composition_strategy
cover_strategy_hint
image_asset_type_plan
static_visual_director_status
```

每张图片必须先标记 `image_asset_type`：

```text
picture_in_picture_image
cover_image
```

并标记 `cover_asset_role`：

```text
picture_in_picture_image -> not_applicable
cover_image 底图 -> cover_background_asset
```

本 skill 不生产 `cover_composited_asset` 或 `platform_cover_asset`；它们由 `cover-design-compiler` 生产。

每张图片必须再标记 `image_production_path`：

```text
codex_image2_render
seedream_prompt_delivery
manual_upload
not_available
```

Codex 环境可调用内置 image 时，required 图片进入 `codex_image2_render`，`image_generation_decision=render_now`。非 Codex 环境或不可出图时，进入 `seedream_prompt_delivery`，`image_generation_decision=deliver_prompt_only`，必须输出 `prompt_delivery_mode=html_copyable_prompt / external_model_payload` 和 `external_model_payload_path`。

不得把 `cover_image` 当普通画中画处理；封面底图必须能被 `cover-design-compiler` 引用，但不得冒充可上传成品。

### R1 prompt 完整度合同

每张进入 `image_prompts` 或实际出图的图片，都必须保留完整 prompt 卡，不得只保存一句素材关键词。

每张图至少包含：

```text
留人任务
口播语义
画面类型
为什么值得生成
不用这张图会损失什么
主体动作
场景环境
镜头 / 构图
光线 / 情绪
字幕安全区
五槽提示词：Scene / Subject / Important Details / Use Case / Constraints
负面提示
验收标准
prompt_integrity_check：pass / fail
```

如果任一核心层缺失：

```text
visual_plan_status = visual_plan_needs_fix
next_skill = talking-head-image-pip
不得进入 copywriting-quality-review
```

实际调用 image 生成时，`prompt_used` 必须是完整 prompt 或可追溯到完整 prompt_id；不得只传短关键词版本。

---

## 7. 自动推进规则

```yaml
auto_next:
  when_pass:
    - visual_plan_status = visual_plan_pass
  next_skill:
    visual_plan_pass: copywriting-quality-review
  forbidden_human_prompt:
    - 是否进入质检？
    - 是否继续？
```

`visual_plan` 通过后自动进入联合质检。  
如果最终交付阶段要求实际图片，图片缺失不伪装，标记 `pending_external`。

---

## 8. 人类门禁

```yaml
human_gates:
  - gate_id: visual_strategy_choice
    trigger: 首屏图存在明显策略取舍
    reason: 审美和传播策略会影响前 5 秒留存
    recommended_action: 推荐一个默认方案，允许用户改首屏方向
    human_reply_examples:
      - 按推荐继续
      - 重做首屏画中画
      - 不要产品界面
    auto_next_after_reply: talking-head-image-pip

  - gate_id: image_generation_unavailable
    trigger: 当前环境无法出实际图片
    reason: 最终交付必须区分提示词和实际图片
    recommended_action: 标记 pending_external，保留提示词和插入位置
    human_reply_examples:
      - 用外部工具生成
      - 先交付无图版
    auto_next_after_reply: copywriting-quality-review 或 final-delivery-builder
```

---

## 9. 失败处理

```yaml
failure_modes:
  missing_draft:
    recovery_action: 回到 copywriting-draft-writer
  hook_low_score:
    recovery_action: 回到 draft 重写前 5 秒
  decorative_visual:
    recovery_action: 删除该 beat，不生成提示词
  prompt_integrity_failed:
    recovery_action: visual_plan_status = visual_plan_needs_fix，补完整 prompt 卡后再出图
  product_misleading:
    recovery_action: 改成隐喻图或回到 Brief 修边界
  image_unavailable:
    recovery_action: image_status = pending_external / generation_failed
  generated_missing_sidecar:
    recovery_action: image_status 不得进入最终 HTML，补 metadata_sidecar 或改为 generation_failed
  asset_overwrite_attempt:
    recovery_action: 新建 image_asset_id，旧资产标 rejected / superseded
  r3_sample_gate_failed:
    recovery_action: 停止批量出图，回补最小资产链
```

---

## 10. 透明度记录

```yaml
execution_trace:
  required: true
  skill_defined:
    - static_visual_director_plan 编译
    - draft -> visual_plan
    - image_asset_type 判定
    - cover_asset_role 判定
    - image_production_path 判定
    - retention_task 分配
    - image_generation_record 记录
    - metadata_sidecar 写入
    - image_asset_set 状态汇总
    - image_status 标记
  environment_capability:
    - image_generation
  manual_fallback:
    - pending_external
```

---

## 11. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| happy_path | draft_created，hook_score >= 7 | 输出 visual_plan，自动质检 |
| low_hook | hook_score < 7 | 回到 draft，不做画中画 |
| first_screen | 首屏图只装饰 | 重写首屏图任务 |
| short_prompt | prompt 只有素材关键词 | visual_plan_needs_fix，不允许出图或进入质检 |
| no_image_env | 环境不能出图 | 标 pending_external，不假装有图 |
| product_ui_risk | 图暗示未实现功能 | 阻断并改隐喻图 |
| generated_missing_sidecar | 图片文件存在但无 sidecar | 不进入最终展示，补 sidecar 或标 generation_failed |
| overwritten_asset | 重做图片覆盖旧文件 | 判失败，必须新建 image_asset_id |

---

## 12. 开源边界

```yaml
open_source_boundary:
  safe_to_publish:
    - 合同
    - sample visual_plan
    - sample image prompt
  must_redact:
    - 真实图片资产
    - 未授权素材
  sample_required:
    - examples/sample-run/intermediate/05-visual-plan.md
    - examples/sample-run/assets/images/image-assets.md
```

---

## 13. 待确认点

| 问题 | 推荐结论 |
|---|---|
| 每张图是否必须有 retention_task | 是 |
| 提示词是否等于最终图片 | 否 |
| 视觉方案通过后是否自动进质检 | 是 |
