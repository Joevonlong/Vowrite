<p align="center">
  <img src="VowriteMac/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

<h1 align="center">Vowrite</h1>

<p align="center">
  <strong>macOS & iOS AI 语音键盘</strong><br>
  自然说话，润色后的文字直接出现在光标位置。
</p>

<p align="center">
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/badge/release-v0.2.0.0-blue?style=flat-square" alt="Release"></a>
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/github/downloads/Joevonlong/Vowrite/total?style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Joevonlong/Vowrite?style=flat-square" alt="License"></a>
  <a href="https://github.com/Joevonlong/Vowrite/stargazers"><img src="https://img.shields.io/github/stars/Joevonlong/Vowrite?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20iOS%2017%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.10%2B-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README_CN.md">中文</a> · <a href="README_DE.md">Deutsch</a>
</p>

---

<p align="center">
  <code>🎤 录音</code> → <code>📝 转录</code> → <code>✨ 润色</code> → <code>📋 插入</code>
</p>

Vowrite 是一款轻量级 macOS 菜单栏应用（+ iOS 键盘），将你的语音转化为整洁、润色过的文字，直接插入到光标所在位置。支持 15+ AI 服务商进行语音识别和文本润色。

不用打字，开口就行。

## ✨ 功能特性

| | 功能 | 说明 |
|---|------|------|
| 🎤 | **语音转文字** | 按下快捷键，说话，文字自动出现 |
| ✨ | **AI 润色** | 自动去除口头禅、修正语法、添加标点 |
| 🌍 | **多语言支持** | 中文、英文、中英混合，Deepgram 支持 36+ 语言 |
| 📋 | **智能输入** | 文字直接出现在光标位置 |
| 🎯 | **全场景适配** | 原生应用、浏览器、Discord、VS Code 等 |
| ⚡ | **预测式 LLM** | 录音时预热连接——每次听写省 ~200–500ms |
| 🔌 | **15+ 服务商** | OpenAI、Groq、DeepSeek、Deepgram、Gemini、Claude、讯飞、MLX Server 等 |
| 🔑 | **密钥库** | API Key 按服务商存入 macOS 钥匙串，填一次全局复用 |
| 📝 | **文本替换** | 自动纠正词汇，弹性模式匹配（STT 后 + LLM 后双位置替换） |
| 🧠 | **自动学词** | 从你的修改中学习——自动将纠正的词汇加入词库 |
| 🎨 | **录音指示器** | Orb Pulse 呼吸光球动画 |
| 🔊 | **声音反馈** | 开始、成功、错误的音效提示 |
| ⌨️ | **自定义快捷键** | 默认 `⌥ 空格`，可自由配置 |
| 📊 | **历史与统计** | 浏览历史记录，追踪节省时间和每分钟字数 |
| 📱 | **iOS 键盘** | 作为系统级键盘扩展的语音输入 |

## 🚀 快速开始

### 下载

