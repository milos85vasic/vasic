#!/bin/sh
# =============================================================================
# ocr-run.sh — the tesseract OCR pass, AS RUN INSIDE the container.
#
# This file never executes on the host. It is bind-mounted read-only into the
# `tesseract-ocr` service defined by compose.ocr.yml and is that service's
# entrypoint. The container is started, waited on, inspected and torn down by
# _tools/containers/cmd/ocr, which drives podman/docker exclusively through
# `digital.vasic.containers` (§11.4.76(1),(3)) — nothing here shells out to a
# runtime, and nothing here knows one exists.
#
# POSIX sh ON PURPOSE. The image (jitesoft/tesseract-ocr, Ubuntu 22.04) ships
# /usr/bin/sh but NO bash and NO find — measured, not assumed:
#
#   command -v sh bash find   ->   /usr/bin/sh          (bash, find: absent)
#
# so this script uses a glob and shell arithmetic and nothing else.
#
# Contract with the caller:
#   /data      a directory of page PNGs, read-write (bind mount). For each
#              `<name>.png` this writes `<name>.ocr.txt` beside it, which is
#              exactly what `tesseract <in> <base>` produces, so a caller that
#              used the host binary reads back the same filenames.
#   OCR_PSM    tesseract --psm value (default 6)
#   OCR_LANG   tesseract -l    value (default eng)
#
# Exit codes, read back off the stopped container by cmd/ocr:
#   0  at least one page was OCR'd (per-page failures are counted and printed)
#   1  pages were present and EVERY one of them failed
#   3  no .png files were found — nothing to do; cmd/ocr maps this to rc 2
#      (COULD NOT DETERMINE), because "no input" is not "OCR succeeded".
# =============================================================================
set -eu

PSM="${OCR_PSM:-6}"
OCRLANG="${OCR_LANG:-eng}"

echo "[ocr-run] $(tesseract --version 2>&1 | head -1)"
echo "[ocr-run] psm=${PSM} lang=${OCRLANG}"

count=0
failed=0

for png in /data/*.png; do
  # An unmatched glob comes back literally in POSIX sh, so this is the "no
  # input" case rather than a file called '*.png'.
  if [ ! -e "$png" ]; then
    echo "[ocr-run] no .png file in /data — nothing to OCR" >&2
    exit 3
  fi

  base="${png%.png}"
  count=$((count + 1))

  # `tesseract <in> <base>` writes <base>.txt, so the base carries the .ocr
  # suffix and the product is <name>.ocr.txt.
  if tesseract "$png" "${base}.ocr" --psm "$PSM" -l "$OCRLANG" 2>&1; then
    echo "[ocr-run] ok  ${png##*/} -> ${base##*/}.ocr.txt"
  else
    echo "[ocr-run] ERR ${png##*/} — tesseract failed" >&2
    failed=$((failed + 1))
  fi
done

echo "[ocr-run] pages=${count} ocr'd=$((count - failed)) failed=${failed}"

# Anti-bluff, container side (§11.4): every page failing is a failure, not a
# quiet zero. A partial result is reported as a success WITH its failure count,
# and the host side records which pages are missing.
if [ "$failed" -ge "$count" ]; then
  echo "[ocr-run] FAIL: all ${count} page(s) failed to OCR" >&2
  exit 1
fi

echo "[ocr-run] done"
