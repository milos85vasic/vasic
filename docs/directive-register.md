# Directive Register — every operator directive, with its disposition

**Status of this file: AUTHORITATIVE INDEX OF INTENT for the umbrella repository.**

## What this is, and why it exists

Every directive the operator gives is recorded here with a disposition, so that no
request can be forgotten, silently dropped, half-applied, or quietly reinterpreted.
It answers a standing operator requirement, restated on 2026-09-05:

> *"All prompts / requests we are giving, and which we have already given MUST BE
> archived for future references so they all can be ALWAYS regularly checked if they
> have all been taken into the account, processed or applied! No work can be
> forgotten, lost, corrupted or ignored!"*

**This is the THIRD time that requirement has been made**, and recording that fact is
itself part of honouring it. The earlier two are `workshop/docs/work-register.md`
rows **R15**, **R22** and **R24** — where R24 is explicitly noted as *"a restatement
of R22, not a new ask"*. `docs/session-instruction-audit-2026-09-01.md` answers a
near-identical request for one specific session.

## Why those earlier answers were not enough — the measured gap

Both prior instruments are DOCUMENTS. Neither is a GATE.

    $ grep -c 'work-register\|instruction-audit\|directive' scripts/check-registry.tsv
    0

Measured 2026-09-05. Nothing in this repository verified that either register was
complete, current, or honest. A register nobody checks decays into a register nobody
trusts, and the operator's requirement is precisely the *checking* half — "ALWAYS
regularly checked". So this file ships with `scripts/verify-directive-register.sh`,
registered in `scripts/check-registry.tsv` as `directive-register` with a
`--prove-failure` paired proof. **The document is the record; the gate is the
promise.**

## Scope, and why this file is at the umbrella root

`workshop/docs/work-register.md` is scoped to the `workshop` submodule and is PRIVATE.
Operator directives routinely span `workshop`, `ai_interviewing` and the umbrella root
at once, and a directive recorded only inside one submodule is invisible from the other
two. This file is the cross-cutting index. The workshop register remains authoritative
for workshop-internal detail; this file links to it rather than duplicating it.

**Content boundary.** This repository is PUBLIC. Operator directives are quoted because
they are the operator's own words about work to be done — they are not private material.
Where a directive would itself carry private content it is SUMMARISED and the private
file is cited by path only. See `docs/content-boundary.md`.

## Disposition vocabulary — fixed, and the gate enforces it

| Disposition | Meaning |
|---|---|
| `DONE` | Delivered AND verified by a named mechanical check. The evidence column must name it. |
| `IN-PROGRESS` | Actively being worked in the current session. |
| `OPEN` | Accepted, not yet started. Never a resting state for a directive older than one session. |
| `BLOCKED` | Cannot proceed without an operator decision or an environment change. The blocker must be named. |
| `STANDING` | A permanent rule that governs all future work rather than a task that completes. |
| `SUPERSEDED` | Replaced by a later directive, which must be named. |

A row whose disposition is `DONE` without evidence is a bluff, and the gate fails on it
(§11.4 — every PASS carries positive evidence).

---

## Session 2026-09-05 — directives D001..D013

Recorded verbatim where short, by intent where long. Every row's evidence column names
a command or a file, never a recollection.

