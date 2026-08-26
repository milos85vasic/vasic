# Constitution Propagation — RISKS

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
| Status | active |
| Status summary | Blast-radius, exclusion and honesty register for the propagation prepared in [`APPLY.md`](APPLY.md). Nothing has been applied. Every number below comes from a read-only command whose output is quoted. **Revision 2 (2026-08-27)** adds §0: the Revision-1 staging was defective and would have regressed the constitution gates; it has been rewritten and the fix measured in [`PROOF.md`](PROOF.md). |
| Continuation | Operator reads this — §0 first — before executing `APPLY.md` §4. |

## 0. Revision 1 of this staging was defective — recorded, not quietly fixed

**The Revision-1 files in this directory would have made the constitution
gates strictly worse if applied.** This is recorded here rather than silently
corrected, because an operator who read Revision 1's `APPLY.md` and acted on it
would have been worse off for it.

### 0.1 The defect

Every `CM-COVENANT-114-*-PROPAGATION` gate sources one predicate,
`submodules/constitution/scripts/gates/lib/pointer_carrier.sh`. It recognises a
§11.4.35 pointer consumer — a carrier allowed to omit the anchor literals —
**iff** the file contains a **line-anchored, non-fenced `## INHERITED FROM `
heading at column zero**:

```awk
!fenced && /^## INHERITED FROM / { found = 1; exit }
```

The Revision-1 drafts opened with a `>` blockquote (`AGENTS.md`, `QWEN.md`,
`GEMINI.md`, `QWEN.insert-block.md`) or with `# CLAUDE.md — <module>` followed
by `## Helix Constitution inheritance` (`CLAUDE.md`). None of those matches.
None of the drafts carried a single one of the 17 anchor literals either. So
every applied file would have registered as a **new anchor-less carrier** and
**added** 17 `MISSING` verdicts of its own.

### 0.2 What it would have cost, measured

Run in temp directories mirroring the real fleet, with the 17 real gates
([`PROOF.md`](PROOF.md) has the full output):

| Scenario | MISSING carriers | MISSING lines | 17 gates |
|---|---|---|---|
| live repository today | 5 | 85 | all FAIL |
| `APPLY.md` §4.6 with the **Revision-1** files | **8** | **136** | all FAIL, louder |
| `APPLY.md` §4.2 – §4.6 with the **Revision-1** files | **24** | **408** | all FAIL, louder |
| `APPLY.md` §4.6 with the **Revision-2** files | **4** | **68** | all FAIL (third-party only) |
| `APPLY.md` §4.2 – §4.6 with the **Revision-2** files | **4** | **68** | all FAIL (third-party only) |

The 136 / 8 row reproduces [`GATE-TRIAGE.md`](../GATE-TRIAGE.md) §6.1's
prediction exactly. It was correct.

### 0.3 What was changed in Revision 2

- All 19 `*.md.staged` carriers were rewritten. Each now opens with its H1
  title and, immediately under it, the canonical **`## INHERITED FROM
  constitution/<BASE>`** heading — the form the constitution's own examples use
  and the form the four repository-root carriers that pass all 17 gates use.
- `vasic.digital/QWEN.insert-block.md` was replaced by a block that starts with
  that heading, so the file it is inserted into becomes a pointer carrier and
  **leaves** the MISSING set. All 55 existing lines of
  `vasic.digital/QWEN.md` are preserved — verified by a zero-deletion diff on
  the produced file.
- The substance the previous author argued for correctly is kept: the
  inheritance is stated **conditionally** (consumed-inside-a-project vs.
  consumed-standalone), the constitution is located with
  `find_constitution.sh` rather than a path, and **no** depth-dependent or
  parent-project path is hardcoded — the heading's `constitution/<BASE>` is
  stated in the carrier itself to be the base file's canonical *name*, resolved
  by the helper, not a filesystem path. §11.4.28(B) is intact; `APPLY.md` §5's
  own grep for `submodules/constitution` finds nothing in any carrier.
- `APPLY.md` §1's tree listing now shows the `.staged` suffixes, and its §4
  `cp` commands now copy **from** `<name>.md.staged` (Revision 1's commands
  copied from a source filename that does not exist).
- `APPLY.md` §4.6 no longer instructs copying anchor-less carriers, carries the
  corrected insertion line numbers (the block grew from 17 to 48 lines, so the
  original body now resumes at line 51, not 20), and ends with a
  `is_pointer_carrier` check on all four produced files.
