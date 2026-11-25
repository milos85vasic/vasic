#!/usr/bin/env bash
# verify-issues-sync.sh -- §11.4.300 umbrella wrapper over the constitution's workable-items Issues mirror verifier.
# The engine is NOT copied (§11.4.28): this wrapper only (1) validates the tracked declaration .workable-items-sync.yaml with the
# engine's own strict loader and (2) runs the engine's read-only verifier for the umbrella's own legs. It never writes to a tracker or the DB.
#
# USAGE  verify-issues-sync.sh [--root DIR] [--prove-failure]
#   default          config validity + `verify` of the umbrella legs (GET-only). While no host is in config/forge/issue_sync_proven.tsv
#                    every leg is UNCONFIRMED, so the verdict is 2 (cannot determine) -- by design, 2 is never a pass.
#   --prove-failure  paired §1.1 proof: the constitution's 23-case mutation proof over an in-memory tracker double, plus wrapper
#                    mutations (invalid config must be 2, disabled config must be 0 and state OFF, missing engine must be 2).
# EXIT   0 in sync or mechanism disabled | 1 drift | 2 cannot determine (never a pass)
# Dependencies: bash, python3, PyYAML, the constitution pin carrying §11.4.300 (scripts/issue_sync/). Classification: project wrapper.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); ROOT=$(cd "$HERE/.." && pwd); PROVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --prove-failure) PROVE=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "verify-issues-sync: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -d "$ROOT" ] || { echo "verify-issues-sync: root not a directory: $ROOT" >&2; exit 2; }
ENG="$ROOT/submodules/constitution/scripts"
V="$ENG/verify_issues_sync.sh"
[ -x "$V" ] || [ -f "$V" ] || { echo "verify-issues-sync: constitution pin lacks scripts/verify_issues_sync.sh (§11.4.300) -- exit 2" >&2; exit 2; }
mode_of() { PYTHONPATH="$ENG" python3 -W ignore -m issue_sync.mode "$1" 2>&1; }
if [ "$PROVE" = 1 ]; then
  out=$(bash "$V" --prove-failure 2>&1); rc=$?; printf '%s\n' "$out" | tail -1
  [ "$rc" = 0 ] || { echo "PROOF FAIL: constitution verifier proof rc=$rc"; exit 1; }
  W=$(mktemp -d) || exit 2; trap 'rm -rf "${W:?}"' EXIT
  printf 'enabled: false\nmode: dry-run\n' > "$W/off.yaml"
  [ "$(mode_of "$W/off.yaml")" = "off" ] || { echo "PROOF FAIL: a disabled config is not reported off"; exit 1; }
  printf 'enabled: true\nenabled: true\n' > "$W/dup.yaml"
  m=$(mode_of "$W/dup.yaml"); [ "$m" = "dry-run" ] || [ "$m" = "apply" ] && { echo "PROOF FAIL: duplicate-key config treated as ON ($m)"; exit 1; }
  printf 'enabled: yes\n' > "$W/bool.yaml"
  m=$(mode_of "$W/bool.yaml"); [ "$m" = "dry-run" ] || [ "$m" = "apply" ] && { echo "PROOF FAIL: YAML bare boolean treated as ON ($m)"; exit 1; }
  printf 'enabled: true\nmode: apply\n' > "$W/applynodec.yaml"
  m=$(mode_of "$W/applynodec.yaml"); [ "$m" = "apply" ] && { echo "PROOF FAIL: apply without apply_decision accepted"; exit 1; }
  # control: the tracked umbrella declaration must be ON in dry-run and must carry no apply_decision
  [ "$(mode_of "$ROOT/.workable-items-sync.yaml")" = "dry-run" ] || { echo "PROOF FAIL: control: umbrella declaration is not dry-run"; exit 1; }
  echo "PROVE-FAILURE: PASS (constitution 23 cases + 5 wrapper cases: off, duplicate key, bare boolean, apply without decision, control)"
  exit 0
fi
CFG="$ROOT/.workable-items-sync.yaml"
[ -f "$CFG" ] || { echo "verify-issues-sync: no .workable-items-sync.yaml (mechanism OFF by default)"; exit 0; }
m=$(mode_of "$CFG"); case "$m" in off) echo "verify-issues-sync: mechanism disabled (OFF)"; exit 0 ;; dry-run|apply) ;; *) echo "verify-issues-sync: invalid declaration: $m" >&2; exit 2 ;; esac
exec bash "$V" --config "$CFG" --db "$ROOT/docs/workable_items.db" --owner-repo github.com/milos85vasic/vasic --db-repo github.com/milos85vasic/vasic --target github.com/milos85vasic/vasic
