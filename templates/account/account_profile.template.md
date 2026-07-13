# {account_display_name}

> 状态：account_profile_draft  
> 文件位置：accounts/{account_slug}/account_profile.md  
> 主责：定义本账号做热点选题、口播、画中画和质检时的账号边界。  
> template_version：account-profile-v0.3

## 一、账号基础

- 账号名：{account_display_name}
- 账号定位：{positioning}
- 业务目标：{business_goal}
- 目标人群：{target_audience}
- 核心业务 / 产品 / 服务：{core_topic_or_offer}
- 当前阶段：{stage}

## 二、账号母题

1. {mother_topic_1}
2. {mother_topic_2}
3. {mother_topic_3}

## 三、热点边界

- 可蹭热点类型：{allowed_hotspots}
- 禁蹭热点类型：{forbidden_hotspots}
- 内容禁区：{content_red_lines}

## 四、转化和产品露出

- 转化路径：{conversion_path}
- 产品 / 服务露出比例：{product_exposure_level}
- 不能承诺什么：{forbidden_claims}

## 五、表达风格

- 常用表达：{common_phrases}
- 禁用表达：{banned_phrases}
- 画中画风格：{visual_style}

## 六、成功指标

- 主指标：{primary_metrics}
- 辅助指标：{secondary_metrics}

## 七、R5 账号视觉身份引用

```yaml
visual_identity_ref: accounts/{account_slug}/visual-identity/visual-identity.yaml
visual_identity_status: identity_draft
column_visual_template_refs:
  - accounts/{account_slug}/visual-identity/column-visual-templates.yaml
visual_count_policy: content_derived_by_r3_0_to_n
```

说明：视觉身份约束账号的证据感、语气、层级、禁忌和栏目表达；不规定每篇图片数量，也不替代 R3 的单篇 `visual_need_analysis`。

## 八、R5 账号热点雷达引用

```yaml
radar_policy_ref: accounts/{account_slug}/hotspot-memory/account-topic-policy.yaml
query_lexicon_ref: accounts/{account_slug}/hotspot-memory/query-lexicon.yaml
hotspot_memory_ref: accounts/{account_slug}/hotspot-memory/
radar_policy_status: policy_draft
used_car_priority_mode: direct_first
new_car_spillover_threshold: 3
```

说明：雷达先读取结构化账号策略和词库；只有本轮少于 3 条事实可核验的二手车直接候选时，才可开启有传导证明的新车外溢。扩词可直接在账号边界内探索，但 `blocked` 只用于硬禁区、合规边界或用户明确封禁。

## 九、待确认

- {pending_question_1}
- {pending_question_2}

## 十、R5-H5 账号启动检查

```yaml
publishing_platforms: []
target_duration: pending_confirmation
audience_priority: []
high_risk_topic_policy: pending_confirmation
account_startup_check_version: r5-h5-v0.1
account_session_snapshot_template_ref: templates/account/account-session-snapshot.template.yaml
```

说明：每次热点、选题、内容或视觉任务先按当前任务检查这些字段。一次最多问 3 个口语问题；用户确认后写入本次 session 的账号快照。热点发现不因视觉身份缺失阻断；视觉交付才按需补视觉身份。
