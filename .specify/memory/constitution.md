<!--
SYNC IMPACT REPORT — .specify/memory/constitution.md
====================================================
Version change: 1.1.0 → 1.2.0  (MINOR)

Bump rationale: four principles added, no principle removed or redefined. The
additions are materially new rules rather than wording, so not PATCH; nothing is
backward-incompatible, so not MAJOR.

Added principles:
  + "Authored Curriculum"    — a published area is authored, never auto-mined vocabulary
  + "Published Means Served" — never advertise what the API will refuse to serve
  + "Derived Presentation"   — theme comes from seeded derivation; contrast floors are gates
  + "Standalone Cloneable"   — every owned module builds and runs from a fresh clone

Why these four, and why now. Each encodes a defect MEASURED in this repository on
2026-09-07, not an aspiration:

  ! 814 of 819 published knowledge areas were single mined transcript terms —
    "Bazillion", "Sillier", "Blinks". Only 32 of 814 titles (3.9%) contained any
    AI/ML term, and raising the evidence floor made it WORSE (0 of 36 at floor 2,
    0 of 8 at floor 3). The miner emits every unlinked term by explicit design;
    nothing selected between it and the API.
  ! The list route served 819 areas while the detail route refused 817 with
    `area_not_published` — 2 publication reviews existed for 819 areas.
  ! The token derivation was widened (hue span 120° → 150–180°) and NOTHING
    regenerated the consuming app's stylesheets, so the measured improvement was
    invisible to every user.
  ! `workshop` did not build outside the umbrella at all: five dependencies
    resolved through relative `replace` paths escaping the repository, declared
    nowhere — and `setup.sh` printed a remedy that could not work.

Factual corrections, called out rather than silently applied:
  ! fleet was "8 submodules declared … six owned" → measured 2026-09-07:
    13 declared in `.gitmodules`, 12 recorded in `helix-deps.yaml`, 11 owned
  ! `submodules/curriculum-kit` exists as a PLAIN DIRECTORY (82 tracked files),
    not a gitlink; wiring it as a submodule is an unperformed operator step

Templates requiring updates — verified by reading, not assumed:
  ✅ .specify/extensions/superspec/templates/plan-template.md — its Constitution
     Check is a table of generic `[Principle N from constitution]` rows, so the
     four new principles slot in with no template edit.
  ✅ .specify/templates/plan-template.md — Constitution Check is the
     principle-agnostic placeholder `[Gates determined based on constitution file]`.
  ✅ .specify/templates/spec-template.md — no principle-specific section.
  ✅ .specify/templates/tasks-template.md — task categories are principle-agnostic.

Deferred: none. No unexplained placeholder tokens remain.
-->
---
version: 1.1.0
ratified: '2026-08-26'
last_updated: '2026-08-31'
---

# vasic Constitution

This project constitution EXTENDS the universal Helix Constitution mounted at
`submodules/constitution/`. It never weakens or overrides an inherited clause — where the two
disagree, the submodule wins. Measured at pin `90297902`: **11,700 lines, 252 anchors**.

## Core Principles

### Evidence-Based Claims

Every assertion MUST be backed by verifiable evidence. Never guess, assume, or fabricate.
Constitution §11.4 applies — no bluffing, no speculation disguised as fact.

A claim measured on one member of a set is NOT a claim about the set. Enumerate the set from its
authoritative source rather than from a hand-written list; a hardcoded list silently goes stale
the moment the set grows. When a number is reported it MUST be a count of things that were
listed, never a line count from a text search.

When a previously stated figure turns out to be wrong, it MUST be withdrawn explicitly rather
than quietly replaced, and the reason recorded.

### Honest Instruments

A check that cannot run MUST report that it could not run. It MUST NOT report success, and it
MUST NOT report failure. Three states are mandatory and distinct:

- `0` — the condition was checked and holds
- `1` — the condition was checked and is violated
- `2` — the condition could NOT be checked

Collapsing state 2 into state 1 makes a broken tool accuse a healthy codebase. Collapsing it into
state 0 makes a broken tool certify code nobody inspected. Both are release blockers. A missing
credential, an unreachable service, a saturated backend, or a crashed helper are all state 2.

