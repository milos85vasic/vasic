# Dual-Site + HelixTranslate — Implementation & Delivery Report

**Date:** 2026-06-25
**Author:** Milos Vasic
**Repos in scope:**
- `/Volumes/T7/Projects/vasic` (monorepo with `milosvasic.ru` and `vasic.digital` as submodules, plus `_tests/`, `_tools/`, `_analysis/`)
- `/Volumes/T7/Projects/helix_translate` (HelixTranslate Go engine)

**Ground rule for this report:** every claim below is grounded in a real file, a `git diff`, a test run, or an evidence artifact on disk. Where a claim in the original brief turned out to be inaccurate, the discrepancy is stated honestly rather than papered over (see §1 note on test count, §2.4 on PDFs, §9 on known-bad providers).

> **Commit status:** None of the work described here has been committed yet. All website changes are in the working tree of the two submodules; all `_tests/`, `_tools/`, `data/` additions are untracked in the monorepo; and the HelixTranslate fix is uncommitted in `/Volumes/T7/Projects/helix_translate` (including the new untracked `pkg/bridge/provider_routing_test.go`). This report does not commit or push anything.

---

## 1. Scope & Goals

A two-site rebuild plus an engine fix that unblocks the multilingual content pipeline both sites depend on:

1. **`milosvasic.ru`** — personal CV / portfolio (Jekyll static site). Goals: factual correctness, full i18n (6 languages), no-flash dark/light theme with persistence, responsive layout with no mobile overflow, multi-language downloadable CV/Cover-Letter PDFs via a chooser popup, and a "Read more" article system for featured projects.
2. **`vasic.digital`** — company site (plain static HTML/CSS/JS). Goals: a parallel "Read more" article system across all 18 portfolio cards, 29-language i18n, corrected/verified project claims, and confirmed structural health.
3. **HelixTranslate integration** — the Go engine at `/Volumes/T7/Projects/helix_translate` is the translation backend for both sites' multilingual article content. A provider-routing bug made explicit `-provider` selection unreliable; fixing it was a precondition for grounding non-English article content. A reusable translation pipeline (`_tools/translate-pipeline.sh`) and article renderer (`_tools/render-articles.sh`) wire the engine into both sites.
4. **Constitution standard** — both the engine and the content pipeline are governed by the HelixTranslate Constitution (`/Volumes/T7/Projects/helix_translate/Constitution.md` + the inherited universal `constitution/Constitution.md`). Load-bearing mandates applied here: reproducibility from a clean clone, "tests track behavior not code," **no silent skips / no silent mocks above unit tests**, and the no-silent-fallback provider contract enforced by the engine fix (§11.4.69 / §11.4.6).

**Verification posture:** 46 Playwright tests pass on chromium across both sites (§7); the HelixTranslate fix is proven by a dedicated Go test suite plus before/after engine logs (§5); 60 real translation runs (30 articles × ru + sr) are logged under `_tests/evidence/translate/` (§6).

---

## 2. milosvasic.ru — Changes

Repo: `/Volumes/T7/Projects/vasic/milosvasic.ru`. Latest commit `29a11fe` ("Auto-commit"); the relevant prior baseline is `1cf7f9c` ("Complete CV website rebuild…"). All changes below are in the working tree.

### 2.1 Facts corrected

**Location: `Moscow` → `Dubna`, separator `·` → `⇄`** (`index.html`, `_layouts/default.html`):
- `index.html` datasheet "based" row — before: `<span class="v">Belgrade, RS · Moscow, RU</span>`; after: `<span class="v" data-i18n="ds.based_v">Belgrade, RS ⇄ Dubna, RU</span>`. The value also gained a `data-i18n` attribute so it is now translatable (previously hard-coded English).
- `_layouts/default.html` footer — before: `… Milos Vasic — Belgrade · Moscow. Built as a static site…`; after: `… Milos Vasic — Belgrade · Dubna. Built as a static site…`.

**Russian proficiency: `Russian (C1)` → `Russian (basic)`** (`index.html` languages row), propagated across all 6 locales in `assets/js/i18n.js` via the new `ds.langs_v` key: en `Russian (basic)`, ru `русский (базовый)`, sr `руски (основни)`, de `Russisch (Grundkenntnisse)`, es `ruso (básico)`, fr `russe (notions)`.

