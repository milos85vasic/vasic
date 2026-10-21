# Contract: Practice Answer Selection and Submission (US1)

This documents the CORRECT contract the fix must satisfy — i.e. the behavior FR-011 through FR-014
require — not a verified description of the current (broken) implementation. The exact current
endpoint shapes are confirmed during implementation (Phase 0 research / root-cause step), not
assumed here.

## Client-side selection

**Contract**: clicking/tapping a multiple-choice option on a practice question MUST update visible
UI state synchronously (no network round-trip required to show a selection) and MUST remain
selected until changed or submitted.

- **Input**: a user interaction event on one option of a rendered question.
- **Output**: that option's visual state changes to "selected"; any previously selected option (for
  a single-select question) reverts to unselected.
- **Failure mode this fix must close**: no visible state change occurs at all (US1's primary
  suspected defect).

## Submission

**Contract**: `POST` (or equivalent) a submission carrying `question_id` + `selected_option` to the
practice-answer endpoint.

- **Success response**: acknowledges the write and returns the learner's actual result —
  `correct` / `incorrect` / `withheld` (per the platform's existing anti-cheating withheld-answer
  design, confirmed working for questions where selection itself succeeds) — never a generic
  "not recorded" failure under normal operating conditions.
- **Failure response** (only under genuine environmental failure, e.g. the progress-recording
  service being actually down): a response the UI renders as "An answer was not recorded", with
  enough detail that a distinct real outage is distinguishable from this defect once fixed.
- **Idempotency**: resubmitting the same `question_id` + `selected_option` (the "Send again" path)
  MUST be safe to retry and, under normal operating conditions, MUST succeed rather than
  deterministically fail the same way every time.

## Read-back (persistence)

**Contract**: `GET` (or equivalent) a previously submitted answer's state for a given
`question_id` MUST return the same `result` that was returned at submission time, after a page
reload or revisit — not an empty/reset state.

## What this contract does NOT claim

- It does not assert which HTTP method, path, or payload shape the current implementation actually
  uses — that is confirmed by the implementer reading the real endpoint during the fix.
- It does not change the existing withheld-answer-key design (the ~98%-of-questions
  answer-withholding behavior already shipped and verified working) — only the broken
  selection/acknowledgment/retry path around it.


## Reconciled by S2 on 2026-10-20: the answer record (`PUT/GET /api/areas/{area}/practice-answers`)

The submission/read-back contract above is realised by `PUT /api/areas/{area}/practice-answers/{question}`
(idempotent upsert; an identical resend is `replay: true`) and `GET /api/areas/{area}/practice-answers`. Refusals:
`400 malformed_pid` / `unknown_parameter` (unknown JSON keys included), `404 question_not_found` (not in the bank,
not in this area, or not served by the deck), `413 practice_answers_full` (the session already holds the per-session
maximum of 5000 distinct answered questions; changing an existing answer is still allowed), `503` when the store, bank
or registry cannot be read (never an empty 200).


## Amendment 2026-10-20 (S2 round 5, delegate decision recorded in the operator-decision style): the run PASS is owned by the server

**Decision.** "Run it again" is an explicit SERVER call, not a client-side bookmark. The server keeps one
integer `pass` per (session, area), starting at 0; every stored answer carries the pass it was given in, and the
read-back returns ONLY the current pass's answers. The previous design (a localStorage timestamp marker compared
with the server's answer times) was withdrawn after three review rounds each found a new interleaving it could not
cover (double restart, restart during the read-back, failed read-back, two tabs, same-second stamps, reload
mid-flight); per Constitution 11.4.250 a tower of heuristics signals a missing primitive, and the primitive is the
server-owned pass number.

**Wire shape.**
- `GET /api/areas/{area}/practice-answers` -> `{status, area, pass, answers}`; `answers` holds only answers recorded in `pass`.
- `PUT /api/areas/{area}/practice-answers/{question}` body may carry `pass`: the pass the client believes it is in.
  Absent = no claim (accepted at the current pass). A different value -> `409 pass_stale` with the current `pass` in
  the body; nothing is stored. The stored record and the reply carry `pass`. An identical answer in a NEW pass is a
  fresh record (`replay: false`, `attempts: 1`); within one pass an identical resend is `replay: true`.
