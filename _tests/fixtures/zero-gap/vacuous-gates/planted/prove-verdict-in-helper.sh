#!/usr/bin/env bash
# planted: a loop inside a proof helper that JUDGES (grep -q ... || return 1) over a
# git-fed enumeration with no emptiness refusal is still a verdict, still reported; so is one whose
# test sits on a continuation line of the `|| return 1` chain ([ -s ] && cp ... || return 1), and one
# whose `|| return 1` command names a failure word (check_drift), and a detect_* loop (its printed rows
# ARE findings) with no failure word at all, and one whose bare `return 1` answers `if ! check_one`.
prove_failure() (
    mkcheck() {
        while IFS= read -r p; do
            grep -q marker "$p" || return 1
        done < <(git ls-files 'x*')
        echo PASS
    }
    mkcheck2() {
        for f in $(git ls-files 'y*'); do
            [ -s "$f" ] &&
                cp "$f" "$f.bak" || return 1
        done
    }
    mkcheck3() {
        while IFS= read -r p; do
            check_drift "$p" || return 1
        done < <(git ls-files 'z*')
    }
    detect_rows() {
        while IFS= read -r p; do
            printf 'row %s\n' "$p"
        done < <(git ls-files 'w*')
    }
    mkcheck4() {
        while IFS= read -r p; do
            if ! check_one "$p"; then
                return 1
            fi
        done < <(git ls-files 'v*')
    }
    mkcheck; mkcheck2; mkcheck3; detect_rows; mkcheck4
)
