# Research: Workshop Areas & Practice Surface (for future HelixQA brainstorming)

Read-only investigation, 2026-09-19. Input for the "Areas & Practice"
sub-project of the exhaustive-HelixQA-coverage effort (matches the depth/style
of the four prior sub-project docs in this directory). All paths relative to
`workshop/`. Live facts captured against `http://127.0.0.1:8087` —
`GET /api/health` reports `build: fae0a71-20260919T001600Z-dirty`,
`source_commit: fae0a71a32d3765e55f48ed866ad3fed4175c9a0`, `source_dirty:
true`. No mutation was performed against the running server.

## 0. This is NOT one feature — it is a family of at least four real,
     distinct routes sharing one taxonomy

The prompt's working name "Areas & Practice" undersells the surface. There are
two frontend routes (`/areas/:slug`, `/practice/:slug`,
`platform/frontend/src/app/app.routes.ts:68` and `:74`), but they sit on top of
**twelve** registered backend routes spanning three genuinely different
concepts that must not be conflated in a bank:

1. **The taxonomy** — `GET /api/areas`, `GET /api/areas/{area}` — what a
   knowledge area IS and whether it is published.
2. **The learning path** — lessons, materials, and a gated end-of-area TEST
   (`assessment`) — a sequential, session/account-scoped study flow with a
   completion gate.
3. **The practice deck** — `GET /api/areas/{area}/questions` — a sessionless,
   ungated flashcard-style quiz drawn from the SAME question bank the gated
   test draws from, with different disclosure rules.

A fourth and fifth exist and are out of the UI's reach entirely:
`GET /api/areas/{area}/coverage` and `GET /api/areas/{area}/export`
(registered in `cmd/workshop-server/main.go:1416` and `:1422` — see the
table in §1), reached by no frontend route at all.

## 1. Real routes

### Frontend

| Route | Component | File |
|---|---|---|
| `/areas/:slug` | `AreaDetailComponent` | `features/areas/area-detail.component.ts` |
| `/practice/:slug` | `PracticeComponent` | `features/practice/practice.component.ts` |
| `/` | `CurriculumComponent` (renders an area-card list + count) | `features/curriculum/curriculum.component.ts` |

`app.routes.ts:32-41`'s own comment says both routes are "specified against a
contract whose endpoints answer 404 on this build (measured 2026-09-01)". **That
comment is stale and materially wrong today.** Every component file it
describes (`area-detail.component.ts:33`, `practice.component.ts:42-46`,
`core/api.ts:606-617`) carries the SAME "measured 2026-09-01, both 404" claim,
while `area-catalogue.ts`'s own header and `curriculum-model.ts:14-51` record a
much richer, later-measured reality (2026-09-07/08/09, quoted below). Do not
trust the routes file's comment or `core/api.ts`'s `areas()`/`area()`/`quiz()`
doc comments as current; the components downstream of them have already been
corrected and say so in their own headers.

`AreaDetailComponent` renders THREE independent sub-surfaces in one page,
each with its own `LoadStatus` and its own `absent`/`withheld`/`empty`
verdict, deliberately never nested inside one another
(`area-detail.component.ts:349-355`):

- the area's own identity/overview (`GET /api/areas/{area}`)
- `<app-area-lessons>` (`GET /api/areas/{area}/lessons`)
- `<app-area-test>` (`GET /api/areas/{area}/assessment`)

### Backend

Registered in `cmd/workshop-server/main.go:1371-1422`, all inside the
authenticated `/api/*` mux (same `authhttp.Middleware` gate every other
API route sits behind — see §6):

