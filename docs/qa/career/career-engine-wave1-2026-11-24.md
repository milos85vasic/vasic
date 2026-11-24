# Career engine, wave 1 of the [UMBRELLA] remediation items (VSC-426..VSC-430)

| | |
|---|---|
| **Document** | `docs/qa/career/career-engine-wave1-2026-11-24.md` |
| **Date** | 2026-11-24 |
| **Source research** | `job_seeker` `docs/research/protocols/11-ats-gap-analysis.md`, `12-failure-modes-and-guards.md`, `13-remediation-backlog.md` (items T162, T166, T168, T169, T170, T171, T179) |
| **Anchors** | §11.4.292 (RED first), §11.4.102 (root cause), §11.4.289 (real extractors, no fixtures as evidence), §11.4.6 (no guessing) |
| **Scope boundary** | No production PDF and no vault was regenerated or re-sealed. Samples were built into a git-ignored scratch directory via `CAREER_OUTDIR`. No contact value, overlay value or passphrase appears in this file. |

All commands run from the umbrella worktree; `PYTHONPATH=_tools`, packages `career.*`.

## T162 / G-02 / F-08 - link annotations (VSC-426)

**Root cause.** `render/latex.py` `_url(text)` used the visible label as the `\href` target. For a label without a
scheme, hyperref writes a `GoToR` remote-file action to `<label>.pdf` (host/handle links) or a scheme-less `/URI`
(e-mail, bare domain). The WeasyPrint engine already used the real `href`, which is why Arabic/Persian PDFs were clean.

**RED, measured on the 300 PDFs in the existing cache (pypdf walk of every `/Link` annotation):**

    300 pdfs {'/URI:mailto': 40, '/URI:https': 160, '/URI:SCHEMELESS': 520, '/GoToR': 780}

780 + 520 = 1300 broken links of 1500 (260 LuaTeX PDFs x 5). The new gate (`gates._check_link_annotations`) run on
existing cache PDFs (en, ru, hi, cv and cover): `rc=1` with "link annotation is a GoToR action, not a URI",
"URI has no mailto:/https: scheme" and "no mailto:/https: link annotation targets the visible contact"; on the
Arabic WeasyPrint PDFs `rc=0`. Unit tests: 6 of 8 new `LinkAnnotations` tests failed before the change.

**Fix.** `_url(text, href)` takes an explicit target; both call sites pass `contact["href"]`. `gates` gained
`_link_annotations` / `_check_link_annotations` (every `/Link` must be `/URI` with `mailto:` or `https:`, and every
visible contact label must be the target of one) and `validate_pdf` calls it. `_tex_contact_urls` now returns the
visible label (second `\href` argument), so the text-layer intactness check keeps judging what the page shows.

**GREEN, 60 freshly built sample PDFs (2 areas x cv/cover x 15 locales, scratch cache):**

    60 pdfs {'/URI:mailto': 60, '/URI:https': 240}      # 0 GoToR, 0 scheme-less

`career build` reported `0 gate failure(s), 0 undetermined` for both areas.

## T166 / G-04 - keyword matcher (VSC-427)

**Root cause.** `screen._has_keyword` squashed both strings to `[0-9a-z]` and tested substrings.

New module `career/keywords.py` (tokeniser: letters, digits and combining marks, so a Devanagari word is one token;
`C++`/`C#` kept; plural and version-suffix tolerance; `Node.js`/`NodeJS` joined form; synonym groups, caller-extensible;
unspaced scripts (Han/kana/Thai) fall back to a squashed substring test; Hangul matches as a token prefix because
particles attach to the noun). `screen._has_keyword` delegates to it.

RED: 13 of 22 tests in `test_keyword_match.py` failed against the old matcher (`Django`/`Go`, `JavaScript`/`Java`,
`C`/`C++`, split phrases, RU/SR/DE/HI/KO/zh cases, synonyms). GREEN: 22 of 22.
Impact on the real corpus: all 150 cached CV texts x their `ats` + `area` keywords = 7155 checks; old matcher
0 missing, new matcher 0 missing (no regression; the gate stays self-referential until T163/T167 add posting-driven
checks, which is wave 2 and job_seeker side).

