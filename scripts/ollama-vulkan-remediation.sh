#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Take the GPU out of ollama's embedding path.
#
# THE DEFECT (measured on this host, 2026-08-26/27)
# -------------------------------------------------
# ollama running library=Vulkan on an Intel iGPU silently corrupts embeddings.
# A large batch causes a GPU fence timeout; the result buffer is read anyway.
# Four failure modes, worst last:
#   1. HTTP 500 {"error":"...unsupported value: NaN"}
#   2. HTTP 200 with all-zero vectors
#   3. the runner wedges - every later request returns NaN until unloaded
#   4. HTTP 200 with a REPEATED STALE vector: well-formed, unit-norm, and
#      invisible to NaN/Inf/zero/L2 checks. This one corrupted 758 vectors
#      across 55 files before anyone noticed.
#
# Upstream is aware and unfixed: llama.cpp #18969, #26044; ollama #13086, #15248.
# Upgrading ollama does NOT fix it.
#
# WHAT DOES NOT WORK (tested here, both are no-ops):
#   OLLAMA_VULKAN=false        OLLAMA_LLM_LIBRARY=cpu
#
# WHY NOT JUST USE A CPU-PINNED MODEL COPY?
# Because Lumen keys its index by model NAME (project_meta.embedding_model), so
# switching LUMEN_EMBED_MODEL starts a SECOND index from zero and orphans the
# existing one. Disabling the GPU daemon-wide keeps the model name AND the index.
# The cost, stated plainly: this disables the GPU for ALL ollama work, not just
# embeddings.
#
#   ./scripts/ollama-vulkan-remediation.sh --check     # read-only diagnosis
#   ./scripts/ollama-vulkan-remediation.sh --apply     # needs sudo + restart
#   ./scripts/ollama-vulkan-remediation.sh --verify    # prove it worked
#   ./scripts/ollama-vulkan-remediation.sh --rollback  # undo, needs sudo
#
# Exit 0 = GPU is out of the path · 1 = the corrupting state is present
#      2 = could not determine (never reported as either of the above)
#
# NOTHING IS ASSUMED ABOUT THE HOST. The GPU vendor, the kernel driver, the
# kernel fault signature, the service manager, the unit's EnvironmentFile and
# the env knob that actually hides the GPU are all DETECTED. A host with no GPU
# at all reports that cleanly and exits 0. Every derivation has an override:
#
#   OLLAMA_ENV_FILE      unit EnvironmentFile (default: asked of the service
#                        manager, then /etc/sysconfig/ollama, /etc/default/ollama)
#   OLLAMA_SERVICE       unit name                    (default ollama)
#   OLLAMA_GPU_FLAG      the KEY=VALUE that hides the GPU
#                        (default: derived from the detected backend library and
#                         GPU vendor - Vulkan/CUDA/ROCm each need a different one)
#   OLLAMA_GPU_DRIVER    kernel driver name           (default: from /sys/class/drm)
#   OLLAMA_GPU_VENDOR    intel | amd | nvidia | none  (default: from PCI vendor id)
#   OLLAMA_FAULT_REGEX   kernel fault signature       (default: per driver)
#   LUMEN_EMBED_MODEL    model to probe with          (default: as lumen resolves it)
#   LUMEN_BACKEND        ollama | lmstudio
#   OLLAMA_HOST          base URL (scheme optional: host:port is fine)
#   LM_STUDIO_HOST       LM Studio base URL
#   LUMEN_CONFIG         lumen config.yaml
#   LUMEN_PROBE_TEXTS    batch-probe size             (default 32)
# ------------------------------------------------------------------------------
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
bad()  { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Print the header block above, so --help can never drift out of sync with it
# the way a hardcoded `sed -n '2,34p'` line range does the moment anyone edits.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

OS="$(uname -s)"
SERVICE="${OLLAMA_SERVICE:-ollama}"
CONFIG="${LUMEN_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/lumen/config.yaml}"

command -v python3 >/dev/null 2>&1 || {
    bad "python3 is required for the aggregate-distinctness probe"; exit 2; }

# ── service manager: detected, never assumed ────────────────────────────────
detect_service_manager() {
    if command -v systemctl >/dev/null 2>&1 && [[ "$(ps -p 1 -o comm= 2>/dev/null)" == systemd ]]; then
        echo systemd
    elif [[ "$OS" == Darwin ]] && command -v launchctl >/dev/null 2>&1; then
        echo launchd
    elif command -v rc-service >/dev/null 2>&1; then
        echo openrc
    else
        echo none
    fi
}
SVCMGR="$(detect_service_manager)"

service_started() {
    [[ "$SVCMGR" == systemd ]] || return 0
    timeout 10 systemctl show "$SERVICE" -p ActiveEnterTimestamp --value 2>/dev/null
}

# ── the unit's EnvironmentFile: asked of systemd, not guessed per distro ────
# /etc/sysconfig/ollama is Red-Hat/ALT shaped; Debian and Arch put it elsewhere,
# and a drop-in may override both. systemd already knows the answer.
detect_env_file() {
    if [[ -n "${OLLAMA_ENV_FILE:-}" ]]; then echo "$OLLAMA_ENV_FILE"; return 0; fi
    if [[ "$SVCMGR" == systemd ]]; then
        local ef
        ef=$(timeout 10 systemctl show "$SERVICE" -p EnvironmentFiles --value 2>/dev/null \
             | head -1 | sed 's/ (ignore_errors=[a-z]*)$//')
        if [[ -n "$ef" ]]; then echo "$ef"; return 0; fi
    fi
    local f
    for f in /etc/sysconfig/"$SERVICE" /etc/default/"$SERVICE" /etc/conf.d/"$SERVICE"; do
        [[ -e "$f" ]] && { echo "$f"; return 0; }
    done
    # Nothing exists yet: name the one the detected distro layout expects.
    if [[ -d /etc/sysconfig ]]; then echo /etc/sysconfig/"$SERVICE"
    elif [[ -d /etc/default ]]; then echo /etc/default/"$SERVICE"
    else echo ""; fi
}
ENVFILE="$(detect_env_file)"

# ── GPU: vendor and kernel driver read off the running kernel ───────────────
GPU_DRIVER="${OLLAMA_GPU_DRIVER:-}"
GPU_VENDOR="${OLLAMA_GPU_VENDOR:-}"
GPU_DESC=""
detect_gpu() {
    [[ -n "$GPU_DRIVER" && -n "$GPU_VENDOR" ]] && { GPU_DESC="${GPU_DESC:-pinned by env}"; return 0; }
    local d drv pciid vid
    for d in /sys/class/drm/card[0-9]*; do
        [[ -r "$d/device/uevent" ]] || continue
        drv=$(sed -n 's/^DRIVER=//p'  "$d/device/uevent" 2>/dev/null | head -1)
        pciid=$(sed -n 's/^PCI_ID=//p' "$d/device/uevent" 2>/dev/null | head -1)
        [[ -n "$drv" ]] || continue
        GPU_DRIVER="${GPU_DRIVER:-$drv}"
        vid=$(printf '%s' "${pciid%%:*}" | tr '[:upper:]' '[:lower:]')
        case "$vid" in
            8086) GPU_VENDOR="${GPU_VENDOR:-intel}"  ;;
            1002|1022) GPU_VENDOR="${GPU_VENDOR:-amd}"    ;;
            10de) GPU_VENDOR="${GPU_VENDOR:-nvidia}" ;;
            *)    GPU_VENDOR="${GPU_VENDOR:-$vid}"   ;;
        esac
        GPU_DESC="$d (PCI $pciid)"
        return 0
    done
    if command -v lspci >/dev/null 2>&1; then
        GPU_DESC=$(lspci 2>/dev/null | grep -iE 'vga|3d controller|display controller' | head -1)
        if [[ -n "$GPU_DESC" ]]; then
            case "$(printf '%s' "$GPU_DESC" | tr '[:upper:]' '[:lower:]')" in
                *intel*)  GPU_VENDOR="${GPU_VENDOR:-intel}"  ;;
                *amd*|*ati*|*radeon*) GPU_VENDOR="${GPU_VENDOR:-amd}" ;;
                *nvidia*) GPU_VENDOR="${GPU_VENDOR:-nvidia}" ;;
            esac
            return 0
        fi
    fi
    if [[ "$OS" == Darwin ]] && command -v system_profiler >/dev/null 2>&1; then
        GPU_DESC=$(timeout 20 system_profiler SPDisplaysDataType 2>/dev/null \
                   | sed -n 's/^ *Chipset Model: *//p' | head -1)
        [[ -n "$GPU_DESC" ]] && { GPU_VENDOR="${GPU_VENDOR:-apple}"; GPU_DRIVER="${GPU_DRIVER:-metal}"; return 0; }
    fi
    GPU_VENDOR="${GPU_VENDOR:-none}"
    return 0
}
detect_gpu

