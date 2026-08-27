# Discoveries

Things agents have learned about the codebase and domain. Each entry names the
file it was verified against.

## Two scripts hardcode `/Volumes/T7/Projects/vasic`

- `_tools/deploy-langs.sh:8` — `ROOT="/Volumes/T7/Projects/vasic"`, followed by
  `cd "$ROOT"` on line 9. The script sets `set -uo pipefail` — **no `-e`** — so
  a failed `cd` prints an error and the script keeps running in the caller's cwd.
- `_tests/playwright.config.js` — hardcodes the same prefix for its two static
  roots. CI works around it by symlinking `/Volumes/T7/Projects/vasic` →
  `$GITHUB_WORKSPACE` rather than editing the in-repo config
  (`.github/workflows/ci.yml` header, "Why the /Volumes symlink").

This checkout lives at `/run/media/milosvasic/DATA4TB/Projects/vasic`. The
documented deploy entry point (`README.md:94-98`, `CLAUDE.md:148-154`) will not
resolve here without the same symlink or an edit. **Verified 2026-08-27.**

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
