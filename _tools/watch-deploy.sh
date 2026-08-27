#!/usr/bin/env bash
# Persistent per-language auto-deploy watcher. Each cycle runs the idempotent
# deploy-langs.sh (regenerate EN + every COMPLETE language's pages + PDFs, then
# commit/push ONLY if something changed). Self-terminates once the translation
# batch is no longer running AND a final cycle has published everything.
set -uo pipefail
# ROOT (the repository root) is DERIVED from this script's own location
# (<repo>/_tools/watch-deploy.sh -> "$(dirname)/.."), never hardcoded. The cd was
# a literal absolute path; on any other checkout it failed, and because this
# script sets -u and pipefail but NOT -e the failure was SILENT — the watcher
# then ran for hours in the caller's working directory, writing its log and
# invoking `bash _tools/deploy-langs.sh` against paths that do not exist. Make
# the cd fatal. Set VASIC_ROOT only to deliberately watch a different checkout.
ROOT="${VASIC_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "FATAL: cannot cd to repository root '$ROOT'" >&2; exit 1; }
LOG="_tests/evidence/translate-new/WATCH-DEPLOY.log"
mkdir -p "$(dirname "$LOG")" || { echo "FATAL: cannot create log dir under '$ROOT'" >&2; exit 1; }
: > "$LOG"
echo "[watch] started $(cat /proc/uptime 2>/dev/null || echo)" >> "$LOG"
for i in $(seq 1 240); do
  echo "===== [watch] cycle $i =====" >> "$LOG"
  bash _tools/deploy-langs.sh >> "$LOG" 2>&1
  if ! pgrep -f 'run-batch.sh' >/dev/null 2>&1; then
    echo "[watch] translation batch no longer running — final deploy cycle then exit" >> "$LOG"
    sleep 30
    bash _tools/deploy-langs.sh >> "$LOG" 2>&1
    echo "[watch] DONE (batch finished)" >> "$LOG"
    break
  fi
  sleep 1200   # 20 min between cycles (a language completes ~hourly at MAXPAR=1)
done
echo "[watch] watcher exited after $i cycles" >> "$LOG"
