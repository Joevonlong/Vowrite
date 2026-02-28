<p align="center">
  <img src="VowriteApp/Resources/AppIcon-source.png" alt="Vowrite" width="128">
</p>

<h1 align="center">Vowrite</h1>

<p align="center">
  <strong>macOS AI 语音键盘</strong><br>
  自然说话，润色后的文字直接出现在光标位置。
</p>

<p align="center">
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/github/v/release/Joevonlong/Vowrite?style=flat-square&label=release" alt="Release"></a>
  <a href="https://github.com/Joevonlong/Vowrite/releases"><img src="https://img.shields.io/github/downloads/Joevonlong/Vowrite/total?style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Joevonlong/Vowrite?style=flat-square" alt="License"></a>
  <a href="https://github.com/Joevonlong/Vowrite/stargazers"><img src="https://img.shields.io/github/stars/Joevonlong/Vowrite?style=flat-square" alt="Stars"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift">
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README_CN.md">中文</a> · <a href="README_DE.md">Deutsch</a>
</p>

---

<p align="center">
  <code>🎤 录音</code> → <code>📝 转录</code> → <code>✨ 润色</code> → <code>📋 插入</code>
</p>

Vowrite 是一款轻量级 macOS 菜单栏应用，将你的语音转化为整洁、润色过的文字，直接插入到光标所在位置。基于 Whisper 语音识别和 GPT 文本润色。

不用打字，开口就行。

## ✨ 功能特性

| | 功能 | 说明 |
|---|------|------|
| 🎤 | **语音转文字** | 按下快捷键，说话，文字自动出现 |
| ✨ | **AI 润色** | 自动去除口头禅、修正语法、添加标点 |
| 🌍 | **多语言支持** | 中文、英文、中英混合 |
| 📋 | **智能输入** | 文字直接出现在光标位置 |
| 🎯 | **全场景适配** | 原生应用、浏览器、Discord、VS Code 等 |
| 🎨 | **浮动录音条** | 极简界面 + 实时波形动画 |
| ⌨️ | **自定义快捷键** | 默认 `⌥ 空格`，可自由配置 |
| ⎋ | **ESC 取消** | 随时按 ESC 取消录音 |
| 📊 | **历史记录** | 浏览和搜索过往的语音输入 |
| 🔌 | **多供应商** | OpenAI、Groq、DeepSeek 等 |

## 🚀 快速开始

### 下载

从 [**Releases**](https://github.com/Joevonlong/Vowrite/releases) 下载最新 `.dmg`。

### 从源码构建

```bash
git clone https://github.com/Joevonlong/Vowrite.git
cd Vowrite/VowriteApp
./build.sh
```

### 设置

1. 启动 Vowrite — 菜单栏出现 🎤 图标
2. 打开 **设置** → 输入 API Key（[从 OpenAI 获取](https://platform.openai.com/api-keys)）
3. 授权 **麦克风** 和 **辅助功能** 权限
4. 按 `⌥ 空格` 开始录音，再按一次停止
5. 文字自动插入到光标位置 ✨

## 🔌 支持的供应商

| 供应商 | 语音模型 | 润色模型 |
|--------|---------|---------|
| **OpenAI** | whisper-1 | gpt-4o-mini |
| OpenRouter | whisper-large-v3 | gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B-Instruct-Turbo |
| DeepSeek | whisper-1 | deepseek-chat |
| 自定义 | 可配置 | 可配置 |

## 🔧 工作原理

```
语音 → Whisper 转录 → GPT 润色 → 光标注入
```

**文字注入** 自动选择最佳方式：

| 方式 | 速度 | 需要 |
|------|------|------|
| 剪贴板粘贴 *（默认）* | ⚡ 瞬间 | 辅助功能权限 |
| Unicode 逐字输入 *（回退）* | 快速 | 无需权限 |

## 📋 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- 支持的供应商 API Key
- 麦克风权限
- 辅助功能权限 *（推荐，非必须）*

## 🗺️ 路线图

详见[完整路线图](ops/ROADMAP.md)。

## 📝 更新日志

详见 [RELEASE_NOTES.md](RELEASE_NOTES.md) 或 [GitHub Releases](https://github.com/Joevonlong/Vowrite/releases)。

## 🤝 参与贡献

欢迎贡献！请先[创建 Issue](https://github.com/Joevonlong/Vowrite/issues) 讨论你想做的改动。

## 📄 许可证

[AGPL-3.0](LICENSE)

---

<p align="center">
  Made with 🎤 by <a href="https://github.com/Joevonlong">Joe Long</a>
</p>
