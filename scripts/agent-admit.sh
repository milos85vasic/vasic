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
#   --slots N     heavy slots (default 2): lock files <scratch>/slots/slot-0..N-1, held with flock(1)
#                 semantics for the WHOLE run (the fd is inherited by bounded-run and CMD)
#   --wait SECS   how long to wait for a free slot (default $AGENT_ADMIT_WAIT or 300); then refused
#   --tag T       label for the scope name and messages ([A-Za-z0-9_.-])
#   -m / -T       bounded-run MemoryMax and wall clock (default $AGENT_ADMIT_MEM or 6G, $AGENT_ADMIT_TIMEOUT
#                 or 3600)
#   --verdict3    for three-valued callers (0 holds / 1 finding / 2 cannot determine): a refusal, an
#                 undeterminable pre-check, a bounded-run timeout (124) or bounded-run's own error (125)
#                 all become rc 2 — NEVER a pass and never mistakable for a finding. CMD's 0/1/2 pass through.
#
# PRE-CHECKS (after a slot is held; any one failing refuses):
#   memory PSI    /proc/pressure/memory  `some avg10` < $AGENT_ADMIT_PSI_MAX (15)
#   tmpfs         used% of /tmp ($AGENT_ADMIT_TMPFS)  < $AGENT_ADMIT_TMPFS_MAX_PCT (40)
#   app.slice     (memory.current - inactive_file) / memory.high  < $AGENT_ADMIT_SLICE_MAX_PCT (85)
#                 cgroup dir: $AGENT_ADMIT_CGROUP, default the user manager's app.slice. memory.high "max"
#                 falls back to memory.max; both "max" or any file unreadable => cannot determine (rc 2).
#                 WHY inactive_file is subtracted (a measured deviation from a raw current/high ratio): on
#                 2026-10-14 15:00 the raw ratio was 21.79/22.74 GB = 95.8% with PSI 0.00 — 6.74 GB of it
#                 was inactive page cache the kernel drops at once. A raw-ratio gate would have refused every
#                 job on an idle host, i.e. a guard asserting the wrong condition (§11.4.201). Both ratios
#                 are printed; only the working-set one gates.
#
# EXIT (default mode)  0 / CMD's own rc after a run (via exec, so it IS CMD's rc; bounded-run adds 124
#                      timeout and 125 its own error) | 1 REFUSED by pressure or no slot (message names the
#                      metric) | 2 cannot determine (unreadable metric, no bounded-run, bad usage).
#      (--verdict3)    see above.   --check: 0 admit / 1 refuse / 2 cannot determine.
#
# NESTING. An admitted run exports AGENT_ADMITTED_SLOT=<its slot file>. A nested call whose slot file is
# a real slot under this root AND is currently locked runs CMD directly (no second slot, no second
# scope) — the real condition is checked, a bare env var naming an unlocked file is not trusted.
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
TMPFS_PATH="${AGENT_ADMIT_TMPFS:-/tmp}"
TMPFS_MAX="${AGENT_ADMIT_TMPFS_MAX_PCT:-40}"
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

check_tmpfs() {
    local b f pct
    read -r b f < <(stat -f -c '%b %f' -- "$TMPFS_PATH" 2>/dev/null) || true
    [ -n "${b:-}" ] && [ "${b:-0}" -gt 0 ] 2>/dev/null || { say "CANNOT DETERMINE: cannot stat filesystem of $TMPFS_PATH"; return 2; }
    pct=$(( (b - f) * 100 / b ))
    echo "metric tmpfs_used_pct=$pct path=$TMPFS_PATH fs=$(stat -f -c %T -- "$TMPFS_PATH" 2>/dev/null) threshold<$TMPFS_MAX"
    [ "$pct" -lt "$TMPFS_MAX" ] && return 0
    say "REFUSED: $TMPFS_PATH is ${pct}% used (>= ${TMPFS_MAX}%): RAM-backed tmpfs pages are unreclaimable; clean up /tmp copies first (scripts/agent-scratch.sh)"
    return 1
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
    for c in check_psi check_tmpfs check_slice; do
        "$c"; rc=$?
        # a refusal (1) outranks could-not-determine (2): a measured overload is a fact
        if [ "$rc" -eq 1 ]; then worst=1; elif [ "$rc" -eq 2 ] && [ "$worst" -eq 0 ]; then worst=2; fi
    done
    return "$worst"
}

# ---- nesting: is THIS process inside an admitted run? (the slot must be real AND locked) ---------------
is_admitted() {
    local s="${AGENT_ADMITTED_SLOT:-}" rs rd fd
    [ -n "$s" ] && [ -f "$s" ] || return 1
    rs=$(realpath -e -- "$s" 2>/dev/null) && rd=$(realpath -e -- "$SLOTS_DIR" 2>/dev/null) || return 1
    [ "$(dirname -- "$rs")" = "$rd" ] || return 1
    exec {fd}<"$rs" || return 1
    if flock -n "$fd"; then flock -u "$fd"; exec {fd}<&-; return 1; fi
    exec {fd}<&-
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
    printf '%s' "$tag" | grep -Eq '^[A-Za-z0-9_.-]{1,40}$' || { say "bad --tag '$tag'"; refuse 2; }

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
    if [ "$VERDICT3" -eq 0 ]; then
        exec "${argv[@]}"
    fi
    "${argv[@]}"; local rc=$?
    case "$rc" in
        124) say "VERDICT=timeout: bounded-run wall clock (-T $tmo) expired -> rc 2 (never a pass)"; exit 2 ;;
        125) say "VERDICT=bounded-run-error (rc 125) -> rc 2 (never a pass)"; exit 2 ;;
    esac
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
    A() { AGENT_SCRATCH_ROOT="$T/scr" AGENT_ADMIT_PSI_FILE="${OV_PSI:-$T/psi}" AGENT_ADMIT_CGROUP="${OV_CG:-$T/cg}" AGENT_ADMIT_TMPFS="$T" \
          AGENT_ADMIT_BOUNDED_RUN="${OV_BR:-$T/fake-br}" AGENT_ADMIT_WAIT=0 bash "${SCRIPT:-$SELF}" "$@"; }
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
    AGENT_ADMIT_TMPFS_MAX_PCT=0 A -- true 2>/dev/null; rc=$?
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
    # W1-W3 wiring: each heavy entry point turns an admission refusal into rc 2 (never a pass, never a finding)
    psi 40
    local E=(AGENT_SCRATCH_ROOT="$T/scr" AGENT_ADMIT_PSI_FILE="$T/psi" AGENT_ADMIT_CGROUP="$T/cg" AGENT_ADMIT_TMPFS="$T" AGENT_ADMIT_BOUNDED_RUN="$T/fake-br" AGENT_ADMIT_WAIT=0)
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
