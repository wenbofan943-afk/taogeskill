# hotspot-copywriting-research CONTRACT

> contract_status: compatibility_entry  
> skill_type: compatibility_router  
> owner: 涛哥创作工作流  
> boundary: 只做旧唤醒词兼容转发，不生产正式内容交接物。

---

## 1. Purpose

`hotspot-copywriting-research` 是旧入口兼容 skill。它存在的目的不是继续承载完整热点文案流程，而是把旧唤醒词安全转交给当前拆分后的专项 skill。

它必须防止两类误用：

```text
1. 外部 AI 读到旧 skill 后，以为这里仍能直接跑完整生产链路。
2. 兼容入口绕过 account_profile、product_profile / campaign_profile、research_run_id 和标准交接物链路。
```

---

## 2. Trigger

当用户使用旧说法或模糊说法时触发：

```text
涛哥 skill
跑热点 skill
热点文案
找热点写文案
按账号母题做内容
自媒体传播
dbskill 质检
```

---

## 3. Inputs

```text
user_intent
current_stage
current_artifact
account_profile_status
product_or_campaign_profile_status
research_run_id
```

如果这些输入不完整，本 skill 不自行补写内容，只转交 `propagation-router` 判断入口、账号、对象和恢复状态。

---

## 4. Outputs

本 skill 只允许输出 `router_handoff`。

```text
contract_set_version
compatibility_status
router_handoff_to
handoff_reason
next_skill
human_gate
execution_trace_update
```

允许值：

```text
compatibility_status: handoff_only / blocked_legacy_direct_run
human_gate: no / inherited_from_target_skill
next_skill:
  propagation-router
  hotspot-topic-research
  content-brief-compiler
  copywriting-draft-writer
  talking-head-image-pip
  copywriting-quality-review
  platform-packaging-adapter
  final-delivery-builder
```

---

## 5. Routing Table

| User intent | router_handoff_to | Reason |
|---|---|---|
| 不知道下一步 / 涛哥创作工作流 / 涛哥 skill | `propagation-router` | 先判断入口、账号、对象、恢复和样例模式 |
| 找热点 / 今日选题 / 热点评分 | `hotspot-topic-research` | 正式热点研究只由 topic skill 生产 |
| 已经选题 | `content-brief-compiler` | 从 selected topic_card 进入 Brief |
| 已有 Brief 要写稿 | `copywriting-draft-writer` | Brief 到口播草案 |
| 要画中画 | `talking-head-image-pip` | 图片资产链由 R3 skill 承载 |
| 能不能发 / 像不像涛哥 / dbskill 质检 | `copywriting-quality-review` | 质检由 review skill 承载 |
| 要平台标题 / 描述 / 话题 | `platform-packaging-adapter` | 分发包装由 packaging skill 承载 |
| 要最终 HTML / 转交包 | `final-delivery-builder` | 最终交付由 delivery skill 承载 |

---

## 6. Forbidden Behavior

```text
不得生成 research_run_record。
不得生成 topic_card。
不得生成 content_brief。
不得生成 draft。
不得生成 visual_plan。
不得生成 image_prompt_set。
不得生成 quality_review。
不得生成 platform_package。
不得生成 final_delivery。
不得出图。
不得自动发布。
不得登录平台。
不得自动评论、私信或互动。
不得改公开互动分析工具代码、服务器、数据库、license、积分或发版链路。
```

---

## 7. Failure Handling

| Case | Required behavior |
|---|---|
| 用户要求旧入口直接一口气产出完整内容 | 输出 `compatibility_status=blocked_legacy_direct_run`，转 `propagation-router` |
| 账号 / 产品对象缺失 | 转 `propagation-router` 或 `account-onboarding`，不得直接跑热点 |
| 已有 current_artifact 但不清楚阶段 | 转 `propagation-router` 读取 manifest / execution_trace |
| 用户明确要质检已有文案 | 转 `copywriting-quality-review` |

---

## 8. Example Handoff

```yaml
contract_set_version: r1-contract-set-v0.1
compatibility_status: handoff_only
router_handoff_to: propagation-router
handoff_reason: old_entry_phrase_needs_current_route_resolution
next_skill: propagation-router
human_gate: no
execution_trace_update: compatibility_entry_routed_without_artifact_creation
```

---

## 9. Acceptance

本 CONTRACT 通过的条件：

```text
SKILL.md 和 CONTRACT.md 均声明 compatibility_entry。
输出字段只包含 router_handoff 所需字段。
禁止正式内容交接物生产。
next_skill 指向存在的当前 skill。
public_release 包含本 CONTRACT。
```
