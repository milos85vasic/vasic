# Contract: Privacy invariants and failure-path scenario map (constitution §11.4.239, §11.4.252, §11.4.254)

Privacy isolation is a **critical-invariant class** for this feature (a leak of one learner's performance profile
to another is the failure that matters). §11.4.239 requires the failure-path Given/When/Then scenarios to exist
**before code**, and closure to cite this map. Each scenario names its test and its paired mutation.

| ID | Given / When / Then | Test (named oracle) | Paired mutation (§1.1) |
|---|---|---|---|
| P-1 | Given learners A and B with distinct seeded responses, when A calls any medium endpoint with B's `X-Session` absent/present, then the response contains zero of B's entry ids or counts | `TestMediumIsolation` — oracle: the seeded fixture's set of B entry ids | handler ignores session and reads "newest session" ⇒ test must FAIL |
| P-2 | Given an admin-role caller, when they call any medium endpoint, then they receive only their own data | `TestAdminGetsNoLearnerView` — oracle: admin fixture ids | handler widens scope for `role=admin` ⇒ FAIL |
| P-3 | Given scoring store unreadable, when GET medium, then `503 scoring_store_unreadable`, never 200/empty | `TestStoreFailureIsUnavailableNotEmpty` — oracle: injected failing source | map `err` to empty slice ⇒ FAIL |
| P-4 | Given mode `off`, when GET medium or recommendation, then no evidence bodies and no recommendation | `TestOffMeansNothingComputed` — oracle: spy source records 0 reads | skip the off check ⇒ FAIL (spy sees reads) |
| P-5 | Given consent off, when POST event, then 403 and 0 rows | `TestEventsRequireConsent` — oracle: row count query on `medium_event` | remove the consent check ⇒ FAIL |
| P-6 | Given an event with an extra field (e.g. `text`), when POST, then 400 and 0 rows | `TestEventShapeIsClosed` — oracle: golden rejected payloads | decoder without `DisallowUnknownFields` ⇒ FAIL |
| P-7 | Given a retried POST with the same `idem_key`, when replayed N=20 times (some concurrent), then exactly 1 row | `TestEventIdempotency` — oracle: `SELECT COUNT(*)` | drop the UNIQUE constraint ⇒ FAIL |
| P-8 | Given DELETE, when called, then 0 rows remain for the session and other sessions' rows are untouched | `TestResetIsScopedAndComplete` — oracle: counts per session before/after | `DELETE` without session predicate ⇒ FAIL |
| P-9 | Given observation rows whose session differs from the caller (adapter bug), when the reader runs, then it refuses (`session_mismatch`) rather than computing | `TestReaderAssertsSession` — oracle: injected foreign-row source | remove the assertion ⇒ FAIL |
| P-10 | Given the same inputs in any order, when computed, then byte-identical output | `TestDeterminism` — oracle: first run's bytes | iterate a map into output ⇒ FAIL (shuffle test) |
| P-11 | Given a corrupt log row (NaN difficulty), when computed, then the row is dropped and counted in `unmapped`; aggregate stays finite | `TestNonFiniteRowIsDropped` — oracle: reference computed without the row | feed NaN through ⇒ FAIL |
| P-12 | Given an invalid threshold config, when the server boots, then it refuses to start naming the key | `TestBootRefusesBadThresholds` (§11.4.254) | accept `NMin=0` ⇒ FAIL |
| P-13 | Given no model/network capability allowed, when `pkg/medium` is built, then its dependency set excludes network/model packages | `verify-medium-no-model.sh` (static gate) — oracle: `go list -deps` output | add an import of `pkg/answer` ⇒ gate FAIL |

## Capability-matrix row (§11.4.254)

| Capability | Requires | When missing |
|---|---|---|
| `medium_profile` | scoring store (013) + question-kind lookup | routes answer `503 scoring_store_absent`; no panic, no empty-200 |
| `medium_engagement` | `medium.db` writable + consent | `403`/`503`; signal path unaffected |

## What is deliberately NOT protected here (honest boundary)

- The append-only response log (013) is not erasable by this feature; see OD-4.
- An anonymous `X-Session` value is a bearer-like identifier chosen by the client: anyone who knows another
  learner's `X-Session` string can read that anonymous learner's profile. This is inherited from spec 015's
  identity model, not introduced here; it is recorded so it is not mistaken for a guarantee.
