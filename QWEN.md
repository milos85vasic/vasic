# vasic — QWEN.md

## INHERITED FROM submodules/constitution/QWEN.md

All rules in `submodules/constitution/QWEN.md` (and the
`submodules/constitution/Constitution.md` it references) apply unconditionally
to this project. Project-specific rules below extend them — they do NOT weaken
or override any universal clause.

When this file disagrees with the constitution submodule, the constitution wins.

> Base agent rules: `submodules/constitution/QWEN.md` — READ IT FIRST.
> The base file is authoritative for any topic not covered here.
> Locate it from any nested depth with
> `submodules/constitution/find_constitution.sh`.

This carrier is read by
the Qwen Code CLI agent (`qwen-code`).
It is one of the four repository-root governance context carriers
(`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) that anchor 11.4.157
requires to be maintained in lockstep. Everything below this paragraph is
byte-identical across all four; only this opening section differs.

### Where the canonical rules actually live

Nothing is copied here. This file is a pointer; the authority is the submodule.

| What | Canonical path in this repository |
|---|---|
| The universal constitution (11,700 lines, 252 `### §` anchors, 1,779,401 bytes, **re-measured on disk 2026-09-03 BEFORE AND AFTER the fourth fast-forward, at `3be10826f3d2` and again at `2887b42e9349` — every figure reproduced identically, sha256 `fe1de96abc84c2fc…` on both sides**; the SAME `Constitution.md` blob `34eff9d8…` as all four superseded pins `902979027a90`, `f16ea779b82a`, `f5876a3b700e` and `3be10826f3d2`, so these figures have not moved across any of the four bumps) | `submodules/constitution/Constitution.md` |
| Claude Code carrier | `submodules/constitution/CLAUDE.md` |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi CLI carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Full anchor corpus companion | `submodules/constitution/CLAUDE_ANCHORS_FULL.md` |
| Parent-walk resolver (works from any nested depth) | `submodules/constitution/find_constitution.sh` |
| Post-pull governance hook | `submodules/constitution/scripts/post_update_hook.sh` |
| Forbidden-command PreToolUse guard | `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` |
| Propagation / covenant gates | `submodules/constitution/scripts/gates/` |

**The pin has now been FAST-FORWARDED FOUR TIMES — 2026-09-01, 2026-09-02, and
again on 2026-09-03, each on explicit operator authorization. Every bump closed
one INSTANCE of the gap; the HOLE that let the first one open unnoticed is now
WATCHED, and the watcher has gone GREEN, RED and GREEN again inside three
days.** `submodules/constitution` is currently checked out at `2887b42e9349`, on
branch `main`, and that **EQUALS**
`git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD` as
re-measured **2026-09-03 after the fourth move**. Every earlier "checked out at
X" in this lineage is WITHDRAWN, and the sequence is kept because it is the whole
lesson: **a pin bumped to equal its upstream does not stay equal** — this one has
now gone stale within a day on FOUR consecutive occasions, and the green below
will not survive the night either.

    902979027a90  ->  f16ea779b82a    2026-09-01, operator-authorized, 0 divergent / 3 behind
    f16ea779b82a  ->  f5876a3b700e    0 divergent / 4 behind
    f5876a3b700e  ->  3be10826f3d2    2026-09-02, operator-authorized, 0 divergent / 2 behind
    remote HEAD 2026-09-02            =  3be10826f3d2     -- EQUAL, no drift   (WITHDRAWN)
    remote HEAD 2026-09-03 (morning)  =  2887b42e9349     -- DIFFERS, direction UNDETERMINED   (WITHDRAWN)
    3be10826f3d2  ->  2887b42e9349    2026-09-03, operator-authorized, 0 divergent / 1 behind
    remote HEAD 2026-09-03 (after)    =  2887b42e9349     -- EQUAL, no drift

**The fourth move was operator-authorized and CLASSIFIED BEFORE it was made**,
and the earlier UNDETERMINED reading was resolved by the authorized `--fetch`
rather than by assumption. The claim this block carried — *"the direction is
UNDETERMINED and this session did not resolve it"*, resting on
`cat-file -t 2887b42e9349` returning *"could not get object info"* — was TRUE
when written and is now **SUPERSEDED**: the fetch brought the object in, and
`git merge-base --is-ancestor 3be10826f3d2 2887b42e9349` returned **TRUE** with
`git rev-list --left-right --count 3be10826…...2887b42e…` returning **`0` / `1`
— 1 behind, 0 divergent**. `git merge --ff-only` performed it, which would have
refused anything that was not a true fast-forward.

**The fourth move touches NO governance document, and that was checked by name
rather than eyeballed.** `diff --stat` across `3be10826f3d2..2887b42e9349` is
**five files, 142 insertions, 20 deletions**, from the single commit
*"fix(helix_code): hc_status reported UP services as DOWN — wrong port + wrong
scheme"*:

    docs/scripts/helix_code_services.docx      Bin 12354 -> 12805
    docs/scripts/helix_code_services.html       47 ++++++--
    docs/scripts/helix_code_services.md         39 +++++---
    docs/scripts/helix_code_services.pdf       Bin 48214 -> 41698
    scripts/helix_code/helix_code_services.sh   76 +++++++++++---

Filtering that name list against every governance path — `Constitution.md`, the
four carriers, `CLAUDE_ANCHORS_FULL.md`, `find_constitution.sh`,
`helix-deps.yaml`, `templates/`, `scripts/gates/`, `scripts/hooks/` and
`scripts/post_update_hook.sh` — returns **NONE**. A service-status script and its
four rendered exports; nothing this repository inherits changed.

Re-measured 2026-09-03 after the move. The index and the submodule working tree
both sit at `2887b42e9349`; the umbrella's `HEAD` still records `f16ea779b82a`,
so the whole four-step move is **STAGED and not yet committed**.
`helix-deps.yaml` records `2887b42e9349` staged in the same change, so gitlink
and manifest moved together exactly as C9 requires — `bash
scripts/verify-manifest-pins.sh` exits **0** at 12 MATCH / 0 DRIFT /
0 UNDETERMINED, and `bash scripts/verify-submodule-remote-sync.sh` is back to
exit **0** at **12 CURRENT / 0 DRIFT / 0 UNDETERMINED**.

**The third move, kept because its lesson is the same one.** It too was
classified before it was made: `merge-base --is-ancestor f5876a3b 3be10826` TRUE,
`rev-list --left-right --count` `0` / `2` — **2 behind, 0 divergent** — and
`git merge --ff-only` performed it. Its `diff --stat` touched **two files, both
inside the constitution's own `scripts/gates/`**; no governance document, no
carrier, not `Constitution.md`.

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

**Nothing this repository records about the corpus has moved in any of the four
bumps, and the fourth was re-measured on both sides of the move rather than
after it.** `Constitution.md` is the SAME git blob
`34eff9d86cadb325721c958d35a411feaad27681` at all five pins. Read on disk at
`3be10826f3d2` and again at `2887b42e9349`, every figure reproduced identically:

| | at `3be10826f3d2` | at `2887b42e9349` |
|---|---|---|
| `Constitution.md` blob | `34eff9d8…` | `34eff9d8…` |
| lines | 11,700 | 11,700 |
| `### §` anchors | 252 | 252 |
| bytes | 1,779,401 | 1,779,401 |
| sha256 | `fe1de96abc84c2fc…` | `fe1de96abc84c2fc…` |
| `du -h CLAUDE.md` | 784K | 784K |
| `du -h Constitution.md` | 1.7M | 1.7M |

**No figure in this file needed correcting for the fourth move** — which is a
measurement, not a rule. The second bump's `diff --stat` likewise touched two
paths, neither a governance document: `design-toolkit` (1 −) and
`docs/codegraph/Status.md` (18 +). Four corpus-neutral moves in a row are a
measured coincidence of what upstream happened to change, **not** a guarantee
that a pin move is corpus-neutral — re-measure after the next one, on both sides.

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
all five pins — `902979027a90`, `f16ea779b82a`, `f5876a3b700e`, `3be10826f3d2`
and `2887b42e9349`, each read directly with `git show <pin>:helix-deps.yaml`. Do
not read the gitlink fix as closing this.

**The residual risk this block used to report as "not started" is now WATCHED,
and the watching instrument is RED.** The risk was real and is restated because
the reason it went unseen is the lesson: any submodule in this tree could sit
arbitrarily far behind its upstream — corpus changes included — with every gate
in this repository green, because C9 compares the manifest to the local gitlink
and **nothing compared the gitlink to the remote**. The bump closed one
INSTANCE, not the CLASS. The class is now covered by
`scripts/verify-submodule-remote-sync.sh`, registered in
`scripts/check-registry.tsv` as `submodule-remote-sync` with a `--prove-failure`
paired proof — which is exactly what R5 demanded. **Watched became FIXED, then
RED, then FIXED again — inside three days.** Re-measured **2026-09-03 after the
fourth fast-forward**, the gate exits **0** at **12 CURRENT / 0 DRIFT /
0 UNDETERMINED** of 12 owned gitlinks probed. The reading this block carried
earlier the same day — *"exits 1 at 11 CURRENT / 1 DRIFT, and the single DRIFT
row is `submodules/constitution` itself"* — is **WITHDRAWN as current** and was
true when written. Every reading in the lineage is now historical:
"6 CURRENT / 6 DRIFT" (2026-09-01), "11 CURRENT / 1 DRIFT" (earlier 2026-09-02),
"12 CURRENT / 0 DRIFT" (later 2026-09-02), "11 CURRENT / 1 DRIFT" (2026-09-03
morning), "12 CURRENT / 0 DRIFT" (2026-09-03, after the fourth move). **Green is
a measurement of today, not a property of the tree** — the gate says so itself,
and TWO cycles of green-then-red-then-green are the proof. **Do not bank this
green; the pin has broken it four times.**
See "Submodule-vs-remote drift" below.

Re-derive. **The pin equals the remote head as of the 2026-09-03 re-measurement,
and that sentence has already been true and then false twice.** When it next
differs, classifying the DIRECTION needs either a scratch bare clone or a
`git fetch` inside the submodule, and a fetch is a mutating command and an
operator decision. The read-only probes below tell you THAT it differs, never
which way:

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
(re-measured 2026-09-03 at pin `2887b42e9349` with `du -h`, unchanged by the
third or fourth bump; both grew from the 654 KB / 1.53 MB
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
make it green.** Re-measured **2026-09-03**,
`bash scripts/verify-content-boundary.sh` exits **1** and prints:

```
LEAK — 15308 surviving match(es) (prose 14552, short 642, name 114); 19 row(s) also could not be determined
corpus MOVED — 18 of 12535 enumerated file(s) changed between the pre- and
       post-analysis fingerprints
```

**THE "NOT REPRODUCIBLE RUN-TO-RUN" FINDING IS RESOLVED, AND THE EARLIER
VERDICT — *"the exact mechanism is UNDETERMINED and was not established"* — IS
WITHDRAWN AS SUPERSEDED, measured 2026-09-04. It was true when written.**

**The algorithm is DETERMINISTIC.** Four runs against a provably frozen copy of
the fleet produced **byte-identical output** — 12939 every time (prose 12368,
short 486, name 85), with every `CB_TRACE` stage count identical at every stage.
The snapshot was a `cp -al` outside the repository with tracked files
de-hardlinked, verified frozen for 60 s before use and bracketed by fingerprints
around every run.

**The mechanism was CONCURRENCY, not the gate.** The live tree was never
quiescent. A fingerprint of exactly what the gate reads, sampled every 20 s,
showed the corpus changing on nearly every sample: two tracked files inside the
private `workshop` submodule were being rewritten continuously by another agent,
and **both are private-side key sources**, so each edit changes the private key
space and therefore the total. Same command, no gate or allow-list edit, live
tree: **12939 / 12939 / 13058 / 12968**. See [[measure-on-a-quiet-tree]].

**The three-run table below is HISTORICAL and is kept only so a stale reading is
recognisable rather than trusted.** Its own conclusion — that nothing changed
during the window, based on `find -newermt '3 hours ago'` returning 0 files — was
the measurement that failed: it was taken over the wrong window and the wrong
set.

| run | tree | leaks | prose | short | name | already_public |
|---|---|---:|---:|---:|---:|---:|
| 1 | pre-edit carriers | 12745 | 12182 | 478 | 85 | 2252 |
| 2 | post-edit carriers | 12846 | 12280 | 481 | 85 | 2261 |
| 3 | pre-edit carriers *(same tree as run 1)* | 12867 | 12299 | 483 | 85 | 2261 |

**THE GATE NOW CARRIES ITS OWN EVIDENCE OF STABILITY — the residual defect was
its SILENCE, and that is fixed.** It fingerprints the exact scanned set before
and after the analysis passes. The enumeration is shared with the analysis by
construction (`cb_ls_tracked` / `cb_ls_untracked` are called by both), because a
second enumeration that merely agrees today would be false reassurance. A green
run now prints positive evidence; a moving run emits `undet` rows **naming the
changed paths** — paths only, never content — and says the counts are not
reproducible. `--expect-corpus <file>` lets two figures be **proved** to come
from the same tree, which is what makes any future re-baselining defensible.
Precedence is unchanged and is asserted by a mutation: **a moving tree cannot
mask a finding** (`LEAKS>0 → rc 1` outranks `UNDET → rc 2`).

**Its first real run caught the tree moving, which is the point:**

```
LEAK — 15308 surviving match(es) (prose 14552, short 642, name 114);
       19 row(s) also could not be determined
corpus MOVED — 18 of 12535 enumerated file(s) changed between the pre- and
       post-analysis fingerprints
```

8 APPEARED, 10 CHANGED, **17 of the 18 inside the private `workshop` submodule**
— consistent with nine agents working in one checkout. `--prove-failure` is
**0 at 59 passed / 28 mutations** (was 43 / 24).

**HONEST BOUNDARY.** The population has moved far past every figure recorded
above, and **no row was judged**: no claim is made about what part of
12867 → 15308 is new content versus a moving tree, and a large document-export
run authorised by the operator is adding files to this repository concurrently.
**Treat 15308 as a reading of a tree that was measurably moving**, not as the
count. The gate now says so itself, which is the whole improvement.

**What survives the instability, and it is the part that matters:** the class A
direction split is stable to within 0.6 percentage points across all three runs,
with **OUTWARD 6240–6241 and INWARD 1538–1544 in absolute terms**. The rows that
move between runs land in UNDETERMINED. See "Class A direction" below.

Every earlier reading is **SUPERSEDED**: `LEAK — 11878 (prose 11356, short 433,
name 89)` from earlier the same day, the **2026-09-02** `LEAK — 11158 (prose
10833, short 268, name 57)`, and `LEAK — 285 (prose 207, short 35, name 43)`.
Note the `name` class fell **89 → 85** and then held at 85 across all three runs
while every other class moved; that is the population changing, not a clearance.
**Treat the percentages and the class shares as the durable figures and the
absolute totals as ±150.**

**THE POPULATION IS FULLY ATTRIBUTED — every row of each run is accounted for by
path, not by sampling.** Every run was taken with `--json`, so the tables here
are aggregated from the gate's own structured row set rather than re-parsed out
of a log, and each aggregate matches its run's own total exactly. **Figures below
are from run 3** (12867); read the class SHARES, which move by less than 0.3
percentage points across the three runs, rather than the counts.

By private source: **`workshop` 12590 (97.8%)**, `ai_interviewing` 277 (2.2%),
`monetization` **0** — the 97.8 / 2.2 split is identical in all three runs. By
public destination, `specs/**` holds **7890**, `submodules/**` ~2800,
`docs/**` 502, `scripts/**` 489, `CONTINUATION.md` 376 and the four root carriers
408 (**102 each**, superseding the 81-per-carrier figure). Inside `specs/**`,
**`specs/002-**` is 6104 and `specs/001-**` is 1786** — the two spec trees are
**61.3% of the entire finding on their own** (61.3–61.5% across the three runs).

**The load-bearing limitation is unchanged: this gate detects CO-OCCURRENCE, not
DIRECTION.** Governance text that originated in these PUBLIC carriers and
propagated INTO a private submodule is indistinguishable, to it, from private
content leaking OUT. **On 2026-09-03 the direction was measured independently,
by git first-commit timestamp, for THREE buckets — the two below, and then class
A, the largest, which had none until that day. Class A is the one to read: see
"Class A direction" in the decision packet. Its answer is NOT uniformly
outward.**

- **Root carriers (324 matches over the four files).** `CLAUDE.md`, `AGENTS.md`,
  `QWEN.md`, `GEMINI.md` were first committed **2026-08-27T00:41:30**. All six
  sampled private counterparts were first committed **2026-09-01 or later**
  (earliest `2026-09-01T21:02:46`). The public text pre-dates the private text
  by five days. **Direction: outward. Cascade, not disclosure.**
- **`submodules/RAG` (1741 matches).** **1623 of them — 93% — come from one
  private directory, `workshop/platform/upstream-contributions/`**, whose name
  states its own role. `submodules/RAG/pkg/grounding` was first committed
  **2026-09-01T11:24:47**; that private staging directory first appeared
  **2026-09-01T21:02:46**, about ten hours LATER. **The public package is the
  older artifact.** `submodules/LLMProvider` has the same shape: 617 of its 692
  matches come from `workshop/platform/gates/`.

**The 94-matches-per-carrier figure this block used to carry is superseded: it
is 81 per carrier, 324 across the four.**

**HONEST BOUNDARY (§11.4.6) — read this before quoting anything above.**
1. **The two probes in this section are FILE-level and SAMPLED** — a first-commit
   comparison on 6 of 16 private sources for the carrier bucket, and on a
   directory for RAG. Neither is a per-string provenance trace. A string can move
   between files, and that was not traced for these two buckets. **The class A
   probe described in the packet below is a different and stronger instrument:
   TEXT-level, per-string, over the complete class with nothing sampled.** Do not
   quote the weaker method's caveat as though it applied to class A, and do not
   quote class A's rigour as though it applied to these two.
2. **The attribution table is complete; a row-by-row JUDGEMENT is not.** Every
   row is placed by path. **No row was judged this session, and none was
   redacted, allow-listed or re-baselined.**
3. **The judged population and today's population are barely the same set.** The
   incident note's two-wave assessment judged **232** matches (29 redacted as
   real disclosures, 203 judged not to be) on **2026-09-01**, and its own split
   was `ai_interviewing` **216** / `workshop` **16**. Today the split is
   `workshop` **12468** / `ai_interviewing` **277** — the dominant source has
   **inverted**. **So the unassessed remainder cannot be computed as
   `<today's total> − 232`.** That subtraction assumes the 232 judged rows are a
   subset of today's ~12,800, and the source split shows they largely are not:
   216 of the
   232 were `ai_interviewing` rows, while 97.8% of today's population is
   `workshop`. **How much the two sets overlap was NOT measured.**
   Do not report any prose row as "cleared".
4. **The `name` class is NOT cleared: 85 matches carrying 9 distinct withheld
   name identifiers, reported by digest only.** The figure this file carried —
   *"89 matches, 8 distinct personal names"* — is **superseded by measurement**,
   not by any clearance: the class went 57 → 89 → 85 while the detector was
   never touched. **A falling name count is not progress.** Direction was NOT
   established for a single name row, and cannot be with this instrument: the
   gate withholds the matched text by design, which is the same protection that
   keeps a real person's name out of an archived artefact.

Re-baselining this figure is an **operator decision** and this session did not
take it. See "Content-boundary re-baseline — the decision packet" below.

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
exemptions, and do not add more.** `.content-boundary-allow` still carries the
same **9 declared pairs**, pardoning **4081** matches as re-measured 2026-09-03
(the 4080 and 4193 figures are superseded; the file is unmodified, so the count
moved with the corpus, not with the allow-list). Every entry needs a real
cross-boundary flow and a mandatory reason, and the operator decides.

### Content-boundary re-baseline — the decision packet (prepared 2026-09-03, NOT decided)

Prepared so an operator can decide; **nothing here was acted on**. No row was
judged, no allow-list entry added, no baseline moved, and the gate still exits 1.

**Three structural classes account for 97.3% of the rows, counted exactly rather
than sampled — and the SHARES are stable across all three runs even though the
totals are not.** Each has a DIFFERENT correct disposition. Counts are run 3:

| Class | Rows | Share | What it is | Direction evidence |
|---|---:|---:|---|---|
| **A · spec trees in this public umbrella** | **7890** | 61.3% | `specs/002-**` 6104 + `specs/001-**` 1786, matching `workshop/docs/session-evidence/`, `platform/backend/`, `pipeline/extract/` | **MEASURED 2026-09-03, text-level, complete, and REPRODUCED on all three runs: ~79% OUTWARD, ~19.5% INWARD.** See "Class A direction" below. **Not uniformly outward — roughly one row in five is private-first.** |
| **B · public reusables extracted from the private tree** | **2703** | 21.0% | `submodules/RAG` 1742, `LLMProvider` 696, `passage` 220, `containers` 19, `verdict` 9, plus `design-toolkit` 17 | File-level and sampled. Direction measured for RAG: the public package pre-dates the private staging copy by ~10 h, and **93%** come from `workshop/platform/upstream-contributions/`. |
| **C · governance prose that propagated OUTWARD** | **1922** | 14.9% | umbrella `docs/**` 502, `scripts/**` 489, 4 root carriers 408, `CONTINUATION.md` 376, `submodules/constitution` 125, `Constitution.md` 22 — matching `workshop/docs/**` | File-level and sampled. The carriers are five days OLDER than every sampled private counterpart. This is the §11.4.157 cascade working. |
| **Remainder — genuinely unassessed** | **352** | 2.7% | `_tests` 88, `_content` 61, `design-system` 58, `_analysis` 39, `.specify` 37, and a long tail | **Not characterised. Not cleared. No direction probe run.** |

**The 85 `name`-class rows do NOT sit in the remainder — they are spread across
every class**: A 50, B 19, remainder 14, C 2, **identical in all three runs**.
**No class is name-clean, so no class can be pardoned wholesale without pardoning
name rows with it.** The earlier split "A 55, remainder 18, B 14, C 2" over 89
rows is superseded.

#### Class A direction — measured 2026-09-03, and it is the strongest probe in this file

**Method, stated so it can be attacked.** Every one of the 7835 class A rows was
dated on BOTH sides at **text level, not file level**: for each matched string,
walk every commit that ever touched the file it was found in, normalise that
blob with the gate's own normalisation (`[^A-Za-z0-9]+` → space, lowercased —
validated against the gate on a 24-of-24 sample), and take the earliest commit
whose content actually contains the string. That dates the TEXT, not the file
that carries it, which is the defect in the class B and C probes. It was then
**widened to corpus level**: for every row, the earliest appearance of that
string ANYWHERE in the public umbrella was compared against its earliest
appearance ANYWHERE in the private repository, so a string that moved between
files is still caught. 55 public and 489 private path-histories were walked for
the pairwise dating; the widening ranged over the **9,414 file-revisions** the
two histories hold (umbrella 8,213, `workshop` 1,201). **Nothing sampled, nothing
extrapolated** — the walk is chronological and skips a blob only when no
still-undated string could be affected by it, which is an exact pruning rather
than a shortcut: a string already dated cannot be dated earlier by a later
commit. Verified for the one case that could have biased it — no string was
found in both private repositories, so the two-repo merge changed no date.

