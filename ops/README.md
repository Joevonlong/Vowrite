# Voxa 运维管理中心 (ops/)

本目录是 Voxa 项目的**管理、维护、发布流程专用目录**，不打包进软件。

## 目录结构

```
ops/
├── README.md              ← 你正在看的文件
├── PROCESS.md             ← 核心流程总纲（开发→测试→发布→运维）
├── CHECKLIST_RELEASE.md   ← 发布前检查清单（每次发版必走）
├── CHECKLIST_SECURITY.md  ← 安全清理检查清单
├── VERSIONING.md          ← 版本号规范 + Changelog 规范
├── WEBSITE.md             ← 官网规划与部署方案
├── ROADMAP.md             ← 产品路线图
└── scripts/
    ├── release.sh         ← 自动化发布脚本
    ├── test.sh            ← 自动化测试脚本
    └── clean.sh           ← 构建清理脚本
```

## 原则

1. **每次发版前**必须过 `CHECKLIST_RELEASE.md`
2. **每次涉及安全变更**必须过 `CHECKLIST_SECURITY.md`
3. **版本号和 Changelog** 按 `VERSIONING.md` 规范执行
4. **所有脚本**在 `ops/scripts/` 下，不放在项目根目录（`build.sh` 除外，那是开发用的）
