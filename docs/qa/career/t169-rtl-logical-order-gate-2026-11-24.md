# JSK-T169: RTL logical-order gate for ar and fa

| | |
|---|---|
| Purpose | Record the target-reader decision, the gate, and its RED/GREEN/mutation evidence for JSK-T169 (gap G-07, G-21, F-25) |
| Constitution | 11.4.6 (no guessing), 11.4.102 (root cause first), 11.4.115 (RED on the broken artifact), 11.4.201 (a gate must assert the real condition) |
| Revision | 1 (2026-11-24) |
| Source of truth | `_tools/career/extract_gates.py` (`check_rtl_document`, `RTL_TARGET_EXTRACTORS`), `_tools/career/gates.py` (`validate_pdf`) |
| Operator decision | 2026-11-24: the gate targets MuPDF and `pdftotext -layout` |

## Supported and unsupported readers (ar and fa)

| Reader | Status | Why |
|---|---|---|
| MuPDF (`mutool draw -F txt`) | **supported, blocking** | reads the words of an RTL line in logical order on the real PDFs (table below) |
| poppler `pdftotext -layout` | **supported, blocking** | sorts by position and applies its own bidi pass; logical order on the real PDFs |
| poppler `pdftotext -raw` | **NOT supported** | dumps content-stream order and applies its RTL reversal to it, so it returns the words of Arabic/Persian lines reversed for a correct PDF (0 of 123 phrases forward on the fresh cv-ar) and forward for a mirrored one (82 of 123). It cannot be satisfied together with MuPDF: a PDF cannot be in visual order for `-raw` and logical order for MuPDF at once |
| pypdf | informational only, does not vote | assembles RTL lines from visually ordered runs and fuses words around embedded Latin runs (T168); it is not a target |
| Position-less readers (any parser that reads the stream in file order and does no bidi of its own) | **NOT supported** | same reason as `-raw`; the product cannot serve a reader whose expectation contradicts the supported two |

Marking the lines up with `/ActualText` was tried and does not help: poppler honours it and then applies its RTL reversal to the ActualText string again (output reversed) and MuPDF ignored it on that file (`evidence/JSK-T169/investigation.txt` in `vasic-digital/job_seeker`). `pdfminer.six` is not installed on this host, so a position-sorting Python reader was not measured.

## The gate

`extract_gates.check_rtl_document(pdf, lang)` (ar and fa only; other locales return `[]`):

1. Phrases come from the document's own HTML source (the `<head>` is excluded): every non-overlapping run of 3 consecutive pure Arabic-script words inside ONE text node. A token with a Latin letter, a digit or punctuation ends a run, because the readers disagree on where an embedded Latin run goes.
2. Each phrase is compared as a whitespace/joiner/mark-insensitive string (`_squash`, NFKC) against the output of BOTH supported readers.
3. At least `MIN_RTL_FORWARD` = 80% of the phrases must read forward in EACH reader. Not 100%: a phrase that wraps onto the next line beside an embedded Latin run is legitimately split by both readers (measured about 2% to 13% on fresh builds), whereas a mirrored layout leaves 0%.
4. A target reader or the sibling `.html` source missing, or no phrase, is `None`, and `validate_pdf` returns rc 2 (never a pass).

It is wired into `gates.validate_pdf` right after the T168 word-boundary check.

## Evidence

| File | What |
|---|---|
| `t169-tests-2026-11-24.txt` | Unit run over test_extract_gates, test_gates_render, test_pdf_pipeline, test_pdf_structure: 124 run, 6 FAILED, all `section heading(s) not recognisable` (T174) on hand-built zh/hi/ja/ko/ar/fa fixtures. These predate this PR: `RealRtl.test_persian_passes` was independently re-run on `origin/main` and fails there too, and the T178 baseline file records the same class. None concerns RTL order. (The file's `rc=0 ok` line belongs to an earlier sub-run) |
| `t169-red-2026-11-24.txt` | RED baseline: with the gate present but not wired, `validate_pdf` verdicts on the visually-mirrored PDFs do not carry the T169 message (they fail only incidentally on T168/T174) |
| `t169-per-pdf-rtl-table-2026-11-24.txt` | GREEN on 4 fresh ar/fa PDFs and RED on 3 mirrored twins, per reader |
| `t169-prove-failure-2026-11-24.txt` | `python3 -m career.prove_extract_gates`: 47 passed, 0 failed of 47 cases, 12 of them T169 (per language ar/fa: control, mirrored PDF, one-reader-only mutations for each reader, absent-reader rc 2; plus the `-raw` scope case and the LTR scope case). The file is the last 40 lines of the run: the first 10 case lines (T168 controls) were cut by `tail -40` when it was captured, which is why 37 case lines are listed against the summary's 47 |

The mirrored twin is produced by `sample_build.visual_order_pdf`: the real document HTML re-rendered by the real WeasyPrint engine with the paragraph forced `ltr` and every word an isolated span in logical order, so the words sit last-first on the page. It is not a stub or a patched extractor output.

Honest boundary: the evidence is 4 fresh ar/fa documents of one area (ai-engineering); the 80% threshold is set from that measured range (87% to 98% forward in the supported readers). The full 300-document matrix is rebuilt and re-gated in the operator hand-off (`docs/operator/rebuild-reseal-and-ocr-packs.md`).