**The probe was run independently against ALL THREE gate runs, and this is the
answer to the instrument's own instability**: the totals move, the direction does
not.

| run | class A rows | OUTWARD | INWARD | UNDETERMINED |
|---|---:|---:|---:|---:|
| 1 | 7835 | **6241** (79.7%) | **1544** (19.7%) | 50 (0.6%) |
| 2 | 7872 | **6240** (79.3%) | **1538** (19.5%) | 94 (1.2%) |
| 3 | 7890 | **6240** (79.1%) | **1538** (19.5%) | 112 (1.4%) |

**OUTWARD varies by ONE row and INWARD by SIX across three runs whose totals
differ by 122.** Every extra row a noisier run emits lands in UNDETERMINED —
these are strings not committed on one side, i.e. working-tree-only text. **The
direction finding is therefore robust to the count instability**, and it is the
figure to act on.

**The widening moved rows in BOTH directions, which is why it is not a
rationalisation**: on run 1, 113 rows flipped INWARD → OUTWARD and **178 flipped
OUTWARD → INWARD**. A one-sided correction would have been evidence of a biased
probe.

**Lead times.** OUTWARD: median 6.1 h, max 611 h. INWARD: median 0.5 h, max
465 h, with **92% of inward rows inside 24 h** — spec and implementation are
being written the same day, in both orders.

