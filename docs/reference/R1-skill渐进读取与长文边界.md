# R1 Skill 渐进读取与长文边界

> 状态：R1 编译补强规则  
> 主责：限制长 `SKILL.md` 在运行时的读取方式，避免 sample run 靠全文硬撑。  
> 边界：本文件不新建 skill，不拆 R2/R3/R4；只规定 R1 阶段如何读长 skill。

---

## 一、为什么补这条

成熟 skill 项目通常采用渐进读取：

```text
metadata 负责触发。
SKILL.md 顶部负责最小执行规则。
长方法论和背景材料按需读取。
输出按固定交接块传递。
```

本项目 R1 第一轮编译后，部分 `SKILL.md` 已超过 500 行：

```text
hotspot-topic-research
platform-packaging-adapter
talking-head-image-pip
propagation-router
```

这不阻塞 R1 sample run，但必须防止测试时靠全文反复搜索来“扶跑”。

---

## 二、R1 读取顺序

每个 skill 触发后，默认只先读三段：

```text
1. YAML frontmatter。
2. R1 Contract Runtime / R1 Compatibility Runtime。
3. R1 交接块 / R1 兼容交接块。
```

然后按当前任务只读必要章节：

| 任务 | 只继续读 |
---|---|
| 缺输入 / 判断能不能跑 | 输入门槛 / 必读 / 回退规则 |
| 正常生成 artifact | 处理流程 / 输出格式 |
| 人类门禁 | 用户交互引导语 / 人类门禁 / 任务后导航 |
| 失败或返工 | 阻断 / 回退规则 / 失败处理 |
| 最终交付 | HTML 必备内容 / 状态写入 / 质检 |

不得为了跑一步内容，把长 skill 从头到尾当方法论全文消化。

---

## 三、长 skill 当前边界

| skill | 允许先读 | 按需读 |
|---|---|---|
| `propagation-router` | R1 Runtime、交接块、交接物检查、路由表 | 输出格式、任务后导航 |
| `hotspot-topic-research` | R1 Runtime、账号与产品对象门禁、Topic Gate | 三池雷达、桥接规则、评分、输出格式 |
| `talking-head-image-pip` | R1 Runtime、Workflow、Find Retention Risk、R1 交接块 | prompt 细则、Rendering And Fallback |
| `platform-packaging-adapter` | R1 Runtime、输入门槛、分发包装输入包、R1 交接块 | 各平台包装规则、输出格式 |

如果运行中必须读取大量章节，应在 `execution_trace` 里记录：

```text
execution_source: skill_inferred
agent_intervention: read_long_skill_sections
reason:
```

这类样本最多算 `pass_with_warnings`，不能直接证明 skill 达到 L3。

---

## 四、后续拆分方向

R1 不马上拆文件。

如果 sample run 证明长 skill 仍然导致误读，再进入 R1 小修或 R4 开源整理时考虑：

```text
把长方法论迁入 skill references/ 或 docs/reference。
SKILL.md 保留触发、输入、输出、门禁、回退和交接块。
把平台差异、视觉 prompt 工艺、热点来源细则拆成按需 reference。
```

拆分前不得改变标准交接物链路。

