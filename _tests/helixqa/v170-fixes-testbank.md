# HelixQA Challenge Bank — v1.7.0 Six-Fix Regression

A HelixQA-style **Challenge bank** that pins the SIX fixes shipped in **v1.7.0** of
`vasic.digital` and `milosvasic.ru` against silent regression. It is the **spec**
(what is checked, thresholds, evidence schema, golden-good / golden-bad mutations,
executable-check column); the **runner** is the executable Playwright suite
[`../tests/v170-fixes.spec.js`](../tests/v170-fixes.spec.js), wired into
[`../playwright.live.config.js`](../playwright.live.config.js) and run **read-only
against LIVE production**:

```
cd _tests && npx playwright test v170-fixes.spec.js --config=playwright.live.config.js
```

**Anti-bluff contract (§11.4.5 / §11.4.69 / §11.4.170):** every PASS is backed by a
**captured, machine-readable POSITIVE measurement** (the assertion's measured value,
not merely "no error"). Golden-BAD mutations (the paired §1.1 mutation, HelixQA
convention) prove the check actually bites: each is the concrete pre-fix state that
the assertion MUST reject. A structural/heuristic check never substitutes for the
rendered-pixel / extracted-text measurement it stands in for.

**Localization mandate:** Challenges **C62 / C63 / C65** enforce Helix Constitution
**§11.4.237** (full localization — no English leakage into a localized surface, in
either HTML prose or generated PDFs).

`feature_class = v170_regression`. Evidence bundle → `_tests/evidence/regression-v1.7.0/`.

**Check class legend**
- **RUN** — executed by `v170-fixes.spec.js` against live now; real pass/fail, gating.
- **AUDITOR** — needs a human/agent rendered-pixel judgement beyond the automated proxy (none gate here; listed where a check is a proxy for a visual property).
- **SPEC** — declared threshold/mutation, documented here, enforced by the RUN check.

**Live baseline (measured on the green run captured in `evidence/regression-v1.7.0/run.txt`): 34/34 PASS.**

---

## Challenge index

| ID | Fix | Surface | Gate | Class | Live measured |
|----|-----|---------|------|-------|---------------|
| C62 | #62 Serbian Cyrillic everywhere | /sr/ HTML prose + sr PDFs | Cyrillic ratio + no-EN-leak | RUN | prose cyr milos 0.732 / vasic 0.737; CV_SR 0.75; EN-stopwords 0–1 |
| C63 | #63 Language switcher switches | product + portfolio, both sites | 15-path map + click navigates+relangs | RUN | 15/15 paths, all targets 200; click → /de/,/ru/ relang |
| C64 | #64 Tall modal/dialog scrolls | download-CV list; overlay CSS | overflow-y + bounded max-height + reachable | RUN | dl-langs scrollHeight 910 > clientHeight 404; last row reachable |
| C65 | #65 PDFs fully localized | CV + Portfolio, sr/de/ar/zh | 0 EN chrome + correct script | RUN | 0 EN-chrome in 22 PDFs; sr 0.75–0.80 / ar 0.74–0.80 / zh 0.47–0.55 / de lat 1.00 |
| C66 | #66 content never flush to edge | both home pages @375/1280 | safe-area gutters + padding ≥16px | RUN | vasic 20px@375 / 48px@1280; milos 24px; CSS env(safe-area-inset-*) present |
| CRS | re-style intact | served brand CSS | display font present | RUN | vasic "Bricolage" ×8; milos "Anton" ×3 |

Overall verdict = PASS only if **all** Challenges PASS (§11.4.134 — loop to the
responsible specialist on any FAIL; never relax the assertion).

---

## C62 — #62 Serbian Cyrillic everywhere (§11.4.237)

**Claim under guard.** The `sr` locale is genuine Serbian **Cyrillic**, not English
(or Latin-transliterated) content mislabeled `lang="sr"` — on the rendered home page
AND in the downloadable Serbian PDFs.

**Assertions (RUN).**
1. `<html lang="sr">` on `/sr/` of both sites.
2. Body prose (script/style/code stripped, URLs & bare domains removed) **Cyrillic
   ratio ≥ 0.70** — `cyrillicLetters / allLetters`.
3. **English-sentence leakage ≤ 5** stopword hits (`the|and|with|from|…|architecture`
   as whole words). Short glossary/brand Latin tokens (Anthropic, OpenAI, GitHub,
   "JSON-lines over stdio") are allowed — hence a small tolerance, not a hard 0.
4. `downloads/Milos_Vasic_CV_SR.pdf` `pdftotext` **Cyrillic ratio ≥ 0.60** and 0 EN
   chrome strings.