Rationale: this exact conflation has been found and fixed four separate times in this repository
— in the index doctor's exit contract, in the constitution sweep's step-1 handling, in the deploy
script's live-link validator, and in the governance cascade verifier. It is the most frequently
recurring defect class here, which is why it is a principle rather than a style note.

### Governance Fidelity

All governance carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) MUST stay in lockstep
— byte-identical below their per-agent header. The constitution submodule is the single source of
truth; no carrier may weaken or override a universal clause.

Every owned submodule MUST carry the four carriers, each opening with a real, non-fenced
`## INHERITED FROM ` pointer heading (§11.4.35 invariant 6). The fleet is DERIVED from
`.gitmodules`, never hardcoded. Measured 2026-09-07: **13 submodules are declared** and
`helix-deps.yaml` records **12** — `submodules/constitution` (the governance source),
`submodules/superspec` (third-party, out of scope per §11.4.156(C)), and **11 owned**:
`milosvasic.ru`, `vasic.digital`, `design-toolkit`, `ai_interviewing`, `monetization`,
`workshop`, `submodules/containers`, `submodules/LLMProvider`, `submodules/RAG`,
`submodules/verdict`, `submodules/passage`. The earlier "8 declared, six owned" figure is
WITHDRAWN as measured false, not silently replaced.

`submodules/curriculum-kit` is present as a PLAIN DIRECTORY of 82 tracked files, NOT a gitlink.
It is therefore outside the cascade until an operator creates its upstream and runs
`git submodule add`. Counting it as owned would be a claim the tree does not support.

### Isolation by Default

Mutation-paired gates catch regressions. Every new gate MUST have a paired mutation proving it
FAILS when the thing it guards is broken. A gate that has never been observed failing is not
known to work.

An assertion that greps a file for a string is not a test — it checks that code *mentions*
something, not that it *does* it. Such an assertion stays green while the behaviour it claims to
cover is deleted. Assertions MUST execute the behaviour and check the observable result.

A mutation proof that exercises only sandboxed copies can go green over an instrument that cannot
start at all; proofs MUST include at least one case that runs the real entry point end to end.

No naked writes — every destructive operation requires a hardlinked backup first (§9).

### Comprehensive Documentation

`CONTINUATION.md` exists at the repository root and MUST be updated in the same commit as any
non-trivial state change (§12.10). `scripts/continuation-check.sh` enforces this mechanically and
is three-valued per **Honest Instruments**.

Every architectural decision is recorded. Honest boundaries — gaps are stated openly, never
hidden. A document that states a status MUST name the command that re-derives it, so the reader
can tell a current fact from a stale one.

### Environment Adaptability

No file in this repository may freeze an assumption about the machine it runs on. Paths, service
managers, package layouts, CPU and memory limits, model names, vector dimensions, endpoints,
ports, container runtimes and GPU vendors MUST be DERIVED at run time, with an environment
variable available to override the derivation when detection is wrong.

A tuned value MUST be computed from measured host facts and MUST print its inputs so the
arithmetic can be audited. A recommendation that returns the same number regardless of the host
has failed this principle even when the number happens to be right.

`scripts/audit-environment-assumptions.sh` enforces this class. Its allow-list entries each carry
a `REASON:` or `BASELINE:` comment; a baseline is a recorded debt, never a justification, and
baselined files are printed on every clean run so the tree can never go quietly green over known
breakage.

Rationale: this repository has been bitten repeatedly — a hardcoded macOS path in a deploy script
that pushes to production, a distro-specific service config path, an i915-only log pattern that
would report "0 faults" forever on AMD hardware, and a GNU-vs-`ugrep` difference that silently
broke a test assertion on this very host.

### Authored Curriculum

A published knowledge area MUST be an AUTHORED subject with a stated scope, not a token a miner
happened to isolate. Extraction MAY propose candidates; it MUST NOT publish them.

Three rules follow, and each is testable:

- An area MUST carry a title, a summary and tags that a reader recognises as a SUBJECT. A single
  word lifted from a transcript is not a subject.
- An area MUST be ON-DOMAIN for the curriculum that publishes it. A curriculum about AI and IT
  publishes AI and IT areas; relevance MUST be measured and reported, not assumed from the fact
  that the words appeared in the source material.
