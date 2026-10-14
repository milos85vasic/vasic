#!/usr/bin/env bash
# scripts/agent-admit.sh — admission control for HEAVY agent work (host-hang fix WP1, 2026-10-14).
#
# WHY. On 2026-10-14 (host anton) ~20 parallel agents ran heavy gates at once (pre-push Playwright with
# three browsers, go test, podman builds, full content-boundary scans) while writing multi-GB copies into
# RAM-backed /tmp. app.slice hit its MemoryHigh, the kernel went into a direct-reclaim storm (sys CPU
# 1108%, load 430, PSI memory full 53-92%) and the box stalled; nothing bounded HOW MANY heavy jobs ran.
# This wrapper is that bound: a slot semaphore plus three pressure pre-checks, then the command runs
# under `bounded-run` (its own cgroup scope with a memory cap, a wall clock and an on-disk TMPDIR).
#
# USAGE
#   agent-admit.sh [--slots N] [--tag T] [--wait SECS] [--verdict3] [-m MEM] [-T SECS] -- CMD [ARGS...]
#   agent-admit.sh --check          run only the pre-checks; print the metrics
#   agent-admit.sh --is-admitted    rc 0 when THIS process already runs inside an admitted run
#   agent-admit.sh --prove-failure  §1.1 paired proof (controls + mutations + wiring)
#
#   --slots N     heavy slots (default 2): lock files <scratch>/slots/slot-0..N-1. agent-admit itself
#                 holds the lock for the WHOLE run and stays alive as CMD's parent; CMD runs with the lock fd
#                 CLOSED, so a child that outlives CMD (or escapes into another scope) cannot keep a slot.
#                 The slot file records pid=<holder> and boot=<boot_id> for the nesting check.
#   --wait SECS   how long to wait for a free slot (default $AGENT_ADMIT_WAIT or 300); then refused
#   --tag T       label for the scope name and messages: the WHOLE string must match ^[A-Za-z0-9_.-]{1,40}$
#   -m / -T       bounded-run MemoryMax and wall clock (default $AGENT_ADMIT_MEM or 6G, $AGENT_ADMIT_TIMEOUT
#                 or 3600)
#   --verdict3    for three-valued callers (0 holds / 1 finding / 2 cannot determine): a refusal, an
#                 undeterminable pre-check, and ANY rc >= 124 (124 bounded-run timeout, 125 bounded-run error,
#                 126 not executable, 127 not found, 128+N death by signal N — 137 is SIGKILL, e.g. the -m
#                 memory cap) all become rc 2: NEVER a pass and never mistakable for a finding. CMD's 0/1/2 and
#                 other rcs below 124 pass through.
#
# PRE-CHECKS (after a slot is held; any one failing refuses):
#   memory PSI    /proc/pressure/memory  `some avg10` < $AGENT_ADMIT_PSI_MAX (15)
#   shmem         Shmem / MemTotal from /proc/meminfo (ALL tmpfs + shm pages, wherever mounted)
#                 < $AGENT_ADMIT_SHMEM_MAX_PCT (10). Measured: 8.1 GB of shmem (25% of this 31.7 GB host)
#                 stalled it on 2026-10-14, so 10% (~3.2 GB) leaves a wide margin.
#   tmpfs         used% of each of $AGENT_ADMIT_TMPFS (default "/tmp /dev/shm /run/user/<uid>"; an absent
#                 path is reported, not an error) < $AGENT_ADMIT_TMPFS_MAX_PCT (25). 40% of a 16 GB /tmp was
#                 6.4 GB — too close to the 8.1 GB that stalled the host.
#   threads       §12.12: live threads of this user (ps -L -u) vs RLIMIT_NPROC (`ulimit -u`; "unlimited"
#                 falls back to kernel.threads-max): used < $AGENT_ADMIT_THREADS_MAX_PCT (75) % AND headroom
#                 >= $AGENT_ADMIT_THREADS_MIN_HEADROOM (512); plus app.slice pids.current/pids.max < 80 %
#                 when pids.max is finite.
#   app.slice     (memory.current - inactive_file) / memory.high  < $AGENT_ADMIT_SLICE_MAX_PCT (85)
#                 cgroup dir: $AGENT_ADMIT_CGROUP, default the user manager's app.slice. memory.high "max"
#                 falls back to memory.max; both "max" or any file unreadable => cannot determine (rc 2).
#                 WHY inactive_file is subtracted (a measured deviation from a raw current/high ratio): on
#                 2026-10-14 15:00 the raw ratio was 21.79/22.74 GB = 95.8% with PSI 0.00 — 6.74 GB of it
#                 was inactive page cache the kernel drops at once. A raw-ratio gate would have refused every
#                 job on an idle host, i.e. a guard asserting the wrong condition (§11.4.201). Both ratios
#                 are printed; only the working-set one gates.
#
# EXIT (default mode)  0 / CMD's own rc after a run (bounded-run adds 124 timeout and 125 its own error)
#                      | 1 REFUSED by pressure or no slot (message names the metric) | 2 cannot determine
#                      (unreadable metric, no bounded-run, bad usage). NOTE: in this mode a refusal (1) and a
#                      CMD that exits 1 look alike on the rc; callers that must tell them apart use --verdict3.
#      (--verdict3)    see above.   --check: 0 admit / 1 refuse / 2 cannot determine.
#
# NESTING. An admitted run exports AGENT_ADMITTED_SLOT=<its slot file>. A nested call runs CMD directly (no
# second slot, no second scope) only when ALL hold: the file is a real slot under this root, it is
# currently locked, its recorded boot id is this boot, and its recorded holder pid is an ANCESTOR of the
# caller. A forged env var naming another job's (locked) slot is therefore not trusted.
#
# HONEST LIMITS. Admission is cooperative: work started without this wrapper is not counted, and the
# AGENT_ADMIT_* tunables can loosen the thresholds (they are recorded in every message). The checks are a
# point-in-time sample; a job admitted at low pressure can still create pressure. It complements, and
# does not replace, bounded-run's cgroup caps.
# Dependencies: bash >= 4.1, flock(1), coreutils, bounded-run (~/.local/bin, hostsafety).
set -u
SELF="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"
UMBRELLA="$(CDPATH='' cd -- "$(dirname -- "$SELF")/.." && pwd)"
SCRATCH="${AGENT_SCRATCH_ROOT:-$HOME/.cache/agent-scratch}"
SLOTS_DIR="$SCRATCH/slots"
PSI_FILE="${AGENT_ADMIT_PSI_FILE:-/proc/pressure/memory}"
PSI_MAX="${AGENT_ADMIT_PSI_MAX:-15}"
TMPFS_PATHS="${AGENT_ADMIT_TMPFS:-/tmp /dev/shm /run/user/$(id -u)}"
TMPFS_MAX="${AGENT_ADMIT_TMPFS_MAX_PCT:-25}"
MEMINFO="${AGENT_ADMIT_MEMINFO:-/proc/meminfo}"
SHMEM_MAX="${AGENT_ADMIT_SHMEM_MAX_PCT:-10}"
THREADS_MAX="${AGENT_ADMIT_THREADS_MAX_PCT:-75}"
THREADS_MIN_HEADROOM="${AGENT_ADMIT_THREADS_MIN_HEADROOM:-512}"
BOOT_ID_FILE=/proc/sys/kernel/random/boot_id
CG_DIR="${AGENT_ADMIT_CGROUP:-/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/app.slice}"
SLICE_MAX="${AGENT_ADMIT_SLICE_MAX_PCT:-85}"
BR="${AGENT_ADMIT_BOUNDED_RUN-$(command -v bounded-run 2>/dev/null)}"