**golden-GOOD (current live = PASS).** milos prose 0.732, vasic prose 0.737 Cyrillic;
EN-stopword hits 0 (milos) / 1 (vasic — "over" inside the glossary phrase "JSON-lines
over stdio"); CV_SR.pdf Cyrillic 0.75.

**golden-BAD (pre-fix state — MUST FAIL).** The `/sr/` page serving the English hero
prose under `lang="sr"` → Cyrillic ratio ≈ 0.0 and EN-stopword hits in the dozens
(EN home measures 104–135). Either violation flips C62 to FAIL.

**Evidence schema.**
```json
{ "challenge": "C62", "target": "milosvasic.ru/sr/", "verdict": "PASS",
  "measurements": { "htmlLang": "sr", "cyrillicRatio": 0.732, "threshold": 0.70,
                    "letters": 5452, "enStopwordHits": 0, "enStopwordTolerance": 5 } }
{ "challenge": "C62", "target": "downloads/Milos_Vasic_CV_SR.pdf", "verdict": "PASS",
  "measurements": { "cyrillicRatio": 0.75, "threshold": 0.60, "enChromeHits": 0 } }
```

---

## C63 — #63 Language switcher actually switches (§11.4.237)

**Claim under guard.** The 15-language switcher on product and portfolio pages both
(a) advertises a complete, resolvable page-path map and (b) actually navigates the
browser to the localized document and re-langs it when clicked — not a dead control.

**Assertions (RUN).**
1. Served HTML embeds the page-path global (`OD_PAGE` on vasic, `MV_PAGE` on milos)
   with **exactly 15** `paths` keys, including `en, sr, de, ru, ar, zh`.
2. **Every** one of the 15 localized product targets resolves **200** (no dead entry).
3. Portfolio served HTML likewise carries the 15-path global.
4. **Interactive:** on product (→`de`) and portfolio (→`ru`), for BOTH sites, opening
   the switcher and clicking the option **navigates** the URL to the `/<code>/` path
   (`waitForURL`) and the new document reports `<html lang="<code>">`.

**golden-GOOD (current live = PASS).** 15/15 path keys on both page types, both sites;
all 15 product targets 200; clicking `de`/`ru` lands at `/products/de/…`,
`/portfolio/ru/` etc. with `<html lang>` updated.

**golden-BAD (pre-fix state — MUST FAIL).** A switcher whose map is missing/partial
(<15 keys), points at a 404 target, or whose click does not change the document
language (stuck on `lang="en"` / URL unchanged). Any flips C63 to FAIL.

**Evidence schema.**
```json
{ "challenge": "C63", "target": "vasic.digital/products/helixtrack.html",
  "verdict": "PASS",
  "measurements": { "global": "OD_PAGE", "pathCount": 15, "targets200": 15,
                    "click": { "code": "de", "urlContains": "/de/", "htmlLang": "de" } } }
```

---

## C64 — #64 Tall modal / dialog scrolls

**Claim under guard.** A floating surface taller than the viewport (the 15-row
download-CV language list; any overlay dialog/menu) **scrolls its own body** rather
than clipping content off-screen — so the last row is always reachable.

**Assertions.**
- **RUN (CSS).** milos `assets/css/style.css`: `.dl-langs { overflow-y:auto }` AND
  `.dl-card { max-height: min(…) }` (bounded). vasic `assets/od/overlays.css`:
  `.od-dialog__panel { max-height: min(…); overflow-y:auto }` AND the floating-menu
  group (`.od-menu/.od-dropdown__menu/.od-popover/.od-lang__menu`) bounded + scrolling.
- **RUN (rendered, proxy for AUDITOR).** At **380×640**, open the milos CV download
  modal: it offers 15 `.dl-lang` rows, `.dl-langs` computes `overflow-y:auto` and
  `scrollHeight > clientHeight`, and the **last** row becomes fully visible after
  `scrollIntoViewIfNeeded()`.
- **AUDITOR.** Visual confirmation on a real notched device that no row is clipped
  behind the URL bar (the automated `dvh`+scroll check is the proxy; not gated).

**golden-GOOD (current live = PASS).** `.dl-langs` scrollHeight 910 > clientHeight 404,
`overflow-y:auto`; last language row reachable by scroll. CSS declarations present in
both served stylesheets.

**golden-BAD (pre-fix state — MUST FAIL).** `.dl-langs` without `overflow-y` / `.dl-card`
without a bounded `max-height` (list grows past the viewport, last rows unreachable) →
rendered `scrollHeight ≤ clientHeight` or last row not reachable; and the CSS grep
misses the declarations. Either flips C64 to FAIL.

**Evidence schema.**
```json
{ "challenge": "C64", "target": "milosvasic.ru CV modal @380x640", "verdict": "PASS",
  "measurements": { "rows": 15, "overflowY": "auto", "scrollHeight": 910,
                    "clientHeight": 404, "lastRowReachable": true },
  "css": { "dlLangsOverflowY": true, "dlCardMaxHeight": true,
           "odDialogPanelBounded": true } }
```

---

## C65 — #65 PDFs fully localized (§11.4.237)

**Claim under guard.** For every sampled locale the downloadable CV and Portfolio PDFs
are **fully translated** — zero English UI-chrome leakage and the body text is in the
locale's target script (not English content with a translated title page).

**Assertions (RUN).** For `sr, de, ar, zh` × {milos CV, milos Portfolio, vasic Portfolio}
(11 docs × ~2 checks): `pdftotext` yields non-trivial text; **0** occurrences of any EN
chrome string `["Selected architecture","Curriculum Vitae","Cover Letter","Engineering
since","Repository fleet"]`; and the target-script gate:
- `sr` → Cyrillic ratio **≥ 0.60**
- `ar` → Arabic ratio **≥ 0.60**
- `zh` → Han ratio **≥ 0.30** (CJK is orthographically compact — a lower floor is correct)
- `de` → Latin ratio **≥ 0.80** AND Cyrillic/Arabic/Han each **< 0.02** (Latin-script
  locale: prove no foreign-script contamination rather than a positive non-Latin ratio).

**golden-GOOD (current live = PASS).** Across all 12 sampled PDFs: 0 EN-chrome hits;
measured script ratios sr 0.75–0.80, ar 0.74–0.80, zh 0.47–0.55, de Latin 1.00.

**golden-BAD (pre-fix state — MUST FAIL).** A PDF that is English content mislabeled
by locale (e.g. the removed "German" PDF that was English) → EN chrome strings present
and/or target-script ratio below floor (de would show EN chrome; sr/ar/zh would show
Latin-dominant text). Any flips C65 to FAIL.

**Evidence schema.**
```json
{ "challenge": "C65", "target": "vasic.digital/downloads/Portfolio_AR.pdf",
  "verdict": "PASS",
  "measurements": { "lang": "ar", "enChromeHits": 0, "arabicRatio": 0.80,
                    "threshold": 0.60 } }
{ "challenge": "C65", "target": "milosvasic.ru/downloads/Milos_Vasic_CV_DE.pdf",
  "verdict": "PASS",
  "measurements": { "lang": "de", "enChromeHits": 0, "latinRatio": 1.00,
                    "cyrillic": 0.0, "arabic": 0.0, "han": 0.0 } }
```

---

## C66 — #66 Content never flush to the viewport edge

**Claim under guard.** Page content keeps a real horizontal gutter at every viewport,
and the gutter is **notch/safe-area aware** so content clears rounded corners / the
notch in landscape.

**Assertions.**
- **RUN (CSS).** Served brand CSS declares `env(safe-area-inset-left)` and
  `env(safe-area-inset-right)` (vasic `assets/od/vasic-digital.css`; milos
  `assets/css/style.css`).
- **RUN (rendered).** On both home pages at **375** and **1280**, the main content
  bands (vasic `.od-hero/.od-section/.od-header`; milos `.wrap`) compute
  `padding-inline ≥ 16px` on both sides — never flush to the edge.
- **AUDITOR.** On a physical notched device in landscape, confirm no glyph sits under
  the notch (the `env()` + padding check is the proxy; not gated).

**golden-GOOD (current live = PASS).** vasic bands 20px @375 / 48px @1280; milos `.wrap`
24px at both; both stylesheets carry the `env(safe-area-inset-*)` gutter formula
(`max(clamp(…), env(safe-area-inset-left), env(safe-area-inset-right))`).

**golden-BAD (pre-fix state — MUST FAIL).** A band with `padding-inline:0` (text flush
to the edge) → measured padding 0 < 16; or brand CSS with the `env(safe-area-inset-*)`
gutter removed → CSS grep misses it. Either flips C66 to FAIL.

**Evidence schema.**
```json
{ "challenge": "C66", "target": "vasic.digital home", "verdict": "PASS",
  "measurements": { "cssHasSafeAreaInset": true,
                    "pads": [ { "vw": 375, "pl": 20, "pr": 20 },
                              { "vw": 1280, "pl": 48, "pr": 48 } ], "min": 16 } }
```

---

## CRS — Re-style intact (display font not reverted)

**Claim under guard.** The v1.6.1 display re-style survives the v1.7.0 localization work.

**Assertions (RUN).** vasic served `assets/od/vasic-digital.css` contains **"Bricolage"**;
milos served `assets/css/style.css` contains **"Anton"** (both 200).

**golden-GOOD (current live = PASS).** "Bricolage" present ×8 in vasic CSS; "Anton" ×3
in milos CSS.

**golden-BAD — MUST FAIL.** Served CSS reverting to a default system/sans display face
(no "Bricolage" / "Anton" token) → substring absent → CRS FAIL.

**Evidence schema.**
```json
{ "challenge": "CRS", "target": "vasic.digital css", "verdict": "PASS",
  "measurements": { "font": "Bricolage", "presentInServedCss": true } }
```

---

## Evidence bundle layout

```
_tests/evidence/regression-v1.7.0/
└── run.txt          # captured `npx playwright test v170-fixes.spec.js --config=…` — the green run (34/34)
```

## Status
Executable now — all six Challenges are RUN checks in `v170-fixes.spec.js` and pass
green against live production (34/34, captured in `run.txt`). AUDITOR rows (C64/C66
physical-device notch confirmation) are documented as proxied-but-not-gated; the
automated `dvh`/scroll and `env()`/padding checks stand in for them. Any future FAIL is
a real regression — fix the site and re-green; never weaken an assertion here.
