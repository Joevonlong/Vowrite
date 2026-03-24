# Vowrite — 需求清单

> 最后更新: 2026-03-25

## 🔑 必须提供（首次使用）

| 项目 | 说明 | 来源 | 状态 |
|---|---|---|---|
| AI API Key | STT + Polish 服务的 API 密钥（任选一家提供商） | 多提供商支持（见下方） | ✅ 已支持 Key Vault 管理 |

### 支持的提供商

| 提供商 | STT | Polish | 状态 |
|--------|-----|--------|------|
| OpenAI | ✅ Whisper/gpt-4o-transcribe | ✅ GPT-4o-mini 等 | ✅ |
| Groq | ✅ Whisper | ✅ | ✅ ⭐推荐 STT |
| DeepSeek | — | ✅ DeepSeek Chat | ✅ ⭐推荐 Polish |
| OpenRouter | — | ✅ 多模型 | ✅ |
| Ollama | ✅ 本地 Whisper | ✅ 本地模型 | ✅ |
| SiliconFlow | ✅ SenseVoice | ✅ Qwen/DeepSeek/GLM | ✅ 🇨🇳 |
| Kimi | — | ✅ kimi-k2.5/moonshot | ✅ 🇨🇳 |
| MiniMax | — | ✅ MiniMax-Text-02 | ✅ 🇨🇳 |
| Custom | ✅ | ✅ | ✅ 自定义 Base URL |

## 🔐 运行时权限

### macOS
| 权限 | 用途 | 授权方式 |
|---|---|---|
| 麦克风 | 录音 | 首次录音时系统弹窗 |
| 辅助功能 | 模拟 Cmd+V 粘贴 | 系统设置 → 隐私与安全 → 辅助功能 |

### iOS
| 权限 | 用途 | 授权方式 |
|---|---|---|
| 麦克风 | 录音 | 首次录音时系统弹窗 |
| 完全访问 | 键盘扩展网络访问 | 设置 → 键盘 → 允许完全访问 |

## 🏗️ 架构

```
VowriteKit/     ← 跨平台核心库（macOS 14+ / iOS 17+）
VowriteMac/     ← macOS 客户端（SPM，依赖 Kit + Sparkle）
VowriteIOS/     ← iOS 主应用（Xcode Project，依赖 Kit）
VowriteKeyboard/ ← iOS 键盘扩展（Xcode Target，依赖 Kit）
```
