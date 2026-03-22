---
name: daily-reminder
description: 每日提醒技能。当用户说"开始每日提醒"时激活，解析日程列表，维护任务状态，每30分钟通过飞书提醒一次，支持特殊时间点提醒，支持完成确认按钮。用户说"完成X"或点击飞书卡片按钮时标记任务完成，第二天自动清空。
---

# 每日提醒 Skill

## 核心职责

本 skill 维护一个持久化的任务列表，通过飞书定时推送未完成的任务，支持：
- 解析用户输入的日程列表
- 每30分钟周期性提醒
- 特殊时间点单独提醒
- 完成状态管理
- 次日0点自动清空

## 数据存储

**文件路径**：`~/.newmax/daily-reminder/tasks.json`

**数据结构**：
```json
{
  "date": "2026-03-23",
  "active": true,
  "tasks": [
    {
      "id": 1,
      "text": "给客户发邮件",
      "scheduled_time": "10:00",
      "completed": false,
      "notified_special": false
    },
    {
      "id": 2,
      "text": "写周报",
      "scheduled_time": null,
      "completed": false,
      "notified_special": false
    }
  ],
  "last_periodic_reminder": "2026-03-23T09:00:00+08:00"
}
```

**字段说明**：
- `date`：当前任务列表所属日期，用于判断是否跨天
- `active`：提醒是否在进行中
- `id`：用户看到的序号（1, 2, 3...），稳定不变
- `text`：任务描述原文
- `scheduled_time`：特殊时间点提醒时间，格式 `HH:MM`，如 `null` 表示不需要时间点提醒
- `completed`：是否已完成
- `notified_special`：该任务的时间点提醒是否已触发（防止重复提醒）
- `last_periodic_reminder`：上次发送周期性提醒的时间（ISO8601，带时区），用于判断是否距今≥30分钟

## 用户指令解析

### 1. 开始每日提醒

**触发词**：用户发送包含"开始每日提醒"的消息

**输入格式示例**：
```
开始每日提醒：
1. 给客户发邮件
2. 写周报
3. 下午3点开周会
4. 对账
```

**解析逻辑**：
1. 按换行拆分，忽略第一行（"开始每日提醒"）
2. 每行匹配正则：`^(\d+)[.、：:]\s*(.*)`
3. 从描述中提取时间：
   - 含 `凌晨\d+点` / `早上\d+点` / `上午\d+点` → 解析为 `HH:00`
   - 含 `下午\d+点` → 解析为 `H+12:00`（如下午3点 → 15:00）
   - 含 `晚上\d+点` → 解析为 `H+12:00`
   - 含 `午\d+点` → 解析为 `11:MM` 格式
   - 时间也可以直接写如 `14:30` 格式
4. 剩余描述去掉时间部分作为 `text`
5. 追加到 tasks 数组（保留已完成的任务不被覆盖）
6. 设置 `last_periodic_reminder = now`
7. 若 `active = false`，设置为 `true`
8. 立即发送一次当前任务列表给用户（让用户知道已记录）

**追加逻辑**：如果 tasks 数组已存在且有未完成任务，新任务追加到列表，不清空已有任务。

### 2. 完成任务

**触发词**：`完成` / `完成了` / `已完成` + 序号

**输入示例**：
- `完成了2`
- `完成第3条`
- `第1条做完了`

**解析逻辑**：
1. 提取序号（可能有"第"字）
2. 找到对应 `id` 的任务，设置为 `completed: true`
3. 发飞书确认："✅ 任务N已标记完成"

### 3. 增加任务

**触发词**：`增加` / `加一个` / `再加` + 任务描述

**输入示例**：
- `增加：下午4点对账`
- `再加一个任务，写方案`
- `加一个 明天上午10点开会`

**解析逻辑**：
1. 提取任务描述（含时间则解析 scheduled_time）
2. `id` 取当前最大 id + 1
3. `completed: false`，`notified_special: false`
4. 追加到 tasks 数组
5. **重置 `last_periodic_reminder = now`**，确保新任务不会被立即的30分钟提醒漏掉
6. 发飞书确认已添加

### 4. 查看任务

**触发词**：`看看任务` / `当前有哪些` / `任务列表`

直接回复当前任务列表（已完成的灰掉显示）。

### 5. 停止提醒

**触发词**：`停止每日提醒` / `结束提醒`

设置 `active: false`，发飞书通知。

## 飞书消息发送

### 发送方式

使用 OpenClaw 的 `message` 工具，channel 设为飞书渠道。

### 周期性提醒卡片

每30分钟发送一次，列出所有未完成任务：

```json
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": { "tag": "plain_text", "content": "📋 今日待办提醒" },
      "template": "blue"
    },
    "elements": [
      { "tag": "div", "text": { "tag": "lark_md", "content": "**时间**: 09:30" } },
      { "tag": "hr" },
      { "tag": "div", "text": { "tag": "lark_md", "content": "**1.** 给客户发邮件" } },
      { "tag": "div", "text": { "tag": "lark_md", "content": "**2.** 写周报" } },
      { "tag": "div", "text": { "tag": "lark_md", "content": "~~**3.** 开周会（已完成）~~" } },
      { "tag": "hr" },
      { "tag": "note", "elements": [
        { "tag": "plain_text", "content": "💡 回复「完成X」标记任务完成" }
      ]}
    ]
  }
}
```

