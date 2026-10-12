#!/usr/bin/env bash
# VSC-360 probe: run from the root of the tree under test. Builds a throwaway specimen in a mktemp sandbox
# (file:// remotes, no network): a submodule whose origin FETCHES from a repository at the tip but PUSHES to a
# second repository that lags the gitlink. The tree's own scripts/verify-submodule-remote-sync.sh is run on it.
#   CONTROL  same specimen without the lagging push target       -> the gate must be green (rc 0)
#   SUBJECT  with the lagging push target                        -> the gate must NOT be green (rc 0 = a lagging
#            push target read as CURRENT = violated, exit 1); rc 1 naming the push target = holds, exit 0
# Exit 0 holds / 1 violated / 2 cannot determine (control not green, git absent, sandbox failure).
set -u
gate=scripts/verify-submodule-remote-sync.sh
[ -f "$gate" ] || { echo "no $gate"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "git absent"; exit 2; }
SB=$(mktemp -d) || exit 2
trap 'rm -rf "$SB"' EXIT
G=(-c user.name=probe -c user.email=probe@example.invalid -c commit.gpgsign=false -c init.defaultBranch=main)
git "${G[@]}" init -q "$SB/up/mod" || exit 2
for i in 1 2 3; do printf 'c%s\n' "$i" >"$SB/up/mod/f.txt"; git "${G[@]}" -C "$SB/up/mod" add f.txt && git "${G[@]}" -C "$SB/up/mod" commit -qm "c$i" || exit 2; done
tip=$(git -C "$SB/up/mod" rev-parse HEAD) || exit 2
git "${G[@]}" clone -q "$SB/up/mod" "$SB/up/lag" && git "${G[@]}" -C "$SB/up/lag" reset -q --hard HEAD~2 || exit 2
mk() { # mk <dir>
  local d=$1; rm -rf "$d"; mkdir -p "$d"; git "${G[@]}" init -q "$d" || return 1
  printf '[submodule "mod"]\n\tpath = mod\n\turl = file://%s/up/mod\n' "$SB" >"$d/.gitmodules"
  printf 'schema_version: 1\n\ndeps:\n' >"$d/helix-deps.yaml"
  git "${G[@]}" -C "$d" update-index --add --cacheinfo "160000,${tip},mod" >/dev/null 2>&1 || return 1
  git "${G[@]}" clone -q "$SB/up/mod" "$d/mod" >/dev/null 2>&1
}
mk "$SB/control" || exit 2
out=$(bash "$gate" --root "$SB/control" 2>&1); rc=$?
[ "$rc" -eq 0 ] || { echo "CONTROL not green (rc $rc): the harness is unsound"; exit 2; }
mk "$SB/subject" || exit 2
git -C "$SB/subject/mod" config --add remote.origin.pushurl "file://$SB/up/lag"
out=$(bash "$gate" --root "$SB/subject" 2>&1); rc=$?
case "$rc" in
  0) echo "VIOLATED: the gate is green (rc 0) although a push target lags the gitlink"; exit 1 ;;
  1) if printf '%s\n' "$out" | grep -qi 'push target'; then echo "holds: rc 1, the lagging push target is named"; exit 0
     else echo "rc 1 but the lagging push target is not named"; exit 1; fi ;;
  *) echo "gate rc $rc"; exit 2 ;;
esac
