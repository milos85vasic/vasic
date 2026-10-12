#!/usr/bin/env bash
# zero-gap-qa-readiness.sh — feature 010 T060 (umbrella part): MANUAL-QA READINESS check.
#
# Answers "can a human start a manual QA session from scripts/qa-up.sh?" WITHOUT starting,
# stopping or restarting anything. It never runs qa-up.sh, never touches the workshop
# container or workshop/platform/bin, and never binds a port (the one disposable listener it
# can create, in --prove-failure, binds a kernel-chosen ephemeral port on 127.0.0.1).
#
# ── STATIC half (always runs; a failure here is rc 1) ───────────────────────
#   S1  scripts/qa-up.sh exists, is executable, and parses (`bash -n`)
#   S2  it documents its flow: header carries WHAT IT BOOTS, USAGE, EXIT and names all four
#       services (vd, mv, workshop, ai)
#   S3  it discovers ports through _tools/containers/cmd/port-discover: that source exists, qa-up
#       references it, and every service's port is obtained from `discover` / `start_static`
#   S4  no frozen port literal: every 4-5 digit number in NON-COMMENT code must be the default
#       of a `${QA_*_DEFAULT_PORT:-N}` preference that is passed to discover/start_static.
#       Anything else (a literal in a `--port 8087`, a URL, a bind) is a finding. The preferred
#       defaults themselves are REPORTED as INFO, because they are literals that discovery may
#       override (qa-up warns when it does); they are not hard-coded bindings.
#
# ── DYNAMIC half (read-only GETs; never starts anything) ────────────────────
#   Reads the services' own state files (vd/mv: $QA_STATE_DIR/<svc>.port; workshop: the state
#   file its own _common.sh names; ai: ai_interviewing/platform/run/server.json) and GETs
#   the health URL of each service that publishes an address: vd/mv `/`, workshop and ai
#   `/api/health`. A service with no state file, no address, or no answer is "not up" — that
#   is NOT determinable readiness, so the dynamic half then ends in rc 2, never a pass. Only
#   when all four answer 200 is the dynamic half PASS.
#
# ── Usage ────────────────────────────────────────────────────────────────────
#   zero-gap-qa-readiness.sh [--root <dir>] [--static-only] [--timeout <s>]
#                            [--state-dir <dir>] [--workshop-state <file>] [--ai-state <file>]
#   zero-gap-qa-readiness.sh --prove-failure
#
# ── Exit (three-valued; 2 is NEVER a pass) ───────────────────────────────────
#   0  static half clean AND all four health endpoints answered 200 just now
#   1  a static finding (missing/non-executable/undocumented/no discovery/frozen port literal)
#      or a service that publishes an address and answers something other than 200
#   2  COULD NOT DETERMINE: bad --root, tool missing (curl), --static-only (readiness of the
#      running stack was not examined), or at least one service not up / no state published.
#      Static findings still win (1 outranks 2).

set -u
export LC_ALL=C

SELF="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
ROOT=""
STATIC_ONLY=0
TIMEOUT=5
STATE_DIR_OVR=""
WS_STATE_OVR=""
AI_STATE_OVR=""
PROVE=0

die2() { echo "zero-gap-qa-readiness: COULD NOT DETERMINE: $*" >&2; exit 2; }

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) [ "$#" -ge 2 ] || die2 "--root needs a value"; ROOT="$2"; shift 2 ;;
        --static-only) STATIC_ONLY=1; shift ;;
        --timeout) [ "$#" -ge 2 ] || die2 "--timeout needs a value"; TIMEOUT="$2"; shift 2 ;;
        --state-dir) [ "$#" -ge 2 ] || die2 "--state-dir needs a value"; STATE_DIR_OVR="$2"; shift 2 ;;
        --workshop-state) [ "$#" -ge 2 ] || die2 "--workshop-state needs a value"; WS_STATE_OVR="$2"; shift 2 ;;
        --ai-state) [ "$#" -ge 2 ] || die2 "--ai-state needs a value"; AI_STATE_OVR="$2"; shift 2 ;;
        --prove-failure) PROVE=1; shift ;;
        -h|--help) sed -n '2,/^set -u/p' "$SELF" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die2 "unknown argument: $1" ;;
    esac