say() { printf 'agent-admit: %s\n' "$*" >&2; }

# ---- pre-checks: each prints one metric line; rc 0 ok / 1 over threshold / 2 unreadable -------------
check_psi() {
    local line v
    line=$(grep '^some ' "$PSI_FILE" 2>/dev/null) || { say "CANNOT DETERMINE: memory PSI unreadable ($PSI_FILE)"; return 2; }
    v=$(printf '%s\n' "$line" | sed -nE 's/.*avg10=([0-9]+(\.[0-9]+)?).*/\1/p')
    [ -n "$v" ] || { say "CANNOT DETERMINE: no avg10 in $PSI_FILE"; return 2; }
    echo "metric memory_psi_some_avg10=$v threshold<$PSI_MAX"
    awk -v v="$v" -v m="$PSI_MAX" 'BEGIN{exit !(v < m)}' && return 0
    say "REFUSED: memory PSI some avg10=$v >= $PSI_MAX (host is already reclaiming; run later)"
    return 1
}

check_shmem() {
    local tot sh pct
    tot=$(sed -n 's/^MemTotal: *\([0-9]*\) kB$/\1/p' "$MEMINFO" 2>/dev/null)
    sh=$(sed -n 's/^Shmem: *\([0-9]*\) kB$/\1/p' "$MEMINFO" 2>/dev/null)
    case "$tot:$sh" in *[!0-9:]*|:*|*:) say "CANNOT DETERMINE: MemTotal/Shmem unreadable in $MEMINFO"; return 2 ;; esac
    [ "$tot" -gt 0 ] || { say "CANNOT DETERMINE: MemTotal is 0 in $MEMINFO"; return 2; }
    pct=$(( sh * 100 / tot ))
    echo "metric shmem_pct_of_ram=$pct (Shmem ${sh} kB / MemTotal ${tot} kB) threshold<$SHMEM_MAX"
    [ "$pct" -lt "$SHMEM_MAX" ] && return 0
    say "REFUSED: shmem (tmpfs + shm pages, unreclaimable without swap) is ${pct}% of RAM (>= ${SHMEM_MAX}%); clean up RAM-backed copies first (scripts/agent-scratch.sh)"
    return 1
}

check_tmpfs() {
    local p b f pct worst=0
    for p in $TMPFS_PATHS; do
        if [ ! -e "$p" ]; then echo "metric tmpfs_used_pct path=$p absent"; continue; fi
        b=''; f=''
        read -r b f < <(stat -f -c '%b %f' -- "$p" 2>/dev/null) || true
        [ -n "${b:-}" ] && [ "${b:-0}" -gt 0 ] 2>/dev/null || { say "CANNOT DETERMINE: cannot stat filesystem of $p"; [ "$worst" -eq 1 ] || worst=2; continue; }
        pct=$(( (b - f) * 100 / b ))
        echo "metric tmpfs_used_pct=$pct path=$p fs=$(stat -f -c %T -- "$p" 2>/dev/null) threshold<$TMPFS_MAX"
        if [ "$pct" -ge "$TMPFS_MAX" ]; then
            say "REFUSED: $p is ${pct}% used (>= ${TMPFS_MAX}%): RAM-backed tmpfs pages are unreclaimable; clean up copies there first (scripts/agent-scratch.sh)"
            worst=1
        fi
    done
    return "$worst"
}

check_threads() {
    local lim live pct head pc pm
    lim="${AGENT_ADMIT_NPROC_LIMIT:-$(ulimit -u 2>/dev/null)}"
    [ "$lim" = unlimited ] && lim=$(cat /proc/sys/kernel/threads-max 2>/dev/null)
    live="${AGENT_ADMIT_THREADS_LIVE:-$(ps -L --no-headers -u "$(id -u)" 2>/dev/null | wc -l)}"
    case "$lim:$live" in *[!0-9:]*|:*|*:) say "CANNOT DETERMINE: thread limit or live thread count unreadable (limit='$lim' live='$live')"; return 2 ;; esac
    [ "$lim" -gt 0 ] && [ "$live" -gt 0 ] || { say "CANNOT DETERMINE: thread limit $lim / live $live"; return 2; }
    pct=$(( live * 100 / lim )); head=$(( lim - live ))
    echo "metric threads_live=$live nproc_limit=$lim used_pct=$pct headroom=$head threshold<${THREADS_MAX}% headroom>=$THREADS_MIN_HEADROOM"
    if [ "$pct" -ge "$THREADS_MAX" ] || [ "$head" -lt "$THREADS_MIN_HEADROOM" ]; then
        say "REFUSED: §12.12 thread headroom: $live of $lim threads in use (headroom $head); serialise, stop idle MCP servers"
        return 1
    fi
    pc=$(cat "$CG_DIR/pids.current" 2>/dev/null); pm=$(cat "$CG_DIR/pids.max" 2>/dev/null)
    case "$pc:$pm" in
        *[!0-9:]*|:*|*:) echo "metric app_slice_pids n/a (pids.max='${pm:-unreadable}')" ;;
        *) echo "metric app_slice_pids=$pc/$pm threshold<80%"
           if [ "$pm" -gt 0 ] && [ $(( pc * 100 / pm )) -ge 80 ]; then say "REFUSED: app.slice tasks $pc of $pm (>= 80%)"; return 1; fi ;;
    esac
    return 0
}

