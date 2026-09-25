<!--
SYNC IMPACT REPORT — .specify/memory/constitution.md (temporary review scratch)
Version change: 1.4.0 -> 1.5.0 (MINOR: principles added and guidance materially expanded; none
removed or redefined). The prior file carried three disagreeing version labels (front-matter
1.1.0, report 1.1.0->1.2.0, footer 1.4.0); all now read 1.5.0.
Added principles: A Restart Runs What Was Built; A Capability With Measured Harm Ships Off;
Non-Readable Is Indistinguishable From Nonexistent; Security Headers Come From the Served Bytes;
A Cache in Front of a Filtered Read Re-Runs the Filters; The Content Boundary Is a Standing
Invariant; Stage the Pointer and Its Manifest Together; A Decision, Once Executed, Updates Its
Carriers; Shell Idioms Must Survive pipefail; Shared-Tree Discipline Is Wider Than stash.
Changed sections: Governance Fidelity (fleet roster re-derived), Project Structure and
toolchains (re-measured), Verification Scripts (six added), Governance (push/integration and
independent-review paragraphs added; footer).
WITHDRAWN figures: "pin 90297902, 11,700 lines, 252 anchors" -> f8afb98ab0eb, 11,894 / 256;
"13 declared, 11 owned" -> 22 declared, 20 owned; curriculum-kit "plain directory" -> gitlink;
toolchain versions (Go 1.26.2/Node 22/ffmpeg 7.0.2 etc.) -> measured 2026-09-25 values.
Templates: .specify/templates/*.md have principle-agnostic Constitution Checks — no edit needed.
Deferred: none. Unverified items are marked UNCONFIRMED in the text where they occur.
-->
---
version: 1.5.0
ratified: '2026-08-26'
last_updated: '2026-09-25'
---

# vasic Constitution

This project constitution EXTENDS the universal Helix Constitution mounted at
`submodules/constitution/`. It never weakens or overrides an inherited clause — where the two
disagree, the submodule wins. Measured 2026-09-25 at pin `f8afb98ab0eb`: **11,894 lines, 256 `### §`
anchors** (`Constitution.md` blob `55b787e431e1`, 1,847,001 bytes, sha256 `e764f149a458…`). Canon
also carries anchors in a bold-opener form that a `### §` count omits — the bare count is a floor,
not the census. Re-derive rather than trusting these figures: the pin moves, and recent moves have
changed
the corpus.

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
`.gitmodules` and `helix-deps.yaml`, never hardcoded. Measured 2026-09-25: **22 gitlinks are
declared**, `helix-deps.yaml` records **21**, and `scripts/verify-governance-cascade.sh` (C1)
classifies them from evidence as **20 owned, 1 governance source (`submodules/constitution`) and
1 third-party (`submodules/superspec`, out of scope per §11.4.156(C))**. Every earlier roster in
this file — "8 declared, six owned", then "13 declared, 11 owned" — is WITHDRAWN as measured
false, not silently replaced, and `submodules/curriculum-kit` is a gitlink, not the plain
directory a previous revision recorded. Re-derive the roster with:

```
git config -f .gitmodules --get-regexp 'submodule\..*\.path'
bash scripts/verify-governance-cascade.sh
```

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

### Shared-Tree Discipline Is Wider Than `stash`

The rule above is not about one command. On a tree other actors write, `git checkout -- <path>`,
`git restore`, `git stash`, `git clean` and a blind `git add -A`/`git add .` are all unbounded
across the tree. Measured: `git checkout --` destroyed +173/-44 lines of another agent's work
(`9b7cf6a`); `commit_fully`'s `git add -A` swept a planted mutation seed into shipped source
(`3623e05`); `CONTINUATION.md` was wiped by a concurrent write (`7bda6e3`). Therefore: stage
EXPLICIT paths; run a paired mutation on a throwaway COPY with trap-restore, never on shipped
source; commit handoff state early; and when a commit-time stash is unavoidable, isolate by
pathspec and confirm the pop restored what the stash held. The `commit` wrapper runs `git add .`,
so `.gitignore` MUST be accurate first and a dirty submodule MUST be reviewed before the wrapper
runs. The PreToolUse guard (`scripts/verify-pretooluse-guard.sh`) blocks force-push, `--no-verify`,
privilege escalation and host-power commands; it was measured 2026-09-25 NOT to block the commands
above (`checkout --`, `restore`, `stash`,
`clean -fd`, `add -A` all returned rc 0; `push --force` returned rc 2), so this rule is enforced by
discipline and review only.

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

### A Restart Runs What Was Built

**A service start, restart or deploy MUST refuse to run a stale or dirty-tree build, and the
artifact it runs MUST carry a stamp naming the source it was built from.** A restart that never
rebuilds is a redeploy of the past.

Rationale, measured: `workshop`'s `start.sh` built the server only when the binary was missing and
`restart.sh` never rebuilt, so a "restart" launched a binary days older than the source under test
(workshop `185fb15`; the serving container ran an 18-hour-old binary in umbrella `738fbf1`). The
guard is
`ensure_fresh_server` / `prepare_fresh_server` / `commit_prepared_server`, refusing a dirty
input tree (including `replace`-module directories, embed assets and hidden git state) and stamping
`build=<sha>-<utc> dirty=<bool>` into `/api/health`. The override
(`WORKSHOP_SKIP_SERVER_FRESHNESS`) is permitted only for throwaway `workshop-oomprobe-*` projects.
`ai_interviewing`'s `platform/scripts/start.sh` still has the original `[ -x "$BIN" ] || build.sh`
shape; that gap is recorded here, not closed.

A prover or test that runs a real start script MUST NOT be able to replace a live, mounted
binary: it MUST hash the live artifact before and after each case, abort on the first change, and
use throwaway containers only (workshop `prove-oomd-protection.sh`, tripwire cases). The live
binary was swapped by a prover twice in one day. The build id from the health endpoint MUST be
quoted in every QA note.

### A Capability With Measured Harm Ships Off

**A capability whose measured error rate violates a stated success criterion MUST default to OFF,
and its default MUST be enforced by a gate, not by a comment.** Turning it on is an operator
decision that cites the measurement.

Rationale, measured 2026-09-24/25 on generation 15 (57 questions x 3 repeats, Wilson 95%): the
workshop answering funnel answered 14/72 = 19.4% (12-30%) of answerable questions and fabricated
4/87 = 4.6% (2-11%) of unanswerable ones, so SC-010/SC-094 (spec 001: declines 100% of unanswerable
questions and fabricates none) is UNMET. Answering was switched ON on 2026-09-24 and OFF the next
day; `calibrated: true`
was found to mean only `MinScore>0`. The compose file now defaults answering to `none` while the
embedding pair stays wired, and gate G29 (`verify-compose-answering-consistency.sh`) requires the
file's claims to equal its rendered flags, an ON default to cite an evidence path, and no
half-set opt-in. Evaluation tooling MUST run on a scratch server with a private index copy and
exit 2 when the capability is not enabled. An evaluation artefact MUST NOT be indexed into the
corpus it evaluates (the benchmark tables and a carrier are currently indexed; decision pending).

### Non-Readable Is Indistinguishable From Nonexistent

**A response to a caller who may not read a resource MUST be byte-identical, in body and headers,
to the response for a resource that does not exist, and the authorization lookup MUST run before
the existence verdict.** Anything else is an existence oracle.

Rationale, measured: `ai_interviewing` served all 158 assets to a user-role account, 81 of them in
restricted tracks. After the fix a restricted asset returns 404 `{"error":"asset not found"}` with
no ETag, Last-Modified or range headers, identical to a missing one (11 name classes x 6 request
forms; 5 mutants RED; live re-check 2026-09-25: 77 assets 200 for both roles, 81 200/404, none
403). Search MUST apply the access filter BEFORE the LIMIT and escape `%`, `_` and backslash (a
user saw 26 of 1,212 visible hits). Every `/api` route MUST be classified in a route-authorization
guard test. QA banks MUST sign in with a dedicated non-seed account and pass secrets by stdin or a
required environment variable, never a literal, and PASS MUST NOT be derived from a client exit
code alone (`helixqa http` exits 0 with zero cases executed).

### Security Headers Come From the Served Bytes

**A content-security policy, cookie attribute or transport header MUST be derived from what is
actually served on the actual connection, not from a configuration copy of it.**

- The CSP MUST hash the inline scripts of the exact `index.html` bytes served, from an atomically
  swapped immutable snapshot; a stale hard link fails closed.
- The session cookie's `Secure` flag MUST follow the real connection; `X-Forwarded-Proto` MUST NOT
  be trusted, and logout MUST use the same attributes.
- HSTS MUST be sent only over TLS to a public dotted DNS name, never `localhost`.
- Security headers MUST appear on EVERY response class (200, 206, 304, 4xx, 405, HEAD, compressed,
  panic-500, SPA fallback). Before the fix 781 of 4,373 sampled responses carried a CSP that did
  not cover their own body; after, 0.
- ETags MUST be per content-coding (`-br`), `If-None-Match` translated, `If-Range` never
  translated. Authenticated API assets are `private, no-cache` by design and carry no ETag.

Rationale: `ai_interviewing` `92c5c17` (46/46 mutants RED, 282,784 requests, 0 errors). Firefox,
Safari and HTTP/3 remain UNCONFIRMED.

### A Cache in Front of a Filtered Read Re-Runs the Filters

**A cache MUST NOT return a result without re-applying redaction, publication and access checks
on every hit, stale hits included; its key MUST include the data generation; errors, timeouts and
panics MUST NOT be cached.** Detached work behind a cache MUST be bounded and its panics recovered.

Rationale, measured: `/api/suggest` returned 503 for 339/662 requests at 8 clients and 1,265/1,269
at 16 because ranking was CPU-bound and every pooled connection `pread()` a 1.6 GB index. The fix
(workshop `25ce01d`: mmap on the index connections, a generation-keyed stale-while-revalidate cache,
a 39-prefix boot pre-warm) took it to 0/38,716 and 0/44,651 non-200. The contract forbids a
minimum prefix length, so the cost was fixed and the contract was not. A crash-loop cause MUST be
MEASURED before it is blamed (the 2026-09-23 root cause was `systemd-oomd`, not the healthcheck).

### The Content Boundary Is a Standing Invariant

**Nothing from a private module may enter a public repository, and a boundary gate MUST state its
corpus fingerprint and its recall on every run.** Naming a private path is permitted; copying what
is inside it is not. Public history is not editable after a push.

Rationale: private material was written into and pushed to this public repository on 2026-09-01
(incident record: `docs/content-boundary-incident-2026-09-01.md`); the tree was redacted and the
history was rewritten twice (umbrella `ebac0d8`, 2026-09-01; `2d629e9`, 2026-09-02) under operator
authorization that §11.4.113 already forbade — a violation, never a precedent (see **Governance**,
Push and integration). The incident is recorded as NOT CLOSED.
`scripts/verify-content-boundary.sh` is RED BY DESIGN: it exits 1 today over rows an operator must
read. It MUST NOT be silenced by allow-listing a class — an allow-list entry hides the row from the
next reader — and a smaller number after a subtraction pass is not a cleanup. Gates over "the
repository" MUST state whether they scan untracked-not-ignored files; the write-to-`git add`
window is a blind spot the boundary gate found in itself.

### Stage the Pointer and Its Manifest Together

**A gitlink bump and the `helix-deps.yaml` ref that records it MUST land in ONE change.**
`scripts/verify-manifest-pins.sh` (cascade C9) compares the manifest to the INDEX, so staging one
without the other fails it — correctly — and it has caught this four times (`bfe2931`, `3922e35`,
`1e1d4b2`, `3623e05`). A ref comment that restates a sha goes stale on the next bump; a comment
MUST say "current" and be re-derived, not carry a bare sha as if it were live.

**The constitution pin is a standing operator decision, not a task that completes.** Under the
standing authorization recorded in the carriers (2026-09-09) an agent MAY fast-forward
`submodules/constitution` and NOTHING else, ONLY when `merge-base --is-ancestor` is TRUE and
`rev-list --left-right --count` shows 0 divergent, ONLY via `git merge --ff-only`, reporting the
`diff --stat` and re-measuring `Constitution.md` (blob, lines, anchors, bytes, sha256) on BOTH
sides — corpus neutrality is a measurement, not a property (the 2026-09-08 and 2026-09-25 bumps
both changed the corpus). Nothing is ever pushed to the constitution repository. Every other
gitlink needs a per-bump operator decision.

### A Decision, Once Executed, Updates Its Carriers

**A reversal or an executed operator decision MUST edit every document that asserts the old state,
in the same commit.** A carrier that describes the pre-decision world cannot be told from a false
one.

Rationale, measured: the `_site` "tracked / ignored" claim flipped twice and was reversed a third
time by an executed decision nobody propagated; the DECISION-11-4-156 record was reversed in part
within a day; workshop answering was recorded ON on the morning it was reversed. Figures in
carriers MUST be re-measured before restating, and a stale figure is WITHDRAWN in place with its
reason, never replaced. `scripts/verify-claim-ledger.sh` (§11.4.266) re-measures recorded claims
and is the enforcement point for the class it covers; a claim it does not cover has no
enforcement and, under §11.4.266, is a release blocker until a ledger row covers it.

### Shell Idioms Must Survive `pipefail`

**Under `set -o pipefail`, a check MUST NOT be written `producer | grep -q PATTERN`.** `grep -q`
exits on first match, the producer receives SIGPIPE, and the pipeline reports failure for a
condition that holds. Use `grep -q PATTERN <<<"$var"` or capture first.

Rationale: `59ea607` fixed 75 sites in 21 files after the pattern corrupted a badge script and
mis-reported ports; the constitution sweep's 96 FAILs were hypothesised to be SIGPIPE artefacts
and that hypothesis was REFUTED by measurement (`CONTINUATION.md`, 2026-09-06) — the class is real
and it is not the explanation for everything. State which claim you tested.

### Quality Over Speed

60% RAM cap on heavy work. TDD where possible. Lint and typecheck before claiming done. No
shortcuts that compromise integrity.

Never edit a shell script while it is executing — bash reads scripts lazily and a live edit makes
the running shell execute garbage. Never commit while another agent is writing; a blind
`git add .` has already been caught about to roll back three submodule pins and to re-introduce a
cyclic gitlink that had been deliberately removed.

## Project Structure

The vasic umbrella monorepo owns two personal/portfolio sites, a curriculum platform, and shared
tooling. The submodule roster is derived (see **Governance Fidelity**); the directories that carry
project-specific rules are:

- **vasic.digital/** — committed static HTML served as-is (no build step)
- **milosvasic.ru/** — Jekyll source; rendered `_site/` is git-ignored and untracked (0 files,
  `git -C milosvasic.ru ls-files _site`); self-publishes on push via `.github/workflows/pages.yml`
  (ACTIVE, do not disable). Local builds run in a container:
  `_tools/containers/bin/site-build -workload jekyll` (§11.4.76, Containers submodule).
- **workshop/** — PRIVATE. Angular SPA (`platform/frontend`) + Go backend (`platform/backend`),
  served from the podman container `workshop-curriculum_platform_1` on port 8087 by default
  (discovered, not fixed — `_tools/containers/cmd/port-discover`). Answering is OFF by default.
- **ai_interviewing/** — PRIVATE. Go (gin) `aicur` + Angular, run as a native binary
  (`platform/bin/aicur`), HTTP 8099 / HTTPS 8445 by default with port fallback.
- **_tools/gen/** — Go generator rendering localized pages and the Atom feeds for both sites
- **design-system/** — shared per-brand tokens and component CSS; `motion.js` is canonical here
  and copied to both sites
- **_tests/** — Playwright plus self-validating harness
- **_content/** — English source; `_content_<lang>/` siblings for translations
- **specs/** — Spec Kit feature specifications 001–009
- **submodules/constitution/** — the universal constitution (see measurement above)

`bash scripts/qa-up.sh` boots all services for manual QA on discovered ports.

Toolchains, MEASURED 2026-09-25 on this host (re-derive, do not trust): Go 1.26.0, Node 26.8.1,
npm 11.19.0, system Python 3.14.4, ffmpeg 8.0.1, podman
(**docker, tesseract, bundle and jekyll are absent**), poppler-utils present. Two consequences are
recorded rather than hidden: gate 5 exits 2 without `tesseract`, and gate 6's webkit project needs
`libmanette-0.2-0` and `libwoff1` (an operator package install). An rc 2 is never a pass.

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

`scripts/pre-push-gates.sh` registers 8 gates (the registry in `scripts/check-registry.tsv`
holds many more checks that are not pre-push gates). A SKIP is never a PASS; `PREPUSH_STRICT=1`
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

Governance and adaptability instruments (the full list is `scripts/check-registry.tsv`). Each
is three-valued per **Honest Instruments**.

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
| `scripts/verify-manifest-pins.sh` | every `helix-deps.yaml` ref equals its gitlink (C9) |
| `scripts/verify-submodule-remote-sync.sh` | gitlinks vs their `origin` — the only remote-facing check |
| `scripts/verify-content-boundary.sh` | private content in public files (RED BY DESIGN) |
| `scripts/verify-claim-ledger.sh` | re-measures recorded claims (§11.4.266) |
| `scripts/verify-pretooluse-guard.sh` | the wired forbidden-command guard actually refuses |
| `scripts/verify-check-registry.sh` | every check has a paired proof; `--run-proofs` executes them |

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

**Push and integration.** Force-push is ABSOLUTELY forbidden (§11.4.113): no `--force`, no
`--force-with-lease`, no `+ref`, no history rewrite, with or without approval. Integrate by
fetching every remote, basing on the most-advanced upstream tip, merging, and pushing
fast-forward to every upstream. The 2026-09-01 history rewrite (`ebac0d8`) was performed under an
explicit per-session authorization that this project's own carriers then permitted, although canon
§11.4.113 (operator mandate 2026-06-03) already forbade it absolutely; it is recorded as a
deviation from canon, not as precedent. Older carrier wording that allows a per-session authorized
force-push
is superseded by §11.4.113 and MUST be corrected wherever found. Never push to third-party
gitlinks (`submodules/superspec`) or to the constitution repository. A push to
`milosvasic.ru` deploys a live production site.

**Independent review.** Every change, including a one-line doc edit, passes an independent review
before it is accepted (§11.4.142); the model and effort are those §11.4.209 currently names — do
not restate them here, because canon has already reversed that ordering once. A reviewer's
report is the reviewer's word: verify what it claims before acting on it.

**Compliance review.** The local gate suite is the enforcement point; there is no server-side
check. Before a release or a tag, run the full sweep plus the verification scripts above, and
record the result. An unrunnable check is reported as such — never as a pass. Claims of
compliance require the command output that demonstrates it.

**Version**: 1.5.0 | **Ratified**: 2026-08-26 | **Last Amended**: 2026-09-25

Ratification date is DERIVED, not asserted: `git log --reverse --format=%cs --
.specify/memory/constitution.md` returns 2026-08-26, the first commit that
introduced this file. Re-derive it rather than trusting this line.
