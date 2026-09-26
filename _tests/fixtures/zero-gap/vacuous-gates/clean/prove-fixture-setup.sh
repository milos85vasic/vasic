#!/usr/bin/env bash
# clean control (fix round F2, review rev-base-A): a fixture-building loop inside a proof helper is
# SETUP, not a gate verdict — its `|| return 1` reports a setup error, it judges nothing. The shape is
# the mkrepo helper of a class proof: copy a corpus, then make each declared submodule a nested repo.
# (no emptiness guard within 12 lines of the loop: nothing else in this file clears it)
prove_failure() (
    T=$(mktemp -d)
    mkrepo() {
        local p
        cp -R "$1" "$2" || return 1
        while IFS= read -r p; do
            [ -d "$2/$p" ] || continue
            git -C "$2/$p" init -q && git -C "$2/$p" add -A &&
                git -C "$2/$p" commit -q -m fixture || return 1
        done < <(git config -f "$2/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}')
        git -C "$2" init -q
    }
    mkrepo corpus "$T/c" || { echo "PROOF UNDETERMINED: cannot build repositories"; exit 2; }
)
