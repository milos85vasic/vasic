# Anti-Patterns

Each entry is a concrete failure this repository has already hit or explicitly
forbids, with the file that records it.

## Git / submodules

- **`git submodule update --init --recursive` on this umbrella.** It fails.
  `milosvasic.ru` embeds `red-elf/Upstreamable`, whose own `.gitmodules` is a
  broken 0-byte gitlink. Init only what you need, non-recursively:
  `git submodule update --init vasic.digital milosvasic.ru`
  (`README.md:34-40`; same reasoning in the `.github/workflows/ci.yml` header,
  deviation (a)).
- **Direct `git add` / `git commit` / `git push` on the main repo.** Forbidden;
  use the project's commit wrapper (`CLAUDE.md:95-96`). The wrapper runs
  `git add .`, so `.gitignore` must be accurate before invoking it
  (`CLAUDE.md:180-181`).
- **Force-push.** Requires explicit per-session authorization *and* a green
  §9.1.5 post-op gate (`CLAUDE.md:97-98`).
- **Writing a governance carrier into an owned submodule from the umbrella.**
  §3 requires the submodule commit to land first; `Constitution.md` §102 stages
  drafts instead. A draft must keep its `.staged` suffix — a file named
  `CLAUDE.md` inside `docs/.../propagation/` would be counted by the propagation
  gates as a real carrier and fail them.
- **"Fixing" a third-party repo to make a gate pass.** `Constitution.md` §103.
  Four of the five carriers the propagation gates report MISSING are third-party
  and are known-excluded, not bugs.

## Build / scripts

- **Hardcoded absolute paths.** *(Occurred; fixed; now machine-enforced.)*
  `_tools/deploy-langs.sh` once set `ROOT` to a literal macOS path under
  `/Volumes/`, and `_tests/playwright.config.js` carried the same prefix for its
  two static roots; CI worked around both with a symlink instead of fixing the
  configs. The shape of the bug is what makes it worth keeping: `deploy-langs.sh`
  runs `set -uo pipefail` **without `-e`**, so the failed `cd` was silent and the
  script went on to commit and push both site submodules from the wrong
  directory. **Fixed:** `deploy-langs.sh:14` derives `ROOT` from
  `${BASH_SOURCE[0]}` and line 15 makes the `cd` fatal;
  `playwright.config.js:7` uses `path.resolve(__dirname, '..')`; the CI symlink
  is removed; a sweep cleared 33 occurrences across 18 files.
  **What prevents a relapse:** `scripts/audit-hardcoded-paths.sh` runs as CI
  Gate 0 and fails the build on any machine-specific absolute root. Derive
  instead — `$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)` in bash,
  `path.resolve(__dirname, '..')` in CJS, `Path(__file__).resolve().parents[N]`
  in python; `$HOME`, `~` and env overrides are fine. Full history in
  `knowledge/discoveries.md`.
- **"Re-fixing" a comment that documents a fixed bug.** Several files carry
  comment-only mentions of the old literal root (`deploy-langs.sh:8`, the
  `ci.yml` header, the audit script's own `PATTERN`). The audit strips
  comment-only lines for exactly this reason: documenting the bug is not the bug.
- **Editing generated site HTML by hand.** The site submodules are outputs of
  `_tools/gen/`; hand edits are lost on the next regeneration.
- **Faking an artifact when a tool is missing.** `deploy-langs.sh` warns and
  skips the PDF build when `pandoc`/`weasyprint` are absent — "never a faked
  artifact" (`_tools/deploy-langs.sh:46-49`). Gate 5 likewise degrades to a
  reasoned SKIP when poppler/tesseract are missing (`README.md:50-52`).

## Tooling / indexing

- **Indexing `_tests/evidence/` semantically.** Embedding it cost roughly 14 of
  the ~15 hours a full index needed and returned screenshots and run logs as
  search hits. Excluded via `.lumenignore`; everything else is still indexed.
- **`codegraph index` on an existing database.** It discards the existing DB —
  the wizard uses `codegraph sync` when `.codegraph/codegraph.db` exists and
  `codegraph init` when it does not (`docs/setup-agents-wizard/README.md`,
  step 7).

## Reporting

- **Treating the absence of a gate as a pass.** Stated twice, verbatim, in
  `CLAUDE.md:192-193` and at the end of `Constitution.md`.
- **Recording an undecided contradiction as an "override".** That would claim an
  authorization nobody gave (`Constitution.md`, "Open conflicts" preamble).
