# Vowrite 代码审查体系

> 生成自 review charter v1，2026-05-15。

---

## 目的与节奏

代码审查分三个层次，覆盖不同时间跨度：

| 类型 | 触发时机 | 执行者 | 范围 |
|------|----------|--------|------|
| **增量审查** | 每个 Feature 完成后（Completion Protocol 执行时） | Arnold（自动） | 新增/改动文件 |
| **月度扫描** | 每月第一个工作日 | 开发者手动触发 | 全仓 L1-L8 |
| **季度深审** | 每季度末 | 开发者 + review-scan.sh | 全仓 + 安全重点 |
| **年度深审** | 每年初 | 开发者 | 架构 + 依赖 + 凭据轮换 |

### 首次深审（Deep Review）

首次完整 deep review 在 review charter v1 制定后执行，报告存入：

```
Vowrite-internal/reviews/2026-05-15-deep-review/
├── 40-findings.md     # 按 P0/P1/P2/P3 分级的所有发现
├── report.md          # 执行摘要
└── raw/               # 各工具原始输出
```

---

## 7 维度索引

| 维度 | 代号 | 覆盖内容 |
|------|------|----------|
| 代码质量 | **L1** | 编译警告、SwiftLint 错误/警告、swift-format 合规、函数复杂度 |
| 安全 | **L2** | 密钥泄漏、日志脱敏、App Sandbox 范围、网络调用门控 |
| 业务正确性 | **L3** | 录音→转写→润色→输出流程完整性、错误路径处理、边界条件 |
| 平台一致性 | **L4** | iOS-macOS feature parity（check-parity.sh）、VowriteKit API 使用对称性 |
| 性能 | **L5** | 首字延迟、内存峰值（Keyboard < 60 MB）、release build 警告基准（当前：4） |
| 文档同步 | **L6** | CHANGELOG vs 实际 commit、feature spec 与代码一致、TESTING.md 手工清单时效 |
| 基建 | **L7** | CI 绿灯率、pre-commit hook 工作状态、gitleaks baseline、.gitignore 覆盖 |

每次 review-scan.sh 运行会覆盖 L1（构建）、L2/L8（安全 grep）、L4（parity）、L7（test.sh），L3/L5/L6 需要人工判断。

---

## 工具

### .swiftlint.yml

路径：`Vowrite/.swiftlint.yml`

- included 范围：`VowriteKit/Sources`、`VowriteMac/Sources`、`VowriteIOS/Sources`、`VowriteKeyboard/Sources`
- 关键自定义规则：
  - `no_raw_print` — 禁止裸 `print()`，要求使用 Logger
  - `todo_with_id` — TODO 必须关联 F-XXX 或 issue id
  - `no_force_in_sources` — 禁止 `try!` / `as!`
  - `transcript_log_guard` — 日志调用包含转录内容时报 **error**（最高优先级）
- 行为：warning 不阻塞提交，error 阻塞提交（通过 pre-commit hook）。

### review-scan.sh

路径：`ops/scripts/review-scan.sh`

```bash
# 完整扫描，写 Markdown 报告
bash ops/scripts/review-scan.sh --report /tmp/scan.md

# CI 模式（GitHub Annotations 格式）
bash ops/scripts/review-scan.sh --ci --soft

# 只运行特定步骤
bash ops/scripts/review-scan.sh --rule L5

# Soft 模式（P2/P3 不阻塞，适合 CI 起步阶段）
bash ops/scripts/review-scan.sh --soft
```

**韧性设计：** 即使 swiftlint / swift-format / gitleaks 全部缺失，L5 和 L8 的 grep 安全扫描仍然运行，不依赖任何外部工具。

### pre-commit hook

安装：

```bash
git config core.hooksPath .githooks
```

行为（不可绕过层级）：

| 检查 | 级别 | 可用 SKIP=lint 跳过？ |
|------|------|----------------------|
| gitleaks 密钥扫描 | 硬性安全红线 | **否** |
| SwiftLint error | 阻塞提交 | 是（不推荐） |
| SwiftLint warning | 不阻塞 | — |
| swift-format lint | 报告，不阻塞 | 是 |

---

## 如何发起一次 Review

### 快速扫描（5 分钟）

```bash
cd /path/to/Vowrite

# 1. 运行全套扫描（soft 模式，不阻塞）
bash ops/scripts/review-scan.sh --soft --report /tmp/quick-scan.md

# 2. 查看报告
open /tmp/quick-scan.md
```

### 完整深审（首次或季度）

```bash
# 1. 安装工具（如未安装）
brew install swiftlint swift-format gitleaks

# 2. 确认 hook 已安装
git config core.hooksPath .githooks

# 3. 运行完整扫描
bash ops/scripts/review-scan.sh --report Vowrite-internal/reviews/$(date +%Y-%m-%d)-review/report.md

# 4. 手动检查 L3/L5/L6
#    - 手工冒烟：见 TESTING.md
#    - 性能基线：首字延迟、Keyboard 内存峰值
#    - CHANGELOG vs commit log diff

# 5. gitleaks 全历史扫描
gitleaks detect --no-banner --redact --config .gitleaks.toml

# 6. 检查 parity
bash scripts/check-parity.sh
```

### Feature 增量审查（Completion Protocol 自动触发）

Arnold 在每次 Feature 完成时自动运行：

```bash
bash ops/scripts/review-scan.sh --rule L2 --rule L8 --soft
```

---

## 报告位置

所有 review 报告存入 **workspace 仓**（不是产品仓）：

```
Vowrite-internal/reviews/
├── 2026-05-15-deep-review/
│   ├── report.md
│   ├── 40-findings.md
│   └── raw/
├── 2026-06-01-monthly/
│   └── report.md
└── ...
```

> `Vowrite-internal/` 位于 workspace repo（`/Users/unclejoe/Dev_Workspace/Vowrite-Workspace/`），不在产品仓 `Vowrite/` 内。

---

## 发现优先级定义

| 级别 | 定义 | 响应时间 |
|------|------|----------|
| **P0** | 安全漏洞、密钥泄漏、编译失败 | 立即修复，阻塞发布 |
| **P1** | 数据隐私风险、测试失败、严重 bug | 当前 sprint 修复 |
| **P2** | 代码质量问题、性能退化、parity 缺口 | 下一个 sprint |
| **P3** | 风格问题、文档不同步、技术债 | Backlog |
