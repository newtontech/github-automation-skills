#!/bin/bash
# 飞书通知函数库
# 直接发送消息到飞书

FEISHU_TARGET="chat:oc_e0bf5463900f1305c26b5c052bb3850e"
LOG_FILE="/home/yhm/.openclaw/logs/feishu-notify.log"

# 发送飞书通知
send_feishu() {
  local title="$1"
  local content="$2"
  local status="${3:-success}"
  
  local emoji="✅"
  [ "$status" = "failed" ] && emoji="❌"
  [ "$status" = "warning" ] && emoji="⚠️"
  
  local message="${emoji} **${title}**

${content}

---
🕐 $(date '+%Y-%m-%d %H:%M:%S %Z')
🤖 OpenClaw 自动任务"
  
  # 直接使用 openclaw CLI 发送
  if command -v openclaw &> /dev/null; then
    openclaw message send \
      --channel feishu \
      --target "$FEISHU_TARGET" \
      --message "$message" \
      >> "$LOG_FILE" 2>&1 && return 0
  fi
  
  # 备用：写入队列
  local queue_file="/home/yhm/.openclaw/queue/feishu/msg-$(date +%s%N).json"
  mkdir -p "$(dirname "$queue_file")"
  
  cat > "$queue_file" << EOF
{
  "target": "$FEISHU_TARGET",
  "message": $(echo "$message" | jq -Rs .),
  "created_at": "$(date -Iseconds)"
}
EOF
  
  return 1
}

# 快捷方法
notify_success() {
  send_feishu "$1" "$2" "success"
}

notify_failure() {
  send_feishu "$1" "$2" "failed"
}

notify_warning() {
  send_feishu "$1" "$2" "warning"
}
