#!/usr/bin/env bash
# =============================================================================
# run-batch.sh  — resumable, capped-concurrency orchestrator around the PROVEN
# committed driver translate-content.sh. It does NOT translate or review itself;
# it only decides WHAT to (re)run and records honest per-(lang,doc) status.
#
#   * SOURCE docs: every *.md under _content/products, _content/sites, _content/docs.
#   * TARGET langs: default 14-language site set (override via args or LANGS env).
#   * RESUME: skip a (doc,lang) whose review JSON is already PASS *under the new
#             §11.4.235 standard* (i.e. contains terms_preserved) AND whose output
#             file exists. Otherwise (re)run the driver for that single file.
#   * FAIL loop: on FAIL/ERROR, re-run the driver up to RETRIES extra times, then
#             record the honest final verdict (never fake a PASS).
#   * CONCURRENCY: at most MAXPAR languages in flight; docs within a language run
#             sequentially to respect API rate limits.
#
# Usage:  run-batch.sh [lang ...]
# Env:    MAXPAR (3)  RETRIES (2)  LANGS ("ru sr de ...")
# =============================================================================
set -uo pipefail

# Repo root — NEVER hardcoded. Derived from this script's own location
# (_tools/translate/run-batch.sh -> ../.. == repo root); VASIC_ROOT overrides.
# This script runs with `set -uo pipefail` but NOT -e, so a failed cd would be
# SILENT and every path below would point at nothing: make it explicitly fatal.
REPO="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO" || { echo "FATAL: cannot cd to repository root '$REPO'" >&2; exit 1; }
DRIVER="$REPO/_tools/translate/translate-content.sh"
CONTENT_DIR="$REPO/_content"
EVID_BASE="$REPO/_tests/evidence/translate-new"
MAXPAR="${MAXPAR:-3}"
RETRIES="${RETRIES:-2}"

DEFAULT_LANGS="ru sr de es fr be zh kk hi ja ko ar tr fa"
if [ $# -gt 0 ]; then LANGS="$*"; else LANGS="${LANGS:-$DEFAULT_LANGS}"; fi

# Source docs (sorted, deterministic).
mapfile -t DOCS < <(find "$CONTENT_DIR/products" "$CONTENT_DIR/sites" "$CONTENT_DIR/docs" -type f -name '*.md' | sort)

revjson_path() {  # <lang> <src>
  local lang="$1" src="$2" rel; rel="${src#"$CONTENT_DIR"/}"
  echo "$EVID_BASE/$lang/$(echo "$rel" | tr '/' '_').review.json"
}

is_pass_new() {  # <revjson>  -> 0 if PASS under new standard AND output exists
  local rj="$1"
  [ -f "$rj" ] || return 1
  python3 - "$rj" "$REPO" <<'PY'
import json,sys,os,re
try:
    d=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception:
    sys.exit(1)
ok = d.get("verdict")=="PASS" and ("terms_preserved" in d) and ("naturalness" in d)
tf = d.get("_translated","")
# `_translated` is an ABSOLUTE path from the machine that produced the review.
# Re-anchor its repo-relative tail onto THIS checkout (argv[2]) instead of
# trusting a foreign prefix; the file must still exist, so no PASS is faked.
if tf and not os.path.isfile(tf):
    m=re.search(r"(_content[^/]*/.*)$", tf.replace("\\","/"))
    if m: tf=os.path.join(sys.argv[2], m.group(1))
sys.exit(0 if (ok and tf and os.path.isfile(tf)) else 1)
PY
}

verdict_of() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("verdict","ERROR"))' "$1" 2>/dev/null || echo ERROR; }

process_lang() {
  local lang="$1"
  local evd="$EVID_BASE/$lang"; mkdir -p "$evd"
  local status="$evd/batch-status.tsv"
  printf 'doc\tfinal_verdict\tattempts\n' > "$status"
  local log="$evd/batch.log"; : > "$log"
  local np=0 npass=0 nfail=0 nerr=0
  for src in "${DOCS[@]}"; do
    np=$((np+1))
    local rel="${src#"$CONTENT_DIR"/}"
    local rj; rj="$(revjson_path "$lang" "$src")"
    if is_pass_new "$rj"; then
      echo "[$lang] SKIP (already PASS) $rel" >> "$log"
      printf '%s\tPASS\t0\n' "$rel" >> "$status"; npass=$((npass+1)); continue
    fi
    local attempt=0 verdict=ERROR
    while [ "$attempt" -le "$RETRIES" ]; do
      attempt=$((attempt+1))
      echo "[$lang] RUN attempt $attempt/$((RETRIES+1)) $rel" >> "$log"
      if bash "$DRIVER" "$lang" "$src" >> "$log" 2>&1; then
        verdict=PASS
      else
        verdict="$(verdict_of "$rj")"
      fi
      [ "$verdict" = "PASS" ] && break
      sleep $((5*attempt))
    done
    printf '%s\t%s\t%s\n' "$rel" "$verdict" "$attempt" >> "$status"
    case "$verdict" in
      PASS) npass=$((npass+1));;
      FAIL) nfail=$((nfail+1));;
      *)    nerr=$((nerr+1));;
    esac
  done
  echo "[$lang] DONE  docs=$np PASS=$npass FAIL=$nfail ERROR=$nerr" | tee -a "$log"
  printf '%s\tPASS=%s\tFAIL=%s\tERROR=%s\tTOTAL=%s\n' "$lang" "$npass" "$nfail" "$nerr" "$np" > "$evd/LANG_SUMMARY.txt"
}

echo "run-batch: langs=[$LANGS] docs=${#DOCS[@]} MAXPAR=$MAXPAR RETRIES=$RETRIES"
running=0
for lang in $LANGS; do
  process_lang "$lang" &
  running=$((running+1))
  if [ "$running" -ge "$MAXPAR" ]; then wait -n 2>/dev/null || wait; running=$((running-1)); fi
done
wait
echo "run-batch: ALL LANGUAGES PROCESSED"
