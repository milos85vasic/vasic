#!/usr/bin/env bash
# scripts/zero-gap-daily.sh — feature 010 daily re-measurement job (task T069, FR-019,
# contract specs/010-zero-gap-verified-closure/contracts/daily-job.md).
#
# It re-measures the umbrella against a FROZEN REAL COPY of the tree and reports. It NEVER
# commits, never writes a tracked file (the register docs/workable_items.db included), never
# restarts a service, never suspends the host (CONST-033). Install of the systemd timer is an
# OPERATOR action (ops/systemd/, T070/T072); this script is runnable on demand: --now.
#
# ORDER (daily-job.md):
#   1 flock a purpose-key file (§11.4.232(B)); held => rc 2 "already running", never queued, nothing
#     registered.
#   2 register the long-op in the durable ops registry BEFORE running it (op_id, purpose_key, owner,
#     pgid, log_path), write a monotonic heartbeat; a no-progress budget reaps a hung step (its own
#     process group only, §11.4.263) and records it failed.
#   3 refuse (rc 2) when the host is already under pressure (§12.6 memory, §12.12 threads, load).
#   4 take a frozen REAL COPY (rsync -a --files-from; NEVER hardlinks: gates rewrite tracked evidence
#     files in place, a hardlink snapshot would write through into the live tree), fingerprint the live
#     tree before and after, run every step INSIDE THE COPY. Scope: the umbrella's own tracked +
#     untracked-not-ignored files; gitlinks (submodules) are not copied, so a step that needs
#     submodule content reports that it could not run (rc 2) rather than passing.
#   5 every step is run through the evidence ADAPTER (sealed record per step) -- no adapter => rc 2;
#     write <state>/<date>.json; notify on RED or STALE; for each closed item whose recorded check
#     (docs/zero-gap/checks/<ID>.check, field cmd=) now fails APPEND a reopen request to
#     <state>/reopen-queue.jsonl. The register is not touched; `gap apply-queue` applies the queue
#     inside an explicit commit.
#   6 write the terminal state (complete|failed|reaped|handoff|blocked-escape, §11.4.232(A)) and the
#     verdict to <state>/ops-registry.jsonl. Success is read from that verdict, not from the exit code.
# If the live tree moved while the job ran (fingerprint or `git status --porcelain` differs) the run
# is UNSTABLE: nothing is reopened from it.
#
# USAGE   zero-gap-daily.sh [--now] [--cheap] [--root DIR] [--state-dir DIR] [--noprogress SEC]
#         zero-gap-daily.sh --prove-failure
#   --cheap       structure-only subset (registry, claim ledger, record scan, closed-item re-checks)
#   default/--now the full set (adds the check-registry --run-proofs, sweep, coverage, determinism sample)
# ENV     ZG_STATE_DIR (default <root>/.remember/logs/zero-gap, MUST be git-ignored), ZG_EVIDENCE
#         (adapter), ZG_DAILY_STEPS_FILE (name<TAB>command lines replacing the built-in steps; used by
#         the proof), ZG_DAILY_MAX_MEM_USED_PCT (60), ZG_DAILY_MAX_LOAD_FACTOR (1.5 x nproc),
#         ZG_DAILY_MAX_THREADS (20000), ZG_NOTIFY_CMD (notify-send), ZG_DAILY_STALE_HOURS (36).
# EXIT    0 every step holds and the tree was stable; 1 at least one step or closed-item check is
#         violated (RED); 2 could not determine (already running, host pressure, no adapter, a step
#         that could not run or was reaped, UNSTABLE).
# HONEST LIMIT  The adapter's per-record state fingerprint is taken over a small fixed anchor
#         repository (<state>/fp), because the steps legitimately rewrite files in the copy; stability
#         of the LIVE tree is the job's own before/after check, not the adapter's.
set -uo pipefail
export LC_ALL=C LANG=C