- An area MUST carry the material that makes it teachable — lessons, an end-of-area assessment,
  and the materials the lessons cite — or it MUST NOT be published. An area with nothing behind
  it is a promise the interface cannot keep.

Rationale, measured 2026-09-07: 814 of 819 published areas were single mined terms — "Bazillion",
"Sillier", "Blinks", "Googling". Only 32 of 814 titles (3.9%) contained any AI/ML term, and 778 of
814 rested on exactly one passage. `derive.py:propose_areas` emits every unlinked term as its own
area by explicit design, commented `E1: propose, don't discard` — correct for a MINER, and exactly
why publishing its raw output is wrong. Raising the evidence floor made relevance WORSE, not
better (0 of 36 at floor 2), which proves the defect is not a threshold and cannot be tuned away.

The reference implementation is `ai_interviewing`: one authored document per area, numbered, each
paired with a question bank at the same number. Fixing this by improving the miner is forbidden;
the miner is not the problem.

### Published Means Served

An API MUST NOT advertise a resource it will refuse to serve. If a listing includes an item, the
item's own route MUST return it — or the listing MUST exclude it and say, in its own payload, how
many were withheld and why.

A refusal MUST carry enough for the caller to render something honest: at minimum the resource's
name and the reason. A page that can show a name and shows an opaque identifier instead has
failed this principle even when the underlying gate is correct.

Rationale, measured 2026-09-07: `/api/areas` served 819 areas while `/api/areas/{id}` refused 817
of them with `area_not_published`, because 2 publication-review records existed for 819 areas. The
gate was right and the contract was broken — the interface advertised 819 subjects of which it
would open 2, and rendered a raw ULID for the rest. Both halves of a gated resource MUST agree.

### Derived Presentation

Visual identity MUST be DERIVED from the seeded token pipeline, never hand-painted into a
consuming application. A colour written directly into a consumer's stylesheet defeats the
derivation for every other consumer and every other seed.

- A widened or corrected token set is NOT delivered until a consumer has regenerated from it and
  the change is measurable in what that consumer SERVES. A token-level measurement is evidence
  about tokens, and MUST NOT be reported as evidence about the interface.
- Accessibility floors are GATES. When a derived colour fails a contrast floor, the DERIVATION
  moves; the floor never does.
- A palette gate MUST measure a property a human would recognise as the complaint — hue spread,
  chromatic share — and MUST be provable against the artefact that motivated it.

Rationale, measured 2026-09-07: the derivation was widened from 3 hue bins over 120° to 4–5 bins
over 150–180°, and the consuming application's stylesheets were never regenerated, so the
improvement reached no user. Separately, two supposedly distinct brands were shipping the
IDENTICAL 3-bin, 120° structure in both themes — a uniqueness claim the tokens did not support.

### Standalone Cloneable

Every owned module MUST be cloneable, buildable and runnable on its own, outside this umbrella. A
module that only works because a parent checkout happens to be present is not a module.

- Every dependency MUST be DECLARED inside the module — in its own manifest, its own `.gitmodules`,
  or its own bootstrap — never resolved by a relative path that escapes the repository undeclared.
- A remedy printed to an operator MUST be runnable in the context that printed it. A setup script
  that emits an impossible command is worse than one that emits none, because it sends the reader
  after a fault that does not exist.
- A module MUST ship a repeatable standalone check with a paired mutation, so cloneability cannot
  regress silently.

Rationale, measured 2026-09-07 by CLONING both modules rather than inspecting them: `workshop` did
not build at all — five dependencies resolved through relative `replace` paths walking three
levels out of the repository, declared nowhere — and its `setup.sh` told the operator to run
`git submodule update --init` for a path that is not a submodule, then misreported the resulting
failure as a network or credentials problem. A fresh clone also came up serving an EMPTY corpus,
because the registry path was derived from a volume nothing in the repository populates.
Inspection reports what a repository DECLARES; only a clone reports what it DELIVERS.

### Source Is Not Served

**A measurement of SOURCE is not evidence about the SERVED product, and MUST
NEVER be reported as one.** Every claim about behaviour MUST state which
population it measured: the artefacts on disk, the process in memory, or the
running product on the wire.

