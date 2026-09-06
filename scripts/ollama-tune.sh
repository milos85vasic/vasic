#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# ollama-tune.sh — derive ollama concurrency settings FROM THIS HOST.
#
# WHY THIS EXISTS
# ---------------
# This project index-embeds through a local ollama. When several clients embed
# concurrently and OLLAMA_NUM_PARALLEL resolves to 1, ollama serialises them:
# every request after the first waits for the whole queue ahead of it. Measured
# here, a single embed went from 0.74s to a >90s client timeout, which stalled
# indexing entirely. The tuning is real. What was WRONG was the first proposal:
#
#     sudo cp /etc/sysconfig/ollama /etc/sysconfig/ollama.bak
#     echo 'OLLAMA_NUM_PARALLEL=4' | sudo tee -a /etc/sysconfig/ollama
#     sudo systemctl restart ollama
#
# Two hardcoded assumptions, neither of which survives a second machine:
#   * `/etc/sysconfig/ollama` is ONE distro's packaging. Debian/Ubuntu ship no
#     such file, a user-level unit reads a different one, macOS has none at all,
#     and a container has no file surface whatsoever.
#   * `4` was a guess from an 8-CPU box. On a 2-vCPU cgroup-capped VM it
#     oversubscribes; on a 64-core host it leaves throughput on the table.
#
# So NOTHING here is written down in advance. The service manager, the config
# file, the restart command and the number are all discovered or computed at
# run time, and every input is printed next to its output so the arithmetic can
# be audited rather than trusted.
#
# USAGE
#   scripts/ollama-tune.sh                  # report only (default, read-only)
#   scripts/ollama-tune.sh --dry-run        # show the exact diff, change nothing
#   scripts/ollama-tune.sh --print-commands # emit operator commands for THIS host
#   scripts/ollama-tune.sh --apply          # apply + restart + verify
#   scripts/ollama-tune.sh --revert         # undo what --apply wrote
#   scripts/ollama-tune.sh --measure        # embed latency / concurrency probe
#   scripts/ollama-tune.sh --help
#
# EXIT CODES (this repo's three-valued convention — see
# scripts/lumen-index-doctor.sh and scripts/verify-all-constitution-rules.sh)
#   0 = fine            nothing to change, or the change was applied AND verified
#   1 = a real problem  tuning is needed / apply refused / apply failed
#   2 = COULD NOT DETERMINE   no ollama, remote ollama, no discoverable surface,
#                             or the effect could not be confirmed
# "Could not check" is never reported as either success or failure.
#
# IMPLEMENTATION NOTES (each of these is a bug this repo has already paid for)
#   * `set -uo pipefail` WITHOUT `-e`: a failed `cd` is silent, so every exit
#     status that matters is checked explicitly.
#   * A pipeline's status is its LAST command's, so `cmd | sed … || fallback`
#     never fires. Output is captured first, then tested for emptiness.
#   * `pgrep -f <pattern>` matches the pgrep caller's OWN command line. Every
#     process scan below filters out this PID, its whole ancestor chain, and
#     anything carrying this script's name.
# ------------------------------------------------------------------------------
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)" || {
    echo "FATAL: cannot resolve repository root" >&2; exit 2; }
SELF_NAME="$(basename -- "${BASH_SOURCE[0]}")"
SELF_PATH="${BASH_SOURCE[0]}"
# The sibling wrapper whose long rebuilds the restart guard exists to protect.
# Derived from ROOT, never written down — see scripts/audit-hardcoded-paths.sh.
REINDEX_SCRIPT="${ROOT}/scripts/lumen-reindex.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $*${NC}"; }
bad()  { echo -e "${RED}❌ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
dim()  { echo -e "${DIM}   $*${NC}"; }
hdr()  { echo; echo -e "${BOLD}── $* ${NC}"; }

# ── Tunable bounds ────────────────────────────────────────────────────────────
# Deliberately few knobs, all overridable so a "what if" can be audited without
# editing the script (the mutation proof uses exactly these).
PARALLEL_MIN="${OLLAMA_TUNE_MIN:-1}"        # 1 == today's serialised behaviour
PARALLEL_MAX="${OLLAMA_TUNE_MAX:-8}"        # see clamp rationale in compute()
MEM_PCT="${OLLAMA_TUNE_MEM_PCT:-50}"        # share of AVAILABLE ram we may claim
SMALL_MODEL_MB="${OLLAMA_TUNE_SMALL_MB:-1024}"
KEEPALIVE_TARGET="${OLLAMA_TUNE_KEEPALIVE:-30m}"
PROBE_TIMEOUT="${OLLAMA_TUNE_PROBE_TIMEOUT:-120}"
PROBE_CONCURRENCY="${OLLAMA_TUNE_PROBE_N:-4}"
DROPIN_NAME="10-vasic-ollama-tune.conf"     # our file, and only ours
BAK_SUFFIX="vasic-bak"

# ── Modes ─────────────────────────────────────────────────────────────────────
MODE="report"; FORCE=0; WANT_MEASURE=0; WITH_KEEPALIVE=1
UNIT_OVERRIDE=""; HOST_OVERRIDE=""; PROVE=0

usage() {
    cat <<EOF
${SELF_NAME} — derive and apply ollama concurrency settings from this host.

  (no flags)         report only; changes nothing
  --dry-run          show exactly what would change, change nothing
  --print-commands   print copy-pasteable commands built for THIS host
  --apply            write the config, restart via the detected mechanism, verify
  --revert           undo what --apply wrote (restores the newest backup)
  --measure          probe embed latency and whether requests actually overlap
  --force            override the in-flight-job guard (restarting ollama kills
                     in-flight embed requests — a running index rebuild dies)
  --no-keep-alive    tune OLLAMA_NUM_PARALLEL only, leave OLLAMA_KEEP_ALIVE alone
  --unit NAME        override service-unit discovery
  --host URL         override OLLAMA_HOST discovery
  --prove-failure    run the §1.1 paired mutation proof against a throwaway,
                     PATH-shimmed host; this host is never written to
  -h, --help         this text

Audit overrides (print different inputs to prove the formula is not a constant):
  OLLAMA_TUNE_CPUS=N  OLLAMA_TUNE_AVAIL_MB=N  OLLAMA_TUNE_MODEL_MB=N
  OLLAMA_TUNE_MIN=N   OLLAMA_TUNE_MAX=N       OLLAMA_TUNE_MEM_PCT=N

Exit: 0 fine · 1 real problem · 2 COULD NOT DETERMINE
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)        MODE="dry-run" ;;
        --apply)          MODE="apply" ;;
        --print-commands) MODE="print-commands" ;;
        --revert)         MODE="revert" ;;
        --measure)        WANT_MEASURE=1; [[ $MODE == report ]] && MODE="measure" ;;
        --force)          FORCE=1 ;;
        --no-keep-alive)  WITH_KEEPALIVE=0 ;;
        --unit)           shift; UNIT_OVERRIDE="${1:-}" ;;
        --host)           shift; HOST_OVERRIDE="${1:-}" ;;
        --prove-failure)  PROVE=1 ;;
        -h|--help)        usage; exit 0 ;;
        # A silently ignored typo is how `--forse` once produced an incremental
        # run when a rebuild was intended. Unknown flags are fatal.
        *) echo "${SELF_NAME}: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [[ $PROVE -eq 1 ]]; then
    # ══════════════════════════════════════════════════════════════════════════
    # §1.1 PAIRED MUTATION PROOF  —  --prove-failure
    #
    # WHAT IS UNDER TEST. The verdict: 0 = the running daemon already meets the
    # computed recommendation, 1 = it does not, 2 = the question could not be
    # answered. Everything this script asserts about a host is worthless if that
    # three-way split cannot be shown to move.
    #
    # WHY THE HOST IS SHIMMED, NOT MOCKED IN CODE. The subject is a host
    # detector, so a control built on THIS host is green only while THIS host
    # happens to be tuned — the "inoperative proof" defect recorded in
    # docs/check-registry.md. Instead the real code paths run unchanged against a
    # SYNTHETIC host: `systemctl`, `journalctl`, `curl`, `podman`, `docker`,
    # `pgrep`, `ss`, `sudo` and `systemd-path` are replaced by stubs on PATH
    # inside a `mktemp -d`, and the daemon's running OLLAMA_NUM_PARALLEL is data
    # the stub journal prints. That makes the control green BY CONSTRUCTION and
    # every mutation a change of evidence rather than a change of code.
    #
    # PATH-shimming is this repository's existing idiom for exactly this problem
    # — scripts/verify-check-registry.sh --prove-filemode shims `stat` the same
    # way — so it is reused rather than reinvented.
    #
    # PINNED CLAMP. OLLAMA_TUNE_MIN/MAX are pinned equal, so RECOMMENDED is the
    # same integer on every host regardless of how many CPUs or how much memory
    # the box running this proof has. Without that, a build machine with a
    # 2-vCPU cgroup and this workstation would need different assertions, and an
    # assertion that has to be tuned per host is not an assertion.
    #
    # HERMETIC. curl is stubbed to fail, so no request leaves this process and
    # this host's REAL ollama — which may well be running — cannot reach any
    # verdict below. Nothing outside the sandbox is created, written or removed;
    # no service is started, stopped or restarted; no config file is touched.
    # ══════════════════════════════════════════════════════════════════════════
    P_PASS=0; P_FAIL=0
    p_ok()  { P_PASS=$((P_PASS+1)); printf '✅ %-30s %s\n' "$1" "$2"; }
    p_bad() { P_FAIL=$((P_FAIL+1)); printf '❌ %-30s %s\n' "$1" "$2"; }

    echo "OLLAMA-TUNE §1.1 PAIRED MUTATION PROOF"
    echo "----------------------------------------------------------------------"

    # ---- PRE-FLIGHT: the REAL entry point on the REAL host — reported --------
    # report mode is read-only by construction (nothing below `--apply` writes),
    # so this is safe to run against the live host. It gates nothing.
    pf_out="$(timeout 180 bash "$SELF_PATH" 2>&1)"; pf_rc=$?
    case "$pf_rc" in
        0|1|2) printf 'ℹ %-30s the real entry point ran against the REAL host and returned rc=%s\n' "PRE-FLIGHT live-run" "$pf_rc"
               printf '%-32s (%s). REPORTED, never gating — the battery below uses a synthetic host.\n' "" \
                      "$(case $pf_rc in 0) echo "already tuned";; 1) echo "tuning needed";; *) echo "could not determine";; esac)" ;;
        124)   p_bad "PRE-FLIGHT live-run" "the real entry point TIMED OUT on the real host — it cannot start, so it cannot report" ;;
        *)     p_bad "PRE-FLIGHT live-run" "the real entry point exited rc=${pf_rc}, outside its own 0/1/2 contract"
               printf '%s\n' "$pf_out" | tail -3 | sed 's/^/        /' ;;
    esac

    TSB="$(mktemp -d "${TMPDIR:-/tmp}/ollama-tune-proof.XXXXXX")" || {
        echo "ollama-tune: UNDETERMINED — cannot create a sandbox; nothing was proved" >&2; exit 2; }
    trap 'rm -rf "$TSB"' EXIT INT TERM     # cleanup: the synthetic host lives and dies inside $TSB
    echo "  sandbox: $TSB"
    mkdir -p "$TSB/bin" || { echo "ollama-tune: UNDETERMINED — cannot populate the sandbox" >&2; exit 2; }

    # -- the synthetic host -----------------------------------------------------
    cat > "$TSB/bin/systemctl" <<'STUB_SYSTEMCTL'
#!/usr/bin/env bash
# A systemd that owns exactly one loaded unit: ollama.service, system scope.
scope=""
[ "${1:-}" = "--user" ] && { scope="user"; shift; }
case "${1:-}" in
  list-units|list-unit-files)
      [ -n "$scope" ] && exit 0
      echo "ollama.service loaded active running Ollama"
      exit 0 ;;
  show)
      [ -n "$scope" ] && exit 0
      unit="${2:-}"; prop=""; prev=""
      for a in "$@"; do [ "$prev" = "-p" ] && { prop="$a"; break; }; prev="$a"; done
      [ "$unit" = "ollama.service" ] || { echo "not-found"; exit 0; }
      case "$prop" in
        LoadState)             echo "loaded" ;;
        ActiveState)           echo "active" ;;
        FragmentPath)          echo "/usr/lib/systemd/system/ollama.service" ;;
        ExecStart)             echo "" ;;
        EnvironmentFiles)      echo "" ;;
        CPUQuotaPerSecUSec)    echo "infinity" ;;
        AllowedCPUs)           echo "" ;;
        ActiveEnterTimestamp)  echo "Mon 2026-09-02 00:00:00 UTC" ;;
        MainPID)               echo "0" ;;
        *)                     echo "" ;;
      esac
      exit 0 ;;