| Route | Handler | File:line |
|---|---|---|
| `GET /api/areas` | `AreasHandler` | `main.go:1371`, impl `internal/api/areas.go:232` |
| `GET /api/areas/{area}` | `AreaHandler` | `main.go:1372`, impl `areas.go:410` |
| `GET /api/areas/{area}/evidence` | `EvidenceHandler` | `main.go:1373`, impl `evidence.go:175` |
| `GET /api/areas/{area}/lessons` | `LessonsHandler` | `main.go:1379`, impl `lessons.go:349` |
| `GET /api/areas/{area}/lessons/{lesson}` | `LessonHandler` | `main.go:1380`, impl `lessons.go:403` |
| `POST /api/areas/{area}/lessons/{lesson}/state` | `LessonStateHandler` | `main.go:1381`, impl `lessons.go:470` |
| `GET /api/areas/{area}/materials` | `AreaMaterialsHandler` | `main.go:1382`, impl `lessons.go:544` |
| `GET /api/areas/{area}/assessment` | `AssessmentHandler` | `main.go:1383`, impl `lessons.go:607` |
| `POST /api/areas/{area}/assessment/submit` | `AssessmentSubmitHandler` | `main.go:1384`, impl `lessons.go:690` |
| `GET /api/areas/{area}/questions` | `QuestionsHandler` | `main.go:1392`, impl `questions.go:118` |
| `GET /api/areas/{area}/coverage` | `CoverageHandler` | `main.go:1416`, impl `coverage.go:194` |
| `GET /api/areas/{area}/export` | `ExportHandler` | `main.go:1422`, impl `export.go:288` |

**Only 6 of these 12 have any frontend caller** (`areas`, `area(={area})`,
`lessons`, `lessons/{lesson}/state`, `assessment`, `assessment/submit`,
`questions` — that's 7 actually; `evidence`, `lessons/{lesson}` single-lesson,
`materials`, `coverage` and `export` are reachable only by direct HTTP call).
Config flags gating the whole surface: `-knowledge-taxonomy` /
`WORKSHOP_KNOWLEDGE_TAXONOMY`, `-learning-catalog` /
`WORKSHOP_LEARNING_CATALOG`, `-knowledge-questions` /
`WORKSHOP_KNOWLEDGE_QUESTIONS` (`main.go:335,348,354`) — each unconfigured
leg degrades its route family to a distinct 503, never a silent empty state
(see §4).

**Areas tie into the `kg_*`/taxonomy system directly, not tangentially.** An
"area" IS a `knowledge.Taxonomy` row — the same taxonomy that backs
`/api/terms` in the search sub-project's report — resolved live against the
passage registry (`ComputeLiveEvidence`) exactly like a term is. The learning
catalog (`-learning-catalog`, JSON files under `curriculum/learning/NN-<slug>.json`,
one `curriculum-kit` `Document` per file — `lessons.go:216`) and the question
bank (`-knowledge-questions`, `pkg/assessment.LoadQuestionsDir`, one `*.json`
file per area under `curriculum/questions/`) are SEPARATE, independently
loaded artifacts that both key off the SAME area ULID. `docs/training/areas/`
holds the human-authored source documents these are built from (confirmed:
`docs/training/areas/01-retrieval-and-the-three-state-contract.{md,html,pdf,docx}`
exists on disk).

## 2. Areas: list vs. detail — the single biggest real-world asymmetry

`GET /api/areas` (`AreasHandler`, `areas.go:232`) and `GET /api/areas/{area}`
(`AreaHandler`, `areas.go:410`) apply the SAME publication decision function,
`AreaPublicationOf` (`internal/api/area_publication.go`) — but they did NOT
always, and the gap between them is the whole reason a dedicated gate exists
(`platform/gates/verify-area-publication-consistency.sh`).

**Measured 2026-09-07, quoted verbatim from that gate's own header
(`verify-area-publication-consistency.sh:20-24`):** `GET /api/areas` served
**819** areas and **817** of their own `href`s answered 404
`area_not_published`. Only a small minority of areas that the LIST advertises
are actually servable through the DETAIL route — publication requires a
recorded review (`pipeline/extract/review_store.py`) AND a matching materials
row AND a review that is not stale; an area can be real, evidenced, and
completely unpublished, and the list still names it.

The list route also has a documented naming defect, now fixed and gated:
**measured 2026-09-07** (`verify-area-naming.sh:8-12`), `GET /api/areas?limit=1000`
once returned "819 areas · 5 titled · 814 with `title: null`" — every
unnamed area rendered as a raw 26-character ULID at the reader.
`verify-area-naming.sh` now asserts every served area carries a real name and
every held-back area carries an explained reason.

