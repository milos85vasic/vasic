# Research and evidence: Research Gap Closure

All commands were read-only and run on 2026-10-21 against `workshop` `main` (`827e79e`) unless the row names `int-0.0.3` (`35f2ea3`). Paths are relative to `/home/milosvasic/Projects/vasic`. Nothing was built or run beyond these.

## 1. Corrections to the input audits

The two input audits are scratch files; where reading the code or a spec changed a conclusion, the correction is recorded here so it is not repeated.

| Audit claim | Finding | Evidence |
|---|---|---|
| ux-research P2 (self-explanation and confidence) "has no implementing task" / "MISSING" | It has implementing tasks, all unticked: unowned is wrong, unfinished is right | `specs/025-ux-research-wave/tasks.md:83-93` (T031-T041) |
| U32 / U35 "only baselined by T006 which is MISSING, no tracked owner" | T006 is the tracked owner, unticked | `specs/025-ux-research-wave/tasks.md:34`; `spec.md:49-51` |
| REQ-6 residency copy "no task produces it" (Part B) vs "024 T072-T074/T078 carry it" (Part C) | Part C is right: tasks exist, all unticked, T078 waits on operator text | `specs/024-answering-enablement-and-provider-ui/tasks.md:158-164` |
| Textbook ids vs the chapter-id grammar "UNCONFIRMED whether a gate covers it" (Part E sub3) | Covered: 012 T021 and a unit test on `main` | `specs/012-document-ingestion-textbooks/tasks.md:149`; `git ls-tree main platform/backend/pkg/curriculum/` lists `textbook_scope_test.go` |
| "A9 NOT-SPECCED (only 013 US3 grep'd by title)" | Confirmed by full-text search: `013 tasks.md` has no gaming-detector or 2PL task; its US3 tasks T037-T044 are the Elo batch recalibration only | `grep -n -i "detector\|2PL\|discrimination" specs/013-adaptive-assessment-scoring/tasks.md` shows only replay/unrelated hits; `013 spec.md:70,127` defer both |
| The `aria-live="assertive"` on the transcript is a conflict with the UX research | A single context-change announcement, deliberately assertive and explained in the code; the research's concern is a step list | `workshop/platform/frontend/src/app/features/transcript/transcript.component.ts:117-142`; research `ux-research-2026-09-01.md:124` |
| 026 T012 names `wire_audit.go`, `wire_lan.go`, `wire_rerank.go` | None exist on `main` or `int-0.0.3`. Existing: `wire_hooks.go` and `wire_{providers,scoring,profile,practice,retrieval,ingestion,textbooks}.go` (`main`), plus `wire_answering.go` (`int-0.0.3`). `wire_scoring.go` on `main` is a no-op stub (36 lines, "Every function is currently a no-op"); `pkg/scoring` is absent from `main`'s `pkg/` listing | `git ls-tree --name-only main platform/backend/cmd/workshop-server/`; `grep -n 'hook:' main.go` empty; `wire_scoring.go:7-9` |
| Skills research §9.1 "no tool found generates or verifies the gate/mutation pairing" | In this repository the pairing is enforced: the registry requires a paired proof per check | `scripts/verify-check-registry.sh:1-40`; `workshop/platform/gates/check-registry-*.tsv` |

## 2. Code facts relied on

- OCR: `pipeline/pdf_textbook_sections.py:212-223` refuses an image-only PDF ("no text layer, OCR not available") and records `extraction_failures` at `:212,:216,:335`. `tesseract 5.5.0` is installed; `tesseract --list-langs` prints `eng` and `osd` only. `pipeline/detect_ocr.sh:43-52` is the spec 008 OCR probe (frames, not textbooks).
- Retrieval benchmark: `pipeline/benchmark/run_retrieval_benchmark.py:149` computes `top5_correct`; `:245-267` prints top-1 and top-5 only. No MRR/nDCG anywhere in `platform pipeline scripts` (`git grep -i 'ndcg\|precision_at_k\|recall@'` on `main` is empty).
- Transcription: `pipeline/compare_engines.py:111` word-level Levenshtein, `:165` "with engine A as reference this is exactly the WER".
- Gates present: `platform/gates/verify-contract-{http,cli,pid}.sh`, `verify-served-contrast.sh`, `verify-retrieval-benchmark.sh`, `verify-bank-reachability.sh`, `lib/question_shape.py`.
- Dependencies: no property-test, WER, subtitle or readability library appears in `platform/backend/go.mod`, `platform/frontend/package.json` or `pipeline/requirements.txt` (grep for `rapid|gopter|fast-check|jiwer|textstat|pysubs2|mewt` found nothing).
- 013: `pkg/scoring` on `int-0.0.3`: `doc.go:8` per (session, area) ability; `events.go:40` `ModalWorthy`; `serve.go:93` `ServeNext(session, area string, cands []Candidate, cfg Config)` (no options parameter). `internal/api/lessons.go:552-561` chapter-complete per area.
- 011: `pkg/answer/audit.go` exists on `main`; 011 tasks T007-T014 are all ticked (`tasks.md:93-119`).
- 021: `spec.md:194-197` FR-001 (question mediums are `assessment.Kind` values; format mediums exist only in the US4 engagement path); `:139-150` US4; `:164-168` US5 BLOCKED; `tasks.md:271` T048a; OD-1..OD-5 at `spec.md:312-321`.
- 022: corpus-only by decision (`research.md:33-40`); `-material-allow-remote` is on branch `s17-022-material`, not `main` (`OPERATOR-DECISIONS-2026-10-21.md` D-06).
- Host plugin facts (names only, one alias): enabled in `~/.claude-claude5/settings.json`: `chrome-devtools-mcp`, `claude-security`, `codspeed`, `context7`, `deepeval`, `figma`, `frontend-design@anthropics`, `code-review@anthropics`, `lumen`, `mattpocock-skills`, `mlflow`, `modern-web-guidance`, `playwright`, `receipts`, `sonarqube`, `superpowers` (two sources), `systematic-debugging@anthropics`, `typescript-lsp`. Not enabled: `trailofbits/*`, `education-agent-skills`. The umbrella's tracked `.claude/settings.json` enables `ashlr@ashlr-marketplace` only.