**Where the INWARD rows sit, because that is what an operator must look at:**
of the 1544 on run 1, **1084 (70.2%) are private SOURCE CODE**, 153 private session-evidence briefs,
117 private training docs, 56 other private docs, 40 data/config, 26 other — and
**68 are `workshop/chapters/01/`, the private teaching-session material**, all
from one JSON artefact, landing in `specs/001-…/tasks.md` (45) and
`specs/002-…/tasks.md` (23). By public file the inward rows concentrate in
`specs/002-…/contracts/knowledge-graph.md` (431), `specs/002-…/tasks.md` (410)
and `specs/001-…/tasks.md` (279). By gate class: 1468 prose, 76 short, 0 name.

**HONEST BOUNDARY — three limits, and the first is the one that matters.**
1. **"Private committed first" is NOT a finding of disclosure.** It establishes
   an ORDER, nothing more. A task line written in a commit message, a symbol
   name, or a design decision made in code and then written up in the spec all
   produce INWARD rows with no private content having left the boundary. **~1540
   rows are not ~1540 leaks, and must never be reported as such.** What the number
   does establish is that the reassuring story — *"the specs are outward
   propagation"* — is true for four rows in five and **false for the fifth**.
2. **The 50 UNDETERMINED rows are the entire class A `name` population**, all in
   `specs/001-…/research/transcription.md`, all carrying ONE withheld identifier.
   They are undetermined because the gate REDACTS the matched text, so there is
   nothing to date — the protection and the blind spot are the same mechanism.
   A weaker FILE-level fallback splits them 30 outward / 20 inward, and **the 20
   inward include 15 rows whose private side is an `ai_interviewing` document
   first committed 2026-08-12, twenty days before the public spec file, and 5
   whose private side is the private recording-notes PDF first committed
   2026-08-31.** That is file-level only, it is weaker than the text-level
   result, and it is **not** a determination — it is recorded because it points
   at the rows an operator should open first.