| # | Directive | Disposition | Evidence / blocker |
|---|---|---|---|
| D001 | Chapter 02 must be processed exactly as Chapter 01 was — multi-part archives + manifests | `DONE` | `scripts/archive-videos.sh` → 16 parts + `.sha256`; round-trip re-verified via `extract-videos.sh` → `skip (intact)`, exit 0 |
| D002 | Proper `.gitignore` configuration for the new chapter media | `DONE` | Verified per artifact class with `git check-ignore -v`: `.mp4`/`.verified` IGNORED; `.sha256`/`part-*`/PDF TRACKABLE. Existing rules are generic, not per-chapter — **no edit was needed, and that is a measurement, not an assumption** |
| D003 | Extract Chapter 01 — the mp4 is absent from the working tree | `DONE` | `extract-videos.sh` restored 1,871,981,557 bytes from 36 parts; every part hash-verified, stream hash verified, extracted digest matched the manifest |
| D004 | Extend the setup script so anything missing is made present — in particular EVERY archived chapter must be extracted | `DONE` | `workshop/scripts/setup.sh` gained `do_extract_chapters` (+ `--no-extract`). **Proven by removal**: deleted `02.01`'s recording, ran setup, got it back BYTE-IDENTICAL (sha `bdc6c495a9a3…`, 78031598 bytes) while `01` and `02` were correctly skipped as intact. `pipeline/venv-setup.sh` gained a `uv venv --seed` fallback (stdlib path still tried first), an absolute-interpreter fix, an interpreter assertion, and the missing `extract/requirements.txt` install |
| D005 | Deep in-depth analysis of everything unfinished; identify and track all pending SpecKit tasks, gaps, shortcomings, issues, weak spots, danger zones | `IN-PROGRESS` | Spec 001 audited: 120 tasks, 69 done / 51 open. Spec 002 audited: 143 tasks, 110 ticked / 107 substantive. Both audits recorded findings including four weak ticks and one red gate |
| D006 | Everything found must be incorporated, implemented, investigated, systematically debugged, completed, tested, and verified with mechanical evidence | `STANDING` | Governs every dispatch this session. Restates `workshop/docs/work-register.md` R1 |
| D007 | Fan out subagents; do everything now | `STANDING` | Recurs each session. 10 agents dispatched this session: spec-001 audit, spec-002 audit, platform health, ai_interviewing health, gate sweep, runner research, GPU research, Ollama wiring map, sub-chapter data model, UI/UX research |
| D008 | Regularly boot the workshop and ai_interviewing local websites so both can be exercised | `IN-PROGRESS` | `ai_interviewing` booted cold→live→down, `http://localhost:8099` HTTP 200 verified. Workshop platform boot NOT yet verified this session |
| D009 | All work fully committed and pushed to all upstreams — every submodule recursively, and the main repository | `OPEN` | Nothing committed yet this session. Gated on D004/D005 completing so a commit is not made over a half-finished tree |
| D010 | All work ALWAYS on `main` branch(es) only | `STANDING` — one exception found | 12 of 13 submodules on `main`. **`submodules/LLMProvider` is on `master`**; its upstream default IS `master` and `origin/main` there is 16 commits BEHIND. Reported to the operator; not changed |
| D011 | Keep the operator updated on progress and all important events | `STANDING` | Progress reported at each agent completion and each verified milestone |
| D012 | *(background)* Local Ollama model choice must be FULLY DYNAMIC per host resources — CPU, GPU, IO. Use the most proper runners if better: llama.cpp (GPU/CUDA), Colibri. Combine all three in parallel if that gives better results. Deep planning + exhaustive deep web research for optimal tuning on EVERY host | `IN-PROGRESS` | Host measured: RTX 3060 12 GB, driver 595.84, CC 8.6; Ryzen 2700X AVX2 (no AVX-512); 30 GiB RAM. Ollama confirmed GPU-accelerated (37/37 layers, `100% GPU`). Distro llama.cpp is CPU-ONLY. **Conflict found: the ASR pipeline actively REFUSES to run when a GPU is visible, across six enforcement layers** — see D012-CONFLICT below. Two research agents running |
| D013 | *(background)* Sub-chapter `02.01` added under Chapter 02; process it as any chapter. Its position under its parent MUST be obvious from every vantage point including UI/UX. Extend/improve the whole UI/UX, add styles and reusable widgets. Deep analysis, planning and deep web research. The platform experience must be a bleeding-edge game changer for learning, cooperation and progress | `IN-PROGRESS` | Media `DONE` (2 parts + manifest, exit 0). Backend design `DONE` — 37 tasks drafted as `specs/003-chapter-hierarchy/`; identity scheme `02.01` dotted, byte-lexicographic sort proven correct. **Three defects already FIXED**: the `HasSuffix` scope match in `workshop-redact/main.go:596` (disclosure-control severity), and the `chapter-\d+` silent-drop regexes in `meeting_notes.py:98` + `author.py:150`, each asserted in BOTH directions. UI/UX research still running. **`02.01` ships no PDF notes — notes-less tolerance still unverified** |
| D014 | All prompts/requests must be archived and ALWAYS regularly checkable, so nothing is forgotten, lost, corrupted or ignored | `DONE` | THIS FILE + `scripts/verify-directive-register.sh` (exit 0, 14 rows, 0 findings) + registry row `directive-register`. Proof: `--prove-failure` → **5 mutations, 5 caught, 0 missed**, control passes. `verify-check-registry.sh` → **51 PASS / 0 FAIL / 0 DEBT** (was 49), R5 anti-drift green. The gate caught a real defect in this very file on its first run (D007's disposition was outside the vocabulary) |

### D012-CONFLICT — recorded because it must not be resolved silently

Directive D012 requires dynamic, capability-driven runner selection. The ASR pipeline
was deliberately built to do the opposite, and says so in its own source:

| Layer | Location | Behaviour |
|---|---|---|
| Hardcoded device | `workshop/pipeline/run_faster_whisper.py:85` | `device="cpu"` — no flag, no env |
| Active refusal | `workshop/pipeline/run_faster_whisper.py:75-78` | CUDA visible → `FAIL`, return 1 |
| Env masking | `workshop/pipeline/run_faster_whisper.py:36-37` | forces `CUDA_VISIBLE_DEVICES=""` |
| Compile-time | `workshop/pipeline/build_whispercpp.sh:70-73` | 11 GPU backends `OFF` |
| Post-build assert | `workshop/pipeline/build_whispercpp.sh:90-94` | `ldd` finds a GPU lib → exit 1 |
| Post-run assert | `workshop/pipeline/run_whispercpp.sh:98-103` | stderr names CUDA → exit 1 |

`workshop/pipeline/requirements.txt` states the rationale: *"no GPU runtime dragged onto
a host that deliberately excludes the GPU."* **That premise is measurably false on this
host** — `ctranslate2.get_cuda_device_count()` returns `1`. Satisfying D012 therefore
means REVERSING a documented, defended decision, not fixing a bug. It is recorded here
so the reversal is deliberate and attributable rather than an unexplained diff.

---

## Prior sessions

Earlier directives are recorded in the instruments that already existed. They are
referenced, not copied, so there is one authority per row:

| Source | Scope | Rows |
|---|---|---|
| `workshop/docs/work-register.md` | `workshop` submodule, PRIVATE | R1..R25 |
| `docs/session-instruction-audit-2026-09-01.md` | session `f190827d`, umbrella | 51 distinct instructions from 96 prompt events |

**Standing rules inherited from those registers** that bind all future work, restated
here because a rule recorded only in a private submodule is invisible from the root:

- **R18 (EXCLUSION, binding):** never mention or port the company the interviewing
  material was prepared for, nor any codebase cross-referenced in `ai_interviewing`.
- **R1:** fix every discovered issue systematically — root cause, machine evidence,
  no bluffing.

---

## How to use this file

1. **Before starting work**, read the `OPEN`, `IN-PROGRESS` and `BLOCKED` rows.
2. **When a directive arrives**, add a row IMMEDIATELY with disposition `OPEN` or
   `IN-PROGRESS`. Do not wait until it is finished — the failure mode this file
   exists to prevent is a directive that was never written down.
3. **When work completes**, move the row to `DONE` and put a command or a file path
   in the evidence column. A `DONE` with no evidence is a bluff.
4. **Verify with** `bash scripts/verify-directive-register.sh`. Three-valued:
   0 clean, 1 a real finding, 2 could-not-determine. **2 is never a pass.**