# A fault signature is driver-specific: grepping i915 wording on an AMD box
# silently reports "0 faults" no matter how badly the GPU is misbehaving.
fault_regex() {
    [[ -n "${OLLAMA_FAULT_REGEX:-}" ]] && { printf '%s' "$OLLAMA_FAULT_REGEX"; return 0; }
    case "$GPU_DRIVER" in
        i915|xe)         printf '%s' 'fence expiration|GPU HANG' ;;
        amdgpu|radeon)   printf '%s' 'amdgpu.*(ring .*timeout|GPU reset|IB test failed)|drm.*ring .*timeout' ;;
        nvidia*|nouveau) printf '%s' 'NVRM: Xid|nouveau .*fault|Xid [0-9]+' ;;
        *)               printf '%s' 'fence expiration|GPU HANG|GPU reset|ring .*timeout|NVRM: Xid' ;;
    esac
}

# The knob that hides the GPU differs per acceleration backend. Writing the
# Vulkan one on a CUDA host is a no-op that LOOKS applied.
gpu_flag_for() {   # gpu_flag_for <library>
    [[ -n "${OLLAMA_GPU_FLAG:-}" ]] && { printf '%s' "$OLLAMA_GPU_FLAG"; return 0; }
    local lib; lib=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
    case "$lib" in
        cuda)        printf '%s' 'CUDA_VISIBLE_DEVICES=-1' ;;
        rocm|hip)    printf '%s' 'HIP_VISIBLE_DEVICES=-1'  ;;
        vulkan)      printf '%s' 'GGML_VK_VISIBLE_DEVICES=-1' ;;
        *)  case "$GPU_VENDOR" in
                nvidia) printf '%s' 'CUDA_VISIBLE_DEVICES=-1' ;;
                amd)    printf '%s' 'HIP_VISIBLE_DEVICES=-1'  ;;
                *)      printf '%s' 'GGML_VK_VISIBLE_DEVICES=-1' ;;
            esac ;;
    esac
}