3. **No row was judged, redacted, allow-listed or re-baselined**, and the gate
   still exits 1.

**What an operator is actually being asked to decide — four options, with the
cost of each stated rather than implied:**

1. **Do nothing.** The gate stays red and stays readable. Cost: the signal keeps
   degrading — 232 → 11,158 → 11,878 → ~12,800 in three days — until nobody reads
   it. **And the total is now known not to be reproducible run-to-run**, which
   makes "watch the number" a weaker plan than it looks.
2. **Allow-list classes B and C** (2700 + 1861 = **4561** rows, as declared
   pairs with reasons). Cost: **an allow-list entry hides the row from the next
   reader**, which is exactly the failure mode this file warns about elsewhere;
   it would pardon **21 `name` rows** along with them; and the direction evidence
   behind both classes is **file-level and sampled**, which is weaker than what
   class A now has.
3. **Teach the gate direction** — a git-timestamp or provenance pass, so
   outward propagation is subtracted with its RECALL COST printed, the way the
   detector already subtracts already-public keys. Cost: real work. **The class A
   probe is a working prototype of exactly this**, run offline over 9,414
   file-revisions in under a minute, so the feasibility question is answered.
   It is still the only option that raises precision without hiding a row.
4. **Judge the ~1540 class A INWARD rows** as a fresh assessment wave — **not all
   ~7870.** The direction probe has cut the reading assignment by 80% and named
   where it concentrates: 1084 rows against private source code, 68 against the
   private teaching-session material, three public files holding 1120 of them.
   Cost: still the largest, and still the only option that could find a genuine
   new disclosure.

**Recommended ordering — a recommendation, not a decision: 4 (now bounded to the
~1540 inward rows plus the 50 undetermined name rows), then 3, then 2 for whatever
survives.** The reason for putting 4 first has CHANGED: class A is no longer the
class with no direction evidence — it now has the best evidence in this file, and
that evidence is what makes the reading assignment small enough to be worth
starting.

**Do NOT read this packet as clearance.** It places every row by path; it judges
none. Options 2 and 4 both require reading private material and are operator
work.

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
public. As of 2026-09-03 BOTH HALVES ARE MEASURED FROM THIS TREE — the
"cannot be probed" claim this section carried is WITHDRAWN as FALSE.** Its
GitHub origin `vasic-digital/design-toolkit` was flipped **public** on
2026-09-01 after a clean full-history privacy audit.

**What changed is the checkout, not the mirror.** A `gitlab` remote **IS**
declared for `design-toolkit` today — added by that submodule's own commit
`7d9240e fix(§11.4.6): record the GitLab mirror; absence needs its own evidence`,
which arrived with the gitlink. Two sentences that stood here are therefore
withdrawn as false, not merely stale: *"this checkout wires up **no** GitLab
remote"* and *"neither the visibility nor the lag can be re-measured here"*.
**Nothing was added to this repository's configuration to obtain the figures
below** — the remote was already there and every probe is read-only.

Measured **2026-09-03**, all four values:

| | GitHub `origin` | GitLab `gitlab` |
|---|---|---|
| visibility | **public** (`gh api … --jq .visibility`) | **private** (`glab api projects/… .visibility`) |
| HEAD | `e7f3815ec35c` | `520c436c2c2a` |
| last push / activity | 2026-09-01T14:14:56Z | 2026-08-08T09:05:45Z |

**The lag is 6 commits, and it is lag, not divergence.**
`git -C design-toolkit merge-base --is-ancestor 520c436c e7f3815e` returns
**TRUE**; `git rev-list --left-right --count 520c436c...e7f3815e` returns
**`0` / `6`** — 0 commits exist on GitLab that GitHub lacks, 6 exist on GitHub
that GitLab lacks. Both commits were already in this checkout's object store, so
no fetch was needed to classify the direction. **The "5 commits" figure is
SUPERSEDED by 6**, and the *reason* it moved is recorded: it was correct on
2026-09-01 against GitHub HEAD `5467a888…`, and the GitHub side has since
advanced one commit to `e7f3815e`. The GitLab side has not moved at all —
`520c436c…` is the same commit both readings name.

**The mirror is BEHIND a public repository, so the 6-commit gap carries no
content-boundary risk**: every commit GitLab lacks is already published on the
public GitHub side. Direction matters here and it is measured, not assumed.

