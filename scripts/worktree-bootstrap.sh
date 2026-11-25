#!/usr/bin/env bash
# scripts/worktree-bootstrap.sh — make a FRESH git worktree of this umbrella able to
# reach a verdict (gap register B5: UG-06, UG-09, UG-10, UG-14 share this root cause:
# uninitialised submodules and no test dependencies, which show up as rc 2 / false DRIFT).
#
# It initialises every submodule declared in .gitmodules at the commit the INDEX pins
# (never bumps a gitlink), optionally borrowing objects from another checkout with
# git's --reference so no full clone is needed, and optionally links _tests/node_modules.
#
# usage: scripts/worktree-bootstrap.sh [--root DIR] [--reference DIR] [--link-node-modules DIR] [--dry-run]
#   --root DIR               worktree to bootstrap (default: the checkout containing this script)
#   --reference DIR          another checkout whose submodule object stores are borrowed
#   --link-node-modules DIR  symlink DIR/_tests/node_modules into the root's _tests/ if absent
#   --dry-run                print what would be done, change nothing
# exit: 0 every declared submodule initialised | 2 could not complete (named, never a pass)
#       64 bad usage
# It only mutates the named root. It is a lifecycle tool (registered `exempt`), and it
# asserts nothing about the repository other than the post-condition it prints.
set -u
ROOT=""; REF=""; LINK=""; DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="${2:-}"; shift 2 ;;
        --reference) REF="${2:-}"; shift 2 ;;
        --link-node-modules) LINK="${2:-}"; shift 2 ;;
        --dry-run) DRY=1; shift ;;
        -h|--help) sed -n 2,19p "$0"; exit 0 ;;
        *) echo "worktree-bootstrap: unknown argument '$1'" >&2; exit 64 ;;
    esac
done
[ -n "$ROOT" ] || ROOT="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [ ! -f "$ROOT/.gitmodules" ] || ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "worktree-bootstrap: COULD NOT DETERMINE — $ROOT is not a git checkout with a .gitmodules" >&2
    exit 2
fi
fail=0; n=0
while read -r _ path; do
    [ -n "$path" ] || continue
    n=$((n+1))
    refarg=()
    if [ -n "$REF" ] && [ -e "$REF/$path/.git" ]; then refarg=(--reference "$REF/$path"); fi
    if [ "$DRY" = 1 ]; then
        echo "would: git -C $ROOT submodule update --init ${refarg[*]:-} $path"; continue
    fi
    if timeout 300 git -C "$ROOT" submodule update --init "${refarg[@]}" -- "$path" >/dev/null 2>&1; then
        echo "ok      $path"
    else
        echo "FAILED  $path (not initialised; a private repository needs credentials, or the pinned commit is unreachable)" >&2
        fail=$((fail+1))
    fi
done < <(git -C "$ROOT" config -f .gitmodules --get-regexp 'submodule\..*\.path')
if [ -n "$LINK" ]; then
    if [ -e "$ROOT/_tests/node_modules" ]; then echo "keep    _tests/node_modules (already present)"
    elif [ ! -d "$LINK/_tests/node_modules" ]; then echo "FAILED  --link-node-modules: $LINK/_tests/node_modules does not exist" >&2; fail=$((fail+1))
    elif [ "$DRY" = 1 ]; then echo "would: ln -s $LINK/_tests/node_modules $ROOT/_tests/node_modules"
    else ln -s "$LINK/_tests/node_modules" "$ROOT/_tests/node_modules" && echo "linked  _tests/node_modules"; fi
fi
if [ "$DRY" = 1 ]; then echo "dry run: $n submodule(s) declared"; exit 0; fi
unin="$(git -C "$ROOT" submodule status 2>/dev/null | grep -c '^-')"
echo "post-condition: $n declared, $unin uninitialised, $fail step(s) failed"
if [ "$fail" -gt 0 ] || [ "$unin" -gt 0 ]; then exit 2; fi
exit 0