esac
exit 1
STUB_SYSTEMCTL

    cat > "$TSB/bin/journalctl" <<'STUB_JOURNALCTL'
#!/usr/bin/env bash
# ollama's one-shot startup line, with the running value supplied as DATA.
# PROOF_RUNNING_PARALLEL=none means the daemon logged no such line at all.
p="${PROOF_RUNNING_PARALLEL:-1}"
[ "$p" = "none" ] && exit 0
printf 'Sep 02 00:00:01 synthetic ollama[1]: level=INFO msg="server config" env="map[OLLAMA_KEEP_ALIVE:5m0s OLLAMA_NUM_PARALLEL:%s OLLAMA_MAX_QUEUE:512]"\n' "$p"
exit 0
STUB_JOURNALCTL

    # curl fails: the API is unreachable, so nothing leaves this process and the
    # real ollama on this host cannot influence a single assertion below.
    printf '#!/usr/bin/env bash\nexit 7\n'            > "$TSB/bin/curl"
    # No container runtime owns it; no bare process; no established connections;
    # no sudo; no systemd-path. Each of these is a real branch being pinned.
    printf '#!/usr/bin/env bash\nexit 1\n'            > "$TSB/bin/podman"
    printf '#!/usr/bin/env bash\nexit 1\n'            > "$TSB/bin/docker"
    printf '#!/usr/bin/env bash\nexit 1\n'            > "$TSB/bin/pgrep"
    printf '#!/usr/bin/env bash\nexit 0\n'            > "$TSB/bin/ss"
    printf '#!/usr/bin/env bash\nexit 1\n'            > "$TSB/bin/sudo"
    printf '#!/usr/bin/env bash\nexit 1\n'            > "$TSB/bin/systemd-path"
    chmod 755 "$TSB/bin"/* || { echo "ollama-tune: UNDETERMINED — cannot chmod the stubs" >&2; exit 2; }

    # Pinned so RECOMMENDED is the same integer on every host (see the header).
    PIN_MIN=4; PIN_MAX=4

    # run_synth <running-parallel> [extra argv...] — the REAL script, unmodified,
    # against the synthetic host.
    run_synth() {
        local running="$1"; shift
        env PATH="$TSB/bin:$PATH" \
            HOME="$TSB" \
            PROOF_RUNNING_PARALLEL="$running" \
            OLLAMA_HOST="" \
            OLLAMA_TUNE_CPUS=8 \
            OLLAMA_TUNE_AVAIL_MB=32768 \
            OLLAMA_TUNE_MODEL_MB=512 \
            OLLAMA_TUNE_MIN="${PIN_MIN}" \
            OLLAMA_TUNE_MAX="${PIN_MAX}" \
            timeout 180 bash "$SELF_PATH" "$@" 2>&1
    }

    # assert <label> <running> <want-rc> <needle> [argv...]
    assert() {
        local label="$1" running="$2" want="$3" needle="$4"; shift 4
        local out rc
        out="$(run_synth "$running" "$@")"; rc=$?
        if [[ $rc -ne $want ]]; then
            p_bad "$label" "expected rc=${want}, got rc=${rc}"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            return
        fi
        if [[ -n "$needle" ]] && ! grep -qF -- "$needle" <<<"$out"; then
            p_bad "$label" "rc=${want} as required, but the output never NAMED '${needle}'"
            printf '%s\n' "$out" | tail -6 | sed 's/^/        /'
            return
        fi
        p_ok "$label" "rc=${rc}${needle:+, and it named '${needle}'}"
    }

    # ---- CONTROL: the synthetic daemon already meets the recommendation -------
    assert "CONTROL synthetic-tuned    " "$PIN_MAX" 0 "already meets the computed recommendation"
    if [[ $P_FAIL -gt 0 ]]; then
        echo "----------------------------------------------------------------------"
        echo "❌ OLLAMA-TUNE §1.1 PROOF: ABORTED — the synthetic control did not pass, so ZERO"
        echo "   mutations ran and nothing below would have been proved."
        exit 1
    fi

    # ---- M1  the running value is BELOW the recommendation — the whole point --
    assert "M1 running-below-recommend " "$((PIN_MAX - 1))" 1 "tuning needed"
    # ---- M2  the daemon carries no value at all ------------------------------
    assert "M2 running-value-empty     " "" 1 "tuning needed"
    # ---- M3  ABOVE the recommendation is fine, not a finding ------------------
    # A gate that reddens on "more than enough" would be crying wolf.
    assert "M3 running-above-recommend " "$((PIN_MAX + 3))" 0 "already meets the computed recommendation"
    # ---- M4  the daemon logged nothing readable -> rc 2, never 0 -------------
    assert "M4 running-unreadable      " "none" 2 "COULD NOT DETERMINE whether tuning is needed"
    # ---- M5  the running value is not a number -> rc 2, never a pass ---------
    assert "M5 running-non-numeric     " "auto" 2 "COULD NOT DETERMINE whether tuning is needed"
    # ---- M6  the unit does not exist -> nothing owns ollama -> rc 2 ----------
    assert "M6 unit-not-found          " "$PIN_MAX" 2 "COULD NOT DETERMINE whether tuning is needed" --unit nonexistent.service
    # ---- M7  a REMOTE daemon has no local surface to tune -> rc 2 ------------
    # 192.0.2.10 is RFC 5737 TEST-NET-1: reserved for documentation, so it is
    # never an address of the machine running this proof.
    assert "M7 remote-daemon           " "$PIN_MAX" 2 "REMOTE daemon" --host 192.0.2.10:11434

    # ---- M8  neither CPU nor memory readable -> COULD NOT DETERMINE ----------
    # Both caps unknown is the one state where the formula itself abstains. It
    # must not fall back to a default number.
    _m8="$(env PATH="$TSB/bin:$PATH" HOME="$TSB" PROOF_RUNNING_PARALLEL=1 OLLAMA_HOST="" \
               OLLAMA_TUNE_CPUS=0 OLLAMA_TUNE_AVAIL_MB=0 OLLAMA_TUNE_MODEL_MB=512 \
               OLLAMA_TUNE_MIN="$PIN_MIN" OLLAMA_TUNE_MAX="$PIN_MAX" \
               timeout 180 bash "$SELF_PATH" 2>&1)"; _m8rc=$?
    if [[ $_m8rc -eq 2 ]] && grep -qF "neither CPU nor memory facts were readable" <<<"$_m8"; then
        p_ok "M8 host-unmeasurable      " "rc=2, and it abstained instead of inventing a number"
    else
        p_bad "M8 host-unmeasurable     " "expected rc=2 naming the unreadable host facts, got rc=${_m8rc}"
    fi

    # ---- M9  the recommendation is COMPUTED, not frozen ----------------------
    # Same synthetic host, different declared bounds: the printed value must
    # move. This shows the number follows its inputs; it is not a claim that
    # every term of the formula was exercised.
    _a="$(run_synth "$PIN_MAX" | grep -oE 'OLLAMA_NUM_PARALLEL = [0-9]+' | head -1)"
    _b="$(env PATH="$TSB/bin:$PATH" HOME="$TSB" PROOF_RUNNING_PARALLEL=1 OLLAMA_HOST="" \
               OLLAMA_TUNE_CPUS=8 OLLAMA_TUNE_AVAIL_MB=32768 OLLAMA_TUNE_MODEL_MB=512 \
               OLLAMA_TUNE_MIN=7 OLLAMA_TUNE_MAX=7 \
               timeout 180 bash "$SELF_PATH" 2>&1 | grep -oE 'OLLAMA_NUM_PARALLEL = [0-9]+' | head -1)"
    if [[ -n "$_a" && -n "$_b" && "$_a" != "$_b" ]]; then
        p_ok "M9 recommendation-computed" "the printed value moved with its declared bounds: '${_a}' vs '${_b}'"
    else
        p_bad "M9 recommendation-computed" "the recommendation did not move with its inputs: '${_a}' vs '${_b}'"
    fi

    # ---- M10 --print-commands carries the SAME verdict and a real command ----
    # The mode must not launder a finding into a green exit while printing
    # instructions nobody is told to run.
    _m10="$(run_synth "$((PIN_MAX - 1))" --print-commands)"; _m10rc=$?
    if [[ $_m10rc -eq 1 ]] && grep -qF "OLLAMA_NUM_PARALLEL=${PIN_MAX}" <<<"$_m10"; then
        p_ok "M10 print-commands-verdict" "rc=1 (same finding as report mode) and the emitted command carries the computed value"
    else
        p_bad "M10 print-commands-verdict" "expected rc=1 with the computed value in the commands, got rc=${_m10rc}"
    fi

    # ---- RESTORED CONTROL ----------------------------------------------------
    assert "CONTROL restored          " "$PIN_MAX" 0 "already meets the computed recommendation"

    echo "----------------------------------------------------------------------"
    if [[ $P_FAIL -gt 0 ]]; then
        echo "❌ OLLAMA-TUNE §1.1 MUTATION PROOF: FAIL — ${P_FAIL} case(s) did not hold."
        exit 1
    fi
    echo "✅ OLLAMA-TUNE §1.1 MUTATION PROOF: PASS — the real entry point ran against the real"
    echo "   host (reported, never gating), a synthetic PATH-shimmed host that is already tuned"
    echo "   by construction passed as the control, and 10 mutations each moved the verdict the"
    echo "   right way: 2 real findings as rc=1, 5 could-not-determine states as rc=2 rather"
    echo "   than as a pass — an unreadable value, a non-numeric value, no owning unit, a"
    echo "   remote daemon, and an unmeasurable host — plus an over-provisioned daemon that is"
    echo "   correctly NOT a finding, a recommendation shown to follow its inputs, and"
    echo "   --print-commands shown to carry the same verdict as report mode."
    exit 0
fi

# ══════════════════════════════════════════════════════════════════════════════
# 1. WHERE IS OLLAMA?  (local vs remote — a remote daemon has no local surface)
# ══════════════════════════════════════════════════════════════════════════════
# ollama's own documented defaults, kept in ONE place and each overridable, so
# that no literal address or port is frozen anywhere further down.
OLLAMA_DEFAULT_ADDR="${OLLAMA_TUNE_DEFAULT_ADDR:-127.0.0.1}"
OLLAMA_DEFAULT_PORT="${OLLAMA_TUNE_DEFAULT_PORT:-11434}"

RAW_HOST="${HOST_OVERRIDE:-${OLLAMA_HOST:-}}"
HOST_SOURCE="default"
if [[ -n "$RAW_HOST" ]]; then
    HOST_SOURCE="OLLAMA_HOST"
    [[ -n "$HOST_OVERRIDE" ]] && HOST_SOURCE="--host"
else
    RAW_HOST="${OLLAMA_DEFAULT_ADDR}:${OLLAMA_DEFAULT_PORT}"
fi
# ollama accepts bare `host`, `host:port`, `:port` and full URLs.
case "$RAW_HOST" in
    *://*) API_URL="$RAW_HOST" ;;
    :*)    API_URL="http://${OLLAMA_DEFAULT_ADDR}${RAW_HOST}" ;;
    *)     API_URL="http://${RAW_HOST}" ;;
esac
API_URL="${API_URL%/}"
HOSTPORT="${API_URL#*://}"
API_HOST="${HOSTPORT%%/*}"; API_HOST="${API_HOST%%\?*}"
case "$API_HOST" in
    \[*\]*) API_PORT="${API_HOST##*\]:}"; [[ "$API_PORT" == "$API_HOST" ]] && API_PORT="$OLLAMA_DEFAULT_PORT" ;;
    *:*)    API_PORT="${API_HOST##*:}" ;;
    *)      API_PORT="$OLLAMA_DEFAULT_PORT" ;;
esac
API_ADDR="${API_HOST%:$API_PORT}"
[[ "$API_ADDR" == "$API_HOST" ]] || true
API_ADDR="${API_ADDR#[}"; API_ADDR="${API_ADDR%]}"

# Is that address this machine? Compare against loopback, this host's names, and
# every address actually configured on an interface — never a hardcoded list.
host_is_local() {
    local a="${1,,}"
    case "$a" in
        localhost|127.0.0.1|0.0.0.0|::1|::|"") return 0 ;;
        127.*) return 0 ;;
    esac
    local n
    for n in "$(hostname 2>/dev/null)" "$(hostname -s 2>/dev/null)" "$(hostname -f 2>/dev/null)"; do
        [[ -n "$n" && "${n,,}" == "$a" ]] && return 0
    done
    local addrs=""
    if command -v ip >/dev/null 2>&1; then
        addrs="$(ip -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
    elif command -v ifconfig >/dev/null 2>&1; then
        addrs="$(ifconfig 2>/dev/null | awk '/inet6? /{print $2}')"
    fi
    [[ -n "$addrs" ]] && grep -qxF "$a" <<<"$addrs" && return 0
    return 1
}
IS_LOCAL=1; host_is_local "$API_ADDR" || IS_LOCAL=0

# ── API reachability (evidence, not assumption) ───────────────────────────────
API_UP=0; API_VERSION=""
if command -v curl >/dev/null 2>&1; then
    API_VERSION="$(curl -sf --max-time 5 "$API_URL/api/version" 2>/dev/null)"
    if [[ -n "$API_VERSION" ]]; then
        API_UP=1
        v="$(printf '%s' "$API_VERSION" | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
        [[ -n "$v" ]] && API_VERSION="$v"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# 2. HOW IS IT MANAGED?  (systemd system / systemd user / launchd / container /
#    bare process / remote / absent) — each with the evidence that decided it.
# ══════════════════════════════════════════════════════════════════════════════
MANAGER="unknown"; MANAGER_EVIDENCE=""; UNIT=""; SCOPE=""; CONTAINER_RT=""; CONTAINER_ID=""
LAUNCHD_LABEL=""; BARE_PIDS=""

ev() { MANAGER_EVIDENCE="${MANAGER_EVIDENCE}${MANAGER_EVIDENCE:+$'\n'}$1"; }

# Ancestors of this shell, so a process scan can never match itself. This is the
# concrete fix for the self-match that once killed a shell in this project.
SELF_ANCESTORS=""
build_ancestors() {
    local p=$$ guard=0
    while [[ -n "$p" && "$p" != "0" && $guard -lt 64 ]]; do
        SELF_ANCESTORS="${SELF_ANCESTORS} $p "
        local st=""
        if [[ -r "/proc/$p/stat" ]]; then
            st="$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)"
        elif command -v ps >/dev/null 2>&1; then
            st="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
        fi
        [[ -z "$st" ]] && break
        p="$st"; guard=$((guard+1))
    done
}
build_ancestors

pid_cmdline() {
    if [[ -r "/proc/$1/cmdline" ]]; then
        tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null
    else
        ps -o command= -p "$1" 2>/dev/null
    fi
}

# Bracketed pattern + ancestor filter + own-name filter. Three independent
# guards, because any one of them alone has failed before.
scan_pids() {  # $1 = bracketed regex
    local raw pid line out=""
    raw="$(pgrep -f "$1" 2>/dev/null)"
    [[ -z "$raw" ]] && return 1
    while IFS= read -r pid; do
        [[ -z "$pid" ]] && continue
        [[ "$SELF_ANCESTORS" == *" $pid "* ]] && continue
        line="$(pid_cmdline "$pid")"
        [[ "$line" == *"$SELF_NAME"* ]] && continue
        out="${out}${out:+$'\n'}${pid} ${line}"
    done <<< "$raw"
    [[ -z "$out" ]] && return 1
    printf '%s\n' "$out"
}

have() { command -v "$1" >/dev/null 2>&1; }

# -- systemd unit discovery (name is NOT assumed to be "ollama.service") -------
find_unit() {  # $1 = "" | "--user"  → echoes unit name, rc 0 if found
    local scope="$1" out name
    local -a sc=(); [[ -n "$scope" ]] && sc=("$scope")
    have systemctl || return 1
    if [[ -n "$UNIT_OVERRIDE" ]]; then
        out="$(systemctl "${sc[@]}" show "$UNIT_OVERRIDE" -p LoadState --value 2>/dev/null)"
        [[ "$out" == "loaded" ]] && { printf '%s\n' "$UNIT_OVERRIDE"; return 0; }
        return 1
    fi
    # list-units catches transient/runtime units; list-unit-files catches
    # installed-but-stopped ones. Both are searched, exact name preferred.
    local candidates
    candidates="$( { systemctl "${sc[@]}" list-units --type=service --all --no-legend --no-pager 2>/dev/null | awk '{print $1}'
                     systemctl "${sc[@]}" list-unit-files --type=service --no-legend --no-pager 2>/dev/null | awk '{print $1}'
                   } | grep -i 'ollama' | sort -u )"
    [[ -z "$candidates" ]] && return 1
    while IFS= read -r name; do
        [[ "$name" == "ollama.service" ]] && { printf '%s\n' "$name"; return 0; }
    done <<< "$candidates"
    printf '%s\n' "$(printf '%s\n' "$candidates" | head -1)"
    return 0
}

detect_manager() {
    if [[ $IS_LOCAL -eq 0 ]]; then
        MANAGER="remote"
        ev "OLLAMA_HOST resolves to '${API_ADDR}', which is not an address of this machine"
        ev "source of host: ${HOST_SOURCE}"
        [[ $API_UP -eq 1 ]] && ev "remote API answers /api/version (${API_VERSION})" \
                            || ev "remote API did not answer /api/version within 5s"
        return
    fi

    # Container FIRST: a containerised daemon can also look like a bare process
    # from the host's point of view, and its file surface is different.
    local rt
    for rt in docker podman; do
        have "$rt" || continue
        local ps_out
        ps_out="$(timeout 8 "$rt" ps --format '{{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Ports}}' 2>/dev/null)"
        [[ $? -ne 0 || -z "$ps_out" ]] && continue
        local hit
        hit="$(printf '%s\n' "$ps_out" | grep -iE "ollama|:${API_PORT}->" | head -1)"
        if [[ -n "$hit" ]]; then
            MANAGER="container"; CONTAINER_RT="$rt"
            CONTAINER_ID="$(printf '%s' "$hit" | cut -f3)"
            [[ -z "$CONTAINER_ID" ]] && CONTAINER_ID="$(printf '%s' "$hit" | cut -f1)"
            ev "${rt} ps lists a container serving ollama: ${hit}"
            return
        fi
    done

    # systemd, system scope
    local u
    u="$(find_unit "")"
    if [[ -n "$u" ]]; then
        local ls; ls="$(systemctl show "$u" -p LoadState --value 2>/dev/null)"
        if [[ "$ls" == "loaded" ]]; then
            MANAGER="systemd-system"; UNIT="$u"; SCOPE=""
            ev "systemctl show ${u} -p LoadState → loaded"
            local frag act exec
            frag="$(systemctl show "$u" -p FragmentPath --value 2>/dev/null)"
            act="$(systemctl show "$u" -p ActiveState --value 2>/dev/null)"
            exec="$(systemctl show "$u" -p ExecStart --value 2>/dev/null | sed -n 's/.*argv\[\]=\([^;]*\).*/\1/p')"
            ev "FragmentPath=${frag:-?}  ActiveState=${act:-?}"
            [[ -n "$exec" ]] && ev "ExecStart=${exec}"
            return
        fi
    fi

    # systemd, user scope
    u="$(find_unit "--user")"
    if [[ -n "$u" ]]; then
        local ls; ls="$(systemctl --user show "$u" -p LoadState --value 2>/dev/null)"
        if [[ "$ls" == "loaded" ]]; then
            MANAGER="systemd-user"; UNIT="$u"; SCOPE="--user"
            ev "systemctl --user show ${u} -p LoadState → loaded"
            ev "FragmentPath=$(systemctl --user show "$u" -p FragmentPath --value 2>/dev/null)"
            ev "ActiveState=$(systemctl --user show "$u" -p ActiveState --value 2>/dev/null)"
            return
        fi
    fi

    # launchd (macOS)
    if have launchctl; then
        local ll
        ll="$(launchctl list 2>/dev/null | grep -i ollama | head -1)"
        if [[ -n "$ll" ]]; then
            MANAGER="launchd"
            LAUNCHD_LABEL="$(printf '%s' "$ll" | awk '{print $3}')"
            ev "launchctl list → ${ll}"
            return
        fi
        local app
        app="$(scan_pids '[O]llama\.app')"
        if [[ -n "$app" ]]; then
            MANAGER="launchd-app"
            ev "Ollama.app process: $(printf '%s' "$app" | head -1)"
            return
        fi
    fi

    # bare process, no service manager
    local bp
    bp="$(scan_pids '[o]llama([[:space:]]|$).*serve')"
    [[ -z "$bp" ]] && bp="$(scan_pids '[o]llama serve')"
    if [[ -n "$bp" ]]; then
        MANAGER="process"; BARE_PIDS="$bp"
        ev "no service manager owns it; running process: $(printf '%s' "$bp" | head -1)"
        return
    fi

    if [[ $API_UP -eq 1 ]]; then
        MANAGER="unmanaged-api"
        ev "API answers on ${API_URL} but no owning service/process could be identified"
        ev "(this is normal when the daemon runs as another user and /proc is masked)"
    else
        MANAGER="absent"
        ev "no ollama service, container, process, or reachable API found"
    fi
}
detect_manager

