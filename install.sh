#!/bin/bash
# GitHub Automation Skills 安装脚本

set -e

INSTALL_DIR="$HOME/.openclaw"
SCRIPTS_DIR="$INSTALL_DIR/scripts"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "🦞 GitHub Automation Skills 安装程序"
echo "========================================"

# 创建目录
echo "📁 创建目录..."
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$SYSTEMD_DIR"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/queue/messages"
mkdir -p "$INSTALL_DIR/queue/sent"
mkdir -p "$INSTALL_DIR/queue/feishu"

# 复制脚本
echo "📋 复制脚本..."
cp scripts/*.sh "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR"/*.sh

# 复制 systemd 配置
echo "⚙️  复制 systemd 配置..."
cp systemd/*.service "$SYSTEMD_DIR/"
cp systemd/*.timer "$SYSTEMD_DIR/"

# 重新加载 systemd
echo "🔄 重新加载 systemd..."
systemctl --user daemon-reload

# 启用并启动所有定时器
echo "🚀 启用定时器..."
timers=(
  "software-quality-scan"
  "random-github-comment"
  "github-pr-review"
  "github-auto-pr"
)

for timer in "${timers[@]}"; do
  echo "  - 启用 $timer.timer"
  systemctl --user enable "$timer.timer"
done

echo ""
echo "✅ 安装完成！"
echo ""
echo "📝 下一步："
echo "1. 复制配置文件: cp config/config.example.json ~/.openclaw/config.json"
echo "2. 编辑配置文件，填入你的 GitHub token 和飞书配置"
echo "3. 启动所有定时器: ./start-all.sh"
echo ""
echo "📊 查看状态: systemctl --user list-timers | grep -E 'quality|github|random'"
