# Research: Workshop Ask / Q&A Surface (for future HelixQA brainstorming)

Read-only investigation, 2026-09-18, live-state facts captured against
`workshop-curriculum_platform_1` (`source_commit=9a319209e...`). All paths
relative to `workshop/`.

## 1. Route: frontend `/ask` (and `/search`) → backend `/api/ask*`

Same merged `InquiryComponent` as search (`features/inquiry/inquiry.component.ts`,
1813 lines) — `path: 'ask'` seeds `data:{mode:'answer'}`, both real,
bookmarkable, auth-guarded routes.

Frontend calls (`core/api.ts`): `ask(question, chapter?)` → `GET /api/ask?q=...&wait=1[&chapter=...]`
(synchronous only — the UI never polls or uses SSE); `askCapability()` →
`GET /api/ask/status`. A 503 with a JSON body is parsed as a real answer
(`unavailable`), never treated as a transport failure.

Backend mount (`pkg/answer/http.go:32-39`, `Mount`) — **richer than the UI
uses**:

| Route | Purpose |
|---|---|
| `GET/POST /api/ask` | ask (sync `wait=1`, async 202+job id, SSE `stream=1`) |
| `GET /api/ask/status` | capability/health |
| `POST /api/ask/suspend`/`resume` | used by `scripts/ingest.sh` only, not the UI |
| `GET /api/ask/{job_id}` | poll |
| `GET /api/ask/{job_id}/stream` | SSE poll |

Mounted unconditionally, even with `Provider: "none"` — absence of a
provider is always a 503 finding, never a 404. FR-025: `/api/ask` is
architecturally isolated (no other route tree imports `pkg/answer`) so a
hung/slow provider can't starve browsing/search. `MaxQuestionBytes=2000`,
`MaxWait=200s`.

## 2. Answer-provider mechanism

Fully pluggable catalogue (`pkg/answer/registry.go`), one table drives
everything — `none` (builtin), `extractive` (builtin, verbatim top-passage
copy, no model call), `ollama` (local), `openai_compatible`, plus 28 hosted
vendor rows via `digital.vasic.llmprovider` (zero vendor HTTP code lives in
this repo).

