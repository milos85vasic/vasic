# 07 — Reconciliation of drafts A–E with upstream §11.4.277 / §11.4.278

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-14 |
| Last modified | 2026-10-14 |
| Status | proposal — NOT canon; nothing here is placed in `submodules/constitution` |
| Status summary | Upstream already carries §11.4.277 (llmctl validation gate) and §11.4.278 (HelixQA UI QA with Vision, PROPOSED). Of 48 normative clauses in drafts A–E: 20 COVERED, 15 PARTIAL, 8 ABSENT, 5 CONFLICT. Plan: zero new anchors from our drafts; amend §11.4.277 and §11.4.278 in place; release the tentative numbers §11.4.277–§11.4.281; drop the rest. One separate host-safety anchor is listed but not drafted here. |
| Issues | Independent review (§11.4.142, §11.4.209 substrate) not yet run on this file; operator questions Q-R1..Q-R9 open |
| Supersedes | The anchor numbering and the "new anchor" framing of `01_rule_texts.md`–`05_consumer_adoption.md` (those files stay as the record of the draft) |

## Contents

1. [Measured baseline](#1-measured-baseline)
2. [Matrix summary](#2-matrix-summary)
3. [Clause-level traceability matrix](#3-clause-level-traceability-matrix)
4. [The five conflicts, quoted](#4-the-five-conflicts-quoted)
5. [Reconciliation plan](#5-reconciliation-plan)
6. [Anchor numbers](#6-anchor-numbers)
7. [Review slices for the §11.4.276 budget](#7-review-slices-for-the-114276-budget)
8. [Amendment text, ready to paste](#8-amendment-text-ready-to-paste)
9. [Impacted gates and mutation pairing](#9-impacted-gates-and-mutation-pairing)
10. [Implementations against the rules](#10-implementations-against-the-rules)
11. [Consumer propagation impact](#11-consumer-propagation-impact)
12. [Separate proposed anchor: agent host resource safety](#12-separate-proposed-anchor-agent-host-resource-safety)
13. [Open questions for the operator](#13-open-questions-for-the-operator)
14. [Honest boundary](#14-honest-boundary)

---

## 1. Measured baseline

All readings taken 2026-10-14 in this checkout. Read-only on `submodules/constitution`
(the only write was a `git fetch` of `origin main` into its object store; no checkout,
no index change, no commit).

| Fact | Reading | How measured |
|---|---|---|
| Constitution checkout | branch `feature/label-sync`, HEAD `c4b74082ba28` (merge `3d002e62d6c6` of upstream `2e70099e26cc`) | `git rev-parse` |
| Upstream main | `50823897f0a8` (2026-10-14 14:53 +0200); HEAD is 44 ahead / 1 behind it | `git fetch origin main`; `rev-list --left-right --count` |
| The one upstream commit HEAD lacks | `5082389` (§11.4.54/§11.4.248 + `codegraph_safe` knob); its only `11.4.277/278` hit is the header status line | `git diff HEAD...FETCH_HEAD -- Constitution.md` |
| Highest anchor | §11.4.278 at HEAD and at upstream main; §11.4.279+ FREE | `grep '^### §11\.4\.27[6-9] \|28[0-9] '` (positive control §11.4.276 = 1, negative control §11.4.999 = 0) |
| §11.4.277 block | `Constitution.md` lines 12003–12068 at HEAD | read in full |
| §11.4.278 block | `Constitution.md` lines 12070–12128 at HEAD; status PROPOSED | read in full |
| Carriers | `CLAUDE.md` / `AGENTS.md` / `QWEN.md` / `GEMINI.md`: 2 mentions of `11.4.277`, 1 of `11.4.278` each (compact summaries) | `grep -c` |
| Templates | 0 mentions of 277/278 in all three `templates/*` | `grep -l` |
| `post_update_hook.sh` | 0 mentions of `llmctl`, `11.4.277`, `11.4.278`, `HelixQA` | `grep` |
| Implemented gates | `cm_covenant_114_277_propagation.sh`, `cm_covenant_114_278_propagation.sh`, `cm_llmctl_submodule_nonrecursive.sh` (+ mutation tests) | `ls scripts/gates` |
| Deferred gates | OWED-GATE-121..130 (§11.4.277), 131..142 (§11.4.278); highest OWED id = 142 at HEAD and at upstream main | `gate_ledger_deferrals.tsv` |
| llmctl vendoring | `.gitmodules` `submodules/llmctl`; `helix-deps.yaml` `ref: v3.2.2` (`5c3dea57fb35`), `recursive_init: false`; index gitlink `5c3dea57fb35` | `git ls-files -s` |
| llmctl repository | HEAD `fc77be2` = `v3.2.2-13`; host binding `347d7e6` is one of those 13 commits, so it is NOT in the constitution's pin | `git describe` |

## 2. Matrix summary

Counted over normative clauses only (honest-boundary prose, classification and
composes lines are not counted).

| Draft | Rows | COVERED | PARTIAL | ABSENT | CONFLICT |
|---|---:|---:|---:|---:|---:|
| A — wrapper | 9 | 4 | 3 | 1 | 1 |
| B — validated before use | 10 | 5 | 2 | 1 | 2 |
| C — golden bank | 10 | 4 | 5 | 0 | 1 |
| D — HelixQA UI QA | 14 | 5 | 4 | 4 | 1 |
| E — docs + propagation | 5 | 2 | 1 | 2 | 0 |
| **Total** | **48** | **20** | **15** | **8** | **5** |

Reading: upstream covers the core of every draft. Our unique contribution is
narrow and concrete — a use record, a call-site identity check, determinism
hashes, per-class controls, a reviewed expectation-correction path, oracle
disagreement handling, a session preflight, per-platform seeded defects, and
propagation reporting. None of it needs a new anchor number.

## 3. Clause-level traceability matrix

Verdicts: **COVERED** (upstream clause says it), **PARTIAL** (what is missing is
named), **ABSENT** (our unique contribution), **CONFLICT** (quoted in §4).
"→" names the disposition in §5.

### 3.1 Draft A — constitution-owned wrapper

| # | Our clause | Verdict | Upstream | Missing / note → disposition |
|---|---|---|---|---|
| A1 | (A) one wrapper owned by the constitution, resolved via `find_constitution.sh`, never copied | PARTIAL | 277(B) "acquire and run ONLY through the vendored llmctl (`submodules/llmctl`)" | The single owned call site exists (the vendored pin). Missing: how a nested submodule resolves it, and proof that the binary actually invoked IS the pin → amend 277(B.1) |
| A2 | (B)(1) version pin; refuse a mismatched `llmctl` (rc 2); print path + version | PARTIAL | 277(B) gitlink pin `v3.2.2` + §11.4.26 re-read on bump | No runtime identity check: a PATH `llmctl` of another version is not refused → amend 277(B.1) |
| A3 | (B)(2) hand out a model only after `require-validated` | COVERED | 277(A) | — |
| A4 | (B)(3) start implies validate; failing model stopped | COVERED | 277(A.1)(2) | — |
| A5 | (B)(4) exits 0/1/2, 1 outranks 2, 2 never a pass | COVERED | 277(A.1)(1) | — |
| A6 | (B)(5) one audit line per call, no content or credentials | ABSENT | — (277(F) logs validation runs, not uses) | It is exactly the input OWED-GATE-121 says is missing ("no use-site inventory / require-validated call-record harness") → amend 277(A.2) |
| A7 | (C) direct `llmctl` invocation in tracked files banned | CONFLICT | 277(A) mandates `llmctl require-validated` | §4 C-1 → replaced by 277(B.1) |
| A8 | (D) remote hosts: run the tool on that host; host alias untracked; roles only in tracked text | PARTIAL | 277(I) SSH keys, run llmctl on that host, remote list as data | Role-only naming in tracked text absent → amend 277(I) |
| A9 | (E) nothing lowers another bar; refusal is rc 2 | COVERED | 277(E), 277(A.1)(1) (75 → 2), "adds no new escape hatch" | — |

### 3.2 Draft B — validated before use

| # | Our clause | Verdict | Upstream | Missing / note → disposition |
|---|---|---|---|---|
| B1 | (A) record fields | PARTIAL | 277(H) binds catalog sha list (incl. mmproj), file size/mtime, engine version line, launch fingerprint (argv minus host/port, so sampling args in argv), suite hashes; 277(F) consumer adds command line, sha of model/mmproj/fixtures/engine binary, build flags, PSI, host class | Missing: llmctl version + commit, run count, per-run per-probe output hash; host name is bound only at llmctl ≥ `347d7e6` (not at the pin) → amend 277(H) |
| B2 | (B) any key change voids; re-quantised = new model | COVERED | 277(H) "a change of any of them voids its record"; quantisation through file identity | — |
| B3 | (B) 30-day age ceiling | CONFLICT | 277(H) 7-day reference; "never looser" | §4 C-2 → drop ours |
| B4 | (C) `require-validated` is a precondition on every use path; a consumer that cannot run reports BLOCKED, never PASS | COVERED | 277(A); 278(D) `not_validated` never green | Vocabulary differs (`not_validated`), substance equal |
| B5 | (D) ≥3 full-suite runs, identical | CONFLICT | 277(C)(7) "the reference value is ONE repeat" | §4 C-3 → amend 277(C)(7) |
| B6 | (D) byte identity within a host, verdict identity across hosts | ABSENT | — | → amend 277(C)(7) |
| B7 | (E) every host of use; a record from host X never authorises Y | COVERED | 277(I) | Now also implemented in llmctl `347d7e6` (post-pin) |
| B8 | (F) every model kind has a suite; no suite = not validated | COVERED | 277(A) last sentences; 277(G) | — |
| B9 | (G) custody: summary + hashes tracked, bulky raw untracked by sha256, no host names | PARTIAL | 277(F) evidence tree `docs/qa/<run-id>/model-validation/` | Tracked/untracked split and role-only naming absent → amend 277(F) |
| B10 | GPU non-determinism → FAIL with root cause, never a relaxation | COVERED | 277(C)(7) "not noise to average away" | — |

### 3.3 Draft C — golden-content oracle bank

| # | Our clause | Verdict | Upstream | Missing / note → disposition |
|---|---|---|---|---|
| C1 | (A) base bank owned by the constitution, never forked; project banks under one schema | COVERED | Vendoring of llmctl (277(B)) puts `vision-golden-v1` under the constitution; 277(C)(3)/(J) consumer classes; suite hash in the record | Our relocation into `scripts/llm/golden/` is unnecessary → drop the relocation |
| C2 | (B) generator rebuilds every fixture to its recorded sha; captured project fixtures pin build/data/viewport/DPI/locale/theme/fonts/capture | PARTIAL | 277(C)(1) "rendered or captured from controlled sources"; (C.1) generator described as byte-reproducible | No rebuild-to-hash obligation; no pin set for captured fixtures → amend 277(C)(8) |
| C3 | (C) machine-readable expectations; closed check vocabulary; no model judge | COVERED | 277(C)(2), (C)(5) | — |
| C4 | (D) fixed base coverage list (incl. Cyrillic, error banner, disabled/enabled, empty state, relative position) | PARTIAL | 277(C)(3) "covers, at minimum, every class of content the CONSUMER's own screens depend on … a class the corpus does not cover is a class the model is NOT validated for" | Upstream rule is consumer-driven and stronger; the fixed list is policy → drop the list, Q-R5 |
| C5 | (E) every probe category has a discriminating golden-bad control | PARTIAL | 277(C)(3) negative controls required; (C.1) reference suite has 2 controls for 9 golden fixtures | Per-class pairing absent → amend 277(C)(3) |
| C6 | (F) a wrong answer is a defect, investigated, never retried-until-green | COVERED | 277(D) | — |
| C7 | (F) closed defect taxonomy; fixture/expectation/prompt defects may change the bank with ground truth + review | CONFLICT | 277(D) forbids "widening the manifest's accepted answers after seeing the output" | §4 C-4 → amend 277(D.1) |
| C8 | (F) a capability gap never loosens; recorded as not validated for that capability | COVERED | 277(C)(3) + 277(D) + §11.4.254 composed | — |
| C9 | (G) kind-specific suites (coder executed, embedding order not threshold, controls) | PARTIAL | 277(G) llmctl ships chat/coder/embedding suites; other kinds need a closed-form oracle as data | Specifics are tool design → drop from canon, recommend to llmctl docs |
| C10 | (H) bank self-validation: rebuild, schema, judge self-test, control pairing | PARTIAL | 277(C)(6) judge self-test; OWED-GATE-122 hash match | Rebuild and pairing absent → folded into 277(C)(3)/(C)(8) |

### 3.4 Draft D — vision-eyed full-suite UI QA

| # | Our clause | Verdict | Upstream | Missing / note → disposition |
|---|---|---|---|---|
| D1 | (A) scope incl. interactive TUI; non-interactive CLI out | COVERED | 278(A) "TUI/CLI-with-screens" | — |
| D2 | (B) ledger from the §11.4.219 IA; per-row fields; states | COVERED | 278(B), (J)(5), (H) | — |
| D3 | (B) a prose step with no executable assertion counts UNCOVERED | PARTIAL | 278(B) "read-verified PASS record"; 278(G) PASS-count rule | Not explicit for prose/TODO steps → amend 278(G.1) |
| D4 | (C) every on-screen assertion decided by the validated vision model; DOM/a11y is the SECOND oracle | CONFLICT | 278(F) order "accessibility tree / DOM > deterministic OCR/template > validated-Vision" | §4 C-5 → adopt upstream order; keep D7 |
| D5 | (C) capture after settle, frame sha256, spec written before run, response recorded | COVERED | 278(F), (H), §11.4.193 | — |
| D6 | (C) action success never substitutes for a vision verdict | ABSENT | — | Was HelixQA's original bluff path → amend 278(E.1) |
| D7 | (C) disagreement between oracles is a finding, not a tie-break | ABSENT | — | → amend 278(F.1) |
| D8 | (D) vision absent / not validated → BLOCKED, never PASS | COVERED | 278(D) `not_validated`; 278(G) closed set | — |
| D9 | (D) validated model errors / times out / unparseable → BLOCKED (rc 2) | PARTIAL | 278(G) closed set has no such outcome | → amend 278(G): add `blocked` |
| D10 | (D) `vision_verify` always verdict-deciding; decorative call is a defect | ABSENT | — | → amend 278(E.1) |
| D11 | (E) session preflight: `require-validated`, golden-good + golden-bad + one project pair through the same pipeline | PARTIAL | 278(D) require-validated; 278(F) comparator self-validation | End-to-end pipeline preflight absent → amend 278(D.1) |
| D12 | (F) full coverage, deterministic; flaky via §11.4.248 | COVERED | 278(B), (F) (§11.4.50); §11.4.248 | — |
| D13 | (G) seeded defect per platform, caught on the right row | ABSENT | — (278(J)(2) pairs a §1.1 mutation per bank, not a product-level seeded build) | → amend 278(J.1) |
| D14 | (H) release blocked on missing/failing/blocked/uncovered/STALE rows | PARTIAL | 278 release blocker; (J)(9) §11.4.236 | Fingerprint-staleness cross-reference to §11.4.135 absent → amend 278(J)(5) |

### 3.5 Draft E — docs and propagation

| # | Our clause | Verdict | Upstream | Missing / note → disposition |
|---|---|---|---|---|
| E1 | (A) named doc set + diagrams for the validation family | PARTIAL | 278(J)(6) for UI QA; §11.4.257 / §11.4.258 generic | Validation-family docs only generic → one sentence in 277(J) |
| E2 | (B) docs change in the same commit | COVERED | §11.4.106(F), §11.4.60; OWED-GATE-141 | — |
| E3 | (C) `post_update_hook.sh` reports llmctl resolution, ledger schema, missing carrier anchors | ABSENT | — (measured: 0 mentions in the hook) | → amend 277(J.1) / 278(K.1) |
| E4 | (C) templates carry the pointer paragraph | ABSENT | — (measured: 0 mentions in templates) | → template change in slice 4 |
| E5 | (C) carriers in lockstep | COVERED | §11.4.157; implemented propagation gates for 277/278 | — |

## 4. The five conflicts, quoted

**C-1 (A7) — who may invoke `llmctl`.**
Ours (`01_rule_texts.md`, ANCHOR-A(C)): *"No tracked file in any governed repository other
than the `llmctl` repository itself and the wrapper's own implementation may invoke
`llmctl` in command position."*
Upstream 277(A): *"Decision-bearing use MUST run with `LLMCTL_VALIDATE_STRICT=1` … AND MUST
gate on `llmctl require-validated <profile>` before each such use."*
Both cannot hold: upstream requires consumers to call `llmctl` directly. Resolution:
drop the ban; keep its intent (one pinned call site) as 277(B.1): every `llmctl`
a tracked file invokes must be the vendored pin, checked at run time.

**C-2 (B3) — record age.**
Ours (ANCHOR-B(B)): *"its age is within the consumer-declared maximum, whose constitutional
ceiling is **30 days**."*
Upstream 277(H) + reference-value rule: *"older than `LLMCTL_VALIDATION_MAX_AGE` (reference
value 604800 s = 7 days …)"* and *"a consumer MAY be stricter but never looser."*
30 days is looser than upstream allows. Resolution: drop ours; 7 days stands.

**C-3 (B5) — how many runs.**
Ours (ANCHOR-B(D)): *"A validation executes the full suite at least three times … Every
probe's verdict AND normalised output hash MUST be identical across the runs on that host."*
Upstream 277(C)(7): *"the reference value is ONE repeat (`determinism_repeat` of
`vision-golden-v1` lists one probe) and a consumer MAY — and for decision-bearing Vision
use SHOULD — require more repeats."*
Upstream sets a floor of one repeated probe; ours sets three full-suite runs. Note that
§11.4.50 already says *"Every test that PASSes MUST have been executed N times (default
N=3 …)"*, so a one-repeat floor sits uneasily with an anchor upstream itself composes.
Resolution (operator choice, Q-R3): amend 277(C)(7) to N=3 for decision-bearing use;
keep one repeat as llmctl's default for non-decision diagnostics.

**C-4 (C7) — correcting a wrong expectation.**
Ours (ANCHOR-C(F)): *"Only the first three [`fixture-defect`, `expectation-defect`,
`prompt-defect`] change the bank, and each change carries a ground-truth record
(§11.4.276(B)) and an independent review (§11.4.142)."*
Upstream 277(D): *"FORBIDDEN: … dropping or softening the failing fixture, widening the
manifest's accepted answers after seeing the output …"*; OWED-GATE-122: *"a manifest
edited after a failing run FAILs."*
Upstream gives no path to fix an expectation that is itself wrong, which would refuse a
correct model forever (a §11.4.201(1) false refusal). Upstream's own words leave the
door open — *"defective … until proven otherwise by evidence"* — but give no decidable
test. Resolution: amend 277(D.1) with the closed taxonomy, a NEW suite version (new
content hash voids every record), ground truth, independent review and a tracked item;
in-place widening stays forbidden.

**C-5 (D4) — which oracle decides.**
Ours (ANCHOR-D(C)): *"Every UI assertion that claims what the user sees is decided by …
the validated vision model's response … Where the platform exposes a structural tree …
it is used as a SECOND oracle."*
Upstream 278 "What this is NOT" + 278(F): *"The accessibility tree / DOM / uiautomator
remain PRIMARY oracles where they are trustworthy … the Vision model corroborates"*;
*"the model decides alone ONLY where no deterministic oracle exists."*
Resolution: adopt upstream's order (it matches §11.4.117 and 277's honest boundary);
keep our disagreement rule (D7) as 278(F.1), which upstream does not have.

## 5. Reconciliation plan

**(i) Amendments to §11.4.277 / §11.4.278 (preferred — the topics are covered).**

| Amendment | Source rows | Purpose |
|---|---|---|
| 277(B.1) resolved call site | A1, A2, A7 | The `llmctl` a tracked file runs is the vendored pin, checked at run time; replaces the wrapper ban |
| 277(A.2) decision-use record | A6 | One record per decision-bearing use; unblocks OWED-GATE-121 |
| 277(C)(3) per-class controls | C5, C10 | Every declared class carries a discriminating control |
| 277(C)(7) determinism floor | B5, B6, B1 | N=3 (§11.4.50) for decision-bearing use; per-probe output hashes; within-host bytes, cross-host verdicts |
| 277(C)(8) fixture reproducibility | C2, C10 | Rebuild-to-hash for generated fixtures; pin set for captured ones |
| 277(D.1) defect taxonomy + correction path | C7 | Decidable "proven otherwise by evidence" |
| 277(F) custody | B9, A8 | Tracked summaries, untracked raw by sha256, roles not host names |
| 277(H) record completion | B1 | llmctl version + commit, run count, host identity (llmctl ≥ `347d7e6`) |
| 277(I) roles + `--host` evidence | A8 | Host roles in tracked text; second-host runs are verdict evidence, never a record |
| 277(J) docs sentence + (J.1) pull report | E1, E3 | Validation-family docs per §11.4.257/§11.4.258; hook reports on pull |
| 278(D.1) session preflight | D11 | End-to-end golden pair before each run |
| 278(E.1) action success / decorative calls | D6, D10 | Close the original HelixQA bluff path by rule |
| 278(F.1) oracle disagreement | D4, D7 | Disagreement is a finding |
| 278(G) add `blocked`; (G.1) prose steps | D9, D3 | Closed set matches HelixQA's runtime outcome |
| 278(J)(5) staleness cross-reference | D14 | §11.4.135 candidate-fingerprint coverage |
| 278(J.1) seeded defect per platform | D13 | End-to-end control needle (§11.4.273) per platform |
| 278(K.1) pull report | E3 | Same hook, UI side |

**(ii) New anchors.** None from our drafts. The one genuinely separate topic in
flight — agent host resource safety — is listed in §12 below, not drafted here.

**(iii) Dropped (with the reason).**

| Dropped | Reason |
|---|---|
| ANCHOR-A as an anchor; the wrapper-only ban (A7) | Conflicts with 277(A); intent kept by 277(B.1) |
| Relocating the base bank into `scripts/llm/golden/` (C1) | Vendoring already puts it under the constitution; a relocation would be a second copy (§11.4.251) |
| 30-day ceiling (B3) | Looser than upstream's 7-day reference |
| Fixed base coverage list (C4) | Upstream's consumer-class rule is stronger; Cyrillic left to Q-R5 |
| Kind-specific suite design (C9) | Tool design, belongs in llmctl's suite docs |
| ANCHOR-E as an anchor (E1, E2, E5) | §11.4.257 / §11.4.258 / §11.4.106(F) / §11.4.157 already bind; only E3/E4 survive as amendments |
| Our 12 gate designs as new names | Mapped onto existing OWED-GATE-121..142 contracts; one new name only (§9) |

## 6. Anchor numbers

- §11.4.277 and §11.4.278 are TAKEN upstream with different content than our drafts.
- Our tentative §11.4.277–§11.4.281 are **released**; `ANCHOR-A..E` placeholders in
  files 01–05 are superseded by this plan and must not be placed.
- §11.4.279+ are FREE at upstream main `5082389` (fetched 2026-10-14). Re-check
  immediately before any landing; this reading is perishable.
- No number is consumed by this plan. The separate host-safety anchor (§12) would take
  §12.13 (default) or §11.4.279 (alternative), operator's choice (Q-R7).
- New deferral ids: next free is OWED-GATE-143 (highest is 142 at HEAD and upstream main).

## 7. Review slices for the §11.4.276 budget

Each slice is one work item with its own ground-truth record (§11.4.276(B)), class
inventory (§11.4.276(C)), declared threat boundary before round 1 (§11.4.276(E)(2)) and
`R_max` = 5 unless the operator declares 6–7. Review substrate per §11.4.209.

| Slice | Content | Ground truth | Threat boundary (declared up front) |
|---|---|---|---|
| S1 | 277(B.1), (A.2), (F), (H), (I) | llmctl `v3.2.2` source at the pin + `347d7e6`; `cm_llmctl_submodule_nonrecursive.sh`; OWED-GATE-121/126/129/130 rows | Call-site identity, use records, record key, evidence custody; NOT model quality |
| S2 | 277(C)(3), (C)(7), (C)(8), (D.1) | `vision-golden-v1` `expectations.json` + generator; recorded runs; §11.4.50 text | Corpus integrity, determinism, correction path; NOT host safety (E) |
| S3 | 278(D.1), (E.1), (F.1), (G), (G.1), (J)(5), (J.1) | HelixQA `vision_gate.go` at the round-2 GO commit; the reference consumer's catalogue | Verdict semantics and coverage; NOT capture tooling per platform |
| S4 | 277(J)/(J.1), 278(K.1), templates, carrier compact summaries, ledger rows, OWED-GATE-143, llmctl pin bump to ≥ `347d7e6` | `post_update_hook.sh`, templates, carriers, `gate_ledger_deferrals.tsv` | Propagation and bookkeeping only; Q-R1 decided BEFORE S4 starts |

Order: S1 → S2 → S3 (S3 needs HelixQA round 2 at GO) → S4. S1 and S2 may run in
parallel (disjoint clauses).

## 8. Amendment text, ready to paste

Insert points are named against `Constitution.md` at HEAD `c4b74082ba28`. Every block
keeps the anchor's single block-start (§11.4.227(B)); carriers need their compact
summaries updated in lockstep (§11.4.157).

**277(A.2) — append after (A.1).**
> **(A.2) Decision-use record.** Every decision-bearing use appends one record to the consumer's untracked per-host use log: time, calling repository, profile, the `llmctl require-validated` exit code obtained immediately before the use, and the digest of the validation record it relied on. The record carries no prompt, image, answer, credential or host name. A decision-bearing use with no record, or with a record whose exit code is not 0, is a §11.4.277 violation. This record is the input `CM-LLMCTL-VALIDATED-BEFORE-DECISION-USE` checks.

**277(B.1) — append after (B).**
> **(B.1) Resolved call site.** Every `llmctl` a tracked file of a governed project invokes MUST be the constitution-vendored pin. Before a decision-bearing use the caller (or a constitution-shipped resolver it calls, resolved via `find_constitution.sh` so a nested submodule reaches the same one) compares the invoked binary's reported version and commit with the `submodules/llmctl` gitlink and refuses with exit 2 on a mismatch or when no binary is found. A PATH `llmctl` of another version is never used for decision-bearing work. Mentioning `llmctl` in prose, comments or evidence is not an invocation.

**277(C)(3) — append to the end of (C)(3).**
> Every content class the consumer declares carries at least one golden-bad control that discriminates it — same layout with wrong or absent content — and names, in its `discriminates` field, the golden probes it controls; a declared class without such a control is a class the model is NOT validated for.

**277(C)(7) — replace the sentence beginning "the reference value is ONE repeat".**
> the reference value is ONE repeated probe (`determinism_repeat` of `vision-golden-v1`) and is sufficient only for non-decision diagnostics; decision-bearing use requires the whole suite run N times under the recorded settings with identical per-probe verdicts and identical normalised output hashes on the same host, N per §11.4.50 (default 3); across hosts with different engines or backends only verdict identity is required and the per-host hashes are recorded side by side.

**277(C)(8) — new, after (C)(7).**
> **(8) REPRODUCIBLE FIXTURES.** A generated fixture is valid only while its committed generator, run from committed inputs in a clean directory, reproduces the recorded SHA256 byte for byte. A captured fixture records the build digest (§11.4.264), data fixture, viewport and DPI, locale, theme, fonts and capture method; a missing pin makes it invalid.

**277(D.1) — append after (D).**
> **(D.1) Defect classes.** A failed golden probe, or a passing control, is classified from the closed set `fixture-defect` (the image does not show what the manifest says), `expectation-defect` (the check is wrong for content that IS shown), `prompt-defect`, `engine-defect`, `model-capability-gap`. Only the first three may change a suite, and only as a NEW suite version (a new content hash, which voids every record keyed on the old one) carrying a §11.4.276(B) ground-truth record, an independent §11.4.142 review and a tracked item. Editing a suite in place after a failing run stays forbidden. A `model-capability-gap` never changes a suite: the class is recorded as not validated for that model (§11.4.254).

**277(F) — append to (F).**
> Custody: the record summary and every hash are committed under the evidence location; bulky raw evidence (returned images, full logs, transcripts) may stay untracked and is then referenced by SHA256. Tracked text names hosts by role only (for example "development host", "remote CPU-only host"); no host name, address or credential enters a tracked file (§11.4.10).

**277(H) — append to (H).**
> A consumer's record additionally binds the llmctl version and commit that produced it and the run count; at llmctl ≥ `347d7e6` the llmctl record itself binds the host name and `require-validated` refuses a record from another host; at the `v3.2.2` pin it does not, and the consumer binds host identity itself.

**277(I) — append to (I).**
> A run against another machine's endpoint (`--host`) is cross-host verdict evidence only; it never becomes that host's record. Hosts are named by role in tracked text.

**277(J) — append to (J).**
> The validation tooling's manual, guide, FAQ and diagrams (data flow, model state machine) follow §11.4.257 / §11.4.258. **(J.1)** On every constitution pull the §11.4.164 post-update hook reports whether `submodules/llmctl` is initialised non-recursively, which `llmctl` version the host resolves and whether it equals the pin.

**278(D.1) — append after (D).**
> **(D.1) Session preflight.** Before a suite run the full vision pipeline (capture → model → comparator) judges one golden-good and one golden-bad frame from the §11.4.277 corpus and one project golden pair (a known screen and its wrong-content twin). Any wrong result blocks the run.

**278(E.1) — append after (E).**
> **(E.1)** An action that succeeded (a click returned, a navigation completed) never substitutes for the read of the resulting screen. A vision result requested for an assertion MUST be able to change that assertion's outcome — by deciding it, or by raising a (F.1) finding; a vision call whose result is discarded is decorative and is a defect.

**278(F.1) — append after (F).**
> **(F.1)** When the deciding oracle and a corroborating oracle disagree on the same frame, the disagreement is recorded as a finding and investigated (§11.4.102); the oracle order decides which verdict is reported, never whether the disagreement is recorded.

**278(G) — in the closed outcome set, add `blocked`; append (G.1).**
> … `waived` (§11.4.271) and `blocked` (a validated model errored, timed out or returned unparseable output for this frame; exit 2; never a pass), each with a reason and a tracked item. **(G.1)** A bank or challenge step with no executable assertion never yields a read-verified PASS for its catalogue entry; the entry counts as uncovered.

**278(J)(5) — append to item (5).**
> Catalogue entries are registered guards for §11.4.135: an entry with no verdict for the candidate fingerprint is uncovered and blocks exactly as a FAIL does.

**278(J.1) — append after (J).**
> **(J.1) Seeded defect per platform.** For every shipped platform a committed seeded-defect variant (a wrong label, a missing control, a swapped colour, a truncated list) MUST be caught by the suite with a FAIL naming the mutated entry (§11.4.273 control needle). Until it is, that platform's vision-dependent verdicts are `blocked` with reason `seeded-defect-not-caught`.

**278(K.1) — append after (K).**
> The §11.4.164 post-update hook reports, per consumer with a UI, whether a catalogue exists for each declared surface.

## 9. Impacted gates and mutation pairing

One new name; everything else amends an existing deferral contract. Each row's paired
§1.1 mutation MUST make the gate fail; each golden-FALSE MUST NOT fire it (§11.4.201(1)).

| Gate (ledger id) | Change | Paired mutation → FAIL | Golden-FALSE |
|---|---|---|---|
| `CM-LLMCTL-VALIDATED-BEFORE-DECISION-USE` (121) | Input = (A.2) use records | Delete the record of one use, or set its rc to 2 | Every use preceded by an rc-0 record |
| `CM-LLMCTL-ONLY-ACQUISITION` (126) | + (B.1) call-site identity | A PATH shim `llmctl` reporting another version is used | Prose "llmctl 3.2.2 was measured" and a `# llmctl` comment |
| `CM-MODEL-DETERMINISM-PINNED` (124) | N ≥ §11.4.50 N, per-probe hashes | A record with 2 runs, or one differing hash in run 2 | Two hosts with different hashes, same verdicts, each internally identical |
| `CM-VISION-KNOWN-ANSWER-FIXTURES` (122) | + rebuild-to-hash, per-class controls, captured-fixture pins | Flip one PNG byte; delete the control of one class | A new fixture landing with its control and generator input |
| `CM-MODEL-WRONG-ANSWER-NOT-RETRIED` (125) | + (D.1) new-version path | Widen a manifest in place after a failing run; loosen under `model-capability-gap` | New suite version with an `expectation-defect` record, ground truth and review id; a tightening with no record |
| `CM-MODEL-VALIDATION-KEY-COMPLETE` (129) | + llmctl version/commit, run count, host identity | Drop the llmctl commit from a record | A complete record at llmctl ≥ `347d7e6` |
| `CM-MODEL-VALIDATION-EVIDENCE` (130) | + custody split, role-only naming | A private host name in a tracked record | Role-named record with sha-referenced untracked raw files |
| `CM-HELIXQA-VISION-VALIDATED` (134) | + (D.1) preflight | Preflight comparator accepts the golden-bad frame and the run starts | Preflight passes both frames and the project pair |
| `CM-UI-VERDICT-PER-FRAME-EVIDENCE` (136) | + (E.1) | A step PASSes on action success while vision errored | Action success and a positive read of the bound frame |
| `CM-UI-SCREEN-IDENTITY-NOT-PLAUSIBILITY` (137) | + (F.1) | A DOM-vs-vision disagreement is not recorded | DOM and vision agree |
| `CM-UI-NO-SKIP-FLAGS` (138) | + `blocked` in the set; (G.1) | A prose step counted as PASS; a runtime model error reported PASS | A `blocked` outcome with reason and tracked item |
| `CM-HELIXQA-UI-SUITE-PER-PLATFORM` (131) | + (J.1) seeded defect | A platform whose seed was not caught still reports PASS rows | Seed caught on the exact mutated entry |
| `CM-UI-CATALOGUE-COVERAGE-100` (132) / `CM-UI-QA-READINESS-GATE` (142) | + (J)(5) fingerprint coverage | A verdict from an older fingerprint counted for the candidate | All verdicts on the candidate fingerprint |
| NEW `CM-277-278-CONSUMER-PROPAGATION-REPORTED` (OWED-GATE-143) | (J.1) / (K.1) hook report + template pointer | Hook run on a consumer with a PATH `llmctl` ≠ pin prints nothing; a template without the pointer | Consumer at pin, templates carrying the pointer |
| `CM-COVENANT-114-277/278-PROPAGATION` (implemented) | Unchanged literal; mirrors must carry updated compact summaries | Amend `Constitution.md` only, leave a mirror summary stale | All four carriers updated in lockstep |

Ledger note: OWED-GATE-143 lands with its deferral row in the same change (§11.4.227(A)).
Whether adding one registered deferral moves the `gate_ledger_baseline.txt` ratchet was
NOT read (UNCONFIRMED); the integrator re-reads `gate_ledger.sh` before landing S4.

## 10. Implementations against the rules

Needed because §11.4.278 is PROPOSED until implementations and evidence exist.

### 10.1 llmctl

Repository HEAD `fc77be2` (`v3.2.2-13`); the constitution pins `v3.2.2` (`5c3dea57fb35`).

| Rule clause | Status | Evidence (read 2026-10-14) |
|---|---|---|
| 277(A) `require-validated`, `LLMCTL_VALIDATE_STRICT`, `LLMCTL_VALIDATE_ON_START` | Satisfied by code | `lib/validate.sh` lines 345–454 (grep) |
| 277(A.1)(1) exits 0/1/2 | Satisfied by code | `lib/validate.sh` header lines 15–17 |
| 277(A.1)(4) `--host` is evidence only | Satisfied, observed | second-host run log: "the result is evidence only, it is NOT recorded as 'vision' validation state" |
| 277(C)(5)(6) mechanical judge, self-test | Satisfied, observed | judge self-test 19/19 in the second-host run log |
| 277(C)(7) as written upstream (one repeat) | Satisfied | `expectations.json` `determinism_repeat` lists one probe |
| Proposed 277(C)(7) N=3 + per-probe hashes | NOT satisfied | Record key has no run count or output hashes |
| 277(H) host binding | NOT at the pin; satisfied at `347d7e6` | `compute_key` returns `profile, host, model_sha256, model_files, engine_tag, launch_fingerprint, suites, no_suite_reason`; `check_state` compares `host` |
| Proposed 277(H) llmctl version/commit in record | NOT satisfied | 0 hits for `llmctl_version` / `LLMCTL_VERSION` in `validate.sh` / `validate_judge.py` |
| 277(F) hash-chained evidence | NOT satisfied (upstream already says so) | — |
| 277(I) per-host records | One host only | Development host: live PASS 21/0/0 runs 2026-10-13 (×2) and 2026-10-14 (the 2026-10-14 run's mode — local record or `--host` — was not re-read). Second, CPU-only host: PASS 21/0/0 in 1552 s (llmctl commit `fc77be2`, `docs/qa/vision-live-<second-host>-2026-10-14/`) — run with `--host`, so it is cross-host VERDICT evidence and NOT a validation record for that host. Whether its answers are byte-identical to the first host's was not compared (UNCONFIRMED) |
| Documentation currency | Drift found | `lib/validate.sh` lines 12–13 still say "No real-model run has been recorded yet" although live runs are committed under `docs/qa/` (§11.4.106 finding for llmctl) |

### 10.2 HelixQA (`submodules/qa`, branch `feature/vision-no-bluff`)

Round 1: `8627c0d`, `4ccbd03` (committed). Round 2: fix commits `0092f0c`, `f08280b`,
`8c42f92`, `79f0aac`, `c47dfb5` exist plus an uncommitted change to
`pkg/autonomous/pipeline.go`; the round-2 review is open. Per §11.4.134 nothing on this
branch counts as satisfied until that review returns GO.

| Rule clause | Status |
|---|---|
| 278(H) frame-bound verdict (`FrameSHA256`, pHash, before-frame sha) | Implemented in round 1; not yet GO |
| 278(G) / (D) BLOCKED on missing frame, provider error, ambiguous reply | Implemented in round 1; not yet GO |
| BLOCKED wired to the process exit code | **Not yet satisfied** (round-2 finding, in progress) |
| Echoed `VERIFIED: yes/no` template must not pass | **Not yet satisfied** (fix `0092f0c`, unreviewed) |
| `recognize` must read only the transcription, not the whole reply | **Not yet satisfied** (fix `f08280b`, unreviewed) |
| A gated step must never be promoted SKIPPED→PASSED by the second runner | **Not yet satisfied** (fix `8c42f92`, unreviewed) |
| Provider ordering (an unvalidated provider must not answer first) | **Not yet satisfied** (fixes `79f0aac`, `c47dfb5`, unreviewed) |
| Determinism of vision requests | **Not yet satisfied** (fix `79f0aac`, unreviewed) |
| Key redaction in logs | **Not yet satisfied** (fix `79f0aac`, unreviewed) |
| 278(D) vision step gated on `llmctl require-validated` + STRICT | **Not satisfied**: 0 files reference `require-validated` or `LLMCTL_VALIDATE_STRICT` outside `tools/opensource` (positive control `HELIX_VISION_ENDPOINT` = 12 files, negative control = 0) |
| 278(F) deterministic oracle tier | Partly: pHash `golden` and `expect_change` are deterministic checks |
| Proposed 278(E.1) action success never a PASS | Gated steps: implemented. Non-gated steps still PASS as "UNVERIFIED-by-vision" (reference doc state diagram) — acceptable only if no catalogue entry is decided by a non-gated step |
| Proposed 278(D.1) preflight, (J.1) seeded defect, (G.1) prose steps | UNCONFIRMED — the terms `preflight` / `seeded` / `catalogue` occur in 18 / 36 / 21 files but those files were not read |

**What §11.4.278 needs to graduate from PROPOSED** (proposed criteria, operator to
confirm, Q-R8): HelixQA round 2 at GO; HelixQA's vision step gated on
`require-validated` + STRICT; one real bank run on the reference consumer through the
llmctl `vision` profile on a host holding a fresh record, with per-frame evidence; the
session preflight and one platform's seeded defect caught; OWED-GATE-134 and 136
implemented.

## 11. Consumer propagation impact

Index gitlinks (`git ls-files -s`) compared with upstream main `5082389` in the
constitution's object store (every pin was present).

| Consumer | Pin | Date | Behind main | Has 277/278 | Highest anchor |
|---|---|---|---:|---|---|
| catalogizer | `50823897f0a8` | 2026-10-14 | 0 | yes | 278 |
| helix_code | `9b795534124b` | 2026-10-13 | 8 | no | 276 |
| llmctl | `4091798af478` | 2026-10-13 | 21 | no | 276 |
| tmux | `1d0485f55288` | 2026-10-11 | 28 | no | 276 |
| claude_toolkit | `e44f22fc5468` | 2026-10-03 | 70 | no | 275 |
| boba | `317cf4352cc6` | 2026-09-27 | 296 | no | 275 |
| ytdlp | `b7c8c239598c` | 2026-09-11 | 352 | no | 274 |
| project_toolkit | `902979027a90` | 2026-08-27 | 377 | no | 271 |
| lava | `f6cf86ed4bfa` | 2026-08-20 | 401 | no | 267 |
| vasic (this repo, index) | `a71b1767b402` | 2026-10-05 | 40 | no | 276 |

Notes:

- Only catalogizer — the reference UI consumer — already carries §11.4.277/§11.4.278.
  This repository's INDEX pin does not; its submodule working tree (`c4b74082ba28`,
  branch `feature/label-sync`) does. Moving the index is an operator decision under
  this repository's standing authorization, which covers fast-forwards only; HEAD is
  44 ahead / 1 behind main, so it is NOT a fast-forward of main.
- **llmctl cannot inherit §11.4.277/§11.4.278 under the current rules (measured).**
  §11.4.277(B) and `CM-LLMCTL-SUBMODULE-NONRECURSIVE` refuse any llmctl constitution
  pin that contains `submodules/llmctl`. The vendoring commit `411389f` precedes the
  anchor commit `4bcc95b` (`merge-base --is-ancestor` TRUE), and both `4bcc95b` and
  `5082389` carry the gitlink. So the tool that implements §11.4.277 is pinned to a
  constitution without it, and every later anchor is blocked the same way. Q-R1.
- Every consumer behind main receives these amendments only after a pin bump and a
  §11.4.26 re-read; the five oldest (claude_toolkit, boba, ytdlp, project_toolkit,
  lava) are 70–401 commits behind and also miss the anchors above their "Highest
  anchor" value (up to §11.4.268–§11.4.276 for lava).
- The vasic sites ship web UIs, so §11.4.278 binds them once it graduates; their
  Playwright suites are not HelixQA suites (278(C) makes HelixQA the driver).

## 12. Separate proposed anchor: agent host resource safety

Listed only; not drafted here (another work stream is building it).

- **Trigger:** a host hang caused by agents filling RAM-backed `/tmp` (tmpfs).
- **Mechanisms being built:** umbrella `scripts/agent-scratch.sh` and
  `scripts/agent-admit.sh` (present, untracked, owned by that stream) and an llmctl
  host-safety component. Not read or assessed here.
- **Shape (as briefed):** a fan-out budget, disk-backed scratch instead of tmpfs, and
  an admission check before an agent or heavy job starts.
- **Interaction with §12.6:** tmpfs pages are RAM; the 60% ceiling must count tmpfs
  usage, and a scratch rule that moves work to disk is how agents stay inside it.
  The §12.6 block at main (its first 30 lines) has no `tmpfs` hit (read 2026-10-14).
- **Interaction with §12.12:** an admission check that bounds concurrent agents also
  bounds processes and threads; it should reuse §12.12's headroom computation rather
  than add a second limit.
- **Also composes:** §11.4.183 (useful parallelism, not agent count), §11.4.230(C)
  (bounded fan-out), §11.4.232 (long-op registry), §11.4.225 (CPU quota), and the
  §11.4.277(E) llmctl precedent (refuse before start under memory pressure).
- **Placement:** §12.13 (default; the §12 host-safety family) or §11.4.279. No `### §12.9`
  heading was found at main although §12.9 (disk) is cited elsewhere; whether it is
  defined in another form was not checked (UNCONFIRMED). Q-R7.

## 13. Open questions for the operator

| # | Question | Default chosen here | Consequence of the other choice |
|---|---|---|---|
| Q-R1 | How does llmctl inherit §11.4.277/§11.4.278 when its constitution pin may not contain `submodules/llmctl`? Options: (a) pointer paragraph only, citing a constitution version it does not vendor; (b) move the llmctl vendoring out of the constitution into a separate hub; (c) relax the gate to accept such a pin while `recursive_init: false` holds | None — blocking only for llmctl's own adoption | (c) changes an implemented gate and an explicit operator decision of 2026-10-13 |
| Q-R2 | Does llmctl support running in place from `submodules/llmctl`, or must a consumer `llmctl setup` from the pin? | 277(B.1) checks identity of whatever binary is invoked against the pin | If in-place works, (B.1) can name the vendored path directly |
| Q-R3 | Raise the determinism floor to §11.4.50 N=3 for decision-bearing use? | Yes | Cost: on the CPU-only host one pass took 1552 s; three passes ≈ 78 min per profile per host (estimate, not measured) |
| Q-R4 | Accept the reviewed expectation-correction path (277(D.1))? | Yes | Without it a wrong manifest entry refuses a correct model forever |
| Q-R5 | Require a non-Latin (Cyrillic) fixture class in the base corpus? | No — consumer-driven; consumers with Cyrillic UI (this repository's Russian site) declare it | A fixed list in canon goes stale |
| Q-R6 | Add `blocked` to the 278(G) closed set? | Yes | Otherwise a runtime model error has no lawful outcome other than FAIL |
| Q-R7 | Place agent host resource safety at §12.13 or §11.4.279? | §12.13 | §11.4.279 keeps all new rules in one series |
| Q-R8 | Graduation criteria for §11.4.278 PROPOSED → binding (§10.2) | As listed | — |
| Q-R9 | Bump the constitution's llmctl pin from `v3.2.2` to ≥ `347d7e6` (host binding) in S4? | Yes, with a §11.4.26 re-read of 277 | Host binding stays a consumer obligation |

Status of the earlier questions in `06_open_questions.md`: Q1, Q2, Q3, Q5, Q6, Q8, Q14
are answered by upstream; Q4 is covered; Q7, Q11, Q12, Q15 became amendments or Q-R3;
Q9, Q10, Q13 stay open.

## 14. Honest boundary

- This is a plan and draft text, not mechanism. No gate, hook, template or canon text
  changed because of it.
- Nothing here has passed an independent review (§11.4.142); slices S1–S4 are where
  that happens.
- Pins, behind-counts and the free-number reading are dated measurements of
  2026-10-14 and go stale; re-measure before acting.
- The HelixQA round-2 status comes from the coordinator's brief plus the branch's
  commit list; no HelixQA test was run here.
- No llmctl test was run here; test counts quoted from commit messages are the
  author's claims, not measurements of this session.
