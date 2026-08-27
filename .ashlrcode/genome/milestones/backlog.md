# Milestone Backlog

Ordered by the strength of the evidence behind each item. Every entry below is
something the repository already names as remaining work — nothing here is
speculative roadmap.

Item numbers are **stable identifiers**, not positions: when an item closes it
moves to "Closed" at the foot of this file and its number is retired, leaving a
gap in the open list. A gap therefore means *done*, never *missing*.

## 1. ~~Resolve the two §11.4.156 CI conflicts (OC-1, OC-2)~~ — DECIDED 2026-08-27, partly closed

~~Operator decision, blocked on G5. Root `.github/workflows/ci.yml` and
`milosvasic.ru/.github/workflows/pages.yml`. Three permitted resolutions are
enumerated in `Constitution.md` OC-1; an agent may not pick one.~~

**Decided; not a backlog item any more.** Two corrections to the text above:
the *"three permitted resolutions"* were only two — an `Override §11.4.156` does
not exist (§11.4.156 refuses the exemption vocabulary by name, and a consumer
carrier may only extend inherited rules) — and the outcome differs per file.

- **OC-1 — DONE.** `.github/workflows/ci.yml` → `ci.yml.disabled`; gates run from
  `scripts/pre-push-gates.sh` via an installed `.git/hooks/pre-push`. The G5
  precondition was satisfied by the same work.
- **OC-2 — WILL NOT BE DONE.** `milosvasic.ru/.github/workflows/pages.yml` is
  **ACTIVE and stays active**: `build_type: "workflow"` makes it the sole publish
  path for the live production site. Operator directive: *"Make sure all pages
  websites work flawlessly! No website can be broken! All websites we have here
  are running deployed in production!"* Recorded as a **documented deviation, not
  an override**.
- **OC-2b — no remedy exists.** `vasic.digital` triggers `pages build and
  deployment` on every push from its Pages source setting (`build_type: "legacy"`)
  with zero workflow files in its tree.

Never propose disabling `pages.yml`, and never write either deviation up as an
`Override §11.4.156`. Record:
`docs/constitution-adoption/DECISION-11-4-156-COMPLY.md` §0.

## 2. Stand up the §11.4.75 five-layer local enforcement (gap G5)

The commit wrapper is in place; **git hooks are not**. The only non-sample hook
at this root is the `ashlr` genome `post-commit` watcher, which is not a
governance layer. This is the prerequisite for item 1.

## 3. Write `scripts/verify-governance-cascade.sh` (OC-3, gap G3)

§11.4.32 step 1 currently reports SKIP-with-reason and never counts as a pass.

## 4. Apply the staged carriers to the owned submodules (gap G7)

Drafts exist for all five owned submodules under
`docs/constitution-adoption/propagation/`. Submodule-first, operator-applied,
per `APPLY.md`. Closing this removes the one *owned* carrier
(`vasic.digital/QWEN.md`) from the propagation gates' MISSING list.

## 5. Wire the `PreToolUse` forbidden-command guard (gap G12)

`submodules/constitution/scripts/hooks/guard-forbidden-commands.sh` is present
and connected to nothing.

## 6. Close `CM-OPENDESIGN-UI-SYSTEM` (`_tests/GATES.md`)

Three named sub-items, all currently absent:
- a self-validated analyzer with golden-good/golden-bad proving the token check
  can FAIL;
- a lint proving **zero** non-token colour/space literals across CSS and inline
  styles;
- consuming OpenDesign as an external dependency rather than as generated output.

## 7. Complete §4 tag mirroring (gap G10)

`v1.8.0` reached `milosvasic.ru` and `vasic.digital` only. `ai_interviewing` and
`monetization` have **no reachable tag** at their pinned commits.

## 8. §11.4.65 markdown exports (gap G8)

No `.html`/`.pdf` siblings anywhere — `Constitution.md` and
`docs/constitution-adoption/README.md` each disclose the deviation about
themselves at the top of the file.

## 9. De-duplicate the `design-toolkit` checkout (gap G11)

Declared in `helix-deps.yaml`; two checkouts, shas matching at capture time.

## 10. Add a root `CONTINUATION.md` (§12.10)

`CLAUDE.md:189-190` records its absence; the restated rule currently describes a
universal obligation with no artifact behind it here.

## 12. Reconcile the `milosvasic.ru` fetch/push asymmetry

Operator decision — either add `milosvasic.ru.git` to `origin`'s push list, or
repoint the fetch URL and the `.gitmodules` entry at `milosvasic.net.v2`.
Full hazard write-up in `Constitution.md`; summary in `knowledge/workspace.md`.

## 13. Fix the §11.4.212 README-orphan (gap G9)

`README.md` links to nothing but the CI badge, while a substantial documentation
tree exists under `docs/` and `_analysis/`.

---

## Closed

### ~~11. Repair the two hardcoded absolute build paths~~ — **DONE 2026-08-27**

Closed against live files, not against a claim:

- `_tools/deploy-langs.sh:14` derives the root —
  `ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"` — and line 15
  makes the `cd` **fatal**, which also closes the silent-failure half of the bug
  (the script runs `set -uo pipefail` without `-e`). Line 8 is now a comment
  recording the history.
- `_tests/playwright.config.js:7` — `const REPO = path.resolve(__dirname, '..');`;
  no machine-specific literal remains in the file.
- `.github/workflows/ci.yml:44-52` and `:182-184` — the symlink workaround that
  this item called "deliberate" has been **removed**, and both notes are phrased
  as history.
- The sweep removed **33 occurrences across 18 files**.
- Relapse guard: `scripts/audit-hardcoded-paths.sh` runs as CI **Gate 0**
  (`.github/workflows/ci.yml:131-140`), exits non-zero on any machine-specific
  absolute root, and currently exits 0 on this tree.

Narrative in `knowledge/discoveries.md`; prevention rule in
`vision/anti-patterns.md`.
