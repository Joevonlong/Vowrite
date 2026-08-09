# Vowrite — Feature Backlog

> 最后更新: 2026-08-10
>
> 详细 Feature spec 见 `Vowrite-internal/tracking/features/F-xxx-*.md`
> 完整 Feature 列表和状态见 `Vowrite-internal/tracking/FEATURES.md`

## Recently integrated to product `main`

| ID | Feature | Status | Product `main` commit |
|----|---------|--------|-----------------------|
| F-084 | Model request compatibility and retirement-safe migration | Partial — external provider and physical-device gates remain | `1075d7d20fa94a47b9534a853666c8f80e84df92` |
| F-085 | model-watch normalization and deprecation guardrails | Partial — hosted Actions and keyed-source gates remain | `90e88781803737c2035987a0844555895f1b343f` |
| F-086 | Guarded 2026-08 model evaluation | Partial — candidate evaluation only; no public catalog activation | `67c3b932569ca4ce89a3b47c8560e9d049c01148` |

## 📋 最近完成

| ID | Feature | 版本 |
|----|---------|------|
| F-045 | Prompt 上下文变量 ({selected}/{clipboard}) | v0.1.12.0 |
| F-044 | Claude (Anthropic) Polish 支持 | v0.1.12.0 |
| F-043 | Gemini Polish 支持 | v0.1.12.0 |
| F-047 | Zhipu GLM Polish 支持 | v0.1.12.0 |
| F-046 | Think Tag 清理 | v0.1.12.0 |
| F-040 | Deepgram STT 集成 | v0.1.12.0 |
| F-042 | Overview 数据统计增强 | v0.1.11.0 |
| F-037 | Settings 界面重组（7 页 sidebar） | v0.1.11.0 |

## 🚧 进行中

| ID | Feature | 版本 |
|----|---------|------|
| F-032 | iOS 键盘扩展 | v0.2.0.0 |

## 📝 待开发

| ID | Feature | 优先级 |
|----|---------|--------|
| F-041 | Provider Registry（配置驱动） | 🔴 高 |
| F-048 | 本地离线 ASR (Sherpa) | 🟡 中 |
| F-050 | MLX Server 本地推理支持 | 🟡 中 |
| F-049 | 讯飞 STT 集成 | 🟢 低 |
| F-003 | 语音触发搜索 | 🟡 中 |

## 📌 说明

- 提出需求：Discord #vowrite-new-requirement 频道
- 评估流程：记录 → 补充描述 → 评估优先级 → 排入版本计划