# ══════════════════════════════════════════════════════════════════════════════
# 3. WHAT IS THE CONFIG SURFACE?  (discovered, never assumed)
# ══════════════════════════════════════════════════════════════════════════════
# SURFACE_KIND ∈ dropin | envfile | launchd-env | container-recreate | none
SURFACE_KIND="none"; SURFACE_PATH=""; SURFACE_WHY=""; SURFACE_ALT=""
ENVFILES=""; ENVFILE_OPTIONAL=""

parse_environment_files() {
    [[ -z "$UNIT" ]] && return 1
    local -a sc=(); [[ -n "$SCOPE" ]] && sc=("$SCOPE")
    local raw
    raw="$(systemctl "${sc[@]}" show "$UNIT" -p EnvironmentFiles --value 2>/dev/null)"
    [[ -z "$raw" ]] && return 1
    # Format: "/path/to/file (ignore_errors=yes)" — ignore_errors=yes is exactly
    # systemd's rendering of the `-` prefix in `EnvironmentFile=-/path`, i.e.
    # "optional: start anyway if it does not exist".
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local p opt
        p="${line%% (ignore_errors=*}"
        opt="no"
        [[ "$line" == *"ignore_errors=yes"* ]] && opt="yes"
        ENVFILES="${ENVFILES}${ENVFILES:+$'\n'}${p}"
        ENVFILE_OPTIONAL="${ENVFILE_OPTIONAL}${ENVFILE_OPTIONAL:+$'\n'}${opt}"
    done <<< "$raw"
    [[ -n "$ENVFILES" ]]
}

systemd_dropin_dir() {
    if [[ "$SCOPE" == "--user" ]]; then
        printf '%s/systemd/user/%s.d\n' "${XDG_CONFIG_HOME:-$HOME/.config}" "$UNIT"
    else
        # systemd's local administration tree, taken from the RUNNING systemd
        # rather than written down, in case of a non-standard prefix.
        # `systemd-path systemd-search-system-unit` prints ONE colon-separated
        # search path, so it must be split — grepping the whole line returns the
        # entire list and yields a nonsense directory.
        local base="" entry
        local raw; raw="$(systemd-path systemd-search-system-unit 2>/dev/null | head -1)"
        if [[ -n "$raw" ]]; then
            local IFS=':'
            for entry in $raw; do
                # Want the ADMIN tree. Rule, not literal: skip anything volatile
                # (/run) or package-owned (/usr, /lib), skip the .control and
                # .attached variants, take the first plain */system left. On a
                # stock host that is /etc/systemd/system; on a prefixed install
                # it is whatever that systemd actually reports.
                case "$entry" in
                    /run/*|/usr/*|/lib/*) continue ;;
                    */system) base="$entry"; break ;;
                esac
            done
        fi
        [[ -z "$base" ]] && base="/etc/systemd/system"
        printf '%s/%s.d\n' "$base" "$UNIT"
    fi
}

