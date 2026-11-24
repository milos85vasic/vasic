# Operator decision: submodules/doc_processor tracks `master`; the divergent HelixDevelopment mirror is a declared exemption

| Field | Value |
|---|---|
| Date | 2026-11-24 |
| Decision source | Operator, housekeeping order of 2026-11-24 |
| Anchors | §11.4.299 (every declared upstream read back), §11.4.66, §11.4.6, §11.4.113 |
| Pin | `submodules/doc_processor` at `12a5fb76381a6bb9a1a668c67211ff073967ea44` (unchanged) |

## Decision

1. `submodules/doc_processor` DECLARES `branch = master` in `.gitmodules`. Its upstream (`vasic-digital/DocProcessor`)
   has no `main`; `master` is its only branch and equals the pin on both vasic-digital hosts and on
   `helixdevelopment1/docprocessor` (measured with `git ls-remote` 2026-11-24).
2. `HelixDevelopment/DocProcessor` carries a `main` at `86f1a98350b8` that is not a descendant of the pin (measured
   DIVERGED). It is recorded as a declared mirror exemption in `config/upstream-parity-exemptions.tsv`, with this note as
   the reason's source. **Nothing is pushed to any doc_processor repository**; no force, no history rewrite.

## How the verifier honours it

The constitution's instrument `verify_upstream_parity.sh` takes ONE `--branch` for a whole fleet and is upstream code in
a submodule, so it was not edited. `scripts/verify-upstream-sync.sh` now reads each top-level submodule's declared
`branch` from `.gitmodules`; a submodule declaring a branch other than `main` is left out of the fleet pass (printed as a
NOTE) and verified in its own pass with `--branch <declared>`. Result with the declaration: the three vasic-digital /
helixdevelopment1 upstreams read CURRENT on `master`, the exempt mirror reads EXEMPT with its reason, exit 0, instead of
NO-BRANCH x2 and DIVERGED. Paired proof: `--prove-failure` still 66 pass / 0 fail.

## Honest boundaries (§11.4.6)

* The exemption row exempts that mirror URL for the whole submodule check, so its `master` (currently equal to the pin)
  is no longer read back either. The operator asked for the exemption explicitly; if that coverage matters, remove the row
  and the mirror reads CURRENT on `master`, with its `main` simply no longer examined.
* `helix-deps.yaml` has no `branch` key in its schema and none was invented; its `ref` comment already says the gitlink
  tracks `heads/master`.
* The wrapper handles top-level submodules only; no nested submodule declares a non-`main` branch today.
