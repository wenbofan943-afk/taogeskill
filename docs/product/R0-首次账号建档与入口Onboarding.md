# R0 首次账号建档与入口 Onboarding

> 状态：confirmed_and_compiled  
> 所属路线：R0 首次使用入口 / GitHub 开源前补强  
> 主责：让第一次使用“涛哥创作工作流”的用户不需要懂账号档案字段，也能通过人话交互创建账号档案，并进入后续内容链路。  
> 边界：本文件只定义账号建档 onboarding，不做热点、不写文案、不自动发布、不登录平台。

---

## 1. 成熟项目借鉴

本轮参考成熟 workflow / 产品入口做法：

| 成熟做法 | 吸收原则 |
|---|---|
| Onboarding wizard | 首次使用不要让用户填长表，用 3-5 个问题收集最小信息 |
| LangGraph interrupt | 人类确认点要带 payload，用户认可后自动恢复 |
| Prefect state / logs | onboarding 也要有状态和日志，不只在聊天里完成 |
| Temporal versioning | 账号档案模板要有版本，旧账号不被新模板静默破坏 |

本项目取舍：

```text
不用表单系统。
不用数据库。
不用前端注册页。
用 skill + 模板 + manifest/trace 记录首次建档。
```

---

## 2. 触发场景

进入 R0 的情况：

```text
用户唤醒：涛哥创作工作流 / 涛哥 skill / 涛哥工作流 / 涛哥创作。
项目里没有任何账号档案。
用户指定账号但 accounts/{账号名}/account_profile.md 不存在。
用户说“新建账号 / 新增账号 / 第一次用 / 没账号 / 帮我建个号”。
外部 AI 下载 skill 后首次运行，找不到账号档案。
```

不进入 R0 的情况：

```text
已有账号档案且 P0 齐全 -> 进入账号档案摘要确认。
已有账号档案但用户没有指定本轮账号 -> 先让用户选择账号，不默认新建。
用户只问项目说明 / 包说明 / GitHub 开源 -> 进入项目说明或 R4。
```

---

## 3. 交互原则

首次建档不是让用户填表，而是 AI 问少量人话问题：

```text
1. 这个账号叫什么？
2. 主要讲给谁听？
3. 账号当前最想达成什么目标？
4. 主要讲什么领域 / 母题？
5. 明确不能碰什么话题或承诺？
```

如果用户一次性说了足够信息，AI 直接整理，不重复问。

如果信息不足，最多一次问 3 个问题；先保证能进入草案档案，不追求一次完美。

---

## 4. 输出路径

新账号建档输出：

```text
accounts/{account_slug}/README.md
accounts/{account_slug}/account_profile.md
accounts/{account_slug}/index.md
accounts/{account_slug}/runs/
```

使用模板：

```text
templates/account/account_profile.template.md
```

---

## 5. 状态与字段

```yaml
onboarding_id:
account_slug:
account_display_name:
onboarding_status: draft_created / waiting_human_confirmation / confirmed / blocked
account_profile_status: account_profile_draft / account_profile_p0_ready / account_profile_confirmed
confirmation_status: pending_human_confirmation / confirmed_by_user
next_skill: propagation-router
```

确认后自动进入：

```text
product_profile / campaign_profile 检查
```

---

## 6. 人类引导模板

首次无账号：

```text
我先帮你建一个账号档案，这样后面找热点、写文案、做画中画时不会串号。

你不用填表，先用人话告诉我三件事：
1. 账号叫什么？
2. 主要讲给谁听？
3. 现在最想达成什么目标？比如涨粉、引流、建立信任、卖服务。

你简单说就行，我会整理成账号档案，再给你确认。
```

档案草案完成：

```text
我先按你说的整理了一版账号档案：账号定位是……目标人群是……主要母题是……明确不能碰的是……

如果这版没问题，你回复“认可”或“同意”，我就继续检查这次要说的产品 / 活动对象；如果要改，直接说“目标人群改成……”“禁区加上……”。
```

---

## 7. 验收标准

```text
用户没有账号时，不再卡死。
不会要求用户理解 account_profile 字段。
账号档案至少达到 P0 ready。
用户确认后自动进入产品 / 活动对象检查。
账号建档动作写入 execution_trace 或工作流状态记录。
外发测试包能说明首次使用如何新建账号。
```

---

## 8. 编译记录

> 编译时间：2026-07-07  
> 编译目标：`skills/account-onboarding/SKILL.md`、`skills/propagation-router/SKILL.md`、`templates/account/account_profile.template.md`、`docs/reference/人类引导与任务后导航规范.md`、`AGENTS.md`、`README.md`、`PROJECT_MAP.md`、`交接物字段词典.md`。

```text
account-onboarding 已作为专项 skill 编译。
propagation-router 已增加“无账号 / 新建账号”路由。
字段词典已增加 account_onboarding。
外发包后续必须包含 onboarding 说明。
```
