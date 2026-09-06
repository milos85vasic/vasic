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
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FIX="$HERE/selfvalidate-fixtures"
VALIDATOR="$HERE/validate.mjs"
OUT="${1:-$ROOT/_tests/evidence/harness/portfolio}"
mkdir -p "$OUT"

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
else
  echo "  FAIL: golden-good expected PASS (rc=0) but rc=$GOOD_RC"; FAILED=1
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
else
  echo "  FAIL: golden-bad expected DETECTION (rc=1) but rc=$BAD_RC"; FAILED=1
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