discover_surface() {
    case "$MANAGER" in
      systemd-system|systemd-user)
        parse_environment_files
        local dd; dd="$(systemd_dropin_dir)"
        local frag; local -a sc=(); [[ -n "$SCOPE" ]] && sc=("$SCOPE")
        frag="$(systemctl "${sc[@]}" show "$UNIT" -p FragmentPath --value 2>/dev/null)"
        # PREFERRED: a drop-in. Three concrete reasons, in order of weight:
        #   1. The unit here is usually PACKAGE-OWNED (/usr/lib/systemd/system);
        #      editing it loses the change on the next package upgrade and makes
        #      the package file dirty. A drop-in never touches it.
        #   2. systemd loads drop-ins AFTER the main unit, so a drop-in
        #      `Environment=` deterministically WINS over an `EnvironmentFile=`
        #      declared in the main unit. Editing the env file instead leaves the
        #      precedence dependent on declaration order.
        #   3. It is reversible by deleting one file we own, and it cannot
        #      clobber unrelated settings that already live in the env file
        #      (on this repo's reference host that file carries the Vulkan
        #      remediation flag — appending there risks it, a drop-in cannot).
        SURFACE_KIND="dropin"
        SURFACE_PATH="${dd}/${DROPIN_NAME}"
        SURFACE_WHY="systemd drop-in: unit fragment is ${frag:-unknown}"
        [[ "$frag" == /usr/* || "$frag" == /lib/* ]] && \
            SURFACE_WHY="${SURFACE_WHY} (package-owned — must not be edited in place)"
        if [[ -n "$ENVFILES" ]]; then
            local first_p first_o
            first_p="$(printf '%s\n' "$ENVFILES" | head -1)"
            first_o="$(printf '%s\n' "$ENVFILE_OPTIONAL" | head -1)"
            SURFACE_ALT="${first_p} (EnvironmentFile, optional=${first_o})"
        fi
        ;;
      launchd|launchd-app)
        SURFACE_KIND="launchd-env"
        SURFACE_PATH="launchctl setenv (user session) + app restart"
        SURFACE_WHY="launchd services inherit the session environment; the app reads it at launch"
        local plist="${HOME}/Library/LaunchAgents/${LAUNCHD_LABEL:-ollama}.plist"
        [[ -f "$plist" ]] && SURFACE_ALT="${plist} (EnvironmentVariables dict — survives logout)"
        ;;
      container)
        # Honest: there is NO in-place surface. Container env is fixed at create
        # time; `docker restart` re-runs the SAME config. It must be recreated.
        SURFACE_KIND="container-recreate"
        SURFACE_PATH="${CONTAINER_RT} container '${CONTAINER_ID}'"
        SURFACE_WHY="container environment is immutable after creation — the container must be recreated, not restarted"
        ;;
      remote)
        SURFACE_KIND="none"
        SURFACE_WHY="ollama is on another machine; there is no local file to edit"
        ;;
      process)
        SURFACE_KIND="none"
        SURFACE_WHY="started by hand with no service manager — the variable must be set by whatever launches it"
        ;;
      *)
        SURFACE_KIND="none"
        SURFACE_WHY="no owning mechanism identified, so no config surface could be located"
        ;;
    esac
}
discover_surface

# ── Can we write it, and can we do so WITHOUT prompting? ──────────────────────
# Never run bare `sudo`: it would block on a password prompt in a script that
# may be running unattended. `sudo -n` fails loudly instead, which is the
# honest answer we want.
WRITE_MODE="no"; WRITE_WHY=""
SUDO_NOPASS=0
if have sudo; then
    sudo -n true >/dev/null 2>&1 && SUDO_NOPASS=1
fi
[[ "$(id -u)" == "0" ]] && SUDO_NOPASS=1

probe_writability() {
    case "$SURFACE_KIND" in
      dropin|envfile)
        local target="$SURFACE_PATH" dir
        dir="$(dirname -- "$target")"
        # The drop-in DIRECTORY usually does not exist yet either, so testing
        # -w on it would always say "no". Walk up to the nearest ancestor that
        # does exist and ask whether we could create the rest underneath it.
        local anc="$dir"
        while [[ -n "$anc" && "$anc" != "/" && ! -d "$anc" ]]; do anc="$(dirname -- "$anc")"; done
        if [[ -e "$target" && -w "$target" ]]; then
            WRITE_MODE="direct"; WRITE_WHY="${target} is writable by $(id -un)"
        elif [[ ! -e "$target" && -d "$anc" && -w "$anc" ]]; then
            WRITE_MODE="direct"; WRITE_WHY="${anc} is writable by $(id -un), so the path below it can be created"
        elif [[ "$(id -u)" == "0" ]]; then
            WRITE_MODE="root"; WRITE_WHY="running as root"
        elif [[ $SUDO_NOPASS -eq 1 ]]; then
            WRITE_MODE="sudo"; WRITE_WHY="sudo -n true succeeded (passwordless sudo available)"
        else
            WRITE_MODE="no"
            WRITE_WHY="not writable by $(id -un), and 'sudo -n true' failed → sudo would prompt for a password"
        fi
        ;;
      launchd-env)
        WRITE_MODE="direct"; WRITE_WHY="launchctl setenv runs as the session user"
        ;;
      container-recreate)
        if [[ $SUDO_NOPASS -eq 1 ]] || timeout 5 "$CONTAINER_RT" ps >/dev/null 2>&1; then
            WRITE_MODE="recreate-possible"; WRITE_WHY="${CONTAINER_RT} is usable, but recreation is destructive and is never done automatically"
        else
            WRITE_MODE="no"; WRITE_WHY="${CONTAINER_RT} not usable without elevation"
        fi
        ;;
      *) WRITE_MODE="no"; WRITE_WHY="$SURFACE_WHY" ;;
    esac
}
probe_writability

# ══════════════════════════════════════════════════════════════════════════════
# 4. MEASURE THE HOST, THEN COMPUTE.  Nothing here is a constant.
# ══════════════════════════════════════════════════════════════════════════════
CPUS_ONLINE=0; CPUS_SRC=""; CPU_LIMIT=0; CPU_LIMIT_SRC=""
MEM_TOTAL_MB=0; MEM_AVAIL_MB=0; MEM_SRC=""
MODEL_MB=0; MODEL_NAME=""; MODEL_SRC=""; MODEL_PARAMS=""; MODEL_QUANT=""

read_cpus() {
    if [[ -n "${OLLAMA_TUNE_CPUS:-}" ]]; then
        CPUS_ONLINE="$OLLAMA_TUNE_CPUS"; CPUS_SRC="OLLAMA_TUNE_CPUS override"; return
    fi
    local n=""
    if have nproc; then n="$(nproc 2>/dev/null)"; CPUS_SRC="nproc"; fi
    if [[ -z "$n" ]] && have getconf; then n="$(getconf _NPROCESSORS_ONLN 2>/dev/null)"; CPUS_SRC="getconf _NPROCESSORS_ONLN"; fi
    if [[ -z "$n" ]] && have sysctl; then n="$(sysctl -n hw.ncpu 2>/dev/null)"; CPUS_SRC="sysctl hw.ncpu"; fi
    [[ "$n" =~ ^[0-9]+$ ]] || { n=0; CPUS_SRC="UNKNOWN"; }
    CPUS_ONLINE="$n"
}

# A cgroup-capped box has FEWER usable CPUs than nproc reports — nproc counts
# the machine, not the slice. Three independent limiters are checked and the
# smallest wins: our own cgroup (v2 then v1), and the unit's own CPUQuota /
# AllowedCPUs, which is what actually binds the ollama process.
read_cpu_limit() {
    local best=0 src=""
    # -- cgroup v2, walking up from our own cgroup path to the root
    local mycg="" p
    [[ -r /proc/self/cgroup ]] && mycg="$(sed -n 's/^0:://p' /proc/self/cgroup 2>/dev/null | head -1)"
    local -a probes=()
    if [[ -n "$mycg" ]]; then
        p="$mycg"
        while [[ -n "$p" && "$p" != "/" ]]; do probes+=("/sys/fs/cgroup${p}/cpu.max"); p="${p%/*}"; done
    fi
    probes+=("/sys/fs/cgroup/cpu.max")
    local f
    for f in "${probes[@]}"; do
        [[ -r "$f" ]] || continue
        local q pr; read -r q pr < "$f" 2>/dev/null || continue
        [[ "$q" == "max" || -z "${pr:-}" ]] && continue
        [[ "$q" =~ ^[0-9]+$ && "$pr" =~ ^[0-9]+$ && "$pr" -gt 0 ]] || continue
        local c=$(( (q + pr - 1) / pr ))
        (( c < 1 )) && c=1
        if [[ $best -eq 0 || $c -lt $best ]]; then best=$c; src="cgroup v2 ${f} (${q}/${pr})"; fi
    done
    # -- cgroup v1
    local q1=/sys/fs/cgroup/cpu/cpu.cfs_quota_us p1=/sys/fs/cgroup/cpu/cpu.cfs_period_us
    if [[ -r "$q1" && -r "$p1" ]]; then
        local q p2; q="$(cat "$q1" 2>/dev/null)"; p2="$(cat "$p1" 2>/dev/null)"
        if [[ "$q" =~ ^[0-9]+$ && "$p2" =~ ^[0-9]+$ && "$p2" -gt 0 ]]; then
            local c=$(( (q + p2 - 1) / p2 )); (( c < 1 )) && c=1
            if [[ $best -eq 0 || $c -lt $best ]]; then best=$c; src="cgroup v1 (${q}/${p2})"; fi
        fi
    fi
    # -- the unit's own limits (these bind ollama, not us)
    if [[ -n "$UNIT" ]]; then
        local -a sc=(); [[ -n "$SCOPE" ]] && sc=("$SCOPE")
        local quota; quota="$(systemctl "${sc[@]}" show "$UNIT" -p CPUQuotaPerSecUSec --value 2>/dev/null)"
        if [[ -n "$quota" && "$quota" != "infinity" ]]; then
            local c=""
            case "$quota" in
                *ms) c=$(( ${quota%ms} / 1000 )); [[ $c -lt 1 ]] && c=1 ;;
                *s)  c="${quota%s}"; c="${c%%.*}" ;;
            esac
            if [[ "$c" =~ ^[0-9]+$ && $c -ge 1 ]]; then
                if [[ $best -eq 0 || $c -lt $best ]]; then best=$c; src="${UNIT} CPUQuotaPerSecUSec=${quota}"; fi
            fi
        fi
        local allowed; allowed="$(systemctl "${sc[@]}" show "$UNIT" -p AllowedCPUs --value 2>/dev/null)"
        if [[ -n "$allowed" ]]; then
            local c=0 part lo hi
            for part in ${allowed//,/ }; do
                if [[ "$part" == *-* ]]; then lo="${part%-*}"; hi="${part#*-}"; c=$((c + hi - lo + 1))
                else c=$((c+1)); fi
            done
            if [[ $c -ge 1 ]]; then
                if [[ $best -eq 0 || $c -lt $best ]]; then best=$c; src="${UNIT} AllowedCPUs=${allowed}"; fi
            fi
        fi
    fi
    CPU_LIMIT="$best"; CPU_LIMIT_SRC="$src"
}

read_mem() {
    if [[ -n "${OLLAMA_TUNE_AVAIL_MB:-}" ]]; then
        MEM_AVAIL_MB="$OLLAMA_TUNE_AVAIL_MB"
        MEM_TOTAL_MB="${OLLAMA_TUNE_TOTAL_MB:-$OLLAMA_TUNE_AVAIL_MB}"
        MEM_SRC="OLLAMA_TUNE_AVAIL_MB override"; return
    fi
    # Linux-only location, named once and overridable, then referenced through
    # the variable — and only ever after the -r probe below succeeds, so a
    # non-Linux host falls through to the sysctl/vm_stat branch instead of
    # silently reporting 0 MiB.
    local meminfo="${OLLAMA_TUNE_MEMINFO:-/proc/meminfo}"
    if [[ -r "$meminfo" ]]; then
        local t a
        t="$(awk '/^MemTotal:/{print int($2/1024)}' "$meminfo" 2>/dev/null)"
        a="$(awk '/^MemAvailable:/{print int($2/1024)}' "$meminfo" 2>/dev/null)"
        [[ -z "$a" ]] && a="$(awk '/^MemFree:/{print int($2/1024)}' "$meminfo" 2>/dev/null)"
        MEM_TOTAL_MB="${t:-0}"; MEM_AVAIL_MB="${a:-0}"; MEM_SRC="$meminfo"
        # A memory-capped cgroup makes /proc/meminfo a lie for this process.
        local mf
        for mf in /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory/memory.limit_in_bytes; do
            [[ -r "$mf" ]] || continue
            local lim; lim="$(cat "$mf" 2>/dev/null)"
            [[ "$lim" =~ ^[0-9]+$ ]] || continue
            local lim_mb=$(( lim / 1048576 ))
            if [[ $lim_mb -gt 0 && $lim_mb -lt $MEM_TOTAL_MB ]]; then
                MEM_TOTAL_MB=$lim_mb
                [[ $MEM_AVAIL_MB -gt $lim_mb ]] && MEM_AVAIL_MB=$lim_mb
                MEM_SRC="${MEM_SRC} + cgroup limit ${mf}"
            fi
        done
        return
    fi
    if have sysctl; then
        local b; b="$(sysctl -n hw.memsize 2>/dev/null)"
        [[ "$b" =~ ^[0-9]+$ ]] && MEM_TOTAL_MB=$(( b / 1048576 ))
        MEM_SRC="sysctl hw.memsize"
        if have vm_stat; then
            local pgsz free inact spec
            pgsz="$(vm_stat 2>/dev/null | sed -n 's/.*page size of \([0-9]*\) bytes.*/\1/p')"
            [[ -z "$pgsz" ]] && pgsz=4096
            free="$(vm_stat 2>/dev/null  | awk '/Pages free/{gsub(/\./,"",$3); print $3}')"
            inact="$(vm_stat 2>/dev/null | awk '/Pages inactive/{gsub(/\./,"",$3); print $3}')"
            spec="$(vm_stat 2>/dev/null  | awk '/speculative/{gsub(/\./,"",$3); print $3}')"
            local pages=$(( ${free:-0} + ${inact:-0} + ${spec:-0} ))
            MEM_AVAIL_MB=$(( pages * pgsz / 1048576 ))
            MEM_SRC="${MEM_SRC} + vm_stat"
        fi
        [[ $MEM_AVAIL_MB -eq 0 ]] && MEM_AVAIL_MB=$MEM_TOTAL_MB
        return
    fi
    MEM_SRC="UNKNOWN"
}

# The resident model's real size, from the daemon itself. A 160M-param F16
# embedding model and a 70B chat model are not the same tuning problem, and the
# only way to know which one this host is running is to ask.
read_model() {
    if [[ -n "${OLLAMA_TUNE_MODEL_MB:-}" ]]; then
        MODEL_MB="$OLLAMA_TUNE_MODEL_MB"; MODEL_SRC="OLLAMA_TUNE_MODEL_MB override"
        MODEL_NAME="${MODEL_NAME:-(override)}"; return
    fi
    [[ $API_UP -eq 1 ]] || { MODEL_SRC="UNKNOWN (API unreachable)"; return; }
    local ps_json
    ps_json="$(curl -sf --max-time 8 "$API_URL/api/ps" 2>/dev/null)"
    if [[ -n "$ps_json" && "$ps_json" == *'"size"'* ]]; then
        local parsed
        parsed="$(printf '%s' "$ps_json" | python3 -c '
import sys, json
try:
    ms = json.load(sys.stdin).get("models") or []
except Exception:
    sys.exit(0)
if not ms: sys.exit(0)
m = max(ms, key=lambda x: x.get("size", 0))
d = m.get("details") or {}
print("%d\t%s\t%s\t%s" % (int(m.get("size",0))//1048576, m.get("name",""),
                          d.get("parameter_size",""), d.get("quantization_level","")))
' 2>/dev/null)"
        if [[ -n "$parsed" ]]; then
            MODEL_MB="$(printf '%s' "$parsed" | cut -f1)"
            MODEL_NAME="$(printf '%s' "$parsed" | cut -f2)"
            MODEL_PARAMS="$(printf '%s' "$parsed" | cut -f3)"
            MODEL_QUANT="$(printf '%s' "$parsed" | cut -f4)"
            MODEL_SRC="/api/ps (resident model)"
            return
        fi
    fi
    # Nothing resident: fall back to the model this project embeds with, looked
    # up in /api/tags. Still discovered, not assumed.
    local want="${LUMEN_EMBED_MODEL:-}"
    local tags; tags="$(curl -sf --max-time 8 "$API_URL/api/tags" 2>/dev/null)"
    if [[ -n "$tags" ]]; then
        local parsed
        parsed="$(printf '%s' "$tags" | WANT="$want" python3 -c '
import sys, json, os
want = os.environ.get("WANT","")
try:
    ms = json.load(sys.stdin).get("models") or []
except Exception:
    sys.exit(0)
if not ms: sys.exit(0)
pick = None
if want:
    for m in ms:
        if m.get("name","").split(":")[0] == want.split(":")[0]: pick = m; break
if pick is None:
    emb = [m for m in ms if "embed" in m.get("name","").lower()]
    pick = min(emb or ms, key=lambda x: x.get("size", 0))
print("%d\t%s" % (int(pick.get("size",0))//1048576, pick.get("name","")))
' 2>/dev/null)"
        if [[ -n "$parsed" ]]; then
            MODEL_MB="$(printf '%s' "$parsed" | cut -f1)"
            MODEL_NAME="$(printf '%s' "$parsed" | cut -f2)"
            MODEL_SRC="/api/tags (no model resident; smallest/embedding model on disk)"
            return
        fi
    fi
    MODEL_SRC="UNKNOWN (daemon reported no models)"
}

read_cpus; read_cpu_limit; read_mem; read_model

# ── THE FORMULA ───────────────────────────────────────────────────────────────
#
#   effective_cpus = min(cpus_online, cgroup/unit cpu limit)   # slice, not box
#   slot_mb        = max(model_mb, 256)                        # per-slot cost
#   mem_cap        = (avail_mb * MEM_PCT/100) / slot_mb
#   cpu_div        = 2  if model_mb <= SMALL_MODEL_MB else 4
#   cpu_cap        = max(1, effective_cpus / cpu_div)
#   value          = clamp(min(cpu_cap, mem_cap), PARALLEL_MIN, PARALLEL_MAX)
#
# WHY THOSE TERMS
#   * effective_cpus, not nproc. `nproc` counts the machine; a cgroup-capped
#     container gets a fraction of it and would be badly oversubscribed.
#   * cpu_div = 2 for a small model. Ollama's runner already spawns roughly one
#     thread per core for a single request, so N concurrent requests on N cores
#     fight each other and every request gets slower. Half the cores leaves the
#     scheduler room while still removing the head-of-line block, which is the
#     actual failure being fixed — the waiting client's latency, not throughput.
#   * cpu_div = 4 for a model above SMALL_MODEL_MB. A large model's runner is
#     far more thread- and bandwidth-hungry per request, so fewer slots.
#   * slot_mb uses the whole model size as the per-slot working set. For an
#     embedding model that is a deliberate OVER-estimate (a KV slot is much
#     smaller than the weights, which are shared across slots), so the memory
#     term stays conservative and effectively never binds on a small model —
#     exactly right, since CPU is what binds there. The 256 MiB floor stops a
#     tiny or unknown model from producing an absurd cap.
#   * MEM_PCT of AVAILABLE (not total) memory. Total is a fiction on a busy
#     host; available is what can actually be claimed without swapping.
#
# CLAMP BOUNDS
#   * Lower bound 1: 1 is ollama's serialised behaviour and the honest answer on
#     a 1-2 core box — there, concurrency cannot help and the script says so
#     rather than inventing a benefit. (0 is NOT used: to ollama 0 means "auto",
#     which is what produced the stall being fixed.)
#   * Upper bound 8: past ~8 slots the shared weights, memory bandwidth and
#     thread thrash dominate; more slots make every request slower while
#     multiplying KV memory. It is a guard against a 128-core host generating a
#     pathological config, not a measured optimum.
compute() {
    EFFECTIVE_CPUS="$CPUS_ONLINE"
    if [[ $CPU_LIMIT -gt 0 && $CPU_LIMIT -lt $EFFECTIVE_CPUS ]]; then EFFECTIVE_CPUS=$CPU_LIMIT; fi
    if [[ $EFFECTIVE_CPUS -lt 1 ]]; then EFFECTIVE_CPUS=0; fi

    SLOT_MB=$MODEL_MB; [[ $SLOT_MB -lt 256 ]] && SLOT_MB=256

    if [[ $MEM_AVAIL_MB -gt 0 ]]; then
        MEM_CAP=$(( MEM_AVAIL_MB * MEM_PCT / 100 / SLOT_MB ))
    else
        MEM_CAP=-1   # unknown
    fi
    [[ $MEM_CAP -eq 0 ]] && MEM_CAP=1

    if [[ $MODEL_MB -gt 0 && $MODEL_MB -gt $SMALL_MODEL_MB ]]; then CPU_DIV=4; else CPU_DIV=2; fi

    if [[ $EFFECTIVE_CPUS -gt 0 ]]; then
        CPU_CAP=$(( EFFECTIVE_CPUS / CPU_DIV )); [[ $CPU_CAP -lt 1 ]] && CPU_CAP=1
    else
        CPU_CAP=-1
    fi

    if [[ $CPU_CAP -lt 0 && $MEM_CAP -lt 0 ]]; then
        RECOMMENDED=-1; return 2      # could not determine
    fi
    local raw
    if   [[ $CPU_CAP -lt 0 ]]; then raw=$MEM_CAP
    elif [[ $MEM_CAP -lt 0 ]]; then raw=$CPU_CAP
    elif [[ $CPU_CAP -lt $MEM_CAP ]]; then raw=$CPU_CAP; else raw=$MEM_CAP; fi

    if   [[ $CPU_CAP -lt 0 ]]; then BINDING="mem_cap (cpu unknown)"
    elif [[ $MEM_CAP -lt 0 ]]; then BINDING="cpu_cap (memory unknown)"
    elif [[ $MEM_CAP -lt $CPU_CAP ]]; then BINDING="mem_cap"
    else BINDING="cpu_cap"; fi
    RAW_VALUE=$raw
    [[ $raw -lt $PARALLEL_MIN ]] && raw=$PARALLEL_MIN
    [[ $raw -gt $PARALLEL_MAX ]] && raw=$PARALLEL_MAX
    RECOMMENDED=$raw
    return 0
}
compute; COMPUTE_RC=$?

# ── Should KEEP_ALIVE / MAX_QUEUE be touched? ─────────────────────────────────
# KEEP_ALIVE: the default 5m unloads the model between bursts, so the first
# embed after a gap pays a full cold load ON TOP of any queue wait — part of the
# same stall. Raising it is only free when the model is small relative to
# available memory, so that is tested rather than assumed.
KEEPALIVE_ADVICE="leave"; KEEPALIVE_WHY=""
if [[ $MODEL_MB -gt 0 && $MEM_AVAIL_MB -gt 0 ]]; then
    # Integer percent rounds a 329 MiB model in 55 GiB down to a useless "0%",
    # so the share is carried in tenths and formatted back out.
    MODEL_SHARE_X10=$(( MODEL_MB * 1000 / MEM_AVAIL_MB ))
    MODEL_SHARE="$(( MODEL_SHARE_X10 / 10 )).$(( MODEL_SHARE_X10 % 10 ))%"
    if [[ $MODEL_SHARE_X10 -lt 50 ]]; then
        KEEPALIVE_ADVICE="set"
        KEEPALIVE_WHY="model is ${MODEL_MB} MiB = ${MODEL_SHARE} of ${MEM_AVAIL_MB} MiB available; keeping it resident costs little and removes the cold-load stall that follows every gap longer than the current keep-alive"
    else
        KEEPALIVE_WHY="model is ${MODEL_SHARE} of available memory — pinning it would hold too much; leave the default"
    fi
else
    KEEPALIVE_WHY="model or memory size unknown — not changed"
fi
[[ $WITH_KEEPALIVE -eq 0 ]] && { KEEPALIVE_ADVICE="leave"; KEEPALIVE_WHY="--no-keep-alive given"; }

# MAX_QUEUE: deliberately NOT changed, and here is the reasoning rather than
# silence. Raising it makes a deeper queue, and a request that waits in a deeper
# queue still times out client-side — it hides the stall instead of fixing it.
# Lowering it converts overflow into an immediate 503, which is arguably better
# feedback but breaks any client that does not retry (this repo's indexer among
# them). The queue is not the defect; serialisation is. Left alone.
MAXQUEUE_WHY="queue depth is not the defect — serialisation is. A deeper queue still times out client-side; a shallower one turns overflow into 503s that non-retrying clients cannot handle."

# ══════════════════════════════════════════════════════════════════════════════
# 5. WHAT IS THE DAEMON ACTUALLY RUNNING RIGHT NOW?
# ══════════════════════════════════════════════════════════════════════════════
# ollama logs its fully-resolved config once at startup as
#   msg="server config" env="map[... OLLAMA_NUM_PARALLEL:1 ...]"
# That line is the RUNNING process's value — not the file's. It is read from the
# CURRENT service start onward, because an older line describes a previous
# process and would make a stale reading look like a fresh confirmation.
RUNNING_PARALLEL=""; RUNNING_KEEPALIVE=""; RUNNING_SRC=""; RUNNING_RC=2

service_started_at() {
    [[ -n "$UNIT" ]] || return 1
    local -a sc=(); [[ -n "$SCOPE" ]] && sc=("$SCOPE")
    systemctl "${sc[@]}" show "$UNIT" -p ActiveEnterTimestamp --value 2>/dev/null
}

read_running_config() {
    RUNNING_RC=2
    if [[ -n "$UNIT" ]] && have journalctl; then
        local -a ja=(-u "$UNIT" --no-pager)
        [[ "$SCOPE" == "--user" ]] && ja+=(--user)
        local since; since="$(service_started_at)"
        [[ -n "$since" ]] && ja+=(--since "$since")
        local line
        line="$(journalctl "${ja[@]}" 2>/dev/null | grep -F 'msg="server config"' | tail -1)"
        if [[ -n "$line" ]]; then
            local p k
            p="$(printf '%s' "$line" | grep -oE 'OLLAMA_NUM_PARALLEL:[^] ]*' | tail -1)"
            k="$(printf '%s' "$line" | grep -oE 'OLLAMA_KEEP_ALIVE:[^] ]*' | tail -1)"
            RUNNING_PARALLEL="${p#OLLAMA_NUM_PARALLEL:}"
            RUNNING_KEEPALIVE="${k#OLLAMA_KEEP_ALIVE:}"
            RUNNING_SRC="journal 'server config' line since service start${since:+ ($since)}"
            [[ -n "$RUNNING_PARALLEL" ]] && RUNNING_RC=0
            return
        fi
    fi
    # Fallback: the process environment. Readable only when we own the process.
    local pid=""
    if [[ -n "$UNIT" ]]; then
        local -a sc=(); [[ -n "$SCOPE" ]] && sc=("$SCOPE")
        pid="$(systemctl "${sc[@]}" show "$UNIT" -p MainPID --value 2>/dev/null)"
    fi
    if [[ -z "$pid" || "$pid" == "0" ]] && [[ -n "$BARE_PIDS" ]]; then
        pid="$(printf '%s' "$BARE_PIDS" | head -1 | awk '{print $1}')"
    fi
    if [[ -n "$pid" && "$pid" != "0" && -r "/proc/$pid/environ" ]]; then
        local envs; envs="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null)"
        if [[ -n "$envs" ]]; then
            local v; v="$(printf '%s\n' "$envs" | sed -n 's/^OLLAMA_NUM_PARALLEL=//p' | tail -1)"
            RUNNING_PARALLEL="${v:-(unset)}"
            v="$(printf '%s\n' "$envs" | sed -n 's/^OLLAMA_KEEP_ALIVE=//p' | tail -1)"
            RUNNING_KEEPALIVE="${v:-(unset)}"
            RUNNING_SRC="/proc/${pid}/environ"
            RUNNING_RC=0; return
        fi
    fi
    RUNNING_SRC="COULD NOT READ (no journal 'server config' line since start; /proc/<pid>/environ not readable — the daemon runs as another user)"
}
read_running_config

# ══════════════════════════════════════════════════════════════════════════════
# 6. THE DESTRUCTIVE EDGE: is an embed/index job in flight right now?
# ══════════════════════════════════════════════════════════════════════════════
# Restarting ollama kills every in-flight request. This project's indexer runs
# for a long time and a restart mid-run destroys the rebuild. Three independent
# signals; ANY of them means "busy".
INFLIGHT=0; INFLIGHT_EVIDENCE=""
iev() { INFLIGHT_EVIDENCE="${INFLIGHT_EVIDENCE}${INFLIGHT_EVIDENCE:+$'\n'}$1"; }

check_inflight() {
    # (a) known indexer processes — bracketed patterns, self/ancestors filtered
    local hits
    hits="$(scan_pids '[l]umen(-linux[^ ]*)?[[:space:]]+index')"
    [[ -n "$hits" ]] && { INFLIGHT=1; iev "index process: $(printf '%s' "$hits" | head -2 | tr '\n' '|')"; }
    hits="$(scan_pids '[l]umen-reindex\.sh')"
    [[ -n "$hits" ]] && { INFLIGHT=1
        iev "reindex wrapper ($([[ -f "$REINDEX_SCRIPT" ]] && echo "$REINDEX_SCRIPT" || echo "lumen-reindex.sh")): $(printf '%s' "$hits" | head -2 | tr '\n' '|')"; }

    # (b) established client connections to the ollama port, excluding our own
    if have ss; then
        local conns n
        conns="$(ss -tnH state established 2>/dev/null | grep -E "[:.]${API_PORT}\b")"
        n=0; [[ -n "$conns" ]] && n="$(printf '%s\n' "$conns" | wc -l | tr -d ' ')"
        # Our own curl probes are short-lived and already finished; anything
        # still established belongs to someone else.
        if [[ "$n" -gt 0 ]]; then
            INFLIGHT=1
            iev "${n} established TCP connection line(s) to port ${API_PORT}: $(printf '%s' "$conns" | head -1 | tr -s ' ')"
        fi
    elif have lsof; then
        local n
        n="$(lsof -nP -iTCP:"${API_PORT}" -sTCP:ESTABLISHED 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
        [[ "${n:-0}" -gt 0 ]] && { INFLIGHT=1; iev "${n} established connection(s) to port ${API_PORT} (lsof)"; }
    else
        iev "neither ss nor lsof present — connection check COULD NOT be performed"
    fi

    # (c) very recent API activity in the journal (a request logs on completion)
    if [[ -n "$UNIT" ]] && have journalctl; then
        local -a ja=(-u "$UNIT" --no-pager --since "-60 seconds")
        [[ "$SCOPE" == "--user" ]] && ja+=(--user)
        local recent
        recent="$(journalctl "${ja[@]}" 2>/dev/null | grep -cE '"(POST|GET) "?/api/(embed|embeddings|generate|chat)')"
        if [[ "${recent:-0}" -gt 0 ]]; then
            INFLIGHT=1; iev "${recent} /api/ request(s) served in the last 60s (journal)"
        fi
    fi
    [[ $INFLIGHT -eq 0 ]] && iev "no index process, no established connection, no recent /api/ traffic"
}
check_inflight

# ══════════════════════════════════════════════════════════════════════════════
# 7. LATENCY / CONCURRENCY MEASUREMENT
# ══════════════════════════════════════════════════════════════════════════════
now_ms() {
    local n; n="$(date +%s%N 2>/dev/null)"
    if [[ "$n" =~ ^[0-9]+$ && ${#n} -gt 10 ]]; then echo $(( n / 1000000 ));
    else echo $(( $(date +%s) * 1000 )); fi
}

# A 500 still exits curl 0, so the HTTP status is checked too — otherwise a
# failing daemon would be timed as if it were serving.
embed_once() {  # $1 = output file; rc 0 only on HTTP 200
    local model="${MODEL_NAME:-}" code
    [[ -z "$model" || "$model" == "(override)" ]] && return 3
    code="$(curl -s --max-time "$PROBE_TIMEOUT" -o "$1" -w '%{http_code}' \
            "$API_URL/api/embed" -H 'Content-Type: application/json' \
            --data "{\"model\":\"${model}\",\"input\":\"ollama-tune latency probe\"}" 2>/dev/null)"
    local rc=$?
    [[ $rc -ne 0 ]] && return $rc
    [[ "$code" == "200" ]] || return 4
    return 0
}

# Serial single request, then N concurrent. If the daemon serialises, N
# concurrent requests take ~N x the single time; if it parallelises they take
# markedly less. This is a BEHAVIOURAL check: it needs no file, no journal and
# no permission, so it is the one verification that works everywhere.
measure() {
    LAT_SINGLE_MS=-1; LAT_CONC_MS=-1; CONC_VERDICT="COULD NOT DETERMINE"
    if [[ $API_UP -ne 1 ]]; then CONC_VERDICT="COULD NOT DETERMINE (API unreachable)"; return 2; fi
    if [[ -z "$MODEL_NAME" || "$MODEL_NAME" == "(override)" ]]; then
        CONC_VERDICT="COULD NOT DETERMINE (no model name discoverable to embed with)"; return 2
    fi
    local tmp; tmp="$(mktemp -d 2>/dev/null)" || { CONC_VERDICT="COULD NOT DETERMINE (no temp dir)"; return 2; }
    local t0 t1
    t0="$(now_ms)"; embed_once "$tmp/single"; local rc=$?; t1="$(now_ms)"
    if [[ $rc -ne 0 ]]; then
        rm -rf -- "$tmp"; CONC_VERDICT="COULD NOT DETERMINE (probe request failed, rc=$rc)"; return 2
    fi
    LAT_SINGLE_MS=$(( t1 - t0 ))
    local i
    t0="$(now_ms)"
    for ((i=0; i<PROBE_CONCURRENCY; i++)); do embed_once "$tmp/c$i" & done
    wait
    t1="$(now_ms)"
    LAT_CONC_MS=$(( t1 - t0 ))
    rm -rf -- "$tmp"
    if [[ $LAT_SINGLE_MS -le 0 ]]; then CONC_VERDICT="COULD NOT DETERMINE (single latency unmeasurable)"; return 2; fi
    # ratio x100 to stay in integer arithmetic
    local ratio=$(( LAT_CONC_MS * 100 / LAT_SINGLE_MS ))
    local serial_threshold=$(( PROBE_CONCURRENCY * 75 ))   # 0.75 x N
    if [[ $ratio -ge $serial_threshold ]]; then
        CONC_VERDICT="SERIALISED (${PROBE_CONCURRENCY} concurrent took ${ratio}% of one request — at or above the ${serial_threshold}% serial threshold)"
        return 1
    fi
    CONC_VERDICT="CONCURRENT (${PROBE_CONCURRENCY} concurrent took only ${ratio}% of one request — below the ${serial_threshold}% serial threshold)"
    return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# 8. THE CHANGE ITSELF
# ══════════════════════════════════════════════════════════════════════════════
desired_dropin_content() {
    printf '# Written by %s — regenerate, do not hand-edit.\n' "$SELF_NAME"
    printf '# Values derived from this host: %s effective CPU(s), %s MiB available RAM, %s MiB model.\n' \
        "$EFFECTIVE_CPUS" "$MEM_AVAIL_MB" "$MODEL_MB"
    printf '[Service]\n'
    printf 'Environment="OLLAMA_NUM_PARALLEL=%s"\n' "$RECOMMENDED"
    [[ "$KEEPALIVE_ADVICE" == "set" ]] && printf 'Environment="OLLAMA_KEEP_ALIVE=%s"\n' "$KEEPALIVE_TARGET"
    return 0
}

# For an EnvironmentFile the change must be idempotent by CONSTRUCTION: existing
# assignments of the same keys are dropped and re-added exactly once. Appending
# (the rejected proposal's `tee -a`) duplicates the line on every run.
desired_envfile_content() {  # $1 = existing file path (may not exist)
    if [[ -f "$1" ]]; then
        grep -vE '^[[:space:]]*(OLLAMA_NUM_PARALLEL|OLLAMA_KEEP_ALIVE)=' "$1" 2>/dev/null
    fi
    printf 'OLLAMA_NUM_PARALLEL=%s\n' "$RECOMMENDED"
    [[ "$KEEPALIVE_ADVICE" == "set" ]] && printf 'OLLAMA_KEEP_ALIVE=%s\n' "$KEEPALIVE_TARGET"
    return 0
}

current_surface_content() {
    [[ -f "$SURFACE_PATH" ]] && cat "$SURFACE_PATH" 2>/dev/null
    return 0
}

# Compare SETTINGS, not bytes. The generated file carries a provenance comment
# containing live measurements (available RAM moves between two runs seconds
# apart), so a byte comparison would report "changed" every single time and
# re-restart the daemon on every invocation — the opposite of idempotent.
# Comments and blank lines are therefore excluded from the comparison.
settings_only() { grep -vE '^[[:space:]]*(#|$)'; }

surface_already_correct() {
    [[ -f "$SURFACE_PATH" ]] || return 1
    local want have_
    case "$SURFACE_KIND" in
        dropin)  want="$(desired_dropin_content | settings_only)" ;;
        envfile) want="$(desired_envfile_content "$SURFACE_PATH" | settings_only)" ;;
        *)       return 1 ;;
    esac
    have_="$(current_surface_content | settings_only)"
    [[ "$want" == "$have_" ]]
}

# `sudo -n` only. A plain `sudo` here would hang on a password prompt.
run_priv() {
    if [[ "$(id -u)" == "0" ]]; then "$@"; return $?; fi
    if [[ "$WRITE_MODE" == "direct" ]]; then "$@"; return $?; fi
    sudo -n "$@"; return $?
}

operator_commands() {
    case "$SURFACE_KIND" in
      dropin)
        # A user-scope unit lives under the caller's own $HOME — prefixing those
        # commands with sudo would be wrong, not merely noisy.
        local dir sudo_ ucap
        dir="$(dirname -- "$SURFACE_PATH")"
        if [[ "$SCOPE" == "--user" ]]; then sudo_=""; ucap="--user "; else sudo_="sudo "; ucap=""; fi
        echo "${sudo_}install -d -m 0755 ${dir}"
        echo "${sudo_}tee ${SURFACE_PATH} >/dev/null <<'EOF'"
        desired_dropin_content
        echo "EOF"
        echo "${sudo_}systemctl ${ucap}daemon-reload"
        echo "${sudo_}systemctl ${ucap}restart ${UNIT}"
        echo "# verify — this reads the RUNNING process, not the file; must print ${RECOMMENDED}:"
        echo "journalctl ${ucap}-u ${UNIT} --no-pager --since \"\$(systemctl ${ucap}show ${UNIT} -p ActiveEnterTimestamp --value)\" | grep -o 'OLLAMA_NUM_PARALLEL:[^ ]*' | tail -1"
        ;;
      envfile)
        echo "sudo cp -a ${SURFACE_PATH} ${SURFACE_PATH}.${BAK_SUFFIX}.\$(date -u +%Y%m%dT%H%M%SZ)"
        echo "sudo tee ${SURFACE_PATH} >/dev/null <<'EOF'"
        desired_envfile_content "$SURFACE_PATH"
        echo "EOF"
        echo "sudo systemctl restart ${UNIT}"
        ;;
      launchd-env)
        echo "launchctl setenv OLLAMA_NUM_PARALLEL ${RECOMMENDED}"
        [[ "$KEEPALIVE_ADVICE" == "set" ]] && echo "launchctl setenv OLLAMA_KEEP_ALIVE ${KEEPALIVE_TARGET}"
        if [[ -n "$LAUNCHD_LABEL" ]]; then
            echo "launchctl kickstart -k gui/\$(id -u)/${LAUNCHD_LABEL}"
        else
            echo "# then quit and reopen Ollama.app so it picks up the session environment"
        fi
        ;;
      container-recreate)
        echo "# The container's environment cannot be changed in place — it must be recreated."
        echo "${CONTAINER_RT} inspect ${CONTAINER_ID} --format '{{json .Config}}'   # capture the current config first"
        echo "${CONTAINER_RT} stop ${CONTAINER_ID} && ${CONTAINER_RT} rm ${CONTAINER_ID}"
        echo "${CONTAINER_RT} run -d --name ${CONTAINER_ID} \\"
        echo "    -e OLLAMA_NUM_PARALLEL=${RECOMMENDED} \\"
        [[ "$KEEPALIVE_ADVICE" == "set" ]] && echo "    -e OLLAMA_KEEP_ALIVE=${KEEPALIVE_TARGET} \\"
        echo "    -p ${API_PORT}:11434 -v ollama:/root/.ollama <image-and-flags-from-the-inspect-above>"
        echo "# If it is managed by compose, add the variables under 'environment:' and re-run 'up -d' instead."
        ;;
      *)
        case "$MANAGER" in
          remote)
            echo "# ollama is REMOTE (${API_URL}). Nothing on this machine configures it."
            echo "# Run this script on the host that actually runs the daemon:"
            echo "#   scripts/${SELF_NAME} --apply"
            ;;
          process)
            echo "# Started by hand, no service manager. Set the variable in whatever launches it:"
            echo "OLLAMA_NUM_PARALLEL=${RECOMMENDED} ollama serve"
            echo "# (the running process must be stopped and restarted by its owner)"
            ;;
          *)
            echo "# No config surface was discovered, so no commands can be built for this host."
            ;;
        esac
        ;;
    esac
    return 0
}

