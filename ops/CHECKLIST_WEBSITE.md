# Website Maintenance Checklist

> Operational steps for keeping `vowrite.com` (served from `docs/` via GitHub Pages) consistent and current. The website is **decoupled** from the app release process — `release.sh` only updates `appcast*.xml`.
>
> State and history live at `Vowrite-internal/tracking/website.md`. This file = executable steps.

---

## Three update tracks

| Track | Trigger | Cadence | Commit prefix |
|-------|---------|---------|---------------|
| **A. Content Audit** | provider catalog refresh OR ≥60 days since last audit | Monthly | `docs(website-A): ...` |
| **B. Release Sync** | stable release tagged | Per stable release | `docs(website-B): ...` |
| **C. Marketing Asset** | new screenshots / GIF / OG image / copy rewrite | Sporadic | `docs(website-C): ...` |

> Only one track per commit. If you do two passes in one sitting, make two commits.

---

## Track A — Content Audit

**Goal:** keep `pricing.html` aligned with `providers.json` and current official prices.

### Inputs
- `VowriteKit/Sources/VowriteKit/Resources/providers.json` — source of truth for which providers/models exist
- Provider official pricing pages — see "Resources" in `Vowrite-internal/tracking/website.md`

### Steps

1. **Diff providers.json since last audit:**
   ```bash
   git log --since="<last-audit-date>" -p -- VowriteKit/Sources/VowriteKit/Resources/providers.json | head -200
   ```
   Note any added/removed model IDs.

2. **For each affected provider, fetch current pricing** from its official page (links in tracking/website.md). Do **not** copy from aggregator sites like OpenRouter unless the row explicitly represents an OpenRouter entry.

3. **Edit `docs/pricing.html`:**
   - STT table — one row per `stt.models[*]` entry. Use `<span class="badge ...">` for FREE / FASTEST / CHEAPEST / TOP ACCURACY / DEFAULT.
   - Polish table — group by provider; for mainstream providers (OpenAI / Claude / Gemini / DeepSeek / Kimi / MiniMax / Doubao / Qwen / Zhipu) keep multiple versions when meaningful.
   - Monthly cost estimate cards — update model names + recompute numbers if any default changed (assumes 30 min/day = 15 STT-hours + 300K Polish tokens / month).

4. **Update footer date:**
   ```html
   <p style="margin-top:6px;">Last updated: <Month> 2026 · v<X.Y.Z.B></p>
   ```

5. **Run validation:**
   ```bash
   ops/scripts/website-check.sh
   ```

6. **Commit:**
   ```bash
   git add docs/pricing.html
   git commit -m "docs(website-A): refresh pricing for <reason>"
   git push origin main
   ```

7. **Update state:** edit `Vowrite-internal/tracking/website.md` — bump "上次 Track A" date and add a History row.

### Style invariants
- Each provider's default model in providers.json gets `⭐ Default` in the rightmost column.
- Free entries use `<span class="badge badge-free">` and `<td class="price free">Free ✨</td>` / `Free 🖥️` / `Free 🔒` (offline).
- Currency: USD. CNY → USD at ~¥7.2 per $1. Note conversion in the footer note.

---

## Track B — Release Sync

**Goal:** site labels match the latest stable release.

### Trigger
Run immediately after `ops/scripts/release.sh` completes a stable release (the script will print a reminder).

### Steps

1. **Bump version strings** in `docs/index.html`:
   - JSON-LD `"softwareVersion": "X.Y.Z.B"`
   - Visible footer: `<p class="version fade-in">vX.Y.Z.B · macOS 14 Sonoma · ...</p>`

2. **Bump pricing.html footer:**
   - `Last updated: <Month> 2026 · vX.Y.Z.B`

3. **(Optional) hero / why.html copy** — only if the release shipped a user-visible feature worth headlining. Most patch releases don't need this.

4. **Run validation:**
   ```bash
   ops/scripts/website-check.sh
   ```
   Must be green before commit.

5. **Commit:**
   ```bash
   git add docs/index.html docs/pricing.html
   git commit -m "docs(website-B): sync to vX.Y.Z.B"
   git push origin main
   ```

6. **Update state:** edit `Vowrite-internal/tracking/website.md` — bump "上次 Track B" date + version, add History row.

> If you bundle Track A and B in one editing session (common scenario right after a release that also added providers), still split into two commits with their respective prefixes.

---

## Track C — Marketing / Asset

**Goal:** swap stale screenshots / placeholder OG images / hero copy as new assets become available.

### Trigger
- New product screenshot from Joe → replace `docs/screenshot-placeholder.png` references
- 1200×630 OG share image ready → add `<meta property="og:image">` references and put file at `docs/og-image.png`
- Hero / why copy rewrite (Joe drives, not Arnold)
- New i18n translations (EN/ZH/DE) → edit `docs/i18n.js`

### Steps

1. Drop new asset(s) into `docs/`.
2. Edit referencing HTML files. Keep filename stable when replacing — easier to diff.
3. For copy changes, update **all three i18n locales** in `i18n.js` (or leave `nav.foo` in EN only if intentional).
4. Run validation:
   ```bash
   ops/scripts/website-check.sh
   ```
5. **Commit:**
   ```bash
   git add docs/<assets>
   git commit -m "docs(website-C): <what changed>"
   git push origin main
   ```

---

## Validation script

`ops/scripts/website-check.sh` checks:

1. Version-string consistency: `Version.swift` ↔ `Info.plist` `CFBundleShortVersionString` ↔ `docs/index.html` JSON-LD `softwareVersion` ↔ visible footer ↔ `pricing.html` footer.
2. Live URLs return HTTP 200: `https://vowrite.com/`, `/why`, `/pricing`, `/appcast.xml`.
3. `pricing.html` "Last updated" warning if >60 days.
4. Nav consistency: every page that has a nav has `/why` and `/pricing` entries.

Exit codes:
- `0` — all green
- `1` — version drift (must fix before any Track A/B/C commit)
- `2` — link broken (must fix immediately)
- `3` — soft warning only (>60 days). Does NOT block commits, but flag in next month's planning.

---

## What NOT to do

- ❌ **Do not edit `docs/appcast.xml` or `docs/appcast-beta.xml` by hand.** Those are owned by `release.sh`.
- ❌ **Do not bundle website changes into product feature commits.** Always a dedicated `docs(website-*): ...` commit.
- ❌ **Do not run Track A and B in the same commit.** Split for clean git log.
- ❌ **Do not copy prices from aggregators (OpenRouter, etc.) for a provider's own row.** Only use the provider's official page. OpenRouter gets its own row labeled as such.
