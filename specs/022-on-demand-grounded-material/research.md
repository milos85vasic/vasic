# Phase 0 Research: On-Demand Grounded Material Generation

Status key: **MEASURED** (checked this session, 2026-10-20), **UNCONFIRMED** (task closes it), **HYPOTHESIS**.

## 0. Baseline (MEASURED unless marked; paths relative to `workshop/`)

| Fact | Evidence |
|---|---|
| Provider seam: `Descriptor` / `Health` / `Generate(ctx, GenRequest, ProgressFunc) (GenResult, *Reason)` | `platform/backend/pkg/answer/provider.go:34-50` |
| `GenResult` = answerable flag + claims keyed by pid + `GenStats` (estimated prompt tokens, output tokens, timings) | `provider.go:52-95` |
| Three-state outcome with closed, disjoint vocabularies; decline = 200, unavailable = 503 | `pkg/answer/outcome.go:54-300` |
| Prompt builder with label↔pid map and bounded budget; invented labels resolve to nothing | `pkg/answer/prompt.go:21-160` |
| Pipeline layering L1 gate → provider → L3 citations → L4 support → L5 relevance | `pkg/answer/pipeline.go:178-520` |
| Reusable grounding functions: `RetrievalGate`, `ValidateCitations`, `ValidateVerbatim` | `submodules/RAG/pkg/grounding/grounding.go:193,282,322` |
| Entailment judge package | `platform/backend/pkg/entail/` |
| Answering is OFF in compose; `min-score` default 0 = uncalibrated ⇒ refuses | `platform/compose.yml:553`; `cmd/workshop-server/main.go:545`; `pkg/answer/pipeline.go:24-31` |
| Hosted-provider guards: allow-remote required; credential scrubbing | `pkg/answer/hosted.go:96-110,225-240`; `provider.go:200-205` |
| Locality verification | `pkg/answer/locality.go:27-60` |
| 011 audit writer not built (T007–T014 unchecked); contract leaves audit-failure policy open | `specs/011-multi-provider-llm-providers/tasks.md` Phase 4; `contracts/remote-generation-audit-log.md` §2 |
| Authoring is offline and citation-mandatory | `pipeline/extract/author.py`; `platform/backend/pkg/assessment/question.go:141-145,231` |
| Auth roles `admin`/`user` exist | `platform/backend/pkg/authstore/authstore.go:47` |
| Existing answering calibration/measurement artefacts exist | `platform/backend/evidence/answering/` (`CALIBRATION.tsv`, `MEASUREMENT-generation-15-2026-09-24.md`, …) |
| Frontend has a markdown sanitiser to reuse | `platform/frontend/src/app/core/markdown.ts` (T002 confirms it sanitises) |
| Fabrication / answer-rate figures (14/72 answered, 4/87 fabricated) | quoted from the umbrella governance record; **UNCONFIRMED here — T008 re-derives from the measurement file** |

## 1. Why reuse `answer.Provider` and the answering layers rather than a new pipeline

The hard-won property of the answering stack is that *a decline and an outage are different values* and that
model claims are never trusted. Re-implementing that for materials would fork the vocabulary and the bugs. The
only new logic is what answering does not have: multi-item output shapes, an all-or-nothing rule over items,
budgets, a cache, and per-attempt auditing for non-local providers.

## 2. Why corpus-only (REQ-3 interpretation) — OD-2

REQ-3 can be read two ways: (a) *re-compose what the corpus knows into new forms for a need*, or (b) *go beyond the
corpus*. (b) cannot be citation-mandatory by definition; the research document itself frames the opportunity as
extending the citation-mandatory discipline to a generative mode (REQ-3 row, §5). This spec implements (a) and
declines honestly when the corpus lacks coverage, routing the operator to ingestion (REQ-2). The reading must be
confirmed with the client and operator; the client's identity is UNCONFIRMED (research doc §6), so the spec
invents no further requirement.

## 3. Quiz (MCQ) deferral — HYPOTHESIS to settle (OD-4)

A multiple-choice item needs wrong answers. Wrong answers are not corpus claims, so they cannot satisfy
membership/verbatim/entailment — they would be exactly the "ungrounded text" this feature forbids, or a second,
weaker verification regime. Options to evaluate later: (i) forbid; (ii) allow model-written distractors flagged
"not from the corpus" and never counted as evidence; (iii) derive distractors from *other verified claims* in the
same retrieval set (every distractor is itself a grounded claim, wrong *for this question*). (iii) preserves
grounding and is the candidate to research; it is not specified here.

## 4. Failure-mode analysis of small local models (HYPOTHESIS → T003/T060 measure)

The host's local generative model is a small instruct model (3B-class per the governance record). Multi-item
structured JSON output is harder than single-answer prose: truncation, schema drift, repeated items, citation
label confusion. Consequence: expect many `malformed_output` declines with a small model; that is acceptable
(decline over fabricate) but affects usefulness and is exactly why enablement is gated on a measurement, and why
`malformed_output` is a first-class, counted decline reason rather than a retry loop. **No automatic retry**: a
retry multiplies spend and, with a stochastic model, can launder a failure into a pass; a retry is a learner action.

## 5. Cache correctness reasoning

Cached value = output of verification against a *specific corpus generation*. Keying by generation guarantees that
a re-ingest cannot serve claims validated against older text. The additional serve-time re-validation (live pids,
suppression) covers the case where a redaction lands without a generation bump. Declined results are cached
because, for a fixed generation, retrieval and gating are deterministic, so re-asking cannot succeed and would only
spend; **UNCONFIRMED**: whether retrieval is bit-for-bit deterministic for a fixed generation (the platform has a
`pkg/search/determinism.go`; T006 checks), without which declines should be cached with a short TTL instead.

## 6. Budget design alternatives

| Option | Verdict |
|---|---|
| Mutable counter row | rejected: can drift from the rows that justify it; a crash between update and insert corrupts it |
| Derived sum over reservation rows in one transaction (chosen) | auditable, crash-safe, concurrency-safe |
| In-memory token bucket | rejected: lost on restart ⇒ a restart loop becomes a spend loop |
| Provider-side limits only | rejected: not available for local/LAN, and not under this platform's control |

## 7. Security notes

Prompt injection from passage text or topic is assumed; defence = post-hoc layers (F-15), strict schema, sanitiser,
no tool use, no secrets in prompts, and no ability for generated text to influence any control path. Egress is the
real exposure (private corpus); it is gated by operator flag + per-request acknowledgement + audit-before-return.

## 8. Open research tasks

- **R-1** (T003) deep multi-angle web research (§11.4.150): faithful/citation-grounded generation, hallucination
  detection in RAG, structured-output reliability of small models, prompt-injection in RAG, caching and
  budgeting for LLM services. Cite primary sources here.
- **R-2** (T004) the exact semantics of 011's audit call sites (per attempt or per construction).
- **R-3** (T005) how answering builds its retriever and applies suppression; reuse points.
- **R-4** (T006) corpus-generation identity and retrieval determinism.
- **R-5** (T008) calibration state and re-derivation of the quoted answering figures.

## 9. UNCONFIRMED register

011 audit semantics; calibrated thresholds in effect; retrieval determinism; local model fitness; whether
`pipeline/extract/author.py` exposes a callable promotion path (OD-7); language behaviour for non-English topics;
client identity and per-client corpus needs.
