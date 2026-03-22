#!/bin/bash
# Daily Reminder Skill 安装脚本

set -e

echo "📋 Daily Reminder Skill 安装向导"

# 1. 创建目录
echo "1. 创建必要的目录..."
mkdir -p ~/.newmax/skills
mkdir -p ~/.newmax/daily-reminder

# 2. 复制 Skill
echo "2. 安装 Skill..."
if [ -L ~/.newmax/skills/daily-reminder ]; then
    echo "   Skill 已存在（软链接），跳过"
elif [ -d ~/.newmax/skills/daily-reminder ]; then
    echo "   Skill 目录已存在，备份后更新..."
    mv ~/.newmax/skills/daily-reminder ~/.newmax/skills/daily-reminder.bak.$(date +%Y%m%d%H%M%S)
fi
ln -sf "$(pwd)" ~/.newmax/skills/daily-reminder

# 3. 初始化 tasks.json
echo "3. 初始化任务数据文件..."
if [ ! -f ~/.newmax/daily-reminder/tasks.json ]; then
    echo '{"date":"","active":false,"tasks":[],"last_periodic_reminder":null}' > ~/.newmax/daily-reminder/tasks.json
    echo "   tasks.json 已创建"
else
    echo "   tasks.json 已存在，跳过"
fi

# 4. 复制 cron 配置
echo "4. 配置 Cron Jobs（需要手动合并到 ~/.openclaw/cron/jobs.json）..."
if [ -f ~/.openclaw/cron/jobs.json ]; then
    echo "   检测到已有 cron/jobs.json，请在 ~/.openclaw/cron/jobs.json 中手动添加以下内容："
    cat <<'EOF'

   {
     "id": "daily-reminder-checker",
     "description": "每分钟检查是否有需要发送的飞书提醒",
     "schedule": { "kind": "cron", "expr": "* * * * *", "tz": "Asia/Shanghai" },
     "payload": { "kind": "agentTurn", "message": "__CRON_CHECK__", "deliver": false },
     "session": { "kind": "isolated" },
     "enabled": true
   },
   {
     "id": "daily-reminder-midnight-clear",
     "description": "每天0点清空任务列表",
     "schedule": { "kind": "cron", "expr": "0 0 * * *", "tz": "Asia/Shanghai" },
     "payload": { "kind": "agentTurn", "message": "__MIDNIGHT_CLEAR__", "deliver": false },
     "session": { "kind": "isolated" },
     "enabled": true
   }

EOF
else
    echo "   创建 cron/jobs.json..."
    cp config-examples/openclaw-cron-jobs.json ~/.openclaw/cron/jobs.json
fi

# 5. 添加 skill 到 openclaw.json
echo "5. 配置 Skill 启用（需要手动合并到 ~/.openclaw/openclaw.json）..."
echo '   在 openclaw.json 的 skills.entries 中添加：'
echo '   "daily-reminder": { "enabled": true }'

# 6. 重启提示
echo ""
echo "✅ 安装完成！"
echo ""
echo "请执行以下步骤："
echo "1. 编辑 ~/.openclaw/openclaw.json，添加 skill 配置"
echo "2. 重启 OpenClaw"
echo "3. 开始使用：告诉 OpenClaw「开始每日提醒」"