**Rationale — this is not a hypothetical.** It occurred FOUR times in a single
day, in four disguises:

1. A palette gate read design-token files and its result was reported as a fact
   about the interface. Nothing had regenerated the served stylesheets.
2. A build identifier was computed over the served directory after a `cp -a`
   merged rather than replaced, so the hash covered an orphaned stylesheet the
   page never loads. The identifier did not describe what was served, inside the
   very instrument written to prove that distinction.
3. A gate suite was verified in-process and reported as working. The running
   container held a binary four hours older than the code under test.
4. A specification's own baseline row recorded "30 areas with an assessment, 224
   questions" — a true reading of the authored catalog on disk — while the
   running server served 14 and 116. Both measurements were correct. Only one
   described the product.

**The rule is symmetric.** An in-process pass is a legitimate result and MUST be
labelled as one; it is not a lesser measurement, it is a measurement of a
different thing. `rm -rf` before copy, never `cp -a` into an existing directory.

### A Snapshot Licenses Only Itself

**A process holding a cached copy of external state MUST NOT assert a DETERMINED
NEGATIVE about that state once the copy may be stale.** It MUST detect staleness
and return could-not-determine, naming what changed.

**Rationale.** A server read its content catalog once at start-up — deliberately,
and documented. It then answered *"this area's learning catalog carries no
end-of-area test"* — a claim about the **directory** — from a snapshot taken
hours earlier. Thirteen authored question banks holding eighty-nine questions had
been written after the process started. The discriminating condition was neither
the areas nor the banks: it was **time**.

The interface then rendered that as *"No test has been written for this area yet
— the server answered and there is genuinely none."* **Confident prose asserting
the opposite of the truth.** An unexplained gap invites investigation; a
confident wrong explanation closes it. A false negative delivered with a stated
reason is worse than a silent one.

**The remedy is not to reload constantly.** It is to know what the snapshot
licenses. Positive assertions about held data remain valid; negative assertions
about the world do not. Distinguish "no source configured" from "source unread"
from "source changed" — collapsing them turns a known state into a fault.

### A Gate's Population Is Part of Its Claim

**The SET a check covers MUST be justified independently of the count it
produces, and stated in its output.** A change to a population MUST be defensible
before its effect on the result is known.

**Rationale.** Three defects in one day were instruments pointed at the wrong
set, not instruments computing wrongly — and every one reported cleanly:

- A link checker scanned one directory and not its sibling. The unchecked
  directory had no checker at all, so its dangling links were invisible.
- A hue gate never sampled the elements it existed to measure: its non-text rows
  graded the ground *behind* an indicator, so a coloured chip could not
  contribute by construction. Correct for contrast, wrong for hue.
- A reachability gate checked route mountedness against ONE fixture area and
  never checked bank-to-area reachability across the population. Eighty-nine
  questions were unreachable while it passed.

**No amount of rigour inside a check catches a check aimed at the wrong set.**
Therefore: an absence assertion MUST first establish its subject set is
non-empty; and when a population is widened, the justification MUST be written
down BEFORE the new count is read. If you find yourself adding a case and then
checking whether the number moved, you are tuning to a result.

### An Exemption Is a Claim That Can Expire

**Every exemption, baseline row, waiver and declared condition is a CLAIM ABOUT A
FILE at a moment in time. Changing the file can falsify it silently.** A declared
condition MUST carry its evidence, its reason, and who may lift it — and MUST be
re-validated whenever its subject changes.

**Rationale.** A check registry exempted a watcher script with the reason *"it
schedules a mutator; it judges nothing."* That was true when written. The script
later gained a three-valued verdict of its own, and the exemption became false
while continuing to look reviewed. **An exemption whose justification has
expired is worse than no exemption**, because it carries the authority of a
decision nobody is making any more.

Corollary, measured the same day: a baseline is recorded DEBT, not a
justification, and MUST be re-derived before it is counted. A row fixed upstream
and never pruned overstates debt exactly as a stale exemption understates it.

### A Screen's Precision Is Not Its Recall

