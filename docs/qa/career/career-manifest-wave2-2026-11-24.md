# Career engine wave 2 - manifest contract and extraction gates (2026-11-24)

| | |
|---|---|
| Branch | `pr/career-manifest-wave2-x` |
| Consumer | `job_seeker` `specs/001-job-seeker-mvp/tasks.md` (JSK-T172 umbrella half, JSK-T160 cover metadata, T163, T174, T178) |
| Test log | `career-manifest-wave2-tests-2026-11-24.txt` (verbatim output of the run below) |

## Manifest contract (JSK-T172, JSK-T160)

`_tools/career/buildlib.py` `manifest_bytes` / `write_manifest` now emit top-level `epoch` and `overlay_sha`
(sha256 of the overlay.yaml bytes, same digest as job_seeker `match.OverlayFileSHA`; `""` without an overlay),
per-`.pdf` `gate` (`pass` only for gate rc 0; `fail`, `undetermined` for rc 2, `unknown` when no verdict was
supplied - fail closed), and per-`cover-*.pdf` `cover_date` (UTC date of the build epoch, the date the cover prints),
`company`, `role` (empty: the engine renders generic covers). `career build` passes the real gate results;
`career verify` re-derives the manifest from files + live gate verdicts + overlay and refuses a manifest that
disagrees (a manifest vouching `pass` for a failing PDF is a lie).

`test_manifest_contract.py` builds a real 3-locale sample (LuaLaTeX en/ru + WeasyPrint ar, real gates, real writer,
scratch overlay with no personal data) and runs job_seeker's own Go code over it (`templates.Open`, `Store.Check`
with `RequireOverlay` and `RequireGate`, `Resolve`, and the unexported `draft.checkCover` through a `go run -overlay`
probe, nothing written into the job_seeker checkout). Negative cases mutate the REAL manifest: failed gate stamp,
missing epoch, foreign overlay, cover from another day, mismatching company.

## Extraction gates (JSK-T163, T174, T178)

`_tools/career/extract_gates.py`, wired into `gates.validate_pdf`: placeholder-token leakage (the pattern is asserted
textually identical to job_seeker `slots.go` `reReserved`), heading recognition on CVs (alias table, 15 locales x 3
required sections), running header/footer on every page. Measured on real renders: all 15 locales of the
`ai-engineering` CV pass all three; golden-bad mutations of the extracted text fail them.

## Already closed by wave 1 (PR #19, `career-engine-wave1-2026-11-24.md`)

T162 link annotations, T166 token keyword matcher, T170 tagged PDF + XMP, and the root causes of T168 (fixed by T170),
T169 (content-stream order, not fixable in the renderer) and T179 (OCR language set, measurement artefact).
`extract_gates.check_word_boundaries`, `check_rtl_logical_order`, `check_ocr_consistency` encode those findings as
callable checks (not wired as blocking: they are measurements, see wave-1 doc).

## Not done, and why

* **T178 hyphenation half**: the renderer auto-hyphenates (`evalua-` / `tion`); `check_hyphenation` measures it on the
  real PDFs and reports hits, so it is NOT a blocking gate. Fixing it means disabling hyphenation in the LuaLaTeX
  engine for 15 locales (ragged lines), a layout decision.
* **T173** CV page budget: the task itself says operator decision first.
* **T180** Hebrew locale: operator decision first.
* No full 300-PDF rebuild was run (out of scope); the shipped cache is untouched.

## Test run (verbatim log: `career-manifest-wave2-tests-2026-11-24.txt`)

`python3 -m unittest -v test_manifest_contract test_extract_gates test_pdf_pipeline test_gates_render test_pdf_structure test_vault`
-> `Ran 129 tests in 521.5s, FAILED (failures=1)`: 128 ok; the one failure,
`test_vault.CrossLanguage.test_node_decrypts_python_sealed_vault_and_rejects_tampering`, is an ENVIRONMENT fault of this
worktree: `Cannot find module '../../milosvasic.ru/assets/js/vault.js'` (the `milosvasic.ru` submodule is not
checked out in the PR worktree). It does not touch the manifest or the new gates; not a pass, not hidden.
A first run (before the `full_cv` flag) had 6 failures in `test_pdf_pipeline`: the minimal fixture documents have no
experience/education/skills sections, so the heading gate correctly refused them; the heading requirement is now a
`full_cv=True` flag set by the matrix build and verify (`career.py`), and the same tests pass.
