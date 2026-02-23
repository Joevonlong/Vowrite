# Voxa 核心流程总纲

所有开发、测试、发布活动遵循以下流程。每个阶段有对应的检查清单和脚本。

---

## 流程总览

```
开发 → 测试 → 清理 → 构建 → 签名 → 打包 → 发布 → 通知
 │      │      │      │      │      │      │      │
 ▼      ▼      ▼      ▼      ▼      ▼      ▼      ▼
代码   功能   安全   Release  codesign  DMG   GitHub  官网
变更   验证   审查   编译    +公证    生成  Release 更新
```

---

## 阶段一：开发

### 分支策略
- `main` — 稳定版，只接受经过测试的代码
- `dev` — 日常开发（可选，小项目直接在 main 上开发）
- `feature/xxx` — 功能分支（较大功能时使用）

### 提交规范
```
<类型>: <简要说明>

类型:
- feat: 新功能
- fix: 修复
- refactor: 重构
- docs: 文档
- chore: 构建/工具/杂项
- security: 安全相关
```

### 开发构建
```bash
cd VoxaApp && ./build.sh
```

---

## 阶段二：测试

### 自动化测试
```bash
ops/scripts/test.sh
```

### 手动测试矩阵

| 测试项 | 说明 | 通过 |
|--------|------|------|
| OpenAI STT | whisper-1 转录中/英文 | ☐ |
| AI Polish | gpt-4o-mini 润色 | ☐ |
| Polish 失败回退 | 断网或无额度时用原文 | ☐ |
| 剪贴板注入 | 有 Accessibility 权限 | ☐ |
| Unicode 注入 | 无 Accessibility 权限 | ☐ |
| 快捷键 | 默认 ⌥Space + 自定义 | ☐ |
| 菜单栏 | 图标/菜单/状态显示 | ☐ |
| 录音条 | 显示/波形/不抢焦点 | ☐ |
| 历史记录 | 保存/查看 | ☐ |
| 麦克风切换 | 多麦克风选择 | ☐ |
| 长录音 | >60秒录音 | ☐ |
| 首次启动 | 无 Key 时的引导 | ☐ |
| 错误处理 | 无网络/无权限/超时 | ☐ |

---

## 阶段三：安全清理

详见 `CHECKLIST_SECURITY.md`。每次发版前必须执行。

核心要求：
- 代码和 Git 历史中无 API Key 泄露
- NSLog 调试信息在 Release 构建中关闭
- Keychain 存储安全
- 无硬编码凭证

---

## 阶段四：构建

### Release 构建
```bash
ops/scripts/release.sh <版本号>
# 例: ops/scripts/release.sh v0.2
```

脚本自动执行：
1. `swift build -c release` 编译优化版
2. 拷贝二进制到 Voxa.app
3. 代码签名（有 Developer ID 时签名+公证，否则 ad-hoc）
4. 打包 DMG
5. 生成 Changelog
6. Git commit + tag

---

## 阶段五：发布

### 当前阶段：GitHub Release
1. `ops/scripts/release.sh` 完成打包
2. 在 GitHub 创建 Release，附上 DMG
3. 更新 RELEASE_NOTES.md

### 未来阶段：签名 + 公证
1. 注册 Apple Developer ($99/年)
2. 用 Developer ID 签名
3. `xcrun notarytool submit` 提交公证
4. `xcrun stapler staple` 订书钉公证票据
5. 打包 DMG 发布

### 发布渠道
- [ ] GitHub Releases（主要）
- [ ] 官网下载页
- [ ] Homebrew Cask（未来）

---

## 阶段六：发布后

### 通知
- 更新官网下载链接和版本号
- 更新 README.md 中的版本信息
- （未来）通过 Sparkle 推送自动更新

### 监控
- 检查 GitHub Issues
- 收集用户反馈
- 监控崩溃报告（未来接入 Sentry 等）

---

## 快速参考

| 我要做什么 | 执行什么 |
|-----------|---------|
| 日常开发构建 | `cd VoxaApp && ./build.sh` |
| 运行测试 | `ops/scripts/test.sh` |
| 发布新版本 | `ops/scripts/release.sh v0.x` |
| 清理构建产物 | `ops/scripts/clean.sh` |
| 检查安全 | 过一遍 `ops/CHECKLIST_SECURITY.md` |
| 发版前检查 | 过一遍 `ops/CHECKLIST_RELEASE.md` |
