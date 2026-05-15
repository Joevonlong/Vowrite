# Vowrite 安全说明

> 生成自 review charter v1，2026-05-15。  
> 本文档记录 Vowrite 的安全架构、数据流边界、隐私承诺和漏洞披露流程。

---

## ① 数据流概览

```
麦克风输入
    │
    ▼
AudioEngine（AVAudioEngine）
    │  录制为临时 .m4a 文件（/tmp/vowrite_*.m4a）
    │  录制结束后立即发送，发送后删除
    ▼
WhisperService / STTAdapter
    │  HTTPS POST 到 STT 提供商（OpenAI Whisper、Groq、Deepgram 等）
    │  请求体：音频二进制；响应体：转录文本
    ▼
AIPolishService
    │  HTTPS POST 到 LLM 提供商（OpenAI GPT-4o-mini 等）
    │  请求体：转录文本 + 系统提示；响应体：润色后文本（流式）
    │
    ├── macOS → MacTextInjector
    │       剪贴板 save → paste → Cmd+V CGEvent → 剪贴板 restore
    │
    └── iOS Keyboard → KeyboardViewController
            textDocumentProxy.insertText()

SwiftData（本地）
    │  DictationRecord：转录原文 + 润色结果 + 时间戳
    │  仅存储在设备本地，不上传
    ▼
历史记录（本地数据库）
```

**网络边界：** Vowrite 仅向用户配置的 STT 和 LLM 提供商发送数据。不存在 Vowrite 自有服务端。所有 API 调用使用 HTTPS（TLS 1.2+）。

---

## ② 凭据存储

### Keychain Access Group

所有 API 密钥通过 `KeychainHelper` / `KeyVault` 存储在系统 Keychain，从不写入磁盘文件、`UserDefaults` 或日志。

```
Access Group: C2H6PL267S.com.vowrite.shared
```

| 密钥类型 | 存储方式 | 共享范围 |
|----------|----------|----------|
| STT Provider API Key | Keychain item（kSecClassGenericPassword） | macOS App + 未来 iOS App |
| LLM Provider API Key | 同上 | 同上 |
| Google OAuth Tokens | Keychain item | App only |

### Google OAuth Token 生命周期

1. 用户通过 `GoogleAuthService` 完成 OAuth 2.0 流程（ASWebAuthenticationSession）
2. `access_token` 存入 Keychain，`refresh_token` 存入 Keychain
3. `access_token` 过期（1 小时）后自动使用 `refresh_token` 刷新
4. 用户登出时清除所有 Keychain 条目

### KeyVault 防护

`KeyVault` 在 Debug 构建中会对密钥进行混淆存储。生产构建禁止任何密钥出现在日志中（`transcript_log_guard` SwiftLint 规则以 error 级别检测此类泄漏）。

---

## ③ 隐私承诺

- **不上传非必要数据：** 只有当前录音的音频和转录文本会发送到第三方提供商，不发送设备信息、用户身份或历史记录。
- **本地优先：** 历史记录（DictationRecord）仅存储在设备本地 SwiftData 数据库，未连接任何 Vowrite 云服务。
- **日志脱敏：** 所有 Logger 调用不得包含转录原文（`rawTranscript`）、润色结果（`polished`）或 API 密钥。由 SwiftLint `transcript_log_guard` 规则在 CI 层强制检查。
- **临时文件清理：** 录音生成的 `.m4a` 文件在上传后立即删除（`AudioEngine` 负责清理）。
- **第三方隐私：** 数据实际由用户选择的提供商处理，Vowrite 不控制其存储策略。用户应审阅所用提供商的隐私政策。

---

## ④ App Sandbox 说明（macOS）

**macOS 版 Vowrite 关闭了 App Sandbox。**

原因：macOS App Sandbox 禁止应用向其他进程发送 `CGEvent`（键盘/鼠标事件）。Vowrite 的核心功能之一是将润色后文本注入用户当前聚焦的任意应用（通过模拟 Cmd+V 粘贴），这依赖 `CGEvent` 的 `cgSessionEventTap` + `combinedSessionState`，在 Sandbox 内无法工作。

**已知风险：**
- 无 Sandbox 意味着应用程序拥有与用户相同的文件系统权限
- 恶意代码（若存在）可访问用户 home 目录下所有文件

**缓解措施：**
- Vowrite 是开源软件，代码可审计
- gitleaks + pre-commit hook 防止密钥提交
- 所有网络调用使用 HTTPS，无中间人注入点
- 不捆绑任何闭源二进制（Sparkle 除外，Sparkle 有 EdDSA 签名验证）
- 发布包通过 Apple Notarization 公证

**替代方案评估：** Accessibility API（AXUIElement）理论上可在 Sandbox 内工作，但在 Electron、Chrome 等应用中行为不可靠（受 App 自身 Sandbox 策略影响）。Clipboard+Cmd+V 方案是目前唯一在所有应用中可靠工作的方法。

---

## ⑤ iOS Keyboard hasFullAccess 边界

iOS 键盘扩展（VowriteKeyboard）需要用户授予 **"完全访问"（Full Keyboard Access）** 才能进行网络请求。

| 能力 | 需要 Full Access |
|------|-----------------|
| 文字输入（textDocumentProxy） | 否 |
| 麦克风录音 | 是（iOS 系统要求） |
| 网络调用（STT/LLM API） | 是 |
| 访问 Keychain（shared group） | 是 |

**边界承诺：**
- 键盘扩展的网络请求**仅**发往用户配置的 STT/LLM 提供商
- 不收集输入内容、不上传未录音的文字
- `hasFullAccess == false` 时，录音按钮不可用，网络调用不发起
- 内存限制：扩展进程内存峰值目标 < 60 MB（见 `MemoryMonitor`）

---

## ⑥ 漏洞披露流程

**安全问题请通过以下方式私下报告，不要公开 Issue：**

- 邮箱：`security@vowrite.app`（占位；当前请发至 `longzhouleo@gmail.com`）
- 主题格式：`[SECURITY] 简短描述`

**处理流程：**

1. 收到报告后 48 小时内确认
2. 评估影响范围和严重级别（P0-P3）
3. P0/P1 问题：7 天内发布 hotfix 或临时缓解措施，同步告知报告者
4. 修复发布后，与报告者协商公开时间（通常 30 天）
5. 在 CHANGELOG.md 中记录安全修复（不包含利用细节）

**目前无 Bug Bounty 计划。** 我们对负责任的披露表示诚挚感谢。

---

## ⑦ 已知风险

当前 deep review 正在进行中，完整发现列表见：

```
Vowrite-internal/reviews/2026-05-15-deep-review/40-findings.md
```

> （占位：review charter v1 制定后，首次 deep review 将填充此路径。）

已知 P0/P1 风险概要（待 review 后更新）：

| ID | 风险 | 状态 |
|----|------|------|
| — | 首次 deep review 尚未完成 | 进行中 |

**发现后处理：** 所有 P0/P1 风险在进入下一个 stable release 前必须修复或有明确缓解措施。P2/P3 记录在 tracking/BUGS.md 并排期处理。