**A check's finding is evidence about the rows it FLAGS and evidence about
nothing else.** A clean row is not a cleared row unless the check's recall has
been measured. Any claim of the form "N defects exist" derived from a screen MUST
state the screen's recall or declare it UNKNOWN.

**Rationale.** An anchor screen was measured at **98% precision** — of 52 rows it
flagged, 51 were real defects. That number is excellent and it licensed nothing.
Reading the 182 rows it did NOT flag found **121 defective, 66.5%**, putting its
recall at **≈29.5%**: it missed seven defective rows in ten. Had the flagged rows
been repaired and the screen then re-run to green, the artifact would have
carried 121 known-reachable defects under a passing gate.

Precision is cheap to measure and recall is expensive, which is exactly why
recall goes unmeasured and why the resulting confidence is misplaced. **A screen
that has never been run against an exhaustively-read sample has no known recall,
and its green is a statement about its own appetite, not about the population.**

### A Gate Cannot See a Displacement Larger Than Its Window

**A check that compares an item to its NEIGHBOURS detects local error and is
BLIND BY CONSTRUCTION to global error.** Any instrument with a bounded comparison
window MUST state that bound in its output, and MUST NOT be read as evidence
about displacement beyond it.

**Rationale.** 44 questions cited passages from an entirely wrong corpus — testing
one system's API contract while anchored to unrelated teaching material — and
every one scored **perfectly clean**. The screen compared each citation against
its adjacent passages; when an anchor is globally wrong, no neighbour helps
either, so coverage and best-alternative are both zero and the delta is zero.
**Maximum cleanliness and maximum wrongness produced the same number.**

No tuning could have reached these. The defect was not that the threshold was
wrong; it was that the question being asked — *"is a nearer passage better?"* —
cannot express *"is this the right corpus?"*. Therefore a bounded-window check
MUST NOT be the only instrument over a population, and its output MUST say what
it cannot see.

### A Rule Enforced by Nothing Is Not a Rule

**A constraint that no instrument checks is a comment, and it MUST NOT be
recorded in a form that implies it was verified.** Every stated rule MUST name
the check that enforces it, or state explicitly that none exists.

**Rationale.** A quality constraint forbidding citations outside a "verified
evidence pack" propagated verbatim into 37 files. Measured: there is **no pack
producer and no pack artefact** — the pack was derived by reading a document; and
**no gate ever checked membership** — the bank verifier's eight assertions cover
resolution, redaction and path, and never pack membership.

The constraint was therefore unenforced, unenforceable, and **guaranteed the
defect it existed to prevent**: the packs certified isolated transcript lines
while the sentences that carry meaning run across them, so a file obeying its own
rule could not cite its own evidence. 139 of 153 correct citations added during
repair lay outside the pack. **An unenforced rule does not fail safe — it
propagates by copying, accumulates authority by repetition, and is discovered
only when someone measures the thing it governs.**

### Reproduce Before Repairing

**A repair MUST begin by reproducing the defect and confirming its MECHANISM, not
merely its symptom.** Where a brief asserts a cause, the assignee MUST verify that
cause and report a contradiction rather than implement against it.

**Rationale.** Seven times in one session the reported symptom was real and the
stated mechanism was wrong. Fixing the stated mechanism would have shipped a
green gate over an unfixed product in at least three:

- Shuffling choice order would not have fixed an answer-shape leak: the choice
  *identifier* encoded the key, so the key would have moved with its label
  attached.
- A "missing withholding call" on a graded path was not missing — the type in use
  carries no citations field, so the protection is INAPPLICABLE. Wiring it would
  have installed an inoperative gate reading green forever.
- A root cause given as "re-cut boundaries" addressed under half the cases and
  targeted an artefact that does not exist.

Each false mechanism was a plausible story that fit the visible evidence. What
distinguished them was measurement, never reasoning. **An instruction to
implement gets a thing built; an instruction to verify-then-implement gets it
built or gets the brief corrected.**

### Never Mutate Shared State With a Whole-Tree Command

**No actor may run a command whose effect is unbounded across a working tree that
other actors are writing.** Every write MUST re-read its target immediately
beforehand and MUST touch only the fields it owns.