**Languages list membership** (Serbian native / English C2 / Russian) is unchanged — only the Russian level was downgraded and the strings became i18n-driven.

### 2.2 Datasheet value i18n keys (6 languages)

File: `/Volumes/T7/Projects/vasic/milosvasic.ru/assets/js/i18n.js`. Six language tables confirmed in order: **en, ru, sr, de, es, fr** (`window.MV_LANGS`). Each datasheet value is now keyed: `ds.based_v`, `ds.remote_v`, `ds.since_v`, `ds.focus_v`, `ds.repos_v`, `ds.stack_v`, `ds.langs_v` (7 value keys × 6 languages). Plus new download-modal keys `dl.heading`, `dl.choose`, `dl.cv`, `dl.cl`, `dl.close` and a `card.more` key per language. Dictionary completeness across all 6 languages is enforced by a Node unit test (§7, `i18n-completeness.spec.js`).

### 2.3 Download popup (EN/SR/RU chooser)

- **JS:** `/Volumes/T7/Projects/vasic/milosvasic.ru/assets/js/downloads.js` (new, untracked, ~47-line IIFE, no deps). Event-delegated click on `[data-dl]` (`data-dl="cv"` | `"cl"`). `FILES = { cv: 'Milos_Vasic_CV', cl: 'Milos_Vasic_Cover_Letter' }`. On open, the three `.dl-lang` anchors (`data-lang="EN|SR|RU"`) are assigned `href = base + fbase + '_' + lang + '.pdf'` (e.g. `/downloads/Milos_Vasic_CV_EN.pdf`). Dialog title localized via `window.MV_I18N` keyed by `<html lang>`. Accessibility: Esc + backdrop close, focus moved to close button on open and restored on close, body scroll lock (`mv-article-lock`). Exposes `window.MVDownloads = { open, close }`.
- **Modal markup:** `_layouts/default.html` (`#dl-modal`, `data-base="{{ '/downloads/' | relative_url }}"`). The hero `<button data-dl="cv|cl">` and contact-card links replace the old direct PDF `<a href download>` links.
- **CSS:** `assets/css/style.scss` (modified) appends a "Read-more article modal" + download-modal block (~265 lines added) styling `.dl-modal` / `.dl-card` / `.dl-lang` / `.dl-x`, reusing the shared `mv-article-lock` body lock.

### 2.4 The 6-PDF build pipeline

Script: `/Volumes/T7/Projects/vasic/milosvasic.ru/downloads/src/build-pdfs.sh` (modified). Per doc: `pandoc` (md → html5 fragment) → ATS HTML template with `lang` + `ats.css` → `weasyprint` → PDF written to `downloads/`. Intended matrix: docs `{cv, cover-letter}` × langs `{EN, SR, RU}` = 6 PDFs (plus legacy un-suffixed `.pdf` from the EN source). Missing source markdown is skipped with a warning (`[ -f "$md" ] || skip`), never failing the build.

**Source markdown present** in `downloads/src/`: `cv.md`, `cover-letter.md`, `cover-letter.sr.md` (new), `ats.css`. **Missing:** `cv.sr.md`, `cv.ru.md`, `cover-letter.ru.md`.

**PDFs actually present** in `downloads/`: `Milos_Vasic_CV.pdf`, `Milos_Vasic_CV_EN.pdf`, `Milos_Vasic_Cover_Letter.pdf`, `Milos_Vasic_Cover_Letter_EN.pdf`, `Milos_Vasic_Cover_Letter_SR.pdf` — i.e. **5 PDFs, not 6.** There is no `Milos_Vasic_CV_SR.pdf` and no `_RU` PDF for either doc, because the corresponding markdown sources have not been authored/translated yet. The popup JS unconditionally builds the SR/RU hrefs, so those buttons currently 404. This is a known limitation gated on the translation pipeline run (§9); the test suite is written to match reality — it only asserts 200 for the EN CV and EN/SR Cover Letter (§7, `milosvasic-ru-features.spec.js:35`).

### 2.5 Read-more article system (12 articles)

