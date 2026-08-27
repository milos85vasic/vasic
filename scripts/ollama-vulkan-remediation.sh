#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Take the GPU out of ollama's embedding path.
#
# THE DEFECT (measured on this host, 2026-08-26/27)
# -------------------------------------------------
# ollama running library=Vulkan on an Intel iGPU silently corrupts embeddings.
# A large batch causes an i915 fence timeout; the result buffer is read anyway.
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
# existing one. Disabling Vulkan daemon-wide keeps the model name AND the index.
# The cost, stated plainly: this disables Vulkan for ALL ollama work, not just
# embeddings.
#
#   ./scripts/ollama-vulkan-remediation.sh --check     # read-only diagnosis
#   ./scripts/ollama-vulkan-remediation.sh --apply     # needs sudo + restart
#   ./scripts/ollama-vulkan-remediation.sh --verify    # prove it worked
#   ./scripts/ollama-vulkan-remediation.sh --rollback  # undo, needs sudo
# ------------------------------------------------------------------------------
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
bad()  { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

ENVFILE=/etc/sysconfig/ollama
FLAG='GGML_VK_VISIBLE_DEVICES=-1'
MODEL="${LUMEN_EMBED_MODEL:-ordis/jina-embeddings-v2-base-code}"
HOST="${OLLAMA_HOST:-http://localhost:11434}"

service_started() { systemctl show ollama -p ActiveEnterTimestamp --value 2>/dev/null; }

# `library=` is logged once at service start, so scan from THAT moment rather
# than a fixed tail - a busy log otherwise pushes it out and reports UNKNOWN.
backend_library() {
    local since; since=$(service_started)
    if [[ -n "$since" ]]; then
        journalctl -u ollama --no-pager --since "$since" 2>/dev/null \
            | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
    else
        journalctl -u ollama --no-pager -n 2000 2>/dev/null \
            | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
    fi
}

# Failure mode 4 is only visible in aggregate: distinct texts MUST yield
# distinct vectors. A per-vector check cannot see it.
batch_probe() {
    local payload r
    payload=$(MODEL="$MODEL" python3 - <<'PY'
import json, os
texts = [("def f_%d(x):\n    return x+%d\n" % (i, i)) * 12 for i in range(32)]
print(json.dumps({"model": os.environ["MODEL"], "input": texts}))
PY
    ) || return 1
    r=$(curl -s --max-time 300 "$HOST/api/embed" -H 'Content-Type: application/json' \
        --data "$payload" 2>/dev/null) || return 1
    printf '%s' "$r" | python3 -c '
import sys, json
try:
    e = json.load(sys.stdin)["embeddings"]
except Exception:
    print("MALFORMED"); sys.exit()
u = len({tuple(v) for v in e})
print("OK %d/%d distinct" % (u, len(e)) if u == len(e) == 32 else "DEGENERATE %d/%d distinct" % (u, len(e)))'
}

# Returns non-zero when the backend is in the corrupting state. It previously
# always returned 0, so anything automating on `--check` passed silently even
# on library=Vulkan with a degenerate probe.
do_check() {
    local rc=0
    echo "── ollama embedding backend ──────────────────────────────"
    local lib; lib=$(backend_library)
    if [[ -z "$lib" ]]; then warn "backend library UNKNOWN (journal unreadable)"; rc=1
    elif [[ "$lib" == "cpu" ]]; then ok "library=cpu - GPU is out of the inference path"
    else bad "library=$lib - THIS IS THE CORRUPTING PATH"; rc=1; fi

    if [[ -r "$ENVFILE" ]] && grep -qF "$FLAG" "$ENVFILE" 2>/dev/null; then
        ok "$ENVFILE contains $FLAG"
    elif [[ -e "$ENVFILE" ]]; then warn "$ENVFILE exists but does not contain $FLAG"
    else warn "$ENVFILE does not exist (the unit sources it via EnvironmentFile=-)"; fi

    # What matters is faults SINCE the current ollama start. A 24h window also
    # counts pre-remediation history and would cry wolf on a fixed host.
    local since n24 nnow
    since=$(service_started)
    n24=$(journalctl -k --since "24 hours ago" --no-pager 2>/dev/null | grep -ciE 'fence expiration|GPU HANG')
    if [[ -n "$since" ]]; then
        nnow=$(journalctl -k --since "$since" --no-pager 2>/dev/null | grep -ciE 'fence expiration|GPU HANG')
        if [[ "${nnow:-0}" -eq 0 ]]; then
            ok "0 i915 faults since ollama started ($since)"
            [[ "${n24:-0}" -gt 0 ]] && info "(${n24} in the last 24h are pre-remediation history)"
        else
            bad "${nnow} i915 fence timeout/GPU-hang lines SINCE ollama started"
        fi
    else
        [[ "${n24:-0}" -eq 0 ]] && ok "0 i915 faults in 24h" || bad "${n24} i915 fault lines in 24h"
    fi

    if curl -sf --max-time 5 "$HOST/api/tags" >/dev/null 2>&1; then
        info "batch probe (32 distinct texts must give 32 distinct vectors)..."
        local p; p=$(batch_probe)
        case "$p" in
            OK*)         ok "batch probe: $p" ;;
            DEGENERATE*) bad "batch probe: $p - STALE DUPLICATE VECTORS"; rc=1 ;;
            *)           bad "batch probe: $p"; rc=1 ;;
        esac
    else
        warn "backend unreachable at $HOST - cannot probe"; rc=1
    fi
    return $rc
}

do_apply() {
    if [[ -r "$ENVFILE" ]] && grep -qF "$FLAG" "$ENVFILE" 2>/dev/null; then
        ok "already applied - $ENVFILE contains $FLAG"
    else
        info "appending $FLAG to $ENVFILE (requires sudo)"
        echo "$FLAG" | sudo tee -a "$ENVFILE" >/dev/null || { bad "could not write $ENVFILE"; exit 1; }
        ok "written"
    fi
    info "restarting ollama (safe: lumen's index is incremental and resumes)"
    sudo systemctl restart ollama || { bad "restart failed"; exit 1; }
    sleep 6
    do_verify
}

do_rollback() {
    if [[ ! -r "$ENVFILE" ]]; then warn "$ENVFILE not present - nothing to roll back"; return 0; fi
    info "removing $FLAG from $ENVFILE (requires sudo)"
    sudo sed -i "\|^${FLAG}$|d" "$ENVFILE" || { bad "could not edit $ENVFILE"; exit 1; }
    sudo systemctl restart ollama || { bad "restart failed"; exit 1; }
    sleep 6
    warn "Vulkan is ENABLED again - the corrupting path is back. Re-check:"
    do_check
}

do_verify() {
    echo "── verification ──────────────────────────────────────────"
    local lib; lib=$(backend_library)
    [[ "$lib" == "cpu" ]] && ok "library=cpu" || bad "library=${lib:-unknown} (expected cpu)"
    local p; p=$(batch_probe)
    case "$p" in
        OK*) ok "batch probe: $p" ;;
        *)   bad "batch probe: $p"; return 1 ;;
    esac
    info "Next: rebuild any index written while Vulkan was active:"
    info "  ./scripts/lumen-reindex.sh <project> --force"
}

case "${1:---check}" in
    --check)    do_check ;;
    --apply)    do_apply ;;
    --verify)   do_verify ;;
    --rollback) do_rollback ;;
    --help|-h)  sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)          bad "unknown option: $1"; exit 2 ;;
esac
