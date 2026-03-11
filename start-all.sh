#!/bin/bash
# 启动所有 GitHub 自动化定时器

echo "🚀 启动所有 GitHub 自动化定时器..."
echo ""

timers=(
  "software-quality-scan"
  "random-github-comment"
  "github-pr-review"
  "github-auto-pr"
)

for timer in "${timers[@]}"; do
  echo "启动 $timer.timer..."
  systemctl --user start "$timer.timer"
done

echo ""
echo "✅ 所有定时器已启动"
echo ""
echo "📊 当前状态:"
systemctl --user list-timers | grep -E "quality|github|random|UNIT"
