# Voxa 文字注入问题 — 完整分析报告

## 一、问题描述

语音识别完成后，文字无法插入到目标应用的光标位置。剪贴板里有内容，但文字没有被粘贴/输入到输入框中。

---

## 二、当前 Voxa 的实现方案

### 流程
1. 用户按快捷键 → `startRecording()` → `saveFrontmostApp()` 记录当前活跃的 app
2. 显示录音浮窗（NonActivatingPanel）
3. 用户说话 → 再按快捷键停止
4. 发送音频到 Whisper API → 得到文字 → AI 润色
5. 隐藏浮窗
6. 调用 `textInjector.inject(text)` → 激活之前的 app → 注入文字

### 当前注入策略（修改后版本）
- **方案 A（主）**: Accessibility API 直接插入 — `AXUIElementSetAttributeValue(kAXSelectedTextAttribute)`
- **方案 B（备）**: 剪贴板 + Cmd+V — `NSPasteboard` 设内容 → `CGEvent` 模拟 Cmd+V
- **方案 C（备）**: Unicode 逐字输入 — `CGEvent` 逐字符发送

---

## 三、所有可能的失败原因

### ❌ 权限问题（最可能的原因）

| 原因 | 说明 | 影响 |
|------|------|------|
| **辅助功能权限未授予** | Voxa 没有在「系统设置 → 隐私与安全 → 辅助功能」中被允许 | AX API 调用返回失败；CGEvent 无法发送键盘事件到其他进程 |
| **输入监控权限未授予** | 「隐私与安全 → 输入监控」中未允许 | CGEvent 键盘事件无法到达目标 app |
| **AXIsProcessTrusted() 返回 false** | App 未被系统信任 | 所有 AX 和 CGEvent 方案全部失效 |
| **Ad-hoc 签名** | App 用 adhoc 签名，没有 Team ID | 每次替换二进制后，TCC 权限记录失效，需要重新授权 |

### ❌ 代码层面问题

| 原因 | 说明 |
|------|------|
| **CGEventSource 使用错误** | Voxa 用 `.hidSystemState`，Maccy（业界标杆）用 `.combinedSessionState` |
| **CGEvent 发送目标错误** | Voxa 用 `.cghidEventTap`，Maccy 用 `.cgSessionEventTap` |
| **缺少 modifier flags 的左/右标记位** | Maccy 额外加了 `0x000008`（NX_COMMANDMASK），表示具体是左 Command 键 |
| **没有抑制本地键盘事件** | Maccy 在粘贴时调用 `setLocalEventsFilterDuringSuppressionState` 防止干扰 |
| **目标 App 未真正激活** | `app.activate()` 是异步的，不保证返回时 app 已获得焦点 |
| **AX 方案对 Web 应用无效** | Chrome/Safari 等浏览器中的文本框，`kAXSelectedTextAttribute` 可能不可写 |

### ❌ 时序问题

| 原因 | 说明 |
|------|------|
| **浮窗关闭后焦点未回到目标 app** | 虽然用了 NonActivatingPanel，但 hide 后焦点可能回到 Voxa 主进程 |
| **剪贴板恢复过早** | 原来是 1.5s 后恢复，如果目标 app 读取剪贴板慢就会失败 |
| **录音启动时焦点已变** | 如果用户通过菜单栏（而非快捷键）启动录音，Voxa 可能已成为前台 app |

### ❌ 系统/环境问题

| 原因 | 说明 |
|------|------|
| **macOS 安全策略升级** | macOS 14+ 对 CGEvent 跨进程注入限制更严格 |
| **目标 app 拒绝程序化输入** | 某些 app（如 Terminal、部分 Electron app）不接受外部 CGEvent |
| **Secure Input 模式** | 如果目标 app 启用了 Secure Input（如密码框），所有注入方式都会被阻止 |

---

## 四、业界标杆方案调研

### 1. Maccy（剪贴板管理器，GitHub 12k+ stars）— 源码分析

**核心粘贴代码**（`Clipboard.swift` → `paste()` 方法）：

```swift
func paste() {
    Accessibility.check()
    
    let cmdFlag = CGEventFlags(rawValue: UInt64(KeyChord.pasteKeyModifiers.rawValue) | 0x000008)
    var vCode = Sauce.shared.keyCode(for: KeyChord.pasteKey)
    
    if KeyboardLayout.current.commandSwitchesToQWERTY && cmdFlag.contains(.maskCommand) {
        vCode = KeyChord.pasteKey.QWERTYKeyCode
    }
    
    let source = CGEventSource(stateID: .combinedSessionState)
    source?.setLocalEventsFilterDuringSuppressionState(
        [.permitLocalMouseEvents, .permitSystemDefinedEvents],
        state: .eventSuppressionStateSuppressionInterval
    )
    
    let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: true)
    let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: false)
    keyVDown?.flags = cmdFlag
    keyVUp?.flags = cmdFlag
    keyVDown?.post(tap: .cgSessionEventTap)
    keyVUp?.post(tap: .cgSessionEventTap)
}
```