```bash
git -C design-toolkit remote -v                          # BOTH: origin (GitHub) + gitlab
git -C design-toolkit ls-remote origin HEAD              # e7f3815ec35c…
git -C design-toolkit ls-remote gitlab HEAD              # 520c436c2c2a…
git -C design-toolkit rev-list --left-right --count 520c436c...e7f3815e   # 0  6
glab api projects/vasic-digital%2Fdesign-toolkit         # .visibility -> private
```

Honest boundary (§11.4.6), and it is narrower than it was:
`scripts/verify-submodule-remote-sync.sh` probes the declared **`origin`** only,
so its CURRENT verdict for this submodule is a true statement about GitHub and
still says **nothing** about the mirror — the gate did not gain mirror
awareness, the operator gained a way to ask by hand. `upstreams/gitlab.sh` in
that submodule is **`.disabled` on purpose**, so no tooling pushes to the mirror
and the gap does not close by itself; renaming it is an operator decision that
starts publishing to a private mirror. **Do not write as though the two mirrors
match, and do not quote "5 commits" as a live figure — re-run the block above.**

`submodules/containers` (`vasic-digital/containers`) was added under §11.4.76,
which mandates that module for ANY containerised workload and forbids
reimplementing it.

**The sentence that used to finish that paragraph — *"a hand-rolled
`Containerfile` is a violation, not merely an inferior choice"* — is WITHDRAWN
as of 2026-09-04. It overstated the anchor, and an overstated rule is as
unhelpful as a missed one.** §11.4.76 was re-read verbatim. Its list of what the
module is authoritative for is *"runtime auto-detection, endpoint discovery,
lifecycle/health management, compose orchestration, cross-build, emulator
integration, and on-demand service boot"*; clause 4 forbids adding a missing
*"runtime … or lifecycle primitive"* *"as a parallel implementation inside the
consuming project"*; and the closing line names the offence as *"reinventing
compose orchestration in-project"*. **A container image recipe appears in none
of those.** Nor could it: the module ships `*.Containerfile` itself under
`pkg/crossbuild`, and its own planned gate `CM-CONTAINERS-USED` scans a
`Dockerfile*`-touching change **for an import of `digital.vasic.containers/…`**
— it treats such a file as a trigger to look for the import, never as the
violation. Read it precisely: **what is forbidden is the hand-rolled runtime,
lifecycle and orchestration logic AROUND a container file, not the file.**

**Two claims this block carried are WITHDRAWN as of 2026-09-03, and both were
false in the direction that flattered the tree.**

- *"The submodule is present for the workload `specs/001-…` plans."* **It has a
  real consumer now.** `_tools/containers/` was committed 2026-09-03 (`460266c`)
  with 7 tracked files — `go.mod` requiring `digital.vasic.containers`, `go.sum`,
  `cmd/site-build/main.go`, `compose/compose.sites.yml`, `compose/jekyll-build.sh`
  — and its own README records the measurement that made it necessary: before it
  existed, `grep -rn 'digital.vasic.containers'` outside `submodules/` and
  `workshop/` returned **zero** hits. **The gitlink was declared,
  manifest-pinned, cascade-verified and unused** — every gate green over a
  submodule nothing consumed.
- *"Nothing in this repository has yet been built or run in a container."*
  **False.** A fleet container is running on this host right now: `podman ps`
  shows `workshop-curriculum_platform_1` (image `docker.io/library/alpine:3.20`)
  **Up 2 hours, healthy**, serving `/opt/workshop/bin/workshop-server` — the
  private `workshop` submodule's platform workload, not the umbrella root's.

**And a third fact this block never carried at all: the umbrella root has been
shipping container files and their hand-rolled runtime logic since 2026-06-26.**
`_tools/helixtranslate-container/Containerfile`,
`Containerfile.translator` and `run.sh` are **tracked**, first committed in
`32dfdbd` — three months before `submodules/containers` was adopted. `grep`
finds **no** reference to `submodules/containers` or `digital.vasic.containers`
anywhere under that directory. It is recorded here rather than left for the next
reader to discover.

**A second clause of that paragraph is WITHDRAWN, by name.** It read
*"referenced by 10 tracked files including `_tools/distribute-helixtranslate.sh`
and four `_tools/gen/` translation scripts"*, and it silently merged two
different paths. Re-measured 2026-09-04:

- **10 tracked files reference the DIRECTORY** `_tools/helixtranslate-container/`
  — the four carriers, `CONTINUATION.md`, `_analysis/CONTAINER-DISTRIBUTION.md`,
  `docs/environment-adaptability/AUDIT.md`, `docs/workshop-curriculum/RECON.md`,
  `scripts/audit-environment-assumptions.sh`, and
  `_tools/distribute-helixtranslate.sh` (whose reference is composed at line 65
  as `ASSETS="$HERE/helixtranslate-container"`, which a literal-path `grep`
  misses). The 10 is right; nine of the ten are documentation or an audit rule.
- **No `_tools/gen/` file is among them.** Those scripts reference
  `_tools/helixtranslate-container.sh` — a **different file**, the SSH shim —
  and there are **six** of them, not four: `translate-ui.py`,
  `translate_ui_all.py`, `translate_ui_batch.py`, `translate_ui_chunked.py`,
  `translate_ui_slow.py`, `repair_ui_terms.py`.

**The surface was then judged file by file, and it splits three ways rather than
two.** Full table, with the measurement behind each verdict:
[`_tools/containers/README.md`](_tools/containers/README.md). In brief — the two
`Containerfile`s are **not** violations (see the withdrawal above);
`_tools/helixtranslate-local.sh` **was** one and is **CONVERTED**, its frozen
`podman` literal replaced by the module's own `runtime.AutoDetect` reached
through `_tools/containers/cmd/runtime-probe`, verified on this host at all
three exit codes; `_tools/distribute-helixtranslate.sh` is one whose replacement
exists but is **UNVERIFIED**; `_tools/helixtranslate-container.sh` and
`_tools/helixtranslate-container/run.sh` are violations that **cannot be closed
from this tree** and now carry declared exceptions; and
`_tools/translate-fleet.sh` is **not** a violation.

**That last verdict was reversed by measurement mid-task and the reversal is the
point.** Its `host == amber.local ? docker : podman` looked like hand-rolled
runtime detection. It is not: the module's own `pkg/remote.RemoteHost` carries a
declared `Runtime string` field — *"the container runtime on this host"* — and
ships **no** remote runtime detector to defer to
(`grep -rn 'DetectRuntime\|AutoDetect' pkg/remote pkg/discovery` outside tests
matches nothing). Naming a REMOTE host's runtime is configuration the module
expects a consumer to supply. Naming the LOCAL host's runtime is not, which is
exactly why the same-looking literal in `helixtranslate-local.sh` was a real
violation and was converted.

**What blocks the rest is one missing upstream primitive, and §11.4.76(4) says
where it belongs.** Both un-closeable files perform a one-shot `run --rm -i`
that streams a document on **STDIN**. Measured at gitlink
`d940b51fc247c285c805799452992da8d09c75b9`: `pkg/runtime`'s `ContainerRuntime`
interface declares Name, Version, IsAvailable, Start, Stop, Remove, Status,
List, Stats, Exec and Logs — **no `Run`, no `Create`**, so there is no
ephemeral-run primitive at all; `Exec(ctx, id, cmd []string)` accepts no stdin;
and the module's only `WithStdin`
(`pkg/remote/connection/interface.go:146`) sits in an interfaces-and-options-only
package that nothing implements and no constructor returns. The fix is an
upstream change to `vasic-digital/containers`, **never a parallel implementation
here** — and until it lands, a working script is not to be replaced by an
unverified rewrite.

**Honest boundary (§11.4.6): whether those particular images were ever built or
run CANNOT BE DETERMINED from this checkout, and the conversion did not change
that.** Re-measured 2026-09-04: `podman images` on this host matches
`helixtranslate` **zero** times, and both remote hosts are **unreachable** —
`getent hosts` fails to resolve `thinker.local` and `amber.local`, and `ssh
-o BatchMode=yes` returns **rc 255** for both, which is a measured absence and
not a broken resolver. So the converted `helixtranslate-local.sh` is verified
for runtime resolution and exit codes only, **never for an actual translation**,
and it says so in its own header. Absent image, absent evidence: this is a 2,
and a 2 is never a pass. Re-derive rather than trusting any of the above:

