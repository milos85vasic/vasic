#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Resilient Lumen indexing.
#
# WHY THIS EXISTS
# ---------------
# On 2026-08-26 this project's Lumen index was found to contain 758 stale
# duplicate vectors spanning 695 distinct texts across 55 files. Root cause was
# ollama running library=Vulkan on an Intel iGPU: a large embedding batch causes
# a GPU fence timeout, and the result buffer is read anyway. The GPU path has
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
#
# Exit 0 = indexed · 1 = gave up after MAX_ROUNDS · 2 = bad usage
#      3 = refused (GPU/Vulkan backend) · 4 = backend not safe to index with
#      5 = a prerequisite is missing (lumen or python3 not runnable)
#
# EVERYTHING IS DERIVED FROM THE ENVIRONMENT, and every derivation has an
# override for when detection is wrong:
#
#   LUMEN_EMBED_MODEL    embedding model (default: lumen's config.yaml, then the
#                        model this project's existing index was built with,
#                        then the model the backend is already running, then
#                        the documented fallback below)
#   LUMEN_BACKEND        ollama | lmstudio
#   OLLAMA_HOST          ollama base URL   (scheme optional: host:port is fine)
#   LM_STUDIO_HOST       LM Studio base URL
#   LUMEN_CONFIG         lumen config.yaml (default $XDG_CONFIG_HOME/lumen/config.yaml)
#   LUMEN_STORE          index store dir   (default $XDG_DATA_HOME/lumen)
#   LUMEN_BIN            path to the lumen binary
#   LUMEN_SERVICE        service-manager unit name for the backend (default ollama)
#   LUMEN_PROBE_TEXTS    batch-probe size  (default 32)
#   LUMEN_PROBE_TIMEOUT  seconds for a single-vector probe (default 120)
#   LUMEN_BATCH_TIMEOUT  seconds for the batch probe        (default 300)
#   MAX_ROUNDS           retry rounds      (default 40)
#   LUMEN_REINDEX_LOG    log file          (default <project>/.lumen-reindex.log)
# ------------------------------------------------------------------------------
set -uo pipefail

# Print the header block above, so --help can never drift out of sync with it
# the way a hardcoded `sed -n '2,30p'` line range does the moment anyone edits.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; }

PROJ="${1:-$(pwd)}"; [[ "$PROJ" == --* ]] && PROJ="$(pwd)"
FORCE=0; ALLOW_GPU=0
for a in "$@"; do
    case "$a" in
        --force)     FORCE=1 ;;
        --allow-gpu) ALLOW_GPU=1 ;;
        --help|-h)   usage; exit 0 ;;
        -*)          # A typo like `--forse` used to be ignored, silently giving
                     # an incremental run when a full rebuild was intended.
                     echo "lumen-reindex: unknown option '$a'" >&2
                     echo "usage: $0 [project-path] [--force] [--allow-gpu]" >&2
                     exit 2 ;;
    esac
done

command -v python3 >/dev/null 2>&1 || {
    echo "lumen-reindex: python3 is required for the vector probes" >&2; exit 5; }

STORE="${LUMEN_STORE:-${XDG_DATA_HOME:-$HOME/.local/share}/lumen}"
CONFIG="${LUMEN_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/lumen/config.yaml}"
SERVICE="${LUMEN_SERVICE:-ollama}"
MAX_ROUNDS="${MAX_ROUNDS:-40}"
export PATH="$HOME/.local/bin:$PATH"

# ── resolve backend / host / model from the environment, not from literals ────
# Precedence mirrors lumen's own internal/config/service.go so that this script
# probes the SAME endpoint and model lumen will actually index with.
# `settings` prints four lines: backend, host, model, source-of-model.
settings=$(STORE="$STORE" CONFIG="$CONFIG" PROJ="$PROJ" python3 - <<'PY'
import os, re, sys, glob, sqlite3, json

def read_config_servers(path):
    out = {}
    try:
        text = open(path, "r", encoding="utf-8", errors="replace").read()
    except Exception:
        return out
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

def http_json(url, timeout=5):
    import urllib.request
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return None

cfg     = read_config_servers(os.environ["CONFIG"])
backend = (os.environ.get("LUMEN_BACKEND") or cfg.get("backend") or "ollama").lower()
if backend == "lmstudio":
    host = normalise_url(os.environ.get("LM_STUDIO_HOST") or cfg.get("host") or "http://localhost:1234", 1234)
    fallback = "nomic-ai/nomic-embed-code-GGUF"
else:
    host = normalise_url(os.environ.get("OLLAMA_HOST") or cfg.get("host") or "http://localhost:11434", 11434)
    fallback = "ordis/jina-embeddings-v2-base-code"

model, src = os.environ.get("LUMEN_EMBED_MODEL", ""), "LUMEN_EMBED_MODEL"
if not model and cfg.get("model"):
    model, src = cfg["model"], "config.yaml"

# The index this project already has is the next-best authority: indexing with a
# different name silently starts a SECOND index instead of updating this one.
if not model:
    proj = os.path.realpath(os.environ["PROJ"])
    for d in sorted(glob.glob(os.path.join(os.environ["STORE"], "*", "index.db"))):
        try:
            c = sqlite3.connect("file:%s?mode=ro" % d, uri=True)
            rows = dict(c.execute("SELECT key, value FROM project_meta").fetchall())
            c.close()
        except Exception:
            continue
        if rows.get("project_path") and os.path.realpath(rows["project_path"]) == proj \
           and rows.get("embedding_model"):
            model, src = rows["embedding_model"], "existing index"
            break

# Then whatever the backend is already serving, if that is unambiguous.
if not model and backend != "lmstudio":
    d = http_json(host + "/api/ps")
    running = [m.get("model") or m.get("name", "") for m in ((d or {}).get("models") or [])]
    if len(running) == 1:
        model, src = running[0], "backend /api/ps"
    else:
        d = http_json(host + "/api/tags")
        avail = [m.get("model") or m.get("name", "") for m in ((d or {}).get("models") or [])]
        if len(avail) == 1:
            model, src = avail[0], "backend /api/tags"
if not model:
    model, src = fallback, "documented fallback"

print(backend); print(host); print(model); print(src)
PY
) || { echo "lumen-reindex: could not resolve backend settings" >&2; exit 5; }

