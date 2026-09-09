#!/usr/bin/env bash
# =============================================================================
# prove-translation-fleet.sh — the §1.1 PAIRED MUTATION for the fleet-config
# decoupling landed 2026-09-08.
#
# WHAT IT GUARDS
# --------------
# Four tracked files used to name two developer machines and one ssh account as
# literals. They now resolve all three through _tools/lib/translation-fleet.sh,
# whose contract carries NO host default: an undeclared fleet is rc 2 (COULD
# NOT DETERMINE), never a guess and never a pass.
#
# §1.1 requires the pairing, not the assertion. So every check below comes in
# two arms:
#
#   CONTROL     the real, derived tree  ->  MUST PASS
#   MUTATION    a throwaway copy with a machine name put back  ->  MUST BE CAUGHT
#
# A detector that has only ever been observed passing is not known to work. The
# mutation arms exist so that a future edit which re-freezes a host name cannot
# make this file green.
#
# Exit 0 = every control passed AND every mutation was caught
#      1 = a control failed or a mutation slipped through  (a REAL finding)
#      2 = could not do its job (missing tree, unreadable file) — never a pass
# =============================================================================
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || exit 2
ROOT="$(cd -- "$HERE/.." && pwd)" || exit 2
LIB="$HERE/lib/translation-fleet.sh"
[ -r "$LIB" ] || { echo "FATAL (rc 2): missing $LIB" >&2; exit 2; }

# The files whose host-independence this proof guards.
GUARDED=(
  "_tools/lib/translation-fleet.sh"
  "_tools/helixtranslate-container.sh"
  "_tools/translate-fleet.sh"
  "_tools/distribute-helixtranslate.sh"
  "_tools/containers/cmd/distribute-helixtranslate/main.go"
)
for g in "${GUARDED[@]}"; do
  [ -r "$ROOT/$g" ] || { echo "FATAL (rc 2): missing guarded file $g" >&2; exit 2; }
done

# ---- THE DETECTOR -----------------------------------------------------------
# A machine name is an mDNS/local-domain host or an `<account>@<host>` literal.
# Deliberately NOT a list of the two names that used to be here: a list of the
# names already removed would pass forever while a THIRD machine was frozen in.
# `$VAR@`, `${VAR}@` and `"$(...)"` forms are derivations, not literals.
# The leading class excludes ONLY the characters that make the match a
# DERIVATION rather than a literal: `$` and `{` (a parameter expansion), `.`
# and `/` (already inside a longer name or a path). It deliberately does NOT
# exclude `"`, `'` or `-` — the mutation arm proved that excluding them let
# `[ "$h" = "<machine>.local" ]` and `${BUILD_HOST:-<machine>.internal}` walk
# straight past, which is exactly the shape both real defects had.
HOSTNAME_PATTERN='(^|[^A-Za-z0-9_$.{/])[a-z][a-z0-9-]*\.(local|lan|home|internal)([^A-Za-z0-9-]|$)'
SSHUSER_PATTERN='(^|[^A-Za-z0-9_${(])[a-z][a-z0-9._-]*@[a-z][a-z0-9.-]*\.[a-z]'

# detect_frozen_host <file> -> 0 = clean, 1 = a machine name is frozen in
detect_frozen_host() {
    local f="$1"
    grep -qE "$HOSTNAME_PATTERN" "$f" && return 1
    grep -qE "$SSHUSER_PATTERN"  "$f" && return 1
    return 0
}

PASS=0; FAIL=0
say() { printf '%-6s %-30s %s\n' "$1" "$2" "$3"; }
ok()   { PASS=$((PASS+1)); say "PASS" "$1" "$2"; }
bad()  { FAIL=$((FAIL+1)); say "FAIL" "$1" "$2"; }

# =============================================================================
# CONTROL ARM — the real tree must be clean and must resolve from environment
# =============================================================================
for g in "${GUARDED[@]}"; do
  if detect_frozen_host "$ROOT/$g"; then
      ok "C1 clean/$(basename "$g")" "no machine name and no frozen ssh account"
  else
      bad "C1 clean/$(basename "$g")" "a machine name or ssh literal is frozen in: $(grep -nEm1 "$HOSTNAME_PATTERN|$SSHUSER_PATTERN" "$ROOT/$g")"
  fi
done

