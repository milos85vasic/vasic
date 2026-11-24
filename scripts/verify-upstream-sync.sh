#!/usr/bin/env bash
# verify-upstream-sync.sh -- §11.4.299 fleet check: does the merged `main` of this repository and of EVERY own-org
# submodule (fleet DERIVED from .gitmodules, recursively, never a roster) sit on EVERY declared upstream (every push URL of
# every remote + every enabled upstreams/*.sh recipe), read back with `git ls-remote`?  Thin wrapper over the constitution's
# instrument submodules/constitution/scripts/sync/verify_upstream_parity.sh; own organisations come from
# config/upstream-parity-own-orgs.txt and declared mirror exemptions from config/upstream-parity-exemptions.tsv (both DATA).
#
# USAGE  verify-upstream-sync.sh [--root DIR] [--quiet] [--prove-failure]
#   --root DIR       project root to check (default: this checkout); a missing directory is exit 2
#   --prove-failure  paired §1.1 proof: runs the constitution's mutation test (66 expectations, M1..M27 + L1..L5; its RESULT line prints the live count) and a fleet-level fixture in which
#                    a submodule's second upstream is behind (the wrapper MUST return 1) next to a green control (0).
# EXIT   0 every upstream of every own repository CURRENT/AHEAD/EXEMPT · 1 at least one BEHIND/DIVERGED/DIFFERS/NO-BRANCH ·
#        2 could not determine (unreachable upstream, uninitialised own submodule, missing instrument); 2 is never a pass.
# SAFETY read-only (ls-remote, rev-parse, merge-base). The fix for a 1 is scripts: submodules/constitution/scripts/sync/push_all_upstreams.sh.
# Needs the constitution pin to carry §11.4.299 (scripts/sync/*); an older pin is exit 2, not a pass.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); REPO=$(cd "$HERE/.." && pwd)
ROOT="$REPO"; Q=(); PROVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --quiet) Q=(--quiet); shift ;;
    --prove-failure) PROVE=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "verify-upstream-sync: unknown argument: $1" >&2; exit 2 ;;
  esac
done
V="$REPO/submodules/constitution/scripts/sync/verify_upstream_parity.sh"
T="$REPO/submodules/constitution/scripts/gates/cm_upstream_parity_mutation_test.sh"
[ -x "$V" ] || { echo "verify-upstream-sync: constitution pin lacks scripts/sync/verify_upstream_parity.sh (§11.4.299) -- exit 2" >&2; exit 2; }
if [ "$PROVE" = 1 ]; then
  [ -x "$T" ] || { echo "paired mutation test missing -- exit 2" >&2; exit 2; }
  out=$(bash "$T" 2>&1); rc=$?; printf '%s\n' "$out" | tail -1
  [ "$rc" = 0 ] || { echo "PROOF FAIL: constitution mutation test rc=$rc"; exit 1; }
  W=$(mktemp -d) || exit 2; trap 'rm -rf "${W:?}"' EXIT
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always
  git init -q -b main "$W/sub"; echo 1 > "$W/sub/f"; git -C "$W/sub" add f; git -C "$W/sub" commit -qm 1; S1=$(git -C "$W/sub" rev-parse HEAD)
  echo 2 >> "$W/sub/f"; git -C "$W/sub" commit -qam 2
  for r in a b; do git init -q --bare -b main "$W/sub.$r.git"; git -C "$W/sub" remote add $r "$W/sub.$r.git"; git -C "$W/sub" push -q $r main; done
  git init -q -b main "$W/root"; echo r > "$W/root/f"; git -C "$W/root" add f; git -C "$W/root" commit -qm r
  git -C "$W/root" submodule add -q "$W/sub.a.git" sub; git -C "$W/root" commit -qm sub
  git -C "$W/root/sub" remote add b "$W/sub.b.git"; git init -q --bare -b main "$W/root.a.git"; git -C "$W/root" remote add a "$W/root.a.git"; git -C "$W/root" push -q a main
  git -C "$W/root/sub" checkout -q main 2>/dev/null; git -C "$W/root/sub" fetch -q origin; git -C "$W/root/sub" merge -q --ff-only origin/main 2>/dev/null
  bash "$V" --fleet "$W/root" --quiet >/dev/null; c=$?; [ "$c" = 0 ] || { echo "PROOF FAIL: green fleet control returned $c"; exit 1; }
  # make upstream b BEHIND without any force push or ref rewind (§11.4.113): advance the submodule by one commit that only
  # upstream a (origin) receives, and fast-forward the superproject's checkout to it; b stays at the older commit.
  echo 3 >> "$W/sub/f"; git -C "$W/sub" commit -qam 3; git -C "$W/sub" push -q a main
  git -C "$W/root/sub" fetch -q origin; git -C "$W/root/sub" merge -q --ff-only origin/main
  bash "$V" --fleet "$W/root" --quiet >/dev/null; m=$?; [ "$m" = 1 ] || { echo "PROOF FAIL: fleet with a behind submodule upstream returned $m, want 1"; exit 1; }
  echo "PROOF OK: green fleet control 0, behind submodule upstream 1, constitution mutation test green"; exit 0
fi
[ -d "$ROOT" ] || { echo "verify-upstream-sync: root not found: $ROOT -- exit 2" >&2; exit 2; }
ORGS=(); while read -r o; do case "$o" in ''|'#'*) ;; *) ORGS+=(--own-org "$o");; esac; done < "$REPO/config/upstream-parity-own-orgs.txt"
EX=(); [ -s "$REPO/config/upstream-parity-exemptions.tsv" ] && EX=(--exempt "$REPO/config/upstream-parity-exemptions.tsv")
exec bash "$V" --fleet "$ROOT" "${ORGS[@]}" "${EX[@]}" "${Q[@]}"
