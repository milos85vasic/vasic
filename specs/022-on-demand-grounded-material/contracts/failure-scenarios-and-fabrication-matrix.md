# Contract: Critical-Invariant Scenario Map and Fabrication Matrix (§11.4.239, §11.4.252, §11.4.254)

Three critical invariants: **(I1) no fabricated content reaches a learner**, **(I2) no spend or egress without an
explicit request and within bounds**, **(I3) one learner's materials and topics are not exposed to another**. The
scenarios below exist before code (T009 reviews them) and closure of the feature cites them.

## 1. Fabrication matrix (I1) — scripted provider outputs and the required verdict

The fake provider returns a scripted JSON/claim set for each row. Expected: the stated outcome, **0 persisted
materials**, matching reason, and (for `declined`) 0 generated text in the response. Oracle: this table, encoded as
`testdata/materialgen/fabrication_matrix.json` by an author other than the implementer (T013).

| # | Scripted provider output | Required outcome | Layer that must catch it | Paired mutation (layer removed) ⇒ test FAIL |
|---|---|---|---|---|
| F-1 | item cites a pid never shown in the prompt | `declined no_citations` | membership | skip membership |
| F-2 | item cites a real pid that was retrieved but gated out | `declined no_citations` | membership | admit gated-out pids |
| F-3 | item has an empty `citations` list | `declined no_citations` | membership | allow empty citations |
| F-4 | quote is not a substring of the cited passage | `declined unsupported` | verbatim | skip verbatim |
| F-5 | quote verbatim, claim contradicts the passage | `declined unsupported` | entailment | skip entailment |
| F-6 | claim supported but answers a different topic | `declined does_not_answer` | relevance | skip relevance |
| F-7 | one bad item among five good ones | `declined` (whole), not 4 items | all-or-nothing rule | strip bad item silently |
| F-8 | more items than requested | `declined malformed_output` | shape | trim extras |
| F-9 | unknown JSON field / non-JSON / truncated JSON | `declined malformed_output` | strict parse | lenient parse |
| F-10 | zero items | `declined no_items` | shape | return empty `generated` |
| F-11 | oversize field | `declined malformed_output` | shape limits | skip limits |
| F-12 | output contains markup/script in text | stored text sanitised on render (no execution); structural parse unaffected | render sanitiser | disable sanitiser |
| F-13 | cited passage suppressed between generation and delivery | `declined redacted_evidence` | suppression recheck | skip recheck |
| F-14 | entailment judge errors / times out | `unavailable verification_unavailable` | fail-closed rule | treat error as "supported" |
| F-15 | topic text instructs "ignore the sources" and the scripted model obeys by emitting an uncited claim | `declined no_citations` | membership (the real defence) | none — prompt wording is not a defence and is not tested as one |

## 2. Scenario map (given / when / then)

| ID | Invariant | Scenario | Test (named oracle) | Paired mutation |
|---|---|---|---|---|
| S-1 | I1 | all rows F-1…F-15 | `TestFabricationMatrix` — oracle: matrix JSON | per-row, above |
| S-2 | I1 | thresholds uncalibrated (`min-score=0`) | `TestUncalibratedNeverGenerates` — oracle: stub count 0, `thresholds_uncalibrated` | treat 0 as "no floor" ⇒ FAIL |
| S-3 | I1 | uncovered topic (fixture corpus has no passage on it) | `TestUncoveredTopicDeclines` — oracle: stub count 0 | lower coverage minimum to 0 ⇒ FAIL |
| S-4 | I2 | boot + idle + other endpoints | `TestNeverUnasked` — oracle: stub count 0 | add warm-up ⇒ FAIL |
| S-5 | I2 | over-budget at each boundary; 50 concurrent | `TestBudgetBoundaries`, `TestBudgetConcurrency` — oracle: hand table / Python oracle | per `budget-and-cost-guards.md` §3 |
| S-6 | I2 | remote provider without allow flag / without ack / audit unwritable | `TestEgressPreconditions` — oracle: stub count 0 | per `audit-and-egress.md` §4 |
| S-7 | I2 | audit equality + no content in audit | `TestAuditEquality`, `TestAuditHasNoContent` — oracle: stub counter, canaries | per `audit-and-egress.md` §4 |
| S-8 | I3 | learner A requests B's material id / job id / list | `TestMaterialsOwnerOnly` — oracle: seeded ids, expects 404 (not 403, so existence is not leaked) | drop the owner predicate ⇒ FAIL |
| S-9 | I3 | admin role reads own materials only on user routes; admin list logs each access | `TestAdminAccessIsLogged` — oracle: access-log row count | skip logging ⇒ FAIL |
| S-10 | I3 | cache row contains no session/topic linkage | `TestCacheHasNoPersonalLinkage` — oracle: column scan for session/topic canaries | store topic in cache ⇒ FAIL |
| S-11 | I2 | each dependency down: retriever, verifier, budget store, cache store, audit file, provider | `TestFailClosedMatrix` — oracle: expected code per dependency, stub count and persisted rows | map error to success ⇒ FAIL |
| S-12 | I1/I2 | crash mid-generation (kill -9 the worker) | `TestCrashRecovery` — oracle: job `unavailable interrupted`, reservation released, no partial material | skip recovery ⇒ FAIL |
| S-13 | I1 | credentials/keys never in logs, audit, errors, material | `TestNoCredentialLeak` — oracle: canary key scan | log request headers ⇒ FAIL |
| S-14 | I1 | boot invariants: invalid budgets, enabled-without-store | `TestBootRefusesInvalidConfig` — oracle: table of invalid configs | accept zero limits ⇒ FAIL |
| S-15 | I2 | static: single `Generate` call site | `verify-materialgen-single-callsite.sh` — oracle: call-site list | add a second call ⇒ gate FAIL |

## 3. Capability matrix (§11.4.254)

| Capability | Requires | When missing |
|---|---|---|
| `materials` | enabled flag, provider ≠ none, calibrated thresholds, `materials.db` writable, verifier available | determined `unavailable` with the specific code; routes still register; Q&A and search unaffected |
| `materials_remote` | allow-remote, audit sink writable, 011 audit writer | `provider_disabled` / `audit_unwritable` |
| `materials_admin` | admin role | `403` |

## 4. Honest boundary

- This map proves the **mechanism** refuses classes of bad output. It does not prove the entailment judge's recall.
  The enablement measurement (FR-022, T060) is the only statement about residual fabrication, and it is a bound
  from a finite set, not a guarantee.
- F-15 documents that prompt wording is not treated as a defence; only the post-hoc layers are.
