# vasic — CLAUDE.md

## INHERITED FROM submodules/constitution/CLAUDE.md

All rules in `submodules/constitution/CLAUDE.md` (and the
`submodules/constitution/Constitution.md` it references) apply unconditionally
to this project. Project-specific rules below extend them — they do NOT weaken
or override any universal clause.

When this file disagrees with the constitution submodule, the constitution wins.

> Base agent rules: `submodules/constitution/CLAUDE.md` — READ IT FIRST.
> The base file is authoritative for any topic not covered here.
> Locate it from any nested depth with
> `submodules/constitution/find_constitution.sh`.

This carrier is read by
Claude Code (claude.ai/code).
It is one of the four repository-root governance context carriers
(`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) that anchor 11.4.157
requires to be maintained in lockstep. Everything below this paragraph is
byte-identical across all four; only this opening section differs.

### Where the canonical rules actually live

Nothing is copied here. This file is a pointer; the authority is the submodule.

| What | Canonical path in this repository |
|---|---|
| The universal constitution (11,700 lines, 252 `### §` anchors, 1,779,401 bytes, measured 2026-09-02 at pin `3be10826f3d2`; the SAME `Constitution.md` blob `34eff9d8…` as all three superseded pins `902979027a90`, `f16ea779b82a` and `f5876a3b700e`, so these figures did not move across any of the three bumps) | `submodules/constitution/Constitution.md` |
| Claude Code carrier | `submodules/constitution/CLAUDE.md` |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi CLI carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Full anchor corpus companion | `submodules/constitution/CLAUDE_ANCHORS_FULL.md` |
| Parent-walk resolver (works from any nested depth) | `submodules/constitution/find_constitution.sh` |
| Post-pull governance hook | `submodules/constitution/scripts/post_update_hook.sh` |
| Forbidden-command PreToolUse guard | `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` |
| Propagation / covenant gates | `submodules/constitution/scripts/gates/` |

**The pin has now been FAST-FORWARDED TWICE — 2026-09-01 on explicit operator
authorization, and again since. Each bump closed one INSTANCE of the gap; the
HOLE that let the first one open unnoticed is now WATCHED, and as of 2026-09-02
the watcher is GREEN for the first time.** `submodules/constitution` is
currently checked out at `3be10826f3d2`, on branch `main`, and that **EQUALS**
`git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD`.
Every earlier "checked out at X" in this block is WITHDRAWN, and the sequence is
kept because it is the whole lesson: **a pin bumped to equal its upstream does
not stay equal** — this one went stale within a day, twice, before the third
move caught it up.

    902979027a90  ->  f16ea779b82a    2026-09-01, operator-authorized, 0 divergent / 3 behind
    f16ea779b82a  ->  f5876a3b700e    0 divergent / 4 behind
    f5876a3b700e  ->  3be10826f3d2    2026-09-02, operator-authorized, 0 divergent / 2 behind
    remote HEAD today                 =  3be10826f3d2     -- EQUAL, no drift

Re-measured 2026-09-02. The index and the submodule working tree both sit at
`3be10826f3d2`; the umbrella's `HEAD` still records `f16ea779b82a`, so the whole
two-step move is **STAGED and not yet committed**. `helix-deps.yaml` records
`3be10826f3d2` staged in the same change, so gitlink and manifest moved together
exactly as C9 requires. `bash scripts/verify-submodule-remote-sync.sh` now exits
**0** at **12 CURRENT / 0 DRIFT / 0 UNDETERMINED**.

**The third move was operator-authorized and CLASSIFIED BEFORE it was made** —
the `--fetch` that earlier revisions correctly refused to run unasked. It
resolved the previously UNDETERMINED direction: `merge-base --is-ancestor
f5876a3b 3be10826` TRUE, `rev-list --left-right --count` `0` / `2` — **2 behind,
0 divergent** — and `git merge --ff-only` performed it, which would have refused
anything else. `diff --stat` touches **two files, both inside the constitution's
own `scripts/gates/`**; no governance document, no carrier, not
`Constitution.md`.

**C9 went FAIL for exactly as long as the manifest was ahead of the index, and
that is the gate working.** Moving `helix-deps.yaml` first left the recorded ref
at `3be10826` while `git ls-files -s` still reported `f5876a3b`;
`verify-manifest-pins.sh` read `11 MATCH, 1 DRIFT` until the gitlink was staged,
then returned to **12 MATCH / 0 DRIFT**. **Stage the gitlink and the manifest
together, or the gate will — correctly — call you out.**

**Do not read any SHA in this file as current; run the gate.** Two consecutive
sessions have now bumped this pin and found it behind upstream again within the
day. Treat the constitution pin as a standing operator decision, not a task that
completes.

**Nothing this repository records about the corpus moved in either bump.**
`Constitution.md` is the SAME git blob `34eff9d86cadb325721c958d35a411feaad27681`
at all four pins — re-measured ON DISK at `3be10826f3d2` as **11,700 lines, 252
`### §` anchors, 1,779,401 bytes**. The second bump's `diff --stat` touches two
paths, neither a governance document: `design-toolkit` (1 −) and
`docs/codegraph/Status.md` (18 +). That is a measured coincidence of what
upstream happened to change, **not** a guarantee that a pin move is
corpus-neutral — re-measure after the next one.

Four findings from the FIRST bump, each measured rather than inferred, kept
because each still describes how a pin move must be done here:

1. **The move was a true fast-forward, not a rebase.**
   `git merge-base --is-ancestor 902979027a90 f16ea779b82a` returned TRUE and
   `git rev-list --left-right --count <pin>...<remote>` returned `0` / `3`:
   **0** commits existed on the pin that upstream lacked, **3** existed upstream
   that the pin lacked. The move itself was performed with `git merge --ff-only`,
   which would have refused anything else. The local branch carried no unpushed
   work — `902979027a90` was a local commit made in this checkout, and it is an
   ancestor of the remote head, so nothing was lost. **Nothing was pushed to the
   constitution repository**; this was a local pin move only.
2. **No recorded anchor count or line count in this repository went stale.**
   `Constitution.md` is literally the same git blob at both commits —
   `34eff9d86cadb325721c958d35a411feaad27681` — re-measured ON DISK AFTER the
   checkout at 11,700 lines and 252 `### §` anchors, sha256
   `fe1de96abc84c2fc...` identical to the old pin's. `git diff --stat` across
   the three commits touches three paths and none is a governance document:
   `design-toolkit` (1 +), `docs/codegraph/Status.md` (12 +), and the
   `submodules/design-toolkit` gitlink. Every figure recorded in this tree still
   describes the pinned text.
3. **`helix-deps.yaml` moved in the SAME change — and did so again at the second
   bump.** Its `constitution` entry records `3be10826f3d2` today, staged
   together with the gitlink; a bumped gitlink with a stale `ref:` is precisely
   what C9 exists to catch, and it has now had two chances to catch one and had
   nothing to report either time. Re-measured 2026-09-02:
   `bash scripts/verify-manifest-pins.sh` exit **0** at 12 MATCH / 0 DRIFT /
   0 UNDETERMINED, and `bash scripts/verify-governance-cascade.sh` exit **0** at
   12 PASS / 0 FAIL / 0 ENV / 8 NOTE.
4. **No gate in this tree detected local-vs-remote submodule drift, and the
   bump did not change that. One was written later the same day, and it is
   RED.** Cascade check C9 and `scripts/verify-manifest-pins.sh` compare
   `helix-deps.yaml` to the **local gitlink**, never to the remote. Both exited
   **0** while the pin sat 3 commits behind, and both exit **0** now. They
   cannot tell the two states apart, so neither exit code is, or ever was,
   evidence about the remote — which is precisely why a second instrument was
   needed. See "Submodule-vs-remote drift" below.

**Upstream defect carried in by the FIRST fast-forward — now FIXED UPSTREAM by
the second, and the fix is measured, not assumed.** `f16ea779b82a` added a
SECOND `design-toolkit` gitlink at the constitution's own ROOT
(`create mode 160000 design-toolkit`) alongside the existing
`submodules/design-toolkit`, while its `.gitmodules` mapped the entry NAMED
`design-toolkit` to path `submodules/design-toolkit` only — leaving the root
gitlink unregistered. This repository correctly declined to fix it, because
fixing it means committing to the constitution submodule, which this repository
does not do. **Waiting was the right call: upstream removed it.** Re-measured
2026-09-02:

```bash
git -C submodules/constitution ls-tree f16ea779b82a --format='%(objectmode) %(path)' | grep design-toolkit
#   160000 design-toolkit          <- the unregistered root gitlink
git -C submodules/constitution ls-tree HEAD  --format='%(objectmode) %(path)' | grep design-toolkit
#   (none)                         <- gone at f5876a3b700e
```

That deletion is the `design-toolkit | 1 −` line in the second bump's
`diff --stat`. **Record the precedent:** a defect in a CONSUMED submodule was
resolved by waiting for upstream, not by committing into a repository this
project does not own.

Separately, the `design-toolkit` ref CONFLICT recorded under
`conflict_resolution` in `helix-deps.yaml` is a DIFFERENT thing and is
**UNCHANGED**: the constitution's own `helix-deps.yaml` says `ref: 16e4e76` at
all four pins — `902979027a90`, `f16ea779b82a`, `f5876a3b700e` and `3be10826f3d2`, each read
directly with `git show <pin>:helix-deps.yaml`. Do not read the gitlink fix as
closing this.

**The residual risk this block used to report as "not started" is now WATCHED,
and the watching instrument is RED.** The risk was real and is restated because
the reason it went unseen is the lesson: any submodule in this tree could sit
arbitrarily far behind its upstream — corpus changes included — with every gate
in this repository green, because C9 compares the manifest to the local gitlink
and **nothing compared the gitlink to the remote**. The bump closed one
INSTANCE, not the CLASS. The class is now covered by
`scripts/verify-submodule-remote-sync.sh`, registered in
`scripts/check-registry.tsv` as `submodule-remote-sync` with a `--prove-failure`
paired proof — which is exactly what R5 demanded. **Watched became FIXED on
2026-09-02:** that gate now exits **0** at **12 CURRENT / 0 DRIFT /
0 UNDETERMINED** of 12 owned gitlinks probed — its first green ever. Both
earlier readings are WITHDRAWN as current: "6 CURRENT / 6 DRIFT" (2026-09-01)
and "11 CURRENT / 1 DRIFT" (earlier on 2026-09-02). **Green is a measurement of
today, not a property of the tree** — the gate says so itself.
See "Submodule-vs-remote drift" below.

Re-derive. **The pin does NOT equal the remote head** — the sentence that used
to stand here ("the pin now equals the remote head, so no scratch clone is
needed") was true for hours and is withdrawn. Classifying the DIRECTION of the
difference needs either a scratch bare clone or a `git fetch` inside the
submodule, and a fetch is a mutating command and an operator decision. The
read-only probes below tell you THAT it differs, never which way:

```bash
git -C submodules/constitution rev-parse HEAD                   # the local pin
git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD
git -C submodules/constitution rev-parse HEAD:Constitution.md   # blob identity
grep -c '^### §' submodules/constitution/Constitution.md        # 252
wc -l < submodules/constitution/Constitution.md                 # 11700
bash scripts/verify-manifest-pins.sh                            # 0 = ref == gitlink
```

Note the path: this repository places the submodule at `submodules/constitution/`,
not at the top-level `constitution/` that the constitution's own prose and
templates use as their example. Both layouts are supported by
`find_constitution.sh` (its candidate list is `constitution` then
`submodules/constitution`). Whenever a quoted constitution snippet says
`constitution/<file>`, the file in THIS repository is
`submodules/constitution/<file>`.

If the submodule directory is empty, it has not been initialised. Initialise it
read-only-safely with `git submodule update --init submodules/constitution`
before relying on any rule below. Do not run that, or any other mutating git
command, without operator authorization.

### Why a pointer block and not an `@import`

Anchor 11.4.35 invariant 6 declares the two inheritance forms **equivalent**: a
consumer carrier MUST start with either the native `@constitution/CLAUDE.md`
import OR the portable `## INHERITED FROM ...` pointer block. This repository
uses the pointer block. The reason is stated openly rather than left implicit:
`submodules/constitution/CLAUDE.md` is 784 KB and `Constitution.md` is 1.7 MB
(re-measured 2026-09-02 at pin `3be10826f3d2` with `du -h`, unchanged by the
second bump; both grew from the 654 KB / 1.53 MB
figures this file used to carry), so a native import would load roughly 165k
tokens of context into every session before any work begins. Re-derive with
`du -h` rather than trusting these numbers — they are a dated observation, and
the pin moves. The pointer form carries the same authority at no
standing cost, and it is the form the constitution's own propagation gates
recognise (`submodules/constitution/scripts/gates/lib/pointer_carrier.sh`
classifies any carrier whose first non-fenced line-anchored heading is
`## INHERITED FROM ` as a legitimate pointer-inheritance consumer).

Read the canonical text on demand, not eagerly. Useful entry points:

```bash
# Locate the submodule from any nested depth
bash submodules/constitution/find_constitution.sh

# Read one anchor instead of the whole corpus
grep -n '^### §11.4.35 ' submodules/constitution/Constitution.md
awk '/^### §11.4.35 /{f=1} f{print} f&&/^### §11.4.36 /{exit}' \
    submodules/constitution/Constitution.md
```

## Critical base rules restated (for agents that do not resolve pointers)

The nine items below are reproduced verbatim from the constitution's own
consumer scaffold `submodules/constitution/templates/AGENTS.project.md.template`.
That bounded restatement is authored by the constitution for exactly this
purpose, so reproducing it is the prescribed mechanism — it is not a copy of the
corpus. The corpus itself is never duplicated here.

- **No bluffing.** Every PASS carries positive evidence. Constitution §11.4.
- **Mutation-paired gates.** Every new gate has a paired mutation
  proving it catches regressions. Constitution §1.1.
- **No guessing language.** `likely`, `probably`, `maybe`, `seems`,
  `appears` etc. are forbidden when reporting causes. Constitution §11.4.6.
- **Credentials never tracked.** `.env` patterns git-ignored;
  runtime-load only; per-service file separation. Constitution §11.4.10.
- **Use the project's commit wrapper.** No direct `git add` /
  `git commit` / `git push` on main repo.
- **Never force-push.** Force-push requires explicit per-session
  authorization AND a green §9.1.5 post-op gate.
- **Hardlinked backup before any destructive op.** Constitution §9.
- **CONTINUATION.md kept in sync** in every non-trivial commit. Constitution §12.10.
- **60% RAM cap.** Heavy work wrapped in bounded execution scope.
  Constitution §12.6.

Anything not covered by those nine items is covered by the canonical files. Go
read them; do not guess.

## Content boundary — do NOT quote private material into this public repository

This is a **PUBLIC** repository (`private=false`, verified against the provider
2026-09-01). **Three** of its submodules are **PRIVATE**: `workshop`
(`milos85vasic/workshop_curriculum`), `ai_interviewing`, `monetization`. A
gitlink exposes only a commit SHA, so their content stays private — until
somebody copies it out.

**`design-toolkit` is no longer one of them.** It was flipped **public** on
2026-09-01 after a clean full-history privacy audit, so the four-private roster
this paragraph used to carry is WITHDRAWN, not restated. Re-derive the whole
roster rather than trusting this sentence — visibility is a provider setting and
changes outside this tree:

```bash
git config -f .gitmodules --get-regexp 'submodule\..*\.url'   # 13 URLs
gh api repos/<owner>/<name> --jq '.visibility'                # per repository
```

Measured 2026-09-01 with exactly that pair: `milos85vasic/workshop_curriculum`,
`milos85vasic/ai_interviewing` and `milos85vasic/monetization` are **private**;
`vasic-digital/design-toolkit`, `vasic-digital/containers`,
`vasic-digital/LLMProvider`, `vasic-digital/RAG`, `vasic-digital/verdict`,
`vasic-digital/passage`, `vasic-digital/vasic-digital.github.io` and
`milos85vasic/milosvasic.ru` are **public**.

**The rule: naming a private path is fine; copying what is inside it is not.**

    docs/x.md:  see workshop/chapters/01/<recording>.mp4        <- reference, allowed
    docs/x.md:  the notes say "<sentence from that recording>"  <- LEAK, forbidden

One pasted paragraph is public permanently and irreversibly: it is then in a
public repository's history, and history is not editable after a push. The
pressure that causes this is diligence, not carelessness — an agent asked to
document the work comprehensively reaches for an illustrative quote, and the
quote is the disclosure. `workshop/chapters/**` holds a recording of a private
teaching session with an identifiable third party; treat it, and the notes
derived from it, as quotable by path only.

Enforced by `scripts/verify-content-boundary.sh` (registered in
`scripts/check-registry.tsv` as `content-boundary`; paired proof
`--prove-failure`; three-valued exit where a repository whose visibility cannot
be established is 2, never a pass). Legitimate cross-boundary flows are declared
as private/public **pairs** with a mandatory reason in `.content-boundary-allow`.
Full design, the measured false-positive reasoning and the fleet map:
[`docs/content-boundary.md`](docs/content-boundary.md).

**This gate is RED on this tree today, and that is the designed state — do not
make it green.** Re-measured **2026-09-02**,
`bash scripts/verify-content-boundary.sh` exits **1** and prints:

```
LEAK — 11158 surviving match(es) (prose 10833, short 268, name 57); 0 row(s) also could not be determined
```

**The `LEAK — 285 (prose 207, short 35, name 43)` reading this block carried is
WITHDRAWN as a current figure — it is no longer COMPARABLE, and the reason is
structural, not a new leak.** The instrument did not change:
`git status --short scripts/verify-content-boundary.sh .content-boundary-allow`
is EMPTY, so nothing was loosened or allow-listed. Three measured causes:
(1) the gate scans `git ls-files`, and the private `workshop` submodule grew from
**52** tracked files at the gitlink recorded when 285 was measured to **583**
today — `docs/` alone 31 → 90; (2) `specs/002-**` is TRACKED IN THIS PUBLIC
umbrella and describes the private implementation, contributing ~5,800 matches
whose sampled text is the spec's own task prose; (3) the public reusables were
EXTRACTED FROM the private submodule, so `submodules/RAG/pkg/grounding/` (~1699),
`submodules/LLMProvider/scripts/lib/anchor.py` (634) and
`submodules/passage/pkg/passage/pid_test.go` (124) match their own origin by
construction.

**The load-bearing limitation: this gate detects CO-OCCURRENCE, not DIRECTION.**
Governance text that originated in these PUBLIC carriers and propagated INTO a
private submodule is indistinguishable, to it, from private content leaking OUT.
Each of the four root carriers carries **94** matches over 22 lines, and the
matched strings are this project's OWN governance prose — the `/usr/bin/whisper`
trap sentence, the three-valued exit contract, the §12.10 path note — found in
`workshop/docs/`. That is the cascade working, not a disclosure.

**HONEST BOUNDARY (§11.4.6): the above is a characterisation of dominant classes
BY SAMPLING, not a row-by-row assessment. 11,158 rows were NOT individually
judged, and the `name` class (57, seven distinct names, reported by digest only)
is NOT cleared.** Re-baselining this figure is an operator decision.

**An EARLIER figure in this lineage — `LEAK — 10293 surviving match(es)
(prose 203, short 8535, name 1568)` — was withdrawn before the 285 reading, and
is recorded here so a stale one is recognisable rather than trusted.** It was a
MID-TUNING snapshot, captured while the detector was still being rewritten, and
it measured the detector's own noise floor rather than this tree. **The two
numbers are not a before/after of any cleanup: nothing was redacted between
them.** The `short` class fell 8535 → 35 and the `name` class 1568 → 43 because
the detector learned to subtract keys already public in two or more public
repositories, public git identity forms, a scale-free name-frequency floor and
path-reference matches — each subtraction printed on every run, with its RECALL
COST stated, so what the gate can no longer see is visible rather than assumed.

**The prose class is the judged class — and the judging has NOT kept pace with
it.** At the 285 reading, 207 prose rows stood against an incident-note two-wave
assessment covering **232** matches (29 redacted as real disclosures, 203 judged
not to be) — so 207 and 203 were close but **not the same set**, and the
difference was never accounted for. **At 10,833 prose rows the gap is no longer a
rounding difference: the assessed population is 232 and the reported population
is two orders of magnitude larger.** Do not read any prose figure as "rows
individually cleared". The judged rows are left VISIBLE rather than
allow-listed, because an allow-list entry buys a green exit at the cost of
hiding the row from the next reader. The `short` and `name` classes are
substring noise the note characterises. **Do not "fix" this gate by adding
exemptions, and do not add more.** `.content-boundary-allow` carried 9 declared
pairs at that measurement, pardoning 4193 matches; every entry needs a real
cross-boundary flow and a mandatory reason, and the operator decides.

A gate that a human must read is worth more than one that is quietly green.

## Project overview

`vasic` is the umbrella monorepo for two personal/portfolio sites and the shared
tooling that builds, translates and validates them. `vasic.digital/` is
committed static HTML served as-is; `milosvasic.ru/` is Jekyll source whose
rendered `_site/` is git-ignored. `_tools/gen/` is the Go generator that renders
the localized pages for both sites, `design-system/` holds the shared per-brand
tokens and component CSS, and `_tests/` is the Playwright plus self-validating
harness. English source content lives in `_content/` with per-language siblings
in `_content_<lang>/`. See `README.md` for the full map.

## Project-specific facts

These are facts about this repository, not additional rules. They exist so an
agent does not have to guess. The authoritative source for each is `README.md`.

### Owned submodules

`.gitmodules` declares **13** gitlinks (measured 2026-09-01). **11** are owned
consumers of the governance cascade: `milosvasic.ru`, `vasic.digital`,
`design-toolkit`, `ai_interviewing`, `monetization`, `workshop`,
`submodules/containers`, `submodules/LLMProvider`, `submodules/RAG`,
`submodules/verdict` and `submodules/passage`.
`submodules/constitution` is the governance **source** — the head of the
cascade, not a consumer. `submodules/superspec` is third-party (upstream
`WangX0111/superspec`) and is outside the owned-submodule set for tagging and
propagation purposes.

**Four of those 11 joined on 2026-09-01**, and the earlier "nine gitlinks,
seven owned" figure is WITHDRAWN, not restated:

- `submodules/LLMProvider` and `submodules/RAG` were **adopted** under the
  §11.4.74 catalogue-check — reuse before reimplement. A consuming project that
  needs to talk to a model backend or rank documents against a query uses these
  and does not grow its own seam.
- `submodules/verdict` and `submodules/passage` are **newly created PUBLIC
  reusables**, extracted from `workshop/` rather than left embedded in it.

All four are **staged, not yet committed** at this writing, which is why
`scripts/verify-manifest-pins.sh` compares against the INDEX (`git ls-files -s`)
and not against `HEAD`: their refs are checkable today instead of sitting
unverifiable until the adding commit lands. The verifier prints a `NOTE` naming
each one as newly STAGED.

Nothing here is a hardcoded roster and nothing should become one. The fleet is
DERIVED at run time from `.gitmodules` plus `helix-deps.yaml`, and the two are
guarded against each other in both directions by cascade check C6, with C9
guarding every recorded `deps[].ref` against its live gitlink. Re-derive rather
than reading a list:

```bash
git config -f .gitmodules --get-regexp 'submodule\..*\.path'
bash scripts/verify-governance-cascade.sh   # C1 classifies the fleet from evidence
bash scripts/verify-manifest-pins.sh        # C9 standalone: refs vs gitlinks
```

**`design-toolkit`'s two mirrors are NOT in sync, and only one of them is
public.** Its GitHub origin `vasic-digital/design-toolkit` was flipped **public**
on 2026-09-01 after a clean full-history privacy audit. Its GitLab mirror is
reported to remain **private**, and the lag between the two mirrors is now
**UNMEASURED — not zero, and no longer the "5 commits" this paragraph used to
assert.** That count was taken on 2026-09-01 against GitHub HEAD `5467a888…`,
with GitLab HEAD `520c436c…` a strict **ancestor** of it
(`merge-base --is-ancestor` TRUE; `rev-list --left-right --count` = `0` / `5`) —
lag, not divergence. **The GitHub side has since moved on**: re-measured
2026-09-02, the gitlink and `origin` HEAD are both `e7f3815ec35c`, so the old
count compares against a right-hand side that no longer exists and the true lag
can only be larger or equal, never smaller.

```bash
git -C design-toolkit remote -v                                      # origin only, GitHub
git -C design-toolkit ls-remote origin HEAD                          # e7f3815e…
# no GitLab remote is declared here — the mirror cannot be probed from this tree
```

Honest boundary (§11.4.6): this checkout wires up **no** GitLab remote for
`design-toolkit` (`git remote -v` shows `origin` only, GitHub, fetch and push),
so **neither** the visibility nor the lag can be re-measured here — and note
that `scripts/verify-submodule-remote-sync.sh` reports this submodule CURRENT,
which is a true statement about GitHub and says nothing about the mirror. The
*visibility* half is **UNVERIFIED from this tree** and is recorded as reported;
the 5-commit lag WAS measured, on 2026-09-01, and is now stale rather than
false. **Do not write as though the two mirrors match, and do not quote
"5 commits" as a live figure.**

`submodules/containers` (`vasic-digital/containers`) was added under §11.4.76,
which mandates that module for ANY containerised workload and forbids
reimplementing it — a hand-rolled `Containerfile` is a violation, not merely an
inferior choice. **Nothing in this repository has yet been built or run in a
container**; the submodule is present for the workload `specs/001-…` plans.

### Submodule-vs-remote drift — a gate exists now, and it is RED

`scripts/verify-submodule-remote-sync.sh` compares every declared gitlink to its
remote (`git ls-remote` on the declared branch, else `HEAD`). **No other
instrument in this tree makes that comparison, and none did until 2026-09-01.**
C9 and `scripts/verify-manifest-pins.sh` compare `helix-deps.yaml` to the
**local gitlink**; a submodule arbitrarily far behind upstream is invisible to
both, and both were green throughout the period this gate now reports as drift.
A green manifest check has never been evidence about a remote. The new gate is
three-valued — 0 all current, 1 real drift, 2 could not determine — and is
registered as `submodule-remote-sync` in `scripts/check-registry.tsv` with a
`--prove-failure` paired proof, which is what R5 required of it.

**It exits 0 as of 2026-09-02 — the first time it has ever done so.** Three
readings in one day, all real, kept because the movement is the record:

```bash
bash scripts/verify-submodule-remote-sync.sh
# 1 — 6 CURRENT,  6 DRIFT, 0 UNDETERMINED   (2026-09-01)
# 1 — 11 CURRENT, 1 DRIFT, 0 UNDETERMINED   (2026-09-02, after five bumps landed)
# 0 — 12 CURRENT, 0 DRIFT, 0 UNDETERMINED   (2026-09-02, after the authorized fast-forward)
```

The 2026-09-01 run named `design-toolkit`, `ai_interviewing`,
`submodules/containers`, `submodules/LLMProvider` and `submodules/RAG` as
**BEHIND** and fast-forwardable, and `submodules/constitution` as **DIFFERS**
against remote `b9096acd98d2`. All five BEHIND rows were bumped and matched
their remotes. The last row was `submodules/constitution`, reading
`f5876a3b700e` vs `3be10826f3d2` **DIFFERS** with the direction UNDETERMINED
because the remote commit was not in this checkout's object store; the operator
authorized the `--fetch`, which classified it as **2 behind, 0 divergent**, and
`git merge --ff-only` closed it. `submodules/superspec` is probed and reported
as a third-party NOTE, never a verdict input, which is why 12 owned gitlinks are
probed of 13 declared.

**Do not bank the green.** This pin has gone stale within a day on two
consecutive occasions. The correct standing conclusion is that the constitution
pin is an operator decision that RECURS, not a task that completes.

**Note what this gate is blind to even at 12 CURRENT.** It probes the declared
`origin` only. `design-toolkit` has a GitLab mirror that this checkout declares
no remote for (`git -C design-toolkit remote -v` → `origin`, GitHub, only), so
"CURRENT" there is a true statement about GitHub and says nothing whatsoever
about the mirror.

Bumping a gitlink is an operator decision and this gate does not make one. **Do
not silence the 1** by deleting the gate, by allow-listing a submodule, or by
bumping pins to make it green.

### Build and test entry points

The gates mirror the definitions preserved in `.github/workflows/ci.yml.disabled`
and are run from the repository root. Toolchains: Go 1.26, Node 20,
Ruby 3.3 + Bundler, poppler-utils, tesseract-ocr.

**There is no server-side CI at this umbrella root.** As of 2026-08-27 the
workflow is disabled per §11.4.156(B) and enforcement is a **local pre-push
hook**. `.git/hooks/` is not tracked by git, so a fresh clone runs no gates
until `bash scripts/pre-push-gates.sh --install` is run, and `git push
--no-verify` bypasses the hook with no record — run these by hand until you have
confirmed the hook is in place. (This says nothing about the site submodules:
`milosvasic.ru` deliberately keeps an active deploy workflow — see **Deploys**.)

```bash
cd _tools/gen && go test ./... && cd -        # Go unit tests (generator)
bash _tools/audit-hardcoding.sh               # hardcoding audit
bash _tools/translate/reproducibility-selftest.sh
bash _tools/portfolio/self-validate.sh
bash _tests/run-harness-selfvalidation.sh     # harness self-validation
```

Playwright (chromium) additionally requires `npm ci` and
`npx playwright install chromium` inside `_tests/`, and a built
`milosvasic.ru/_site` before the suite is served.

### Governance and adaptability instruments

Separate from the pre-push gates. Every one is three-valued — **0 clean, 1 a
real finding, 2 COULD NOT DETERMINE, and 2 is never a pass.** Results below were
measured on 2026-09-01 and are dated observations, not standing facts, **except
`audit-environment-assumptions.sh`, re-measured 2026-09-02 below.**

```bash
bash scripts/continuation-check.sh              # CONTINUATION.md is not stale
bash scripts/verify-governance-cascade.sh       # 0 — 12 PASS/0 FAIL/0 ENV/8 NOTE (C0..C9)
bash scripts/verify-manifest-pins.sh            # 0 — C9 standalone: 12 MATCH/0 DRIFT/0 UNDET of 12
bash scripts/verify-check-registry.sh           # 0 — 41 PASS/0 FAIL/0 DEBT; --run-proofs is 1, see below
bash scripts/audit-hardcoded-paths.sh           # 0 — gate 0, 6 file(s) explicitly allowed
bash scripts/audit-environment-assumptions.sh   # 0 — 2026-09-02, after 12 fixes + 5 reasoned exemptions
bash scripts/verify-content-boundary.sh         # 1 — RED BY DESIGN, see "Content boundary"
bash scripts/verify-submodule-remote-sync.sh    # 0 — 12/12 CURRENT, first green ever; remotes move
bash scripts/verify-provider-ci.sh              # provider-side CI probe
bash scripts/lumen-index-doctor.sh              # 0 — semantic index health
bash scripts/ollama-tune.sh                     # local inference host tuning
```

Four of those need reading carefully rather than glancing at:

- **`verify-check-registry.sh` used to print 5 DEBT rows on every run. As of
  2026-09-02 it prints ZERO — all five owed paired proofs were written, and each
  was verified in BOTH directions: it passes on this tree AND it fails against a
  deliberately weakened throwaway copy of the gate it guards.** Every mutation is
  DATA rather than a code edit, so each control is green by construction — the
  "inoperative proof" defect the registry itself documents.
  `setup-agents-wizard-suite` also owed **three-valued** and now demonstrates
  rc 2 four ways. Measured: **41 PASS / 0 FAIL / 0 DEBT / 0 UNDET / 0 NOTE**,
  exit 0; `--strict` also **0**. The five `debt` rows became `check` rows, and
  no new `*.sh` was created, so R5 stays green.

  **`--run-proofs` still exits 1**, at 54 PASS / 5 FAIL, and none of the five is
  a newly-promoted check. One is REAL — `provider-ci` fails its own selftest
  assertion *"M6b no repository or owner name in body"*. Four are **false
  positives of the hollow-proof heuristic** (`submodule-remote-sync`,
  `mutation-anchor-rot`, `private-object-exposure`, `remedy-executability`):
  each proof runs and returns 0, but summarises in prose instead of the
  `M<n>` / "N mutations" form the heuristic recognises. **The heuristic was NOT
  loosened** — it is the only thing between the registry and a proof that
  returns 0 while exercising nothing. Also still open and now printed on every
  run rather than buried in prose: the sweep's **DROP** direction. Its ADD
  direction is proved; assertion **L1** deletes a gate, measures the count
  falling `3 → 2`, and records that the sweep still exits 0 because it keeps
  **no expected-gate ledger**.

  The zero-DEBT history is worth keeping. A zero means "every registered check is
  accounted for", **not** "every check has a working paired proof" — a plain run
  verifies proof *structure* only and says so;
  `--run-proofs` actually executes them, `--strict` makes debt block. Its R5
  anti-drift rule means **a new `*.sh` under `scripts/` fails the registry until
  it is registered** in `scripts/check-registry.tsv` (documented in
  `docs/check-registry.md`) as a check, a debt, or an exemption. Measured
  across 2026-09-01 in three states, all real: exit **0** at 21 PASS / 0 FAIL /
  5 DEBT in the morning; then exit **1** at 20 PASS / 1 FAIL / 5 DEBT once an
  unregistered `scripts/verify-content-boundary.sh` appeared — R5 doing its job;
  then exit **0** once that gate was registered. Re-measured later the same day
  it is exit **0** at **31 PASS / 0 FAIL / 5 DEBT / 0 UNDET / 0 NOTE**
  (re-measured 2026-09-02; the **25 PASS** figure carried here earlier is
  superseded) — the
  PASS count moved 23 → 25 → 31 as further checks landed and were registered, which
  is R5 working rather than drift, and the "23 PASS" figure this bullet used to
  carry is superseded, not wrong-at-the-time. **Both the FAIL and the 5 DEBT
  rows are now cleared** — the five that owed a proof were
  `constitution-rules-sweep`, `lumen-index-doctor`, `ollama-tune`,
  `prepush-gates` and `setup-agents-wizard-suite`.
- **`audit-environment-assumptions.sh` went RED at 17 and was taken back to
  GREEN in the same session — 12 by REAL FIXES, 5 by reasoned exemptions. Read
  that split before quoting the exit code.** The instrument has now moved five
  times without the audit itself being edited once. Every state is recorded,
  because the movement is the point.

  **Final state, re-measured 2026-09-02:** exit **0**,
  `✅ no NEW frozen environment assumptions (531 justified occurrence(s) allow-listed)`,
  scanning **2166 files across 14 repositories in 12 classes**.

  **How the 17 were cleared — the distinction is the whole point, because an
  allow row is not a fix:**

  | Resolution | Count | What |
  | --- | --- | --- |
  | **Real fix** | 11 | `pipeline/benchmark/{build_bench_nomic_full,run_retrieval_benchmark}.py` — every `argparse` default now `os.environ.get(...)` (`$OLLAMA_URL`, `$BENCH_EMBED_MODEL`, `$WORKSHOP_BASE_URL`, `$BENCH_ALT_MODEL`, `$BENCH_CURRENT_MODEL`), each keeping its former literal as last resort so existing callers are unchanged; prints and docstrings now report the RESOLVED model instead of a frozen name |
  | **Real fix** | 1 | `platform/backend/gates/prove-evidence-precision-mutation.sh` — bare GNU-only `sed -i` → portable `sed -i.bak … && rm -f "$SED_BAK"` |
  | **Exemption** | 1 | `platform/backend/internal/api/suggest_gates_test.go` — `net.Listen("tcp", "127.0.0.1:0")` asks the KERNEL for a port and reads it back with `ln.Addr()`, injecting it via `t.Setenv`; that is an override being exercised, not an assumption, and `go build` excludes `*_test.go` from every production binary |
  | **Exemption** | 4 | the three `pipeline/benchmark/*.json` result files — a benchmark result records WHICH MODEL WAS MEASURED; rewriting that name would falsify the record rather than adapt anything. Verified before exempting: only `positive_queries` / `negative_queries` are ever dereferenced, the `_meta` object is never read back |

  **The 5 exemptions are recorded debt-free but they are still exemptions**, each
  carrying a `# REASON:` naming the evidence. **No `# BASELINE:` row was added
  and the 728-row baseline was not touched.** A green exit bought with five
  reasoned rules is not the same artifact as a green exit bought with twelve
  fixes; both happened here, and the table above is why the distinction survives.

  **The red that preceded it, and its correctly-attributed cause.**
  The run that opened this session exited **1** with
  `❌ 17 frozen environment assumption(s)`. All 17 were inside `workshop/`, in
  seven files: `pipeline/benchmark/build_bench_nomic_full.py` (6),
  `pipeline/benchmark/run_retrieval_benchmark.py` (5),
  `pipeline/benchmark/retrieval_benchmark.json` (2),
  `pipeline/benchmark/results.json` (1),
  `pipeline/benchmark/results_nomic_full.json` (1),
  `platform/backend/internal/api/suggest_gates_test.go` (1) and
  `platform/backend/gates/prove-evidence-precision-mutation.sh` (1).

  **Attribute this carefully — a stronger claim was drafted and WITHDRAWN before
  it stood.** It read "the workshop gitlink bumps pulled the benchmark into
  scope", resting on all seven files being ABSENT at `55076bf943a5`. They are —
  but `55076bf943a5` is the gitlink `CONTINUATION.md` still *recorded*, not the
  one in effect at the previous `Synced-Commit`, which was `6130d6b55d693`
  (`git rev-parse 1b90daa6:workshop`). Against that correct baseline, only **2**
  of the 7 files are new (`build_bench_nomic_full.py`, `results_nomic_full.json`
  = **7 findings**); the other **5 files / 10 findings** were already present and
  simply went unseen. **Comparing against a stale reference point does not just
  misstate a number — it manufactures causality.** The fleet-derivation mechanism
  is real for the 7; the 10 are the more uncomfortable half.

  Most were frozen model names (`nomic-embed-text`, `jina-embeddings-code-cpu`)
  and endpoints (`127.0.0.1:11434`, `127.0.0.1:8087`) in benchmark code and its
  committed JSON results. **They were judged separately rather than
  blanket-allowed by directory** — the `argparse` defaults were the real freezes
  and were fixed; a results file recording which model was measured is closer to
  a RESULT than an assumption and was exempted with its evidence. Same
  directory, opposite verdicts, which is the outcome a blanket rule would have
  destroyed.

  The earlier cycle, kept because each dead figure is a lesson: 7 frozen
  GNU-vs-BSD assumptions (six in
  `scripts/verify-check-registry.sh` — GNU-only in-place `sed -i`,
  `stat -c '%a'` — and one in `scripts/verify-manifest-pins.sh`) were fixed with
  portable helpers, taking the audit **green (exit 0)** at 1763 files across 14
  repositories; then, re-measured 2026-09-01, it went **red (exit 1)** at
  **10 frozen environment assumptions**, scanning **1794 files across 14
  repositories in 12 classes** — all 10 inside `submodules/LLMProvider`
  (`pkg/providers/ai21/ai21_test.go`, `pkg/providers/openrouter/openrouter_test.go`,
  `scripts/prove-offline-discovery.sh`), which had just joined the owned fleet
  and brought its own occurrences into scope with no edit to the audit itself.
  **That figure is now WITHDRAWN, not restated.** An intervening run on
  2026-09-02 exited **0** at **1987 files across 14 repositories in 12 classes**,
  and none of the three previously-cited `submodules/LLMProvider` occurrences was
  flagged. **Careful with that sentence: the 10 LLMProvider FINDINGS are gone,
  but that submodule still contributes 14 files to the 728-row BASELINE** (13
  under `pkg/providers/`, plus
  `challenges/scripts/host_no_auto_suspend_challenge.sh`), re-verified
  2026-09-02. A finding fixed upstream and a baselined debt row are different
  states printed in different sections — an empty findings list is not a clean
  submodule. That submodule's own commit log
  (`git -C submodules/LLMProvider log --oneline`) shows the fix landed upstream:
  `test(ai21): stop asserting AI21's uptime in a unit test`,
  `test(settings,codestral,ollama): stop freezing real model ids and endpoints
  in fixtures`, and `fix(providers): default model and endpoint were frozen
  with no override layer (F23, F24)` — a real fix in the consumed submodule,
  not a re-baselining in this tree. Read the rest of today's output before
  calling anything clean. **Both long-standing residues were worked this session
  and BOTH MOVED, by real fixes rather than by re-baselining:**

  - **STALE allow rules 2 → 0** (rule count 444 → 436). Both were DELETED from
    the embedded `ALLOW_RULES` heredoc, each leaving a tombstone comment carrying
    the evidence. `scripts/audit-hardcoded-paths.sh * *` was a blanket whole-file
    exemption that suppressed NOTHING — its one class hit sits inside a `#`
    comment, which the scanner blanks for `.sh` before any class is tested.
    `_tools/gen/review_ui_all.py MODEL *` named a model id living only in a
    module docstring with no quote character on the line, and `git log -p --all`
    shows that was the only occurrence the file has EVER had. Neither deletion
    surfaced a new finding, and `--strict-allow-list` moved **1 → 0**.
  - **Baselined occurrences 728 → 683** (−45), across 216 files. **F13 and F14
    are CLOSED.** The slice was chosen by measurement, not taste: of the 728,
    **638 sit inside submodules** (472 `containers`, 102 `constitution`, 20
    `workshop`, 17 `LLMProvider`, 14 `ai_interviewing`) and can only be fixed by
    an upstream commit returning as a gitlink bump, leaving **90**
    umbrella-root-owned — of which `_tests/` ENDPOINT was exactly half. The fix
    is a new `_tests/env.js`, one source of truth for PORTS **and** BASES, each
    `process.env`-derived with the former literal as documented default and an
    unparseable port throwing at `require()` instead of silently defaulting.
    Covering both closes the half no allow rule could express: the port a config
    **bound** and the base a spec **requested** were independent literals free to
    disagree, and a disagreement surfaced as an assertion about the *site*.
    Measured: `node --check` on 29 files; **237 passed** on chromium at default
    ports; **12 passed / 41 passed at non-default `VD_PORT=9401 MV_PORT=9082`**,
    impossible before and the entire content of F13. Proof the SOURCE moved
    rather than the ledger: `git show HEAD:scripts/audit-environment-assumptions.sh`
    run against the fixed tree reports **8** stale rules. Note `_tests/env.js` is
    **UNTRACKED**, so `git ls-files` does not yet show it to the gate.

  Still printed on every run by design: **683 baselined occurrences** — declared,
  known, unfixed defects; next coherent slice is F15 (MODEL, `_tools/gen/`, 17
  rows) — and **1 frozen assumption inside a third-party gitlink**
  (`submodules/superspec/.github/workflows/ci.yml`, a pinned
  `python-version: "3.12"`), reported out-of-scope under §11.4.156(C) /
  §11.4.29 so it is never silently omitted. **A baseline is recorded debt, not
  a justification, and an allow row is not a fix — and ANY exit code here, green
  or red, is a measurement of today, not a guarantee about tomorrow's fleet.
  This instrument's verdict has changed four times without the audit itself
  being edited once; the fleet moves under it. Re-run it, never quote it.**
- **`verify-content-boundary.sh` exits 1 and is MEANT to.** See the "Content
  boundary" section above: ~207 judged non-disclosures are left visible rather
  than allow-listed. A 1 from this gate is a reading assignment, not a
  regression.
- **`verify-submodule-remote-sync.sh` exits 1 and the 1 is a real finding, not a
  designed one.** Six owned gitlinks are out of sync with their remotes pending
  a bump, which is an operator decision. See "Submodule-vs-remote drift" above.
  It is the ONLY instrument here that looks at a remote at all; every other one
  on this list is blind to it by construction.

Both audits, and gate E, once had the same blind-instrument defect and all three
are fixed: gate E enforced §11.4.156 only at the umbrella root, because
`git ls-files` sees a gitlink as ONE entry — an active `pages.yml` in
`milosvasic.ru` and an active `ci.yml` in `superspec` both passed it — and the
two audits scanned **zero files inside the 9 submodules declared at the time**.
All three now derive the fleet from `.gitmodules` + `helix-deps.yaml`, which is
why the environment audit's coverage moved with the fleet on its own — 14
repositories at the 2026-09-01 run, with no edit to the audit.
`scripts/pre-push-gates.sh`'s
`run_gate` likewise gained a distinct **UNDET** verdict for a child `rc=2`
instead of mapping every non-zero return into FAILED, and gate 6 classifies
network-class failures as rc=2. **A blind instrument reports PASS.**

### Deploys

Deploys are driven by `bash _tools/deploy-langs.sh`. It regenerates EN plus
every complete language into both site submodules, commits and pushes each site
only when something changed, then validates the LIVE sites. `--dry-run` previews
without committing.

**`milosvasic.ru` self-publishes on push, and that must not change** (verified
2026-08-27, re-verified 2026-09-01: `git ls-files '.github/workflows/*'` in that
submodule returns `.github/workflows/pages.yml` — one file, still under its
active name). Its `.github/workflows/pages.yml` is the custom GitHub Pages
build+deploy action and is **ACTIVE**. It was briefly renamed to a `.disabled`
name under the 2026-08-27 11.4.156 decision (*"Comply — disable both, enforce
locally."*); that half of the decision was **reversed the same day** on the
operator's overriding directive:

> *"Make sure all pages websites work flawlessly! No website can be broken! All
> websites we have here are running deployed in production!"*

The material fact behind the reversal:
`gh api repos/milos85vasic/milosvasic.ru/pages` returns `build_type: "workflow"`
(re-measured 2026-09-01, unchanged) — that workflow is the **sole** publish path
for the live site. There is no `gh-pages` branch and no `docs/` folder, and the
repository root is Jekyll SOURCE (Liquid + front matter), so it cannot be served
raw from a branch. `_tools/deploy-langs.sh` is **not** a substitute: it
generates, commits and pushes source, then `sleep`s waiting for the server to
rebuild — it covers generation and push, none of the publish step. **Do not
disable, rename, or otherwise "fix" `pages.yml`.** `vasic.digital` needs no
build step (committed static HTML), but its Pages source is still
`build_type: "legacy"` (`gh api repos/vasic-digital/vasic-digital.github.io/pages`,
re-measured 2026-09-01), so every push still triggers a provider-side `pages
build and deployment` Actions run even though `git ls-files
'.github/workflows/*'` in that submodule returns **zero** files.

`design-toolkit` adds **no** §11.4.156 CI surface of its own: the same
`git ls-files '.github/workflows/*'` returns **0** there too (measured
2026-09-01), so its flip to public created no new provider-side trigger.

Every `build_type` and run-count in this file is a DATED OBSERVATION, not a
standing fact. Provider settings change outside this tree and nothing here can
see that happen. Re-measure before relying on any of them:

```bash
bash scripts/verify-provider-ci.sh   # 0 = none found, 1 = confirmed, 2 = could not determine
```

It enumerates the owned repositories from this checkout's own remotes and
queries the provider. Exit 2 means UNVERIFIED — it is not a pass and must never
be recorded as one. `scripts/setup-agents-wizard.sh` runs it as Step 9 and turns
a confirmed finding into a manual step, because changing a provider setting is
an operator action in a provider UI.

## Honest boundary — this repository is NOT yet fully compliant

Anchor 11.4.6 forbids reporting a state you have not verified, so this section
states plainly what is still missing rather than letting the pointer above imply
full adoption. The full audit is
[`docs/constitution-adoption/INVENTORY.md`](docs/constitution-adoption/INVENTORY.md).

Known open gaps at the time this carrier was created (identifiers are the
inventory's own):

- G3 — CLOSED (verified 2026-08-27). Both halves of the §11.4.32 sweep contract
  now exist and run. `scripts/verify-all-constitution-rules.sh` discovers its
  gates dynamically, and `scripts/verify-governance-cascade.sh` supplies step 1:
  re-measured 2026-09-01 as **12 PASS / 0 FAIL / 0 ENV / 8 NOTE, exit 0**, with
  a paired-mutation proof (`--prove-failure`) that catches seeded violations as
  rc=1 and reports an environment fault as rc=2 rather than accusing the tree.
  It grew from 10 checks to 12 with **C8** (the four carriers INSIDE each owned
  submodule agree with each other, normalising the per-agent header rather than
  splitting at a fixed line, because submodule carriers do not share this root's
  header geometry) and **C9** (every `helix-deps.yaml` `deps[].ref` equals
  its live gitlink; re-derivable standalone as
  `bash scripts/verify-manifest-pins.sh`). Step 1 is a measured PASS, not a
  SKIP-with-reason; OC-3 is resolved.
  **C5 ROOT-LOCKSTEP was tightened on 2026-09-01 and no longer splits at a
  hardcoded line 24.** It now measures where the four carriers actually converge
  and enforces from there, and prints a NOTE saying so — *"declared split 19
  equals the measured convergence line 19 — the gate enforces exactly the range
  it claims, with no ungated identical remainder (ceiling 24)"*. That closes a
  real blind spot: a line-24 window is a strict SUBSET of the shared region, so
  the old form could pass on carriers that differed at lines 19–23. Lines 1–18
  are the per-agent opening block. **Edit the shared region as ONE artifact** —
  split the head off, edit the tail once, recompose — rather than editing four
  files by hand and trusting a gate to catch the slip:

  ```bash
  for N in 18 19; do
    printf 'from %s: ' "$N"
    for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md; do tail -n +$N "$f" | sha256sum; done \
      | sort -u | wc -l
  done   # expect 4, then 1
  ```
  **This closes the sweep CONTRACT, not the sweep's verdict.** For the sweep's
  own PASS/FAIL split see "The sweep's own result" below.
  The step-1 caller was ALSO fixed: it previously mapped any non-zero rc to
  `STEP1 FAIL`, collapsing the verifier's three-valued contract and reporting a
  broken check as a governance violation. It now branches on rc and has a
  distinct ERROR state that exits non-zero without accusing the tree.
  The earlier "37 PASS / 21 FAIL / 0 ERROR out of 58" figure is WITHDRAWN, not
  restated: the true pre-fast-forward split was 36/22, and the gate population
  moved 57 → 286 when the constitution was fast-forwarded, so no old split is
  comparable to a present-day run. No completed post-fast-forward split is
  claimed here.
- G4 — PARTIAL (decided 2026-08-27; **partially reversed the same day**).
  ~~`.github/workflows/ci.yml` is active at the repository root, which conflicts
  with anchor 11.4.156(A). Resolving it is an operator decision (disable per
  11.4.156(B), or record an explicit override in a project Constitution).~~
  **The override half of that sentence was wrong: no such option exists.**
  11.4.156 refuses the exemption vocabulary by name ("No escape hatch — no
  `--allow-ci` … `--ci-exempt` flag"), and a consumer carrier may only extend
  inherited rules, never weaken or override them — so a project-local override is
  structurally impossible, not merely disfavoured. First operator decision:
  *"Comply — disable both, enforce locally."* ~~Both `.github/workflows/ci.yml`
  and `milosvasic.ru/.github/workflows/pages.yml` are renamed to a non-active
  `.disabled` name.~~ **Reversed in part on 2026-08-27** after a material fact
  emerged: `gh api repos/milos85vasic/milosvasic.ru/pages` returns
  `build_type: "workflow"`, so `pages.yml` is the SOLE publish path for the live
  production site (no `gh-pages` branch, no `docs/` folder, root is Jekyll
  source; `_tools/deploy-langs.sh` pushes source and waits — it does not
  publish). The operator's overriding directive: *"Make sure all pages websites
  work flawlessly! No website can be broken! All websites we have here are
  running deployed in production!"*
  **Current state.** `.github/workflows/ci.yml` → `ci.yml.disabled` and the
  gates run from a local pre-push hook — **the umbrella root complies** with
  11.4.156. `milosvasic.ru/.github/workflows/pages.yml` is **ACTIVE and will
  stay active**; that submodule is a **known, documented deviation** from
  11.4.156, taken deliberately for production uptime. It is **not** an
  `Override §11.4.156` — the rule forbids one — and must never be written up as
  one. `vasic.digital` is non-compliant at the **provider** level
  (`build_type: "legacy"`; every push triggers a `pages build and deployment`
  run) with **no file-level remedy**, because it has zero workflow files.
  **Not CLOSED** — honest boundary (11.4.6): file-level disabling stops
  FILE-triggered runs but does not reach provider-side settings (org-default
  required workflows, branch-protection required checks, the GitHub Pages source
  setting, provider-side scheduled exports). That boundary is unchanged: those
  settings are still operator-only to CHANGE, in a provider UI. What is no
  longer hand-asserted is their STATUS. It is measured on demand by
  `bash scripts/verify-provider-ci.sh` (0 = none found, 1 = provider-side
  triggering confirmed, 2 = could not determine — **not** a pass), which the
  setup wizard runs as Step 9 and which surfaces a confirmed finding as a
  manual step. Do not quote a status from this document as current; run the
  check. **Cost of the umbrella half: no server-side enforcement on
  push or PR; `.git/hooks/` is untracked, so a fresh clone is unprotected until
  `bash scripts/pre-push-gates.sh --install` is run, and `git push --no-verify`
  bypasses the hook.** Record:
  `docs/constitution-adoption/DECISION-11-4-156-COMPLY.md`; CI surface inventory:
  `docs/constitution-adoption/CI-INVENTORY-11-4-156.md`.
- G5 — PARTIALLY CLOSED (verified 2026-08-26). A commit wrapper IS available:
  `commit` resolves on PATH to `$SUBMODULES_HOME/Upstreamable/commit`, which
  chains to `Software-Toolkit/Utils/Git/commit.sh` (`git add .` + `git commit`)
  and then `push_all.sh`. `push_all.sh` reads the `upstreams/*.sh` recipes, and
  this root DOES have a tracked `upstreams/GitHub.sh`, so `commit "<message>"`
  works here and pushes to the `github` remote plus tags. What is still missing
  at this root is git HOOKS, not the wrapper. Note the wrapper runs `git add .`,
  which stages everything untracked — keep `.gitignore` accurate before using it.
- G6 — CLOSED (verified 2026-08-27). `helix-deps.yaml` exists at the repository root and parses under `yaml.safe_load`.
- G7 — CLOSED (re-measured 2026-09-01; **44 of 44**). The closure condition this
  entry itself named — "`workshop/` is onboarded and that verifier exits 0" — is
  met. `bash scripts/verify-governance-cascade.sh` exits **0** with 12 PASS /
  0 FAIL / 0 ENV / 8 NOTE: C1 classifies all **13** declared gitlinks FROM
  EVIDENCE (**11 owned**, 1 governance source, 1 third-party, no hardcoded
  roster); C2 finds all **11 × 4 = 44** owned-submodule carriers present and
  non-empty; C3 finds all 44 accepted by the canonical `is_pointer_carrier`
  predicate (§11.4.35 inv. 6); C6 finds `helix-deps.yaml` and `.gitmodules` in
  agreement both ways (13 submodules = 12 `deps[]` + third-party comments);
  C7 classifies the 1 nested gitlink under the 11 owned submodules; C8 finds
  every owned submodule internally in four-carrier lockstep.
  **Every earlier count is WITHDRAWN, not restated**, and the sequence is kept
  because the reason each one died is the lesson. (a) "only
  `vasic.digital/QWEN.md` exists, and it references no anchor" — false on both
  halves. (b) "CLOSED, 5 × 4 = 20/20" — wrong, because it enumerated a HARDCODED
  list of five submodules instead of deriving the fleet, the same defect class
  the roster itself is criticised for, committed while correcting (a).
  (c) "PARTIAL, 20/24" — correct when written, superseded once `workshop/` was
  onboarded and `submodules/containers` was added. A "24/24" figure circulated
  verbally is likewise superseded: 24 was 6 × 4, measured before
  `submodules/containers` joined the owned fleet. (d) "**28 of 28**" (7 × 4) —
  correct on the morning of 2026-09-01, superseded the same day when
  `submodules/LLMProvider`, `submodules/RAG`, `submodules/verdict` and
  `submodules/passage` joined the owned fleet. A "36/36" figure circulated
  verbally is likewise superseded and was never measured: 36 is 9 × 4, and the
  owned fleet is 11, not 9. The gate caught (b) before any human did, and the
  fleet moved under (d) within hours — which is the point of it. **Do not
  re-derive this number by hand — run the verifier and quote what it prints.**
- G8 — the markdown export mandate (11.4.65) is unmet across the repository.
  Unchanged and with no work in flight.
- G12 — no `PreToolUse` guard is wired, although the canonical guard script is
  present in the submodule. Unchanged and with no work in flight.

### Content boundary incident, 2026-09-01 — OPEN, and not closeable by a commit

This is not an inventory `G` item; it is an incident, and it is recorded here
because it is the largest un-remedied fact about this repository.

**Private material was written into this PUBLIC repository, committed, and
pushed.** Three classes crossed the boundary: verbatim prose quoted out of a
private meeting-notes PDF inside the private `workshop` submodule; SQL and
script headers copied out of a private repository; and **a third party's full
real name** — a person who is not the repository owner and who did not publish
it. That name is deliberately **never written into any file in this tree**; it
is referred to only as recorded in the incident note, by location.

**The working tree is redacted. The commits are not.** Redaction is
containment, not a remedy: the content remains in the history of a **public
remote**, and history is not editable after a push. Do not read the redaction,
or any green gate, as closure. Removing it from history is a rewrite of public
history — an operator decision, prepared and unexecuted.

Full forensics, the exact pre-redaction blob/line locations, the two-wave
assessment (232 matches assessed; 29 redacted as real disclosures; 203 judged
not to be) and the unexecuted remediation plan:
[`docs/content-boundary-incident-2026-09-01.md`](docs/content-boundary-incident-2026-09-01.md).
The standing rule and its fleet map:
[`docs/content-boundary.md`](docs/content-boundary.md).

The gate that now watches for a recurrence is
`scripts/verify-content-boundary.sh`, registered as `content-boundary` in
`scripts/check-registry.tsv` with a `--prove-failure` paired proof and a
three-valued exit. **It exits 1 today, by design** — see the "Content boundary"
section near the top of this file. It was written after the leak, so it is
evidence that the class is now watched, and evidence of nothing at all about
what is already public.

### The sweep's own result

`scripts/verify-all-constitution-rules.sh` discovers its gates dynamically, and
that population moved **57 → 286** when the constitution was fast-forwarded, so
**every split published before the fast-forward is withdrawn and none of them is
comparable to a present-day run.** Do not restate an old number.

The most recent measurement on record is **186 PASS / 95 FAIL / 6 ERROR of 287
gates**. It is written here as a *reported prior measurement*, not as a state
this file observed: a re-run started 2026-09-01 had not finished when this text
was written, so no fresh split is claimed. Two classes of failure inside it are
known and **cannot be cleared by any commit this repository can make**:

1. **Third-party and staged carriers** — `submodules/superspec/examples/…`,
   `milosvasic.ru/Upstreamable/…`, and the vendored spec-kit extension copy
   under `.specify/extensions/`. `scripts/verify-governance-cascade.sh` reports
   these as *known-unclearable* and excludes them from its own verdict; the
   propagation-gate family inside the sweep still counts them as FAILs.
   Excluded there means **not double-counted, never suppressed** (§11.4.6).
2. **Defects internal to the constitution submodule**, which is upstream code
   this repository consumes rather than owns.

Neither class licenses treating the sweep as green.

### Host capability — verify it, never assume it

Re-measured on the development host 2026-09-01, **after** an ASR stack and a
generative model were installed the same day. **Two claims this section used to
carry — "No ASR engine" and "No generative model" — are WITHDRAWN, not
restated.** What follows constrains what can actually be built here:

- **A dual ASR stack IS installed — inside a project venv, not on the system
  interpreter.** Both engines target the same model family and neither needs a
  GPU:
  - **faster-whisper 1.2.1** on **CTranslate2 4.8.2**, in
    `workshop/pipeline/venv` (Python 3.14.6), with the CT2 weights at
    `workshop/pipeline/models/ct2/faster-whisper-large-v3-turbo` (1.6 GB). It
    installed from **prebuilt wheels**; `torch` is **not** present even in that
    venv, and is not needed.
  - **whisper.cpp v1.9.1**, built **CPU-only** at
    `workshop/pipeline/engines/whisper.cpp`, binary
    `build/bin/whisper-cli`, with `models/ggml/ggml-large-v3-turbo-q8_0.bin`
    (834 MB).
- **The system `python3` still has no ASR engine, and that distinction is the
  whole point.** `faster_whisper`, `whisper`, `vosk`, `transformers` and `torch`
  are all still absent from `python3`'s import path; the engine resolves only
  through `workshop/pipeline/venv/bin/python`. A probe that runs bare `python3`
  will conclude there is no transcriber, and be wrong.
- **`/usr/bin/whisper` exists and is a trap. This is unchanged and still
  load-bearing.** It is a GTK desktop notification client (© 2023 Lorenzo
  Paderi, GPL), not a transcriber. `command -v whisper` succeeds and proves
  nothing — and it now succeeds on a host that genuinely HAS a transcriber,
  which makes the trap worse, not better: the name on `PATH` still resolves to
  the wrong program. A capability probe that tests only for a name on `PATH`
  will report an engine that is not there while missing the two that are.
- **A generative model IS available locally, and it is not merely present —
  it is wired in.** `ollama list` holds **three** models, not two:
  `qwen2.5:3b-instruct-q4_K_M` (1.9 GB / 1841 MiB, **generative**, pulled
  2026-09-01) alongside the two **embedding** models
  `ordis/jina-embeddings-v2-base-code` and `jina-embeddings-code-cpu` (323 MB
  each). "Nothing local can generate prose" is false as of that pull. What a
  3B q4 instruct model is fit FOR is a separate question this line does not
  answer. **Re-measured 2026-09-02:** the running container
  `workshop-curriculum_platform_1` has this model in its own argv —
  `podman inspect workshop-curriculum_platform_1 --format '{{.Config.Cmd}}'`
  shows `/opt/workshop/bin/workshop-server … -ollama http://127.0.0.1:11434
  -answer-provider ollama -answer-model qwen2.5:3b-instruct-q4_K_M …` — so the
  workshop platform's answer path is actually wired to this model today, not
  merely capable of being wired to it.
- `podman` is present; `docker` is absent (`command -v podman docker`). No image
  for this repository exists.

Re-derive all of it rather than trusting the list — a host changes under you,
and this section has already been wrong once in each direction:

```bash
ollama list
command -v podman docker
python3 -c 'import faster_whisper'                       # expect ModuleNotFoundError
workshop/pipeline/venv/bin/python -c 'import faster_whisper, ctranslate2; \
  print(faster_whisper.__version__, ctranslate2.__version__)'
git -C workshop/pipeline/engines/whisper.cpp describe --tags
workshop/pipeline/engines/whisper.cpp/build/bin/whisper-cli --help | head -3
podman inspect workshop-curriculum_platform_1 --format '{{.Config.Cmd}}'   # confirms -answer-model wiring
```

### Live-production test coverage moved out of gate 6, into deploy

`_tests/playwright.config.js` carries
`testIgnore: /(restyle-seo-regression|v170-fixes|v171-hardcoding)\.spec\.js/`,
so **gate 6 does not run those three specs** — **32 `test()` blocks and 97
`expect()` call sites**, counted 2026-09-01. They are claimed by
`_tests/playwright.live.config.js`, whose `testMatch` names all four live specs.

**They now run at deploy time — via an UNCOMMITTED working-tree change made on
2026-09-01.** `_tools/deploy-langs.sh` declares
`LIVE_SPECS="all-languages-link-integrity restyle-seo-regression v170-fixes
v171-hardcoding"`, pre-flights each spec file, and invokes the live config with
no spec name on the command line, so the whole `testMatch` set executes.
**At `HEAD` that is not yet true** — `git show HEAD:_tools/deploy-langs.sh`
names `all-languages-link-integrity.spec.js` alone. Until the change is
committed, a fresh clone runs the other three **nowhere**; run
`cd _tests && npx playwright test --config=playwright.live.config.js` by hand
before any release.

A figure of "86" circulates for this suite. It is a Playwright **test-case pass
count** ("86 passed / 2 failed") observed across the four-spec live run — not a
count of assertions in the three deferred specs, which is 97. Both are real;
they do not measure the same thing.

The gate-6 deferral is sound and should not be reverted blindly: the measured
cause was runner reachability (12 `net::ERR_TIMED_OUT`, 8
`net::ERR_NAME_NOT_RESOLVED`, 5 `EAI_AGAIN`, 77 sixty-second `page.goto`
timeouts, and **zero** genuine assertion failures) while `curl` reached both
live sites with `http=200`. Gating a push of undeployed source on public DNS is
the defect. The question was *where* those specs run, not *whether* — and the
answer is: after deployment, against what was actually shipped.

### SpecKit feature 001 is planned, not built

`specs/001-workshop-curriculum-platform/` carries a full planning set —
`spec.md` (42 `FR-###`, 18 numbered `SC-###` plus `SC-016a`), `plan.md`,
`research.md` and three research files, `data-model.md`, three `contracts/`,
`quickstart.md`, `tasks.md` (91 `T###`) and `checklists/`.

**This section's heading is now WRONG and is kept only until the work settles.**
The claim it used to carry — "`analyze`, `implement` and `review` have not run,
and not one of the 91 tasks has been executed" — is **WITHDRAWN**. Measured
2026-09-01: `specs/001-workshop-curriculum-platform/analysis.md` exists
(15,555 bytes), and `git -C workshop status --short` shows an untracked
`pipeline/` tree carrying real implementation — `run_faster_whisper.py`,
`run_whispercpp.sh`, `build_whispercpp.sh`, `compare_engines.py`,
`detect_media.sh`, `calibrate.sh`, `requirements.txt`, `CALIBRATION.md` — plus
untracked `curriculum/`, `platform/`, `evidence/` and seven `docs/` pages.
Building is underway.

**No completion claim is made here, and none should be inferred.** Everything
named above is UNTRACKED in both repositories (`git ls-files` returns nothing
for `analysis.md`; `workshop`'s own status marks the rest `??`), the work was in
flight while this was written, and no task-by-task status was measured. Re-derive
before relying on any of it:

```bash
ls specs/001-workshop-curriculum-platform/
git -C workshop status --short
```

Treat every capability `tasks.md` assumes as unverified until the "Host
capability" checks above say otherwise — and note those checks moved twice on
2026-09-01, so re-run them rather than reading them.

`CONTINUATION.md` DOES exist at this root and is now §12.10-conformant
(verified 2026-08-31, re-verified 2026-09-01). An earlier revision of this file
claimed it did not; that claim was already false when written — a thin 725-byte session note was tracked
at `18c84ff`, but it satisfied none of §12.10's six mandatory protections, so
the gap was real even though the stated reason for it was not. The document now
carries the §0 resumption prompt, the §3 active-work detail, and the top-of-file
timestamp the rule requires. `scripts/continuation-check.sh` guards it against
going stale: it cross-checks the gap statuses against these carriers, verifies
every entry point it names still exists and is executable, and walks
`git log` to catch a commit that changed a watched governance file WITHOUT
updating `CONTINUATION.md` (§12.10 protection 2). Three-valued: 0 in sync,
1 drift, 2 could not determine.
Honest boundary (§11.4.6): §12.10 protection 1 is internally inconsistent — it
names `docs/CONTINUATION.md` while requiring the file "at the project root".
This repository resolves that in favour of the ROOT and records the ambiguity
rather than silently picking a side.

Do not claim this repository passes a constitutional gate you have not actually
run. Do not treat the absence of a gate as a pass.

## Project overrides of universal rules

None. No clause of the universal constitution is overridden by this project.
Any future override MUST be recorded explicitly here with its justification, per
the `Override §X.Y` form in
`submodules/constitution/templates/Constitution.project.md.template`.

**Do not propose an `Override §11.4.156`.** One was sought on 2026-08-27 and
does not exist: 11.4.156 names and refuses the exemption vocabulary, and the
inheritance contract at the head of this file ("extend them — they do NOT weaken
or override any universal clause") makes a project-local override of an
inherited clause structurally impossible. The umbrella root was brought into
compliance instead. `milosvasic.ru` keeps an active deploy workflow and is a
**known, documented deviation** taken for production uptime; `vasic.digital` is
non-compliant at the provider level with no file-level remedy. **A documented
deviation is not an override** — neither may be recorded, reported, or
rationalised as one. See G4 above.
