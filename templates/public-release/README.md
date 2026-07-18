# Public Release Template

> 状态：template  
> 主责：说明未来 `public_release/` 候选包应该如何组织。  
> 边界：本目录是模板，不是实际公开发布包。

---

## 结构

```text
public_release/
├── README.md
├── AGENTS.md
├── PROJECT_MAP.md
├── VERSION
├── public-manifest.yaml
├── LICENSE
├── INSTALL.md
├── UPDATE.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── RELEASE_NOTES.md
├── NOTICE.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── .github/
│   └── ISSUE_TEMPLATE/
├── docs/
├── skills/
├── objects/
├── templates/
├── examples/
├── tools/
└── release-checklist.md
```

检查报告：

```text
release-checklist.md：人类可读清单。
release_check_report：AI 接续用的结构化检查结果。
release_record：版本状态和发布状态真源。
```

## 使用方式

构建候选包时必须按本目录的 candidate-safe 模板生成 `public-manifest.yaml` 与 `release-checklist.md`，不得复制根目录历史发布记录后只改提交号。模板引用和公开运行闭包由 `routes/public-build-closure.json` 统一登记。

生成后必须按 `docs/reference/GitHub开源上线检查清单.md` 跑检查。

禁止把本模板目录本身当成公开包。