**Rationale.** `git stash -u` on a shared tree reverted **125 tracked files** to
HEAD in one command; HEAD moved concurrently and the paired `git stash pop`
reapplied **zero**. Recovery required merging two incomplete sources — rebalanced
fields from the stash, repaired fields from disk — because neither held the whole
truth.

The compounding failure is subtler and MUST be designed against: **an actor that
verifies its write against the copy it read cannot detect what changed
underneath it.** The destroying actor's own check reported "no fields changed
outside my lane" and was TRUE, because it compared against its own stale
snapshot. Therefore a post-write verification MUST diff against the file's
CURRENT content, never against the copy the writer began from. A regeneration
step with no narrow mode is this hazard in permanent form.

### A Statistic a Fix Can Overshoot Requires a Two-Sided Check

**Where a gate drives a measured statistic toward a target, the check MUST bound
it in BOTH directions and MUST prove both arms.** A one-sided check on a
correctable statistic actively selects for its inverse.

**Rationale.** An assessment was measured at **100% "the correct answer is the
longest option"** against a ~25% chance baseline. A one-sided gate would have
rewarded driving that to zero — installing the inverse tell, where eliminating
the longest option becomes a free correct guess. The shipped gate bounds the
statistic within a band around chance and proves both directions: one mutation
seeds always-longest, another seeds never-longest, and both must fail.

The same reasoning applies wherever a fix is scored by the metric it moves.
**A metric optimised against becomes a target, and the cheapest way to satisfy a
one-sided bound is usually to overshoot it.** A paired control proving the gate
still PASSES a legitimate population is therefore mandatory, so that "catches the
defect" is proved separately from "rejects everything".

### Quality Over Speed

60% RAM cap on heavy work. TDD where possible. Lint and typecheck before claiming done. No
shortcuts that compromise integrity.

Never edit a shell script while it is executing — bash reads scripts lazily and a live edit makes
the running shell execute garbage. Never commit while another agent is writing; a blind
`git add .` has already been caught about to roll back three submodule pins and to re-introduce a
cyclic gitlink that had been deliberately removed.

## Project Structure

The vasic umbrella monorepo owns two personal/portfolio sites, a curriculum module, and shared
tooling:

