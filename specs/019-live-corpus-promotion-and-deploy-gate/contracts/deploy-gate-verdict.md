# Contract: Deploy Gate and Verdict

**Implements**: FR-007..FR-010, FR-013 | **Script**: `workshop/scripts/deploy-gate.sh` (NEW) | **Gate wrappers**:
`platform/gates/verify-live-equals-built.sh`, `prove-live-equals-built-mutation.sh`

## CLI

```text
scripts/deploy-gate.sh [--pre|--post] [--base URL] [--evidence DIR] [--strict] [--quick]
```
- `--pre` (default before a deploy/hand-off): validates the **candidate** artefacts (binary stamp, staged bundle, candidate registry) and writes the fingerprint.
- `--post`: validates that what is **served/running** equals what was built (all checks below).
- `--strict`: commit equality is exact (D1 off). `--quick`: skips the container exec and the full re-hash (used by `live-drift.sh`, 5 s budget).
- Credential via `scripts/_live_auth.sh`; the token is never printed or written.

## Exit contract *(three-valued; 2 is never a pass)*

`0` PASS · `1` FAIL (at least one check rc 1) · `2` UNDETERMINED (no check failed but at least one could not be determined: stack down, no token, no
container runtime, unreadable file, git unavailable). If a check is 1 and another is 2 the exit is 1 and both are listed.

## Checks

| id | name | PASS when | FAIL (rc 1) | UNDETERMINED (rc 2) |
|---|---|---|---|---|
| G0 | tree quiescent and clean | `git status --porcelain` of `workshop` empty on two reads 30 s apart (`ws_git_quiescent`) | tree dirty | cannot read git state |
| G1 | commit identity | `/api/health.source_commit == HEAD` and `source_dirty == false`; or `!=` with **no** compiled-input path in `git diff --name-only source_commit..HEAD` (D1 default: `NOTE`) | dirty; or input-relevant diff; (`--strict`: any difference) | health unreachable; `source_commit` empty; commit not in object store |
| G2 | bundle identity | `sha256(GET /)` == `sha256(dist/index.html)`, `provenance.web.manifest_sha256` == `bundle-manifest.sh dist` (or == recorded promotion manifest when the build is not reproducible, D4) | any mismatch | no dist, no promotion record, endpoint unavailable |
| G3 | registry digest | host `sha256sum` == container `sha256sum` == `provenance.registry.loaded_sha256` == `provenance.registry.disk_sha256` | any inequality (message names which pair; "bind mount pinned to an old inode" when host ≠ container) | no runtime, container absent, file unreadable |
| G4 | index coverage | `index.pid_count == wc -l registry` and generation `state` live | unequal | `index/status` 503 |
| G5 | frontend/backend coherence | `web.build_info.commit == build.source_commit` (or equal under the D1 classification) | different builds | `build_info` absent (older bundle) is **FAIL** `no_build_info`, not 2 |
| G6 | corpus reconciliation | `corpus.total == wc -l registry`; `by_content_type` sums to total and equals the independent python count | unequal | python/registry unreadable |
| G7 | verdict binding | (`--pre` only) the candidate fingerprint was computed from files that still exist and match | changed since computed | files unreadable |

## Verdict schema

`data-model.md` §5. Written to `<evidence>/verdict.json` with mode 0600; no token, no URL with credentials, no passage text.

## The mechanical seam (§11.4.236)

`restart.sh --require-verdict <file>`, `promote-web.sh --promote --require-verdict <file>`, `promote-registry.sh --apply --require-verdict <file>`
recompute the fingerprint and **refuse (rc 2)** when: the file is absent; not parseable; `verdict != "PASS"`; `mode != "pre"` for pre-deploy use; or any
fingerprint component differs from the recomputed value. `--override-verdict "<reason>"` is accepted only with a non-empty reason and writes an `override`
row to the journal. Default-on for `restart.sh` is decision D2.

## Mutation proof

Gate mutants M1-M6 (spec tasks T025): each must make the gate or its test suite fail.
