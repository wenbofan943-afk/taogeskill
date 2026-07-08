# Visual Plan

```yaml
visual_plan_id: VP-SR1R4DR-001
draft_id: D-SR1R4DR-001
research_run_id: R-SR1R4DR-001
visual_plan_status: visual_plan_ready
image_prompt_set_id: IPS-SR1R4DR-001
visual_budget:
  required_visuals: 1
  optional_visuals: 1
```

## First Screen Visual Task

```text
把“解释不完”的疲惫感视觉化，帮助前 5 秒留住二手本地经营者。
```

## Required Visual

```yaml
image_prompt_id: IP-SR1R4DR-001
image_task_id: IMG-TASK-SR1R4DR-001
retention_task: 让本地经营者一眼看到“问题堆积”的压力
insert_after_text: 你发现没有，很多本地经营者现在最累的地方，不是车不好卖，而是解释不完。
insert_before_text: 客户一上来就问：这车有没有事故？
aspect_ratio: 16:9
prompt_card:
  scene: 本地服务展厅办公桌上，屏幕和便签堆满客户问题
  subject: 一位本地经营者坐在桌前，看着密密麻麻的问题列表
  important_details: 便签上写着事故、公里数、价格、售后、来源；画面干净，不能出现真实品牌或车牌
  use_case: 短视频口播画中画首屏辅助图
  constraints: 不要夸张漫画感，不要真实个人信息，不要平台 UI 截图，不要暗示自动私信
```

## Optional Visual

```yaml
image_prompt_id: IP-SR1R4DR-002
retention_task: 解释“评论区问题 = 信任缺口清单”
status: optional_not_materialized_in_sample
```


