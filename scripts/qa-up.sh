#!/usr/bin/env bash
# =============================================================================
# qa-up.sh — boot every local website and service for a manual QA session,
# on ports that are DISCOVERED, never assumed.
#
# WHAT IT BOOTS
#   vd        vasic.digital          static, served from vasic.digital/
#   mv        milosvasic.ru          static, served from milosvasic.ru/_site/
#                                    (rebuilt first, in a container, when any
#                                    tracked source file is newer than it)
#   workshop  workshop curriculum    workshop/scripts/start.sh --port <P>
#   ai        ai_interviewing        ai_interviewing/platform/scripts/start.sh,
#                                    HTTP and HTTPS ports passed through its own
#                                    AICUR_HTTP / AICUR_HTTPS variables
#
# WHY PORTS ARE DISCOVERED (operator directive, 2026-09-22)
#   A service's historical default port may be held by ANOTHER service on this
#   host — measured: an unrelated llama-server holds 8082. Binding a literal
#   then fails, or worse, a tester lands on the wrong program. Every port here
#   comes from _tools/containers/cmd/port-discover, the thin CLI front for the
#   Containers Submodule's pkg/serviceregistry (§11.4.76(1)/(4): discovery is
#   consumed from that module, never reimplemented). It returns the default
#   when free, the previously registered port when that is still free, and
#   otherwise a genuinely free port near the default — and records the choice
#   in the shared registry ($ROOT/.service-registry) so other tools can look
#   it up by name.
#
# IDEMPOTENT. A static server counts as OURS only when its recorded pid is
#   alive, its cmdline names the port, AND the kernel reports that pid as the
#   owner of the port's listener (ss -ltnp) — so a foreign program that won a
#   discovery->bind race is never reported as our site (§11.4.174). Ours and
#   answering: reused, not restarted. The workshop and ai stacks are reused
#   when the address their own state file publishes answers /api/health, and
#   are always checked at THAT address, not the port that was requested.
#
# USAGE
#   bash scripts/qa-up.sh              boot everything, print the URLs
#   bash scripts/qa-up.sh --only vd    boot one service (vd | mv | workshop | ai)
#   bash scripts/qa-up.sh --stop       stop what this script started; a workshop/ai
#                                      stack it merely reused is left running
#   bash scripts/qa-up.sh --no-rebuild never rebuild milosvasic.ru/_site
#
# ENVIRONMENT (all optional)
#   QA_VD_DEFAULT_PORT        preferred port for vd        (default 8401)
#   QA_MV_DEFAULT_PORT        preferred port for mv        (default 8084)
#   QA_WORKSHOP_DEFAULT_PORT  preferred port for workshop  (default 8087)
#   QA_AI_HTTP_DEFAULT_PORT   preferred HTTP port for ai   (default 8099)
#   QA_AI_HTTPS_DEFAULT_PORT  preferred HTTPS port for ai  (default 8443)
#   QA_NAME_PREFIX            registry name prefix         (default vasic-qa)
#   QA_STATE_DIR              pid/port files               (default $ROOT/.service-registry/qa)
#   QA_REGISTRY_DIR           port-discover registry       (default $ROOT/.service-registry)
#   QA_AI_HOME                ai_interviewing platform dir (default $ROOT/ai_interviewing/platform)
#
# EXIT: 0 every requested service is up and answering on its discovered port
#       1 a service genuinely failed to come up or does not answer
#       2 could not determine (no go / curl / ss, port-discover unbuildable,
#         bad argument) — NEVER a pass
# =============================================================================
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONTAINERS_DIR="$ROOT/_tools/containers"
PORT_DISCOVER="$CONTAINERS_DIR/bin/port-discover"
SITE_BUILD="$CONTAINERS_DIR/bin/site-build"
PREFIX="${QA_NAME_PREFIX:-vasic-qa}"
STATE_DIR="${QA_STATE_DIR:-$ROOT/.service-registry/qa}"
REGISTRY_DIR="${QA_REGISTRY_DIR:-$ROOT/.service-registry}"
BIND=127.0.0.1
# ONE definition, used by BOTH the start and the --stop paths: an override that
# only one path honours stopped the LIVE instance from a sandbox run (2026-09-22).
AI_HOME="${QA_AI_HOME:-$ROOT/ai_interviewing/platform}"

