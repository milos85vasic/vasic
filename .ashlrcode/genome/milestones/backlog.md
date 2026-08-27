# Milestone Backlog

Ordered by the strength of the evidence behind each item. Every entry below is
something the repository already names as remaining work — nothing here is
speculative roadmap.

## 1. Resolve the two §11.4.156 CI conflicts (OC-1, OC-2)

Operator decision, blocked on G5. Root `.github/workflows/ci.yml` and
`milosvasic.ru/.github/workflows/pages.yml`. Three permitted resolutions are
enumerated in `Constitution.md` OC-1; an agent may not pick one.

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

## 11. Repair the two hardcoded `/Volumes/T7/...` paths

`_tools/deploy-langs.sh:8` and `_tests/playwright.config.js`. CI symlinks around
them deliberately ("out of scope for this task"); the workaround is documented,
not fixed. See `knowledge/discoveries.md`.

## 12. Reconcile the `milosvasic.ru` fetch/push asymmetry

Operator decision — either add `milosvasic.ru.git` to `origin`'s push list, or
repoint the fetch URL and the `.gitmodules` entry at `milosvasic.net.v2`.
Full hazard write-up in `Constitution.md`; summary in `knowledge/workspace.md`.

## 13. Fix the §11.4.212 README-orphan (gap G9)

`README.md` links to nothing but the CI badge, while a substantial documentation
tree exists under `docs/` and `_analysis/`.
