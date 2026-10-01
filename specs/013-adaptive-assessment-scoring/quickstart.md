# Quickstart: Adaptive Assessment and Real-Time Scoring

Two parts. Part 1 is runnable **today**, against the already-existing, already-labeled POC — it
re-establishes trust in the algorithm itself before any server code exists. Part 2 is the manual
API walkthrough for **once Phase 1 is implemented** (`pkg/scoring`, the two new routes, the
`GET /api/progress` extension) — every command in Part 2 is written against the contracts in
`contracts/`, but none of it has been run yet, because the endpoints do not exist yet. That
distinction is stated plainly rather than blurred, per this project's Evidence-Based Claims
principle.

## Part 1 — reproduce the algorithm's own evidence (runnable now)

The POC at `workshop/docs/research/education-platform/poc/adaptive_scoring_poc.py` is the exact
oracle data-model.md §3 cites for the Elo update, K-factor decay and downgrade logic. Re-running it
is not a formality — it is the §11.4.245 "oracle is independent of the code under test" discipline,
checked before any of that code is written.

```bash
cd workshop   # PRIVATE submodule; read-only for this feature — see plan.md's Summary
python3 docs/research/education-platform/poc/adaptive_scoring_poc.py --attempts 30 --seed 42
```

**Re-run in this session, 2026-09-30, and byte-identical to the research document's own captured
trace** (`sample-output-30-attempts-seed42.txt`) — the tail of the real output:

```
 30    5.50   wrong 0.122   5.293   5.241  -0.052  normal adaptive pick: nearest-difficulty item to current ability estimate

  final ability estimate : 5.241
  hidden true ability     : 5.000
  absolute error          : 0.241
  attempts                : 30 (16 correct / 14 wrong)
  downgrade events        : 1

=== Summary: convergence toward hidden true ability ===
                                      learner   true   est.    err downgrades
         Learner A (strong, true ability 8.5)   8.50   8.07   0.43          0
     Learner B (struggling, true ability 2.5)   2.50   2.67   0.17          5
        Learner C (average, true ability 5.0)   5.00   5.24   0.24          1
```

**What this run proves, and what it does not.** It proves the algorithm this feature implements —
the exact `K(n)` decay curve, the exact downgrade trigger/magnitude, the exact clamp-to-[0,10]
behavior — behaves sensibly and reproducibly, independent of this checkout's own future Go
implementation (the script is documented as standalone, imports nothing from `platform/backend`).
It does **not** prove `pkg/scoring`'s Go code is correct — that is what the unit tests named in
plan.md's Constitution Check (§11.4.224/§11.4.245) exist for, using this exact trace's `K` column
and `delta` column as the golden oracle values a Go `elo_test.go` asserts against.

**A second, independent reproduction — determinism itself**, since research §4 documents a real,
previously-caught determinism defect in this same script (a `PYTHONHASHSEED`-sensitive RNG seed,
fixed and re-verified across four separate invocations):

```bash
python3 docs/research/education-platform/poc/adaptive_scoring_poc.py --attempts 30 --seed 42 > /tmp/run1.txt
python3 docs/research/education-platform/poc/adaptive_scoring_poc.py --attempts 30 --seed 42 > /tmp/run2.txt
diff /tmp/run1.txt /tmp/run2.txt && echo "IDENTICAL — deterministic given a fixed seed"
```

## Part 2 — manual API validation (once `pkg/scoring` and the new routes are implemented)