read_num() { local v; v=$(cat -- "$1" 2>/dev/null) || return 1; printf '%s' "$v"; }
check_slice() {
    local cur high lim inact work wpct rpct
    cur=$(read_num "$CG_DIR/memory.current") && high=$(read_num "$CG_DIR/memory.high") \
        || { say "CANNOT DETERMINE: cannot read memory.current/memory.high under $CG_DIR"; return 2; }
    lim=$high
    if [ "$lim" = max ]; then
        lim=$(read_num "$CG_DIR/memory.max") || { say "CANNOT DETERMINE: memory.high is max and memory.max unreadable ($CG_DIR)"; return 2; }
    fi
    case "$cur$lim" in *[!0-9]*) say "CANNOT DETERMINE: no finite memory limit on $CG_DIR (high=$high); set AGENT_ADMIT_CGROUP to a limited slice"; return 2 ;; esac
    [ "$lim" -gt 0 ] || { say "CANNOT DETERMINE: zero memory limit on $CG_DIR"; return 2; }
    inact=$(sed -n 's/^inactive_file //p' "$CG_DIR/memory.stat" 2>/dev/null)
    case "$inact" in ''|*[!0-9]*) say "CANNOT DETERMINE: inactive_file unreadable in $CG_DIR/memory.stat"; return 2 ;; esac
    work=$(( cur > inact ? cur - inact : 0 ))
    wpct=$(( work * 100 / lim )); rpct=$(( cur * 100 / lim ))
    echo "metric app_slice_working_set_pct=$wpct (current-inactive_file=$work / limit=$lim) raw_current_pct=$rpct threshold<$SLICE_MAX"
    [ "$wpct" -lt "$SLICE_MAX" ] && return 0
    say "REFUSED: app.slice working set is ${wpct}% of its memory limit (>= ${SLICE_MAX}%); another heavy job would push it into throttling"
    return 1
}

prechecks() {
    local rc worst=0
    for c in check_psi check_shmem check_tmpfs check_slice check_threads; do
        "$c"; rc=$?
        # a refusal (1) outranks could-not-determine (2): a measured overload is a fact
        if [ "$rc" -eq 1 ]; then worst=1; elif [ "$rc" -eq 2 ] && [ "$worst" -eq 0 ]; then worst=2; fi
    done
    return "$worst"
}

