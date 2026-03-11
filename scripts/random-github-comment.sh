#!/bin/bash
# 随机选择 GitHub issue 并发表评论
# 权重规则：最新的 issue 权重最高，老的 issue 按指数衰减保持低权重

set -e

LOG_FILE="/home/yhm/.openclaw/logs/random-github-comment.log"
STATE_FILE="/home/yhm/.openclaw/workspace/random-comment-state.json"
COMMENTED_FILE="/home/yhm/.openclaw/workspace/random-commented-issues.json"

# 加载飞书通知库
source /home/yhm/.openclaw/scripts/feishu-lib.sh

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$STATE_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 初始化已评论文件
if [ ! -f "$COMMENTED_FILE" ]; then
  echo '{}' > "$COMMENTED_FILE"
fi

log "开始执行随机评论任务"

# 获取所有仓库
REPOS=$(gh repo list --limit 50 --json nameWithOwner 2>/dev/null | jq -r '.[].nameWithOwner')

if [ -z "$REPOS" ]; then
  log "ERROR: 无法获取仓库列表"
  notify_failure "随机评论失败" "无法获取仓库列表"
  exit 1
fi

# 收集所有 open issues
ISSUES_FILE=$(mktemp)
echo "[]" > "$ISSUES_FILE"

for repo in $REPOS; do
  # 跳过 fork 的仓库
  is_fork=$(gh repo view "$repo" --json isFork 2>/dev/null | jq -r '.isFork' || echo "false")
  if [ "$is_fork" = "true" ]; then
    continue
  fi
  
  # 获取 issues
  repo_issues=$(gh issue list --repo "$repo" --state open --limit 20 --json number,title,createdAt 2>/dev/null || echo '[]')
  
  if [ "$repo_issues" != "[]" ]; then
    echo "$repo_issues" | jq --arg repo "$repo" '[.[] | . + {repo: $repo}]' >> /tmp/issues_batch.json
    jq -s 'add' "$ISSUES_FILE" /tmp/issues_batch.json > "${ISSUES_FILE}.tmp" 2>/dev/null || true
    mv "${ISSUES_FILE}.tmp" "$ISSUES_FILE" 2>/dev/null || true
    rm -f /tmp/issues_batch.json
  fi
done

ISSUE_COUNT=$(jq 'length' "$ISSUES_FILE")
log "找到 $ISSUE_COUNT 个 open issues"

if [ "$ISSUE_COUNT" -eq 0 ]; then
  log "没有找到 open issues"
  rm -f "$ISSUES_FILE"
  exit 0
fi

# 计算权重并选择 issue
NOW=$(date +%s)

SELECTED=$(python3 << PYTHON_SCRIPT
import json
import math
import random
from datetime import datetime

with open('$ISSUES_FILE') as f:
    issues = json.load(f)

with open('$COMMENTED_FILE') as f:
    commented = json.load(f)

now = $NOW

weighted = []
for issue in issues:
    created = datetime.fromisoformat(issue['createdAt'].replace('Z', '+00:00'))
    age_seconds = now - int(created.timestamp())
    age_days = age_seconds / 86400
    
    base_weight = math.exp(-age_days / 30)
    
    key = f"{issue['repo']}#{issue['number']}"
    if key in commented:
        base_weight *= 0.5
    
    weighted.append((issue, base_weight))

total = sum(w for _, w in weighted)
r = random.random() * total
cumsum = 0
selected = None
for issue, w in weighted:
    cumsum += w
    if cumsum >= r:
        selected = issue
        break

if selected:
    print(json.dumps(selected))
PYTHON_SCRIPT
)

rm -f "$ISSUES_FILE"

if [ -z "$SELECTED" ] || [ "$SELECTED" = "null" ]; then
  log "选择 issue 失败"
  notify_failure "随机评论失败" "无法选择 issue"
  exit 1
fi

REPO=$(echo "$SELECTED" | jq -r '.repo')
ISSUE_NUMBER=$(echo "$SELECTED" | jq -r '.number')
ISSUE_TITLE=$(echo "$SELECTED" | jq -r '.title')

log "选中: $REPO#$ISSUE_NUMBER - $ISSUE_TITLE"

# 获取 issue 标签
ISSUE_DATA=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json labels 2>/dev/null)
ISSUE_LABELS=$(echo "$ISSUE_DATA" | jq -r '.labels[].name' 2>/dev/null || echo "")

# 生成评论内容
COMMENT_FILE=$(mktemp)
cat > "$COMMENT_FILE" << 'EOF'
## 🤖 自动评论

感谢创建这个 issue！我来补充一些想法：

EOF

# 根据 issue 标签生成不同内容
if echo "$ISSUE_LABELS" | grep -qi "bug\|fix"; then
  cat >> "$COMMENT_FILE" << 'EOF'
### 问题分析

这个问题看起来值得深入调查。建议：
1. 收集更多复现步骤
2. 检查相关日志
3. 确认影响范围

EOF
elif echo "$ISSUE_LABELS" | grep -qi "feature\|enhancement"; then
  cat >> "$COMMENT_FILE" << 'EOF'
### 功能建议评估

这个功能想法很有价值！考虑因素：
- 用户需求强度
- 实现复杂度
- 与现有功能的协调

EOF
else
  cat >> "$COMMENT_FILE" << 'EOF'
### 通用建议

- 可以考虑添加更多上下文信息
- 如果有相关 PR 或讨论，可以链接过来
- 标签分类有助于后续跟踪

EOF
fi

cat >> "$COMMENT_FILE" << EOF

---
*🕐 评论时间: $(date '+%Y-%m-%d %H:%M:%S %Z')*
*🤖 由 OpenClaw 自动生成*
EOF

# 发表评论
COMMENT_URL=$(gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body-file "$COMMENT_FILE" 2>&1)
rm -f "$COMMENT_FILE"

if echo "$COMMENT_URL" | grep -q "https://"; then
  log "评论成功: $COMMENT_URL"
  
  # 记录已评论的 issue
  KEY="$REPO#$ISSUE_NUMBER"
  jq --arg key "$KEY" --arg time "$(date -Iseconds)" '. + {($key): $time}' "$COMMENTED_FILE" > "${COMMENTED_FILE}.tmp" 2>/dev/null || true
  mv "${COMMENTED_FILE}.tmp" "$COMMENTED_FILE" 2>/dev/null || true
  
  # 发送飞书通知
  DETAILS="📦 仓库: \`$REPO\`
📝 Issue: #$ISSUE_NUMBER
📌 标题: $ISSUE_TITLE
💬 [查看评论]($COMMENT_URL)"
  
  notify_success "GitHub 随机评论完成" "$DETAILS"
else
  log "评论失败: $COMMENT_URL"
  notify_failure "随机评论失败" "仓库: $REPO\nIssue: #$ISSUE_NUMBER\n错误: $COMMENT_URL"
fi

# 更新状态文件
jq -n \
  --arg last_run "$(date -Iseconds)" \
  --arg repo "$REPO" \
  --arg issue "$ISSUE_NUMBER" \
  --arg title "$ISSUE_TITLE" \
  --arg url "$COMMENT_URL" \
  '{last_run: $last_run, last_repo: $repo, last_issue: $issue, last_title: $title, comment_url: $url}' \
  > "$STATE_FILE"

log "任务完成"
