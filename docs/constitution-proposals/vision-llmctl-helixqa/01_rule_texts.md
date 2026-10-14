# 01 — Rule texts (full blocks, PROPOSED, not canon)

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-10-14 |
| Status | proposal — NOT placed in `submodules/constitution/Constitution.md` |
| Anchors | ANCHOR-A..ANCHOR-E, tentative §11.4.277..§11.4.281 |

**Placement note for the integrator.** The five blocks below are written in the
canon heading format. The numbers 277–281 are TENTATIVE: they were free on both
sides of the upstream fetch taken 2026-10-12 (canon's highest anchor was
§11.4.276). Re-check before placing (`grep -n '^### §11\.4\.27[7-9] \|^### §11\.4\.28[01] '
Constitution.md`). If a number has been taken in the meantime, renumber by
replacing the placeholder token `ANCHOR-X` everywhere in this proposal set
(blocks, gates, carriers, ToC); the placeholders are used inside the blocks for
cross-references so a renumber is a mechanical substitution, never a rewrite.

Placeholder map: `ANCHOR-A` = §11.4.277, `ANCHOR-B` = §11.4.278,
`ANCHOR-C` = §11.4.279, `ANCHOR-D` = §11.4.280, `ANCHOR-E` = §11.4.281.

---

### §11.4.277 — Constitution-owned `llmctl` wrapper: every local-model obtain / run / query by any project or nested submodule goes through ONE wrapper shipped by the constitution submodule; direct `llmctl` invocation is banned (User mandate, 2026-10-12)

**Forensic anchor — operator mandate (2026-10-12), intent recorded verbatim by the
orchestrating session:** vision-model obtaining and running via `llmctl` MUST go
through the constitution submodule — a constitution-owned wrapper used by every
consuming project and every nested submodule, recursively; direct `llmctl` calls
are banned.

**Forensic FACTS (measured, genericised).** (1) `llmctl` is its own repository,
not a submodule of the constitution. Measured 2026-10-12/13 by the orchestrating
session at version 3.1.0; **re-measured 2026-10-14 by the drafting agent at
`VERSION` 3.2.2, `git describe` `v3.2.2-8-g3afac16`** — the tool moved two minor
versions inside three days, which is itself the argument for a single, pinned
call site. (2) Its command surface includes `setup`, `doctor`,
`models download|verify`, `start`, `stop`, `switch`, `auto`, `status`, `admit`,
`cluster`, and — at 3.2.2 — `validate`, `vision validate`, `validate-all` and
`require-validated` (`lib/validate.sh` header, read 2026-10-14). (3) Its model
catalog (`models/catalog.json`) declares two vision profiles: `vision` on port
8082 (Gemma 3 4B IT Q4_K_M + mmproj) and `vision-pro` on port 8083 (Gemma 3 12B
IT Q4_K_M + mmproj), both served by llama.cpp `llama-server` behind an
OpenAI-compatible API; every catalog file carries a `sha256`, while
`hf_revision` is the moving ref `main`. (4) It uses XDG paths and has no
remote-host flag (orchestrator measurement 2026-10-12/13; not re-measured).
Without a single call site, each consumer would pin its own version, choose its
own profile, skip validation on its own terms and parse its own endpoint — N
divergent copies of one decision (§11.4.251).

**What this is NOT (the §11.4.227 boundary, stated first).** §11.4.76 governs
container orchestration through the containers submodule; it does not govern
model serving. §11.4.231 governs which model TIER an agent dispatch uses; it
says nothing about how a local model is obtained or run. §11.4.74 says extend,
don't reimplement; it does not say where a shared call site lives. This anchor
adds exactly that: the single location (the constitution submodule), the single
interface (the wrapper), and the ban on bypassing it.

**The mandate (ALL hold):**

**(A) ONE WRAPPER, OWNED BY THE CONSTITUTION.** The constitution submodule ships
`scripts/llm/llmctl_wrapper.sh` (name tentative; lowercase snake_case per
§11.4.29) plus its library and tests. It is the ONLY sanctioned way for a
governed project, service, component, test harness or nested submodule to
obtain, start, stop, switch, query, validate or require-validate a model that
`llmctl` manages. Consumers reach it through
`find_constitution.sh` (parent-walk), so a submodule nested at any depth
resolves the SAME wrapper as its umbrella — never a copy (§11.4.251).

