# Constitution Propagation — RISKS

> **Note on filenames.** The staged carrier drafts in this directory are stored with a
> `.staged` suffix (e.g. `AGENTS.md.staged`). The constitution's propagation gates discover
> carriers by exact filename (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`), so drafts
> named that way inside the repo are counted as real carriers and fail the gate. Drop the
> `.staged` suffix when you copy a file into its target submodule.


| Field | Value |
|---|---|
| Revision | 1 |
| Created | 2026-08-26 |
| Last modified | 2026-08-26 |
| Status | active |
| Status summary | Blast-radius, exclusion and honesty register for the propagation prepared in [`APPLY.md`](APPLY.md). Nothing has been applied. Every number below comes from a read-only command whose output is quoted. |
| Continuation | Operator reads this before executing `APPLY.md` §4. |

## 1. What was and was not done while preparing this

**Not run, anywhere:** `git add`, `git commit`, `git push`, `git fetch`,
`git pull`, `git checkout`, `git submodule update`, `git tag`, `git remote add`,
`git config`. No file inside any submodule working tree was created, modified,
or deleted. The only writes are the 22 files in this directory
(`docs/constitution-adoption/propagation/`), all of them in the umbrella repo.

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
  context" §11.4.28(B) forbids. The prepared file keeps the sentence for exact
  fidelity to the reference form; the operator must either (a) read it as the
  forward obligation it states and open a separate remediation item for the
  README, or (b) delete that paragraph from all four `ai_interviewing` carriers
  before committing. **It must not be committed as an unexamined claim.**
  The same sentence is materially true of `design-toolkit`, `monetization`,
  `milosvasic.ru` and `vasic.digital` only insofar as their content was not
  audited for project-coupling in this pass — see §6.
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
| Whether applying this would make any existing gate pass | No gate exists to run (INVENTORY.md G3/G5) | Build `scripts/verify-all-constitution-rules.sh` per §11.4.32, then run it before and after |
| Whether the constitution's own nested submodules (`anti_bluff`, `continuum`, `session_orchestrator`, `token_optimizer`, its `design-toolkit`, …) need the same treatment | Out of scope — this task named the 5 umbrella-owned submodules. INVENTORY.md §7.3 lists them as targets | A separate decision; each such commit would push through `submodules/constitution`'s 6-URL fan-out or those modules' own remotes |
