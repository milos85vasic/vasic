#!/usr/bin/env bash
# clean control (fix round F3): a `{`-bodied proof harness whose fixture loop ends in `|| exit 1` (a setup
# error: every command in the chain builds a fixture) is setup, not a verdict.
prove_x() {
    T=$(mktemp -d)
    for p in $(git ls-files 'fixtures/*'); do
        mkdir -p "$T/$p" && cp -R "$p" "$T/$p" &&
            git -C "$T/$p" init -q && git -C "$T/$p" add -A || exit 1
        printf 'seed\n' >"$T/$p/seed.txt" || exit 1
        ln -s "$T/$p/seed.txt" "$T/$p/link" || exit 1
        git -C "$T/$p" -c user.name=zg commit -q -m fixture || exit 1
    done
}
prove_x
