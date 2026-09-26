#!/usr/bin/env bash
# planted (fix round F3, review rev-f): inside a real proof harness, `bash -n "$f" || return 1` JUDGES
# each file (a syntax check), it builds no fixture, so the loop is a verdict and is reported; so is a
# chain whose FIRST command builds (cp) and whose later command judges (bash -n).
prove_syntax() {
    for f in $(git ls-files '*.sh'); do
        bash -n "$f" || return 1
    done
    echo PASS
}
prove_copied() {
    for f in $(git ls-files '*.bash'); do
        cp "$f" "$T/" && bash -n "$T/$f" || return 1
    done
    echo PASS
}
prove_syntax; prove_copied
