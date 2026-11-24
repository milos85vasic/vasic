#!/usr/bin/env bash
# run-matrix.sh -- REAL (no mocks) --runner matrix over every launcher in the umbrella + submodules.
# Per launcher: help rc0 | --runner=bogus rc2 | --runner bogus rc2 | env bogus rc2 | absent runner rc2
# | accept (--runner=podman, --runner podman, CONTAINERS_RUNNER=podman) rc0 on a SAFE invocation.
# Safe = never touches foreign containers: the live workshop platform (127.0.0.1:8087) is never addressed;
# workshop lifecycle runs use an isolated project/port (see run-live.sh).
# Exit: 0 all cells OK, 1 some cell failed. Output: matrix.tsv + raw/*.txt in $OUT.
set -u
U="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
OUT="$(cd "${1:-$(dirname -- "${BASH_SOURCE[0]}")}" && pwd -P)"; mkdir -p "$OUT/raw"
TSV="$OUT/matrix.tsv"; : > "$TSV"
ABSENT=docker; command -v docker >/dev/null 2>&1 && { echo "docker present: absent-runner column would be invalid" >&2; ABSENT=nerdctl; command -v nerdctl >/dev/null && { echo "no absent runner"; exit 2; }; }
printf 'launcher\tflag_eq\tflag_sp\tenv\thelp_rc0\tbogus_rc2\tbogus_sp_rc2\tenvbogus_rc2\tabsent_rc2\tverdict\n' > "$TSV"
run() { # run <rawname> <env-assign-or-:> cmd...  -> sets RC, writes raw
  local raw="$OUT/raw/$1.txt"; local e="$2"; shift 2
  { echo "\$ (cd $PWD) ${e} $*"; env ${e/:/} timeout 60 "$@" </dev/null; echo "rc=$?"; } >"$raw" 2>&1
  RC=$(tail -1 "$raw" | sed 's/rc=//')
}
cell() { [ "$1" = "$2" ] && echo OK || echo "FAIL($1)"; }
# launcher <name> <dir> <cmd...> -- <safe-extra-args...>
launcher() {
  local name="$1" dir="$2"; shift 2; local cmd=() extra=()
  while [ "$1" != "--" ]; do cmd+=("$1"); shift; done; shift; extra=("$@")
  local rx=("${extra[@]}"); [ -n "${RX:-}" ] && read -r -a rx <<<"$RX"; local arc="${ARC:-0}"
  local k; k="$(printf '%s' "${name%% (*}" | tr -c 'A-Za-z0-9._\n' '_')"; cd "$dir" || return
  run "$k.help" : "${cmd[@]}" --help;                      local h; h=$(cell "$RC" 0)
  local want=2 b bs eb ab
  if [ -n "${NATIVE:-}" ]; then
    # container-free launcher: --runner is accepted and IGNORED ("no containers used"); only the shape is checked.
    run "$k.bogus" : "${cmd[@]}" --runner=bogus "${rx[@]}"; grep -q 'no containers used' "$OUT/raw/$k.bogus.txt" && b="OK(ignored)" || b="FAIL(not-acknowledged)"
    run "$k.bogus_sp" : "${cmd[@]}" --runner bogus "${rx[@]}"; grep -q 'no containers used' "$OUT/raw/$k.bogus_sp.txt" && bs="OK(ignored)" || bs="FAIL(not-acknowledged)"
    run "$k.envbogus" CONTAINERS_RUNNER=bogus "${cmd[@]}" "${rx[@]}"; eb="n/a-native"
    run "$k.absent" : "${cmd[@]}" --runner=; ab=$(cell "$RC" 2)
  else
  run "$k.bogus" : "${cmd[@]}" --runner=bogus "${rx[@]}"; b=$(cell "$RC" 2)
  run "$k.bogus_sp" : "${cmd[@]}" --runner bogus "${rx[@]}"; bs=$(cell "$RC" 2)
  run "$k.envbogus" CONTAINERS_RUNNER=bogus "${cmd[@]}" "${rx[@]}"; eb=$(cell "$RC" 2)
  run "$k.absent" : "${cmd[@]}" --runner="$ABSENT" "${rx[@]}"; ab=$(cell "$RC" 2)
  fi
  local fe fs fv
  if [ -n "${NOACCEPT:-}" ]; then fe="n/a-live"; fs="n/a-live"; fv="n/a-live"; else
  run "$k.eq" : "${cmd[@]}" --runner=podman "${extra[@]}";  fe=$(cell "$RC" "$arc")
  run "$k.sp" : "${cmd[@]}" --runner podman "${extra[@]}";  fs=$(cell "$RC" "$arc")
  run "$k.env" CONTAINERS_RUNNER=podman "${cmd[@]}" "${extra[@]}"; fv=$(cell "$RC" "$arc"); fi
  local v=PASS; for x in $h $b $bs $eb $ab $fe $fs $fv; do case "$x" in FAIL*) v=GAP;; esac; done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$fe" "$fs" "$fv" "$h" "$b" "$bs" "$eb" "$ab" "$v" >> "$TSV"
}
cd "$U"
RX="--only workshop" launcher "umbrella scripts/qa-up.sh (accept: --stop --only vd; refusal: --only workshop)" "$U" bash scripts/qa-up.sh -- --stop --only vd
launcher "milosvasic.ru/start.sh --dry-run" "$U/milosvasic.ru" bash ./start.sh -- --dry-run
ARC=1 launcher "workshop/scripts/status.sh (isolated project: STOPPED rc1 is the answer)" "$U/workshop" env WORKSHOP_PROJECT_NAME=zzz-runner-matrix WORKSHOP_HTTP_PORT=18087 bash scripts/status.sh --
launcher "workshop/scripts/restart.sh --dry-run" "$U/workshop" env WORKSHOP_PROJECT_NAME=zzz-runner-matrix WORKSHOP_HTTP_PORT=18087 bash scripts/restart.sh -- --dry-run
launcher "ai_interviewing/status.sh" "$U/ai_interviewing/platform/scripts" bash ./status.sh --
launcher "ai_interviewing/stop.sh" "$U/ai_interviewing/platform/scripts" bash ./stop.sh --
NATIVE=1 ARC=1 launcher "umbrella _tools/od/start-daemon.sh (native Electron: flag ignored; no Open Design app on Linux so rc1 after the flag is accepted)" "${OD_ROOT:-$U}" bash _tools/od/start-daemon.sh --
ISO="WORKSHOP_PROJECT_NAME=zzz-runner-matrix WORKSHOP_HTTP_PORT=18087"
NOACCEPT=1 launcher "workshop/scripts/start.sh (accept: see live.*)" "$U/workshop" env $ISO bash scripts/start.sh --
launcher "workshop/scripts/stop.sh (isolated project)" "$U/workshop" env $ISO bash scripts/stop.sh --
NOACCEPT=1 launcher "ai_interviewing/start.sh (accept: see live.*)" "$U/ai_interviewing/platform/scripts" bash ./start.sh --
NOACCEPT=1 launcher "ai_interviewing/restart.sh (accept: see live.*)" "$U/ai_interviewing/platform/scripts" bash ./restart.sh --
NOACCEPT=1 launcher "job_seeker/gates/live_h3.sh (accept: see live.*)" "$U/job_seeker" bash gates/live_h3.sh --
launcher "job_seeker/bin/jsstack probe" "$U/job_seeker" ./bin/jsstack -- probe
NATIVE=1 NOACCEPT= launcher "workshop/scripts/run-isolated.sh (native server; VALIDATE_ONLY)" "$U/workshop" env WORKSHOP_ISOLATED_VALIDATE_ONLY=1 bash scripts/run-isolated.sh --
NOACCEPT=1 launcher "umbrella _tools/hawkscan/run.sh (accept would run a scan: see verify-runner-flag)" "$U" bash _tools/hawkscan/run.sh --
NOACCEPT=1 launcher "umbrella _tools/deploy-langs.sh (accept: --dry-run is heavy: see verify-runner-flag --prove-args)" "$U" bash _tools/deploy-langs.sh --
NOACCEPT=1 launcher "umbrella _tools/helixtranslate-local.sh (accept needs the image: see verify-runner-flag)" "$U" bash _tools/helixtranslate-local.sh --
( cd "$U/submodules/containers" && go build -o "$OUT/boot.bin" ./cmd/boot ) 2>/dev/null
NOACCEPT=1 launcher "submodules/containers/cmd/boot (accept: boots services, not run)" "$U" "$OUT/boot.bin" --
rm -f "$OUT/boot.bin"
fails=$(grep -c "GAP" "$TSV")
echo "launchers with a gap: $fails"; column -t -s$'\t' "$TSV"
[ "$fails" = 0 ]
