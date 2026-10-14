# 02 — Gate design (PROPOSED)

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-14 |
| Status | design only — no gate code exists; gate code is a separate work item |

Conventions followed (read in `submodules/constitution/scripts/gates/` on
2026-10-14): one script `scripts/gates/cm_<name>.sh` per gate plus a paired
`cm_<name>_mutation_test.sh` (§1.1); new gate names registered in the gate
ledger (`gate_ledger.sh`, `gate_ledger_baseline.txt`, `gate_ledger_*.tsv`);
propagation gates follow the existing `cm_covenant_114_<N>_propagation.sh`
pattern. Every gate below is three-valued: **0** clean, **1** a determined
finding, **2** could not determine. **1 outranks 2. 2 is never a pass.**
Every gate also states its golden-FALSE case per §11.4.201(1): an input the gate
MUST NOT flag, run as part of its mutation test, so a gate that fires on
everything fails its own proof.

## Index

| Gate | Anchor | Script (tentative) |
|---|---|---|
| `CM-COVENANT-114-277..281-PROPAGATION` | A..E | `cm_covenant_114_27{7,8,9}_propagation.sh`, `cm_covenant_114_28{0,1}_propagation.sh` |
| `CM-LLMCTL-WRAPPER-ONLY` | A | `cm_llmctl_wrapper_only.sh` |
| `CM-LLMCTL-WRAPPER-CONTRACT` | A | `cm_llmctl_wrapper_contract.sh` |
| `CM-MODEL-VALIDATED-BEFORE-USE` | B | `cm_model_validated_before_use.sh` |
| `CM-MODEL-VALIDATION-DETERMINISM` | B | `cm_model_validation_determinism.sh` |
| `CM-GOLDEN-BANK-REPRODUCIBLE` | C | `cm_golden_bank_reproducible.sh` |
| `CM-GOLDEN-BANK-CONTROLS` | C | `cm_golden_bank_controls.sh` |
| `CM-GOLDEN-BANK-NO-LOOSENING` | C | `cm_golden_bank_no_loosening.sh` |
| `CM-UI-VISION-COVERAGE-LEDGER` | D | `cm_ui_vision_coverage_ledger.sh` |
| `CM-UI-VISION-VERDICT-NO-BLUFF` | D | `cm_ui_vision_verdict_no_bluff.sh` |
| `CM-UI-VISION-SEEDED-DEFECT` | D | `cm_ui_vision_seeded_defect.sh` |
| `CM-VISION-FAMILY-DOCS-SYNC` | E | `cm_vision_family_docs_sync.sh` |

---

## Propagation gates — `CM-COVENANT-114-277..281-PROPAGATION`

- **Asserts:** the literal anchor token (`11.4.277` .. `11.4.281`) appears as a
  block-start exactly once in each governance file of the mirror set
  (`Constitution.md`, `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`), and
  the mirror copies of the compact summary are content-hash equal
  (§11.4.227(B)).
- **Inputs:** the five governance files of the constitution checkout; for a
  consumer run, the consumer's four root carriers (pointer form accepted per
  §11.4.35 invariant 6).
- **rc:** 0 present once everywhere and lockstep; 1 missing, duplicated or
  diverged; 2 a governance file unreadable.
- **Fixtures:** a five-file mirror with the literal; copies with it stripped,
  duplicated, or with one summary edited.
- **Paired mutation:** strip the literal from `QWEN.md` → MUST exit 1.
- **Golden-FALSE:** the literal appearing additionally inside a `Composes`
  list of ANOTHER anchor (a citation, not a block-start) MUST NOT count as a
  duplicate.

## `CM-LLMCTL-WRAPPER-ONLY` (ANCHOR-A(C))

- **Asserts:** no tracked file of any governed repository invokes `llmctl` in
  command position, except inside the `llmctl` repository itself and the
  wrapper's own implementation directory.
- **Inputs:** the fleet derived from `.gitmodules` + `helix-deps.yaml`
  (never a hardcoded roster); per repository `git ls-files`; file classes:
  shell, Makefile, compose/Containerfile, Go/Python/JS/TS sources (argument
  vectors to `exec`/`spawn`/`subprocess`/`exec.Command`), and Markdown code
  fences whose first token is `llmctl`.
