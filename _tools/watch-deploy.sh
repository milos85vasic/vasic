#!/usr/bin/env bash
# Persistent per-language auto-deploy watcher. Each cycle runs the idempotent
# deploy-langs.sh (regenerate EN + every COMPLETE language's pages + PDFs, then
# commit/push ONLY if something changed). Self-terminates once the translation
# batch is no longer running AND a final cycle has published everything.
set -uo pipefail
cd /Volumes/T7/Projects/vasic
LOG="_tests/evidence/translate-new/WATCH-DEPLOY.log"
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
