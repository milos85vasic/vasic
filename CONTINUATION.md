# CONTINUATION.md — vasic umbrella monorepo

<!-- The three fields below are MACHINE-READ by scripts/continuation-check.sh.
     Keep the exact `Field: value` shape. -->

    Last-Updated: 2026-08-31T20:06:46Z
    Synced-Commit: 708c8b1d034ac693283862412f2f4e1534b0e30a
    Authority-Root: submodules/constitution

This file is the single canonical handoff document mandated by **Constitution
§12.10** ("Continuation document — sacred invariant"). Its binding requirements,
quoted from `submodules/constitution/Constitution.md`:

> 1. **`docs/CONTINUATION.md` MUST exist** at the project root. Its
>    absence is a release blocker.
> 2. **Every non-trivial state change** MUST update this document in
>    the same commit as the work itself.
> 3. **Top-of-file timestamp** is updated on every edit. Stale
>    timestamps trigger gate failure.
> 4. **Section §3 "Active work"** lists every IN PROGRESS / BLOCKED
>    item with enough detail that any agent can resume without
>    conversation context — concrete commands, file paths,
>    monitor IDs.
> 5. **Section §0 "How to use this document"** contains the verbatim
>    resumption prompt — a single block any operator can paste into
>    any CLI agent.
> 6. **Document MUST be self-contained.** No hyperlinks to ephemeral
>    external systems as the only source of truth.

**Path note (honest boundary, §11.4.6).** §12.10's protection 1 is internally
inconsistent: it names `docs/CONTINUATION.md` but requires it "at the project
root". This repository resolves that in favour of the **repository root** —
`CONTINUATION.md` — because that is where the file already existed (tracked
since commit `18c84ff`) and where all four governance carriers restate the rule
("`CONTINUATION.md` kept in sync"). No `docs/CONTINUATION.md` exists here; if
one is ever added, one of the two must become a pointer, not a rival.

---

## §0 How to use this document

Read this file **first**, before any other file in the repository. It is
self-contained: every fact below is reproduced here, not linked to.

Verify it is not stale before trusting it:

```bash
bash scripts/continuation-check.sh     # 0 = in sync · 1 = drift · 2 = undetermined
```

If that exits `1`, it names the drift. **Fix the drift before doing anything
else** — a stale continuation document is a §12.10 violation, and §12.10 has no
override flag.

### Verbatim resumption prompt (§12.10 protection 5)

Paste this block, unedited, into any CLI agent (Claude Code, Codex, Cursor,
Aider, Gemini CLI, Qwen Code, OpenCode, Crush, Kimi CLI):

```text
You are resuming work on the `vasic` umbrella monorepo.

1. Read CONTINUATION.md at the repository root, in full, before anything else.
2. Run `bash scripts/continuation-check.sh`. If it exits 1, that document is
   stale — reconcile it against the four governance carriers (CLAUDE.md,
   AGENTS.md, QWEN.md, GEMINI.md) and docs/constitution-adoption/INVENTORY.md
   before starting new work. If it exits 2, report what could not be determined
   and why; do not treat 2 as a pass.
3. Read CLAUDE.md (or the carrier for your agent: AGENTS.md / QWEN.md /
   GEMINI.md — they are byte-identical below their opening section). The
   authority it points at is the git submodule at `submodules/constitution/`,
   NOT the top-level `constitution/` used as an example in the constitution's
   own prose. Read anchors on demand, never eagerly:
     awk '/^### §12.10 /{f=1} f&&/^### §12.11 /{exit} f{print}' \
         submodules/constitution/Constitution.md
4. Binding rules you inherit unconditionally: no bluffing (every PASS carries
   positive evidence, §11.4); no guessing language — "likely", "probably",
   "seems", "appears" are forbidden when reporting causes (§11.4.6); every new
   gate ships with a paired mutation proving it catches regressions (§1.1);
   never force-push; hardlinked backup before any destructive operation (§9);
   keep CONTINUATION.md in sync in the SAME commit as the work (§12.10).
5. Two PRODUCTION websites are published from this tree. Do not disable
   `milosvasic.ru/.github/workflows/pages.yml` — it is the sole publish path
   for the live site. See §5 of CONTINUATION.md before touching any CI or
   deploy file.
6. Do not commit or push unless the operator asks. If asked, use the `commit`
   wrapper on PATH, never bare `git add` / `git commit` / `git push`. Note the
   wrapper runs `git add .` — check `.gitignore` first.
7. Report the current §3 "Active work" items and ask which to take, unless the
   operator already told you.
```

