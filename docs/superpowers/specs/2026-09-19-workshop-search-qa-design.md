# Design: Exhaustive HelixQA Coverage — Workshop Search

**Status**: Approved in chat 2026-09-19 (operator: "all, one by one, subagents
driven"). Third of 8 planned sub-projects.

## Scope of this sub-project

`GET /api/search` and `GET /api/suggest` — the lexical/semantic retrieval
surface, reached in the frontend via `InquiryComponent`'s `data-mode="search"`
pane (`data-testid="search-pane"`), **not** the `data-mode="answer"` pane
(that's the separate Ask/Q&A sub-project, sharing the same component but a
functionally distinct backend path). Also in scope: `GET
/api/passages/{pid}/crossrefs`, since it shares the same `Envelope`
three-state contract and the same `PublicationGate` instance as search, even
though it is invoked from the transcript reader, not the search pane.

Out of scope (separate sub-projects, or already covered elsewhere): the
`answer`-mode pane and its provider (Ask/Q&A sub-project); `GET
/api/passages` and `GET /api/passages/{pid}` direct-access routes (arguably
belong here or to a "passages/terms" sub-project — see Open Question below);
`GET /api/terms`/`GET /api/terms/{term}` (same open question);
`GET /api/index/status` (diagnostics/status sub-project).

**Open question, resolved for this design**: `/api/passages`,
`/api/passages/{pid}`, `/api/terms*` are direct-access/lookup routes, not
search/ranking routes — they don't exercise the `Envelope` decision ladder
that is this sub-project's centerpiece. They are LEFT OUT of this
sub-project and folded into the future "Diagnostics/Status" or a dedicated
pass, to keep this sub-project focused on the actual search/ranking
contract per the research's own recommended focus.

## Why the `Envelope` decision ladder is the centerpiece

`pkg/search/envelope.go:540-698`'s `NewEnvelope` is a priority-ordered
6-branch decision ladder existing specifically to never collapse "answered,
found nothing" (`no_match`) into the same bucket as "could not be answered"
(`unavailable/*`) — a design born from a real historical bug in
`ai_interviewing`'s own search component. Each of the 6 branches is a
distinct, real, live-triggerable server behavior:

1. Named total failure → `unavailable`
2. Any results → `ok`
3. Zero results, no enabled leg ran → `unavailable/no_leg_executed`
4. Zero results, every `kinds=` filter value has zero indexed entries →
   `unavailable/kind_not_indexed`
5. Zero results, any leg failed / degraded caveat → `unavailable/partial_failure_zero_results`
6. Every leg succeeded, found nothing → `no_match` (the ONLY genuine
   "nothing matches" case)

A bank that doesn't hit all 6 branches with real, live-triggered inputs is
not exhaustive coverage of this surface, regardless of how many other cases
it has.

## Architecture

One `helixqa http` bank file, at `submodules/qa/banks/workshop/`:

- `search.yaml`

Every case uses the structured `http:` action type exclusively. Search is
authenticated like every other route (`wrapWithAuth` exempts only
`/api/health` and `/api/auth/*`) — every case uses `auth: admin` unless it is
specifically testing the unauthenticated-401 case.

**Verify before writing any case, not assumed from research**: the research
doc flags that at investigation time an UNCOMMITTED, unrelated golden-bad
mutation was temporarily present in `main.go` (from a concurrent
sub-project's own WK-CHLIST-002 test-and-revert cycle). Confirm
`git diff -- platform/backend/cmd/workshop-server/main.go` is clean and
`source_commit == HEAD` before trusting any live auth-behavior observation.

## Data flow / cases to encode

1. **Branch 2 (`ok`)** — a real query with real results (pick a term/phrase
   confirmed live to hit the lexical or semantic index), asserting `status:
   "ok"` and at least one `Hit` with the documented fields present.
2. **Branch 6 (`no_match`)** — a real, well-formed query guaranteed to match
   nothing (e.g. a nonsense token unlikely to exist in the corpus, confirmed
   live first), asserting `status: "no_match"`, not `unavailable`.
3. **Branch 4 (`kind_not_indexed`)** — `kinds=` filtered to a real,
   known-but-currently-empty kind (confirmed live which kind currently has
   zero rows — the research notes `kg_*` kinds have real rows but are
   EXCLUDED from `indexed_kinds` entirely because the publication gate
   withholds every row of them, so `kg_*` may not even be a valid `kinds=`
   value — read the real allow-list in `router.go`/`search.go` before
   picking a kind for this case, don't assume `kg_*` works).
4. **`kinds=<unknown>` → 400** — a genuinely unknown kind name, distinct from
   case 3's known-but-empty kind (research finding: easy to conflate, worth
   a dedicated pair).
5. **Empty query → 400 `empty_query`** — never a 200 with empty results.
6. **`q` exceeding 8192 bytes → 413.**
7. **Unknown query parameter → 400** (allow-listed params).
8. **`limit` out of range** (below 1 or above 100) — confirm the real
   clamping/rejection behavior by reading the handler, don't assume 400 vs.
   silent-clamp without checking.
9. **Pure-punctuation query** — tokenizes to zero tokens per the research,
   short-circuits into the ladder (which branch exactly — confirm live,
   don't assume it's `no_match` vs `unavailable/no_leg_executed`).
10. **Redaction-in-search-results at the HTTP level** — `GET
    /api/search?q=<a term known to appear only in redacted content>` must
    NOT return that passage. This is complementary to, not a duplicate of,
    G-KG-25's internal lexical-leg proof — it targets the HTTP-observable
    behavior directly. Read the research's note that only the lexical leg
    has a dedicated paired-mutation gate for this; the semantic/catalog/
    crossrefs redaction paths exist in code but have no equivalent proof —
    if a real semantic-mode redacted-content case can be constructed and
    live-verified here, it closes part of that gap.
11. **`GET /api/suggest`** — at least one real case exercising the
    catalog-based suggestion path, including `dropRedactedTargets`
    re-checking the live DB (a redacted term should not appear as a
    suggestion even if the in-memory catalog is stale).
12. **`GET /api/passages/{pid}/crossrefs`** — at least one real case with a
    real `pid`, and one with a redacted/dangling target to confirm it's
    dropped (both during traversal AND via the belt-and-braces
    registry-re-resolve strip, per the research — a single case that
    confirms the OBSERVABLE result is enough; this bank does not need to
    distinguish which of the two internal mechanisms fired).
13. **Unauthenticated access** to `/api/search` → 401, matching the
    established discipline elsewhere.

## Testing discipline

Every case gets a golden-bad control per the established pattern. The
redaction-in-results case (10) is the highest-value golden-bad target: invert
the lexical `redacted = 0` filter (or the wrapping `dropRedactedTargets`
check) to prove the bank genuinely catches leaked redacted content, restore,
confirm PASS again — this is the single most security-relevant case in this
whole sub-project and must not be skipped or weakened.

## Assumptions

- The live workshop server stays rebuilt and current for the duration of
  this sub-project; re-confirmed at the start of every task per the Global
  Constraints (same discipline as every prior sub-project).
- `helixqa http` (never `run`) only.
- Wired into `verify-helixqa-web.sh` via the same directory glob, no gate
  script change expected (confirm rather than assume, per prior sub-projects'
  own discipline of not trusting a stale assumption about a shared gate).
- No new fixture chapters or filesystem state needed — this sub-project
  operates entirely against the existing corpus and existing redaction
  state.
