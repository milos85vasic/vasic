#!/usr/bin/env bash
# _tools/lib/vasic-runner.sh -- SOURCE me. The umbrella's one entry onto the
# Containers Submodule's forced-runner helper (--runner=NAME), so every launcher
# in this repository honours the same contract and none reimplements it.
#
#   precedence   --runner=NAME | --runner NAME   >   $CONTAINERS_RUNNER   >   default order
#   NAME         podman|docker|nerdctl|cri-o|lxd|kubernetes|auto -- the list is
#                DERIVED from the module (`runner list`), never written here
#   refusals     unknown NAME, or a forced runner that is not installed ->
#                exit 2, no fallback to another runner
#
# Usage in a launcher:
#
#   . "$ROOT/_tools/lib/vasic-runner.sh"
#   vasic_runner_load || exit 2            # rc 2 + message if the module is absent
#   runner_parse_args "$@" || exit 2       # strips --runner out of the args
#   set -- "${RUNNER_REST[@]+"${RUNNER_REST[@]}"}"
#   runner_select || exit 2                # validates + exports CONTAINERS_RUNNER*
#
# The helper is `submodules/containers/scripts/lib/runner.sh`, resolved from THIS
# file's repository root (override: $CONTAINERS_DIR = a module checkout). If the
# submodule is not initialised, or is pinned before the runner selector landed,
# vasic_runner_load returns 2 with the command that fixes it -- it never skips
# the flag silently.
#
# No top-level side effects besides defining functions.

vasic_runner_load() {
  local here root helper
  here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  root="$(cd -- "$here/../.." && pwd -P)"
  : "${CONTAINERS_DIR:=$root/submodules/containers}"
  export CONTAINERS_DIR
  helper="$CONTAINERS_DIR/scripts/lib/runner.sh"
  if [ ! -r "$helper" ]; then
    printf 'runner: COULD NOT DETERMINE -- %s is missing.\n' "$helper" >&2
    printf '  Initialise the Containers Submodule at its pinned commit:\n' >&2
    printf '    git -C %s submodule update --init submodules/containers\n' "$root" >&2
    printf '  (or point CONTAINERS_DIR at a checkout that has scripts/lib/runner.sh)\n' >&2
    return 2
  fi
  # shellcheck disable=SC1090
  . "$helper"
}

# vasic_runner_usage -- the one help paragraph every launcher prints, so the
# supported-runner list always comes from the module.
vasic_runner_usage() {
  if vasic_runner_load 2>/dev/null; then runner_usage
  else printf '  --runner=NAME   force the container runner (list: see submodules/containers/docs/RUNNER_FLAG.md); exit 2 if refused\n'
  fi
}

# vasic_runner_maybe "$@" -- for launchers whose pre-existing behaviour must not
# change when nobody asked for a runner (no flag, no $CONTAINERS_RUNNER): then it
# only copies the args. When a runner WAS asked for, it loads the module helper,
# strips the flag, validates through the module and exports CONTAINERS_RUNNER*.
# Sets the array VASIC_ARGS to the remaining args. rc 2 = refused / cannot tell.
#   vasic_runner_maybe "$@" || exit 2
#   set -- "${VASIC_ARGS[@]+"${VASIC_ARGS[@]}"}"
vasic_runner_maybe() {
  VASIC_ARGS=("$@")
  local a want=0
  [ -n "${CONTAINERS_RUNNER:-}" ] && want=1
  for a in "$@"; do
    case "$a" in --) break ;; --runner|--runner=*) want=1 ;; esac
  done
  [ "$want" = 1 ] || return 0
  vasic_runner_load || return 2
  runner_parse_args "$@" || return 2
  VASIC_ARGS=("${RUNNER_REST[@]+"${RUNNER_REST[@]}"}")
  runner_select || return 2
}
