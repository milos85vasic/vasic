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

# vasic_runner_strip "$@" -- PURE BASH, needs neither the module nor Go. Removes
# --runner NAME / --runner=NAME from the args into VASIC_ARGS and sets
# VASIC_RUNNER_ASKED=1 when a runner was asked for (flag or $CONTAINERS_RUNNER).
# It validates SHAPE only (a value must be present); choosing and refusing a
# runner is vasic_runner_maybe's job. For launchers that only need a runner on
# SOME paths (qa-up: static servers and --stop need none), so the decision to
# load/select can be deferred until a container is actually about to be used.
# rc 2 = --runner without a value.
vasic_runner_strip() {
  VASIC_ARGS=(); VASIC_RUNNER_ASKED=0
  local names=() n
  [ -n "${CONTAINERS_RUNNER:-}" ] && VASIC_RUNNER_ASKED=1
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --) VASIC_ARGS+=("$@"); break ;;
      --runner)
        if [ "$#" -lt 2 ] || [ "${2#-}" != "$2" ]; then printf 'runner: --runner needs a value\n' >&2; return 2; fi
        VASIC_RUNNER_ASKED=1; names+=("$2"); shift 2 ;;
      --runner=*)
        [ -n "${1#--runner=}" ] || { printf 'runner: --runner= has an empty value\n' >&2; return 2; }
        VASIC_RUNNER_ASKED=1; names+=("${1#--runner=}"); shift ;;
      *) VASIC_ARGS+=("$1"); shift ;;
    esac
  done
  # A FORCED name is checked at parse time even when no container will be used (a typo must not be
  # silently accepted). The env var is not checked here: it is inherited, and its refusal stays deferred.
  for n in ${names[@]+"${names[@]}"}; do vasic_runner_check_name "$n" || return 2; done
  return 0
}

# vasic_runner_check_name NAME -- pure bash. SHAPE (^[a-z0-9][a-z0-9-]*$, or auto) is always checked.
# MEMBERSHIP is checked against the module's supported list ONLY when its `runner` binary is already
# available (CONTAINERS_RUNNER_BIN or the module's user cache); this never builds anything and never needs
# Go, so --stop and static servers keep working on a host with no toolchain. Without a binary a
# well-formed unknown name passes here and is refused later, when a container is actually needed.
vasic_runner_check_name() {
  local name="$1" bin list
  [ "$name" = auto ] && return 0
  case "$name" in
    ""|-*|*[!a-z0-9-]*) printf 'runner: invalid runner name %q (allowed: lowercase letters, digits, "-"; or auto)\n' "$name" >&2; return 2 ;;
  esac
  bin="${CONTAINERS_RUNNER_BIN:-${XDG_CACHE_HOME:-${HOME:-/nonexistent}/.cache}/containers-runner/runner}"
  [ -x "$bin" ] || return 0
  list="$("$bin" list 2>/dev/null)" || return 0
  [ -n "$list" ] || return 0
  if ! printf '%s\n' "$list" | grep -qx -- "$name"; then
    printf 'runner: unknown container runner %q (supported: %s, auto)\n' "$name" "$(printf '%s' "$list" | paste -sd, - | sed 's/,/, /g')" >&2
    return 2
  fi
}