**关键差异**：

| 要素 | Voxa（当前） | Maccy（正确做法） |
|------|-------------|-----------------|
| CGEventSource | `.hidSystemState` | `.combinedSessionState` |
| Event tap | `.cghidEventTap` | `.cgSessionEventTap` |
| Modifier flags | 仅 `.maskCommand` | `.maskCommand \| 0x000008`（含左/右标记） |
| 本地事件抑制 | 无 | `setLocalEventsFilterDuringSuppressionState` |
| 焦点恢复 | 手动 activate + 轮询 | 关闭 popup 后系统自动恢复 |

**Maccy 的流程**（比 Voxa 简单得多）：
1. 用户在 Maccy 弹窗中选择条目
2. `Clipboard.copy(item)` — 把内容写入剪贴板
3. `popup.close()` — **先关闭弹窗**，让系统自动把焦点还给之前的 app
4. `Clipboard.paste()` — 然后发送 Cmd+V

**关键洞察：Maccy 不需要手动 activate 目标 app！** 它依赖系统在关闭弹窗后自动恢复焦点。

### 2. Superwhisper（商业语音输入工具）

和 Voxa 最相似的产品。从其功能描述看：
- 使用「Push to talk」模式
- 文字直接输入到当前焦点应用
- 支持所有应用（包括 Cursor、浏览器等）

Superwhisper 是闭源的，但根据行为分析，它很可能用的是 **剪贴板 + Cmd+V** 方案（和 Maccy 类似），因为：
- 用户报告粘贴后剪贴板内容会短暂变化
- 它要求辅助功能权限

### 3. macOS 原生听写（Dictation）

苹果自己的听写功能用的是完全不同的底层方案：
- 通过 **Input Method Kit (IMK)** 作为系统级输入法
- 直接通过 `NSTextInputClient` 协议与文本框通信
- 不需要剪贴板，不需要模拟按键
- 第三方 app 无法使用这个方案（需要作为系统输入法注册）

### 4. 方案可行性总结

| 方案 | 可靠性 | 兼容性 | 复杂度 | 说明 |
|------|--------|--------|--------|------|
| **剪贴板 + Cmd+V**（Maccy 方式） | ⭐⭐⭐⭐⭐ | 所有 app | 低 | 业界验证，最可靠 |
| AX API 直接设值 | ⭐⭐⭐ | 原生 app | 中 | 浏览器/Electron 可能不支持 |
| CGEvent Unicode 输入 | ⭐⭐ | 大部分 app | 低 | 慢，中文支持不确定 |
| Input Method Kit | ⭐⭐⭐⭐⭐ | 所有 app | 极高 | 需要作为输入法注册，开发量巨大 |
| AppleScript paste | ⭐⭐⭐ | 支持 AS 的 app | 低 | 不通用 |

---

## 五、结论与修复建议

### 根本原因（高概率）

1. **权限问题** — Ad-hoc 签名的 app 每次替换二进制后 TCC 权限会失效，需要重新授权
2. **CGEvent 参数错误** — 使用了错误的 EventSource 和 EventTap 类型

### 推荐修复方案

**采用 Maccy 的粘贴方案**（已被 12k+ stars 项目验证）：

1. 使用 `CGEventSource(stateID: .combinedSessionState)`
2. 使用 `.cgSessionEventTap` 而非 `.cghidEventTap`
3. Modifier flags 加上 `0x000008` 左键标记
4. 粘贴前调用 `setLocalEventsFilterDuringSuppressionState`
5. **先关闭浮窗 → 等系统恢复焦点 → 再粘贴**，不要手动 activate

### 权限检查清单

- [ ] 系统设置 → 隐私与安全 → **辅助功能** → 添加 Voxa
- [ ] 系统设置 → 隐私与安全 → **输入监控** → 添加 Voxa（如有）
- [ ] 每次替换 Voxa.app 二进制后，重新确认权限（因为 ad-hoc 签名）

---

*分析时间：2026-02-27*
*参考源码：Maccy v0.32+ (GitHub: p0deje/Maccy)*
