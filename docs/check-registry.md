# The check registry and its meta-check

`scripts/check-registry.tsv` + `scripts/verify-check-registry.sh`

## Why

`specs/001-workshop-curriculum-platform/spec.md` states two success criteria
quantified over *every* automated check:

- **SC-012** — every check has a paired demonstration that it FAILS when the
  guarded condition is broken. 100%, no exceptions.
- **SC-013** — the system distinguishes "unable to verify" from "passed" and
  "failed" in 100% of its checks.

Neither is evaluable without an enumeration of "every check". Per §11.4, a PASS
that cannot be evidenced is a bluff, so an unevaluable universal claim is worse
than no claim. The registry is that enumeration; the meta-check is what keeps it
true instead of aspirational.

The concrete motivation is measured, not theoretical. On 2026-09-01 two gates in
this tree were found with proofs that could not do their job:

- `scripts/verify-governance-cascade.sh --prove-failure` — its pre-flight control
  runs against the LIVE tree. The live tree had a real C8 violation, so the
  control failed, the mutation battery ran **zero** mutations, and the command
  exited 1 having proved nothing.
- a second gate exercised only sandboxed copies while its real entry point could
  not start.

Neither is visible from a summary line. `--run-proofs` sees both.

## Format

TSV, TAB-separated, field 1 is the row type from a closed vocabulary:

```
scanroot   <dir>
exempt     <path>  <reason>
check      <id>  <entry-point>  <proof-kind>  <proof-arg>  <undet-probe>
debt       <id>  <entry-point>  <owed>        <reason>
```

Full field semantics, including why TSV rather than YAML, are in the header of
`scripts/check-registry.tsv` itself. In short: the governance submodule already
keeps every gate ledger as TSV parsed with `cut -f1`, typed rows from a closed
vocabulary are already a governance requirement here
(`submodules/constitution/scripts/gates/cm_ledger_row_typed_from_closed_vocabulary.sh`),
and TSV needs no `python3`/`yq` — a pre-push instrument must not have a parser
that can fail to load and then report a tree it never read.

## Anti-drift

A hand-maintained list rots. Both directions are closed:

- **outward** — every registered path must exist; a dead row is a FAIL.
- **inward** — every `*.sh` under a declared `scanroot` must appear in some row.
  A new check dropped into `scripts/` and not registered is a **FAIL**, not an
  omission. This is the half without which the registry is decorative.
- **ratchet** — a `debt` row whose owed property is found SATISFIED is a FAIL
  ("stale debt — promote it"). Debt may hide a gap; it must not hide a fix.

## Exit codes

`0` all registered checks conform · `1` a real conformance violation ·
`2` could not determine (registry missing/unreadable/malformed, scanroot absent,
probe timed out). The instrument is not exempt from its own SC-013 rule.

Registered **debt** does not block a default run. It prints on every run and is
never reported as compliance. `--strict` turns each debt row into a failure.

## Modes and cost

| mode | what it does | measured wall clock |
|---|---|---|
| default | proof STRUCTURE + executes every rc-2 probe | **0.8–1.1 s** |
| `--prove-failure` | its own §1.1 paired mutation proof (10 mutations) | **5.6 s** |
| `--run-proofs` | additionally EXECUTES every registered paired proof | **243 s** |

The trade is declared rather than silently sampled: executing every paired proof
is the strongest evidence and is far too slow for a hook, so the default run
verifies structure and says in its own summary that it observed no proof
actually run. Nothing is skipped at random.

## Wiring it into the pre-push hook

Not wired by this change — that is the controller's call once the debt below is
scheduled. When wired, it belongs in `scripts/pre-push-gates.sh` as a new gate
id in `GATE_IDS`, with:

```bash
gate_N() { bash "$ROOT/scripts/verify-check-registry.sh"; }
# name:       check-registry conformance (SC-012 / SC-013)
# provenance: docs/check-registry.md
```

Two cautions specific to that host:

