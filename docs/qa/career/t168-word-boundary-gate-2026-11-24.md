# JSK-T168 / G-06 / F-25 - cross-extractor word-boundary gate (2026-11-24)

| | |
|---|---|
| Task | job_seeker `specs/001-job-seeker-mvp/tasks.md` JSK-T168 |
| Code | `_tools/career/extract_gates.py` `check_word_boundaries`, wired in `gates.validate_pdf`; proof `prove_extract_gates.py` |
| RED (broken artifact, gate not wired) | `t168-red-2026-11-24.txt` |
| GREEN + paired mutations | `t168-green-and-prove-failure-2026-11-24.txt` |

**Gate.** Whitespace-token counts of MuPDF, `pdftotext -raw` and pypdf must satisfy min/max >= 0.90.
zh/ja are exempt (no inter-word spaces). For ar/fa pypdf is not a voter (see below). Fewer than two extractors
-> `None` -> `validate_pdf` rc 2 (never a pass).

**RED on the broken artifact (11.4.115).** The pre-T170 build (LuaLaTeX with `tagging=off`, i.e. no inter-word space
glyphs) built fresh by the real renderer: hi mupdf 530 / poppler 1004 / pypdf 1026 (min/max 0.53). With the gate not
wired, `validate_pdf` refused it only for tagging and soft-hyphen reasons and said nothing about word boundaries
(`t168-red-2026-11-24.txt`). With the gate wired, `BrokenArtifactWordBoundaries` passes (hi and ko refused with
"word boundaries differ").

**GREEN.** 20 freshly built PDFs (ai-engineering, cv + cover x en de ru sr fr hi ko ar fa es): every one passes,
ratios 0.966-0.994 for non-RTL (hi 1010/1004/1010, ko 935/929/952).

**Measured finding that shaped the gate.** pypdf reports ar 891 and fa 918 tokens against MuPDF/poppler
1007/1053 and 1012/1069 (min/max 0.85/0.86) although the stream holds the same space glyphs: pypdf fuses the words around
embedded Latin/number runs of a visually ordered right-to-left line. That is the logical-order problem of T169, not a missing
glyph, so ar/fa are judged by MuPDF vs poppler (0.956 / 0.947).

**Paired mutations** (`python3 -m career.prove_extract_gates`, 12 cases): controls en/hi/ko pass; MuPDF loses 45% of the
spaces (hi, ko) -> blocked; poppler loses 45% (en) -> blocked; pypdf loses all spaces -> blocked; one extractor only ->
cannot determine; zh exemption control. `python3 -m unittest career.test_extract_gates career.test_gates_render
career.test_pdf_structure`: 51 tests OK.
