# Release Scope Audit 20260708-001

> 状态：release_scope_audit_ready_for_human_review  
> 目标版本：`0.1.0-alpha.1`  
> 边界：本报告只审计 release commit 范围，不执行 commit、tag、remote、push 或 GitHub Release。

---

## 结论

当前可以继续准备 `0.1.0-alpha.1` 灰度测试包，但在创建 release commit 前，需要先确认 Git 入库范围。

本轮已把以下生成物排除出普通 Git 范围：

```text
releases/
support-logs/
*.zip
*.zip.sha256
accounts/*/runs/
accounts/*/index.md
indexes/all_runs.md
根目录 alpha / ci / field / release / regression / workflow 检查报告
```

当前 release zip 仍保留在本地：

```text
releases/v0.1.0-alpha.1/taoge-creative-workflow-0.1.0-alpha.1-public-release.zip
```

---

## 建议纳入 Release Commit

这些是公开 alpha 包的源文件和治理规则，建议纳入：

```text
.gitignore
README.md
AGENTS.md
PROJECT_MAP.md
STATUS.md
CONTACT.md
INSTALL.md
UPDATE.md
CHANGELOG.md
RELEASE_NOTES.md
NOTICE.md
VERSION
LICENSE
CONTRIBUTING.md
SECURITY.md
CODE_OF_CONDUCT.md
public-manifest.yaml
release-checklist.md
.github/
tools/
templates/
examples/
skills/*/SKILL.md
skills/*/CONTRACT.md
docs/reference/
docs/how-to/
docs/tutorials/
docs/product/
docs/explanation/
交接物字段词典.md
```

原因：

```text
这些文件决定别人下载后能不能读懂、安装、跑 sample、导出反馈日志、执行 checker、理解 alpha 边界。
```

---

## 建议排除 Release Commit

这些不建议进入 release commit：

```text
releases/
support-logs/
offline_tester_packages/
根目录 *-check-report.md / *.json
accounts/*/runs/*/assets/images/
accounts/*/runs/*/deliverables/export/
accounts/*/runs/
accounts/*/index.md
indexes/all_runs.md
```

原因：

```text
它们是生成物、测试反馈包、重型媒体、可转交包或本地候选产物。
GitHub Release 可以单独上传 zip；源码 commit 不需要保存构建出来的 zip。
```

---

## 需人工确认

以下内容需要涛哥确认是否纳入 release commit：

| 范围 | 当前状态 | 建议 |
|---|---|---|
| `accounts/涛哥汽车观察/runs/S20260706-005/` | untracked / ignored by release scope | 不纳入公开 release commit，保留为本地真实测试证据 |
| `accounts/涛哥汽车观察/runs/S20260707-001/` | untracked / ignored by release scope | 不纳入公开 release commit，保留为本地真实测试证据 |
| `accounts/涛哥汽车观察/index.md` | removed from Git tracking / ignored by release scope | 不纳入公开 release commit，保留为本地账号运行索引 |
| `indexes/all_runs.md` | removed from Git tracking / ignored by release scope | 不纳入公开 release commit，保留为本地全局运行索引 |
| 根目录业务汇总表：`热点候选池.md`、`热点评分表.md`、`自媒体选题库.md`、`调研运行记录.md` | modified | 这些是项目方法论/运行记录混合体，公开前需确认是否已脱敏 |

建议默认策略：

```text
公开源码只放规则、skill、模板、tools、examples 和脱敏 docs。
真实账号运行产物不作为首个 alpha release commit 的核心内容。
```

---

## 当前 Release Gate

```text
overall_result: blocked
blocked_reason: dirty_worktree_items=100
waiting_human_count: 3
waiting_human:
- no_git_remote_configured
- tag v0.1.0-alpha.1 not created
- release commit/tag/remote/push require explicit approval
```

这是正确门禁，不是构建失败。

---

## 下一步建议

1. 人工确认本报告的 release commit 范围。
2. 排除或忽略真实测试 run 和本地生成物。
3. 重新跑 `validate-public-release.ps1` 和 `validate-release-gate.ps1`。
4. 用户显式批准后，才创建 release commit。
5. tag、remote、push、GitHub Release 继续分别等显式批准。

---

## 执行记录：源码仓库净化

用户已确认执行一次源码净化。本轮将以下历史运行产物从 Git 跟踪中移出，但不删除本地文件：

```text
accounts/涛哥车商自媒/runs/
accounts/涛哥汽车观察/runs/
accounts/*/index.md
indexes/all_runs.md
```

说明：

```text
这些内容属于本地真实运行证据和运行索引，不进入首个公开 alpha release commit。
本轮不改写 Git 历史；如果未来仓库已经公开过这些文件，再考虑历史清理工具。
```
