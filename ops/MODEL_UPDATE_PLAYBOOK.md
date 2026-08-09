# Model Update Playbook

> F-082 established read-only upstream model detection. F-085 adds
> source/namespace normalization, scoped deprecation guardrails, public
> Cerebras reconciliation, and versioned state. F-086 owns the next catalog
> curation and the first permitted v2 re-baseline after external acceptance.

This is the repeatable procedure for keeping Vowrite's model catalog
(`VowriteKit/Sources/VowriteKit/Resources/providers.json`) current. Detection
is automated; catalog edits and baseline updates are deliberately reviewed.
Aggregator catalogs contain aliases, proxy pricing, and provider-like slugs
that are not proof of a direct-provider API model ID.

## Safety invariants

1. The watcher is read-only unless a reviewer explicitly supplies
   `--update-state`.
2. CI never supplies `--update-state`, edits the catalog, commits, or pushes.
3. An aggregator signal is discovery evidence only. It never proves a direct
   provider ID, retirement, price, or availability.
4. A catalog change requires an official provider document or an official
   direct-provider API response.
5. A replacement in the deprecation manifest is a reviewed suggestion, never
   an automatic migration.
6. During F-085, do not run `--update-state`. The first v2 baseline may be
   written only after F-086's target-account requests and quantified evaluation
   are accepted, approved public rows land, and the resulting diff is reviewed.

## Cadence and triggers

| Trigger | What happens |
|---|---|
| **Weekly cron** — `.github/workflows/model-watch.yml` (Monday, 06:00 UTC) | Runs offline regression tests, then the read-only live watcher; actionable output creates or updates one open `model-watch` issue |
| **Manual** — `workflow_dispatch` or local run | Produces the same read-only report on demand |
| **Provider announcement** — launch, retirement, or account notice | Run the playbook immediately; do not wait for the cron |
| **Monthly website audit** | Perform Track A in `ops/CHECKLIST_WEBSITE.md` after any approved catalog curation |

## Pipeline overview

```text
 OpenRouter public catalog ─────────────── aggregator namespace ─┐
                                                                │
 Cerebras public /models ─────────────────── direct namespace ───┤
                                                                ├─> normalize
 Keyed provider /models ── or SKIPPED_NO_KEY ─ direct namespace ┤    + compare
                                                                │
 Reviewed deprecations.json ───────── scope + evidence date ─────┘
                                      │
                                      ├─> read-only report + one GitHub issue
                                      └─> v2 raw/canonical state
                                           (explicit update only after curation)
```

OpenRouter answers "what appeared in this aggregator?" Direct sources answer
"what does this provider expose?" Those questions remain separate even when
the strings happen to match.

## Source, namespace, and alias rules

Every signal retains its `source`, `namespace`, `rawID`, and `canonicalID`.
The namespace is source-specific: OpenRouter remains an aggregator namespace;
Cerebras and keyed provider endpoints remain provider-specific direct
namespaces.

The alias-collapse allow-list is intentionally narrow:

| Source | Allowed normalization | Audit behavior |
|---|---|---|
| OpenRouter | Remove one terminal `:batch` suffix | Retain both raw base/batch IDs and increment the collapsed-alias count |
| Every other source | None | Preserve the ID exactly, aside from an endpoint's documented response wrapper handling |

Normalization requirements:

- Collapse a base and its `:batch` alias only within the same source and
  namespace.
- Keep all raw IDs so a reviewer can recover or audit the decision.
- `--show-aliases` may expose the raw members but never changes the canonical
  decision.
- Do not generically strip `:free`, `:thinking`, dates, organization prefixes,
  or any future suffix.
- Do not merge identical strings across sources or namespaces.
- Treat a vendor-like OpenRouter prefix only as a `providerHint` for triage.
  Never copy or derive a direct-provider ID from it.

The fixed F-085 OpenRouter fixture is the normalization contract: 65 raw
signals become seven canonical signals, with 58 aliases collapsed and retained
for audit.

## Source coverage and status language

| Source | Authentication | Meaning |
|---|---|---|
| OpenRouter public catalog | None | Cross-ecosystem discovery signal; never direct-provider proof |
| Cerebras public catalog (`https://api.cerebras.ai/public/v1/models`) | None | Independent direct Cerebras reconciliation |
| Supported provider `/models` endpoints | Provider key | Direct reconciliation for that provider only |

For a keyed source without its environment variable, report
`SKIPPED_NO_KEY`. It means "not checked," never "checked with no change."
Cerebras must still run without `CEREBRAS_API_KEY`; do not turn its public
endpoint into a keyed skip.