done
case "$TIMEOUT" in ''|*[!0-9]*) die2 "--timeout must be an integer" ;; esac

if [ -z "$ROOT" ]; then ROOT="$(cd -- "$(dirname -- "$SELF")/.." && pwd -P)"; fi

FINDINGS=0
INFO=()
finding() { echo "FINDING  $*"; FINDINGS=$((FINDINGS + 1)); }
okline()  { echo "PASS     $*"; }

# ─────────────────────────────────────────────────────────────────────────────
static_half() {
    local qa="$ROOT/scripts/qa-up.sh" pd="$ROOT/_tools/containers/cmd/port-discover"
    # S1
    if [ ! -f "$qa" ]; then finding "S1 scripts/qa-up.sh does not exist"; return; fi
    if [ ! -x "$qa" ]; then finding "S1 scripts/qa-up.sh is not executable"; else okline "S1 qa-up.sh exists and is executable"; fi
    if bash -n "$qa" 2>/dev/null; then okline "S1 qa-up.sh parses (bash -n)"; else finding "S1 qa-up.sh does not parse"; fi
    # S2
    local hdr; hdr="$(awk 'NR>1 && !/^#/{exit} {print}' "$qa")"
    local k miss=""
    for k in "WHAT IT BOOTS" "USAGE" "EXIT"; do printf '%s\n' "$hdr" | grep -q -- "$k" || miss="$miss [$k]"; done
    for k in vd mv workshop ai; do printf '%s\n' "$hdr" | grep -Eq "^#[[:space:]]+$k[[:space:]]" || miss="$miss [service $k]"; done
    if [ -z "$miss" ]; then okline "S2 header documents flow (WHAT IT BOOTS / USAGE / EXIT) and all four services"; else finding "S2 header does not document:$miss"; fi
    # S3
    if [ -f "$pd/main.go" ]; then okline "S3 discovery CLI source present (_tools/containers/cmd/port-discover/main.go)"; else finding "S3 _tools/containers/cmd/port-discover/main.go missing"; fi
    if grep -Eq 'port-discover' "$qa" && grep -Eq '^discover\(\)' "$qa"; then okline "S3 qa-up.sh defines discover() over port-discover"; else finding "S3 qa-up.sh has no discover() over port-discover"; fi
    local code; code="$(grep -vE '^[[:space:]]*#' "$qa")"
    local svc
    for svc in 'start_static vd' 'start_static mv' 'discover "$PREFIX-workshop"' 'discover "$PREFIX-ai-http"' 'discover "$PREFIX-ai-https"'; do
        if printf '%s\n' "$code" | grep -qF -- "$svc"; then :; else finding "S3 no call '$svc' — a service's port is not obtained through discovery"; fi
    done
    printf '%s\n' "$code" | grep -qF 'start_static()' || finding "S3 start_static() missing"
    # the body of start_static must obtain its port from discover
    if printf '%s\n' "$code" | awk '/^start_static\(\)/{f=1} f&&/discover "\$PREFIX/{found=1} f&&/^}/{exit} END{exit !found}'; then
        okline "S3 start_static obtains its port from discover"; else finding "S3 start_static does not call discover"; fi
    # S4: strip the allowed default-preference expansions, trailing comments, then look for port-like numbers
    local stripped bad pref
    stripped="$(printf '%s\n' "$code" | sed -E 's/\$\{QA_[A-Z_]+_DEFAULT_PORT:-[0-9]+\}//g; s/[[:space:]]#[[:space:]].*$//')"
    bad="$(printf '%s\n' "$stripped" | grep -nE '(^|[^0-9A-Za-z_.])[0-9]{4,5}([^0-9]|$)' || true)"
    if [ -z "$bad" ]; then okline "S4 no frozen port literal in non-comment code"; else
        while IFS= read -r l; do [ -n "$l" ] && finding "S4 frozen port literal in qa-up.sh code (stripped-line $l)"; done <<<"$bad"; fi
    # defaults: each must sit on a line that hands it to discover/start_static
    pref="$(grep -nE '\$\{QA_[A-Z_]+_DEFAULT_PORT:-[0-9]+\}' "$qa" | grep -vE '^[0-9]+:[[:space:]]*#' || true)"
    local ndef=0 nbad=0 l
    while IFS= read -r l; do
        [ -z "$l" ] && continue
        ndef=$((ndef + 1))
        printf '%s\n' "$l" | grep -qE 'start_static|discover' || { nbad=$((nbad + 1)); finding "S4 default preference not passed to discover/start_static: $l"; }
        INFO+=("$(printf '%s' "$l" | sed -E 's/^[0-9]+:[[:space:]]*//')")
    done <<<"$pref"
    if [ "$ndef" -eq 0 ]; then finding "S4 no QA_*_DEFAULT_PORT preference found — cannot confirm what is passed to discovery"; fi
    [ "$ndef" -gt 0 ] && [ "$nbad" -eq 0 ] && okline "S4 all $ndef port preferences are passed through discover/start_static"
    for l in "${INFO[@]+"${INFO[@]}"}"; do echo "INFO     preferred-default literal (discovery may override): $l"; done
}

