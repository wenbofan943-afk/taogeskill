# Expected Agent Behavior

1. 先确认账号档案和产品对象。
2. 生成或读取候选选题。
3. 用户选择 `T-SAMPLE-001` 后，直接进入内容 Brief。
4. Brief 通过后自动写口播，不要求用户回复“继续写口播”。
5. 质检通过后自动生成平台包装和最终 HTML。
6. 如果不能直接出图，在 HTML 中展示 prompt_card、插入位置和 `image_status=pending_external`。
