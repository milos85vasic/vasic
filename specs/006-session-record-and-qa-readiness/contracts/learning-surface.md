# Contract — The learning surface

## Routes

`/api/areas/{id}/lessons` · `/lessons/{lesson}` · `/lessons/{lesson}/state` ·
`/materials` · `/assessment` · `/assessment/submit`

**All six require the opaque `X-Session` header.** One channel only — a sibling
module accepts a session three ways, and three places to supply it are three
places for them to disagree.

**The client must send it.** It did not, and every area page rendered an error
card: `400` without, `200` with. The header builder is **one exported function**
consumed by every client.

## Lessons carry content

Every served lesson of a published area carries a non-empty **`body`** — declared
**upstream in the kit**, kept distinct from `summary`. Collapsing them was the
semantic lie that caused 339 bodies to be discarded on every build.

**Measured: 318 of 318 served, median 328 words, longest 4,563.** Twelve lessons
under 100 words are **short, not padded**.

## The assessment gate

While locked: **zero** prompts, options and answers, with the remaining
requirement stated and `pass_percent` shown **before** the attempt.

Enforced **by construction**: the taking projection is a map with **no answer
field at all**, so no future upstream field can leak by defaulting to present.

**And the lock is not bypassable one route over.** The practice deck and the
graded bank are the same authored rows — 224 of 224 match by prompt, 0 of 224 by
id — so gating practice would delete a feature the contract intends. Graded rows
are **withheld from the open route, and the withholding says so.**

**Fail-closed**: nil, unreadable **or stale** catalog withholds every key. A
graded prompt the snapshot never saw would look "graded nowhere" to a literal
index and be published.

## Absence must be true

An area with no assessment states **only what the server established**. It may
not claim "there is genuinely none" unless that has been determined — the
snapshot may only license what it holds.

**Measured: 27 of 39 areas serve a test, 205 questions; 12 carry none and each
says so with its evidence count.**

## Submission validation

`responses` is required and must be an array. A misspelled top-level key is
refused **400 naming the offending key**, before the store is touched — it
previously returned 200 and permanently recorded a 0% attempt. **`responses: []`
still grades**: a blank paper is a real submission.

## Asserted by

`verify-lesson-content.sh` (two arms: in-process **and live**) · prover 9
mutations · `verify-bank-reachability.sh` + prover 9 · `verify-answer-key-disclosure.sh`
+ prover **16** · `verify-submission-validation.sh` + prover **11**. Each carries
a vacuity refusal exiting 2 and **overreach mutations** — a practice-only question
stripped of its answer, a valid submission refused — which a gate written only
against the leak would have certified as correct.