log()  { printf '>> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
undetermined() { printf 'UNDETERMINED: %s\n' "$*" >&2; exit 2; }

ONLY="" STOP=0 REBUILD=1
while [ "$#" -gt 0 ]; do
    case "$1" in
        --only) [ "$#" -ge 2 ] || undetermined "--only needs vd|mv|workshop|ai"
                case "$2" in vd|mv|workshop|ai) ONLY="$2" ;; *) undetermined "unknown service: $2" ;; esac
                shift 2 ;;
        --stop) STOP=1; shift ;;
        --no-rebuild) REBUILD=0; shift ;;
        -h|--help) sed -n '2,57p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) undetermined "unknown argument: $1" ;;
    esac
done
wants() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }
mkdir -p "$STATE_DIR"
# ss is needed by BOTH the start and the --stop paths (ownership = listener pid).
command -v ss   >/dev/null 2>&1 || undetermined "ss absent; cannot prove which process owns a port"

# ---- ownership: is the pid in <svc>.pid OUR static server on <svc>.port? ----
owned_pid() {   # prints pid if the recorded process is alive AND is ours
    local svc="$1" pid port root
    pid="$(cat "$STATE_DIR/$svc.pid" 2>/dev/null)" || return 1
    port="$(cat "$STATE_DIR/$svc.port" 2>/dev/null)" || return 1
    [ -r "/proc/$pid/cmdline" ] || return 1
    tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- "http.server $port " || return 1
    # ...and serving OUR directory: a stale/recycled pid record can otherwise
    # name ANOTHER python http.server on the same port (found by round-3 review).
    root="$(cat "$STATE_DIR/$svc.root" 2>/dev/null)" || return 1
    tr '\0' '\n' < "/proc/$pid/cmdline" | grep -qxF -- "$root" || return 1
    # Alive-and-named is not ownership: a process that is about to fail its
    # bind looks exactly like that while a FOREIGN program already holds the
    # port. Ownership is the kernel's answer — the pid owning the listener.
    [ "$(listener_pid "$port")" = "$pid" ] || return 1
    printf '%s' "$pid"
}

listener_pid() {  # $1 port -> pid owning the TCP listener on $BIND:$1 (empty if none)
    ss -ltnpH "sport = :$1" 2>/dev/null | grep -F "$BIND:$1 " \
        | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' | head -1
}

stop_static() {
    local svc="$1" pid
    if pid="$(owned_pid "$svc")"; then
        kill "$pid" && log "$svc: stopped pid $pid"
    else
        log "$svc: nothing of ours running"
    fi
    rm -f "$STATE_DIR/$svc.pid" "$STATE_DIR/$svc.port" "$STATE_DIR/$svc.root"
}

# Stacks with their own lifecycle scripts are stopped ONLY when this script
# started them (a <svc>.started marker, written on the start path and never on
# the reuse path). A stack that was already up — started by an operator or a
# gate that reads its state file — is left running and said so.
stop_stack() {  # $1 svc, $2 its own stop.sh
    local svc="$1" rc
    if [ ! -f "$STATE_DIR/$svc.started" ]; then
        log "$svc: not started by qa-up.sh — left running (stop it with $2)"
        return 0
    fi
    bash "$2"; rc=$?
    [ "$rc" -eq 0 ] || exit "$rc"
    rm -f "$STATE_DIR/$svc.started"
}

if [ "$STOP" -eq 1 ]; then
    wants vd && stop_static vd
    wants mv && stop_static mv
    wants workshop && stop_stack workshop "$ROOT/workshop/scripts/stop.sh"
    wants ai && stop_stack ai "$AI_HOME/scripts/stop.sh"
    exit 0
fi

command -v curl >/dev/null 2>&1 || undetermined "curl absent; cannot check whether any service answers"

# ---- the Containers Submodule's discovery CLI, built on demand -------------
ensure_bin() {  # $1 binary path, $2 cmd dir name
    [ -x "$1" ] && return 0
    command -v go >/dev/null 2>&1 || undetermined "go toolchain absent; cannot build $2"
    log "building $2 from _tools/containers/cmd/$2 ..."
    ( cd "$CONTAINERS_DIR" && go build -o "bin/$2" "./cmd/$2" ) || undetermined "go build ./cmd/$2 failed"
}
ensure_bin "$PORT_DISCOVER" port-discover