- `APPLY.md` §5 gained two checks — the per-file predicate check and a
  fleet-level MISSING-count check — precisely because their absence is what
  let Revision 1 ship.

### 0.4 What Revision 2 does **not** claim

It does not make the 17 gates pass. Four category-(c) third-party carriers
([`GATE-TRIAGE.md`](../GATE-TRIAGE.md) §3.1, §7) hold every one of them FAILing
and nothing in this directory can clear them. The claim is narrower and
measured: the propagation stops adding failures and removes one
(`vasic.digital/QWEN.md`) — 85 MISSING lines → 68, five MISSING carriers →
four.

## 1. What was and was not done while preparing this

**Not run, anywhere:** `git add`, `git commit`, `git push`, `git fetch`,
`git pull`, `git checkout`, `git submodule update`, `git tag`, `git remote add`,
`git config`. No file inside any submodule working tree was created, modified,
or deleted. The only writes are the files in this directory
(`docs/constitution-adoption/propagation/`), all of them in the umbrella repo:
22 at Revision 1, and at Revision 2 the same 20 staged artifacts rewritten in
place plus `PROOF.md` added — 23 files.

**Also run for Revision 2 (all read-only):** the 17
`cm_covenant_114_*_propagation.sh` gates against the live repository root and
against five temp directories under the session scratchpad, plus
`lib/pointer_carrier.sh --selftest` and direct `is_pointer_carrier` calls. No
gate script, no library, and no submodule file was modified to produce those
runs.

**Observed, not caused — a concurrent auto-commit swept the rewritten drafts.**
This repository has an automated commit loop (`git log --oneline` shows a run
of `Auto-commit` entries). At 2026-08-26T23:11:47Z, while Revision 2 was being
prepared, a commit made outside this task
(`f5626d6 Fix 3 refuted claims from independent audit …`) captured all 20
rewritten `*.staged` artifacts in this directory into git history. The Revision-2
work itself ran no `git add`, `git commit`, or `git push`; the files' content on
disk and in `HEAD` is identical, so nothing was half-captured. It is recorded
here because a reader comparing `git log` against this document's "no mutating
git command was run" statement would otherwise see a contradiction — and because
it is the §11.4.84 working-tree-quiescence hazard in its live form: an
unrelated commit absorbed in-flight edits it did not describe.

**Run:** `git -C <sub> ls-files`, `ls-files -s`, `remote -v`,
`remote get-url --push --all`, `rev-parse`, `describe`, `status --porcelain`,
`symbolic-ref -q`, `check-ignore -v`, `submodule status`, plus `cat` / `head` /
`awk` / `grep` / `wc` on tracked files.

## 2. Push fan-out per repository

Measured with `git -C <repo> remote get-url --push --all origin` and
`git -C <repo> remote -v`. "Distinct URLs" counts unique destinations, since
`ai_interviewing` and `vasic.digital` configure three remote *names* that all
resolve to one URL.

| Repository | Remote names | `git push origin` push URLs | Distinct destinations | Providers |
|---|---|---|---|---|
| `ai_interviewing` | `github`, `origin`, `upstream` | `git@github.com:milos85vasic/ai_interviewing.git` | **1** | GitHub |
| `design-toolkit` | `origin` | `git@github.com:vasic-digital/design-toolkit.git` | **1** | GitHub |
| `milosvasic.ru` | `gitflic`, `github`, `origin`, `upstream` | `git@gitflic.ru:milosvasic/milosvasic-net-v-2.git`<br>`git@github.com:milos85vasic/milosvasic.net.v2.git` | **2** | GitFlic, GitHub |
| `monetization` | `gitflic`, `github`, `gitlab`, `gitverse`, `origin`, `upstream` | `git@gitflic.ru:milosvasic/monetization.git`<br>`git@github.com:milos85vasic/monetization.git`<br>`git@gitlab.com:milos85vasic/monetization.git`<br>`ssh://git@gitverse.ru:2222/milosvasic/monetization.git` | **4** | GitFlic, GitHub, GitLab, GitVerse |
| `vasic.digital` | `github`, `origin`, `upstream` | `git@github.com:vasic-digital/vasic-digital.github.io.git` | **1** | GitHub (Pages) |
| umbrella `vasic` | `github`, `origin`, `upstream` | `git@github.com:milos85vasic/vasic.git` | **1** | GitHub |
| **Total if APPLY.md §4 is fully executed** | — | — | **10** | 4 providers |
| `submodules/constitution` — **NOT touched** | `gitflic`, `github`, `gitlab`, `gitverse`, `origin`, `upstream`, `vasic_digital_github`, `vasic_digital_gitlab` | `git@gitflic.ru:helixdevelopment/helixconstitution.git`<br>`git@github.com:HelixDevelopment/HelixConstitution.git`<br>`git@gitlab.com:helixdevelopment1/helixconstitution.git`<br>`git@gitverse.ru:helixdevelopment/HelixConstitution.git`<br>`git@github.com:vasic-digital/HelixConstitution.git`<br>`git@gitlab.com:vasic-digital/HelixConstitution.git` | **6** | GitFlic, GitHub ×2 orgs, GitLab ×2 orgs, GitVerse |
| `submodules/superspec` — **NOT touched** | `origin` | `git@github.com:WangX0111/superspec.git` | **1** | GitHub (third-party) |

