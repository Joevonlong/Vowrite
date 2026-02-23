# 版本号与 Changelog 规范

---

## 版本号格式

采用 **语义化版本** (Semantic Versioning): `vMAJOR.MINOR.PATCH`

| 部分 | 何时递增 | 示例 |
|------|---------|------|
| MAJOR | 不兼容的大改动、重大架构变更 | v1.0 → v2.0 |
| MINOR | 新功能、向后兼容的改进 | v0.1 → v0.2 |
| PATCH | Bug 修复、小调整 | v0.1.0 → v0.1.1 |

### 当前版本线

```
v0.x — 早期开发阶段，功能快速迭代
v1.0 — 首个正式发布版本（签名 + 公证 + 官网）
```

### 预发布标签（可选）

```
v0.2-beta    测试版
v0.2-rc1     发布候选
```

---

## Tag 规范

- Git tag 与版本号一致: `v0.1`, `v0.2`, `v1.0`
- 使用 annotated tag: `git tag -a v0.2 -m "v0.2 — 功能描述"`
- Tag 打在发布 commit 上，不打在中间 commit

---

## Changelog 规范

每个版本的变更记录在 `RELEASE_NOTES.md` 中，格式：

```markdown
## vX.Y — 标题

**发布日期:** YYYY-MM-DD

### 新功能
- feat: 描述

### 修复
- fix: 描述

### 改进
- refactor/chore: 描述

### 已知问题
- 描述
```

---

## 需要更新版本号的位置

每次发版时，以下位置的版本号必须同步更新：

1. `VoxaApp/Resources/Info.plist` → `CFBundleShortVersionString`
2. `VoxaApp/Views/SettingsView.swift` → `AboutTab` 中的版本显示
3. `RELEASE_NOTES.md` → 新增版本条目
4. `README.md` → 版本历史章节
5. `Git tag`

`ops/scripts/release.sh` 会自动处理大部分，但请在 checklist 中确认。
