# Sample Account Profile

```yaml
sample_only: true
contains_real_account: false
account_slug: sample-account
account_name: 示例账号
profile_status: sample_profile
```

## 定位

这是一个用于开源包演示的虚构账号。  
它只展示账号档案字段结构，不代表真实账号、真实经历或真实客户。

## 受众

```text
想用 AI 内容 workflow 管理选题、口播、画中画、质检和最终交付的创作者或运营者。
```

## 语气

```text
直接、清楚、克制，不夸大能力。
```

## 禁区

```text
不承诺自动发布。
不暗示平台登录、私信、评论或截流能力。
不展示真实客户、手机号、微信号、车牌或平台后台数据。
```

## R5 账号视觉身份（脱敏样例）

```yaml
visual_identity_ref: examples/r5-h1-account-visual-identity-fixtures/sample-account/visual-identity.yaml
visual_identity_status: identity_active
column_visual_template_refs:
  - examples/r5-h1-account-visual-identity-fixtures/sample-account/column-visual-templates.yaml
visual_count_policy: content_derived_by_r3_0_to_n
```

## R5 账号热点雷达（脱敏样例）

```yaml
radar_policy_ref: examples/r5-h2-account-radar-fixtures/sample-account/account-topic-policy.yaml
query_lexicon_ref: examples/r5-h2-account-radar-fixtures/sample-account/query-lexicon.yaml
hotspot_memory_ref: examples/r5-h2-account-radar-fixtures/sample-account/
radar_policy_status: policy_active
used_car_priority_mode: direct_first
new_car_spillover_threshold: 3
```

## R5-H5 账号启动检查（脱敏样例）

```yaml
publishing_platforms:
  - douyin
target_duration: 60s
audience_priority:
  - buyer
  - seller
  - dealer
high_risk_topic_policy: verify_mechanism_only
account_startup_check_version: r5-h5-v0.1
account_session_snapshot_template_ref: templates/account/account-session-snapshot.template.yaml
```

热点任务可在视觉身份仍为草案时继续；进入视觉交付时再按需补齐视觉身份。所有确认字段在每个 session 形成独立账号快照，不复用其他账号的快照、词库或候选。