backup_surface() {
    [[ -f "$SURFACE_PATH" ]] || { echo "(nothing to back up — ${SURFACE_PATH} does not exist)"; return 0; }
    local stamp bak
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    bak="${SURFACE_PATH}.${BAK_SUFFIX}.${stamp}"
    # Hardlink first (constitution §9: hardlinked backup before a destructive
    # op). The new content is written to a temp file and MOVED into place, which
    # allocates a new inode, so the hardlinked backup keeps the old bytes.
    if run_priv ln "$SURFACE_PATH" "$bak" 2>/dev/null; then
        echo "$bak (hardlink)"; return 0
    fi
    if run_priv cp -p "$SURFACE_PATH" "$bak" 2>/dev/null; then
        echo "$bak (copy)"; return 0
    fi
    return 1
}

write_surface() {
    local content="$1" tmp
    tmp="$(mktemp 2>/dev/null)" || return 1
    printf '%s\n' "$content" > "$tmp" || { rm -f -- "$tmp"; return 1; }
    local dir; dir="$(dirname -- "$SURFACE_PATH")"
    if [[ ! -d "$dir" ]]; then
        run_priv install -d -m 0755 "$dir" || { rm -f -- "$tmp"; return 1; }
    fi
    run_priv install -m 0644 "$tmp" "$SURFACE_PATH" || { rm -f -- "$tmp"; return 1; }
    rm -f -- "$tmp"
    return 0
}

