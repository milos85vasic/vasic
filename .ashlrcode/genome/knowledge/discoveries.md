# Discoveries

Things agents have learned about the codebase and domain. Each entry names the
file it was verified against.

## Every build path is DERIVED — the two hardcoded-root bugs are fixed

**Status: CLOSED. Re-verified against the live files 2026-08-27.** Kept as
history because the failure mode is instructive. Nothing in this entry is
outstanding work — do not open a task from it.

**What it was.** `_tools/deploy-langs.sh` set `ROOT` to a literal macOS path and
`cd`-ed into it. The script sets `set -uo pipefail` — **no `-e`** — so the
failed `cd` merely printed an error and the script carried on in the caller's
working directory, with `GEN` and `PDF` pointing at directories that do not
exist, and then committed and pushed both site submodules. Silent, and
destructive. `_tests/playwright.config.js` carried the same literal prefix for
its two static roots, and CI papered over the whole class by symlinking that
path to `$GITHUB_WORKSPACE` instead of fixing the configs.

**What it is now.**

- `_tools/deploy-langs.sh:14` —
  `ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"`; line 15 makes
  the `cd` **fatal** (`|| { echo "FATAL: cannot cd to repository root ..."; exit 1; }`).
  Line 8 is a *comment* describing the historical bug — it is documentation, not
  a defect, and must not be "re-fixed".
- `_tests/playwright.config.js:7` — `const REPO = path.resolve(__dirname, '..');`
  with `VD_ROOT`/`MV_ROOT` joined off it. No machine-specific literal remains
  anywhere in that file.
- `.github/workflows/ci.yml:44-52` and `:182-184` — the symlink bridge is
  **removed**; both notes are written as history ("that bridge has been
  removed", "no longer needed").
- A repo-wide sweep removed **33 occurrences across 18 files**.
- `scripts/audit-hardcoded-paths.sh` now enforces the invariant as CI **Gate 0**
  (`.github/workflows/ci.yml:131-140`) and fails the build if any
  machine-specific absolute root is reintroduced. It strips comment-only lines
  before matching, on the stated principle that documenting the bug is not the
  bug, and it allow-lists itself in `.hardcoded-paths-allow` because its own
  `PATTERN` must contain the literal it detects.

This checkout lives at `/run/media/milosvasic/DATA4TB/Projects/vasic`, and the
documented deploy entry point (`README.md:94-98`, `CLAUDE.md:148-154`) resolves
here with no symlink and no local edit.

## Recursive submodule checkout is a known failure

`milosvasic.ru` embeds `red-elf/Upstreamable`, whose `.gitmodules` is a broken
0-byte gitlink. Init only what the gates need, non-recursively:
`git submodule update --init vasic.digital milosvasic.ru`
(`README.md:34-40`; `.github/workflows/ci.yml` deviation (a)).

## `_tests/evidence/` is tracked output at scale

4,526 tracked files — 1,353 json, 1,167 txt, 1,142 png, 515 log — against only
95 real source files in all of `_tests/` (`.lumenignore` header). `.gitignore`
carries an explicit `!_tests/evidence/` negation so it stays tracked. It is
excluded from the Lumen index only; CodeGraph and git still see it.

## Language completeness is data-driven, not a list

`_tools/deploy-langs.sh:21-25` counts files containing `"verdict": "PASS"` under
`_tests/evidence/translate-new/<lang>/` and compares that to the number of `*.md`
files under `_content/{products,sites,docs}`. A language ships only when the
counts match. Candidate list: `ru sr de es fr be zh kk hi ja ko ar tr fa` (14).

## Private-repo suppression lives at the data gate, not the renderer

`_tools/gen` declares `PortfolioEntry.Private` but **never branches on it** — the
renderer trusts pre-validated data. Suppression is enforced by
`_tools/portfolio/validate.mjs` and re-asserted at runtime by the Playwright
private-repo deep-link guard, with `TestPortfolioDataHasNoPrivateLeak` as a
belt-and-suspenders check (`_tests/TEST-TYPES.md`, "honest edges").

## The commit wrapper resolves outside this repository

`command -v commit` → `<workspace>/project_toolkit/Upstreamable/commit` (on this
host: `/run/media/milosvasic/DATA4TB/Projects/project_toolkit/Upstreamable/commit`).
It chains `Software-Toolkit/Utils/Git/commit.sh` (`git add .` + `git commit`)
then `push_all.sh`, which reads `upstreams/*.sh`. This root has a tracked
`upstreams/GitHub.sh` exporting
`UPSTREAMABLE_REPOSITORY="git@github.com:milos85vasic/vasic.git"`, so
`commit "<msg>"` works here. **Verified 2026-08-27.**

## `.git/hooks/` now has exactly one non-sample hook — and it is not governance

`post-commit`, installed by `ashlr-plugin` (`scripts/install-genome-hooks.ts`),
backgrounds `bun run scripts/genome-commit-watcher.ts`. The §11.4.75 five-layer
enforcement ritual is still absent, so `Constitution.md` gap **G5 stays OPEN**
even though the directory is no longer hook-free. **Verified 2026-08-27.**

## Release tags do not fan out to every owned submodule

`v1.8.0` exists on `milosvasic.ru` and `vasic.digital` only (gap G10 OPEN).
`design-toolkit` is checked out twice in this tree (gap G11); the shas matched
as of the Constitution's capture.

## The 21 failing gates are classified, not mysterious

`scripts/verify-all-constitution-rules.sh` → 58 gates, 37 PASS / 21 FAIL /
0 ERROR, exit 1. The 21 are exactly the 17 `cm_covenant_114_*_propagation.sh`
gates (each reporting the same five carriers: 17 × 5 = 85 MISSING lines) plus
4 gates failing inside the constitution submodule's own tree. Four of the five
carriers are third-party (known-excluded, §103); only `vasic.digital/QWEN.md` is
an owned gap, and its fix is staged awaiting operator application.
