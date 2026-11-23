# milosvasic.ru Career Platform v2 — Master Plan

Status: **planning complete, implementation starting**
Date: 2026-11-19
Owner: operator (Miloš Vasić) · executor: agent fleet
Supersedes: none (new workstream)
Scope: `milosvasic.ru` (Jekyll submodule) + `_tools/`, `_content*`, `_tests/` (umbrella)

> **Status note 2026-11-23.** Implementation is largely done; see `docs/STATE-MILESTONE.md` for the measured state and the pending list. The locale code for Chinese is `zh`. The 300-PDF rebuild (10 areas x 15 languages x 2 kinds) was in progress and unverified at this date.

---

## 1. The problem in one paragraph

`milosvasic.ru` today publishes **15 languages × 3 career documents** (CV, Cover Letter,
Portfolio) as **plain, unauthenticated PDFs** under `downloads/`, built by a
Markdown → pandoc → WeasyPrint pipeline (`_tools/pdf/build-pdfs.sh`) that has no
notion of a *position*, no LaTeX, no ATS contract, and no gating. The site itself
is a single-page CV-shaped brochure: it is organized by *artifact type* (work,
experience, skills), not by *technology area*, so a recruiter hiring for Android
TV has to read a generalist CV and infer fit. Translations exist but were produced
by a batch Mistral/Groq loop whose review standard predates the current content.

We are replacing all of that with:

1. **A career content model** — one structured, evidence-backed source of truth.
2. **A LaTeX document engine** — per-area "recipes" that switch sections on/off,
   emitting PDF + HTML + Markdown + DOCX + JSON Resume from one model.
3. **A cryptographic vault + admin console** — CV/Cover Letter are no longer
   public files at all; they are AES-256-GCM bundles unlocked in the browser by
   an admin passphrase.
4. **A technology-organized site** — `/expertise/<area>/` × 10 areas × 15
   languages, with heavy, machine-verified SEO.
5. **A new visual system** — "Aurora Atlas": colorful, per-area accents, spring
   motion, View Transitions, WCAG-AA clean.
6. **A fully re-created translation set** — every locale regenerated against the
   new content with deterministic validators and an independent review pass.

Everything above is gated by machine-checkable evidence. No claim ships without a
receipt.

---

## 2. Measured environment (facts this plan depends on)

Re-measured 2026-11-19 on the development host. Every item is re-derivable; none
is an assumption.

| Capability | State | Consequence |
|---|---|---|
| `xelatex`, `pdflatex`, `lualatex`, `latexmk` | present (`/usr/bin`) | LaTeX engine available |
| `moderncv.cls`, `fontspec`, `etoolbox`, `geometry`, `titlesec`, `enumitem`, `hyperref`, `xcolor`, `tabularx`, `fancyhdr`, `lastpage`, `microtype`, `csquotes`, `booktabs`, `xltabular` | present | custom class is buildable |
| `bidi.sty` | **MISSING** | **RTL LaTeX is not ATS-safe today** (proved below) |
| `texlive-lang-arabic` (provides `bidi`) | available via apt, **needs sudo** (interactive auth refused) | operator action required to enable LaTeX-RTL |
| `pandoc` 3.11 | present | DOCX + Markdown exports |
| `weasyprint` 67.0 | present | HTML→PDF, and the RTL renderer |
| `pdftotext`, `pdfinfo`, `pdffonts`, `pdftoppm`, `pdfimages` | present | ATS extraction + visual evidence |
| `qpdf`, `tectonic` | missing | not required by this plan |
| System fonts | Noto Sans Arabic, Noto Naskh Arabic, Noto Sans CJK family, DejaVu, Liberation | all 15 locales covered |
| `opencode` CLI v2.3.2 | present | headless model calls for translation |
| `scillm` (127.0.0.1:4001) | **down** | HelixTranslate path unavailable |
| Ollama | only `qwen2.5:3b-instruct` + embedders | not fit for native-quality translation |
| Disk free | 89 GB (95% used) | keep artifacts in `~/.cache/claude-tmp/opencode` |
| RAM / cores | 22 GB available / 16 | parallel builds and test shards OK |

### 2.1 The RTL finding, recorded because it changes the design

A minimal XeLaTeX document using the e-TeX direction primitives
(`\TeXXeTstate=1`, `\beginR`) compiles (rc 0) and embeds Noto Naskh Arabic, but
`pdftotext` returns **presentation-form glyphs** (`ﻣﺮﺣﺒﺎ`) and **mojibake for the
mixed Latin line** (`�����: �� ��������`). That is exactly the ATS failure mode we
must never ship. `arabxetex.sty` is present but aborts: `File 'bidi.sty' not found`.

