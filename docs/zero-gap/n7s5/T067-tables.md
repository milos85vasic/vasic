# T067 — SC-006 / SC-007 / SC-008 across the tree (stream S5, 2026-10-21)

Producer-prepared; PENDING-INDEPENDENT-REVIEW. Environment: a linked git worktree WITHOUT the submodules (gitlinks must not be touched), so many checks answer rc 2 "cannot determine" here; the tables say so instead of hiding it.

## SC-006 — five identical outcomes per check

Command: `bash scripts/zero-gap-determinism-registry.sh --runs 5 --timeout 45` (frozen real copy). Result file: `docs/zero-gap/determinism-registry.tsv`, run log `docs/zero-gap/n7s5/T064-census-run.txt`.

| Measure | Value |
|---|---|
| registered checks | 67 |
| STABLE (5 runs, one verdict) | 47: 10 at rc 0, 6 at rc 1, **31 at rc 2** (cannot determine in this worktree: submodules / tools absent -- stable but not informative) |
| UNSTABLE | **0** (`docs/zero-gap/unstable-checks.tsv` is empty) |
| NOT-RUN (denylist, reasons in `docs/zero-gap/check-denylist.tsv`) | 16 |
| TIMEOUT (45 s, no verdict) | 4: name-in-path, fleet-summary, zero-gap-sweep, zero-gap-determinism |
| output text varies with an identical verdict | 1 (content-boundary) |
| verdict | **rc 2: the census is incomplete (20 checks not run to completion). SC-006 is NOT met**: 16 checks have a decisive, repeated verdict |

## SC-007 — every check has a paired proof

| Command | Output |
|---|---|
| `bash scripts/verify-check-registry.sh` | `CM-CHECK-REGISTRY: 160 PASS, 0 FAIL, 0 DEBT, 0 UNDET` -- STRUCTURE only: "no paired proof was EXECUTED" (the script says so) |
| `bash scripts/verify-check-registry.sh --run-proofs` | NOT run by this stream (about an hour; needs the submodules). Executed proofs by this stream: scan-records (15 cases), daily (17), determinism-registry (6), seal-checks (6), module-page-check (8), pre-push-gates (S0-S4b + 9 mutations), evidence adapter (37 passed / 0 failed) |
| `bash scripts/zero-gap-class-unproven-checks.sh --root .` | rc 1, 128 findings (incl. exempt rows of fixture sub-registries and planted corpora) -- not triaged |

SC-007 holds structurally; the executed-proof half is not demonstrated by this stream.

## SC-008 — records are clean

| Command | Output |
|---|---|
| `bash scripts/zero-gap-scan-records.sh docs/zero-gap specs/010-zero-gap-verified-closure --private-root <main checkout>/workshop/chapters` | `INSPECTED 2xx ... VERDICT HOLDS (rc 0)` (guessing / credential / private layers) |
| same without a private source | `VERDICT UNDETERMINED (rc 2)` -- by design |
| "zero unmeasured assertions" | NOT shown: `verify-claim-ledger.sh --completeness` reports 344 figures / 12 badges over 12 registered rows |
