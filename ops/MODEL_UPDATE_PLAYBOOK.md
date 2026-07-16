# Model Update Playbook

> F-082. The repeatable procedure for keeping Vowrite's model catalog
> (`VowriteKit/Sources/VowriteKit/Resources/providers.json`) current: newest
> polish (LLM) models, newest STT models, retired IDs cleaned up, website in
> sync. Detection is automated; **curation is deliberately human/agent-driven**
> — aggregator catalogs are full of irrelevant or renamed entries, and a
> fabricated model ID ships a 404 to users (the F-062 `deepseek-v4` lesson).

---

## Cadence & triggers

| Trigger | What happens |
|---|---|
| **Monthly cron** — `.github/workflows/model-watch.yml` (06:00 UTC, 1st) | Runs `model-watch.py`; on drift files/updates a `model-watch`-labeled GitHub issue with the report |
| **Manual** — `workflow_dispatch` or local run | Same report on demand (e.g. right after a big vendor launch) |
| **Provider announcement** (deprecation email, launch news) | Run the playbook without waiting for the cron |

The website Content Audit (Track A in `ops/CHECKLIST_WEBSITE.md`) has the same
monthly rhythm — do them together: catalog first, website second.

## Pipeline overview

```
 OpenRouter public catalog ──┐
 (keyless, created + prices) │   ops/scripts/model-watch.py     GitHub issue
                             ├─► diff vs providers.json +  ──►  (monthly, label
 Provider GET /models ───────┘   ops/model-watch/state.json     model-watch)
 (per-key, exact recon)                                              │
                                                                     ▼
                                    curation (this playbook, steps 1-9)
                                    research → edit → build/test → website
                                                                     │
                                              --update-state ◄───────┘
                                              (re-baseline, report goes quiet)
```

## Procedure

1. **Get the signal.** Read the month's `model-watch` issue, or run locally:
   ```bash
   python3 ops/scripts/model-watch.py
   # more reconciliation coverage with keys in env, e.g.:
   # OPENAI_API_KEY=... GROQ_API_KEY=... python3 ops/scripts/model-watch.py
   ```
2. **Verify against official docs — never trust the aggregator alone.**
   For each interesting delta, confirm on the provider's own models/pricing
   page (links below): exact API model ID, price, context, reasoning-control
   parameter, deprecation dates. Delegate this to cheap-model research agents
   or check manually. OpenRouter prices are proxy prices; the website uses
   official ones.
3. **Edit `providers.json`** on a `feature/F-XXX-…` branch, following the
   catalog rules below.
4. **New provider?** Follow the new-provider checklist below (small code
   change required).
5. **Validate:**
   ```bash
   cd VowriteMac && swift build          # registry decode asserts on bad JSON
   cd ../VowriteKit && swift test
   cd .. && ops/scripts/test.sh          # full suite
   python3 -c 'import json;json.load(open("VowriteKit/Sources/VowriteKit/Resources/providers.json"))'
   ```
   Smoke-test at least the new default models with real keys via the app's
   API connection tester (Settings → API Keys).
6. **Website Track A** — sync `docs/pricing.html` (+ provider sections) per
   `ops/CHECKLIST_WEBSITE.md`, dedicated `docs(website-A):` commit.
7. **Tracking docs** — internal FEATURES/DASHBOARD/spec updates; CHANGELOG
   routing is `[mac, ios]` for catalog changes (both files, per-platform prose).
8. **STT watchlist** — refresh `Vowrite-internal/tracking/models/STT_WATCHLIST.md`
   (cloud + local candidates better than Whisper); promote candidates worth
   integrating into IDEAS/FEATURES.
9. **Re-baseline:**
   ```bash
   python3 ops/scripts/model-watch.py --update-state
   git add ops/model-watch/state.json && git commit -m "chore: model-watch re-baseline"
   ```
   Close the month's `model-watch` issue.

## providers.json catalog rules

1. **Official-source-only IDs.** Every model ID must be copied from an
   official doc or an official `/models` response fetched during this update.
   No guessing version suffixes.
2. **Thinking off by default (F-073).** Any reasoning-capable model gets
   `polishOverrides` that disable/minimize thinking (table below). If thinking
   cannot be disabled, append `(thinking on, slower)` to the description so
   the picker is honest.
3. **Tiering per provider:** `defaultModel` = the balanced fast-cheap choice;
   list one flagship and one cheapest; keep ≤ 6 models per pipeline per
   provider — the picker is not a museum. Older generations stay only while
   they serve a real fallback purpose.
4. **`defaultModel` must appear in `models[]`.**
5. **Retirements.** Upstream-announced sunset → keep the entry until the
   sunset date with `description: "… (deprecates YYYY-MM-DD)"`, then delete.
   Silently-gone IDs (reconciliation "possibly retired") → verify, then delete.
