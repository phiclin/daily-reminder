# daily-reminder

每日提醒 Skill for OpenClaw / Claude Code，支持飞书定时推送。

## 功能特性

- **每30分钟周期性提醒**：自动通过飞书推送未完成任务列表
- **特殊时间点提醒**：指定时间点的任务会在到达时间时单独提醒一次
- **完成确认**：支持回复「完成X」标记完成，或直接点击飞书卡片按钮
- **智能追加**：任务可随时增加，自动纳入下一次提醒
- **次日自动清空**：每天0点自动清空所有任务，无需手动处理
- **跨会话持久化**：任务状态存储在 JSON 文件，不依赖会话内存

## 效果预览

### 周期性提醒卡片

```
┌─────────────────────────────────────┐
│ 📋 今日待办提醒                     │
├─────────────────────────────────────┤
│ 09:30                               │
│ ─────────────────────────────────── │
│ 1. 给客户发邮件                     │
│ 2. 写周报                           │
│ 3. 下午3点开周会                    │
│ ─────────────────────────────────── │
│ 💡 回复「完成X」标记任务完成        │
└─────────────────────────────────────┘
```

### 时间点提醒卡片

```
┌─────────────────────────────────────┐
│ 🔔 时间提醒                         │
├─────────────────────────────────────┤
│ 现在时间：15:00                     │
│ 该做这件事了：开周会                │
└─────────────────────────────────────┘
```

## 系统要求

- OpenClaw 或 Claude Code
- 飞书消息渠道配置
- `message` 工具权限（发送飞书消息）
- `read`/`write` 工具权限（读写任务文件）
- cron 调度支持（每分钟触发）

## 安装

### 1. 安装 Skill

将 skill 复制到用户级 skills 目录：

```bash
mkdir -p ~/.newmax/skills
git clone https://github.com/YOUR_USERNAME/daily-reminder.git ~/.newmax/skills/daily-reminder
```

或创建软链接（方便更新）：

```bash
git clone https://github.com/YOUR_USERNAME/daily-reminder.git /tmp/daily-reminder
ln -sf /tmp/daily-reminder ~/.newmax/skills/daily-reminder
```

### 2. 在 OpenClaw 中启用 Skill

编辑 `~/.openclaw/openclaw.json`，添加：

```json
{
  "skills": {
    "entries": {
      "daily-reminder": {
        "enabled": true
      }
    }
  }
}
```

### 3. 创建任务数据目录

```bash
mkdir -p ~/.newmax/daily-reminder
echo '{"date":"","active":false,"tasks":[],"last_periodic_reminder":null}' > ~/.newmax/daily-reminder/tasks.json
```

### 4. 配置 Cron 调度

编辑 `~/.openclaw/cron/jobs.json`：

```json
{
  "version": 1,
  "jobs": [
    {
      "id": "daily-reminder-checker",
      "description": "每分钟检查是否有需要发送的飞书提醒",
      "schedule": {
        "kind": "cron",
        "expr": "* * * * *",
        "tz": "Asia/Shanghai"
      },
      "payload": {
        "kind": "agentTurn",
        "message": "__CRON_CHECK__",
        "deliver": false
      },
      "session": {
        "kind": "isolated"
      },
      "enabled": true
    },
    {
      "id": "daily-reminder-midnight-clear",
      "description": "每天0点清空任务列表",
      "schedule": {
        "kind": "cron",
        "expr": "0 0 * * *",
        "tz": "Asia/Shanghai"
      },
      "payload": {
        "kind": "agentTurn",
        "message": "__MIDNIGHT_CLEAR__",
        "deliver": false
      },
      "session": {
        "kind": "isolated"
      },
      "enabled": true
    }
  ]
}
```

### 5. 重启 OpenClaw

让配置生效。

## 使用方法

### 开始每日提醒

```
开始每日提醒：
1. 给客户发邮件
2. 写周报
3. 下午3点开周会
```

Skill 会解析任务列表，提取时间信息，立即发送一次确认。

### 完成任务

```
完成了2
```

或

```
完成第3条
```

### 增加任务

```
增加：下午4点对账
```

### 查看任务

```
看看任务
```

### 停止提醒

```
停止每日提醒
```

## 任务格式

### 支持的时间表达

- `下午3点` → 15:00
- `下午3点半` → 15:30
- `14:30` → 14:30（直接写时间）
- `凌晨5点` → 05:00
- `早上9点` → 09:00
- `晚上8点` → 20:00

### 无时间任务

纯描述任务只参与每30分钟周期性提醒，不触发单独的时间点提醒：

```
开始每日提醒：
1. 给客户发邮件
2. 写周报
```

### 带时间任务

时间任务既参与周期性提醒，又在到达时间点时单独提醒：

```
开始每日提醒：
1. 给客户发邮件
2. 下午3点开周会  ← 会在15:00单独提醒一次
```

## 数据存储

任务状态存储在 `~/.newmax/daily-reminder/tasks.json`：

```json
{
  "date": "2026-03-23",
  "active": true,
  "tasks": [
    {
      "id": 1,
      "text": "给客户发邮件",
      "scheduled_time": null,
      "completed": false,
      "notified_special": false
    },
    {
      "id": 2,
      "text": "开周会",
      "scheduled_time": "15:00",
      "completed": false,
      "notified_special": false
    }
  ],
  "last_periodic_reminder": "2026-03-23T09:00:00+08:00"
}
```

## 飞书卡片按钮

Skill 支持飞书卡片的交互按钮。按钮点击会触发 `action=complete&id=X` 回调，由 Skill 自动处理完成逻辑。

卡片设计可以根据飞书版本和渠道配置进行调整。

## 常见问题

### Q: cron job 触发了但没收到飞书消息

检查：
1. OpenClaw 的飞书渠道是否正常配置
2. `message` 工具是否在允许列表中
3. 查看 OpenClaw 日志排查

### Q: 怎么修改30分钟间隔？

编辑 cron job 配置，将 `expr` 从 `* * * * *` 改为 `*/30 * * * *`（每30分钟），然后将 SKILL.md 中的判断逻辑从 `>=30分钟` 改为严格 `==30分钟`。

### Q: 支持其他消息渠道吗？

Skill 通过 OpenClaw 的 `message` 工具发送消息，支持任何 OpenClaw 配置的渠道（飞书、Telegram、Discord 等）。

## License

MIT
