# JSK-T179 / G-20 - OCR consistency gate and the ru/sr recall cause (2026-11-24)

| | |
|---|---|
| Task | job_seeker `specs/001-job-seeker-mvp/tasks.md` JSK-T179 |
| Code | `_tools/career/extract_gates.py` (`ocr_applicable`, `ocr_recall`, `check_ocr_consistency`), `gates.validate_pdf`, `sample_build.scramble_text_layer` (test support) |
| RED | `t179-red-2026-11-24.txt` |
| GREEN + paired mutations | `t179-prove-failure-2026-11-24.txt`, `t179-tests-2026-11-24.txt` |

**Cause of the 67-77 percent Cyrillic recall (resolved, MEASURED).** A single-language OCR run (`rus` / `srp`) cannot read the Latin technology
names and URLs every CV holds. Fresh PDFs, page 1, 200 dpi: ru CV `rus` 0.728 vs `rus+eng` 0.964; sr CV `srp` 0.698 vs `srp+eng` 0.942; ru cover `rus` 0.733 vs `rus+eng` 0.946; sr cover
0.736 vs 0.932. The text layer and the page agree; the old figure measured the OCR language set. Table: `t179-per-pdf-ocr-table-2026-11-24.txt`.

**Gate.** For locales with a configured pack (en, de, fr, ru, sr; `<lang>+eng`): page-1 recall of the text layer's words (>= 3 letters) in the OCR
text must be >= 0.90 (measured 0.932-0.986). Tesseract, pdftoppm or the pack missing -> `validate_pdf` rc 2 (never a pass). Locales without a pack
(hi, ko, ar, fa, zh, ja, es, tr, be, kk) are reported NOT APPLICABLE; installing their models is the operator step Q-ATS-6, after which adding them is one
dictionary line in `OCR_LANG`. The backlog bar of 0.95 is not used: short pages with many Latin names (sr cover 0.932) sit below it for a measured reason, not a defect.

**RED.** A real PDF whose font ToUnicode maps every letter to its neighbour (the page shows one text, the layer says another) is not refused by the OCR
reason with the gate un-wired (`t179-red-...`); wired, recall is 0.0 and `validate_pdf` returns rc 1 "OCR recall".

**Tests.** `t179-tests-2026-11-24.txt`: 128 tests, 6 failures, the same six `test_pdf_pipeline` heading-fixture failures that fail identically on clean `main` (see
`t178-main-baseline-failures-2026-11-24.txt` in PR 62; not caused by this change). `t179-prove-failure-2026-11-24.txt`: 31 cases (T168 + T178 + T179) 31 passed:
controls en/ru recall 0.985 / 0.964 with validate_pdf rc 0; the scrambled-text-layer artifacts (en, ru) blocked with an "OCR recall" reason; `rus`-only 0.728 (root cause);
tesseract absent -> rc 2; non-OCR locales not applicable.
