# Closure wave 2026-10-08: research note (section 11.4.150)

Scope: VSC-382, VSC-383, VSC-372, VSC-374, VSC-381, VSC-364, VSC-363. Written by the independent reviewer
(actor `reviewer-indep-closure-wave-r1`) from sources actually read in this review. No web source was consulted;
every source is a path in this repository. Nothing here is a claim about code not read.

## Sources consulted

- `docs/zero-gap/CLOSURE.md` (closure bar, review, research_ref, per-item loop).
- `specs/010-zero-gap-verified-closure/contracts/register-cli.md` (gap verdict / gap close contract).
- `_tools/workable-items/internal/wi/validate_gap.go` rule V-G3 (what a closed item must carry) and `gapcmd.go` `gapClose`.
- `submodules/constitution/Constitution.md` anchors 11.4.142, 11.4.150, 11.4.209, 11.4.240.
- Each item's `docs/zero-gap/checks/VSC-NNN.check`, its probe script, the working-tree diff of the fix, and the
  sealed RED and GREEN records in `.remember/logs/zero-gap/evidence/sidecar.jsonl`.

## Per item: alternatives considered and why the fix is right

- VSC-382 (stale helper binaries): existence-only guard replaced by a `-newer` staleness test at the three cited
  sites. Alternative: always rebuild (rejected: cost on every gate run). Right because it rebuilds exactly when a source
  file is newer than the binary.
- VSC-383 (golden PDF fixtures built only when absent): `build-fixtures.sh` newer than a PDF now forces a rebuild.
  Alternative: compare `make-image.js` too (rejected in the code comment: a fresh checkout writes it after fixtures).
- VSC-372 (in-tree tracked symlinks reported COULD-NOT-INSPECT): the class resolves an in-tree link to a regular
  file of the same repository and scans the target once; dangling, out-of-tree and cross-repository links stay
  COULD-NOT-INSPECT. Alternative: follow every symlink (rejected: a link can leave the tree or point at a FIFO).
- VSC-374 (tracked executables outside every scanroot): the aggregator gets a paired `--prove-failure` and a
  registry check row; scripts that are themselves proofs, generators or recipes get reasoned `exempt` rows.
  Alternative: declare `_tests` a scanroot (rejected by the item author, not re-decided here).
- VSC-381 (coverage map absent): `docs/zero-gap/coverage.tsv` exists and the coverage-gaps class inspects every cell.
- VSC-364 (argv policy misses percent-encoded names and five name shapes): decode `%HH` (twice) before judging and
  treat the segments auth, creds and pat as secret-shaped. Alternative: blanket refusal of `-a` style flags (rejected
  in the policy header as too broad).
- VSC-363 (six deferred T008 cases): one RED-first Go test per case, fix per case; `openat2` no-symlink open with a
  non-linux fallback file.

## Residuals, stated rather than hidden

- VSC-372, VSC-374, VSC-363, VSC-364: the fix is in the working tree, uncommitted at review time; the GREEN records are
  of the working tree, not of a commit.
- Chain binding (T068) is not in place; digests are self-recorded (progress.yml, T009 residual).