**(B) THE WRAPPER'S CONTRACT.** (1) **Version pin:** the wrapper declares the
minimum and the tested `llmctl` version as DATA and refuses (rc 2) an `llmctl`
older than the minimum or not found; it prints the resolved binary path and
version on every call. (2) **Use only through validation:** any subcommand that
hands a model to a consumer (`endpoint <profile>`, `query <profile> ...`)
first runs `require-validated` (ANCHOR-B) and refuses — rc 2, not a degraded
answer — when the record is absent, stale or failing. (3) **Start implies
validate:** `start` / `switch` / `auto` through the wrapper are followed by the
ANCHOR-B validation; a model that starts but does not validate is stopped and
reported. (4) **Three-valued exits:** 0 success, 1 a determined wrong result
(validation FAIL, refused use of a failing model), 2 could not determine
(binary absent, profile not downloaded, endpoint down, insufficient resources).
1 outranks 2. 2 is never a pass. (5) **Audit line:** every call appends one
line (timestamp, caller repository root, subcommand, profile, resolved llmctl
version, rc) to an untracked per-host log; the log never carries prompts,
images, credentials or host passwords.

**(C) DIRECT INVOCATION IS BANNED.** No tracked file in any governed repository
other than the `llmctl` repository itself and the wrapper's own implementation
may invoke `llmctl` in command position (shell, Makefile, CI-equivalent local
hook, container entrypoint, compose file, Go/Python/JS `exec`/`spawn`/
`subprocess` argument vector, or a user-guide code fence instructing the reader
to run it). Mentioning `llmctl` in prose, in a comment, or as the subject of a
measurement is not an invocation. A consuming project that needs a capability
the wrapper lacks extends the wrapper upstream in the constitution (§11.4.74),
never adds a local call.

**(D) REMOTE HOSTS THROUGH THE SAME WRAPPER.** Because `llmctl` has no
remote-host flag (fact 4), validation and use on a designated remote host run
the wrapper ON that host (its own checkout of the same constitution pin),
reached by an operator-supplied host alias read from an untracked per-host
configuration. Credentials, host passwords and private host names never appear
in a tracked file (§11.4.10 / CONST-042); tracked text names hosts by ROLE only
(for example "development host", "remote GPU host").

**(E) NOTHING HERE LOWERS ANOTHER BAR.** The wrapper does not replace §11.4.76
for containerised serving, §11.4.161 rootless runtime, §12.6 memory headroom or
§12 host safety; a wrapper call that would exceed declared headroom is refused
by `llmctl admit` semantics and surfaces as rc 2.