# ---- nesting: is THIS process inside an admitted run? (the slot must be real AND locked) ---------------
ppid_of() { local st; st=$(cat "/proc/$1/stat" 2>/dev/null) || return 1; st=${st##*) }; set -- $st; printf '%s' "$2"; }
is_ancestor() { # $1 pid: is it $$ or an ancestor of $$?
    local p=$$ n=0
    while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$n" -lt 128 ]; do
        [ "$p" = "$1" ] && return 0
        p=$(ppid_of "$p") || return 1; n=$((n + 1))
    done
    return 1
}
is_admitted() {
    local s="${AGENT_ADMITTED_SLOT:-}" rs rd fd holder boot
    [ -n "$s" ] && [ -f "$s" ] || return 1
    rs=$(realpath -e -- "$s" 2>/dev/null) && rd=$(realpath -e -- "$SLOTS_DIR" 2>/dev/null) || return 1
    [ "$(dirname -- "$rs")" = "$rd" ] || return 1
    exec {fd}<"$rs" || return 1
    if flock -n "$fd"; then flock -u "$fd"; exec {fd}<&-; return 1; fi
    exec {fd}<&-
    holder=$(sed -n 's/^pid=//p' "$rs" 2>/dev/null); boot=$(sed -n 's/^boot=//p' "$rs" 2>/dev/null)
    [ -n "$holder" ] && [ "$boot" = "$(cat "$BOOT_ID_FILE" 2>/dev/null)" ] || return 1
    is_ancestor "$holder" || return 1
    return 0
}

refuse() { # $1 = 1 refused | 2 undet; maps under --verdict3
    if [ "$VERDICT3" -eq 1 ]; then say "VERDICT=$([ "$1" -eq 1 ] && echo refused || echo undetermined) -> rc 2 (never a pass)"; exit 2; fi
    exit "$1"
}

admit_and_run() {
    local slots=2 tag=job wait="${AGENT_ADMIT_WAIT:-300}" mem="${AGENT_ADMIT_MEM:-6G}" tmo="${AGENT_ADMIT_TIMEOUT:-3600}"
    VERDICT3=0
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --slots) slots=${2:-}; shift 2 || { say "--slots needs a value"; exit 2; } ;;
            --tag) tag=${2:-}; shift 2 || { say "--tag needs a value"; exit 2; } ;;
            --wait) wait=${2:-}; shift 2 || { say "--wait needs a value"; exit 2; } ;;
            -m) mem=${2:-}; shift 2 || { say "-m needs a value"; exit 2; } ;;
            -T) tmo=${2:-}; shift 2 || { say "-T needs a value"; exit 2; } ;;
            --verdict3) VERDICT3=1; shift ;;
            --) shift; break ;;
            *) say "unknown argument '$1' (usage: [opts] -- CMD...)"; exit 2 ;;
        esac
    done
    [ "$#" -gt 0 ] || { say "no command (usage: [opts] -- CMD...)"; exit 2; }
    case "$slots$wait$tmo" in *[!0-9]*|'') say "--slots/--wait/-T must be integers"; refuse 2 ;; esac
    [ "$slots" -ge 1 ] || { say "--slots must be >= 1"; refuse 2; }
    [[ "$tag" =~ ^[A-Za-z0-9_.-]{1,40}$ ]] || { say "bad --tag (the whole value must match ^[A-Za-z0-9_.-]{1,40}\$)"; refuse 2; }

    if is_admitted; then   # nested inside an admitted run: no second slot, no second scope
        "$@"; local nrc=$?
        exit "$nrc"
    fi

    mkdir -p -- "$SLOTS_DIR" 2>/dev/null && chmod 700 -- "$SCRATCH" "$SLOTS_DIR" 2>/dev/null \
        || { say "CANNOT DETERMINE: cannot create slot dir $SLOTS_DIR"; refuse 2; }
    local deadline=$(( $(date +%s) + wait )) i fd='' slot=''
    while :; do
        for ((i = 0; i < slots; i++)); do
            # Slot files are ephemeral state: after a reboot no lock is held and every file is free again.
            # A stale file left unwritable (e.g. mode 000) is repaired once; only a second failure is rc 2.
            if ! { exec {fd}>>"$SLOTS_DIR/slot-$i"; } 2>/dev/null; then
                chmod 600 -- "$SLOTS_DIR/slot-$i" 2>/dev/null
                exec {fd}>>"$SLOTS_DIR/slot-$i" || { say "CANNOT DETERMINE: cannot open $SLOTS_DIR/slot-$i"; refuse 2; }
            fi
            if flock -n "$fd"; then slot="$SLOTS_DIR/slot-$i"; break 2; fi
            exec {fd}>&-
        done
        if [ "$(date +%s)" -ge "$deadline" ]; then
            say "REFUSED: metric=slots — all $slots heavy slot(s) busy for ${wait}s (tag=$tag); run it in a later wave"
            refuse 1
        fi
        sleep 2
    done
    chmod 600 -- "$slot" 2>/dev/null || true
    # holder record for the nesting check (the lock is on the fd; this rewrite does not drop it)
    printf 'pid=%s\nboot=%s\ntag=%s\nstarted=%s\n' "$$" "$(cat "$BOOT_ID_FILE" 2>/dev/null)" "$tag" "$(date -Is)" >"$slot" 2>/dev/null \
        || { flock -u "$fd"; exec {fd}>&-; say "CANNOT DETERMINE: cannot record the holder in $slot"; refuse 2; }

    local prc
    prechecks >&2; prc=$?
    if [ "$prc" -ne 0 ]; then
        flock -u "$fd"; exec {fd}>&-
        refuse "$prc"
    fi
    if [ -z "$BR" ] || [ ! -x "$BR" ]; then
        flock -u "$fd"; exec {fd}>&-
        say "CANNOT DETERMINE: bounded-run not found (AGENT_ADMIT_BOUNDED_RUN='${BR}'); refusing to run heavy work unbounded"
        refuse 2
    fi
    export AGENT_ADMITTED_SLOT="$slot" AGENT_ADMITTED_TAG="$tag"
    say "ADMITTED tag=$tag slot=$slot -> bounded-run -m $mem -T $tmo"
    local -a argv=("$BR" -q -m "$mem" -T "$tmo" -n "admit-${tag}-$$" -- "$@")
    # agent-admit stays alive as the lock holder and CMD's parent; CMD gets the lock fd CLOSED
    local rc
    "${argv[@]}" {fd}>&-; rc=$?
    flock -u "$fd" 2>/dev/null; exec {fd}>&-
    [ "$VERDICT3" -eq 1 ] || exit "$rc"
    if [ "$rc" -ge 124 ]; then
        case "$rc" in
            124) say "VERDICT=timeout: bounded-run wall clock (-T $tmo) expired -> rc 2 (never a pass)" ;;
            125) say "VERDICT=bounded-run-error (rc 125) -> rc 2 (never a pass)" ;;
            126|127) say "VERDICT=command not executable/not found (rc $rc) -> rc 2 (never a pass)" ;;
            *) say "VERDICT=killed by signal $((rc - 128)) (rc $rc$([ "$rc" -eq 137 ] && echo ', SIGKILL: e.g. the -m memory cap')) -> rc 2 (never a pass)" ;;
        esac
        exit 2
    fi
    exit "$rc"
}