## T170 / G-08 / G-22 / F-26 - tagged PDF, XMP, title display (VSC-428)

Environment: LuaHBTeX 1.22.0 (TeX Live 2025), tagpdf, WeasyPrint 67.0. **veraPDF is not installed
(`which verapdf` empty); no PDF/UA validator was available, so NO PDF/UA conformance is claimed anywhere.**
What is gated is presence of structure: `/MarkInfo /Marked`, `/StructTreeRoot`, XMP `/Metadata`, `/Lang`,
document title, `DisplayDocTitle` (`gates._check_structure`, wired into `validate_pdf`).

RED: the same check on the 300 cached PDFs: 300 of 300 fail (not tagged, no tag tree, no XMP, no DisplayDocTitle;
`/Lang` was already present). `test_pdf_structure.py`: 7 of 9 errors/failures before.

Implemented:
* LuaLaTeX: renderer emits `\DocumentMetadata{lang=<l>,pdfversion=1.7,tagging=on}` before `\documentclass`
  (deliberately no `pdfstandard=ua-1`: the file must not declare an unmeasured conformance).
* Three real defects of the tagged build were found by measurement and fixed in `miloscv.cls`:
  1. tagpdf rewrites every line-end hyphen to U+00AD in the text layer; the existing gate forbids it (ATS reads two
     words). Fix: `\tagpdfsetup{activate/softhyphen=false}`. Without it 3 of 4 checked locales failed the gate.
  2. Under tagging the kernel list code ignores `\setlist`: `\itemsep` measured 4.5pt instead of 0.2pt, +8.5pt per
     bullet, pushing a mobile-area Russian CV to 4 pages (budget 3). Fix: restate the geometry through `\@listi`
     when tagpdf is active. Bullet x/y positions then equal the untagged build.
  3. `DisplayDocTitle` was only set by the PDF/UA option: `\hypersetup{pdfdisplaydoctitle=true}`.
* WeasyPrint (ar/fa): `pdf_variant="pdf/ua-1"`, the only mode that writes both the tag tree and the XMP packet.
  **Caveat:** the library stamps `pdfuaid:part=1` into the XMP of those files; that is the library's declaration,
  not a measured result.

GREEN on 60 sample PDFs: structure gate clean for all; pages and word counts (pdftotext) unchanged vs the existing
cache for every one of the 60; byte-reproducibility test (two builds, identical bytes) passes with tagging on.
Cost: total size 2.86 MB -> 4.21 MB (+47%, largest 152 KB), because tagpdf embeds two small CSS attachments
(`/AF`) plus the structure tree. Re-sealing and re-distribution of every PDF is therefore a follow-up (below).

## T168 / G-06 - MuPDF word boundaries in Hindi/Korean (VSC-429): root cause found AND fixed by T170

Reproduced (existing cache, `mutool draw -F txt` vs `pdftotext -raw`, tokens): hi 530 vs 1004, ko 515 vs 929,
longest MuPDF token 90 characters (en: 925 vs 919, no loss).
**Root cause.** LuaTeX emits no space glyph between words, only a text-matrix move (`Tm`) per word; MuPDF's gap
heuristic does not recognise the gap for these fonts, poppler and pypdf do. Confirmed in the content stream: the
rebuilt (tagged) PDF contains the space glyph `<0003>` between words, the old one does not.
**Measured fix** (tagpdf inserts real interword space glyphs): ai-engineering hi mupdf 530 -> 1010 tokens (poppler
1004), ko 515 -> 935 (poppler 929); mobile hi 588 -> 1054, ko 551 -> 947; longest token 90 -> 23.
There is no separate "variance gate" yet; the cross-extractor gate (F-25) stays a wave-2 item.

## T169 / G-07 - Arabic order in `pdftotext -raw` (part of VSC-429): not fixable in our rendering, documented

