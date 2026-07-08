# State And Gates

> 状态：状态接续和门禁编排规则
> 主责：定义 agent 执行任务时如何读取状态、写回状态、处理 checkpoint、执行检查和收口。
> 边界：本文件不定义具体字段 schema；字段真源仍是 `交接物字段词典.md` 和各 skill contract。

---

## 状态读取顺序

```text
1. AGENTS.md
2. PROJECT_MAP.md
3. 工作流状态记录.md
4. 当前 task_type 对应 required reads
5. manifest.yaml / checkpoint / execution trace
```

如果 `工作流状态记录.md` 与账号/session 具体 manifest 冲突：

```text
以账号/session 具体 manifest 为准。
修正汇总状态记录。
记录冲突原因。
```

## 状态写回原则

每次小循环完成后至少写回：

```text
current_stage
current_artifact
session_status
field_gate_status
next_action
after_completion_status
recommended_user_replies
blocking_reason
```

真实内容产物写入：

```text
accounts/{account_slug}/runs/{session_id}/
```

公开样例写入：

```text
examples/
docs/tutorials/
```

发版产物写入：

```text
releases/v{version}/
```

## 门禁类型

| gate | 何时触发 | 通过条件 | 不通过 |
|---|---|---|---|
| `human_account_confirm` | 换账号 / 新建账号 | 用户认可账号摘要 | 回到 account onboarding |
| `human_topic_select` | 生成 3 个候选选题后 | 用户选一个，或明确全做进入 R2 | 不进入 Brief |
| `field_gate` | 产品定义、skill 编译、公开包同步 | 字段词典 / contract / skill / checker 同源 | 先修字段 |
| `branch_lock_gate` | 多选题 / 多分支 | parent / child / checkpoint 清楚 | 封锁旁支任务 |
| `image_capability_gate` | 画中画生成 | Codex 可出图则生成；否则提示词降级 | 记录 provider_state |
| `public_privacy_gate` | public build / GitHub release | 隐私扫描、source zip、release zip 均过 | 阻断发布 |
| `remote_release_gate` | push / tag / Release | GitHub 页面、assets、Actions、hash 均过 | 回到 release 修复 |
| `git_publish_gate` | commit / push / tag / Release / repo metadata | 用户明确要求提交、推送、发版、发布、同步 GitHub、创建 tag 或更新 Release | 停在本地改动和检查结果，不执行 git 写入或远端动作 |
| `final_delivery_regression_gate` | 用户指出最终交付物浅显 BUG / 交付页字段缺失 / 展示误导 | 同时检查方法论、字段词典、skill 合同、模板、实际 HTML 和源 Markdown | 回到对应上游 skill 修订，并重建最终 HTML |

## Git 写入边界

默认允许：

```text
本地文件修改
本地检查
git status / diff / log / show / ls-files 等只读检查
```

默认禁止，除非用户明确要求：

```text
git commit
git push
创建 / 删除 / 移动 tag
修改 GitHub Release
上传 Release asset
修改 GitHub repo description / topics / settings
用 GitHub API 写入远端 main 或 workflow
```

如果任务是项目级治理、产品定义、文档编排、路由设计或本地 dry-run，完成后必须先停在本地结果报告，不能因为检查通过就自动提交或推送。

## 收口格式

最终回复必须说明：

```text
做了什么
产物在哪里
检查结果是什么
还有什么没做 / 不能做
用户下一步可以直接说什么
```

不得用“应该可以”“大概没问题”替代实际检查结果。

## 任务后导航

每次任务结束后，必须根据 `routes/workflow-routes.yaml` 的 `after_completion` 字段判断收口方式：

```text
on_success：任务完成，给结果、产物、检查结果和推荐下一步。
on_waiting_human：需要人判断，说明为什么停下，并给 2-5 个可直接回复的话。
on_blocked：被门禁阻断，说明阻断原因、恢复路线和日志 / 报告位置。
auto_continue_allowed：为 true 且无门禁时，自动进入下一步，不要求用户回复“继续”。
```

如果 route 没有声明 `after_completion`，必须按 `docs/governance/agent-orchestration/after-task-guidance.md` 的通用规则收口，并把缺失记录为编排债务。

## 最终交付物缺陷回归

当用户指出“交付物里有明显 BUG”“HTML 不好读”“字段没展示”“最终物料理解错了”时，不得只改当前 HTML。必须按以下顺序检查：

```text
1. 实际 final-delivery.html 是否确实有问题。
2. 对应 deliverables/*.md 是否也有同类问题。
3. intermediate 上游交接物是否已经丢字段。
4. 交接物字段词典是否有标准字段。
5. 对应 skill CONTRACT / SKILL 是否强制输出。
6. final-delivery 模板是否强制展示。
7. 是否需要新增或修订方法论文档。
8. 修完后重跑该 session 的对应上游链路，并重新检查 HTML 链接和字段展示。
```

如果缺陷来自“字段有但最终展示没吃干净”，必须记录为：

```text
issue_type = compiled_delivery_mapping_bug
revision_path = back_to_{upstream_skill}
required_backwrite = field_dictionary / contract / skill / template / actual_delivery
```