discover() {    # $1 registry name, $2 preferred port, [$3 = -udp] -> prints a free port
    local p
    p="$("$PORT_DISCOVER" -registry-dir "$REGISTRY_DIR" ${3:+"$3"} "$1" "$2")" \
        || undetermined "port-discover failed for $1 (default $2)"
    case "$p" in ''|*[!0-9]*) undetermined "port-discover returned a non-port for $1: '$p'" ;; esac
    [ "$p" = "$2" ] || warn "$1: using port $p instead of preferred $2 (preferred is in use or claimed by another name in the registry, or $1 is registered at $p)"
    printf '%s' "$p"
}

answers() {     # $1 url -> 0 when it returns HTTP 200
    [ "$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$1")" = 200 ]
}

FAILED=0
declare -A URL

start_static() {    # $1 svc, $2 docroot, $3 preferred port
    local svc="$1" root="$2" pref="$3" pid port i
    [ -f "$root/index.html" ] || { warn "$svc: $root/index.html missing"; FAILED=1; return; }
    if pid="$(owned_pid "$svc")"; then
        port="$(cat "$STATE_DIR/$svc.port")"
        if answers "http://$BIND:$port/"; then
            log "$svc: already running (pid $pid) on $port — reused"
            URL[$svc]="http://$BIND:$port/"; return
        fi
        kill "$pid" 2>/dev/null
        for i in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.25; done
    fi
    port="$(discover "$PREFIX-$svc" "$pref")" || exit 2
    setsid nohup python3 -m http.server "$port" --bind "$BIND" --directory "$root" \
        > "$STATE_DIR/$svc.log" 2>&1 < /dev/null &
    pid=$!
    printf '%s' "$pid"  > "$STATE_DIR/$svc.pid"
    printf '%s' "$port" > "$STATE_DIR/$svc.port"
    printf '%s' "$root" > "$STATE_DIR/$svc.root"
    for i in $(seq 1 40); do
        kill -0 "$pid" 2>/dev/null || break
        answers "http://$BIND:$port/" && break
        sleep 0.25
    done
    # An answer on the port is NOT enough: between discovery and bind another
    # process can take the port, ours dies with "Address already in use", and
    # the answer then comes from a FOREIGN program. Only our own live process
    # (owned_pid: pid alive + cmdline names this port) counts as started.
    if owned_pid "$svc" >/dev/null && answers "http://$BIND:$port/"; then
        log "$svc: started (pid $pid) on $port"
        URL[$svc]="http://$BIND:$port/"
    elif answers "http://$BIND:$port/"; then
        warn "$svc: our server (pid $pid) does not own port $port and ANOTHER program answers there — lost the discovery-to-bind race; see $STATE_DIR/$svc.log"
        rm -f "$STATE_DIR/$svc.pid" "$STATE_DIR/$svc.port"; FAILED=1
    else
        warn "$svc: did not answer on $port; see $STATE_DIR/$svc.log"; FAILED=1
    fi
}

mv_site_stale() {   # 0 when a tracked source file is newer than the built site
    local idx="$ROOT/milosvasic.ru/_site/index.html" f
    [ -f "$idx" ] || return 0
    while IFS= read -r f; do
        [ "$ROOT/milosvasic.ru/$f" -nt "$idx" ] && return 0
    done < <(git -C "$ROOT/milosvasic.ru" ls-files | grep -v '^_site/')
    return 1
}

if wants vd; then
    start_static vd "$ROOT/vasic.digital" "${QA_VD_DEFAULT_PORT:-8401}"
fi

if wants mv; then
    if [ "$REBUILD" -eq 1 ] && mv_site_stale; then
        log "mv: _site is older than its source — rebuilding in a container ..."
        ensure_bin "$SITE_BUILD" site-build
        "$SITE_BUILD" -workload jekyll > "$STATE_DIR/mv-build.log" 2>&1
        rc=$?
        [ "$rc" -eq 0 ] || { warn "mv: site-build rc=$rc; see $STATE_DIR/mv-build.log"; [ "$rc" -eq 2 ] && exit 2; FAILED=1; }
        # a rebuilt tree is served by the same process — python reads per request
    fi
    start_static mv "$ROOT/milosvasic.ru/_site" "${QA_MV_DEFAULT_PORT:-8084}"
