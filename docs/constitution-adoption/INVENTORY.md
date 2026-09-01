# Constitution Adoption — Inventory & Gap Analysis

| Field | Value |
|---|---|
| Revision | 2 |
| Created | 2026-08-26 |
| Last modified | 2026-09-01 |
| Status | active — **historical record plus a current status ledger** |
| How to read it | The §8 G-headings are the ORIGINAL 2026-08-26 discovery evidence and are deliberately not rewritten as gaps move. Current statuses live in **§8.0 Current status ledger**, and the authority above that is the `- G<n> — <STATUS>` lines in the four root carriers. Never quote a G-heading as a current status. |
| Status summary | Phase-1 read-and-map inventory of `submodules/constitution` (HelixConstitution) and its adoption state in the `vasic` umbrella. Read-only pass: no existing file was modified. Headline finding — the umbrella repository has **zero** agent-instruction files at its root, so the constitution's prescribed inheritance mechanism is **not wired at all**. |
| Issues | 12 ranked gaps (G1–G12) |
| Issues summary | G1 no consumer governance layer; G2 no inheritance pointer; G3 no post-pull validation sweep; G4 active CI contradicts §11.4.156; G5 no mechanical enforcement; G6 no `helix-deps.yaml`; G7 no submodule propagation; G8 §11.4.65 export gap (265 `.md`, 0 `.html`); G9 §11.4.212 README-orphan gap; G10 §4 tag-mirroring gap; G11 duplicate `design-toolkit` checkout; G12 no anti-forgetting hook. |
| Fixed | — |
| Fixed summary | — |
| Continuation | Phase 2 — apply the proposed inheritance design in §7 below. |

> **Scope of this document.** This is a **read-only inventory**. Per the task
> that produced it, no existing file in this repository was modified and no
> mutating git command was run. Every claim below cites a real path and, where
> the claim is a quotation, exact text. Anything that could not be verified from
> the checkout is marked **unverified** together with what would verify it.

## Table of contents

