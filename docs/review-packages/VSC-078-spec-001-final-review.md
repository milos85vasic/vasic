# VSC-078 review package: final review against spec 001 (T105)

| Field | Value |
|---|---|
| Document | docs/review-packages/VSC-078-spec-001-final-review.md |
| Register id | VSC-078 (Operator-blocked; reviewer: human operator) |
| Authorised by | operator decision #19, 2026-10-14 (`docs/operator-decisions-2026-10-14-session.md`): "VSC-078 review package drafted for operator" |
| Revision | 1.0, 2026-10-15 |
| Measured against | umbrella HEAD `b622be4` plus working tree; `workshop` gitlink `fb798e98c998`, workshop HEAD `83ffa49abd2c` (34 commits ahead of the gitlink), workshop working tree 6 uncommitted paths |
| Visibility | PUBLIC umbrella: ids, counts and paths only; no private workshop content is quoted |
| Nature | a reading aid. It judges nothing and closes nothing; the register was not edited |

## Table of contents

1. [How statuses were derived](#1-how-statuses-were-derived)
2. [T105: task text and acceptance criteria](#2-t105-task-text-and-acceptance-criteria)
3. [Headline counts](#3-headline-counts)
4. [All tasks (131)](#4-all-tasks-131)
5. [Functional requirements (FR)](#5-functional-requirements-fr)
6. [Success criteria (SC)](#6-success-criteria-sc)
7. [Open predecessors blocking T105](#7-open-predecessors-blocking-t105)
8. [Human review checklist](#8-human-review-checklist)
9. [Known risks and limits](#9-known-risks-and-limits)
10. [Re-derive commands](#10-rederive-commands)

## 1. How statuses were derived

Read-only, nothing executed beyond `ls`, `git log`, `git ls-files`, `sqlite3 -readonly`. No gate was run.

- **DONE**: ticked `[x]` in `specs/001-workshop-curriculum-platform/tasks.md` AND at least one path named in the task text exists on disk; the commit is the last one touching that path (`git log -1`). File existence is NOT runtime proof.
- **UNVERIFIED**: ticked `[x]`, but no path in the task text resolves. Evidence is the checkbox only. The register records these as evidence class `checkbox-state` (the work was not re-run when the register was backfilled).
- **PARTIAL**: unticked and the task text itself says PARTIAL/PARTLY.
- **OPEN**: unticked, no partial marker.
- FR/SC rows are derived from the tasks that cite the id; an FR/SC cited by no task is UNVERIFIED. Five SC rows carry a manual note (SC-004, 009, 010, 014, 015).
- Register: ids are the register row whose title is `001-workshop-curriculum-platform T###`. 110 of 131 tasks have a row; 21 do not (shown as `none`; UNCONFIRMED whether they are tracked elsewhere).
- `review.md` (2026-09-03) is stale in places (e.g. it says `add-chapter.sh` does not exist; `workshop/scripts/add-chapter.sh` exists today). Use it as history, not as current state.
- Numbering collision: 001 and 002 both define `SC-0nn`/`FR-0nn`; gate files citing "SC-009" may belong to spec 002 (tasks.md lines 21-26 say so). Evidence below is tied to spec-001 tasks only.

## 2. T105: task text and acceptance criteria

Public text from tasks.md line 859: "**T105 [REVIEW]** Final review against spec.md: every FR traced, every SC measured or explicitly recorded as not-yet-measurable." Owner: human reviewer, last. Blocker: predecessors (all other open tasks).
Acceptance reading (derived from that sentence and `review.md` §7/§9, not a separate criteria list):
1. Every FR traced: `review.md` cites 5 of 48 FR ids per tasks.md (2026-09-03); this package lists all 59 FR ids found in spec.md with task coverage (section 5), which is a trace of tasks to FRs, not a review of whether each FR holds.
2. Every SC measured, or recorded as not-yet-measurable: section 6 lists 24 SC ids with a state; "UNVERIFIED" rows need a measurement or an explicit not-yet-measurable record from the reviewer.
3. The review cannot be honest while predecessor tasks are open (section 7).

## 3. Headline counts

- Tasks: 131 total (T001-T131 numbering; ids not contiguous by phase). **DONE 50 / PARTIAL 15 / OPEN 45 / UNVERIFIED 21** (T105 itself counted as OPEN). Ticked in tasks.md: 71; unticked: 60.
- FR (59 ids in spec.md): DONE 7, OPEN 15, PARTIAL 26, UNVERIFIED 11
- SC (24 ids in spec.md): DONE 5, OPEN 5, PARTIAL 11, UNVERIFIED 3
- The task brief cited "42 FR / 18+ SC" and "91 tasks"; the files today hold the counts above (FR ids by `grep`, tasks include the 2026-09 additions T106-T131). Re-derive before quoting.

## 4. All tasks (131)

| Task | Status | Register | Register status | Label (public task text) | Evidence path @ last commit |
|---|---|---|---|---|---|
| T001 | DONE | VSC-042 | Completed | Create the module skeleton workshop/platform/{backend,frontend,bin} an | `submodules/containers` @ e2dfe37 |
| T002 | DONE | VSC-043 | Completed | Initialise the Go module in workshop/platform/backend/go.mod (Go 1.26. | `workshop/platform/backend/go.mod` @ d85ca2d; `ai_interviewing/platform/backend/go.mod` @  |
| T003 | DONE | WSP-001 | Completed | Add replace digital.vasic.containers => ../../../submodules/containers | `workshop/platform/backend/go.mod` @ d85ca2d |
| T004 | DONE | VSC-044 | Completed | Scaffold the Angular client in workshop/platform/frontend mirroring ai | `workshop/platform/frontend` @ eb691db; `ai_interviewing/platform/frontend` @  |
| T005 | DONE | WSP-002 | Completed | Create workshop/pipeline/requirements.txt pinning faster-whisper + ctr | `workshop/pipeline/requirements.txt` @ 5b611f9; `workshop/pipeline/venv-setup.sh` @ 266f443 |
| T006 | OPEN | VSC-045 | Queued | Configure linting/formatting to match the reference module (gofmt, Ang | `workshop/platform/frontend` @ eb691db; `ai_interviewing/platform/frontend` @  |
| T007 | UNVERIFIED | WSP-003 | Completed | Verify workshop/ still adds zero CI: git -C workshop ls-files / grep - | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T008 | DONE | PSG-001 | Completed | Implement the ULID passage identifier minter in submodules/passage/pkg | `submodules/passage/pkg/passage/pid.go` @  |
| T009 | DONE | PSG-002 | Completed | Implement the <!-- pid: … --> source anchor reader/writer in submodule | `submodules/passage/pkg/passage/anchor.go` @  |
| T010 | DONE | PSG-003 | Completed | Implement the passage registry (passages.jsonl → passages.db) in submo | `submodules/passage/pkg/passage/registry.go` @  |
| T011 | DONE | PSG-004 | Completed | Implement the four-outcome resolver in submodules/passage/pkg/passage/ | `submodules/passage/pkg/passage/registry.go` @  |
| T012 | DONE | PSG-005 | Completed | half is proven, not asserted: go test -count=1 ./... in submodules/pas | `submodules/passage/pkg/passage/redaction.go` @ ; `submodules/passage` @ 13325b7 |
| T013 | DONE | PSG-006 | Completed | Prove the two survival guarantees in submodules/passage/pkg/passage/pi | `submodules/passage/pkg/passage/pid_test.go` @  |
| T014 | DONE | WSP-004 | Completed | Settle P-U1 before any code-identity work begins ((./contracts/passage | `workshop/pipeline/detect_symbols.sh` @ 9af0876; `workshop/evidence` @ 316ac99 |
| T015 | OPEN | VSC-046 | Queued | Implement the code-passage matching key (path, symbol) and the symbol_ | `submodules/passage/pkg/passage/symbol.go` @ ; `workshop/pipeline/symbols` @ bd7da41 |
| T016 | OPEN | VSC-047 | Queued | Implement the §8 ingest matching branches for code passages in submodu | `submodules/passage/pkg/passage/ingest_match.go` @ ; `workshop/pipeline/symbols` @ bd7da41 |
| T017 | OPEN | VSC-048 | Queued | Prove SC-016a via gate G-PID-4 in submodules/passage/pkg/passage/symbo | `submodules/passage` @ 13325b7; `submodules/passage/pkg/passage/symbol_test.go` @  |
| T018 | DONE | VDC-001 | Completed | Implement three-valued exit helpers in submodules/verdict/pkg/verdict/ | `submodules/verdict/pkg/verdict/verdict.go` @  |
| T019 | PARTIAL | WSP-005 | Queued | "* — with ffprobe exercised by -show_format -show_streams on a 1 s fix | `workshop/pipeline/detect_media.sh` @ c5bb3b2; `workshop/platform/gates/check-registry-001.tsv` @ a4190db |
| T020 | OPEN | WSP-006 | Queued | Implement backend/model detection in workshop/pipeline/detect_backend. | `workshop/pipeline/detect_backend.sh` @ c5bb3b2; `scripts/lumen-reindex.sh` @ 6fd4cb2 |
| T021 | PARTIAL | VSC-049 | Queued | Create workshop/scripts/{start,stop,status}.sh over a Go consuming ada | `workshop/scripts/start.sh` @ 185fb15; `workshop/platform/orchestration/cmd/workshop-boot/main.go` @ 36e5e48 |
| T022 | OPEN | VSC-050 | Queued | Review the passage contract implementation against (./contracts/passag | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T106 | PARTIAL | WSP-061 | Queued | Implement the shared wrapper library workshop/scripts/_common.sh contr | `workshop/scripts/_common.sh` @ 21508e6; `scripts/lumen-reindex.sh` @ 6fd4cb2 |
| T107 | OPEN | none | no register row | — NAMES only, no values, no paths-as-secrets. WHAT IS STILL GENUINELY | `workshop/scripts/verify-accuracy.sh` @ ff579df; `workshop/scripts/redact.sh` @ d85ca2d |
| T108 | DONE | WSP-063 | Completed | Implement workshop/scripts/build.sh per (./contracts/pipeline-cli.md) | `workshop/scripts/build.sh` @ 185fb15; `workshop/platform/bin` @  |
| T109 | DONE | WSP-064 | Completed | Implement workshop/scripts/restart.sh per (./contracts/pipeline-cli.md | `workshop/scripts/restart.sh` @ 185fb15 |
| T110 | UNVERIFIED | WSP-065 | Completed | Prove gate G-CLI-16 ((./contracts/pipeline-cli.md) §4.8, §5) — consump | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T023 | DONE | WSP-007 | Completed | Wire workshop/pipeline/transcribe/reassemble.sh to invoke the EXISTING | `workshop/scripts/extract-videos.sh` @ e6f6ee9; `workshop/scripts/install-hooks.sh` @ 5b611f9 |
| T024 | DONE | WSP-008 | Completed | Implement silence detection in workshop/pipeline/audio_energy.py produ | `workshop/pipeline/audio_energy.py` @ bd7da41 |
| T025 | DONE | WSP-009 | Completed | Implement ≤300 s chunking that cuts INSIDE measured silence, in worksh | `workshop/pipeline/transcribe/chunker.py` @ bd7da41; `workshop/pipeline/audio_energy.py` @ bd7da41 |
| T026 | DONE | WSP-010 | Completed | Implement the faster-whisper driver in workshop/pipeline/run_faster_wh | `workshop/pipeline/run_faster_whisper.py` @ 5b611f9 |
| T027 | DONE | WSP-011 | Completed | Map engine confidence (avg_logprob, no_speech_prob) to the uncertain f | `workshop/pipeline/run_faster_whisper.py` @ 5b611f9; `workshop/platform/backend/cmd/ingest-transcript/main.go` @ e196b34 |
| T028 | OPEN | WSP-012 | Queued | Implement atomic checkpoint/resume (write-temp → fsync → rename) in wo | `workshop/pipeline/transcribe/checkpoint.py` @ e6f6ee9; `workshop/pipeline/transcribe/chunker.py` @ bd7da41 |
| T029 | OPEN | WSP-013 | Queued | for the GATE — this task named workshop/pipeline/transcribe/coverage.p | `workshop/platform/backend/pkg/curriculum/curriculum.go` @ ff90e09 |
| T030 | OPEN | VSC-051 | Queued | Emit the markdown transcript with pid anchors and timestamps to worksh | `workshop/curriculum/chapter-01/transcript.md` @ 901f0cf; `workshop/chapters/01` @ a965971 |
| T031 | OPEN | VSC-052 | Queued | Implement the immutable machine layer + append-only correction overlay | `workshop/platform/backend/pkg/transcript/layers.go` @ e6f6ee9 |
| T032 | DONE | WSP-014 | Completed | Extract the notes PDF text layer in workshop/pipeline/transcribe/pdf_n | `workshop/pipeline/transcribe/pdf_notes.py` @ bd7da41 |
| T033 | DONE | WSP-015 | Completed | Implement the WER scorer in workshop/scripts/verify-accuracy.sh over w | `workshop/scripts/verify-accuracy.sh` @ ff579df; `workshop/pipeline/compare_engines.py` @ 5b611f9 |
| T034 | OPEN | WSP-016 | Queued | Freeze and hash the normaliser in workshop/pipeline/compare_engines.py | `workshop/pipeline/compare_engines.py` @ 5b611f9; `workshop/pipeline` @ a965971 |
| T035 | OPEN | WSP-017 | Queued | Paired mutation proof for the scorer in workshop/scripts/verify-accura | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T036 | UNVERIFIED | VSC-053 | Completed | Run the 5-minute calibration on the extracted 300 s sample; this settl | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T037 | OPEN | VSC-054 | Queued | Produce and publish the Chapter 1 accuracy report: the METHOD statemen | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T038 | DONE | WSP-018 | Completed | [THE PATH NOT BUILT NOTE IS WITHDRAWN — re-measured 2026-09-03 while w | `workshop/scripts/redact.sh` @ d85ca2d; `workshop/platform/backend/cmd/workshop-redact` @ e49c256 |
| T039 | DONE | WSP-019 | Completed | [TICKED 2026-09-03. THE PATH NOT BUILT NOTE IS WITHDRAWN — re-measured | `workshop/chapters/01/redaction-review.json` @ 83260ee |
| T040 | DONE | WSP-020 | Completed | Record the Chapter 1 redaction review and apply whatever it identifies | `workshop/curriculum/chapter-01/transcript.md` @ 901f0cf |
| T041 | OPEN | WSP-021 | Queued | Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the | `workshop/docs/session-evidence/t041-decision-packets.md` @ 5846bc2 |
| T111 | OPEN | none | no register row | Implement the workshop/scripts/transcribe.sh <chapter-slug> wrapper pe | `workshop/scripts/transcribe.sh` @ e6f6ee9 |
| T112 | DONE | WSP-067 | Completed | Implement the workshop/scripts/verify-accuracy.sh <chapter-slug> wrapp | `workshop/chapters/01/transcript/accuracy-plan.json` @ 5846bc2 |
| T113 | PARTIAL | none | no register row | Implement the workshop/scripts/ingest.sh wrapper per (./contracts/pipe | `workshop/scripts/ingest.sh` @ a4190db; `submodules/passage` @ 13325b7 |
| T121 | OPEN | none | no register row | Implement disk-space exhaustion handling in workshop/scripts/extract-v | `workshop/scripts/extract-videos.sh` @ e6f6ee9 |
| T122 | OPEN | none | no register row | Enforce the checksum manifest as a hard precondition of reassembly in | `workshop/scripts/extract-videos.sh` @ e6f6ee9 |
| T042 | DONE | WSP-022 | Completed | Implement the chapter model + store in workshop/platform/backend/pkg/c | `workshop/platform/backend/pkg/curriculum/curriculum.go` @ ff90e09 |
| T043 | UNVERIFIED | VSC-055 | Completed | Implement GET /api/chapters and GET /api/chapters/{slug} per (./contra | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T044 | UNVERIFIED | VSC-056 | Completed | Implement GET /api/chapters/{slug}/transcript returning passages with | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T045 | DONE | WSP-023 | Completed | Implement local recording range-serve with seek in workshop/platform/b | `workshop/platform/backend/internal/api/recording.go` @ f13e644 |
| T046 | DONE | WSP-024 | Completed | Build the chapter list and detail views in workshop/platform/frontend/ | `workshop/platform/frontend/src/app/features/chapters` @ 94e1dc3 |
| T047 | DONE | WSP-025 | Completed | Build the transcript reader with timestamp→recording seek in workshop/ | `workshop/platform/frontend/src/app/features/transcript` @ 5b00c30 |
| T048 | DONE | VSC-057 | Completed | Reuse design-system/learning-kit/ curriculum CSS (verified present, fr | `design-system/learning-kit` @ 12ecc0b |
| T049 | DONE | WSP-026 | Completed | Persist reader position/progress per FR-010 — (population: source) (FR | `workshop/platform/backend/internal/api/progress.go` @ 94e1dc3 |
| T050 | DONE | WSP-027 | Completed | Prove SC-003: transcript passage → recording seek lands within 5 s, in | `workshop/platform/frontend/src/app/features/transcript/seek.spec.ts` @ a3b0a73 |
| T051 | OPEN | none | no register row | Write workshop/docs/quickstart.md and time a fresh-clone-to-running ru | `workshop/docs/quickstart.md` @ 6130d6b; `workshop/evidence` @ 316ac99 |
| T114 | OPEN | none | no register row | Prove gate G-CLI-15 ((./contracts/pipeline-cli.md) §4.8, §5) — the con | `workshop/platform/orchestration/cmd/workshop-boot` @ 36e5e48; `workshop/platform/bin/workshop-boot` @  |
| T123 | OPEN | none | no register row | Implement the explicit "no chapters available yet" state: GET /api/cha | `workshop/platform/frontend/src/app/features/chapters` @ 94e1dc3 |
| T124 | OPEN | none | no register row | Implement loopback-only-by-default access control as shared middleware | `workshop/platform/backend/internal/api` @ 72c565e |
| T125 | OPEN | none | no register row | Convey passage uncertainty (FR-003) in workshop/platform/frontend/src/ | `workshop/platform/frontend/src/app/features/transcript` @ 5b00c30 |
| T126 | OPEN | none | no register row | Make the recording player's controls — play, pause, seek, and "jump to | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T052 | DONE | WSP-029 | Completed | Implement the lexical FTS5 prefix index in workshop/platform/backend/p | `workshop/platform/backend/pkg/search/lexical.go` @ 6e482b8 |
| T053 | UNVERIFIED | VSC-058 | Completed | Implement GET /api/suggest backed by the LEXICAL path only — a query e | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T054 | DONE | WSP-030 | Completed | Implement the semantic leg in workshop/platform/backend/pkg/search/sem | `workshop/platform/backend/pkg/search/semantic.go` @ 50743ba |
| T055 | DONE | WSP-031 | Completed | Implement the three-state contract in workshop/platform/backend/pkg/se | `workshop/platform/backend/pkg/search/envelope.go` @ 50743ba |
| T056 | UNVERIFIED | VSC-059 | Completed | Parse and promote Lumen's glued "No results found. / Warning: Index is | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T057 | UNVERIFIED | AII-001 | Completed | Prove gate G-HTTP-7 ((./contracts/http-api.md) §5) — the frontend half | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T058 | DONE | WSP-032 | Completed | Implement index generations with a verification gate and atomic swap i | `workshop/platform/backend/pkg/index/generation.go` @ 25ce01d |
| T059 | PARTIAL | VSC-060 | Queued | Enforce redaction rules R1 and R5 in workshop/platform/backend/pkg/ind | `submodules/passage` @ 13325b7 |
| T060 | DONE | WSP-033 | Completed | Implement cross-reference derivation and storage in workshop/platform/ | `workshop/platform/backend/pkg/crossref` @ e49c256 |
| T061 | DONE | WSP-034 | Completed | Enforce redaction rule R3 in workshop/platform/backend/pkg/crossref/ a | `workshop/platform/backend/pkg/crossref` @ e49c256 |
| T062 | UNVERIFIED | VSC-061 | Completed | Build the search UI with type-ahead in workshop/platform/frontend/src/ | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T063 | DONE | WSP-035 | Completed | WCAG 2.1 AA + full keyboard operability for search (FR-041, FR-042, SC | `_tests/evidence/a11y-audit/run-audit.js` @ 4479ccad; `workshop/platform/frontend/e2e/a11y-responsive.spec.ts` @ e6f6ee9 |
| T064 | DONE | WSP-036 | Completed | Build the ≥20-query retrieval benchmark in workshop/platform/backend/t | `workshop/pipeline/benchmark/retrieval_benchmark.json` @ 56bce2b; `workshop/platform/backend/testdata/benchmark/retrieval.tsv` @ a3b0a73 |
| T065 | DONE | WSP-037 | Completed | Measure and record p95 latencies for suggest and search (SC-005, SC-00 | `workshop/platform/backend/cmd/bench/main.go` @ 11ed64a |
| T066 | UNVERIFIED | VSC-062 | Completed | Prove SC-016 and gate G-PID-3 ((./contracts/passage-contract.md) §5.3) | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T067 | OPEN | WSP-038 | Queued | Document the media boundary in workshop/docs/search.md — audio and vid | `workshop/docs/search.md` @ 11ed64a |
| T115 | OPEN | WSP-069 | Queued | Implement the workshop/scripts/index.sh wrapper per (./contracts/pipel | `workshop/scripts/index.sh` @ ff579df; `scripts/ollama-tune.sh` @ 59ea607 |
| T116 | OPEN | WSP-070 | Queued | Implement the workshop/scripts/crossref.sh wrapper per (./contracts/pi | `workshop/scripts/crossref.sh` @ 11ed64a; `workshop/platform/backend/pkg/crossref` @ e49c256 |
| T117 | UNVERIFIED | VSC-080 | Completed | Prove gate G-HTTP-6 ((./contracts/http-api.md) §5): over 100 randomise | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T118 | DONE | WSP-071 | Completed | Build workshop/scripts/bench-retrieval.sh per (./quickstart.md) US3 st | `workshop/scripts/bench-retrieval.sh` @ eba5c17 |
| T127 | OPEN | none | no register row | Make index rebuild incremental in workshop/platform/backend/pkg/index/ | `workshop/platform/backend/pkg/index/generation.go` @ 25ce01d |
| T128 | OPEN | none | no register row | Prove SC-022: with at least 5 concurrent simulated clients issuing /ap | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T068 | DONE | VSC-063 | Completed | Implement the Provider interface with adapters none (default), extract | `workshop/platform/backend/pkg/answer/provider.go` @ 14a6ca6; `submodules/LLMProvider` @ baf80cc |
| T069 | UNVERIFIED | VSC-064 | Completed | Implement the extractive adapter — ~0.3 s, genuinely grounded, structu | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T070 | UNVERIFIED | VSC-065 | Completed | Implement L1: the calibrated retrieval gate with BOTH min_score and mi | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T071 | UNVERIFIED | VSC-066 | Completed | Implement L2: JSON-schema-constrained generation where "minItems": 1 o | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T072 | UNVERIFIED | VSC-067 | Completed | Implement L3: deterministic citation pid set-membership against the LI | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T073 | PARTIAL | WSP-039 | Queued | Implement L4: support verification (embedding floor, then batched enta | `workshop/pipeline/venv` @  |
| T074 | UNVERIFIED | VSC-068 | Completed | Any layer failing ⇒ refuse the WHOLE answer; never strip claims silent | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T075 | PARTIAL | VSC-069 | Queued | Enforce redaction rule R4 and (./contracts/http-api.md) §3.10 A4 (FR-0 | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T076 | PARTIAL | WSP-040 | Queued | Prove G-PID-5 end to end ((./contracts/passage-contract.md) §7.3) — th | `workshop/platform/gates/verify-redaction-propagation.sh` @ 0e5df52 |
| T077 | DONE | WSP-041 | Completed | Build the ≥10-question adversarial unanswerable set as the U rows of w | `workshop/platform/backend/testdata/benchmark/questions.tsv` @ 5b611f9 |
| T078 | OPEN | none | no register row | [PATH CORRECTED 2026-09-02 — this task named workshop/scripts/bench-an | `workshop/platform/backend/gates/bench-answers.sh` @ 11ed64a; `workshop/platform/backend/evidence/answering/bench-question-verifier-ab-2026-09-02.tsv` @ 692a27a |
| T079 | OPEN | WSP-043 | Queued | [PATH CORRECTED 2026-09-02 — T078's harness is workshop/platform/backe | `workshop/platform/backend/gates/bench-answers.sh` @ 11ed64a |
| T080 | PARTIAL | WSP-044 | Queued | Enforce FR-024 privacy: resolved-address allowlist (net.LookupIP + IsL | `workshop/pipeline/venv` @  |
| T081 | PARTIAL | none | no register row | Enforce FR-025 by SEPARATE ROUTE TREES at compile time — browsing and | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T082 | UNVERIFIED | VSC-071 | Completed | Implement the ingest exclusive lock that suspends answering while sear | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T083 | OPEN | WSP-045 | Queued | Document in workshop/docs/answering.md that answering is ASYNCHRONOUS | `workshop/docs/answering.md` @ 11ed64a; `workshop/docs/limits.md` @ b7b857a |
| T129 | OPEN | none | no register row | Discard partial answer output on mid-generation failure or disconnect | `workshop/platform/backend/pkg/answer/pipeline.go` @ 11ed64a |
| T084 | OPEN | WSP-046 | Queued | (transcribe.sh T111, index.sh T115, crossref.sh T116, redact.sh T038/T | `workshop/scripts/add-chapter.sh` @ 839d7e1; `workshop/scripts` @ a4190db |
| T085 | OPEN | VSC-072 | Queued | Prove idempotency (FR-027) as gate G-CLI-7 ((./contracts/pipeline-cli. | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T086 | OPEN | VSC-073 | Queued | Incomplete materials MUST report precisely what is missing and MUST NO | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T087 | OPEN | VSC-074 | Queued | Enforce the publish preconditions B1–B6 of (./contracts/pipeline-cli.m | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T088 | OPEN | WSP-047 | Queued | Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempot | `workshop/pipeline/extract/fixtures/synthetic_chapter/passages.jsonl` @ 53c33d0; `workshop/platform/backend/cmd/fixture-corpus/main.go` @ 1235b6c |
| T089 | DONE | WSP-048 | Completed | Write the reusable extension prompt in workshop/docs/prompts/add-a-cha | `workshop/docs/prompts/add-a-chapter.md` @ 9af0876 |
| T090 | OPEN | VSC-075 | Queued | Prove SC-011: a new chapter integrated in under 30 minutes hands-on wi | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T130 | OPEN | none | no register row | Detect and refuse a genuinely concurrent second invocation of workshop | `workshop/scripts/add-chapter.sh` @ 839d7e1 |
| T091 | DONE | WSP-049 | Completed | Write workshop/docs/user-guide.md (FR-030) | `workshop/docs/user-guide.md` @ 6130d6b |
| T092 | DONE | WSP-050 | Completed | Write workshop/docs/manual.md (operator) (FR-030) | `workshop/docs/manual.md` @ d843b55 |
| T093 | DONE | WSP-051 | Completed | Write workshop/docs/faq.md (FR-030) | `workshop/docs/faq.md` @ 6130d6b |
| T094 | DONE | WSP-052 | Completed | Write the training material under workshop/docs/training/ — — find wor | `workshop/docs/training` @ 6711de7; `workshop/docs/quickstart.md` @ 6130d6b |
| T095 | PARTIAL | WSP-053 | Queued | Document every limit honestly per FR-031: no direct media indexing, as | `workshop/docs/limits.md` @ b7b857a |
| T096 | OPEN | none | no register row | Register every check this feature adds in scripts/check-registry.tsv s | `scripts/check-registry.tsv` @ aa78155; `scripts/verify-check-registry.sh` @ 63fae39 |
| T097 | PARTIAL | WSP-055 | Queued | Verify EVERY feature check has a paired mutation proof including a rea | `workshop/platform/gates` @ 83ffa49; `workshop/platform/backend/gates` @ babdc1d |
| T098 | PARTIAL | WSP-056 | Queued | Verify EVERY feature check distinguishes could-not-determine from pass | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T099 | OPEN | WSP-057 | Queued | Write machine evidence to workshop/evidence/ retained with the commit | `workshop/evidence` @ 316ac99; `workshop/platform/backend/evidence` @ 467b15f |
| T131 | OPEN | none | no register row | Route this feature's automated-check evidence that could contain trans | `workshop/evidence` @ 316ac99; `_tests/evidence` @ 7a4a831 |
| T100 | UNVERIFIED | WSP-058 | Completed | Confirm zero CI added anywhere as gate G-CLI-11 ((./contracts/pipeline | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T101 | UNVERIFIED | VSC-076 | Completed | Update CONTINUATION.md and confirm bash scripts/continuation-check.sh | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T102 | UNVERIFIED | WSP-059 | Completed | Confirm workshop/'s four governance carriers remain in lockstep — bash | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T103 | UNVERIFIED | VSC-077 | Completed | Run the whole gate suite green: pre-push-gates, verify-governance-casc | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T104 | OPEN | none | no register row | Commit and push the umbrella and every submodule to all upstreams; ver | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T119 | OPEN | WSP-072 | Queued | excluded, the identifier occurs exactly once anywhere under workshop/ | tasks.md checkbox + register provenance only; no resolvable path in task text |
| T120 | PARTIAL | WSP-073 | Queued | , naming FAIL: G12 verify-retrieval-benchmark.sh and COULD-NOT-RUN: G8 | `workshop/scripts/verify.sh` @ babdc1d |
| T105 | PARTIAL | none | no register row | Final review against spec.md — every FR traced, every SC measured or e | `specs/001-workshop-curriculum-platform/review.md` @ 402a8c7 |

## 5. Functional requirements (FR)

| FR | Text (truncated) | Status | Basis |
|---|---|---|---|
| FR-001 | System MUST produce a complete written transcript of each chapter's re | PARTIAL | cited by T024, T025, T026, T029, T030, T111: 3 done / 6 |
| FR-002 | System MUST associate each transcript passage with a timestamp locatin | PARTIAL | cited by T030, T044, T047, T050: 2 done / 4 |
| FR-003 | System MUST explicitly mark passages that could not be transcribed wit | PARTIAL | cited by T026, T027, T044, T125: 2 done / 4 |
| FR-004 | System MUST produce a verification report stating measured transcript  | PARTIAL | cited by T033, T034, T035, T037, T087, T112: 2 done / 6 |
| FR-005 | System MUST attribute passages to distinct speakers where the recordin | OPEN | cited by T041: none done |
| FR-006 | System MUST preserve the original recording and all supporting materia | PARTIAL | cited by T023, T032, T111: 2 done / 3 |
| FR-007 | System MUST reassemble split recordings automatically and verify their | PARTIAL | cited by T023, T122: 1 done / 2 |
| FR-056 | If the host runs out of disk space during reassembly or transcription, | OPEN | cited by T121: none done |
| FR-057 | If the checksum manifest required by FR-007 is itself missing or corru | OPEN | cited by T122: none done |
| FR-008 | System MUST present chapters as a browsable curriculum with titles and | UNVERIFIED | cited by T042, T043, T046: ticked, checkbox-only on some |
| FR-009 | Users MUST be able to read a chapter's transcript and materials, and p | UNVERIFIED | cited by T044, T045, T047: ticked, checkbox-only on some |
| FR-010 | System MUST preserve a user's position and progress within a chapter. | DONE | cited by T049: all DONE (file-existence basis, no re-run) |
| FR-011 | System MUST organise each chapter's content into navigable sections ra | DONE | cited by T032: all DONE (file-existence basis, no re-run) |
| FR-012 | System MUST be startable and stoppable through documented commands tha | PARTIAL | cited by T005, T021, T051, T108, T109, T114: 3 done / 6 |
| FR-013 | System MUST follow the organisational conventions already established  | PARTIAL | cited by T001, T002, T004, T006: 3 done / 4 |
| FR-049 | System MUST present an explicit "no chapters available yet" state when | OPEN | cited by T123: none done |
| FR-055 | System MUST support at least 5 concurrent users performing search and  | OPEN | cited by T128: none done |
| FR-014 | System MUST return results matching a query by meaning, including when | DONE | cited by T054, T118: all DONE (file-existence basis, no re-run) |
| FR-015 | System MUST offer suggestions as the user types. | UNVERIFIED | cited by T052, T053, T062: ticked, checkbox-only on some |
| FR-016 | System MUST index all curriculum content types: transcripts, written d | OPEN | cited by T067: none done |
| FR-017 | System MUST take a user from a search result to the exact passage in i | UNVERIFIED | no task in tasks.md cites this id |
| FR-018 | System MUST offer cross-references from any passage to related materia | PARTIAL | cited by T060, T061, T116: 2 done / 3 |
| FR-019 | System MUST state plainly when a search has no relevant match, and MUS | UNVERIFIED | cited by T055, T057, T062: ticked, checkbox-only on some |
| FR-020 | System MUST report honestly when search is unavailable or degraded, an | PARTIAL | cited by T055, T056, T057, T058, T059, T062, T081, T115…: 2 done / 9 |
| FR-058 | Indexing MUST be incremental: adding one chapter MUST index only that  | OPEN | cited by T127: none done |
| FR-021 | System MUST answer natural-language questions about indexed content, r | PARTIAL | cited by T068, T069, T071, T072, T073, T079: 1 done / 6 |
| FR-022 | System MUST decline to answer when the indexed content does not suppor | PARTIAL | cited by T070, T073, T074, T075, T078: 0 done / 5 |
| FR-023 | System MUST support both locally-hosted and externally-hosted answerin | PARTIAL | cited by T020, T068, T069: 1 done / 3 |
| FR-024 | System MUST NOT transmit curriculum content outside the machine when c | PARTIAL | cited by T080: 0 done / 1 |
| FR-025 | System MUST continue to serve browsing and search when answering is un | PARTIAL | cited by T081, T082: 0 done / 2 |
| FR-053 | If answer generation fails or disconnects after it has started produci | OPEN | cited by T129: none done |
| FR-026 | System MUST provide a single documented, repeatable procedure that ing | PARTIAL | cited by T084, T089, T090: 1 done / 3 |
| FR-027 | The extension procedure MUST be idempotent: running it twice on the sa | PARTIAL | cited by T085, T088, T113: 0 done / 3 |
| FR-028 | The extension procedure MUST report precisely what is missing when a c | OPEN | cited by T084, T086, T087: none done |
| FR-029 | Long-running processing MUST be resumable and MUST report progress, wi | PARTIAL | cited by T026, T028, T084, T111: 1 done / 4 |
| FR-054 | The extension procedure MUST detect a concurrent invocation against th | OPEN | cited by T130: none done |
| FR-030 | System MUST ship user-facing documentation covering: a quick-start tut | PARTIAL | cited by T051, T083, T089, T091, T092, T093, T094: 5 done / 7 |
| FR-031 | Documentation MUST state honestly what the system cannot do, including | PARTIAL | cited by T067, T083, T095: 0 done / 3 |
| FR-032 | Every automated check MUST be accompanied by evidence that it can fail | PARTIAL | cited by T013, T014, T017, T019, T021, T035, T053, T055…: 5 done / 32 |
| FR-033 | System MUST NOT report a check as passed when it could not actually ru | PARTIAL | cited by T011, T014, T018, T019, T021, T055, T078, T096…: 8 done / 22 |
| FR-034 | The feature MUST NOT introduce any server-side continuous-integration  | UNVERIFIED | cited by T007, T100: ticked, checkbox-only on some |
| FR-035 | All governance carrier documents MUST remain synchronised, and the con | UNVERIFIED | cited by T101, T102, T103: ticked, checkbox-only on some |
| FR-036 | All work MUST be committed and pushed across the main repository and e | OPEN | cited by T104: none done |
| FR-050 | Automated-check evidence that could contain transcript excerpts, speak | OPEN | cited by T131: none done |
| FR-037 | Every passage MUST carry a stable identifier assigned at ingest that i | PARTIAL | cited by T008, T009, T010, T011, T013, T015, T016, T022…: 5 done / 11 |
| FR-038 | System MUST preserve machine-generated transcript output immutably, an | PARTIAL | cited by T031, T044: 0 done / 2 |
| FR-039 | System MUST provide a documented redaction step capable of suppressing | PARTIAL | cited by T012, T038, T039, T040, T059, T061, T075, T076…: 5 done / 11 |
| FR-051 | Any access to the curriculum from other than the operator's own loopba | OPEN | cited by T124: none done |
| FR-043 | Every component and service this feature produces MUST be usable indep | UNVERIFIED | no task in tasks.md cites this id |
| FR-044 | Components MUST be placed where another project can consume them. Lang | DONE | cited by T008, T018: all DONE (file-existence basis, no re-run) |
| FR-045 | Each reusable component MUST be independently testable — its test suit | UNVERIFIED | no task in tasks.md cites this id |
| FR-046 | Before scaffolding any new component, the canonical submodule catalogu | UNVERIFIED | cited by T003, T048, T110: ticked, checkbox-only on some |
| FR-047 | Each genuinely new reusable component MUST live in **its own repositor | DONE | cited by T008, T018: all DONE (file-existence basis, no re-run) |
| FR-048 | Every such reusable repository MUST be **public**. It therefore MUST N | UNVERIFIED | no task in tasks.md cites this id |
| FR-040 | System MUST write the evidence produced by its automated checks to a v | PARTIAL | cited by T014, T099, T107, T119, T120: 1 done / 5 |
| FR-041 | The curriculum interface MUST meet WCAG 2.1 Level AA. | DONE | cited by T063: all DONE (file-existence basis, no re-run) |
| FR-042 | Search MUST be fully operable by keyboard alone, including entering a  | DONE | cited by T063: all DONE (file-existence basis, no re-run) |
| FR-052 | A passage marked uncertain (FR-003) MUST be conveyed with a text label | OPEN | cited by T125: none done |
| FR-059 | Playback controls — play, pause, seek, and jumping to a timestamp from | OPEN | cited by T126: none done |

## 6. Success criteria (SC)

| SC | Text (truncated) | Status | Basis |
|---|---|---|---|
| SC-001 | A reader can read the complete Chapter 1 session as text, covering 100 | PARTIAL | cited by T024, T025, T029: 2 done / 3 |
| SC-002 | Transcript accuracy is measured on a random sample of at least 30 pass | PARTIAL | cited by T033, T034, T037, T112: 2 done / 4 |
| SC-003 | A reader can move from any transcript passage to the corresponding mom | PARTIAL | cited by T045, T047, T050, T126: 3 done / 4 |
| SC-004 | A new user can go from a fresh clone to a running curriculum in under  | UNVERIFIED | no timing evidence located by this package; review.md 2026-09-03 recorded UNMEASURED; re-check by human |
| SC-005 | Search suggestions appear within 200 milliseconds of a keystroke, meas | PARTIAL | cited by T052, T053, T065, T128: 2 done / 4 |
| SC-006 | Search results return within 2 seconds at the 95th percentile. | PARTIAL | cited by T065, T115, T128: 1 done / 3 |
| SC-007 | On a benchmark set of at least 20 meaning-based queries with known exp | DONE | cited by T054, T064, T118: all DONE (file-existence basis, no re-run) |
| SC-008 | At least 80% of the benchmark queries succeed when the query shares no | DONE | cited by T054, T064, T118: all DONE (file-existence basis, no re-run) |
| SC-009 | 100% of citations in generated answers resolve to passages that genuin | PARTIAL | count floor (>=20 answerable) recorded met in tasks.md; human certification of citation support NOT recorded (UNCONFIRMED) |
| SC-010 | On a set of at least 10 questions the content cannot answer, the syste | OPEN | UNMET: measured fabrication 4/87 = 4.6% (workshop 467b15f); answering turned OFF 2026-09-25 (operator decision) |
| SC-011 | A maintainer can add a new chapter using only the documented procedure | OPEN | cited by T090: none done |
| SC-012 | Every automated check in the feature has a paired demonstration that i | PARTIAL | cited by T013, T014, T017, T019, T021, T035, T053, T055…: 5 done / 32 |
| SC-013 | The system distinguishes "unable to verify" from "passed" and "failed" | PARTIAL | cited by T018, T019, T021, T096, T098, T106, T107, T108…: 3 done / 14 |
| SC-014 | The repository introduces zero active server-side CI workflows. | DONE | `git -C workshop ls-files` lists zero workflow files (read-only check, this session) |
| SC-015 | After completion, the main repository and every submodule report a cle | OPEN | workshop working tree has 6 modified/untracked paths; gitlink pin lags HEAD by 34 commits; nothing pushed |
| SC-016 | After a transcript is corrected and the content re-indexed, **100%** o | PARTIAL | cited by T008, T009, T013, T066, T088, T113: 3 done / 6 |
| SC-016a | For passages in source code the curriculum does NOT own, where an iden | PARTIAL | cited by T011, T014, T015, T016, T017, T095: 2 done / 6 |
| SC-017 | The curriculum interface passes an automated WCAG 2.1 Level AA audit w | DONE | cited by T063: all DONE (file-existence basis, no re-run) |
| SC-018 | 100% of automated checks write their evidence to the repository's vers | PARTIAL | cited by T099, T107, T120: 0 done / 3 |
| SC-019 | Every component identified as reusable can be imported and exercised b | UNVERIFIED | no task in tasks.md cites this id |
| SC-020 | 100% of reusable components resolve from a public repository under an  | UNVERIFIED | no task in tasks.md cites this id |
| SC-021 | 100% of public reusable repositories contain zero workshop content, ve | DONE | cited by T063: all DONE (file-existence basis, no re-run) |
| SC-022 | At least 5 concurrent users can search and browse simultaneously witho | OPEN | cited by T128: none done |
| SC-023 | Adding a new chapter re-indexes only that chapter — index-build time f | OPEN | cited by T127: none done |

The 2026-09-03 `review.md` §7 state for comparison: FAILING SC-001, SC-010; NOT MET SC-015, SC-018; MET SC-005 (ad hoc), SC-014, SC-016; the rest UNMEASURED or PARTIAL. It predates later work and has not been re-derived here.

## 7. Open predecessors blocking T105

59 open or partial tasks besides T105 (the item says "~50"; tasks.md says 56 unticked on 2026-09-03; now 60 unticked including T105). Grouped by the owner named in the task text.

### Owner: operator (5)

| Task | Status | Register | Label |
|---|---|---|---|
| T006 | OPEN | VSC-045 | Configure linting/formatting to match the reference module (gofmt, Ang |
| T041 | OPEN | WSP-021 | Human review checkpoint: speaker attribution is HUMAN (D-TRANS-2 — the |
| T073 | PARTIAL | WSP-039 | Implement L4: support verification (embedding floor, then batched enta |
| T099 | OPEN | WSP-057 | Write machine evidence to workshop/evidence/ retained with the commit |
| T104 | OPEN | none | Commit and push the umbrella and every submodule to all upstreams; ver |

### Owner: human reviewer (1)

| Task | Status | Register | Label |
|---|---|---|---|
| T022 | OPEN | VSC-050 | Review the passage contract implementation against (./contracts/passag |

### Owner: implementer (42)

| Task | Status | Register | Label |
|---|---|---|---|
| T015 | OPEN | VSC-046 | Implement the code-passage matching key (path, symbol) and the symbol_ |
| T016 | OPEN | VSC-047 | Implement the §8 ingest matching branches for code passages in submodu |
| T017 | OPEN | VSC-048 | Prove SC-016a via gate G-PID-4 in submodules/passage/pkg/passage/symbo |
| T019 | PARTIAL | WSP-005 | "* — with ffprobe exercised by -show_format -show_streams on a 1 s fix |
| T020 | OPEN | WSP-006 | Implement backend/model detection in workshop/pipeline/detect_backend. |
| T021 | PARTIAL | VSC-049 | Create workshop/scripts/{start,stop,status}.sh over a Go consuming ada |
| T106 | PARTIAL | WSP-061 | Implement the shared wrapper library workshop/scripts/_common.sh contr |
| T107 | OPEN | none | — NAMES only, no values, no paths-as-secrets. WHAT IS STILL GENUINELY |
| T028 | OPEN | WSP-012 | Implement atomic checkpoint/resume (write-temp → fsync → rename) in wo |
| T029 | OPEN | WSP-013 | for the GATE — this task named workshop/pipeline/transcribe/coverage.p |
| T030 | OPEN | VSC-051 | Emit the markdown transcript with pid anchors and timestamps to worksh |
| T031 | OPEN | VSC-052 | Implement the immutable machine layer + append-only correction overlay |
| T034 | OPEN | WSP-016 | Freeze and hash the normaliser in workshop/pipeline/compare_engines.py |
| T035 | OPEN | WSP-017 | Paired mutation proof for the scorer in workshop/scripts/verify-accura |
| T037 | OPEN | VSC-054 | Produce and publish the Chapter 1 accuracy report: the METHOD statemen |
| T111 | OPEN | none | Implement the workshop/scripts/transcribe.sh <chapter-slug> wrapper pe |
| T113 | PARTIAL | none | Implement the workshop/scripts/ingest.sh wrapper per (./contracts/pipe |
| T051 | OPEN | none | Write workshop/docs/quickstart.md and time a fresh-clone-to-running ru |
| T114 | OPEN | none | Prove gate G-CLI-15 ((./contracts/pipeline-cli.md) §4.8, §5) — the con |
| T059 | PARTIAL | VSC-060 | Enforce redaction rules R1 and R5 in workshop/platform/backend/pkg/ind |
| T067 | OPEN | WSP-038 | Document the media boundary in workshop/docs/search.md — audio and vid |
| T115 | OPEN | WSP-069 | Implement the workshop/scripts/index.sh wrapper per (./contracts/pipel |
| T116 | OPEN | WSP-070 | Implement the workshop/scripts/crossref.sh wrapper per (./contracts/pi |
| T075 | PARTIAL | VSC-069 | Enforce redaction rule R4 and (./contracts/http-api.md) §3.10 A4 (FR-0 |
| T076 | PARTIAL | WSP-040 | Prove G-PID-5 end to end ((./contracts/passage-contract.md) §7.3) — th |
| T078 | OPEN | none | [PATH CORRECTED 2026-09-02 — this task named workshop/scripts/bench-an |
| T079 | OPEN | WSP-043 | [PATH CORRECTED 2026-09-02 — T078's harness is workshop/platform/backe |
| T080 | PARTIAL | WSP-044 | Enforce FR-024 privacy: resolved-address allowlist (net.LookupIP + IsL |
| T081 | PARTIAL | none | Enforce FR-025 by SEPARATE ROUTE TREES at compile time — browsing and |
| T083 | OPEN | WSP-045 | Document in workshop/docs/answering.md that answering is ASYNCHRONOUS |
| T084 | OPEN | WSP-046 | (transcribe.sh T111, index.sh T115, crossref.sh T116, redact.sh T038/T |
| T085 | OPEN | VSC-072 | Prove idempotency (FR-027) as gate G-CLI-7 ((./contracts/pipeline-cli. |
| T086 | OPEN | VSC-073 | Incomplete materials MUST report precisely what is missing and MUST NO |
| T087 | OPEN | VSC-074 | Enforce the publish preconditions B1–B6 of (./contracts/pipeline-cli.m |
| T088 | OPEN | WSP-047 | Make the procedure accept a PRE-SUPPLIED TRANSCRIPT FIXTURE so idempot |
| T090 | OPEN | VSC-075 | Prove SC-011: a new chapter integrated in under 30 minutes hands-on wi |
| T095 | PARTIAL | WSP-053 | Document every limit honestly per FR-031: no direct media indexing, as |
| T096 | OPEN | none | Register every check this feature adds in scripts/check-registry.tsv s |
| T097 | PARTIAL | WSP-055 | Verify EVERY feature check has a paired mutation proof including a rea |
| T098 | PARTIAL | WSP-056 | Verify EVERY feature check distinguishes could-not-determine from pass |
| T119 | OPEN | WSP-072 | excluded, the identifier occurs exactly once anywhere under workshop/ |
| T120 | PARTIAL | WSP-073 | , naming FAIL: G12 verify-retrieval-benchmark.sh and COULD-NOT-RUN: G8 |

### owner not stated in task text (11)
T121, T122, T123, T124, T125, T126, T127, T128, T129, T130, T131

### Which of these the operator already decided

- Decision #19 (2026-10-14): VSC-078 package drafted (this file). WSP-028 and VSC-300 are agent-run (not spec-001 task rows).
- Decisions #17 (workshop backlog gates W1/W2: VSC-070, 079, 125, 301, WSP-054, 062, 125, 167, 168) and #18 (WSP-068 yes, WSP-066 deferred) concern zero-gap register items; none of those ids is a spec-001 task row in the mapping above. Whether finishing them closes any T-task is UNCONFIRMED.
- Decision #22 (material downloads kept for signed-in users, audit what is served) and #23 (`source_ref.path` redacted centrally) touch served content; their link to specific T-tasks is UNCONFIRMED.
- Decision #5: workshop stays loopback-only until the /media review is GO.
- No decision found that closes any of the operator-owned tasks above (T006, T041, T073, T099, T104).

## 8. Human review checklist

1. [ ] SC-004 fresh clone to running in 15 min: no timing evidence found by this package. Pointers: `specs/001-workshop-curriculum-platform/quickstart.md`, `workshop/scripts/verify-standalone-clone.sh`.
2. [ ] SC-009 citation support: confirm the human certification over >=20 answers exists or is recorded as missing. Pointers: tasks.md lines ~254-267; `review.md` §7.
3. [ ] SC-010 / SC-094 answering decision: answering OFF since 2026-09-25; confirm the OFF state is what ships. Pointers: workshop `467b15f`, `compose` default `WORKSHOP_ANSWER_PROVIDER` none.
4. [ ] Fabrication rate 4.6% (4/87) is the measured basis of the OFF decision. Pointers: workshop `467b15f` measurement file under `platform/backend/evidence/answering/`.
5. [ ] SC-001 coverage identity and SC-002 accuracy: confirm current measured values, not the 2026-09-03 ones. Pointers: `workshop/platform/gates/`, `workshop/scripts/verify-accuracy.sh`.
6. [ ] SC-015 clean trees and pushed: workshop has 6 uncommitted paths, nothing pushed. Pointers: `git -C workshop status --short`, `git ls-remote`.
7. [ ] Workshop gitlink `fb798e98c998` lags workshop HEAD by 34 commits; a bump is an operator decision. Pointers: `git ls-files -s workshop`.
8. [ ] Content-boundary gate is RED by design; read the survivors, do not treat green/red as clearance. Pointers: `scripts/verify-content-boundary.sh`, `docs/content-boundary.md`, `docs/content-boundary-judgement-2026-10-14/`.
9. [ ] Security exposures fixed 2026-10-14: confirm each fix has a recorded verification. Pointers: `docs/operator-decisions-2026-10-14-session.md` #4, #22, #23; register rows (ids UNCONFIRMED here).
10. [ ] Signed-in material downloads: audit what is served matches decision #22. Pointers: workshop serving routes; audit output (not located by this package).
11. [ ] `source_ref.path` redaction at serialisation (decision #23): confirm no raw path in API responses. Pointers: workshop API handlers (location UNCONFIRMED).
12. [ ] LAN exposure stays loopback-only (decision #5). Pointers: compose bind addresses in the workshop deploy files.
13. [ ] T041 and T104 are operator-only: read the BLOCKED text and decide. Pointers: tasks.md T041, T104.
14. [ ] T006 lint baseline: pick one or withdraw the claim. Pointers: tasks.md T006 (VSC-045).
15. [ ] T073 needs a host that can run it, or an explicit record. Pointers: tasks.md T073.
16. [ ] T099 move-vs-mirror decision. Pointers: tasks.md T099.
17. [ ] PARTIAL tasks: decide if each remainder is acceptable (15 listed in section 4). Pointers: section 4, status PARTIAL.
18. [ ] UNVERIFIED ticked tasks (21): sample a few, re-run their gate, or accept checkbox evidence. Pointers: section 4, status UNVERIFIED; register `item_provenance.evidence_class`.
19. [ ] FRs with no citing task: decide trace or waive. Pointers: section 5, UNVERIFIED rows.
20. [ ] SC-012 / SC-013 paired-proof and three-valued coverage across all gates. Pointers: `workshop/platform/gates/check-registry-*.tsv`.
21. [ ] SC-014 no active server-side CI in the workshop repo (this package: zero workflow files tracked). Pointers: `git -C workshop ls-files`.
22. [ ] Umbrella gates 0-6 green without bypass before any push (decision #8). Pointers: `scripts/pre-push-gates.sh`.
23. [ ] Spec 001 vs 002 id collision: confirm each cited gate belongs to the intended spec. Pointers: tasks.md lines 21-26.

## 9. Known risks and limits

- Answering fabrication was measured at 4/87 = 4.6% (Wilson 95% 2-11%); 3 of the 4 were one question repeated. SC-010 and SC-094 are UNMET. Answering is OFF by operator decision (2026-09-25); semantic search stays on.
- Material downloads: kept for signed-in users (decision #22); what is served has not been audited by this package.
- Workshop gitlink is not bumped (pin `fb798e98c998`, workshop HEAD `83ffa49abd2c`); the workshop tree has 6 uncommitted paths; the umbrella tree has other agents' uncommitted changes.
- Nothing is pushed: umbrella push waits on gates 0-6 green without bypass (decision #8).
- DONE here means "ticked and the named file exists", not "re-run green". No gate was run in preparing this package.
- The content-boundary gate remains RED by design; survivors still need human reading.
- The 2026-09-03 `review.md` is partly stale; a refresh is a precondition for an honest T105 closure.
- Counts in this file are a dated reading (2026-10-15); re-derive with the commands below.

## 10. Re-derive commands

```bash
sqlite3 -readonly docs/workable_items.db "select * from operator_block_details where atm_id='VSC-078'"
grep -cE '^- \[x\] T[0-9]+' specs/001-workshop-curriculum-platform/tasks.md
grep -cE '^- \[ \] T[0-9]+' specs/001-workshop-curriculum-platform/tasks.md
git -C workshop rev-list --count $(git ls-files -s workshop | cut -c8-19)..HEAD
git -C workshop status --short
```