```bash
git ls-files | grep -iE 'containerfile|dockerfile|compose'   # the tracked surface
git ls-files _tools/containers/                              # the consumer
git grep -l '_tools/helixtranslate-container/' -- .          # 9 literal + 1 composed = 10
podman ps --format '{{.Names}} {{.Image}} {{.Status}}'       # what is actually running
podman images | grep -i helixtranslate                       # expect no rows on this host
( cd _tools/containers && go build -o bin/runtime-probe ./cmd/runtime-probe \
    && ./bin/runtime-probe )                                 # the module's own answer
for h in thinker.local amber.local; do getent hosts "$h" || echo "$h unresolvable"; done
```

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

**It has now exited 0 twice and 1 three times, and the SAME submodule caused
every red.** The "it exits 0 as of 2026-09-02, the first time it has ever done
so" that stood here is **WITHDRAWN as current**; so is the "back to 1 on
2026-09-03" that replaced it. Five readings, all real, kept because the movement
is the record — and because readings 3→4→5 are the clearest evidence in this file
that a green here does not survive the day:

```bash
bash scripts/verify-submodule-remote-sync.sh
# 1 — 6 CURRENT,  6 DRIFT, 0 UNDETERMINED   (2026-09-01)
# 1 — 11 CURRENT, 1 DRIFT, 0 UNDETERMINED   (2026-09-02, after five bumps landed)
# 0 — 12 CURRENT, 0 DRIFT, 0 UNDETERMINED   (2026-09-02, after the authorized fast-forward)
# 1 — 11 CURRENT, 1 DRIFT, 0 UNDETERMINED   (2026-09-03, the SAME pin went stale again)
# 0 — 12 CURRENT, 0 DRIFT, 0 UNDETERMINED   (2026-09-03, after the FOURTH authorized fast-forward)
```

The 2026-09-03 DRIFT row, verbatim, before it was closed:
`submodules/constitution 3be10826f3d2 2887b42e9349 DIFFERS`. The gate's own
words at the time — *"The difference is DETERMINED; the direction is NOT, because
the remote commit is not in this checkout's object store."* **The operator then
authorized the `--fetch`, which resolved it as 1 behind / 0 divergent, and
`git merge --ff-only` closed it.** That is the designed sequence: the gate states
what it cannot know, an operator decides, and only then does a pin move.

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

**Do not bank the green — and note that this file already said so, and was
right.** This pin has now gone stale within a day on **three** consecutive
occasions, the third measured 2026-09-03 against a green recorded 2026-09-02.
The correct standing conclusion is that the constitution pin is an operator
decision that RECURS, not a task that completes.

