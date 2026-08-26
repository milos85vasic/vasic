# Constitution Propagation — APPLY procedure

> **Note on filenames.** The staged carrier drafts in this directory are stored with a
> `.staged` suffix (e.g. `AGENTS.md.staged`). The constitution's propagation gates discover
> carriers by exact filename (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`), so drafts
> named that way inside the repo are counted as real carriers and fail the gate. Drop the
> `.staged` suffix when you copy a file into its target submodule.


| Field | Value |
|---|---|
| Revision | 2 |
| Created | 2026-08-26 |
| Last modified | 2026-08-27 |
| Status | prepared — NOT applied |
| Status summary | Ready-to-copy inheritance-pointer carriers for the 5 owned submodules of the `vasic` umbrella, plus the exact copy/commit/push procedure. Nothing in this directory has been applied. No submodule working tree was written to and no mutating git command was run while producing it. **Revision 2 (2026-08-27):** every staged carrier was rewritten — the Revision-1 drafts opened with a `>` blockquote / a `## Helix Constitution inheritance` heading, neither of which satisfies the propagation gates' `is_pointer_carrier()` predicate, so applying them as written would have taken the fleet from 5 MISSING carriers / 85 MISSING lines to 8 / 136 (§4.6 alone) or 24 / 408 (§4.2 – §4.6). Every carrier now opens with a real, non-fenced, line-anchored `## INHERITED FROM constitution/<BASE>` heading and keeps the conditional / standalone prose. Proven in a temp-dir gate run — see [`PROOF.md`](PROOF.md). |
| Continuation | Operator executes §4 below, submodule-by-submodule, in the order given. Read [`PROOF.md`](PROOF.md) first — it is the empirical before/after for the corrected set. |

> **Read [`RISKS.md`](RISKS.md) before running anything in §4.** It names the
> push fan-out per repository, the third-party exclusion, and everything that
> could not be verified from a read-only checkout.

## 1. What this directory contains

```
docs/constitution-adoption/propagation/
├── APPLY.md                                                ← this file
├── RISKS.md
├── PROOF.md                                                ← temp-dir gate proof
├── ai_interviewing/{AGENTS,CLAUDE,QWEN,GEMINI}.md.staged   (→ 4 new files)
├── design-toolkit/{AGENTS,CLAUDE,QWEN,GEMINI}.md.staged    (→ 4 new files)
├── milosvasic.ru/{AGENTS,CLAUDE,QWEN,GEMINI}.md.staged     (→ 4 new files)
├── monetization/{AGENTS,CLAUDE,QWEN,GEMINI}.md.staged      (→ 4 new files)
└── vasic.digital/
    ├── AGENTS.md.staged  CLAUDE.md.staged  GEMINI.md.staged  (→ 3 new files)
    └── QWEN.insert-block.md    ← block to INSERT at the top of the EXISTING
                                   vasic.digital/QWEN.md (after its H1 title)
```

Every draft carrier is stored with a `.staged` suffix, for the reason the note
at the top of this file gives: a file literally named `CLAUDE.md` inside this
repository is discovered by the propagation gates as a real fleet carrier. The
`cp` commands in §4 therefore copy **from** `<name>.md.staged` **to**
`<name>.md`; the suffix is dropped by the copy, never by a rename in place.

19 files to create + 1 block to insert into 1 existing file. **No existing file
is replaced anywhere.**

`submodules/superspec` gets nothing — see [`RISKS.md` §3](RISKS.md#3-third-party-exclusion--submodulessuperspec).

## 2. Survey — what each owned submodule already has

Tracked-file survey via `git -C <sub> ls-files` (tracked only; untracked and
ignored paths deliberately not counted).

| Submodule | Upstream (`.gitmodules`) | Tracked agent-instruction files | Other tracked governance-adjacent content | Action |
|---|---|---|---|---|
| `ai_interviewing` | `git@github.com:milos85vasic/ai_interviewing.git` | **none** | `README.{md,html,pdf,docx}`, `docs/`, `platform/`, `scripts/`, `upstreams/GitHub.sh` — 911 tracked files. README purpose: "Interview-preparation corpus and employer due-diligence … a self-contained, exhaustively-researched preparation kit". | CREATE 4 |
| `design-toolkit` | `git@github.com:vasic-digital/design-toolkit.git` | **none** | `README.md`, `agents/` (11 design-specialist recipe `.md`, none a canonical carrier), `docs/`, `evidence/`, `generators/`, `knowledge/`, `mcp/`, `proposed/`, `qa/`, `submodules/` — 90 tracked files. README purpose: "A reusable, license-clean **design-capability layer** … Status: FIRST INCREMENT — review-ready local scaffold." | CREATE 4 |
| `milosvasic.ru` | `git@github.com:milos85vasic/milosvasic.ru.git` | **none** (see note) | `README.md`, `README.pdf`, Jekyll site (`_layouts`, `_config.yml`, 20 language dirs), `Upstreams/{GitFlic,GitHub}.sh`, `.gitmodules` → nested submodule `Upstreamable` — 1017 tracked entries. README purpose: personal CV / portfolio site. | CREATE 4 |
| `monetization` | `git@github.com:milos85vasic/monetization.git` | **none** | `README.md` ("Projects monetization. Monetization of existing projects."), `docs/`, `repos.txt`, `upstreams/{GitFlic,GitHub,GitLab,GitVerse}.sh` — 8 tracked files total. | CREATE 4 |
| `vasic.digital` | `git@github.com:vasic-digital/vasic-digital.github.io.git` | **`QWEN.md`** (55 lines, tracked) | `README.md`, `commit` (custom commit wrapper), `Upstreams/GitHub.sh`, `LOGO_CONVERSION.md`, static site + 20 language dirs — 1130 tracked files. | CREATE 3 + INSERT into `QWEN.md` |

### 2.1 Correction to INVENTORY.md §6.2 — where the reference implementation actually lives

INVENTORY.md §6.2 lists `milosvasic.ru/Upstreamable/AGENTS.md` and
`.../CLAUDE.md` as evidence and §7.3 calls that file "the reference
implementation for the propagation work". Both files exist on disk and both
were read for this document — but they are **not tracked by `milosvasic.ru`**.
`milosvasic.ru/.gitmodules` reads:

```
[submodule "Upstreamable"]
	path = Upstreamable
	url = git@github.com:red-elf/Upstreamable.git
```

and `git -C milosvasic.ru ls-files -s | grep ^160000` returns

```
160000 94f9831b8aa0a1d4df23671d2e4600886aad0dcf 0	Upstreamable
```

so `Upstreamable` is a gitlink to a **third repository** (`red-elf/Upstreamable`,
push URLs `git@github.com:red-elf/Upstreamable.git` + `git@gitflic.ru:red-elf/upstreamable.git`).
Consequence: **`milosvasic.ru` itself carries zero agent-instruction files**, and
editing the reference implementation would mean committing into a fourth-level
repository that is outside the 5-submodule scope of this task. Nothing here
touches `Upstreamable`.

### 2.2 What already exists in `vasic.digital/QWEN.md` (must be preserved)

55 lines, headed `# Vasic-Digital GitHub Pages Project`. It documents:
the project overview, a repository-structure tree, the `commit` script
(reads `env.properties`, honours `DEFAULT_COMMIT_MESSAGE` / `PROJECT_NAME`),
`Upstreams/GitHub.sh` (exports the upstream URL), the environment-configuration
contract, the development workflow, and usage notes. `grep -in constitution
vasic.digital/QWEN.md` returns **zero hits** — confirming INVENTORY.md §6.2.

All 55 lines stay. The pointer block is inserted **after line 1**, before the
existing `## Project Overview` heading.

## 3. The pointer form standardised on, and why

### 3.1 The path problem this form exists to solve

Every template and every quoted snippet in the constitution says
`constitution/…`. Three independent facts make **any** literal path wrong
inside an owned submodule:

1. **The umbrella's real path is not `constitution/`.** It is
   `submodules/constitution/` (`.gitmodules:1-3`). From inside a submodule the
   constitution is not at either name — from `monetization/` it is at
   `../submodules/constitution/`, and from `milosvasic.ru/Upstreamable/` it is
   at `../../submodules/constitution/`. The relative distance is a function of
   checkout depth, which the submodule cannot know.
2. **The same repository is checked out at two different depths simultaneously.**
   `design-toolkit` is a gitlink of the umbrella *and* a gitlink of the
   constitution:
   `git submodule status` → `16e4e76… design-toolkit (v0.2.2-4-g16e4e76)`;
   `git -C submodules/constitution/submodules/design-toolkit rev-parse HEAD` →
   `16e4e76d57ab61b5f3b46fae3372b2e6d6cc73e3` — same commit of
   `git@github.com:vasic-digital/design-toolkit.git`. One file, committed once,
   must be correct at depth 1 (`design-toolkit/`) *and* at depth 3
   (`submodules/constitution/submodules/design-toolkit/`). No relative path
   satisfies both.
3. **A standalone clone has no constitution at all.** `git clone
   git@github.com:milos85vasic/monetization.git` produces a tree with no parent
   and no `constitution/` anywhere. Any hardcoded path is then a dangling link,
   and any sentence asserting "these rules apply unconditionally" is false.

Two further consequences follow, and both rule out the project-root forms:

- **`@constitution/CLAUDE.md` MUST NOT be used in a submodule carrier.** The
  Claude-Code import resolves relative to the importing file's directory, so
  inside `monetization/CLAUDE.md` it would resolve to
  `monetization/constitution/CLAUDE.md`, which does not exist — it silently
  resolves to nothing. INVENTORY.md §7 names this "the single highest-risk
  detail in the whole change".
- **Hardcoding `submodules/constitution/` would itself be a violation.**
  §11.4.28(B) (`Constitution.md:2411-2418`): "Owned submodules MUST remain
  **fully decoupled** from any specific consuming project. No project-specific
  context, **hardcoded paths**, hostnames, asset names, naming schemes, or
  runtime assumptions may be introduced into an owned submodule's source tree.
  Every owned submodule MUST be: **Project-not-aware** — its code, tests, and
  docs make no reference to which parent project consumes it."
  `submodules/constitution/` is the umbrella's layout, i.e. exactly such a
  hardcoded parent-project path.

**The resolution the constitution ships** is the runtime resolver
`submodules/constitution/find_constitution.sh`. Its Phase 1 walks up parents
trying both layouts —

```
local rels=( "constitution" "submodules/constitution" )
```

— and its Phase 2 follows `git rev-parse --show-superproject-working-tree`
recursively "if we are inside a submodule … Repeat until at top-level", which is
precisely the submodule-at-any-depth case. It exits `1` with
`ERROR: constitution submodule not found above <pwd>` when there is none, which
is the standalone case. So the carrier names the *helper*, not a path, and
states the inheritance **conditionally**.

### 3.2 The exact conditional form (reproduced from the in-tree reference)

Quoted verbatim from `milosvasic.ru/Upstreamable/AGENTS.md` lines 3-16 — the
form INVENTORY.md §7.3 designates as the reference implementation:

```markdown
> **Base agent rules:** when this module is consumed inside a
> project that includes the Helix Constitution submodule, the file
> `constitution/AGENTS.md` is authoritative for any topic not
> covered here. Locate it from any nested depth using the
> constitution's `find_constitution.sh` helper.
>
> When this module is consumed standalone (no constitution
> submodule reachable in any parent), only the module-local notes
> below apply.
>
> Canonical reference:
> https://github.com/HelixDevelopment/HelixConstitution
```

and the CLAUDE-side twin, verbatim from
`milosvasic.ru/Upstreamable/CLAUDE.md` lines 6-24:

```markdown
## Helix Constitution inheritance

When this module is consumed inside a project that includes the
Helix Constitution as a git submodule
(https://github.com/HelixDevelopment/HelixConstitution), the rules
in `constitution/CLAUDE.md` and the `constitution/Constitution.md`
it references apply unconditionally. Use the constitution's
`find_constitution.sh` helper to locate it from any nested depth.

When this module is consumed standalone (no `constitution/`
submodule reachable in any parent), only the module-local notes
below apply.

This module stays fully decoupled and reusable per the Helix
Constitution's §11.4.28 (Submodules-As-Equal-Codebase + Decoupling
+ Dependency-Layout mandate). No project-specific context is
injected here.
```

The reference form's **substance** — the two-case conditional, the resolver
instead of a path, the standalone case stated plainly — is correct and is kept
verbatim in spirit below. Its **shape** is not usable on its own, and that is
what Revision 2 changed.

### 3.2.1 Why the shape had to change: `is_pointer_carrier()`

The reference opens with a `>` blockquote (`AGENTS.md`) or with a
`## Helix Constitution inheritance` heading (`CLAUDE.md`). Neither is visible
to the mechanism that decides whether a carrier is allowed to omit the anchor
literals.

Every `CM-COVENANT-114-*-PROPAGATION` gate sources one shared predicate,
`scripts/gates/lib/pointer_carrier.sh`, whose entire body is:

````awk
BEGIN { fenced = 0; found = 0 }
/^(```|~~~)/ { fenced = !fenced; next }
!fenced && /^## INHERITED FROM / { found = 1; exit }
END { exit !found }
````

A carrier satisfies it **iff** it contains a line-anchored, non-fenced
`## INHERITED FROM ` heading at column zero. Nothing else counts — not a
blockquote, not a differently-worded H2, not a mid-line mention in backticks
(a decoy the predicate's own self-test exercises). A carrier that fails the
predicate and does not restate the anchor literal is scored `MISSING`, so each
Revision-1 draft would have **added** a new failing carrier to the fleet
instead of clearing one. Measured, not argued: see [`PROOF.md`](PROOF.md).

Three facts about the predicate decide the corrected form:

1. It requires the **heading**, and only the heading. It never opens, resolves,
   or stats the path written after `## INHERITED FROM `.
2. It scans the whole file, so the heading may sit under the document's H1
   title — which is exactly the shape of the four repository-root carriers that
   pass all 17 gates today, and of the predicate's own `golden-good` fixture
   (`# CLAUDE.md` … `## INHERITED FROM constitution/CLAUDE.md`).
3. It is inherited by reference by both gate families — the 12 legacy
   bare-literal gates and the 5 fence-aware §11.4.227(B) block-integrity gates —
   so one heading satisfies all 17.

So both constraints hold at once. The carrier opens with the canonical heading
`## INHERITED FROM constitution/<BASE>` — the exact form the constitution's own
examples use — and immediately below it states the inheritance
**conditionally**, names `find_constitution.sh` as the resolver, and says
plainly that a standalone clone inherits nothing. The path inside the heading is
the canonical **name** of the base file, resolved by the helper; the carrier
says so in as many words, so no reader mistakes it for a filesystem path, and
no depth-dependent path is hardcoded anywhere (§11.4.28(B) intact).

### 3.3 Provenance of each of the four carriers

| Carrier | Form used | Authority |
|---|---|---|
| `AGENTS.md` | `## INHERITED FROM constitution/AGENTS.md` heading + the reference's conditional / standalone prose | heading form: `submodules/constitution/CLAUDE.md` "How to consume" + the `is_pointer_carrier()` predicate (§3.2.1); prose substance: `milosvasic.ru/Upstreamable/AGENTS.md:3-16` |
| `CLAUDE.md` | `## INHERITED FROM constitution/CLAUDE.md` heading + the same conditional / standalone prose | §11.4.35 invariant 6 (`Constitution.md:2910-2916`) names `## INHERITED FROM constitution/CLAUDE.md` as the portable pointer-block form; prose substance: `milosvasic.ru/Upstreamable/CLAUDE.md:6-24` |
| `QWEN.md` | **derived** — same heading + prose with `constitution/QWEN.md` substituted | `submodules/constitution/README.md` "How to consume" §2: "Same for `AGENTS.md` (any AI-agent tooling) and (since 2026-05-20) `QWEN.md` for Qwen Code:" followed by the blockquote form. **No `QWEN.project.md.template` ships** — `submodules/constitution/templates/` contains exactly `AGENTS.project.md.template`, `CLAUDE.project.md.template`, `Constitution.project.md.template`. A QWEN-specific consumer form is **not specified**; this is the README's own substitution. |
| `GEMINI.md` | **derived** — same heading + prose with `constitution/GEMINI.md` substituted | §11.4.157 (`Constitution.md:9566`): "`GEMINI.md` is a FIRST-CLASS governance context carrier, EQUAL to `CLAUDE.md` / `AGENTS.md` / `QWEN.md` — NEVER an optional or best-effort sibling." `submodules/constitution/GEMINI.md:29-38` prescribes for consumers a `## INHERITED FROM constitution/GEMINI.md` heading — the heading form is adopted here verbatim; only its *unconditional* wording ("apply unconditionally") is replaced by the two-case conditional, which is what a project-unaware module can honestly assert (§3.1). **No `GEMINI.project.md.template` ships.** |

A module-level `Constitution.md` is **not** included. The only Constitution
template that ships (`Constitution.project.md.template`) opens "This
constitution **extends** the Helix Universal Constitution at
`constitution/Constitution.md`" and requires `## Owned-submodule set` and
`## Project-specific remotes` sections — it is a *project* scaffold. Whether an
owned, project-unaware submodule must also carry its own `Constitution.md` is
**not specified** anywhere in `templates/`, in README "How to consume", or in
§11.4.28. Nothing is invented here.

### 3.4 Deviation from the reference: carrier count

The reference implementation carries **2** carriers (`AGENTS.md`, `CLAUDE.md`).
This propagation prepares **4** (adding `QWEN.md`, `GEMINI.md`), following
INVENTORY.md §7.3 ("all four carriers") and §11.4.157's first-class-GEMINI
mandate. If the operator prefers strict parity with the reference, apply only
`AGENTS.md` + `CLAUDE.md` per submodule and drop the other two — the files are
independent and the commit/push steps below are unchanged.

## 4. The procedure

### 4.0 Preconditions (verified read-only at preparation time — re-verify)

| Check | Command | Value observed 2026-08-26 |
|---|---|---|
| Every target on a branch, not detached | `git -C <sub> symbolic-ref -q HEAD` | all 5 on `refs/heads/main` |
| Every target clean | `git -C <sub> status --porcelain` | all 5 → 0 lines |
| No carrier filename is git-ignored | `git -C <sub> check-ignore -v CLAUDE.md AGENTS.md QWEN.md GEMINI.md` | no match in any of the 5 |

If any target is dirty or detached when the operator runs this, **stop** — the
steps below assume a clean `main`.

### 4.1 Ordering — submodules first, parent last

`Constitution.md:203-215` (§3, "Submodule changes propagate through submodule
commits first"):

> 1. **Commit inside the submodule first** (the submodule's own `git add` + `git commit`), since the parent project's commit wrapper does not commit submodule source — it only captures the updated submodule pointer.
> 2. **Push the submodule commit** to **all** remotes of that submodule.
> 3. **Then** run the parent project's commit wrapper to capture the updated submodule pointer in main and push main.
>
> Skipping step 1 produces parent commits / tags that point at old submodule HEADs without the actual source.

So: all five submodule commit+push rounds (§4.2 – §4.6) complete **before** the
umbrella capture (§4.7).

### 4.2 `ai_interviewing` — CREATE 4

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
P=docs/constitution-adoption/propagation
cp "$P/ai_interviewing/AGENTS.md.staged"  ai_interviewing/AGENTS.md
cp "$P/ai_interviewing/CLAUDE.md.staged"  ai_interviewing/CLAUDE.md
cp "$P/ai_interviewing/QWEN.md.staged"    ai_interviewing/QWEN.md
cp "$P/ai_interviewing/GEMINI.md.staged"  ai_interviewing/GEMINI.md

git -C ai_interviewing add AGENTS.md CLAUDE.md QWEN.md GEMINI.md
git -C ai_interviewing commit -m "docs: add Helix Constitution inheritance pointers (conditional form, §11.4.28(B) + §11.4.35)"
git -C ai_interviewing push origin main
```

**Blast radius:** `origin` has **1 push URL** — `git@github.com:milos85vasic/ai_interviewing.git`.
The `github` and `upstream` remotes resolve to that same single URL, so pushing
all three remotes still writes to 1 distinct repository.

**Caveat before you run this one:** the carrier text ends "No project-specific
context is injected here." For `ai_interviewing` that sentence is *aspirational,
not descriptive* — its own `README.md` opens "**Interview-preparation corpus and
employer due-diligence** for the CauseMatch *Senior Full-Stack Engineer …*
position — built for the candidate at [milosvasic.ru](https://milosvasic.ru)".
Either accept the sentence as the forward §11.4.28(B) obligation it states, or
delete that one paragraph from `ai_interviewing/{AGENTS,CLAUDE,QWEN,GEMINI}.md`
before committing. See [`RISKS.md` §5](RISKS.md#5-honesty-flags-in-the-prepared-text).

### 4.3 `design-toolkit` — CREATE 4

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
P=docs/constitution-adoption/propagation
cp "$P/design-toolkit/AGENTS.md.staged"  design-toolkit/AGENTS.md
cp "$P/design-toolkit/CLAUDE.md.staged"  design-toolkit/CLAUDE.md
cp "$P/design-toolkit/QWEN.md.staged"    design-toolkit/QWEN.md
cp "$P/design-toolkit/GEMINI.md.staged"  design-toolkit/GEMINI.md

git -C design-toolkit add AGENTS.md CLAUDE.md QWEN.md GEMINI.md
git -C design-toolkit commit -m "docs: add Helix Constitution inheritance pointers (conditional form, §11.4.28(B) + §11.4.35)"
git -C design-toolkit push origin main
```

**Blast radius:** `origin` has **1 push URL** —
`git@github.com:vasic-digital/design-toolkit.git`. It is the only remote.

**Two-parent consequence — read before running.** The same repository at the
same commit is also the constitution's own submodule at
`submodules/constitution/submodules/design-toolkit`. Pushing a new
`design-toolkit` commit makes the **constitution's** recorded gitlink stale.
Bringing the constitution back in sync means a commit inside
`submodules/constitution`, whose `origin` fans out to **6 push URLs**
(see [`RISKS.md` §2](RISKS.md#2-push-fan-out-per-repository)). That step is
**out of scope here and is not prepared** — decide it deliberately.

### 4.4 `milosvasic.ru` — CREATE 4

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
P=docs/constitution-adoption/propagation
cp "$P/milosvasic.ru/AGENTS.md.staged"  milosvasic.ru/AGENTS.md
cp "$P/milosvasic.ru/CLAUDE.md.staged"  milosvasic.ru/CLAUDE.md
cp "$P/milosvasic.ru/QWEN.md.staged"    milosvasic.ru/QWEN.md
cp "$P/milosvasic.ru/GEMINI.md.staged"  milosvasic.ru/GEMINI.md

git -C milosvasic.ru add AGENTS.md CLAUDE.md QWEN.md GEMINI.md
git -C milosvasic.ru commit -m "docs: add Helix Constitution inheritance pointers (conditional form, §11.4.28(B) + §11.4.35)"
git -C milosvasic.ru push origin main
```

**Blast radius:** `origin` has **2 push URLs**, and they are *not* the origin
fetch URL:

```
git@gitflic.ru:milosvasic/milosvasic-net-v-2.git
git@github.com:milos85vasic/milosvasic.net.v2.git
```

`git remote get-url origin` (fetch) is `git@github.com:milos85vasic/milosvasic.ru.git`
— the URL `.gitmodules` declares — and **no configured push URL writes to it**.
One `git push origin main` therefore publishes to two repositories, neither of
which is the one the umbrella records as this submodule's source. See
[`RISKS.md` §2.1](RISKS.md#21-milosvasicru--fetchpush-url-asymmetry).

This does **not** touch `milosvasic.ru/Upstreamable` (a separate
`red-elf/Upstreamable` repository — §2.1 above).

### 4.5 `monetization` — CREATE 4 (widest fan-out)

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
P=docs/constitution-adoption/propagation
cp "$P/monetization/AGENTS.md.staged"  monetization/AGENTS.md
cp "$P/monetization/CLAUDE.md.staged"  monetization/CLAUDE.md
cp "$P/monetization/QWEN.md.staged"    monetization/QWEN.md
cp "$P/monetization/GEMINI.md.staged"  monetization/GEMINI.md

git -C monetization add AGENTS.md CLAUDE.md QWEN.md GEMINI.md
git -C monetization commit -m "docs: add Helix Constitution inheritance pointers (conditional form, §11.4.28(B) + §11.4.35)"
git -C monetization push origin main
```

**Blast radius:** `origin` has **4 push URLs** across 4 providers:

```
git@gitflic.ru:milosvasic/monetization.git
git@github.com:milos85vasic/monetization.git
git@gitlab.com:milos85vasic/monetization.git
ssh://git@gitverse.ru:2222/milosvasic/monetization.git
```

A single `git push` publishes to GitFlic, GitHub, GitLab and GitVerse at once.
The repo currently tracks **8 files** — this commit adds 4 more, a 50 % increase
in its tracked-file count, to 4 providers.

### 4.6 `vasic.digital` — CREATE 3 + INSERT into the existing `QWEN.md`

> **Revision 2 — what changed and why it matters here.** Revision 1 of this
> section copied three carriers that opened with `# CLAUDE.md — vasic.digital`
> / a `>` blockquote / `## Helix Constitution inheritance`, and inserted a
> blockquote into `QWEN.md`. None of those four files satisfied
> `is_pointer_carrier()` (§3.2.1), and none carried a single one of the 17
> anchor literals — so applying §4.6 as written turned `vasic.digital` into
> **three additional MISSING carriers** while leaving `QWEN.md` MISSING too.
> Measured in a temp-dir gate run: the fleet went from **5 MISSING carriers /
> 85 MISSING lines to 8 / 136**, with all 17 gates still FAILing, louder. The
> four staged files below now each open with a real, non-fenced,
> line-anchored `## INHERITED FROM constitution/<BASE>` heading; the same
> measurement on the corrected set gives **4 MISSING carriers / 68 MISSING
> lines** — `vasic.digital/QWEN.md` leaves the failing set. Full before/after,
> including the control run on the uncorrected copies, is in
> [`PROOF.md`](PROOF.md).

The three new carriers:

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
P=docs/constitution-adoption/propagation
cp "$P/vasic.digital/AGENTS.md.staged"  vasic.digital/AGENTS.md
cp "$P/vasic.digital/CLAUDE.md.staged"  vasic.digital/CLAUDE.md
cp "$P/vasic.digital/GEMINI.md.staged"  vasic.digital/GEMINI.md
```

The existing carrier — **insert, do not append, and do not replace.**
`vasic.digital/QWEN.md` line 1 is `# Vasic-Digital GitHub Pages Project`; the
block goes immediately after it, ahead of the existing `## Project Overview`
heading, because README "How to consume" §2 says "Add a clearly-marked pointer
**at the top** of your project's root `CLAUDE.md` … Same for `AGENTS.md` … and
… `QWEN.md`", and §11.4.35 invariant 6 (`Constitution.md:2910-2916`) says the
consumer carrier "MUST **start** with" the pointer. Appending at end-of-file
would satisfy neither.

Keeping the existing H1 title on line 1 and putting the pointer heading
immediately under it is the shape of the four repository-root carriers that
pass all 17 propagation gates today (`# vasic — CLAUDE.md`, then
`## INHERITED FROM …` on line 3) and of the predicate's own `golden-good`
fixture. The pointer is the document's first section either way, and
`is_pointer_carrier()` scans the whole file, so the heading is found (verified
on the produced file — [`PROOF.md`](PROOF.md) §4).

All 55 existing lines are preserved verbatim:

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic/vasic.digital
B=../docs/constitution-adoption/propagation/vasic.digital/QWEN.insert-block.md
{ head -n 1 QWEN.md; echo; cat "$B"; tail -n +2 QWEN.md; } > QWEN.md.new
# verify before swapping: the diff must be pure insertion, zero deletions
diff <(tail -n +2 QWEN.md) <(tail -n +51 QWEN.md.new) && mv QWEN.md.new QWEN.md
```

(The block is **48** lines; with the blank separator line the insertion is 49
lines, so the original body resumes at **line 51** of the new file — the new
file is 104 lines, and `## Project Overview` lands on line 52. The `diff` must
print nothing. If it prints anything, **do not** `mv` — the insertion is wrong.)

Then confirm the produced file is a pointer carrier before committing — this is
the check whose absence made Revision 1 defective, and it takes one command:

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
. submodules/constitution/scripts/gates/lib/pointer_carrier.sh
for f in vasic.digital/{AGENTS,CLAUDE,QWEN,GEMINI}.md; do
  is_pointer_carrier "$f" && echo "OK   pointer carrier: $f" \
                          || echo "FAIL not a pointer carrier: $f"
done
```

All four must print `OK`. A `FAIL` means the file will be scored `MISSING` by
all 17 propagation gates — stop and fix it before committing.

Then commit. `vasic.digital` ships its own commit wrapper — the tracked script
`commit`, which "Reads configuration from `env.properties` … Supports default
commit messages via `DEFAULT_COMMIT_MESSAGE`" (its own `QWEN.md`). The
constitution's `AGENTS.project.md.template` restates "**Use the project's commit
wrapper.** No direct `git add` / `git commit` / `git push` on main repo." Prefer:

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic/vasic.digital
./commit "docs: add Helix Constitution inheritance pointers (conditional form, §11.4.28(B) + §11.4.35)"
```

The wrapper's exact behaviour (whether it stages all changes and whether it
pushes) was **not executed or read line-by-line** for this document — inspect
`vasic.digital/commit` before relying on it. The plain-git equivalent:

```bash
git -C vasic.digital add AGENTS.md CLAUDE.md GEMINI.md QWEN.md
git -C vasic.digital commit -m "docs: add Helix Constitution inheritance pointers (conditional form, §11.4.28(B) + §11.4.35)"
git -C vasic.digital push origin main
```

**Blast radius:** `origin` has **1 push URL** —
`git@github.com:vasic-digital/vasic-digital.github.io.git`. Note this is a
GitHub **Pages** repository: a push to its default branch triggers a site
rebuild/redeploy. Four Markdown files land at the site root; whether the Jekyll
build ignores or publishes them was **not verified** (see
[`RISKS.md` §6](RISKS.md#6-not-verified)).

### 4.7 Umbrella — capture the five updated gitlinks, last

Only after all five submodule pushes succeed:

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
git status --short        # expect exactly 5 gitlink modifications + this docs/ dir
git add ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital \
        docs/constitution-adoption/propagation
git commit -m "chore: capture owned-submodule constitution-inheritance pointers (§3 submodule-first ordering)"
git push origin main
```

**Blast radius:** the umbrella's `origin` has **1 push URL** —
`git@github.com:milos85vasic/vasic.git`. Its `github` and `upstream` remotes
carry the same single URL.

### 4.8 Total blast radius if everything in §4.2 – §4.7 is applied

| Repository | Commits | `git push origin` writes to | Distinct URLs |
|---|---|---|---|
| `ai_interviewing` | 1 | GitHub ×1 | 1 |
| `design-toolkit` | 1 | GitHub ×1 | 1 |
| `milosvasic.ru` | 1 | GitFlic ×1, GitHub ×1 | 2 |
| `monetization` | 1 | GitFlic, GitHub, GitLab, GitVerse | 4 |
| `vasic.digital` | 1 | GitHub ×1 (Pages redeploy) | 1 |
| umbrella `vasic` | 1 | GitHub ×1 | 1 |
| **Total** | **6** | — | **10** |

**10 push URLs across 4 providers (GitHub, GitLab, GitFlic, GitVerse), from
6 commits in 6 separate repositories.** `submodules/constitution` (6 URLs) and
`submodules/superspec` (1 URL) are **not** in this total — neither is touched.
Re-syncing the constitution's `design-toolkit` gitlink (§4.3) would add its
6 URLs, taking the total to 16.

## 5. Post-apply verification (read-only)

```bash
cd /run/media/milosvasic/DATA4TB/Projects/vasic
# 1. Every owned submodule now tracks the carriers
for s in ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital; do
  echo "== $s"; git -C "$s" ls-files | grep -E '^(AGENTS|CLAUDE|QWEN|GEMINI)\.md$'
done

# 2. Every carrier names the base file and the resolver, and none hardcodes the
#    umbrella layout (a hit here is a §11.4.28(B) violation)
for s in ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital; do
  for f in AGENTS CLAUDE QWEN GEMINI; do
    grep -q 'find_constitution.sh' "$s/$f.md" || echo "MISSING resolver: $s/$f.md"
    grep -q 'submodules/constitution' "$s/$f.md" && echo "HARDCODED PARENT PATH: $s/$f.md"
    grep -q '^@constitution/' "$s/$f.md" && echo "DANGLING @import: $s/$f.md"
  done
done

# 3. vasic.digital/QWEN.md kept all 55 original lines (pure insertion, 0 deletions)
diff <(git -C vasic.digital show HEAD~1:QWEN.md) \
     <(head -n 1 vasic.digital/QWEN.md; tail -n +51 vasic.digital/QWEN.md)

# 4. The resolver actually resolves from inside each submodule
for s in ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital; do
  echo -n "$s -> "; (cd "$s" && bash ../submodules/constitution/find_constitution.sh)
done

# 5. THE GATE-FACING CHECK — every applied carrier is recognised as a §11.4.35
#    pointer consumer by the very predicate the 17 propagation gates source.
#    A FAIL here means the file is scored MISSING by all 17. (This is the check
#    whose absence made Revision 1 of this directory defective.)
. submodules/constitution/scripts/gates/lib/pointer_carrier.sh
for s in ai_interviewing design-toolkit milosvasic.ru monetization vasic.digital; do
  for f in AGENTS CLAUDE QWEN GEMINI; do
    [ -f "$s/$f.md" ] || continue
    is_pointer_carrier "$s/$f.md" \
      && echo "OK   pointer carrier: $s/$f.md" \
      || echo "FAIL not a pointer carrier: $s/$f.md"
  done
done

# 6. Fleet-level before/after — MISSING carriers must not increase, and
#    vasic.digital/QWEN.md must have left the MISSING set.
G=submodules/constitution/scripts/gates
for a in 162 167 176 187 191 196 199 200 201 202 207 213 230 231 232 233 235; do
  bash "$G/cm_covenant_114_${a}_propagation.sh" --root . || true
done 2>&1 | tee /tmp/sweep-after-apply.txt | grep -c '❌ MISSING'
grep '❌ MISSING' /tmp/sweep-after-apply.txt \
  | sed 's/.*MISSING *//; s/  *—.*//' | sort -u
```

Check 4 is the mechanical proof that the conditional form works from every
depth. It was **not run** during preparation (it only reads, but it is listed
here as the operator's confirmation step).

Checks 5 and 6 are the ones that decide whether this propagation helps or
hurts, and both **were** run during preparation of Revision 2 — against a temp
directory mirroring this fleet, never against the live submodules. Expected
values, reproduced in [`PROOF.md`](PROOF.md): check 5 prints `OK` for all 20
carriers; check 6 prints `68` and lists exactly the four third-party carriers
(`milosvasic.ru/Upstreamable/{AGENTS,CLAUDE}.md`,
`submodules/superspec/examples/static-landing-page/CLAUDE.md`,
`.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md`) — down
from `85` and five. The 17 gates still exit 1 on those four: they are category
(c) in [`GATE-TRIAGE.md`](../GATE-TRIAGE.md) §3.1 and no change in this directory
can clear them. A check-6 number **above** 85 means the applied carriers are
not pointer carriers — revert before committing.

## 6. What this procedure does NOT do

- It does not create the umbrella-root carriers (`CLAUDE.md`, `AGENTS.md`,
  `QWEN.md`, `GEMINI.md`, `Constitution.md`) that INVENTORY.md §7.1 specifies —
  submodule pointers alone do not close G1/G2 (INVENTORY.md §6.4: the 175
  `CM-COVENANT-114-N-PROPAGATION` gates check carriers "across the project").
  **State note, 2026-08-26 22:58:** four untracked root carriers (`AGENTS.md`,
  `CLAUDE.md`, `GEMINI.md`, `QWEN.md`, ~9.6 KB each) appeared in the umbrella
  working tree *during* the preparation of this directory, written by work
  outside this task. They use the unconditional project-root form
  (`## INHERITED FROM submodules/constitution/CLAUDE.md`), which is correct **at
  the repository root** — the path is real from there and the root is allowed to
  be project-aware. They are complementary to, not in conflict with, the
  conditional submodule form standardised in §3: the two layers are governed by
  different clauses (§11.4.35 invariant 6 for the root, §11.4.28(B) for owned
  submodules). Since Revision 2 the two forms share the same *heading* —
  `## INHERITED FROM …` — and differ only in what follows it: the root names a
  real relative path and asserts inheritance unconditionally (both true at the
  repository root), while a submodule carrier names the base file's canonical
  name, resolves it with `find_constitution.sh`, and states the inheritance
  conditionally (the only honest form for a module that can be cloned alone).
  Those four root carriers are also the working reference Revision 2 was
  measured against — they are the carriers that pass all 17 propagation gates
  today. Nothing in this directory reads, modifies, or depends on them.
- It does not create any gate, sweep, hook, or `helix-deps.yaml`
  (INVENTORY.md §7.4). Per §11.4.32 (`Constitution.md:2079-2082`) "Without it,
  new rules cascade as anchors but never get enforced in the codebase" — these
  pointers are, until then, unenforced.
- It does not generate the `.html` / `.pdf` siblings that §11.4.65 requires.
  Its scope table (`Constitution.md:5989`) INCLUDES "Owned-submodule trees
  … top-level README.md / CLAUDE.md / AGENTS.md". Every file created in §4 is
  therefore born non-compliant with §11.4.65 until exported. Same known,
  disclosed deviation INVENTORY.md §1 records for itself, and it applies to
  `APPLY.md` / `RISKS.md` / `PROOF.md` and the 20 prepared files in this
  directory too.
- It does not touch `submodules/superspec`, `submodules/constitution`, or
  `milosvasic.ru/Upstreamable`.
- It does not clear all 17 propagation gates, and Revision 2 does not claim it
  does. Four category-(c) third-party carriers
  ([`GATE-TRIAGE.md`](../GATE-TRIAGE.md) §3.1, §7) hold every one of the 17
  FAILing no matter what happens in this directory. What the procedure now does
  is stop *adding* to that set, and remove one carrier from it
  (`vasic.digital/QWEN.md`): 85 MISSING lines → 68, five MISSING carriers →
  four. Measured, not asserted — [`PROOF.md`](PROOF.md).
