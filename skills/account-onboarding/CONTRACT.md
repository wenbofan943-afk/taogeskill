# account-onboarding CONTRACT

> contract_version：0.2.0
> contract_set_version：r0-onboarding-v0.2
> 对应 skill：`skills/account-onboarding/SKILL.md`  
> 状态：confirmed_and_compiled

---

## 1. 定位

```yaml
skill_id: account-onboarding
skill_name: 首次账号建档引导
skill_type: onboarding
primary_input: user_intent + optional account hints
primary_output: account_onboarding + account_profile draft
next_skill_on_confirm: propagation-router
```

本 skill 只解决首次使用或账号不存在时的账号建档问题。

---

## 2. 触发条件

```text
用户说第一次用 / 没账号 / 新建账号 / 新增账号 / 帮我建账号。
用户唤醒涛哥创作工作流但没有任何 account_profile。
用户指定账号，但 accounts/{账号名}/account_profile.md 不存在。
propagation-router 检查发现 account_profile P0 缺失。
```

---

## 3. 输入

```text
user_intent
account_display_name
target_audience
business_goal
core_topic_or_offer
content_red_lines
```

缺字段时，一次最多问 3 个口语问题。

---

## 4. 输出

```text
accounts/{account_slug}/README.md
accounts/{account_slug}/account_profile.md
accounts/{account_slug}/index.md
accounts/{account_slug}/runs/
```

R5-H1 adds P1 account-visual references alongside the profile:

```text
accounts/{account_slug}/visual-identity/visual-identity.yaml
accounts/{account_slug}/visual-identity/column-visual-templates.yaml
```

The references may remain `identity_draft` after P0 onboarding confirmation. They are not a hotspot gate and must not invent brand assets, a fixed visual count, or a logo.

标准交接块：

```text
contract_set_version: r0-onboarding-v0.1
onboarding_id:
account_slug:
account_display_name:
onboarding_status:
account_profile_status:
confirmation_status:
artifact_path:
next_skill:
human_prompt:
human_reply_examples:
auto_next_action:
execution_trace_update:
```

---

## 5. 状态

```text
onboarding_status:
  draft_created
  waiting_human_confirmation
  confirmed
  blocked

account_profile_status:
  account_profile_draft
  account_profile_p0_ready
  account_profile_confirmed

confirmation_status:
  pending_human_confirmation
  confirmed_by_user
```

---

## 6. 人类门禁

建档草案完成后必须停给用户确认：

```text
我整理了一版账号档案：账号定位是……目标人群是……主要母题是……明确不能碰的是……

如果这版没问题，你回复“认可”或“同意”，我就继续检查这次要说的产品 / 活动对象；如果要改，直接说“目标人群改成……”“禁区加上……”。
```

允许确认短句：

```text
认可
同意
没变化
就按这个
```

---

## 7. 自动推进

用户确认后：

```text
account_profile_status = account_profile_confirmed
confirmation_status = confirmed_by_user
next_skill = propagation-router
auto_next_action = product_profile / campaign_profile check
```

不得要求用户再说“继续”。

---

## 8. 失败处理

| 问题 | 处理 |
|---|---|
| 用户拒绝提供账号名 | blocked，说明没有账号无法开始内容生产 |
| 用户只给账号名 | 创建草案并把目标人群、业务目标、禁区列入待确认 |
| slug 冲突 | 提示已有账号，进入账号档案确认或让用户改名 |
| 用户要求收集手机号 / 微信等个人信息 | 拒绝收集，改为普通账号描述 |

---

## 9. 验收样例

| 样例 | 输入 | 预期 |
|---|---|---|
| first_time_minimal | “第一次用，账号叫小周观察，讲给新手用户，想涨粉” | 创建 account_profile 草案，等待确认 |
| add_account | “新增一个账号，叫小周说车” | 进入 account-onboarding，创建新账号草案 |
| account_missing | “给小王车评做一条内容”但账号不存在 | 进入 account-onboarding |
| profile_confirmed | 用户回复“认可” | 回 propagation-router 检查 product_profile |

