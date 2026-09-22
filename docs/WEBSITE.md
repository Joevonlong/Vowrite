# Vowrite website

The public site is a static GitHub Pages site served from `docs/`, with the domain in `CNAME`. There is no frontend build step. Serve this directory over HTTP and open `index.html`. The homepage explains the product through six prominent features; `pricing.html` is the independent usage and historical provider-reference page.

## Design and content contract

The September 2026 implementation follows the supplied Open Design website (project `1a6dbee0-49b7-409a-bdeb-b44b26eb7e64`): neutral surfaces, orange accents, system fonts, 1200px layout, shared navigation, interactive voice examples, and progressive detail. The owner's subsequent consolidation request replaces repeated Apps, Translate and Why pages with one clear homepage. Dictation, refinement, contextual writing, translation, platforms and provider choice are visible without opening a disclosure. Four translation examples and the Mac/iOS controls are directly visible. Large platform cards distinguish the downloadable Mac app from iOS source builds. Unique installation, language, architecture and comparison details remain in their corresponding sections.

`website-assets/design-source.json` fingerprints the input design. `website-assets/content-baseline.json` pins the original product commit, content keys, text, language dictionaries, table cells, commands, links, examples and protected asset checksums. `website-assets/fact-corrections.json` records reviewed replacement copy in English, Chinese and German. No original translation keys are deleted.

`website-assets/content-consolidation.json` records the current information architecture, every old route/anchor destination and each merged duplicate's original text, reason and surviving section. Original content is either preserved/corrected at its canonical destination or explicitly accounted for as a merged duplicate. Duplicate heroes, summary feature cards, short FAQs and marketing calls to action do not remain as hidden second copies. `apps.html`, `translate.html`, `why.html` and `demo.html` are small compatibility entries with query-preserving redirects and usable no-JavaScript links.

Two pricing tables retain **all 77 original data rows**, including every model, value and note, as explicitly labeled **historical reference**, not current quotes. The English source tables are identified as English in every site language. Current billing links are presented separately. They must not be promoted to current offers without a fresh per-provider review.

## Shared components

| Component | Reference / use | States and behavior |
| --- | --- | --- |
| Navigation / language | Every page header | Responsive menu; keyboard selection, Escape, focus return; persistent en/zh/de with storage-failure fallback |
| Desktop voice example | `index.html#live-demo` | Notes/email/chat; six stages; play/pause/next/replay; real clipboard result or manual fallback; no recording or API call |
| Feature index | `#features` | Six direct links to the main sections; wraps on small screens |
| Feature example | `#dictation`, `#cleanup`, `#expression`, `#translation` | Dictation, refinement, formats and four original translation pairs using declared preset data |
| Platform cards | `#platforms` | Mac download / iOS source status, requirements, device controls and native installation disclosures |
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

The browser check covers both canonical pages, en/zh/de, widths 375/600/768/1024/1440, light/dark, expanded content, 200% zoom, accessibility, keyboard/click interactions, clipboard rejection, four original translation pairs, visible main features, reduced motion, disabled JavaScript, blocked storage, failed script loading, and WebKit. It also follows all declared legacy routes/anchors, checks query and language persistence, and exercises fallback links without JavaScript. Reports and screenshots go to the evidence directory. The static check verifies the original content and deduplication ledger, all local links/fragments/assets, exact historical table cells, translations, commands and protected assets. Native platform parity is unchanged and can be checked with `scripts/check-parity.sh`.

## Publication and rollback

The website-only change does not alter app versions, appcasts, CNAME, robots, icons or native code. GitHub Pages still needs an explicitly authorized publication and a deployed-route check, including extensionless `/why`, `/apps`, `/translate` and `/pricing`; a local static server does not prove remote routing. The first three routes now resolve to the homepage's corresponding section. Compatibility pages use `noindex,follow` and canonical homepage section URLs so they do not create duplicate content.

Rollback through a normal repository task that restores website files from the pinned product baseline; keep any unrelated later changes. Do not reset shared history or modify release feeds to undo a website change.
