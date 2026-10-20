# Research: Answering Enablement + Provider Status UI

**Feature**: [spec.md](./spec.md) | Date 2026-10-20. Every claim cites a file or is marked UNCONFIRMED.
Private-content rule: no benchmark question text, cited passage or answer text is reproduced.

## R1. What the current numbers say, and why a one-sided gate is wrong

`workshop/platform/backend/evidence/answering/MEASUREMENT-generation-15-2026-09-24.md` §1 compares five
configurations on 24 answerable / 29 unanswerable (after dropping 4 contaminated rows), 3 repeats:
the deployed funnel (19% recall, 4.6% fabrication), retrieval gate held open (28% / 8.0%), ONNX
entailment L4 (8% / 0 of 87), Ollama LLM judge (0% / 0 of 87). The zero-fabrication rows are the
zero-recall rows. **Decision**: the gate is two-sided with Wilson bounds, not point estimates (a
0-of-87 result still has an upper bound of 4.2%, so "0 fabrications observed" cannot by itself clear
a 2% limit; the trial minimum in FR-008 exists for this reason).

## R2. Why the retrieval score cannot be the gate

Same file §2.1: with corrected labels, top-score AUC 0.497 and margin AUC 0.491, i.e. no separating
signal; with the original labels the margin is inverted (0.388). **Decision**: the new gate does not
try to be smarter about retrieval scores; it measures END OUTCOMES on a labelled set, which is the
only quantity the operator cares about. The thresholds stay as configuration that enters the
fingerprint, not as something the gate tunes.

## R3. Benchmark validity is a precondition (producer != oracle)

The v1 benchmark has 4 contaminated rows (question text indexed verbatim) and 9 U rows later found
answerable (MEASUREMENT §6, `benchmark-audit-generation-15-2026-09-24.tsv`). The set that tuned the
floors (generation 11, ~1.1k-2.5k passages, per the MEASUREMENT header) is smaller than the live
corpus (33,278 passages at generation 15; 34,817 rows in the registry per the architecture baseline).
**Decision**: benchmark v2 as NEW files, labelled by an actor independent of the pipeline builder
(§11.4.240/§11.4.249), with a recorded audit; verdicts bind the benchmark hash so relabelling to pass
is visible. Corpus growth from spec 017 (1,675 textbook sections not yet in the live registry,
architecture baseline) means a verdict must be re-taken after promotion (D3).

## R4. The `extractive` provider as the first candidate

`pkg/answer/extractive.go:10-27`: no model, no socket, verbatim passages, "cannot fabricate by
construction", single-digit milliseconds. Its limitation is stated in its own comment: it does not
synthesise. What is UNCONFIRMED: its recall/fabrication on this benchmark (the retrieval gate still
decides whether to answer, and the measurement shows the gate barely separates classes, so it may
return verbatim passages for unanswerable questions - which would count as `answered` U trials under
FR-008 if the harness classifies by outcome status). T-measure-extractive settles it with a verdict,
not an opinion. It is also the cheapest provider to exercise 025 US1 streaming (fast phases) against.

## R5. Where the fabrications got through (hypotheses, all UNCONFIRMED until traced)

From the fabrications file's table (questions not reproduced): F1 passes the deployed gate (top 0.786,
margin 0.066) deterministically and is answered under every lexical-L4 configuration; it is refused
only by ONNX floor 0.50 and by the LLM judge. F3 passes at floor 0.50 in 1 of 3 repeats. F2 is stopped
only by the margin test. The MEASUREMENT file records `citations_verified: true` on the fabrications,
i.e. L3/L4-lexical accepted claims whose cited passage lexically overlaps but does not state the
asked-for fact. The two questions ask for a quantity of a specific unit/currency (paraphrase). A
deterministic "demanded-quantity must appear in the cited span" check would be a candidate additional
rule in the L5 question-focus layer (which already exists as the "focus" mode: `pkg/answer/question.go`,
`internal/answering/wire.go` `QuestionVerify` "focus"/"llm"), but L5 `focus+llm` was ALREADY running
in the deployed configuration that fabricated (MEASUREMENT table, "L5 question-focus+llm"), so either
the demand extractor does not recognise the unit class or the judge accepted it. This is exactly the
root-cause question US3 answers by tracing, not by assuming. **No fix is chosen here.**

## R6. Alternatives to the boot-time gate, rejected

* *UI toggle to enable*: rejected - it is the unmeasured default-enable; hot switch is blocked
  upstream (011 FR-011/FR-012 NEEDS CLARIFICATION).
* *Documentation-only gate (a checklist)*: rejected - §11.4.236 requires the blocker to bind to a
  mechanical seam; prose is bypassed silently.
* *Gate inside `/api/ask` per request*: rejected - per-request cost and complexity for no benefit;
  boot decides, overview reports.
* *Adding an `UnavailableCode` for gate-not-cleared*: not chosen as default (D4) because the closed
  vocabularies are "proven disjoint" in tests and mirrored in `core/vocabulary.ts:335`; reuse of
  `no_provider` with a detail field is honest enough and lower risk. Revisit on operator decision.

## R7. Role and visibility

`authstore` has roles `admin`/`user` (`pkg/authstore/authstore.go:47`). The audit rows are the only
sensitive part (session identifiers, endpoints, byte counts). **Decision**: enforce at the API layer;
UI renders what is returned (a hidden-in-UI field would still be in the payload).

## R8. Streaming interplay (spec 025 US1)

The stage list reads phases from the same job the answering handler runs; with answering OFF there
is no stage stream (503 JSON). So 025 US1's live verification needs an answering-enabled scratch
server (extractive or ollama), which is available without touching the live stack and without
passing this spec's gate (the gate guards the LIVE deployment configuration only; scratch servers
for tests set the provider directly and run with `-answer-verdict-dir` pointing at an empty temp dir
plus an explicit test-only constructor, never the production flag path - T046 defines it). This is
the one place the gate must not be accidentally bypassed in production: the bypass is a
compile-time test helper in `_test.go`/testdata, not a flag.

## R9. Tooling already in the tree (extend, do not reimplement - §11.4.74)

`gates/answer-eval/{eval.sh,mkcmd.py,runbench.py,cmp.py,perrun.py,fake_server.py}`; compose
consistency verifier `gates/verify-compose-answering-consistency.sh` and its prover;
`gates/prove-g-http-5-search-survives-answering-down.sh`; `gates/verify-floor-domain.sh`;
`scripts/_live_auth.sh`; `scripts/bench-retrieval.sh`. This feature adds `gate_verdict.py`, the Go
`verdict` package, and wrappers.

## R10. UNCONFIRMED register

* Whether the frontend session exposes `role` (T006).
* Metrics surface for gate decisions (FR-020): logs only if none.
* Real vendor behaviour for hosted rows: never run from this tree (011 honest boundary).
* Exact LAN-model behaviour: 011 US3 not built.
* Wall time of a full measurement run on the host (the MEASUREMENT file runs 3 repeats per variant;
  duration not recorded there).
