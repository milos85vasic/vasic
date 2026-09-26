#!/usr/bin/env bash
# planted (fix round F3): functions whose names hold "prov" only as a SUBSTRING are not proof harnesses,
# so even a builder-only `cp ... || return 1` loop in them is the gate's own pass path over a git-fed
# enumeration with no emptiness refusal, and is reported ({ body and ( body).
approve_bundle() {
    for f in $(git ls-files 'dist/*'); do
        cp "$f" out/ || return 1
    done
    echo PASS
}
improve_cache() (
    for f in $(git ls-files 'cache/*'); do
        mkdir -p "out/$f" || exit 1
    done
    echo PASS
)
approve_bundle; improve_cache