fi

# ---- stacks with their own lifecycle scripts --------------------------------
json_str() {    # $1 file, $2 key -> string value (empty if absent)
    sed -n "s/.*\"$2\": *\"\\([^\"]*\\)\".*/\\1/p" "$1" 2>/dev/null | head -1
}
json_num() {    # $1 file, $2 key -> numeric value (empty if absent)
    sed -n "s/.*\"$2\": *\\([0-9][0-9]*\\).*/\\1/p" "$1" 2>/dev/null | head -1
}
url_port() {    # $1 http://host:port[/...] -> port
    printf '%s' "$1" | sed -n 's#^[a-z]*://[^/]*:\([0-9][0-9]*\).*#\1#p'
}
listener_comm() {   # $1 port -> process name owning the TCP listener on it
    ss -ltnpH "sport = :$1" 2>/dev/null | sed -n 's/.*users:(("\([^"]*\)".*/\1/p' | head -1
}
wait_healthy() {    # $1 state file, $2 seconds -> 0 once the published address answers
    local i addr
    for i in $(seq 1 "$2"); do
        addr="$(json_str "$1" http)"
        [ -n "$addr" ] && answers "$addr/api/health" && return 0
        sleep 1
    done
    return 1
}

# The workshop's state file lives where ITS OWN _common.sh says (it moves to
# run-<slug>/ under WORKSHOP_PROJECT_NAME) — asked, never re-derived here.
ws_state_file() {
    bash -c 'source "$1/workshop/scripts/_common.sh" >/dev/null 2>&1; printf "%s" "$STATE_FILE"' _ "$ROOT"
}
# A workshop is adopted only when its published address answers AND the
# listener on that port is a workshop-server process — never anything that
# happens to answer 200 behind a stale state file.
ws_adoptable() {    # $1 state file -> prints address when adoptable
    local addr port
    addr="$(json_str "$1" http)"; [ -n "$addr" ] || return 1
    port="$(url_port "$addr")"; [ -n "$port" ] || return 1
    answers "$addr/api/health" || return 1
    [ "$(listener_comm "$port")" = "workshop-server" ] || return 1
    printf '%s' "$addr"
}

if wants workshop; then
    ws_state="$(ws_state_file)"
    [ -n "$ws_state" ] || undetermined "workshop: could not resolve its state file from workshop/scripts/_common.sh"
    if ws_addr="$(ws_adoptable "$ws_state")"; then
        log "workshop: already running on $ws_addr — reused"
        URL[workshop]="$ws_addr/"
    else
        port="$(discover "$PREFIX-workshop" "${QA_WORKSHOP_DEFAULT_PORT:-8087}")" || exit 2
        ws_out="$(bash "$ROOT/workshop/scripts/start.sh" --port "$port" 2>&1)"; rc=$?
        printf '%s\n' "$ws_out"
        if [ "$rc" -eq 2 ]; then undetermined "workshop start.sh could not determine the stack state"; fi
        # start.sh is idempotent: rc 0 also means "it was ALREADY up". Only a
        # run that actually started the stack may claim it for --stop.
        if [ "$rc" -eq 0 ] && ! printf '%s' "$ws_out" | grep -q 'already running'; then
            : > "$STATE_DIR/workshop.started"
        fi
        # Check the address the server PUBLISHED, not the one we asked for: an
        # existing container keeps the port baked in at creation.
        if [ "$rc" -eq 0 ] && wait_healthy "$ws_state" 60 && ws_addr="$(ws_adoptable "$ws_state")"; then
            case "$ws_addr" in *":$port") : ;; *) warn "workshop: asked for port $port but the stack is serving on $ws_addr (an existing container keeps its port)" ;; esac
            URL[workshop]="$ws_addr/"
        else
            warn "workshop: start rc=$rc, and no workshop-server answers at '$(json_str "$ws_state" http)'"; FAILED=1
        fi
    fi
fi