Keep source failures distinguishable in the report: authentication failure
(401/403), rate limiting (429), timeout/network failure, and malformed JSON are
not interchangeable. Exit `3` means all network sources were unavailable; it
does not mean the catalog is current.

## Tier-aware deprecation evidence

Reviewed retirement facts live in `ops/model-watch/deprecations.json`. Each
entry records at least:

```json
{
  "provider": "groq",
  "model": "qwen/qwen3-32b",
  "capability": "polish",
  "retireAt": "2026-07-17T00:00:00Z",
  "scope": "free_developer",
  "unaffectedScope": "committed_spend_enterprise",
  "replacement": "openai/gpt-oss-120b",
  "sourceURL": "https://console.groq.com/docs/deprecations",
  "verifiedAt": "2026-08-09"
}
```

`scope` and `unaffectedScope` must appear in every retirement report row and
GitHub issue summary. Never widen a tier-scoped notice to the whole provider.
In particular, the reviewed Groq Qwen and Llama retirements apply to
Free/Developer accounts; committed-spend Enterprise accounts are explicitly
unaffected by those notices.

Use progressively stronger deadline labels for an applicable catalog entry:

| Time to `retireAt` | Report action |
|---|---|
| More than 30 days | No deadline escalation |
| 30 days or fewer | `WARNING_30D` |
| 14 days or fewer | `URGENT_14D` |
| 7 days or fewer | `CRITICAL_7D` |
| Retired and still configured for the applicable scope | `BLOCKER_RETIRED` |

Missing replacement text remains visible; it does not suppress the warning.
No severity authorizes an automatic catalog edit.

### Evidence freshness interval

Retirement evidence becomes stale when `verifiedAt` is **more than 30 calendar
days old** at evaluation time. Evidence exactly 30 calendar days old is still
current. A stale row must identify its `sourceURL`, `verifiedAt`, `scope`, and
`unaffectedScope` so a reviewer can re-check the fact. Refreshing evidence is a
reviewed manifest change with git history, not an HTML-scraping side effect.

## State schema and atomic updates

F-085 reads the F-082 v1 state backward-compatibly and normalizes it in memory.
The v2 schema retains both layers:

- raw source evidence, including every collapsed alias;
- canonical source/namespace signals used for stable comparisons;
- provider reconciliation snapshots and the last curated timestamp.

Identical normalized input must produce byte-stable ordering. An explicit
state update writes a same-directory temporary file and atomically replaces
`ops/model-watch/state.json`; a failed write must leave the previous baseline
intact.

The update gate is strict:

- F-085 implementation and CI: `--update-state` is prohibited.
- First v2 baseline: allowed only after F-086 has accepted the target-key live
  requests and 36-sample polish / 30-clip STT evidence, landed only the approved
  public rows and migrations, and reviewed the proposed state diff.
- Later cycles: allowed only inside an approved catalog-curation feature after
  the same source verification and test gates.

## Curation procedure

1. **Get the signal.** Read the open `model-watch` issue or run locally:

   ```bash
   python3 ops/scripts/model-watch.py
   python3 ops/scripts/model-watch.py --show-aliases
   # Optional keyed coverage, for example:
   # OPENAI_API_KEY=... GROQ_API_KEY=... python3 ops/scripts/model-watch.py
   ```

2. **Read coverage before findings.** Record which sources were direct,
   aggregator-only, `SKIPPED_NO_KEY`, or failed. Never turn missing coverage
   into a no-change conclusion.

3. **Verify every candidate with an official source.** Confirm the exact API
   ID, availability scope, price, context, reasoning controls, and retirement
   date. OpenRouter pricing and slugs remain proxy/aggregator evidence.

4. **Check retirement scope.** Confirm both affected and unaffected account
   tiers. Update `deprecations.json` only from a reviewed provider source.

5. **Evaluate before public curation.** Use target-tier keys and the controlled
   datasets. Record the sanitized evidence in the cycle's evaluation artifact.
   Until it is accepted, do not add or replace bundled rows, enable a migration,
   write a public changelog entry, or re-baseline watcher state.

6. **Curate and validate after acceptance.** On the approved feature branch,
   add only accepted rows and provider-scoped migrations, then run:

   ```bash
   python3 ops/scripts/tests/test_model_watch.py
   cd VowriteMac && swift build
   cd ../VowriteKit && swift test
   cd .. && ops/scripts/test.sh
   python3 -c 'import json; json.load(open("VowriteKit/Sources/VowriteKit/Resources/providers.json"))'
   ```

   Smoke-test every new or changed row with real provider keys through Settings
   > API Keys. A default additionally requires the stricter default gate.
   Missing live credentials remain an explicit external validation gate.