# ─────────────────────────────────────────────────────────────────────────────
DYN_DOWN=0
DYN_OK=0
DYN_BAD=0
probe() {  # $1 label, $2 url
    local code
    code="$(curl -s -m "$TIMEOUT" -o /dev/null -w '%{http_code}' "$2" 2>/dev/null)" || code=000
    if [ "$code" = 200 ]; then echo "PASS     D $1 answered 200 at $2"; DYN_OK=$((DYN_OK + 1))
    elif [ "$code" = 000 ]; then echo "NOTUP    D $1 did not answer at $2 (connection refused/timeout)"; DYN_DOWN=$((DYN_DOWN + 1))
    else finding "D $1 answered HTTP $code at $2"; DYN_BAD=$((DYN_BAD + 1)); fi
}
jstr() { sed -n "s/.*\"$2\": *\"\\([^\"]*\\)\".*/\\1/p" "$1" 2>/dev/null | head -1; }

dynamic_half() {
    command -v curl >/dev/null 2>&1 || { echo "NOTUP    D curl absent"; DYN_DOWN=4; return; }
    local sd="${STATE_DIR_OVR:-${QA_STATE_DIR:-$ROOT/.service-registry/qa}}" svc port
    for svc in vd mv; do
        if [ -s "$sd/$svc.port" ]; then
            port="$(cat "$sd/$svc.port")"
            case "$port" in ''|*[!0-9]*) echo "NOTUP    D $svc: unreadable port file"; DYN_DOWN=$((DYN_DOWN + 1)); continue ;; esac
            probe "$svc" "http://127.0.0.1:$port/"
        else echo "NOTUP    D $svc: no $sd/$svc.port (never started, or stopped)"; DYN_DOWN=$((DYN_DOWN + 1)); fi
    done
    local ws="$WS_STATE_OVR" addr
    if [ -z "$ws" ]; then
        ws="$(timeout 20 bash -c 'source "$1/workshop/scripts/_common.sh" >/dev/null 2>&1; printf "%s" "${STATE_FILE:-}"' _ "$ROOT" 2>/dev/null)"
    fi
    addr=""; [ -n "$ws" ] && [ -f "$ws" ] && addr="$(jstr "$ws" http)"
    if [ -n "$addr" ]; then probe workshop "$addr/api/health"; else echo "NOTUP    D workshop: no published address (state file '${ws:-unresolved}')"; DYN_DOWN=$((DYN_DOWN + 1)); fi
    local ai="${AI_STATE_OVR:-$ROOT/ai_interviewing/platform/run/server.json}"
    addr=""; [ -f "$ai" ] && addr="$(jstr "$ai" http)"
    if [ -n "$addr" ]; then probe ai "$addr/api/health"; else echo "NOTUP    D ai: no published address (state file '$ai')"; DYN_DOWN=$((DYN_DOWN + 1)); fi
}

