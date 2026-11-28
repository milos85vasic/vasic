# Implementation-Ready Task Descriptions — specs/008-unified-workshop-platform

Source: `specs/008-unified-workshop-platform/tasks.md` (the ACTIVE unified spec, supersedes specs/001–007).
Task states read directly from that file. The 7 genuinely unblocked tasks are:

**T038, T196, T289, T356, T357, T462, T543**

Nothing below is committed or pushed. No files were edited.

---

## 1. T038 — Passage-contract review checkpoint

| Field | Value |
|---|---|
| Unified id | **T038** |
| Source | `(was: 001/T022)` |
| Phase | Phase 2 — Foundational — blocking prerequisites |
| State | `[ ]` open (human-review checkpoint) |
| Files mentioned | `contracts/passage-contract.md`, `submodules/passage/pkg/passage/symbol.go`, `submodules/passage/pkg/passage/ingest_match.go`, `submodules/passage/pkg/passage/symbol_test.go` |
| Markers | `[REVIEW]` |
| Dependencies | Predecessors T031/T032/T033 (unified) are DONE — commit `1e361bd`, 75/75 tests passing. No code blocker. |
| First command | `bash submodules/passage/pkg/passage/symbol_test.go` — actually: `cd submodules/passage && go test -count=1 ./pkg/passage/...` to confirm 75/75 green, then read `contracts/passage-contract.md` end-to-end and write the review record at `specs/001-workshop-curriculum-platform/review.md`-style location for the passage contract. |
| Notes | All-code work is complete; T038 is a **human judgement review** of the passage contract implementation (`pkg/passage` symbol key `(path,symbol)`, `symbol_aliases`, four-outcome resolver, redaction log) before anything consumes it. Not self-approvable. Owner: human reviewer. Unblocked today. |

---

## 2. T196 — Emit transcript with pid anchors

