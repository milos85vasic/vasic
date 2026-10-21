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

### Amendment 2026-10-21 (S2 round 7, delegate decision): run-limit eviction, lock deadline, watchdog, Idempotency-Key

- **Run limit is not permanent.** At the tracked-session bound (20000) sessions IDLE for 90 days (newest answer older than
  that, or no answer at all) are evicted together with their answer rows, so an evicted session returns at pass 0 with
  no earlier run visible. If nothing is idle a restart from a new session is 413 and the message says the limit is
  server-wide. The page shows a distinct notice (`restart-capacity`) and does NOT hold the learner's answers back: they go
  to the current run, as the notice says.
- **Lock deadline.** The cross-process lock is taken with LOCK_NB and a bounded retry (3 s); a lock held elsewhere is a
  503 naming the cause ("the practice store is busy"), never an unbounded stall behind the in-process lock.
- **Nothing waits forever.** Every read-back is tied to the load() that issued it (a generation token), a stale reply is
  ignored before it can touch the in-flight counter (which is also clamped at 0), and a watchdog (15 s) turns any waiter
  that nothing drove into a visible unsent answer (`pass_unknown`) / failed restart, resetting the bookkeeping.
- **Idempotency-Key from the UI.** The assessment submit sends one `Idempotency-Key` per PAPER: stable across resends of
  the same paper (a scoring failure `503 ... send the same paper again` is retried with the same key and scores once),
  fresh for a different paper and after any outcome that ends the paper. `409 idempotency_key_reuse` ("use a fresh key")
  makes the next press use a fresh key. The 503 and 409 texts differ.

### Amendment 2026-10-21 (S2 round 8, DELEGATE DECISIONS — each is operator-ratifiable and reversible)

- **D-8.1 Authenticated users are never evicted.** When the tracked-session bound (20000) is reached the server evicts
  ONLY anonymous `X-Session` ids that have been idle for 90 days, together with their answer rows. A session whose key
  is an account (`auth-user:<id>`) is never evicted and its answer rows are never deleted by this mechanism. If only
  accounts and active sessions remain, a new anonymous session's restart is the honest 413 ("a server-wide limit").
  Rationale: an anonymous id costs nothing to mint (so a bound is needed and idle ones are reclaimable); an account is
  a person's data. To reverse: allow `authhttp.ProgressKeyPrefix` sessions in `evictIdle` (one line) or raise the bound.
- **D-8.2 Idleness counts the last restart.** The pass file records, per session, the time of its last restart
  (`practice-pass.json` v2: `{"v":2,"sessions":{<id>:{"touched":<unix>,"areas":{...}}}}`; the earlier bare map is still
  read, its sessions simply have no restart time). A session's idleness is the newest of its last answer and its last
  restart, so a session that restarted and has not answered yet is not idle.
- **D-8.3 What the learner sees at the run limit.** "Run it again" is refused with 413. The page resets its deck locally
  and shows a persistent notice ("Run it again is unavailable right now: the server is at its limit of tracked practice
  runs ... Your answers are still being saved to the current run"). The answers the learner then gives OVERWRITE the
  current run's answers question by question (they are not a new run). After a reload the notice is shown AGAIN for as
  long as the page is still in the pass in which the refusal happened (stored per browser session user and deck in
  localStorage; cleared by any successful restart; ignored once the pass has moved), so a part-overwritten run is never
  silently presented as a run the learner just completed.
- **D-8.4 One attempt end to end.** A resend of an accepted paper under the same Idempotency-Key records ONE attempt in
  the learning-progress history: the binding carries an `attempted` fact (set once the attempt is written, re-binding
  the key if a twin had released it); a resend re-grades without recording. `ReleaseGradedKey` keeps a binding whose
  attempt is recorded. Limits: the first recording and its mark are two writes (a crash between them lets one resend
  record a second attempt); an evicted/expired binding starts a new generation (a deliberate second submission).
- **D-8.5 The Idempotency-Key survives a reload.** The assessment page stores the key per browser session user, area and
  paper fingerprint in sessionStorage (try/catch; the key then lives for the page only if storage is blocked) and clears it
  on success, 403, 409 and any other non-retryable outcome. The two 503s are told apart on the wire (`phase`:
  `submit_key_not_recorded` = nothing was submitted; `submit_not_scored` = answers received, not marked) and in words.

### Amendment 2026-10-21 (S2 rounds 9-10, DELEGATE DECISIONS — operator-ratifiable)

- **D-8.4 revised (supersedes the "attempted flag" mechanism).** The fact "this paper's attempt is already on record" is
  a MARKER ENTRY inside the learning-progress data (`Attempts["idem:<key>:<paper fingerprint>"]`), written in the same
  `SessionStore.Mutate` file write as the attempt; the check and the record are one step under that store's lock, so
  concurrent sends of one paper record ONE attempt and losing the scoring database cannot separate them. The scoring
  database's `attempted` column is retained in its API but no longer consulted by the submit handler.
- **D-8.6 Markers and key bindings expire together.** Markers older than `scoring.IdempotencyTTL` (24 h) are ignored and
  pruned (plus a cap of the newest 200). A resend after the TTL is a NEW submission in both stores: one new attempt,
  scored again — never "scored again but no new attempt". (Chosen over "never re-score when a marker exists" because the
  key binding is the scoring side's idempotency authority and already expires at the TTL.)
- **D-8.7 The ungated re-grade is bounded.** A resend of a recorded paper is graded through `ckit.Grade` (no gate, no
  record). Invariant: it is reachable only for the exact paper (same key AND fingerprint) that already passed the
  availability gate through `Submit` inside the TTL; any new paper, new key or expired marker takes the gated path
  (tests: `ARecordedResendNeverBypassesTheGateForANewPaper`).
- **D-8.8 Process model and durability of the stores (ops guide).** The practice stores (`practice-answers.json`,
  `practice-pass.json`) and the learning-progress store (`learning-progress.json`) serialise read-modify-write with an
  in-process mutex AND an exclusive advisory `flock` on `practice.lock` / `learning-progress.lock` in the data directory
  (3 s bounded wait; a stuck holder is a 503 "busy"), so two server processes sharing a data directory do not lose each
  other's updates; platforms without `flock` fall back to ONE PROCESS PER DATA DIRECTORY. The practice files are written
  temp-file + fsync + rename + directory fsync; `learning-progress.json` is rename-based but NOT fsynced (a power loss
  can lose the most recent write, never tear the file) — an open item if the operator wants fsync there too.

### Amendment 2026-10-21 (S2 round 11) — ops notes and small decisions

- **D-8.9 `learning-progress.json` is now durable** (supersedes the "not fsynced" open item of D-8.8): temp file + fsync
  of the file BEFORE the rename + directory fsync AFTER it (fault-injection seams pin the order).
- **D-8.10 Busy is not unreadable.** A lock held by another process is `ErrStoreBusy` -> 503 "the learning-progress store
  is busy ... nothing was lost, try again" (`phase: progress_store_busy`), mirroring the practice store.
- **D-8.11 Marker and binding agree at the TTL.** The attempt marker is stamped with the key binding's own stamp and
  both sides judge liveness with the same comparison on the scoring store's clock (live while `now - stamp <= TTL`).
- **Ops guide (lock files).** The three lock files (`practice.lock`, `learning-progress.lock`, in the data directory)
  are created mode 0600. Two server processes running as DIFFERENT users on one data directory therefore fail CLOSED
  (the second cannot open the lock file: 503), by design. Behaviour of `flock` on NFS/network filesystems is UNTESTED and
  not supported: keep the data directory on a local filesystem, one server per directory unless they share a user.
