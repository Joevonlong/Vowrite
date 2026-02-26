# Vowrite 🎙️

> **macOS AI 语音键盘** — 自然说话，自动将润色后的文字插入光标位置。

[🇬🇧 English](README.md)

<p align="center">
  <img src="VowriteApp/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

Vowrite 是一款轻量级 macOS 菜单栏应用，将你的语音转化为整洁、润色过的文字，直接插入到光标所在位置。基于 OpenAI Whisper 语音识别和 GPT 文本润色。

不用打字，开口就行。

---

## ✨ 功能特性

- 🎤 **语音转文字** — 按下快捷键，说话，文字自动出现
- ✨ **AI 润色** — 自动去除口头禅、修正语法、添加标点
- 🌍 **多语言支持** — 中文、英文、中英混合
- 📋 **智能输入** — 文字直接出现在光标位置
- 🎯 **零权限回退** — 无辅助功能权限时自动切换 Unicode 逐字输入
- 🎨 **浮动录音条** — 极简录音界面 + 实时波形动画
- ⌨️ **自定义快捷键** — 默认 `⌥ 空格`（Option + Space）
- 📊 **历史记录** — 浏览和搜索过往的语音输入
- 🔌 **多供应商** — OpenAI、OpenRouter、Groq、Together AI、DeepSeek 或自定义

## 🚀 快速开始

### 下载

从 [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases) 下载最新版本。

### 从源码构建

```bash
cd VowriteApp
./build.sh
```

或手动构建：

```bash
cd VowriteApp
swift build -c release
cp .build/arm64-apple-macosx/release/Vowrite Vowrite.app/Contents/MacOS/Vowrite
codesign -fs - --deep --entitlements Resources/Vowrite.entitlements Vowrite.app
open Vowrite.app
```

### 设置

1. 启动 Vowrite — 菜单栏出现 🎤 图标
2. 打开 **设置** → 输入 API Key（[从 OpenAI 获取](https://platform.openai.com/api-keys)）
3. 授权 **麦克风** 和 **辅助功能** 权限
4. 按 `⌥ 空格` 开始录音，再按一次停止
5. 文字自动插入到光标位置 ✨

## 🔧 工作原理

```
🎤 录音 → 📝 转录 → ✨ 润色 → 📋 插入
```

1. **录音** — 通过 AVAudioEngine 采集 AAC 音频
2. **转录** — 发送至 Whisper API 进行语音识别
3. **润色** — GPT 清理口头禅、修正语法、添加标点
4. **插入** — 通过剪贴板粘贴或 Unicode 逐字输入到光标位置

### 文字注入方式

| 方式 | 速度 | 需要 |
|------|------|------|
| **剪贴板粘贴**（默认） | ⚡ 瞬间 | 辅助功能权限 |
| **Unicode 逐字输入**（回退） | 快速 | 无需任何权限 |

Vowrite 自动检测权限状态，选择最佳方式。

## 🔌 支持的供应商

| 供应商 | 语音模型 | 润色模型 |
|--------|---------|---------|
| **OpenAI** | whisper-1 | gpt-4o-mini |
| OpenRouter | whisper-large-v3 | gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B-Instruct-Turbo |
| DeepSeek | whisper-1 | deepseek-chat |
| 自定义 | 可配置 | 可配置 |

## 📁 项目结构

```
VowriteApp/
├── App/                        # 应用生命周期与状态
├── Core/
│   ├── Audio/                  # 麦克风录音
│   ├── STT/                    # 语音转文字 (Whisper)
│   ├── AI/                     # 文本润色 (GPT)
│   ├── TextInjection/          # 光标文字注入
│   ├── Hotkey/                 # 全局快捷键
│   └── Keychain/               # API Key 安全存储
├── Views/                      # SwiftUI 视图
├── Models/                     # SwiftData 数据模型
├── Resources/                  # Info.plist、Entitlements
└── build.sh                    # 构建脚本
```

## 📋 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- 支持的供应商 API Key（推荐 OpenAI）
- 麦克风权限
- 辅助功能权限（推荐，非必须）

## 🗺️ 路线图

- [x] **v0.1** — 核心语音输入功能
- [x] **v0.2** — 发布打包与错误处理
- [ ] **v0.3** — 自定义 Prompt、多输出模式
- [ ] **v0.4** — 实时流式转录、本地 Whisper
- [ ] **v1.0** — 代码签名、公证、自动更新

详见[完整路线图](ops/ROADMAP.md)。

## 📄 许可证

MIT License — 详见 [LICENSE](LICENSE)。

## 🤝 参与贡献

欢迎贡献！请先创建 Issue 讨论你想做的改动。
