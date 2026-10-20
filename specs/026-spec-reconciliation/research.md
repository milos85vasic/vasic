# Research: Specs 011-017 Reconciliation

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)
**Method**: every code claim below was re-read or re-run on 2026-10-20 at workshop HEAD `33e9760` (read-only). Items taken from the gap analysis without re-verification are in section 8. Paths relative to `workshop/` unless stated.

## 1. D1 - Passage Kind and content_type (contradiction C1/C2)

| Fact | Evidence |
|---|---|
| `textbook_section` Kind exists | `platform/backend/internal/passagestore/domain.go:71` (`KindTextbookSection`), registered in the kind list at `:253-254` |
| Content type vocabulary has `textbook` | `domain.go:167` (`ContentTypeTextbook = "textbook"`), allowed only for `KindTextbookSection` (`:198-199`) |
| Sidecar decoder REQUIRES `content_type`, no default | `cmd/ingest-transcript/main.go:102-117` (field `ContentType`, comment "NO default"); `content_type.go:23-29` `docContentTypes`: `doc_section -> {authored_lesson, meeting_notes}`, `code -> {code}`, `diagram -> {diagram}`, `textbook_section -> {textbook}` |
| So a 012-style row `kind: doc_section` without `content_type` is refused, and `doc_section` + `authored_lesson` would misclassify a textbook | same files; spec 017 FR-009/FR-010 scoping |
| 012 says `doc_section`, "no new Kind" | `specs/012-.../spec.md` FR-001, FR-020, entity "doc_section passage"; `data-model.md:68,83,122-131`; `plan.md:89-90`; `tasks.md:18`; `contracts/epub-ingestion-stage.md` step 5 |
| 015 FR-007 | `specs/015-.../spec.md:249-255`, `plan.md:83-84`, `data-model.md:145-152`, `contracts/location-anchor.md:79-85` |

Decision D1: textbook content of every format is `textbook_section` + `textbook`. 015's "no new Kind" is retained in its true meaning (015 adds none) and its "use doc_section" is superseded for textbooks. `doc_section` remains correct for authored lessons and meeting notes.

## 2. D2 - License record vs `DisallowUnknownFields` (C3)

| Fact | Evidence |
|---|---|
| Decoder rejects unknown fields | `cmd/ingest-transcript/main.go:161` `dec.DisallowUnknownFields()` in `readJSON` (`:155-165`) |
| `docSection` declares 7 fields: `pid, text, path, line_start, line_end, kind, content_type`; no `attrs`, no license | `main.go:102-117` |
| 017 measured the failure and worked around it | `pipeline/pdf_textbook_sections.py:232-236` (comment: `json: unknown field "license_basis"`), writes the companion report at `:295`, content `license_basis` at `:308-309` |
| 012 T016 stores license "in the extraction sidecar's own output" | `specs/012-.../tasks.md:107` (T016) |
| Passage `Observation.Attrs` is an open map, keys owned by the application | `domain.go:111-135` (`Attr*` constants), `:343` reads `AttrContentType` from `rec.Attrs` |

Options considered:
- A. Add `license` to `docSection`: changes the decoder and stamps legal metadata into every passage forever. Rejected: widens a hot-spot file for no retrieval benefit.
- B. Carry license in `attrs` per passage: needs T006a first, spreads one run-level fact across thousands of rows, and `attrs` is documented as location metadata. Rejected.
- C. **Chosen**: license record in the companion report `<out>.report.json`, key `license` = `{basis, recorded_by, recorded_at}`; this is exactly what `pdf_textbook_sections.py` already does (it writes `license_basis` at the report top level; D2 normalizes it to the nested `license` object, an additive change to the script made when 012 is implemented). The run-level gate is the extractor's refusal (`pdf_textbook_sections.py:182` refuses an empty basis) before any source byte is read.

Still true and unchanged: `ingest-transcript` does not read the report file, so a sidecar can be ingested without its license record; the gate is the extractor, not the ingester. Closing that (an ingester-side check of the report) is NOT in scope (listed in 012 as a follow-up note).

`attrs` passthrough (012-T006a) stays, retargeted: the real signature is `DocumentObservation(chapterSlug, text string, kind passage.Kind, contentType string, ref passage.SourceRef)` (`domain.go:642-643`), the real call site `cmd/ingest-transcript/main.go:443`. 012's data-model quoted a 4-parameter signature at `domain.go:538` and "9 call sites"; both are stale (UNCONFIRMED how many call sites remain: not re-counted).

## 3. D3 - Achievement event stream (C5)