7. **Update adjacent surfaces after public enablement.** Run website Track A,
   refresh the internal STT watchlist, and update feature/tracking docs. Accepted
   shared catalog changes go to both platform changelogs with platform-specific
   wording; pending candidates never appear as shipped changes.

8. **Review the proposed baseline.** Verify that raw aliases, canonical
   namespaces, source statuses, and scoped retirements are all preserved.

9. **Re-baseline only after the external and curation gates.** The first v2
   update belongs to F-086 only after target-key requests, the 36/30 evaluation,
   public rows, migrations, catalog validation, and changelog review are all
   accepted:

   ```bash
   python3 ops/scripts/model-watch.py --update-state
   git diff -- ops/model-watch/state.json
   git add ops/model-watch/state.json
   git commit -m "chore: model-watch re-baseline"
   ```

   Re-run the read-only watcher. Close the `model-watch` issue only when the
   remaining findings and incomplete source coverage are understood and
   recorded.

## `providers.json` catalog rules

1. **Official-source-only IDs.** Copy each model ID from official provider
   documentation or a direct official API response gathered in this update.
2. **Thinking off by default (F-073).** Add verified `polishOverrides` for
   reasoning-capable models. If thinking cannot be disabled, say so in the
   user-facing description.
3. **Curate, do not accumulate.** For cloud providers, keep a balanced default,
   a flagship, and a low-cost option, with no more than six models per pipeline
   unless an approved feature documents an exception.
4. **Default integrity.** Every `defaultModel` must appear in its `models` list.
5. **Retirements.** Keep a dated deprecation marker until the applicable
   retirement, then remove or migrate it through a reviewed feature. A direct
   endpoint mismatch still requires verification before deletion.
6. **Descriptions.** Keep them short and user-facing. Regional providers may
   use localized descriptions when that improves clarity.
7. **Preserve official ID syntax.** Organization prefixes and compatibility
   wrappers differ by provider; never normalize catalog IDs from aggregator
   conventions.

### F-086 pending candidate contract (2026-08)

These are evaluation candidates, not bundled catalog rows or approved
migrations. The request rules below are the exact contracts to test; a passing
offline fixture is not a substitute for target-account evidence.

| Provider / capability | Candidate action after acceptance | Request contract to validate | Default remains |
|---|---|---|---|
| OpenAI polish | Add `gpt-5.6-terra` | `"reasoning_effort": "none"` | `gpt-5.4-mini` |
| Claude polish | Replace `claude-opus-4-8` with `claude-opus-5` | Native Messages; `"thinking": {"type": "disabled"}`; omit temperature | `claude-sonnet-5` |
| Gemini polish | Replace `gemini-3.5-flash` with `gemini-3.6-flash` and `gemini-3.1-flash-lite` with `gemini-3.5-flash-lite` | `"reasoning_effort": "none"`; omit deprecated scene temperature | `gemini-2.5-flash` |
| SiliconFlow polish | Add `deepseek-ai/DeepSeek-V4-Flash` as non-default after acceptance | `"thinking": {"type": "disabled"}` | `deepseek-ai/DeepSeek-V3` |
| SiliconFlow polish | Replace `deepseek-ai/DeepSeek-V3.1-Terminus` only with accepted `deepseek-ai/DeepSeek-V4-Pro` | `"thinking": {"type": "disabled"}` | `deepseek-ai/DeepSeek-V3` |
| SiliconFlow polish | Add `zai-org/GLM-5.2` as non-default after acceptance | `"thinking": {"type": "disabled"}` | `deepseek-ai/DeepSeek-V3` |
| Qianfan polish | Evaluate ERNIE 5.1 only after `/models` proves its exact target-account slug | Record the exact accepted request payload; no slug is pre-approved | `ernie-4.5-turbo-128k` |
| OpenRouter STT | Add `openai/whisper-large-v3-turbo` | Existing OpenRouter transcription request contract | `openai/whisper-large-v3` |

Each candidate requires a recorded target account, tier, and region; at least
five successful live requests with zero schema/parameter 4xx failures; and an
accepted 36-sample polish or 30-clip STT result. Polish overrides must pass both
ordinary and speculative paths. Only then may its bundled row and any
provider-qualified migration land. Re-baseline only after every accepted public
row has landed and the final watcher diff is reviewed.

No default changes are part of F-086. A later default proposal must separately
pass the stricter default thresholds and record Joe's explicit approval.
Provider-less Mode storage remains byte-for-byte unchanged.

Qwen Flash remains gated on the target region's `/models` response plus five
chat requests. MiniMax M3 remains unchanged until international and CN
endpoints are proved independently. Claude Fable 5/Mythos 5, Kimi K3/K2.7
Code, Qwen 3.8 Max Preview, Ollama `:cloud` tags, and Volcengine Seed Evolving
remain excluded. xAI batch STT belongs to F-088 and remains disabled here.

