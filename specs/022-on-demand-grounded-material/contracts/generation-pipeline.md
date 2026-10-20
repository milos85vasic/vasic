# Contract: Generation Pipeline (FR-002 – FR-005, FR-010, FR-011, FR-020, FR-021)

One orchestrator, `materialgen.Generator.Run(ctx, job)`, called from exactly one place (the request handler's
background worker for that job). Stages are ordered; every stage failure maps to exactly one outcome; **no stage
after the provider call may leave a persisted partial result**.

## Stages

| # | Stage | Pure? | Outcome on failure |
|---|---|---|---|
| 0 | Enabled? (`-materials-enabled`) | yes | `unavailable generation_disabled` |
| 1 | Provider present (`Descriptor`) and not `none` | yes | `unavailable no_provider` |
| 2 | Thresholds calibrated (`MinScore > 0`, `MinMargin ≥ 0`) | yes | `unavailable thresholds_uncalibrated` |
| 3 | Validate + normalise request; remote-ack check | yes | `400` (not a three-state outcome) |
| 4 | Cache lookup + single-flight (contract `cache-and-idempotency.md`) | no | hit ⇒ re-validate (stage 11) and return |
| 5 | Budget reserve (contract `budget-and-cost-guards.md`) | no | `unavailable budget_exceeded` / `rate_limited` / `budget_store_unreadable` |
| 6 | Retrieve (`Retriever.Retrieve(ctx, topic, TopK)`), then **drop suppressed pids** | no | `unavailable retrieval_unavailable` |
| 7 | L1 gate: `grounding.RetrievalGate` with calibrated thresholds; coverage rule `distinct admitted ≥ MinDistinctPassages` | yes | `declined below_threshold|margin_too_small|insufficient_coverage` (0 provider calls) |
| 8 | Provider `Health`; egress + audit preconditions for non-local (contract `audit-and-egress.md`) | no | `unavailable provider_unreachable|provider_disabled|audit_unwritable` |
| 9 | Build prompt over the **admitted** set only; insert `generation_attempt`; call `Provider.Generate`; settle attempt; audit | no | provider `*Reason` ⇒ `unavailable` with its code |
| 10 | Parse strict JSON; shape limits; item count == requested | yes | `declined malformed_output|no_items` |
| 11 | Verify (in order): membership → verbatim → entailment → relevance; **any** failed item declines the whole material | no | `declined no_citations|unsupported|does_not_answer|redacted_evidence`; verifier cannot run ⇒ `unavailable verification_unavailable` |
| 12 | Persist atomically: `material_cache` + `material` + budget settlement in one transaction | no | `unavailable cache_store_unreadable` (nothing partial) |

A decline (stage 7, 10, 11) settles the budget with actual tokens used (stage 7 declines use none) and **is cached**
(FR-017). An `unavailable` result releases the unspent reservation and is **not** cached.

## Admission and the prompt

- The prompt contains: a fixed instruction block (versioned), the learner topic inside an explicit
  "untrusted request" delimiter, and the admitted passages each inside an "untrusted source" delimiter with a
  short label. The instruction block states that content inside delimiters is data, that every item must cite
  labels from the sources, and that the answer must be exactly the JSON schema. (Prompt-injection posture, FR-020;
  it is a mitigation, **not** the safety mechanism — the safety mechanism is stages 10–11, which do not trust the
  model.)
- Prompt size is bounded by `PromptBudget` semantics from `answer.BuildPrompt`
  (`pkg/answer/prompt.go:109-160`): passages are admitted by score, truncated at passage boundaries, and the label ↔ pid map is kept so
  labels the model invents resolve to *nothing* (membership failure), as in `Prompt.Resolve` (`prompt.go:40`).
- Estimated prompt tokens come from the same estimator `GenStats.EstimatedPromptTokens` reports
  (`provider.go:86-95`); the pre-flight estimate is an upper bound used for the reservation.

## Verification layers (what each one catches)

| Layer | Catches | Implementation seam |
|---|---|---|
| membership | invented / out-of-set / missing citation | `grounding.ValidateCitations` (`grounding.go:282`) against the admitted pid set |
| verbatim | quote not in the cited passage | `grounding.ValidateVerbatim` (`grounding.go:322`) |
| entailment | claim not supported by (or contradicting) the passage | `answer.SupportVerifier` / `pkg/entail` via `answer.VerifyClaims` (`pipeline.go:447`) |
| relevance | supported but irrelevant fragment copied from a related passage | `answer.QuestionVerifier` (`question.go:80`), question = `topic` |

Per-item verdicts are stored; a single failed item ⇒ whole material declined (FR-002), with the **first** failing
layer's reason in a fixed precedence (membership, verbatim, entailment, relevance) so outcomes are deterministic.

## What is deliberately not guaranteed (honest boundary)

- Entailment and relevance judges are models; they have false negatives. The measured fabrication bound (FR-022) is
  the statement about this residual risk, and the feature is OFF until the operator accepts that bound.
- A verbatim quote proves the quote exists, not that the *paraphrase around it* is faithful; that is the
  entailment layer's job and the reason it cannot be skipped.

## Call-site rule (FR-011)

`rg "\\.Generate\\(" platform/backend --glob '!*_test.go'` restricted to `pkg/materialgen` MUST show exactly one
call, inside `generator.go`'s stage 9, and `Run` MUST be referenced only from the job worker started by the
`POST /api/materials` handler. `verify-materialgen-single-callsite.sh` (T017) enforces both with a paired mutation.
