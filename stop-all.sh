#!/bin/bash
# 停止所有 GitHub 自动化定时器

echo "🛑 停止所有 GitHub 自动化定时器..."
echo ""

timers=(
  "software-quality-scan"
  "random-github-comment"
  "github-pr-review"
  "github-auto-pr"
)

for timer in "${timers[@]}"; do
  echo "停止 $timer.timer..."
  systemctl --user stop "$timer.timer"
  systemctl --user stop "$timer.service"
done

echo ""
echo "✅ 所有定时器已停止"