# ── backend / host / model, resolved the way lumen resolves them ────────────
settings=$(CONFIG="$CONFIG" python3 - <<'PY'
import os, re
def read_config_servers(path):
    out = {}
    try: text = open(path, "r", encoding="utf-8", errors="replace").read()
    except Exception: return out
    block = re.split(r'^\s*servers\s*:', text, maxsplit=1, flags=re.M)
    if len(block) < 2: return out
    first = re.split(r'^\s*-\s', block[1], flags=re.M)
    if len(first) < 2: return out
    for line in first[1].splitlines():
        if re.match(r'^\s*-\s', line): break
        m = re.match(r'^\s*(backend|host|model)\s*:\s*(.+?)\s*$', line)
        if m: out[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return out
def normalise_url(u, port):
    if not u: return u
    u = u.strip()
    if not re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*://', u):
        if u.startswith(":"): u = "localhost" + u
        u = "http://" + u
    if not re.search(r':\d+(/|$)', u): u = u.rstrip("/") + ":" + str(port)
    return u.rstrip("/")
cfg = read_config_servers(os.environ["CONFIG"])
backend = (os.environ.get("LUMEN_BACKEND") or cfg.get("backend") or "ollama").lower()
if backend == "lmstudio":
    host = normalise_url(os.environ.get("LM_STUDIO_HOST") or cfg.get("host") or "http://localhost:1234", 1234)
    model = os.environ.get("LUMEN_EMBED_MODEL") or cfg.get("model") or "nomic-ai/nomic-embed-code-GGUF"
else:
    host = normalise_url(os.environ.get("OLLAMA_HOST") or cfg.get("host") or "http://localhost:11434", 11434)
    model = os.environ.get("LUMEN_EMBED_MODEL") or cfg.get("model") or "ordis/jina-embeddings-v2-base-code"
print(backend); print(host); print(model)
PY
) || { bad "could not resolve backend settings"; exit 2; }
BACKEND=$(printf '%s\n' "$settings" | sed -n 1p)
HOST=$(printf '%s\n' "$settings" | sed -n 2p)
MODEL=$(printf '%s\n' "$settings" | sed -n 3p)

host_is_local() {
    local hp="${HOST#*://}"; hp="${hp%%/*}"
    local h="${hp%:*}"; h="${h#[}"; h="${h%]}"
    case "$h" in localhost|127.0.0.1|::1|0.0.0.0|"$(uname -n)") return 0 ;; *) return 1 ;; esac
}

