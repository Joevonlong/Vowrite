# Vowrite website

The public site is a static GitHub Pages site served from `docs/`, with the domain in `CNAME`. There is no frontend build step. Open `index.html`, or serve this directory over HTTP. Each of the five original pages remains a complete independent page; `demo.html` also preserves the design's demo entry point.

## Design and content contract

The September 2026 implementation follows the supplied Open Design website (project `1a6dbee0-49b7-409a-bdeb-b44b26eb7e64`): neutral surfaces, orange accents, system fonts, 1200px layout, shared navigation, interactive voice examples, and progressive detail. Apps and Translate use the same components while retaining complete independent guides. The latest visual reference supersedes the older 980px proposal. The comparison sections, FAQ, feature details, provider guide, installation commands and roadmap remain reachable from the homepage.

`website-assets/design-source.json` fingerprints the input design. `website-assets/content-baseline.json` pins the original product commit, content keys, text, language dictionaries, table cells, commands, links, examples and protected asset checksums. `website-assets/fact-corrections.json` records reviewed replacement copy in English, Chinese and German. No original translation keys are deleted.

Two pricing tables retain **all 77 original data rows**, including every model, value and note, as explicitly labeled **historical reference**, not current quotes. The English source tables are identified as English in every site language. Current billing links are presented separately. They must not be promoted to current offers without a fresh per-provider review.

## Shared components

| Component | Reference / use | States and behavior |
| --- | --- | --- |
| Navigation / language | Every page header | Responsive menu; keyboard selection, Escape, focus return; persistent en/zh/de with storage-failure fallback |
| Desktop voice example | `index.html#live-demo` | Notes/email/chat; six stages; play/pause/next/replay; real clipboard result or manual fallback; no recording or API call |
| Feature example | `#dictation`, `#cleanup`, `#expression`, `#translation` | Dictation, refinement, formats and language selection using declared preset data |
| Provider example | `#configuration` | Validated choices and an empty-selection message; no credentials or real account changes |
| Full-detail disclosure | `.hc-details`, pricing `.va-history` | Native keyboard-operable details; original deep links open ancestor panels |
| Comparison / provider table | `.compare-table-wrap`, `.table-wrap` | Full row/column preservation; localized captions; table-local scrolling and focus |
| Fact note | `.site-fact-note` | Shared note treatment for processing scope, dates and official sources |
| Installation command | `.site-copy` with `pre` or `.download-note` | Copies only the command; announces success or selects text for manual copying |

The shared stylesheet retains the reference cascade in one `style.css`. Original branding and release assets stay in their original paths. The fact corrections cover unavailable Sherpa recognition, local text-only providers, latency, cloud data flow, authentication, device-local settings, installation, actual shortcut handling and sourced competitor capabilities. They do not imply a new native-app release or live provider validation.

## Validation

From the product root:

```sh
python3 scripts/check-website.py
python3 -m http.server 8767 --bind 127.0.0.1 --directory docs
```

With Playwright and axe-core available to Node (or installed in a temporary directory):

```sh
WEBSITE_URL=http://127.0.0.1:8767 WEBSITE_EVIDENCE=/tmp/vowrite-website-evidence node scripts/test-website.cjs
```

The browser check covers five pages, en/zh/de, widths 375/600/768/1024/1440, light/dark, expanded content, 200% zoom, accessibility, actual keyboard/click interactions, clipboard rejection, four original translation pairs, reduced motion, disabled JavaScript, blocked storage, failed script loading, and WebKit. The test writes machine-readable reports and screenshots to the evidence directory. The static check verifies content against the pinned baseline, every local link/fragment/asset, exact historical table cells, translations, commands, and protected assets. Native platform parity is unchanged and can be checked with `scripts/check-parity.sh`.

## Publication and rollback

The website-only change does not alter app versions, appcasts, CNAME, robots, icons or native code. GitHub Pages still needs an explicitly authorized publication and a deployed-route check, including extensionless `/why`, `/apps`, `/translate` and `/pricing`; a local static server does not prove remote routing. `demo.html` uses a static fallback link and a query-preserving redirect to the homepage demo.

Rollback through a normal repository task that restores website files from the pinned product baseline; keep any unrelated later changes. Do not reset shared history or modify release feeds to undo a website change.
