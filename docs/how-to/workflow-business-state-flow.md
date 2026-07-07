# 业务状态流转图

> 状态：active  
> 主责：给人和 AI 快速理解涛哥创作工作流如何从账号档案走到最终交付、转交包和开源包。  
> 交互版：`workflow-business-state-flow.html`

## 1. 内容生产主链路

```mermaid
flowchart TD
  Z["首次建档 account_onboarding"] --> A["账号档案确认 account_profile"]
  A --> B["产品/对象确认 product_profile"]
  B --> C["热点调研 research_run_record"]
  C --> D["选题卡 topic_card"]
  D -->|人类选题 / 代测选择| E["内容 Brief content_brief"]
  E --> F["口播草案 draft"]
  F --> G["画中画计划 visual_plan"]
  G --> H["图片资产 image_asset_set"]
  H --> I["文案与视觉质检 quality_review"]
  I --> J["多平台包装 platform_package"]
  J --> K["内容交付记录 content_delivery_record"]
  K --> L["最终 HTML final_delivery"]
  L --> M{"人类最终验收"}
  M -->|人工发布后记录| N["publish_record"]
  M -->|局部返工| F
  M -->|导出转交包| O["portable_bundle / standalone_html"]
  M -->|归档| P["session_archived"]
```

## 2. 人类停顿点

```mermaid
stateDiagram-v2
  [*] --> AccountConfirm
  AccountConfirm --> Research: 认可账号档案
  Research --> TopicGate: 生成候选选题
  TopicGate --> AutoProduction: 选 topic_id
  AutoProduction --> FinalReview: 自动完成 Brief/口播/画中画/质检/平台包/HTML
  FinalReview --> PublishRecord: 人工发布后记录
  FinalReview --> Revision: 局部返工
  FinalReview --> Export: 导出转交包
  FinalReview --> Archive: 归档
  Revision --> AutoProduction
```

## 3. 工程状态与包边界

```mermaid
flowchart LR
  W["工作母仓"] --> S["真实 session"]
  S --> H["project_local HTML"]
  H --> E["offline tester package"]
  W --> P["public_release candidate"]
  P --> G["GitHub release"]
  S -.不得直接公开.-> P
  E -.线下测试，不公开.-> Tester["测试者"]
  P -.净化后.-> G
```

## 4. 一句话解释

```text
涛哥创作工作流不是自动发布工具，而是一套“账号档案 -> 热点选题 -> 文案 -> 图片资产 -> 质检 -> 平台包装 -> HTML 交付 -> 可转交包 / 开源样例”的内容生产与资产治理 workflow。
```
