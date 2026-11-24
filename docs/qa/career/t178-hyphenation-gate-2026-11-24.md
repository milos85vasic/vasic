# JSK-T178 / G-18 / G-19 - extraction hygiene: running header and hyphenation (2026-11-24)

| | |
|---|---|
| Task | job_seeker `specs/001-job-seeker-mvp/tasks.md` JSK-T178 |
| Code | `_tools/career/extract_gates.py` (`hyphen_breaks`, `check_hyphenation`), `gates.validate_pdf`, `latex/miloscv.cls` (`\hyphenpenalty`) |
| RED | `t178-red-2026-11-24.txt` |
| Paired mutations | `t178-prove-failure-2026-11-24.txt` (22 cases incl. T168) |
| Per-PDF data | `t178-per-pdf-hyphen-table-2026-11-24.txt` |
| Tests | `t178-tests-2026-11-24.txt` |

**Running header/footer (G-18)** was already a blocking gate (`check_running_headers`, wave 2); unchanged.

**Hyphenation (G-19) - root cause.** `miloscv.cls` set `\hyphenpenalty=600`, so LuaLaTeX cut words at line ends
(`evalua-`/`tion`, `Post-`/`greSQL`, `Reposito-`/`ries`, `Au-`/`todesk`). The text layer keeps the `-` (tagpdf soft-hyphen rewrite is
off), so an extractor that joins lines literally sees two tokens and `PostgreSQL` no longer matches. The earlier note
"fixing it needs ragged lines, a layout decision" is withdrawn: the class is already `\RaggedRight` with
`\emergencystretch=2em`, and `\hyphenpenalty=10000` (forbid automatic hyphenation, keep breaks at hyphens the text itself contains)
rebuilds all 22 measured documents inside the 3-page / 1-page budgets.

**Gate.** Each line-end hyphen is classed `explicit` (the source `.tex` itself contains that hyphenated compound) or `auto` (the
renderer cut a word). `auto` must be 0; `explicit` is budgeted at 8 per document (measured max 4). No sibling source and an
`auto`-looking break -> rc 2 (never a pass).

**RED (broken artifact).** The real renderer with the old penalty (600): `validate_pdf` returned
`rc 0 'PDF is extractable, single-column ...'` for the en CV with the gate un-wired.

**GREEN.** 22 fresh PDFs (cv + cover x en de ru sr fr es hi ko tr be kk): `auto=0` everywhere, pages within budget, explicit
0-4 (table file). `BrokenArtifactHyphenation` shows the 600-penalty en and de CVs refused ("automatic hyphenation") and the current class clean.

**Follow-up (operator-gated, not done):** the class change alters every LuaLaTeX PDF; the shipped cache and the sealed vault are rebuilt by
the operator's `career build` + re-seal (passphrase is the operator's secret).

**Test run** (`t178-tests-2026-11-24.txt`): 122 tests, 6 failures, all in `test_pdf_pipeline` (`RealLatexScripts` zh/hi/ja/ko, `RealRtl` ar/fa) with
"section heading(s) not recognisable ..." - minimal fixture documents have no experience/education/skills sections and the T174 heading gate
refuses them. They are NOT caused by this change: `test_chinese` and `test_persian_passes` were re-run on a clean checkout of `main`
(`4c7f6dc`) and fail identically. Reported, not hidden; fixing them belongs to the T174 fixtures (another agent is fixing red tests on main).