**Single loudest number: `monetization`.** One `git push` writes to four
providers. That repository currently tracks **8 files**
(`git -C monetization ls-files | wc -l` → `8`); the four carriers are a 50 %
increase in its content, published to GitFlic, GitHub, GitLab and GitVerse
simultaneously. If any of the four is unreachable or credential-stale, the push
partially succeeds — git pushes each URL in turn — leaving the mirrors
divergent. Nothing in this preparation detects or repairs that.

**`design-toolkit` has two parents.** `git submodule status` shows it as an
umbrella gitlink at `16e4e76d57ab61b5f3b46fae3372b2e6d6cc73e3`, and
`git -C submodules/constitution/submodules/design-toolkit rev-parse HEAD`
returns the identical SHA of the identical upstream. Committing to
`design-toolkit` makes the **constitution's** recorded gitlink stale. Restoring
that consistency requires a commit inside `submodules/constitution`, which fans
out to the **6 URLs** in the row above — including two `vasic-digital` mirrors
of a repository owned by `HelixDevelopment`. That step is deliberately **not
prepared and not recommended blind**; it turns a 10-URL change into a 16-URL
change and publishes into the shared constitution repository.

### 2.1 `milosvasic.ru` — fetch/push URL asymmetry

This one is easy to get wrong and worth reading twice.

```
$ git -C milosvasic.ru remote get-url origin
git@github.com:milos85vasic/milosvasic.ru.git

$ git -C milosvasic.ru remote get-url --push --all origin
git@gitflic.ru:milosvasic/milosvasic-net-v-2.git
git@github.com:milos85vasic/milosvasic.net.v2.git
```

`.gitmodules` declares this submodule's URL as
`git@github.com:milos85vasic/milosvasic.ru.git` — and **no configured push URL
writes to it**. A `git push origin main` publishes to
`milosvasic-net-v-2` (GitFlic) and `milosvasic.net.v2` (GitHub) instead. Whether
those three are mirrors of one repository under different names, or genuinely
different repositories, **could not be verified offline** (§6). If they are not
mirrors, the commit lands where the umbrella is not looking, and the next
`git submodule update` on a fresh clone will not find the new commit.

The same shape, less severely, exists for `monetization` and
`submodules/constitution`, whose `origin` fetch URL is a GitHub URL while their
`origin` push URL list starts with GitFlic. There the GitHub URL *is* included
among the push URLs, so the asymmetry is benign.

## 3. Third-party exclusion — `submodules/superspec`

**Nothing is prepared for it, and nothing may be written into it.**

Evidence, in order of strength:

1. **Upstream ownership.** `.gitmodules` maps it to
   `git@github.com:WangX0111/superspec.git`; `git -C submodules/superspec remote -v`
   confirms `origin` is that URL and is the *only* remote. `WangX0111` is not
   `milos85vasic`, not `vasic-digital`, and not `HelixDevelopment` — the three
   orgs every other gitlink in `.gitmodules` belongs to. It is an external
   maintainer's repository.
2. **The constitution's own rule scopes propagation to owned submodules.**
   §11.4.28 is titled for owned submodules and §11.4.28(B) governs "Owned
   submodules"; the umbrella-side `Constitution.project.md.template` provides a
   `## Owned-submodule set` section and closes it with the literal line
   "Third-party submodules excluded."