| Fact | Evidence |
|---|---|
| 014 consumes `AchievementEvent {id, kind, title, message, scoreDelta?, occurredAt, coalesceKey, modalWorthy?}` and kinds `level-up | chapter-complete | adjusted` | `specs/014-.../data-model.md:24-80`, `contracts/achievement-components.md:164-171` |
| 013 defines no event, endpoint or notification; only `ResponseLogEntry.DowngradeTriggered`, `AbilityScore`, and `last_downgrade_reason` on `GET /api/progress` | `specs/013-.../contracts/progress-extension.md`, 014 `tasks.md:55-75` (014 itself says so) |
| No level concept exists | grep `level` in 013 spec: none; ability is a 0-10 float |
| Existing progress surface: three-answer contract and closure-source pattern | `internal/api/progress.go:266-299` (`LessonCompletionSummary`, `LessonCompletionSource`) |
| Lesson-completion tallies exist per area | same, `TotalLessons/CompleteLessons/InProgressLessons/Percent` |

Decision D3: see `specs/013-adaptive-assessment-scoring/contracts/achievement-events.md` (new). Naming reconciled: 013's "downgrade" is on the wire `adjusted`.

## 4. D4 - Remedial routing (orphan)

013 `spec.md` Assumptions (hook paragraph about `citations_study_href` / `lesson_sections_study_href`) defers remedial-material routing and kind-easing to 014 "or a later iteration of this feature". 014 has no FR for either. The hooks exist: `internal/api/questions.go:516` (`citations_study_href`) and `:532` (`lesson_sections_study_href`), both `"/api/areas/<area>/lessons"`. Decision D4: 014 FR-022 + tasks T016b/T016c implement the remedial link; kind-easing is deferred to 013 (T036b, operator decision O-4).

## 5. D5 - Practice-bank baseline

Re-runnable measurement (read-only):

```bash
cd workshop/curriculum/questions && python3 - <<'PY'
import json,glob,collections
c=collections.Counter();n=0
for f in glob.glob('*.json'):
    d=json.load(open(f)); qs=d.get('questions',[]) if isinstance(d,dict) else d
    for q in qs: n+=1; c[q.get('difficulty')]+=1
print(n,dict(c),len(glob.glob('*.json')))
PY
```

Output on 2026-10-20 at `33e9760`: `292 {'hard': 179, 'medium': 113} 40`. Zero `easy`. Cause of the drop from 311: commits `fb277ab` (removed 18) and `da916c1` (withheld 1) under `curriculum/questions` (SC-009 data work). Superseded figures: 311 / 121 / 190 in 013 `spec.md` (edge case, FR-009, assumptions), `plan.md:86,219`, `data-model.md:277`.

## 6. D6 - Frontend directory convention (C6)

`platform/frontend/src/app/features/` holds `areas auth chapters curriculum inquiry passage plans practice progress section transcript` (listing run 2026-10-20). 015 declares `src/app/profile/` (`plan.md:212-213`, `tasks.md:468`). 014 uses `features/gamification/`. Decision D6 in spec FR-009. The route name was undefined anywhere; D6 fixes it as `profile` (UNCONFIRMED whether it collides with a future route; `app.routes.ts` has no `profile` today per the gap analysis).

## 7. D7 - MMR for crossrefs

Spec 017 `research.md` section 0 (corrected 2026-10-05): MMR "removed from `(*Service).fuse`" after being measured non-deterministic (served set varied on 14/26 identical calls) and score-corrupting; `pkg/crossref` declines it in its package doc. The UX research document (path `workshop/docs/research/ux-research-2026-09-01.md`, section "P3 - MMR-diversify the cross-reference list", lines 182-197; not quoted here) recommends MMR for the related-content list; that recommendation predates the measurement. Spec 016 FR-006/FR-007: crossref relevance is cosine with `min_score` 0 and always 20 targets (gap analysis, prebuilt DB: 692,460 rows over 34,623 sources = exactly 20 per source; UNCONFIRMED by me, the prebuilt sqlite was not opened). Decision D7 = spec FR-010.

## 8. UNCONFIRMED register

- Live-stack state (build `ce62bcb`, reranker flags, `passages.jsonl` kind counts) comes from the gap analysis; not re-measured here.
- 016 DONE/PARTIAL verdicts: evidence paths and commits were spot-checked for existence (all 18 commit ids resolve in `git cat-file -t`; named files exist in `git ls-files`), tests were NOT run. "DONE" means "source present at HEAD".
- `chapter-complete` granularity (O-5).
- Slug-vs-ULID resolution for `/api/areas/{area}` (gap analysis C11) not re-verified.
- Number of remaining `DocumentObservation` call sites.
- Whether `tesseract` is installed now (umbrella `CLAUDE.md` says yes, re-measured 2026-10-08; 012's DIA premise "not installed" is outdated): 012 FR-019 OCR is no longer environment-blocked, stated as a note in 012 only.

> **Amended 2026-10-20 after the S4 independent review, M5: the report file must be byte-identical across runs (`scripts/ingest-textbooks.sh` compares report hashes), and `recorded_at` is wall-clock. So the report's `license` object carries only the deterministic summary `{basis, basis_class, record_file}` and the full record `{basis, basis_class, recorded_by, recorded_at}` is the sibling file `<out>.license.json` (stem + `.license` + suffix). `--recorded-at` and `SOURCE_DATE_EPOCH` make it reproducible. Write order: license file, report, sidecar last. The license record is still never in the sidecar or a passage attr.**