Reproduced on existing and rebuilt Arabic PDFs identically: of 43 source items, first four words appear in logical
order for `pdftotext -layout` 29, `mutool` 25, pypdf 24, and **reversed in 21 and forward in 0 for `pdftotext -raw`**.
Cause: `-raw` is "content stream order" by definition, and WeasyPrint writes RTL runs in visual order; the other
extractors apply bidi reordering. WeasyPrint 67 has no ActualText/logical-order option and tagging does not change it
(counts identical before and after). Remedy path: gate on "logical order in at least two extractors" (F-25), not
a renderer change. Nothing was changed.

## T179 / G-20 - Cyrillic OCR recall 67-77% (VSC-429): measurement artefact, not a rendering defect

Tesseract 5 with language packs `deu eng fra osd rus srp srp_latn`. Word recall of OCR against the text layer
(words >= 3 letters, one existing cache CV per language):

| PDF | OCR languages | Cyrillic words | Latin words | all |
|---|---|---|---|---|
| ru CV | `rus` (200 and 300 dpi, identical) | 431/431 = 100% | 11/302 = 3.6% | 60.3% |
| ru CV | `rus+eng` 300 dpi | 430/431 = 99.8% | 289/302 = 95.7% | 98.1% |
| sr CV | `srp` | 454/455 = 99.8% | 11/319 = 3.4% | 60.1% |
| sr CV | `srp+eng` | 452/455 = 99.3% | 294/319 = 92.2% | 96.4% |
| ru cover | `rus` | 176/176 = 100% | 1/63 = 1.6% | 74.1% |
| ru cover | `rus+eng` | 176/176 = 100% | 49/63 = 77.8% | 94.1% |
| en CV | `eng` | - | 782/792 = 98.7% | 98.7% |
| de CV | `deu+eng` | - | 787/799 = 98.5% | 98.5% |

Root cause: a single-language OCR run cannot read the Latin technology names and URLs that every CV contains; the
Cyrillic text itself is recognised at 99.8-100%. The text layer and the visual agree. Remedy for the future gate
(T179): OCR with `<lang>+eng`, compute recall per script class. No renderer change is warranted.

## T171 / G-09 - plain-text / DOCX export: NOT done, left to wave 2

Not modest: a new artifact suffix changes `ENGINE_FORMATS`, `expected_files`, the 10x2x15 matrix check in
`career verify`, `manifest.json` and the vault packing, and `job_seeker` `templates.go` accepts `.pdf` slots only
(T172 adds the manifest fields). It needs its own design pass.

## Follow-up, operator-gated (not done here)

1. Full rebuild of all 300 PDFs (`career build`) and re-seal of the vault: every PDF byte changes (links, tagging).
   The vault passphrase is the operator's secret and was neither read nor used.
2. Until then `career verify` / `gates.validate_pdf` on the existing cache is RED on the new structure check by design.
3. Install veraPDF (host package or operator download) to measure PDF/UA-1; only then may any conformance be claimed.

## Full-suite result (measured 2026-11-24)

`cd _tools && python3 -m unittest discover -s career -p 'test_*.py'` in the umbrella worktree: 311 tests; 9 failures and 17
errors. 25 are environmental: the worktree has no checked-out `milosvasic.ru` / `submodules/LLMProvider` submodule
(`FileNotFoundError` on `milosvasic.ru/sitemap.xml`, `.../assets/js/vault.js`, `submodules/LLMProvider/pkg/providers`). One was a
REAL regression of this change: `test_pdf_pipeline.GateHardening.test_expected_contacts_from_doc_override_source` expected the
`\href` target from `_tex_contact_urls`; the contract is now the visible label. The test was updated to the new contract.
Re-run of the 8 affected modules (`test_expertise_cli/localized/polish`, `test_profile_facts`, `test_vault`, `test_vault_fuzz`,
`test_vault_review`, `test_pdf_pipeline`) against an overlay with the real submodules present: `Ran 161 tests, OK (expected failures=1)`.
No gate in `scripts/` (pre-push, registry, claim ledger) runs `career verify`; the only claims of `300/300` were in
`docs/STATE-MILESTONE.md`, now annotated as historical. `vault.collect_artifacts` seals only rc 0 PDFs, so a re-seal from the
old cache would seal nothing until the rebuild (fail-closed, not silently weakened).