- **Detection:** a parser per class that finds the COMMAND token (shell:
  first word of a simple command after `sudo`/`env`/`exec`/`command`/
  `nohup`/`timeout` wrappers and after variable assignments; Go:
  `exec.Command("llmctl", ...)` and a constant resolving to `llmctl`; Python:
  first element of the argv list). A name-resolution bypass (a variable
  holding `llmctl`, a symlink, `$(command -v llmctl)`) is a declared member
  of the class and is enumerated per §11.4.276(C).
- **rc:** 0 none; 1 at least one invocation (prints repository, path, line);
  2 a repository could not be enumerated (missing checkout).
- **Fixtures:** `bad_shell.sh` (`llmctl start vision`), `bad_env.sh`
  (`env FOO=1 llmctl switch vision-pro`), `bad_var.sh` (`L=llmctl; "$L" start`),
  `bad.go` (`exec.Command("llmctl", "status")`), `bad.md` (fence starting
  `llmctl start vision`), `good_wrapper.sh` (calls the wrapper).
- **Paired mutation:** append `llmctl status` to a consumer script → MUST
  exit 1.
- **Golden-FALSE:** prose "`llmctl` 3.2.2 was measured on 2026-10-14", a
  comment `# llmctl is pinned by the wrapper`, the string in a JSON evidence
  record, and any file inside the `llmctl` repository MUST NOT fire.

## `CM-LLMCTL-WRAPPER-CONTRACT` (ANCHOR-A(B))

- **Asserts (by EXECUTION, not grep):** the wrapper (1) refuses an `llmctl`
  older than its declared minimum (rc 2); (2) refuses `endpoint`/`query` for
  a profile whose `require-validated` returns 1 (rc 1) or 2 (rc 2), and
  returns the endpoint only on 0; (3) runs validation after `start`/`switch`/
  `auto` and stops a model that fails it; (4) writes one audit line per call
  with no prompt, image or credential content.
- **Inputs:** the wrapper; a hermetic fake `llmctl` on `PATH` whose
  `--version`, `require-validated` and `validate` outputs and exit codes are
  driven by fixture files (a fake is permitted here because the gate tests the
  WRAPPER, a unit; §11.4.27). A separate live stage, when a real `llmctl` is
  present, repeats (2) against a real profile and reports rc 2 when none is
  installed.
- **rc:** 0 every contract clause held; 1 any clause violated; 2 the wrapper
  is absent or the harness could not run.
- **Paired mutation:** make `endpoint` skip `require-validated` → MUST exit 1;
  make the version check always succeed → MUST exit 1.
- **Golden-FALSE:** a fake `llmctl` exactly at the minimum version with a
  fresh PASS record MUST produce rc 0 and an endpoint.

## `CM-MODEL-VALIDATED-BEFORE-USE` (ANCHOR-B(A)(B)(C)(E))

- **Asserts:** for every (profile, host role) a consumer declares it uses,
  a validation record exists that (1) carries every required field;
  (2) matches the model about to be used on every key — each model file
  sha256 (weights and projector), engine tag, `llmctl` version, suite content
  hash, host fingerprint, sampling; (3) is within the consumer's declared
  maximum age, itself ≤ 30 days; (4) has verdict PASS. Also asserts every use
  site in the consumer calls the wrapper's gated subcommands (cross-checked
  with `CM-LLMCTL-WRAPPER-ONLY`).
- **Inputs:** consumer DATA file declaring profiles in use and host roles;
  committed record summaries; the current catalog and suite hashes (computed,
  not read from the record).
- **rc:** 0 all fresh PASS; 1 a record is FAIL, stale by key, older than the
  maximum, or missing a field; 2 a record for a declared (profile, host) does
  not exist or a key cannot be computed (model not downloaded on this host).
  A missing record is rc 2 at gate level and BLOCKS use; it is never a pass.
- **Fixtures:** `fresh_pass.json`; `sha_mismatch.json`; `engine_changed.json`;
  `suite_hash_changed.json`; `age_31d.json`; `missing_mmproj_sha.json`;
  `other_host.json` (record from a different host fingerprint).