**Note what this gate is blind to even when a row reads CURRENT.** It probes the
declared **`origin`** only. `design-toolkit` has a GitLab mirror, and the
parenthetical that stood here — *"this checkout declares no remote for (`git -C
design-toolkit remote -v` → `origin`, GitHub, only)"* — is **WITHDRAWN as
false**: a `gitlab` remote IS declared there today. What survives is the real
limitation: the gate does not probe it. Re-measured 2026-09-03, this row reads
`design-toolkit e7f3815ec35c e7f3815ec35c CURRENT`, which is a true statement
about GitHub while the mirror sits **6 commits behind** at `520c436c2c2a`. A
gate reporting CURRENT is not evidence about a remote it never asked. See
"Owned submodules" above for the measured mirror figures.

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
real finding, 2 COULD NOT DETERMINE, and 2 is never a pass.** **The whole suite
was re-run on 2026-09-03 and the results below are that run.** Four verdicts
moved since 2026-09-02 and every superseded figure is named where it stood, not
silently replaced. They remain dated observations, not standing facts.

```bash
bash scripts/continuation-check.sh              # 0 — 8 PASS/0 DRIFT/0 UNDET/7 NOTE
bash scripts/verify-governance-cascade.sh       # 0 — 12 PASS/0 FAIL/0 ENV/8 NOTE (C0..C9)
bash scripts/verify-manifest-pins.sh            # 0 — C9 standalone: 12 MATCH/0 DRIFT/0 UNDET of 12
bash scripts/verify-check-registry.sh           # 0 — 43 then 45 PASS in ONE session; --run-proofs 0 at 65 PASS
bash scripts/audit-hardcoded-paths.sh           # 1 — WENT RED: 1 occurrence, 1 file; see below
bash scripts/audit-environment-assumptions.sh   # 0 — 567 allow-listed, 666 baselined, 2247 files
bash scripts/verify-content-boundary.sh         # 1 — RED BY DESIGN, see "Content boundary"
bash scripts/verify-submodule-remote-sync.sh    # 0 — RED, THEN GREEN AGAIN: 12 CURRENT/0 DRIFT
bash scripts/verify-provider-ci.sh              # 1 — 1 CONFIRMED/6 UNVERIFIED/2 HISTORICAL
bash scripts/verify-all-constitution-rules.sh   # 1 — 173 PASS/96 FAIL/2 ERROR of 271 gates
bash scripts/lumen-index-doctor.sh              # semantic index health
bash scripts/ollama-tune.sh                     # local inference host tuning
```

**Four verdicts that moved on 2026-09-03, stated as withdrawals:**

| Instrument | Was (2026-09-01/02) | Is (2026-09-03) |
|---|---|---|
| `verify-check-registry.sh` | 0 — **41** PASS | 0 — **43**, then **45** PASS *within the same session* |
| `audit-hardcoded-paths.sh` | **0** — 6 file(s) allowed | **1** — 1 occurrence, 12 file(s) allowed |
| `audit-environment-assumptions.sh` | 0 — **531** allow-listed, **2166** files, **683** baselined | 0 — **567** allow-listed, **2247** files, **666** baselined |
| `verify-submodule-remote-sync.sh` | **0** — 12 CURRENT | **1** — 11 CURRENT / 1 DRIFT, then **0** — 12 CURRENT after the fourth authorized fast-forward, *both on 2026-09-03* |
| `verify-content-boundary.sh` | 1 — **11878** (prose 11356, short 433, name 89) | 1 — **15308** (prose 14552, short 642, name 114) with **`corpus MOVED — 18 of 12535 files`**; RED BY DESIGN, and the gate now REPORTS its own instability instead of hiding it |

**`audit-hardcoded-paths.sh` went RED and the finding is REAL, not a re-baseline.**
Exit **1**, `❌ 1 occurrence(s) across 1 file(s)`, scanning 6054 files across 14
repositories. The single occurrence is
`workshop/chapters/01/transcript/accuracy-plan.json:3`, a JSON value carrying
this developer host's absolute checkout path. **It is INSIDE the private
`workshop` submodule and was NOT edited from here** — a finding inside a
submodule is fixed inside that submodule and returns as a gitlink bump, which is
an operator decision. Two other figures in the same run also moved and are
recorded rather than glossed: files **explicitly allowed** 6 → **12**, and
**377 baselined occurrences** are printed on every run as declared, known,
unfixed debt.

Five of those need reading carefully rather than glancing at:

- **`verify-check-registry.sh` used to print 5 DEBT rows on every run. As of
  2026-09-02 it prints ZERO — all five owed paired proofs were written, and each
  was verified in BOTH directions: it passes on this tree AND it fails against a
  deliberately weakened throwaway copy of the gate it guards.** Every mutation is
  DATA rather than a code edit, so each control is green by construction — the
  "inoperative proof" defect the registry itself documents.
  `setup-agents-wizard-suite` also owed **three-valued** and now demonstrates
  rc 2 four ways. Re-measured **2026-09-03**: **43 PASS / 0 FAIL / 0 DEBT /
  0 UNDET / 0 NOTE**, exit 0. The **41 PASS** figure measured 2026-09-02 is
  SUPERSEDED — two further checks were registered in the intervening day, which
  is R5 working rather than drift; the PASS count has now moved
  23 → 25 → 31 → 41 → 43 for that reason alone. The five `debt` rows became
  `check` rows, and no new unregistered `*.sh` appeared, so R5 stays green.

  **`--run-proofs` now exits 0** — re-measured 2026-09-03 at
  **65 PASS / 0 FAIL / 0 DEBT / 0 UNDET / 0 NOTE**. **The reading this bullet
  carried — *"still exits 1, at 54 PASS / 5 FAIL"* — is WITHDRAWN**, and all
  five named rows were re-checked individually: `provider-ci`,
  `submodule-remote-sync`, `mutation-anchor-rot`, `private-object-exposure` and
  `remedy-executability` each now show **3 PASS / 0 FAIL**. The one previously
  called REAL is genuinely resolved: `provider-ci` no longer fails
  *"M6b no repository or owner name in body"*; its `--run-proofs` row reports
  `PASS M1 verdict is not constant … got 5 distinct`. The other four were
  described as false positives of the hollow-proof heuristic (proofs that ran
  and returned 0 but summarised in prose rather than the `M<n>` / "N mutations"
  form) and now report in the recognised form. **The heuristic was NOT
  loosened** — it is the only thing between the registry and a proof that
  returns 0 while exercising nothing. **This run takes roughly an hour**; a
  plain run verifies proof *structure* only and is not a substitute.

  **Honest boundary (§11.4.6): a 0 here means every registered proof executed
  and reported, not that this tree is defect-free.** The sweep's **DROP**
  direction remains open and is printed on every run: its ADD direction is
  proved, while assertion **L1** deletes a gate, measures the count falling
  `3 → 2`, and records that the sweep still exits 0 because it keeps **no
  expected-gate ledger**.

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
  that split before quoting the exit code.** The instrument has now moved six
  times without the audit itself being edited once. Every state is recorded,
  because the movement is the point.

  **Current state, re-measured 2026-09-03:** exit **0**,
  `✅ no NEW frozen environment assumptions (567 justified occurrence(s) allow-listed)`,
  scanning **2247 files across 14 repositories in 12 classes**, printing
  **666 baselined occurrences** and **1 out-of-scope third-party assumption**.

  **The 2026-09-02 reading — 531 allow-listed, 2166 files, 683 baselined — is
  SUPERSEDED, and all three numbers moved without the audit being touched.**
  `git status --short scripts/audit-environment-assumptions.sh` is EMPTY, so the
  instrument is byte-identical to the one that produced the old figures; the
  scanned fleet grew (2166 → 2247 files) because the submodules under it did.
  Baselined debt fell 683 → **666** (−17) and the allow-list grew 531 → **567**;
  **this file does NOT claim which of those is a fix and which is a new
  exemption — that was not measured this session.** Do not read the −17 as
  seventeen defects repaired.

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
    run against the fixed tree reports **8** stale rules. **`_tests/env.js` is now
    TRACKED** — added in commit `402a8c7`, confirmed 2026-09-03 with
    `git ls-files --error-unmatch _tests/env.js`. The note that stood here
    ("`_tests/env.js` is **UNTRACKED**, so `git ls-files` does not yet show it to
    the gate") is **WITHDRAWN**: every gate that enumerates via `git ls-files`
    now sees it.

  Still printed on every run by design, re-measured 2026-09-03: **666 baselined
  occurrences** — declared, known, unfixed defects; the **683** figure is
  superseded — and **1 frozen assumption inside a third-party gitlink**
  (`submodules/superspec/.github/workflows/ci.yml`, a pinned
  `python-version: "3.12"`), reported out-of-scope under §11.4.156(C) /
  §11.4.29 so it is never silently omitted. **A baseline is recorded debt, not
  a justification, and an allow row is not a fix — and ANY exit code here, green
  or red, is a measurement of today, not a guarantee about tomorrow's fleet.
  This instrument's verdict has changed five times without the audit itself
  being edited once; the fleet moves under it. Re-run it, never quote it.**
- **`verify-content-boundary.sh` exits 1 and is MEANT to.** Re-measured
  2026-09-04: **15308** (prose 14552, short 642, name 114) with **19 undetermined
  rows**, of which the load-bearing one is `corpus MOVED — 18 of 12535 enumerated
  file(s) changed`. The earlier claim that **"the total is now known not to be
  reproducible run-to-run"** is **SUPERSEDED**: the algorithm is deterministic —
  four runs on a frozen snapshot were byte-identical — and the movement is
  concurrent editing, which the gate now measures and names rather than absorbing
  silently. See the
  "Content boundary" section above. A 1 from this gate is a reading assignment,
  not a regression — but the *reading* has not kept pace with the *population*,
  and that gap is still the finding. **What DID move on 2026-09-03 is the
  reading assignment's SHAPE**: class A, 61.5% of the population, now has
  text-level direction evidence over its complete row set — 79.7% outward,
  ~19.5% inward — so the rows an operator must actually open number about 1540,
  not about 7870. Nothing was judged, allow-listed or re-baselined to achieve that.
- **`verify-submodule-remote-sync.sh` exits 0 as of 2026-09-03, and that is a
  measurement of today rather than a property of the tree.** Re-measured after
  the fourth authorized fast-forward: **12 CURRENT / 0 DRIFT / 0 UNDETERMINED**.
  Both **"six owned gitlinks are out of sync"** (2026-09-01) and **"11 CURRENT /
  1 DRIFT"** (2026-09-03 morning) are WITHDRAWN as current. **This gate has now
  gone red on the constitution pin four times; treat a green as perishable.**
  Bumping is an operator decision. See "Submodule-vs-remote drift" above. It is
  the ONLY instrument on this list that looks at a remote at all, and even it
  probes `origin` only.
- **`audit-hardcoded-paths.sh` exits 1 as of 2026-09-03 and the 1 is REAL.**
  One occurrence, in `workshop/chapters/01/transcript/accuracy-plan.json` — a
  developer-host absolute path frozen into a tracked JSON value inside a private
  submodule. Not fixable from this tree; see the block above the bullet list.
- **`verify-provider-ci.sh` exits 1 and the 1 is CONFIRMED, not undetermined.**
  One standing provider-side trigger, on `vasic-digital/vasic-digital.github.io`.
  Six rows are separately UNVERIFIED and are printed regardless of exit code, by
  the script's own documented rule: *"Precedence: CONFIRMED (1) outranks
  UNDETERMINED (2) outranks clean (0)"* — so **the 1 hides no 2 here, and the 6
  UNVERIFIED rows are still open**. See G4 below.

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
(**re-measured 2026-09-03 via `scripts/verify-provider-ci.sh`: `pages=enabled
build_type=workflow source=main:/ status=built` — unchanged**) — that workflow is
the **sole** publish path for the live site. There is no `gh-pages` branch and no
`docs/` folder, and the repository root is Jekyll SOURCE (Liquid + front matter),
so it cannot be served raw from a branch. `_tools/deploy-langs.sh` is **not** a
substitute: it generates, commits and pushes source, then `sleep`s waiting for
the server to rebuild — it covers generation and push, none of the publish step.
**Do not disable, rename, or otherwise "fix" `pages.yml`.** `vasic.digital` needs
no build step (committed static HTML), but its Pages source is still
`build_type: "legacy"` (**re-measured 2026-09-03: `pages=enabled
build_type=legacy source=main:/ status=built`, and the probe classifies it
CONFIRMED — 41 provider-generated `pages build and deployment` runs in the last
30 days, newest 2026-09-01T19:54:02Z**), so every push still triggers a
provider-side run even though `git ls-files '.github/workflows/*'` in that
submodule returns **zero** files. **This is the fleet's only CONFIRMED standing
provider-side trigger.**

`design-toolkit` adds **no** §11.4.156 CI surface of its own: the same
`git ls-files '.github/workflows/*'` returns **0** there too (re-measured
2026-09-03), so its flip to public created no new provider-side trigger — and
the 2026-09-03 probe confirms it from the provider side as well, `NONE` on both
its GitHub origin and its GitLab mirror (`jobs_enabled=true`, but
`active-pipeline-schedules=0` and `pipelines(listed=0, in-window=0)`).

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
  check.

  **RE-MEASURED 2026-09-03 — exit 1, and the verdict per repository is NOT what
  this entry's prose implies.** The probe covered **22 repositories / 40
  upstream rows** over a 30-day window, with `gh` and `glab` both authenticated:
  **1 CONFIRMED · 6 UNVERIFIED · 2 HISTORICAL · 30 no-trigger · 1 out-of-scope.**

  | Repository | Reading 2026-09-03 | Meaning |
  |---|---|---|
  | `vasic-digital/vasic-digital.github.io` | **CONFIRMED** — `pages` enabled, `build_type=legacy`, 41 provider-generated runs in window, newest 2026-09-01T19:54:02Z | The **only** standing provider-side trigger in the fleet. Confirms this entry's `legacy` claim, with no file-level remedy: `git ls-files '.github/workflows/*'` returns 0. |
  | `milos85vasic/milosvasic.ru` | **HISTORICAL**, *not* confirmed — `pages` enabled, **`build_type=workflow`** (re-verified), 34 provider-generated runs since 2026-08-04 but **newest 2026-08-06T20:29:49Z** | `pages.yml` remains the SOLE publish path and **MUST NOT be disabled, renamed or "fixed"**. The gate's own words: those runs are *"a fact about the past, NOT a claim that a push today triggers one"*. |
  | `milos85vasic/vasic` (this root) | **clean** — `active=0 inert=1`, 0 provider-generated runs | The umbrella half of G4 holds. |
  | 6 rows on `gitflic.ru` / `gitverse.ru` | **UNVERIFIED** | No read-only API adapter is registered for those hosts. **rc-2 material — not a pass.** |

  **Two findings worth acting on, neither acted on here.** (a) The probe's own
  remediation output flags **21 repositories where Actions are ENABLED while the
  tree declares zero active workflow files** — disabling Actions is the only
  file-independent way to stop provider-generated runs, but it would also stop
  any Pages *workflow* build, so `milosvasic.ru` must be excluded from any such
  sweep. (b) The `milosvasic.ru` HISTORICAL rows mean **34 runs occurred that no
  setting readable today explains**; confirming that the setting which produced
  them is genuinely gone is operator-only.

  **Cost of the umbrella half: no server-side enforcement on
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

**A full run COMPLETED on 2026-09-03 and this is its split, observed rather than
reported: exit 1 — `❌ SWEEP: FAIL — 96 FAIL + 2 ERROR out of 271 gate(s)`, i.e.
173 PASS / 96 FAIL / 2 ERROR of 271.**

**The "186 PASS / 95 FAIL / 6 ERROR of 287 gates" this block carried is
WITHDRAWN**, and it was never a state this file observed — it was recorded as a
*reported prior measurement* from a run that had not finished. It is not
comparable to the run above in any case: **the gate population itself moved
287 → 271**, so no per-count comparison between the two is meaningful. The
population has now moved twice (57 → 286 → 287 → 271) without this repository
editing the sweep, because the sweep discovers its gates from the constitution
submodule.

Three FAILs from the 2026-09-03 run are named here because they are actionable
in THIS tree, unlike the two classes below: `cm_readme_badge_row_at_top`
(§11.4.259, no badge row atop `README.md`), `cm_zero_findings_audit_sweep`
(§11.4.261, no `scripts/audit/zero_findings_sweep.sh`) and
`cm_zero_findings_monotone_ratchet` (§11.4.261(C), no
`docs/findings/zero_findings_ratchet.tsv`). **None was acted on this session.**

Two classes of failure inside the run are known and **cannot be cleared by any
commit this repository can make**:

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

**They run at deploy time, and that IS committed.** `_tools/deploy-langs.sh`
declares `LIVE_SPECS="all-languages-link-integrity restyle-seo-regression
v170-fixes v171-hardcoding"`, pre-flights each spec file, and invokes the live
config with no spec name on the command line, so the whole `testMatch` set
executes.

