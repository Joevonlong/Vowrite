# Website Planning

---

## Phase 1: MVP (GitHub Pages, Zero Cost)

### Technical Approach
- Pure static HTML + CSS (single page)
- Hosted on GitHub Pages
- Custom domain (optional, ~$10/year)

### Page Structure
```
index.html
├── Hero: One-liner intro + download button + demo GIF
├── Features: 3-4 core selling points (icon + text)
├── How it works: 3-step flow diagram
├── Screenshot: Recording bar + settings UI screenshots
├── Download: Version number + DMG download link
├── FAQ: Frequently asked questions
└── Footer: GitHub link + version info
```

### Deployment
```bash
# Place static files in docs/ directory
# GitHub Settings → Pages → Source: /docs
```

### Domain Options
- Free: `username.github.io/vowrite`
- Custom: `vowrite.com` (already purchased)

---

## Phase 2: Enhancement (After Gaining Users)

- Integrate Plausible / Umami lightweight analytics (privacy-friendly)
- Add Changelog page (auto-generated from RELEASE_NOTES.md)
- Add documentation pages (installation guide, provider configuration)
- Multi-language support (Chinese/English)

---

## Phase 3: Production (After v1.0)

- Migrate to Astro / Next.js (if more complex pages are needed)
- Sparkle appcast.xml hosting (auto-update)
- Download statistics
- User feedback form

---

## Design References

Similar product website style references:
- Typeless (typeless.ch) — Clean, single-page, dark theme
- Whisper Transcription (goodsnooze.gumroad.com) — Minimalist
- Superwhisper (superwhisper.com) — Polished, animated

### Design Principles
- Dark theme (consistent with app style)
- Mobile-friendly
- Fast loading (pure static, no JS framework dependencies)
- Prominent download button
