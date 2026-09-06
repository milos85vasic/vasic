#!/usr/bin/env bash
# =============================================================================
# reproducibility-selftest.sh  —  §11.4.77 regression guard.
#
# The HelixTranslate engine path MUST default to a REPO-RELATIVE, reproducible
# location produced by the committed container recipe
# (_tools/distribute-helixtranslate.sh -> _tools/helixtranslate-container.sh).
# It must NEVER default to an ephemeral /tmp/... path, because a clean clone
# cannot reproduce anything under /tmp (§11.4.77: reproduce from a clean clone).
#
# This test scans every translation script under _tools and:
#   * (shell) checks each *.sh parameter-expansion default of an engine-binary
#     variable (HELIX_BIN or HELIX_TRANSLATE_BIN).
#   * (python) checks each *.py for an ENGINE/HELIX_BIN assignment whose default
#     is an ephemeral /tmp/... literal (the UI-translation scripts under
#     _tools/gen/).
#   * FAILS (exit 1) if ANY such default resolves to /tmp/...
#   * PASSES (exit 0) when every such default is repo-relative.
#
# It parses no config and needs no engine present — it is a pure static guard,
# safe to run from a clean clone. bash 3.2 compatible.
#
# ── THREE-VALUED EXIT (this fleet's convention; 2 is NEVER a pass) ───────────
#   0  clean   — both populations were non-empty and every default is repo-relative
#   1  finding — a default still points at ephemeral /tmp
#   2  COULD NOT DETERMINE — the subject population is missing, so ZERO
#      assertions were evaluated. Never a pass, and not an accusation either.
#
# WHY THE PYTHON HALF NOW HAS A POSITIVE CONTROL — a defect, measured 2026-09-06.
# Both halves of this test are ABSENCE assertions ("no /tmp default"), and an
# absence assertion over an empty set is vacuously true. The shell half already
# guarded against that: with no `${HELIX_BIN:-...}` anywhere it refuses to
# report a verdict. The python half did not. Driven on a throwaway copy with
# EVERY *.py under _tools deleted, this script printed
#   `PASS (no /tmp engine default in any _tools/**/*.py)`
# and exited **0** — a pass reported for a population it no longer had. The
# subject-existence control below is that hole closed, and M4 in the paired
# proof is what keeps it closed.
#
# A SECOND reclassification, same date: "no HELIX_BIN default found under
# _tools" used to exit 1. Its own message says "the engine-path default may
# have been renamed", which is the subject going missing, not a /tmp default
# being found. It is now rc 2 for the same reason the python control is.
#
# Usage:
#   bash _tools/translate/reproducibility-selftest.sh
#   bash _tools/translate/reproducibility-selftest.sh --root DIR
#   bash _tools/translate/reproducibility-selftest.sh --prove-failure
#
# §1.1 PAIRED MUTATION PROOF: `--prove-failure`. Every mutation is DATA — a
# synthetic `_tools` tree under mktemp, handed to the REAL entry point through
# `--root` — never an edit to this script.
# =============================================================================
set -u

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
PROVE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --root)          shift; REPO="${1:-}" ;;
    --prove-failure) PROVE=1 ;;
    -h|--help)       sed -n '/^# Usage:/,/^# =====/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "reproducibility-selftest.sh: unknown option '$1'" >&2; exit 2 ;;
  esac
  shift
done

undet() {
  echo "UNDETERMINED: $1"
  echo "  Zero assertions were evaluated, so this is neither a pass nor a finding (§11.4.6)."
  exit 2
}