**Decision.** LaTeX remains the canonical engine for the 13 LTR locales. For
`ar` and `fa`, the *same resolved document model* is rendered by WeasyPrint
(native Unicode bidi via fribidi/Pango), which produces correct shaping and
correct `pdftotext` order. The pipeline records which renderer produced each
artifact in its manifest, and it **automatically upgrades ar/fa to LaTeX** the
moment `bidi.sty` is present. Both renderers are covered by the same ATS gate, so
the split is verified rather than asserted.

---

## 3. Decisions already taken (operator-confirmed)

| # | Decision | Choice |
|---|---|---|
| D1 | Admin gating on a static host | **Encrypted vault + passphrase admin console** |
| D2 | Area matrix | **10 areas × 15 languages** |
| D3 | Release authority | **Commit + push + tag via the project deploy path** |
| D4 | LaTeX vs HTML for RTL | LaTeX for 13 LTR; WeasyPrint for `ar`/`fa`, auto-upgrading |
| D5 | Translation engine | Agent fleet (headless `opencode` / subagents) + deterministic validators + independent reviewer model |
| D6 | Plaintext policy | No plaintext CV/CL artifact is ever written under `milosvasic.ru/`; builds write plaintext only to a git-ignored local directory |

### 3.1 The 10 areas

`ai-engineering`, `android`, `android-tv`, `android-aosp`, `flutter`,
`react-native`, `mobile`, `go`, `web-frontend`, `desktop`.

Each area is a **recipe**: which sections exist, which skills are emphasized,
which projects appear and in what order, which ATS keywords are mandatory, and
which cover-letter angle is used. Areas are data, never code branches.

### 3.2 The 15 locales

`en` (master) · `ru` · `sr` · `de` · `es` · `fr` · `be` · `zh` · `kk` · `hi` ·
`ja` · `ko` · `ar` · `tr` · `fa`.

RTL: `ar`, `fa`. Cyrillic: `ru`, `sr`, `be`, `kk`. CJK: `zh`, `ja`, `ko`.
Devanagari: `hi`.

---

## 4. Target architecture

```
_content/career/                        ← NEW: single source of truth
  profile.yaml                          identity, contact, experience, skills,
                                        projects, metrics, education, languages
  areas/<area>.yaml                     ×10 recipes
  locales/<lang>.yaml                   ×15 translated string tables
  schema/career.schema.json             JSON Schema (Draft 2020-12)

_tools/career/                          ← NEW: Go document engine
  cmd/careerdoc/main.go                 build / verify / vault / manifest
  internal/model/                       load → validate → resolve(locale, recipe)
  internal/render/latex/                .tex emitter + class + per-lang font map
  internal/render/html/                 semantic HTML + print CSS
  internal/render/markdown/             Markdown
  internal/render/docx/                 pandoc bridge (Markdown → DOCX)
  internal/render/resumejson/           JSON Resume v1.0.0
  internal/render/coverletter/          letter template over the same model
  internal/vault/                       PBKDF2-SHA256 + AES-256-GCM + manifest
  internal/ats/                         extraction oracle (pdftotext/pdfinfo/pdffonts)
  latex/miloscv.cls                     ATS CV class (toggles, single column)
  latex/miloscover.cls                  cover-letter class
  latex/lang/<lang>.tex                 font + hyphenation + direction config

milosvasic.ru/
  _data/career/                         generated site data (areas, metrics, i18n)
  _layouts/                             default, expertise, area, admin, doc
  expertise/index.html                  technology hub
  expertise/<area>/index.html           ×10 (×15 localized dirs)
  admin/index.html                      vault console (noindex, unlinked)
  downloads/vault/                      encrypted bundles + manifest.json ONLY
  downloads/Portfolio_<LANG>.pdf        portfolio stays public (not career docs)

_tools/translate/v2/                    ← NEW: translation pipeline
  extract.mjs                           build unit inventory
  translate.mjs                         model-driven translation (glossary sentinels)
  review.mjs                            independent reviewer model
  validate.mjs                          deterministic locale validators
  style/<lang>.md                       native style guide per locale

_tests/
  tests/career-docs.spec.js             ATS + format matrix (10×15×5)
  tests/vault-security.spec.js          no plaintext, crypto, tamper
  tests/admin-console.spec.js           browser unlock flow
  tests/seo-deep.spec.js                JSON-LD, hreflang, sitemap
  tests/i18n-v2.spec.js                 script/leak/completeness
  tests/design-v2.spec.js               visual + a11y + motion
  evidence/career-v2/                   machine-readable receipts
```

