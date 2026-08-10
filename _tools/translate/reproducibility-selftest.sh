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
#     is an ephemeral /tmp/... literal (the six UI-translation scripts under
#     _tools/gen/).
#   * FAILS (exit 1) if ANY such default resolves to /tmp/...
#   * PASSES (exit 0) when every such default is repo-relative.
#
# It parses no config and needs no engine present — it is a pure static guard,
# safe to run from a clean clone. bash 3.2 compatible.
# =============================================================================
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
TOOLS="$REPO/_tools"

echo "== HelixTranslate reproducibility self-test (repo=$REPO) =="

# Grab every "${HELIX_BIN:-DEFAULT}" / "${HELIX_TRANSLATE_BIN:-DEFAULT}" default,
# as path:lineno:content, across all committed *.sh under _tools.
matches="$(grep -rnE '\$\{HELIX_(TRANSLATE_)?BIN:-[^}]*\}' "$TOOLS" \
  --include='*.sh' --exclude='reproducibility-selftest.sh' 2>/dev/null | sort)"

if [ -z "$matches" ]; then
  echo "FAIL: no HELIX_BIN / HELIX_TRANSLATE_BIN default found under $TOOLS."
  echo "      (Nothing to guard — the engine-path default may have been renamed.)"
  exit 1
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
# The six UI-translation scripts under _tools/gen/ default the engine path in an
# `ENGINE = ...` (or `HELIX_BIN = ...`) assignment. Such a default that is an
# ephemeral /tmp/... literal is equally non-reproducible from a clean clone.
# Scan every committed *.py under _tools for an ENGINE/HELIX_BIN assignment whose
# right-hand side references /tmp/... and FAIL if any is found. The self-test is
# a *.sh file, so --include='*.py' already excludes it.
echo "----------------------------------------------------------------------"
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
  echo "PASS (no /tmp engine default in any _tools/**/*.py)"
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