# ─────────────────────────────────────────────────────────────────────────────
# §1.1 PAIRED MUTATION PROOF  —  --prove-failure
#
# Control: a synthetic `_tools` tree that is green BY CONSTRUCTION, so a red
# live tree can never disable the battery. Each case invokes the REAL entry
# point with `--root <sandbox>`; the only thing that changes between cases is
# the FIXTURE DATA.
#   0 all mutations caught with the right verdict / 1 one was not / 2 no sandbox
# ─────────────────────────────────────────────────────────────────────────────
if [ "$PROVE" -eq 1 ]; then
  echo "REPRODUCIBILITY-SELFTEST §1.1 PAIRED MUTATION PROOF"
  echo "----------------------------------------------------------------------"
  P_PASS=0; P_FAIL=0
  p_ok(){  P_PASS=$((P_PASS+1)); printf '✅ %-32s %s\n' "$1" "$2"; }
  p_bad(){ P_FAIL=$((P_FAIL+1)); printf '❌ %-32s %s\n' "$1" "$2"; }

  SB="$(mktemp -d "${TMPDIR:-/tmp}/reprosel-proof.XXXXXX")" || {
    echo "UNDETERMINED: cannot create a sandbox, so nothing was proved." >&2; exit 2; }
  trap 'rm -rf "$SB"' EXIT INT TERM

  # $2 = the shell default, $3 = the python default. Both are fixture DATA.
  mk_tree() {
    local sh_default="${1-\$TOOLS/helixtranslate-container.sh}"
    local py_default="${2-os.path.join(TOOLS, \"helixtranslate-container.sh\")}"
    rm -rf "$SB/tree"
    mkdir -p "$SB/tree/_tools/gen"
    {
      printf '#!/usr/bin/env bash\n'
      printf 'TOOLS="$(dirname "$0")"\n'
      [ -n "$sh_default" ] && printf 'HELIX_BIN="${HELIX_BIN:-%s}"\n' "$sh_default"
      printf 'echo "$HELIX_BIN"\n'
    } >"$SB/tree/_tools/translate-thing.sh"
    if [ -n "$py_default" ]; then
      {
        printf 'import os\n'
        printf 'TOOLS = os.path.dirname(__file__)\n'
        printf 'ENGINE = os.environ.get("HELIX_BIN", %s)\n' "$py_default"
      } >"$SB/tree/_tools/gen/translate-ui.py"
    fi
  }

  expect() {
    local label="$1" want="$2" root="$3" out rc
    out="$(bash "$SELF" --root "$root" 2>&1)"; rc=$?
    if [ "$rc" -eq "$want" ]; then
      p_ok "$label" "rc=$rc as required"
    else
      p_bad "$label" "expected rc=$want, got rc=$rc — $(printf '%s' "$out" | grep -m1 -E 'FAIL|UNDETERMINED|RESULT' | head -c 110)"
    fi
  }

  mk_tree
  expect "CONTROL repo-relative defaults" 0 "$SB/tree"

  mk_tree '/tmp/helixtranslate/bin/helix'
  expect "M1 shell default under /tmp" 1 "$SB/tree"

  mk_tree '' ''
  mk_tree "\$TOOLS/helixtranslate-container.sh" '"/tmp/helixtranslate/bin/helix"'
  expect "M2 python default under /tmp" 1 "$SB/tree"

  mk_tree '' 'os.path.join(TOOLS, "helixtranslate-container.sh")'
  expect "M3 shell subject absent" 2 "$SB/tree"

  mk_tree "\$TOOLS/helixtranslate-container.sh" ''
  expect "M4 python subject absent" 2 "$SB/tree"

  expect "M5 _tools tree absent" 2 "$SB/no-such-root"

  mk_tree
  expect "CONTROL restored" 0 "$SB/tree"

  echo "----------------------------------------------------------------------"
  if [ "$P_FAIL" -gt 0 ]; then
    echo "❌ REPRODUCIBILITY-SELFTEST §1.1 PROOF: FAIL — $P_FAIL of $((P_PASS + P_FAIL)) case(s) did not behave as required."
    exit 1
  fi
  echo "✅ REPRODUCIBILITY-SELFTEST §1.1 MUTATION PROOF: PASS — a synthetic control passed"
  echo "   twice and 5 mutations were each caught with the right THREE-VALUED verdict."
  echo "   M3 and M4 are the anti-vacuity pair: an ABSENT subject population is rc 2, not"
  echo "   the vacuous rc 0 this gate used to report for the python half."
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Normal operation
# ─────────────────────────────────────────────────────────────────────────────
[ -n "$REPO" ] && [ -d "$REPO" ] || undet "target root is not a directory: '${REPO}'"
TOOLS="$REPO/_tools"

