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
| The universal constitution (11,101 lines, 261 anchors) | `submodules/constitution/Constitution.md` |
| Claude Code carrier | `submodules/constitution/CLAUDE.md` |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi CLI carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Full anchor corpus companion | `submodules/constitution/CLAUDE_ANCHORS_FULL.md` |
| Parent-walk resolver (works from any nested depth) | `submodules/constitution/find_constitution.sh` |
| Post-pull governance hook | `submodules/constitution/scripts/post_update_hook.sh` |
| Forbidden-command PreToolUse guard | `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` |
| Propagation / covenant gates | `submodules/constitution/scripts/gates/` |

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
`submodules/constitution/CLAUDE.md` is 654 KB and `Constitution.md` is 1.53 MB,
so a native import would load roughly 165k tokens of context into every session
before any work begins. The pointer form carries the same authority at no
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

`milosvasic.ru`, `vasic.digital`, `design-toolkit`, `ai_interviewing`,
`monetization`, and `submodules/constitution` are owned-org gitlinks.
`submodules/superspec` is third-party (upstream `WangX0111/superspec`) and is
outside the owned-submodule set for tagging and propagation purposes.

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

### Deploys

Deploys are driven by `bash _tools/deploy-langs.sh`. It regenerates EN plus
every complete language into both site submodules, commits and pushes each site
only when something changed, then validates the LIVE sites. `--dry-run` previews
without committing.

**`milosvasic.ru` self-publishes on push, and that must not change** (verified
2026-08-27). Its `.github/workflows/pages.yml` is the custom GitHub Pages
build+deploy action and is **ACTIVE**. It was briefly renamed to a `.disabled`
name under the 2026-08-27 11.4.156 decision (*"Comply — disable both, enforce
locally."*); that half of the decision was **reversed the same day** on the
operator's overriding directive:

> *"Make sure all pages websites work flawlessly! No website can be broken! All
> websites we have here are running deployed in production!"*

The material fact behind the reversal:
`gh api repos/milos85vasic/milosvasic.ru/pages` returns `build_type: "workflow"`
— that workflow is the **sole** publish path for the live site. There is no
`gh-pages` branch and no `docs/` folder, and the repository root is Jekyll
SOURCE (Liquid + front matter), so it cannot be served raw from a branch.
`_tools/deploy-langs.sh` is **not** a substitute: it generates, commits and
pushes source, then `sleep`s waiting for the server to rebuild — it covers
generation and push, none of the publish step. **Do not disable, rename, or
otherwise "fix" `pages.yml`.** `vasic.digital` needs no build step (committed
static HTML), but its Pages source was `build_type: "legacy"` when last
measured, so every push still triggers a provider-side `pages build and
deployment` Actions run even though it has **zero** workflow files in its tree.

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
  10 PASS / 0 FAIL / 0 ENV / 3 NOTE, exit 0, with a paired-mutation proof
  (`--prove-failure`) that catches 5 seeded violations as rc=1 and reports an
  environment fault as rc=2 rather than accusing the tree. Step 1 is a measured
  PASS, not a SKIP-with-reason; OC-3 is resolved.
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
- G7 — PARTIAL (measured 2026-08-31; **20/24**). Two successive claims here were
  wrong and both are withdrawn rather than restated.
  (a) The original — "only `vasic.digital/QWEN.md` exists, and it references no
  anchor" — was false on both halves.
  (b) Its replacement — "CLOSED, 5 x 4 = 20/20" — was ALSO wrong, because it
  enumerated a HARDCODED list of five submodules instead of deriving the fleet
  from `.gitmodules`. That is the same defect class the fleet roster itself is
  criticised for, committed while correcting the first error.
  Derived measurement (`git config -f .gitmodules --get-regexp
  'submodule\..*\.path'`, excluding the governance source and the third-party
  gitlink) finds **SIX** owned submodules, not five: `milosvasic.ru`,
  `vasic.digital`, `design-toolkit`, `ai_interviewing`, `monetization`, and
  `workshop` — the last added in commit `e22d6b1` and present in HEAD when the
  "20/20" claim was made.
  Coverage is therefore **20 of 24**. The five older submodules each carry all
  four carriers, every one opening with a real, non-fenced `## INHERITED FROM `
  heading (§11.4.35 inv. 6) and citing §11.4.28(B). `workshop/` carries **none**
  of the four. `scripts/verify-governance-cascade.sh` independently FAILs C1
  (fleet roster does not classify `workshop`) and C6 (`helix-deps.yaml` records
  it nowhere) — the gate caught this before any human did, which is the point of
  it. G7 closes when `workshop/` is onboarded and that verifier exits 0.
- G8 — the markdown export mandate (11.4.65) is unmet across the repository.
- G12 — no `PreToolUse` guard is wired, although the canonical guard script is
  present in the submodule.

`CONTINUATION.md` DOES exist at this root and is now §12.10-conformant
(verified 2026-08-31). An earlier revision of this file claimed it did not; that
claim was already false when written — a thin 725-byte session note was tracked
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
