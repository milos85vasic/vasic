# Phase 0 Research: Live Corpus Promotion and Deploy Gate

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | Date: 2026-10-20

Method: read of `workshop/` at commit `33e9760` (scripts, compose, server source, gates). No live authenticated call and no build was run
in this authoring pass; everything needing one is `UNCONFIRMED` and carries a task.

## R-1 Where does "stale" come from? (root causes, not symptoms)

1. **Three artefacts, three lifecycles.** The server binary is rebuilt by `restart.sh` via `prepare_fresh_server` (`_common.sh:440-470`,
   with a dirty-input guard and a stamp). The Angular bundle is rebuilt **only** by `scripts/build.sh` (`build.sh:132-154`) — and `restart.sh`
   deliberately does not (`_common.sh:452-455`). The registry changes only by ingest tooling. So "restart" refreshes one of three things.
2. **Nothing compares them.** `verify-build-identity.sh` grades the binary (B1) and `/api/health` (B2); no instrument looks at the bundle or the
   registry digest (spec.md B8). The stamp (`commit=ce62bcb…`) and the bundle mtime (Oct 7) are both observable and nobody reads them together.
3. **The browser cannot tell.** The Status page reports `web: true/false` only (`status.component.ts`).

## R-2 Bundle promotion: in place, additive, no restart — and why not the alternatives

**Finding.** `webHandler` opens files from `cfg.webDir` on every request, serves hashed assets `immutable`, other files `no-cache`, `index.html`
`no-store` (`main.go:2739-2790`). Therefore a safe in-place promotion exists: put new content-hashed chunks into the directory (no name collision
by construction), then `rename(2)` a staged `index.html` over the old one, then — much later — delete old chunks.

**Decision.** `promote-web.sh --promote` = additive chunks → atomic `index.html` → `build-info.json`; `--prune` after a grace period; `--rollback`
from `web.prev/` (a copy of the old `index.html`/`build-info.json`, old chunks are still present until pruned).

**Rejected.**
- *Replace the directory* (`mv web web.old; mv web.new web`): the compose bind mount pins the directory inode at container start (`compose.yml:645`),
  so the container keeps serving the *old* directory until restart. Correct only inside a restart window.
- *`build.sh`'s `rm -rf web/*; cp -a`*: leaves a window with `webServable` false (placeholder served) and, mid-copy, an `index.html` that references
  absent chunks. Recorded as a finding; not edited here (it is the operator's full-build entry point and out of scope).
- *Restart for every frontend change*: a ~45-minute boot (`restart.sh` header) to ship CSS is disproportionate.
**Verification.** T003 proves headers/behaviour on an isolated server; if (c)/(d) fail, the design falls back to swap-at-restart for all promotions.

## R-3 Registry promotion: why rename, why a superset check, why a journal

**Finding.** The registry is rewritten whole by the ingest library (sorted by pid, normalised whitespace — `architecture.md` §3.2 step 2 note)
and loaded once at boot. A new registry is only seen after restart, and a *partial* file at boot would be loaded as the registry.

**Decision.** `promote-registry.sh`: (1) the candidate must be a **superset** — every current line byte-identical; (2) real-copy backup with pre-digest;
(3) write candidate to a temp file in the same directory and `rename(2)` (atomic on one filesystem, new inode inside the bind-mounted directory —
the directory mount is unaffected, spec.md B6); (4) journal row with `prev_sha256` chain; (5) restart is a separate, gated step.
**Why a superset rule:** the re-serialisation drift risk. If an ingest changes existing lines, that is a *finding*, not an expected diff, and needs a
stated `--allow-changes` reason (matches `architecture.md` §3.2 "if existing lines differ after a no-op sync that is a finding, STOP").
**Why a chain:** §11.4.268 asks that deletion/reordering/truncation of an evidence ledger be detectable; this ledger is small and the clause is
applied to it only (the clause itself says the covered set is per-project data).

## R-4 What the gate compares, and over which independent channel

| Check | Producer (what is measured) | Oracle (independent) |
|---|---|---|
| G1 commit | `/api/health` `source_commit`, `source_dirty` (server) | `git rev-parse HEAD` + `git diff --name-only` classified against the input set (host) |
| G2 bundle | `provenance.web.manifest_sha256` (server, from the mounted dir) | `GET /` sha vs built `index.html` sha (over the wire) **and** `bundle-manifest.sh dist` (host) |
| G3 registry | `provenance.registry.loaded_sha256` (process) | host `sha256sum`, container `sha256sum` via runtime exec |
| G4 index | `index.pid_count` (DB) | `wc -l` of the registry |
| G5 coherence | `web.build_info.commit` | `source_commit` |
| G6 corpus | `corpus.total`, `by_content_type` sum | python count over the registry |

A single-channel check can be wrong in the same way as the thing it checks (the very lesson of `verify-build-identity.sh`'s header); every
G-check therefore has a second channel.

## R-5 Strict vs classified commit equality (D1)

`HEAD` moves with every evidence, docs and spec commit (e.g. `33e9760` is a pure evidence commit). Strict equality would force a rebuild and a
~45-minute restart per such commit and teach the operator to ignore the gate. The input set is already derived once for the freshness guard
(`_server_inputs_state`, `_common.sh:633`): backend module + every `replace` target + every `go:embed`'d file. The gate reuses that derivation
(not a hand-written list) so "input-relevant" has one definition.

## R-6 Reproducibility of the Angular build (D4)

Content-hashed filenames are stable only if inputs and toolchain are. `npm ci` against the lockfile is the standard route; whether this
workspace yields byte-identical output twice is **UNCONFIRMED** — T004 measures. If not reproducible, comparing "served vs freshly built" would
false-fail on every run, so G2 falls back to "served vs recorded promotion manifest" and the reproducibility gap is reported (§11.4.246 note).

## R-7 Progressive delivery (§11.4.265)

The deployment is one local container started by `restart.sh`; there is no traffic split to shift. The clause is conditional on a traffic-shiftable
deploy, so the strategy is recorded **latent** with an honest skip rather than claimed. The bundle's additive promotion gives an analogous, smaller
property (old and new chunks coexist; instant rollback by restoring `index.html`).

## R-8 Container-side digest without inventing a runtime detector

§11.4.76 forbids re-implementing runtime detection in a consumer. The repo already resolves a runtime for `status.sh`/`stop.sh` (`workshop-boot`,
`_common.sh`); T023 reuses that. Where the digest of a file *inside* the container cannot be taken through the module, the fallback is the resolved
runtime's `exec` with an explicit rc 2 if unresolved — and the finding is recorded for the containers module owner.

## R-9 Deep research (§11.4.150)

Topics for the T001 research note (executed at implementation time, sources recorded): atomic static-asset deploys for SPAs (asset-first/index-last,
immutable caching), content-addressed manifests, reproducible JS builds (lockfile discipline, `SOURCE_DATE_EPOCH`), deploy gates binding artefact
digests to verdicts (SLSA provenance attestation shapes), hash-chained journals. No external tool was used while authoring this spec; nothing in
the design depends on an unverified external claim.