echo "== HelixTranslate reproducibility self-test (repo=$REPO) =="

[ -d "$TOOLS" ] || undet "no _tools directory under $REPO — there is nothing to scan."

# ---- Shell scripts (§11.4.77) ----------------------------------------------
# Grab every "${HELIX_BIN:-DEFAULT}" / "${HELIX_TRANSLATE_BIN:-DEFAULT}" default,
# as path:lineno:content, across all committed *.sh under _tools.
matches="$(grep -rnE '\$\{HELIX_(TRANSLATE_)?BIN:-[^}]*\}' "$TOOLS" \
  --include='*.sh' --exclude='reproducibility-selftest.sh' 2>/dev/null | sort)"

if [ -z "$matches" ]; then
  undet "no HELIX_BIN / HELIX_TRANSLATE_BIN default found under $TOOLS.
  The engine-path default may have been renamed, so the shell half of this
  guard has NO SUBJECT. An absence assertion over an empty set is vacuously
  true and must not be reported as a pass."
fi

fail=0
# Here-doc (not a pipe) so 'fail' stays set in THIS shell under bash 3.2.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  # hit = path:lineno:content ; extract the DEFAULT inside ${VAR:-DEFAULT}
  def="${hit#*:-}"          # drop everything up to and incl. the first ':-'
  def="${def%%\}*}"         # keep up to the first closing '}'
  if printf '%s' "$def" | grep -q '/tmp/'; then
    echo "FAIL (ephemeral /tmp default): $hit"
    fail=1
  else
    echo "PASS (repo-relative default):  $hit"
  fi
done <<EOF
$matches
EOF

# ---- Python UI-translation scripts (§11.4.77) -------------------------------
# The UI-translation scripts under _tools/gen/ default the engine path in an
# `ENGINE = ...` (or `HELIX_BIN = ...`) assignment. Such a default that is an
# ephemeral /tmp/... literal is equally non-reproducible from a clean clone.
#
# POSITIVE CONTROL FIRST. The violation grep below is an ABSENCE assertion, so
# it must be preceded by evidence that the population it ranges over is not
# empty — see the header for the measurement that made this necessary.
echo "----------------------------------------------------------------------"
py_subjects="$(grep -rlE '(ENGINE|HELIX_BIN)[[:space:]]*=' "$TOOLS" \
  --include='*.py' 2>/dev/null | sort)"

if [ -z "$py_subjects" ]; then
  undet "no *.py under $TOOLS carries an ENGINE / HELIX_BIN assignment.
  The python half of this guard has NO SUBJECT, so 'no /tmp default in any
  .py' would be vacuously true. This is exactly the state in which this gate
  used to print a green PASS."
fi
py_n="$(printf '%s\n' "$py_subjects" | grep -c .)"
echo "SUBJECT: $py_n python file(s) under _tools carry an ENGINE/HELIX_BIN assignment"

py_matches="$(grep -rnE '(ENGINE|HELIX_BIN)[[:space:]]*=[^#]*/tmp/' "$TOOLS" \
  --include='*.py' 2>/dev/null | sort)"

if [ -n "$py_matches" ]; then
  # Here-doc (not a pipe) so 'fail' stays set in THIS shell under bash 3.2.
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    echo "FAIL (ephemeral /tmp .py engine default): $hit"
    fail=1
  done <<EOF
$py_matches
EOF
else
  echo "PASS (no /tmp engine default in any of those $py_n .py file(s))"
fi

echo "----------------------------------------------------------------------"
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL — an engine default still points at ephemeral /tmp (§11.4.77 gap)."
  echo "Fix: default the engine var to a repo-relative path, e.g."
  echo "     HELIX_BIN=\"\${HELIX_BIN:-\$TOOLS/helixtranslate-container.sh}\""
  exit 1
fi
echo "RESULT: PASS — all engine-binary defaults are repo-relative / reproducible."
exit 0