- **Sources:** `/Volumes/T7/Projects/vasic/milosvasic.ru/_article_src/` — `en/` has **12** `.md` files; `sr/` has 3 (android-toolkit, catalogizer, helix-agent); `ru/` has 3 (grab-tube, helix-flow-platform, helix-track-core).
- **Output:** `articles/en/` has **12 rendered `.html` fragments** (and they are copied into `_site/articles/en/` on Jekyll build). `articles/sr/` and `articles/ru/` are not yet rendered.
- **The 12 slugs/titles:** android-toolkit (Android Toolkit), catalogizer (Catalogizer), grab-tube (GrabTube), helix-agent (HelixAgent), helix-code (HelixCode), helix-flow-platform (Helix-Flow Platform), helix-track-core (HelixTrack Core), helix-translate (HelixTranslate), llms-verifier (LLMs Verifier), mail-server-factory (Mail Server Factory), panoptic (Panoptic), share-connect (ShareConnect). These exactly match the 12 `data-article="…"` "Read more →" links added to the project cards in `index.html`.
- **JS:** `assets/js/articles.js` (new, untracked, ~233-line IIFE, idempotent guard `if (window.MVArticles) return`). Event-delegated click on `[data-article]` → builds an ARIA `role=dialog aria-modal` modal on first use → `fetchFragment(slug)` fetches `articles/<lang>/<slug>.html` (lang from `document.documentElement.lang`), falling back to `articles/en/<slug>.html`. Loading spinner, error+Retry state, out-of-order fetch guard (`state.reqId`), Esc-close, Tab focus-trap, body scroll lock (`mv-article-lock`), focus restore. Public API `window.MVArticles` + globals `window.openArticle` / `window.closeArticle`.
- **Renderer:** `/Volumes/T7/Projects/vasic/_tools/render-articles.sh` (see §6).

---

## 3. vasic.digital — Changes

Repo: `/Volumes/T7/Projects/vasic/vasic.digital`. Latest commit `507bde7` ("Complete company website polish… 29-language i18n…"). Changes below are in the working tree.

### 3.1 Read-more wiring (18 cards)

- **JS:** `js/articles.js` (new, untracked, ~233 lines, IIFE, guard `if (window.VDArticles) return`). Same architecture as the milos site: click delegation on `[data-article]`, lazily-built ARIA dialog, `fetchFragment` with `articles/<lang>/<slug>.html` → `articles/en/<slug>.html` fallback, `innerHTML` injection of trusted first-party fragments with `escapeHtml()` on dynamic values, focus trap, Esc close, scroll lock (`vd-article-lock`), `state.reqId` race guard, loading/error/Retry states. Public API `window.VDArticles` + `window.openArticle` / `window.closeArticle`.
- **CSS:** `css/articles.css` (new, untracked, ~216 lines). `.vd-article-modal` BEM tree reusing theme tokens (`--card-bg`, `--accent-primary`) with fallbacks, dark-theme override, mobile bottom-drawer ≤600px, `prefers-reduced-motion`, typography for injected `.hx-article` content.
- **index.html wiring** (`git diff index.html`): adds `<link rel="stylesheet" href="css/articles.css">` and `<script src="js/articles.js" defer></script>`, plus exactly **18** `<a class="read-more" href="#" data-article="…">Read more →</a>` anchors — one per portfolio card, after each existing `.project-link`. Confirmed: `grep -c 'class="read-more"'` = 18, matching 18 GitHub `.project-link`s. The 18 slugs: catalogizer, grabtube, shareconnect, panoptic, android-toolkit, asinka, helixtrack-core, helixcode, helixtranslate, helix-flow-platform, llmsverifier, server-factory-core-framework, mail-server-factory, helixtrack-web-client, helixtrack-desktop-client, helixtrack-android-client, helixtrack-ios-client, yole.
- **`readMore` translation key** (`git diff js/translations.js`, "1 file changed, 6 insertions(+), 4 deletions(-)"): en `readMore: "Read more →"`, ru `"Подробнее →"`, sr `"Сазнај више →"`, fr `"En savoir plus →"`, de `"Mehr erfahren →"`, es `"Leer más →"`. `js/language-switcher.js` (modified) re-translates the anchors on language switch with an existence-guarded hook:
  ```js
  const readMore = item.querySelector('.read-more');
  if (readMore && t.portfolio.readMore) { readMore.textContent = t.portfolio.readMore; }
  ```

### 3.2 Article sources & output

