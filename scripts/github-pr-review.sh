#!/bin/bash
# GitHub PR Review - 随机选择仓库的 PR 进行代码审核
# 每 39 分钟运行一次

set -e

LOG_FILE="/home/yhm/.openclaw/logs/github-pr-review.log"
STATE_FILE="/home/yhm/.openclaw/workspace/github-pr-review-state.json"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "========== 开始 GitHub PR Review 任务 =========="

# 获取所有非 fork 仓库
REPOS=$(gh repo list --limit 50 --json nameWithOwner,isFork 2>/dev/null | jq -r '.[] | select(.isFork == false) | .nameWithOwner')

if [ -z "$REPOS" ]; then
  log "ERROR: 无法获取仓库列表"
  exit 1
fi

# 收集所有 open PRs
PRS_FILE=$(mktemp)
echo "[]" > "$PRS_FILE"

for repo in $REPOS; do
  prs=$(gh pr list --repo "$repo" --state open --limit 20 --json number,title,author,createdAt 2>/dev/null || echo '[]')
  
  if [ "$prs" != "[]" ]; then
    prs_with_repo=$(echo "$prs" | jq --arg repo "$repo" '[.[] | . + {repo: $repo}]')
    jq -s 'add' "$PRS_FILE" <(echo "$prs_with_repo") > "${PRS_FILE}.tmp" 2>/dev/null || true
    mv "${PRS_FILE}.tmp" "$PRS_FILE" 2>/dev/null || true
  fi
done

PR_COUNT=$(jq 'length' "$PRS_FILE")
log "找到 $PR_COUNT 个 open PRs"

if [ "$PR_COUNT" -eq 0 ]; then
  log "没有找到 open PRs"
  rm -f "$PRS_FILE"
  exit 0
fi

# 随机选择一个 PR
RANDOM_INDEX=$((RANDOM % PR_COUNT))
SELECTED=$(jq ".[$RANDOM_INDEX]" "$PRS_FILE")
rm -f "$PRS_FILE"

REPO=$(echo "$SELECTED" | jq -r '.repo')
PR_NUMBER=$(echo "$SELECTED" | jq -r '.number')
PR_TITLE=$(echo "$SELECTED" | jq -r '.title')
PR_AUTHOR=$(echo "$SELECTED" | jq -r '.author.login')

log "选中: $REPO#$PR_NUMBER - $PR_TITLE (by $PR_AUTHOR)"

# 获取 PR 的 diff 和文件变更
PR_DIFF=$(gh pr diff "$PR_NUMBER" --repo "$REPO" 2>/dev/null | head -c 10000 || echo "")
PR_FILES=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json files --jq '.files[].path' 2>/dev/null || echo "")

# 获取已有的 review 评论（避免重复）
EXISTING_REVIEWS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" 2>/dev/null | jq -r '.[].body' 2>/dev/null || echo "")

# 构建 review 提示词
REVIEW_PROMPT="作为开发人员，我想请您执行 GitHub 合并请求代码审核

考虑下面提到的先前评论，避免重复类似的建议。
如果您发现反复出现的问题，请跳过它。
对于安全问题或敏感信息泄露，请在 @ 中提及受理人的用户名。

提供清晰、简洁且可操作的反馈，并提供具体的改进建议。

根据以下标准查看下面的代码片段：
- 语法和样式：查找语法错误和与约定的偏差。
- 性能优化：提出更改建议以提高效率。
- 安全实践：检查漏洞和硬编码密钥（掩盖一半信息）。
- 测试处理：检查测试覆盖是否充分。
- 错误处理：识别未处理的异常或错误。
- 代码质量：查找代码异味、不必要的复杂性或冗余代码。
- Bug 检测：查找潜在 Bug 或逻辑错误。

【PR 信息】
仓库: $REPO
PR 编号: #$PR_NUMBER
标题: $PR_TITLE
作者: @$PR_AUTHOR

【变更文件】
$PR_FILES

【代码 Diff】
\`\`\`diff
$PR_DIFF
\`\`\`

【已有的 Review 评论】
$EXISTING_REVIEWS

请生成专业的代码审核评论，使用 Markdown 格式。
"

# 使用 opencode 进行 review
log "使用 acpx 进行代码审核..."

REVIEW_RESULT=$(acpx run opencode \
  --prompt "$REVIEW_PROMPT" \
  --timeout 600 \
  2>&1)

# 提取 review 内容
REVIEW_BODY=$(echo "$REVIEW_RESULT" | grep -A 1000 "代码审核" | grep -B 1000 "^--$" | head -c 8000 || echo "$REVIEW_RESULT")

if [ -n "$REVIEW_BODY" ]; then
  # 提交 review
  REVIEW_URL=$(gh pr review "$PR_NUMBER" --repo "$REPO" --body "$REVIEW_BODY" --comment 2>&1)
  
  if echo "$REVIEW_URL" | grep -qi "review\|submitted"; then
    log "Review 提交成功"
    
    # 更新状态
    jq -n \
      --arg last_run "$(date -Iseconds)" \
      --arg repo "$REPO" \
      --arg pr "$PR_NUMBER" \
      --arg title "$PR_TITLE" \
      --arg author "$PR_AUTHOR" \
      '{last_run: $last_run, last_repo: $repo, last_pr: $pr, last_title: $title, last_author: $author}' \
      > "$STATE_FILE"
  else
    log "Review 提交失败: $REVIEW_URL"
  fi
else
  log "未能生成 review 内容"
fi

log "任务完成"
