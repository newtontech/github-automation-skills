#!/bin/bash
# SONAR 项目贡献任务
# 每天凌晨 5:11 运行

set -e

REPO="lyulixing/SONAR-Your-Local-First-AI-Network-Intelligence-Assistant"
LOG_FILE="/home/yhm/.openclaw/logs/sonar-contribution.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "========== 开始 SONAR 项目贡献任务 =========="

# 获取现有 issues
log "获取现有 issues..."
EXISTING_ISSUES=$(gh issue list --repo "$REPO" --state all --limit 50 --json number,title 2>/dev/null || echo '[]')

# 创新建议库
declare -A IDEAS
IDEAS["AI-Powered Relationship Graph Visualization"]="添加交互式网络图可视化，使用 D3.js 或 Cytoscape.js 展示人脉关系强度和聚类"
IDEAS["Smart Follow-up Scheduler"]="基于 ML 的智能跟进时间建议，根据历史响应模式优化联系时机"
IDEAS["Relationship Health Score"]="关系健康度评分：结合交互频率、最近联系时间和情感分析的综合指标"
IDEAS["Contact Enrichment APIs"]="联系人数据增强：集成 LinkedIn、Clearbit、Hunter 等数据源"
IDEAS["Multi-language Support (i18n)"]="添加国际化支持，让全球用户都能使用"
IDEAS["Team Collaboration Mode"]="团队协作模式：共享联系人同时保护隐私"
IDEAS["Export to CRM"]="导出到主流 CRM：Salesforce、HubSpot、Pipedrive"
IDEAS["Mobile App Companion"]="移动端伴侣应用：React Native 实现"
IDEAS["Duplicate Detection"]="智能重复检测与合并：使用模糊匹配算法"
IDEAS["Privacy-Preserving Analytics"]="隐私保护分析：使用差分隐私技术"

# 随机选择一个
KEYS=("${!IDEAS[@]}")
RANDOM_KEY="${KEYS[$RANDOM % ${#KEYS[@]}]}"
TITLE="$RANDOM_KEY"
DESCRIPTION="${IDEAS[$RANDOM_KEY]}"

log "选中的建议: $TITLE"

# 检查是否已存在
if echo "$EXISTING_ISSUES" | jq -r '.[].title' | grep -qi "$TITLE"; then
  log "类似 issue 已存在，跳过"
  exit 0
fi

# 构建 issue 内容
BODY="## 📝 功能描述

$DESCRIPTION

## 💡 为什么重要

作为本地优先的人脉管理工具，这个功能可以：
- 提升用户的工作效率
- 增强人脉数据的价值
- 改善整体用户体验

## 🔍 参考实践

基于同类产品（Clay、Dex、Nat、Monica）和 CRM 最佳实践的建议。

## 📋 建议实现步骤

1. 调研现有解决方案和竞品
2. 设计用户界面和 API 接口
3. 实现核心功能
4. 添加测试覆盖
5. 更新用户文档

## ✅ 验收标准

- [ ] 功能按设计实现
- [ ] 单元测试覆盖 > 80%
- [ ] 文档已更新
- [ ] 无性能退化

---
🤖 由 OpenClaw 自动分析生成
📅 基于软件工程最佳实践
🔍 参考同类产品和行业标准"

# 创建 issue
log "创建 Issue..."
ISSUE_URL=$(gh issue create --repo "$REPO" \
  --title "[Enhancement] $TITLE" \
  --body "$BODY" \
  2>&1 || echo "")

if echo "$ISSUE_URL" | grep -q "https://"; then
  log "Issue 创建成功: $ISSUE_URL"
  
  # 发送飞书通知
  QUEUE_FILE="/home/yhm/.openclaw/queue/messages/sonar-$(date +%s).json"
  mkdir -p "$(dirname "$QUEUE_FILE")"
  
  MESSAGE="✅ **SONAR 项目贡献完成**

📦 项目: \`$REPO\`
💡 建议: $TITLE
📝 类型: Enhancement
🔗 [查看 Issue]($ISSUE_URL)

---
🕐 $(date '+%Y-%m-%d %H:%M:%S')
🤖 OpenClaw 自动任务"
  
  jq -n \
    --arg action "send" \
    --arg channel "feishu" \
    --arg target "chat:oc_e0bf5463900f1305c26b5c052bb3850e" \
    --arg message "$MESSAGE" \
    '{action: $action, channel: $channel, target: $target, message: $message}' \
    > "$QUEUE_FILE"
  
  log "飞书通知已写入队列"
else
  log "Issue 创建失败: $ISSUE_URL"
fi

log "任务完成"
