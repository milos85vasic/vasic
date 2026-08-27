# Constitution Adoption — start here

| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-08-27 |
| Status | active |
| Status summary | Reader's guide to how the `vasic` umbrella inherits the Helix Universal Constitution: where the constitution lives, which parts of the prescribed adoption mechanism are wired, how the inheritance pointer is recognised, how to run the two verifiers, and what still fails. |
| Scope | Documentation only. This file describes artifacts; it does not add, weaken, or override any rule. |
| Verifiers described | `tests/test_constitution_inheritance.sh`, `scripts/verify-all-constitution-rules.sh` |

> **§11.4.65 disclosure.** This document ships without its `.html` and `.pdf`
> siblings, the same known and disclosed deviation
> [`INVENTORY.md`](INVENTORY.md) records for itself as gap **G8**. It is stated
> rather than left to be discovered.

---

## Table of contents

- [0. The 60-second version](#0-the-60-second-version)
- [1. What the constitution is, and where it lives](#1-what-the-constitution-is-and-where-it-lives)
- [2. The five-part adoption mechanism, with status](#2-the-five-part-adoption-mechanism-with-status)
- [3. How inheritance actually works here](#3-how-inheritance-actually-works-here)
- [4. The §11.4.157 five-carrier lockstep](#4-the-114157-five-carrier-lockstep)
- [5. Running the verifiers](#5-running-the-verifiers)
- [6. Current honest status — 37 PASS / 21 FAIL](#6-current-honest-status--37-pass--21-fail)
- [7. Open conflicts — operator decisions, not bugs](#7-open-conflicts--operator-decisions-not-bugs)
- [8. Document index](#8-document-index)

---

## 0. The 60-second version

This repository **consumes** a shared, project-agnostic constitution that lives
in a git submodule. Nothing from that corpus is copied into this repository.
Five files at the repository root — `CLAUDE.md`, `AGENTS.md`, `QWEN.md`,
`GEMINI.md`, `Constitution.md` — each open with a `## INHERITED FROM ` heading
that points at the submodule and declares its rules to apply unconditionally.

Two scripts check that this wiring is real:

```bash
bash tests/test_constitution_inheritance.sh              # 8 invariants; currently 8 PASS
bash tests/test_constitution_inheritance.sh --prove-failure   # proves the gate can fail
bash scripts/verify-all-constitution-rules.sh --quiet    # the full sweep; currently exits 1
```

The sweep **does not pass**, and this documentation does not claim it does.
See [§6](#6-current-honest-status--37-pass--21-fail) for the 21 failures and why
each one is what it is.

---

## 1. What the constitution is, and where it lives

The Helix Universal Constitution is a single, project-agnostic rule corpus
maintained in its own repository and consumed here as a git submodule.

| Property | Value | Verified by |
|---|---|---|
| Path in this repository | **`submodules/constitution/`** | `git submodule status` |
| Upstream | `git@github.com:HelixDevelopment/HelixConstitution.git` | `.gitmodules` |
| Pinned commit | `448981ae3498229c734dc60719f4b19f01d7a75f` | `git submodule status` |
| `git describe` | `v1.0.0-51-g448981a` — 51 commits **past** the only semver tag, i.e. not tag-pinned | `git describe` |
| Corpus size | `Constitution.md` — 11,101 lines / 1,534,735 bytes | `wc -l`, `ls -l` |
| Anchor count | 261 distinct numbered anchors (mechanically counted in [`INVENTORY.md` §2](INVENTORY.md)) | INVENTORY.md |

The files that matter most, all resolved **by reference** and never copied:

| What | Canonical path |
|---|---|
| The universal constitution | `submodules/constitution/Constitution.md` |
| Claude Code carrier | `submodules/constitution/CLAUDE.md` (654,214 bytes) |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi CLI carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Parent-walk resolver | `submodules/constitution/find_constitution.sh` |
| Consumer scaffolds | `submodules/constitution/templates/` |
| The gate fleet | `submodules/constitution/scripts/gates/` |

If `submodules/constitution/` is empty it was never initialised. Initialise it
with `git submodule update --init submodules/constitution` — and note that this
is a mutating git command, so an agent needs operator authorization first.

### 1.1 The path note that trips everyone up

The constitution's **own prose and templates** use a top-level `constitution/`
directory as their worked example — e.g. `constitution/CLAUDE.md`,
`@constitution/CLAUDE.md`. **This repository does not use that layout.** It
places the submodule at `submodules/constitution/`, the §11.4.28
dependency-layout form (owned submodules grouped under a root `submodules/`
directory).

Both layouts are first-class: `submodules/constitution/find_constitution.sh`
searches for either, walking up from any nested depth. Line 42:

```bash
    local rels=( "constitution" "submodules/constitution" )
```

**Translation rule.** Wherever a quoted universal clause says
`constitution/<file>`, the real path in this checkout is
`submodules/constitution/<file>`. That substitution is the only systematic edit
made when the project `Constitution.md` was instantiated from
`submodules/constitution/templates/Constitution.project.md.template`, and the
project `Constitution.md` says so in its own path note.

Locate the submodule from anywhere:

```bash
bash submodules/constitution/find_constitution.sh
```

---

## 2. The five-part adoption mechanism, with status

The constitution **prescribes** how a project adopts it. Nothing here was
invented. [`INVENTORY.md` §5](INVENTORY.md) is the source that identified the
mechanism as five parts and quoted each one; the quotations below are from
`submodules/constitution/README.md` ("How to consume") and
`submodules/constitution/Constitution.md`.

The status column reflects what is on disk **today**, which is later than the
state INVENTORY.md recorded — INVENTORY.md was written before parts 2, 4 and
most of 5 landed, and still says so.

| # | Part | Prescribed by | Status today |
|---|---|---|---|
| 1 | Add the submodule | `README.md` "How to consume" §1 | **DONE** |
| 2 | Wire the inheritance | `README.md` §2 + §11.4.35 invariant 6 | **DONE** |
| 3 | Instantiate the templates | `submodules/constitution/templates/` | **PARTIAL** — only 3 of 5 templates exist upstream |
| 4 | Verify with an automated test | `README.md` §4 + §1.1 | **DONE** |
| 5 | The post-pull transaction | §11.4.164 + §11.4.32 | **PARTIAL** — sweep exists; cascade verifier and hook wiring do not |

### Part 1 — add the submodule → DONE

> ```bash
> git submodule add git@github.com:HelixDevelopment/HelixConstitution.git constitution
>
> # Pin to a tag for reproducibility (recommended)
> cd constitution
> git checkout v1.0.0          # whatever the current stable tag is
> ```

Done, at `submodules/constitution` rather than `constitution` — the layout
`find_constitution.sh` explicitly supports (see [§1.1](#11-the-path-note-that-trips-everyone-up)).

**Honest boundary.** The quoted step recommends pinning to a tag. This
repository pins a **commit** (`448981ae…`), which `git describe` resolves to
`v1.0.0-51-g448981a` — 51 commits past the tag. The pin is reproducible and the
inheritance test asserts it (invariant I2), but it is not the tag-pin the
snippet recommends.

### Part 2 — wire the inheritance → DONE

> Add a clearly-marked pointer at the top of your project's root
> `CLAUDE.md`:
>
> ```markdown
> ## INHERITED FROM constitution/CLAUDE.md
>
> All rules in `constitution/CLAUDE.md` (and the `constitution/Constitution.md`
> it references) apply unconditionally. Project-specific rules below
> extend them.
>
> @constitution/CLAUDE.md
> ```

and its normative form, §11.4.35 invariant 6:

> 6. **`@constitution/CLAUDE.md` import (Claude-Code-style) and the
>    pointer-block fallback (Aider/Codex/Gemini-style) are equivalent.**
>    The consumer's CLAUDE.md MUST start with one of:
>    - The native import: `@constitution/CLAUDE.md`
>    - The portable pointer-block per the `## INHERITED FROM
>      constitution/CLAUDE.md` heading defined in
>      `constitution/CLAUDE.md` "How inheritance works".

All five root carriers now open with the pointer block form. The mechanics —
and why the pointer was chosen over the import — are
[§3](#3-how-inheritance-actually-works-here).

### Part 3 — instantiate the templates → PARTIAL

The submodule ships consumer scaffolds at
`submodules/constitution/templates/`. There are exactly three:

| Template | Used here for |
|---|---|
| `Constitution.project.md.template` | the root `Constitution.md` |
| `AGENTS.project.md.template` | the root `AGENTS.md`, and the nine-item "Critical base rules restated" block reproduced in all four agent carriers |
| `CLAUDE.project.md.template` | the root `CLAUDE.md` |

There is **no** `QWEN.project.md.template` and **no**
`GEMINI.project.md.template`, even though §11.4.157 makes all five carriers
equal. That is a gap in the constitution submodule itself, recorded as **G7b**
in [`INVENTORY.md` §8](INVENTORY.md) and repeated in the project
`Constitution.md`; it forces every consuming project to hand-derive two of its
five carriers. Per §11.4.26 the fix belongs upstream in
`HelixDevelopment/HelixConstitution`, not here.

The nine-item restated block is worth calling out because it looks like a
copy of the corpus and is not. It is authored **by the constitution** in
`AGENTS.project.md.template` for exactly this purpose ("for agents that don't
follow @imports"), so reproducing it is the prescribed mechanism. Everything
else in the carriers is a pointer.

### Part 4 — verify with an automated test → DONE

> Every consuming project should ship a test that verifies the
> constitution submodule is present, at the expected pinned revision,
> and that the project's CLAUDE.md / AGENTS.md / QWEN.md / Constitution
> all reference the submodule.

Implemented as `tests/test_constitution_inheritance.sh`, 8 invariants, plus a
`--prove-failure` paired-mutation mode that satisfies §1.1 ("a gate that cannot
be made to fail is a sham"). See [§5](#5-running-the-verifiers).

**Honest boundary.** The quoted step names two reference implementations (the
ATMOSphere and Herald projects' tests). Neither repository is present in this
checkout, so neither was available to copy. The gate's own header says so and
cites, per invariant, the clause or shipped artifact each assertion comes from.

### Part 5 — the post-pull transaction → PARTIAL

§11.4.32:

> **Validation sweep contract.** The sweep is implemented as
> `scripts/verify-all-constitution-rules.sh` (canonical name) which:
>
> 1. Re-runs the existing governance-cascade verifier (`scripts/
>    verify-governance-cascade.sh`) covering every §11.9 + CONST-*
>    anchor across every owned submodule (recursive per CONST-047).
> 2. For each rule whose enforcement gate is implementable
>    programmatically […] the sweep runs the corresponding gate against
>    the post-pull tree.
> 3. Any failure produces a directed FAIL entry naming the rule […]

§11.4.164:

> The canonical hook script lives at `constitution/scripts/post_update_hook.sh`
> and is inherited by reference (§11.4.28) — NEVER copied locally.

What exists and what does not:

| Piece | State |
|---|---|
| `scripts/verify-all-constitution-rules.sh` (step 2 + 3) | **exists** — discovers gates dynamically, reports directed FAIL entries |
| `scripts/verify-governance-cascade.sh` (step 1) | **does not exist**; the sweep prints an explicit SKIP naming it — recorded as open conflict **OC-3** |
| `submodules/constitution/scripts/post_update_hook.sh` | **present in the submodule, invoked from nowhere in this repository** — INVENTORY gap **G12**'s sibling condition |
| §11.4.75 five-layer git-hook ritual | **absent** — `.git/hooks/` contains only git's own `*.sample` files (0 non-sample hooks) — INVENTORY gap **G5** |

---

## 3. How inheritance actually works here

### 3.1 The literal the gates key on

The whole mechanism rests on one exact string: a line-anchored heading

```
## INHERITED FROM <anything>
```

at the top of a carrier, **outside any fenced code block**. A file carrying it
is a §11.4.35 *pointer-inheritance consumer*: it inherits every universal anchor
by reference and is not required to restate anchor text verbatim.

The single canonical predicate lives at
`submodules/constitution/scripts/gates/lib/pointer_carrier.sh`. It is eight
lines wrapping four lines of `awk`:

````bash
is_pointer_carrier() {
    awk '
        BEGIN { fenced = 0; found = 0 }
        /^(```|~~~)/ { fenced = !fenced; next }
        !fenced && /^## INHERITED FROM / { found = 1; exit }
        END { exit !found }
    ' "$1"
}
````

Every `cm_covenant_114_*_propagation.sh` gate sources it, and so does this
repository's `tests/test_constitution_inheritance.sh` (invariant I4) — by
reference, never by copy. The practical effect, from a real run of one gate
against this repository:

```
⏭ POINTER-INHERITANCE-SKIP  AGENTS.md  — §11.4.35 pointer consumer (inherits 11.4.213 by pointer)
⏭ POINTER-INHERITANCE-SKIP  CLAUDE.md  — §11.4.35 pointer consumer (inherits 11.4.213 by pointer)
⏭ POINTER-INHERITANCE-SKIP  GEMINI.md  — §11.4.35 pointer consumer (inherits 11.4.213 by pointer)
⏭ POINTER-INHERITANCE-SKIP  QWEN.md  — §11.4.35 pointer consumer (inherits 11.4.213 by pointer)
```

Without the heading those four lines would read `❌ MISSING … lacks anchor
literal 11.4.213`, once for every one of the 17 propagation gates.

### 3.2 The fenced-code-block trap the predicate guards against

Two details in that `awk` are load-bearing, and the file's own header explains
why each exists.

**Fence tracking.** A bare `grep -qE '^## INHERITED FROM '` would false-match
the "How inheritance works" **example** that the canonical constitution mirrors
quote inside a fenced block. That fenced text is a *carrier quoting the heading*
— a full-restating mirror that must still be checked for every anchor — not a
real pointer. A predicate fooled by it would silently skip the canonical files
themselves. The `awk` therefore toggles a `fenced` flag on every fence-opening
line — backtick **or** tilde — and only recognises the heading outside a fence.
The tilde form is tracked too: a predicate that toggled on backticks alone would
be fooled by a `~~~`-fenced decoy, and there is a golden-bad fixture for exactly
that.

The trap is not hypothetical. `submodules/constitution/CLAUDE.md` line 91 is a
literal, column-zero `## INHERITED FROM constitution/CLAUDE.md` — sitting inside
the fence opened on line 90:

````markdown
## How inheritance works

A consuming project's root `CLAUDE.md` MUST start with a clearly-marked
inheritance pointer:

```markdown
## INHERITED FROM constitution/CLAUDE.md
...
```
````

`grep` says pointer. The predicate says otherwise, and can be checked directly:

```bash
$ . submodules/constitution/scripts/gates/lib/pointer_carrier.sh
$ is_pointer_carrier submodules/constitution/CLAUDE.md; echo $?
1
```

Had it said `0`, every propagation gate would have skipped the canonical
`CLAUDE.md` — the one file in the fleet that must be checked against every
single anchor.

**The `^` line-start anchor.** The live `constitution/CLAUDE.md` mentions
`` `## INHERITED FROM constitution/CLAUDE.md` `` mid-line, inside backticks, in
prose. A substring match would read that as a pointer heading and skip a full
mirror. The `^` anchor is what stops it, and again there is a golden-bad fixture
named after exactly that shape.

The predicate ships its own runnable proof:

```bash
bash submodules/constitution/scripts/gates/lib/pointer_carrier.sh --selftest
```

It exercises five fixtures — one golden-good, three golden-bad decoys
(fenced carrier, mid-line backticked mention, `~~~`-fenced), one negative
control — and prints `pointer_carrier.sh selftest: PASS (5/5)`. The inheritance
test runs this **first**, as invariant I7, on the §11.4.201(7)(b) principle that
a null result is not evidence until the instrument is proven to see.

### 3.3 Why the pointer block and not the native `@import`

§11.4.35 invariant 6 declares the two forms **equivalent** — a consumer carrier
must start with either the native `@constitution/CLAUDE.md` import **or** the
portable `## INHERITED FROM ` pointer block. This repository chose the pointer,
and the reason is stated in the carriers rather than left implicit:

`submodules/constitution/CLAUDE.md` is **654,214 bytes** and
`submodules/constitution/Constitution.md` is **1,534,735 bytes**. A native
`@import` auto-loads the imported file into the agent's context at session
start, so every session — including ones that never touch governance — would
begin by loading roughly 654 KB before any work starts. The pointer form carries
the same authority at no standing cost, and it is the form the constitution's
own propagation gates recognise via the predicate above.

The trade-off is real and worth stating: an agent that does **not** resolve
pointers sees only the nine restated base rules, not the corpus. That is why
each carrier says, in as many words, that a rule absent from the carriers is not
absent — read it from `submodules/constitution/Constitution.md` before acting.

Read one anchor instead of the whole corpus:

```bash
grep -n '^### §11.4.35 ' submodules/constitution/Constitution.md
awk '/^### §11.4.35 /{f=1} f{print} f&&/^### §11.4.36 /{exit}' \
    submodules/constitution/Constitution.md
```

---

## 4. The §11.4.157 five-carrier lockstep

§11.4.157 (`submodules/constitution/Constitution.md:9566`):

> `GEMINI.md` is a FIRST-CLASS governance context carrier, EQUAL to `CLAUDE.md`
> / `AGENTS.md` / `QWEN.md` — NEVER an optional or best-effort sibling. Every
> governance addition or edit MUST land in ALL FIVE carriers in lockstep: the
> canonical `Constitution.md` PLUS each per-agent mirror `CLAUDE.md` +
> `AGENTS.md` + `QWEN.md` + `GEMINI.md` […] **(B) No silent drift.** A
> `GEMINI.md` whose highest rule number lags the other mirrors is a §11.4.157
> violation […] **(D) Consumer projects too.** The lockstep binds the consuming
> project's repository-root context files […] a project that maintains the other
> three but not `GEMINI.md` is non-compliant.

The clause exists because of a real incident recorded in its own forensic case
study: `GEMINI.md` once drifted fourteen mandates behind the other three
mirrors, so a Gemini-CLI agent was operating under an out-of-date constitution
while the fleet believed the rule was universally in force.

**How this repository satisfies it.** All four root agent carriers are 197 lines
each. Lines 1–23 differ by design — the title, which base file the carrier
points at, and one sentence naming which agent reads it. **Line 24 onward is
byte-identical across all four**, which is what makes drift structurally
impossible rather than merely discouraged: a governance edit either lands in all
four or the check below fails.

Verify it in one line — it must print `1`:

```bash
for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do tail -n +24 "$f" | sha256sum | cut -d' ' -f1; done | sort -u | wc -l
```

Real output, this checkout:

```
1
```

The shared digest is
`d26e2c31252d8837870b559c90d0650709f903b74ceaedc45944bb623fa4f836`. A `2` means
a carrier drifted; `diff <(tail -n +24 CLAUDE.md) <(tail -n +24 GEMINI.md)`
names what.

The fifth carrier, `Constitution.md`, is **not** byte-identical to the other
four and is not meant to be — it is the project constitution, not a per-agent
mirror. What binds it is invariants I3/I4/I5 of the inheritance test: it must
exist, open with the pointer heading, and name `submodules/constitution/`.

> **Not specified.** §11.4.157 mandates lockstep but does not prescribe *how* a
> consumer proves it, and names no byte-identity check. The line-24 split and
> the one-liner above are this project's chosen mechanism, not a universal
> requirement.

---

## 5. Running the verifiers

Two commands. Both are read-only: neither writes to this repository, neither
writes into any submodule working tree, and neither runs a mutating git command.

### 5.1 `tests/test_constitution_inheritance.sh` — the inheritance gate

```bash
bash tests/test_constitution_inheritance.sh
```

Real output, this checkout:

```
CM-CONSTITUTION-INHERITANCE: checking /run/media/milosvasic/DATA4TB/Projects/vasic
✅ PASS  I7 PREDICATE-NOT-BLIND — pointer_carrier.sh --selftest: pointer_carrier.sh selftest: PASS (5/5)
✅ PASS  I1 SUBMODULE-PRESENT — canonical root complete at submodules/constitution/ (§11.4.35)
✅ PASS  I2 PINNED-REVISION — submodules/constitution HEAD == pinned gitlink 448981ae3498229c734dc60719f4b19f01d7a75f
✅ PASS  I3 FIVE-CARRIERS — CLAUDE.md AGENTS.md QWEN.md GEMINI.md Constitution.md all present (§11.4.157)
✅ PASS  I4 POINTER-INHERITANCE — all five carriers open with a real, non-fenced '## INHERITED FROM ' heading (§11.4.35 inv. 6)
✅ PASS  I5 SUBMODULE-REFERENCED — all five carriers name 'submodules/constitution/'
✅ PASS  I6 ANCHOR-PRESENT — '### §11.4 End-user quality guarantee' present in the inherited corpus
✅ PASS  I8 PROPAGATION-GATES — 17/17 cm_covenant_114_*_propagation gates PASS on the root carriers
----------------------------------------------------------------------
CM-CONSTITUTION-INHERITANCE: 8 PASS, 0 SKIP, 0 FAIL  (root /run/media/milosvasic/DATA4TB/Projects/vasic)
✅ CM-CONSTITUTION-INHERITANCE: PASS — constitution inheritance is wired
```

Exit code `0`.

The eight invariants, in the order they run:

| Invariant | Asserts | Clause |
|---|---|---|
| I7 PREDICATE-NOT-BLIND | the pointer predicate's own 5-fixture selftest passes, **before** anything relies on it | §11.4.201(7)(b) |
| I1 SUBMODULE-PRESENT | the canonical root's six files are present and non-empty | §11.4.35 |
| I2 PINNED-REVISION | the submodule's HEAD equals the gitlink recorded in this repository's index | README "How to consume" §4 |
| I3 FIVE-CARRIERS | all five root carriers exist and are non-empty | §11.4.157 |
| I4 POINTER-INHERITANCE | each carries a real, non-fenced pointer heading — or a native `@import` | §11.4.35 inv. 6 |
| I5 SUBMODULE-REFERENCED | each names `submodules/constitution/` | README "How to consume" §4 |
| I6 ANCHOR-PRESENT | the inherited corpus still carries `### §11.4 End-user quality guarantee` | the exact literal `meta_test_inheritance.sh` deletes |
| I8 PROPAGATION-GATES | all 17 `cm_covenant_114_*_propagation.sh` gates pass against the four root carriers in isolation | §11.4.35 inv. 5 |

Note what I8 does **not** cover. It stages copies of the four root carriers into
a temp directory and points the gate family there, so its verdict is about *this
project's own carriers*. Carriers belonging to third-party repositories that
happen to be reachable from the umbrella are out of I8's scope by construction —
they are still reported, and still fail, in the full sweep
([§6](#6-current-honest-status--37-pass--21-fail)).

`--root <dir>` and `--quiet` are also accepted.

### 5.2 `--prove-failure` — the §1.1 paired mutation proof

A gate that always passes proves nothing. §1.1: a gate that cannot be made to
fail "is a sham and must be rewritten". This mode builds a throwaway **copy** of
the governance surface in a `mktemp -d` sandbox, confirms the unmutated copy
passes (the golden-good control, without which "the mutations failed" would be
meaningless), then applies four single-point mutations one at a time and asserts
the gate fails on each.

```bash
bash tests/test_constitution_inheritance.sh --prove-failure
```

Real output, this checkout:

```
CM-CONSTITUTION-INHERITANCE §1.1 PAIRED MUTATION PROOF
  sandbox: /tmp/.private/milosvasic/tmp.YfGy7PxL8j   (every mutation below is applied to a COPY;
  neither this repository nor any submodule working tree is written to)
----------------------------------------------------------------------
✅ CONTROL golden-good  — unmutated sandbox copy PASSes (rc=0)
✅ M1 pointer-stripped  — root CLAUDE.md loses its '## INHERITED FROM ' pointer heading -> gate FAILed (rc=1), as it must  [I4 + I8]
✅ M2 carrier-deleted   — root GEMINI.md deleted (five-carrier lockstep broken)          -> gate FAILed (rc=1), as it must  [I3 + I4 + I5]
✅ M3 anchor-deleted    — '### §11.4 ...' anchor deleted from the inherited corpus       -> gate FAILed (rc=1), as it must  [I6]
✅ M4 canonical-emptied — submodules/constitution/GEMINI.md emptied (canonical root gap) -> gate FAILed (rc=1), as it must  [I1]
----------------------------------------------------------------------
✅ CM-CONSTITUTION-INHERITANCE §1.1 MUTATION PROOF: PASS — control passed and all 4 mutations were caught
```

Exit code `0`. The sandbox path changes on every run.

M3 deserves a note: it is the same mutation
`submodules/constitution/meta_test_inheritance.sh` applies — deleting the
`### §11.4 ` anchor line — except that harness mutates the **real**
`submodules/constitution/Constitution.md` in place and restores it afterwards.
This mode applies it to a copy instead, so the gate is proven non-bluff against
the identical regression without ever writing into a submodule working tree.

### 5.3 `scripts/verify-all-constitution-rules.sh` — the §11.4.32 sweep

```bash
bash scripts/verify-all-constitution-rules.sh            # full per-gate output
bash scripts/verify-all-constitution-rules.sh --quiet    # one line per gate; FAIL detail always shown
bash scripts/verify-all-constitution-rules.sh --list     # show what would run, run nothing, exit 0
```

Gates are **discovered, never hardcoded** — `find … -name '*.sh'` under
`submodules/constitution/scripts/gates/`. Pull a new gate from upstream and the
sweep picks it up with no edit here. That is a direct response to §11.4.32's
anti-bluff clause: *"A sweep that exits PASS without actually running every
implementable gate is a §11.4.32 violation."*

Each gate's invocation is resolved **from the gate itself**, because the family
overloads `--root` for two different things: a gate whose usage header says
`--root <consumer-root>` or `<project-root>` gets the project root, one that says
`--root <constitution-root>` gets `submodules/constitution`, and one with no
`--root` in its header runs on its own defaults. `--selftest` and
`selfcheck <tmpdir>` are used where the script documents them. Every resolved
argv is printed, so a reader can check the resolution rather than trust it.

This run takes minutes, not seconds. `GATE_TIMEOUT` (default 900s) caps each
gate when coreutils `timeout` is on PATH; when it is not, the sweep says so
rather than pretending a cap is in force.

Real output — `bash scripts/verify-all-constitution-rules.sh --quiet`, this
checkout, constitution HEAD `448981ae3498229c734dc60719f4b19f01d7a75f`:

```
======================================================================
§11.4.32 VALIDATION SWEEP — verify-all-constitution-rules.sh
======================================================================
project root        : /run/media/milosvasic/DATA4TB/Projects/vasic
constitution        : /run/media/milosvasic/DATA4TB/Projects/vasic/submodules/constitution
constitution HEAD   : 448981ae3498229c734dc60719f4b19f01d7a75f
gates discovered    : 57 (dynamically, under scripts/gates/**)
per-gate timeout    : 900s

---- STEP 1 — governance-cascade verifier (§11.4.32 step 1) ----------
⏭ STEP1 SKIP — scripts/verify-governance-cascade.sh does not exist in this
               repository. §11.4.32 step 1 requires the sweep to re-run it;
               writing it is outstanding work. This is an explicit SKIP with
               a reason (§11.4.3), NOT a pass, and it is recorded as open
               conflict OC-3 in Constitution.md.

---- STEP 2 — every gate under submodules/constitution/scripts/gates --
PASS   rc=0       656ms  cm_build_on_source_proven_not_test_side_mutation_test.sh    (gate defaults)
PASS   rc=0        11ms  cm_build_on_source_proven_not_test_side.sh                  (gate defaults)
PASS   rc=0     56079ms  cm_cli_agent_plugins_wired_mutation_test.sh                 (gate defaults)
PASS   rc=0     12255ms  cm_cli_agent_plugins_wired.sh                               --root /run/media/milosvasic/DATA4TB/Projects/vasic/submodules/constitution --quiet
PASS   rc=0       526ms  cm_continuum_resume_engine_present_mutation_test.sh         (gate defaults)
FAIL   rc=1      1228ms  cm_continuum_resume_engine_present.sh                       --root /run/media/milosvasic/DATA4TB/Projects/vasic/submodules/constitution --quiet
FAIL   rc=1       519ms  cm_covenant_114_162_propagation.sh                          --root /run/media/milosvasic/DATA4TB/Projects/vasic --quiet

                        […] 48 further gate lines elided for length […]

FAIL   rc=1        70ms  cm_track_branch_label.sh                                     --quiet
PASS   rc=0       308ms  cm_version_increment_on_deploy_mutation_test.sh             (gate defaults)
PASS   rc=0        38ms  cm_version_increment_on_deploy.sh                           (gate defaults)
PASS   rc=0       650ms  gate_ledger.sh                                              selfcheck <scratch>
PASS   rc=0       106ms  lib/pointer_carrier.sh                                      --selftest

---- STEP 2b — project-side gates -------------------------------------
PASS   rc=0      2275ms  tests/test_constitution_inheritance.sh                      --root <root> --quiet

======================================================================
SUMMARY
======================================================================
gates run           : 58
  PASS              : 37
  FAIL   (rc=1)     : 21
  ERROR  (rc!=0,1)  : 0
§11.4.32 step 1     : skip

FAILED:
  ❌ cm_continuum_resume_engine_present.sh
  ❌ cm_covenant_114_162_propagation.sh
  ❌ cm_covenant_114_167_propagation.sh
  ❌ cm_covenant_114_176_propagation.sh
  ❌ cm_covenant_114_187_propagation.sh
  ❌ cm_covenant_114_191_propagation.sh
  ❌ cm_covenant_114_196_propagation.sh
  ❌ cm_covenant_114_199_propagation.sh
  ❌ cm_covenant_114_200_propagation.sh
  ❌ cm_covenant_114_201_propagation.sh
  ❌ cm_covenant_114_202_propagation.sh
  ❌ cm_covenant_114_207_propagation.sh
  ❌ cm_covenant_114_213_propagation.sh
  ❌ cm_covenant_114_230_propagation.sh
  ❌ cm_covenant_114_231_propagation.sh
  ❌ cm_covenant_114_232_propagation.sh
  ❌ cm_covenant_114_233_propagation.sh
  ❌ cm_covenant_114_235_propagation.sh
  ❌ cm_gate_ledger_ratchet.sh
  ❌ cm_track_branch_label_mutation_test.sh
  ❌ cm_track_branch_label.sh

======================================================================
DETAIL — full output of every non-PASS gate
======================================================================
===== cm_continuum_resume_engine_present.sh  [FAIL rc=1]
      argv: --root /run/media/milosvasic/DATA4TB/Projects/vasic/submodules/constitution --quiet
❌ FOUND    project-specific literal(s) inside the engine (decoupling violation):
            submodules/continuum/test/e2e/e2e_test.go
----------------------------------------------------------------------
❌ CM-CONTINUUM-RESUME-ENGINE-PRESENT: FAIL — one or more checks failed (see above)

                        […] the other 20 FAIL details elided for length […]

======================================================================
❌ SWEEP: FAIL — 21 FAIL + 0 ERROR out of 58 gate(s).

Before treating any of these as a regression, read
  Constitution.md -> 'Known-excluded gate findings'
which names the five third-party / staged carriers the propagation
gates report, and the four failures internal to the constitution
submodule's own tree. Those are recorded, NOT suppressed: they still
FAIL here and they still make this sweep exit non-zero.
```

Exit code `1`. The transcript above is the real run, trimmed only where marked;
elapsed times vary per run. The full run wrote 398 lines. `--quiet` still prints
every FAIL in full — the elisions above are this document's, not the sweep's.

Two counts to note. `gates discovered : 57` is the scripts found under
`scripts/gates/**`; `gates run : 58` adds this repository's own
`tests/test_constitution_inheritance.sh` in step 2b. And step 1 is `skip`, not
`pass` — the sweep never counts a missing verifier as a passing one.

### 5.4 The exit-code contract

Both scripts use the same three-value contract, and neither ever treats a
non-zero as "close enough".

| Exit | `tests/test_constitution_inheritance.sh` | `scripts/verify-all-constitution-rules.sh` |
|---|---|---|
| `0` | every invariant holds — or, in `--prove-failure`, the control passed and all four mutations were caught | every discovered gate exited `0` |
| `1` | at least one invariant FAILed — or a mutation did **not** make the gate fail, i.e. this gate is a bluff gate | at least one gate FAILed (`rc=1`) or ERRORed |
| `2` | environment error: root not found, canonical predicate unreadable, gate family not found | the sweep could not run at all: root missing, submodule not initialised, gates directory absent, zero gates discovered |

Two rules the sweep applies that are easy to get wrong:

- **An `rc=2` gate is an ERROR, never a pass.** §11.4.201(7)(b): a blind
  instrument produces no evidence. ERRORs are counted separately and still make
  the sweep exit `1`.
- **A known-excluded finding still FAILs.** Nothing is suppressed. Exclusion
  (see [§6](#6-current-honest-status--37-pass--21-fail)) means "not ours to
  fix"; it is a note for the reader, never a verdict change.

---

## 6. Current honest status — 37 PASS / 21 FAIL

**The sweep does not pass.** It exits `1`. Do not read anything in this
directory as a compliance claim.

58 gates run: **37 PASS, 21 FAIL, 0 ERROR**, plus §11.4.32 step 1 recorded as an
explicit **SKIP with a reason**. The 58 are the 57 scripts discovered under
`submodules/constitution/scripts/gates/**` plus this repository's own
`tests/test_constitution_inheritance.sh`.

The 21 failures decompose exactly, with nothing left over:

### A. 17 propagation gates → the same five carriers, every time

All 17 `cm_covenant_114_*_propagation.sh` gates (anchors 162, 167, 176, 187,
191, 196, 199, 200, 201, 202, 207, 213, 230, 231, 232, 233, 235) fail, and each
reports the **same five** carriers as `MISSING`. 17 × 5 = 85 `MISSING` lines in
the sweep transcript, and no sixth carrier appears anywhere. (Counted from the
run above: 12 of the 17 are the legacy bare-literal gates, reporting *"lacks
anchor literal 11.4.N"*; the other 5 are the fence-aware §11.4.227(B)
block-integrity gates, reporting *"zero 11.4.N block-starts"*. 12 × 5 + 5 × 5 =
85.)

| Carrier | Owning repository | Why it is what it is |
|---|---|---|
| `milosvasic.ru/Upstreamable/AGENTS.md` | `red-elf/Upstreamable` — third-party, and a gitlink **of** the `milosvasic.ru` submodule (a fourth-level repository) | project `Constitution.md` §103: not owned, not pushed, never edited from here |
| `milosvasic.ru/Upstreamable/CLAUDE.md` | same | §103 |
| `submodules/superspec/examples/static-landing-page/CLAUDE.md` | `WangX0111/superspec` — third-party | §103 — a vendored example fixture of someone else's project |
| `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` | vendored copy of the same superspec fixture | §103 |
| `vasic.digital/QWEN.md` | `vasic-digital/vasic-digital.github.io` — **owned** | §102 — the fix is staged, not applied |

**Four of the five are third-party.** Writing a governance carrier into a
repository this project neither owns nor pushes to would be editing someone
else's tree to make a gate go green.

**One is ours.** `vasic.digital/QWEN.md` exists (55 lines) and references no
anchor and no constitution. Its fix is prepared at
[`propagation/vasic.digital/QWEN.insert-block.md`](propagation/vasic.digital/QWEN.insert-block.md)
and awaits operator application, because §3 of the universal constitution
requires the submodule commit and push to land **before** the parent captures
the pointer — so the umbrella never writes a carrier into an owned submodule's
working tree. The procedure is
[`propagation/APPLY.md`](propagation/APPLY.md); read
[`propagation/RISKS.md`](propagation/RISKS.md) first.

That is also why every prepared carrier in `propagation/` carries a `.staged`
suffix. The gates discover carriers by **exact filename**, so a draft named
`CLAUDE.md` sitting inside this repository would be counted as a real carrier
and would itself fail the gate.

### B. 4 gates failing inside the constitution submodule's own tree

These are failures **of the constitution repository**, not of this repository's
adoption. They cannot be fixed from here without writing into a submodule
working tree, and per §11.4.26 they belong upstream in
`HelixDevelopment/HelixConstitution`.

| Gate | Finding |
|---|---|
| `cm_continuum_resume_engine_present.sh` | a project-specific literal inside a reusable engine: `submodules/continuum/test/e2e/e2e_test.go` — a §11.4.28(B) decoupling violation |
| `cm_gate_ledger_ratchet.sh` | ratchet violated — `unimplemented=432` exceeds the checked-in `baseline=420` |
| `cm_track_branch_label.sh` | ALIAS-VALIDATION: the labeler yielded `xhigh`, not the expected synthetic alias |
| `cm_track_branch_label_mutation_test.sh` | its paired §1.1 mutation test, failing because the gate above fails |

### What "excluded" means, precisely

It means **"not this repository's to fix"**. It does not mean suppressed,
waived, or passing. All 21 still FAIL, all 21 still make the sweep exit `1`, and
the list exists so a reader can tell a structural finding from a new regression
— not so anyone can round `21 FAIL` down to zero.

### The wider gap picture

The sweep is one view. The full audit is [`INVENTORY.md`](INVENTORY.md), whose
G-identifiers the project `Constitution.md` tracks:

| Gap | State |
|---|---|
| G1 no consumer governance layer | **CLOSED** — four root agent carriers |
| G2 no inheritance pointer | **CLOSED** — all five carriers open with `## INHERITED FROM ` |
| G3 no post-pull validation sweep | **PARTIAL** — sweep exists, cascade verifier does not (OC-3) |
| G4 active CI contradicts §11.4.156 | ~~**OPEN** — OC-1 / OC-2, operator decision~~ → **PARTIAL** (2026-08-27) — decided *"Comply — disable both, enforce locally."*, then **partially reversed the same day**. `ci.yml` → `ci.yml.disabled`, gates local (umbrella compliant at file level); `milosvasic.ru/.github/workflows/pages.yml` stays **ACTIVE** — sole publish path for a production site, a **documented deviation, not an override**; `vasic.digital` non-compliant at the **provider** level with no file-level remedy. **Not CLOSED and will not close.** [Decision record](DECISION-11-4-156-COMPLY.md) §0 |
| G5 no §11.4.75 mechanical enforcement layers | **OPEN** — `.git/hooks/` holds only `*.sample` files |
| G6 no `helix-deps.yaml` | **CLOSED** — `helix-deps.yaml` at the root |
| G7 no propagation to owned submodules | **OPEN** — staged under `propagation/`, unapplied |
| G7b no `QWEN`/`GEMINI` project templates | **OPEN, upstream** — a gap in the constitution submodule |
| G8 §11.4.65 markdown export mandate | **OPEN** — no `.html` / `.pdf` siblings anywhere, this file included |
| G9 §11.4.212 README-orphan | **OPEN** — root `README.md` links to nothing but the CI badge |
| G10 §4 tag mirroring incomplete | **OPEN** — `v1.8.0` is on `milosvasic.ru` and `vasic.digital` only |
| G11 `design-toolkit` checked out twice | **OPEN** — declared in `helix-deps.yaml`; the shas match today |
| G12 §11.4.109 anti-forgetting layer absent | **OPEN** — the canonical guard script is in the submodule and wired nowhere |

> **Reading note.** The "Known open gaps" section inside the four root carriers
> was written before `helix-deps.yaml` and the two verifiers landed, and still
> lists **G3** and **G6** as open. The table above and the one in the project
> `Constitution.md` are the current state. Correcting the carriers is a
> five-carrier-lockstep edit and is therefore out of scope for a documentation
> change.

---

## 7. Open conflicts — operator decisions, not bugs

The project `Constitution.md` records three **open conflicts**: places where
this repository's live state contradicts a universal clause and **nobody has
decided what to do**. They are deliberately not filed as overrides — an override
is an authorization, and no one has given one.

> **Update 2026-08-27 — OC-1 is decided and closed at file level; OC-2 is
> decided the other way and stays OPEN.** The operator's first decision was
> *"Comply — disable both, enforce locally."* ~~Both workflows are renamed to a
> non-active `.disabled` name per §11.4.156(B), and the gates move to a local
> pre-push hook.~~ **That was partially reversed the same day.** `pages.yml`
> turned out to be the *sole* publish path for a live production website
> (`build_type: "workflow"`; no `gh-pages` branch, no `docs/` folder, Jekyll
> source at the root, and `_tools/deploy-langs.sh` merely pushes source and waits
> for that workflow). The operator's overriding directive, verbatim: ***"Make
> sure all pages websites work flawlessly! No website can be broken! All websites
> we have here are running deployed in production!"***
>
> **Net state:** `.github/workflows/ci.yml` → `ci.yml.disabled`, gates in a local
> pre-push hook — OC-1 resolved by compliance at file level.
> `milosvasic.ru/.github/workflows/pages.yml` is **ACTIVE and stays active** —
> OC-2 remains **open as a permanent documented deviation**. A third surface,
> **OC-2b**, is added below: `vasic.digital` triggers Pages Actions runs from its
> provider settings with no workflow file to disable.
>
> Crucially, **the `Override §11.4.156` listed below as resolution 2 turned out
> not to exist**: §11.4.156's closing formula refuses the exemption vocabulary by
> name, and the inheritance contract (*"extend them — they do NOT weaken or
> override any universal clause"*) makes a project-local override structurally
> impossible. **That still holds, and OC-2/OC-2b are not overrides either** — a
> deviation admits the clause applies and is knowingly unmet; an override would
> claim it does not apply. No constitution amendment was made. The OC-1/OC-2 text
> below is kept as the original record. Full decision, honest boundary and loss
> analysis: [`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) §0.
> **OC-2, OC-2b and OC-3 all remain open** — OC-3 genuinely undecided, OC-2 and
> OC-2b decided-and-accepted rather than resolved.

> The template `Constitution.project.md.template` offers `## Overrides` and
> nothing else; an "Open conflicts" section is **not specified** by it. It is an
> addition, marked as such in the project `Constitution.md`, because §11.4.6
> forbids reporting a state that was not verified and §11.4.156 names silence as
> the one option it does not allow.

### OC-1 — active CI at the repository root vs §11.4.156(A) — ✅ DECIDED 2026-08-27

*Original record retained below. Current state: comply — `ci.yml` renamed to a
non-active `.disabled` name, gates relocated to a local pre-push hook. Resolution
2 (`Override §11.4.156`) is void; see the update banner in §7 and
[`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md).*

§11.4.156(A):

> **(A) Zero active CI at the repository root.** No active
> `.github/workflows/*.yml|*.yaml`, no `.gitlab-ci.yml`, no `.gitlab/**`
> pipeline include, nor any equivalent provider config may exist at the ROOT of
> any governed repository/submodule — the only location a provider executes.

and its closing formula:

> Non-compliance is a release blocker regardless of context. No escape hatch —
> no `--allow-ci`, `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`,
> `--ci-exempt` flag.

**Live state.** `.github/workflows/ci.yml` exists at this repository's root
(9,526 bytes) with live `on: push` / `on: pull_request` triggers, and
`README.md` line 3 advertises it with a status badge.

**Why it is a conflict of intent, not neglect.** §11.4.156 moves enforcement to
the local §11.4.75 five-layer git-hook ritual. This repository has **none** of
those five layers (gap G5). Disabling the workflow today would delete the only
mechanical check that exists here and put nothing in its place.

Three resolutions exist; an agent may pick none of them unilaterally:

1. Disable per §11.4.156(B) (rename to `ci.yml.disabled-local-only`) **and**
   stand up the §11.4.75 local layers first, so enforcement moves rather than
   disappears. — ✅ **CHOSEN 2026-08-27.**
2. Record an explicit `Override §11.4.156` in the project `Constitution.md`,
   with the operator's justification. — ❌ **This resolution does not exist.**
   §11.4.156 refuses the exemption vocabulary by name, and a consumer carrier
   may only extend inherited rules, never weaken them.
3. Keep both and accept the release-blocker state knowingly. — ❌ Rejected;
   §11.4.156 makes non-compliance *"a release blocker regardless of context"*.

~~Nothing in this repository disables, edits, or re-enables that workflow.~~
**Superseded:** the workflow is being renamed under the decision record.

### OC-2 — the same clause, inside an owned submodule — ⚠ OPEN: PERMANENT DOCUMENTED DEVIATION (2026-08-27)

*~~Decided with OC-1: `pages.yml` renamed to a non-active `.disabled` name.~~*
**Reversed the same day, before anything was committed or pushed.** The
asymmetry the original note flagged turned out to be the decisive fact, and
sharper than recorded: `ci.yml` is a **test** workflow whose enforcement
relocates to the local hook, while `pages.yml` is a **deploy** workflow — and
`gh api repos/milos85vasic/milosvasic.ru/pages` returns `build_type: "workflow"`,
so it is the **sole** publish path for `https://milosvasic.ru/`. There is no
`gh-pages` branch, no `docs/` folder, and the repository root is Jekyll SOURCE,
so it cannot be served raw from a branch. `_tools/deploy-langs.sh` is not a
substitute — it pushes source, then `sleep`s waiting for that workflow to run.
Disabling it does not relocate a check or downgrade a deploy to manual; it
**ends** publishing for a live production site.

**Operator's overriding directive, verbatim:** ***"Make sure all pages websites
work flawlessly! No website can be broken! All websites we have here are running
deployed in production!"***

**`pages.yml` is ACTIVE and stays active.** `milosvasic.ru` is therefore a
**known, documented deviation** from §11.4.156 — **not** an `Override §11.4.156`,
which §11.4.156 forbids by name and which the inheritance contract makes
structurally impossible. Never record it as one. The
[`REMOTE-ASYMMETRY.md`](REMOTE-ASYMMETRY.md) §9 recommendation to extend an
override to this file remains void — there is no override to extend, and this is
not one. Full record:
[`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) §0.

`milosvasic.ru/.github/workflows/pages.yml` is an active root workflow in an
**owned** submodule, so §11.4.156(A) and (C) bind it exactly as they bind OC-1.
It is listed separately because acting on it means committing inside a submodule
working tree, which the project `Constitution.md` §102 reserves to the operator
— and because, unlike OC-1, the operator has decided it will not be acted on.

### OC-2b — `vasic.digital` triggers CI with no workflow file — ⚠ OPEN: NO FILE-LEVEL REMEDY

`vasic.digital` (`vasic-digital/vasic-digital.github.io`) has **no `.github/`
directory at all**, yet it is §11.4.156-non-compliant: its GitHub Pages source
setting alone starts an Actions run on every push. Verified 2026-08-27 —
`gh api .../pages` returns `build_type: "legacy"`, and the run list shows
`pages build and deployment` (`dynamic/pages/pages-build-deployment`) on
2026-08-27 and 2026-08-10. §11.4.156(A) addresses files at a repository root;
there is no file here to disable, so **no change to that tree can make it
compliant**. Only the operator, in the Pages UI, could stop the runs, and that
would unpublish a production site — which the directive quoted in OC-2 forbids.
Recorded, not resolved; and, like OC-2, **not an override**.

`submodules/superspec/.github/workflows/ci.yml` is deliberately **not** listed:
§11.4.156(C) scopes the clause to *"repositories we author + push"*, and
superspec is third-party.

### OC-3 — §11.4.32 step 1 has no cascade verifier to re-run

§11.4.32 step 1 requires the sweep to re-run
`scripts/verify-governance-cascade.sh`. That file does not exist in this
repository. `scripts/verify-all-constitution-rules.sh` therefore reports step 1
as an explicit **SKIP naming the missing file**, and never counts it as a pass.
Writing that verifier is remaining work, not a resolved item.

---

## 8. Document index

Everything under `docs/constitution-adoption/`. Line counts as of 2026-08-27.

| File | Lines | What it is |
|---|---|---|
| [`README.md`](README.md) | — | This file. Entry point: mechanism, verifiers, status. |
| [`INVENTORY.md`](INVENTORY.md) | 1104 | The original read-only gap analysis. Identifies the five-part adoption mechanism and quotes it, surveys agent files across the umbrella and every submodule, and ranks gaps G1–G12 (+G7b). Written **before** the carriers, manifest and verifiers landed; its per-gap statuses are historical, its quotations and measurements are not. |
| [`INDEX-COVERAGE.md`](INDEX-COVERAGE.md) | 489 | Verified CodeGraph + Lumen index-coverage report for the checkout. Adjacent evidence, not part of the adoption chain: it is what proves which trees the code-intelligence indexers actually reached. |
| [`propagation/APPLY.md`](propagation/APPLY.md) | 535 | The operator procedure for applying the staged carriers to the five owned submodules — survey, the conditional pointer form and why it differs from the root form, ordering (submodules first, umbrella last), per-submodule commands, post-apply verification, and an explicit list of what it does not do. |
| [`propagation/RISKS.md`](propagation/RISKS.md) | 219 | Blast-radius and honesty register for that procedure: push fan-out per repository, the `milosvasic.ru` fetch/push asymmetry, the superspec exclusion, and what could not be verified read-only. **Read before running anything in `APPLY.md`.** |
| [`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) | — | **The §11.4.156 decision record (2026-08-27, revision 2).** Why an `Override §11.4.156` was structurally unavailable, the four options and the choice, **§0's partial reversal** (`ci.yml` → `.disabled` with gates on a local pre-push hook; `pages.yml` **restored to ACTIVE** because it is the sole publish path for a production site; `vasic.digital` non-compliant at the provider level with no file-level remedy), the §11.4.6 honest boundary on provider-side settings, and what is lost — no server-side enforcement, `.git/hooks/` untracked so a fresh clone is unprotected until `scripts/pre-push-gates.sh --install` is run, and `git push --no-verify` bypasses the hook. |
| `CI-INVENTORY-11-4-156.md` | — | Per-file inventory of every CI surface considered under that decision, including the ones ruled structurally inert. Produced separately; **not present when this index row was written.** |

### Staged carriers awaiting operator application

19 drafts plus 1 insert-block, none applied. The `.staged` suffix is required —
see [§6.A](#a-17-propagation-gates--the-same-five-carriers-every-time).

| Target submodule | Files |
|---|---|
| `ai_interviewing` | [`AGENTS.md.staged`](propagation/ai_interviewing/AGENTS.md.staged) (25) · [`CLAUDE.md.staged`](propagation/ai_interviewing/CLAUDE.md.staged) (28) · [`GEMINI.md.staged`](propagation/ai_interviewing/GEMINI.md.staged) (25) · [`QWEN.md.staged`](propagation/ai_interviewing/QWEN.md.staged) (25) |
| `design-toolkit` | [`AGENTS.md.staged`](propagation/design-toolkit/AGENTS.md.staged) (25) · [`CLAUDE.md.staged`](propagation/design-toolkit/CLAUDE.md.staged) (28) · [`GEMINI.md.staged`](propagation/design-toolkit/GEMINI.md.staged) (25) · [`QWEN.md.staged`](propagation/design-toolkit/QWEN.md.staged) (25) |
| `milosvasic.ru` | [`AGENTS.md.staged`](propagation/milosvasic.ru/AGENTS.md.staged) (25) · [`CLAUDE.md.staged`](propagation/milosvasic.ru/CLAUDE.md.staged) (28) · [`GEMINI.md.staged`](propagation/milosvasic.ru/GEMINI.md.staged) (25) · [`QWEN.md.staged`](propagation/milosvasic.ru/QWEN.md.staged) (25) |
| `monetization` | [`AGENTS.md.staged`](propagation/monetization/AGENTS.md.staged) (25) · [`CLAUDE.md.staged`](propagation/monetization/CLAUDE.md.staged) (28) · [`GEMINI.md.staged`](propagation/monetization/GEMINI.md.staged) (25) · [`QWEN.md.staged`](propagation/monetization/QWEN.md.staged) (25) |
| `vasic.digital` | [`AGENTS.md.staged`](propagation/vasic.digital/AGENTS.md.staged) (25) · [`CLAUDE.md.staged`](propagation/vasic.digital/CLAUDE.md.staged) (28) · [`GEMINI.md.staged`](propagation/vasic.digital/GEMINI.md.staged) (25) · [`QWEN.insert-block.md`](propagation/vasic.digital/QWEN.insert-block.md) (17) — a block to **insert** into the existing 55-line `vasic.digital/QWEN.md`, never a replacement |

### Governed artifacts outside this directory

Not part of `docs/constitution-adoption/`, but the things it documents:

| Path | Role |
|---|---|
| `Constitution.md` | The project constitution — §101–§103, owned-submodule set, remotes, open conflicts, known-excluded findings, gap table |
| `CLAUDE.md` · `AGENTS.md` · `QWEN.md` · `GEMINI.md` | The four root agent carriers, byte-identical from line 24 |
| `helix-deps.yaml` | The §11.4.31 dependency manifest |
| `tests/test_constitution_inheritance.sh` | The inheritance gate + its `--prove-failure` mutation proof |
| `scripts/verify-all-constitution-rules.sh` | The §11.4.32 validation sweep |
| `submodules/constitution/` | The canonical corpus. Read it; do not copy from it |

---

## Related documentation

- [`../setup-agents-wizard/README.md`](../setup-agents-wizard/README.md) — the
  AI-agents setup wizard, which is what installs and configures the agents that
  read the root carriers described here.
