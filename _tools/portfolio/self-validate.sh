#!/usr/bin/env bash
# §1.1 anti-bluff mutation self-test for the portfolio DATA validator.
#
# A gate that cannot FAIL is a rubber stamp. This harness proves the portfolio
# validator (_tools/portfolio/validate.mjs) is mutation-paired:
#   - golden-GOOD fixture MUST PASS      (validate.mjs exits EXACTLY 0)
#   - golden-BAD  fixture MUST be DETECTED (validate.mjs exits EXACTLY 1)
# It exits 0 only if BOTH hold, and writes verdict evidence JSON under
# _tests/evidence/harness/portfolio/ (good.verdict.json, bad.verdict.json),
# mirroring the export/visual self-validate evidence style.
#
# WHY "EXACTLY 1" AND NOT "non-zero" (§1.1, §11.4.6).
# This assertion used to read `[ "$BAD_RC" -ne 0 ]`, i.e. ANY failure counted
# as proof the mutation was caught. It was not proof of anything: validate.mjs
# exited 1 both for a genuine detected violation AND for "cannot read / cannot
# parse". A MISSING OR CORRUPT golden-BAD fixture therefore read as a caught
# mutation and this gate printed SATISFIED having evaluated zero assertions.
# Measured: deleting bad.json, and replacing it with `{ this is not json`,
# BOTH produced "SELF-VALIDATION RESULT: PASS ... SATISFIED", exit 0.
#
# The fix is TWO-PART and neither half works alone — tightening this assertion
# while validate.mjs still returned 1 for a parse error would have kept the
# hole open while looking closed. validate.mjs now exits 2 for any
# could-not-evaluate condition (see its header), and only then can this
# harness demand the exact DETECTION code.
#
# Three-valued exit, this fleet's convention (2 is NEVER a pass):
#   0 = both arms behaved as required
#   1 = the validator is not mutation-paired (a real finding about the gate)
#   2 = the self-test could not be carried out (fixture or toolchain fault)
# Precedence: a real finding (1) outranks could-not-determine (2), so a
# broken arm can never be masked by an undetermined one.
#
# AN UNRECOGNISED EXIT IS UNDETERMINED — a defect, measured 2026-09-06.
# run_case() already mapped any rc outside {0,1,2} to UNDETERMINED in the
# verdict JSON, and the comment there says so in its own words: "an
# unrecognised exit proves nothing". The ASSERTION block below ignored that
# mapping and re-tested the raw rc, so anything that was not 0/1/2 fell
# through to the FAIL arm. Driven with `node` hidden behind a PATH stub
# (rc 127), this harness printed
#   `SELF-VALIDATION RESULT: FAIL  (validator is not mutation-paired)`
# and exited **1** — a MISSING TOOLCHAIN reported as a confirmed finding about
# the validator, while its own evidence file recorded verdict=UNDETERMINED.
# The exit code and the evidence contradicted each other. The two arms below
# now branch on the same three-valued vocabulary run_case uses.
#
# Usage:
#   bash _tools/portfolio/self-validate.sh [OUT_DIR]
#   bash _tools/portfolio/self-validate.sh --out DIR --fixtures DIR --validator PATH
#   bash _tools/portfolio/self-validate.sh --prove-failure
#
# §1.1 PAIRED MUTATION PROOF for THIS HARNESS: `--prove-failure`. It proves the
# harness itself reports the right verdict when the validator or the fixtures
# are broken. Every mutation is DATA — stub validator files and fixture files
# written under mktemp, plus a PATH stub — never an edit to this script.
set -u

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIX="$HERE/selfvalidate-fixtures"
VALIDATOR="$HERE/validate.mjs"
OUT=""
PROVE=0

