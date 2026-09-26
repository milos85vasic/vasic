#!/usr/bin/env bash
# planted (fix round F3): in a proof harness, `cat "$f" >/dev/null || return 1` CHECKS that each file is
# readable (a redirect to /dev/null builds nothing), so the loop is a verdict and is reported.
prove_readable() {
    for f in $(git ls-files 'x*'); do
        cat "$f" >/dev/null || return 1
    done
    echo PASS
}
prove_readable
