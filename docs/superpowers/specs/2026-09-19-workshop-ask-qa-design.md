# Design: Exhaustive HelixQA Coverage — Workshop Ask / Q&A

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven"). Fourth of 8 planned sub-projects.

## A scoping decision this design makes explicit rather than silently assuming

**The live answer provider is `none`, by an explicit, documented operator
directive** (`compose.yml:459-461`: *"THE GENERATIVE ANSWER PATH IS OFF BY
DEFAULT, ON AN EXPLICIT OPERATOR DIRECTIVE."*). Confirmed live in the
research: every `/api/ask` call today gets 503 `no_provider` once
authenticated — the `answered`/`declined` pipeline states (L1-L5, citations,
the six-member `declined` vocabulary) are architecturally real and
extensively unit-tested at the Go level, but are **NOT honestly reachable
via a live HTTP call today** without an operator re-enabling a provider
(`WORKSHOP_ANSWER_PROVIDER=ollama` + `WORKSHOP_OLLAMA_URL`).

**This sub-project does NOT flip that setting.** It is a deployment
decision an operator made deliberately, and this HelixQA-coverage effort is
about testing observable behavior, not about changing what's deployed. This
design instead:

1. Tests every state that IS honestly reachable today (`no_provider` 503,
   input validation, auth-gating, capability reporting via
   `/api/ask/status`, the deployment-vs-corpus refusal distinction where it
   applies without generation).
2. Documents the `answered`/`declined` pipeline states as a **named,
   explicit gap** in this bank's own header comment and in this task's
   report — not a silent omission — so a future operator decision to
   re-enable a provider has a clear, ready-made bank extension point.

If the operator wants full pipeline coverage, that's a separate, explicit
decision to make later (re-enable a provider, note the resulting behavior
change, then extend this bank) — not something this design or its
implementer should decide unilaterally.

## Scope of this sub-project

`GET/POST /api/ask`, `GET /api/ask/status` — the subset reachable with
`Provider: none`. Also the architectural-isolation guarantee (FR-025: a
hung/slow provider can't starve browsing/search) — already has a dedicated
gate (`verify-g-http-5-search-survives-answering-down.sh`), so this
sub-project does not duplicate it, only confirms via one live HelixQA case
that search stays reachable while `/api/ask` 503s.

Out of scope for this sub-project: the async/job/SSE surface
(`/api/ask/suspend`/`resume`, `/api/ask/{job_id}`, `/api/ask/{job_id}/stream`)
— the research notes this exceeds what the Angular UI actually uses; left as
an explicit, named gap rather than tested blind, since "does this
UI-unreached surface belong in 'everything'" is itself a scope question this
design resolves as: **not in this pass** (HelixQA banks in this effort so far
consistently target the real, UI-reachable surface — the async/SSE
completeness question can become its own future sub-project item if the
operator wants it).

## Architecture

One `helixqa http` bank file, at `submodules/qa/banks/workshop/`:

- `ask.yaml`

Every case uses the structured `http:` action type exclusively, `auth:
admin` for authenticated cases.

## Data flow / cases to encode

1. **`GET /api/ask/status` reports the real, current capability** —
   `enabled`/`suspended`/provider fields reflect the live `none` state
   (read the real handler for exact field names, don't assume).
2. **`GET /api/ask/status` requires auth** — confirmed live in research
   (`curl` with no auth → 401 `authentication required`); a direct
   regression pin.
3. **A well-formed question with no provider → 503 `no_provider`** — the
   one honestly-reachable "asked a real question" path today. Assert the
   exact `reason.code` from the research (`no_provider`), not a generic
   503.
4. **Empty question → 400 `empty_query`** — distinct from the 503 path
   (empty is a fourth thing, not a fourth answer-state, per the research).
5. **Question exceeding `MaxQuestionBytes` (2000) → 413.**
6. **Health-checked-before-job**: confirm (from the real response, or by
   timing if the response itself doesn't say so) that a `no_provider`
   result returns immediately rather than after any generation attempt —
   read `pkg/answer`'s `Health()`-before-job-creation logic to know exactly
   what to assert here, don't guess at timing thresholds.
7. **Search stays reachable while ask is down** — one `GET /api/search`
   case in this bank (or cross-referenced from the search bank) confirming
   FR-025 isolation observably, without re-deriving the existing dedicated
   gate's internal proof.
8. **Unauthenticated `POST /api/ask` → 401**, matching the established
   discipline.

## What this bank does NOT cover, and why (documented, not silent)

- `answered`/`declined` states, citations, the six-member decline
  vocabulary, L1-L5 pipeline layers — unreachable with the live `none`
  provider; extensively unit-tested at the Go level already
  (`pkg/answer/*_test.go`); a future sub-project item if an operator
  re-enables a provider.
- Async/job/SSE endpoints — UI-unreached; a future sub-project item if the
  operator wants that surface tested.
- Non-English/`ambiguous` intent classification — this is a FRONTEND
  (`core/intent.ts`) heuristic gating whether the expensive leg even runs;
  since the expensive leg is unreachable today regardless (`none`
  provider), this has no distinct backend-observable behavior to bank
  right now — noted as a gap tied to the same provider-reachability
  decision as the pipeline states above, not a separate omission.

## Testing discipline

Every reachable case gets a golden-bad control per the established pattern
— e.g., for case 2 (auth required), invert the auth check the same way
prior sub-projects have, confirm genuine FAIL, restore, confirm PASS again.

## Assumptions

- The live workshop server stays rebuilt and current for the duration of
  this sub-project.
- `helixqa http` (never `run`) only.
- Wired into `verify-helixqa-web.sh` via the same directory glob, no gate
  script change expected (confirm, don't assume).
- The answer-provider deployment setting (`none`) is NOT changed by this
  sub-project's implementer under any circumstance — if a task's own
  investigation suggests flipping it would "complete" coverage, that
  suggestion goes in the report as a recommendation for the operator, never
  as an action taken.
