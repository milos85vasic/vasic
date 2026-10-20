# Contract: Answering Gate Verdict + Fingerprint

**Implements**: FR-007..FR-009, FR-014 | **New package**: `workshop/platform/backend/pkg/answer/verdict`
**Producer**: `workshop/platform/backend/gates/answer-eval/gate_verdict.py` (measurement tooling).
**Consumers**: server boot check (`cmd/workshop-server/answering_gate.go`), overview, enable script.

## Location and naming

`workshop/evidence/answering-verdicts/verdict-<fingerprint12>-<yyyymmddThhmmssZ>.json` plus
`verdict-....runs.tsv` (raw per-run rows) and `MANIFEST.sha256` (one line per file). The directory is
private (inside `workshop/`), append-only by convention and checked by a gate. Path is a server flag
`-answer-verdict-dir` (default `<repo>/evidence/answering-verdicts`; compose mounts it read-only).

## Schema `answering-verdict/1`

```json
{
  "schema": "answering-verdict/1",
  "fingerprint": { "sha256": "<64 hex>", "inputs": { "provider": "...", "model": "...", "endpoint_host": "...",
                   "locality_declared": "...", "min_score": 0.0, "min_margin": 0.0, "min_support": 0.0,
                   "score_k": 0.0, "top_k": 0, "max_claims": 0, "verifier_kind": "...",
                   "question_verifier_kind": "...", "entail_model_id": "...",
                   "corpus_root_hash": "...", "benchmark_sha256": "...", "thresholds_sha256": "..." } },
  "benchmark": { "path": "testdata/benchmark/questions-v2.tsv", "sha256": "...", "answerable_n": 0, "unanswerable_n": 0, "dropped_n": 0 },
  "thresholds": { "path": "testdata/benchmark/gate-thresholds.json", "sha256": "...", "values": {} },
  "runs": 3,
  "answerable":   { "trials": 0, "answered": 0, "recall": 0.0, "wilson_low": 0.0, "wilson_high": 0.0 },
  "unanswerable": { "trials": 0, "answered": 0, "fabrication": 0.0, "wilson_low": 0.0, "wilson_high": 0.0 },
  "sides": { "recall": "pass", "fabrication": "pass" },
  "result": "pass",
  "failed_side": null,
  "produced_by": { "tool": "gate_verdict.py", "tool_sha256": "...", "git_head": "...", "utc": "..." },
  "raw_runs_sha256": "..."
}
```

## Decision rule (normative; the ONLY place the rule is stated - code and tests cite this section)

Let `z = 1.959964`, Wilson score interval for `k` successes in `n` trials.

* `sides.recall = pass` iff `answerable.trials >= min_answerable_trials` AND `answerable.wilson_low >= recall_floor`.
* `sides.fabrication = pass` iff `unanswerable.trials >= min_unanswerable_trials` AND `unanswerable.wilson_high <= fabrication_limit`.
* `result = pass` iff both sides pass. `failed_side` is `recall`, `fabrication`, `both`, or
  `insufficient_trials` (a side failed only because the trial minimum was not met).
* A recall regression guard (US3) compares `answerable.wilson_low` with a recorded prior value and
  fails the fix if it dropped by more than `recall_regression_tolerance`.

## Validation (fail closed)

The Go loader returns `pass` only if ALL hold: schema string matches; every required field present
with correct type; `fingerprint.sha256` equals the recomputation over `fingerprint.inputs`; recomputed
Wilson bounds equal the stored ones within 1e-9; `result` equals the rule applied to the stored
counts; `raw_runs_sha256` matches the sibling TSV; manifest line matches. Anything else is `invalid`
(treated as no verdict) - never an error that lets boot continue as enabled.

## Fingerprint canonicalisation

JSON object of the `inputs` with keys sorted lexicographically, no insignificant whitespace, strings
UTF-8, numbers via shortest round-trip decimal, absent optional input rendered as `""`/`0`, hashed
with SHA-256. Property test: permuting key order or whitespace of the source never changes the
digest; changing any single input always does.

## Compatibility

`answering-verdict/1` is the only accepted schema string. A future `/2` requires a new loader
branch; unknown schemas are `invalid`.