1. ~~`pre-push-gates.sh` maps **every** non-zero child rc to `FAILED`.~~
   **WITHDRAWN, re-verified 2026-09-01.** `run_gate` now has a distinct `UNDET`
   verdict for a child rc=2 (around lines 512-518), the summary prints
   `undetermined=` as its own counter, and an undetermined run says "COULD NOT
   DETERMINE a verdict" and blocks *without* accusing the tree. A
   `verify-check-registry.sh` rc of 2 is therefore reported as what it is. The
   debt row below was narrowed to `proof` accordingly.
2. Run it **default mode** in the hook (≈1 s). `--run-proofs` at 243 s does not
   belong on a push path; it belongs in a pre-tag / release sweep.

## The conformance gap, as of 2026-09-01

Determined empirically by running each entry point, not by reading its prose.
Re-derive with `bash scripts/verify-check-registry.sh`.

Conforming (paired proof **and** demonstrated rc-2): `constitution-inheritance`,
`governance-cascade`, `manifest-pins`, `continuation-sync`, `provider-ci`,
`check-registry`, `hardcoded-paths`, `content-boundary`,
`environment-assumptions`, `submodule-remote-sync`, `mutation-anchor-rot`,
`private-object-exposure`.

Measured 2026-09-01 after `private-object-exposure` was registered:
**29 PASS / 0 FAIL / 5 DEBT / 0 UNDET, exit 0**, R5 green. That is a count of
PASS *assertions* (each conforming check contributes an SC-012 row and an
SC-013 row), not a count of checks.

Owed:

| check | owes | note |
|---|---|---|
| `scripts/verify-all-constitution-rules.sh` | proof | rc-2 verified; nothing demonstrates the sweep fails when a child gate is silently dropped |
| `scripts/lumen-index-doctor.sh` | proof | rc-2 verified |
| `scripts/ollama-tune.sh` | proof | rc-2 verified |
| `scripts/pre-push-gates.sh` | proof | rc-2 now implemented (see the withdrawal above); only the paired proof is still owed |
| `scripts/test-setup-agents-wizard.sh` | proof, three-valued | asserts three-valued behaviour in the wizard it tests; implements none for itself |

### The inoperative-proof defect — closed for two, found in a third (2026-09-01)

`--run-proofs` used to report `governance-cascade` and `manifest-pins` as proofs
that could not pass. Both ran their control against the **live tree**, so any
real violation made the control fail and the battery never started. Measured by
copying each script into a tree that was not a green checkout: both exited
non-zero having run **0 mutations**.

Both are now **FIXED**. Each has a synthetic control that is green by
construction, and the live run is demoted to a REPORTED pre-flight that cannot
disable the battery — the shape `verify-check-registry.sh --prove-failure` uses.
Re-measured against the same red tree: `manifest-pins` runs **10/10** mutations,
`governance-cascade` runs **11/11**. The same shape was used for the two new
audit proofs (10 mutations each).

A **third** instance is now visible and is *not* fixed: `continuation-sync`
(`scripts/continuation-check.sh --prove-failure`) also baselines against the
live tree, so it reports `PROOF FAIL baseline, unmutated` whenever
`CONTINUATION.md` is stale — which it is today, because commits `7b4df26d`,
`4ee9e8de` and `b0ab4b44` changed watched governance files without updating it in
the same commit (§12.10 protection 2). (Those three were cited as `d0b3c64`,
`96b2988` and `ee3933d` until 2026-09-01; all three were rewritten by the
authorized content-boundary remediation of that date and no longer resolve. The
old→new mapping is in `docs/content-boundary-incident-2026-09-01.md` §8B.) It is a *degraded* rather than an
inoperative proof: its six mutations and its rc-2 branch all still execute and
pass. It was deliberately left alone because a synthetic control for it must make
C7 (the §6 gate table vs the live runner) and C8 (production workflow facts)
green by construction, and the runner it compares against —
`scripts/pre-push-gates.sh` — was under concurrent edit.

Consequence, stated rather than implied: `bash scripts/verify-check-registry.sh`
is **rc 0**, but `--run-proofs` is **rc 1** on account of that one row.

## Declared scope boundary

