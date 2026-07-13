---
name: account-onboarding
description: 涛哥创作工作流的首次账号建档 skill。Use when a user invokes “涛哥创作工作流 / 涛哥 skill / 涛哥工作流” but has no account profile, asks to create/add a new account, says first-time use, or names an account that does not exist under accounts/{账号名}/account_profile.md. It guides the user with at most 3 plain-language questions at a time, creates account_profile / README / index drafts, asks for confirmation, then routes back to product/campaign checking. It does not research hotspots, write scripts, generate images, publish, login, comment, or DM.
---

# Account Onboarding

## Overview

This skill turns first-time human input into a usable account profile. It is a wizard, not a form: ask a few plain-language questions, draft the files, summarize them back to the user, and wait for confirmation before content production.

## Runtime

```yaml
contract_set_version: r0-onboarding-v0.2
contract_status: confirmed
skill_type: onboarding
primary_input: user_intent + optional account hints
primary_output: account_profile + account_onboarding_record
next_skill_on_confirm: propagation-router
```

## Read First

```text
docs/product/R0-首次账号建档与入口Onboarding.md
templates/account/account_profile.template.md
docs/reference/账号档案完整性检查表.md
交接物字段词典.md
docs/reference/人类引导与任务后导航规范.md
```

## Trigger Rules

Use this skill when:

```text
User invokes the workflow and there is no account_profile in the project.
User says first-time use, no account, create account, add account, new account, 帮我建账号, 新增账号.
User names an account but accounts/{账号名}/account_profile.md does not exist.
Router cannot continue because account_profile is missing.
```

Do not use this skill when:

```text
An existing account_profile exists and only needs confirmation.
Existing accounts are present but the user did not name which account to use.
The task is product/campaign setup after account confirmation.
The user is asking about GitHub release, packaging, or docs only.
```

## Workflow

### 1. Ask The Smallest Useful Questions

Ask at most three questions at a time. Use plain language:

```text
我先帮你建一个账号档案，这样后面找热点、写文案、做画中画时不会串号。

你不用填表，先告诉我三件事：
1. 账号叫什么？
2. 主要讲给谁听？
3. 现在最想达成什么目标？比如涨粉、引流、建立信任、卖服务。
```

If the user already gave enough detail, skip questions and draft the profile.

### 2. Draft Account Files

Create:

```text
accounts/{account_slug}/README.md
accounts/{account_slug}/account_profile.md
accounts/{account_slug}/index.md
accounts/{account_slug}/runs/
```

Use `templates/account/account_profile.template.md`. If some fields are unknown, write safe defaults and add them under `待确认`; do not block just because the profile is imperfect.

Minimum P0 fields:

```text
账号名
账号定位
目标人群
业务目标
账号母题
热点边界
内容禁区
转化路径
不能承诺什么
```

R5 identity fields are P1 defaults, not a reason to block first onboarding. Create the `visual_identity_ref` and `column_visual_template_refs` from the account templates with `identity_draft`; ask for actual visual direction only after the P0 profile is confirmed or when the user asks to establish account visual consistency. Do not invent a logo, fixed color value, or image count.

### 3. Summarize And Confirm

After drafting, stop for human confirmation:

```text
我整理了一版账号档案：账号定位是……目标人群是……主要母题是……不能碰的是……

如果没问题，你回复“认可”或“同意”，我就继续检查这次要说的产品 / 活动对象；如果要改，直接说“目标人群改成……”“禁区加上……”。
```

Allowed confirmation replies:

```text
认可
同意
没变化
就按这个
```

### 4. Route After Confirmation

On confirmation:

```text
account_profile_status = account_profile_confirmed
confirmation_status = confirmed_by_user
next_skill = propagation-router
auto_next_action = product_profile / campaign_profile check
```

If the user changes details, update `account_profile.md`, summarize the changed fields, and ask for confirmation once more.

## Output Block

Every run must output:

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

## Boundaries

```text
Do not research hotspots.
Do not write content.
Do not create product claims.
Do not publish, login, comment, DM, or interact with platforms.
Do not collect phone numbers, WeChat IDs, addresses, ID cards, plates, cookies, tokens, or private customer records.
```
