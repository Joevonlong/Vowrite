# Vowrite 测试体系

> 生成自 review charter v1，2026-05-15。

---

## ① 当前测试矩阵

| 目标 | 测试框架 | 测试数量 | 状态 |
|------|----------|----------|------|
| VowriteKit | XCTest（SPM testTarget） | 6 个测试用例 | ✅ 运行中 |
| VowriteMac | 无独立测试目标 | — | ⚠️ 仅构建验证 |
| VowriteIOS | 无独立测试目标（Xcode 项目） | — | ⚠️ 仅构建验证 |
| VowriteKeyboard | 无独立测试目标 | — | ⚠️ 仅构建验证 |

**现状说明：**

VowriteKit 的 SPM `Package.swift` 中定义了 `testTarget`，可通过 `swift test` 运行。VowriteMac、VowriteIOS、VowriteKeyboard 目前没有独立的单元测试目标，测试依赖脚本化构建验证（`ops/scripts/test.sh`）和手工冒烟。

---

## ② 如何添加单元测试

### VowriteKit（SPM testTarget）

VowriteKit 已有测试目标，直接在 `VowriteKit/Tests/VowriteKitTests/` 下添加测试文件：

```bash
# 运行现有测试
cd VowriteKit && swift test

# 运行特定测试
cd VowriteKit && swift test --filter VowriteKitTests.MyTestCase
```

新增测试类：

```swift
// VowriteKit/Tests/VowriteKitTests/MyServiceTests.swift
import XCTest
@testable import VowriteKit

final class MyServiceTests: XCTestCase {
    func testExample() async throws {
        // ...
    }
}
```

### VowriteMac（SPM executable）

VowriteMac 是 SPM executable target，可在 `Package.swift` 中添加 testTarget：

```swift
// 在 VowriteMac/Package.swift targets 数组中添加：
.testTarget(
    name: "VowriteMacTests",
    dependencies: ["VowriteMac", "VowriteKit"],
    path: "Tests/VowriteMacTests"
),
```

平台相关代码（CGEvent、Carbon API）在测试环境中需 mock。

### VowriteIOS / VowriteKeyboard（Xcode 项目）

通过 Xcode GUI 添加：

1. File → New → Target → Unit Testing Bundle
2. 选择 `VowriteIOS` 或 `VowriteKeyboard` 作为宿主 App
3. 测试文件放入新建的 `Tests/` 目录

注意：Keyboard Extension 测试受沙盒限制，网络和 Keychain 访问需 mock。

---

## ③ 手工冒烟清单（发版前必跑）

每次 stable 版本发布前，必须通过以下 10 个场景的手工验证：

### macOS

| # | 场景 | 验证点 | 期望结果 |
|---|------|--------|----------|
| 1 | **录音→转写→润色→粘贴** | 按下 Option+Space，说话，松开 | 润色后文本出现在当前焦点应用中 |
| 2 | **热键全局响应** | 在 Safari/VS Code/Terminal 中分别触发 | 每个应用均能正确注入文本 |
| 3 | **模式切换** | 在菜单栏切换不同模式，各录制一段 | 每种模式的提示词效果不同 |
| 4 | **翻译模式** | 使用翻译模式录制中文 | 输出为英文 |
| 5 | **Provider 切换** | 在设置中切换 STT 提供商（如 Groq→OpenAI），录制验证 | 两个提供商均能转写 |
| 6 | **历史记录** | 完成 3 次录制，打开历史记录面板 | 3 条记录显示，内容和时间戳正确 |
| 7 | **剪贴板恢复** | 在录制前复制一段文字，录制后 | 原剪贴板内容已恢复，不被覆盖 |
| 8 | **错误提示** | 在网络断开情况下录制 | 显示错误提示，不崩溃 |

### iOS / Keyboard

| # | 场景 | 验证点 | 期望结果 |
|---|------|--------|----------|
| 9 | **键盘扩展录音** | 在任意应用中切换到 Vowrite 键盘，点击录音按钮 | 录音完成后文字插入文本框 |
| 10 | **OAuth 登录** | 在 iOS 设置中完成 Google OAuth 流程 | 登录成功，token 存入 Keychain |

### 冒烟清单执行方式

```bash
# 跑自动化部分（构建 + 单测 + 安全扫描）
bash ops/scripts/test.sh

# 手工部分见上表，逐项在实机验证
```

---

## ④ 性能基线

| 指标 | 目标值 | 测量方法 |
|------|--------|----------|
| **首字延迟**（录音结束→第一个字符出现） | < 2.5 秒（WiFi）| 秒表测量，Instruments Timeline |
| **Keyboard 内存峰值** | < 60 MB | Xcode Memory Gauge / MemoryMonitor 类 |
| **release build 编译警告** | ≤ 4（当前基准） | `swift build -c release 2>&1 \| grep -c warning:` |
| **VowriteKit 测试通过率** | 100% | `swift test` |

性能基线回归检测集成在 `review-scan.sh` L1 步骤（warning 超基准时报 P2）。首字延迟和内存目标为手工测量，暂无自动化。

---

## ⑤ 覆盖率目标与现状

| 目标 | 当前覆盖率 | 目标覆盖率 | 说明 |
|------|----------|------------|------|
| VowriteKit 核心逻辑 | 估计 < 20% | 60% | 当前仅 6 个测试，DictationEngine 未覆盖 |
| AIPolishService | 0% | 50% | 需 mock URLSession |
| WhisperService | 0% | 50% | 需 mock URLSession |
| MacTextInjector | 0% | — | CGEvent 测试需真实会话，暂不可测 |
| Keyboard UI | 0% | 30% | 需 UITest |

**覆盖率测量：**

```bash
# SwiftPM 覆盖率（VowriteKit）
cd VowriteKit && swift test --enable-code-coverage
xcrun llvm-cov report \
    .build/debug/VowriteKitPackageTests.xctest/Contents/MacOS/VowriteKitPackageTests \
    --instr-profile .build/debug/codecov/default.profdata \
    --ignore-filename-regex ".build"
```

**路线图：** 覆盖率提升计划跟踪在 `tracking/TODO.md`（T-COV-001 系列）。优先覆盖 `DictationEngine`、`AIPolishService`（mock 网络层）和 `ModeManager`。
