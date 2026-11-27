# macOS runner proof, 2026-11-25

Host mistborn.local (macOS arm64, /bin/bash 3.2.57, PATH /opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin), checkout /Volumes/T7/Projects/vasic/workshop.

## RED (workshop main 507da3a7, before the fix)

- scripts/runner-flag.test.sh: "44 passed, 1 failed" (tail in red-before-fix-507da3a7-runner-flag.test.sh.txt; the failing line itself was not captured in that tail).
- Direct reproduction, captured in the session: running run-isolated.sh with --runner=podman and WORKSHOP_ISOLATED_VALIDATE_ONLY=1 printed
  "run-isolated: REFUSED: --root '/Users/milosvasic/.cache/workshop-isolated' cannot be normalised", rc 2.
- Root cause: BSD realpath has no -m or -s ("realpath: illegal option -- -") and BSD readlink has no -m; both were used in scripts/run-isolated.sh (readlink -m also in answering-measure.sh). GNU timeout was used in start.sh.
- With only the system PATH (no /opt/homebrew/bin), runner-flag.test.sh exits 2 CANNOT-DETERMINE because podman is not on PATH.

## GREEN (workshop main 364850d3, tag vasic-1.0.0-dev-0.1.0, Mac checkout fast-forwarded)

green-final-364850d3-*.txt: runner-flag 45 passed / 0 failed; portable-helpers OK 50 assertions; runner-prepare 39 passed / 0 failed. mutation-final.txt: 5 killed / 0 survived. Hashes: SHA256SUMS.

Not exercised: start.sh itself on the Mac (no machine stop, no container start; the brief was read-only), so runbook B in docs/operator/open-operator-items-2026-11-25.md is still open for start, reboot and docker/colima. Label: PROVISIONAL (section 11.4.298).
