---
name: final-delivery-builder
description: 涛哥创作工作流最终交付构建 skill。Use when topic 已确认且内容链路已完成，需要生成人类可验收的 final-delivery.html、图片资产记录，或在用户要转交时生成 portable_bundle / standalone_html。只做交付页和交付包，不自动发布、不登录平台、不调用外部图片 API。
---

# Final Delivery Builder

## 使命

把已经通过选题确认并完成内容链路的内容，从后台 Markdown 交接物整理成人类可用的交付结果。

本 skill 解决：

```text
用户能不能直接看懂。
文案能不能直接复制。
图片能不能预览和下载。
平台物料能不能直接拿走。
HTML 离开项目目录后会不会断链。
AI 能不能从 manifest 恢复来源。
```

## 边界

不做：

```text
自动发布。
平台登录。
自动评论、私信或互动。
外部图片 API 接入。
Seedream API 调用。
视频剪辑、渲染或上传。
```

## 输入

必须读取：

```text
accounts/{账号名}/runs/{session_id}/manifest.yaml
deliverables/content-delivery-record.md
deliverables/final-script.md
deliverables/final-visual-plan.md
deliverables/final-platform-package.md
assets/images/image-assets.md
intermediate/02-topic-card.md
intermediate/03-content-brief.md
intermediate/05-visual-plan.md
intermediate/06-quality-review.md
```

如果图片资产不存在：

```text
1. 先按 visual_plan 生成必要图片，写入 assets/images/。
2. 如果当前环境不能出图，写 image_status = pending_external / generation_failed。
3. 不得假装图片已经生成。
```

## 输出形态

### 1. project_local

默认输出：

```text
deliverables/final-delivery.html
```

用途：

```text
项目内验收。
AI 恢复。
深度追溯。
```

链接规则：

```text
允许用相对路径链接 session 内 intermediate、assets、deliverables。
必须标记 delivery_page_mode = project_local。
不得把 project_local 页面单独说成可转交包。
```

### 2. portable_bundle

当用户说“发给别人 / 传网盘 / 交付客户 / 拿到别的电脑看”时输出：

```text
deliverables/export/{session_id}/
├── final-delivery.html
├── assets/images/
├── sources/
├── export-manifest.json
└── manifest-sha256.txt
```

链接规则：

```text
HTML 内所有图片和来源链接必须指向 export 包内部。
不得链接回原 session 目录。
```

### 3. standalone_html

当用户明确要单文件交付时输出：

```text
deliverables/export/{session_id}/final-delivery-standalone.html
```

规则：

```text
图片用 data URI 或等价方式内嵌。
关键追溯材料用摘要或折叠区内嵌。
必须提示：standalone_html 适合人类验收，不替代完整后台链路。
```

## HTML 必备内容

```text
1. 选题与切口：选题、为什么做、目标、热点来源、时效、内容定位。
2. 正式文案：推荐标题、Hook、完整口播、一键复制。
3. 画中画：实际图片、下载入口、插入位置、对应口播段落。
4. 发布物料：各平台封面标题、视频标题、描述、标签、人工发布备注。
5. 追溯材料：topic_card、content_brief、draft、visual_plan、quality_review、platform_package、delivery_record。
```

页面顶部必须明确：

```text
选题已确认，内容链路已自动完成。
未自动发布。
不登录平台。
不自动评论、私信或互动。
delivery_page_mode。
```

## 状态写入

更新：

```text
manifest.yaml
content-delivery-record.md
工作流状态记录.md
accounts/{账号名}/README.md
accounts/{账号名}/index.md
indexes/all_runs.md
```

必须写入：

```text
delivery_page_mode：project_local / portable_bundle / standalone_html
final_delivery_status：html_ready / bundle_ready / standalone_ready / needs_export / blocked
image_assets_status：generated / pending_external / generation_failed / manual_required
export_status：not_requested / export_ready / export_needs_fix / export_blocked
```

## 质检

完成前必须检查：

```text
HTML 本地引用是否存在。
图片文件是否存在且非空。
复制按钮是否存在。
下载入口是否存在。
project_local 是否误称为可转交包。
portable_bundle 是否仍链接原 session 目录。
工作流链接检查 BROKEN_COUNT = 0。
```

如果浏览器不能打开 `file://`，不绕过安全策略；改用静态引用检查和图片尺寸检查。

## 用户交互引导语

本 skill 生成的是最终人类验收入口，不是发布动作。完成后必须告诉用户当前 HTML 的可用范围，以及下一步怎么选。

project_local 完成时使用：

```text
最终交付页已经生成，适合在本项目里验收。你可以打开 HTML 复制文案、下载图片、查看平台物料；如果要发给别人，回复“导出转交包”；如果只想要一个文件，回复“导出单文件 HTML”；人工发布后，回复“记录发布结果”。
```

portable_bundle 完成时使用：

```text
可转交包已经生成，里面的 HTML、图片和来源都在同一个包里，离开项目目录也不会断链。你可以把这个包发给别人；人工发布后，回复“记录发布结果”。
```

standalone_html 完成时使用：

```text
单文件 HTML 已经生成，适合快速发给别人验收。它方便阅读和转发，但不替代完整后台链路；如果以后要复盘，仍以 session 目录和 manifest 为准。
```

图片无法生成时使用：

```text
当前环境没有生成出实际图片，我已经保留可复制提示词和插入位置。你可以回复“用外部工具生成”，后续可以按 Seedream 等外部模型的入参做降级；也可以回复“先交付无图版”。
```

输出交接物必须包含：

```text
human_prompt
human_reply_examples
recommended_action
auto_next_action
task_after_navigation
```

不要写：

```text
请确认。
是否导出？
下一步怎么做？
等待人工处理。
```