The scanroots are `scripts/` and `tests/`. `_tools/` and `_tests/` hold further
gates that `pre-push-gates.sh` runs (`_tools/audit-hardcoding.sh`,
`_tools/translate/reproducibility-selftest.sh`, `_tools/portfolio/self-validate.sh`,
`_tests/run-harness-selfvalidation.sh`) and are **not** swept yet. That is a
declared boundary, not a claim that they conform. Widening it is a one-line
`scanroot` addition.

## `submodule-remote-sync` — added 2026-09-01

| field | value |
|---|---|
| row | `check	submodule-remote-sync	scripts/verify-submodule-remote-sync.sh	flag	--prove-failure	--root /nonexistent` |
| entry point | `bash scripts/verify-submodule-remote-sync.sh` |
| paired proof | `bash scripts/verify-submodule-remote-sync.sh --prove-failure` |
| rc-2 probe | `--root /nonexistent` |

### What it closes

It closes a blind spot that was structural, not accidental. Cascade check C9 and
`scripts/verify-manifest-pins.sh` both answer *"does `helix-deps.yaml` agree with
the gitlink this repository will commit?"* — a purely **local** comparison.
Neither has ever contacted a remote: on 2026-09-01 a grep for `ls-remote` and
`git fetch` across `scripts/*.sh` returned **nothing**. So both exited **0** all
day while `submodules/constitution` sat behind its upstream, and the root
carriers had to warn readers in prose that *"the pin is BEHIND its upstream, and
no gate in this tree catches that"*. Prose is not a gate.

The two instruments answer different questions and neither replaces the other:

| instrument | compares | question |
|---|---|---|
| `manifest-pins` (C9) | manifest `ref` vs local gitlink | is the RECORD true? |
| `submodule-remote-sync` | local gitlink vs remote tip | is the PIN fresh? |

Both can be green while the tree is stale. Only together do they mean "what we
recorded is what we will commit, and what we will commit is what upstream has".

### Contract

Three-valued, and **state 2 outranks state 1**:

- **0** — every owned gitlink was compared and equals its remote tip.
- **1** — at least one owned gitlink differs, reported as **BEHIND**
  (fast-forwardable), **AHEAD** (the gitlink is an UNPUSHED commit, so the tree
  does not clone for anyone else) or **DIVERGED** (operator reconciliation;
  never automate). These have different remedies and are never conflated.
- **2** — COULD NOT DETERMINE: offline, DNS failure, SSH auth refused, remote
  gone, probe timeout, or `git` absent. **A network failure must never read as
  "current"** — that would replace an old blind instrument with a new one.

The fleet is **derived** on every run from `.gitmodules` plus `helix-deps.yaml`;
there is no roster in the file. Ownership is classified from evidence — a path
documented in the manifest's third-party comment block is reported but never
gates, because upstream's release cadence is not ours to fix. Measured
2026-09-01 that classifies `submodules/superspec` third-party and the other 12
owned, without the script naming either.

### First real run, 2026-09-01

**exit 1** — 10 CURRENT, 2 DRIFT, 0 UNDETERMINED of 12 owned gitlinks probed, 13
declared. `design-toolkit` and `ai_interviewing` are both **BEHIND** their
remotes and fast-forwardable. Neither was visible to any pre-existing gate.

### Paired proof

`--prove-failure` builds real local git repositories in a `mktemp -d` sandbox
wired by `file://` remotes, so `ls-remote` exercises the real code path with **no
network involved**. Six states, each asserted separately: CURRENT→0, BEHIND→1,
DIVERGED→1, AHEAD→1, UNREACHABLE→**2 (never 0)**, third-party-behind→0, plus a
restored control. The unreachable case is the one an unproven instrument would
get wrong, and it is the reason the gate exists.

Additionally seeded against the **live** tree: forcing every remote unreachable
(`GIT_SSH_COMMAND=false`) yielded **12 UNDETERMINED, rc=2**, and removing the
mutation restored the pre-mutation verdict of rc=1.

## `private-object-exposure` — added 2026-09-01

