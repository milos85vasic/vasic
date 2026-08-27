#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Resilient Lumen indexing.
#
# WHY THIS EXISTS
# ---------------
# On 2026-08-26 this project's Lumen index was found to contain 758 stale
# duplicate vectors spanning 695 distinct texts across 55 files. Root cause was
# ollama running library=Vulkan on an Intel iGPU: a large embedding batch causes
# an i915 fence timeout, and the result buffer is read anyway. The GPU path has
# FOUR failure modes, in increasing order of nastiness:
#
#   1. HTTP 500 {"error":"...unsupported value: NaN"}   - loud, easy to see
#   2. HTTP 200 with all-zero vectors                   - silent
#   3. runner wedges: every later request returns NaN   - loud but misattributed
#   4. HTTP 200 with a REPEATED STALE vector            - silent AND well-formed;
#      passes NaN/Inf/zero/L2-norm checks. This is what corrupted the index.
#
# Lumen prints its USAGE TEXT after a failed run, which makes (1) and (3) look
# like CLI misuse rather than a backend fault. That cost hours of misdiagnosis.
#
# The durable fix is scripts/ollama-vulkan-remediation.sh (CPU inference).
# This script is the operational wrapper: it refuses to start on a known-bad
# backend, retries around transient faults, and resumes (Lumen is incremental).
#
#   ./scripts/lumen-reindex.sh [project-path] [--force] [--allow-gpu]
#
# --force      full rebuild (`lumen index -f`). REQUIRED after a corruption
#              event: affected files carry a non-empty hash, so an incremental
#              run treats them as done and skips them forever.
# --allow-gpu  proceed even if the backend is on a GPU/Vulkan path. Off by
#              default precisely because that is what caused the corruption.
# ------------------------------------------------------------------------------
set -uo pipefail

PROJ="${1:-$(pwd)}"; [[ "$PROJ" == --* ]] && PROJ="$(pwd)"
FORCE=0; ALLOW_GPU=0
for a in "$@"; do
    case "$a" in
        --force)     FORCE=1 ;;
        --allow-gpu) ALLOW_GPU=1 ;;
    esac
done

MODEL="${LUMEN_EMBED_MODEL:-ordis/jina-embeddings-v2-base-code}"
HOST="${OLLAMA_HOST:-http://localhost:11434}"
MAX_ROUNDS="${MAX_ROUNDS:-40}"
LOG="${LUMEN_REINDEX_LOG:-$PROJ/.lumen-reindex.log}"
export PATH="$HOME/.local/bin:$PATH"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG"; }

embed_ok() {
    local r
    r=$(curl -s --max-time 120 "$HOST/api/embed" \
        -d "{\"model\":\"$MODEL\",\"input\":\"health check\"}" 2>/dev/null)
    [[ -n "$r" ]] && grep -q '"embeddings"' <<<"$r" && ! grep -q 'NaN' <<<"$r"
}

# Failure mode 4 is invisible per-vector, so probe for it directly: send a batch
# of DISTINCT texts and require DISTINCT vectors back.
batch_ok() {
    local r n
    local payload
    payload=$(MODEL="$MODEL" python3 - <<'PY'
import json, os
texts = [("def f_%d(x):\n    return x+%d\n" % (i, i)) * 12 for i in range(32)]
print(json.dumps({"model": os.environ["MODEL"], "input": texts}))
PY
    ) || return 1
    r=$(curl -s --max-time 300 "$HOST/api/embed" -H 'Content-Type: application/json' \
        --data "$payload" 2>/dev/null) || return 1
    n=$(printf '%s' "$r" | python3 -c '
import sys,json
try:
    e=json.load(sys.stdin)["embeddings"]
    print(len({tuple(v) for v in e}), len(e))
except Exception:
    print(0,0)' 2>/dev/null)
    [[ "$n" == "32 32" ]]
}

backend_library() {
    journalctl -u ollama --no-pager -n 400 2>/dev/null \
        | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
}

reset_runner() {
    log "unloading the model to clear a wedged runner"
    ollama stop "$MODEL" >/dev/null 2>&1
    sleep 5
    embed_ok
}

mkdir -p "$(dirname "$LOG")"
log "=== lumen-reindex: $PROJ (force=$FORCE) ==="

lib=$(backend_library)
if [[ "$lib" == "Vulkan" || "$lib" == "vulkan" ]]; then
    if [[ $ALLOW_GPU -eq 1 ]]; then
        log "WARNING: backend library=$lib - proceeding only because --allow-gpu was given"
    else
        log "REFUSING TO START: ollama reports library=$lib."
        log "That path silently writes stale duplicate vectors. Fix it first:"
        log "  ./scripts/ollama-vulkan-remediation.sh --apply"
        log "Override with --allow-gpu if you accept the risk."
        exit 3
    fi
elif [[ -n "$lib" ]]; then
    log "backend library=$lib"
else
    log "backend library UNKNOWN (journal unreadable) - continuing"
fi

if ! batch_ok; then
    log "batch probe FAILED (duplicate or malformed vectors) - attempting a reset"
    reset_runner || true
    if ! batch_ok; then
        log "batch probe still failing. The backend is not safe to index with."
        exit 4
    fi
fi
log "batch probe OK: 32 distinct texts -> 32 distinct vectors"

args=("$PROJ"); [[ $FORCE -eq 1 ]] && args=(-f "$PROJ")
for round in $(seq 1 "$MAX_ROUNDS"); do
    embed_ok || { log "round $round: backend unhealthy, resetting"; reset_runner || { sleep 60; continue; }; }

    out=$(lumen index "${args[@]}" 2>&1); rc=$?
    summary=$(printf '%s\n' "$out" | grep -E 'Done\.|Error:' | tail -1)
    log "round $round: rc=$rc ${summary:-<no summary line>}"

    if [[ $rc -eq 0 ]]; then
        log "=== INDEX COMPLETE after $round round(s) ==="
        exit 0
    fi
    # A forced rebuild only needs to be forced once; later rounds resume.
    args=("$PROJ")
    if grep -q 'NaN\|embedding servers exhausted' <<<"$out"; then
        reset_runner || sleep 30
    else
        log "round $round: non-embedding failure; backing off 30s"
        sleep 30
    fi
done
log "=== gave up after $MAX_ROUNDS rounds ==="
exit 1