**Live/deployed state, measured, not assumed**: `compose.yml:459-461`
documents an explicit operator directive: *"THE GENERATIVE ANSWER PATH IS
OFF BY DEFAULT, ON AN EXPLICIT OPERATOR DIRECTIVE. THE PREVIOUS DEFAULT WAS
`ollama`."* Confirmed live via `podman inspect`: running binary started with
`-answer-provider none`. **So today, every `/api/ask` call gets 503
`{"reason":{"code":"no_provider",...}}` once authenticated.** Ollama itself
has 3 models installed on the host but the container has no `-ollama`
endpoint wired at all (`/api/health`'s `ollama.configured: false`) —
flipping the provider back on would need BOTH `WORKSHOP_ANSWER_PROVIDER=ollama`
AND `WORKSHOP_OLLAMA_URL` re-supplied.

Pipeline layers (`pkg/answer/pipeline.go`, `verify.go`): retrieve → **L1**
calibrated retrieval gate (min-score/min-margin, both 0 by default =
deliberately hostile, refuses everything rather than fabricating a
threshold) → **L1.5** kind gate → **L1.6** disclosure gate (§3) → generate →
**L3** citation identity (cited id placed AND resolves live) → **L4** support
verification (lexical default; entailment needs a model not present in this
container image) → **L5** question-verification (does the claim actually
answer the question — live default `none`).

`/api/ask/status` reports which layers are live: `enabled`, `suspended`,
`calibrated`, `verifier_kind`, `question_verifier_kind`,
`estimated_seconds` (measured median, never guessed), `latency_note`
(hardcoded measured numbers: cold prefill 10.6 tok/s, warm 15.7-6.6, e2e
11-67s over an 18-question benchmark).

## 3. Citations, redaction/leak defenses — enforced at THREE independent, serve-time points

`Answer.citations_verified` is explicitly documented (code + UI copy) as *"a
NECESSARY condition for support and NOT entailment"* — UI shows a warning
tag rather than a green check when false/absent.

1. **`TextDisclosureGate`** (`pkg/answer/disclosure.go`) — re-resolves every
   pid against the LIVE registry on EVERY request before any text (quote,
   excerpt, answer text) is rendered, through one choke-point function
   (`discloseDoc`). Historical, pre-fix defect this file documents: three
   separate leak paths (`closest[].excerpt` 203 chars, `citations[].quote`
   127 chars, extractive `text` 71 chars) each bypassing a per-field check —
   the single-choke-point design exists specifically because an
   enumeration-based fix missed one exit.
2. **L3b at generation time** (`verify.go`) — a cited id resolving `redacted`
   declines the WHOLE answer (`ReasonRedactedEvidence`), never silently
   drops just that citation — *"Claims are never silently stripped to keep
   an answer presentable."*
3. **Post-hoc, on cached/polled answers** (`pkg/answer/jobs.go` +
   `jobs_redaction_test.go`) — an in-memory cached job (up to 30 min) is
   RE-CHECKED against the live registry on next poll; a redaction that
   happened after the job finished but before a reader polls it WITHDRAWS
   the cached answer to `declined{redacted_evidence}` with citations/text
   wiped (`TestStoredAnswerWithdrawnAfterRedaction`).

Distinct closed-vocabulary code `CodeAnswerTextWithheld` — a DEPLOYMENT-level
refusal (this instance may not disclose this passage) vs. `declined` which is
a CORPUS-level finding — deliberately kept separate. UI renders this as its
own sixth pane state (`data-testid="ask-withheld"`), explicitly "no Retry —
retrying does not obtain permission."

## 4. Real edge cases

- **Empty/nonsense question**: empty → 400 `empty_query` (a fourth thing,
  not a fourth answer-state). >2000 bytes → 413. Gibberish (syntactically
  valid, nonsensical) is NOT special-cased — goes through normal retrieval,
  likely `declined{below_threshold}`.
- **"Genuinely no answer"**: `declined` (HTTP 200, not an error), closed
  six-member vocabulary: `below_threshold`, `margin_too_small` (*"the
  dangerous question: one whose topic the corpus covers at length while the
  asked-for fact is absent"*), `unsupported`, `no_citations`,
  `redacted_evidence`, `does_not_answer` (citations support the claim but it
  answers a DIFFERENT question). `DisjointVocabularies()` is a
  runtime-checked invariant that decline and unavailable never share a
  member.
- **Provider timeout/unreachable**: `Health()` checked BEFORE creating a job
  — never even starts one, immediate 503. Confirmed live: provider is
  `none`, so every call takes this path today. `provider_unreachable` (for
  `ollama`) carries `RetryAfterS:30`.
- **Refused-to-answer, two structurally different kinds kept apart**: a
  CONTENT refusal (`declined{...}`, a finding about the corpus) vs. a
  DEPLOYMENT/POLICY refusal (`unavailable{answer_text_withheld}` etc., a
  fact about this build, never blaming the corpus).
- **Non-English / ambiguous intent**: `core/intent.ts` is a heuristic,
  NON-MODEL, ENGLISH-ONLY classifier (`question`/`lookup`/`ambiguous`)
  gating whether the expensive answer leg runs at all — a non-English
  question with no `?` lands in `ambiguous` (asks the reader, doesn't
  guess — safe direction but a real, documented limitation).
- **Withdraw mid-flight**: reader can cancel an in-flight ask — dedicated
  `withdrawn` phase, not a decline/fault.
- **Ingest-in-progress**: `/api/ask/suspend`/`resume` hold answering during
  a corpus rebuild, reported via `CodeIngestInProgress` (`RetryAfterS:60`).

## 5. Existing coverage — do not duplicate

No HelixQA bank exists yet for ask/answering. Extensive Go-level unit
coverage already exists (`pkg/answer/jobs_redaction_test.go`,
`citations_verified_test.go`, `disclosure_test.go`,
`entailment_verify_test.go`, `generation_gate_test.go`, `provider_test.go`,
`question_test.go`, `registry_test.go`, `http_test.go`,
`suspend_http_test.go`, `internal/answering/wire_test.go`,
`publication_test.go`, `question_verify_vocabulary_test.go`) — a QA bank
should assert observable HTTP/UI behavior, not re-derive these.

Shell gates with paired-mutation proofs already covering this surface:
`verify-answer-provider-selection.sh` (derives its coverage set from
`go run ./cmd/answer-providers`, stays complete as vendor rows evolve),
`verify-answer-question.sh` (L5 actually refuses off-topic claims),
`verify-g-http-5-search-survives-answering-down.sh` (search keeps serving
with the provider genuinely unreachable; ask 503s — never the reverse,
never both down — the strongest existing live proof of FR-025 isolation).

Frontend: `inquiry.component.spec.ts` (1158 lines, Karma/mocked HTTP) and
`core/intent.spec.ts` already unit-test in isolation — a bank should target
the real running server's HTTP responses and rendered DOM, which these don't.

## 6. Authentication

Required everywhere in scope, confirmed both statically and live — same
`authGuard`/`authhttp.Middleware` mechanism as every other content route, no
separate role/scope check found specific to asking. Confirmed live:
`curl /api/ask/status` (no auth) → 401 `authentication required`.

## Additional blind spots for the brainstorm

1. **No rate limiting or cost/budget guard on `/api/ask` itself.** Rate
   limiting exists ONLY for login (T508). The only "budget" concept
   (`PromptBudget`) bounds prompt SIZE, not request FREQUENCY or cost over
   time — matters once a real provider is switched back on; a
   resource-exhaustion surface worth a bank case or an explicit accepted-gap
   note.
2. **The live provider is `none`** — any live bank exercising
   `answered`/`declined` states must either target `provider_unreachable`/
   `no_provider` as the only honestly-reachable states today, or require an
   explicit, operator-approved flip of `WORKSHOP_ANSWER_PROVIDER` (+
   `WORKSHOP_OLLAMA_URL`) first — a deployment decision, not a code gap,
   and should be surfaced to the operator before any bank assumes
   generation is reachable.
3. **Backend surface exceeds what the Angular client uses** (async 202,
   `stream=1` SSE, job polling, suspend/resume) — needs an explicit scope
   decision on whether "everything" includes this UI-unreached surface.
4. **Intent classification is English-only** — a real edge-case matrix
   needs at least one non-English and one no-question-mark
   declarative-but-meant-as-question case (both land in `ambiguous` by
   design, not silently misclassified).
