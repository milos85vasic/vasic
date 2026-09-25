# Contract: daily re-measurement (`zero-gap-daily.sh` + systemd user units)

Install is an OPERATOR action (host configuration). Prepared, documented, not installed unasked.

`ops/systemd/zero-gap-daily.timer`: `OnCalendar=daily`, `Persistent=true`,
`RandomizedDelaySec=900`.
`ops/systemd/zero-gap-daily.service`: `Type=oneshot`, `MemoryMax=16G`, `CPUWeight=20`, `Nice=10`,
`IOSchedulingClass=idle`, `ExecStart=.../scripts/zero-gap-daily.sh`.

`zero-gap-daily.sh` MUST, in order:
1. take `flock` on a purpose-key file (§11.4.232(B): no two same-purpose runs); if held → exit 2 with
   "already running", never queue;
2. register the long-op BEFORE running (id, purpose_key, owner, pgid, log_path) and write a
   monotonic heartbeat; a no-progress budget kills a hung run and records `failed`;
3. check thread and memory headroom (§12.12/§12.6) and refuse (rc 2) if the host is already under
   pressure — a sweep must not become the incident;
4. fingerprint the tree; run the cheap subset, then the full set (`verify-check-registry.sh
   --run-proofs`, sweep, coverage, claim ledger, determinism sample); fingerprint again;
5. append sealed evidence records; write `.remember/logs/zero-gap/<date>.json`; on RED or STALE
   raise `notify-send`; for any closed item whose recorded check now fails, APPEND a reopen request
   (item id + the failing evidence reference) to `.remember/logs/zero-gap/reopen-queue.jsonl`. The
   register is NOT modified by the job; `gap apply-queue` applies the queue inside an explicit commit;
6. write the terminal state — one of §11.4.232(A)'s exact set `complete|failed|reaped|handoff|
   blocked-escape` — to the durable op registry `.remember/logs/zero-gap/ops-registry.jsonl`
   ({op_id, purpose_key, owner, pid|pgid, log_path, verdict, evidence_path}); success is read from
   that verdict, not from the process exit code.

It NEVER commits, never touches tracked files (including `docs/workable_items.db`), never restarts a service, never suspends the host
(CONST-033). If the moved-tree fingerprint differs it reports UNSTABLE and does not reopen or close
anything from that run. On demand: `bash scripts/zero-gap-daily.sh --now`.