## 3. Decisions taken in this spec and why

- **Gaming detector before IRT.** The detector needs only the log columns 013 already keeps (`013 spec.md:70`); IRT needs response volume that does not exist (research `skills-and-plugins` §8 rejects item-response modelling as premature at launch). So the detector is BUILD and IRT is shadow-only.
- **No model anywhere near textbooks.** OR-04 and D-06 are explicit. Textbook-to-areas is therefore a deterministic TOC draft; textbook-to-questions is NEEDS-OPERATOR.
- **Cross-reference rather than duplicate.** RG-15, RG-33, RG-35, RG-38, RG-39, RG-43 point at existing tasks; the register check verifies those task ids still exist.
- **Tooling decisions follow the research's own reasoning.** The register adds only the repository-specific facts the research could not know (the in-repo registry, existing gates, host-enabled plugins).

## 4. Not covered here, and why

Items in the backlog's Part E that are task-note gaps rather than research requirements are out of scope: a promotion primitive for `index.sh`, a CLI entry point for `crossref.Derive`, per-pid `(pid, content_hash)` carry-forward, a speaker-label tool, silence/VAD in the coverage identity (spec 008). Wiring defects (route mounts, `ACHIEVEMENT_EVENT_SOURCE`, missing compose flags) belong to the must-wire backlog.

## 5. UNCONFIRMED (not claimed)

- Whether a captions `<track>` exists on the recording player today (T056 reads `recording-player.component.ts` first).
- Whether the 018 Library UI can display a self-report count (T036 decides).
- Backlog Part E sub4 items R2, R4, R5 against code (T062 re-verifies first).
- Which states the `core/state.component.ts:333` assertive set contains.
- Whether the installed `superpowers` version is v6.3.0.

## 6. Cross-spec analysis of 011-027 (speckit-analyze equivalent, 2026-10-21)

Method: an ad hoc script parsed every `spec.md` and `tasks.md` of 011-027 (ids, duplicates, FR/SC referenced by tasks, cross-spec references), then each semantic finding was checked with `grep` and `git show` against `workshop` `main` and `int-0.0.3`. Result: 0 duplicate task ids; 0 unresolved cross-spec FR/SC references (3 regex false positives inspected); no route collisions. Fixes applied as append-only annotations marked "Reconciled by 027 on 2026-10-21":

| ID | Finding | Applied to |
|---|---|---|
| A-01 | `wire_audit.go`, `wire_lan.go`, `wire_rerank.go` and `// hook:*` lines never existed; real files are `wire_hooks.go` plus `wire_{providers,scoring,profile,practice,retrieval,ingestion,textbooks}.go` | 026 plan and tasks; 011 spec/plan/tasks; 017 spec/plan/tasks |
| A-02 | 026 showed O-2..O-7 open and lacked O-8 and the crossref floor (ratified, D-08) | 026 spec |
| A-03 | 026 T014 count 012=29 is 27 | 026 tasks |
| A-04 | O-8 has no task or code anywhere | reported only (needs a 013-stream task) |
| A-05 | 013 T036b tagged DEFERRED though O-4 is BUILD; 021 T048a waits on a 013 `ServeNext` options seam nobody defines | 013 tasks |
| A-06 | 013 spec still lists O-2 and the zero-easy response as open; T049 | 013 spec and tasks |
| A-07 | 011 FR-005 marker resolved (O-7); LAN public-IP marker is an unratified delegate default (X-01) | 011 spec |
| A-08 | 020 D-TITLES amended by D-03 | 020 spec |
| A-09 | 025 tooling row points at a tooling spec | 025 spec |
| A-10 | 012 T047: OCR packs `eng`, `osd` only; FR-018/019 and SC-009 had no task | 012 tasks |

Reported, not applied (files owned or uncommitted by another stream): B-01 `022 spec.md:52-54` says 011's audit writer is unbuilt (it is built: 011 T007-T014 ticked, `pkg/answer/audit.go` on `main`); B-02 014 T016c/T025 wait on an operator routing map though O-3 is ratified; B-03 023 has no `tasks.md`; B-04 all specs `Status: Draft`; B-05 FR-to-task traceability is by story tag in newer specs (FRs never named in their own tasks: 018 12/16, 019 15/15, 020 15/16, 021 15/20, 022 18/26, 024 15/21, 025 15/21); B-06 020 resolver versus 015 anchors (027 FR-015); B-09 014 FR-007/FR-008 numbers and X-02 unratified; B-10 `ACHIEVEMENT_EVENT_SOURCE` provided nowhere (must-wire backlog).