### 4.1 Data flow

```
profile.yaml ─┐
areas/*.yaml ─┼→ validate(schema) → resolve(locale, recipe) → DocumentModel
locales/*.yaml┘                                                   │
                                                                  ├→ LaTeX  → xelatex  → PDF   (LTR)
                                                                  ├→ HTML   → WeasyPrint→ PDF   (ar/fa)
                                                                  ├→ HTML   → file
                                                                  ├→ Markdown → file
                                                                  ├→ Markdown → pandoc → DOCX
                                                                  └→ JSON Resume
                                                                          │
                                                          AES-256-GCM vault → downloads/vault/
                                                                          │
                                                          /admin/ WebCrypto unlock
```

The **DocumentModel** is the contract. Every renderer is a pure function of it.
No renderer may read `profile.yaml` directly, and no content may live in a
renderer. This is what makes the 750-artifact matrix (10 areas × 15 langs × 5
formats) verifiable instead of 750 special cases.

### 4.2 Vault format (normative)

- Bundle = `TAR` of `{cv.pdf, cv.html, cv.md, cv.docx, cv.json}` + `bundle.json`
  (per-file sha256, byte sizes, area, lang, renderer, build id).
- Encryption: `AES-256-GCM`, 96-bit random IV, AAD = `"milosvasic-career-v2|<area>|<lang>"`.
- KDF: `PBKDF2-HMAC-SHA256`, 600 000 iterations, 32-byte key, 16-byte random salt per bundle.
- Ciphertext file: `downloads/vault/<area>/<lang>.mvb`.
- Public manifest: `downloads/vault/manifest.json` — area ids, locale codes, per-bundle
  salt, iv, ciphertext sha256, ciphertext size, plaintext size, format list, build id.
  **No plaintext bytes, no plaintext hashes** (a hash of the plaintext would be an
  offline confirmation oracle).
- Passphrase source: `CV_VAULT_PASSPHRASE` env, else `_secure/cv-vault.passphrase`
  (0600, git-ignored). Release builds **fail closed** when neither exists.
- The passphrase is never logged, never printed, never committed, never embedded.

**Honest boundary.** A static site has no identity provider. "Admin-only" here means
"possession of a high-entropy passphrase", enforced by real cryptography, not by an
`if` in JavaScript. This is stated on the console page and in the security doc. It is
not a substitute for server-side auth, and it is not claimed to be one.

---

## 5. Phases, deliverables, and gates

Every gate is three-valued: **0 pass · 1 finding · 2 could-not-determine**, and a
2 is never a pass. Each gate writes `_tests/evidence/career-v2/<gate>.json`.

### Phase 0 — Baseline & safety (blocking)

| Deliverable | Gate |
|---|---|
| Baseline evidence snapshot of the current site (page count, test results, PDF inventory, sitemap size) | `evidence/baseline.json` exists and is reproducible |
| Hardlink backup of `milosvasic.ru` + `_content*` before mutation | `_backups/2026-11-19/` present, `cmp` spot-check |
| Feature branches in both repos | `git rev-parse --abbrev-ref HEAD` = `feat/career-platform-v2` |
| Vault passphrase provisioned | `_secure/cv-vault.passphrase` exists, mode 600, never tracked |

### Phase 1 — Career content model

| Deliverable | Gate |
|---|---|
| `profile.yaml` covering every fact the current CV asserts, each with a `source:` pointer | schema valid; zero unsourced bullets |
| 10 area recipes | schema valid; each declares ≥1 unique ATS keyword set |
| `career.schema.json` | `ajv`-clean on all inputs |
| Resolver unit tests (Go) | `go test ./...` green; table-driven per recipe |

### Phase 2 — Document engine + vault

| Deliverable | Gate |
|---|---|
| `miloscv.cls` / `miloscover.cls` | compile on all 13 LTR locales |
| 5 renderers | golden-file tests per renderer |
| 750 artifacts built | `careerdoc build --all` rc 0, manifest complete |
| ATS oracle | for every artifact: required tokens present, no U+FFFD, no presentation forms, fonts embedded |
| Vault | decrypt round-trip per bundle; wrong passphrase fails; 1-bit tamper fails |
| Paired mutation | `prove-career-pipeline.sh` breaks a recipe → build fails; corrupts a bundle → decrypt fails |

### Phase 3 — Admin console

| Deliverable | Gate |
|---|---|
| `/admin/` page | Playwright: wrong passphrase → error; correct → 5 download buttons |
| Non-discovery | `noindex`, absent from sitemap, `Disallow: /admin/` |
| No plaintext | recursive scan of `milosvasic.ru/` finds zero career plaintext artifacts |