**Wire shapes, as the client normalisers expect them:**

- List row (`AreaCard`, `curriculum-model.ts:663-673`,
  `normaliseAreaCard` at `:675-692`): `id`/`slug`, `title` (falls back to
  id — "the id is the LAST resort, not the first"), `summary`, `tags`,
  `chapters`/`chapter_slugs`, `evidence_count`, `evidence_certainty`,
  `origin`, `ordinal`. Envelope also carries `corpus_revision`
  (`areas.go:508` uses the identical field on the detail route — T409/SC-042:
  any claim about served content cites the corpus revision it was resolved
  against).
- Detail row (`Area`, `core/knowledge.ts:299-321`, `normaliseArea` at
  `:428+`): `slug`, `title`, `summary`, `why_here`, `track`, `code`,
  `chapter_slugs`, `from_s`/`to_s`, `spans[]`, `passage_count`,
  `uncertain_passage_count`, `term_count`, `question_count`, `read_minutes`,
  `terms[]`. Detail-only 200 also adds `published: true`, `lesson_sections[]`
  (with `authorship`/`citation_count` per section), `publication_review`
  (`decision`/`proposer`/`reviewer`/`reviewed_at` — proposer and reviewer
  are deliberately DIFFERENT fields since 2026-09-02, `areas.go:520-527`).
- `include=held_back` is the ONLY accepted value of `?include=` on the LIST
  route; any other value is refused 400 `unknown_parameter`, not ignored
  (`areas.go:256-260`).

**A real, currently-unflagged inconsistency worth a bank case:** the app has
**two independent client-side parsers of the SAME `GET /api/areas` response**.
`CurriculumComponent` (the `/` landing page) calls `WorkshopApi.areas()`
(`core/api.ts:618`, using `normaliseArea`/`core/knowledge.ts`) to render its
area-card list and count (`curriculum.component.ts:437`), while
`AreaDetailComponent`'s identity fallback calls `AreaCatalogue.cards()`
(`area-catalogue.ts:114`, using `normaliseAreaCard`/`curriculum-model.ts`) for
the SAME data. The two normalisers read different field sets from the same
payload (`normaliseArea` has no field for `tags`; `normaliseAreaCard` was
written specifically because of that gap — see its own header,
`area-catalogue.ts:32-38`) and could silently diverge if the server's shape
changes under only one of them.

## 3. The learning path: lessons -> gate -> test

`LearningDeps.learningArea()` (`lessons.go:140-227`) is the ONE entry point
every lesson/materials/assessment handler starts from — it re-applies the
identical `AreaPublicationOf` gate the taxonomy routes use, so an unpublished
area's lessons cannot leak through a sibling route (`lessons.go:21-36`
explains this is a DELIBERATE difference from the practice-deck route, which
does NOT gate on publication review — see §5).

**Session identity, and a load-bearing subtlety for test design.**
`sessionOf()` (`lessons.go:311-323`) prefers an AUTHENTICATED identity
(`authhttp.FromContext` -> `authhttp.UserProgressKey(u.ID)`) and falls back to
the `X-Session` header only when no authenticated principal is present. **Since
every `/api/*` route in this deployment already sits behind
`authhttp.Middleware` (confirmed live: `curl /api/areas` with no cookie/bearer
-> 401 `{"error":"unauthorized","message":"authentication required"}`), the
`X-Session` fallback branch may be effectively unreachable through the real
HTTP stack** — it would only fire if a caller were authenticated by some
mechanism that does not populate `authhttp.FromContext`, which does not appear
to exist in this build. This is worth confirming precisely (not asserted here
as fact) before writing a bank case that assumes `X-Session` behavior is
independently reachable in production; the Go unit tests
(`TestLearningRoutesRequireTheSessionHeader`, `lessons_test.go:570`) exercise
the handler directly, bypassing the auth middleware, which is a different
thing from an HTTP-level bank case.