3. **§11.4.65 excludes third-party trees explicitly.** `Constitution.md:5995`
   heads the exclusion list "EXCLUDED (NOT subject to §11.4.65 — these are
   application/service source code or **third-party trees we do not own**)",
   listing "Any third-party submodule NOT in the owned-submodule set".
4. **INVENTORY.md already ruled on it.** §7.3's target table ends
   "`submodules/superspec` | **none** — third-party, excluded per §4", and §10
   of its unverified table records the same conclusion with the same basis.
5. **Practical harm.** Writing carriers into it would mean either committing to
   a repository the operator does not control — a push that would be rejected,
   or worse, accepted into a fork the umbrella then diverges from — or carrying
   a permanently dirty working tree that breaks `git submodule status` cleanliness
   for everyone.

Note it already contains two files matching an agent-carrier name —
`examples/static-landing-page/CLAUDE.md` and
`examples/static-landing-page/.specify/memory/constitution.md`. Both are
**vendored example fixtures inside the third-party tree**, not carriers of this
project (INVENTORY.md §6.2 classifies them the same way). They are not to be
edited, counted, or propagated to.

The only residual claim that is inference rather than fact is that `WangX0111`
is external to the operator — see §6.

## 4. Risks of the change itself

| # | Risk | Why it exists | Mitigation in `APPLY.md` |
|---|---|---|---|
| R1 | A carrier hardcodes the umbrella layout (`submodules/constitution/…`) and thereby violates §11.4.28(B)'s "No project-specific context, hardcoded paths" | The constitution's own templates and README all say `constitution/…`, and the umbrella's real path is `submodules/constitution/…`; the naive fix is to path-correct, which is exactly the violation | The conditional form names the base file and `find_constitution.sh`, never a parent-relative path. `APPLY.md` §5 check 2 greps for `submodules/constitution` in every carrier and reports a hit as a violation. |
| R2 | An `@constitution/CLAUDE.md` import silently resolves to nothing | Claude Code resolves `@` imports relative to the importing file, so inside a submodule it points at `<sub>/constitution/CLAUDE.md`, which never exists | The prepared `CLAUDE.md` carries no `@` import at all. `APPLY.md` §5 check 2 greps for a leading `@constitution/`. |
| R3 | The pointer asserts inheritance that is false for a standalone clone | A cloned-alone submodule has no constitution anywhere; an unconditional "these rules apply" sentence would be a bluff in the §11.4 sense | Both sentences are conditional ("when this module is consumed inside a project that includes …" / "When this module is consumed standalone … only the module-local notes below apply") — the reference implementation's exact wording. |
| R4 | Existing content in `vasic.digital/QWEN.md` is destroyed | The temptation is to overwrite with a clean template | No replacement file is provided for it. `APPLY.md` §4.6 ships an insert-block plus a `diff` gate that must print nothing before the swap, and a post-apply zero-deletion diff. |
| R5 | Parent gitlinks captured before submodule pushes land | §3 (`Constitution.md:213`): "Skipping step 1 produces parent commits / tags that point at old submodule HEADs without the actual source." | `APPLY.md` §4.1 states the ordering; §4.7 is explicitly last. |
| R6 | Partial multi-URL push leaves mirrors divergent | `monetization` (4 URLs) and `milosvasic.ru` (2 URLs) push to several hosts in one command; one failing host does not roll back the others | **Not mitigated.** The operator must re-check each provider after the push. No verification of remote state is possible offline. |
| R7 | The new files are born §11.4.65-non-compliant | §11.4.65 requires `.html` + `.pdf` siblings for every included `.md`, and `Constitution.md:5989` INCLUDES owned-submodule top-level `README.md` / `CLAUDE.md` / `AGENTS.md`; protection 1 is "A missing export is a §11.4.65 violation regardless of when the markdown was last touched" | **Not mitigated** — no export tooling exists in this repo. `APPLY.md` §6 discloses it. The same deviation applies to `APPLY.md`, this file, and the 19 prepared carriers plus the insert block, exactly as INVENTORY.md §1 disclosed for itself. |
| R8 | The pointers are unenforced decoration | The gates that would check them (`scripts/verify-governance-cascade.sh`, `scripts/verify-all-constitution-rules.sh`, `tests/test_constitution_inheritance.sh`) do not exist — INVENTORY.md G3/G5. §11.4.32 (`Constitution.md:2079-2082`): "Without it, new rules cascade as anchors but never get enforced in the codebase." | **Not mitigated by design** — this task prepares propagation only. `APPLY.md` §6 states it. |
| R9 | Submodule carriers alone do not close G1/G2 | The 175 `CM-COVENANT-114-N-PROPAGATION` gates check `CLAUDE.md` / `AGENTS.md` "across the project" (§11.4.35 invariant 5), and the umbrella root still has none (INVENTORY.md §6.1, §6.4) | `APPLY.md` §6 states it. The umbrella-root carriers of INVENTORY.md §7.1 are a separate change. |
| R10 | `vasic.digital` is a GitHub **Pages** repository — a push redeploys the live site | Four new root-level `.md` files land in a published static site | Flagged in `APPLY.md` §4.6. Whether Jekyll ignores or publishes them is **unverified** (§6). |
| R12 | A staged carrier does not satisfy `is_pointer_carrier()` and therefore *adds* 17 MISSING verdicts instead of clearing any | This is not hypothetical: it is exactly what Revision 1 of this directory did (§0). A carrier that looks like a pointer to a human — a blockquote, a differently-worded H2 — is invisible to the predicate, which matches only a line-anchored, non-fenced `## INHERITED FROM ` heading at column zero | **Mitigated and measured.** Every carrier now opens with that heading; `APPLY.md` §5 check 5 runs the real predicate over every applied file, and check 6 re-runs all 17 gates and prints the fleet MISSING count. [`PROOF.md`](PROOF.md) records the before/after with a control run on the uncorrected files. |
| R11 | `vasic.digital` has a commit wrapper and the constitution forbids bypassing it | `AGENTS.project.md.template`: "**Use the project's commit wrapper.** No direct `git add` / `git commit` / `git push` on main repo." The tracked script `vasic.digital/commit` exists. | `APPLY.md` §4.6 gives the wrapper form first and the plain-git form as a labelled fallback, and states the wrapper's internals were not executed or line-read. |