# A bare positional OUT dir is still accepted: scripts/pre-push-gates.sh and
# _tests/GATES.md both call this with no arguments at all, and the historical
# one-argument form must keep working.
while [ $# -gt 0 ]; do
  case "$1" in
    --out)           shift; OUT="${1:-}" ;;
    --fixtures)      shift; FIX="${1:-}" ;;
    --validator)     shift; VALIDATOR="${1:-}" ;;
    --prove-failure) PROVE=1 ;;
    -h|--help)       sed -n '/^# Usage:/,/^# ===/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "self-validate.sh: unknown option '$1'" >&2; exit 2 ;;
    *)  OUT="$1" ;;
  esac
  shift
done
OUT="${OUT:-$ROOT/_tests/evidence/harness/portfolio}"

# Run validate.mjs against a fixture, capture output + rc, and emit a verdict
# JSON. Args: <fixture-path> <name> <expected-verdict PASS|FAIL>
run_case() {
  fixture="$1"; name="$2"; expect="$3"
  log="$OUT/$name.output.txt"
  node "$VALIDATOR" --file "$fixture" >"$log" 2>&1
  rc=$?
  # Three-valued, mirroring validate.mjs. Anything that is not a recognised
  # code is UNDETERMINED too — an unrecognised exit proves nothing.
  case "$rc" in
    0) verdict="PASS" ;;
    1) verdict="FAIL" ;;
    *) verdict="UNDETERMINED" ;;
  esac
  node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    // `node -e` has no __dirname; the caller passes the repo root as the last
    // argument so this stays anchored on the location of this script, never on cwd.
    const argv = process.argv.slice(1);
    const __dirname_shim = argv.pop();
    const [fixture, name, expect, rcStr, verdict, logFile, outFile] = argv;
    const lines = fs.readFileSync(logFile, "utf8").split("\n").filter(Boolean);
    // Deterministic provenance stamp. A caller-pinned SOURCE_DATE_EPOCH (the
    // reproducible-builds convention this repo already follows in
    // _tools/gen/build.sh and _tools/pdf/build-pdfs.sh) yields a real,
    // reproducible generatedAt. With it unset we OMIT the field rather than
    // embed a wall clock: this verdict is COMMITTED evidence (_tests/GATES.md
    // cites it for the portfolio §1.1 gate), and an embedded clock made it
    // permanently dirty on every run. Mirrors the sibling convention in
    // design-toolkit/qa/run-checks.mjs (generatedAt_omitted_for_determinism).
    const sde = process.env.SOURCE_DATE_EPOCH;
    const provenance = (sde && /^[0-9]+$/.test(sde))
      ? { generatedAt: new Date(Number(sde) * 1000).toISOString() }
      : { generatedAt_omitted_for_determinism: true };
    // CHECKOUT-INDEPENDENT, for the same reason the timestamp above is omitted.
    // This file is COMMITTED evidence, and `fixture` was recorded as an
    // ABSOLUTE path — so it encoded WHERE the repository happened to sit and
    // every run from a different checkout rewrote a tracked file. The committed
    // copies still carry a path from a checkout that is not this one, right
    // beside `generatedAt_omitted_for_determinism: true`: the clock was made
    // reproducible and the path was not. A path outside the repository is left
    // absolute deliberately — a `../../..` string would be more
    // checkout-dependent, not less.
    const repoRoot = path.resolve(__dirname_shim, "..", "..");
    const relFixture = (() => {
      if (!path.isAbsolute(fixture)) return fixture;
      const rel = path.relative(repoRoot, fixture);
      return (rel && !rel.startsWith("..")) ? rel : fixture;
    })();
    const doc = {
      schema: "portfolio-validator/1",
      ...provenance,
      validator: "_tools/portfolio/validate.mjs",
      fixture: relFixture,
      name,
      expected: expect,
      rc: Number(rcStr),
      verdict,
      match: (verdict === expect),
      output: lines,
    };
    fs.writeFileSync(outFile, JSON.stringify(doc, null, 2) + "\n");
  ' "$fixture" "$name" "$expect" "$rc" "$verdict" "$log" "$OUT/$name.verdict.json" "$HERE"
  echo "$rc"
}

