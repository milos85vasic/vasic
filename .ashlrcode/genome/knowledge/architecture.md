# Architecture

> Auto-populated from an ashlr baseline scan at genome init. Edit freely to
> capture intent and tradeoffs that a scanner cannot see.

## Snapshot

- **Files scanned:** 5000 (truncated)
- **Runtime:** Unknown
- **Runtime notes:** walk: git ls-files
- **Top extensions:** .json (1219), .txt (1185), .png (1040), .md (768), .log (451), .html (138)

## Largest source files

- `_tests/evidence/live-v1.5.1/vfx/asset-motion.js` — 406 LOC
- `_tests/evidence/a11y-audit/run-audit.js` — 383 LOC
- `_tests/evidence/suite/html-report/trace/assets/defaultSettingsView-BNmKHKpQ.js` — 264 LOC

## Top-level layout

```
vasic/
├── .ashlrcode/
├── _analysis/
├── _content/
├── _content_ar/
├── _content_be/
├── _content_de/
├── _content_es/
├── _content_fa/
├── _content_fr/
├── _content_hi/
├── _content_ja/
├── _content_kk/
├── _content_ko/
├── _content_ru/
├── _content_sr/
├── _content_tr/
├── _content_zh/
├── _tests/
├── _tools/
├── ai_interviewing/
├── data/
├── design-system/
├── design-toolkit/
├── docs/
├── milosvasic.ru/
├── monetization/
├── scripts/
├── submodules/
├── tests/
├── upstreams/
├── vasic.digital/
├── AGENTS.md
├── CLAUDE.md
├── Constitution.md
├── GEMINI.md
├── MANUAL-STEPS.md
├── QWEN.md
├── README.md
├── helix-deps.yaml
```

## Notes

- The scanned snapshot above is auto-populated and may be overwritten by a
  re-scan. **Do not hand-edit it.**
- The intent-level description — why each top-level directory exists, what it
  owns, and what crosses its boundary — lives in `vision/architecture.md`.
  Structural hazards (recursive-checkout failure, hardcoded `/Volumes/T7` paths)
  are in `knowledge/discoveries.md`.
- Scanner caveat: the "Largest source files" list is dominated by
  `_tests/evidence/`, which is captured Playwright output, not source. Real
  source lives in `_tools/gen/` (Go), `_tests/tests/` + `_tests/tools/` (JS),
  and `design-system/` (CSS).