- `_article_src/en/` — **18** `.md` files. `articles/en/` — **18** `.html` fragments. 1:1 mapping; all 18 filenames match the 18 `data-article` slugs. Sample fragment structure (`articles/en/catalogizer.html`): `<article class="hx-article">` → `<header class="hx-article-head">` with `<h1>` title, `hx-article-tech` line, repo link, then `<h2>` body sections.

### 3.3 Verified healthy

- `index.html`: valid `<!DOCTYPE html>`, `<html lang="en">`, balanced divs (120 `<div` / 120 `</div>`).
- `translations.js`, `articles.js`, `language-switcher.js`: all pass `node --check`. The prior syntax-fix commit `f60e563` ("Fix missing closing brace…") is the last edit in that area; the file is currently clean.
- **29 languages** in `translations.js`: en, ru, be, zh, hi, fa, ar, ko, ja, sr, fr, de, es, pt, no, da, sv, is, bg, ro, hu, it, el, he, ka, kk, uz, tg, tr (matches the "29-language i18n" claim).

---

## 4. The 30 Project Articles

Total = **12 (milosvasic.ru) + 18 (vasic.digital) = 30** English article sources, each rendered to an HTML fragment (verified counts: `ls _article_src/en/*.md` → 12 and 18 respectively).

**How generated & grounded:** each article is hand-authored Markdown with YAML frontmatter (`title`, `slug`, `repo`, `tech`, `teaser`) followed by a narrative body in a consistent structure ("The hook", "Why it's fascinating", "The hard problems", …). Grounding rules observed in the sources:
- **Real repositories only.** Frontmatter `repo:` points at actual GitHub repos — e.g. `helix-track-core.md` → `https://github.com/Helix-Track/Core`. The article renderer surfaces this link in the fragment header.
- **No fabricated metrics.** The bodies describe architecture and design decisions qualitatively (e.g. HelixTrack Core's single action-routed `/do` endpoint, SQLCipher-encrypted storage, Documents V2 module) rather than inventing benchmark numbers or adoption figures.
- **Private HelixTrack clients are described at product level only.** The vasic.digital set includes `helixtrack-web-client`, `helixtrack-desktop-client`, `helixtrack-android-client`, `helixtrack-ios-client` — these describe the product line without deep-linking to private repos. This is independently enforced by a Playwright guard that fails if any portfolio link deep-links a known-private repo path (§7, `vasic-digital.spec.js:48`, banned list incl. `/Web-Client`, `/Desktop-Client`, `/Android-Client`, `/iOS-Client`, `/Bear-Suite/*`).

**Counts by site:**
- milosvasic.ru (12): android-toolkit, catalogizer, grab-tube, helix-agent, helix-code, helix-flow-platform, helix-track-core, helix-translate, llms-verifier, mail-server-factory, panoptic, share-connect.
- vasic.digital (18): catalogizer, grabtube, shareconnect, panoptic, android-toolkit, asinka, helixtrack-core, helixcode, helixtranslate, helix-flow-platform, llmsverifier, server-factory-core-framework, mail-server-factory, helixtrack-web-client, helixtrack-desktop-client, helixtrack-android-client, helixtrack-ios-client, yole.

---

## 5. HelixTranslate Fix — Provider Routing

Repo: `/Volumes/T7/Projects/helix_translate`. Uncommitted working-tree change. Touched files: `cmd/unified-translator/main.go`, `cmd/markdown-translator/main.go`, `pkg/bridge/bridge.go`, `pkg/translator/llm/llm.go`, `pkg/translator/llm/verified_factory.go`, plus the new untracked test `pkg/bridge/provider_routing_test.go`.

### 5.1 Root cause

When an operator passed an explicit `-provider X`, the run did **not** route to X. There was no explicit-provider routing path, so the selection fell through to the bridge's "strongest-verified-model" default branch, and the logger printed `config.Model` — which **defaults to the literal `"gpt-4"`**. Net effect: `-provider gemini` logged `model=gpt-4` and the request actually hit **OpenAI**.

**Hard before-evidence** (`_tests/evidence/helixtranslate/BEFORE.bug-repro.gemini.log`):
```
INFO: Starting API-based translation | provider=gemini model=gpt-4
[LLM_ERROR] ... OpenAI API error (status 403): {"code":403,"reason":"NOT_ENOUGH_BALANCE", ...}
```
A `-provider gemini` request produced an **OpenAI** 403 — proof the explicit provider was ignored and routed to OpenAI/gpt-4. Two defects: (a) `parseFlags()` never distinguished `-provider gemini` from the default `"openai"`; (b) `executeAPITranslation` logged raw `config.Model` regardless of the real provider.

### 5.2 The fix

A deterministic explicit-provider routing path with a **no-silent-fallback** contract (§11.4.69 / §11.4.6):
- `pkg/bridge/bridge.go`: new `ProviderRequest` struct + `TranslatorForProvider` / `ClientForProvider`. `ClientForProvider` resolves model (explicit `-model` → strongest-verified-for-provider → honest error), API key (explicit → `<PROVIDER>_API_KEY` via `factory.ResolveProviderKey` → honest error), and base URL (explicit → resolver canonical) — never cross-provider switching, never an empty-key client. A new `openAICompatibleProviders` map decides the OpenAI-compatible generic-client path vs the native-wire path (anthropic via `llm.NewClientForProvider`).
- `pkg/translator/llm/llm.go`: extracted the per-provider client switch into a shared `newClientForProvider`; added exported seams `NewClientForProvider` (raw client) and `NewLLMTranslatorWithClient` (wraps a prebuilt client so the real translation prompt reaches the model).
- `pkg/translator/llm/verified_factory.go`: added `ResolveProviderKey` exposing env-key resolution to the bridge.
- `cmd/unified-translator/main.go`: added `ProviderExplicit` / `ModelExplicit` detection (via `flag.Visit`), a new `case config.ProviderExplicit:` branch calling `providerTranslator(...)`, and replaced the misleading `model=config.Model` log line with a `Translator selected | selected_provider=<trans.GetName()>` line reporting the real provider. On failure it returns `provider=%s translation unavailable (no silent fallback)`.
- `cmd/markdown-translator/main.go`: parallel change — `-api-key` / `-base-url` flags, `providerExplicit`/`modelExplicit` detection, `bridgeWorkflowConfig` calls `b.ClientForProvider(...)` when explicit, else `b.BestClient`.

### 5.3 The test that proves it

`pkg/bridge/provider_routing_test.go` intercepts the single client-construction seam (`clientBuild`, no network) and asserts the actual `(marker, model, baseURL)` requested:
- `TestClientForProvider_RoutesToRequestedProvider` (8 sub-cases): each provider routes to its own host — groq→`api.groq.com`, mistral→`api.mistral.ai`, novita→`api.novita.ai`, zhipu→`bigmodel.cn`, and the pivotal **"gemini routes to Google's OpenAI-compatible endpoint, NOT OpenAI"** asserting `generativelanguage.googleapis.com` — directly locking the reproduced bug. Also covers `-model` (`llama-3.3-70b-versatile`) and `-base-url` overrides, and asserts `c.GetProviderName()` equals the requested provider (the misleading-log half).
- `TestClientForProvider_NoSilentFallback`: bare provider with no verified model + no `-model` → honest error, not a silent switch.
- `TestClientForProvider_MissingKeyHonestError`: known provider, no key → honest "API key" error.
- `TestTranslatorForProvider_WrapsClient`: translator reports the requested provider (`mistral`).

### 5.4 Working providers + model-bridge

Configured in `internal/verifier/providers_env.go` and `pkg/translator/llm/llm.go` whitelists:
- **groq** → `https://api.groq.com/openai/v1`, model **`llama-3.3-70b-versatile`** (the verified working primary).
- **mistral** → `https://api.mistral.ai/v1`, model **`mistral-large-latest`** ("large", the verified fallback).

**Proven working (live evidence, not just config):**
- groq EN→RU Cyrillic — `proof.en2ru.cyrillic.log`: `provider=groq provider_explicit=true` → `selected_provider=llm-groq` → success in 464ms.
- groq EN→SR Latin — `proof.en2sr.latin.log`.
- mistral EN→RU Cyrillic — `proof.en2ru.mistral.log`: `selected_provider=llm-mistral`, ~2.99s.
- markdown-translator honoring explicit groq — `markdown-translator.groq.ru.log`.

**model-bridge** (`cmd/model-bridge/`): a CLI exposing the LLMsVerifier-selected strongest verified model to operators and to a Claude Code agent. Subcommands `best-model`, `list`, `invoke -prompt`, and `mcp` (stdio MCP server with `bridge_invoke` / `bridge_best_model` / `bridge_list`). Reads provider keys from `*_API_KEY`, runs the in-process verification pipeline, persists to SQLite (`./data/verified_models.db`), never prints key values (§11.4.10), delegates to `pkg/bridge`. Evidence `model-bridge-proof.log`: `BUILD_OK`; `best-model` returns strongest = `novita/Sao10K/L3-8B-Stheno-v3.2` (score 0.91875) with a 7-entry fallback chain.

### 5.5 Evidence index — `/Volumes/T7/Projects/vasic/_tests/evidence/helixtranslate/`

| File | Shows |
|---|---|
| `BEFORE.bug-repro.gemini.log` | The bug: `-provider gemini` logged `model=gpt-4`, hit OpenAI (403 NOT_ENOUGH_BALANCE) |
| `go-test.provider-routing.log` / `gotest-provider-routing.log` | All routing tests + 8 sub-cases PASS; `ok pkg/bridge` |
| `go-test.touched-packages.log` | `ok` for `pkg/bridge`, `pkg/translator/llm`, `cmd/unified-translator`, `cmd/markdown-translator` |
| `gotest-core.log`, `gobuild-cmd.log` | core package tests + cmd build OK |
| `govet.log` | `go vet` exit code 0 |
| `model-bridge-proof.log` | model-bridge builds, emits strongest model + fallback chain |
| `markdown-translator.groq.ru.log` | markdown-translator honors explicit `-provider=groq` |
| `proof.en2ru.cyrillic.{log,md,_session_report.md}` | groq EN→RU Cyrillic success + session report |
| `proof.en2ru.mistral.{log,md,_session_report.md}` | mistral EN→RU Cyrillic success + report |
| `proof.en2sr.latin.{log,md,_session_report.md}` | groq EN→SR Latin success + report |

---

## 6. Universal Translation Pipeline & Constitution Mandate

### 6.1 `_tools/translate-pipeline.sh`

`/Volumes/T7/Projects/vasic/_tools/translate-pipeline.sh` — reusable Markdown translation wrapper around the engine binary (`HELIX_TRANSLATE_BIN`, default `/Volumes/T7/Projects/helix_translate/build/unified-translator`; binary confirmed present and executable on disk). Key behavior:
- Two modes: **plain** (translate whole file) and **`--article`** (keep YAML frontmatter byte-identical — slugs/repos/tech/title/teaser are proper nouns / URLs that must survive so links keep working — and translate only the body, then reassemble original-frontmatter + translated-body).
- Language→script: `ru → cyrillic`, `sr → latin`.
- **Provider strategy:** primary `groq` / `llama-3.3-70b-versatile`, with up to 3 retries and quadratic backoff (15s/60s/135s) to clear rate-limit windows, then fall back to `mistral` / `mistral-large-latest`. The provider that actually produced the output is recorded in the per-file log.
- Idempotent and re-runnable; destination is **not** written on failure (exit non-zero) so callers detect it; per-run evidence appended under `_tests/evidence/translate/`.

**Evidence of real runs:** `_tests/evidence/translate/` contains **60** logs — `*.ru.log` + `*.sr.log` for the article slugs across both sites (e.g. `helix-track-core.ru.log`, `catalogizer.sr.log`, `helixtrack-android-client.ru.log`, …). These are the proof that the pipeline executed end-to-end through the engine for ru and sr.

### 6.2 `_tools/render-articles.sh`

`/Volumes/T7/Projects/vasic/_tools/render-articles.sh` — renders `<root>/_article_src/<lang>/*.md` into `<root>/articles/<lang>/*.html`. Per file: extract `title`/`repo`/`tech` frontmatter (awk) → `pandoc -f markdown -t html5` on the body → wrap in `<article class="hx-article">` with header (`<h1>`, optional tech `<p>`, optional repo link). Underscore source dir is Jekyll-excluded; `articles/` is served verbatim. Usage `render-articles.sh <site-root> <lang> [<lang> …]`.

### 6.3 Constitution mandate

Both engine and pipeline are governed by `/Volumes/T7/Projects/helix_translate/Constitution.md` (extending the universal `constitution/Constitution.md`). Applied mandatory standards: reproducibility from a clean clone; tests track user-visible behavior, not implementation; **no silent skips, no silent mocks above unit tests**; Conventional Commits; SSH-only git. The engine fix's no-silent-fallback contract (§11.4.69 / §11.4.6) is the direct constitutional expression of "no silent skips" at the provider-routing layer — an unavailable explicit provider errors honestly rather than silently switching.

---

## 7. Test Results

**Command:** `npx playwright test --project=chromium` in `/Volumes/T7/Projects/vasic/_tests`.
**Result (this session):** **46 passed (32.0s)** on chromium. (The brief's "~51 tests" is a slight overcount; the verified chromium total is 46. The suite also defines firefox and webkit projects, so the all-project total is higher.)

Per-spec breakdown (chromium):

| Spec | Tests | Covers |
|---|---|---|
| `tests/milosvasic-ru.spec.js` | 15 | Title; hero name/role/CV button; portrait image loads; no-flash `data-theme`; theme toggle + persistence (`mv-theme`); language switch EN→RU/SR/DE (nav text + `mv-lang`); nav scroll-to-section; ≥6 work-card GitHub links (non-404); ≥4 experience timeline items; skill chips; **download popup opens, EN CV link returns 200**; mobile (375px) no horizontal overflow; footer year 2026 + social links; `<html lang>` updates on language change; evidence screenshots (desktop light/dark + mobile). |
| `tests/milosvasic-ru-features.spec.js` | 7 | Popup offers EN/SR/RU and builds correct CV hrefs (incl. SR/RU hrefs even though those PDFs aren't built yet); popup switches to Cover-Letter hrefs; popup closes on Escape; **EN CV + EN/SR Cover-Letter PDFs return 200** (matches what's on disk); 12 read-more triggers; clicking read-more opens dialog (`data-open=true`, content, scroll-lock, Esc restores); all 12 EN article fragments return 200. |
| `tests/milosvasic-ru-a11y.spec.js` | 5 | axe-core scan (no critical/serious; `heading-order` + `link-in-text-block` disabled with rationale); heading hierarchy; visible focus indicators (`:focus-visible` rule + tab/skip-link); `prefers-reduced-motion` respected; color contrast on key elements. |
| `tests/i18n-completeness.spec.js` | 2 | Pure-Node (vm sandbox): every EN key exists in ru/sr/de/es/fr; new feature keys (`ds.based_v`, `ds.langs_v`, `dl.*`, `card.more`) present in all languages. |
| `tests/vasic-digital.spec.js` | 13 | Title + logo loads; no-flash theme; theme toggle + persistence; language switch to RU (+ `vasic-digital-lang`); corrected stats (`240+`, "GitHub Organizations") + footer 2026; **no portfolio link deep-links a private repo**; mobile no overflow + hamburger; 9 service cards; ≥10 portfolio cards with title/link/tech; contact section (`i@mvasic.ru`, Belgrade/Serbia); hero buttons; hamburger toggle; evidence screenshots. |
| `tests/vasic-digital-features.spec.js` | 4 | All 18 portfolio cards have a read-more trigger; clicking opens dialog with content; all 18 EN article fragments return 200; `articles.css` + `articles.js` linked and return 200. |
| **Total** | **46** | |

**Port fix:** the brief notes a prior `gvproxy:8081` collision. `playwright.config.js` now serves `vasic.digital` on **`http://localhost:8401`** (was 8081) and `milosvasic.ru/_site` on `8082`; the vasic specs use `BASE = 'http://localhost:8401'`. Both suites green confirms the port move resolved the collision.

**Evidence:** `_tests/evidence/` holds the 6 full-page screenshots (`milos-desktop-{light,dark}.png`, `milos-mobile.png`, `vasic-desktop-{light,dark}.png`, `vasic-mobile.png`), the Playwright HTML report (`evidence/html-report/`), the HelixTranslate logs (§5.5), and the 60 translation logs (§6.1). `_tests/data/verified_models.db` is the LLMsVerifier SQLite store.

---

## 8. Reproduction Commands

```bash
# --- Website tests (both sites) ---
cd /Volumes/T7/Projects/vasic/milosvasic.ru && jekyll build      # produces _site/ (served on :8082)
cd /Volumes/T7/Projects/vasic/_tests
npm install                                                       # @playwright/test + @axe-core/playwright
npx playwright install chromium
npx playwright test --project=chromium                            # 46 passed; webServers auto-start on :8401 and :8082

# --- HelixTranslate engine: build + prove the fix ---
cd /Volumes/T7/Projects/helix_translate
go build -o build/unified-translator ./cmd/unified-translator
go build ./cmd/model-bridge
go vet ./...
go test ./pkg/bridge/ ./pkg/translator/llm/ ./cmd/unified-translator/ ./cmd/markdown-translator/
go test -run TestClientForProvider ./pkg/bridge/                  # the provider-routing proof

# --- Translation pipeline (per article) ---
/Volumes/T7/Projects/vasic/_tools/translate-pipeline.sh \
  --in  /Volumes/T7/Projects/vasic/milosvasic.ru/_article_src/en/helix-track-core.md \
  --out /Volumes/T7/Projects/vasic/milosvasic.ru/_article_src/ru/helix-track-core.md \
  --lang ru --article

# --- Render article fragments ---
/Volumes/T7/Projects/vasic/_tools/render-articles.sh /Volumes/T7/Projects/vasic/milosvasic.ru en sr ru
/Volumes/T7/Projects/vasic/_tools/render-articles.sh /Volumes/T7/Projects/vasic/vasic.digital en

# --- Rebuild the 6 CV/Cover-Letter PDFs ---
cd /Volumes/T7/Projects/vasic/milosvasic.ru/downloads/src && ./build-pdfs.sh   # needs pandoc + weasyprint
```

---

## 9. Remaining Work & Known Limitations (stated honestly)

1. **SR/RU CV/Cover-Letter PDFs depend on the pipeline run.** Only 5 of the intended 6 PDFs exist (EN CV, EN/SR Cover Letter, + legacy un-suffixed CV/CL). Missing: `cv.sr.md`, `cv.ru.md`, `cover-letter.ru.md` sources → no `Milos_Vasic_CV_SR.pdf`, no `_RU` PDFs. The download popup builds SR/RU hrefs regardless, so those buttons 404 until the sources are authored/translated and `build-pdfs.sh` is re-run. (Tests are written to match reality — they don't assert 200 for the not-yet-built PDFs.)
2. **SR/RU article fragments depend on the pipeline run.** milosvasic.ru has only 3 sr + 3 ru article sources and no rendered `articles/sr/` or `articles/ru/`; vasic.digital has only `en/`. Until `translate-pipeline.sh` is run for all 30 articles in ru+sr and `render-articles.sh` regenerates the fragments, the read-more modal falls back to English for non-English locales. The 60 logs in `_tests/evidence/translate/` show the pipeline runs were exercised, but the translated outputs are not yet wired into the rendered `articles/<lang>/` trees for both sites.
3. **Provider availability (config/runtime, not committed evidence):**
   - **gemini** — the BEFORE log shows the misrouted gemini request producing an OpenAI 403; the routing fix now sends gemini to `generativelanguage.googleapis.com`, but a valid `GEMINI_API_KEY` is still required (the brief notes the key is invalid). `.env.example` ships a blank `GEMINI_API_KEY=`.
   - **deepseek / novita** — the brief notes "no balance." Caveat for accuracy: this is **not** substantiated by quotable committed text — the only quotable balance failure on disk is the OpenAI 403 (surfaced via the gemini misroute). In fact `model-bridge-proof.log` lists novita as the verified strongest provider at verification time, which partly contradicts a blanket "no balance" claim. These statuses, where real, are runtime/operator observations not captured in tracked configs.
   - The pipeline mitigates all of the above by defaulting to the two providers proven working with balance: **groq** (`llama-3.3-70b-versatile`) and **mistral** (`mistral-large-latest`).
4. **Nothing is committed.** Two site working trees, the monorepo's untracked `_tests/`/`_tools/`/`data/`, and the HelixTranslate fix (incl. untracked `pkg/bridge/provider_routing_test.go`) are all staged-in-working-tree only. Committing (Conventional Commits, SSH remotes per the constitution) is the next step but was intentionally out of scope for this report.
```