# `library=` is logged once at service start, so scan from THAT moment rather
# than a fixed tail - a busy log otherwise pushes it out and reports UNKNOWN.
# Falls back to ollama's own log file where there is no journal at all.
backend_library() {
    host_is_local || { echo ""; return 0; }
    if command -v journalctl >/dev/null 2>&1; then
        local since; since=$(service_started)
        if [[ -n "$since" ]]; then
            journalctl -u "$SERVICE" --no-pager --since "$since" 2>/dev/null \
                | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
            return 0
        fi
        journalctl -u "$SERVICE" --no-pager -n 4000 2>/dev/null \
            | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
        return 0
    fi
    local f
    for f in "$HOME/.ollama/logs/server.log" "${TMPDIR:-/tmp}/ollama.log"; do
        [[ -r "$f" ]] || continue
        grep -oE 'library=[a-zA-Z]+' "$f" 2>/dev/null | tail -1 | cut -d= -f2
        return 0
    done
    echo ""
}

kernel_faults_since() {   # kernel_faults_since <since|"">  -> count, or "" if unknowable
    host_is_local || { echo ""; return 0; }
    command -v journalctl >/dev/null 2>&1 || { echo ""; return 0; }
    local re; re=$(fault_regex)
    if [[ -n "${1:-}" ]]; then
        journalctl -k --since "$1" --no-pager 2>/dev/null | grep -ciE "$re"
    else
        journalctl -k --since "24 hours ago" --no-pager 2>/dev/null | grep -ciE "$re"
    fi
    return 0
}

# Failure mode 4 is only visible in aggregate: distinct texts MUST yield
# distinct vectors. A per-vector check cannot see it.
batch_probe() {
    N="${LUMEN_PROBE_TEXTS:-32}" MODEL="$MODEL" HOST="$HOST" BACKEND="$BACKEND" python3 - <<'PY'
import json, os, sys, urllib.request, urllib.error
n = int(os.environ["N"]); model = os.environ["MODEL"]
host = os.environ["HOST"]; backend = os.environ["BACKEND"]
texts = [("def f_%d(x):\n    return x+%d\n" % (i, i)) * 12 for i in range(n)]
if backend == "lmstudio":
    url, pick = host + "/v1/embeddings", lambda d: [e["embedding"] for e in d["data"]]
else:
    url, pick = host + "/api/embed", lambda d: d["embeddings"]
req = urllib.request.Request(url, data=json.dumps({"model": model, "input": texts}).encode(),
                             headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=300) as r:
        body = r.read().decode("utf-8", "replace")
except urllib.error.HTTPError as e:
    print("MALFORMED HTTP %s" % e.code); sys.exit()
except Exception as e:
    print("UNREACHABLE %s" % e); sys.exit()
if "NaN" in body:
    print("MALFORMED NaN in response"); sys.exit()
try:
    v = pick(json.loads(body))
except Exception:
    print("MALFORMED"); sys.exit()
u = len({tuple(x) for x in v})
print("OK %d/%d distinct" % (u, len(v)) if u == len(v) == n
      else "DEGENERATE %d/%d distinct" % (u, len(v)))
PY
}