# Writing the file and restarting the daemon are two different privileges: a
# user can own the drop-in directory and still not be allowed to talk to PID 1.
# Try unprivileged first, then `sudo -n` — never a prompting `sudo`.
systemctl_priv() {
    systemctl "$@" >/dev/null 2>&1 && return 0
    [[ "$(id -u)" == "0" ]] && return 1
    have sudo || return 1
    sudo -n systemctl "$@" >/dev/null 2>&1
}

restart_service() {
    case "$MANAGER" in
      systemd-system)
        systemctl_priv daemon-reload || return 1
        systemctl_priv restart "$UNIT" || return 1
        ;;
      systemd-user)
        systemctl --user daemon-reload || return 1
        systemctl --user restart "$UNIT" || return 1
        ;;
      launchd)
        [[ -n "$LAUNCHD_LABEL" ]] || return 1
        launchctl kickstart -k "gui/$(id -u)/${LAUNCHD_LABEL}" || return 1
        ;;
      *) return 1 ;;
    esac
    return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# 9. REPORT
# ══════════════════════════════════════════════════════════════════════════════
print_report() {
    hdr "how ollama is managed on this host"
    case "$MANAGER" in
        systemd-system) ok  "systemd (system scope), unit '${UNIT}'" ;;
        systemd-user)   ok  "systemd (USER scope), unit '${UNIT}'" ;;
        launchd)        ok  "launchd, label '${LAUNCHD_LABEL}'" ;;
        launchd-app)    ok  "macOS Ollama.app (no launchd job registered)" ;;
        container)      ok  "${CONTAINER_RT} container '${CONTAINER_ID}'" ;;
        process)        warn "plain process — no service manager" ;;
        remote)         warn "REMOTE daemon at ${API_URL}" ;;
        unmanaged-api)  warn "API reachable but owner not identifiable" ;;
        absent)         bad "no ollama found" ;;
    esac
    local l; while IFS= read -r l; do [[ -n "$l" ]] && dim "evidence: $l"; done <<< "$MANAGER_EVIDENCE"
    dim "api: ${API_URL} (from ${HOST_SOURCE}) — $([[ $API_UP -eq 1 ]] && echo "reachable, version ${API_VERSION}" || echo "NOT reachable")"

    hdr "config surface"
    case "$SURFACE_KIND" in
        dropin|envfile)
            ok "${SURFACE_KIND}: ${SURFACE_PATH}"
            dim "why: ${SURFACE_WHY}"
            [[ -n "$SURFACE_ALT" ]] && dim "also present, deliberately NOT edited: ${SURFACE_ALT}"
            if [[ -n "$ENVFILES" ]]; then
                local i=1 p o
                while IFS= read -r p; do
                    o="$(printf '%s\n' "$ENVFILE_OPTIONAL" | sed -n "${i}p")"
                    dim "unit declares EnvironmentFile=${p}  (optional=${o}$([[ "$o" == yes ]] && echo ", i.e. the '-' prefix"))"
                    i=$((i+1))
                done <<< "$ENVFILES"
            fi
            ;;
        launchd-env|container-recreate)
            warn "${SURFACE_KIND}: ${SURFACE_PATH}"; dim "why: ${SURFACE_WHY}"
            [[ -n "$SURFACE_ALT" ]] && dim "alternative: ${SURFACE_ALT}" ;;
        *) warn "no config surface: ${SURFACE_WHY}" ;;
    esac
    dim "writable: ${WRITE_MODE} — ${WRITE_WHY}"

    hdr "measured host facts (the formula's inputs)"
    printf '   %-22s %s\n' "cpus online"      "${CPUS_ONLINE} (${CPUS_SRC})"
    if [[ $CPU_LIMIT -gt 0 ]]; then
        printf '   %-22s %s\n' "cpu limit"    "${CPU_LIMIT} (${CPU_LIMIT_SRC})"
    else
        printf '   %-22s %s\n' "cpu limit"    "none detected (no cgroup quota, no CPUQuota/AllowedCPUs)"
    fi
    printf '   %-22s %s\n' "effective cpus"   "${EFFECTIVE_CPUS}"
    printf '   %-22s %s\n' "memory total"     "${MEM_TOTAL_MB} MiB (${MEM_SRC})"
    printf '   %-22s %s\n' "memory available" "${MEM_AVAIL_MB} MiB"
    printf '   %-22s %s\n' "model"            "${MODEL_NAME:-unknown} — ${MODEL_MB} MiB${MODEL_PARAMS:+, ${MODEL_PARAMS} params}${MODEL_QUANT:+ ${MODEL_QUANT}} (${MODEL_SRC})"

    hdr "computed recommendation (audit the arithmetic)"
    if [[ $COMPUTE_RC -ne 0 || $RECOMMENDED -lt 0 ]]; then
        warn "OLLAMA_NUM_PARALLEL: COULD NOT DETERMINE — neither CPU nor memory facts were readable"
    else
        printf '   %-22s %s\n' "slot_mb"  "max(model ${MODEL_MB}, 256) = ${SLOT_MB} MiB"
        printf '   %-22s %s\n' "mem_cap"  "$([[ $MEM_CAP -lt 0 ]] && echo "unknown" || echo "${MEM_AVAIL_MB} * ${MEM_PCT}% / ${SLOT_MB} = ${MEM_CAP}")"
        printf '   %-22s %s\n' "cpu_div"  "${CPU_DIV} (model ${MODEL_MB} MiB $([[ $MODEL_MB -le $SMALL_MODEL_MB ]] && echo "<=" || echo ">") ${SMALL_MODEL_MB} MiB small-model threshold)"
        printf '   %-22s %s\n' "cpu_cap"  "$([[ $CPU_CAP -lt 0 ]] && echo "unknown" || echo "${EFFECTIVE_CPUS} / ${CPU_DIV} = ${CPU_CAP}")"
        printf '   %-22s %s\n' "raw = min(caps)" "${RAW_VALUE} (binding term: ${BINDING})"
        printf '   %-22s %s\n' "clamp"    "[${PARALLEL_MIN}, ${PARALLEL_MAX}]"
        echo -e "   ${BOLD}OLLAMA_NUM_PARALLEL = ${RECOMMENDED}${NC}"
    fi
    if [[ "$KEEPALIVE_ADVICE" == "set" ]]; then
        printf '   %-22s %s\n' "OLLAMA_KEEP_ALIVE" "${KEEPALIVE_TARGET} — ${KEEPALIVE_WHY}"
    else
        printf '   %-22s %s\n' "OLLAMA_KEEP_ALIVE" "unchanged — ${KEEPALIVE_WHY}"
    fi
    printf '   %-22s %s\n' "OLLAMA_MAX_QUEUE" "unchanged — ${MAXQUEUE_WHY}"

    hdr "what the RUNNING daemon has right now"
    if [[ $RUNNING_RC -eq 0 ]]; then
        ok "OLLAMA_NUM_PARALLEL=${RUNNING_PARALLEL:-(unset)}  OLLAMA_KEEP_ALIVE=${RUNNING_KEEPALIVE:-(unset)}"
        dim "source: ${RUNNING_SRC}"
    else
        warn "COULD NOT DETERMINE the running value"
        dim "${RUNNING_SRC}"
    fi

    hdr "in-flight work (restart guard)"
    if [[ $INFLIGHT -eq 1 ]]; then
        bad "BUSY — restarting ollama now would kill in-flight requests"
    else
        ok "idle"
    fi
    while IFS= read -r l; do [[ -n "$l" ]] && dim "$l"; done <<< "$INFLIGHT_EVIDENCE"
    return 0
}