- **Paired mutation:** flip one hex digit of the recorded model sha → MUST
  exit 1; set max age to 45 days in the consumer DATA → MUST exit 1 (ceiling).
- **Golden-FALSE:** a 29-day-old record matching every key, 3 identical runs,
  verdict PASS, consumer max 30 → MUST exit 0.

## `CM-MODEL-VALIDATION-DETERMINISM` (ANCHOR-B(D))

- **Asserts:** every record has run count ≥ 3; for every probe, the verdict
  and the normalised output hash are identical across all runs; per-host
  hashes recorded; across hosts only verdict identity is required.
- **Inputs:** record summaries (per-run per-probe hashes).
- **rc:** 0 deterministic; 1 run count < 3 or any within-host divergence;
  2 the per-run section is absent (cannot determine).
- **Paired mutation:** change one probe's hash in run 2 → MUST exit 1; delete
  run 3 → MUST exit 1.
- **Golden-FALSE:** two hosts whose output hashes differ from each other but
  are identical within each host, verdicts identical → MUST exit 0.

## `CM-GOLDEN-BANK-REPRODUCIBLE` (ANCHOR-C(B)(H)(1))

- **Asserts:** running the committed generator from committed inputs in a
  scratch directory reproduces every fixture's recorded sha256 byte for byte;
  project fixtures carry a complete pin set (build artifact hash, data
  fixture, viewport/DPI, locale, theme, fonts, capture method).
- **Inputs:** base bank and project bank directories; `expectations.json`.
- **rc:** 0 every hash reproduced; 1 any mismatch or missing pin; 2 the
  generator cannot run on this host (missing interpreter) — never a pass.
- **Paired mutation:** change one byte of a committed PNG → MUST exit 1.
- **Golden-FALSE:** regenerating twice in two different scratch directories on
  the same host and comparing MUST exit 0 (no timestamp or path leaks into
  output).

## `CM-GOLDEN-BANK-CONTROLS` (ANCHOR-C(C)(D)(E)(H)(2-4))

- **Asserts:** schema validity; every probe uses only the closed check
  vocabulary; no check invokes a model; every golden probe category has at
  least one `control-bad` fixture that declares it in `discriminates`; the
  base-bank coverage list of ANCHOR-C(D) is complete; the judge self-test
  (canned correct answers PASS every golden probe, canned wrong answers FAIL,
  canned golden answers on a control FAIL) holds.
- **rc:** 0 complete; 1 a category without a control, an unknown check type,
  a coverage item missing, or a judge self-test inversion; 2 the judge cannot
  be executed.
- **Paired mutation:** delete `91_bad_wrong_content` from the seed suite → MUST
  exit 1; add check type `llm_judge` → MUST exit 1.
- **Golden-FALSE:** adding a new golden fixture together with its control and
  generator input MUST exit 0.

## `CM-GOLDEN-BANK-NO-LOOSENING` (ANCHOR-C(F))

