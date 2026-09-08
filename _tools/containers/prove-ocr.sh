#!/usr/bin/env bash
# =============================================================================
# PAIRED MUTATION PROOF for _tools/containers/cmd/ocr (§1.1).
#
# WHY THIS FILE EXISTS AT ALL. The OCR container workload shipped with its
# mutations exercised BY HAND in the session that wrote it, and recorded in
# _tools/containers/README.md as prose. Prose is not a proof. A hand-run
# mutation cannot be re-run by the next reader, cannot be registered in
# scripts/check-registry.tsv, and cannot notice the day the assertion it
# describes stops holding. `cmd/runtime-probe` ships main_test.go; `cmd/ocr`
# shipped nothing. This closes that asymmetry.
#
# WHAT IT PROVES. That cmd/ocr's freshness assertion is real: that a container
# which exits 0 while writing NOTHING is reported as a failure, in both the
# absent and the stale case. The stale case is the one that matters, because
# OCR output lands BESIDE its input, so a leftover <page>.ocr.txt from an
# earlier run is exactly what a no-op container looks like when it succeeds.
#
# EVERY MUTATION IS DATA — a throwaway compose file, an empty PATH, an empty
# directory, an extra argv word. Not one of them edits cmd/ocr. A proof that
# mutates the code it is proving tests a program that will never ship; the
# constitution names that an "inoperative proof" and the check registry
# documents it as a real defect class rather than a hypothetical one.
#
# THE CONTROL (M0) CARRIES THE SAME WEIGHT AS THE MUTATIONS. Without it,
# "every mutation was caught" is satisfied by a program that returns 1
# unconditionally — which catches everything and detects nothing.
#
#   exit 0  every mutation was caught AND the control passed
#   exit 1  a mutation slipped through, or the control failed
#   exit 2  the proof could not run (no go, no runtime, no fixture) — NEVER a pass
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIXTURE="$ROOT/_tests/export/fixtures/golden-good.pdf"

command -v go       >/dev/null 2>&1 || { echo "UNDETERMINED: go is not on PATH";       exit 2; }
command -v pdftoppm >/dev/null 2>&1 || { echo "UNDETERMINED: pdftoppm is not on PATH"; exit 2; }
[[ -f "$FIXTURE" ]] || { echo "UNDETERMINED: fixture absent: $FIXTURE"; exit 2; }

BIN="$HERE/bin/ocr"
( cd "$HERE" && go build -o bin/ocr ./cmd/ocr ) || { echo "UNDETERMINED: cmd/ocr failed to build"; exit 2; }

# A runtime must actually be here, or every result below is a 2 and proves
# nothing. Ask cmd/ocr itself, so the probe and the workload agree by
# construction rather than by a second, independently-wrong detector.
if ! "$BIN" -probe >/dev/null 2>&1; then
    echo "UNDETERMINED: no container runtime/compose available — cmd/ocr -probe did not succeed"
    exit 2
fi

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

PASS=0; FAIL=0

# ---- the no-op compose file: THE mutation ----------------------------------
# Same service name, same container name, same mount contract as the real
# compose.ocr.yml — and a command that exits 0 having written nothing. This is
# precisely the container that must NOT be mistaken for a successful OCR.
NOOP="$T/compose.noop.yml"
cat > "$NOOP" <<'YAML'
services:
  tesseract-ocr:
    image: docker.io/library/alpine:3.20
    container_name: vasic-tesseract-ocr
    command: ["true"]
    volumes:
      - ${VASIC_OCR_DIR:?VASIC_OCR_DIR must be set}:/data:rw
    network_mode: none
    restart: "no"
YAML

# A fresh directory holding one REAL rendered page from the tracked fixture.
seed_pages() {
    local d="$1"
    rm -rf "$d"; mkdir -p "$d"
    pdftoppm -png -r 100 -f 1 -l 1 "$FIXTURE" "$d/page" >/dev/null 2>&1 || return 1
    [[ -n "$(find "$d" -name '*.png' -print -quit)" ]] || return 1
}