## 5. Honesty flags in the prepared text

- **`ai_interviewing` and the decoupling sentence.** The reference CLAUDE.md
  form ends "This module stays fully decoupled and reusable per the Helix
  Constitution's §11.4.28 … **No project-specific context is injected here.**"
  Reproduced verbatim into `ai_interviewing`, that last sentence is contradicted
  by that module's own `README.md`, which opens "**Interview-preparation corpus
  and employer due-diligence** for the CauseMatch *Senior Full-Stack Engineer,
  Agent-Native Development* position — built for the candidate at
  [milosvasic.ru](https://milosvasic.ru) (Miloš Vasić)". Naming a specific
  employer and a specific consuming site is precisely the "project-specific
  context" §11.4.28(B) forbids. Revision 1 kept the sentence for exact
  fidelity to the reference form and left the operator to accept or delete it.
  **Revision 2 removed it**, replacing it with a claim about the carrier
  itself, which is verifiable and was verified: *"This file therefore hardcodes
  no parent-project path and no depth-dependent path, keeping the module
  project-not-aware, decoupled and reusable per §11.4.28(B)."* That is a
  statement about the file the operator is committing — checked by `APPLY.md`
  §5 check 2, which greps every carrier for the umbrella layout string and
  finds none in any of the 20. No carrier now asserts anything about the
  *module's* content, which this pass did not audit (§6). Whether
  `ai_interviewing`'s README is itself §11.4.28(B)-compliant remains an open,
  separate remediation item — it is simply no longer pre-judged by a sentence
  in the carrier.
- **INVENTORY.md §6.2/§7.3 needs a correction.** It presents
  `milosvasic.ru/Upstreamable/{AGENTS,CLAUDE}.md` as `milosvasic.ru`'s files.
  They are tracked by a **different repository**, `red-elf/Upstreamable`
  (`milosvasic.ru/.gitmodules`, gitlink `94f9831b8aa0a1d4df23671d2e4600886aad0dcf`).
  `milosvasic.ru` itself tracks **zero** agent-instruction files. The reference
  *form* is still valid and is what this propagation reproduces; only the
  attribution is wrong. `APPLY.md` §2.1 records this. This file does not modify
  INVENTORY.md.
- **Four carriers, not two, and not five.** The reference implementation ships
  `AGENTS.md` + `CLAUDE.md` only. This propagation prepares four, adding
  `QWEN.md` and `GEMINI.md` per §11.4.157 and INVENTORY.md §7.3. The fifth
  carrier (`Constitution.md`) is deliberately **not** prepared: whether a
  project-unaware owned submodule must carry its own `Constitution.md` is
  **not specified** in `submodules/constitution/templates/`, in README "How to
  consume", or in §11.4.28. The only Constitution template that ships is a
  *project* scaffold requiring `## Owned-submodule set` and
  `## Project-specific remotes`.
- **`QWEN.md` and `GEMINI.md` forms are derived, not quoted.**
  `submodules/constitution/templates/` contains exactly three files —
  `AGENTS.project.md.template`, `CLAUDE.project.md.template`,
  `Constitution.project.md.template`. There is **no** `QWEN.project.md.template`
  and **no** `GEMINI.project.md.template` (INVENTORY.md records this as gap
  G7b). The QWEN form is the README's own instruction ("Same for `AGENTS.md` …
  and (since 2026-05-20) `QWEN.md` for Qwen Code:" + the blockquote) applied to
  the conditional wording. The GEMINI form is derived from §11.4.157's
  first-class-carrier mandate; `submodules/constitution/GEMINI.md` does prescribe
  a consumer pointer, but as an unconditional `## INHERITED FROM
  constitution/GEMINI.md` heading and with **SHOULD**, not MUST ("the project's
  repo-root carrier SHOULD start with a clearly-marked inheritance pointer") —
  and its unconditional wording is unusable in a project-unaware module. Where
  the constitution specifies nothing, this document says "not specified" rather
  than inventing a convention.

## 6. Not verified

Each item states what would settle it. None of these was guessed at above.

| Item | Why unverified | What would verify it |
|---|---|---|
| Whether `milosvasic.ru`'s three URLs (`milosvasic.ru` on GitHub, `milosvasic.net.v2` on GitHub, `milosvasic-net-v-2` on GitFlic) are mirrors of one repository | Requires network access; `git fetch` / `ls-remote` was forbidden | `git -C milosvasic.ru ls-remote git@github.com:milos85vasic/milosvasic.ru.git` compared against the two push URLs, or an operator statement |
| Whether each push URL is reachable and the credentials current | No network operation was run | `git -C <sub> ls-remote <url>` per URL, before committing anything |
| Whether the four new root `.md` files would be published by `vasic.digital`'s GitHub Pages build | Requires reading and reasoning about the site's build configuration, and ultimately a deploy | Inspect `vasic.digital` for `_config.yml` / `.nojekyll` and its exclude list; or push to a branch and preview |
| What `vasic.digital/commit` actually does (stages all? pushes? which remotes?) | The script was not executed and was not read line-by-line | `cat vasic.digital/commit` and dry-run it in a scratch clone |
| Whether `WangX0111` is genuinely external to the operator | Inferred from the org not matching any of `milos85vasic` / `vasic-digital` / `HelixDevelopment` | Operator confirmation, or `gh repo view WangX0111/superspec` |
| Whether the five submodules' *content* is otherwise §11.4.28(B)-compliant (beyond the `ai_interviewing` README flagged in §5) | This pass surveyed carriers and remotes, not the 3,156 tracked files across the five modules for project-coupling | A §11.4.28(B) audit per module — out of scope here |
| Whether the constitution submodule pointer is current relative to its upstream | `git fetch` was forbidden | `git -C submodules/constitution fetch --all && git -C submodules/constitution log --oneline HEAD..origin/main` (INVENTORY.md §10 records the same item) |
| ~~Whether applying this would make any existing gate pass~~ — **verified 2026-08-27; the answer is no** | Superseded: `scripts/verify-all-constitution-rules.sh` and the 17 `cm_covenant_114_*_propagation.sh` gates now exist and were run. Applying this propagation leaves all 17 FAILing, held by four third-party carriers; what it changes is the MISSING count, 85 → 68, and the MISSING-carrier count, 5 → 4 | Done — [`PROOF.md`](PROOF.md); re-runnable at any time with `APPLY.md` §5 check 6 |
| Whether the constitution's own nested submodules (`anti_bluff`, `continuum`, `session_orchestrator`, `token_optimizer`, its `design-toolkit`, …) need the same treatment | Out of scope — this task named the 5 umbrella-owned submodules. INVENTORY.md §7.3 lists them as targets | A separate decision; each such commit would push through `submodules/constitution`'s 6-URL fan-out or those modules' own remotes |
