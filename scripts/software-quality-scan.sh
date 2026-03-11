#!/bin/bash
# 软件工程质量扫描 - 随机选择仓库和质量标准，创建 issue
# 每 23 分钟运行一次

set -e

LOG_FILE="/home/yhm/.openclaw/logs/software-quality-scan.log"
STATE_FILE="/home/yhm/.openclaw/workspace/software-quality-state.json"

# 加载飞书通知库
source /home/yhm/.openclaw/scripts/feishu-lib.sh

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "========== 开始软件工程质量扫描 =========="

# 软件工程质量标准列表
QUALITY_STANDARDS=(
  "SOLID:SOLID 原则"
  "DRY:DRY 原则"
  "KISS:KISS 原则"
  "YAGNI:YAGNI 原则"
  "CODE_COVERAGE:测试覆盖率"
  "DOCUMENTATION:文档完整性"
  "ERROR_HANDLING:错误处理"
  "SECURITY:安全性"
  "PERFORMANCE:性能优化"
  "TESTABILITY:可测试性"
  "MAINTAINABILITY:可维护性"
  "COMPLEXITY:代码复杂度"
  "DEPENDENCY:依赖管理"
  "LOGGING:日志规范"
  "API_DESIGN:API 设计"
  "DATABASE:数据库设计"
  "CACHING:缓存策略"
  "CONFIG:配置管理"
  "MONITORING:监控告警"
  "FAULT_TOLERANCE:容错设计"
)

# 随机选择质量标准
STANDARD_INDEX=$((RANDOM % ${#QUALITY_STANDARDS[@]}))
SELECTED_STANDARD="${QUALITY_STANDARDS[$STANDARD_INDEX]}"
STANDARD_KEY="${SELECTED_STANDARD%%:*}"
STANDARD_DESC="${SELECTED_STANDARD#*:}"

log "选中的质量标准: $STANDARD_KEY - $STANDARD_DESC"

# 获取所有非 fork 仓库
REPOS=$(gh repo list --limit 50 --json nameWithOwner,isFork 2>/dev/null | jq -r '.[] | select(.isFork == false) | .nameWithOwner')

if [ -z "$REPOS" ]; then
  log "ERROR: 无法获取仓库列表"
  notify_failure "质量扫描失败" "无法获取仓库列表"
  exit 1
fi

# 随机选择仓库
REPO_ARRAY=($REPOS)
REPO_INDEX=$((RANDOM % ${#REPO_ARRAY[@]}))
SELECTED_REPO="${REPO_ARRAY[$REPO_INDEX]}"

log "选中的仓库: $SELECTED_REPO"

# 获取仓库信息
REPO_INFO=$(gh repo view "$SELECTED_REPO" --json description,primaryLanguage,stargazerCount 2>/dev/null)
LANGUAGE=$(echo "$REPO_INFO" | jq -r '.primaryLanguage.name // "Unknown"')
STARS=$(echo "$REPO_INFO" | jq -r '.stargazerCount')

log "仓库语言: $LANGUAGE, Stars: $STARS"

# 生成 issue 内容
ISSUE_BODY="## 问题描述

本项目需要改进 **$STANDARD_DESC** 方面的质量。

## 为什么重要

良好的软件工程实践可以：
- 提高代码可维护性
- 降低 Bug 率
- 提升团队协作效率

## 建议行动

1. 审查当前项目在 $STANDARD_KEY 方面的现状
2. 识别需要改进的地方
3. 制定改进计划
4. 逐步实施改进

## 验收标准

- [ ] 现状分析完成
- [ ] 改进计划制定
- [ ] 至少一项改进已实施

---
🤖 由 OpenClaw 软件工程质量扫描自动创建
📅 扫描标准: $STANDARD_KEY
🏷️ 仓库语言: $LANGUAGE"

# 创建 issue
log "创建 issue..."
ISSUE_URL=$(gh issue create --repo "$SELECTED_REPO" \
  --title "[Quality] $STANDARD_DESC" \
  --body "$ISSUE_BODY" 2>&1 || echo "")

if echo "$ISSUE_URL" | grep -q "https://"; then
  log "Issue 创建成功: $ISSUE_URL"
  
  # 更新状态
  jq -n \
    --arg last_run "$(date -Iseconds)" \
    --arg repo "$SELECTED_REPO" \
    --arg standard "$STANDARD_KEY" \
    --arg url "$ISSUE_URL" \
    --arg language "$LANGUAGE" \
    '{last_run: $last_run, last_repo: $repo, last_standard: $standard, issue_url: $url, language: $language}' \
    > "$STATE_FILE"
  
  # 发送飞书通知
  DETAILS="📦 仓库: \`$SELECTED_REPO\`
🎯 标准: $STANDARD_KEY
📝 语言: $LANGUAGE
🔗 [查看 Issue]($ISSUE_URL)"
  
  notify_success "软件工程质量扫描完成" "$DETAILS"
else
  log "Issue 创建失败: $ISSUE_URL"
  notify_failure "质量扫描失败" "仓库: $SELECTED_REPO\n错误: $ISSUE_URL"
fi

log "任务完成"