| field | value |
|---|---|
| row | `check	private-object-exposure	scripts/verify-private-object-exposure.sh	flag	--prove-failure	--root /nonexistent` |
| entry point | `bash scripts/verify-private-object-exposure.sh` |
| paired proof | `bash scripts/verify-private-object-exposure.sh --prove-failure` |
| rc-2 probe | `--root /nonexistent` |

### What it closes

A hazard that was found, written down, and then guarded by nothing but the
sentence that recorded it. `docs/content-boundary-incident-2026-09-01.md` §8A.6
states it exactly:

> *"It is recorded here because a local-any hazard that nothing checks is one
> accidental `git push --all` away from being a much larger incident than this
> one."*

(The document's own wording is "a local-only hazard"; the point is unchanged.)

The concrete state, measured 2026-09-01 before the operator acted: the local
branch `backup/pre-untrack-git-backup-a8137db` carried **96 files** that were a
copy of the PRIVATE `milos85vasic/workshop_curriculum` object store, including a
**1,870,772,012-byte** packfile, inside the **PUBLIC** `milos85vasic/vasic`. It
was not an ancestor of `main` and `git ls-remote` showed it was never pushed.
`.git/hooks/` is untracked, so a fresh clone runs no hook at all. Nothing in the
tree could say any of that.

**The branch has since been removed** (`docs/branch-removal-2026-09-01.txt`),
and that changes nothing about this check. It guards the whole **category**
rather than that one branch: the §9.3 habit that produced it — copy a
submodule's `.git` into the umbrella before a destructive operation — is the
correct habit and will produce another one. Not one line of the detection reads
a branch name, so the removal did not alter a single code path. What changed is
only which state the tree is in, and the check reports that state precisely
rather than going quiet.

### Why a rename cannot defeat it

The detector reads **no** branch name, directory name, commit message or date.
It keys on the internal layout and byte magic that a copied repository must keep
in order to still be a repository:

| id | evidence | read from |
|---|---|---|
| E1 | `PACK` + pack version 2/3 | blob content |
| E2 | `\377tOc` + index version 2 | blob content |
| E3 | zlib stream that inflates to a git loose-object header | blob content |
| E4 | `HEAD` holding `ref: refs/…` or a bare 40-hex sha | blob content |
| E5 | `config` holding `[core]` and `repositoryformatversion` | blob content |
| E6 | `packed-refs` beginning `# pack-refs with:` | blob content |

A directory is judged a foreign object store on **≥2 evidence classes, at least
one of them an objects-layer proof (E1/E2/E3)**. Path shape is a cheap
pre-filter and never a verdict.

Everything found this way is foreign *by construction*: git will not track its
own `.git`, so an object store appearing in `git rev-list --objects` output is
necessarily a copy of some other repository, committed as content. Provenance,
when available, comes from E5 — the captured `config`'s `url =` lines — and is
matched against the private half of the fleet.

### Scope — the general class, three layers

| layer | question | source of truth |
|---|---|---|
| A | does any object reachable from **any** ref, or staged in the index, belong to a foreign object store? | `git rev-list --objects --all --indexed-objects` — exactly what `--all` / `--mirror` publish, plus what `git add .` would commit next |
| B | is a submodule's tree committed as **files** instead of a gitlink, or is its path not a repository checkout at all? | `.gitmodules` paths+urls, corroborated against `helix-deps.yaml`; visibility from `gh` |
| C | is a foreign object store in the worktree held off by nothing but `.gitignore`? | `find` + the same byte magic, then `git ls-files` / `git check-ignore` |

No roster is hardcoded. Measured 2026-09-01 the fleet derives as **13 declared
submodules: 10 public / 3 private / 0 visibility-undetermined** — re-derive, do
not quote it.

**Pushable vs reflog-only, graded apart.** Layer A takes *two* enumerations: the
pushable set (`--all --indexed-objects`) and the union that adds `--reflog`.
`git branch -D` unhooks a store from every ref but leaves its objects in the
object database until `gc --prune=now`. `git push` cannot publish an object no
ref reaches, so calling that an exposure would be a false finding — and going
silent about it would be worse, because one reflog checkout puts it back on a
ref. It is therefore an **unsuppressible NOTE at rc 0**, and the paired proof
asserts both halves: rc 0, *and* the store still named in the output.

**Reading a captured pack without a repository.** For each store the check runs
`git show-index` on the captured `.idx` blob. That parses a pack index with **no
repository and no `.pack` file**, which matters because a captured store's
`config` can carry a stale `worktree =` line that makes every ordinary git
command abort. On 2026-09-01 three consecutive attempts to read exactly such a
store in this tree reported *"0 commits, nothing here"* — and every one of them
was an **aborted query**, not a measurement. The census also compares the
store's own refs (`packed-refs`, `refs/**`, a detached `HEAD`) against the
objects it actually holds, so an **incomplete capture** — a backup that would not
restore — is reported as one. A census that cannot be taken prints as *unknown*,
never as *empty*.

### Contract

Three-valued, and **a confirmed failure outranks an undetermined**:

- **0** — no foreign object store anywhere, no submodule content committed as
  files, every declared submodule path a real repository checkout.
- **1** — a determined finding.
- **2** — could not determine: no root; root not a repository **toplevel**;
  `git rev-list` failed; `.gitmodules` present but unparseable; a submodule
  path that cannot be classified; or a submodule whose state needs grading
  while its provider visibility is unknown.

**When an unknown visibility is deliberately *not* an rc-2**, stated so it is
never read as leniency: a submodule contributing zero objects to this
repository's history whose path is a real checkout has no content here to
expose. No provider answer could change that structural fact, so none is
demanded. Visibility is required — and its absence escalated — exactly where it
would change the verdict.

**The `rev-parse` walk-up trap.** `git -C <dir> rev-parse --git-dir` *succeeds*
inside an empty directory nested in a repository, because it walks **up** and
finds the parent's `.git`; a check written that way reads an uninitialised
submodule as healthy. Every repository test here instead requires the directory
to **be** the resolved toplevel (`rev-parse --show-toplevel`, both sides made
physical with `pwd -P`, compared for equality). The paired proof asserts this
directly rather than describing it.

The guard is **read-only**. It never writes, deletes, renames, force-updates or
pushes a ref. Removing a backup is an operator decision under §9.3.

### Two real runs, 2026-09-01, either side of the operator's removal

**Before — exit 1**, 2 findings, 0 undetermined:

1. foreign git object store at `workshop-git-backup-2026-08-29`, **6 of 6**
   evidence classes, largest packfile 1,870,772,012 bytes, provenance
   `milos85vasic/workshop_curriculum`, carried by
   `refs/heads/backup/pre-untrack-git-backup-a8137db`;
2. that store is a copy of a **PRIVATE** repository held inside a **PUBLIC** one.

**After the branch was removed — exit 0**, 0 findings, 0 undetermined, **3
unsuppressible notes**. The same store is still detected, now classified
`REFLOG-ONLY`: unreachable from every ref and from the index, therefore not
publishable by any `git push`, with its objects still in the object database
until a `gc --prune=now`. The gate says so on every run rather than falling
silent.

Its census, read from the `.idx` files alone: **8 objects across 2 index
files** — the 1.78 GB pack indexes exactly **one**. That is the measured basis
for "this was never a history backup".

One correction, recorded because it was arrived at by a narrower read: the
store's `packed-refs` names `59460387d331…`, which the **large** pack does not
contain — but the **small** pack does (`git show-index` on
`pack-ef685738….idx`, line 5). Taken across the whole store, all **2** refs
resolve, and the gate reports exactly that. "The pack does not contain it" was
true; "the backup would not restore" did not follow from it.

Plus the standing worktree NOTE: a 3,742,068,523-byte copy of the same store
sits in the working tree, untracked **only** because of `.gitignore:90
workshop-git-backup-*/`. Given that this project's commit wrapper runs
`git add .` (INVENTORY gap G5), that line is the whole of the protection.

### Paired proof

`--prove-failure` builds a throwaway repository under `mktemp -d` with an
isolated `HOME` and `GH_CONFIG_DIR`, and never touches the real tree. Measured
2026-09-01, **all assertions pass, rc 0**:

| step | assertion | measured |
|---|---|---|
| GREEN | ordinary repository | rc 0 |
| RED | a **real** foreign store (verified `PACK` magic `5041434b00000002`) committed at `assets/vendor-data` on branch `wip/notes` | rc **1** |
| DECOY | `docs/samples` carrying packfile-, idx- and loose-object-**shaped** paths plus `HEAD`, `config` and `packed-refs`, all with non-git bytes | **not** flagged |
| REFLOG | branch deleted, reflog kept | rc **0**, *and* `REFLOG-ONLY` still named — asserted both ways, because a silent 0 is indistinguishable from a clean tree |
| GREEN | `reflog expire --expire=now --all` + `gc --prune=now` | rc 0, subject sha256 unchanged, 0 files dirtied |
| UNDET | `--root /nonexistent` | rc 2 |
| UNDET | a directory that is not a repository | rc 2 |
| UNDET | an **empty** submodule dir nested in a repo — `rev-parse --git-dir` returns the parent's `.git` with rc 0 | rc 2, and the walk-up is the *named* reason |

The `reflog expire` / `gc --prune=now` above run **inside the `mktemp -d`
sandbox only**; the guard itself never runs either, and the real tree is not
touched by any mode of this file.

Three of those rows are the ones that matter. The **decoy** is what separates
content detection from a name match: without it, "a rename cannot defeat this"
would be a claim rather than a demonstration. The **empty nested directory** row
asserts both the rc and that the uninitialised submodule is the stated cause — an
rc 2 arrived at for an unrelated reason would prove nothing about the trap. The
**reflog** row is asserted both ways for the same reason in the other direction:
an rc 0 that says nothing cannot be told apart from a clean repository.

The mutant's names are asserted at runtime to contain none of `backup`,
`workshop`, `git-backup`, `.git`, `objects-copy` or `mirror`; if any did, the
proof aborts with rc 2 rather than crediting itself.

### Wiring, and what was deliberately not done

This is a **gate**, and the gate is the guarantee. It was **not** wired into
`scripts/pre-push-gates.sh`, for two reasons stated rather than implied:

1. `git push --no-verify` bypasses hooks entirely, and `.git/hooks/` is
   untracked, so a hook is a convenience and never the guarantee. A guard whose
   only home is a bypassable hook is not a guard.
2. `scripts/pre-push-gates.sh` was under concurrent edit by its owner (the same
   reason the `prepush-gates` debt row above records for not touching it), and
   its `GATE_IDS` array is a hardcoded list, so adding a gate means editing that
   file. Doing so from a change that does not own it is how two agents produce
   one broken runner.

The wiring, when its owner takes it, is one id in `GATE_IDS` and one `run_gate`
arm; the entry point takes no arguments and already returns the 0/1/2 the runner
expects. It deliberately does **not** accept the hook's stdin refspecs: it always
scans every ref, because restricting it to the refs being pushed would make it
blind to precisely the `--all` / `--mirror` case it exists for.

## `remedy-executability` — added 2026-09-01

`scripts/verify-remedy-executability.sh` — **every documented way out must
actually exist.**

### What it closes

`GET /api/chapters/{chapter}/accuracy` served a correct, honest body:

```json
{"measured": false,
 "reason": "verify-accuracy has not been run for this chapter",
 "remedy": "bash workshop/scripts/verify-accuracy.sh <chapter> --reference <path>",
 "wer": null}
```

and `ls workshop/scripts/verify-accuracy.sh` reported **no such file**. The
endpoint was not wrong about the measurement — it was right that none had been
taken. It was wrong about the **way out**, which is the part a reader acts on.
Accuracy was not un-measured; it was **un-runnable by the documented command**,
and under §11.4.6 that is a bluff: the body asserts a path to resolution that
cannot be walked, and the reader cannot tell without trying it.

**Nothing in this tree was checking.** Every gate here verifies its subject; not
one verified its own advice. A remedy string is the only output a gate produces
that the reader is expected to **execute**, and it was the only output nothing
graded. That is the class this closes — not the single string.

### Derivation, and the declared scope boundary

**Candidates are derived, never listed.** The tree is scanned for the marker
forms it actually emits and whatever is found is graded:

| Form | Example |
|---|---|
| structured key | `"remedy": "…"` in JSON and Go map literals |
| Go const | `const AccuracyRemedy = "…"` (any `*Remedy` identifier) |
| line marker | line-leading `Remedy:` / `Fix:` / `Run:` / `Try:` / `try:` |

A payload-free marker yields no candidate, which is why Python's `try:` — always
payload-free — does not flood the corpus.

**Scope is declared**, following the `scanroot` convention this registry already
established: `scripts`, `tests`, `workshop/scripts`, `workshop/platform`,
`workshop/pipeline`, `workshop/docs`, `_tools`, `_tests`, `docs`, printed on
every run and overridable with `--scanroot`. `ai_interviewing/` and the two site
submodules are **out of scope**: their `Fix:` lines are prose about software
engineering in general, not remedies this platform emits. A declared boundary is
not a claim that what lies outside it conforms. Vendored and generated trees
(`node_modules`, `venv`, `vendor`, `pipeline/engines`, `pipeline/models`,
`dist`, `_site`, `testdata`, `.specify`) are pruned: counting an upstream's
broken advice as this tree's finding would be a claim with no remedy attached,
which is this gate committing its own defect.

The gate **does not exclude itself**. Its own header quotes the accuracy
endpoint's remedy, and that string is graded on every run like any other.

### Command vs instruction — the discriminator, and why it is safe

Not every remedy is a command. *"Ask your administrator to install podman"* is a
legitimate remedy and there is nothing to resolve. The rule is stated, not
implied:

> A remedy is a **COMMAND** when it names a **subject a shell can start** — a
> path-shaped token (`dir/file.ext`, `./file`, an absolute path), or a head
> token that resolves on `PATH` **to an executable**.
>
> A remedy is an **INSTRUCTION** when it names no such subject. It addresses a
> person; there is nothing here to resolve; it is not a defect.

**The property that makes this safe: classification never consults whether the
subject exists.** Path-shape is lexical, so `bash scripts/nope.sh` is a COMMAND
that FAILS — never an instruction that passes. A broken remedy cannot be
reclassified into the harmless bucket by virtue of being broken. That inversion
is excluded by construction rather than by care.

Tokens holding a placeholder or an expansion — `<path>`, `${VAR}`, `$1`, `*` —
are **not** subjects. They are holes the reader fills, and resolving them would
be resolving the gate's own guess.

One narrow prose test refines the ambiguous branch only. The measured case:

```go
"remedy": "install a working ffprobe or ffmpeg on the host that runs " + …
```

whose head token `install` is coreutils, so a head-resolves rule alone calls an
operator instruction a command. A payload carrying bare English articles and
prepositions as standalone words is treated as prose. It is applied **only**
where no path-shaped subject was found, so it can never hide a broken file
remedy.

### Existence is not enough — the operation is exercised

Measured on the development host, 2026-09-01:

```
command -v ffprobe   ->  /usr/bin/ffprobe   (found)
ffprobe -version     ->  exit 0             (runs)
ffprobe -show_format ->  exit 8             (UNUSABLE)
```

Present, executable, and unable to do the thing it is named for. So for every
**file subject** the gate does not stop at `-e`: readable, non-empty, a regular
file; either the executable bit **or** an explicit interpreter named in the
remedy itself; that interpreter (or the shebang's) resolved on `PATH`; and then
the file is **parsed with that interpreter's own syntax check** — `bash -n` for
shell, `ast.parse` for Python. That exercises exactly what the remedy promises,
"this can be started", and it catches the present-but-broken case without
executing anything.

Relative subjects are resolved from the emitting file **outward to the root**,
because a remedy written inside `workshop/` may spell a path from the module
root while the same string served over HTTP spells it from the repository root.
Both are correct; a gate that knew only one would invent findings.

**Honest boundary (§11.4.6).** For an EXTERNAL head token — `git`, `podman`,
`npm` — the gate proves **existence only**. It does not run them: the corpus
contains `git push`, and this repository contains a deploy script that fired at
two live production sites when it was run by accident today. Executing
discovered strings is not a safety trade this gate is willing to make. Those are
counted, listed under an unsuppressible NOTE, and `--strict` turns them into
rc 2. **A NOTE is not a pass; it is a stated limit.**

### Contract

Three-valued, and **a confirmed failure outranks an undetermined**:

- **0** — every remedy that names something resolves to something startable.
- **1** — a remedy names a file that is absent, unreadable, empty, not
  executable with no interpreter given, whose interpreter is missing, or which
  does not parse. A reader following it would fail.
- **2** — the question could not be answered: `--root` is not a directory, a
  declared scanroot does not exist, `grep` is absent, or **the scan matched
  nothing at all**. A gate that inspected nothing has not reported a clean tree;
  it has failed to run.
- `--strict` additionally promotes the EXTERNAL note to **2**.

### First real run, 2026-09-01

**exit 0** — 23 remedy strings: **10 resolve, 0 BROKEN, 1 external, 12
instruction**. The ten that resolve include the accuracy endpoint's own
`AccuracyRemedy` const, three `ingest.sh` remedies in `chapters.go`, two
`extract-videos.sh` remedies in `recording.go`, and `workshop/docs/faq.md`'s
`scripts/build.sh`. `--strict` yields **2** on the one external remedy
(`git`), as designed.

Two defects in the gate itself were found and fixed by that first run, and both
are recorded here because a gate that invents subjects grades nothing:

1. **Glob expansion.** Payload tokenisation uses an unquoted expansion, so a
   payload containing `**` (markdown emphasis — every `**Run:**` line in these
   docs) globbed against the working directory. The gate reported a remedy
   naming `AGENTS.md`, a file that appears in no remedy anywhere. Fixed with
   `set -f`.
2. **`command -v` is not "is a command".** `command -v AGENTS.md` succeeds on
   this host, because a directory holding a markdown file is on the operator's
   `PATH`. Resolution now requires `type -t` plus an executable, non-directory
   target.

### Paired proof (§1.1)

`--prove-failure` builds a throwaway lab — never the real tree — and asserts six
states, each separately:

| State | Expected |
|---|---|
| remedy names a script that exists and starts | 0 |
| remedy repointed at a nonexistent script | **1**, not 2 |
| restored byte-identically (checksum-proved) | 0 |
| **second, independent mutation**: subject present but unparsable | **1** |
| operator instruction (`ask your administrator to install podman`) | 0, and classified INSTRUCTION |
| empty scan | **2** |

The mutant is asserted to still **parse** (`bash -n`) before the gate is run
against it — a gate that only reddens on a syntax break proves nothing. The
second mutation exists because absence and unstartability are different
failures, and a gate catching only the first would pass a remedy naming a script
that exists and is broken.

**The strongest evidence is not synthetic.** The gate was run against a
reconstruction of this repository's own pre-fix state — `accuracy.go` beside
every `workshop/scripts/*.sh` **except** `verify-accuracy.sh`:

```
MISSING  workshop/platform/backend/internal/api/accuracy.go:26
         | remedy:  bash workshop/scripts/verify-accuracy.sh <chapter> --reference <path>
         | subject: workshop/scripts/verify-accuracy.sh — resolves nowhere
rc=1
```

Adding the script back to the same lab and re-running the same command yields
**rc=0**. The mutation is the real history, not an invention.

### Wiring, and what was deliberately not done

Registered as a `check` row; **not** wired into `scripts/pre-push-gates.sh`, for
the same two reasons the `private-object-exposure` section records: a hook is
bypassable by `git push --no-verify` and `.git/hooks/` is untracked, so the hook
is never the guarantee; and `pre-push-gates.sh` carries a hardcoded `GATE_IDS`
array and was under concurrent edit by its owner. The wiring, when its owner
takes it, is one id and one `run_gate` arm — the entry point takes no arguments
and already returns the 0/1/2 the runner expects.