# Returns non-zero when the backend is in the corrupting state. It previously
# always returned 0, so anything automating on `--check` passed silently even
# on library=Vulkan with a degenerate probe. It ALSO used to return 1 for
# "cannot tell", which reports a corrupting backend on a host whose journal is
# merely unreadable; "cannot tell" is now 2, so no caller ever mistakes an
# unknown for a verdict.
do_check() {
    local rc=0 unknown=0
    echo "── host ──────────────────────────────────────────────────"
    info "os=$OS  service-manager=$SVCMGR  service=$SERVICE"
    if [[ "$GPU_VENDOR" == "none" ]]; then
        ok "no GPU detected on this host - there is no GPU path to remediate"
    else
        info "gpu vendor=$GPU_VENDOR driver=${GPU_DRIVER:-unknown} ${GPU_DESC:+($GPU_DESC)}"
    fi

    echo "── ollama embedding backend ──────────────────────────────"
    info "backend=$BACKEND host=$HOST model=$MODEL"
    local lib; lib=$(backend_library)
    local lib_lc; lib_lc=$(printf '%s' "$lib" | tr '[:upper:]' '[:lower:]')
    if [[ -z "$lib" ]]; then
        if host_is_local; then warn "backend library UNKNOWN (no readable service log)"
        else warn "backend is remote; its library cannot be read from this host"; fi
        unknown=1
    elif [[ "$lib_lc" == "cpu" ]]; then
        ok "library=cpu - GPU is out of the inference path"
    else
        bad "library=$lib - THIS IS THE CORRUPTING PATH"; rc=1
    fi

    local FLAG; FLAG=$(gpu_flag_for "$lib")
    if [[ "$GPU_VENDOR" == "none" && -z "$lib" ]]; then
        info "no GPU and no service log: nothing to configure"
    elif [[ -z "$ENVFILE" ]]; then
        warn "no EnvironmentFile mechanism found for $SERVICE on this host"
        unknown=1
    elif [[ -r "$ENVFILE" ]] && grep -qF "$FLAG" "$ENVFILE" 2>/dev/null; then
        ok "$ENVFILE contains $FLAG"
    elif [[ -e "$ENVFILE" ]]; then
        warn "$ENVFILE exists but does not contain $FLAG"
    else
        warn "$ENVFILE does not exist (the unit sources it via EnvironmentFile=-)"
    fi

    # What matters is faults SINCE the current ollama start. A 24h window also
    # counts pre-remediation history and would cry wolf on a fixed host.
    if [[ "$GPU_VENDOR" == "none" ]]; then
        info "no GPU: skipping the kernel fault scan"
    else
        local since n24 nnow
        since=$(service_started)
        n24=$(kernel_faults_since "")
        nnow=$(kernel_faults_since "$since")
        if [[ -z "$n24" && -z "$nnow" ]]; then
            warn "no kernel log available - GPU fault history unknown"
            unknown=1
        elif [[ -n "$since" && -n "$nnow" ]]; then
            if [[ "${nnow:-0}" -eq 0 ]]; then
                ok "0 ${GPU_DRIVER:-gpu} faults since $SERVICE started ($since)"
                [[ "${n24:-0}" -gt 0 ]] && info "(${n24} in the last 24h are pre-remediation history)"
            else
                bad "${nnow} ${GPU_DRIVER:-gpu} fault/hang lines SINCE $SERVICE started"; rc=1
            fi
        else
            [[ "${n24:-0}" -eq 0 ]] && ok "0 ${GPU_DRIVER:-gpu} faults in 24h" \
                                    || { bad "${n24} ${GPU_DRIVER:-gpu} fault lines in 24h"; rc=1; }
        fi
    fi

    info "batch probe (${LUMEN_PROBE_TEXTS:-32} distinct texts must give as many distinct vectors)..."
    local p; p=$(batch_probe)
    case "$p" in
        OK*)          ok "batch probe: $p" ;;
        DEGENERATE*)  bad "batch probe: $p - STALE DUPLICATE VECTORS"; rc=1 ;;
        UNREACHABLE*) warn "backend unreachable at $HOST - cannot probe ($p)"; unknown=1 ;;
        *)            bad "batch probe: $p"; rc=1 ;;
    esac

    # A definite fault outranks an unknown; an unknown outranks "healthy".
    if [[ $rc -eq 0 && $unknown -eq 1 ]]; then
        warn "could not determine the backend's state - reporting neither healthy nor corrupt"
        rc=2
    fi
    return $rc
}

