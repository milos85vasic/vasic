#!/usr/bin/env bash
# Persistent per-language auto-deploy watcher. Each cycle runs the idempotent
# deploy-langs.sh (regenerate EN + every COMPLETE language's pages + PDFs, then
# commit/push ONLY if something changed). Self-terminates once the translation
# batch is no longer running AND a final cycle has published everything.
set -uo pipefail
# WHY THIS SCRIPT READS AN EXIT CODE, AND WHY IT DID NOT.
#
# Both `bash _tools/deploy-langs.sh` call sites below discarded `$?` entirely,
# and this script sets -u and pipefail but NOT -e. So every verdict the deploy
# produced was thrown away, and the watcher looped up to 240 times -- 80 hours
# at a 20-minute cadence -- against a deploy that might have been failing every
# single cycle, reporting nothing.
#
# That was survivable while deploy-langs.sh always exited 0. It stopped being
# survivable when it gained real codes: 5 a build RAN AND FAILED, 4 a publish
# failed, 2 a step COULD NOT RUN (absent toolchain), 0 clean. A watcher that
# discards those is a watcher that cannot tell a working deploy from a broken
# one -- which is the only question it exists to answer.
#
# The contract here mirrors the one it consumes, and keeps the same precedence:
# a confirmed failure outranks a could-not-determine, which outranks clean.
#   0  every cycle clean
#   2  at least one cycle could not run, none failed        (never a pass)
#   5  at least one cycle RAN AND FAILED
# A single fatal does not stop the watcher -- a transient may clear -- but
# CONSECUTIVE_FATAL_LIMIT of them in a row does, because a deploy failing for
# the same reason 3 times will not fix itself in 237 more.
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
DEPLOY="${WATCH_DEPLOY_CMD:-_tools/deploy-langs.sh}"   # overridable so the paired proof can drive it with DATA
CONSECUTIVE_FATAL_LIMIT="${WATCH_FATAL_LIMIT:-3}"
CYCLES="${WATCH_CYCLES:-240}"
SLEEP_BETWEEN="${WATCH_SLEEP:-1200}"   # 20 min (a language completes ~hourly at MAXPAR=1)
SLEEP_FINAL="${WATCH_FINAL_SLEEP:-30}"

# VACUITY REFUSAL. With CYCLES=0 the loop body never runs, `i` is never set, and
# under `set -u` the summary line below would crash -- a hard error where the
# honest answer is "this watcher observed nothing". Zero cycles can never be a
# clean verdict: it is a could-not-determine, and it says so.
if [ "$CYCLES" -lt 1 ] 2>/dev/null; then
  echo "[watch] UNDETERMINED: CYCLES=$CYCLES — the watcher ran no cycle and therefore observed nothing. Not a pass." >> "$LOG"
  exit 2
fi

worst=0          # 0 clean < 2 could-not-determine < 5 confirmed failure
fatal_run=0      # consecutive cycles that RAN AND FAILED
aborted=0

# Fold one cycle's exit code into the watcher's verdict. Precedence is explicit:
# a confirmed failure can never be masked by a later clean cycle, and a
# could-not-determine can never be recorded as a pass.
record_rc() {
  local rc="$1" cycle="$2"
  case "$rc" in
    0) echo "[watch] cycle $cycle -> 0 clean" >> "$LOG"; fatal_run=0 ;;
    2) echo "[watch] cycle $cycle -> 2 COULD NOT RUN (a step's toolchain was absent; this is NOT a pass)" >> "$LOG"
       [ "$worst" -lt 2 ] && worst=2; fatal_run=0 ;;
    *) echo "[watch] cycle $cycle -> $rc CONFIRMED FAILURE (deploy ran and failed)" >> "$LOG"
       worst=5; fatal_run=$(( fatal_run + 1 )) ;;
  esac
}

for i in $(seq 1 "$CYCLES"); do
  echo "===== [watch] cycle $i =====" >> "$LOG"
  bash "$DEPLOY" >> "$LOG" 2>&1
  record_rc "$?" "$i"

  if [ "$fatal_run" -ge "$CONSECUTIVE_FATAL_LIMIT" ]; then
    echo "[watch] ABORT: $fatal_run consecutive failing cycles. A deploy failing the same way $fatal_run times will not fix itself in $(( CYCLES - i )) more." >> "$LOG"
    aborted=1
    break
  fi

  if ! pgrep -f 'run-batch.sh' >/dev/null 2>&1; then
    echo "[watch] translation batch no longer running — final deploy cycle then exit" >> "$LOG"
    sleep "$SLEEP_FINAL"
    bash "$DEPLOY" >> "$LOG" 2>&1
    record_rc "$?" "final"
    echo "[watch] DONE (batch finished)" >> "$LOG"
    break
  fi
  sleep "$SLEEP_BETWEEN"
done

echo "[watch] watcher exited after $i cycle(s); aborted=$aborted; verdict=$worst" >> "$LOG"
exit "$worst"
