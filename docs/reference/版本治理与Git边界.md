# 版本治理与 Git 边界

> 状态：项目级规则
> 继承：`D:\OpenClaw\workspace\AI工程驾驭系统\02-全局协议\版本治理与Git协议.md`
> 边界：本文件只约束本项目的 Git 使用方式，不代表已经可以公开发布。

---

## 1. 仓库定位

本项目启用独立本地 Git 仓库：

```text
仓库根目录：D:\OpenClaw\workspace\涛哥创作工作流
Git 工具：D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe
仓库用途：本地版本治理、DIFF、回滚点、开源前净化准备
```

当前仓库是“工作母仓”，不是可直接公开的 GitHub 发布仓。

原因：

```text
项目内包含真实账号档案、真实内容运行记录、实际图片资产、外部资料缓存和生产交付物。
这些内容对本地工作有用，但不能默认进入公开 GitHub。
```

---

## 2. 必须纳入版本管理

以下内容属于项目源规则和可维护资产，原则上纳入本地 Git：

```text
README.md
AGENTS.md
STATUS.md
PROJECT_MAP.md
.gitignore
docs/
skills/
objects/
indexes/
根目录方法论文档
交接物字段词典.md
docs/reference/内容形式类型与载体字典.md
docs/reference/文案策略矩阵.md
docs/reference/账号档案完整性检查表.md
```

账号档案可在本地仓库中管理，但未来公开 GitHub 时必须脱敏或替换为 sample account。

---

## 3. 禁止直接纳入公开 GitHub

以下内容不得直接进入公开 GitHub：

```text
真实账号的生产 runs。
真实账号的未脱敏档案。
真实内容交付物。
实际生成图片、视频、音频。
平台账号、Cookie、登录态、密钥、API key。
外部资料 zip / 缓存包。
客户资料、聊天记录、录音、未授权素材。
```

公开发布必须先生成净化后的开源包，建议命名为：

```text
releases/v{version}/public_release/
```

同一个版本的公开候选包必须集中放在版本化目录中，不得把 zip、hash、release gate 报告散落在项目根目录：

```text
releases/v0.1.0-alpha.1/
├── public_release/
├── taoge-creative-workflow-0.1.0-alpha.1-public-release.zip
├── taoge-creative-workflow-0.1.0-alpha.1-public-release.zip.sha256
├── release-gate-report.md
└── release-gate-report.json
```

`public_release/` 可以作为旧文档中的简称，但脚本默认产物必须进入 `releases/v{version}/`。根目录只保留源文档、方法论、索引和治理入口。

线下给人试用的测试包建议放在：

```text
offline_tester_packages/
```

测试包只用于外部试用和反馈收集，不等于 GitHub 公开候选包；不得把测试包的生成说成已经完成开源发布。

公开包只允许包含：

```text
skills/
docs/
templates/
examples/sample-account/
examples/sample-run/
README
LICENSE
CONTRIBUTING
CHANGELOG
SECURITY
```

---

## 4. Git 调用规则

不要依赖裸 `git` 命令。本机当前默认入口是：

```powershell
& "D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe" status --short
```

常用检查：

```powershell
& "D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe" rev-parse --show-toplevel
& "D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe" status --short --ignored
& "D:\OpenClaw\tools\PortableGit-2.55.0.2\cmd\git.exe" check-ignore -v "accounts/账号/runs/session/assets/images/example.png"
```

---

## 5. 任务级纪律

### 文档 / 产品设计任务

```text
开始前看 Git 状态。
只改本任务允许的 docs / README / AGENTS / STATUS / PROJECT_MAP / skill 文档。
结束后说明改了哪些文件。
不自动提交。
```

### 内容生产任务

```text
内容产物进入 accounts/{账号}/runs/{session_id}/。
图片、视频、音频、export 包默认不入 Git。
最终 HTML 是否入 Git 由当前任务决定；公开 GitHub 前必须重新生成 sample。
```

### 开源发布任务

```text
不得直接推当前工作母仓。
先生成 public_release 或独立发布目录。
跑开源检查清单。
确认无真实账号、真实产物、密钥、大文件和外部缓存。
再由涛哥确认远端仓库、License 和首个 tag。
```

### 线下测试包任务

```text
测试包进入 offline_tester_packages/。
测试包必须脱敏，不包含真实 accounts/ 生产目录。
测试包必须带 TESTING-GUIDE、PACKAGE-MANIFEST、检查记录和 hash。
测试包默认不纳入普通 Git 历史。
测试包反馈沉淀回 docs/product/GitHub开源上线前Workflow修复路线图.md。
```

## 6. release_record 状态

任何开源候选包、zip、tag 或 GitHub release 动作都必须写 `release_record`，不能只在聊天里说“发版了”。

```yaml
release_record:
  release_id:
  release_state: release_candidate_built / release_commit_ready / tag_ready / remote_ready / github_release_published
  version:
  tag_name:
  release_candidate_path:
  zip_path:
  sha256_path:
  release_notes_path:
  remote_url:
  commit_hash:
  publish_status: not_published / publish_ready_waiting_human / published_to_github / publish_blocked
  human_approval_required: true
  artifact_path:
  next_skill:
```

状态边界：

```text
release_candidate_built：只代表本地候选包已生成到 `releases/v{version}/`。
release_commit_ready：只代表可以准备本地 commit。
tag_ready：只代表 tag 信息已准备，未必已创建。
remote_ready：只代表远端配置或说明已确认，未必已推送。
github_release_published：只有真实 GitHub release 完成后才能写。
```

阻断规则：

```text
缺 release_check_report -> publish_status=publish_blocked
缺 License 确认 -> publish_status=publish_blocked
未做人类远端确认 -> publish_status=publish_ready_waiting_human 或 publish_blocked
发现真实账号、密钥、本机路径依赖 -> publish_status=publish_blocked
```

---

## 7. 当前停顿点

本地 Git 仓库可以用于版本治理；初始 commit 和 GitHub remote 必须等涛哥单独确认。