Short one-line variant:

```text
Read CONTINUATION.md at the repo root, run `bash scripts/continuation-check.sh`,
then continue the §3 "Active work" items under the constitution mounted at
`submodules/constitution/`.
```

---

## §1 What this repository is

`vasic` is the umbrella monorepo for two personal/portfolio websites and the
shared tooling that builds, translates and validates them. It is not a
framework; the sites are git submodules and everything that generates or checks
them lives at the top level.

| Path | What it is |
| --- | --- |
| `vasic.digital/` | Site submodule — committed **static HTML**, no build step. |
| `milosvasic.ru/` | Site submodule — **Jekyll** source; rendered `_site/` is git-ignored. |
| `_tools/gen/` | **Go generator** (Go 1.26) that renders the localized pages for both sites. |
| `_tools/` | Translation (`translate/`), PDF (`pdf/`), portfolio (`portfolio/`) tooling + `deploy-langs.sh`. |
| `design-system/` | Shared per-brand tokens, fonts, icons, motion, component CSS. |
| `_tests/` | Playwright + self-validating harness (visual oracle, PDF/OCR export checks, link/sitemap integrity). |
| `_content/` | English source content. Per-language siblings are `_content_<lang>/`. |
| `scripts/` | Repo-level operational scripts, including the local gate runner. |
| `docs/constitution-adoption/` | The governance audit: `INVENTORY.md` (gap register G1–G12) and the §11.4.156 decision records. |

**Languages.** 14 translation trees exist: `ar be de es fa fr hi ja kk ko ru sr
tr zh`. `_tools/deploy-langs.sh` computes which are *complete* at run time from
its `LANGS` list and the document count — it does not trust a static list of
"shipped" languages.

**Submodules.** Owned-org gitlinks: `milosvasic.ru`, `vasic.digital`,
`design-toolkit`, `ai_interviewing`, `monetization`, `workshop`, and
`submodules/constitution`. `submodules/superspec` is **third-party**
(upstream `WangX0111/superspec`) and is outside the owned-submodule set for
tagging and propagation purposes.

**Clone caveat.** Init the site submodules **non-recursively**:
`git submodule update --init vasic.digital milosvasic.ru`. `milosvasic.ru`
embeds a nested submodule (`Upstreamable`) whose `.gitmodules` is a broken
0-byte gitlink, so a recursive checkout of the umbrella fails.

---

## §2 Where the authority lives

All rules come from the constitution submodule. **This repository mounts it at
`submodules/constitution/`, not the top-level `constitution/` that the
constitution's own prose and templates use as their example.** Wherever a quoted
snippet says `constitution/<file>`, the file here is
`submodules/constitution/<file>`. `submodules/constitution/find_constitution.sh`
resolves either layout from any nested depth.

| What | Path |
| --- | --- |
| The universal constitution | `submodules/constitution/Constitution.md` |
| Claude Code carrier (upstream) | `submodules/constitution/CLAUDE.md` |
| Codex / Cursor / Aider / OpenCode / Crush / Kimi carrier | `submodules/constitution/AGENTS.md` |
| Qwen Code carrier | `submodules/constitution/QWEN.md` |
| Gemini CLI carrier | `submodules/constitution/GEMINI.md` |
| Parent-walk resolver | `submodules/constitution/find_constitution.sh` |
| Forbidden-command PreToolUse guard (present, **not wired** — see G12) | `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` |

Measured on the currently checked-out gitlink (`902979027a90`,
`helixconstitution-v68-51-g9029790`): `Constitution.md` is 11,700 lines / 1.7 MB
and carries 252 `### §…` anchor headings (`wc -l`, `grep -cE '^### §'`).