**Honest boundary (§11.4.6).** The wrapper proves that every governed call goes
through one audited, version-pinned, validation-gated path. It does NOT prove
that `llmctl` itself is correct, that the served model is good — that is
ANCHOR-B and ANCHOR-C — or that a process outside governed repositories (an
operator's interactive shell) never calls `llmctl` directly; the ban applies to
tracked files of governed repositories. Whether `llmctl cluster` can carry
remote validation in place of (D) is UNCONFIRMED.

**Classification: universal (§11.4.17)** — `llmctl` is an own-organisation tool
named in canon on the §11.4.76 / §11.4.160 / §11.4.162 precedent (a named
fleet substrate); the consuming project supplies its profile choices, host-role
map and audit-log location as DATA per §11.4.35.

**Composes** §11.4.6 / §11.4.10 / §11.4.29 / §11.4.35 / §11.4.74 / §11.4.76 /
§11.4.161 / §11.4.231 / §11.4.251 / §11.4.254 (capability matrix: the wrapper
reports which profiles are validated, per host) / §11.4.270 (`llmctl` is a
dependency with a VERIFIED existence verdict) / ANCHOR-B / ANCHOR-C / ANCHOR-E.

Propagation gate `CM-COVENANT-114-277-PROPAGATION` (literal `11.4.277` as a
block-start, exactly once per governance file, lockstep across the mirror set
per §11.4.227(B)) + recommended mechanism gates `CM-LLMCTL-WRAPPER-ONLY` and
`CM-LLMCTL-WRAPPER-CONTRACT` (design in `02_gate_design.md`). Paired §1.1
mutations: add a `llmctl start vision` line to a consumer script →
`CM-LLMCTL-WRAPPER-ONLY` MUST FAIL; make the wrapper's `endpoint` skip
`require-validated` → `CM-LLMCTL-WRAPPER-CONTRACT` MUST FAIL; strip the literal
→ propagation FAILs. Golden-FALSE per §11.4.201(1): a README sentence
"`llmctl` 3.2.2 was measured on 2026-10-14" and a comment `# llmctl is pinned
by the wrapper` MUST NOT fire `CM-LLMCTL-WRAPPER-ONLY`.

**Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.277.

Non-compliance is a release blocker regardless of context. No escape hatch — no
`--direct-llmctl-OK`, `--local-wrapper-copy`, `--skip-require-validated`,
`--unpinned-llmctl`, `--remote-credentials-in-repo` flag exists.

---

### §11.4.278 — Validated-before-use: every model `llmctl` runs passes a fully deterministic, recorded, fresh validation + verification on the host that will use it, BEFORE any project, component, service or submodule uses it (User mandate, 2026-10-12)

**Forensic anchor — operator mandate (2026-10-12), intent recorded verbatim:**
every model run by `llmctl` MUST, BEFORE use by any project / component /
service / submodule recursively, pass fully deterministic validation and
verification — a recorded, fresh, passing validation carrying model sha, engine
tag, `llmctl` version, suite hash, host and sampling; a `require-validated`
precondition; repeatability across at least three runs; validation on this
host and on designated remote hosts; credentials never in tracked files.

**Forensic FACTS (measured).** (1) `llmctl` 3.2.2 already implements most of the
mechanism (read 2026-10-14 in `lib/validate.sh`): known-answer suites under
`validation/suites/<name>/`, a deterministic judge (`lib/validate_judge.py`:
normalised substring / ordered / forbidden / first-number / regex / JSON
checks — "never an LLM judging an LLM"), a per-profile state record holding
model sha256, file size/mtime, engine tag, launch fingerprint, per-suite content
hash and timestamp, and `require-validated` that exits 0 only for a matching,
fresh PASS. Its default freshness is `LLMCTL_VALIDATION_MAX_AGE=604800` (7
days). (2) Suites present at 3.2.2: `chat-v1`, `coder-v1`, `embedding-v1`,
`vision-golden-v1`. (3) Live evidence recorded in that repository: two
`vision` profile runs on 2026-10-13, both `validate rc 0`, the second reporting
`counts: pass 21, fail 0, undetermined 0`, model and mmproj sha256 recorded,
VRAM back to baseline; one `small` profile run on 2026-10-14, PASS — **all on
one host**. (4) The vision suite's `determinism_repeat` names ONE probe
(`01_text_large/read`); whether the judge repeats it three times or more is
UNCONFIRMED (not read). So the mechanism exists; what is missing is the
constitutional binding: that no governed consumer may use a model without it,
that it holds on every host of use, and that repeatability is ≥3 runs across
the whole suite.

**What this is NOT (the §11.4.227 boundary).** §11.4.163 governs validation of
MEDIA artifacts; it does not govern the models that read them. §11.4.273
governs control-needling a measuring instrument before believing a census; this
anchor applies that discipline to one specific instrument class — a local
model — and binds it to a use-time precondition. §11.4.264 governs promoting
ONE immutable build artifact; a model file is pinned by sha256 under the same
idea but is not built here.

**The mandate (ALL hold):**

**(A) THE VALIDATION RECORD.** A passing validation is a machine-written record
(§11.4.262) carrying at least: profile; sha256 of EVERY model file (weights AND
projector / mmproj); catalog revision; engine identity (server binary build tag
and backend); `llmctl` version and commit; wrapper version (ANCHOR-A); suite id
and suite content hash (sha256 over the sorted manifest of every fixture,
expectation and prompt file); host fingerprint (host ROLE label plus an opaque
stable id and hardware tier — never a private host name in tracked text);
sampling parameters (temperature, seed, top-k, top-p, max tokens, prompt-cache
setting); run count; per-run per-probe normalised output hash; per-probe
verdict; timestamp; verdict.

**(B) FRESHNESS.** A record is FRESH only while every keyed field still matches
the model about to be used — model sha, engine tag, `llmctl` version, suite
hash, host fingerprint, sampling — AND its age is within the consumer-declared
maximum, whose constitutional ceiling is **30 days**. A consumer MAY declare a
shorter maximum (`llmctl`'s own 7-day default satisfies the ceiling). Any key
change invalidates the record at once, regardless of age. A fine-tuned,
re-quantised or re-converted model is a NEW model (new sha) and starts with no
record.

**(C) `require-validated` IS A PRECONDITION, NOT A REPORT.** Every use path —
the wrapper's `endpoint` / `query`, a service's boot (§11.4.254 boot-time
invariant), a HelixQA session preflight (ANCHOR-D), a test harness — calls
`require-validated <profile>` and proceeds only on rc 0. rc 1 (record is a FAIL)
and rc 2 (no record, stale, could not determine) both REFUSE use. A consumer
that cannot run without the model reports its own result as BLOCKED, never PASS
and never "skipped as green".

**(D) DETERMINISM: ≥3 RUNS, IDENTICAL RESULTS.** A validation executes the full
suite at least three times under the recorded sampling (temperature 0, fixed
seed, top-k 1, prompt cache off, single slot, or the consumer-declared
equivalent that the engine documents as deterministic). Every probe's verdict
AND normalised output hash MUST be identical across the runs on that host. A
divergence is not averaged, voted or retried away: it is rc 1, a determinism
defect investigated per §11.4.102 (root cause first) and recorded. Byte
identity is required WITHIN a host; ACROSS hosts with different backends only
verdict identity is required, and the per-host output hashes are recorded side
by side.

**(E) EVERY HOST OF USE.** A model is validated on each host where it will be
used: the development host and every designated remote host. Remote validation
follows ANCHOR-A(D). A record from host X never authorises use on host Y.

**(F) EVERY KIND, NOT ONLY VISION.** Chat, coder, embedding, decision and vision
profiles all carry a suite (ANCHOR-C covers what a suite must contain). A
profile without a suite is never reported as validated and is unusable by
governed consumers.

**(G) EVIDENCE CUSTODY.** The record summary and every hash are committed in the
consumer's evidence location (§11.4.83); bulky raw evidence (images returned,
full logs, per-run transcripts) stays in an untracked evidence store, referenced
by sha256 (§11.4.268 chain). No credential, host password, private host name or
private content enters a tracked record.

**Honest boundary (§11.4.6).** A fresh PASS proves the model answered THIS suite
correctly and repeatably on THIS host with THIS engine. It does not prove the
model is correct on inputs outside the suite; ANCHOR-C's coverage requirements
and ANCHOR-D's seeded defects are what bound that gap, and they bound it — they
do not close it. GPU kernels on some backends are not bit-deterministic; where
(D) fails for that reason, the recorded outcome is a FAIL with a root cause, not
a relaxation of (D) — relaxing it is an operator decision (§11.4.66) recorded
with evidence.

**Classification: universal (§11.4.17)** — the consuming project supplies its
profile list, maximum age (≤30 days), host-role map and evidence locations as
DATA per §11.4.35.

**Composes** §11.4.5 / §11.4.6 / §11.4.10 / §11.4.66 / §11.4.83 / §11.4.102 /
§11.4.201 / §11.4.245 (the suite IS the oracle, authored first) / §11.4.254 /
§11.4.262 / §11.4.264 / §11.4.268 / §11.4.273 / ANCHOR-A / ANCHOR-C / ANCHOR-D.

Propagation gate `CM-COVENANT-114-278-PROPAGATION` + recommended mechanism gates
`CM-MODEL-VALIDATED-BEFORE-USE` and `CM-MODEL-VALIDATION-DETERMINISM`. Paired
§1.1 mutations: use a profile whose record has a different model sha →
`CM-MODEL-VALIDATED-BEFORE-USE` MUST FAIL; a record with 2 runs, or with one
probe whose output hash differs between runs → `CM-MODEL-VALIDATION-DETERMINISM`
MUST FAIL; a 31-day-old record → FAIL; strip the literal → propagation FAILs.
Golden-FALSE: a 29-day-old record whose every key matches, 3 identical runs,
all probes PASS MUST NOT fire either gate.

**Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.278.

Non-compliance is a release blocker regardless of context. No escape hatch — no
`--use-unvalidated-model`, `--stale-record-OK`, `--single-run-suffices`,
`--validated-elsewhere`, `--llm-judge-OK`, `--retry-until-deterministic` flag
exists.

---

### §11.4.279 — Golden-content oracle bank: vision models are validated against pre-prepared, reproducibly rendered screenshots of KNOWN content with machine-readable expectations and flagged golden-bad controls, scored deterministically; every other model kind has a known-answer suite; a wrong answer is a defect, never an excuse (User mandate, 2026-10-12)

**Forensic anchor — operator mandate (2026-10-12), intent recorded verbatim:**
vision golden screenshots are prepared in advance with KNOWN content,
reproducibly rendered, with machine-readable expectations; the local vision
model must recognise what is expected; golden-bad controls must be flagged;
scoring is deterministic (no LLM judge); a wrong result is a real defect to
investigate (§11.4.102) and fix, never excused or loosened without evidence;
other model kinds get known-answer suites.

**Forensic FACTS (measured 2026-10-14 in the `llmctl` repository).** The
`vision-golden-v1` suite's `expectations.json` declares schema 1, eleven
fixtures with roles `golden` and `control-bad`, a generator
(`scripts/vision/make_golden.py`, stdlib-only, embedded bitmap font, own
DEFLATE, described as byte-reproducible), per-fixture image sha256, per-probe
deterministic checks (`contains_all`, `forbidden`, ...), and fixed sampling
(`temperature 0, seed 42, top_k 1, top_p 1.0, max_tokens 200, cache_prompt
false`). One control-bad fixture (`91_bad_wrong_content`) has the same layout as
a golden fixture with WRONG text and declares which golden probe it
discriminates; another (`90_bad_blank`) is blank. The content shapes are large
text, shape counts, a login form, a list view, a table, a dialog, a dark theme,
small text and colour blocks. This is the right design; the gaps are that it
lives in one tool's repository, that consumers cannot extend it with their own
UI under a shared contract, and that nothing in canon makes a wrong answer
binding.

**What this is NOT (the §11.4.227 boundary).** §11.4.117 and §11.4.160 require a
self-validated golden-good / golden-bad analyzer for OCR/vision pipelines; they
do not specify the bank's contents, reproducibility, ownership, scoring
vocabulary or the disposition of a wrong answer. §11.4.245 requires the oracle
before the test; this anchor IS that oracle for models. §11.4.137 governs
subtitle content correctness, a different oracle.

**The mandate (ALL hold):**

**(A) OWNERSHIP AND LAYERING.** The BASE bank lives in the constitution
submodule beside the wrapper (`scripts/llm/golden/vision/<suite>/`), so every
consumer validates against the same content-addressed fixtures. A consuming
project adds a PROJECT bank (its own screens, rendered from its own build) under
the same schema. `llmctl`'s `vision-golden-v1` is the seed: it moves to — or is
consumed by suite content hash from — the constitution, never forked
byte-identically (§11.4.251).

**(B) KNOWN CONTENT, REPRODUCIBLY RENDERED.** Every golden image is produced by a
committed generator from committed inputs. Rebuilding it on any host yields the
recorded sha256, byte for byte; a fixture that cannot be rebuilt to its hash is
invalid. A PROJECT fixture rendered from an application pins the build
(content-addressed artifact, §11.4.264), the data fixture, the viewport/DPI,
locale, theme, fonts and the capture method, and records each.

**(C) MACHINE-READABLE EXPECTATIONS.** Each fixture carries: id, image path,
image sha256, role (`golden` or `control-bad`), a plain description of the
known content, and probes. Each probe carries its prompt and deterministic
checks from a closed vocabulary — `contains_all`, `contains_any`, `forbidden`,
`ordered`, `regex_all`, `regex_none`, `first_number` (with tolerance 0 unless
declared), `json_equals`, `exact_after_normalisation` — with the normalisation
declared once per suite. No check calls a model.

**(D) COVERAGE OF WHAT UI TESTING WILL ASK.** The base bank covers at least: text
at large and small sizes; text on dark and light themes; counts of objects;
colours; relative position (left/right/top/bottom); a form with labelled fields
and a button; a list; a table with headers; a modal dialog; an error banner; a
disabled versus enabled control; an empty state; non-Latin script (at least
Cyrillic); and a "no text" blank. A probe category a consumer's UI suite relies
on (ANCHOR-D) that the base bank lacks is added to the base or project bank
BEFORE the UI suite relies on it.

**(E) FLAGGED GOLDEN-BAD CONTROLS.** Every golden probe category has at least one
control-bad fixture that discriminates it: same layout, wrong content (or
absent element, or blank). The model MUST fail to report the golden content on
the control and MUST report the control's actual content where the probe asks
for it. A model that "reads" the golden answer off a control is hallucinating or
anchoring on the prompt; that is rc 1 for the whole validation.

**(F) A WRONG RESULT IS A DEFECT.** A golden probe that fails, or a control that
passes, is investigated per §11.4.102 and classified from a closed set:
`fixture-defect` (image does not show what the description says),
`expectation-defect` (the check is wrong for content that IS shown),
`prompt-defect`, `engine-defect`, `model-capability-gap`. Only the first three
change the bank, and each change carries a ground-truth record (§11.4.276(B))
and an independent review (§11.4.142). A `model-capability-gap` NEVER loosens an
expectation: the profile is recorded as not validated for that capability
(§11.4.254 capability matrix), and the consumer chooses a different profile or
declares the capability unsupported.

**(G) OTHER KINDS: KNOWN-ANSWER SUITES.** Chat and decision profiles: prompts with
single determinable answers and forbidden-answer checks. Coder profiles: tasks
whose output is executed against committed tests. Embedding profiles: fixed
text pairs with required similarity ORDER (not raw thresholds), plus a
dimension check. Each suite has controls in the same sense as (E).

**(H) THE BANK VALIDATES ITSELF.** A bank change runs (1) the rebuild-and-hash
check, (2) the schema check, (3) a judge self-test where canned correct answers
PASS every golden probe and canned wrong answers FAIL, and (4) a control-pairing
check that every golden category has a control.

**Honest boundary (§11.4.6).** A bank proves the model recognises THESE
contents. Real screens are richer; ANCHOR-D's per-platform seeded defects and
real-frame binding are what carry recognition from the bank to the product, and
a model may pass the bank yet misread a real screen — which is then a new
fixture, not an excuse.

**Classification: universal (§11.4.17)** — the consumer supplies its project
bank, build pin and capture method as DATA per §11.4.35.

**Composes** §11.4.6 / §11.4.66 / §11.4.102 / §11.4.107(10) / §11.4.117 /
§11.4.142 / §11.4.160 / §11.4.201 / §11.4.245 / §11.4.251 / §11.4.254 /
§11.4.264 / §11.4.276(B) / ANCHOR-A / ANCHOR-B / ANCHOR-D.

Propagation gate `CM-COVENANT-114-279-PROPAGATION` + recommended mechanism gates
`CM-GOLDEN-BANK-REPRODUCIBLE`, `CM-GOLDEN-BANK-CONTROLS` and
`CM-GOLDEN-BANK-NO-LOOSENING`. Paired §1.1 mutations: alter one pixel of a
golden PNG → reproducibility FAILs; delete the control for a category →
controls gate FAILs; widen a `contains_all` to drop a token with no
ground-truth record → no-loosening gate FAILs; make the judge call a model →
FAIL; strip the literal → propagation FAILs. Golden-FALSE: adding a NEW golden
fixture with its own control and generator input MUST NOT fire any gate.

**Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.279.

Non-compliance is a release blocker regardless of context. No escape hatch — no
`--hand-edited-golden`, `--no-controls`, `--llm-judge`, `--loosen-to-pass`,
`--model-is-close-enough` flag exists.

---

### §11.4.280 — Vision-eyed full-suite UI QA: every project with a UI on any platform runs HelixQA full suites over every screen, state, flow, use case and edge case, with a validated local vision model as the system's eyes reading REAL on-screen content, frame-bound verdicts, BLOCKED-never-PASS, a coverage ledger and a per-platform seeded defect (User mandate, 2026-10-12)

**Forensic anchor — operator mandate (2026-10-12), intent recorded verbatim:**
EVERY project with a UI on any platform / OS MUST run Helix QA full suites
covering all screens, pages, components, widgets, all flows, use cases and edge
cases, deterministically, with the vision model as the system's eyes
recognising REAL on-screen content, no bluff: frame/screenshot-bound verdicts,
BLOCKED never PASS when vision is unavailable, golden-good/bad self-validation,
mutation-paired; a screens × states × platforms ledger; release blocked on
missing or stale rows; a seeded defect per platform the suite must catch.

**Forensic FACTS (measured by the orchestrating session 2026-10-12/13; not
re-measured here).** (1) HelixQA's vision verdict engine had bluff paths: a step
PASSED on action success when vision errored or was absent; `vision_verify` was
decorative (its result did not decide the verdict); a verdict was not bound to
the frame it judged. A fix is in progress on the `submodules/qa` branch
`feature/vision-no-bluff` (the drafting agent confirmed on 2026-10-14 only that
this branch is the one checked out). (2) A reference consuming project with a
multi-platform UI (46 screens: web 16, desktop 6, setup wizard 10, Android 4,
Android TV 10) had screenshot assertions for only about 6–9 of them, and most of
its test-bank steps were TODO prose. A suite that is green while most screens
are prose is §11.4 PASS-bluff at fleet scale.

**What this is NOT (the §11.4.227 boundary).** §11.4.48/§11.4.49 require UI-driven
and dual-approach testing; §11.4.159/§11.4.160 require vision verification of
RECORDINGS; §11.4.117 is the pixel-oracle fallback when the hierarchy is blank;
§11.4.169 requires every test type; §11.4.219 requires a screen CATALOGUE (the
design contract). None requires a coverage ledger keyed by screen × state ×
platform that blocks release, a validated local model as the verdict-deciding
eye on EVERY UI assertion, or a seeded per-platform defect. This anchor adds
those.

**The mandate (ALL hold):**

**(A) SCOPE.** Every governed project that ships a user interface — web,
desktop, mobile, TV, embedded panel, setup wizard, and terminal UI (an
interactive full-screen TUI is a UI) — on every platform it ships. A
non-interactive command-line program is out of scope of this anchor (it is
covered by §11.4.169's other test types).

**(B) THE LEDGER.** A tracked `screens × states × platforms` ledger, derived from
the §11.4.219 screen catalogue / IA contract (never hand-enumerated where the IA
exists), one row per (surface, platform, screen-or-component, state) with:
flows that visit it; suite and test ids; last run id; verdict
(`PASS`/`FAIL`/`BLOCKED`/`UNCOVERED`); frame sha256 of the deciding capture;
ANCHOR-B validation record id; timestamp. States include at least default,
loading, empty, error, populated, disabled, focus/selected, and each theme.
A test step written as prose with no executable assertion counts as
`UNCOVERED`.

**(C) FRAME-BOUND, VISION-DECIDED VERDICTS.** Every UI assertion that claims what
the user sees is decided by: a capture taken AFTER the action settles, its
sha256, the expected-content specification written before the run
(§11.4.245, §11.4.159(J)), the validated vision model's response (hash), and
the deterministic judge of ANCHOR-C(C). The verdict record references the frame
by hash; a verdict without a frame is invalid. Action success (a click
returned, a navigation completed) NEVER substitutes for the vision verdict.
Where the platform exposes a structural tree (DOM, accessibility), it is used as
a SECOND oracle (§11.4.49); disagreement between the two is a finding, not a
tie-break.

**(D) BLOCKED, NEVER PASS.** If the vision model is absent, not validated
(ANCHOR-B rc ≠ 0), errors, times out, or returns unparseable output, the step
is `BLOCKED` (rc 2), and a suite with any BLOCKED row is not green. A
`vision_verify` step is always verdict-deciding; a decorative vision call is a
defect.

**(E) SESSION SELF-VALIDATION.** Each suite run starts with a preflight: the
wrapper's `require-validated` for the profile in use, then a golden-good and a
golden-bad frame from the ANCHOR-C bank plus one project golden pair (a known
screen and its control-bad twin), judged through the SAME pipeline the suite
uses. A preflight failure blocks the run.

**(F) FULL COVERAGE, DETERMINISTICALLY.** The suite covers every ledger row, every
flow and use case in the project's use-case list, and edge cases (empty and
maximum data, long and non-Latin strings, offline/error, permission denied,
resize/rotation where the platform has it). Runs are deterministic: fixed build
(§11.4.264), fixed data fixtures, fixed viewport/DPI/locale/theme, fixed
sampling; a flaky row is handled by §11.4.248, never by retry-to-green.

**(G) SEEDED DEFECT PER PLATFORM.** For every platform, a committed mutation build
(for example a wrong label, a missing control, a swapped theme colour, a
truncated list) MUST be caught by the suite with a FAIL naming the mutated row.
A seeded defect the suite does not catch makes the suite's PASS
untrustworthy for that platform, and the platform's rows are reported BLOCKED
until it is caught.

**(H) RELEASE GATE.** A release (§11.4.40) is blocked while any ledger row is
`FAIL`, `BLOCKED`, `UNCOVERED`, or STALE — older than the last change to that
surface, or older than the consumer-declared maximum age.

**Honest boundary (§11.4.6).** The vision model reads what the bank and the
preflight prove it can read; a new kind of content can still be misread, which
(G) and (E) are designed to surface rather than hide. Protected surfaces that
capture black (§11.4.112) are recorded as `BLOCKED` with that reason, never as
PASS. This anchor does not make manual QA (§11.4.185 / §11.4.238) unnecessary;
it moves discovery to automation.

**Classification: universal (§11.4.17)** — the consumer supplies its surfaces,
platforms, IA contract, use-case list, seeded-defect builds and maximum row age
as DATA per §11.4.35.

**Composes** §11.4.6 / §11.4.40 / §11.4.48 / §11.4.49 / §11.4.112 / §11.4.117 /
§11.4.143 / §11.4.159 / §11.4.160 / §11.4.163 / §11.4.169 / §11.4.201 /
§11.4.219 / §11.4.238 / §11.4.245 / §11.4.248 / §11.4.262 / §11.4.264 /
§11.4.266 / ANCHOR-A / ANCHOR-B / ANCHOR-C.

Propagation gate `CM-COVENANT-114-280-PROPAGATION` + recommended mechanism gates
`CM-UI-VISION-COVERAGE-LEDGER`, `CM-UI-VISION-VERDICT-NO-BLUFF` and
`CM-UI-VISION-SEEDED-DEFECT`. Paired §1.1 mutations: delete a ledger row that the
IA contract has → ledger gate FAILs; make a step PASS when the vision call
raises → no-bluff gate FAILs; remove the frame hash from a verdict → FAIL;
disable one platform's seeded-defect build or let it pass → seeded-defect gate
FAILs; strip the literal → propagation FAILs. Golden-FALSE: a project whose
every row is PASS with frames, fresh, preflight green and every seeded defect
caught MUST NOT fire any gate; a project that ships only a non-interactive CLI
MUST NOT be required to carry a ledger.

**Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.280.

Non-compliance is a release blocker regardless of context. No escape hatch — no
`--action-success-is-pass`, `--vision-optional`, `--prose-steps-count`,
`--sample-screens-suffice`, `--no-seeded-defect`, `--stale-rows-OK` flag exists.

---

### §11.4.281 — Vision / model-validation / UI-QA documentation and propagation travel in the SAME change: guides, manuals, FAQs, diagrams and exports for ANCHOR-A..D are updated with the change that alters behaviour, and consumers receive the rules through the post-update hook and templates (User mandate, 2026-10-12)

**Forensic anchor — operator mandate (2026-10-12), intent recorded verbatim:** docs
sync — user guides, manuals, FAQs, diagrams, schemes and graphs updated in the
same change (tied to §11.4.257 / §11.4.258 / §11.4.65); consumer propagation via
the post-update hook and templates.

**What this is NOT (the §11.4.227 boundary).** §11.4.257 / §11.4.258 / §11.4.65
already require manuals, diagrams and exports generally. This anchor names the
concrete artefacts the ANCHOR-A..D family must keep in step, makes their
staleness mechanically detectable, and names the propagation path.

**The mandate (ALL hold):**

**(A) THE DOC SET.** The constitution ships, beside the wrapper: a user guide
(how a consumer obtains, validates and uses a model through the wrapper); a
validation-record reference (every field of ANCHOR-B(A)); a golden-bank authoring
guide (ANCHOR-C, with the closed check vocabulary and the defect taxonomy); a
HelixQA vision-suite authoring guide (ANCHOR-D: ledger schema, frame binding,
preflight, seeded defects); an FAQ; and diagrams — data flow (consumer →
wrapper → `llmctl` → server → judge → record), the model state machine
(absent → downloaded → served → validating → validated / failed → stale), the
UI-step sequence (action → settle → capture → hash → vision → judge → verdict
→ ledger), and a coverage graph rendered from the ledger. Each is exported per
§11.4.65.

**(B) SAME CHANGE.** A change that alters the wrapper's interface, the record
schema, the check vocabulary, the ledger schema or a verdict rule updates the
affected documents and diagrams in the same commit. A consumer's own project
docs (its manual, its coverage graph) follow the same rule for its project bank
and ledger.

**(C) PROPAGATION.** `scripts/post_update_hook.sh` verifies, on every constitution
pull, that the consumer resolves the wrapper, that its ledger (when it has a UI)
parses against the current schema, and reports anchors ANCHOR-A..E missing from
its carriers. The project templates carry the pointer paragraph of
`03_carrier_snippets.md`. The four carriers are kept in lockstep (§11.4.157).

**Honest boundary (§11.4.6).** A staleness gate detects a doc that was not
touched by a behaviour-changing commit; it cannot prove the touched doc is
correct — that is the independent review's job (§11.4.142, §11.4.168).

**Classification: universal (§11.4.17).**

**Composes** §11.4.12 / §11.4.22 / §11.4.60 / §11.4.65 / §11.4.142 / §11.4.157 /
§11.4.164 / §11.4.168 / §11.4.257 / §11.4.258 / ANCHOR-A..D.

Propagation gate `CM-COVENANT-114-281-PROPAGATION` + recommended mechanism gate
`CM-VISION-FAMILY-DOCS-SYNC`. Paired §1.1 mutation: change the record schema
without touching the reference doc → FAIL; strip the literal → propagation
FAILs. Golden-FALSE: a commit that changes only a test fixture's comment MUST
NOT require a doc change.

**Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.281.

Non-compliance is a release blocker regardless of context. No escape hatch — no
`--docs-later`, `--diagram-optional`, `--no-export`, `--skip-post-update-check`
flag exists.