6. **Descriptions:** ≤ ~8 words, user-facing benefit ("Fastest", "Cheapest,
   high-volume", "Frontier — best reasoning"). Chinese OK for CN-only
   providers (existing style).
7. **ID formats differ:** SiliconFlow/Together/OpenRouter use `org/model`;
   DashScope/DeepSeek/Moonshot/Zhipu use bare names; Gemini compat layer
   strips the `models/` prefix. Copy exactly.

### Thinking-disable parameter cheat sheet (verify each cycle)

| Provider | Parameter (OpenAI-compat top-level) |
|---|---|
| OpenAI (gpt-5.x) | `"reasoning_effort": "minimal"` (`"none"` where supported) |
| Gemini (compat layer) | `"reasoning_effort": "none"` (pro tiers: `"minimal"`) |
| DeepSeek | `"thinking": {"type": "disabled"}` |
| Qwen / DashScope | `"enable_thinking": false` |
| Kimi / Moonshot | `"thinking": {"type": "disabled"}` |
| Zhipu GLM | `"thinking": {"type": "disabled"}` |
| MiniMax | `"thinking": {"type": "disabled"}` |
| Volcengine Doubao | `"thinking": {"type": "disabled"}` |
| Together (hybrid models) | `"reasoning": {"enabled": false}` |
| Groq (qwen3 etc.) | `"reasoning_effort": "none"` |
| Anthropic (native Messages) | thinking off unless requested — no override needed |

## New-provider checklist

Metadata is registry-driven, but provider *identity* is still a Swift enum:

1. `VowriteKit/Sources/VowriteKit/Config/APIProvider.swift` — new case +
   `providerID` mapping (raw value = display name; mind Keychain identity).
2. `providers.json` — full entry: `baseURL`, `auth` (style/placeholder/keyURL),
   `capabilities`, `stt`/`polish` blocks, `platformFilter` if local-only.
3. KeyVault / Settings UI / iOS — automatic via `availableCases` generics
   (verified by F-068); no per-provider UI code.
4. Optional: `APIPreset.swift` one-click preset — only for a genuinely
   recommended combo.
5. `ops/scripts/model-watch.py` — add the provider to `KEY_ENV` (has an
   OpenAI-compatible `GET /models`) or `SKIP_REASONS` (doesn't), and its
   OpenRouter vendor prefix to `WATCH_PREFIXES` if one exists.
6. Non-OpenAI STT protocol → STTAdapter implementation (F-039 pattern);
   polish-only OpenAI-compatible providers need zero service code.
7. Validate per step 5 above; note regional latency in the spec and UI.

Reference implementations: F-030 (SiliconFlow/Kimi/MiniMax), F-068 (region
split), F-062 (previous full refresh).

## Official data sources

| Provider | Models / pricing |
|---|---|
| OpenAI | <https://platform.openai.com/docs/models> · <https://openai.com/api/pricing/> |
| Anthropic | <https://platform.claude.com/docs/en/about-claude/models> · pricing page |
| Google Gemini | <https://ai.google.dev/gemini-api/docs/models> · <https://ai.google.dev/gemini-api/docs/pricing> |
| DeepSeek | <https://api-docs.deepseek.com/quick_start/pricing> |
| Qwen / DashScope | <https://help.aliyun.com/zh/model-studio/models> |
| Kimi / Moonshot | <https://platform.moonshot.cn/docs/price/chat>（迁移中：platform.kimi.com） |
| MiniMax | <https://platform.minimax.io/docs> · <https://platform.minimaxi.com/> |
| Zhipu | <https://docs.bigmodel.cn/> · <https://bigmodel.cn/pricing> |
| Volcengine Ark | <https://www.volcengine.com/docs/82379> · <https://www.volcengine.com/pricing> |
| SiliconFlow | <https://docs.siliconflow.cn/> · <https://www.siliconflow.com/pricing> |
| Groq | <https://console.groq.com/docs/models> · <https://groq.com/pricing> |
| Together | <https://docs.together.ai/docs/serverless-models> |
| Mistral | <https://docs.mistral.ai/getting-started/models/> |
| xAI | <https://docs.x.ai/docs/models> |
| Deepgram | <https://developers.deepgram.com/docs/models-languages-overview> |
| OpenRouter (signal only) | <https://openrouter.ai/api/v1/models> |
| STT leaderboards | HF Open ASR leaderboard · artificialanalysis.ai/speech-to-text · SpeechIO |

## model-watch.py reference

- **Sources:** OpenRouter public catalog (always) + per-provider `GET /models`
  for every provider with its env key set (`KEY_ENV` in the script).
- **State:** `ops/model-watch/state.json` — the last curated baseline
  (OpenRouter IDs + per-provider IDs). Committed. A run only reports deltas
  vs this baseline, so the monthly issue keeps nagging until curation lands.
- **Exit codes:** `0` no drift · `10` findings · `3` no source reachable ·
  `1` fatal (bad providers.json).
- **Flags:** `--report FILE` (write markdown), `--update-state` (re-baseline),
  `--limit-new N`, `--timeout S`.
- **CI:** monthly + manual dispatch; provider keys are optional repo secrets —
  absent secrets simply reduce reconciliation coverage, the OpenRouter signal
  never needs one.
