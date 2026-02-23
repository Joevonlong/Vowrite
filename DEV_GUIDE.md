# Voxa 开发指南

## 构建与部署

### 编译
```bash
cd /Users/unclejoe/Dev_Workspace/Voxa/VoxaApp
swift build
```

### 部署到 Voxa.app
```bash
# 1. 复制二进制
cp .build/arm64-apple-macosx/debug/Voxa Voxa.app/Contents/MacOS/Voxa

# 2. 重新签名（必须！否则辅助功能权限失效）
codesign --force --sign - Voxa.app

# 3. 如果是首次部署或权限失效：
#    系统设置 → 隐私与安全性 → 辅助功能 → 添加 Voxa.app
```

### ⚠️ 重要：每次替换二进制后必须重新签名

Ad-hoc 签名的 app，每次替换二进制后 codesign 哈希值会改变，macOS TCC（隐私权限系统）会认为是"新的 app"，之前授予的辅助功能权限就失效了。

**解决方法**：替换二进制后执行 `codesign --force --sign -`，这样 identifier 会从 Info.plist 读取（`com.voxa.app`），保持稳定。如果权限仍然失效，需要在辅助功能设置里先删除再重新添加 Voxa。

---

## 文字注入方案（核心功能）

### 最终方案：剪贴板 + Cmd+V（Maccy 方案）

参考 Maccy（GitHub 12k+ stars 剪贴板管理器）的经过验证的实现。

**关键参数（不要改！）**：

| 参数 | 正确值 | 错误值（之前的坑） |
|------|--------|-------------------|
| CGEventSource | `.combinedSessionState` | ~~`.hidSystemState`~~ |
| Event tap | `.cgSessionEventTap` | ~~`.cghidEventTap`~~ |
| Modifier flags | `.maskCommand \| 0x000008` | ~~仅 `.maskCommand`~~ |
| 本地事件抑制 | `setLocalEventsFilterDuringSuppressionState` | ~~无~~ |

### 核心代码
```swift
let source = CGEventSource(stateID: .combinedSessionState)
source?.setLocalEventsFilterDuringSuppressionState(
    [.permitLocalMouseEvents, .permitSystemDefinedEvents],
    state: .eventSuppressionStateSuppressionInterval
)
let cmdFlag = CGEventFlags(rawValue: UInt64(CGEventFlags.maskCommand.rawValue) | 0x000008)
let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
keyDown?.flags = cmdFlag
keyUp?.flags = cmdFlag
keyDown?.post(tap: .cgSessionEventTap)
keyUp?.post(tap: .cgSessionEventTap)
```

### 曾经尝试过但不可靠的方案

| 方案 | 问题 |
|------|------|
| AX API 直接插入 (`kAXSelectedTextAttribute`) | 对原生 app 有效，但 Electron 应用（Discord、VS Code）不支持 |
| `postToPid()` | 不可靠，事件经常无法到达目标进程 |
| `.cghidEventTap` | 在 macOS 14+ 上跨进程不可靠 |
| Unicode 逐字输入 | 太慢，中文支持不确定 |

---

## 权限清单

Voxa 需要以下系统权限才能正常工作：

- [x] **麦克风** — 录音用（首次启动会自动请求）
- [x] **辅助功能** — CGEvent 模拟按键用（需手动添加）
- [ ] **输入监控** — 部分系统可能需要（如果辅助功能不够）

### 检查权限是否生效

在 app 中调用 `AXIsProcessTrusted()` 返回 `true` 即为正常。如果返回 `false`，需要重新在辅助功能中添加 Voxa。

---

## 浮窗（RecordingOverlay）注意事项

- 使用 `NonActivatingPanel`（`.nonactivatingPanel` 样式），不会抢占目标 app 的焦点
- `canBecomeMain` 返回 `false`
- 隐藏浮窗后，系统会自动将焦点还给之前的 app
- **不需要手动 activate 目标 app** — 系统自动处理焦点恢复（但代码里仍做了 activate 作为保险）

---

## 问题排查

### 文字无法插入到目标 app

1. 检查 `AXIsProcessTrusted()` 是否为 `true`
2. 检查是否替换了二进制但忘了重新签名
3. 检查辅助功能权限是否包含 Voxa
4. 查看控制台日志：`log show --predicate 'process == "Voxa"' --last 5m | grep TextInjector`

### 特定 app 无法粘贴

- Electron 应用（Discord、Slack、VS Code）：Cmd+V 方案有效，AX API 方案无效
- 密码输入框：Secure Input 模式下所有方案都无效（这是系统限制）
- Terminal：可能需要 Cmd+V 而非其他方案

---

*最后更新：2026-02-27*
*参考：Maccy (github.com/p0deje/Maccy) Clipboard.swift paste() 方法*