### 时间点提醒卡片

到达 `scheduled_time` 且 `notified_special = false` 时发送：

```json
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": { "tag": "plain_text", "content": "🔔 时间提醒" },
      "template": "red"
    },
    "elements": [
      { "tag": "div", "text": { "tag": "lark_md", "content": "**现在时间：15:00**" } },
      { "tag": "div", "text": { "tag": "lark_md", "content": "该做这件事了：**开周会**" } }
    ]
  }
}
```

### 带按钮的任务卡片

周期性提醒也可以带上按钮，方便用户直接点击完成：

```json
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": { "tag": "plain_text", "content": "📋 今日待办提醒 09:30" },
      "template": "blue"
    },
    "elements": [
      {
        "tag": "action",
        "actions": [
          {
            "tag": "button",
            "text": { "tag": "plain_text", "content": "✅ 完成1" },
            "type": "primary",
            "value": { "action": "complete", "id": "1" }
          },
          {
            "tag": "button",
            "text": { "tag": "plain_text", "content": "✅ 完成2" },
            "type": "primary",
            "value": { "action": "complete", "id": "2" }
          }
        ]
      }
    ]
  }
}
```

**按钮回调处理**：OpenClaw 收到按钮点击后，会传入 `action=complete&id=X` 格式的文本，本 skill 解析后执行完成逻辑。

## reminder-checker 逻辑（每分钟执行）

当 cron 每分钟触发本 skill 时，传入消息为 `__CRON_CHECK__`（约定标记）。

此时 skill 执行以下逻辑：

```
IF 消息内容 == "__CRON_CHECK__":
    读取 tasks.json
    IF date != 今天:
        # 跨天了，任务作废，跳过
        RETURN

    IF active == false:
        RETURN

    now = 当前时间 (HH:MM)
    today = 今天日期字符串

    # 1. 检查特殊时间点提醒
    FOR each task WHERE scheduled_time == now AND notified_special == false AND completed == false:
        发送时间点提醒卡片
        标记 notified_special = true

    # 2. 检查是否需要发周期性提醒
    IF last_periodic_reminder 不存在 OR 距今 >= 30分钟:
        筛选 completed == false 的任务
        IF 有未完成任务:
            发送周期性提醒卡片（带上完成按钮）
            更新 last_periodic_reminder = now

    写回 tasks.json
    RETURN
```

## 0点清理逻辑

在每天 00:00 触发的 cron job 中：

```
读取 tasks.json
IF date != 今天:
    # 已经清理过，直接写一个今日空任务
    写 tasks.json { date: 今天, active: false, tasks: [] }
    RETURN

# date == 今天，说明上次是昨天开的提醒
IF active == true:
    发送飞书："🌙 今日提醒已结束，所有任务已清空"
设置 tasks = []
active = false
date = 今天
写回 tasks.json
```

## 按钮回调处理

当用户点击飞书卡片的"完成"按钮时，OpenClaw 会发送按钮的 `value` 字段作为文本。本 skill 解析：

```
IF 文本匹配 { "action": "complete", "id": "X" }:
    找到 id == X 的任务
    标记 completed = true
    写回 tasks.json
    回复确认消息
```

## 序号 id 的稳定性

用户看到的序号就是 JSON 中的 `id`。完成或增加操作不改变已有任务的 id。删除操作也不改变 id（任务标记 completed=true，仍在列表中但不再显示）。

## 时间解析正则参考

```python
# 时间解析
patterns = [
    (r'凌晨(\d+)点', lambda m: f"{int(m.group(1))}:00"),
    (r'早上(\d+)点', lambda m: f"{int(m.group(1))}:00"),
    (r'上午(\d+)点', lambda m: f"{int(m.group(1))}:00"),
    (r'下午(\d+)点', lambda m: f"{int(m.group(1))+12}:00"),
    (r'晚上(\d+)点', lambda m: f"{int(m.group(1))+12}:00"),
    (r'(\d{1,2}):(\d{2})', lambda m: f"{int(m.group(1))}:{m.group(2)}"),
]
```

## 外部依赖

- OpenClaw 的 `message` 工具（发送飞书消息）
- `read` / `write` 工具（读写 tasks.json）
- cron 调度：每分钟触发一次 skill（OpenClaw 配置）
- 00:00 cron 触发清理（OpenClaw 配置）

## 注意事项

1. **不依赖 skill 内部状态**：所有状态都在 tasks.json，每次调用都重新读取
2. **时间比较用 HH:MM 字符串比较**：前提是时间格式补零（如 09:05 而不是 9:5）
3. **按钮回调的 action 格式**：与 OpenClaw 的飞书集成方式相关，如有问题可简化为纯文本指令交互
4. **30分钟间隔容错**：判断 `>= 30分钟` 而非严格 `== 30分钟`，避免因分钟精度丢失导致少发提醒