# ai_interviewing: adopted only when the state file's pid is alive, is the aicur
# binary, owns the HTTP listener, AND HTTPS came up (the server treats an HTTPS
# bind failure as NON-fatal and records tls_error — a half-up server is a
# failure on the reuse path exactly as on the start path).
ai_state="$AI_HOME/run/server.json"
ai_check() {    # prints "OK <addr> <https>" | "HALF <addr> <tls_error>" | "NO"
    local pid addr port https tlserr
    pid="$(json_num "$ai_state" pid)"; addr="$(json_str "$ai_state" http)"
    [ -n "$pid" ] && [ -n "$addr" ] || { echo NO; return; }
    tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q -- "/bin/aicur " || { echo NO; return; }
    port="$(url_port "$addr")"
    [ -n "$port" ] && [ "$(listener_pid_any "$port")" = "$pid" ] || { echo NO; return; }
    answers "$addr/api/health" || { echo NO; return; }
    https="$(json_str "$ai_state" https)"; tlserr="$(json_str "$ai_state" tls_error)"
    if [ -n "$https" ] && [ -z "$tlserr" ]; then echo "OK $addr $https"; else echo "HALF $addr ${tlserr:-no https listener published}"; fi
}
listener_pid_any() {    # $1 port -> pid owning a TCP listener on that port (any address)
    ss -ltnpH "sport = :$1" 2>/dev/null | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' | head -1
}
ai_report() {   # $1 = output of ai_check
    set -- $1
    case "$1" in
        OK)   URL[ai]="$2/   (https: $3)" ;;
        HALF) shift 2; warn "ai: HTTP is up but HTTPS is not: $*"; FAILED=1 ;;
        *)    return 1 ;;
    esac
}

if wants ai; then
    verdict="$(ai_check)"
    if [ "${verdict%% *}" != NO ]; then
        log "ai: found a running instance on $(echo "$verdict" | cut -d' ' -f2) — checking it"
        ai_report "$verdict"
    else
        before_pid="$(cat "$AI_HOME/run/server.pid" 2>/dev/null)"
        kill -0 "${before_pid:-0}" 2>/dev/null || before_pid=""
        http_port="$(discover "$PREFIX-ai-http" "${QA_AI_HTTP_DEFAULT_PORT:-8099}")" || exit 2
        # HTTPS + HTTP/3 bind ONE port on TCP and UDP, so the UDP side must be free too.
        https_port="$(discover "$PREFIX-ai-https" "${QA_AI_HTTPS_DEFAULT_PORT:-8443}" -udp)" || exit 2
        # -port-fallback 0: bind EXACTLY the discovered ports or fail — an
        # in-binary hop would leave the registry naming a port nobody is on.
        ai_out="$(AICUR_HTTP="$BIND:$http_port" AICUR_HTTPS="$BIND:$https_port" AICUR_PORT_FALLBACK=0 \
            bash "$AI_HOME/scripts/start.sh" 2>&1)"; rc=$?
        printf '%s\n' "$ai_out"
        after_pid="$(cat "$AI_HOME/run/server.pid" 2>/dev/null)"
        # Ownership only for a NEW process this run started; start.sh is
        # idempotent and returns 0 for an instance somebody else started.
        if [ "$rc" -eq 0 ] && [ -n "$after_pid" ] && [ "$after_pid" != "$before_pid" ] \
           && ! printf '%s' "$ai_out" | grep -q 'already running'; then
            : > "$STATE_DIR/ai.started"
        fi
        # An instance started elsewhere may still be ingesting (state file is
        # written only after ingest) — wait for it rather than misjudging it.
        [ "$rc" -eq 0 ] && wait_healthy "$ai_state" "${AICUR_HEALTH_TIMEOUT:-120}" >/dev/null
        verdict="$(ai_check)"
        if [ "$rc" -eq 0 ] && ai_report "$verdict"; then
            case "$(echo "$verdict" | cut -d' ' -f2)" in *":$http_port") : ;; *) warn "ai: asked for port $http_port but the server is on $(echo "$verdict" | cut -d' ' -f2) (an instance not started by this run)" ;; esac
        else
            warn "ai: start rc=$rc, and no aicur process owning its published address answers"; FAILED=1
        fi
    fi
fi

printf '\n%-10s %s\n' SERVICE URL
for svc in vd mv workshop ai; do
    wants "$svc" || continue
    printf '%-10s %s\n' "$svc" "${URL[$svc]:-DOWN}"
done
exit "$FAILED"