prove() {
    local pass=0 fail=0 T rc out
    ok() { pass=$((pass + 1)); echo "  ok   $*"; }
    bad() { fail=$((fail + 1)); echo "  FAIL $*"; }
    T=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/agent-admit-prove.XXXXXX") || { echo "COULD-NOT-PROVE: no temp dir on disk"; return 2; }
    cleanup() { rm -rf -- "$T"; }
    trap cleanup RETURN
    # A fixture world: fake PSI, a fake cgroup dir, a fake bounded-run that records its argv and runs CMD.
    mkdir -p "$T/cg" "$T/scr"
    psi() { printf 'some avg10=%s avg60=0.00 avg300=0.00 total=1\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=1\n' "$1" >"$T/psi"; }
    cg() { printf '%s\n' "$1" >"$T/cg/memory.current"; printf '%s\n' "$2" >"$T/cg/memory.high"; printf '%s\n' "${3:-max}" >"$T/cg/memory.max"
           printf 'anon 1\ninactive_file %s\n' "${4:-0}" >"$T/cg/memory.stat"; }
    printf '#!/usr/bin/env bash\necho "$*" >>"%s/br.argv"\nwhile [ "$1" != -- ]; do shift; done; shift\nexec "$@"\n' "$T" >"$T/fake-br"
    chmod +x "$T/fake-br"
    # OV_* override one fixture input for a single case (the fixture defaults are set here, so a plain
    # AGENT_ADMIT_* prefix on the call would be shadowed).
    A() { AGENT_SCRATCH_ROOT="$T/scr" AGENT_ADMIT_PSI_FILE="${OV_PSI:-$T/psi}" AGENT_ADMIT_CGROUP="${OV_CG:-$T/cg}" AGENT_ADMIT_TMPFS="${OV_TMPFS:-$T/absent-mount}" \
          AGENT_ADMIT_MEMINFO="${OV_MI:-$T/meminfo}" AGENT_ADMIT_NPROC_LIMIT="${OV_NPROC:-10000}" AGENT_ADMIT_THREADS_LIVE="${OV_LIVE:-100}" \
          AGENT_ADMIT_BOUNDED_RUN="${OV_BR:-$T/fake-br}" AGENT_ADMIT_WAIT=0 bash "${SCRIPT:-$SELF}" "$@"; }
    meminfo() { printf 'MemTotal:       %s kB\nMemFree:        1 kB\nShmem:          %s kB\n' "$1" "$2" >"$T/meminfo"; }
    meminfo 31717516 122260
    SCRIPT=$SELF
    psi 0.50; cg 1000 10000 max 0
    # A1 healthy host: CMD runs under bounded-run with the default caps, its rc is returned
    rm -f "$T/br.argv"; A --tag a1 -- bash -c 'exit 7' 2>/dev/null; rc=$?
    [ "$rc" -eq 7 ] && grep -q -- '-m 6G -T 3600 -n admit-a1-' "$T/br.argv" && ok "A1 admitted: CMD rc 7 returned, run under bounded-run -m 6G -T 3600" || bad "A1 rc=$rc argv=$(cat "$T/br.argv" 2>/dev/null)"
    # A2 PSI over threshold => rc 1, message names the metric, CMD not run
    psi 22.00; rm -f "$T/ran"; out=$(A -- touch "$T/ran" 2>&1); rc=$?
    [ "$rc" -eq 1 ] && [ ! -e "$T/ran" ] && printf '%s' "$out" | grep -q 'memory PSI some avg10=22.00' && ok "A2 PSI 22 refused rc 1, metric named, CMD not run" || bad "A2 rc=$rc out=$out"
    psi 0.50
    # A3 app.slice working set >= 85% => rc 1
    cg 9000 10000 max 0; out=$(A -- true 2>&1); rc=$?
    [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'working set is 90%' && ok "A3 app.slice working set 90% refused rc 1" || bad "A3 rc=$rc out=$out"
    # A4 the same raw usage that is mostly inactive cache is ADMITTED (the measured 2026-10-14 case)
    cg 9580 10000 max 3000; A -- true 2>/dev/null; rc=$?
    [ "$rc" -eq 0 ] && ok "A4 raw 95.8% but working set 65% (inactive cache) admitted" || bad "A4 rc=$rc"
    # A5 memory.high max falls back to memory.max; both max => rc 2
    cg 100 max 10000 0; A -- true 2>/dev/null; rc=$?
    cg 100 max max 0; A -- true 2>/dev/null; local rc2=$?
    [ "$rc" -eq 0 ] && [ "$rc2" -eq 2 ] && ok "A5 high=max uses memory.max; no finite limit is rc 2" || bad "A5 rc=$rc/$rc2"
    cg 1000 10000 max 0
    # A6 unreadable metrics are rc 2, never a silent pass
    OV_PSI=/nonexistent A -- true 2>/dev/null; rc=$?
    local rc3; OV_CG=/nonexistent A -- true 2>/dev/null; rc3=$?
    [ "$rc" -eq 2 ] && [ "$rc3" -eq 2 ] && ok "A6 unreadable PSI / cgroup => rc 2" || bad "A6 rc=$rc/$rc3"
    # A7 tmpfs used% over threshold => rc 1 (threshold lowered to 0 so any used filesystem trips it)
    OV_TMPFS="$T" AGENT_ADMIT_TMPFS_MAX_PCT=0 A -- true 2>/dev/null; rc=$?
    [ "$rc" -eq 1 ] && ok "A7 tmpfs used% >= threshold refused rc 1" || bad "A7 rc=$rc"
    # A8 no bounded-run => rc 2 (never runs heavy work unbounded)
    rm -f "$T/ran"; OV_BR=/nonexistent A -- touch "$T/ran" 2>/dev/null; rc=$?
    [ "$rc" -eq 2 ] && [ ! -e "$T/ran" ] && ok "A8 bounded-run absent => rc 2, CMD not run" || bad "A8 rc=$rc"
    # A9 slots: with --slots 1 held by a background run, a second run is refused rc 1 (metric=slots)
    A --slots 1 --tag holder -- bash -c "touch '$T/held'; sleep 4" 2>/dev/null &
    local holder=$!; local w=0; while [ ! -e "$T/held" ] && [ "$w" -lt 50 ]; do sleep 0.1; w=$((w + 1)); done
    out=$(A --slots 1 --tag second -- true 2>&1); rc=$?
    wait "$holder"
    [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'metric=slots' && ok "A9 a busy single slot refuses the second run (metric=slots)" || bad "A9 rc=$rc out=$out"
    # A10 nesting: inside an admitted run a nested call runs directly (no second slot even with --slots 1)
    A --slots 1 --tag outer -- bash -c "AGENT_SCRATCH_ROOT='$T/scr' AGENT_ADMIT_WAIT=0 bash '$SELF' --slots 1 --tag inner -- bash -c 'exit 5'" 2>/dev/null; rc=$?
    [ "$rc" -eq 5 ] && ok "A10 nested call inside an admitted run reuses the held slot (rc 5 passed through)" || bad "A10 rc=$rc"
    # A11 a faked AGENT_ADMITTED_SLOT naming an UNLOCKED slot is not trusted
    mkdir -p "$T/scr/slots"; touch "$T/scr/slots/slot-0"; AGENT_ADMITTED_SLOT="$T/scr/slots/slot-0" AGENT_SCRATCH_ROOT="$T/scr" bash "$SELF" --is-admitted; rc=$?
    [ "$rc" -eq 1 ] && ok "A11 --is-admitted rejects a faked slot env (slot not locked)" || bad "A11 rc=$rc"
    # A12 --verdict3: refusal, undetermined, timeout(124) and bounded-run error(125) all become rc 2
    local v=0
    psi 30; A --verdict3 -- true 2>/dev/null; [ $? -eq 2 ] || v=$((v + 1)); psi 0.5
    OV_PSI=/nonexistent A --verdict3 -- true 2>/dev/null; [ $? -eq 2 ] || v=$((v + 1))
    A --verdict3 -- bash -c 'exit 124' 2>/dev/null; [ $? -eq 2 ] || v=$((v + 1))
    A --verdict3 -- bash -c 'exit 125' 2>/dev/null; [ $? -eq 2 ] || v=$((v + 1))
    A --verdict3 -- bash -c 'exit 1' 2>/dev/null; [ $? -eq 1 ] || v=$((v + 1))
    [ "$v" -eq 0 ] && ok "A12 --verdict3: refused/undet/124/125 -> 2, a real finding (1) passes through" || bad "A12 $v cases wrong"
    # A13 fresh boot: a missing slots dir is recreated, and stale slot files left by a previous boot (no lock
    #     held, one of them mode 000) are reused — admission self-heals and does not wedge after a reboot
    rm -rf "$T/scr/slots"; A --tag boot1 -- true 2>/dev/null; rc=$?
    printf 'stale pid 1 from a previous boot\n' >"$T/scr/slots/slot-0"; chmod 000 "$T/scr/slots/slot-0"; touch "$T/scr/slots/slot-1"
    A --slots 1 --tag boot2 -- true 2>/dev/null; local rc5=$?
    [ "$rc" -eq 0 ] && [ "$rc5" -eq 0 ] && ok "A13 missing slots dir recreated; stale (even mode-000) slot files reused" || bad "A13 rc=$rc/$rc5"
    # A14 a forged AGENT_ADMITTED_SLOT naming ANOTHER job's (locked) slot is not trusted: at PSI 40 the intruder
    #     is refused and never runs (review X1)
    A --slots 1 --tag holder -- bash -c "touch '$T/held14'; sleep 4" 2>/dev/null &
    local h14=$! w14=0; while [ ! -e "$T/held14" ] && [ "$w14" -lt 50 ]; do sleep 0.1; w14=$((w14 + 1)); done
    psi 40; rm -f "$T/intruder"
    AGENT_ADMITTED_SLOT="$T/scr/slots/slot-0" A --slots 1 --tag intruder -- touch "$T/intruder" 2>/dev/null; rc=$?
    psi 0.5; wait "$h14"
    [ "$rc" -ne 0 ] && [ ! -e "$T/intruder" ] && ok "A14 forged slot env of another job: refused (rc $rc), CMD not run" || bad "A14 rc=$rc ran=$([ -e "$T/intruder" ] && echo yes)"
    # A15 a child that OUTLIVES CMD does not keep the slot: CMD runs with the lock fd closed (review leak test)
    A --slots 1 --tag leak -- bash -c "sleep 3 >/dev/null 2>&1 & exit 0" 2>/dev/null; rc=$?
    local st15; st15=$( ( exec {f}>>"$T/scr/slots/slot-0"; flock -n "$f" && echo free || echo HELD ) )
    [ "$rc" -eq 0 ] && [ "$st15" = free ] && ok "A15 slot free right after CMD exits although its child still runs" || bad "A15 rc=$rc slot=$st15"
    # A15b CMD (and so anything it spawns or moves to another scope) does not even hold the slot's fd
    out=$(A --slots 1 --tag fdleak -- bash -c 'ls -l /proc/$$/fd 2>/dev/null | grep -c "slots/slot-"' 2>/dev/null)
    [ "$out" = 0 ] && ok "A15b CMD inherits no fd on the slot file" || bad "A15b slot fds seen by CMD: $out"
    # A16 --verdict3: SIGKILL (137, e.g. the memory cap), not-found (127) and not-executable (126) are rc 2
    local v16=0
    A --verdict3 -- bash -c 'kill -9 $$' 2>/dev/null; [ $? -eq 2 ] || v16=$((v16 + 1))
    A --verdict3 -- /nonexistent-binary-wp1 2>/dev/null; [ $? -eq 2 ] || v16=$((v16 + 1))
    A --verdict3 -- bash -c 'exit 126' 2>/dev/null; [ $? -eq 2 ] || v16=$((v16 + 1))
    A --verdict3 -- bash -c 'exit 3' 2>/dev/null; [ $? -eq 3 ] || v16=$((v16 + 1))
    [ "$v16" -eq 0 ] && ok "A16 --verdict3: 137/127/126 -> 2; an ordinary rc 3 passes through" || bad "A16 $v16 cases wrong"
    # A17 a --tag holding a newline is rc 2 (whole-string regex, not line-wise grep)
    A --tag $'ok\nINJECT' -- true 2>/dev/null; rc=$?
    [ "$rc" -eq 2 ] && ok "A17 newline in --tag refused rc 2" || bad "A17 rc=$rc"
    # A18 shmem >= 10% of RAM refused; unreadable meminfo rc 2
    meminfo 31717516 8100000; A -- true 2>/dev/null; rc=$?
    OV_MI=/nonexistent A -- true 2>/dev/null; local rc18=$?; meminfo 31717516 122260
    [ "$rc" -eq 1 ] && [ "$rc18" -eq 2 ] && ok "A18 shmem 25% of RAM refused rc 1; unreadable meminfo rc 2" || bad "A18 rc=$rc/$rc18"
    # A19 §12.12 thread headroom: 3900 of 4096 threads refused; garbage limit rc 2
    OV_NPROC=4096 OV_LIVE=3900 A -- true 2>/dev/null; rc=$?
    OV_NPROC=bogus A -- true 2>/dev/null; local rc19=$?
    [ "$rc" -eq 1 ] && [ "$rc19" -eq 2 ] && ok "A19 thread headroom 196 of 4096 refused rc 1; unreadable limit rc 2" || bad "A19 rc=$rc/$rc19"
    # W1-W3 wiring: each heavy entry point turns an admission refusal into rc 2 (never a pass, never a finding)
    psi 40
    local E=(AGENT_SCRATCH_ROOT="$T/scr" AGENT_ADMIT_PSI_FILE="$T/psi" AGENT_ADMIT_CGROUP="$T/cg" AGENT_ADMIT_TMPFS="$T/absent-mount" AGENT_ADMIT_MEMINFO="$T/meminfo" AGENT_ADMIT_NPROC_LIMIT=10000 AGENT_ADMIT_THREADS_LIVE=100 AGENT_ADMIT_BOUNDED_RUN="$T/fake-br" AGENT_ADMIT_WAIT=0)
    # Each wiring case first checks STATICALLY that the entry point calls this wrapper: an unwired entry
    # point would otherwise run its real heavy work (a full scan, go test) from inside this proof.
    wired() { grep -q 'agent-admit.sh' "$UMBRELLA/scripts/$1"; }
    if ! wired pre-push-gates.sh; then bad "W1 scripts/pre-push-gates.sh does not call agent-admit.sh (not executed)"; else
    out=$(env -u AGENT_ADMITTED_SLOT "${E[@]}" PREPUSH_ONLY=1 bash "$UMBRELLA/scripts/pre-push-gates.sh" 2>&1); rc=$?
    if printf '%s' "$out" | grep -q 'UNDET gate 1' && printf '%s' "$out" | grep -q 'failed=0  undetermined=1' && [ "$rc" -ne 0 ]; then
        ok "W1 pre-push gate 1 under refusal: UNDET (rc 2), failed=0, push blocked (rc $rc)"
    else bad "W1 rc=$rc $(printf '%s' "$out" | grep -E 'gate 1|passed=' | head -3)"; fi; fi
    if ! wired zero-gap-verify.sh; then bad "W2 scripts/zero-gap-verify.sh does not call agent-admit.sh (not executed)"; else
    out=$(env -u AGENT_ADMITTED_SLOT "${E[@]}" ZG_SESSION_ID=prove bash "$UMBRELLA/scripts/zero-gap-verify.sh" --item VSC-367 2>&1); rc=$?
    [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'agent-admit: REFUSED' && ok "W2 zero-gap-verify under refusal: rc 2" || bad "W2 rc=$rc $(printf '%s' "$out" | tail -2)"; fi
    if ! wired verify-content-boundary.sh; then bad "W3 scripts/verify-content-boundary.sh does not call agent-admit.sh (not executed)"; else
    out=$(env -u AGENT_ADMITTED_SLOT "${E[@]}" bash "$UMBRELLA/scripts/verify-content-boundary.sh" 2>&1); rc=$?
    [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'agent-admit: REFUSED' && ok "W3 verify-content-boundary under refusal: rc 2" || bad "W3 rc=$rc $(printf '%s' "$out" | tail -2)"; fi
    psi 0.5
    # W4 a gate whose admitted command is SIGKILLed (rc 137, e.g. the -m cap) is UNDET/rc 2, never FAIL
    printf '#!/usr/bin/env bash\nkill -9 $$\n' >"$T/kill-br"; chmod +x "$T/kill-br"
    local E4=(AGENT_SCRATCH_ROOT="$T/scr" AGENT_ADMIT_PSI_FILE="$T/psi" AGENT_ADMIT_CGROUP="$T/cg" AGENT_ADMIT_TMPFS="$T/absent-mount" AGENT_ADMIT_MEMINFO="$T/meminfo" AGENT_ADMIT_NPROC_LIMIT=10000 AGENT_ADMIT_THREADS_LIVE=100 AGENT_ADMIT_BOUNDED_RUN="$T/kill-br" AGENT_ADMIT_WAIT=0)
    if wired pre-push-gates.sh; then
        out=$(env -u AGENT_ADMITTED_SLOT "${E4[@]}" PREPUSH_ONLY=1 bash "$UMBRELLA/scripts/pre-push-gates.sh" 2>&1); rc=$?
        printf '%s' "$out" | grep -q 'failed=0  undetermined=1' && ok "W4 pre-push gate 1 with a SIGKILLed command: UNDET, failed=0 (rc $rc)" || bad "W4 $(printf '%s' "$out" | grep -E 'gate 1|passed=' | head -3)"
    fi
    out=$(env -u AGENT_ADMITTED_SLOT "${E4[@]}" ZG_SESSION_ID=prove bash "$UMBRELLA/scripts/zero-gap-verify.sh" --item VSC-367 2>&1); rc=$?
    [ "$rc" -eq 2 ] && ok "W5 zero-gap-verify with a SIGKILLed admitted run: rc 2" || bad "W5 rc=$rc"
    out=$(env -u AGENT_ADMITTED_SLOT "${E4[@]}" bash "$UMBRELLA/scripts/verify-content-boundary.sh" 2>&1); rc=$?
    [ "$rc" -eq 2 ] && ok "W6 verify-content-boundary with a SIGKILLed admitted run: rc 2" || bad "W6 rc=$rc"
    # M1 mutation: the PSI comparison neutered => A2's detector sees an overloaded host admitted
    sed 's/^    awk -v v="\$v" -v m="\$PSI_MAX".*/    return 0/' "$SELF" >"$T/m1.sh"
    psi 22.00; SCRIPT="$T/m1.sh" A -- true 2>/dev/null; rc=$?; psi 0.5
    [ "$rc" -eq 0 ] && ok "M1 a mutant without the PSI comparison admits PSI 22 (A2 would FAIL)" || bad "M1 rc=$rc"
    # M2 mutation: the inactive_file subtraction removed => A4's detector sees the cache-heavy idle host refused
    sed 's/^    work=\$(( cur > inact ? cur - inact : 0 ))/    work=$cur/' "$SELF" >"$T/m2.sh"
    cg 9580 10000 max 3000; SCRIPT="$T/m2.sh" A -- true 2>/dev/null; rc=$?; cg 1000 10000 max 0
    [ "$rc" -eq 1 ] && ok "M2 a mutant gating on the raw ratio refuses an idle cache-heavy host (A4 would FAIL)" || bad "M2 rc=$rc"
    # M3 mutation: --verdict3 mapping removed => A12's detector sees a refusal surface as rc 1
    sed 's/^    if \[ "\$VERDICT3" -eq 1 \]; then say "VERDICT=.*/    :/' "$SELF" >"$T/m3.sh"
    psi 30; SCRIPT="$T/m3.sh" A --verdict3 -- true 2>/dev/null; rc=$?; psi 0.5
    [ "$rc" -eq 1 ] && ok "M3 a mutant without the verdict3 mapping returns 1 for a refusal (A12 would FAIL)" || bad "M3 rc=$rc"
    # M4 mutation: the stale-slot repair removed => A13's detector sees a mode-000 slot wedge admission (rc 2)
    sed '/^                chmod 600 -- "\$SLOTS_DIR\/slot-\$i" 2>\/dev\/null$/d' "$SELF" >"$T/m4.sh"
    printf 'stale\n' >"$T/scr/slots/slot-0"; chmod 000 "$T/scr/slots/slot-0"
    SCRIPT="$T/m4.sh" A --slots 1 -- true 2>/dev/null; rc=$?; chmod 600 "$T/scr/slots/slot-0"
    [ "$rc" -eq 2 ] && ok "M4 a mutant without the stale-slot repair wedges on a mode-000 slot (A13 would FAIL)" || bad "M4 rc=$rc"
    mut() { # $1 name  $2 old  $3 new -> $T/$1.sh (fails the proof if the anchor moved)
        python3 -I -c 'import sys
s=open(sys.argv[1]).read(); o,n=sys.argv[2],sys.argv[3]
sys.exit(3) if o not in s else open(sys.argv[4],"w").write(s.replace(o,n,1))' "$SELF" "$2" "$3" "$T/$1.sh" || bad "$1 mutation anchor not found"; }
    # M5 ancestry check removed => A14's forged-slot intruder is admitted
    mut m5 '    is_ancestor "$holder" || return 1' '    :'
    A --slots 1 --tag holder -- bash -c "touch '$T/held-m5'; sleep 4" 2>/dev/null &
    local hm=$! wm=0; while [ ! -e "$T/held-m5" ] && [ "$wm" -lt 50 ]; do sleep 0.1; wm=$((wm + 1)); done
    psi 40; rm -f "$T/intruder"
    AGENT_ADMITTED_SLOT="$T/scr/slots/slot-0" SCRIPT="$T/m5.sh" A --slots 1 -- touch "$T/intruder" 2>/dev/null
    psi 0.5; wait "$hm"
    [ -e "$T/intruder" ] && ok "M5 a mutant without the ancestor check lets a forged slot ride (A14 would FAIL)" || bad "M5 not caught"
    # M6 fd not closed for CMD => A15's outliving child keeps the slot
    mut m6 '"${argv[@]}" {fd}>&-; rc=$?' '"${argv[@]}"; rc=$?'
    out=$(SCRIPT="$T/m6.sh" A --slots 1 -- bash -c 'ls -l /proc/$$/fd 2>/dev/null | grep -c "slots/slot-"' 2>/dev/null)
    [ "$out" != 0 ] && ok "M6 a mutant that leaks the lock fd hands it to CMD (A15b would FAIL)" || bad "M6 fds=$out"
    # M7 only 124/125 mapped => A16's SIGKILL surfaces as 137
    mut m7 'if [ "$rc" -ge 124 ]; then' 'if [ "$rc" -eq 124 ] || [ "$rc" -eq 125 ]; then'
    SCRIPT="$T/m7.sh" A --verdict3 -- bash -c 'kill -9 $$' 2>/dev/null; rc=$?
    [ "$rc" -eq 137 ] && ok "M7 a mutant mapping only 124/125 returns 137 for SIGKILL (A16 would FAIL)" || bad "M7 rc=$rc"
    # M8 shmem comparison neutered => A18's 25%-shmem host is admitted
    mut m8 '[ "$pct" -lt "$SHMEM_MAX" ] && return 0' 'return 0'
    meminfo 31717516 8100000; SCRIPT="$T/m8.sh" A -- true 2>/dev/null; rc=$?; meminfo 31717516 122260
    [ "$rc" -eq 0 ] && ok "M8 a mutant without the shmem gate admits 25% shmem (A18 would FAIL)" || bad "M8 rc=$rc"
    # M9 thread gate neutered => A19's near-limit host is admitted
    mut m9 'if [ "$pct" -ge "$THREADS_MAX" ] || [ "$head" -lt "$THREADS_MIN_HEADROOM" ]; then' 'if false; then'
    OV_NPROC=4096 OV_LIVE=3900 SCRIPT="$T/m9.sh" A -- true 2>/dev/null; rc=$?
    [ "$rc" -eq 0 ] && ok "M9 a mutant without the thread gate admits 196 threads of headroom (A19 would FAIL)" || bad "M9 rc=$rc"
    # M10 tag validated line-wise again => A17's newline tag passes
    mut m10 '[[ "$tag" =~ ^[A-Za-z0-9_.-]{1,40}$ ]]' "printf '%s' \"\$tag\" | grep -Eq '^[A-Za-z0-9_.-]{1,40}\$'"
    SCRIPT="$T/m10.sh" A --tag $'ok\nINJECT' -- true 2>/dev/null; rc=$?
    [ "$rc" -eq 0 ] && ok "M10 a mutant with line-wise tag validation accepts a newline tag (A17 would FAIL)" || bad "M10 rc=$rc"
    echo "agent-admit --prove-failure: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}

case "${1:-}" in
    --prove-failure) prove; exit $? ;;
    --check) prechecks; exit $? ;;
    --is-admitted) is_admitted; exit $? ;;
    -h|--help) sed -n '2,52p' "$SELF"; exit 0 ;;
    '') say "usage: $0 [--slots N] [--tag T] [--wait S] [--verdict3] [-m MEM] [-T S] -- CMD... | --check | --is-admitted | --prove-failure"; exit 2 ;;
    *) admit_and_run "$@" ;;
esac