# ─────────────────────────────────────────────────────────────────────────────
run_main() {
    [ -d "$ROOT" ] || die2 "--root is not a directory: $ROOT"
    static_half
    if [ "$STATIC_ONLY" -eq 1 ]; then
        echo "NOTE     --static-only: the running stack was not examined"
    else
        dynamic_half
    fi
    echo "SUMMARY  static findings+dynamic non-200: $FINDINGS ; dynamic: $DYN_OK answered, $DYN_DOWN not up"
    if [ "$FINDINGS" -gt 0 ]; then echo "VERDICT: FAIL"; return 1; fi
    if [ "$STATIC_ONLY" -eq 1 ] || [ "$DYN_DOWN" -gt 0 ] || [ "$DYN_OK" -ne 4 ]; then
        echo "VERDICT: COULD NOT DETERMINE — static half clean, but readiness of the running stack is not established (not a pass)"; return 2; fi
    echo "VERDICT: PASS — static half clean and all four health endpoints answered 200"; return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Paired proof: seeded frozen port / no discovery / non-executable / undocumented are caught
# on scratch copies of qa-up.sh; a mock stack (kernel-chosen ephemeral ports, 127.0.0.1) proves
# the dynamic half's pass and its refusal to pass when one service is down.
# ─────────────────────────────────────────────────────────────────────────────
prove_failure() {
    local pass=0 fail=0 rc out
    T="$(mktemp -d "${TMPDIR:-/tmp}/zgqa-proof.XXXXXX")" || die2 "mktemp failed"
    MOCKPIDS=""
    trap 'for p in $MOCKPIDS; do kill "$p" 2>/dev/null; done; rm -rf "$T"' EXIT
    ok()  { echo "  PASS $1"; pass=$((pass + 1)); }
    bad() { echo "  FAIL $1"; fail=$((fail + 1)); echo "$out" | head -6 | sed 's/^/       /'; }
    local live="$ROOT/scripts/qa-up.sh"
    [ -f "$live" ] || die2 "scripts/qa-up.sh absent: cannot build the proof fixtures"
    mkdir -p "$T/base/scripts" "$T/base/_tools/containers/cmd/port-discover"
    cp "$live" "$T/base/scripts/qa-up.sh"; chmod +x "$T/base/scripts/qa-up.sh"
    : > "$T/base/_tools/containers/cmd/port-discover/main.go"
    mutant() {  # $1 name, then a sed script applied to qa-up.sh
        rm -rf "$T/$1"; cp -a "$T/base" "$T/$1"; shift_name="$1"; shift
        [ "$#" -gt 0 ] && sed -i -E "$1" "$T/$shift_name/scripts/qa-up.sh"
    }
    expect() {  # label want root
        out="$(bash "$SELF" --root "$3" --static-only 2>&1)"; rc=$?
        if [ "$rc" -eq "$2" ]; then ok "$1 (rc $rc)"; else bad "$1: wanted rc $2 got $rc"; fi
    }
    echo "zero-gap-qa-readiness --prove-failure"
    # control: the real qa-up.sh, static-only, is rc 2 (never a pass) with zero static findings
    out="$(bash "$SELF" --root "$ROOT" --static-only 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -q '^FINDING'; then ok "C0 control: real qa-up.sh static clean, --static-only => 2 not 0"; else bad "C0 got $rc"; fi
    # M1 seeded frozen port in a bind
    mutant m1 's/--bind "\$BIND"/--bind "$BIND" --port 8087/'
    expect "M1 seeded frozen port literal is caught" 1 "$T/m1"
    # M2 seeded frozen port replacing a discovery call
    mutant m2 's/port="\$\(discover "\$PREFIX-workshop" "\$\{QA_WORKSHOP_DEFAULT_PORT:-8087\}"\)" \|\| exit 2/port=8087/'
    expect "M2 discovery call replaced by a literal is caught" 1 "$T/m2"
    # M3 discovery removed from start_static
    mutant m3 's/port="\$\(discover "\$PREFIX-\$svc" "\$pref"\)" \|\| exit 2/port="$pref"/'
    expect "M3 start_static no longer discovering is caught" 1 "$T/m3"
    # M4 not executable
    mutant m4; chmod -x "$T/m4/scripts/qa-up.sh"
    expect "M4 non-executable qa-up.sh is caught" 1 "$T/m4"
    # M5 header stripped of USAGE
    mutant m5 's/^#   bash scripts\/qa-up.sh +boot everything.*$//; s/^# USAGE$/# HOWTO/'
    expect "M5 undocumented flow is caught" 1 "$T/m5"
    # M6 missing script
    mutant m6; rm -f "$T/m6/scripts/qa-up.sh"
    expect "M6 missing qa-up.sh is caught" 1 "$T/m6"
    # rc 2
    out="$(bash "$SELF" --root /nonexistent 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ]; then ok "U1 --root /nonexistent => 2"; else bad "U1 got $rc"; fi
    # dynamic: nothing up => 2 (empty state)
    mkdir -p "$T/empty"
    out="$(bash "$SELF" --root "$ROOT" --state-dir "$T/empty" --workshop-state "$T/none.json" --ai-state "$T/none.json" 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'NOTUP'; then ok "U2 nothing up => 2 (not a pass)"; else bad "U2 got $rc"; fi
    # mock stack: four disposable 127.0.0.1 servers on kernel-chosen ports, answering 200 everywhere
    command -v python3 >/dev/null 2>&1 || die2 "python3 absent: cannot build the mock stack"
    cat > "$T/mock.py" <<'PY'
import sys, http.server, socketserver
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def log_message(self, *a): pass
s = socketserver.TCPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
s.serve_forever()
PY
    local i ports=()
    for i in 1 2 3 4; do
        python3 "$T/mock.py" > "$T/mock$i.port" 2>/dev/null &
        MOCKPIDS="$MOCKPIDS $!"
    done
    local w
    for i in 1 2 3 4; do for w in $(seq 1 50); do [ -s "$T/mock$i.port" ] && break; sleep 0.1; done; ports+=("$(cat "$T/mock$i.port" 2>/dev/null)"); done
    if [ -z "${ports[0]}" ] || [ -z "${ports[3]}" ]; then die2 "mock servers did not start"; fi
    mkdir -p "$T/state"; printf '%s' "${ports[0]}" > "$T/state/vd.port"; printf '%s' "${ports[1]}" > "$T/state/mv.port"
    printf '{"http": "http://127.0.0.1:%s"}\n' "${ports[2]}" > "$T/ws.json"
    printf '{"http": "http://127.0.0.1:%s"}\n' "${ports[3]}" > "$T/ai.json"
    out="$(bash "$SELF" --root "$ROOT" --state-dir "$T/state" --workshop-state "$T/ws.json" --ai-state "$T/ai.json" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '4 answered'; then ok "G1 mock stack: real qa-up.sh static clean + 4/4 answered => 0"; else bad "G1 got $rc"; fi
    # one service down: kill mock 4 (ai) => 2
    kill "${MOCKPIDS##* }" 2>/dev/null; sleep 0.3
    out="$(bash "$SELF" --root "$ROOT" --state-dir "$T/state" --workshop-state "$T/ws.json" --ai-state "$T/ai.json" 2>&1)"; rc=$?
    if [ "$rc" -eq 2 ]; then ok "G2 one of four down => 2, never 0"; else bad "G2 got $rc"; fi
    # static finding outranks a fully-up mock stack: frozen-port mutant + (restart not needed) use m1 with state of 3 up -> 1
    out="$(bash "$SELF" --root "$T/m1" --state-dir "$T/state" --workshop-state "$T/ws.json" --ai-state "$T/ai.json" 2>&1)"; rc=$?
    if [ "$rc" -eq 1 ]; then ok "G3 static finding outranks incomplete dynamic => 1"; else bad "G3 got $rc"; fi
    echo "  $pass passed / $fail failed"
    [ "$fail" -eq 0 ]
}

if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi
run_main
exit $?
