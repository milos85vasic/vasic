#!/usr/bin/env bash
# =============================================================================
# translation-fleet.sh — THE single source of truth for WHICH remote hosts the
# HelixTranslate container fleet runs on, WHICH container runtime each of them
# uses, and WHICH SSH account reaches them.
#
# WHY THIS FILE EXISTS
# --------------------
# Until 2026-09-08 four tracked files each carried the same two developer
# machine names as literals — an mDNS `.local` build host and an mDNS `.local`
# worker host — plus a frozen SSH account name. The names themselves are not
# repeated here: writing them down would re-freeze in a comment exactly what
# was removed from the code, and `_tools/prove-translation-fleet.sh` scans this
# file too. Measured before the change:
#
#   _tools/distribute-helixtranslate.sh          12 x frozen ssh account,
#                                                 3 x `<worker-host>` literal,
#                                                 1 x `<build-host>` default
#   _tools/helixtranslate-container.sh            1 x frozen ssh account,
#                                                 1 x `<worker-host>` comparison,
#                                                 1 x `<build-host>` default
#   _tools/translate-fleet.sh                     1 x `<worker-host>` comparison,
#                                                 1 x two-host default string
#   _tools/containers/cmd/distribute-helixtranslate/main.go
#                                                 2 x host-name defaults
#
# A default that names somebody's machine is not a default, it is a wrong
# answer waiting to be used: on any other checkout the scripts resolved a host
# that does not exist and failed at ssh time with a DNS error rather than a
# configuration error. Both hosts are in fact unreachable from this checkout
# (`getent hosts` fails, `ssh -o BatchMode=yes` returns rc 255), so the frozen
# defaults were never even correct here.
#
# THE CONTRACT
# ------------
#   HT_FLEET            REQUIRED. Space-separated `host[:runtime]` entries, e.g.
#                         HT_FLEET="<build-host>:podman <worker-host>:docker"
#                       No default. Absent => rc 2 (COULD NOT DETERMINE), never
#                       a guess and never a pass.
#   HOSTS               Legacy alias for HT_FLEET, honoured for callers that
#                       predate this file. Runtime suffixes are allowed here too.
#   HT_SSH_USER         SSH account for every fleet host. Defaults to the
#                       INVOKING user (`$USER`), which is derived from the
#                       environment rather than frozen into the tree. Empty and
#                       unresolvable => rc 2.
#   HT_DEFAULT_RUNTIME  Runtime for a fleet entry that carries no `:runtime`
#                       suffix. Default `podman`. A runtime NAME is not machine
#                       specific, so a default here freezes nothing.
#   HT_BUILD_HOST       Host that performs the native image build.
#   BUILD_HOST          Legacy alias for HT_BUILD_HOST.
#                       Both default to the FIRST entry of HT_FLEET — derived,
#                       not named.
#
# Every function returns 2 (COULD NOT DETERMINE) rather than inventing a value.
# 2 is never a pass.
#
# Usage:
#   . "$(dirname -- "${BASH_SOURCE[0]}")/lib/translation-fleet.sh"
#   ht_fleet_require || exit $?
# =============================================================================

# Resolve the fleet declaration into HT_FLEET_ENTRIES (array of host[:runtime]).
# rc 0 = resolved, rc 2 = not declared.
ht_fleet_require() {
    local _decl="${HT_FLEET:-${HOSTS:-}}"
    if [ -z "${_decl// /}" ]; then
        cat >&2 <<'MSG'
FATAL (rc 2, COULD NOT DETERMINE): the translation fleet is not declared.

  This tree deliberately carries NO host names. Declare the fleet in the
  environment, as space-separated `host[:runtime]` entries:

      export HT_FLEET="build-host:podman worker-host:docker"

  Optionally also:
      export HT_SSH_USER=<account>          # defaults to $USER
      export HT_BUILD_HOST=<host>           # defaults to the first HT_FLEET entry
      export HT_DEFAULT_RUNTIME=podman      # for entries with no :runtime suffix

  Refusing to guess is deliberate: a frozen default resolved somebody else's
  machine and failed at ssh time as a DNS error instead of a config error.
MSG
        return 2
    fi
    # shellcheck disable=SC2206
    HT_FLEET_ENTRIES=( $_decl )
    [ "${#HT_FLEET_ENTRIES[@]}" -gt 0 ] || return 2
    return 0
}

# echo every fleet host, one per line, suffix stripped.
ht_fleet_hosts() {
    ht_fleet_require || return $?
    local e
    for e in "${HT_FLEET_ENTRIES[@]}"; do printf '%s\n' "${e%%:*}"; done
}

# echo the container runtime declared for $1, else HT_DEFAULT_RUNTIME.
ht_fleet_runtime() {
    local want="$1" e host rt
    ht_fleet_require || return $?
    for e in "${HT_FLEET_ENTRIES[@]}"; do
        host="${e%%:*}"
        [ "$host" = "$want" ] || continue
        rt="${e#"$host"}"; rt="${rt#:}"
        if [ -n "$rt" ]; then printf '%s\n' "$rt"; return 0; fi
        break
    done
    printf '%s\n' "${HT_DEFAULT_RUNTIME:-podman}"
}

# echo the SSH account. Derived from the environment; never frozen in the tree.
ht_ssh_user() {
    local u="${HT_SSH_USER:-${USER:-}}"
    if [ -z "$u" ]; then
        echo "FATAL (rc 2): no SSH account — set HT_SSH_USER (\$USER is unset)" >&2
        return 2
    fi
    printf '%s\n' "$u"
}

# echo `user@host` for $1.
ht_ssh_target() {
    local u; u="$(ht_ssh_user)" || return $?
    printf '%s@%s\n' "$u" "$1"
}

# echo the build host: HT_BUILD_HOST, else BUILD_HOST, else the first entry.
ht_build_host() {
    if [ -n "${HT_BUILD_HOST:-}" ]; then printf '%s\n' "$HT_BUILD_HOST"; return 0; fi
    if [ -n "${BUILD_HOST:-}" ];    then printf '%s\n' "$BUILD_HOST";    return 0; fi
    ht_fleet_require || return $?
    printf '%s\n' "${HT_FLEET_ENTRIES[0]%%:*}"
}