- **Asserts:** in the diff range under review, any expectation change that
  makes a check accept MORE answers (a token removed from `contains_all`, a
  token removed from `forbidden`, a widened regex, a tolerance raised, a probe
  deleted, a fixture's role changed from `golden` to anything else) carries a
  defect-classification record of class `fixture-defect`,
  `expectation-defect` or `prompt-defect` with a ground-truth reference and a
  review id. A `model-capability-gap` record never authorises a loosening.
- **Inputs:** `git diff` of the bank over the range; the defect records.
- **rc:** 0 no unauthorised loosening; 1 a loosening without an authorising
  record, or authorised by `model-capability-gap`; 2 the diff range cannot be
  resolved.
- **Paired mutation:** drop `"42"` from `01_text_large/read.contains_all` with
  no record → MUST exit 1.
- **Golden-FALSE:** TIGHTENING a check (adding a forbidden token) with no record
  MUST exit 0.

## `CM-UI-VISION-COVERAGE-LEDGER` (ANCHOR-D(A)(B)(H))

- **Asserts:** for each in-scope surface, the ledger exists and parses; its
  row set is a superset of (IA screens × declared states × shipped platforms)
  computed from the §11.4.219 catalogue / IA contract; no row is `UNCOVERED`,
  `FAIL`, `BLOCKED` or STALE at release; prose-only steps are counted
  `UNCOVERED` (detected by the absence of an executable assertion id).
- **Inputs:** IA contract; ledger TSV; suite inventory; consumer max row age.
- **rc:** 0 complete and fresh; 1 a missing row, non-PASS row or stale row;
  2 the IA contract cannot be read (rc 2, and §11.4.219 is the remedy).
- **Fixtures:** a 3-screen × 2-state × 2-platform IA with a full ledger, a
  ledger missing one row, a ledger with a prose step, a stale row.
- **Paired mutation:** delete one row the IA requires → MUST exit 1.
- **Golden-FALSE:** a project whose only deliverable is a non-interactive CLI
  (declared as such in its DATA) MUST exit 0 without a ledger; a ledger with
  EXTRA rows beyond the IA (e.g. a component gallery) MUST exit 0.

## `CM-UI-VISION-VERDICT-NO-BLUFF` (ANCHOR-D(C)(D)(E))

- **Asserts (by EXECUTION against the HelixQA verdict engine):** with the
  vision client stubbed to (a) raise, (b) time out, (c) return unparseable
  output, (d) be absent, (e) return a not-validated `require-validated`, a UI
  step whose action succeeds is `BLOCKED`, never `PASS`; a `vision_verify`
  step's outcome decides the verdict; every PASS verdict record contains a
  frame sha256 that matches the stored frame; the session preflight runs and
  blocks on a golden-bad pass.
- **Inputs:** HelixQA engine at the consumer's pinned version; scripted
  scenarios.
- **rc:** 0 every scenario correct; 1 any bluff path; 2 engine not runnable.
- **Paired mutation:** re-introduce "action success ⇒ PASS when vision
  errors" → MUST exit 1; drop the frame hash from the verdict record → MUST
  exit 1.
- **Golden-FALSE:** a step where action succeeds AND vision returns the
  expected content for a real captured frame MUST be PASS with rc 0.

## `CM-UI-VISION-SEEDED-DEFECT` (ANCHOR-D(G))

- **Asserts:** for every shipped platform, a committed seeded-defect build
  exists, the suite has run against it at the current suite version, and the
  run reported FAIL naming the mutated row (and nothing else failed for an
  unrelated reason).
- **Inputs:** seeded-defect manifest (platform → build hash → mutated row id →
  last run id); run records.
- **rc:** 0 every platform's seed caught; 1 a seed not caught, or caught on
  the wrong row; 2 a platform has no seed or no run on the current suite
  version.
- **Paired mutation:** mark a seed run as PASS → MUST exit 1.
- **Golden-FALSE:** a seed caught on the exact mutated row with all other
  rows PASS MUST exit 0.

## `CM-VISION-FAMILY-DOCS-SYNC` (ANCHOR-E)

- **Asserts:** a commit that changes a declared behaviour surface (wrapper
  interface file, record schema, check vocabulary, ledger schema, verdict
  rules) also changes the mapped documents and diagrams, and their §11.4.65
  exports are regenerated from the new sources (export hash matches a fresh
  render).
- **Inputs:** a surface→docs map (DATA); the commit range.
- **rc:** 0 in step; 1 a surface changed without its docs, or a stale export;
  2 the map is absent.
- **Paired mutation:** change the record schema only → MUST exit 1.
- **Golden-FALSE:** a commit changing only a fixture comment or a test name
  MUST exit 0.

---

## Ordering and cost

Static gates (`WRAPPER-ONLY`, `GOLDEN-BANK-*`, `COVERAGE-LEDGER`,
`DETERMINISM`, `DOCS-SYNC`, propagation) run in seconds and belong in the
pre-push hook. Execution gates (`WRAPPER-CONTRACT`, `VERDICT-NO-BLUFF`) run in
a hermetic harness in under a minute. Live stages (a real model validation,
a real seeded-defect run) are minutes to tens of minutes, run under §11.4.89
background execution and §12.6 memory headroom, and report rc 2 — never 0 —
on a host without the model.
