#!/usr/bin/env bash
# VSC-365 probe (check author: t090-check-author). Run from the root of the tree under test.
# Target: "a planted edit of argvpolicy.go is reported as drift (1 of 1 mutation caught)".
# Builds a throwaway sandbox holding a registry with the tree's OWN exempt row for scripts/zero-gap-evidence.sh (copied
# verbatim, whatever its hash fields look like), the files that row can cover (scripts/zero-gap-*.sh and the whole
# _tools/zero-gap-chain module) and one conforming dummy check row so the registry verifier can run.
#   control : verifier on the sandbox reports no FACT DRIFT at all;
#   mutation: append one Go comment line to _tools/zero-gap-chain/argvpolicy.go in the sandbox, re-run; the verifier
#             must now report FACT DRIFT (any declared row).
# Exit 0 mutation caught / 1 not caught / 2 cannot determine (including: the control already drifts).
set -u
SRC=$(pwd)
V="$SRC/scripts/verify-check-registry.sh"
[ -f "$V" ] && [ -f "$SRC/scripts/check-registry.tsv" ] && [ -f "$SRC/_tools/zero-gap-chain/argvpolicy.go" ] || { echo "verifier, registry or argvpolicy.go absent"; exit 2; }
ROW=$(grep -P '^exempt\tscripts/zero-gap-evidence\.sh\t' "$SRC/scripts/check-registry.tsv")
[ -n "$ROW" ] || { echo "no exempt row for scripts/zero-gap-evidence.sh in the registry"; exit 2; }
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/scripts" "$T/_tools" || exit 2
cp "$SRC"/scripts/zero-gap-*.sh "$T/scripts/" 2>/dev/null
cp "$V" "$T/scripts/verify-check-registry.sh"
cp -R "$SRC/_tools/zero-gap-chain" "$T/_tools/zero-gap-chain" || exit 2
printf '#!/usr/bin/env bash\nset -uo pipefail\nwhile [[ $# -gt 0 ]]; do\n case "$1" in\n --root) shift; [[ -d "${1:-}" ]] || exit 2 ;;\n --prove-failure) D=$(mktemp -d); trap '"'"'rm -rf "$D"'"'"' EXIT; echo M1; exit 0 ;;\n esac\n shift\ndone\nexit 0\n' >"$T/scripts/alpha-check.sh"
chmod 755 "$T/scripts/alpha-check.sh"
{ printf 'scanroot\tscripts\n'; printf '%s\n' "$ROW"; printf 'check\talpha\tscripts/alpha-check.sh\tflag\t--prove-failure\t--root /nonexistent\n'; } >"$T/scripts/check-registry.tsv"
run() { (cd "$SRC" && timeout 300 bash "$V" --root "$T" 2>&1); }
O1=$(run)
printf '%s\n' "$O1" | grep -q 'CM-CHECK-REGISTRY' || { echo "verifier did not complete on the sandbox"; printf '%s\n' "$O1" | tail -5; exit 2; }
if printf '%s\n' "$O1" | grep -q 'FACT DRIFT'; then echo "control already reports FACT DRIFT (stale hash in the tree): cannot isolate the mutation"; exit 2; fi
printf '\n// VSC-365 planted edit\n' >>"$T/_tools/zero-gap-chain/argvpolicy.go"
O2=$(run)
printf '%s\n' "$O2" | grep -q 'CM-CHECK-REGISTRY' || { echo "verifier did not complete after the mutation"; exit 2; }
if printf '%s\n' "$O2" | grep -q 'FACT DRIFT'; then echo "planted edit of argvpolicy.go reported as FACT DRIFT (1 of 1 caught)"; exit 0; fi
echo "planted edit of argvpolicy.go NOT reported: exempt row for scripts/zero-gap-evidence.sh still hashes only the adapter (0 of 1 caught)"
exit 1