# C2 — a DECLARED fleet resolves, and resolves to exactly what was declared.
c2="$( . "$LIB"
       export HT_FLEET="alpha.invalid:podman beta.invalid:docker gamma.invalid"
       export HT_SSH_USER=tester
       printf '%s|%s|%s|%s|%s' \
         "$(ht_fleet_hosts | tr '\n' ',')" \
         "$(ht_fleet_runtime alpha.invalid)" \
         "$(ht_fleet_runtime beta.invalid)" \
         "$(ht_fleet_runtime gamma.invalid)" \
         "$(ht_ssh_target beta.invalid)" )"
if [ "$c2" = "alpha.invalid,beta.invalid,gamma.invalid,|podman|docker|podman|tester@beta.invalid" ]; then
    ok "C2 derived resolution" "declared fleet resolves per host; unsuffixed entry falls back to podman"
else
    bad "C2 derived resolution" "got: $c2"
fi

# C3 — the ssh account comes from the environment, not the tree.
c3="$( . "$LIB"; unset HT_SSH_USER; USER=someoneelse ht_ssh_user )"
if [ "$c3" = "someoneelse" ]; then
    ok "C3 ssh account derived" "\$USER is honoured; no account is frozen in the tree"
else
    bad "C3 ssh account derived" "expected 'someoneelse', got '$c3'"
fi

# C4 — three-valued: an UNDECLARED fleet is rc 2, not a guess and not a pass.
for entry in helixtranslate-container.sh translate-fleet.sh distribute-helixtranslate.sh; do
  case "$entry" in
    helixtranslate-container.sh) args=(-i /etc/hostname -o /dev/null -provider p -model m -target-lang ru) ;;
    translate-fleet.sh)          args=(probe ru) ;;
    *)                           args=() ;;
  esac
  out="$(env -u HT_FLEET -u HOSTS -u HT_HOST -u HT_BUILD_HOST -u BUILD_HOST \
          HT_SRC="$ROOT" bash "$ROOT/_tools/$entry" "${args[@]}" 2>&1)"; rc=$?
  if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q 'HT_FLEET'; then
      ok "C4 rc2/$entry" "undeclared fleet => rc 2, naming HT_FLEET"
  else
      bad "C4 rc2/$entry" "expected rc 2 naming HT_FLEET, got rc $rc"
  fi
done

# =============================================================================
# MUTATION ARM — put a machine name back, in a throwaway copy, and require the
# detector to catch it. If any of these PASSES, the detector is inoperative.
# =============================================================================
LAB="$(mktemp -d)" || exit 2
trap 'rm -rf "$LAB"' EXIT

mutate() {  # <name> <description> <line to append>
    local name="$1" desc="$2" line="$3"
    local f="$LAB/mutant.sh"
    cp "$ROOT/_tools/translate-fleet.sh" "$f" || return 2
    printf '%s\n' "$line" >> "$f"
    if detect_frozen_host "$f"; then
        bad "$name" "MUTATION SLIPPED THROUGH — $desc"
    else
        ok  "$name" "caught: $desc"
    fi
}

mutate "M1 host default"  "HOSTS=\"\${HOSTS:-<machine>.local ...}\"" \
       'read -r -a HOSTLIST <<<"${HOSTS:-thinker.local amber.local}"'
mutate "M2 host compare"  'rt=docker when host == a named machine' \
       'rt="podman"; [ "$host" = "amber.local" ] && rt="docker"'
mutate "M3 ssh literal"   'a frozen <account>@<host> ssh target' \
       'ssh -o BatchMode=yes "milosvasic@amber.local" true'
mutate "M4 third machine" 'a machine this tree has never named before' \
       'BUILD_HOST="${BUILD_HOST:-newbox.internal}"'
mutate "M5 lan domain"    'a .lan host, proving the rule is not a two-name list' \
       'WORKER=fileserver.lan'

# M6 — the CONTROL for the detector itself: a derived form must NOT be caught,
# or the detector is a tautology that fails everything.
f="$LAB/control.sh"; cp "$ROOT/_tools/translate-fleet.sh" "$f"
printf '%s\n' 'HOST="${HT_HOST:?set HT_HOST}"' 'ssh "$(ht_ssh_target "$HOST")" true' >> "$f"
if detect_frozen_host "$f"; then
    ok  "M6 detector control" "a fully derived form is NOT flagged (detector is not a tautology)"
else
    bad "M6 detector control" "FALSE POSITIVE — derived form flagged: $(grep -nEm1 "$HOSTNAME_PATTERN|$SSHUSER_PATTERN" "$f")"
fi

echo "────────────────────────────────────────────────────────"
echo "$PASS passed / $FAIL failed  ($((PASS+FAIL)) assertion(s), 5 mutations + 1 detector control)"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
