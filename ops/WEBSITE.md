# 官网规划

---

## 阶段一：MVP（GitHub Pages，零成本）

### 技术方案
- 纯静态 HTML + CSS（单页）
- 托管在 GitHub Pages
- 自定义域名（可选，~$10/年）

### 页面结构
```
index.html
├── Hero: 一句话介绍 + 下载按钮 + 演示 GIF
├── Features: 3-4 个核心卖点（图标 + 文字）
├── How it works: 3 步流程图
├── Screenshot: 录音条 + 设置界面截图
├── Download: 版本号 + DMG 下载链接
├── FAQ: 常见问题
└── Footer: GitHub 链接 + 版本信息
```

### 部署方式
```bash
# 在 docs/ 目录放静态文件
# GitHub Settings → Pages → Source: /docs
```

### 域名方案
- 免费: `username.github.io/voxa`
- 自定义: `voxa.app` 或 `getvoxa.com`（需购买域名）

---

## 阶段二：增强（有用户后）

- 接入 Plausible / Umami 轻量分析（隐私友好）
- 添加 Changelog 页面（自动从 RELEASE_NOTES.md 生成）
- 添加文档页面（安装指南、Provider 配置）
- 多语言支持（中/英）

---

## 阶段三：正式（v1.0 后）

- 迁移到 Astro / Next.js（如需要更复杂的页面）
- Sparkle appcast.xml 托管（自动更新）
- 下载统计
- 用户反馈表单

---

## 设计参考

同类产品官网风格参考：
- Typeless (typeless.ch) — 简洁、单页、深色
- Whisper Transcription (goodsnooze.gumroad.com) — 极简
- Superwhisper (superwhisper.com) — 精致、动画

### 设计原则
- 深色主题（与 app 风格一致）
- 移动端友好
- 加载速度快（纯静态，无 JS 框架依赖）
- 下载按钮醒目