verdict() {   # → 0 fine · 1 change needed · 2 could not determine
    [[ $COMPUTE_RC -ne 0 || $RECOMMENDED -lt 0 ]] && return 2
    case "$MANAGER" in
        absent) return 2 ;;
        remote) return 2 ;;
    esac
    if [[ $RUNNING_RC -ne 0 ]]; then return 2; fi
    local cur="${RUNNING_PARALLEL:-}"
    [[ "$cur" == "(unset)" || -z "$cur" ]] && return 1
    [[ "$cur" =~ ^[0-9]+$ ]] || return 2
    if [[ "$cur" -lt "$RECOMMENDED" ]]; then return 1; fi
    return 0
}

# ══════════════════════════════════════════════════════════════════════════════
# 10. DRIVE
# ══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}ollama-tune${NC} — everything below is measured on this host, nothing is assumed"
print_report

RC=0
case "$MODE" in

  report|measure)
    verdict; RC=$?
    hdr "verdict"
    case $RC in
        0) ok "running configuration already meets the computed recommendation — nothing to do" ;;
        1) bad "tuning needed: running OLLAMA_NUM_PARALLEL=${RUNNING_PARALLEL:-(unset)} < recommended ${RECOMMENDED}"
           info "next: ${SELF_PATH} --print-commands   (or --dry-run / --apply)" ;;
        2) warn "COULD NOT DETERMINE whether tuning is needed — see the notes above" ;;
    esac
    if [[ $WANT_MEASURE -eq 1 ]]; then
        hdr "latency / concurrency probe"
        if [[ $INFLIGHT -eq 1 ]]; then
            warn "a job is in flight; probe requests will queue behind it and the numbers"
            warn "will reflect that queue — which is exactly the stall being diagnosed"
        fi
        measure; mrc=$?
        if [[ $mrc -eq 2 ]]; then
            warn "$CONC_VERDICT"
            [[ $RC -eq 0 ]] && RC=2
        else
            printf '   %-22s %s ms\n' "single embed" "$LAT_SINGLE_MS"
            printf '   %-22s %s ms (%s concurrent)\n' "concurrent wall" "$LAT_CONC_MS" "$PROBE_CONCURRENCY"
            if [[ $mrc -eq 1 ]]; then bad "$CONC_VERDICT"; [[ $RC -eq 0 ]] && RC=1
            else ok "$CONC_VERDICT"; fi
        fi
    fi
    ;;

  print-commands)
    hdr "copy-pasteable commands for THIS host"
    operator_commands
    verdict; RC=$?
    ;;

  dry-run)
    hdr "dry run — nothing is written"
    case "$SURFACE_KIND" in
      dropin|envfile)
        local_want=""
        if [[ "$SURFACE_KIND" == "dropin" ]]; then local_want="$(desired_dropin_content)"
        else local_want="$(desired_envfile_content "$SURFACE_PATH")"; fi
        if surface_already_correct; then
            ok "${SURFACE_PATH} already has exactly these settings — --apply would be a no-op"
            RC=0
        else
            info "would write ${SURFACE_PATH} (mode: ${WRITE_MODE})"
            if [[ -f "$SURFACE_PATH" ]]; then
                echo "--- current"; current_surface_content | sed 's/^/    /'
            else
                echo "--- current: (file does not exist)"
            fi
            echo "--- proposed"; printf '%s\n' "$local_want" | sed 's/^/    /'
            if have diff && [[ -f "$SURFACE_PATH" ]]; then
                echo "--- diff"
                diff -u "$SURFACE_PATH" <(printf '%s\n' "$local_want") | sed 's/^/    /'
            fi
            info "would then: $([[ "$MANAGER" == systemd-* ]] && echo "daemon-reload + restart ${UNIT}" || echo "restart via ${MANAGER}")"
            [[ $INFLIGHT -eq 1 ]] && warn "…but the restart would be REFUSED right now: a job is in flight (use --force to override)"
            RC=1
        fi
        ;;
      *)
        warn "no writable config surface — --apply would not be able to change anything here"
        info "the operator commands for this host are:"
        operator_commands | sed 's/^/    /'
        RC=2
        ;;
    esac
    ;;

  revert)
    hdr "revert"
    case "$SURFACE_KIND" in
      dropin)
        if [[ ! -f "$SURFACE_PATH" ]]; then
            ok "${SURFACE_PATH} does not exist — nothing written by this script to revert"
            RC=0
        elif [[ $INFLIGHT -eq 1 && $FORCE -eq 0 ]]; then
            bad "REFUSING: a job is in flight and reverting requires a restart (use --force)"
            RC=1
        else
            if run_priv rm -f -- "$SURFACE_PATH"; then
                ok "removed ${SURFACE_PATH}"
                if restart_service; then ok "restarted ${UNIT}"; RC=0
                else bad "removed the drop-in but could NOT restart — the running daemon still has the old value"; RC=1; fi
            else
                bad "could not remove ${SURFACE_PATH} (${WRITE_WHY})"
                info "run: sudo rm -f ${SURFACE_PATH} && sudo systemctl daemon-reload && sudo systemctl restart ${UNIT}"
                RC=1
            fi
        fi
        ;;
      envfile)
        newest="$(ls -1t -- "${SURFACE_PATH}.${BAK_SUFFIX}."* 2>/dev/null | head -1)"
        if [[ -z "$newest" ]]; then
            warn "no ${BAK_SUFFIX} backup found next to ${SURFACE_PATH} — nothing to restore"
            RC=2
        elif [[ $INFLIGHT -eq 1 && $FORCE -eq 0 ]]; then
            bad "REFUSING: a job is in flight and reverting requires a restart (use --force)"
            RC=1
        else
            if run_priv cp -p -- "$newest" "$SURFACE_PATH"; then
                ok "restored ${SURFACE_PATH} from ${newest}"
                if restart_service; then ok "restarted ${UNIT}"; RC=0; else bad "restore done, restart FAILED"; RC=1; fi
            else
                bad "could not restore (${WRITE_WHY})"; RC=1
            fi
        fi
        ;;
      *) warn "nothing to revert for surface kind '${SURFACE_KIND}'"; RC=2 ;;
    esac
    ;;

  apply)
    hdr "apply"
    if [[ $COMPUTE_RC -ne 0 || $RECOMMENDED -lt 0 ]]; then
        warn "COULD NOT DETERMINE a value from this host — refusing to write a guess"
        RC=2
    elif [[ "$SURFACE_KIND" != "dropin" && "$SURFACE_KIND" != "envfile" ]]; then
        bad "no writable config surface on this host (${SURFACE_WHY})"
        info "this is the honest outcome, not a failure to try. Do it by hand:"
        operator_commands | sed 's/^/    /'
        RC=1
    elif [[ "$WRITE_MODE" == "no" ]]; then
        bad "cannot write ${SURFACE_PATH} without an interactive password prompt"
        dim "${WRITE_WHY}"
        info "no prompt was triggered. Run these yourself — they are built for THIS host:"
        echo
        operator_commands | sed 's/^/    /'
        RC=1
    elif surface_already_correct; then
        ok "${SURFACE_PATH} already contains exactly these settings — no write, no restart"
        # Idempotency is not just "the file matches": confirm the RUNNING daemon
        # agrees, otherwise the file is right and the process is stale.
        if [[ $RUNNING_RC -eq 0 && "${RUNNING_PARALLEL:-}" == "$RECOMMENDED" ]]; then
            ok "the running daemon also reports OLLAMA_NUM_PARALLEL=${RECOMMENDED}"
            RC=0
        else
            warn "file is correct but the RUNNING daemon reports '${RUNNING_PARALLEL:-unknown}' — it has not been restarted since"
            RC=1
        fi
    elif [[ $INFLIGHT -eq 1 && $FORCE -eq 0 ]]; then
        bad "REFUSING to apply: a job is in flight against this ollama."
        echo "   Applying means restarting the daemon, and a restart kills every in-flight"
        echo "   request — including a running index rebuild, which would have to start over."
        while IFS= read -r l; do [[ -n "$l" ]] && echo "     · $l"; done <<< "$INFLIGHT_EVIDENCE"
        echo "   Wait for it to finish, or re-run with --force if you accept the loss."
        RC=1
    else
        # ---- measure BEFORE, so the operator gets a real number to compare
        BEFORE_SINGLE=-1; BEFORE_CONC=-1
        measure; mrc_before=$?
        if [[ $mrc_before -ne 2 ]]; then
            BEFORE_SINGLE=$LAT_SINGLE_MS; BEFORE_CONC=$LAT_CONC_MS
            info "before: single ${BEFORE_SINGLE} ms · ${PROBE_CONCURRENCY} concurrent ${BEFORE_CONC} ms — ${CONC_VERDICT}"
        else
            warn "before-measurement: ${CONC_VERDICT}"
        fi

        bak="$(backup_surface)"
        if [[ $? -ne 0 ]]; then
            bad "could not create a backup of ${SURFACE_PATH} — refusing to modify it"
            RC=1
        else
            info "backup: ${bak}"
            if [[ "$SURFACE_KIND" == "dropin" ]]; then want="$(desired_dropin_content)"
            else want="$(desired_envfile_content "$SURFACE_PATH")"; fi
            if write_surface "$want"; then
                ok "wrote ${SURFACE_PATH}"
                if restart_service; then
                    ok "restarted ${UNIT} via ${MANAGER}"
                    sleep 2
                    # ---- VERIFY IN THE RUNNING PROCESS, not in the file.
                    read_running_config
                    if [[ $RUNNING_RC -eq 0 && "${RUNNING_PARALLEL:-}" == "$RECOMMENDED" ]]; then
                        ok "VERIFIED: the running daemon reports OLLAMA_NUM_PARALLEL=${RUNNING_PARALLEL} (${RUNNING_SRC})"
                        RC=0
                    elif [[ $RUNNING_RC -eq 0 ]]; then
                        bad "file written and service restarted, but the running daemon reports '${RUNNING_PARALLEL}', not ${RECOMMENDED}"
                        RC=1
                    else
                        warn "COULD NOT CONFIRM the value in the running process (${RUNNING_SRC})"
                        warn "the file was written successfully — but a successful write is NOT evidence that it took effect"
                        RC=2
                    fi
                    # ---- and a behavioural check, which needs no permissions
                    measure; mrc_after=$?
                    if [[ $mrc_after -ne 2 ]]; then
                        info "after:  single ${LAT_SINGLE_MS} ms · ${PROBE_CONCURRENCY} concurrent ${LAT_CONC_MS} ms — ${CONC_VERDICT}"
                        if [[ $BEFORE_CONC -gt 0 && $LAT_CONC_MS -gt 0 ]]; then
                            info "concurrent wall time: ${BEFORE_CONC} ms → ${LAT_CONC_MS} ms"
                        fi
                        [[ $mrc_after -eq 1 && $RC -eq 0 ]] && { bad "…but requests still serialise; the setting did not have the intended effect"; RC=1; }
                    else
                        warn "after-measurement: ${CONC_VERDICT}"
                    fi
                else
                    bad "wrote ${SURFACE_PATH} but the restart FAILED — the running daemon still has the old value"
                    info "restart it yourself:"
                    operator_commands | grep -E 'restart|kickstart' | sed 's/^/    /'
                    RC=1
                fi
            else
                bad "write of ${SURFACE_PATH} failed (${WRITE_WHY})"
                RC=1
            fi
        fi
    fi
    ;;
esac

hdr "exit"
case $RC in
    0) ok  "exit 0 — fine" ;;
    1) bad "exit 1 — a real problem / action required" ;;
    2) warn "exit 2 — COULD NOT DETERMINE (this is neither a pass nor a fail)" ;;
esac
exit $RC