BACKEND=$(printf '%s\n' "$settings" | sed -n 1p)
HOST=$(printf '%s\n' "$settings" | sed -n 2p)
MODEL=$(printf '%s\n' "$settings" | sed -n 3p)
MODEL_SRC=$(printf '%s\n' "$settings" | sed -n 4p)
[[ -n "$BACKEND" && -n "$HOST" && -n "$MODEL" ]] || {
    echo "lumen-reindex: backend/host/model resolution returned nothing" >&2; exit 5; }

# A log under an unwritable project dir used to swallow every message silently,
# because `set -uo pipefail` without -e ignores a failed mkdir.
LOG="${LUMEN_REINDEX_LOG:-$PROJ/.lumen-reindex.log}"
if ! mkdir -p "$(dirname "$LOG")" 2>/dev/null || ! : >>"$LOG" 2>/dev/null; then
    LOG="${TMPDIR:-/tmp}/lumen-reindex.$$.log"
    echo "lumen-reindex: log target not writable, using $LOG" >&2
fi

# tee fails when the log disappears mid-run; never let that become the function's
# (and therefore the caller's) exit status.
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOG" || printf '%s\n' "$*"; return 0; }

# ── probes ───────────────────────────────────────────────────────────────────
# Failure mode 4 is invisible per-vector, so the batch probe sends DISTINCT
# texts and requires DISTINCT vectors back. Both probes speak whichever API the
# resolved backend uses, and both go over urllib so a missing curl cannot make a
# healthy backend look broken.
probe() {   # probe <n-texts> <timeout> ; prints "OK n/m" | "DEGENERATE n/m" | "UNREACHABLE ..." | "MALFORMED ..."
    N="$1" TIMEOUT="$2" MODEL="$MODEL" HOST="$HOST" BACKEND="$BACKEND" python3 - <<'PY'
import json, os, sys, urllib.request, urllib.error

n       = int(os.environ["N"])
timeout = float(os.environ["TIMEOUT"])
model   = os.environ["MODEL"]
host    = os.environ["HOST"]
backend = os.environ["BACKEND"]

texts = [("def f_%d(x):\n    return x+%d\n" % (i, i)) * 12 for i in range(n)]
if backend == "lmstudio":
    url, payload, pick = host + "/v1/embeddings", {"model": model, "input": texts}, \
        lambda d: [e["embedding"] for e in d["data"]]
else:
    url, payload, pick = host + "/api/embed", {"model": model, "input": texts}, \
        lambda d: d["embeddings"]

req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                             headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = r.read().decode("utf-8", "replace")
except urllib.error.HTTPError as e:
    detail = ""
    try:
        detail = e.read().decode("utf-8", "replace")[:200]
    except Exception:
        pass
    print("MALFORMED HTTP %s %s" % (e.code, detail.replace("\n", " "))); sys.exit()
except Exception as e:
    print("UNREACHABLE %s (%s)" % (url, e)); sys.exit()

if "NaN" in body:
    print("MALFORMED NaN in response"); sys.exit()
try:
    vecs = pick(json.loads(body))
except Exception as e:
    print("MALFORMED %s" % e); sys.exit()
u = len({tuple(v) for v in vecs})
print("%s %d/%d distinct" % ("OK" if u == len(vecs) == n else "DEGENERATE", u, len(vecs)))
PY
}

embed_ok()  { case "$(probe 1 "${LUMEN_PROBE_TIMEOUT:-120}")" in OK*) return 0 ;; *) return 1 ;; esac; }
batch_ok()  { case "$(probe "${LUMEN_PROBE_TEXTS:-32}" "${LUMEN_BATCH_TIMEOUT:-300}")" in OK*) return 0 ;; *) return 1 ;; esac; }

