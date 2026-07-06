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
内容形式类型与载体字典.md
文案策略矩阵.md
账号档案完整性检查表.md
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
public_release/
```

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

---

## 6. 当前停顿点

本地 Git 仓库可以用于版本治理；初始 commit 和 GitHub remote 必须等涛哥单独确认。