# $1 = label, $2 = expected rc, $3.. = command
check() {
    local label="$1" want="$2"; shift 2
    local out rc
    out="$("$@" 2>&1)"; rc=$?
    if [[ "$rc" == "$want" ]]; then
        PASS=$((PASS+1)); printf '  PASS %-42s rc=%s\n' "$label" "$rc"
    else
        FAIL=$((FAIL+1)); printf '  FAIL %-42s rc=%s (wanted %s)\n' "$label" "$rc" "$want"
        printf '%s\n' "$out" | sed 's/^/         | /' | tail -6
    fi
}

echo "=== paired mutation proof: _tools/containers/cmd/ocr ==="

# ---- M0 CONTROL: the real workload still says 0, on a real page -------------
# If this fails, every "the mutation was caught" line below is worthless: a
# program that always fails catches every mutation and detects nothing.
if seed_pages "$T/control"; then
    check "M0 CONTROL real compose OCRs a real page" 0 \
        "$BIN" -root "$ROOT" -dir "$T/control"
    # ...and the control must have produced a NON-EMPTY transcript, not merely
    # exited 0. Asserting only on rc would let a green exit stand for nothing.
    if [[ -s "$(find "$T/control" -name '*.ocr.txt' -print -quit 2>/dev/null)" ]]; then
        PASS=$((PASS+1)); printf '  PASS %-42s\n' "M0b CONTROL wrote a non-empty transcript"
    else
        FAIL=$((FAIL+1)); printf '  FAIL %-42s\n' "M0b CONTROL wrote NO non-empty transcript"
    fi
else
    echo "UNDETERMINED: could not rasterise the fixture with pdftoppm"; exit 2
fi

# ---- M1: no-op container, FRESH directory -> must be a FAILURE, not a pass --
if seed_pages "$T/m1"; then
    check "M1 no-op container, no transcript at all" 1 \
        "$BIN" -root "$ROOT" -dir "$T/m1" -compose "$NOOP"
fi

# ---- M2: no-op container, STALE transcripts already present ----------------
# The load-bearing mutation. OCR output lands beside its input, so a leftover
# transcript is indistinguishable from a fresh one to any check that merely
# asks "does a .ocr.txt exist?". cmd/ocr must require it to be NEWER.
if seed_pages "$T/m2"; then
    for p in "$T/m2"/*.png; do printf 'stale transcript from an earlier run\n' > "${p%.png}.ocr.txt"; done
    sleep 1   # make "strictly newer" a decidable question on 1s-granularity fs
    check "M2 no-op container, STALE transcripts present" 1 \
        "$BIN" -root "$ROOT" -dir "$T/m2" -compose "$NOOP"
fi

# ---- M3: no runtime at all -> COULD NOT DETERMINE, never a pass, never a FAIL
# An empty PATH is DATA. Blaming a document for a missing runtime would be a
# false accusation, which is why this is 2 and not 1.
mkdir -p "$T/emptypath"
if seed_pages "$T/m3"; then
    check "M3 empty PATH (no runtime)" 2 \
        env PATH="$T/emptypath" "$BIN" -root "$ROOT" -dir "$T/m3"
fi

# ---- M4: no input PNGs -> 2. OCR of nothing is not a successful OCR --------
mkdir -p "$T/m4"
check "M4 directory holds no PNGs" 2 \
    "$BIN" -root "$ROOT" -dir "$T/m4"

# ---- M5: unreadable -dir -> 2 ----------------------------------------------
check "M5 -dir does not exist" 2 \
    "$BIN" -root "$ROOT" -dir "$T/does-not-exist"

# ---- M6: unreadable compose file -> 2 --------------------------------------
if seed_pages "$T/m6"; then
    check "M6 compose file unreadable" 2 \
        "$BIN" -root "$ROOT" -dir "$T/m6" -compose "$T/no-such-compose.yml"
fi

# ---- M7: unexpected argv word -> 1 (a caller error IS a real failure) ------
check "M7 unexpected argument" 1 \
    "$BIN" -root "$ROOT" -dir "$T/control" stray-word

echo
echo "RESULT: $PASS passed / $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