### Thinking-control reference (verify every cycle)

| Provider | OpenAI-compatible top-level parameter |
|---|---|
| OpenAI (supported GPT-5.x models) | `"reasoning_effort": "none"`; use another value only when official model docs require it |
| Gemini compatibility layer | `"reasoning_effort": "none"` (some pro tiers may require `"minimal"`) |
| DeepSeek | `"thinking": {"type": "disabled"}` |
| Qwen / DashScope | `"enable_thinking": false` |
| Kimi / Moonshot | `"thinking": {"type": "disabled"}` |
| Zhipu GLM | `"thinking": {"type": "disabled"}` |
| MiniMax | `"thinking": {"type": "disabled"}` |
| Volcengine Doubao | `"thinking": {"type": "disabled"}` |
| Together hybrid models | `"reasoning": {"enabled": false}` |
| Groq reasoning models | `"reasoning_effort": "none"` |
| Anthropic native Messages | Thinking is off unless requested; any explicit disabled object is a candidate-specific contract that still requires live validation |

## New-provider checklist

Registry metadata is data-driven, but provider identity is still a Swift enum:

1. Add the provider case and stable `providerID` mapping in
   `VowriteKit/Sources/VowriteKit/Config/APIProvider.swift`.
2. Add the complete `providers.json` entry: base URL, authentication,
   capabilities, model blocks, and any platform filter.
3. Verify KeyVault, Settings, and iOS availability through the generic
   `availableCases` path.
4. Add an `APIPreset` only for a genuinely recommended combination.
5. Add an official direct catalog source to the watcher when one exists.
   Otherwise document a precise skip reason. An OpenRouter prefix is never a
   substitute.
6. Add an `STTAdapter` for a non-OpenAI STT protocol; OpenAI-compatible polish
   providers generally need no service-specific code.
7. Run the full validation procedure and record regional latency or data
   handling constraints in the feature spec and UI.

Reference implementations: F-030 (provider integration), F-068 (region split),
and F-062 (catalog refresh).

## Official data sources

| Provider | Models / pricing |
|---|---|
| OpenAI | <https://platform.openai.com/docs/models> and <https://openai.com/api/pricing/> |
| Anthropic | <https://platform.claude.com/docs/en/about-claude/models> and the official pricing page |
| Google Gemini | <https://ai.google.dev/gemini-api/docs/models> and <https://ai.google.dev/gemini-api/docs/pricing> |
| DeepSeek | <https://api-docs.deepseek.com/quick_start/pricing> |
| Qwen / DashScope | <https://help.aliyun.com/zh/model-studio/models> |
| Kimi / Moonshot | <https://platform.moonshot.cn/docs/price/chat> and <https://platform.kimi.com/> |
| MiniMax | <https://platform.minimax.io/docs> and <https://platform.minimaxi.com/> |
| Zhipu | <https://docs.bigmodel.cn/> and <https://bigmodel.cn/pricing> |
| Volcengine Ark | <https://www.volcengine.com/docs/82379> and <https://www.volcengine.com/pricing> |
| SiliconFlow | <https://docs.siliconflow.cn/> and <https://www.siliconflow.com/pricing> |
| Groq | <https://console.groq.com/docs/models>, <https://console.groq.com/docs/deprecations>, and <https://groq.com/pricing> |
| Together | <https://docs.together.ai/docs/serverless-models> |
| Mistral | <https://docs.mistral.ai/getting-started/models/> |
| xAI | <https://docs.x.ai/docs/models> |
| Cerebras | <https://api.cerebras.ai/public/v1/models> and official model documentation |
| Deepgram | <https://developers.deepgram.com/docs/models-languages-overview> |
| OpenRouter (discovery only) | <https://openrouter.ai/api/v1/models> |

## Watcher command reference

- **Sources:** OpenRouter public catalog, Cerebras public catalog, and supported
  keyed direct-provider endpoints.
- **State:** `ops/model-watch/state.json`, the last reviewed raw and canonical
  baseline. A read-only run continues to report drift until curation lands.
- **Exit codes:** `0` no actionable drift or deadline; `10` actionable
  discovery/deprecation warning; `3` every network source unavailable; `1`
  local catalog, manifest, state, or JSON fatal error.
- **Flags:** `--report FILE`, `--show-aliases`, `--limit-new N`, `--timeout S`,
  and the explicitly gated `--update-state`.
- **CI:** weekly plus manual dispatch; offline tests run first; missing optional
  keys remain visible as `SKIPPED_NO_KEY`; no state or catalog mutation occurs.