**The warning that stood here is WITHDRAWN as FALSE, and it actively
misinformed.** It read: *"via an UNCOMMITTED working-tree change made on
2026-09-01 … At `HEAD` that is not yet true — `git show
HEAD:_tools/deploy-langs.sh` names `all-languages-link-integrity.spec.js`
alone. Until the change is committed, a fresh clone runs the other three
**nowhere**."* Re-measured **2026-09-03**: `git show HEAD:_tools/deploy-langs.sh`
is **byte-identical** to the working tree (both sha256
`5b64034fd9c368f4…`), and `HEAD` carries all four specs on line 513 with the
presence pre-flight beside it. It landed in commit **`695c22d`** on 2026-09-01 —
so the claim was already false, or became false, the day it was written.
**A fresh clone DOES run all four.** Re-derive rather than trusting either
version of this paragraph:

```bash
git show HEAD:_tools/deploy-langs.sh | grep -n 'LIVE_SPECS='
cmp <(git show HEAD:_tools/deploy-langs.sh) _tools/deploy-langs.sh && echo identical
```

A figure of "86" circulates for this suite. It is a Playwright **test-case pass
count** ("86 passed / 2 failed") observed across the four-spec live run — not a
count of assertions in the three deferred specs, which is 97. Both are real;
they do not measure the same thing.

**OPEN DEFECT, recorded and NOT fixed — gate 6 validates a STALE artifact for
`milosvasic.ru`, and a failing build step is silently tolerated.** Measured
2026-09-03 on this host:

```bash
command -v jekyll                                   # (nothing — not on PATH)
cd milosvasic.ru && bundle exec jekyll --version    # rc 127: "command not found: jekyll"
cd milosvasic.ru && bundle check                    # missing: jekyll 4.4.1, jekyll-seo-tag 2.8.0, jekyll-feed 0.17.0
stat -c '%y' milosvasic.ru/_site/index.html         # 2026-08-28 08:52:45
stat -c '%y' milosvasic.ru/index.html               # 2026-09-03 19:03:35
```

**Jekyll cannot build on this host at all.** `ruby` and `bundle` are present;
the `jekyll` gem executable is not. The consequence is the part that matters:
`_tests/playwright.config.js:17` sets `MV_ROOT = milosvasic.ru/_site` and line 62
serves exactly that directory to the suite — so **the `milosvasic.ru` half of
gate 6 is asserting against a six-day-old build, not against current content.**
A green gate 6 is not evidence about today's `milosvasic.ru` source.

**The failure is tolerated by design, and that is arguably the worse half.**
`_tools/deploy-langs.sh:375` runs
`( cd milosvasic.ru && jekyll build … ) || build_warn "jekyll _site rebuild"`,
and `build_warn` only increments a counter; `report_build_warns` then prints
`N build step(s) failed and were tolerated` and the script **still exits 0**.
A `--dry-run` therefore reports success while having built nothing.

**PRODUCTION IS NOT AFFECTED.** `milosvasic.ru` publishes through its own
server-side `pages.yml` workflow (`build_type=workflow`, re-verified 2026-09-03),
which nothing here touched. This defect is confined to LOCAL build and LOCAL
test evidence.

**Remedy — `bundle install` inside `milosvasic.ru` — is an ENVIRONMENT change and
was NOT made.** Neither was the tolerate-and-continue behaviour altered:
silently downgrading a failed build to a warning is a separate decision, and
changing it could break the deploy path for a live production site. Both are
operator decisions.

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