# -----------------------------------------------------------------------------
# §1.1 PAIRED MUTATION PROOF for THIS HARNESS  —  --prove-failure
#
# self-validate.sh is itself the mutation proof for validate.mjs. That leaves
# one question open, and it is the one §1.1 actually asks: does THIS harness
# report the right verdict when the thing it guards is broken? The battery
# below answers it by handing the REAL entry point stub validators and mutated
# fixtures — DATA under mktemp — through --validator / --fixtures, plus a PATH
# stub for the absent-toolchain case. This script's own source is never edited.
#
#   0  every mutation produced the required verdict
#   1  a mutation was not caught, or was caught with the wrong verdict
#   2  the proof could not be carried out (no sandbox / no node) — never a pass
# -----------------------------------------------------------------------------
if [ "$PROVE" -eq 1 ]; then
  echo "PORTFOLIO SELF-VALIDATE §1.1 PAIRED MUTATION PROOF"
  echo "----------------------------------------------------------------------"
  P_PASS=0; P_FAIL=0
  p_ok(){  P_PASS=$((P_PASS+1)); printf '✅ %-34s %s\n' "$1" "$2"; }
  p_bad(){ P_FAIL=$((P_FAIL+1)); printf '❌ %-34s %s\n' "$1" "$2"; }

  command -v node >/dev/null 2>&1 || {
    echo "UNDETERMINED: node is not on PATH, so the control cannot be established" >&2
    echo "  and no mutation verdict would mean anything. This is NOT a pass." >&2; exit 2; }

  SB="$(mktemp -d "${TMPDIR:-/tmp}/portfolio-proof.XXXXXX")" || {
    echo "UNDETERMINED: cannot create a sandbox, so nothing was proved." >&2; exit 2; }
  trap 'rm -rf "$SB"' EXIT INT TERM

  # Fresh copy of the real fixtures for every case; mutations edit the COPY.
  mk_fixtures() {
    rm -rf "$SB/fix"; mkdir -p "$SB/fix"
    cp "$FIX/good.json" "$SB/fix/good.json" || return 1
    cp "$FIX/bad.json"  "$SB/fix/bad.json"  || return 1
  }
  mk_fixtures || { echo "UNDETERMINED: the real fixtures could not be copied; no control." >&2; exit 2; }

  # A stub validator is a FIXTURE FILE, not a patched program: it stands in for
  # validate.mjs so the harness's own reaction can be observed.
  mk_stub_validator() { printf 'process.exit(%s);\n' "$1" >"$SB/stub-$1.mjs"; }
  mk_stub_validator 0; mk_stub_validator 1; mk_stub_validator 3

  mkdir -p "$SB/nonode"
  printf '#!/bin/sh\necho "node: command not found" >&2\nexit 127\n' >"$SB/nonode/node"
  chmod 755 "$SB/nonode/node"

  n=0
  expect() {  # <label> <want-rc> [env-prefix] -- <extra args...>
    local label="$1" want="$2"; shift 2
    local out rc
    n=$((n+1))
    out="$(bash "$SELF" --out "$SB/out$n" "$@" 2>&1)"; rc=$?
    if [ "$rc" -eq "$want" ]; then
      p_ok "$label" "rc=$rc as required"
    else
      p_bad "$label" "expected rc=$want, got rc=$rc — $(printf '%s' "$out" | grep -m1 -E 'SELF-VALIDATION RESULT|UNDETERMINED' | head -c 110)"
    fi
  }

  expect "CONTROL real validator+fixtures" 0 --fixtures "$SB/fix"

  expect "M1 validator that always passes"  1 --fixtures "$SB/fix" --validator "$SB/stub-0.mjs"
  expect "M2 validator that always fails"   1 --fixtures "$SB/fix" --validator "$SB/stub-1.mjs"

  mk_fixtures; rm -f "$SB/fix/bad.json"
  expect "M3 golden-BAD fixture deleted"    2 --fixtures "$SB/fix"

  mk_fixtures; printf '{ this is not json' >"$SB/fix/bad.json"
  expect "M4 golden-BAD fixture corrupt"    2 --fixtures "$SB/fix"

  mk_fixtures; rm -f "$SB/fix/good.json"
  expect "M5 golden-GOOD fixture deleted"   2 --fixtures "$SB/fix"

  mk_fixtures
  expect "M6 validator outside 0/1/2"       2 --fixtures "$SB/fix" --validator "$SB/stub-3.mjs"
  expect "M7 fixtures directory absent"     2 --fixtures "$SB/no-such-fixtures"

  # M8: the toolchain itself is gone. This is the case that used to read FAIL.
  n=$((n+1))
  m8_out="$(PATH="$SB/nonode:$PATH" bash "$SELF" --out "$SB/out$n" --fixtures "$SB/fix" 2>&1)"; m8_rc=$?
  if [ "$m8_rc" -eq 2 ]; then
    p_ok "M8 node absent (PATH stub)" "rc=2 as required"
  else
    p_bad "M8 node absent (PATH stub)" "expected rc=2, got rc=$m8_rc — $(printf '%s' "$m8_out" | grep -m1 'SELF-VALIDATION RESULT' | head -c 110)"
  fi

  mk_fixtures
  expect "CONTROL restored" 0 --fixtures "$SB/fix"

  echo "----------------------------------------------------------------------"
  if [ "$P_FAIL" -gt 0 ]; then
    echo "❌ PORTFOLIO SELF-VALIDATE §1.1 PROOF: FAIL — $P_FAIL of $((P_PASS + P_FAIL)) case(s) did not behave as required."
    exit 1
  fi
  echo "✅ PORTFOLIO SELF-VALIDATE §1.1 MUTATION PROOF: PASS — a control passed twice and"
  echo "   8 mutations were each caught with the right THREE-VALUED verdict. M6 and M8 are"
  echo "   the pair that used to read FAIL: an exit outside the validator's 0/1/2 contract,"
  echo "   and an absent interpreter, are COULD-NOT-DETERMINE, not an accusation."
  exit 0
