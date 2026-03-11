#!/bin/bash
# GitHub Auto PR - 随机选择有 3 轮以上评论的 issue，使用 acpx 修复并创建 PR
# 每 53 分钟运行一次

set -e

LOG_FILE="/home/yhm/.openclaw/logs/github-auto-pr.log"
STATE_FILE="/home/yhm/.openclaw/workspace/github-auto-pr-state.json"
WORKSPACE="/home/yhm/.openclaw/workspace"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "========== 开始 GitHub Auto PR 任务 =========="

# 获取所有非 fork 仓库
REPOS=$(gh repo list --limit 50 --json nameWithOwner,isFork 2>/dev/null | jq -r '.[] | select(.isFork == false) | .nameWithOwner')

if [ -z "$REPOS" ]; then
  log "ERROR: 无法获取仓库列表"
  exit 1
fi

# 收集有 3 轮以上评论的 issues
ISSUES_FILE=$(mktemp)
echo "[]" > "$ISSUES_FILE"

for repo in $REPOS; do
  log "检查仓库: $repo"
  
  # 获取 open issues
  issues=$(gh issue list --repo "$repo" --state open --limit 30 --json number,title,body,comments,createdAt 2>/dev/null || echo '[]')
  
  # 筛选评论数 >= 3 的 issues
  filtered=$(echo "$issues" | jq --arg repo "$repo" '[.[] | select(.comments >= 3) | . + {repo: $repo}]')
  
  if [ "$filtered" != "[]" ]; then
    jq -s 'add' "$ISSUES_FILE" <(echo "$filtered") > "${ISSUES_FILE}.tmp" 2>/dev/null || true
    mv "${ISSUES_FILE}.tmp" "$ISSUES_FILE" 2>/dev/null || true
  fi
done

ISSUE_COUNT=$(jq 'length' "$ISSUES_FILE")
log "找到 $ISSUE_COUNT 个有 3+ 评论的 issues"

if [ "$ISSUE_COUNT" -eq 0 ]; then
  log "没有符合条件的 issues"
  rm -f "$ISSUES_FILE"
  exit 0
fi

# 随机选择一个 issue
SELECTED=$(jq '.[range(length) | . as $i | [$i] | .[]] | .[env.RANDOM | tonumber % length]' "$ISSUES_FILE" 2>/dev/null || jq '.[0]' "$ISSUES_FILE")
rm -f "$ISSUES_FILE"

REPO=$(echo "$SELECTED" | jq -r '.repo')
ISSUE_NUMBER=$(echo "$SELECTED" | jq -r '.number')
ISSUE_TITLE=$(echo "$SELECTED" | jq -r '.title')
ISSUE_BODY=$(echo "$SELECTED" | jq -r '.body')

log "选中: $REPO#$ISSUE_NUMBER - $ISSUE_TITLE"

# 获取 issue 的评论内容（用于提取复现步骤和错误日志）
COMMENTS=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --comments --json comments 2>/dev/null | jq -r '.comments[].body' 2>/dev/null || echo "")
COMMENTS_STR=$(echo "$COMMENTS" | tr '\n' ' ' | head -c 2000)

# 构建 acpx 提示词
PR_PROMPT="请基于以下GitHub Issue内容，生成一个专业、结构化的Pull Request描述，包含所有必要部分：

【Issue信息】
Issue标题：$ISSUE_TITLE
Issue编号：#$ISSUE_NUMBER
Issue内容：$ISSUE_BODY
复现步骤：从评论中提取
错误日志：从评论中提取

【要求】
1. 标题：使用\"fix: 修复{简短问题描述} (#$ISSUE_NUMBER)\"格式，不超过70字符
2. 结构：
   - **问题描述**：清晰说明Issue中报告的问题，包含现象和影响范围
   - **根本原因分析**：深入分析问题产生的技术原因，指出具体代码位置（文件+行号）
   - **解决方案**：详细说明修复方案和实现思路
   - **修改内容**：列出所有变更文件及主要修改点
   - **测试验证**：描述测试方法、结果和覆盖率
   - **关联Issue**：使用\"Fixes #$ISSUE_NUMBER\"自动关闭Issue
   - **潜在影响**：说明可能影响的其他模块或功能
3. 语言：中文，专业术语准确，避免模糊表述
4. 格式：使用Markdown，适当使用列表和强调

【开发要求】
1. 首先分析 issue 内容，理解问题
2. 编写测试用例（TDD 方式）
3. 实现修复代码
4. 运行测试确保通过
5. 创建 PR 并使用上述描述模板
"

# 保存提示词到文件
PROMPT_FILE="$WORKSPACE/auto-pr-prompt-$ISSUE_NUMBER.txt"
echo "$PR_PROMPT" > "$PROMPT_FILE"

log "开始使用 acpx 修复 issue..."

# 使用 acpx 运行 opencode
ACPX_RESULT=$(acpx run opencode \
  --repo "$REPO" \
  --prompt-file "$PROMPT_FILE" \
  --timeout 3600 \
  --worktree \
  2>&1)

if echo "$ACPX_RESULT" | grep -qi "success\|completed\|pr created"; then
  log "acpx 执行成功"
  
  # 提取 PR URL
  PR_URL=$(echo "$ACPX_RESULT" | grep -oE 'https://github\.com/[^ ]+pull/[0-9]+' | head -1)
  
  if [ -n "$PR_URL" ]; then
    log "PR 已创建: $PR_URL"
    
    # 更新状态
    jq -n \
      --arg last_run "$(date -Iseconds)" \
      --arg repo "$REPO" \
      --arg issue "$ISSUE_NUMBER" \
      --arg pr_url "$PR_URL" \
      --arg title "$ISSUE_TITLE" \
      '{last_run: $last_run, last_repo: $repo, last_issue: $issue, pr_url: $pr_url, last_title: $title}' \
      > "$STATE_FILE"
  fi
else
  log "acpx 执行可能失败: $ACPX_RESULT"
fi

# 清理
rm -f "$PROMPT_FILE"

log "任务完成"
