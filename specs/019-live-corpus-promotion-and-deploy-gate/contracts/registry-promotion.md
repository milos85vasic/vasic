# Contract: Registry and Bundle Promotion Procedure

**Implements**: FR-001, FR-002, FR-011 | **Scripts**: `scripts/promote-registry.sh`, `scripts/promote-web.sh` (NEW)

## Registry: `promote-registry.sh --candidate <file> [--sidecars <dir>] (--apply | --rollback <run> | --status [--verify])`

```text
1. preconditions   WORKSHOP_ORCH=1 for --apply/--rollback; tree quiescent (two reads); long-op owner for purpose_key registry-promote is us; rc 2 otherwise
2. validate        candidate parses as JSONL; every line valid JSON; `registry-restamp-content-type -check -registry <candidate>` rc 0;
                   rows_candidate >= rows_live;  every live line is present byte-identical in the candidate (superset)  -> else rc 1 (unless --allow-changes "<reason>")
3. no-op           sha256(candidate) == sha256(live) -> rc 0 "already promoted"; no write, no backup, no journal row
4. gate (pre)      --require-verdict <file> when D2/flag demands it
5. backup          REAL COPY  .backups/passages.jsonl.pre-<run>  (cp, never ln); sha256 recorded BEFORE any write; sidecars copied alongside
6. swap            write candidate to <dir>/.passages.jsonl.tmp.<pid> ; fsync ; rename(2) over the live file (same filesystem, same directory)
7. verify          platform/gates/verify-backup-distinctness.sh --backup … --source <live> --digest <pre> ; sha256(live) == sha256(candidate)
8. journal         append row (data-model §6) with prev_sha256 chain
9. report          counts only: rows_before/after, added, changed_existing=0, backup path, pre/post sha
   (restart is a SEPARATE, gated step; the new registry is not visible to the running server until it)
--rollback <run>   copy backup back via temp+rename ; assert sha256(live) == recorded pre_sha256 ; journal ; (restart separate)
```
Interruption at any numbered step leaves the live file entirely old or entirely new (tested by SIGTERM chaos). Concurrent runs: second refuses (rc 2).

## Bundle: `promote-web.sh --build | --stage | --promote | --prune | --rollback | --status`

```text
--build     npm ci && npx ng build --configuration production   (agent-admit.sh -m 6G -T 1800)  -> frontend/dist/**
--stage     verify index.html exists and every chunk it references exists; write build-info.json; compute manifest -> platform/web.next/
--promote   1. copy NEW hashed chunks into platform/web/   (names do not collide; existing names skipped after hash check)
            2. copy old index.html + build-info.json -> platform/web.prev/
            3. rename(2) staged index.html over platform/web/index.html
            4. write build-info.json (rename)
            5. journal row ; manifest recorded in evidence
--prune     delete chunks not referenced by the current index.html AND older than the recorded grace period
--rollback  rename web.prev/index.html back ; restore build-info ; journal ; old chunks still present until pruned
```
Never `rm -rf` the served directory. Same bundle twice -> rc 0 "already promoted". Directory replacement is used **only** inside a restart window (compose pins the
mount inode).

## Order of operations for a data release (what 018/020 call)

`deploy-gate.sh --pre` → `promote-registry.sh --apply --require-verdict` → (`promote-web.sh --promote` if the UI changed) → `restart.sh --require-verdict` →
wait for boot (measure) → `deploy-gate.sh --post` → evidence + UI acceptance.
