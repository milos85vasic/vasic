#!/usr/bin/env bash
# _tests/zero-gap-guard-fixtures.sh — fixture driver for the feature-010 push-path guards (T040, T041).
#
# Builds ONE disposable git repository per case from a fixture directory, commits a base and a head, runs
# the guard under test against that repository, and compares exit code and a required output token with
# <cases>/expect.tsv. Nothing here touches the live repository, its index, its hooks or any remote: every
# repository lives under a mktemp directory that is removed on exit.
#
#   bash _tests/zero-gap-guard-fixtures.sh --script <guard.sh> --cases <fixture-dir>
#
# FIXTURE LAYOUT (<cases>/)
#   base/                  the tree committed as ref `base`
#   base/GITLINKS          optional: lines "<path> <40-hex sha>" recorded as gitlinks (mode 160000)
#   <case>/                files copied over the base tree and committed as `head`; a missing or empty
#                          directory is the no-change control
#   <case>/DELETE          optional: one path per line, removed in head
#   <case>/GITLINKS        optional: "<path> <sha>" lines; set/replace gitlinks in head
#   <case>/RMGITLINK       optional: one path per line; gitlink removed in head
#   expect.tsv             header + "case<TAB>rc<TAB>token"; the guard's combined output must contain token
#
# The guard is invoked as:  <script> --root <repo> --base base --head HEAD
#
# EXIT: 0 every case behaved; 1 at least one case did not (the guard under test is wrong or neutered);
#       2 cannot determine (git/mktemp missing, fixture directory unreadable or empty, case dir absent
#       with no expect row).
set -uo pipefail
SCRIPT="" CASES=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --script) SCRIPT="${2:-}"; shift 2 ;;
    --cases)  CASES="${2:-}"; shift 2 ;;
    *) echo "fixtures: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
[ -n "$SCRIPT" ] && [ -n "$CASES" ] || { echo "fixtures: --script and --cases are required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "fixtures: git absent" >&2; exit 2; }
[ -d "$CASES/base" ] && [ -r "$CASES/expect.tsv" ] || { echo "fixtures: $CASES lacks base/ or expect.tsv" >&2; exit 2; }
SCRIPT_ABS="$(cd "$(dirname "$SCRIPT")" 2>/dev/null && pwd)/$(basename "$SCRIPT")"
CASES_ABS="$(cd "$CASES" && pwd)"
[ -e "$SCRIPT_ABS" ] || { echo "fixtures: guard under test absent: $SCRIPT" >&2; exit 2; }
WORK="$(mktemp -d)" || { echo "fixtures: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null HOME="$WORK/home"
mkdir -p "$HOME"
G() { git -C "$1" -c user.name=fx -c user.email=fx@example.invalid -c commit.gpgsign=false "${@:2}"; }

apply_gitlinks() { # <repo> <file>
  local p s
  while read -r p s; do
    [ -n "$p" ] || continue
    G "$1" update-index --add --cacheinfo "160000,$s,$p" || return 1
  done < "$2"
}

pass=0 fail=0 total=0
while IFS=$'\t' read -r name erc token; do
  [ "$name" = "case" ] && continue
  [ -n "$name" ] || continue
  total=$((total+1))
  repo="$WORK/r$total"; mkdir -p "$repo"
  G "$repo" init -q . >/dev/null 2>&1 || { echo "fixtures: git init failed" >&2; exit 2; }
  cp -a "$CASES_ABS/base/." "$repo/" || exit 2
  rm -f "$repo/GITLINKS"
  G "$repo" add -A >/dev/null 2>&1
  [ -r "$CASES_ABS/base/GITLINKS" ] && { apply_gitlinks "$repo" "$CASES_ABS/base/GITLINKS" || exit 2; }
  G "$repo" commit -q -m base >/dev/null 2>&1 || { echo "fixtures: base commit failed" >&2; exit 2; }
  G "$repo" tag base
  ov="$CASES_ABS/$name"
  if [ -d "$ov" ]; then
    cp -a "$ov/." "$repo/" || exit 2
    rm -f "$repo/DELETE" "$repo/GITLINKS" "$repo/RMGITLINK" "$repo/.keep"
    [ -r "$ov/DELETE" ] && while read -r d; do [ -n "$d" ] && rm -rf "${repo:?}/$d"; done < "$ov/DELETE"
    [ -r "$ov/RMGITLINK" ] && while read -r d; do [ -n "$d" ] && G "$repo" rm -q --cached "$d" >/dev/null 2>&1; done < "$ov/RMGITLINK"
    G "$repo" add -A >/dev/null 2>&1   # add -A stages the base gitlinks as deleted (no work-tree dir): put them back
    if [ -r "$CASES_ABS/base/GITLINKS" ]; then
      while read -r d s; do
        [ -n "$d" ] || continue
        if [ -r "$ov/RMGITLINK" ] && grep -qxF -- "$d" "$ov/RMGITLINK"; then continue; fi
        G "$repo" update-index --add --cacheinfo "160000,$s,$d" || exit 2
      done < "$CASES_ABS/base/GITLINKS"
    fi
    [ -r "$ov/GITLINKS" ] && { apply_gitlinks "$repo" "$ov/GITLINKS" || exit 2; }
  fi
  G "$repo" commit -q --allow-empty -m head >/dev/null 2>&1 || { echo "fixtures: head commit failed" >&2; exit 2; }
  out="$(bash "$SCRIPT_ABS" --root "$repo" --base base --head HEAD 2>&1)"; rc=$?
  if [ "$rc" = "$erc" ] && printf '%s\n' "$out" | grep -qF -- "$token"; then
    pass=$((pass+1)); printf 'ok    %-26s rc=%s  token=[%s]\n' "$name" "$rc" "$token"
  else
    fail=$((fail+1)); printf 'FAIL  %-26s want rc=%s token=[%s]; got rc=%s\n' "$name" "$erc" "$token" "$rc"
    printf '%s\n' "$out" | sed 's/^/        | /' | head -8
  fi
done < "$CASES_ABS/expect.tsv"
[ "$total" -gt 0 ] || { echo "fixtures: expect.tsv holds no case" >&2; exit 2; }
printf 'fixtures: %d case(s): %d ok, %d FAIL\n' "$total" "$pass" "$fail"
[ "$fail" -eq 0 ]