# ── backend library detection, without assuming systemd or a local backend ───
# `library=` is logged ONCE at service start. A fixed tail misses it on a busy
# host, which made this return UNKNOWN and let the Vulkan refusal silently NOT
# fire - the exact failure the refusal exists to prevent. Scan from the service
# start instead, matching ollama-vulkan-remediation.sh.
host_is_local() {
    local hp="${HOST#*://}"; hp="${hp%%/*}"     # strip scheme and any path
    local h="${hp%:*}"                          # strip :port
    h="${h#[}"; h="${h%]}"                      # strip IPv6 brackets
    case "$h" in
        localhost|127.0.0.1|::1|0.0.0.0|"$(uname -n)") return 0 ;;
        *) return 1 ;;
    esac
}

backend_library() {
    # A journal on THIS host says nothing about a backend running on another.
    host_is_local || { echo ""; return 0; }
    if command -v journalctl >/dev/null 2>&1; then
        local since=""
        if command -v systemctl >/dev/null 2>&1; then
            since=$(timeout 10 systemctl show "$SERVICE" -p ActiveEnterTimestamp --value 2>/dev/null)
        fi
        if [[ -n "$since" ]]; then
            timeout 20 journalctl -u "$SERVICE" --no-pager --since "$since" 2>/dev/null \
                | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
            return 0
        fi
        timeout 20 journalctl -u "$SERVICE" --no-pager -n 4000 2>/dev/null \
            | grep -oE 'library=[a-zA-Z]+' | tail -1 | cut -d= -f2
        return 0
    fi
    # No journal (macOS, containers, non-systemd): ollama's own server log.
    local f
    for f in "$HOME/.ollama/logs/server.log" "${TMPDIR:-/tmp}/ollama.log"; do
        [[ -r "$f" ]] || continue
        grep -oE 'library=[a-zA-Z]+' "$f" 2>/dev/null | tail -1 | cut -d= -f2
        return 0
    done
    echo ""
}

# Unload over HTTP rather than via the `ollama` CLI: the CLI always talks to the
# local daemon, which is the wrong machine when HOST is remote.
reset_runner() {
    log "unloading the model to clear a wedged runner"
    MODEL="$MODEL" HOST="$HOST" BACKEND="$BACKEND" python3 - <<'PY' >/dev/null 2>&1 || true
import json, os, urllib.request
if os.environ["BACKEND"] != "lmstudio":
    req = urllib.request.Request(
        os.environ["HOST"] + "/api/embed",
        data=json.dumps({"model": os.environ["MODEL"], "input": "", "keep_alive": 0}).encode(),
        headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=30).read()
    except Exception:
        pass
PY
    sleep 5
    embed_ok
}

log "=== lumen-reindex: $PROJ (force=$FORCE) ==="
log "backend=$BACKEND host=$HOST model=$MODEL (model from: $MODEL_SRC)"

# Fail fast instead of burning MAX_ROUNDS x 30s discovering this the hard way.
if [[ -n "${LUMEN_BIN:-}" ]]; then
    [[ -x "$LUMEN_BIN" ]] || { log "LUMEN_BIN is set but not executable: $LUMEN_BIN"; exit 5; }
    LUMEN=("$LUMEN_BIN")
elif command -v lumen >/dev/null 2>&1; then
    LUMEN=(lumen)
else
    log "the 'lumen' binary is not on PATH and LUMEN_BIN is unset - nothing to run"
    exit 5
fi

lib=$(backend_library)
# Lowercase via tr, not ${lib,,}: the latter is a syntax error on bash 3.2,
# which is still /bin/bash on macOS, and a syntax error fails the whole file.
lib_lc=$(printf '%s' "$lib" | tr '[:upper:]' '[:lower:]')
if [[ "$lib_lc" == "vulkan" ]]; then
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
elif host_is_local; then
    log "backend library UNKNOWN (no readable service log) - continuing"
else
    log "backend is remote ($HOST); its library cannot be read from this host - continuing"
fi

p=$(probe "${LUMEN_PROBE_TEXTS:-32}" "${LUMEN_BATCH_TIMEOUT:-300}")
if [[ "$p" != OK* ]]; then
    log "batch probe FAILED: $p - attempting a reset"
    case "$p" in
        UNREACHABLE*) log "the backend is not answering at all; nothing to reset."
                      log "Check that $BACKEND is running and reachable at $HOST."
                      exit 4 ;;
    esac
    reset_runner || true
    p=$(probe "${LUMEN_PROBE_TEXTS:-32}" "${LUMEN_BATCH_TIMEOUT:-300}")
    if [[ "$p" != OK* ]]; then
        log "batch probe still failing ($p). The backend is not safe to index with."
        exit 4
    fi
fi
log "batch probe OK: ${LUMEN_PROBE_TEXTS:-32} distinct texts -> distinct vectors ($p)"

args=("$PROJ"); [[ $FORCE -eq 1 ]] && args=(-f "$PROJ")
for round in $(seq 1 "$MAX_ROUNDS"); do
    embed_ok || { log "round $round: backend unhealthy, resetting"; reset_runner || { sleep 60; continue; }; }

    out=$(LUMEN_EMBED_MODEL="$MODEL" "${LUMEN[@]}" index "${args[@]}" 2>&1); rc=$?
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
