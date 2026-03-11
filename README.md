# GitHub Automation Skills

🤖 带随机选择和网络搜索的 GitHub 自动化技能库

## 📋 功能特性

- ✅ **随机仓库扫描** - 每 23 分钟随机选择仓库 + 质量标准提 issue
- ✅ **加权随机评论** - 每 37 分钟按时间衰减权重选择 issue 评论
- ✅ **随机 PR 审核** - 每 39 分钟随机选择 PR 进行审核
- ✅ **智能自动 PR** - 每 53 分钟为多评论 issue 自动创建 PR
- ✅ **项目贡献** - 每天为指定项目贡献创新建议
- ✅ **飞书通知** - 所有任务完成后自动发送飞书通知

## 🚀 快速开始

```bash
# 克隆仓库
git clone https://github.com/newtontech/github-automation-skills.git
cd github-automation-skills

# 安装依赖
./install.sh

# 配置
cp config.example.json ~/.openclaw/config.json
# 编辑配置文件，填入你的 API keys

# 启动所有定时任务
./start-all.sh
```

## 📁 目录结构

```
github-automation-skills/
├── README.md
├── install.sh
├── start-all.sh
├── stop-all.sh
├── scripts/
│   ├── software-quality-scan.sh    # 软件质量扫描
│   ├── random-github-comment.sh    # 随机评论
│   ├── github-pr-review.sh         # PR 审核
│   ├── github-auto-pr.sh           # 自动 PR
│   ├── sonar-contribution.sh       # 项目贡献
│   └── feishu-lib.sh               # 飞书通知库
├── systemd/
│   ├── software-quality-scan.{service,timer}
│   ├── random-github-comment.{service,timer}
│   ├── github-pr-review.{service,timer}
│   ├── github-auto-pr.{service,timer}
│   └── sonar-contribution.{service,timer}
├── config/
│   └── config.example.json
└── docs/
    ├── quality-standards.md
    └── contribution-ideas.md
```

## 🔧 配置

### 必需的环境变量

- `GITHUB_TOKEN` - GitHub 个人访问令牌
- `FEISHU_WEBHOOK` - 飞书机器人 Webhook URL（可选）

### 质量标准库

项目包含 20 个软件工程质量标准：

- **设计原则**: SOLID, DRY, KISS, YAGNI
- **测试**: CODE_COVERAGE, TESTABILITY
- **质量**: MAINTAINABILITY, COMPLEXITY
- **安全**: SECURITY, ERROR_HANDLING
- **性能**: PERFORMANCE, CACHING
- **架构**: API_DESIGN, DATABASE
- **运维**: LOGGING, MONITORING, FAULT_TOLERANCE
- **工程化**: DOCUMENTATION, DEPENDENCY, CONFIG

## 📊 运行统计

查看日志：
```bash
tail -f ~/.openclaw/logs/software-quality-scan.log
tail -f ~/.openclaw/logs/random-github-comment.log
tail -f ~/.openclaw/logs/github-pr-review.log
```

查看状态：
```bash
systemctl --user list-timers | grep github
```

## 🤝 贡献

欢迎贡献新的技能和改进！

## 📄 许可证

MIT License

---

🤖 由 OpenClaw 自动化系统驱动
