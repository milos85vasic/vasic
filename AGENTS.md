# vasic — AGENTS.md

## INHERITED FROM submodules/constitution/AGENTS.md

All rules in `submodules/constitution/AGENTS.md` (and the
`submodules/constitution/Constitution.md` it references) apply unconditionally
to this project. Project-specific rules below extend them — they do NOT weaken
or override any universal clause.

When this file disagrees with the constitution submodule, the constitution wins.

> Base agent rules: `submodules/constitution/AGENTS.md` — READ IT FIRST.
> The base file is authoritative for any topic not covered here.
> Locate it from any nested depth with
> `submodules/constitution/find_constitution.sh`.

This carrier is read by
Codex, Cursor, Aider, OpenCode, Crush, Kimi CLI and other generic AI-agent tooling.
It is one of the four repository-root governance context carriers
(`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) that anchor 11.4.157
requires to be maintained in lockstep. Everything below this paragraph is
byte-identical across all four; only this opening section differs.

### Where the canonical rules actually live

Nothing is copied here. This file is a pointer; the authority is the submodule.

| What | Canonical path in this repository |
|---|---|
| The universal constitution (11,700 lines, 252 `### §` anchors, measured 2026-09-01 at pin `f16ea779b82a`; the same `Constitution.md` blob as the superseded pin `902979027a90`) | `submodules/constitution/Constitution.md` |
| Claude Code carrier | `submodules/constitution/CLAUDE.md` |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi CLI carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Full anchor corpus companion | `submodules/constitution/CLAUDE_ANCHORS_FULL.md` |
| Parent-walk resolver (works from any nested depth) | `submodules/constitution/find_constitution.sh` |
| Post-pull governance hook | `submodules/constitution/scripts/post_update_hook.sh` |
| Forbidden-command PreToolUse guard | `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` |
| Propagation / covenant gates | `submodules/constitution/scripts/gates/` |

**The pin was FAST-FORWARDED to its upstream HEAD on 2026-09-01, on explicit
operator authorization. The gap this block used to report is closed; the HOLE
that let it open unnoticed is not.** `submodules/constitution` is now checked
out at `f16ea779b82a`, on branch `main`, equal to
`git ls-remote git@github.com:HelixDevelopment/HelixConstitution.git HEAD` as
measured that day. **That equality did NOT survive the day, and this block is
not evidence that it holds now.** Re-measured 2026-09-01 by
`bash scripts/verify-submodule-remote-sync.sh`: the remote HEAD is
`b9096acd98d2` and the gitlink `f16ea779b82a` **DIFFERS** from it. The
difference is DETERMINED; the DIRECTION is **not**, because the remote commit is
not in this checkout's object store, and `--fetch` — which would classify it —
is a mutating command and an operator decision. Do not read `f16ea779b82a` as
current; run the gate. Four findings from the bump itself, each measured rather
than inferred:

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
3. **`helix-deps.yaml` moved in the SAME change.** Its `constitution` entry now
   records `f16ea779b82a`, and the manifest and the gitlink were staged
   together — a bumped gitlink with a stale `ref:` is precisely what C9 exists
   to catch. Re-measured after the bump: `bash scripts/verify-manifest-pins.sh`
   exit **0** at 12 MATCH / 0 DRIFT / 0 UNDETERMINED, and
   `bash scripts/verify-governance-cascade.sh` exit **0** at 12 PASS / 0 FAIL /
   0 ENV / 8 NOTE.
4. **No gate in this tree detected local-vs-remote submodule drift, and the
   bump did not change that. One was written later the same day, and it is
   RED.** Cascade check C9 and `scripts/verify-manifest-pins.sh` compare
   `helix-deps.yaml` to the **local gitlink**, never to the remote. Both exited
   **0** while the pin sat 3 commits behind, and both exit **0** now. They
   cannot tell the two states apart, so neither exit code is, or ever was,
   evidence about the remote — which is precisely why a second instrument was
   needed. See "Submodule-vs-remote drift" below.

**Upstream defect carried in by the fast-forward — recorded, NOT ours to fix.**
`f16ea779b82a` adds a SECOND `design-toolkit` gitlink at the constitution's own
ROOT (`create mode 160000 design-toolkit`) alongside the existing
`submodules/design-toolkit`, while its `.gitmodules` still maps the entry NAMED
`design-toolkit` to path `submodules/design-toolkit` only — so the root gitlink
is unregistered in `.gitmodules`. Fixing it means committing to the constitution
submodule, which this repository does not do. Separately, the `design-toolkit`
ref CONFLICT recorded under `conflict_resolution` in `helix-deps.yaml` is
**UNCHANGED** by the move: the constitution's own `helix-deps.yaml` still says
`ref: 16e4e76` at both `902979027a90` and `f16ea779b82a`.

**The residual risk this block used to report as "not started" is now WATCHED,
and the watching instrument is RED.** The risk was real and is restated because
the reason it went unseen is the lesson: any submodule in this tree could sit
arbitrarily far behind its upstream — corpus changes included — with every gate
in this repository green, because C9 compares the manifest to the local gitlink
and **nothing compared the gitlink to the remote**. The bump closed one
INSTANCE, not the CLASS. The class is now covered by
`scripts/verify-submodule-remote-sync.sh`, registered in
`scripts/check-registry.tsv` as `submodule-remote-sync` with a `--prove-failure`
paired proof — which is exactly what R5 demanded. **Watched is not fixed:**
measured 2026-09-01 that gate exits **1** at 6 CURRENT / 6 DRIFT / 0
UNDETERMINED of 12 owned gitlinks probed, and `submodules/constitution` is among
the 6. See "Submodule-vs-remote drift" below.

Re-derive. The pin now equals the remote head, so no scratch clone is needed —
but a `git fetch` inside the submodule is still a mutating command and still an
operator decision:

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
(measured 2026-09-01 at pin `f16ea779b82a`; both grew from the 654 KB / 1.53 MB
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
make it green.** Re-measured 2026-09-01,
`bash scripts/verify-content-boundary.sh` exits **1** and prints:

```
LEAK — 285 surviving match(es) (prose 207, short 35, name 43); 0 row(s) also could not be determined
```

**The figure this block used to carry — `LEAK — 10293 surviving match(es)
(prose 203, short 8535, name 1568)` — is WITHDRAWN, not restated.** It was a
MID-TUNING snapshot, captured while the detector was still being rewritten, and
it measured the detector's own noise floor rather than this tree. **The two
numbers are not a before/after of any cleanup: nothing was redacted between
them.** The `short` class fell 8535 → 35 and the `name` class 1568 → 43 because
the detector learned to subtract keys already public in two or more public
repositories, public git identity forms, a scale-free name-frequency floor and
path-reference matches — each subtraction printed on every run, with its RECALL
COST stated, so what the gate can no longer see is visible rather than assumed.

The **207 prose** matches are the judged class. Honest boundary (§11.4.6): the
incident note's two-wave assessment covered **232** matches — 29 redacted as
real disclosures, 203 judged not to be — so 207 and 203 are close but are **not
the same set**, and the difference is not accounted for here. Do not read 207 as
"207 rows individually cleared". The judged rows are left VISIBLE rather than
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
reported to remain **private**, and it is **5 commits behind**, measured rather
than assumed:

```bash
git -C design-toolkit ls-remote origin HEAD                          # 5467a888…
git -C design-toolkit ls-remote git@gitlab.com:vasic-digital/design-toolkit.git HEAD   # 520c436c…
git -C design-toolkit rev-list --left-right --count 520c436c…...5467a888…   # 0  5
```

`git merge-base --is-ancestor` confirms the GitLab head is a strict **ancestor**
of the GitHub head — 0 commits on GitLab that GitHub lacks, **5** on GitHub that
GitLab lacks — so this is lag, not divergence. Honest boundary (§11.4.6): this
checkout wires up **no** GitLab remote for `design-toolkit` (`git remote -v`
shows `origin` only, GitHub, fetch and push), so the *visibility* half of that
statement is **UNVERIFIED from this tree** and is recorded as reported; the
5-commit lag is measured. **Do not write as though the two mirrors match.**

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

**It exits 1, and the 1 is correct: several gitlinks are behind their remotes
pending a bump. That is an operator decision, not a defect in the gate.**
Measured 2026-09-01:

```bash
bash scripts/verify-submodule-remote-sync.sh
# 1 — 6 CURRENT, 6 DRIFT, 0 UNDETERMINED of 12 owned gitlink(s) probed, 13 declared
```

CURRENT: `milosvasic.ru`, `vasic.digital`, `monetization`, `workshop`,
`submodules/verdict`, `submodules/passage`. DRIFT: `design-toolkit`,
`ai_interviewing`, `submodules/containers`, `submodules/LLMProvider` and
`submodules/RAG` are each **BEHIND** — the gitlink is a strict ancestor of the
remote head, so each is fast-forwardable — while `submodules/constitution` is
**DIFFERS**: the difference is determined, the direction is **not**, because the
remote commit `b9096acd98d2` is not in this checkout's object store. `--fetch`
classifies it, and fetching is a mutating command and an operator decision.
`submodules/superspec` is probed and reported as a third-party NOTE, never a
verdict input, which is why 12 owned gitlinks are probed of 13 declared.

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
measured on 2026-09-01 and are dated observations, not standing facts:

```bash
bash scripts/continuation-check.sh              # CONTINUATION.md is not stale
bash scripts/verify-governance-cascade.sh       # 0 — 12 PASS/0 FAIL/0 ENV/8 NOTE (C0..C9)
bash scripts/verify-manifest-pins.sh            # 0 — C9 standalone: 12 MATCH/0 DRIFT/0 UNDET of 12
bash scripts/verify-check-registry.sh           # 0 — 25 PASS/0 FAIL/5 DEBT/0 UNDET, see below
bash scripts/audit-hardcoded-paths.sh           # 0 — gate 0, 6 file(s) explicitly allowed
bash scripts/audit-environment-assumptions.sh   # 1 — RED AGAIN, 10 frozen assumptions, see below
bash scripts/verify-content-boundary.sh         # 1 — RED BY DESIGN, see "Content boundary"
bash scripts/verify-submodule-remote-sync.sh    # 1 — 6 of 12 owned gitlinks drift from their remote
bash scripts/verify-provider-ci.sh              # provider-side CI probe
bash scripts/lumen-index-doctor.sh              # 0 — semantic index health
bash scripts/ollama-tune.sh                     # local inference host tuning
```

Four of those need reading carefully rather than glancing at:

- **`verify-check-registry.sh` prints 5 DEBT rows on every run** and can still
  exit 0. That is deliberate: a known gap must never go quietly green. A zero
  means "every registered check is accounted for", **not** "every check has a
  paired proof". A plain run verifies proof *structure* only and says so;
  `--run-proofs` actually executes them, `--strict` makes debt block. Its R5
  anti-drift rule means **a new `*.sh` under `scripts/` fails the registry until
  it is registered** in `scripts/check-registry.tsv` (documented in
  `docs/check-registry.md`) as a check, a debt, or an exemption. Measured
  across 2026-09-01 in three states, all real: exit **0** at 21 PASS / 0 FAIL /
  5 DEBT in the morning; then exit **1** at 20 PASS / 1 FAIL / 5 DEBT once an
  unregistered `scripts/verify-content-boundary.sh` appeared — R5 doing its job;
  then exit **0** once that gate was registered. Re-measured later the same day
  it is exit **0** at **25 PASS / 0 FAIL / 5 DEBT / 0 UNDET / 0 NOTE** — the
  PASS count moved 23 → 25 as further checks landed and were registered, which
  is R5 working rather than drift, and the "23 PASS" figure this bullet used to
  carry is superseded, not wrong-at-the-time. The FAIL is cleared; **the 5
  DEBT rows are not** — `constitution-rules-sweep`, `lumen-index-doctor`,
  `ollama-tune`, `prepush-gates` and `setup-agents-wizard-suite` still owe a
  paired proof. Zero here means "every registered check is accounted for", and
  the run says so itself: *"Proof STRUCTURE was verified; no paired proof was
  EXECUTED."*
- **`audit-environment-assumptions.sh` is RED again (exit 1). Its green was
  real while it lasted, and both states are recorded, because the movement is
  the point.** The 7 frozen GNU-vs-BSD assumptions this bullet once reported —
  six in `scripts/verify-check-registry.sh` (GNU-only in-place `sed -i`,
  `stat -c '%a'`) and one in `scripts/verify-manifest-pins.sh` — **were** fixed
  with portable helpers, and the audit did go **green (exit 0)** at 1763 files
  across 14 repositories. Re-measured later on 2026-09-01 it exits **1** with
  **10 frozen environment assumptions**, scanning **1794 files across 14
  repositories in 12 classes**. All 10 sit inside `submodules/LLMProvider`,
  which joined the owned fleet the same day and brought its own occurrences into
  scope: `pkg/providers/ai21/ai21_test.go` (2 `MODEL`),
  `pkg/providers/openrouter/openrouter_test.go` (5 `MODEL`) and
  `scripts/prove-offline-discovery.sh` (2 `ENDPOINT` + 1 `MODEL`). **The
  coverage moved with the fleet on its own, with no edit to the audit** — which
  is the behaviour the fleet-derivation fix was for, and a red verdict earned
  that way is the instrument working. Read the rest of its output before calling
  anything clean: it also prints **712 baselined occurrences** — declared,
  known, unfixed defects, printed on every run by design — **2 STALE allow rules
  of 405**, where the occurrence each one names is GONE (a rule is an exemption
  at a PATH, not at an occurrence), and **1 frozen assumption inside a
  third-party gitlink** (`submodules/superspec/.github/workflows/ci.yml`, a
  pinned `python-version: "3.12"`), reported out-of-scope under §11.4.156(C) /
  §11.4.29 so it is never silently omitted. **A baseline is recorded debt, not a
  justification, and an allow row is not a fix.**
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
- **A generative model IS available locally.** `ollama list` holds **three**
  models, not two: `qwen2.5:3b-instruct-q4_K_M` (1.9 GB, **generative**,
  pulled 2026-09-01) alongside the two **embedding** models
  `ordis/jina-embeddings-v2-base-code` and `jina-embeddings-code-cpu` (323 MB
  each). "Nothing local can generate prose" is false as of that pull. What a
  3B q4 instruct model is fit FOR is a separate question this line does not
  answer.
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