**Inheritance form used here: the pointer block, not `@import`.** Anchor
§11.4.35 invariant 6 declares the two forms equivalent. This repository's four
root carriers (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`) each open with
`## INHERITED FROM submodules/constitution/CLAUDE.md`. The reason is cost: the
upstream carrier is 784 KB and `Constitution.md` is 1.7 MB, so a native import
would load roughly 165k tokens into every session before any work begins.

**Lockstep (§11.4.157).** The four root carriers must be byte-identical below
their opening section; only the opening section differs per agent. Verified at
`Synced-Commit`: `diff` of everything from `## Critical base rules restated`
onward is empty for `AGENTS.md`, `QWEN.md` and `GEMINI.md` against `CLAUDE.md`.
**Any edit to one carrier must be applied to all four in the same commit.**

**Project overrides of universal rules: NONE.** In particular, do not propose an
`Override §11.4.156` — that rule names and refuses the exemption vocabulary
("No escape hatch — no `--allow-ci` … `--ci-exempt` flag"), and a consumer
carrier may only extend inherited rules, never weaken them. A **documented
deviation is not an override** and must never be written up as one.

---

## §3 Active work

**IN PROGRESS**

| # | Item | Where to resume |
| --- | --- | --- |
| A1 | Carrier lockstep edit owed for this file (see §7 "Follow-up owed"). The four root carriers still say "There is also no `CONTINUATION.md` at this root yet" — that sentence is **false as of this commit**. It must be replaced in all four carriers in ONE commit per §11.4.157. | `CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md` — search for the literal string `There is also no ` |
| A2 | REOPENED 2026-08-31. G7 is **20/24**, not closed. The `workshop` submodule (added `e22d6b1`, `git@github.com:milos85vasic/workshop_curriculum.git`) carries none of the four governance carriers and is absent from `helix-deps.yaml`. Onboarding it is in flight. The prior 'RESOLVED / 20 of 20' entry was measured against a hardcoded five-item list rather than the fleet derived from `.gitmodules`. | `git config -f .gitmodules --get-regexp 'submodule\..*\.path'`; `bash scripts/verify-governance-cascade.sh` (C1/C6) |
| A3 | Post-fast-forward gate split for `scripts/verify-all-constitution-rules.sh` is **unmeasured**. The gate population moved 57 → 286 when the constitution was fast-forwarded, so every previously published split is withdrawn and none is comparable. Do not restate an old number. | `bash scripts/verify-all-constitution-rules.sh` |

**BLOCKED / NOT STARTED** — see §4. G8 and G12 are open with no work in flight.
G7 is PARTIAL (20/24): `workshop/` onboarding in flight.

**Background jobs.** None recorded by this file. `.lumen-reindex.log` at the
root is the running record for the semantic index; its last entry at
`Synced-Commit` is `[21:03:08] … batch probe OK: 32 distinct texts -> 32
distinct vectors`. If an index rebuild or gate sweep is running when you arrive,
**do not kill it and do not restart ollama** — check
`bash scripts/lumen-index-doctor.sh` (0 healthy / 1 corruption / 2 could not
inspect) rather than assuming.

**Operator-only manual steps** that no script here can perform are recorded in
`MANUAL-STEPS.md`.

---

## §4 Open gaps

Gap identifiers are `docs/constitution-adoption/INVENTORY.md`'s own (G1–G12).
The **current status** of each lives in the four root carriers, not in
`INVENTORY.md` — the inventory headings preserve the original discovery text and
were not rewritten as gaps moved. `scripts/continuation-check.sh` compares the
table below against every carrier that mentions the gap and fails on any
disagreement.

| Gap | Status | What is actually missing |
| --- | --- | --- |
| G3 | CLOSED | §11.4.32 sweep contract: both halves exist and run. `scripts/verify-governance-cascade.sh` supplies step 1 with a `--prove-failure` paired mutation; the step-1 caller distinguishes rc=1 (violation) from rc=2 (broken check) instead of collapsing both to FAIL. |
| G4 | PARTIAL | §11.4.156. **Umbrella root complies**: `.github/workflows/ci.yml.disabled` is inert, enforcement is the local pre-push hook. **Will not reach CLOSED** — file-level disabling cannot reach provider-side settings (org-default required workflows, branch-protection required checks, the Pages source setting), which are operator-only and unverified. `milosvasic.ru` keeps an ACTIVE `pages.yml` as a documented deviation; `vasic.digital` is non-compliant at the provider level with no file-level remedy. |
| G5 | PARTIALLY CLOSED | The commit **wrapper** exists (`commit` on PATH → `$SUBMODULES_HOME/Upstreamable/commit` → `Software-Toolkit/Utils/Git/commit.sh` + `push_all.sh`, driven by the tracked `upstreams/GitHub.sh`). What is still missing is git **hooks** as a tracked, travelling artefact. The wrapper runs `git add .` — keep `.gitignore` accurate before using it. |
| G6 | CLOSED | `helix-deps.yaml` exists at the root and parses under `yaml.safe_load`. |
| G7 | PARTIAL | Constitution-aware governance carriers across the owned submodules. **20 of 24** as of 2026-08-31. Fleet DERIVED from `.gitmodules` (not a hardcoded list — an earlier '20/20 CLOSED' claim here enumerated five submodules and missed the sixth): six owned submodules, of which `milosvasic.ru`, `vasic.digital`, `design-toolkit`, `ai_interviewing` and `monetization` each carry all four carriers with a real `## INHERITED FROM ` heading citing §11.4.28(B); **`workshop/` carries none**. `scripts/verify-governance-cascade.sh` FAILs C1 (roster does not classify `workshop`) and C6 (absent from `helix-deps.yaml`). Closes when that verifier exits 0. |
| G8 | OPEN | The §11.4.65 markdown/export mandate is unmet across the repository. |
| G12 | OPEN | No `PreToolUse` guard is wired. `.claude/settings.json` declares only `enabledPlugins`; the canonical guard script sits unused at `submodules/constitution/scripts/hooks/guard-forbidden-commands.sh`. |

**Not listed above:** G1, G2, G9, G10, G11 are not carried in the carriers'
"Known open gaps" list. G1 (no consumer governance layer) and G2 (no inheritance
pointer) are answered by the four root carriers existing. G9, G10 and G11 have
**no verified current status recorded anywhere in this tree** — do not report
them as closed, and do not report them as open, without re-auditing
`docs/constitution-adoption/INVENTORY.md` first.

**Do not claim this repository passes a constitutional gate you have not
actually run. Do not treat the absence of a gate as a pass.**

---

## §5 Operational hazards

**H1 — Two live production websites are published from this tree.** Operator
directive, standing: *"Make sure all pages websites work flawlessly! No website
can be broken! All websites we have here are running deployed in production!"*

**H2 — `milosvasic.ru/.github/workflows/pages.yml` is ACTIVE and must stay
active.** `gh api repos/milos85vasic/milosvasic.ru/pages` returns
`build_type: "workflow"` — that workflow is the **sole** publish path for
`https://milosvasic.ru/`. There is no `gh-pages` branch, no `docs/` folder, and
the repository root is Jekyll **source** (Liquid + front matter), so it cannot
be served raw from a branch. `_tools/deploy-langs.sh` is **not** a substitute:
it generates, commits and pushes *source*, then `sleep`s waiting for the server
to rebuild — the rebuild it waits for **is** that workflow. It was renamed to a
`.disabled` name once, on 2026-08-27, and reversed the same day before anything
was committed or pushed. **Do not disable, rename, or "fix" it.** It is a known,
documented **deviation** from §11.4.156 taken for uptime — never an override.

**H3 — `vasic.digital` is non-compliant at the provider level with no file-level
remedy.** Its Pages source is `build_type: "legacy"`, so every push triggers a
provider-side `pages build and deployment` Actions run even though the tree
contains **zero** workflow files (verified: `vasic.digital/.github/workflows/`
does not exist). Nothing in that repository can change this.

**H4 — There is no server-side CI at this umbrella root, and the hook does not
travel.** `.git/hooks/` is not tracked by git, so a **fresh clone runs no gates
at all** until `bash scripts/pre-push-gates.sh --install` is run. `git push
--no-verify` bypasses the hook with **no record**. At `Synced-Commit` the hook
is installed in this working tree (`.git/hooks/pre-push` present, executable) —
that fact does not travel with a clone. Run the gates by hand until you have
confirmed the hook is in place.

**H5 — No hardcoded absolute paths, ever.** 18 tracked files once hardcoded the
original author's macOS external-volume prefix, which pointed at nothing on
every other checkout. `_tools/deploy-langs.sh` uses `set -uo pipefail` *without*
`-e`, so its `cd "$ROOT"` failed silently and the script carried on in the
caller's working directory — then committed and pushed both site submodules.
`scripts/audit-hardcoded-paths.sh` (gate 0) is the guard. Derive roots; never
write them literally. `.hardcoded-paths-allow` is the only exemption list and is
deliberately one entry long.

**H6 — Do not force-push.** Force-push requires explicit per-session
authorization AND a green §9.1.5 post-op gate. Take a hardlinked backup before
any destructive operation (§9).

**H7 — Use the commit wrapper.** No direct `git add` / `git commit` / `git push`
on the main repository. The wrapper stages everything untracked (`git add .`).

**H8 — A test once stayed green while the thing it tested was deleted.** Assert
against observed state, never against the presence of a string. Every new gate
ships with its paired mutation (§1.1).

---

## §6 Gates — how to run them

There is **no active workflow at this root**. The definitions are preserved,
inert, in `.github/workflows/ci.yml.disabled`; the runnable replacement is
`scripts/pre-push-gates.sh`. Run from the repository root.

| Gate | Command |
| --- | --- |
| E | `git ls-files \| grep -E '^\.github/workflows/.*\.ya?ml$\|^\.gitlab-ci\.yml$'` (must be EMPTY) |
| 0 | `./scripts/audit-hardcoded-paths.sh` |
| 1 | `cd _tools/gen && go test ./...` |
| 2 | `bash _tools/audit-hardcoding.sh` |
| 3 | `bash _tools/translate/reproducibility-selftest.sh` |
| 4 | `bash _tools/portfolio/self-validate.sh` |
| 5 | `bash _tests/run-harness-selfvalidation.sh` |
| 6 | `cd _tests && npx playwright test --project=chromium --grep-invert 'all-language'` |

Run them all at once, and manage the hook:

```bash
bash scripts/pre-push-gates.sh              # run every gate (exit 0 = push OK)
bash scripts/pre-push-gates.sh --list       # print the gate table, run nothing
bash scripts/pre-push-gates.sh --install    # write the untracked .git/hooks/pre-push shim
bash scripts/pre-push-gates.sh --uninstall  # remove that shim
```

Switches: `PREPUSH_VERBOSE=1` (stream output live), `PREPUSH_SKIP_SLOW=1` (skip
gate 6 with a printed reason), `PREPUSH_STRICT=1` (treat every SKIP as a
FAILURE — use before a release or a §11.4.40 pre-tag sweep), `PREPUSH_ONLY="E 0
1"` (run only the listed ids). There is deliberately **no** switch that skips
gate E.

Gates 5 and 6 SKIP with a stated reason when `_tests/node_modules` or the built
`milosvasic.ru/_site` is absent. **A SKIP is reported loudly and is not a pass.**

Governance sweeps (not part of the pre-push set):

```bash
bash scripts/verify-governance-cascade.sh   # step 1; --prove-failure runs its paired mutation
bash scripts/verify-all-constitution-rules.sh
bash scripts/continuation-check.sh          # this document is not stale
```

Toolchains the gates expect on `PATH`: Go 1.26, Node 20, Ruby 3.3 + Bundler,
poppler-utils, tesseract-ocr. Playwright additionally needs `npm ci` and
`npx playwright install chromium` inside `_tests/`, and a built
`milosvasic.ru/_site`.

**Deploys** are driven by `bash _tools/deploy-langs.sh` — it regenerates EN plus
every complete language into both site submodules, commits and pushes each site
only when something changed, then validates the LIVE sites. `--dry-run` previews
without committing. Its exit codes: `0` deploy completed and live validation
passed (or was explicitly skipped); `1` deploy completed but the live validator
found broken links; `2` deploy completed but the live validator could not run.

---

## §7 How this document is kept honest

A hand-written status file goes stale the moment it is written. This one is
machine-checked:

```bash
bash scripts/continuation-check.sh          # 0 in sync · 1 drift · 2 undetermined
bash scripts/continuation-check.sh --list   # print every check, run none
bash scripts/continuation-check.sh --prove-failure   # paired §1.1 mutation proof
```

It verifies, against the live tree rather than against its own text: the §12.10
structural requirements above; that the `Synced-Commit` is a real ancestor of
`HEAD`; that no commit since `Synced-Commit` touched a watched governance file
**without** also touching this document (§12.10 protection 2, mechanically); that
every gap status in §4 agrees with **every** carrier that mentions that gap
(§11.4.157 lockstep folded in); that every `*.sh` this document names exists,
and is executable when §6 invokes it directly; that §12.10 still exists under
that anchor name in the mounted constitution; and that the §5 production facts
(root CI inert, `pages.yml` present, `vasic.digital` workflow-free) still hold.

**Follow-up owed to the controller (do NOT apply it piecemeal).** All four root
carriers contain this sentence, which is now false:

> There is also no `CONTINUATION.md` at this root yet, so the restated item above
> describes the universal rule rather than an existing artifact here.

It must be replaced — in `CLAUDE.md`, `AGENTS.md`, `QWEN.md` and `GEMINI.md`
together, in one commit, per the §11.4.157 lockstep requirement — with a
sentence pointing at this file and at `scripts/continuation-check.sh`. Editing
fewer than four is itself a lockstep violation.

**When you change anything non-trivial, update this document in the same
commit** (§12.10 protection 2) and refresh `Last-Updated` and `Synced-Commit`
(protection 3). `scripts/continuation-check.sh` will tell you when you forgot.