- [1. Method and honesty contract](#1-method-and-honesty-contract)
- [2. What the constitution submodule actually is](#2-what-the-constitution-submodule-actually-is)
- [3. Nested submodules of the constitution](#3-nested-submodules-of-the-constitution)
- [4. Mandatory vs advisory — the exact wording](#4-mandatory-vs-advisory--the-exact-wording)
- [5. The prescribed adoption mechanism (quoted)](#5-the-prescribed-adoption-mechanism-quoted)
- [6. Agent instruction files across the umbrella and every submodule](#6-agent-instruction-files-across-the-umbrella-and-every-submodule)
- [7. Proposed minimal inheritance design](#7-proposed-minimal-inheritance-design)
- [8. Gaps and violations, ranked by severity](#8-gaps-and-violations-ranked-by-severity)
- [9. Full mandatory-rule table](#9-full-mandatory-rule-table)
- [10. Unverified items](#10-unverified-items)

---

## 1. Method and honesty contract

Everything in this document was produced by reading files in the checkout at
`/run/media/milosvasic/DATA4TB/Projects/vasic` and running **read-only** shell
commands (`ls`, `cat`, `sed`, `grep`, `git ls-files`, `git grep`,
`git submodule status`, `git tag`, `git remote -v`, `find`). No `git fetch`,
`pull`, `checkout`, `commit`, `push`, or `submodule update` was run.

Three verdict values are used and they mean exactly this:

- **Yes** — a concrete artifact in the checkout satisfies the rule, and the
  artifact is named.
- **No** — the required artifact is demonstrably absent or demonstrably
  contradicted, and the check that proves it is named.
- **Unknown — needs verification** — the rule is conditional, or checking it
  requires running the project's own gates / network access, neither of which
  this pass did. The verifying action is stated in [§10](#10-unverified-items).

Where a verdict is inherited from the pre-existing audit at
`_analysis/constitution-compliance.md` (dated 2026-08-05, re-verified
2026-08-10), that is stated explicitly rather than re-claimed as first-hand.

**Self-referential caveat.** §11.4.65 (Universal Markdown export mandate)
requires every non-source `.md` in the project to carry synchronized `.html`
and `.pdf` siblings. This document is `docs/constitution-adoption/INVENTORY.md`
and therefore falls inside that scope. It ships **without** those siblings
because the task that produced it permitted the creation of exactly one file.
That is a known, deliberate, disclosed §11.4.65 deviation, not an oversight.

---

## 2. What the constitution submodule actually is

**It is not empty and it does define enforceable rules.** This needs saying up
front because the task allowed for the opposite finding.

| Property | Value |
|---|---|
| Path in this repo | `submodules/constitution` |
| Upstream | `git@github.com:HelixDevelopment/HelixConstitution.git` (`.gitmodules:3`) |
| Pinned commit | `448981ae3498229c734dc60719f4b19f01d7a75f` (`git ls-files -s`) |
| `git describe` | `v1.0.0-51-g448981a` — 51 commits **past** the only semver tag, i.e. **not pinned to a tag** |
| Checked out? | Yes, fully, including all 7 of its own nested submodules |
| Canonical rule text | `submodules/constitution/Constitution.md` — 11,101 lines / 1.53 MB |

Top-level governing documents (each also exported to `.html`, `.pdf`, `.docx`
per its own §11.4.65):

| File | Lines | Role (per `submodules/constitution/README.md` "Contents" table) |
|---|---|---|
| `Constitution.md` | 11101 | "**The canonical universal constitution.** All clauses are project-agnostic." |
| `CLAUDE.md` | 2998 | "Universal CLAUDE.md for Claude Code agents. Imports `Constitution.md` by reference." |
| `AGENTS.md` | 2738 | "Universal AGENTS.md for every other CLI agent (Codex, Cursor, Aider, OpenCode, Crush, Kimi CLI)." |
| `QWEN.md` | 1089 | "Universal QWEN.md for the Qwen Code CLI agent." |
| `GEMINI.md` | 497 | Gemini CLI carrier; made a first-class peer by §11.4.157. |
| `CLAUDE_ANCHORS_FULL.md` | 790 | Full anchor corpus companion. |
| `submodules-catalogue.md` | 229 | "Canonical inventory of every owned-by-us repository under `vasic-digital` + `HelixDevelopment` (142 repos at landing time)." |
| `helix-deps.yaml` | — | §11.4.31 machine-readable dependency manifest for the constitution's own 7 deps. |
| `templates/` | 3 files | `AGENTS.project.md.template`, `CLAUDE.project.md.template`, `Constitution.project.md.template` — the consumer-side scaffolds. |
| `find_constitution.sh` | — | Parent-walk resolver; **already supports the `submodules/constitution/` layout** (see below). |
| `meta_test_inheritance.sh` | — | Mutation meta-test that proves a consumer's inheritance gate is not a bluff gate. |
| `scripts/hooks/guard-forbidden-commands.sh` | 29,705 B | The canonical §11.4.109(A) `PreToolUse` guard. Present, executable, **never invoked from this repo**. |
| `scripts/post_update_hook.sh` | 20,975 B | The canonical §11.4.164 post-pull hook. Present, **never invoked from this repo**. |

**Scale of the rule corpus** (mechanically counted over `Constitution.md`):

| Measure | Count |
|---|---|
| Distinct numbered anchors (headings + bold-anchor paragraphs) | **261** |
| Top-level articles §1–§12 | 12 |
| §11.4.N covenant anchors | 234 |
| Anchors declaring a `CM-COVENANT-114-N-PROPAGATION` gate | **175** |
| Occurrences of the token `MUST` | 1,542 |
| Occurrences of the token `SHOULD` | 15 |
| Occurrences of "No escape hatch" | 200 |
| Occurrences of "release blocker" | 176 |

The 1,542-to-15 `MUST`/`SHOULD` ratio is the quantitative answer to
"mandatory vs advisory": this corpus is almost entirely mandatory.

**Layout note that matters.** `submodules/constitution/find_constitution.sh`
already resolves this repository's layout. Lines 41–46:

> ```
> # Candidate relative locations of the constitution submodule, in
> # priority order. The canonical top-level `constitution/` is kept
> # for backward compatibility; `submodules/constitution/` is the
> # §11.4.28 dependency-layout form (all owned submodules under a
> # root `submodules/` directory, §11.4.29 snake_case).
> local rels=( "constitution" "submodules/constitution" )
> ```

So the *path* is fine. What is missing is everything the path was supposed to
be wired into.

---

## 3. Nested submodules of the constitution

`submodules/constitution/.gitmodules` registers 7 submodules. All 7 are
populated. An eighth directory, `clickup_sync`, exists on disk but is **not a
git submodule** — it has no `.git` file and no `.gitmodules` entry.

| Submodule | Path | Purpose (from its own README) | Own agent files | Cites the constitution? |
|---|---|---|---|---|
| `anti_bluff` | `submodules/constitution/submodules/anti_bluff` | "mechanical anti-bluff seams for any Helix-constitution project" — executable guards that refuse on a real condition; wires a status-custody seam into a consumer's tracker SQLite DB. Design law quoted in its README: "**Prose does not bind; seams do.**" | none | Yes (§11.4.28(C), §11.4.17, §11.4.35, §11.4.6) |
| `continuum` | `.../submodules/continuum` | "Continuum — instant-resume continuation engine". Content-addressed multi-stream snapshot store; resume cost `O(changed streams)`. Go stdlib only. | none | Yes (§12.10, §11.4.127, §11.4.131, §11.4.207) |
| `design-toolkit` | `.../submodules/design-toolkit` | "A reusable, license-clean **design-capability layer** that combines with **OpenDesign** to produce **unique, enterprise-grade, non-repeatable UI/UX**". Ships 11 design-specialist agent recipes under `agents/`. Status: "FIRST INCREMENT — review-ready local scaffold." | 11 recipe `.md` under `agents/`, none canonical | Yes (§11.4.162) |
| `docs_chain` | `.../submodules/docs_chain` | Universal Go bidirectional document-and-database dependency-propagation engine; content-hash change detection with Kahn topological ordering and atomic-rename commits. Phases 1–5 implemented; 6–7 PLANNED. | `AGENTS.md`, `CLAUDE.md`, `QWEN.md`, `CONSTITUTION.md` | Yes (all 5 top-level `.md`) |
| `helix_perf_cache` | `.../submodules/helix_perf_cache` | "A **project-agnostic reusable engine** for LLM inference-performance measurement and caching". Honest two-track framing separating local KV-cache reuse from hosted-API prompt caching. | `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `QWEN.md` | Yes (all 6 top-level `.md`) |
| `session_orchestrator` | `.../submodules/session_orchestrator` | "A **project-agnostic, fully decoupled** Go engine for coordinating a *flowing pool* of session aliases behind a *floating orchestrator role*". Same-session failover explicitly NOT implemented. | none | **No** — zero "constitution" matches in its top-level `.md` |
| `token_optimizer` | `.../submodules/token_optimizer` | "Project-agnostic Go engine that minimizes the token / cost / byte footprint of LLM request pipelines". Only `pkg/config` implemented so far. | none | **No** — zero "constitution" matches in its top-level `.md` |
| `clickup_sync` | `.../submodules/clickup_sync` | **Not a submodule.** Docs-only directory. Its `docs/design/DESIGN.md` states: "DESIGN ONLY (Phase 0). NO implementation code, NO repo creation, NO ClickUp writes, NO main-tree source edits exist as a result of this document." | none | Yes, but only under `docs/` |

Pin state (`git -C submodules/constitution submodule status`): `design-toolkit`
at `v0.2.2-4-g16e4e76` and `docs_chain` at `helixcode-v1.1.0-9-g9510e01` are
**past** their tags; the other five track `heads/main`.

---

## 4. Mandatory vs advisory — the exact wording

### 4.1 The blanket mandatory declaration

`submodules/constitution/Constitution.md:124-127`:

> **This document defines mandatory, non-negotiable rules for every project
> that includes this constitution submodule. Every AI agent and every
> human contributor MUST comply. Violations are blockers.**

`Constitution.md:129-132`:

> Project-specific constitutions extend this document. When a project
> Constitution (e.g. `docs/guides/PROJECT_CONSTITUTION.md`) and this
> universal Constitution differ, the project Constitution may extend or
> tighten — but NEVER weaken — the universal rules below.

### 4.2 The per-anchor mandatory formula

175 of the 234 §11.4.N anchors close with a three-part formula. Representative
instance, `Constitution.md:9569-9573` (§11.4.157):

> **Canonical authority:** constitution submodule [`Constitution.md`](Constitution.md) §11.4.157.
>
> Non-compliance is a release blocker regardless of context. No escape hatch — no `--skip-gemini-md`, `--gemini-optional`, `--gemini-lag-OK`, `--four-carrier-suffices` flag.

The same formula appears 176 times ("release blocker") and 200 times ("No
escape hatch"). Each also names its enforcement gate, e.g. the same clause:

> Propagation gate `CM-COVENANT-114-157-PROPAGATION` (literal `11.4.157` across the consumer fleet, GEMINI.md INCLUDED)

### 4.3 The single most important rule

`Constitution.md:163-164` (§1.1):

> This is the **single most important rule in this Constitution.** Every
> subsequent §11.4.x clause is downstream of it.

Referring to (`Constitution.md:147-160`) mutation-paired gates: a gate that
cannot be made to FAIL by breaking its assertion "is a sham and must be
rewritten."

### 4.4 What is genuinely advisory

Only 15 `SHOULD` tokens exist. The load-bearing advisory items relevant here:

- **Tag pinning is recommended, not mandatory.** `submodules/constitution/README.md`
  ("How to consume" → step 1): "`# Pin to a tag for reproducibility (recommended)`".
  So this repo's `v1.0.0-51-g448981a` floating pin is *not* a violation.
- **Multi-upstream for the consumer is SHOULD.** `Constitution.md:196-198`:
  "Consuming projects SHOULD do the same for their own multi-remote topology."
  (For the constitution submodule itself it is MUST — §2.1 / Appendix C.)
- **Parent-walk helper is SHOULD.** Appendix B, `Constitution.md:10230-10238`:
  "every project SHOULD provide a helper that walks up parents until it finds
  `constitution/Constitution.md`".
- **Changelog export script is SHOULD.** `Constitution.md:243-245`: "The project
  SHOULD provide a script (`scripts/testing/export_changelog.sh <tag>` or
  equivalent)". The changelog *entries* themselves are MUST (§5).
- **`CM-CANONICAL-ROOT-CLARITY` is "recommended, per consuming project"**
  (`Constitution.md:2933`) — the gate is recommended; the underlying §11.4.35
  inheritance-pointer requirement it checks is MUST.

Some clauses are **conditionally applicable** rather than advisory — e.g.
§11.4.47 (Firebase data review), §11.4.51 (Live-ADB-First), §11.4.128
(device recording) presuppose an Android/device product. §11.4.169 explicitly
contemplates this by requiring a *justified* N/A per required test type. The
pre-existing audit at `_analysis/constitution-compliance.md` uses an
"Applies?" column for exactly this reason.

---

## 5. The prescribed adoption mechanism (quoted)

**The constitution DOES prescribe an adoption mechanism.** It is not invented
here. It has five parts.

### 5.1 Part 1 — add the submodule (`submodules/constitution/README.md`, "How to consume" §1)

> ```bash
> git submodule add git@github.com:HelixDevelopment/HelixConstitution.git constitution
>
> # Pin to a tag for reproducibility (recommended)
> cd constitution
> git checkout v1.0.0          # whatever the current stable tag is
> ```

**Status in this repo: DONE** (at `submodules/constitution` rather than
`constitution`, which `find_constitution.sh` explicitly supports).

### 5.2 Part 2 — wire the inheritance (`submodules/constitution/README.md`, "How to consume" §2)

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
>
> Same for `AGENTS.md` (any AI-agent tooling) and (since 2026-05-20)
> `QWEN.md` for Qwen Code:
>
> ```markdown
> > Base agent rules: `constitution/AGENTS.md` — READ IT FIRST.
> > The base file is authoritative for any topic not covered here.
> ```
>
> And for your project Constitution:
>
> ```markdown
> This constitution **extends** the Helix Universal Constitution at
> `constitution/Constitution.md`. All clauses there apply unless
> explicitly overridden below with an explicit `Override §X.Y`
> section.
> ```

The normative form of the same requirement is §11.4.35 invariant 6,
`Constitution.md:2919-2925`:

> 6. **`@constitution/CLAUDE.md` import (Claude-Code-style) and the
>    pointer-block fallback (Aider/Codex/Gemini-style) are equivalent.**
>    The consumer's CLAUDE.md MUST start with one of:
>    - The native import: `@constitution/CLAUDE.md`
>    - The portable pointer-block per the `## INHERITED FROM
>      constitution/CLAUDE.md` heading defined in
>      `constitution/CLAUDE.md` "How inheritance works".

And the canonical-root definition, `Constitution.md:2861-2874`:

> The three files in **this constitution submodule**
> (`constitution/Constitution.md`, `constitution/CLAUDE.md`,
> `constitution/AGENTS.md`) are the **canonical root** — also called
> the **parent** files. […]
> The three files in **the consuming project's repository root**
> (`<project-root>/CLAUDE.md`, `<project-root>/AGENTS.md`, optionally
> `<project-root>/Constitution.md` or equivalent) are the **consumer
> extensions**. They MUST start with the inheritance pointer […]

§11.4.157 (`Constitution.md:9564`) widens the carrier set from three to five:

> Every governance addition or edit MUST land in ALL FIVE carriers in lockstep: the canonical `Constitution.md` PLUS each per-agent mirror `CLAUDE.md` + `AGENTS.md` + `QWEN.md` + `GEMINI.md`

**Status in this repo: NOT DONE.** See [§6](#6-agent-instruction-files-across-the-umbrella-and-every-submodule).

### 5.3 Part 3 — templates to instantiate

The submodule ships the exact consumer-side scaffolds:

- `submodules/constitution/templates/CLAUDE.project.md.template` — opens with
  `## INHERITED FROM constitution/CLAUDE.md`, the "constitution wins" sentence,
  and the bare `@constitution/CLAUDE.md` import line.
- `submodules/constitution/templates/AGENTS.project.md.template` — opens with
  the `> Base agent rules live at constitution/AGENTS.md … **READ THOSE FIRST.**`
  blockquote, then a "Critical base rules restated (for agents that don't follow
  @imports)" list of 9 items.
- `submodules/constitution/templates/Constitution.project.md.template` — the
  "extends the Helix Universal Constitution" opener, plus `## Owned-submodule set`
  and `## Project-specific remotes` sections required by §4 and §2.1.

There is **no** `QWEN.project.md.template` or `GEMINI.project.md.template`
despite §11.4.157 mandating five-carrier lockstep. That is a gap in the
constitution submodule itself (recorded as G7b in [§8](#8-gaps-and-violations-ranked-by-severity)).

### 5.4 Part 4 — verify with an automated test (`submodules/constitution/README.md`, "How to consume" §4)

> Every consuming project should ship a test that verifies the
> constitution submodule is present, at the expected pinned revision,
> and that the project's CLAUDE.md / AGENTS.md / QWEN.md / Constitution
> all reference the submodule. See:
>
> - The ATMOSphere project's `test_constitution_inheritance.sh` for the
>   reference implementation pattern.
> - The Herald project's `tests/test_constitution_inheritance.sh` + paired
>   `tests/test_i6_refinement_meta.sh` […]
> - The Herald `scripts/audit_antibluff.sh` for the canonical anti-bluff
>   audit pattern […]

That gate must itself be mutation-proven by
`submodules/constitution/meta_test_inheritance.sh`, whose in-source header
states its contract:

> ```
> # Pattern (mutation testing — Constitution §1.1):
> #   1. Take a snapshot of Constitution.md.
> #   2. Mutate: delete the §11.4 anchor block.
> #   3. Run the consuming project's inheritance gate.
> #   4. Assert the gate now reports FAIL.
> #   5. Restore.
> ```

**Status in this repo: NOT DONE.** No `test_constitution_inheritance.sh` exists
under `tests/`, `scripts/`, or `_tests/`; `git grep meta_test_inheritance`
returns no hit outside the submodule itself.

### 5.5 Part 5 — the post-pull transaction (§11.4.164 + §11.4.32)

§11.4.164, `Constitution.md:9743`:

> The canonical hook script lives at `constitution/scripts/post_update_hook.sh` and is inherited by reference (§11.4.28) — NEVER copied locally.

and its consumer obligation:

> Every project that fetches/pulls the constitution submodule MUST invoke the post-update hook after the fetch completes. […] A project that pulls the constitution and does NOT invoke the hook is non-compliant

§11.4.32, `Constitution.md:2044-2050`:

> **Validation sweep contract.** The sweep is implemented as
> `scripts/verify-all-constitution-rules.sh` (canonical name) which:
> 1. Re-runs the existing governance-cascade verifier (`scripts/
>    verify-governance-cascade.sh`) covering every §11.9 + CONST-*
>    anchor across every owned submodule (recursive per CONST-047).

and, `Constitution.md:2085-2090`:

> **Composition.** §11.4.32 is the **enforcement engine** for every
> other §11.4.x and CONST-NNN rule. Without it, new rules cascade
> as anchors but never get enforced in the codebase.

**Status in this repo: NOT DONE.** Neither script exists.

### 5.6 Summary answer

> **The constitution prescribes a concrete, named, five-part adoption
> mechanism. Nothing needs to be invented. Of the five parts, exactly one
> (adding the submodule) is done in this repository; the other four are
> entirely unwired.**

---

## 6. Agent instruction files across the umbrella and every submodule

Enumerated with `ls -a`, `git ls-files`, and `find . -maxdepth 3` for
`AGENTS.md`, `CLAUDE.md`, `QWEN.md`, `GEMINI.md`, `AGENT.md`, `Constitution.md`,
`CONSTITUTION.md`, `CONVENTIONS.md`, `.cursorrules`, `.clinerules`,
`.windsurfrules`.

### 6.1 Umbrella root — the headline finding

| Expected file | Consumed by | Present? |
|---|---|---|
| `CLAUDE.md` | Claude Code | **ABSENT** |
| `AGENTS.md` | Codex, Cursor, Aider, OpenCode, Crush, Kimi CLI | **ABSENT** |
| `QWEN.md` | Qwen Code | **ABSENT** |
| `GEMINI.md` | Gemini CLI | **ABSENT** |
| `Constitution.md` | humans + all agents | **ABSENT** |
| `.cursorrules` | Cursor (legacy) | **ABSENT** |
| `CONTINUATION.md` (§12.10) | all agents | **ABSENT** |
| `helix-deps.yaml` (§11.4.31) | consumer tooling | **ABSENT** |

The only Markdown file at the repository root is `README.md`, and it does not
mention the constitution.

`README.md:41-44` goes further and states affirmatively that the constitution
is *not* consumed by anything:

> It is excluded from the Jekyll build
> anyway, and the other submodules (constitution/, design-toolkit/) are not read
> by any gate — so only these two are fetched.

`README.md:35-36` also instructs a fresh clone **not** to initialize it:

> ```bash
> git submodule update --init vasic.digital milosvasic.ru
> ```

`_analysis/OPENDESIGN-ADOPTION-PLAN.md:79` records the same state as a known
open item:

> **Wire the constitution as a submodule** of the `vasic` umbrella (`submodules/constitution` or `constitution/`) so `find_constitution.sh` resolves and the gates actually apply here (today it governs by reference only, NOT checked out).

That note is now half-stale — the submodule *is* checked out and mapped in
`.gitmodules` — but its substantive claim ("governs by reference only") remains
accurate: nothing reads it.

### 6.2 Every agent instruction file that exists anywhere in the tree

| Path | Consumed by | Inherits the constitution? | Evidence |
|---|---|---|---|
| `submodules/constitution/CLAUDE.md` | Claude Code | **N/A — it IS the canonical root** | §11.4.35: "The three files in **this constitution submodule** … are the **canonical root**" (`Constitution.md:2861`) |
| `submodules/constitution/AGENTS.md` | all other CLI agents | N/A — canonical root | same |
| `submodules/constitution/QWEN.md` | Qwen Code | N/A — canonical root | `QWEN.md:34` "The **authoritative source** is `Constitution.md` in this repository." |
| `submodules/constitution/GEMINI.md` | Gemini CLI | N/A — canonical root | `GEMINI.md:19-26` "these ARE the canonical root per §11.4.35, NOT consumer extensions" |
| `submodules/constitution/Constitution.md` | humans + all agents | N/A — canonical root | — |
| `vasic.digital/QWEN.md` | Qwen Code | **No** | `grep -in constitution vasic.digital/QWEN.md` → **0 hits**. 55 lines describing the `commit` script and `Upstreams/GitHub.sh`. |
| `milosvasic.ru/Upstreamable/AGENTS.md` | Codex/Cursor/etc. | **Yes — pointer form** | Lines 3-8: "> **Base agent rules:** when this module is consumed inside a project that includes the Helix Constitution submodule, the file `constitution/AGENTS.md` is authoritative for any topic not covered here. Locate it from any nested depth using the constitution's `find_constitution.sh` helper." |
| `milosvasic.ru/Upstreamable/CLAUDE.md` | Claude Code | **Yes — pointer form** | Line 6 heading `## Helix Constitution inheritance`; lines 9-13 reference `constitution/CLAUDE.md`, `constitution/Constitution.md`, `find_constitution.sh`. |
| `submodules/constitution/submodules/docs_chain/{AGENTS,CLAUDE,QWEN}.md` + `CONSTITUTION.md` | respective agents | **Yes** | All five of its top-level `.md` match "constitution"; README states it "is consumed as a core part of the HelixConstitution submodule". |
| `submodules/constitution/submodules/helix_perf_cache/{AGENTS,CLAUDE,GEMINI,QWEN}.md` | respective agents | **Yes** | All six top-level `.md` match; cites `constitution/submodules/helix_perf_cache/`, §11.4.28(C), §11.4.112. Sizes 5,417–5,430 B — the same content mirrored per vendor. |
| `.specify/memory/constitution.md` | spec-kit `/speckit.constitution` | **No — unrelated artifact** | It is the **unfilled spec-kit template**: line 1 is `# [PROJECT_NAME] Constitution`, body is `[PRINCIPLE_1_NAME]` placeholders. Nothing to do with HelixConstitution. |
| `.specify/extensions/superspec/examples/static-landing-page/CLAUDE.md` | example fixture | No | Vendored example inside a third-party submodule. |

### 6.3 Submodules with no agent instruction file at all

`ai_interviewing/`, `monetization/`, `design-toolkit/` (umbrella copy),
`submodules/superspec/`, and the constitution's `anti_bluff`, `continuum`,
`session_orchestrator`, `token_optimizer`.

Note that `session_orchestrator` and `token_optimizer` contain **zero**
references to the constitution in any top-level `.md` — they are the only two
engines in the constitution's own dependency set that do not acknowledge it.

### 6.4 The mechanical consequence

§11.4.35 invariant 5 (`Constitution.md:2913-2918`) defines what the propagation
gates check:

> The existing `CM-COVENANT-114-N-PROPAGATION` gate
> family verifies that anchor TEXT for §11.4.N exists in EVERY
> `CLAUDE.md` and `AGENTS.md` across the project.

There are **175** such gates. The umbrella has **zero** `CLAUDE.md` and **zero**
`AGENTS.md`. Therefore **all 175 propagation gates fail by construction** — not
as a judgement call, but as an arithmetic fact. `git grep` for the literal
`11.4.<N>` across umbrella-owned files finds 62 distinct anchors mentioned, all
of them inside `_analysis/`, `_tests/`, `README.md`, `.github/workflows/ci.yml`
and `.gitignore` — **none** inside an agent context carrier, because none exists.

---

## 7. Proposed minimal inheritance design

Design principles, in priority order:

1. **Reference, never copy.** §11.4.164 states the rule for hook scripts
   verbatim — "inherited by reference (§11.4.28) — NEVER copied locally"
   (`Constitution.md:9743`) — and §11.4.35 invariant 7 forbids re-authoring an
   anchor in the wrong layer: "AI agents MUST NOT silently re-author a §11.4.X
   anchor in the wrong layer and call it propagation." A 1.5 MB copy of
   `Constitution.md` into the umbrella would diverge on the next upstream
   commit and would itself become a §11.4.35 violation.
2. **Path-correct.** Every template and every quoted snippet says
   `constitution/…`. In this repo the real path is `submodules/constitution/…`.
   Every pointer written must use the real path, or the `@import` silently
   resolves to nothing. This is the single highest-risk detail in the whole
   change.
3. **Five carriers, not three.** §11.4.157(A) requires CLAUDE + AGENTS + QWEN +
   GEMINI + Constitution in lockstep.
4. **Additive only.** No existing file's meaning changes; `README.md` gains
   links, `.claude/settings.json` gains a hook.

### 7.1 New files at the umbrella root (5)

| File | Content | Source |
|---|---|---|
| `CLAUDE.md` | Instantiate `submodules/constitution/templates/CLAUDE.project.md.template`, replacing every `constitution/` with `submodules/constitution/`. Its first content line must be the `## INHERITED FROM submodules/constitution/CLAUDE.md` heading; the import line `@submodules/constitution/CLAUDE.md` follows. | §11.4.35 inv. 6 |
| `AGENTS.md` | Instantiate `AGENTS.project.md.template`, path-corrected. Keeps the template's "Critical base rules restated" block verbatim — that block is the constitution's own prescribed restatement for agents that ignore `@imports`, so reproducing it is sanctioned, not duplication. | README "How to consume" §2 |
| `QWEN.md` | No template ships. Use the AGENTS.md pointer form, which `submodules/constitution/README.md` explicitly prescribes for QWEN: `> Base agent rules: submodules/constitution/QWEN.md — READ IT FIRST.` plus the same restated-rules block. | README "How to consume" §2 + §11.4.157 |
| `GEMINI.md` | No template ships. Use the pointer block that `submodules/constitution/GEMINI.md:31-38` itself prescribes for consumers: `## INHERITED FROM constitution/GEMINI.md` → path-corrected. | §11.4.157(A) |
| `Constitution.md` | Instantiate `Constitution.project.md.template`, path-corrected. Must populate `## Owned-submodule set` with the six owned gitlinks (`milosvasic.ru`, `vasic.digital`, `design-toolkit`, `ai_interviewing`, `monetization`, `submodules/constitution`) and mark `submodules/superspec` third-party (upstream `git@github.com:WangX0111/superspec.git`, outside every operator-listed org). | §4 + §11.4.28 |

Each of the five is a pointer plus a project-specific delta. None restates the
234 anchors. Total added text should be on the order of 150–300 lines, not
15,000.

### 7.2 The exact pointer block

For `CLAUDE.md`, the first lines of the file:

```markdown
# vasic — CLAUDE.md

## INHERITED FROM submodules/constitution/CLAUDE.md

All rules in `submodules/constitution/CLAUDE.md` and the
`submodules/constitution/Constitution.md` it references apply unconditionally
to this project. Project-specific rules below extend them — they do NOT weaken
or override any universal clause.

When this file disagrees with the constitution submodule, the constitution wins.

@submodules/constitution/CLAUDE.md
```

For `AGENTS.md` / `QWEN.md` / `GEMINI.md`, the portable blockquote form, since
those runtimes do not all honour `@import`:

```markdown
> Base agent rules: `submodules/constitution/AGENTS.md` — READ IT FIRST.
> The base file is authoritative for any topic not covered here.
> Locate it from any nested depth with `submodules/constitution/find_constitution.sh`.
```

### 7.3 Propagation to submodules

Per §11.4.28(B) an owned submodule "MUST remain **fully decoupled** from any
specific consuming project" and be "**Project-not-aware**"
(`Constitution.md:2411-2418`). So the submodule-side pointer must be the
**conditional** form already proven in this repo at
`milosvasic.ru/Upstreamable/AGENTS.md:3-12` — which names no consuming project
and degrades gracefully:

> When this module is consumed standalone (no constitution
> submodule reachable in any parent), only the module-local notes
> below apply.

That existing file is the reference implementation for the propagation work.
Targets that need it, in dependency order:

| Target | Needs |
|---|---|
| `vasic.digital/` | `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` created; existing `QWEN.md` gains the pointer block above its current content |
| `milosvasic.ru/` (root) | all four carriers — only `Upstreamable/` currently has any |
| `design-toolkit/` | all four carriers |
| `ai_interviewing/` | all four carriers |
| `monetization/` | all four carriers |
| `submodules/constitution/submodules/session_orchestrator` | all four carriers (currently zero constitution awareness) |
| `submodules/constitution/submodules/token_optimizer` | all four carriers (currently zero constitution awareness) |
| `submodules/constitution/submodules/{anti_bluff,continuum,design-toolkit}` | carriers absent though READMEs cite the constitution |
| `submodules/superspec` | **none** — third-party, excluded per §4 |

Ordering matters: §3 (`Constitution.md:203-215`) requires the submodule commit
and push to land **before** the parent captures the pointer.

### 7.4 Enforcement wiring (without which the pointers are decoration)

| Artifact | Purpose | Mandated by |
|---|---|---|
| `scripts/verify-governance-cascade.sh` | Assert each of the 5 carriers exists, opens with the pointer, and that every owned submodule carries one. | §11.4.32 step 1 |
| `scripts/verify-all-constitution-rules.sh` | The canonical post-pull sweep that calls the above plus each implementable gate. | §11.4.32 (canonical name given verbatim) |
| `tests/test_constitution_inheritance.sh` | The presence/revision/reference gate. | README "How to consume" §4 |
| A meta-test calling `bash submodules/constitution/meta_test_inheritance.sh 'bash tests/test_constitution_inheritance.sh'` | Proves the gate above is not a bluff gate. | §1.1 + `meta_test_inheritance.sh` usage header |
| `PreToolUse` hook in `.claude/settings.json` → `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` | Blocks force-push / sudo / host-power at the tool-call boundary. Reference the submodule path; do not copy. | §11.4.109(A) |
| `docs/AGENT_GUARDRAILS.md` | The subagent constitutional preamble the orchestrator pastes into every dispatch. | §11.4.109(B) |
| A post-pull invocation of `submodules/constitution/scripts/post_update_hook.sh` | Completes the governance-update transaction. | §11.4.164 |
| `helix-deps.yaml` at the umbrella root | Declares the umbrella's own six owned deps. Model it on `submodules/constitution/helix-deps.yaml`. | §11.4.31 |

### 7.5 Why referencing beats copying — stated plainly

- A copy of `Constitution.md` is 1.53 MB and 11,101 lines. It would be stale the
  moment upstream lands anchor §11.4.239.
- §11.4.35 invariant 7 names the failure mode: "duplicates silently diverge over
  time", and the prescribed remedy for a misfiled rule is `git mv` + commit,
  explicitly *not* "leave both copies in place to be safe".
- The `@import` / pointer-block pair is the constitution's own answer to the
  only real objection (agents that do not resolve imports), and §11.4.35
  invariant 6 declares the two forms **equivalent**.
- The restated-rules block in `AGENTS.project.md.template` is a deliberate,
  bounded 9-item safety net authored by the constitution itself — using it is
  following the mechanism, not duplicating the corpus.

---

## 8. Gaps and violations, ranked by severity

Severity uses the constitution's own vocabulary: a "release blocker" clause
violated is CRITICAL.

### 8.0 Current status ledger — READ THIS BEFORE THE G-HEADINGS BELOW

> **The G-headings in §8.1 onward are the ORIGINAL 2026-08-26 discovery
> evidence and are deliberately NOT rewritten as gaps move.** That is what makes
> this document a forensic record: it preserves what was actually observed on
> the day, including the observations that later turned out to be wrong. Several
> of them are now stale by design.
>
> **Never quote a G-heading below as a current status.** Use the ledger in this
> subsection, and treat even it as dated — the authority is the
> `- G<n> — <STATUS>` lines in the four root carriers, which
> `scripts/continuation-check.sh` C4 holds in agreement with `CONTINUATION.md`
> §4 mechanically on every run. This ledger is not machine-compared to those; if
> it disagrees with them, **this ledger is the defect**.

Reconciled against the carriers and re-measured on **2026-09-01**:

| Gap | Status now | Measured how |
|---|---|---|
| G1 | **CLOSED** | Four root carriers exist (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`), 520 lines each, sharing the line-24-to-EOF digest `a1f3a936e0ff6817…`. |
| G2 | **CLOSED** | All four plus root `Constitution.md` open with `## INHERITED FROM `; cascade C5 ROOT-CARRIERS PASS. |
| G3 | **CLOSED** | Cascade step 1 exits 0 at 12 PASS / 0 FAIL / 0 ENV / 7 NOTE, with a `--prove-failure` paired mutation. Closes the sweep CONTRACT, not the sweep's verdict — see G-note below. |
| G4 | **PARTIAL, and will not reach CLOSED from inside this tree** | Umbrella root complies (`.github/workflows/ci.yml.disabled`, local pre-push hook). `milosvasic.ru/.github/workflows/pages.yml` stays ACTIVE as a **documented deviation, never an override** — it is the sole publish path for a live production site. `vasic.digital` is non-compliant at the **provider** level with no file-level remedy. Provider-side settings are operator-only and **unverified**; `scripts/verify-provider-ci.sh` measures on demand and its exit 2 is not a pass. |
| G5 | **PARTIALLY CLOSED** | The commit **wrapper** exists (`commit` on PATH, driven by the tracked `upstreams/GitHub.sh`); it runs `git add .`. Missing: git **hooks** as a tracked, travelling artefact — `.git/hooks/pre-push` is installed here but `.git/hooks/` is untracked, so a fresh clone is unprotected. |
| G6 | **CLOSED** | `helix-deps.yaml` exists at the root and parses under `yaml.safe_load`. |
| G7 | **CLOSED — 28 of 28** | `bash scripts/verify-governance-cascade.sh` exits 0. C2 finds all **7 × 4 = 28** owned-submodule carriers present; C3 finds all 28 accepted by the canonical `is_pointer_carrier` predicate; C8 finds each owned submodule internally in lockstep. The fleet is DERIVED from `.gitmodules` + `helix-deps.yaml`, never hardcoded. **The §8 G7 heading below, and the staged-but-unapplied `propagation/` note, are both superseded.** Withdrawn figures: "20/20", "20/24", and a verbally circulated "24/24" (which was 6 × 4, before `submodules/containers` joined the fleet). |
| G8 | **OPEN** | §11.4.65 markdown/export mandate unmet across the repository. No work in flight. |
| G9 | **NO VERIFIED CURRENT STATUS** | Not carried in the carriers' gap list. Do not report it closed or open without re-auditing. |
| G10 | **NO VERIFIED CURRENT STATUS** | As G9. |
| G11 | **NO VERIFIED CURRENT STATUS** | The duplicate `design-toolkit` checkout is still *described* in `helix-deps.yaml` around its `design-toolkit` entry, with a two-command re-derivation recipe. A description is not a status. |
| G12 | **OPEN** | No `PreToolUse` guard is wired; the canonical guard script sits unused in the constitution submodule. No work in flight. |

**G-note — the sweep's own verdict.** G3 closing means a sweep exists, runs, and
is mutation-proven. It does **not** mean the sweep passes.
`scripts/verify-all-constitution-rules.sh` discovers its gates dynamically and
that population moved **57 → 286** when the constitution pin was fast-forwarded,
so every split published before the fast-forward is withdrawn and none is
comparable to a present-day run. The most recent measurement on record is
**186 PASS / 95 FAIL / 6 ERROR of 287 gates** — recorded as a *reported prior
measurement*, because a re-run started 2026-09-01 had not completed when this
was written. Its failures are known to include third-party and staged carriers
that no commit here can clear, and defects internal to the constitution
submodule itself.

**Also open, and not a numbered gap:**
`scripts/audit-environment-assumptions.sh` exits **1** — 7 frozen GNU-vs-BSD
environment assumptions in `scripts/verify-check-registry.sh` (6) and
`scripts/verify-manifest-pins.sh` (1), plus 699 baselined occurrences across
18 files. A baseline is recorded debt, not compliance.

### G1 — CRITICAL — The umbrella has no consumer governance layer at all

**Rule:** §11.4.35 (`Constitution.md:2861-2874`), §11.4.157(A)
(`Constitution.md:9564`).
**Evidence:** `ls` at the repository root returns exactly one `.md` file,
`README.md`. `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`, and
`Constitution.md` are all ABSENT. `git ls-files` confirms none is tracked.
**Consequence:** every one of the 175 `CM-COVENANT-114-N-PROPAGATION` gates
fails by construction, and no agent invoked in this repository is exposed to
any constitutional rule.

### G2 — CRITICAL — No inheritance pointer exists anywhere in the umbrella

**Rule:** §11.4.35 invariant 6 (`Constitution.md:2919-2925`).
**Evidence:** `git grep -e '@constitution/CLAUDE.md' -e 'INHERITED FROM constitution'`
returns zero hits in any governance file. The only matches for
`find_constitution.sh` are marketing copy in `_content*/products/HelixConstitution.md`
and `_analysis/content-briefs/HelixConstitution.md` — the repo *describes* the
mechanism as a product feature while not using it.

### G3 — CRITICAL — No post-pull validation sweep; the enforcement engine is missing

**Rule:** §11.4.32 (`Constitution.md:2026-2094`), which describes itself as
"the **enforcement engine** for every other §11.4.x and CONST-NNN rule. Without
it, new rules cascade as anchors but never get enforced in the codebase."
**Evidence:** `scripts/verify-all-constitution-rules.sh` ABSENT,
`scripts/verify-governance-cascade.sh` ABSENT. `ls scripts/` returns only
`install_skills.sh`, `rollback-agents-wizard.sh`, `setup-agents-wizard.sh`,
`test-setup-agents-wizard.sh`.

### G4 — CRITICAL — Active CI directly contradicts §11.4.156

**Rule:** §11.4.156 (`Constitution.md:9542-9557`): "**(A) Zero active CI at the
repository root.** No active `.github/workflows/*.yml|*.yaml` … may exist at the
ROOT of any governed repository/submodule". "Non-compliance is a release blocker
regardless of context. No escape hatch — no `--allow-ci`, `--enable-workflow`,
`--keep-pipeline`, `--remote-ci-OK`, `--ci-exempt` flag."
**Evidence:** `.github/workflows/ci.yml` exists at the root with live triggers,
and `README.md:3` advertises it with a status badge. Note this is a *genuine
conflict of intent*, not mere neglect: the workflow's own header documents why
it was added ("Nothing ran the test suite, so a regression could only be caught
by hand"). Resolving it is an operator decision — either disable per §11.4.156(B)
(rename to `ci.yml.disabled-local-only`) and migrate to the §11.4.75 local
five-layer hook ritual, or record an explicit `Override §11.4.156` in the new
project `Constitution.md`. Silently leaving it is the one option the constitution
forbids.

> **UPDATE 2026-08-27 — decided, and one of the two options above was wrong.**
> This section is a Phase-1 snapshot and is retained as written. Two corrections:
>
> 1. **The `Override §11.4.156` option does not exist.** It was sought and
>    disqualified twice over. §11.4.156's closing formula names and refuses the
>    exemption vocabulary — *"No escape hatch — no `--allow-ci`,
>    `--enable-workflow`, `--keep-pipeline`, `--remote-ci-OK`, `--ci-exempt`
>    flag"* — so a project-local override is a `--ci-exempt` by another
>    spelling. And the inheritance contract every carrier here states —
>    *"Project-specific rules below extend them — they do NOT weaken or override
>    any universal clause"* — makes a project-local override of an inherited
>    clause structurally impossible. With the override gone, compliance was the
>    only remaining path that does not amend shared governance.
> 2. **The operator decided: *"Comply — disable both, enforce locally."***
>    ~~Both `.github/workflows/ci.yml` and
>    `milosvasic.ru/.github/workflows/pages.yml` are renamed to a non-active
>    `.disabled` name per §11.4.156(B), and the gates move to a local
>    **pre-push hook**.~~ No constitution amendment was made.
> 3. **PARTIALLY REVERSED the same day — only `ci.yml` was disabled.** A material
>    fact emerged after correction 2 was written:
>    `gh api repos/milos85vasic/milosvasic.ru/pages` returns
>    `build_type: "workflow"`, meaning GitHub Pages publishes the **live
>    production site** `https://milosvasic.ru/` exclusively by running
>    `pages.yml`. There is no `gh-pages` branch, no `docs/` folder, and the repo
>    root is Jekyll SOURCE, so it cannot be served raw from a branch;
>    `_tools/deploy-langs.sh` pushes source and then `sleep`s waiting for that
>    very workflow, so it is not a substitute. Disabling `pages.yml` would end
>    publishing outright. **Operator's overriding directive, verbatim:** *"Make
>    sure all pages websites work flawlessly! No website can be broken! All
>    websites we have here are running deployed in production!"*
>
> **The state that stands (verified 2026-08-27).**
>
> | Surface | State | Posture |
> |---|---|---|
> | `.github/workflows/ci.yml` | renamed `ci.yml.disabled`; gates in a local pre-push hook | umbrella root **file-level compliant** |
> | `milosvasic.ru/.github/workflows/pages.yml` | **ACTIVE**, byte-identical to the publishing version; **will not be disabled** | **known, documented DEVIATION — not an override** |
> | `vasic.digital` | zero workflow files, yet `build_type: "legacy"` triggers `pages build and deployment` on every push | **non-compliant at the PROVIDER level; no file-level remedy** |
>
> The `milosvasic.ru` state is **not** an `Override §11.4.156` and must never be
> recorded as one — correction 1 above still holds in full. An override would
> claim the clause no longer applies; this admits it applies, is knowingly unmet,
> and says why.
>
> **G4 moves OPEN → PARTIAL, not CLOSED — and will not reach CLOSED.** Honest
> boundary (§11.4.6): file-level disabling stops FILE-triggered runs but does not
> reach provider-side settings (org-default required workflows,
> branch-protection required checks, Pages source settings, provider-side
> scheduled exports); those remain operator-only to CHANGE. Their STATUS is no
> longer asserted from memory: `bash scripts/verify-provider-ci.sh` enumerates
> the owned repositories from this checkout's own remotes and queries the
> provider — exit **0** none found, **1** confirmed, **2** could not determine
> (**not** a pass). `scripts/setup-agents-wizard.sh` runs it as Step 9 and turns
> a confirmed finding into a manual step. Anything this document says about the
> provider is a dated observation; re-measure before quoting it.
> **Cost of the umbrella half:** no server-side enforcement on push or PR;
> `.git/hooks/` is untracked, so a fresh clone has no protection until
> `bash scripts/pre-push-gates.sh --install` is run, and `git push --no-verify`
> bypasses the hook. Full record:
> [`DECISION-11-4-156-COMPLY.md`](DECISION-11-4-156-COMPLY.md) §0; CI surface
> inventory: `CI-INVENTORY-11-4-156.md`.

### G5 — HIGH — No mechanical enforcement layer (§11.4.75 five layers, zero present)

**Rule:** §11.4.75 (`Constitution.md:6967-7010`).
**Evidence:** `ls .git/hooks/` shows no non-sample hooks. No `commit_all.sh`.
No pre-commit, pre-push, or post-commit wiring anywhere. §11.4.75's own forensic
anchor is the operator asking "Why do these violations still happen!?" — the
answer here is that no layer exists.

### G6 — HIGH — No `helix-deps.yaml` at the umbrella root

**Rule:** §11.4.31 (`Constitution.md:1907-1913`): "Every owned-by-us submodule
MUST ship a machine-readable, version-controlled **dependency manifest** at
the canonical path `helix-deps.yaml`".
**Evidence:** ABSENT at root. The constitution submodule ships its own at
`submodules/constitution/helix-deps.yaml` (a good model), and its header even
records that its own manifest "was MISSING until 2026-08-15" — the same class of
gap, previously caught one level up.

### G7 — HIGH — Zero propagation to owned submodules

> **SUPERSEDED — see §8.0.** G7 is **CLOSED** as of 2026-09-01, measured at
> **28 of 28** carriers across seven owned submodules by
> `bash scripts/verify-governance-cascade.sh` (exit 0). The evidence paragraph
> below is the 2026-08-26 observation, preserved unchanged as the forensic
> record of what was true then. It is not a current status.

**Rule:** §11.4.157(A) five-carrier lockstep; §11.4.28(A) equal-codebase.
**Evidence:** Of six owned submodules, only `vasic.digital` has any carrier
(`QWEN.md`), and it contains **zero** references to the constitution
(`grep -in constitution vasic.digital/QWEN.md` → 0 hits). `ai_interviewing`,
`monetization`, `design-toolkit`, and `milosvasic.ru` root have none at all.

**G7b (MEDIUM, upstream defect):** the constitution submodule ships
`templates/` for CLAUDE / AGENTS / Constitution but **not** for QWEN or GEMINI,
even though §11.4.157 makes all five equal. Consumers must hand-derive two of
five carriers. Worth reporting upstream per §11.4.26.

### G8 — HIGH — §11.4.65 export mandate comprehensively unmet

**Rule:** §11.4.65 (`Constitution.md:5959-5966`): "Any markdown document inside
the project and which is not part of the applications or services source code
MUST BE exported (be available) in PDF and HTML!"
**Evidence:** 265 tracked `.md` files outside submodules and `_content*`;
**0** of them have an `.html` sibling (counted mechanically). `README.md` has
neither `README.html` nor `README.pdf`.

### G9 — HIGH — §11.4.212 README-as-entrypoint unmet; every project doc is an orphan

**Rule:** §11.4.212 (`Constitution.md:10586`): "No project document may be an
ORPHAN — a doc that no link-path from README reaches is a §11.4.212 violation."
**Evidence:** `grep -oE '\]\([^)]+\)' README.md` returns exactly two links, both
to the CI badge/workflow URL. `_analysis/`, `_tests/GATES.md`,
`_tests/TEST-TYPES.md`, `docs/setup-agents-wizard/` are all unreachable from
README.

### G10 — MEDIUM — §4 tag mirroring incomplete

**Rule:** §4 (`Constitution.md:218-227`): "the same tag MUST be created on
**every owned submodule**".
**Evidence:** umbrella tags are `pre-restyle, v1.7.1, v1.7.2, v1.8.0`.
`git -C <sub> tag -l v1.8.0`: present on `milosvasic.ru` and `vasic.digital`;
**absent** on `design-toolkit`, `ai_interviewing`, `monetization`,
`submodules/constitution` — all owned-org.

### G11 — MEDIUM — `design-toolkit` is checked out twice

**Rule:** §11.4.28(C) dependency-layout / no-nested-own-org-chains.
**Evidence:** `design-toolkit` @ `16e4e76` at the umbrella root **and**
`submodules/constitution/submodules/design-toolkit` @ `16e4e76`. The shas match
today, so nothing is broken now; the constitution's own `helix-deps.yaml`
justifies the inner copy under the "§11.4.28(C) hub carve-out". But two gitlinks
to the same repo can drift independently, and no manifest at the umbrella
declares which one is authoritative — because the umbrella has no manifest (G6).

### G12 — MEDIUM — §11.4.109 anti-forgetting layer absent while its script sits unused

**Rule:** §11.4.109(A)/(B) (`Constitution.md:8399-8440`).
**Evidence:** `.claude/settings.local.json` contains only a `permissions.allow`
array with two Lumen MCP entries — no `PreToolUse` hook. Meanwhile
`submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` is present
(29,705 bytes, executable) and would block force-push / sudo / host-power
classes if wired. `docs/AGENT_GUARDRAILS.md` is ABSENT.

### Ranking rationale

G1–G4 are CRITICAL because each independently defeats the entire adoption:
without carriers no rule reaches an agent (G1/G2); without the sweep no rule is
ever checked (G3); and G4 is an active, live contradiction of a named
release-blocker clause rather than a mere omission. G5–G9 are HIGH because each
violates a "release blocker" clause but is remediable without an operator
policy decision. G10–G12 are MEDIUM: real, cited, and fixable, but none blocks
the inheritance wiring itself.

---

## 9. Full mandatory-rule table

All 261 numbered anchors extracted mechanically from
`submodules/constitution/Constitution.md`. Two known duplicate anchor numbers
(§11.4.140 and §11.4.141, each minted twice) are the **operator-owned
collision** the constitution documents in its own header Status summary
("the KNOWN operator-owned §11.4.54 anchor-number collision on 11.4.140/11.4.141
cited strictly in those senses") — both rows are listed.

Column meanings:

- **Prop. gate** — `**FAIL**` where the anchor declares a
  `CM-COVENANT-114-N-PROPAGATION` gate. All 175 such gates fail because the
  umbrella has zero `CLAUDE.md` / `AGENTS.md` (see [§6.4](#64-the-mechanical-consequence)).
  `—` means the anchor declares no such gate. 177 rows carry `**FAIL**` because
  §11.4.140 and §11.4.141 are each minted twice (the documented collision).
- **Substance** — first-hand or cited verdict on the underlying requirement.
  **65 anchors were examined** in this pass: 50 received a definite
  Yes / Partial / No verdict, and 15 were examined but remain `Unknown` because
  they are conditional or need a runtime check. The other **196 were not
  examined** and are honestly marked `Unknown` rather than guessed. `Unknown`
  here means *not checked* — and given G1–G3, the realistic prior is that most
  are unmet.

| Anchor | Title | Source | Prop. gate | Substance |
|---|---|---|---|---|
| §1 | Test coverage is mandatory for every change | `Constitution.md:133` | — | No |
| §1.1 | False-positive immunity is an invariant | `Constitution.md:147` | — | Partial |
| §2 | Commit and push mechanics — single entrypoint, locked | `Constitution.md:168` | — | No |
| §2.1 | Multi-upstream push is the norm | `Constitution.md:185` | — | Unknown |
| §3 | Submodule changes propagate through submodule commits first | `Constitution.md:201` | — | Unknown |
| §4 | Every tag on the main repo MUST be mirrored on every owned submodule | `Constitution.md:218` | — | No |
| §5 | Changelog discipline and multi-format export | `Constitution.md:229` | — | No |
| §6 | Documentation up to the nano-details | `Constitution.md:247` | — | No |
| §7 | Making false-success results literally impossible | `Constitution.md:265` | — | Partial |
| §7.1 | NO BLUFF — positive-evidence-only validation | `Constitution.md:282` | — | Partial |
| §8 | Bleeding-edge ultra-perfection quality bar | `Constitution.md:319` | — | Unknown |
| §9 | Absolute codebase and data safety — zero risk, zero loss | `Constitution.md:351` | — | Unknown |
| §9.1 | Mandatory safety protocol for destructive operations | `Constitution.md:359` | — | Unknown |
| §9.2 | Force-push requires explicit user authorization every time | `Constitution.md:400` | — | Unknown |
| §9.3 | Hardlinked backup is the standard — there is no excuse | `Constitution.md:421` | — | No |
| §9.4 | Commit-message audit trail for history rewrites | `Constitution.md:429` | — | Unknown |
| §10 | Enforcement | `Constitution.md:442` | — | No |
| §11 | End-user quality covenant | `Constitution.md:452` | — | Partial |
| §11.4 | End-user quality guarantee — forensic anchor (User mandate, 2026-04-28) | `Constitution.md:454` | — | No |
| §11.4.1 | FAIL-bluffs are equally forbidden | `Constitution.md:485` | — | Unknown |
| §11.4.2 | Recorded-evidence requirement | `Constitution.md:515` | — | Unknown |
| §11.4.3 | Per-environment-topology test dispatch | `Constitution.md:540` | — | Unknown |
| §11.4.4 | Test-interrupt-on-discovery + retest-from-clean-baseline | `Constitution.md:557` | — | Unknown |
| §11.4.5 | Captured-evidence quality analysis | `Constitution.md:601` | — | Unknown |
| §11.4.6 | No-guessing mandate | `Constitution.md:630` | — | Yes |
| §11.4.7 | Demotion-evidence rule | `Constitution.md:651` | — | Unknown |
| §11.4.8 | Deep-web-research-before-implementation | `Constitution.md:672` | — | Unknown |
| §11.4.9 | Batch-source-fixes-before-rebuild | `Constitution.md:696` | — | Unknown |
| §11.4.10 | Credentials-handling mandate | `Constitution.md:709` | — | Yes |
| §11.4.10.A | Pre-store credential leak audit (User mandate, 2026-05-17) | `Constitution.md:751` | — | Unknown |
| §11.4.11 | File-layout discipline | `Constitution.md:820` | — | Unknown |
| §11.4.12 | Auto-generated docs sync mandate | `Constitution.md:857` | — | Unknown |
| §11.4.13 | Out-of-band sink-side captured-evidence | `Constitution.md:870` | — | Unknown |
| §11.4.14 | Test playback cleanup mandate | `Constitution.md:888` | — | Unknown |
| §11.4.15 | Item-status tracking mandate | `Constitution.md:913` | — | Unknown |
| §11.4.16 | Item-type tracking mandate | `Constitution.md:935` | **FAIL** | Unknown |
| §11.4.17 | Universal-vs-project classification of new rules (User mandate, 2026-05-14) | `Constitution.md:970` | — | No |
| §11.4.20 | Subagent-driven-by-default mandate (User mandate, 2026-05-14) | `Constitution.md:1017` | — | Unknown |
| §11.4.18 | Script documentation mandate (User mandate, 2026-05-14) | `Constitution.md:1089` | — | Unknown |
| §11.4.19 | Fixed-document column-alignment mandate (User mandate, 2026-05-14) | `Constitution.md:1150` | **FAIL** | Unknown |
| §11.4.21 | Operator-blocked status + self-resolution exhaustion mandate (User mandate, 2026-05-14) | `Constitution.md:1253` | **FAIL** | Unknown |
| §11.4.22 | Document-sync commit discipline (User mandate, 2026-05-14) | `Constitution.md:1398` | — | Unknown |
| §11.4.23 | Visual-cue & grouping mandate for Issues docs (User mandate, 2026-05-14) | `Constitution.md:1493` | — | Unknown |
| §11.4.24 | Build-resource stats tracking mandate (User mandate, 2026-05-14) | `Constitution.md:1593` | — | Unknown |
| §11.4.25 | Full-Automation-Coverage Mandate (User mandate, 2026-05-15) | `Constitution.md:1708` | — | Unknown |
| §11.4.26 | Constitution-Submodule Update Workflow Mandate (User mandate, 2026-05-15) | `Constitution.md:1788` | — | No |
| §11.4.31 | Submodule-Dependency-Manifest Mandate (User mandate, 2026-05-15) | `Constitution.md:1879` | — | No |
| §11.4.32 | Post-Constitution-Pull Validation Mandate (User mandate, 2026-05-15) | `Constitution.md:2026` | — | No |
| §11.4.30 | .gitignore + No-Versioned-Build-Artifacts Mandate (User mandate, 2026-05-15) | `Constitution.md:2095` | — | Unknown |
| §11.4.29 | Lowercase-Snake_Case-Naming Mandate (User mandate, 2026-05-15) | `Constitution.md:2225` | — | Unknown |
| §11.4.28 | Submodules-As-Equal-Codebase + Decoupling + Dependency-Layout Mandate (User mandate, 2026-05-15) | `Constitution.md:2359` | — | Partial |
| §11.4.27 | No-Fakes-Beyond-Unit-Tests + 100%-Test-Type-Coverage Mandate (User mandate, 2026-05-15) | `Constitution.md:2548` | — | Partial |
| §11.4.33 | Type-aware closure-status vocabulary (User mandate, 2026-05-15) | `Constitution.md:2691` | — | Unknown |
| §11.4.34 | Reopened-source attribution mandate (User mandate, 2026-05-15) | `Constitution.md:2747` | — | Unknown |
| §11.4.35 | Canonical-root inheritance clarity (User mandate, 2026-05-15) | `Constitution.md:2816` | — | No |
| §11.4.36 | Mandatory install_upstreams on clone/add Mandate (User mandate, 2026-05-15) | `Constitution.md:2948` | — | Unknown |
| §11.4.37 | Fetch-before-edit mandate (User mandate, 2026-05-15) | `Constitution.md:3037` | — | Unknown |
| §11.4.38 | Installable-Asset Evidence Mandate (User mandate, 2026-05-17) | `Constitution.md:3131` | — | Unknown |
| §11.4.39 | Per-Feature On-Device End-User Validation Mandate (iter-76, 2026-05-17) | `Constitution.md:3192` | — | Unknown |
| §11.4.40 | Full-suite retest before release tag mandate (User mandate, 2026-05-17) | `Constitution.md:3236` | **FAIL** | Unknown |
| §11.4.41 | Pre-Force-Push Merge-First Mandate (User mandate, 2026-05-17) | `Constitution.md:3323` | — | Unknown |
| §11.4.42 | Iteration-discipline mandate (User mandate, 2026-05-18) | `Constitution.md:3455` | **FAIL** | Unknown |
| §11.4.43 | TDD-Fix-Discipline Mandate (User mandate, 2026-05-18) | `Constitution.md:3555` | **FAIL** | Unknown |
| §11.4.44 | Document Revision Header Mandate (User mandate, 2026-05-18) | `Constitution.md:3659` | **FAIL** | No |
| §11.4.45 | Integration-Status-Doc Maintenance Mandate (User mandate, 2026-05-18) | `Constitution.md:3761` | **FAIL** | Unknown |
| §11.4.46 | Validate-recent-work-before-post-flash-tests mandate (User mandate, 2026-05-18) | `Constitution.md:3860` | **FAIL** | Unknown |
| §11.4.47 | Firebase Data Review Mandate (User mandate, 2026-05-18) | `Constitution.md:3963` | **FAIL** | Unknown |
| §11.4.48 | UI-Driven Video Testing Mandate (User mandate, 2026-05-18) | `Constitution.md:4069` | **FAIL** | Unknown |
| §11.4.49 | Dual-Approach Testing Mandate (User mandate, 2026-05-18) | `Constitution.md:4205` | **FAIL** | Unknown |
| §11.4.50 | Deterministic Consistency Mandate (User mandate, 2026-05-18) | `Constitution.md:4315` | **FAIL** | Unknown |
| §11.4.51 | Live-ADB-First Maximization Mandate (User mandate, 2026-05-18) | `Constitution.md:4437` | **FAIL** | Unknown |
| §11.4.52 | Autonomous-Validation Mandate (User mandate, 2026-05-18) | `Constitution.md:4561` | **FAIL** | Unknown |
| §11.4.53 | Fixed_Summary parity mandate (User mandate, 2026-05-18) | `Constitution.md:4744` | **FAIL** | Unknown |
| §11.4.54 | ATM-NNN ticket identifier mandate (User mandate, 2026-05-19) | `Constitution.md:4886` | **FAIL** | Unknown |
| §11.4.55 | Reopens-history tracking + per-item Reopens.md doc (User mandate, 2026-05-19) | `Constitution.md:5011` | **FAIL** | Unknown |
| §11.4.56 | Status_Summary parity + two-audience format (User mandate, 2026-05-19) | `Constitution.md:5124` | **FAIL** | Unknown |
| §11.4.57 | README.md doc-link section + revision metadata (User mandate, 2026-05-19) | `Constitution.md:5224` | **FAIL** | No |
| §11.4.58 | Parallel-development methodology (User mandate, 2026-05-19) | `Constitution.md:5327` | **FAIL** | Unknown |
| §11.4.59 | README always-sync mandate (User mandate, 2026-05-19) | `Constitution.md:5544` | — | Unknown |
| §11.4.60 | Documentation always-sync composite covenant (User mandate, 2026-05-19) | `Constitution.md:5622` | **FAIL** | Unknown |
| §11.4.61 | Mandatory Markdown metadata table + structured-doc ToC (User mandate, 2026-05-19) | `Constitution.md:5725` | — | No |
| §11.4.63 | Workable-items procedure docs as single source of truth (User mandate, 2026-05-19) | `Constitution.md:5860` | **FAIL** | Unknown |
| §11.4.65 | Universal Markdown export mandate (User mandate, 2026-05-19) | `Constitution.md:5954` | **FAIL** | No |
| §11.4.66 | Blocker-resolution interactive-clarification mandate (User mandate, 2026-05-19) | `Constitution.md:6088` | **FAIL** | Unknown |
| §11.4.67 | Shell-script target-shell-parseability mandate (User mandate, 2026-05-19) | `Constitution.md:6184` | **FAIL** | Unknown |
| §11.4.68 | Positive sink-side / downstream evidence mandate (User mandate, 2026-05-20) | `Constitution.md:6347` | **FAIL** | Unknown |
| §11.4.69 | Universal Sink-Side Positive-Evidence Taxonomy + Mechanical Enforcement (User mandate, 2026-05-20) | `Constitution.md:6486` | **FAIL** | Yes |
| §11.4.70 | Subagent-Driven Execution Is The Default (User mandate, 2026-05-20) | `Constitution.md:6773` | — | Unknown |
| §11.4.71 | Pre-Push Fetch + Investigate + Integrate Mandate (User mandate, 2026-05-20) | `Constitution.md:6843` | **FAIL** | Unknown |
| §11.4.72 | Audio Top-Priority Mandate (User mandate, 2026-05-20) | `Constitution.md:6878` | — | Unknown |
| §11.4.73 | Main-specification document versioning + revision discipline (User mandate, 2026-05-20) | `Constitution.md:6896` | — | Unknown |
| §11.4.74 | Submodule-catalogue-first discovery + extend-don't-reimplement (User mandate, 2026-05-20) | `Constitution.md:6930` | — | Partial |
| §11.4.75 | Mechanical Enforcement Without Exception (User mandate, 2026-05-20) | `Constitution.md:6967` | **FAIL** | No |
| §11.4.76 | Containers-submodule mandate (User mandate, 2026-05-20) | `Constitution.md:7109` | — | Unknown |
| §11.4.77 | Regeneration-mechanism-required mandate (User mandate, 2026-05-20) | `Constitution.md:7142` | — | Partial |
| §11.4.78 | CodeGraph code-intelligence mandate (User mandate, 2026-05-20) | `Constitution.md:7194` | — | Partial |
| §11.4.79 | Own-org submodules MUST be included in the CodeGraph index (User mandate, 2026-05-21) | `Constitution.md:7242` | — | Unknown |
| §11.4.80 | CodeGraph regular-update + sync automation mandate (User mandate, 2026-05-21) | `Constitution.md:7284` | — | Unknown |
| §11.4.81 | Cross-platform-parity mandate (User mandate, 2026-05-21) | `Constitution.md:7327` | — | Unknown |
| §11.4.82 | Iteration-speedup discipline mandate (User mandate, 2026-05-22) | `Constitution.md:7368` | — | Unknown |
| §11.4.83 | docs/qa/ end-user evidence mandate (User mandate, 2026-05-22) | `Constitution.md:7433` | — | Unknown |
| §11.4.84 | Working-tree quiescence rule for subagent commits (User mandate, 2026-05-22) | `Constitution.md:7459` | — | Unknown |
| §11.4.85 | Stress + Chaos Test Mandate (User mandate, 2026-05-24) | `Constitution.md:7492` | — | Unknown |
| §11.4.86 | Roster/corpus-backed Status-doc auto-sync mandate (User mandate, 2026-05-25) | `Constitution.md:7549` | — | Unknown |
| §11.4.87 | Endless-loop autonomous work + zero-idle agent dispatch + anti-bluff testing mandate (User mandate, 2026-05-26) | `Constitution.md:7572` | **FAIL** | Unknown |
| §11.4.88 | Background-push mandate: commit-lock release immediately after commit, push runs detached (User mandate, 2026-05-26) | `Constitution.md:7610` | **FAIL** | Unknown |
| §11.4.89 | Background test execution mandate (User mandate, 2026-05-27) | `Constitution.md:7640` | **FAIL** | Unknown |
| §11.4.90 | Obsolete status + per-item obsolescence audit mandate (User mandate, 2026-05-27) | `Constitution.md:7674` | **FAIL** | Unknown |
| §11.4.91 | Summary-doc clarity mandate (User mandate, 2026-05-27) | `Constitution.md:7703` | — | Unknown |
| §11.4.92 | Multi-pass change-evaluation discipline (User mandate, 2026-05-27) | `Constitution.md:7742` | **FAIL** | Unknown |
| §11.4.93 | SQLite-backed single-source-of-truth for workable items (User mandate, 2026-05-27) | `Constitution.md:7778` | **FAIL** | No |
| §11.4.94 | Zero-idle priority-first parallel-by-default operating mode (User mandate, 2026-05-27) | `Constitution.md:7840` | **FAIL** | Unknown |
| §11.4.95 | Workable-items SQLite DB is TRACKED in git, NEVER gitignored (User mandate, 2026-05-27) | `Constitution.md:7883` | **FAIL** | No |
| §11.4.96 | Safe-parallel-work-with-long-build catalogue + mandate (User mandate, 2026-05-27) | `Constitution.md:7911` | **FAIL** | Unknown |
| §11.4.97 | Maximum-use-of-idle-time mandate + progress-update cadence (User mandate, 2026-05-27) | `Constitution.md:7965` | **FAIL** | Unknown |
| §11.4.98 | Full-Automation Anti-Bluff Mandate — Live tests MUST be re-runnable end-to-end without manual intervention (User mandate | `Constitution.md:8003` | **FAIL** | Unknown |
| §11.4.99 | Latest-Source Documentation Cross-Reference Mandate — instructions, guides, and manuals MUST be verified against the lat | `Constitution.md:8036` | **FAIL** | Unknown |
| §11.4.100 | RETIRED | `Constitution.md:8086` | — | Unknown |
| §11.4.101 | Autonomous-decision-over-blocking mandate (User mandate, 2026-05-28) | `Constitution.md:8090` | **FAIL** | Unknown |
| §11.4.102 | Mandatory systematic-debugging activation + always-loaded skill-discovery + plugin-dependency availability (User mandate | `Constitution.md:8123` | **FAIL** | Unknown |
| §11.4.103 | Continuous parallel-stream working routine (User mandate, 2026-05-29) | `Constitution.md:8153` | **FAIL** | Unknown |
| §11.4.104 | Participant identity, attribution & notification-tagging (User mandate, 2026-05-31) | `Constitution.md:8189` | **FAIL** | Unknown |
| §11.4.105 | Natural-language intent recognition & clarification (User mandate, 2026-05-31) | `Constitution.md:8232` | **FAIL** | Unknown |
| §11.4.106 | Docs Chain — mechanical documentation/DB sync engine (Operator mandate, 2026-05-31) | `Constitution.md:8279` | **FAIL** | Unknown |
| §11.4.107 | Anti-bluff AV/test-validation techniques mandate (User-driven research, 2026-06-02) | `Constitution.md:8315` | **FAIL** | Partial |
| §11.4.108 | Four-layer fix-verification + runtime-signature-as-definition-of-done mandate (systematic-debugging Phase 4.5, 2026-06-0 | `Constitution.md:8365` | **FAIL** | Unknown |
| §11.4.109 | Mandatory Anti-Forgetting Enforcement: PreToolUse Guard Hook + Subagent Constitutional Preamble + Orchestrator Pre-Actio | `Constitution.md:8399` | **FAIL** | No |
| §11.4.110 | Pre-build build-readiness verdict + change-impact clash detection mandate (operator mandate, 2026-06-03) | `Constitution.md:8485` | **FAIL** | Unknown |
| §11.4.111 | Resolve-by-stable-name-not-by-enumeration-index mandate (research-derived, 2026-06-03) | `Constitution.md:8519` | **FAIL** | Unknown |
| §11.4.112 | Structural-impossibility won't-fix classification mandate (research-derived, 2026-06-03) | `Constitution.md:8539` | **FAIL** | Unknown |
| §11.4.113 | Absolute no-force-push + merge-onto-latest-main mandate (User mandate, 2026-06-03) | `Constitution.md:8565` | **FAIL** | Unknown |
| §11.4.114 | Last-known-good-tag regression isolation mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8600` | **FAIL** | Unknown |
| §11.4.115 | RED-baseline-on-the-broken-artifact + polarity-switch mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8624` | **FAIL** | Unknown |
| §11.4.116 | Real-time conductor↔autonomous-test-framework sync channel mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8652` | **FAIL** | Unknown |
| §11.4.117 | Computer-vision / OCR pixel-oracle fallback for non-introspectable UIs mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8676` | **FAIL** | Unknown |
| §11.4.118 | Discovery-pressure to confirm known-issue-set completeness mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8700` | **FAIL** | Unknown |
| §11.4.119 | Single-resource-owner partitioning for parallel hardware testing mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8724` | **FAIL** | Unknown |
| §11.4.120 | Fix-breaks-its-own-gate reconciliation mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8748` | **FAIL** | Unknown |
| §11.4.121 | No-commit-while-build-writes-tracked-artifacts mandate (1.1.8-dev remediation, 2026-06-03) | `Constitution.md:8776` | **FAIL** | Unknown |
| §11.4.122 | No-silent-removal-of-existing-components-without-operator-confirmation mandate (User mandate, 2026-06-03) | `Constitution.md:8800` | **FAIL** | Unknown |
| §11.4.123 | Rock-solid-proof-or-deep-research mandate (User mandate, 2026-06-03) | `Constitution.md:8822` | **FAIL** | Unknown |
| §11.4.124 | Dead/unwired-code investigate-before-remove mandate (User mandate, 2026-06-04) | `Constitution.md:8844` | **FAIL** | Unknown |
| §11.4.125 | Code-review-agent gate before pre-build + main build (mandatory multi-layer review) (User mandate, 2026-06-04) | `Constitution.md:8870` | **FAIL** | Unknown |
| §11.4.126 | Default autonomous-loop working mode from first prompt (User mandate, 2026-06-04) | `Constitution.md:8896` | **FAIL** | Unknown |
| §11.4.127 | Session-handoff resumption-prompt mandate (User mandate, 2026-06-06) | `Constitution.md:8918` | **FAIL** | Unknown |
| §11.4.128 | Always-on device-recording mandate (User mandate, 2026-06-06) | `Constitution.md:8932` | **FAIL** | Unknown |
| §11.4.129 | Huge-blocker release protocol (User mandate, 2026-06-06) | `Constitution.md:8944` | **FAIL** | Unknown |
| §11.4.130 | Post-remediation validate-the-fix-FIRST-after-redeploy (User mandate, 2026-06-06) | `Constitution.md:8956` | **FAIL** | Unknown |
| §11.4.131 | Standing session-resumption file mandate (User mandate, 2026-06-07) | `Constitution.md:8972` | **FAIL** | Unknown |
| §11.4.132 | Risk-ordered validation priority mandate (User mandate, 2026-06-07) | `Constitution.md:8994` | **FAIL** | Unknown |
| §11.4.133 | Target-System + hardware safety mandate (User mandate, 2026-06-08) | `Constitution.md:9018` | **FAIL** | Unknown |
| §11.4.134 | Code-review iterate-until-GO + rock-solid-evidence mandate (User mandate, 2026-06-08) | `Constitution.md:9046` | **FAIL** | Unknown |
| §11.4.135 | Standing regression-guard suite + every-fixed-defect-gets-a-permanent-regression-test (User mandate, 2026-06-08) | `Constitution.md:9060` | **FAIL** | Unknown |
| §11.4.136 | Real-content end-to-end playback-test mandate (User mandate, 2026-06-08) | `Constitution.md:9073` | **FAIL** | Unknown |
| §11.4.137 | Subtitle/caption content-correctness oracle + secure-display-proxy-honesty mandate (User mandate, 2026-06-08) | `Constitution.md:9082` | **FAIL** | Unknown |
| §11.4.138 | Operator-escape => mandatory bluff-audit + permanent guard (User mandate, 2026-06-08) | `Constitution.md:9097` | **FAIL** | Unknown |
| §11.4.139 | Fresh-process clean-artifact runtime-signature mandate (User mandate, 2026-06-08) | `Constitution.md:9106` | **FAIL** | Unknown |
| §11.4.140 | Universal action-prefix system (`ACTION_NAME ::`) (User mandate, 2026-06-09) | `Constitution.md:9114` | **FAIL** | Yes |
| §11.4.141 | Token-efficiency mandate (research-derived + operator mandate, 2026-06-09) | `Constitution.md:9233` | **FAIL** | Yes |
| §11.4.142 | Universal code-review mandate — every change reviewed, always, no exception (User mandate, 2026-06-09) | `Constitution.md:9263` | **FAIL** | Partial |
| §11.4.143 | Real-user-journey mandate for video-streaming-app full-automation tests (User mandate, 2026-06-10) | `Constitution.md:9283` | **FAIL** | Unknown |
| §11.4.144 | Tracked/recorded-device availability-following mandate (User mandate, 2026-06-10) | `Constitution.md:9297` | **FAIL** | Unknown |
| §11.4.145 | Independent multi-angle impact-research per change (User mandate, 2026-06-10) | `Constitution.md:9311` | **FAIL** | Unknown |
| §11.4.146 | Reproduce-first test + same-test-confirms-fix + mandatory extend-to-all-cases workflow (User mandate, 2026-06-10) | `Constitution.md:9329` | **FAIL** | Unknown |
| §11.4.147 | Crashed-agent respawn-until-complete + no-work-loss registry mandate (User mandate, 2026-06-10) | `Constitution.md:9351` | **FAIL** | Unknown |
| §11.4.148 | Workable-item integrity (status+type+id) + comprehensive structured description + bidirectional external-tracker sync + | `Constitution.md:9373` | **FAIL** | Unknown |
| §11.4.149 | Per-workable-item testing-diary mandate (User mandate, 2026-06-10) | `Constitution.md:9395` | **FAIL** | Unknown |
| §11.4.150 | Mandatory deep multi-angle web research per change/issue, before declaring fixed or structural (User mandate, 2026-06-11 | `Constitution.md:9415` | **FAIL** | Unknown |
| §11.4.151 | Project-prefixed release-tag/version-naming mandate (User mandate, 2026-06-12) | `Constitution.md:9439` | **FAIL** | Unknown |
| §11.4.152 | Crashlytics-recorded-data continuous monitoring + systematic-debug + regression-test-coverage mandate (User mandate, 202 | `Constitution.md:9460` | **FAIL** | Unknown |
| §11.4.153 | Comprehensive per-feature Status + Status_Summary document set with mandatory video-recording confirmation (User mandate | `Constitution.md:9490` | **FAIL** | Unknown |
| §11.4.154 | Window-scoped capture + fresh-corpus rotation for feature/QA recordings (User mandate, 2026-06-15) | `Constitution.md:9516` | **FAIL** | Unknown |
| §11.4.155 | Project-name-prefixed feature/QA recording filenames (User mandate, 2026-06-15) | `Constitution.md:9528` | **FAIL** | Unknown |
| §11.4.156 | All CI/CD automation (GitHub Actions / GitLab pipelines / equivalents) MUST be disabled (User mandate, 2026-06-15) | `Constitution.md:9542` | **FAIL** *(as measured for this Phase-1 pass)* — **partially remediated 2026-08-27**, see the G4 update: `.github/workflows/ci.yml` → `ci.yml.disabled`, gates → local pre-push hook. `milosvasic.ru/.github/workflows/pages.yml` remains **ACTIVE** by operator decision (sole publish path for a production site) — a documented deviation, not an override. `vasic.digital` triggers provider-side Pages runs with no workflow file to disable. **Do not read this as PASS anywhere**: §11.4.156(B)'s test is *"a push triggers ZERO runs"*, two of three surfaces knowingly fail it, and the umbrella's remaining provider-side settings are unverified. | No |
| §11.4.157 | GEMINI.md maintained in lockstep with CLAUDE.md / AGENTS.md / QWEN.md (User mandate, 2026-06-15) | `Constitution.md:9558` | **FAIL** | No |
| §11.4.158 | Intensive all-feature/flow/edge-case video-recording + read-the-screen content-verification mandate (User mandate, 2026- | `Constitution.md:9574` | **FAIL** | Unknown |
| §11.4.159 | Mandatory window-specific video recording + vision validation mandate (User mandate, 2026-06-20) | `Constitution.md:9600` | **FAIL** | Unknown |
| §11.4.160 | Vision-verified recording + HelixQA bridge mandate (User mandate, 2026-06-21) | `Constitution.md:9649` | **FAIL** | Unknown |
| §11.4.161 | Rootless container runtime mandate (User mandate, 2026-06-21) | `Constitution.md:9671` | **FAIL** | Yes |
| §11.4.162 | OpenDesign UI design system mandate (User mandate, 2026-06-21) | `Constitution.md:9689` | **FAIL** | Partial |
| §11.4.163 | Universal Media Validation & Verification Mandate (User mandate, 2026-06-21) | `Constitution.md:9717` | **FAIL** | Unknown |
| §11.4.164 | Universal Constitution Auto-Propagation & Hook System (User mandate, 2026-06-21) | `Constitution.md:9741` | **FAIL** | No |
| §11.4.165 | Universal Independent Verification Agent Mandate (User mandate, 2026-06-21) | `Constitution.md:9769` | **FAIL** | Unknown |
| §11.4.166 | REPEALED (operator decision, 2026-06-22) | `Constitution.md:9793` | **FAIL** | Unknown |
| §11.4.167 | Big-work-item feature work-stream lifecycle (own copy-on-write project copy + own branch/tags + per-feature builds, no-m | `Constitution.md:9795` | **FAIL** | Unknown |
| §11.4.168 | Exported-document independent content + textual + full-visual validation mandate (User mandate, 2026-06-23) | `Constitution.md:9913` | **FAIL** | Yes |
| §11.4.169 | Mandatory comprehensive test-type coverage with anti-bluff captured evidence (User mandate, 2026-06-25) | `Constitution.md:9935` | **FAIL** | Partial |
| §11.4.140 | Mandatory HelixTranslate canonical translation pipeline (User mandate, 2026-06-25) | `Constitution.md:9969` | **FAIL** | Yes |
| §11.4.141 | Mandatory independent per-language translation review (User mandate, 2026-06-25) | `Constitution.md:9999` | **FAIL** | Yes |
| §11.4.170 | Device-independent host-side rendered-UI visual-proof mandate (User mandate, 2026-06-25) | `Constitution.md:10029` | **FAIL** | Yes |
| §12 | Host-session safety — directly OR indirectly signing the user out is FORBIDDEN | `Constitution.md:10033` | — | Unknown |
| §12.1 | Forbidden operations — directly OR indirectly | `Constitution.md:10039` | — | Unknown |
| §12.2 | Required safeguards | `Constitution.md:10060` | — | Unknown |
| §12.3 | Container hygiene | `Constitution.md:10074` | — | Unknown |
| §12.6 | Memory-Budget Ceiling — 60% MAXIMUM | `Constitution.md:10085` | — | Unknown |
| §12.10 | Continuation document — sacred invariant | `Constitution.md:10115` | — | No |
| §12.11 | Maximal dynamic resource utilization for containerized builds (User mandate, 2026-07-03) | `Constitution.md:10157` | — | Unknown |
| §12.12 | Process/thread-limit (RLIMIT_NPROC) awareness for parallel subagent/multi-process work (User mandate, 2026-07-07) | `Constitution.md:10177` | — | Unknown |
| §11.4.171 | Mandatory comprehensive human-readable workable-item descriptions (User mandate, 2026-06-29) | `Constitution.md:10241` | **FAIL** | Unknown |
| §11.4.172 | Mandatory production-readiness planning with realistic timeline projection (User mandate, 2026-06-29) | `Constitution.md:10243` | **FAIL** | Unknown |
| §11.4.173 | Containerized + distributed build mandate (User mandate, 2026-06-29) | `Constitution.md:10245` | **FAIL** | Unknown |
| §11.4.174 | Shared-host process-ownership verification mandate (User mandate, 2026-06-29) | `Constitution.md:10247` | **FAIL** | Unknown |
| §11.4.176 | Conflict-free multi-track work-division + exactly-once claim registry + capability-aware deadlock-proof device-lock (Use | `Constitution.md:10249` | **FAIL** | Unknown |
| §11.4.177 | Developer-tooling project-decoupling + invocation-directory operation (User mandate, 2026-07-04) | `Constitution.md:10251` | **FAIL** | Unknown |
| §11.4.178 | Track-qualified identity for parallel work streams (session-name collision ban) (User mandate, 2026-07-04) | `Constitution.md:10253` | **FAIL** | Unknown |
| §11.4.179 | Corruption-isolated parallel git streams (own-.git independent clones, not shared-common-dir worktrees) (User mandate, 2 | `Constitution.md:10255` | **FAIL** | Unknown |
| §11.4.180 | Commit/push (single-writer) wrappers MUST auto-reap provably-stale locks before acquiring (User mandate, 2026-07-04) | `Constitution.md:10257` | **FAIL** | Unknown |
| §11.4.181 | Consistent controlled feature-branch naming: one feature/logic-group ⇒ exactly ONE canonical branch name across the main | `Constitution.md:10259` | **FAIL** | Unknown |
| §11.4.182 | Track+branch work-stream identity label `(T<N>/<branch>)` on every agent/subagent/work-stream label and every operator-f | `Constitution.md:10261` | **FAIL** | Unknown |
| §11.4.183 | Maximal multi-agent utilization per work-stream + full-constitution-application + zero-bluff mandate (User mandate, 2026 | `Constitution.md:10263` | **FAIL** | Unknown |
| §11.4.184 | Mandatory SonarQube static-analysis CLI + local tooling installed and PATH-discoverable (User mandate, 2026-07-06) | `Constitution.md:10265` | **FAIL** | Unknown |
| §11.4.185 | Manual QA-team testing as the mandatory FINAL confirmation of done (User mandate, 2026-07-07) | `Constitution.md:10267` | **FAIL** | Unknown |
| §11.4.186 | Anti-divergence enforcement: cross-document consistency is a mandatory-before-export/commit gate, never an after-the-fac | `Constitution.md:10271` | **FAIL** | Unknown |
| §11.4.187 | Automatic multi-track ruler orchestration (User mandate, 2026-07-04; landed 2026-07-09) | `Constitution.md:10273` | **FAIL** | Unknown |
| §11.4.188 | Regular main→feature merge cadence: every track / feature-branch MUST FREQUENTLY merge canonical `main` into itself DURI | `Constitution.md:10275` | **FAIL** | Unknown |
| §11.4.189 | Most-reopened cases get extra-depth live-testing scrutiny FIRST (User mandate, 2026-07-10) | `Constitution.md:10277` | **FAIL** | Unknown |
| §11.4.190 | Website engineering-quality mandate: every project website MUST be fully responsive + completely SEO-optimized + uniquel | `Constitution.md:10279` | **FAIL** | Unknown |
| §11.4.191 | Work-to-track/branch binding enforcement: a logic-group's work can NEVER be committed OR dispatched onto the wrong track | `Constitution.md:10281` | **FAIL** | Unknown |
| §11.4.192 | Continuous multi-track auto-backfill: a FREE track MUST be IMMEDIATELY re-assigned its next-highest-priority domain work | `Constitution.md:10283` | **FAIL** | Unknown |
| §11.4.193 | Anti-blind-typing mandate: every UI interaction MUST be "seen" and "understood" via OCR/vision/screenshot proof, NEVER b | `Constitution.md:10303` | **FAIL** | Unknown |
| §11.4.194 | Exhaustive all-scenario, all-angle code-review + verify-against-captured-runtime-evidence mandate (User mandate, 2026-07 | `Constitution.md:10325` | **FAIL** | Unknown |
| §11.4.195 | Branch-structure governance: taxonomy + merge-after-live-QA + flavor/product non-merge (User mandate, 2026-07-14) | `Constitution.md:10353` | **FAIL** | Unknown |
| §11.4.196 | Native-alias-first priority + per-alias real-signal limit/subscription tracking + auto-rebind-on-recovery + resource-det | `Constitution.md:10388` | **FAIL** | Unknown |
| §11.4.197 | Research / kicked-off-work completion mandate: every research effort MUST be driven to full, wired, verified completion | `Constitution.md:10398` | **FAIL** | Unknown |
| §11.4.198 | Default working mechanisms: multi-alias native-first orchestration AND heavy token-optimization are ALWAYS-ON defaults f | `Constitution.md:10420` | **FAIL** | Unknown |
| §11.4.199 | Exact-reproduction-sequence mandate: when a working reproduction exists, the investigation MUST use ITS exact sequence — | `Constitution.md:10438` | **FAIL** | Unknown |
| §11.4.200 | Non-targetable deploy/flash tooling MUST isolate exactly ONE eligible target and VERIFY-AFTER-WRITE on the INTENDED targ | `Constitution.md:10458` | **FAIL** | Unknown |
| §11.4.201 | Every guard/gate MUST assert the REAL condition: a false-positive refusal is a FAIL-bluff, a false-negative pass is a PA | `Constitution.md:10478` | **FAIL** | Unknown |
| §11.4.202 | Reporting directives: a report MUST auto-create a fully-populated, fully-synced workable item — never a prose acknowledg | `Constitution.md:10518` | **FAIL** | Unknown |
| §11.4.207 | Instant multi-stream resume engine: whole-fleet continuation state is a durable, content-addressed, atomically-committed | `Constitution.md:10524` | **FAIL** | Unknown |
| §11.4.208 | Operator-request-history document: every project maintains a project-local, always-in-sync ledger of every operator requ | `Constitution.md:10532` | **FAIL** | Unknown |
| §11.4.209 | Code-review MUST run on the Fable model at xhigh effort (Opus xhigh fallback) (User mandate, 2026-07-15) | `Constitution.md:10544` | **FAIL** | Unknown |
| §11.4.210 | Zero-loss request/prompt intake: every operator request MUST be mechanically captured, tracked, and processed — never sk | `Constitution.md:10556` | **FAIL** | Unknown |
| §11.4.211 | Merge-conflict resolution during main→feature/product/flavor merges MUST run on the Fable model at xhigh effort (Opus xh | `Constitution.md:10572` | **FAIL** | Unknown |
| §11.4.212 | Main README is the canonical starting-point / entry point for ALL project documentation — no doc may be an orphan unreac | `Constitution.md:10584` | **FAIL** | No |
| §11.4.213 | FEATURE research-scheduling directive: recognized via all §11.4.140 forms, SCHEDULES (never synchronously executes) a de | `Constitution.md:10596` | **FAIL** | Unknown |
| §11.4.214 | Recurrence-links-not-mints: a defect that returns MUST reopen its existing item, never enter as a new id (research-deriv | `Constitution.md:10618` | **FAIL** | Unknown |
| §11.4.215 | A doc that BINDS work MUST live, tracked, in the repository where that work happens (research-derived, 2026-07-17) | `Constitution.md:10638` | **FAIL** | Unknown |
| §11.4.216 | Canonical machine-readable design-token source: one CSS custom-property file (`:root` + `[data-theme="dark"]`), generate | `Constitution.md:10652` | **FAIL** | Unknown |
| §11.4.217 | OpenDesign brand contract: every UI-shipping product carries a 9-section DESIGN.md + tokens.css twin with disjoint color | `Constitution.md:10666` | **FAIL** | Unknown |
| §11.4.218 | Living design-library catalogue: every component × state × theme rendered self-contained + a cross-platform reusability | `Constitution.md:10680` | **FAIL** | Unknown |
| §11.4.219 | Per-app screen catalogues: full-IA coverage per surface, per-platform chrome variants, honesty markers for unbuilt behav | `Constitution.md:10694` | **FAIL** | Unknown |
| §11.4.220 | Open-first design tooling: self-hosted open platforms are primary; proprietary tools are import/export targets only; des | `Constitution.md:10708` | **FAIL** | Unknown |
| §11.4.221 | Motion discipline: token-bound durations/easings + machine-readable manifest + reduced-motion static fallbacks everywher | `Constitution.md:10722` | **FAIL** | Unknown |
| §11.4.222 | Design-completion export wave: a design is not done until token codegen, the honest-output raster matrix, both-theme ren | `Constitution.md:10736` | **FAIL** | Unknown |
| §11.4.223 | Provenance-marker discipline for design documentation + central open-item registry in the area index (User mandate, 2026 | `Constitution.md:10750` | **FAIL** | Unknown |
| §11.4.224 | Test-first (TDD) for ALL work, not only fixes + a minimum code-coverage floor that is NECESSARY-never-sufficient (User m | `Constitution.md:10764` | **FAIL** | Unknown |
| §11.4.225 | Scheduler-quota burst-throttling telemetry + interactive-scope isolation from bursty fleets: progressive interactive deg | `Constitution.md:10790` | **FAIL** | Unknown |
| §11.4.226 | Evidence-class-at-closure + standing detection pressure: machinery presence does NOT predict whether a fix holds — the E | `Constitution.md:10808` | **FAIL** | Unknown |
| §11.4.227 | Governance-corpus self-custody: the rule corpus is bound by the same custody it imposes — every named gate is implemente | `Constitution.md:10838` | **FAIL** | Unknown |
| §11.4.228 | Cross-agent extension lifecycle mandate: per-platform compatibility declaration, source tracking, per-extension document | `Constitution.md:10860` | **FAIL** | Unknown |
| §11.4.229 | Live in-session task/todo tracker MUST always be up to date and fully in sync with the real work state — never stale, ne | `Constitution.md:10907` | **FAIL** | Unknown |
| §11.4.230 | Parallelized-pipeline methodology: build↔validate overlap + affected-stages-only re-run + parallel multi-device testing/ | `Constitution.md:10927` | **FAIL** | Unknown |
| §11.4.231 | Nano-precision model-tier selection: lightest-capable-model-first with dynamic mid-task escalation (User mandate, 2026-0 | `Constitution.md:10944` | **FAIL** | Unknown |
| §11.4.232 | Anti-mess long-op orchestration: every long-op is registered, single-owned-per-purpose, liveness-PROVEN, handed-off-on-s | `Constitution.md:10967` | **FAIL** | Unknown |
| §11.4.233 | Standing anti-mess control plane: a level-triggered, idempotent, invariant-catalogue reconciliation loop over the WHOLE | `Constitution.md:10994` | **FAIL** | Unknown |
| §11.4.234 | Dedicated hook-validation script: hook checks run as an explicit stage of a dedicated commit/push script, and the commit | `Constitution.md:11017` | **FAIL** | Unknown |
| §11.4.235 | Build-and-deploy the moment source fixes are proven-correct (test-side hardening is a parallel stage, never a build gate | `Constitution.md:11035` | **FAIL** | Unknown |
| §11.4.236 | QA-deploy-readiness gate: no manual-QA hand-off until the mandated validation produced a candidate-fingerprinted PASS ve | `Constitution.md:11049` | **FAIL** | Unknown |
| §11.4.237 | Mandatory exhaustive context-and-spirit-aware translation review: every localized artifact independently reviewed for CO | `Constitution.md:11055` | **FAIL** | Partial |
| §11.4.238 | Automated QA must be the DISCOVERER: manual QA finds nothing new, and anything it finds is a coverage escape (User manda | `Constitution.md:11077` | **FAIL** | Unknown |

### 9.1 Verdict rollup

Counted mechanically over the table above.

| Substance verdict | Count |
|---|---|
| Yes | 10 |
| Partial | 14 |
| No | 26 |
| Unknown — needs verification | 211 |
| **Total anchor rows** | **261** |

| Propagation-gate verdict | Rows |
|---|---|
| **FAIL** — gate declared, cannot pass (175 distinct gates over 177 rows) | 177 |
| No gate declared | 84 |
| **Total anchor rows** | **261** |

---

## 10. Unverified items

Each of these is honestly **unverified**; the action that would settle it is
given.

| Item | Why unverified | What would verify it |
|---|---|---|
| 196 anchors marked `Unknown` in [§9](#9-full-mandatory-rule-table) | Checking each requires running the project's own gates, which do not exist (G3), or domain-specific runtime evidence | Build `scripts/verify-all-constitution-rules.sh` per §11.4.32 and run it; that script *is* the mechanism the constitution specifies for answering this question |
| Whether the umbrella is intended to be multi-provider (§2.1) | `git remote -v` shows one provider; `upstreams/` holds only `GitHub.sh`. §2.1 binds "Every project hosted on multiple Git providers" | Operator statement, or running `submodules/constitution/install_upstreams.sh` semantics against the umbrella's intended mirror set |
| Whether the constitution submodule pointer is current | Comparing to upstream requires `git fetch`, which this pass was forbidden to run | `git -C submodules/constitution fetch --all && git -C submodules/constitution log --oneline HEAD..origin/main` |
| Whether `.codegraph/codegraph.db` indexes own-org submodules (§11.4.79) | The DB was not opened | `sqlite3 .codegraph/codegraph.db` and inspect indexed paths for submodule prefixes |
| Whether releases exist on remote providers | Requires network | `gh release list` / `glab release list` — the prior audit at `_analysis/constitution-compliance.md` flagged the same item as "UNVERIFIED (offline)" |
| Whether `submodules/superspec` is genuinely third-party | Inferred from its upstream `git@github.com:WangX0111/superspec.git` being outside every operator-listed org in §11.4.28 | Operator confirmation, or `gh org list` per §11.4.28's own discovery instruction |
| §3 commit-ordering compliance (submodule-first) | Requires reflog archaeology across seven repos | `git -C <sub> reflog` cross-referenced against parent commit timestamps |
| Whether `ai_interviewing` / `monetization` are in-scope for §11.4.28(A) equal-codebase work | Both are near-empty (`monetization/` holds `docs`, `README.md`, `repos.txt`, `upstreams`) | Operator scoping decision |

---

## Appendix — commands used to produce this document

All read-only. Reproducible from a clean checkout.

```bash
# Inventory
ls -a; cat .gitmodules; git ls-files -s | awk '$1==160000'; git submodule status
ls -la submodules/constitution submodules/constitution/submodules

# Rule corpus
grep -n '^## \|^### ' submodules/constitution/Constitution.md
grep -o 'CM-COVENANT-114-[0-9]*-PROPAGATION' submodules/constitution/Constitution.md | sort -u | wc -l
grep -o '\bMUST\b' submodules/constitution/Constitution.md | wc -l
grep -o '\bSHOULD\b' submodules/constitution/Constitution.md | wc -l

# Governance-layer presence
for f in CLAUDE.md AGENTS.md QWEN.md GEMINI.md Constitution.md CONTINUATION.md helix-deps.yaml; do
  [ -e "$f" ] && echo "PRESENT $f" || echo "ABSENT  $f"; done
git grep -n -e '@constitution/CLAUDE.md' -e 'INHERITED FROM constitution'
find . -maxdepth 3 -name .git -prune -o -type f \
  \( -iname 'AGENTS.md' -o -iname 'CLAUDE.md' -o -iname 'QWEN.md' \
     -o -iname 'GEMINI.md' -o -iname '.cursorrules' -o -iname 'Constitution.md' \) -print

# Enforcement-layer presence
ls scripts/; ls .git/hooks/ | grep -v sample; cat .claude/settings.local.json

# Export + entrypoint gaps
git ls-files '*.md' | grep -vE '^(submodules/|milosvasic\.ru/|vasic\.digital/|design-toolkit/|ai_interviewing/|monetization/|_content)' | wc -l
grep -oE '\]\([^)]+\)' README.md

# Tag mirroring
git tag; for s in milosvasic.ru vasic.digital design-toolkit ai_interviewing monetization submodules/constitution; do
  echo "$s $(git -C $s tag -l v1.8.0)"; done
```