require_root_restart() {
    case "$SVCMGR" in
        systemd) return 0 ;;
        *) bad "this host uses service manager '$SVCMGR'; automatic restart is not implemented"
           info "Set the flag by hand, then restart $SERVICE yourself:"
           info "  $(gpu_flag_for "$(backend_library)")"
           return 1 ;;
    esac
}

do_apply() {
    local FLAG; FLAG=$(gpu_flag_for "$(backend_library)")
    if [[ "$GPU_VENDOR" == "none" ]]; then
        ok "no GPU detected - nothing to remediate"; return 0
    fi
    [[ -n "$ENVFILE" ]] || { bad "no EnvironmentFile found for $SERVICE; set OLLAMA_ENV_FILE"; exit 2; }
    require_root_restart || exit 2
    if [[ -r "$ENVFILE" ]] && grep -qF "$FLAG" "$ENVFILE" 2>/dev/null; then
        ok "already applied - $ENVFILE contains $FLAG"
    else
        info "appending $FLAG to $ENVFILE (requires sudo)"
        echo "$FLAG" | sudo tee -a "$ENVFILE" >/dev/null || { bad "could not write $ENVFILE"; exit 1; }
        ok "written"
    fi
    info "restarting $SERVICE (safe: lumen's index is incremental and resumes)"
    sudo systemctl restart "$SERVICE" || { bad "restart failed"; exit 1; }
    sleep 6
    do_verify
}

do_rollback() {
    local FLAG; FLAG=$(gpu_flag_for "$(backend_library)")
    [[ -n "$ENVFILE" ]] || { warn "no EnvironmentFile found for $SERVICE - nothing to roll back"; return 0; }
    if [[ ! -r "$ENVFILE" ]]; then warn "$ENVFILE not present - nothing to roll back"; return 0; fi
    require_root_restart || exit 2
    info "removing $FLAG from $ENVFILE (requires sudo)"
    sudo sed -i "\|^${FLAG}$|d" "$ENVFILE" || { bad "could not edit $ENVFILE"; exit 1; }
    sudo systemctl restart "$SERVICE" || { bad "restart failed"; exit 1; }
    sleep 6
    warn "the GPU is ENABLED again - the corrupting path is back. Re-check:"
    do_check
}

do_verify() {
    echo "── verification ──────────────────────────────────────────"
    local lib; lib=$(backend_library)
    local lib_lc; lib_lc=$(printf '%s' "$lib" | tr '[:upper:]' '[:lower:]')
    if [[ "$GPU_VENDOR" == "none" ]]; then
        ok "no GPU present; the inference path cannot be a GPU path"
    elif [[ "$lib_lc" == "cpu" ]]; then
        ok "library=cpu"
    elif [[ -z "$lib" ]]; then
        warn "library unknown - cannot verify"; return 2
    else
        bad "library=$lib (expected cpu)"; return 1
    fi
    local p; p=$(batch_probe)
    case "$p" in
        OK*)          ok "batch probe: $p" ;;
        UNREACHABLE*) warn "backend unreachable at $HOST - cannot verify ($p)"; return 2 ;;
        *)            bad "batch probe: $p"; return 1 ;;
    esac
    info "Next: rebuild any index written while the GPU path was active:"
    info "  ./scripts/lumen-reindex.sh <project> --force"
}

case "${1:---check}" in
    --check)    do_check ;;
    --apply)    do_apply ;;
    --verify)   do_verify ;;
    --rollback) do_rollback ;;
    --help|-h)  usage ;;
    *)          bad "unknown option: $1"; exit 2 ;;
esac