| Field | Value |
|---|---|
| Unified id | **T196** |
| Source | `(was: 001/T030)` |
| Phase | Phase 6 — US3 + US12 — transcript and curriculum browsing |
| State | `[ ]` open (genuinely unblocked) |
| Files mentioned | `workshop/curriculum/chapter-01/transcript.md` (exists, 107,847 B, timestamps done), `workshop/pipeline/build_transcript.py`, `workshop/curriculum/passages.jsonl`, `submodules/passage/pkg/passage/anchor.go` (ticked, never written into a real doc) |
| Markers | `[US1]` |
| Dependencies | T210 (`--write-anchors`) is real and proven against synthetic fixtures; `build_transcript.py` merges ASR segments into silence-delimited turn paragraphs, so an individual segment has **no stable line of its own to anchor** under the current rendering — that is the structural reason the pid-anchor half is unwritten. Nothing blocks starting; owner: implementer. |
| First command | `grep -c '<!-- pid:' workshop/curriculum/chapter-01/transcript.md` → confirms 0 anchors; then design the anchor insertion: map each `passages.jsonl` pid to a location in `transcript.md` (via the sidecar's `pid` field, since `SourceRef.Anchor` was relabeled `AnchorSidecar`) and insert `<!-- pid: <PID> -->` markers at the corresponding turn/paragraph boundaries. |
| Notes | Timestamps half is done; pid-anchor half genuinely unwritten. Real transcript NOT touched this pass (0 pid comments, clean `git status`). Mechanism proven on a synthetic fixture. `001/T113 (unified T210)`'s `--write-anchors` has nothing to switch on against a real source until this lands. Quoting rule: path identifiers only — no prose/transcript content or personal names. |

---

## 3. T289 — Author text alternatives for 205 video materials

| Field | Value |
|---|---|
| Unified id | **T289** |
| Source | `(was: 006/T044)` |
| Phase | Phase 8 — US13 + US14 + US15 — deep linking, video anchors and materials |
| State | `[ ]` open (genuinely unblocked) |
| Files mentioned | `workshop/curriculum/` video materials (213 total; 205 carry `alt: ""`), `workshop/platform/frontend/src/app/features/areas/area-lessons.component.ts` (renders materials in place with captions, T321) |
| Markers | `[P] [SUBAGENT] [US4]` |
| Dependencies | None block starting. This is **genuine editorial/accessibility work** — author text alternatives (alt text) for 205 video materials, not auto-generable from outside this scope. The interface already names the absence (`alt: ""`) rather than hiding it — a disclosed gap, not a hidden one. FR-016→unified FR-119, FR-028→unified FR-268. |
| First command | Enumerate the 205 materials lacking alt text (path-level only): `grep -rn 'alt' workshop/curriculum/ --include='*.json' --include='*.jsonl'` to locate material records, then author one alternative text per video material per its `MaterialID`/`kind` without quoting any private content. |
| Notes | Editorial task, not engineering. Counts only (205 of 213) — no transcript text, no personal names. 205 of 213 materials carry `alt: ""`. |

---

## 4. T356 — Fix fabrication verification (SC-010)

| Field | Value |
|---|---|
| Unified id | **T356** |
| Source | `(was: 001/T078)` |
| Phase | Phase 9 — US20 + US22 — search by meaning, grounded answering |
| State | `[ ]` open (genuinely unblocked) |
| Files mentioned | `workshop/platform/backend/gates/bench-answers.sh` (the harness — exists, has run), `workshop/platform/backend/testdata/benchmark/questions.tsv` (24 `A` rows + 33 `U` rows), `workshop/platform/backend/pkg/answer/`, `pkg/answerhood/ollama.go`, `pkg/answer/pipeline.go`, `workshop/platform/backend/evidence/answering/bench-question-verifier-ab-2026-09-02.tsv` |
| Markers | `[TDD]` |
| Dependencies | Harness exists and ran. L4 (real entailment) unavailable on this host (T351: no `model.onnx`). Residual defect understood: a single fabricated/echoed word inside an otherwise well-grounded claim (e.g. "annually" copied from the question wording, not a citation). SC-010 (spec 001's) **NOT met**: 1 fabrication in 33 unanswerable questions on generation 67, `answered+cited 3 / declined 21 / unavailable 0`, `refused 32 / FABRICATED 1 / unavailable 0`. |
| First command | `bash workshop/platform/backend/gates/bench-answers.sh http://127.0.0.1:8087` (reproduces the failing measurement), then inspect the 1 fabricated row and the non-determinism finding (`pkg/answerhood/ollama.go` sets `temperature:0` but **no fixed seed**, unlike the main generator which sets both `temperature:0` and `seed:7`). |
| Notes | **Part A (flag surface) DONE**: long-option parser (`--questions`/`--report`/`--min-answerable`/`--timeout`/`--base`) added; `--answerable`/`--unanswerable`/`--report` flags still owed by contract. Part B open: SC-010 not met with a well-understood residual cause. The harness top score + margin print on every response (including successes) is done. Do not rebuild the harness — fix the surviving fabrication, re-run. Quoting rule: identifiers/paths only. |

---

## 5. T357 — Human per-citation certification (SC-009)

| Field | Value |
|---|---|
| Unified id | **T357** |
| Source | `(was: 001/T079)` |
| Phase | Phase 9 — US20 + US22 — search by meaning, grounded answering |
| State | `[ ]` open (genuinely unblocked — NOT a pure operator item) |
| Files mentioned | `workshop/platform/backend/gates/bench-answers.sh` (same harness as T356), `workshop/platform/backend/testdata/benchmark/questions.tsv`, `verify-sc009-citation-span.sh` (rc 0, but certifies **media citation inside time span**, not claim support — spec 002's SC-009, per its own `NOTE:` line) |
| Markers | `[TDD]` |
| Dependencies | Blocked **twice**: (1) on the answer rate — `answered+cited 3` on the 24 answerable questions, so no population of ≥20 answers exists to certify (T356's work); (2) on **human per-citation reading** of ≥20 answers (operator labour — irreducible, not delegable to a machine). Corpus floor holds (24 `A` rows ≥ 20); answer floor does not. L4 effectively absent on this host. `verify-sc009-citation-span.sh` is the wrong gate (standing rule 7). |
| First command | Reproduce: `bash workshop/platform/backend/gates/bench-answers.sh http://127.0.0.1:8087` (see T356). Until `answered+cited` reaches ≥20, there is nothing to certify per citation. |
| Notes | **Unmet on both counts** (re-measured 2026-09-03). The recorded 2026-09-01 figure (`answered+cited 17`) was also below 20; drop from 17→3 is a measured change on generation 67, cause not diagnosed, `unavailable 0` rules out timeouts. No per-citation certification artifact exists. Must not be filed as a pure operator item — unwritten engineering (answer rate) + human reading. |

---

## 6. T462 — Contract sections + route-manifest rows for `screen_text`

| Field | Value |
|---|---|
| Unified id | **T462** |
| Source | `(was: 002/T139)` |
| Phase | Phase 14 — OCR ingestion (added 2026-09-02) |
| State | `[ ]` open (genuinely unblocked — deliberately deferred) |
| Files mentioned | `contracts/http-api.md` (and `http-api-delta.md` §4), `workshop/platform/gates/route-manifest.tsv`, `scripts/check-registry.tsv`, `check-registry-002.tsv`; G-OCR-1 … G-OCR-11 |
| Markers | `[UNBUILT] [P]` |
| Dependencies | None block writing contract text. Deliberately **not done in this pass**: moving eleven `G-OCR-*` ids into `contracts/` while none of the eleven gates exists would publish gate identifiers for gates nothing builds — a green gate-attachment closure check reporting the wrong question. Correct order: gates first, contract second. Current measurement: **19 ids, `unattached: 0`**, unchanged. |
| First command | Add contract sections for the `screen_text` passage kind, its evidence entries, and the modality + interval-bound fields (`contracts/http-api-delta.md` §4 pattern); add route-manifest rows; then move `G-OCR-1`..`G-OCR-11` into `contracts/` so the gate-attachment closure check enumerates them. Verify `verify-check-registry.sh` still reports `unattached: 0`. |
| Notes | FR-059→unified FR-274, Gate **G-KG-1**. Capable of being written ahead of implementation; left alone intentionally. Nothing technical or decisional blocks it. |

---

## 7. T543 — Closure: hierarchy depth measurement + limits documentation

| Field | Value |
|---|---|
| Unified id | **T543** |
| Source | `(was: 003/T037)` |
| Phase | Phase 17 — Polish and cross-cutting concerns |
| State | `[ ]` open (genuinely unblocked) |
| Files mentioned | `workshop/docs/limits.md` (exists, 2,273 lines, 117 headings; records nothing about hierarchy), `CONTINUATION.md`, `GET /api/chapters` (`"max_depth_present": 2` already published via `MaxDepthPresent`, `pkg/curriculum/chapterid.go:325`), `specs/003-chapter-hierarchy/` (archived `02`/`02.01` uningested) |
| Markers | `[REVIEW]` |
| Dependencies | `max_depth_present` IS already published as a measurement (LIVE: `GET /api/chapters` 200 returns `"max_depth_present": 2`). Nothing blocks starting. Missing: `limits.md` hierarchy section, archived/uningested status of `02`/`02.01`, no-constant-bounds-depth assertion, CONTINUATION.md update in same change, gate-coverage check confirming every contracted gate is carried by a task. FR-003→unified FR-017, SC-021→unified SC-025. |
| First command | `curl -s http://127.0.0.1:8087/api/chapters | jq .max_depth_present` → confirms `2` (already published). Then add `workshop/docs/limits.md` §10.x recording: per-request hierarchy-derivation cost measured at corpus size present (side-by-side with the figure), archived/uningested status of `02`/`02.01`, no-hardcoded-chapter-ceiling assertion (search returns nothing — confirmed at T544/T545), and update `CONTINUATION.md` in the same change. Run the gate-coverage check to confirm every contracted gate is carried by a task. |
| Notes | Partial per 2026-09-08 audit: `max_depth_present` done; `limits.md` records nothing about hierarchy; no gate-coverage check exists. Counts/paths only — `02` and `02.01` remain archived and uningested; nothing here ingests them. |

---

## Summary table

| Id | Source | Phase | Files (key) | First command | Notes |
|---|---|---|---|---|---|
| T038 | `001/T022` | Phase 2 | `contracts/passage-contract.md`, `submodules/passage/pkg/passage/*` | `cd submodules/passage && go test -count=1 ./pkg/passage/...` | Human-review checkpoint; code done (commit `1e361bd`, 75/75) |
| T196 | `001/T030` | Phase 6 | `workshop/curriculum/chapter-01/transcript.md`, `build_transcript.py`, `passages.jsonl` | `grep -c '<!-- pid:' workshop/curriculum/chapter-01/transcript.md` | pid anchors unwritten; timestamps done |
| T289 | `006/T044` | Phase 8 | `workshop/curriculum/` video materials (205/213 `alt: ""`) | `grep -rn 'alt' workshop/curriculum/` | Editorial/accessibility task; no engineering blocker |
| T356 | `001/T078` | Phase 9 | `bench-answers.sh`, `questions.tsv`, `pkg/answer/` | `bash workshop/platform/backend/gates/bench-answers.sh http://127.0.0.1:8087` | SC-010 not met: 1 fabrication in 33; fix residual, re-run |
| T357 | `001/T079` | Phase 9 | `bench-answers.sh`, `questions.tsv` | Same harness; need `answered+cited ≥ 20` first | Blocked on T356 answer rate + human per-citation reading |
| T462 | `002/T139` | Phase 14 | `contracts/http-api-delta.md`, `route-manifest.tsv`, G-OCR-1..11 | Add contract §4 sections + route-manifest rows for `screen_text` | Deliberately deferred; gates first, contract second |
| T543 | `003/T037` | Phase 17 | `workshop/docs/limits.md`, `CONTINUATION.md`, `GET /api/chapters` | `curl .../api/chapters \| jq .max_depth_present` | `max_depth_present=2` published; need limits.md section + CONTINUATION.md + gate-coverage check |

---

## Quoting / privacy rule observed

Per the task constraint, the `workshop` submodule is PRIVATE. This report refers to files **by path only** and quotes **code identifiers only** (function names, gate ids, file paths, JSON keys, task ids). No prose, transcript content, or personal names from the private submodule is quoted anywhere above. Counts are given at file/granularity level only.