- **vasic.digital/** — committed static HTML served as-is (no build step)
- **milosvasic.ru/** — Jekyll source; rendered `_site/` is git-ignored; self-publishes on push
  via `.github/workflows/pages.yml` (ACTIVE, do not disable)
- **workshop/** — workshop curriculum; chapter recordings stored as size-bounded split parts
- **ai_interviewing/** — curriculum reference implementation: Go backend + Angular frontend,
  run as a native binary (`platform/bin/aicur`). It defines **no containers**.
- **_tools/gen/** — Go generator rendering localized pages for both sites
- **design-system/** — shared per-brand tokens and component CSS
- **_tests/** — Playwright plus self-validating harness
- **_content/** — English source; `_content_<lang>/` siblings for translations
- **submodules/constitution/** — the universal constitution (see measurement above)

Toolchains, measured on this host: Go 1.26.2, Node 22.19.0, npm 10.9.3, Ruby 3.3.8,
Python 3.14.6, ffmpeg/ffprobe 7.0.2, podman + podman-compose (**docker is absent**),
poppler-utils, tesseract-ocr.

## CI/CD Policy

Remote CI is disabled at the umbrella root per §11.4.156. `.github/workflows/ci.yml` is renamed
to `ci.yml.disabled`; enforcement is a local pre-push hook:

```
bash scripts/pre-push-gates.sh --install
```

The hook MUST be installed on fresh clones — `.git/hooks/` is not tracked by git, so a fresh
clone has zero enforcement until that command is run, and `git push --no-verify` bypasses it.
This cost is stated plainly rather than buried.

**milosvasic.ru** keeps its active deploy workflow (`pages.yml`) as a **documented deviation**
for production uptime. It is NOT an override — §11.4.156 forbids overrides ("No escape hatch"),
and it must never be written up as one. Verified basis: the GitHub Pages API reports
`build_type: "workflow"`, making that workflow the sole publish path.

**vasic.digital** is non-compliant at the **provider** level with no file-level remedy: it
triggers `pages build and deployment` runs on every push while containing zero workflow files.

File-level disabling cannot reach provider-side settings. Their CURRENT status is measured on
demand by `scripts/verify-provider-ci.sh`, not asserted here.

**No new CI may be added.** Introducing an active workflow is a release blocker.

## Local Gate Suite

`scripts/pre-push-gates.sh` registers 8 gates. A SKIP is never a PASS; `PREPUSH_STRICT=1`
converts skips to failures for release use.

| ID | Gate |
|----|------|
| E  | §11.4.156(E) — no active root CI config tracked |
| 0  | hardcoded path audit |
| 1  | Go unit tests (`_tools/gen`) |
| 2  | hardcoding audit (builds the Go generator) |
| 3  | HelixTranslate reproducibility self-test |
| 4  | portfolio §1.1 data-integrity self-validation |
| 5  | harness self-validation (§11.4.170 visual + §11.4.168 export) |
| 6  | Playwright chromium, excluding the all-language crawl |

## Verification Scripts

Governance and adaptability instruments. Each is three-valued per **Honest Instruments**.

| Script | Verifies |
|---|---|
| `scripts/verify-all-constitution-rules.sh` | full constitution gate sweep |
| `scripts/verify-governance-cascade.sh` | §11.4.32 step 1 — carriers cascade to every owned submodule |
| `scripts/continuation-check.sh` | CONTINUATION.md has not gone stale (§12.10) |
| `scripts/audit-hardcoded-paths.sh` | no machine-specific absolute paths |
| `scripts/audit-environment-assumptions.sh` | no frozen host assumptions |
| `scripts/verify-provider-ci.sh` | provider-side CI triggers that file checks cannot see |
| `scripts/ollama-tune.sh` | local inference concurrency, derived from host facts |
| `scripts/lumen-index-doctor.sh` | semantic index integrity |

## Testing Strategy

Run the full local suite via `bash scripts/pre-push-gates.sh`. The individual commands:

```bash
cd _tools/gen && go test ./... && cd -        # Go unit tests (generator)
bash _tools/audit-hardcoding.sh               # hardcoding audit
bash _tools/translate/reproducibility-selftest.sh
bash _tools/portfolio/self-validate.sh
bash _tests/run-harness-selfvalidation.sh     # harness self-validation
```

Playwright (chromium) requires `npm ci` and `npx playwright install chromium` inside `_tests/`,
plus a built `milosvasic.ru/_site`.

## Deploys

Driven by `bash _tools/deploy-langs.sh`. Regenerates EN plus every complete language into both
site submodules, commits and pushes each site only when something changed, then validates live
sites. `--dry-run` previews without committing.

It stages an explicit path list rather than everything, and ABORTS when unrelated changes are
present, so a deploy cannot sweep unrelated work into a production commit. Its live validator
distinguishes "found broken links" from "could not run the validator" per **Honest Instruments**.

## Governance

**Authority.** The universal constitution in `submodules/constitution/` is authoritative for
every topic. This document extends it with project-specific facts and discipline. Any conflict
resolves in favour of the submodule.

**Amendment procedure.** Amendments are made by running `/speckit-constitution`, which MUST:
re-measure every factual claim before restating it; record a Sync Impact Report at the top of
this file; propagate consequences to the Spec Kit templates and runtime guidance docs; and leave
no unexplained placeholder tokens. A factual correction MUST be called out in the report rather
than silently applied.

**Versioning policy.** Semantic versioning of governance:

- **MAJOR** — a principle is removed, or redefined in a backward-incompatible way.
- **MINOR** — a principle is added, or guidance is materially expanded.
- **PATCH** — clarifications, wording, typo and factual corrections that change no rule.

**Compliance review.** The local gate suite is the enforcement point; there is no server-side
check. Before a release or a tag, run the full sweep plus the verification scripts above, and
record the result. An unrunnable check is reported as such — never as a pass. Claims of
compliance require the command output that demonstrates it.

**Version**: 1.4.0 | **Ratified**: 2026-08-26 | **Last Amended**: 2026-09-08

Ratification date is DERIVED, not asserted: `git log --reverse --format=%cs --
.specify/memory/constitution.md` returns 2026-08-26, the first commit that
introduced this file. Re-derive it rather than trusting this line.
