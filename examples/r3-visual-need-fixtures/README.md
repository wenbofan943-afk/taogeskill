# R3 Visual Need Fixtures

> 脱敏机器 fixture。验证 R3-C71 到 C80 的内容驱动视觉需求合同，不调用 Image 2。

`fixtures.json` 使用两个完整基线文档和声明式 mutation / repeat 形成正反例。它覆盖：0 图可通过、概念 / 证据 / 情绪任务、5 与 7 个 accepted 全部进入 Image 2、情绪错位、生成图冒充证据、仅按秒数切图、重复视觉、旧 call limit、映射断链、缺 zero reason 和旧 visual-budget 字段污染。

运行：

```powershell
.\tools\validate-r3-visual-need.ps1
```

`repeat_generate_count` 只服务 fixture 构造，不是正式产品字段，也不是图片数量策略。