- `POST /api/areas/{area}/practice-answers/restart` body empty or `{"pass": n}` (the pass being left) -> `200
  {status, area, pass}` with the new pass. With `pass` given and not current -> `409 pass_stale` with the current pass and
  nothing moves, so a retry whose reply was lost, and a restart from a second tab, are safe and idempotent.
  Refusals: 400 (no X-Session, unknown body key), 404 (area with no practice questions), 413 (run limit), 503.

**Client behaviour.** No timestamp, no marker, no heuristic: on load the client reads `{pass, answers}`; on restart it
calls the endpoint and adopts the returned pass; a write that is issued while the restart call is in flight waits for
it and carries the new pass; a late reply from an earlier pass is recognised by its pass number (or by the local
restart epoch) and dropped; a `409 pass_stale` makes the client adopt the current pass, re-read, and tell the learner
the run was restarted elsewhere. A restart that could not be recorded keeps new answers waiting (never filed under the
old pass) and is retried by "Send again".

**Migration.** Existing answer rows have no `pass` field and are pass 0 (`practice-pass.json` is created on first
restart). The legacy `workshop-practice-restart:<user>:<slug>` localStorage marker written by earlier builds is IGNORED
(the client removes it).

**Known limits (stated, not hidden).** `pass` is per (session, area): a signed-in account's session key is the
account, an anonymous browser's is its X-Session value. The pass store is a JSON file guarded by one process-wide lock
(the same single-writer assumption as the answer file).

### Amendment 2026-10-21 (S2 round 6, delegate decision): unknown pass, lower-pass 409, corrupt pass file, locking

- **Unknown pass (D3, decided).** The client NEVER sends an answer without a `pass` claim and never sends a restart
  blind. When the read-back failed (pass unknown) a write or a restart first learns the pass with one extra read; if
  that read also fails the answer is kept as an unsent answer ("An answer was not recorded", reason `pass_unknown`,
  resend with "Send again") and a restart is reported as not recorded (`restart-failed`). A claim-less write is still
  ACCEPTED by the server (older clients), so the guarantee is client-side by construction, not a server refusal.
- **Abandoned runs.** Answers held back behind a failed or in-flight restart belong to the run being abandoned; pressing
  "Run it again" again, reloading the deck, or adopting another tab's run drops them. They are never filed in a later pass.
- **409 with a LOWER pass (D4).** If the server reports a pass lower than the page's (its pass file was reset or
  restored) nothing was stored: the page adopts the server's number, keeps the answer as an unsent answer (reason
  `pass_reset_on_server`) and a resend names the server's pass. It is never dropped silently.
- **Lost restart reply (D5).** A restart call that got no reply is retried naming the same pass; a `409 pass_stale` of
  exactly that pass + 1 is that restart having landed, so no "restarted elsewhere" notice is shown.
- **Scoring binding (M2).** An accepted graded submit whose idempotency binding vanished before its keyed scoring (a twin
  request released it) is answered `503` ("recorded but could not be scored; send the same paper again with the same
  Idempotency-Key"), never a silent 200. The keyed scoring record also checks the binding's paper fingerprint and refuses
  a binding that now belongs to another paper (`409 idempotency_key_reuse`).
- **Pass file durability and recovery.** `practice-pass.json` and `practice-answers.json` are written temp-file + fsync +
  rename + directory fsync. A pass file that does not parse, or holds a negative pass, makes every practice route answer
  503; the server NEVER resets it to 0 on its own because that would make every earlier run's answers visible again.
  Recovery is an operator action: restore the file from backup, or delete it knowingly (all runs return to pass 0).
  The number of tracked sessions is bounded (20000; a restart from a NEW session beyond it is 413).
- **Concurrency.** Read-modify-write of both files holds an in-process lock and an exclusive `flock` on
  `practice.lock` in the data directory, so two server processes sharing the directory do not lose each other's updates
  (a second process waits, it is not refused). Platforms without `flock` fall back to the single-process assumption.
