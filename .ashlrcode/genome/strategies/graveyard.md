# Strategy Graveyard

Failed approaches and why they didn't work.

## Semantic-indexing `_tests/evidence/`

- **Tried:** running `lumen index .` over the whole tree, evidence included.
- **Result:** 4,526 tracked evidence files (1,353 json, 1,167 txt, 1,142 png,
  515 log) against only 95 real source files in all of `_tests/`. Embedding them
  consumed roughly **14 of the ~15 hours** the index needed, and searches
  returned screenshots and run logs instead of answers.
- **Now:** `_tests/evidence/` is listed in `.lumenignore`. Everything else —
  all source, all submodules, all docs — is still indexed. Reversible: delete
  the line and re-run `lumen index .`.
- **Source:** `.lumenignore` header comment.

## Recursive submodule checkout

- **Tried:** `submodules: recursive` in CI / `--recursive` locally.
- **Result:** known failure. `milosvasic.ru` embeds `red-elf/Upstreamable`,
  whose `.gitmodules` is a broken 0-byte gitlink.
- **Now:** init only `vasic.digital` and `milosvasic.ru`, non-recursively.
  `milosvasic.ru/.github/workflows/pages.yml` sets `submodules: false` for the
  same reason, and Upstreamable is excluded from the Jekyll build via
  `milosvasic.ru/_config.yml` `exclude:`.
- **Source:** `README.md:34-40`; `.github/workflows/ci.yml` header, deviation (a).

## Re-style candidates rejected at v1.6.0

Both sites were generated as two distinct candidates; Candidate A shipped on
each. The rejected alternates are **retained as re-appliable drop-ins**, with
their fonts already deployed — parked, not deleted:

- `vasic.digital` — **"VOLTAGE"** (Fraunces serif / frosted glass). Shipped
  instead: **"MACHINA"**.
- `milosvasic.ru` — **"LUMINOUS CRIMSON GLASS"** (Fraunces serif / glass).
  Shipped instead: **"TERMINAL BRUTALIST"**.

Rollback restore points recorded at the time: vasic `v1.5.0`, milos `v1.5.2`,
umbrella `pre-restyle` (the tag still exists, 2026-08-07).
**Source:** `_analysis/CHANGELOG.md`, v1.6.0 entry; full detail in
`_analysis/RESTYLE-v1.6.0.md`.
