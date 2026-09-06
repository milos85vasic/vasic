#!/usr/bin/env bash
# =============================================================================
# PAIRED MUTATION PROOF for _tests/preflight.js (§1.1).
#
# A gate that cannot fail proves nothing. This script builds a THROWAWAY repo
# skeleton in a scratch directory, copies the real preflight into it unchanged,
# and drives it against fixture trees that each seed exactly one fault.
#
# Every mutation is DATA — a fixture spec file, a missing directory, a browser
# name — never an edit to preflight.js. A proof that mutates the code it is
# proving tests a program that will never ship; the constitution's own wording
# for that is an "inoperative proof", and the registry documents it as a real
# defect class rather than a hypothetical one.
#
# The CONTROL matters as much as the mutations: M0 asserts the preflight can
# still say READY. Without it, "every mutation was caught" is satisfied by a
# program that returns 2 unconditionally, which catches everything and detects
# nothing.
#
#   exit 0  every mutation was caught AND the control passed
#   exit 1  a mutation slipped through, or the control failed
#   exit 2  the proof could not run (no node, no playwright) — never a pass
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v node >/dev/null 2>&1 || { echo "UNDETERMINED: node is not on PATH"; exit 2; }
[[ -d "$HERE/node_modules/@playwright/test" ]] || {
    echo "UNDETERMINED: _tests/node_modules/@playwright/test absent — run: (cd _tests && npm ci)"; exit 2; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

PASS=0; FAIL=0

# ---- skeleton ---------------------------------------------------------------
# A repo shaped exactly like the real one, so preflight's own path arithmetic
# (REPO = dirname(_tests)) is exercised rather than bypassed.
build_skeleton() {
    rm -rf "$T/repo"
    mkdir -p "$T/repo/_tests/tests" "$T/repo/vasic.digital" "$T/repo/milosvasic.ru/_site"
    cp "$HERE/preflight.js" "$T/repo/_tests/preflight.js"
    cp "$HERE/env.js"       "$T/repo/_tests/env.js"
    ln -s "$HERE/node_modules" "$T/repo/_tests/node_modules"
    echo '<html></html>' > "$T/repo/vasic.digital/index.html"
    echo '<html></html>' > "$T/repo/milosvasic.ru/_site/index.html"
}

# $1 = projects JS array literal, $2 = testIgnore JS literal (or 'null')
#
# printf, NOT an unquoted heredoc. An unquoted heredoc collapses backslashes, so
# a testIgnore of /ignored\.spec\.js/ arrived in the fixture as /ignored\\.spec\\.js/
# — a regex matching a literal backslash, which matches no filename. That made
# M4 fail and look like a preflight defect; it was this line. printf's %s does
# not touch backslashes in the ARGUMENT, only in the format string.
write_config() {
    printf 'module.exports = { testDir: "tests", testIgnore: %s, projects: %s };\n' \
        "$2" "$1" > "$T/repo/_tests/playwright.config.js"
}

# $1 = spec filename, $2 = body
write_spec() { printf '%s\n' "$2" > "$T/repo/_tests/tests/$1"; }

run_preflight() { ( cd "$T/repo/_tests" && node preflight.js --json "$@" 2>&1 ); }

# $1 = label, $2 = expected rc, $3 = a string the JSON must contain ('' = any)
assert() {
    local label="$1" want="$2" needle="$3" out rc
    out="$(run_preflight "${@:4}")"; rc=$?
    if [[ "$rc" != "$want" ]]; then
        echo "  FAIL $label — expected rc $want, got $rc"
        printf '%s\n' "$out" | head -6 | sed 's/^/        /'
        FAIL=$((FAIL+1)); return
    fi
    if [[ -n "$needle" ]] && ! printf '%s' "$out" | grep -qF "$needle"; then
        echo "  FAIL $label — rc $want as expected, but output lacks: $needle"
        printf '%s\n' "$out" | head -8 | sed 's/^/        /'
        FAIL=$((FAIL+1)); return
    fi
    echo "  PASS $label"
    PASS=$((PASS+1))
}

echo "=== prove-preflight.sh — mutations are DATA, preflight.js is never edited ==="

# ---- M0 CONTROL: a healthy tree must be READY -------------------------------
# Vacuity control. chromium is the browser gate 6 actually uses; probing only it
# keeps this proof from failing on a host that simply lacks webkit's libraries —
# which is a real state of THIS host and not a defect in the preflight.
build_skeleton
write_config "[{name:'chromium'}]" "null"
write_spec 'ok.spec.js' "const { VD_BASE: VD, MV_BASE: MV } = require('../env.js');
test('a', async ({ page }) => { await page.goto(\`\${VD}/\`); await page.goto(\`\${MV}/\`); });"
assert "M0 control — healthy tree is READY" 0 '"ready": true' --project=chromium

# ---- M1: a route the spec requests is absent from the served root -----------
# This is today's live fault in miniature: the page exists in the milosvasic.ru
# SOURCE but not under _site, which is what the harness serves.
write_spec 'missing.spec.js' "const { MV_BASE: MV } = require('../env.js');
test('b', async ({ page }) => { await page.goto(\`\${MV}/products/ru/catalogizer.html\`); });"
assert "M1 missing route is caught" 2 'products/ru/catalogizer.html' --project=chromium

# ---- M2: a browser that cannot launch ---------------------------------------
# Named deliberately so the probe must reject it rather than skip it silently.
build_skeleton
write_config "[{name:'chromium'}]" "null"
write_spec 'ok.spec.js' "const { VD_BASE: VD } = require('../env.js');
test('a', async ({ page }) => { await page.goto(\`\${VD}/\`); });"
assert "M2 unknown browser type is caught" 2 'no browser type' --project=nosuchbrowser

# ---- M3: the served root does not exist at all ------------------------------
build_skeleton
write_config "[{name:'chromium'}]" "null"
write_spec 'ok.spec.js' "const { VD_BASE: VD } = require('../env.js');
test('a', async ({ page }) => { await page.goto(\`\${VD}/\`); });"
rm -rf "$T/repo/milosvasic.ru/_site"
assert "M3 absent served root is caught" 2 'jekyll build' --project=chromium

# ---- M4: testIgnore is HONOURED ---------------------------------------------
# A route requested only by an ignored spec must NOT be demanded. Without this,
# the preflight would fail this host for files it is correct not to have — the
# three live-only specs request production routes that _site never carries.
build_skeleton
write_config "[{name:'chromium'}]" "/ignored\\.spec\\.js/"
write_spec 'ignored.spec.js' "const { MV_BASE: MV } = require('../env.js');
test('c', async ({ page }) => { await page.goto(\`\${MV}/only-on-the-live-site.html\`); });"
assert "M4 ignored spec's route is not demanded" 0 '"ready": true' --project=chromium

# ---- M5: a computed route is reported, never guessed ------------------------
# `${MV}/${lang}/index.html` cannot be resolved without running the spec. It is
# reported as computed and must not manufacture a MISSING row — a preflight that
# invents a path would go red on a route no spec ever requests.
build_skeleton
write_config "[{name:'chromium'}]" "null"
write_spec 'computed.spec.js' "const { MV_BASE: MV } = require('../env.js');
const lang='ru';
test('d', async ({ page }) => { await page.goto(\`\${MV}/\${lang}/index.html\`); });"
assert "M5 computed route does not fabricate a MISSING" 0 '"route": "/${lang}/index.html"' --project=chromium

# ---- M6: the contract — this program NEVER exits 1 --------------------------
# Exit 1 is a claim about site CONTENT, and a preflight has read no content.
# Asserted across every state above rather than argued in a comment.
build_skeleton
write_config "[{name:'chromium'}]" "null"
write_spec 'missing.spec.js' "const { MV_BASE: MV } = require('../env.js');
test('e', async ({ page }) => { await page.goto(\`\${MV}/nope.html\`); });"
out="$(run_preflight --project=chromium)"; rc=$?
if [[ "$rc" == "1" ]]; then
    echo "  FAIL M6 contract — preflight exited 1, which is a content claim it cannot make"
    FAIL=$((FAIL+1))
else
    echo "  PASS M6 contract — a fault yields $rc, never 1"
    PASS=$((PASS+1))
fi

# ---- M7: a spec with no env binding is not silently counted -----------------
# A spec that never imports env.js requests nothing this preflight can resolve;
# it must contribute zero routes rather than a confident zero-missing.
build_skeleton
write_config "[{name:'chromium'}]" "null"
write_spec 'nobind.spec.js' "test('f', async ({ page }) => { await page.goto('http://example.invalid/x'); });"
assert "M7 unbound spec contributes no routes" 0 '"checked": 0' --project=chromium

echo
echo "prove-preflight: $PASS passed / $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
