# Voxa v0.4 — Release Notes

**发布日期:** 2026-02-27
**标签:** v0.4

---

## 🔧 文字注入重写 + 🎨 波形动画升级

v0.4 彻底重写了文字注入引擎，修复了语音输入后文字无法插入目标应用的问题，并大幅提升了录音波形动画的视觉效果。

### 🐛 Bug 修复

- **文字注入引擎重写** — 采用 Maccy（12k+ stars）验证过的粘贴方案
  - 使用 `CGEventSource(.combinedSessionState)` + `.cgSessionEventTap`
  - 添加左键 modifier flag（`0x000008`）
  - 添加 `setLocalEventsFilterDuringSuppressionState` 防止键盘事件干扰
  - 修复了在 Discord、VS Code 等 Electron 应用中无法插入文字的问题
  - 修复了目标应用未正确激活导致粘贴失败的时序问题

### ✨ 新功能

- **ESC 快捷取消** — 录音时按 ESC 键可立即取消录音
- **开发指南** — 新增 `DEV_GUIDE.md`，包含构建部署流程、文字注入方案文档、问题排查指南

### 🎨 UI 改进

- **波形动画重做**
  - 13 根柱子，钟形高度分布（中间高两边低）
  - 有声音时波形持续大幅跳动，给用户清晰的"我在听"反馈
  - 平滑的 60fps 渲染 + 慢速目标更新（~4Hz），动画丝滑不晃眼
  - 安静时柱子缩为小点
- **录音浮窗优化** — 整体更紧凑，按钮大而清晰，波形居中

### 📝 技术细节

- 文字注入从多层回退策略（AX API → Cmd+V → Unicode）简化为单一可靠方案（剪贴板 + Cmd+V）
- 音频电平检测改为二值模式：超过底噪即视为有声音，不做音量大小的线性映射
- 详细的问题分析报告见 `ANALYSIS.md`

### ⚠️ 开发注意

- Ad-hoc 签名的 app 每次替换二进制后需执行 `codesign --force --sign -` 保持 TCC 权限
- 正式发布版本使用 Apple Developer 证书签名则无此问题

---

# Voxa v0.3 — Release Notes

**发布日期:** 2026-02-27
**标签:** v0.3

---

## 🎨 App 图标上线

v0.3 为 Voxa 添加了正式的应用图标，提升品牌辨识度。

### 新增
- **App 图标** — 声纹圆环 + 文字光标设计，珊瑚粉到琥珀橙渐变，扁平卡通风格
- **图标自动化脚本** `scripts/generate-icon.sh` — 一键从 1024×1024 PNG 生成所有 macOS 需要的尺寸并打包为 .icns
- **构建集成** — `build.sh` 自动检测新图标并转换
- **图标指南文档** `docs/APP_ICON_GUIDE.md`

### 改进
- `Info.plist` 新增 `CFBundleIconFile` 配置

---

# Voxa v0.2 — Release Notes

**发布日期:** 2026-02-26
**标签:** v0.2

---

## 🚀 发布就绪版本

v0.2 聚焦于发布质量优化，让 Voxa 做好面向用户的准备。

---

## ✨ 改进内容

### Release 构建优化
- 所有 `NSLog` 和 `print` 调试日志已用 `#if DEBUG` 包裹
- Release 模式下不再输出调试信息，提升性能与安全性

### 中文错误提示
- 所有用户可见的错误提示改为友好中文：
  - "No speech detected" → "未检测到语音，请重试"
  - "No API key set" → "请先在设置中配置 API Key"
  - "insufficient_quota" → "API 额度不足，请充值"
  - 网络错误 → "网络连接失败，请检查网络"
  - 录音失败 → "录音失败，请检查麦克风权限"
  - 通用错误 → "处理失败，请重试"

### 版本号更新
- Info.plist、菜单栏、关于页面统一更新为 v0.2

---

# Voxa v0.1 — Release Notes

**发布日期:** 2026-02-26
**标签:** v0.1
**Commit:** 3ce5cee

---

## 🎉 首个可用版本

Voxa 是一款 macOS 菜单栏语音输入工具。按下快捷键说话，AI 自动将语音转为文字并插入到光标所在位置。

---

## ✨ 核心功能

### 语音转文字
- 使用 OpenAI Whisper API 进行语音识别
- 支持中文、英文及中英混合输入
- 录音格式: AAC (m4a)，高质量采集

### AI 文本润色
- GPT 自动去除口语填充词（嗯、啊、那个、um、uh）
- 修正语法，添加标点符号
- 保留说话者原意，不添加额外内容
- 润色失败时自动回退到原始转录文本

### 光标自动输入
- **剪贴板模式**（首选）: Cmd+V 粘贴，速度快
- **Unicode 逐字输入**（回退）: 无需任何系统权限，兼容性最强
- 自动检测 Accessibility 权限状态，智能选择注入方式
- 录音开始时记忆前台应用，结束后自动切回并输入

### 菜单栏应用
- 常驻菜单栏，不占 Dock 位置
- 浮动录音条 + 实时波形动画
- 录音条不抢夺焦点（NonActivatingPanel）

### 快捷键
- 默认: `⌥ Space`（Option + 空格）
- 可自定义任意修饰键 + 按键组合

### 多供应商支持
| 供应商 | STT 模型 | 润色模型 |
|--------|---------|---------|
| OpenAI | whisper-1 | gpt-4o-mini |
| OpenRouter | whisper-large-v3 | gpt-4o-mini |
| Groq | whisper-large-v3-turbo | llama-3.1-8b-instant |
| Together AI | whisper-large-v3 | Llama-3.1-8B |
| DeepSeek | whisper-1 | deepseek-chat |
| 自定义 | 可配置 | 可配置 |

### 其他
- 听写历史记录（SwiftData 持久化）
- 麦克风选择
- 开机自启
- API Key 通过 Keychain 安全存储

---

## 🔧 构建方式

```bash
cd VoxaApp
./build.sh
```

---

## ⚙️ 系统要求

- macOS 14.0 (Sonoma) 或更高
- API Key（推荐 OpenAI）
- 麦克风权限
- 辅助功能权限（推荐，非必须）

---

## 📋 已知限制

- 每次重新编译后可能需要重新授权辅助功能权限（开发阶段）
- Unicode 逐字输入模式在长文本时速度较慢
- 暂无实时流式转录（录完后一次性处理）
- 暂无本地 Whisper 模型支持（需联网）

---

## 🔮 后续计划

- [ ] 实时流式语音识别
- [ ] 本地 Whisper 模型支持（离线使用）
- [ ] 更多语言优化
- [ ] 自定义润色 Prompt
- [ ] 快捷短语/模板
- [ ] Xcode 项目化 + 正式代码签名