**`GET /api/areas/{area}/lessons`** (`lessons.go:349-400`): 200 body carries
`area` (id/title/summary/ord — from the AUTHORED catalog, not the derived
taxonomy presentation — author's words win over derived ones), `lessons[]`
(each via `learning.LessonObject`), `completion` (`ckitCompletion` —
total/complete/in-progress lesson counts + percent), `estimated_minutes`, and
an `assessment` summary object carrying the gate. `links.assessment` and
`links.materials` are included so a client need not construct them.

**`GET /api/areas/{area}/lessons/{lesson}`** (single lesson,
`lessons.go:403-451`): same lesson object PLUS `prev`/`next` neighbour links
(`null`, never omitted, when there is no neighbour) and `position: {index, of}`
— computed from the SAME sorted slice the list route uses, never a second
sort (`lessons.go:433-441`). **No frontend route or component calls this** —
`AreaLessonsComponent` renders every lesson inline from the list response.

**`POST /api/areas/{area}/lessons/{lesson}/state`** (`lessons.go:470-540`):
body `{"state": "not-started"|"in-progress"|"complete"}` — the STRING is
validated by `curriculum-kit`'s own `MarkLesson`, not pre-validated here
(deliberately: "a second copy of the vocabulary here could accept a value the
gate cannot read"). The 200 ack carries the gate's NEW answer
(`completion` + `assessment`) in the SAME response, specifically so a client
never renders a stale lock for one round trip.

**`GET /api/areas/{area}/materials`** (`lessons.go:544-598`, no frontend
caller): every material across every lesson, flattened, filterable by
`?kind=` (refused 400 for an unrecognised kind, never silently emptied —
`lessons.go:556-564`), with `counts_by_kind` and `unresolved_video_links`
(a video material whose chapter this server cannot resolve keeps its anchor
and loses its `href` — REPORTED, not silent).

**`GET /api/areas/{area}/assessment`** (`lessons.go:607-687`) always answers
200 whether the gate is open or shut — "the lock is a state of the test, not
an error about the request." Body: `assessment` (id/title/pass_percent/
max_points/question_count/**required_correct** — a DISPLAY-only ceiling
value, `requiredCorrectCount`, `lessons.go:918-939`, never itself a second
pass/fail gate), `availability` (the real gate — `available`,
`required_lessons`, `missing_lessons[]` WITH titles+links so a client can say
what to finish, `complete_of_required`), `completion`, `attempts[]`,
`best_attempt` (`null` both when nothing attempted AND when every attempt was
indeterminate — the kit refuses to call an ungraded attempt "best"),
`submit_href`, and `questions` — **`null` while the gate is shut, an EMPTY
ARRAY IS NEVER USED for "gate shut"** because that would falsely claim the
test has no questions.

**`POST /api/areas/{area}/assessment/submit`** (`lessons.go:690-914`) is
where the interesting edge cases concentrate — see §6.

## 4. Determined negatives that must not go stale — the staleness guard

`catalogNegativeRefused()` (`lessons.go:256-293`) is a mechanism worth its own
bank attention. Both the learning catalog and the question bank are loaded
ONCE at process startup and never re-read. **Measured 2026-09-08**
(`lessons.go:241-249`): 39 served areas, only 14 answering 200 with 116
questions from an in-process reload, while the SAME directory re-loaded fresh
found 30 areas with an assessment and 224 questions — 13 published areas with
a complete authored bank were told "there is no test here" because their bank
was authored AFTER the process started. The fix is three-valued staleness
(`learning.Fresh` / `NoSource` / `Stale` / `StalenessUnknown`): only `Fresh`
or `NoSource` license a determined negative (`empty` state, `no_assessment` /
`no_learning_catalog`); `Stale` or unverifiable degrade to 503
`curriculum_unreadable` with an explicit remedy ("restart the server so it
re-reads the learning catalog"). **This cannot be exercised as a bank case
without restarting the live process mid-run** (an operator action, not
something a read-only or even a normal-write bank case can trigger) — worth
flagging as PENDING_FORENSICS for how a future bank would simulate it (e.g.
against a disposable test binary rather than the shared dev instance).

## 5. The practice deck: overlapping content, different rules

`GET /api/areas/{area}/questions` (`questions.go:118-283`) is **deliberately
NOT gated on publication review** (`questions.go:35-45` states this as a
conscious, recorded reading of an underspecified contract point) and is
**sessionless by design** (`questions.go:329-335` — "a practice deck needs no
login"). It serves the SAME underlying question-bank rows the gated
end-of-area assessment draws from, split into `short`/`long` arrays
(`b['short']`/`b['long']`, `core/api.ts:672-680`), and layers THREE
independently-motivated withholding mechanisms onto that one population —
a future bank must keep these three straight rather than treating "withheld"
as one concept:

1. **Citation-resolvability withholding (G-KG-2/T072, closed
   `WithholdReason` vocabulary):** `no_citations`, `citation_redacted`,
   `citation_not_present`, `citation_undetermined` — a question is entirely
   removed from `short`/`long` and moved to the `withheld` block
   (`questions.go:205-273`) when its evidence cannot legitimately be cited at
   all. This is the ordinary redaction-adjacent path.
2. **Answer-key disclosure (D9, `questions_graded.go`, `Graded *GradedPromptIndex`):**
   per-row `answer_key_disclosure` is `disclosed` / `withheld_graded` /
   `withheld_undetermined`. A row that is ALSO part of a gated end-of-area
   test never ships `answer`/`correct_index`/`explanation` here — only via
   `POST .../assessment/submit`, after a real attempt. An UNDETERMINED
   gradedness (unreadable learning catalog) is withheld exactly like a KNOWN
   graded row — never resolved toward disclosure.
3. **Citation/lesson-section suppression on assessment-mode rows (D11/D12,
   `questions.go:357-533`):** even when the answer key itself is withheld,
   the CITATIONS and LESSON-SECTION LINKS used to still ship on every row,
   and **measured** (`questions.go:362-465`) 36 of 290 questions (12.4%) carry
   a >=12-word verbatim run of their own answer key inside a linked lesson
   section, and separately 4 of 289 assessment-mode rows (measured
   2026-09-09) leak a >=17-word run through a citation `href` — a one-hop
   route to the passage text. Both channels are now suppressed for
   `withheld_graded`/`withheld_undetermined` rows: `citations: null` +
   `citations_withheld: true` + `citation_count` (never `[]`, which would
   falsely claim "cites nothing"); same shape for `lesson_sections`. **This is
   NOT a redaction/publication-gate mechanism** — it exists purely to stop an
   interview-bank candidate from answering by search, and is orthogonal to
   whether the passage itself is redacted.

**MCQ choice order is per-question-stable, not per-session**, deliberately
weaker than the assessment path's per-session shuffle
(`pkg/learning/shuffle.go`): `practiceChoiceOrder()`
(`questions.go:601-630`) uses a SHA-256 digest of the question id + authored
index, so the practice deck's rendering is reproducible for the same question
id across requests/sessions — but the population-wide "always pick option 2"
tell it exists to kill (measured **88.4%** win rate before the fix,
`verify-question-shape.sh:6-13`) is what it actually defeats.

**MCQs whose answer key is withheld cannot be graded client-side, and the UI
has a dedicated state for it**, not a silent wrong-answer:
`practice.component.ts:253-263` — `q.answer_index === null` renders
`app-state state="degraded"` ("This question cannot be graded... Defaulting
to the first choice would mark a correct answer wrong"). Given the 289/295
measured split above, **the large majority of practice-deck MCQs that are
also part of a gated test will hit this branch**, not the graded branch — a
representative bank sample must include both populations, not just the
minority that grades.

**Grading here is entirely client-side and entirely unrecorded server-side**
beyond one side effect: answering a question calls
`api.recordProgress(chapter, pid, t)` (`practice.component.ts:612-619`) which
posts to `POST /api/progress` (the CHAPTER READING-POSITION endpoint, a
DIFFERENT system from the lesson-completion `Progress *learning.SessionStore`
used by §3 — see §7 for why these two "progress" concepts must not be
conflated in a bank). An unacknowledged write is queued and surfaced to the
reader (`unsaved` signal, `practice.component.ts:456-457`), never silently
dropped.

**Deck position** (which question index a learner is on) is `sessionStorage`
only (`core/practice-store.ts`, `PracticeStore`) — explicitly a
this-tab-this-visit convenience, never durable, distinct from both
`localStorage`-based `LessonProgressStore` (§7) and the server-backed
`/api/progress`.

## 6. Real edge cases on the assessment-submit path

`AssessmentSubmitHandler` (`lessons.go:690-914`) is the single richest edge
case surface in this whole area:

- **Locked submission is 403 with NO `result` key at all**, not a zero score
  (`ckit.ErrAssessmentLocked` — `lessons.go:811-836`). The 403 body still
  carries `availability`/`completion` so the client can render what remains
  outstanding.
- **`unknown_choice` (400)** — a submitted choice-token was never issued to
  THIS session for that question. Choice ids on this route are per-session
  shuffle TOKENS (`pkg/learning/shuffle.go`, "D10"), not stable
  `curriculum-kit` ids — a token copied from another session, another
  learner's screen, or the catalog on disk will not resolve
  (`lessons.go:754-763`). This is a genuine security/isolation property worth
  a bank case: submit with a token obtained from a DIFFERENT session's
  `GET .../assessment` response and confirm 400, not silent misgrading.
- **D8 — a misspelled top-level body key (`response` vs `responses`) used to
  decode cleanly to an empty slice and be RECORDED as a scored 0% attempt.**
  Now refused by dedicated validation (`internal/api/assessment_submit_body.go`)
  BEFORE any progress-store mutation, so a rejected submission leaves no
  attempt behind. Worth a regression-style bank case even though this is
  fixed, since the failure mode (a malformed body silently scoring zero and
  being recorded) is exactly the anti-bluff class this whole platform is
  built to catch.
- **Free-text (`short`) questions are never machine-graded.** A submission
  with ONLY free-text questions produces `markedPoints == 0`, which forces
  `passed` to `false` regardless of what the server's raw `passed` field says
  (`curriculum-model.ts:449-457`: `passed: markedPoints > 0 && o['passed'] ===
  true`) — an area whose entire bank is free-text can structurally never show
  a pass on the client. Worth confirming whether this is an intentional
  design floor or an unconsidered corner (the client-side AND-guard exists
  specifically because an earlier version of this same guard AND-ed on
  `determinate` instead and suppressed EVERY pass on this corpus, since every
  assessment here carries at least one free-text question —
  `curriculum-model.ts:396-405`).
- **Best-attempt semantics:** `best_attempt` is `null` both for "never
  attempted" and "every attempt was indeterminate" — a bank case distinguishing
  these two states needs to look at `attempts[]` (always present, chronological)
  rather than trusting `best_attempt`'s nullness alone.
- **Malformed area PID vs. unknown area vs. zero-evidence area** — three
  different outcomes worth keeping straight: a non-26-char-ULID path segment
  is 400 `malformed_pid`; a well-formed but non-existent id is 404
  `area_not_found`; a well-formed, taxonomy-known id with zero LIVE evidence
  is ALSO 404 `area_not_found` — deliberately indistinguishable from unknown
  (`TestAreaHandler_ZeroLiveEvidenceIsIndistinguishableFrom404`,
  `areas_test.go:327`).

## 7. Two separate "progress" systems live on this one surface — do not conflate

- **`/api/progress`** (chapter/passage reading position, `X-Session`-keyed,
  used app-wide — chapters, transcript, and the practice deck's
  `recordProgress` call).
- **`LearningDeps.Progress` / `ckit.Progress`** (`learning.SessionStore`) —
  lesson completion state and assessment attempts, read/written only through
  `/api/areas/{area}/lessons/{lesson}/state` and
  `/api/areas/{area}/assessment(/submit)`.

Both are keyed by the same session/account identity (`sessionOf()`), but they
are different stores answering different questions, exposed through
completely different routes. `LessonProgressStore`
(`features/areas/lesson-progress.ts`) is the client wrapper for the SECOND
one and its own header (`lesson-progress.ts:8-61`) documents a real, already-fixed
historical defect worth knowing before writing a bank: this store used to be
the ONLY record of lesson completion (pure `localStorage`, never sent to the
server) while the header falsely claimed no server endpoint existed. The
consequence, measured, was that the end-of-area test opened on a browser-only
mark the server had never accepted, the server (correctly) still withheld the
real questions, and the resulting submission scored `0 of 0 points`. The fix
(`markLesson()`, `area-catalogue.ts:248-277`) makes every mark a real
POST with a pending/synced/failed status shown to the reader — never an
optimistic tick left standing over a refused write.

## 8. Existing coverage — do not duplicate

**Go unit tests** (all pure handler/package-level, `platform/backend/internal/api/`):
`areas_test.go` (`TestAreaListAndDetailAgree`, `TestUnreviewedAreaIsHeldBackByTheList`,
`TestAreaHandler_*` — malformed pid, unknown pid, zero evidence, stale review,
review-with-no-materials, reviewed-area-serves-200), `areas_naming_test.go`,
`lessons_test.go` (`TestAssessmentIsLockedUntilRequiredLessonsAreComplete`,
`TestMaterialsCarryTimeLinksAndReportUnresolvableChapters`,
`TestPublishedAreaWithNoCatalogSaysWhichThingIsMissing`,
`TestLearningRoutesRequireTheSessionHeader`,
`TestCatalogLoaderRejectsAMisspelledKey`, `TestProgressIsPerSession`,
`TestAssessmentPreviewReportsTheCeilingOfTheRequiredCorrectCount`,
`TestLearnerAtTheFloorFailsAndAtTheCeilingPasses`), `lessons_staleness_test.go`,
`lesson_link_suppression_test.go`, `questions_test.go`
(`TestQuestionsHandler_MalformedAreaIs400/NoTaxonomyIs503/NoRegistryIs503/
UnknownAreaIs404/ZeroEvidenceAreaIs404/NoQuestionBankConfiguredIs503/
ServesResolvedWithholdsUnresolvedWithReason/ResponseNeverCarriesASourceFilenameShape/
AssessmentModeWithholdsTheCitationRoute`), `questions_graded_test.go`,
`assessment_disclosure_test.go`, `assessment_citation_divergence_test.go`,
`assessment_result_stability_test.go`, `coverage_wire_test.go`,
`evidence_test.go`, `evidence_undetermined_test.go`,
`evidence_word_precision_test.go`, `export_wire_test.go`,
`export_publication_gate_test.go`.

**Shell gates with paired-mutation proofs** (`platform/gates/`):
`verify-area-publication-consistency.sh` (list/detail agreement — the "819
served, 817 404" defect class), `verify-area-naming.sh` (every served area is
named, every held-back area explained), `verify-assessment-gate.sh`
(B1-B8: the full lock/unlock/submit state machine over real HTTP),
`verify-question-shape.sh` (the population-level answerable-without-reading
tells: longest-option, fixed-position, id-suffix), `verify-lesson-content.sh`
(a lesson must carry real teaching text, not just a heading), `verify-lesson-content.sh`'s
companion `prove-lesson-content.sh`, `verify-assessment-reach.sh` (§3.6/§3.9
coverage+export routes are reachable, not merely unit-tested),
`verify-question-doc-section-support.sh` (a question's citations should reach
at least one prose `doc_section`, not only ASR transcript material — adopted
2026-09-09 ALONGSIDE `verify-question-shape.sh`, not instead of it).

**Frontend Karma specs** (`platform/frontend/src/app/features/`):
`areas/area-catalogue.spec.ts`, `areas/area-server-authority.spec.ts` ("D1 —
the server is the authority for the gate, the questions and the score" — the
whole locked/open/submit/refused state machine, client side),
`areas/area-detail-no-assessment.spec.ts`, `areas/area-detail-corpus-revision.spec.ts`
(T409 corpus-revision citation), `areas/area-lesson-prev-next.spec.ts`,
`areas/area-lesson-video-bounds.spec.ts`, `areas/area-lesson-quote-distinction.spec.ts`,
`areas/area-test.component.spec.ts` (locked-state copy correctness; T408
non-colour outcome labelling), `practice/practice.component.spec.ts`
(question-kind labelling correctness across the closed 3-member vocabulary).
**No `area-detail.component.spec.ts` and no `area-lessons.component.spec.ts`
exist** — the top-level `AreaDetailComponent` orchestration (identity
fallback logic, the three-way `absent`/`withheld`/`unavailable` split at the
overview level) and the whole `AreaLessonsComponent` rendering surface
(checkbox sync states, materials rendering, prev/next navigation chrome) have
no dedicated spec file of their own, only the narrower specs above.

**None of the above is a HelixQA (`helixqa http`) bank.** Every item is either
a Go unit/integration test, a shell gate against real HTTP, or a Karma spec
against mocked HTTP — a future bank targeting the live server's actual HTTP
responses and rendered DOM would be complementary to all of it, not
duplicative, provided it does not re-derive the population-level statistical
findings the gates already own (question-shape tells, doc-section coverage,
publication consistency) and instead exercises the CONTRACT surface: status
codes, envelope shapes, the three-valued `absent`/`empty`/`withheld` UI
distinctions, and the session/token isolation properties named in §6.

## 9. Authentication

No special-casing found anywhere in this surface. Confirmed live:
`curl http://127.0.0.1:8087/api/areas` with no cookie/bearer -> `401
{"error":"unauthorized","message":"authentication required"}` — identical
`wrapWithAuth`/`authhttp.Middleware` gate as every other `/api/*` route
documented in the auth/session sub-project's report. `/api/areas/{area}/lessons`
and `/assessment` additionally require the session identity described in §3
(satisfied automatically once authenticated, per that section's caveat about
the `X-Session` fallback's live reachability).

## Files most relevant for the future brainstorm

- `platform/frontend/src/app/app.routes.ts:32-41,62-78`
- `platform/frontend/src/app/features/areas/area-detail.component.ts` (read its full header)
- `platform/frontend/src/app/features/areas/area-catalogue.ts`
- `platform/frontend/src/app/features/areas/curriculum-model.ts` (the type/normaliser contract — read in full)
- `platform/frontend/src/app/features/areas/area-lessons.component.ts`, `area-test.component.ts`
- `platform/frontend/src/app/features/areas/lesson-progress.ts`
- `platform/frontend/src/app/features/practice/practice.component.ts`
- `platform/frontend/src/app/core/practice-store.ts`
- `platform/backend/internal/api/areas.go`, `area_publication.go`, `lessons.go`, `questions.go`, `questions_graded.go`
- `platform/gates/verify-area-publication-consistency.sh`, `verify-assessment-gate.sh`, `verify-question-shape.sh`, `verify-question-doc-section-support.sh`

## Suggested focus for the brainstorming session

1. Treat "Areas & Practice" as (at least) three distinct contract surfaces —
   taxonomy, learning path, practice deck — with separate bank sub-suites,
   not one flat set of cases.
2. The list-vs-detail publication asymmetry (§2) is the single highest-value
   target: a bank exercising `GET /api/areas` against `GET /api/areas/{id}`
   for a sample of ids across "published", "held back — no review",
   "held back — stale review", and "unknown/zero-evidence" is the HTTP-level
   complement to `verify-area-publication-consistency.sh`'s own proof.
3. The three DIFFERENT withholding mechanisms on the practice-deck route
   (§5: citation-resolvability, answer-key disclosure, D11/D12 leak
   suppression) are easy to conflate into one "redaction" bank case — they
   need to stay three, each with its own assertion.
4. Session-scoped choice-token isolation on assessment submit (§6,
   `unknown_choice`) is a genuine cross-session security property and is not
   currently named in any HTTP-level bank listed in §8.
5. Confirm (not assumed here) whether `X-Session`'s fallback branch in
   `sessionOf()` is reachable through the real authenticated HTTP stack at
   all, before writing a case that depends on it independently of account
   auth.
6. The two independent client parsers of `GET /api/areas` (§2, `normaliseArea`
   vs. `normaliseAreaCard`) is a real drift risk worth a contract-level bank
   case even though it is not itself a "feature".
7. `AreaDetailComponent` and `AreaLessonsComponent` have no dedicated Karma
   spec (§8) — their `absent`/`withheld`/`unavailable` branching is exactly
   the kind of thing an HTTP-level bank case is well suited to cover.
