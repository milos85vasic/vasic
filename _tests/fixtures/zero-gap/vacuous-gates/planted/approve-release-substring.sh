#!/usr/bin/env bash
# planted (fix round F3, review rev-f): approve_release() holds "prov" as a SUBSTRING only; it is not a
# proof harness, so its gpg --verify loop over a git-fed enumeration is a verdict and is reported.
approve_release() {
    while IFS= read -r f; do
        gpg --verify "$f" || return 1
    done < <(git ls-files '*.sig')
    echo PASS
}
approve_release
