# Quickstart: Validating the Learning-Medium Profile

All commands run from `workshop/` unless stated. Authenticated calls use the repository's own helper:
`source scripts/_live_auth.sh; AUTH="$(ws_live_auth_header "$BASE")"` (it reads the seed password from
`WORKSHOP_TEST_SEED_PASSWORD`; never write a credential into this file or the evidence).
`BASE` defaults to `http://127.0.0.1:8087`. Worktree streams verify against an isolated throwaway server
(architecture plan §2.2 item 6), never by restarting the live stack.

## Prerequisites

- Spec 013 US1 merged (response log + practice submit). Until then only Scenario 0 runs.
- `go build ./...` clean; `PATH` has `python3`; Playwright installed (`npm ci` in `platform/frontend`).
- Record the build stamp from `GET /api/health` (`build_id`, `source_dirty`) in every evidence file.

## Scenario 0 — pure algorithm against the golden fixtures (runs today)

```bash
cd platform/backend && go test ./pkg/medium/... -count=1 -run 'Golden|Determinism|Property|Boot' -v
python3 -I ../../pipeline/medium_reference.py testdata/medium/golden_worked_example.json | diff - testdata/medium/golden_worked_example.expected.json
```
Expect: PASS, empty diff (the hand-worked example of `data-model.md` §3: mcq `preferred`, z = 1.535).

## Scenario 1 — seeded demo learner (UI-visible)

```bash
scripts/seed-medium-demo.sh --base "$BASE" --learner demo-medium-a   # submits real answers through the API
curl -s -H "$AUTH" "$BASE/api/profile/medium" | python3 -m json.tool | head -60
```
Open `$BASE/profile/medium` signed in as the demo learner. **Operator sees**: a table with one row per question
format; a `preferred` badge on one format with "observed vs expected" and an evidence count; `no_clear_preference`
on another; `not_measurable` on short answer with the reason; a "Why?" disclosure listing entry counts.

## Scenario 2 — insufficient evidence never recommends

Create a fresh learner, submit 3 answers, open `/profile/medium`: every format shows `insufficient_evidence`, the
recommendation card says "no recommendation yet — N more graded answers needed", HTTP body has `"medium": null`.

## Scenario 3 — override and off

On `/profile/medium` pin "flashcard", reload the area page: hint says "you chose flashcards". Switch to "off":
page shows "medium suggestions are off", network panel shows no evidence body. "Reset my data" empties both.

## Scenario 4 — area page hint and practice selector (US3)

Open the demo learner's area page → hint with a "why" link. Open `/practice/<slug>`; choose the format selector
"Flashcards": only flashcard-kind questions remain; choose a kind with zero questions → explicit empty message.

## Scenario 5 — isolation (privacy-critical)

```bash
bash platform/gates/verify-medium-isolation.sh --base "$BASE"   # two learners, both directions, authenticated and X-Session
```
Expect 0 cross-reads of N ≥ 200.

## Scenario 6 — engagement opt-in (US4, only if shipped)

`POST /api/profile/medium/events` with consent off → 403; turn consent on in the UI, view a recording, check
`/api/profile/medium/activity` shows a bucket count and **no** change to any performance state.

## Scenario 7 — live verification evidence (machine-written)

```bash
scripts/verify-medium-live.sh --base "$BASE" --out ../specs/021-learning-medium-profile/evidence/live
sha256sum -c ../specs/021-learning-medium-profile/evidence/live/MANIFEST.sha256
```
Expect `result.json` with `"verdict":"pass"`, build stamp, per-check results, and a manifest whose hashes verify.

## Full-feature regression

`go test ./...` (backend), `npm run test:unit` + Playwright `e2e/medium.spec.ts` (frontend), `pytest` for the
reference oracle, then the gates `verify-medium-no-model.sh`, `verify-medium-isolation.sh` and their `prove-*`
mutation pairs. A single failing mutation-proof means the gate is blind and the feature is not done.