从 [**Releases**](https://github.com/Joevonlong/Vowrite/releases) 下载最新 `.dmg`。

### 从源码构建

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
swift build        # 仅编译
./build.sh         # 编译、签名并启动
```

### 设置

1. 启动 Vowrite — 菜单栏出现 🎤 图标
2. 打开 **设置** → 选择预设或输入 API Key（⭐ 推荐：[Groq](https://console.groq.com/keys) 转录 + [DeepSeek](https://platform.deepseek.com/api_keys) 润色）
3. 授权 **麦克风** 和 **辅助功能** 权限
4. 按 `⌥ 空格` 开始录音，再按一次停止
5. 文字自动插入到光标位置 ✨

## 🔌 支持的服务商

### STT（语音转文字）

| 服务商 | 模型 | 协议 | 备注 |
|--------|------|------|------|
| **⭐ Groq** | whisper-large-v3-turbo | OpenAI 兼容 | 快速，有免费额度 |
| **OpenAI** | whisper-1, gpt-4o-transcribe | OpenAI | 官方 |
| **Deepgram** | Nova-3, Nova-2 | 原生（Token 认证 + 二进制上传） | 36+ 语言 |
| **火山引擎** | — | OpenAI 兼容 | 字节跳动 |
| **通义千问** | — | OpenAI 兼容 | 阿里云 |
| **硅基流动** | SenseVoice | OpenAI 兼容 | 中文优化 |
| **讯飞** | — | WebSocket (HMAC-SHA256) | 支持 23 种中文方言 |
| **Sherpa** | — | 离线 (sherpa-onnx) | 完全本地运行（脚手架） |
| **自定义** | 可配置 | OpenAI 兼容 | 任何端点 |

### Polish（文本润色）

| 服务商 | 默认模型 | 备注 |
|--------|---------|------|
| **⭐ DeepSeek** | deepseek-chat | 性价比高 |
| **OpenAI** | gpt-4o-mini | 全家桶 |
| **Gemini** | gemini-2.0-flash | Google |
| **Claude** | claude-sonnet | Anthropic 原生 API |
| **智谱 GLM** | glm-4-flash | OpenAI 兼容 |
| **Groq** | llama-3.1-8b | 快速推理 |
| **Kimi** | kimi-k2.5 | 月之暗面 |
| **MiniMax** | MiniMax-Text-02 | — |
| **火山引擎** | — | 字节跳动 |
| **通义千问** | — | 阿里云 |
| **硅基流动** | Qwen/DeepSeek/GLM | 多模型 |
| **Ollama** | 本地模型 | 100% 离线 |
| **MLX Server** | 本地模型 | Apple Silicon 原生，无需 API Key |
| **OpenRouter** | gpt-4o-mini | 多模型网关 |
| **Together AI** | Llama-3.1-8B | 开源模型 |
| **自定义** | 可配置 | 任何 OpenAI 兼容端点 |

## 🔧 工作原理

```
语音 → STT 服务商 → AI 润色 → 光标注入
```

**预测式管线：** 录音时预热连接，STT 请求预构建——润色文字比串行处理快 ~200–500ms。

**文字注入** 使用剪贴板 + CGEvent 模拟 Cmd+V，在所有应用中稳定工作，包括 Electron 应用（Discord、VS Code、Slack）。

## 📁 项目结构

```
Vowrite/
├── VowriteKit/                 # 共享核心库 (macOS + iOS)
│   └── Sources/VowriteKit/
│       ├── Audio/              # 麦克风录音 (AVAudioEngine)
│       ├── Services/           # STT 适配器、AI 润色、连接测试
│       ├── Config/             # providers.json 注册表、API 配置、预设、密钥库
│       ├── Engine/             # DictationEngine——跨平台编排器
│       ├── Models/             # SwiftData 模型 (DictationRecord, Mode, Replacement 等)
│       ├── Protocols/          # 平台抽象 (TextOutput, Permissions 等)
│       └── Replacement/        # ReplacementManager, 弹性匹配, 自动学习
├── VowriteMac/                 # macOS 应用 (菜单栏 + 设置窗口)
│   └── Sources/
│       ├── App/                # 应用生命周期、状态、窗口管理
│       ├── Platform/           # macOS 专有：快捷键、文字注入、浮窗、Sparkle
│       └── Views/              # SwiftUI 视图 (设置、历史、引导等)
├── VowriteIOS/                 # iOS 应用 (Tab 式 UI)
│   └── Sources/
│       ├── App/                # 应用生命周期、状态
│       ├── Platform/           # iOS 专有：剪贴板输出、触觉反馈、权限
│       └── Views/              # SwiftUI 视图 (主页、录音、设置等)
└── docs/                       # 网站 (GitHub Pages → vowrite.com)
```

## 📋 系统要求

### macOS
- macOS 14.0 (Sonoma) 或更高版本
- 支持的服务商 API Key
- 麦克风权限
- 辅助功能权限 *（推荐，用于光标注入）*

### iOS
- iOS 17.0 或更高版本
- 支持的服务商 API Key
- 麦克风权限

## 🤖 AI Agent 指南

本节面向在此代码库工作的 AI/LLM agent（Claude Code、Cursor、Copilot 等）。

### 快速开始

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteMac
swift build                     # 验证编译
```

### 优先阅读

- **`CLAUDE.md`** — 项目规范、架构、编译命令、提交格式、完成协议
- **`CONTRIBUTING.md`** — 贡献指南（如存在）
- **`Vowrite/CHANGELOG.md`** — 发布历史

### 运行测试

```bash
cd Vowrite && ops/scripts/test.sh
```

无单元测试 target——测试为脚本驱动（编译验证、安全扫描、Bundle 校验）。

### 模块指南

| 模块 | 作用 |
|------|------|
| `VowriteKit/Audio/` | 通过 AVAudioEngine 录音 → 临时 .m4a |
| `VowriteKit/Services/` | STT 适配器（OpenAI、Deepgram、讯飞等）+ AIPolishService（流式 GPT） |
| `VowriteKit/Config/` | `providers.json` 注册表、`APIProvider`、`ProviderRegistry`、预设、密钥库 |
| `VowriteKit/Engine/` | `DictationEngine`——跨平台编排器（录音 → 转录 → 润色 → 输出） |
| `VowriteKit/Models/` | SwiftData 模型：`DictationRecord`、`Mode`、`ReplacementRule` |
| `VowriteKit/Replacement/` | `ReplacementManager`——文本替换规则、弹性匹配、自动学习 |
| `VowriteMac/Platform/` | macOS 专有：`HotkeyManager`（Carbon）、`TextInjector`（CGEvent）、`MacOverlayController`、Sparkle |
| `VowriteIOS/` | iOS 应用 + 键盘扩展 |

### 添加新服务商

1. 编辑 `VowriteKit/Sources/VowriteKit/Config/providers.json`——添加包含 `id`、`name`、`baseURL`、`capabilities`（stt/polish）和 `models` 的条目
2. 如果服务商使用标准 OpenAI 兼容 API，到此完成——`ProviderRegistry` 会自动处理
3. 如果服务商使用非标准协议（如 Deepgram 的二进制上传或讯飞的 WebSocket），在 `VowriteKit/Services/` 中创建新的 `STTAdapter`

### 添加新 STT 适配器

1. 在 `VowriteKit/Sources/VowriteKit/Services/` 中创建新文件（如 `MySTTAdapter.swift`）
2. 遵循 `STTAdapter` 协议——实现 `transcribe(audioURL:language:)` → `String`
3. 在 STT 路由器（`WhisperService`）中注册适配器

### 发布流程

```bash
cd Vowrite && ops/scripts/release.sh v0.2.1.0 "简短描述"
git push origin main --tags
gh release create v0.2.1.0 releases/Vowrite-v0.2.1.0.dmg --title "Vowrite v0.2.1.0 — 描述"
```

发布脚本自动处理：更新 changelog → 版本号更新（Info.plist + SettingsView.swift）→ release 编译 → DMG 打包 → git commit + 带注释 tag。

### 规范

- **提交格式：** `<type>: <description>` — 类型：feat, fix, docs, refactor, chore, security, style, test
- **分支：** `main` 用于发布；`feature/F-{ID}-{slug}` 用于功能开发
- **版本号：** 4 段式 `MAJOR.MINOR.PATCH.BUILD`
- **无外部 Swift 依赖** — 仅使用系统框架

## 🗺️ 路线图

详见[完整路线图](ops/ROADMAP.md)。

## 📝 更新日志

详见 [CHANGELOG.md](CHANGELOG.md) 或 [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases)。

## 🤝 参与贡献

欢迎贡献！请先[创建 Issue](https://github.com/Joevonlong/Vowrite/issues) 讨论你想做的改动。

## 📄 许可证

[MIT](LICENSE)

---

<p align="center">
  Made with 🎤 by <a href="https://github.com/Joevonlong">Joe Long</a>
</p>