fi

# ORDER MATTERS HERE. The subject is checked BEFORE the evidence directory is
# created, so `--fixtures /nonexistent` reaches its rc 2 without this script
# having written anything — and the default OUT is tracked evidence under
# _tests/, which a probe must not touch. Reversing these two lines would make
# the registry's rc-2 probe dirty the working tree on every run.
[ -d "$FIX" ] || { echo "UNDETERMINED: fixture directory does not exist: $FIX" >&2
                   echo "  Neither arm has a subject, so nothing was proved (§11.4.6)." >&2; exit 2; }
[ -f "$VALIDATOR" ] || { echo "UNDETERMINED: validator does not exist: $VALIDATOR" >&2; exit 2; }

# The evidence directory must exist before either arm runs; if it cannot be
# created, no verdict file can be written and nothing is demonstrable.
mkdir -p "$OUT" || { echo "UNDETERMINED: cannot create the evidence directory $OUT" >&2; exit 2; }

echo "=================================================================="
echo " §1.1 PORTFOLIO DATA VALIDATOR — MUTATION SELF-VALIDATION"
echo "=================================================================="
# GATE: PORTFOLIO-DATA-INTEGRITY (§1.1) — this self-validation IS the check that
# satisfies the portfolio-data-integrity gate. It is NOT a CM-OPENDESIGN-UI-SYSTEM
# check (that gate is design-token/no-ad-hoc-CSS; see _tests/GATES.md for the
# honest, partial evidence that currently stands in for CM-OPENDESIGN-UI-SYSTEM).
echo "GATE: PORTFOLIO-DATA-INTEGRITY (§1.1)"

echo; echo ">>> GOLDEN-GOOD (expect PASS) ......................................"
GOOD_RC="$(run_case "$FIX/good.json" golden-good PASS)"
cat "$OUT/golden-good.output.txt"