### Phase 4 — Design system v2 ("Aurora Atlas")

| Deliverable | Gate |
|---|---|
| Tokens + components + motion | visual regression baselines (light/dark × desktop/mobile) |
| Motion | `prefers-reduced-motion` disables all non-essential motion; no CLS regression |
| Accessibility | axe: zero critical/serious on all page types |
| Performance | LCP < 2.0 s, CLS < 0.1, INP < 200 ms on the local harness |

### Phase 5 — Pages & SEO

| Deliverable | Gate |
|---|---|
| `/expertise/` hub + 10 area pages | every page renders in 15 locales |
| JSON-LD graph | parses; required fields present; no invalid `@id` references |
| hreflang reciprocity | every pair is mutual; `x-default` present |
| sitemap | superset of every indexable page; `lastmod` from git; `/admin/` absent |
| OG images | 10 area cards generated deterministically, correct dimensions |

### Phase 6 — EN content freeze

Freeze `_content/**` (EN) and record sha256 of every source file. Translation
never starts against a moving source.

### Phase 7 — Translation (parallel, 14 locales)

| Deliverable | Gate |
|---|---|
| Every `_content_<lang>/**` regenerated | 38/38 files per locale present |
| Deterministic validators | script/charset, glossary preservation, frontmatter byte-identity, length ratio, no English leakage, no truncation, number/date preservation |
| Independent review | reviewer model ≠ translator model; rubric JSON per file; PASS required |
| Native spot-audit | 3 files per locale read by a second model against `style/<lang>.md` |

### Phase 8 — Full test matrix

All existing suites green plus the five new specs. `PREPUSH_STRICT=1` clean.

### Phase 9 — Release

| Deliverable | Gate |
|---|---|
| `CHANGELOG.md`, semver `v2.0.0` | tag exists in submodule and umbrella gitlink bump |
| Push + Pages publish | live `https://milosvasic.ru/` returns 200 with the new build id |
| Live verification | live specs green; admin console unlock verified against the live bundle |
| Post-deploy evidence | `evidence/release-v2.json` with live URLs, hashes, timestamps |

### Phase 10 — `job_seeker` (only after Phase 9 closes)

Out of scope for this plan; its own plan follows. The LaTeX engine, the vault, and
the career content model are designed to be *reused* there (local generation,
ATS scoring, job-API matching), so nothing built here is throwaway.

---

## 6. Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `bidi.sty` unavailable → RTL LaTeX blocked | certain | medium | WeasyPrint RTL renderer, same model, auto-upgrade path, documented |
| 750 artifacts × 15 locales build time | high | medium | parallel builds (16 cores), incremental by content hash, `-j` shards |
| Translation volume (532 files) exceeds session budget | high | high | phased waves per locale; resumable unit inventory; deterministic resume |
| Design regression breaks existing Playwright contracts | medium | high | inventory every asserted selector first; keep `.mvx-*` contracts |
| Pages publish breaks | low | critical | never touch `pages.yml`; build through `site-build`; verify live |
| Plaintext leak into the public tree | medium | critical | vault test scans the whole tree; `.gitignore` entries; pre-push gate |
| Passphrase loss | medium | high | operator copies it to a password manager at Phase 0; backup note in `_secure/README` |
| Content-boundary gate stays red | certain | none | pre-existing and by design; do not add allow-list entries |

---

## 7. Definition of done (the whole workstream)

1. `milosvasic.ru` is deployed and live at `v2.0.0` with the new design, the
   expertise hub, and 15 locales.
2. No public plaintext CV or Cover Letter exists anywhere in the published tree;
   the vault is the only carrier, and it is proven decryptable with the operator
   passphrase and unreadable without it.
3. All 750 career artifacts exist, and each passes the ATS extraction oracle.
4. Every locale passes the deterministic validator suite and the independent
   review, with receipts on disk.
5. Every existing test suite plus the five new ones is green, deterministically,
   from a clean checkout.
6. `CHANGELOG.md`, tag, and post-deploy evidence exist and match the live site.
7. `CONTINUATION.md` is updated; the umbrella gitlink bump is committed.

---

## 8. Explicit non-goals

- No server, no database, no runtime auth. The site stays static on GitHub Pages.
- No change to `milosvasic.ru/.github/workflows/pages.yml`.
- No new fonts downloaded at runtime (only the vendored families + system Noto).
- No fabricated experience, dates, employers, or metrics. Every bullet traces to a
  source path recorded in `profile.yaml`.
- No allow-list entries added to `scripts/verify-content-boundary.sh`.
- No force-push, ever.
