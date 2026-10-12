#!/usr/bin/env bash
# VSC-364 probe: run from the root of the tree under test. Builds the evidence-chain
# adapter from THAT tree into a scratch dir and feeds six planted placeholder argv shapes
# (and two benign controls) to its `argv-policy` subcommand.
# Exit: 0 all six refused + both controls accepted; 1 a planted shape slipped through or a control
# was refused; 2 cannot determine (build failure).
set -u
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
# A scratch worktree has no submodule content: point the module's `replace` at the main
# checkout's continuum module (read-only use), building from a COPY of the tree's sources.
MAIN=$(cd "$(git rev-parse --git-common-dir)/.." && pwd) || exit 2
CONT="$MAIN/submodules/constitution/submodules/continuum"
[ -d "$CONT" ] || { echo "continuum module absent: $CONT"; exit 2; }
mkdir "$T/src" && cp _tools/zero-gap-chain/*.go _tools/zero-gap-chain/go.mod "$T/src/" || exit 2
rm -f "$T"/src/*_test.go
sed -i "s#^replace .*#replace github.com/vasic-digital/continuum => $CONT#" "$T/src/go.mod"
( cd "$T/src" && GOPROXY=off GOTOOLCHAIN=local GOFLAGS=-mod=mod go build -o "$T/zgc" . ) >"$T/build.log" 2>&1 || { echo "build failed"; head -3 "$T/build.log"; exit 2; }
miss=0
planted() { # name, argv...
  local n=$1; shift
  if "$T/zgc" argv-policy -- "$@" >/dev/null 2>&1; then echo "NOT-REFUSED $n"; miss=$((miss+1)); else echo "refused $n"; fi
}
planted pct-query-key   curl 'https://h.invalid/x?%74oken=PLACEHOLDER'
planted flag-auth       tool --auth PLACEHOLDER
planted flag-creds      tool --creds PLACEHOLDER
planted flag-pat        tool --pat PLACEHOLDER
planted env-npm-auth    env NPM_AUTH=PLACEHOLDER tool
planted header-x-auth   curl -H 'X-Auth: PLACEHOLDER' https://h.invalid
for c in "ls -la" "git log --author=someone --oneline"; do
  # shellcheck disable=SC2086
  if ! "$T/zgc" argv-policy -- $c >/dev/null 2>&1; then echo "CONTROL-REFUSED $c"; miss=$((miss+1)); fi
done
[ "$miss" -eq 0 ]