echo; echo ">>> GOLDEN-BAD  (expect FAIL) ......................................"
BAD_RC="$(run_case "$FIX/bad.json" golden-bad FAIL)"
cat "$OUT/golden-bad.output.txt"

echo; echo "=================================================================="
echo " ASSERTIONS"
echo "=================================================================="
FAILED=0
UNDET=0

# GOOD arm: must be EXACTLY 0. rc 2 means the good fixture could not be
# evaluated — that is a harness fault, not the validator being wrong.
if [ "$GOOD_RC" -eq 0 ]; then
  echo "  PASS: golden-good verdict=PASS (rc=$GOOD_RC)"
elif [ "$GOOD_RC" -eq 2 ]; then
  echo "  UNDET: golden-good COULD NOT BE EVALUATED (rc=2) — fixture missing/corrupt or toolchain fault"; UNDET=1
elif [ "$GOOD_RC" -eq 1 ]; then
  echo "  FAIL: golden-good expected PASS (rc=0) but the validator REJECTED it (rc=1)"; FAILED=1
else
  # Outside the validator's own 0/1/2 contract — the same class run_case
  # records as UNDETERMINED. A crashed or absent interpreter lands here, and it
  # is not evidence that the validator is unpaired.
  echo "  UNDET: golden-good returned rc=$GOOD_RC, outside the validator's 0/1/2 contract"
  echo "         (an absent or crashed toolchain looks like this); nothing was proved"; UNDET=1
fi

# BAD arm: must be EXACTLY 1 — the DETECTION code, and nothing else.
# rc 0 = the seeded mutation went unnoticed (the gate cannot fail: a real
#        finding about the gate).
# rc 2 = the validator never got far enough to judge, so this run proves
#        NOTHING about whether the mutation would be caught. It is not a pass
#        and it must never again be counted as one.
if [ "$BAD_RC" -eq 1 ]; then
  echo "  PASS: golden-bad DETECTED (rc=1 — assertions evaluated and violated)"
elif [ "$BAD_RC" -eq 2 ]; then
  echo "  UNDET: golden-bad COULD NOT BE EVALUATED (rc=2) — fixture missing/corrupt;"
  echo "         this run proves NOTHING about whether the mutation is caught"; UNDET=1
elif [ "$BAD_RC" -eq 0 ]; then
  echo "  FAIL: golden-bad expected DETECTION (rc=1) but the validator PASSED it (rc=0)"
  echo "        — the seeded mutation went unnoticed; the gate cannot fail"; FAILED=1
else
  echo "  UNDET: golden-bad returned rc=$BAD_RC, outside the validator's 0/1/2 contract"
  echo "         (an absent or crashed toolchain looks like this); nothing was proved"; UNDET=1
fi

echo
echo "Evidence:"
echo "  $OUT/golden-good.verdict.json"
echo "  $OUT/golden-bad.verdict.json"
echo
# Precedence: real finding (1) outranks could-not-determine (2) outranks clean.
if [ "$FAILED" -ne 0 ]; then
  echo "SELF-VALIDATION RESULT: FAIL  (validator is not mutation-paired)"
  echo "GATE: PORTFOLIO-DATA-INTEGRITY (§1.1) — NOT SATISFIED"
  exit 1
elif [ "$UNDET" -ne 0 ]; then
  echo "SELF-VALIDATION RESULT: UNDETERMINED  (the self-test could not be carried out)"
  echo "GATE: PORTFOLIO-DATA-INTEGRITY (§1.1) — COULD NOT DETERMINE (rc=2, NOT a pass)"
  exit 2
else
  echo "SELF-VALIDATION RESULT: PASS  (good=PASS rc=0, bad=DETECTED rc=1 as required)"
  echo "GATE: PORTFOLIO-DATA-INTEGRITY (§1.1) — SATISFIED"
  exit 0
fi
