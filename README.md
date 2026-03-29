# AutoTalk Pro

> 多渠道 AI 智能聊天助手桌面端 — 让 AI 替你回复微信、Telegram 和企业微信消息

---

## 产品简介

**AutoTalk Pro** 是一款桌面端 AI 智能聊天助手，支持同时接入微信、Telegram 和企业微信，利用大语言模型自动回复消息。适用于客服自动化、私域运营、个人助理等场景。

首次启动自动下载运行环境，**无需配置任何开发环境**，开箱即用。

---

## 核心功能

### 多渠道接入
| 渠道 | 登录方式 |
|------|----------|
| **微信** | 扫码登录（基于 wechatbot-webhook） |
| **Telegram** | 手机号 + 验证码（基于 GramJS） |
| **企业微信** | Corp ID + Agent ID + Secret |

### AI 智能回复
- **按会话独立开关**：每个对话可单独启用或关闭自动回复
- **半自动 / 全自动模式**：AI 生成建议后人工确认，或完全自动发送
- **群聊 @检测**：群聊中被 @提及时才触发 AI 回复
- **创意度调节**：Temperature 参数控制回复创造性

### AI 人设系统
- 支持自定义名称、职业、说话风格、行为规则和开场白
- 可创建多套人设并随时切换
- 适用于医生、客服、交易员等各种角色

### 安全与隐私
- 锁屏密码保护
- SQLite 本地存储，数据不上传
- API Key 加密存储

### 其他
- macOS + Windows 双平台
- 亮色 / 暗色主题
- 首次运行自动下载 Node.js 运行时

---

## 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS 10.15+ 或 Windows 10+ (64位) |
| 磁盘空间 | 至少 500 MB |
| 网络 | 首次启动需联网；海外 AI 模型需科学上网 |

---

## 下载安装

### 国内下载（Gitee）
https://gitee.com/zoushiyong_admin/AutoTalkPro/releases

### GitHub 下载
https://github.com/shiyongzou/AutoTalkPro/releases

下载对应平台的 zip 包解压即可使用。

---

## 支持的 AI 模型

| 平台 | 代表模型 | 需要科学上网 |
|------|----------|:---:|
| **DeepSeek** | DeepSeek-V3.2、DeepSeek-R1 | 否 |
| **通义千问** | qwen3-235b、qwen-max、qwen-turbo | 否 |
| **智谱 GLM** | glm-4-plus、glm-4 | 否 |
| **豆包** | doubao-pro-256k/32k/4k | 否 |
| **Moonshot** | moonshot-v1-8k/32k/128k | 否 |
| **MiniMax** | MiniMax-Text-01 | 否 |
| **Ollama 本地** | qwen2.5、llama3.3、deepseek-r1 | 否 |
| **OpenAI** | GPT-5.4、GPT-4.1、GPT-4o | 是 |
| **Claude** | claude-opus-4-6、claude-sonnet-4-6 | 是 |

国内用户推荐 **DeepSeek**（性价比最高）或 **Ollama**（完全免费本地运行）。

---

## 快速开始

1. 下载安装包，解压运行
2. 首次启动自动下载运行环境（约 1-2 分钟）
3. 选择渠道登录（微信扫码 / Telegram 验证码 / 企业微信配置）
4. 进入「AI设置」配置模型和 API Key
5. 进入「人设」设置 AI 角色
6. 在「会话」中对需要的对话开启自动回复

---

## 从源码构建

```bash
# 确保已安装 Flutter SDK >= 3.11
flutter pub get

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# 运行测试
flutter test
```

---

## 许可证

本项目为私有项目，未经授权不得分发或商用。
