# 06 — Open questions, with the defaults this draft chose

| Field | Value |
|---|---|
| Revision | 2 |
| Created | 2026-10-14 |
| Status | proposal — every default is reversible by an operator decision (§11.4.66) |

**Superseded in part (2026-10-14).** See `07_reconciliation_after_upstream_merge.md` §13:
Q1, Q2, Q3, Q5, Q6, Q8 and Q14 are answered by upstream §11.4.277/§11.4.278; Q4 is
covered; Q7, Q11, Q12 and Q15 became amendment proposals or Q-R3; Q9, Q10 and Q13 stay
open; new questions are Q-R1..Q-R9. The four review slices below are replaced by
slices S1–S4 in `07` §7.

Each question states the DEFAULT this draft uses (§11.4.101: decide rather than
block) and what would change if the operator chooses otherwise.

| # | Question | Default chosen | Consequence of the other choice |
|---|---|---|---|
| Q1 | Where do the wrapper and the base golden bank live? | Both in the constitution submodule (`scripts/llm/`, `scripts/llm/golden/`). | If the bank stays in `llmctl`, the constitution consumes it by suite content hash; never a byte-identical copy (§11.4.251). |
| Q2 | Where does `validate` live? | In `llmctl` (it already ships `validate`, `vision validate`, `validate-all`, `require-validated` at 3.2.2). The wrapper calls it; it does not reimplement it (§11.4.74). | A constitution-side validator would duplicate the judge; rejected unless `llmctl` cannot meet ANCHOR-B. |
| Q3 | How long is a record fresh? | Until model sha / engine tag / `llmctl` version / suite hash / host fingerprint / sampling changes, and never older than 30 days. Consumers may be stricter. | Measured conflict to note: `llmctl`'s own default is 7 days (`LLMCTL_VALIDATION_MAX_AGE=604800`). 7 ≤ 30, so it complies; the 30-day figure is a ceiling, not a target. |
| Q4 | Is a fine-tuned / re-quantised model the same model? | No — a new sha is a new model with no record. | — |
| Q5 | Does a TUI count as a UI? | Yes for an interactive full-screen TUI; a non-interactive CLI does not. | Excluding TUIs would leave interactive terminal apps outside ANCHOR-D. |
| Q6 | Must "HelixQA full suites" be HelixQA, or can another runner (for example Playwright) satisfy ANCHOR-D if its vision step uses the validated model, frame binding and the same judge? | HelixQA is the mandated runner (operator wording); another runner may act as a second oracle only. | Allowing equivalents needs a conformance test; UNCONFIRMED whether the operator wants that. |
| Q7 | What is committed? | Record summaries, hashes, ledgers, expectations, generators. Bulky raw evidence (frames, transcripts, logs) stays untracked, referenced by sha256. | Committing frames would bloat history and risks private content in public repositories. |
| Q8 | May a hosted vision API substitute for the local model? | No. Advisory only (a second opinion recorded as such); it never decides a verdict and never substitutes when the local model is BLOCKED. | — |
| Q9 | The constitution has no `QWEN`/`GEMINI` project templates (measured: three templates). Add them? | Not in this proposal; the pointer paragraph is added to the two existing carrier templates. Flagged for the integrator. | Adding them is a separate §11.4.157 change. |
| Q10 | The `llmctl` catalog pins file sha256 but `hf_revision` is the moving ref `main` (measured 2026-10-14). Is that deterministic enough? | Yes for validation, because the record keys on file sha256: a changed upstream file changes the sha and invalidates the record. Recommended upstream to `llmctl`: pin `hf_revision` to a commit so downloads are reproducible. | — |
| Q11 | Determinism across hosts with different backends (CPU vs GPU)? | Verdict identity across hosts; byte identity within a host. | Requiring cross-host byte identity could fail for reasons unrelated to correctness (different numeric kernels per backend); whether it does is UNCONFIRMED until measured on two hosts. |
| Q12 | `llmctl`'s vision suite declares `determinism_repeat` for ONE probe; ANCHOR-B(D) requires ≥3 runs of the whole suite. | ANCHOR-B governs; `llmctl` needs an upstream change or the wrapper runs the suite three times and compares. Whether the judge already repeats ≥3 times was NOT read (UNCONFIRMED). | — |
| Q13 | Remote validation: `llmctl` has no remote-host flag (orchestrator measurement). Does `llmctl cluster` cover it? | The wrapper runs on the remote host via an untracked host alias. `cluster` coverage is UNCONFIRMED. | If `cluster` suffices, ANCHOR-A(D) can point at it instead. |
| Q14 | Is naming `llmctl` and HelixQA in universal canon allowed by §11.4.17? | Yes, on the §11.4.76 / §11.4.160 / §11.4.162 precedent (own-organisation fleet substrates named in canon). | If not, the names move to consumer DATA and canon speaks of "the fleet's model manager". |
| Q15 | Live evidence so far is single-host (two `vision` runs 2026-10-13, one `small` run 2026-10-14, all PASS on one host). | Recorded as one-host evidence only; ANCHOR-B(E) is unmet until a designated remote host has a record. | — |

## Review slicing for the §11.4.276 budget

To keep each review inside the 5–7 round budget, review in four slices, each
with its own ground-truth record (§11.4.276(B)) and class inventory (§11.4.276(C)):

1. **ANCHOR-A + ANCHOR-B** — wrapper contract and validation record (ground
   truth: `llmctl` `lib/validate.sh`, catalog, live-run records).
2. **ANCHOR-C** — bank, check vocabulary, defect taxonomy (ground truth: the
   seed suite's `expectations.json` and generator).
3. **ANCHOR-D** — ledger, verdict rules, seeded defects (ground truth: HelixQA
   verdict engine on `feature/vision-no-bluff`; a consumer's IA contract).
4. **ANCHOR-E + carriers** — docs set, propagation, carrier/template/index
   snippets, ToC/status/changelog.