HERE=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT="" STATE="" MODE=full NOPROG=1800 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --now) shift ;;
        --cheap) MODE=cheap; shift ;;
        --root) ROOT=${2:-}; shift 2 ;;
        --state-dir) STATE=${2:-}; shift 2 ;;
        --noprogress) NOPROG=${2:-}; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        *) echo "zero-gap-daily: unknown argument '$1'" >&2; exit 2 ;;
    esac
done

say() { printf 'zero-gap-daily: %s\n' "$*" >&2; }

# ---------------------------------------------------------------- helpers
json_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

host_pressure() { # prints reason and returns 1 when the host is under pressure
    local mt ma used_pct load1 nproc thr
    mt=$(awk '/^MemTotal:/{print $2}' /proc/meminfo); ma=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    if [ -z "$mt" ] || [ -z "$ma" ] || [ "$mt" -le 0 ]; then echo "cannot read /proc/meminfo"; return 1; fi
    used_pct=$(( (mt - ma) * 100 / mt ))
    if [ "$used_pct" -gt "${ZG_DAILY_MAX_MEM_USED_PCT:-60}" ]; then echo "memory used ${used_pct}% > ${ZG_DAILY_MAX_MEM_USED_PCT:-60}% (§12.6)"; return 1; fi
    load1=$(awk '{print $1}' /proc/loadavg); nproc=$(nproc 2>/dev/null || echo 1)
    if awk -v l="$load1" -v n="$nproc" -v f="${ZG_DAILY_MAX_LOAD_FACTOR:-1.5}" 'BEGIN{exit !(l > n*f)}'; then echo "load1 $load1 > ${ZG_DAILY_MAX_LOAD_FACTOR:-1.5} x $nproc cpus"; return 1; fi
    thr=$(awk '{split($4,a,"/"); print a[2]}' /proc/loadavg)
    if [ "${thr:-0}" -gt "${ZG_DAILY_MAX_THREADS:-20000}" ]; then echo "threads $thr > ${ZG_DAILY_MAX_THREADS:-20000} (§12.12)"; return 1; fi
    echo "mem_used=${used_pct}% load1=$load1/$nproc threads=$thr"; return 0
}

status_sha() { git --no-optional-locks -C "$1" status --porcelain=v1 --ignore-submodules=none -z 2>/dev/null | sha256sum | cut -d' ' -f1; }

live_fp() { # fingerprint of the live tree via the shared library (rc 2 when it cannot)
    ( . "$HERE/zero-gap-lib.sh" && zg_fingerprint "$1" ) 2>/dev/null | head -1 | cut -d' ' -f1
}