Every request/response shape below is the literal contract from `contracts/practice-next.md`,
`contracts/practice-submit.md` and `contracts/progress-extension.md` — copy-pasteable once the
server is built, not a hypothetical sketch. Run against the local `workshop-curriculum_platform_1`
container (or a local `workshop-server` build) on its discovered port
(`_tools/containers/cmd/port-discover`, per this repository's own `scripts/qa-up.sh` convention —
**do not hardcode 8087**; re-derive it, per this project's Environment Adaptability principle).

```bash
BASE="http://127.0.0.1:$(discovered_port)"   # see scripts/qa-up.sh for the real derivation
SESSION="quickstart-$(date +%s)"
AREA="<a real area PID from GET ${BASE}/api/areas>"
```

### 2.1 Cold start: first recommended question

```bash
curl -s "${BASE}/api/areas/${AREA}/questions/next" -H "X-Session: ${SESSION}" | tee /tmp/next1.json
```

Expected (per `contracts/practice-next.md`): `selection.rule == "cold_start"`, `serving.served_difficulty`
at or near the lowest available difficulty across the practice bank and graded-catalog union
(FR-009 — the practice bank alone has zero `easy`-seeded items, research §2.1), and a
`serving.token` to carry into the next call.

```bash
QUESTION=$(jq -r '.question.id' /tmp/next1.json)
TOKEN=$(jq -r '.serving.token' /tmp/next1.json)
```

### 2.2 Submit an answer, observe the score move

```bash
curl -s -X POST "${BASE}/api/areas/${AREA}/questions/${QUESTION}/submit" \
  -H "X-Session: ${SESSION}" -H "Content-Type: application/json" \
  -d "{\"serving_token\": \"${TOKEN}\", \"chosen\": [0]}" | tee /tmp/submit1.json
```

Expected: `scoring.ability_before` at the 5.0 cold-start midpoint (data-model.md §2's no-response
default), `scoring.k_factor` near `0.9` (the POC's own `K(0)` value reproduced in Part 1),
`scoring.reason` non-empty, `ability.attempt_count == 1`, and a `next` object carrying the
following recommended question — satisfying SC-002 ("no observable delay") by construction: the
updated score is in the **same response**, not a value requiring a second read.

### 2.3 Confirm no staleness independently (SC-002, the actual acceptance test)

```bash
curl -s "${BASE}/api/progress" -H "X-Session: ${SESSION}" | jq ".ability_score[\"${AREA}\"]"
```

Expected: identical `ability`/`attempt_count` to what `2.2`'s response already reported — a
**second, independent** read confirming the first response was not merely echoing a value it never
actually persisted. This is the concrete re-run of SC-002's own acceptance language ("verified
across repeated submit-then-read sequences"), not a restatement of it.

### 2.4 Retry idempotency (§11.4.253 — the exact chaos-verification cases the anchor names)

```bash
# Simultaneous retries: same token, two concurrent callers.
curl -s -X POST "${BASE}/api/areas/${AREA}/questions/${QUESTION}/submit" \
  -H "X-Session: ${SESSION}" -H "Content-Type: application/json" \
  -d "{\"serving_token\": \"${TOKEN}\", \"chosen\": [0]}" &
curl -s -X POST "${BASE}/api/areas/${AREA}/questions/${QUESTION}/submit" \
  -H "X-Session: ${SESSION}" -H "Content-Type: application/json" \
  -d "{\"serving_token\": \"${TOKEN}\", \"chosen\": [0]}" &
wait
```

Expected: both responses carry the **same** `scoring.entry_id` (data-model.md §5.1's `serving_token
UNIQUE` column made this durable at the DB layer, not by an application-level race-prone check), and
`GET /api/progress` immediately after shows `attempt_count` incremented by exactly **1**, not 2 —
the concrete proof that a retried submit never double-counts.

### 2.5 Force and observe a downgrade (User Story 2)

```bash
for i in 1 2 3; do
  NEXT=$(curl -s "${BASE}/api/areas/${AREA}/questions/next" -H "X-Session: ${SESSION}")
  Q=$(echo "$NEXT" | jq -r '.question.id'); T=$(echo "$NEXT" | jq -r '.serving.token')
  # deliberately submit an answer known to be wrong for this question
  curl -s -X POST "${BASE}/api/areas/${AREA}/questions/${Q}/submit" \
    -H "X-Session: ${SESSION}" -H "Content-Type: application/json" \
    -d "{\"serving_token\": \"${T}\", \"chosen\": [999]}" | jq '.scoring.reason'
done
curl -s "${BASE}/api/areas/${AREA}/questions/next" -H "X-Session: ${SESSION}" | jq '.selection'
```

Expected: the 4th `GET …/next` call's `selection.rule == "downgrade"` and
`selection.downgrade_triggered == true`, with the served `serving.served_difficulty` measurably
below what the 3rd call's own `ability` estimate alone would have picked — the literal Independent
Test spec.md's User Story 2 names: "Confirm the fourth question served is measurably easier than
the question that would have been served by the normal nearest-to-ability selection rule."

## What this quickstart does NOT validate (honest boundary)

- **User Story 3's batch recalibration** has no manual curl walkthrough here — it is a background
  process, not a request/response surface. Its own validation is a unit/integration test asserting
  `ItemDifficultyState.DifficultyEstimate` moves after a batch of accumulated `response_log` rows
  (data-model.md §4's `Store.RecalibrateBatch`), per spec.md's own User Story 3 Independent Test.
- **The K-factor, logistic-divisor, and downgrade tuning constants** are demonstrated *sensible* by
  Part 1's reproduction, never *production-validated* — spec.md's own NEEDS CLARIFICATION items on
  this point are not resolved by running this quickstart, and this document does not claim they
  are.
- **UI rendering of any of the above** (badges, toasts, a visible score widget) is explicitly
  `014-gamification-design-system`'s scope, not this feature's, and nothing here exercises it.
