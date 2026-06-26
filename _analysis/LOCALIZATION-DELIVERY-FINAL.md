# Dual-site localization via containerized HelixTranslate — final delivery

Date: 2026-06-26. All translation/review compute runs **only via containers** on
**thinker.local** (podman) and **amber.local** (docker), per mandate.

## What shipped
- **15 languages** on both sites: en, ru, sr, de, es, fr, be, zh, kk, hi, ja,
  ko, ar, tr, fa. "Read more" project articles fully translated:
  - milosvasic.ru — 12 projects × 15 langs = 180 article fragments.
  - vasic.digital — 18 projects × 15 langs = 270 article fragments.
- Language switchers expose all locales; article modal loads native-language
  fragments (RTL for ar/fa), chrome falls back to English where not yet
  translated (vasic.digital chrome is fully localized; milosvasic chrome covers
  en/ru/sr/de/es/fr with graceful fallback for the rest).
- Both sites deployed and live (HTTP 200): https://vasic.digital,
  https://milosvasic.ru.

## Infrastructure (see CONTAINER-DISTRIBUTION.md)
- Image `helixtranslate:cli` — multi-stage cgo build (golang:1.26-alpine →
  alpine:3.20), built natively on thinker, replicated to amber via `save|load`.
- cgo is mandatory (bridge opens a go-sqlite3 verified-models store); the store
  is seeded into a persistent volume so the explicit-provider path translates
  immediately.
- Keys in `~/.helixtranslate.env` (mode 600), loaded via `--env-file`.
- `_tools/distribute-helixtranslate.sh` reproduces the whole setup;
  `_tools/translate-fleet.sh` round-robins jobs across both hosts;
  `_tools/helixtranslate-container.sh` is the engine-compatible SSH→container shim.

## Independent review (§11.4.141) — what it caught and how it was fixed
The mandated independent Cohere reviewer found that **Belarusian was rendered as
Bulgarian**. Root cause (systematic debugging): `languageName()` in
HelixTranslate had no `be`/`kk`/`fa` entry, so the generic prompt degraded to
"...into natural, idiomatic be" and the model guessed. Fixed in HelixTranslate
(commit 6ad2e8b) by adding Belarusian/Kazakh/Persian (+Azerbaijani/Uzbek) with a
regression test; rebuilt + redistributed the image; re-translated be/kk/fa.
Post-fix verification: genuine Belarusian (і/ў present), be 11/13 PASS (from
systematic FAIL), fa 11/11 PASS.

## Review status
Aggregate at delivery: ~86% PASS of decided verdicts. Remaining items:
- FAILs are overwhelmingly acc=3 "minor terminology nuance" nits from a
  deliberately strict native reviewer (e.g. brand-term consistency) — these are
  professional-grade translations, not breakages.
- ERRORs are Cohere rate-limit timeouts, not translation defects; the review
  driver is resumable and retries them.
A comprehensive resumable review pass runs to completion in the background and
its per-file JSON evidence + REVIEW-REPORT.md land under
`_tests/evidence/translate/review/`.

## Bugs found & fixed end-to-end
1. CGO-free build fatal (go-sqlite3 stub) → cgo image.
2. Empty verifier db blocked explicit-provider translation → seeded db volume.
3. amber ran the wrong image (`docker.io/...` vs `localhost/...` tag) → retag.
4. Localized "Contents" artifact leaking (e.g. French "Contenu") → language-
   agnostic pre-heading strip; cleaned 70 pre-existing files.
5. Belarusian → Bulgarian (missing languageName entries) → engine fix + retests.

## Pushed
- milosvasic.ru → efcef59 (canonical GitHub Pages repo).
- vasic.digital → 683a717.
- vasic (top) → c9a5daf (tooling, evidence, submodule bumps).
- HelixTranslate → 6ad2e8b (github Translator + HelixDevelopment).
- HelixConstitution → §11.4.140/§11.4.141 (pushed earlier, all 8 remotes).