# ---------------------------------------------------------------- the run
run_daily() {
    local OP_ID LOG REG REPORT QUEUE LOCKF COPY STEPS i rc
    [ -n "$ROOT" ] || ROOT=$(cd "$HERE/.." && pwd)
    ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || { say "root absent"; return 2; }
    git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { say "root is not a git work tree"; return 2; }
    [ -n "$STATE" ] || STATE=${ZG_STATE_DIR:-$ROOT/.remember/logs/zero-gap}
    mkdir -p "$STATE" || { say "cannot create $STATE"; return 2; }
    STATE=$(cd "$STATE" && pwd)
    # the job writes only here: refuse when a tracked file could be hit
    if git -C "$ROOT" ls-files --error-unmatch -- "$STATE" >/dev/null 2>&1 ||
       { case "$STATE" in "$ROOT"/*) ! git -C "$ROOT" check-ignore -q -- "$STATE/.probe" ;; *) false ;; esac; }; then
        say "state dir $STATE is inside the repository and not git-ignored; refusing (the job never writes tracked or trackable files)"; return 2
    fi
    LOCKF="$STATE/daily.lock"; REG="$STATE/ops-registry.jsonl"; QUEUE="$STATE/reopen-queue.jsonl"
    exec 9>"$LOCKF" || { say "cannot open $LOCKF"; return 2; }
    if ! flock -n 9; then say "already running (lock $LOCKF held); not queued"; return 2; fi

    OP_ID="zgd-$(date -u +%Y%m%dT%H%M%SZ)-$$"
    LOG="$STATE/$OP_ID.log"; REPORT="$STATE/$(date -u +%Y-%m-%d).json"
    : >"$LOG"
    local PGID; PGID=$(ps -o pgid= -p $$ | tr -d ' ')
    reg() { # state verdict reason
        printf '{"op_id":%s,"purpose_key":"zero-gap-daily","owner":%s,"pid":%s,"pgid":%s,"log_path":%s,"state":%s,"verdict":%s,"reason":%s,"evidence_path":%s,"ts":%s}\n' \
            "$(json_str "$OP_ID")" "$(json_str "${USER:-unknown}:zero-gap-daily.sh")" "$$" "${PGID:-0}" "$(json_str "$LOG")" \
            "$(json_str "$1")" "$(json_str "${2:-}")" "$(json_str "${3:-}")" "$(json_str "$REPORT")" "$(json_str "$(now_iso)")" >>"$REG"
    }
    # STALE: the previous report is older than the allowance (a missed day is itself a finding)
    local stale_h=${ZG_DAILY_STALE_HOURS:-36} last
    last=$(ls -1t "$STATE"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].json 2>/dev/null | head -1 || true)
    local STALE=0
    if [ -n "$last" ] && [ $(( ( $(date +%s) - $(stat -c %Y "$last") ) / 3600 )) -gt "$stale_h" ]; then STALE=1; fi
    reg running "" ""
    HB=0; hb() { HB=$((HB+1)); printf '%s %s\n' "$HB" "$(date +%s)" >"$STATE/$OP_ID.heartbeat"; }
    hb
    notify() { # message
        local cmd=${ZG_NOTIFY_CMD:-notify-send}
        command -v "${cmd%% *}" >/dev/null 2>&1 && $cmd "zero-gap-daily" "$1" >/dev/null 2>&1 || true
    }
    finish() { # state verdict reason exit-code
        reg "$1" "$2" "$3"
        printf 'VERDICT %s (rc %s) op=%s %s\n' "$2" "$4" "$OP_ID" "$3"
        flock -u 9 2>/dev/null || true
        rm -f "$STATE/$OP_ID.heartbeat"
        return "$4"
    }

    local reason
    if ! reason=$(host_pressure); then
        say "host under pressure: $reason; refusing to start a sweep"
        finish failed UNDETERMINED "host pressure: $reason" 2; return $?
    fi

    local EVID=${ZG_EVIDENCE:-$HERE/zero-gap-evidence.sh}
    if [ ! -f "$EVID" ]; then finish failed UNDETERMINED "evidence adapter absent ($EVID): steps cannot be sealed" 2; return $?; fi

    # ---- fingerprints and the frozen real copy
    local FP0 ST0 FP1 ST1 FPC
    FP0=$(live_fp "$ROOT") || FP0=""; ST0=$(status_sha "$ROOT")
    if [ -z "$FP0" ]; then finish failed UNDETERMINED "cannot fingerprint the live tree" 2; return $?; fi
    COPY=$(mktemp -d "${ZG_SCRATCH:-${TMPDIR:-/tmp}}/zgd.XXXXXX") || { finish failed UNDETERMINED "cannot create the copy dir" 2; return $?; }
    local LIST="$COPY.list"
    git -C "$ROOT" ls-files -z --cached --others --exclude-standard >"$LIST.raw" 2>>"$LOG"
    : >"$LIST"
    while IFS= read -r -d '' p; do
        [ -d "$ROOT/$p" ] && [ ! -L "$ROOT/$p" ] && continue   # gitlink / nested repo: not copied
        { [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; } || continue # tracked-but-deleted
        printf '%s\0' "$p" >>"$LIST"
    done <"$LIST.raw"
    if ! rsync -a --from0 --files-from="$LIST" "$ROOT/" "$COPY/" >>"$LOG" 2>&1; then
        rm -rf "$COPY" "$LIST" "$LIST.raw"; finish failed UNDETERMINED "rsync of the frozen copy failed" 2; return $?
    fi
    (
        cd "$COPY" && git init -q && git -c user.email=zgd@localhost -c user.name=zgd add -f --pathspec-from-file="$LIST" --pathspec-file-nul &&
        git -c user.email=zgd@localhost -c user.name=zgd commit -q -m "zero-gap-daily frozen copy" ) >>"$LOG" 2>&1 ||
        { rm -rf "$COPY" "$LIST" "$LIST.raw"; finish failed UNDETERMINED "cannot index the frozen copy" 2; return $?; }
    rm -f "$LIST" "$LIST.raw"
    FPC=$(live_fp "$COPY") || FPC=""
    hb

    # the adapter's fixed fingerprint anchor (see HONEST LIMIT)
    local FPA="$STATE/fp"
    if [ ! -d "$FPA/.git" ]; then mkdir -p "$FPA" && ( cd "$FPA" && git init -q && echo anchor >README && git add -- README && git -c user.email=zgd@localhost -c user.name=zgd commit -q -m anchor ) >>"$LOG" 2>&1; fi

    # ---- steps
    STEPS="$COPY.steps"; : >"$STEPS"
    if [ -n "${ZG_DAILY_STEPS_FILE:-}" ]; then
        cat "$ZG_DAILY_STEPS_FILE" >"$STEPS"
    else
        {
            printf 'registry-structure\tbash scripts/verify-check-registry.sh\n'
            printf 'claim-ledger\tbash scripts/verify-claim-ledger.sh\n'
            printf 'scan-records\tbash scripts/zero-gap-scan-records.sh --root .\n'
            if [ "$MODE" = full ]; then
                printf 'registry-run-proofs\tbash scripts/verify-check-registry.sh --run-proofs\n'
                printf 'sweep\tbash scripts/zero-gap-sweep.sh --out "$ZGD_OUT/sweep"\n'
                printf 'coverage\tbash scripts/zero-gap-coverage.sh\n'
                printf 'determinism-sample\tbash scripts/zero-gap-determinism.sh --runs 2 --root .\n'
                printf 'raw:seal-checks\tbash scripts/zero-gap-seal-checks.sh run\n'
            fi
        } >"$STEPS"
    fi
    # closed-item re-checks: every recorded check of the register's closed items
    local cf cid ccmd
    for cf in "$COPY"/docs/zero-gap/checks/*.check; do
        [ -f "$cf" ] || continue
        cid=$(basename "$cf" .check)
        ccmd=$(sed -n 's/^cmd=//p' "$cf" | head -1)
        [ -n "$ccmd" ] || continue
        printf 'closed:%s\t%s\n' "$cid" "$ccmd" >>"$STEPS"
    done

    local OUT="$STATE/out-$OP_ID"; mkdir -p "$OUT"
    local sitem names=() rcs=() recs=() secs=() logs=() worst=0 viol=0 undet=0 steplog sname scmd t0 pid last_sz sz idle
    while IFS=$'\t' read -r sname scmd; do
        [ -n "$sname" ] || continue
        steplog="$OUT/$(printf '%s' "$sname" | tr -c 'A-Za-z0-9._-' '_').log"
        case "$sname" in closed:*) sitem=${sname#closed:} ;; *) sitem=SWEEP ;; esac
        t0=$(date +%s)
        if [[ "$sname" == raw:* ]]; then
            # a `raw:` step does its own sealing (the adapter holds the store lock while a check runs, so a step
            # that itself calls the adapter must not be wrapped in another record)
            ( cd "$COPY" && ZGD_OUT="$OUT" ZGD_LIVE_ROOT="$ROOT" ZG_STORE_DIR="$STATE/evidence" ZG_SESSION_ID="${ZG_SESSION_ID:-zero-gap-daily-$OP_ID}" exec setsid bash -c "$scmd" ) >"$steplog" 2>&1 &
        else
        ( cd "$COPY" && ZGD_OUT="$OUT" ZGD_LIVE_ROOT="$ROOT" exec setsid bash "$EVID" record --store "$STATE/evidence" --streams "$STATE/evidence/streams" \
            --fp-dir "$FPA" --item-id "$sitem" --check-id "daily-$sname" --population-kind process --verdict-role author \
            --independence-tier instance --evidence-class runtime --verdict-exit --session "${ZG_SESSION_ID:-zero-gap-daily-$OP_ID}" \
            -- bash -c "$scmd" ) >"$steplog" 2>&1 &
        fi
        pid=$!
        last_sz=-1; idle=0
        while kill -0 "$pid" 2>/dev/null; do
            sleep 1; hb
            sz=$(stat -c %s "$steplog" 2>/dev/null || echo 0)
            if [ "$sz" = "$last_sz" ]; then idle=$((idle+1)); else idle=0; last_sz=$sz; fi
            if [ "$idle" -ge "$NOPROG" ]; then
                say "step '$sname' made no progress for ${NOPROG}s: reaping its process group $pid"
                # setsid made $pid its own group leader; never signal our own group (§11.4.263)
                if [ "$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')" = "$pid" ] && [ "$pid" != "$PGID" ]; then
                    kill -TERM -- "-$pid" 2>/dev/null; sleep 2; kill -KILL -- "-$pid" 2>/dev/null
                fi
                wait "$pid" 2>/dev/null; rc=124; break
            fi
        done
        if [ "${rc:-}" != 124 ]; then wait "$pid"; rc=$?; fi
        # a failing closed-item check leaves its sealed record as a single-record file the reopen queue can cite
        rec=""
        if [ "$rc" = 1 ] && [ "$sitem" != SWEEP ]; then
            rec="${OUT#"$ROOT"/}/record-$sitem.json"
            if ! python3 - "$STATE/evidence/sidecar.jsonl" "$sitem" "$ROOT/$rec" <<'PYEOF'
import json, sys
src, item, dst = sys.argv[1:4]
try:
    lines = [l for l in open(src).read().split("\n") if l.strip()]
    rec = json.loads(lines[-1])
    assert rec["item_id"] == item and rec["outcome"] == 1
except Exception:
    sys.exit(1)
open(dst, "w").write(lines[-1] + "\n")
PYEOF
            then rec=""; undet=1; say "closed check $sitem failed but its sealed record could not be extracted; no reopen request can be queued"; fi
        fi
        recs+=("$rec")
        names+=("$sname"); rcs+=("$rc"); secs+=("$(( $(date +%s) - t0 ))"); logs+=("$steplog")
        case "$rc" in 0) ;; 1) viol=1 ;; *) undet=1 ;; esac
        printf 'STEP %s rc=%s %ss\n' "$sname" "$rc" "$(( $(date +%s) - t0 ))" >>"$LOG"
        rc=0
    done <"$STEPS"
    rm -f "$STEPS"

    FP1=$(live_fp "$ROOT") || FP1=""; ST1=$(status_sha "$ROOT")
    rm -rf "$COPY"
    local UNSTABLE=0
    if [ "$FP0" != "$FP1" ] || [ "$ST0" != "$ST1" ]; then UNSTABLE=1; fi

    # ---- reopen requests (never from an unstable run)
    local reopens=0
    if [ "$UNSTABLE" -eq 0 ]; then
        for i in "${!names[@]}"; do
            case "${names[$i]}" in closed:*) [ "${rcs[$i]}" = 1 ] && [ -n "${recs[$i]}" ] || continue
                # the record shape `gap apply-queue` reads (DisallowUnknownFields): item_id, repo-relative evidence, why, queued_at
                printf '{"item_id":%s,"evidence":%s,"why":"captured-evidence-contradicts","queued_at":%s}\n' "$(json_str "${names[$i]#closed:}")" \
                    "$(json_str "${recs[$i]}")" "$(json_str "$(now_iso)")" >>"$QUEUE"; reopens=$((reopens+1)) ;;
            esac
        done
    fi

    local VERDICT RC STATE_T
    if [ "$UNSTABLE" -eq 1 ]; then VERDICT=UNSTABLE; RC=2; STATE_T=complete
    elif [ "$viol" -eq 1 ]; then VERDICT=VIOLATED; RC=1; STATE_T=complete
    elif [ "$undet" -eq 1 ]; then VERDICT=UNDETERMINED; RC=2; STATE_T=failed
    else VERDICT=HOLDS; RC=0; STATE_T=complete; fi

    python3 - "$REPORT" "$OP_ID" "$MODE" "$VERDICT" "$FP0" "$FP1" "$ST0" "$ST1" "$FPC" "$reopens" "$STALE" "$(printf '%s\n' "${names[@]:-}")" "$(printf '%s\n' "${rcs[@]:-}")" "$(printf '%s\n' "${secs[@]:-}")" "$(printf '%s\n' "${logs[@]:-}")" <<'PYEOF'
import json, sys
(p, op, mode, verdict, fp0, fp1, st0, st1, fpc, reopens, stale, n, r, s, l) = sys.argv[1:16]
steps = [dict(name=a, rc=int(b), seconds=int(c), log=d) for a, b, c, d in zip(n.split("\n"), r.split("\n"), s.split("\n"), l.split("\n")) if a]
json.dump(dict(op_id=op, mode=mode, verdict=verdict, live_fingerprint_before=fp0, live_fingerprint_after=fp1,
               live_status_sha_before=st0, live_status_sha_after=st1, copy_fingerprint=fpc, reopen_requests=int(reopens),
               stale=stale == "1", steps=steps), open(p, "w"), indent=2, sort_keys=True)
open(p, "a").write("\n")
PYEOF
    if [ "$VERDICT" = VIOLATED ]; then notify "RED: a zero-gap re-measurement failed ($reopens reopen request(s)); see $REPORT"; fi
    if [ "$STALE" -eq 1 ]; then notify "STALE: the previous zero-gap report was older than ${stale_h}h"; fi
    finish "$STATE_T" "$VERDICT" "steps=${#names[@]} reopen_requests=$reopens unstable=$UNSTABLE" "$RC"; return $?
}

# ---------------------------------------------------------------- paired proof
prove_failure() {
    command -v git >/dev/null && command -v rsync >/dev/null && command -v python3 >/dev/null && command -v flock >/dev/null ||
        { echo "prove-failure: git/rsync/python3/flock missing"; return 2; }
    local T fails=0 rc o
    T=$(mktemp -d "${TMPDIR:-/tmp}/zgd-proof.XXXXXX") || return 2
    trap 'rm -rf "$T"' RETURN
    local R="$T/repo" S="$T/repo/.remember/logs/zero-gap" STUB="$T/adapter.sh" NOTE="$T/notified"
    mkdir -p "$R/docs/zero-gap/checks" "$R/scripts"
    ( cd "$R" && git init -q && printf '.remember/\n' >.gitignore && echo one >tracked.txt && git add -- .gitignore tracked.txt &&
      git -c user.email=t@t -c user.name=t commit -q -m init ) || { echo "prove-failure: cannot build the fixture"; return 2; }
    # a stub ADAPTER (test double): runs the command after `--`, appends a sealed line, returns the command's rc
    cat >"$STUB" <<'EOF'
#!/usr/bin/env bash
store=""; item=""; while [ $# -gt 0 ]; do case "$1" in --store) store=$2; shift 2 ;; --item-id) item=$2; shift 2 ;; --) shift; break ;; *) shift ;; esac; done
mkdir -p "$store"; "$@"; rc=$?; printf 'sealed rc=%s\n' "$rc" >>"$store/sealed.log"
printf '{"item_id":"%s","outcome":%s}\n' "$item" "$rc" >>"$store/sidecar.jsonl"; exit "$rc"
EOF
    printf '#!/usr/bin/env bash\necho "$*" >>"%s"\n' "$NOTE" >"$T/notify.sh"; chmod +x "$STUB" "$T/notify.sh"
    steps() { printf '%b' "$1" >"$T/steps.tsv"; }
    runit() { # extra env as args: VAR=val ...
        env ZG_EVIDENCE="$STUB" ZG_DAILY_STEPS_FILE="$T/steps.tsv" ZG_NOTIFY_CMD="$T/notify.sh" ZG_DAILY_MAX_MEM_USED_PCT=99 ZG_DAILY_MAX_LOAD_FACTOR=1000 ZG_SCRATCH="$T" "$@" \
            bash "$SELF" --now --root "$R" --state-dir "$S" --noprogress "${NP:-60}" 2>&1
    }
    chk() { # name cond-rc
        if [ "$2" -eq 0 ]; then echo "  ok   $1"; else echo "  FAIL $1"; fails=$((fails+1)); fi
    }
    local before after ino_live ino_copy
    # C0 control (also the T069 RED: a step that rewrites a tracked file and records inodes)
    steps "rewrite\techo changed >tracked.txt; stat -c %i tracked.txt >\"$T/ino_copy\"\nsecond\ttrue\n"
    ino_live=$(stat -c %i "$R/tracked.txt")
    before=$(git -C "$R" status --porcelain=v1 -z | sha256sum)
    o=$(runit); rc=$?
    after=$(git -C "$R" status --porcelain=v1 -z | sha256sum)
    chk "C0 control run holds (rc 0)" "$([ "$rc" -eq 0 ]; echo $?)"
    [ "$rc" -eq 0 ] || echo "$o" | sed 's/^/      /'
    chk "C1 a step that rewrote a tracked file left the LIVE tree byte-identical (git status before == after)" "$([ "$before" = "$after" ] && [ "$(cat "$R/tracked.txt")" = one ]; echo $?)"
    ino_copy=$(cat "$T/ino_copy" 2>/dev/null || echo 0)
    chk "C2 the copy is a real copy, not a hardlink (inode differs)" "$([ "$ino_copy" != "$ino_live" ] && [ "$ino_copy" != 0 ]; echo $?)"
    chk "C3 the op was registered running BEFORE and terminal after, same op_id" "$(python3 - "$S/ops-registry.jsonl" <<'PY'
import json,sys
rows=[json.loads(l) for l in open(sys.argv[1])]
ok=len(rows)>=2 and rows[0]["state"]=="running" and rows[-1]["state"]=="complete" and rows[-1]["verdict"]=="HOLDS" and rows[0]["op_id"]==rows[-1]["op_id"] and rows[0]["purpose_key"]=="zero-gap-daily"
sys.exit(0 if ok else 1)
PY
echo $?)"
    chk "C4 each step was sealed through the adapter" "$([ "$(grep -c '^sealed' "$S/evidence/sealed.log" 2>/dev/null)" -ge 2 ]; echo $?)"
    chk "C5 a dated report was written and names the verdict" "$(grep -q '"verdict": "HOLDS"' "$S"/*-*-*.json 2>/dev/null; echo $?)"
    # C6 a raw: step runs WITHOUT being wrapped in the adapter (it seals itself)
    steps "raw:self\ttouch \"$T/raw-ran\"\n"
    rm -f "$T/raw-ran" "$S/evidence/sealed.log"
    o=$(runit); rc=$?
    chk "C6 a raw: step runs unwrapped (no adapter record for it) and still counts in the verdict" "$([ "$rc" -eq 0 ] && [ -e "$T/raw-ran" ] && [ ! -s "$S/evidence/sealed.log" ]; echo $?)"
    # M1 lock held
    ( exec 8>"$S/daily.lock"; flock 8; sleep 8 ) & local holder=$!
    sleep 1
    local nrows; nrows=$(wc -l <"$S/ops-registry.jsonl")
    o=$(runit); rc=$?
    chk "M1 lock held => rc 2 'already running', nothing registered" "$([ "$rc" -eq 2 ] && echo "$o" | grep -q 'already running' && [ "$(wc -l <"$S/ops-registry.jsonl")" = "$nrows" ]; echo $?)"
    kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
    # M2 pressure
    rm -f "$T/marker"; steps "mark\ttouch \"$T/marker\"\n"
    o=$(runit ZG_DAILY_MAX_MEM_USED_PCT=0); rc=$?
    chk "M2 host pressure => rc 2 and the step was NOT executed" "$([ "$rc" -eq 2 ] && [ ! -e "$T/marker" ] && echo "$o" | grep -q 'pressure'; echo $?)"
    # M3 closed item now failing
    printf 'check_id=x\npre_fix_ref=HEAD\ncmd=exit 1\n' >"$R/docs/zero-gap/checks/ZZZ-001.check"
    ( cd "$R" && git add -- docs/zero-gap/checks/ZZZ-001.check && git -c user.email=t@t -c user.name=t commit -q -m check )
    steps "ok\ttrue\n"; rm -f "$NOTE"
    o=$(runit); rc=$?
    chk "M3 a closed item whose check now fails => rc 1" "$([ "$rc" -eq 1 ]; echo $?)"
    chk "M3b a reopen request names the item and the register was not touched" "$(grep -q '"item_id":"ZZZ-001"' "$S/reopen-queue.jsonl" && grep -q '"evidence":"' "$S/reopen-queue.jsonl"; echo $?)"
    chk "M3c RED raised a notification" "$(grep -q 'RED' "$NOTE" 2>/dev/null; echo $?)"
    # M4 unstable: a concurrent editor touches the LIVE tree during the run
    rm -f "$S/reopen-queue.jsonl"
    steps "editor\techo moved >>\"\$ZGD_LIVE_ROOT/tracked.txt\"\n"
    o=$(runit); rc=$?
    chk "M4 live tree moved during the run => UNSTABLE rc 2 and NO reopen request" "$([ "$rc" -eq 2 ] && echo "$o" | grep -q UNSTABLE && [ ! -s "$S/reopen-queue.jsonl" ]; echo $?)"
    echo one >"$R/tracked.txt"
    # M5 hung step reaped
    rm -f "$R/docs/zero-gap/checks/ZZZ-001.check"; ( cd "$R" && git add -u -- docs/zero-gap/checks && git -c user.email=t@t -c user.name=t commit -q -m rm )
    steps "hang\tsleep 120\n"
    o=$(NP=3 runit); rc=$?
    chk "M5 a hung step is reaped by the no-progress budget => rc 2, step rc 124" "$([ "$rc" -eq 2 ] && grep -q '"rc": 124' "$S"/*-*-*.json; echo $?)"
    chk "M5b no process of the hung step survives" "$(! pgrep -f 'sleep 120' >/dev/null 2>&1; echo $?)"
    # M6 no adapter
    steps "ok\ttrue\n"
    o=$(runit ZG_EVIDENCE="$T/nonexistent"); rc=$?
    chk "M6 no evidence adapter => rc 2 (unsealed steps are never a pass)" "$([ "$rc" -eq 2 ]; echo $?)"
    # M7 state dir not ignored
    o=$(env ZG_EVIDENCE="$STUB" ZG_DAILY_STEPS_FILE="$T/steps.tsv" bash "$SELF" --now --root "$R" --state-dir "$R/trackable" 2>&1); rc=$?
    chk "M7 a state dir that is not git-ignored is refused (rc 2)" "$([ "$rc" -eq 2 ] && echo "$o" | grep -q 'not git-ignored'; echo $?)"
    if [ "$fails" -gt 0 ]; then echo "prove-failure: $fails case(s) failed"; return 1; fi
    echo "prove-failure: all cases passed"; return 0
}

SELF=$(readlink -f "${BASH_SOURCE[0]}")
if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi
run_daily
exit $?
