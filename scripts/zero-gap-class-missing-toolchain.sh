#!/usr/bin/env bash
# zero-gap-class-missing-toolchain.sh — sweep class `missing-toolchain` (feature 010, task T026).
#
# WHAT IT DETECTS (§11.4.18)
#   Host tools/libraries whose ABSENCE makes a gate exit 2 (never a pass) with NO usable container
#   route. Each is an Operator-blocked item: the finding carries the catalogued remedy and the gate(s)
#   that stay rc 2 because of it. Every remedy is an operator action; this class never installs,
#   builds, starts a container or pulls an image, and only reads (stat and PATH lookups).
#
# POPULATION (docs/zero-gap/sweep-classes.tsv row `missing-toolchain`; derived, never a hand list)
#   1. tool:<name>     one item per row of the tracked catalogue docs/zero-gap/toolchains.tsv.
#                      Each row is probed on the host: `command -v <tool>` is answered by an
#                      external-command PATH lookup (type -P), `dpkg-query -W <pkg>` by
#                      `dpkg-query -W -f '${Status}'` (present iff "install ok installed").
#                      Any other probe text is COULD-NOT-INSPECT (the probe is never eval'd).
#   2. derived:<tool>  one item per tool named by a `command -v X`, `type -P X`, `which X` or
#                      `need X` precondition in the tracked scripts/verify-*.sh, scripts/prove-*.sh
#                      and the tracked `check` entrypoints of scripts/check-registry.tsv, that has
#                      NO catalogue row (drift check: the catalogue must not lag the gates).
#                      Comment lines, echo/printf lines and heredoc bodies are skipped.
#   Items 2 are ADDITIONS to the catalogue population (controller ruling, feature-010 class review):
#   the tsv row names the catalogue; the derived drift check and the docs-drift check below extend it.
#   SELF-SCAN EXCLUSION (T038 review rev-base-A; shared rule): files under _tests/fixtures/zero-gap/
#   and every scripts/zero-gap-class-*.sh are never scanned, even when registered as a `check`: their
#   proof and self-test text (maybetool, newghost, zgselftest ...) is not a precondition of any gate.
#   The exclusion is by path name only (proof P20: the same text in a verify-*.sh is still derived).
#
# CATALOGUE (six tab-separated columns): tool probe gate_that_needs_it remedy source container_route.
#   container_route is `none`, or `src=<tracked resolver source> bin=<built resolver> build=<build tool>
#   runtime=<rt>[,<rt>...]` (repo-relative paths; `..`, a leading `/` or any other form is an
#   unparseable row => COULD-NOT-INSPECT). bundle, jekyll and tesseract carry routes because the
#   operator decided they are CONTAINER WORKLOADS, never host packages (docs/OPERATOR-DECISIONS-2026-
#   09-07.md #10, docs/OPERATOR-DECISIONS-2026-09-09.md #4; _tests/export/validate-pdf.js
#   resolveOcrEngine and _tests/preflight.js name those routes).
#
# FINDINGS
#   tool:<t>     medium host-capability   catalogued tool absent from the probe PATH AND (route `none`
#                OR the route is unusable). A route is USABLE when its resolver source is a tracked
#                regular file, its resolver binary is a built regular executable OR its build tool is
#                on the probe PATH, and at least one listed runtime is on the probe PATH; then the
#                item is inspected and NOT reported (a stderr note names the route). No finding, not
#                even a low one: the gate runs through the route, so there is no Operator-blocked item.
#                The route check is STRUCTURAL: it does not check the compose provider, the image, the
#                network or that the workload succeeds end to end (UNCONFIRMED by this class).
#                A symlinked route source/binary is COULD-NOT-INSPECT (never followed).
#                A row whose gate column starts with UNCONFIRMED is registered only when a scanned
#                script names the tool as a precondition; otherwise it is inspected and not
#                reported (no measured gate exits 2 on it — docker on this host).
#   tool:<t>     low docs-drift           catalogued tool PRESENT while CLAUDE.md or CONTINUATION.md
#                still has a line naming it with `NOT INSTALLED`, `is absent`, `are absent`,
#                `all absent` or `MISSING` and no WITHDRAWN/SUPERSEDED/no longer/was true when
#                marker on that line (dated withdrawn claims are history, not drift).
#   derived:<t>  governance-drift "catalogue missing derived tool": a gate probes <t>, no catalogue
#                row exists, and <t> is absent on this host.  Severity (controller ruling):
#                HIGH only when a probe site is followed by `exit 2`, `return 2` or an undet* call
#                in command position — on the probe line itself, or, when the probe OPENS a block
#                (`if`, trailing `{` `||` `&&` `\`), within the next 3 lines up to fi / else / elif
#                / } / done / esac; the evidence_ref is that site.  Otherwise LOW (an optional or
#                fallback probe: no gate is shown to exit 2 on it).  A derived tool that IS present
#                is inspected but not reported: it cannot make a gate exit 2 here.
#
# FAIL CLOSED.  Every tool the class itself runs (awk perl iconv sort xargs sha256sum od sed tr cut
#   head wc find mktemp, plus git on a live run) must be on PATH, else each missing one is
#   `COULD-NOT-INSPECT host-tool:<t>` and rc 2 (a missing iconv is never reported as bad UTF-8).
#   The perl precondition scanner must pass a self-test (a stub perl that prints nothing fails it)
#   and its xargs exit status must be 0; otherwise rc 2 with NO partial findings — the derived
#   population is never silently dropped.  A catalogue tool name must start with a letter or digit
#   (`..` is an unparseable row, never a `tool:..` token).
#
# PATH SEMANTICS — RESULTS DEPEND ON THE CALLER'S PATH, AND THAT IS RECORDED, NOT HIDDEN.
#   The probe uses the PATH this process received (the runner passes the caller's PATH through its
#   env -i allow-list). No extra directories are added: no gate in this tree searches ~/.nvm or
#   /snap/bin (git grep finds neither outside this header), so a gate run under a PATH lacking them
#   really does miss node/glab, and widening the search here would report a tool the gate cannot see.
#   Instead the FIRST stderr line is `[class missing-toolchain] probe PATH (sha256 <12 hex>; HOME
#   shown as ~): <PATH>` and every host-dependent finding text carries that sha256 prefix, so two
#   registers measured under different PATHs are distinguishable (proof P22).
#   In --corpus mode the probe PATH is <corpus>/bin only, so a corpus plants present tools as stubs.
#
# EXIT CODES: 0 clean (full non-empty population inspected, no finding); 1 at least one FINDING;
#   2 could not determine (absent/unparseable catalogue, empty population, unavailable dpkg-query
#   for a dpkg probe, bad flags, --root not a directory). A finding outranks an undetermined.
#
# WHAT IT DOES NOT SEE
#   * A precondition built from a variable (`command -v "$b"` in a loop) or a tool named in prose
#     or in a heredoc; a tool required through a wrapper other than the four idioms above.
#   * Whether a probe's exit 2 sits further away than the block window above, or behind a helper
#     other than undet* (die, fail ...): such a derived tool is reported LOW, not HIGH.
#   * Library dependencies not listed in the catalogue (only dpkg-probed names are checked).
#   * Untracked scripts (the scan set is tracked files only, plus the catalogue read from disk).
#   * A precondition written only inside a scripts/zero-gap-class-*.sh (excluded by name, above).
#   * Whether a usable container route actually runs: compose provider, image, network and the
#     workload's own exit are outside the structural route check; the resolver binary is a stat of
#     an untracked build output (its freshness against the source is not compared).
#   * A runtime detected by the Containers Submodule but not listed in the row (cri-o, lxd,
#     kubernetes): such a host is reported as having no runtime for the route.
#
# MEASURED (live tree, 2026-09-26, fix round F1; three runs byte-identical on stdout AND stderr,
#   about 0.6 s; population 30 under both PATHs, POPULATION-SHA e29e8c17...):
#   * env -i PATH=/usr/local/bin:/usr/bin:/bin (probe PATH sha256 594a1a2ff933): 6 FINDINGs —
#     1 high derived:node (_tools/portfolio/self-validate.sh:171 exits 2 without node), 5 low
#     derived: docs_chain (verify-docs-chain.sh:141 falls back to a built binary), glab
#     (verify-provider-ci.sh:876 records a state), ifconfig (ollama-tune.sh:424 after `ip`), lumen
#     (test-setup-agents-wizard.sh:666 records FAIL, not rc 2), shellcheck (:511 optional leg).
#   * the caller's interactive PATH (node under ~/.nvm, glab under /snap/bin on it): 4 low FINDINGs,
#     the same minus node and glab.
#   All 6 hand-read: each states truthfully that the tool is absent from the recorded probe PATH with
#   no catalogue row, and each severity matches the site (6/6). bundle, jekyll and tesseract are NOT
#   reported: host binaries absent, routes usable (site-build and ocr built, podman on PATH; the
#   ruby:3.3 and tesseract-ocr images were present in `podman images` when hand-checked). The
#   pre-fix baseline's 3 high self-scan FPs (maybetool, newghost, zgselftest) and 3 contradicted
#   mediums are gone (proof P19 asserts the first on every run).
#
# USAGE
#   scripts/zero-gap-class-missing-toolchain.sh --root <dir> [--corpus <dir>] [--emit-population]
#   scripts/zero-gap-class-missing-toolchain.sh --prove-failure
set -uo pipefail

# >>> zg_pct_encode (feature 010 class contract; copy verbatim)
# zg_pct_encode_z: NUL-separated raw items on stdin -> one canonical token per line.
# Every byte outside A-Z a-z 0-9 . _ ~ / + : @ , = - becomes %XX (uppercase hex).
zg_pct_encode_z() {
    LC_ALL=C od -An -v -tx1 | LC_ALL=C awk '
        BEGIN { hx = "0123456789abcdef"; safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~/+:@,=-"; tok = ""; pending = 0 }
        { for (i = 1; i <= NF; i++) {
              if ($i == "00") { print tok; tok = ""; pending = 0; continue }
              pending = 1
              v = (index(hx, substr($i, 1, 1)) - 1) * 16 + index(hx, substr($i, 2, 1)) - 1
              c = (v > 32 && v < 127) ? sprintf("%c", v) : ""
              if (c != "" && index(safe, c) > 0) tok = tok c; else tok = tok "%" toupper($i)
          } }
        END { if (pending) print tok }'
}
# zg_pct_encode <string>: one item -> one canonical token.
zg_pct_encode() { printf '%s\0' "$1" | zg_pct_encode_z; }
# <<< zg_pct_encode

export LC_ALL=C
CLASS=missing-toolchain
CAT_REL=docs/zero-gap/toolchains.tsv
REG_REL=scripts/check-registry.tsv
FIXPFX=_tests/fixtures/zero-gap/
SELF=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
TMP=${TMPDIR:-/tmp}

ROOT="" CORPUS="" EMIT=0 PROVE=0
while [ $# -gt 0 ]; do
    case "$1" in
    --root) ROOT="${2:-}"; shift 2 ;;
    --corpus) CORPUS="${2:-}"; shift 2 ;;
    --emit-population) EMIT=1; shift ;;
    --prove-failure)
        PROVE=1; shift ;;
    *) echo "COULD-NOT-INSPECT - unknown argument: $1"; exit 2 ;;
    esac
done

# ---------------------------------------------------------------------------------------------
# --prove-failure: paired proof on THROWAWAY copies of the corpus (control => 0, planted defect =>
# finding/rc 1, empty population / broken tool / unparseable probe => rc 2, live tree untouched).
# ---------------------------------------------------------------------------------------------
prove_failure() {
    local repo fx work pass=0 fail=0 out rc want got before after n
    repo=$(cd "$(dirname "$SELF")/.." && pwd)
    fx=$repo/${FIXPFX}missing-toolchain
    [ -d "$fx/planted" ] && [ -d "$fx/clean" ] && [ -f "$fx/expect.tsv" ] || { echo "COULD-NOT-INSPECT corpus $fx is incomplete"; return 2; }
    work=$(mktemp -d "$TMP/zg-mt-prove.XXXXXX") || return 2
    # shellcheck disable=SC2064
    trap "rm -rf '$work'" EXIT   # cleanup: the throwaway tree is removed on every exit path
    ok() { echo "  PASS $*"; pass=$((pass + 1)); }
    bad() { echo "  FAIL $*"; fail=$((fail + 1)); }
    fresh() { rm -rf "$work/w"; mkdir -p "$work/w"; cp -R "$fx/planted" "$fx/clean" "$work/w/"; }
    run() { env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$work/w" "$@"; }
    locs() { printf '%s\n' "$1" | awk '$1 == "FINDING" { print $5 }' | LC_ALL=C sort; }
    before=$(cd "$repo" && sha256sum "$SELF" "$fx/expect.tsv" "$repo/$CAT_REL" 2>/dev/null | sha256sum)

    fresh
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    n=$(printf '%s\n' "$out" | grep -c '^FINDING')
    if [ "$rc" -eq 0 ] && [ "$n" -eq 0 ] && grep -q '^INSPECTED [1-9]' <<<"$out"; then ok "P1 control: clean corpus => rc 0, no finding, non-empty population"; else bad "P1 rc=$rc findings=$n"; fi

    out=$(run --corpus "$work/w/planted" 2>&1); rc=$?
    want=$(grep -v '^#' "$fx/expect.tsv" | cut -f1 | LC_ALL=C sort); got=$(locs "$out")
    if [ "$rc" -eq 1 ] && [ "$got" = "$want" ]; then ok "P2 planted corpus => rc 1 and exactly the planted locations"; else bad "P2 rc=$rc got=[$(echo $got)]"; fi

    fresh; rm -f "$work/w/clean/bin/presenttool"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "tool:presenttool" ]; then ok "P3 mutation: a catalogued tool made absent => tool:presenttool, rc 1"; else bad "P3 rc=$rc"; fi

    fresh; printf 'command -v newghost >/dev/null 2>&1 || exit 2\n' >>"$work/w/clean/scripts/verify-uses.sh"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "derived:newghost" ]; then ok "P4 mutation: uncatalogued absent derived tool => derived:newghost, rc 1"; else bad "P4 rc=$rc"; fi

    fresh; printf -- '- `presenttool` is NOT INSTALLED on this host.\n' >>"$work/w/clean/CLAUDE.md"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "tool:presenttool" ] && grep -q ' docs-drift ' <<<"$out"; then ok "P5 mutation: present tool still recorded missing => docs-drift tool:presenttool, rc 1"; else bad "P5 rc=$rc"; fi

    fresh; printf 'command -v maybetool >/dev/null 2>&1 || exit 2\n' >>"$work/w/clean/scripts/verify-uses.sh"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "tool:maybetool" ]; then ok "P6 mutation: an UNCONFIRMED row becomes reportable once a gate names the tool"; else bad "P6 rc=$rc"; fi

    fresh; printf '#!/usr/bin/env bash\nnothing() { :; }\n' >"$work/w/clean/scripts/verify-uses.sh"; printf 'x\n' >"$work/w/clean/scripts/prove-other.sh"
    rm -f "$work/w/clean/scripts/check-registry.tsv"
    : >"$work/w/clean/docs/zero-gap/toolchains.tsv"; printf 'tool\tprobe\tgate_that_needs_it\tremedy\tsource\tcontainer_route\n' >"$work/w/clean/docs/zero-gap/toolchains.tsv"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out"; then ok "P7 empty population (header-only catalogue, no derived tool) => rc 2, never clean"; else bad "P7 rc=$rc"; fi

    fresh; rm -f "$work/w/clean/bin/dpkg-query"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT' <<<"$out"; then ok "P8 broken tool: dpkg-query unavailable for a dpkg probe => rc 2"; else bad "P8 rc=$rc"; fi

    fresh; sed -i.bak 's/^libpresent\tdpkg-query -W libpresent/libpresent\trpm -q libpresent/' "$work/w/clean/docs/zero-gap/toolchains.tsv"; rm -f "$work/w/clean/docs/zero-gap/toolchains.tsv.bak"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q 'unparseable probe' <<<"$out"; then ok "P9 unparseable probe text => rc 2 (never eval'd)"; else bad "P9 rc=$rc"; fi

    fresh; rm -f "$work/w/clean/docs/zero-gap/toolchains.tsv"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ]; then ok "P10 absent catalogue => rc 2"; else bad "P10 rc=$rc"; fi

    fresh; rm -f "$work/w/planted/docs/zero-gap/toolchains.tsv"
    out=$(run --corpus "$work/w/planted" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out"; then ok "P11 a finding-rich corpus without its catalogue is undetermined, not partially clean"; else bad "P11 rc=$rc"; fi

    fresh
    out=$(run --corpus "$work/w/planted" 2>&1); got=$(sed -n 's/^POPULATION-SHA //p' <<<"$out")
    want=$(run --corpus "$work/w/planted" --emit-population 2>/dev/null | sha256sum | cut -d' ' -f1)   # stdout only: stderr carries the PATH record
    if [ -n "$got" ] && [ "$got" = "$want" ]; then ok "P12 POPULATION-SHA equals the sha of --emit-population"; else bad "P12 sha mismatch"; fi

    # P15 severity of derived: items (controller ruling): high only when the probe is followed by
    # exit 2 / return 2 / an undet* call, else low
    fresh; out=$(run --corpus "$work/w/planted" 2>&1)
    if grep -q '^FINDING missing-toolchain high governance-drift derived:uncatalogued ' <<<"$out" \
        && grep -q '^FINDING missing-toolchain high governance-drift derived:multitool ' <<<"$out" \
        && grep -q '^FINDING missing-toolchain high governance-drift derived:twolinetool ' <<<"$out" \
        && grep -q '^FINDING missing-toolchain low governance-drift derived:softtool ' <<<"$out" \
        && grep -q '^FINDING missing-toolchain low governance-drift derived:optionaltool ' <<<"$out" \
        && grep -q '^FINDING missing-toolchain low governance-drift derived:needtool ' <<<"$out"; then ok "P15 derived severity: exit 2 / undet => high, message-only / need => low"
    else bad "P15 derived severity wrong: $(grep ' derived:' <<<"$out" | cut -d' ' -f3,5 | tr '\n' ' ')"; fi

    # P16 fail closed: a broken perl (the derived-precondition scanner) never shrinks the population silently
    mkdir -p "$work/brk"; printf '#!/bin/sh\nexit 2\n' >"$work/brk/perl"; chmod +x "$work/brk/perl"
    fresh; out=$(env -i PATH="$work/brk:$PATH" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$work/w" --corpus "$work/w/planted" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^COULD-NOT-INSPECT ' <<<"$out" && grep -q '^INSPECTED ' <<<"$out" && grep -q '^POPULATION-SHA ' <<<"$out"; then ok "P16 broken perl => rc 2, no partial findings, INSPECTED/POPULATION-SHA printed"
    else bad "P16 broken perl rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi
    out=$(env -i PATH="$work/brk:$PATH" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$work/w" --corpus "$work/w/planted" --emit-population 2>/dev/null); rc=$?
    if [ "$rc" -eq 2 ]; then ok "P16e broken perl => --emit-population rc 2"; else bad "P16e rc=$rc"; fi

    # P16c a perl that exits 0 and prints nothing (a stub) is caught by the scanner self-test
    mkdir -p "$work/brk3"; printf '#!/bin/sh\nexit 0\n' >"$work/brk3/perl"; chmod +x "$work/brk3/perl"
    fresh; out=$(env -i PATH="$work/brk3:$PATH" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$work/w" --corpus "$work/w/planted" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q 'self-test' <<<"$out"; then ok "P16c silent perl stub => rc 2 (self-test)"
    else bad "P16c rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi

    # P16b a perl that passes the self-test but fails on the scanned files: the xargs status is checked
    mkdir -p "$work/brk2"; printf '#!/bin/sh\n[ $# -gt 2 ] && exit 2\nexec %s "$@"\n' "$(type -P perl)" >"$work/brk2/perl"; chmod +x "$work/brk2/perl"
    fresh; out=$(env -i PATH="$work/brk2:$PATH" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$work/w" --corpus "$work/w/planted" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^COULD-NOT-INSPECT perl ' <<<"$out"; then ok "P16b perl failing on the scanned files => rc 2 (xargs status checked)"
    else bad "P16b rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi

    # P17 a required tool missing from PATH (iconv): rc 2 naming the tool, never 'not valid UTF-8'
    mkdir -p "$work/noiconv"; for b in awk bash cat cut env git grep head mktemp od perl rm sed sha256sum sort tr wc xargs basename dirname find mkdir printf; do p=$(type -P "$b") && ln -sf "$p" "$work/noiconv/$b"; done
    fresh; out=$(env -i PATH="$work/noiconv" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C "$BASH" "$SELF" --root "$work/w" --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && grep -q '^COULD-NOT-INSPECT tool%3Aiconv\|^COULD-NOT-INSPECT host-tool:iconv ' <<<"$out" && ! grep -q 'not valid UTF-8' <<<"$out"; then ok "P17 iconv missing => rc 2, named as a missing tool"
    else bad "P17 rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi

    # P18 a catalogue tool name that is not a token ('..') => COULD-NOT-INSPECT on the row, never an invalid token
    fresh; printf '..\tcommand -v ..\tgate x\tnone\tsrc\tnone\n' >>"$work/w/clean/docs/zero-gap/toolchains.tsv"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q 'tool:\.\.' <<<"$out" && grep -q 'unparseable tool name' <<<"$out"; then ok "P18 tool name '..' => row COULD-NOT-INSPECT, no tool:.. token"
    else bad "P18 rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi

    # P19 (review rev-base-A, fix 1) the LIVE run never reports the class scripts' own proof/self-test strings
    out=$(env -i PATH="$PATH" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$repo" 2>/dev/null); rc=$?
    if { [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ]; } && ! grep -Eq '^FINDING [^ ]+ [^ ]+ [^ ]+ derived:(maybetool|newghost|zgselftest|selfscantool) ' <<<"$out" \
        && ! awk '$1 == "FINDING" && $NF ~ /^scripts\/zero-gap-class-/ { f = 1 } END { exit !f }' <<<"$out"; then ok "P19 live run: no maybetool/newghost/zgselftest and no evidence_ref inside a zero-gap-class-*.sh (rc $rc)"
    else bad "P19 live self-scan rc=$rc: $(grep -E 'maybetool|newghost|zgselftest|zero-gap-class-' <<<"$out" | cut -c1-200 | tr '\n' '|')"; fi

    # P20 the exclusion is by NAME: the same probe text in a verify-*.sh is still a precondition
    fresh; mv "$work/w/clean/scripts/zero-gap-class-selfscan.sh" "$work/w/clean/scripts/verify-selfscan.sh"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "derived:selfscantool" ]; then ok "P20 mutation: class-script text moved to verify-selfscan.sh => derived:selfscantool (exclusion is by name only)"; else bad "P20 rc=$rc got=[$(locs "$out" | tr '\n' ' ')]"; fi

    # P21 (fix 2) container route: a finding only when the host tool is absent AND the route is unusable
    fresh; rm -f "$work/w/clean/bin/podman"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out" | tr '\n' ' ')" = "tool:buildabletool tool:containedtool " ] && grep -q 'none of its container runtimes' <<<"$out"; then ok "P21a mutation: no container runtime on the probe PATH => both routed tools reported"; else bad "P21a rc=$rc got=[$(locs "$out" | tr '\n' ' ')]"; fi
    fresh; rm -f "$work/w/clean/bin/go" "$work/w/clean/tools/bin/contained"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out" | tr '\n' ' ')" = "tool:buildabletool tool:containedtool " ] && grep -q 'is not built and its build tool go is not on the probe PATH' <<<"$out"; then ok "P21b mutation: resolver not built and no build tool => reported"; else bad "P21b rc=$rc got=[$(locs "$out" | tr '\n' ' ')]"; fi
    fresh; rm -f "$work/w/clean/tools/contained/main.go"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "tool:containedtool" ] && grep -q 'is not a tracked file' <<<"$out"; then ok "P21c mutation: resolver source removed => tool:containedtool"; else bad "P21c rc=$rc got=[$(locs "$out" | tr '\n' ' ')]"; fi
    fresh; rm -f "$work/w/clean/tools/contained/main.go"; ln -s ../buildable/main.go "$work/w/clean/tools/contained/main.go"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q '^COULD-NOT-INSPECT tool:containedtool ' <<<"$out"; then ok "P21d symlinked resolver => COULD-NOT-INSPECT, rc 2, never followed"; else bad "P21d rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi
    fresh; sed -i.bak 's#src=tools/contained/main.go#src=../contained/main.go#' "$work/w/clean/docs/zero-gap/toolchains.tsv"; rm -f "$work/w/clean/docs/zero-gap/toolchains.tsv.bak"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && ! grep -q '^FINDING' <<<"$out" && grep -q 'unparseable container_route for containedtool' <<<"$out"; then ok "P21e route path with '..' => row COULD-NOT-INSPECT, rc 2"; else bad "P21e rc=$rc: $(tr '\n' '|' <<<"$out" | cut -c1-300)"; fi
    fresh; rm -f "$work/w/clean/bin/podman"; printf '#!/bin/sh\nexit 0\n' >"$work/w/clean/bin/containedtool"; chmod +x "$work/w/clean/bin/containedtool"
    out=$(run --corpus "$work/w/clean" 2>&1); rc=$?
    if [ "$rc" -eq 1 ] && [ "$(locs "$out")" = "tool:buildabletool" ]; then ok "P21f host binary present => its route is irrelevant (only buildabletool reported)"; else bad "P21f rc=$rc got=[$(locs "$out" | tr '\n' ' ')]"; fi

    # P22 (fix 3) PATH dependence is RECORDED: live mode on a throwaway git tree, the same derived tool
    # is reported under one PATH and not under another, and the first stderr line names each PATH's sha
    g=$work/g; rm -rf "$g"; mkdir -p "$g" "$work/pbin"; cp -R "$fx/clean/." "$g/"; rm -rf "$g/bin"
    printf '#!/usr/bin/env bash\ncommand -v zgpathtool >/dev/null 2>&1 || exit 2\n' >"$g/scripts/verify-pathdep.sh"
    printf '#!/bin/sh\nexit 0\n' >"$work/pbin/zgpathtool"; chmod +x "$work/pbin/zgpathtool"
    if env -i PATH="$PATH" HOME="${HOME:-/}" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$g" init -q >/dev/null 2>&1 \
        && env -i PATH="$PATH" HOME="${HOME:-/}" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git -C "$g" add -A >/dev/null 2>&1; then
        local pa pb sa sb oa ob ea eb
        pa=$PATH; pb=$work/pbin:$PATH
        sa=$(printf '%s' "$pa" | sha256sum | cut -c1-12); sb=$(printf '%s' "$pb" | sha256sum | cut -c1-12)
        oa=$(env -i PATH="$pa" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$g" 2>"$work/ea"); ea=$(head -n 1 "$work/ea")
        ob=$(env -i PATH="$pb" HOME="${HOME:-/}" TMPDIR="$TMP" LC_ALL=C bash "$SELF" --root "$g" 2>"$work/eb"); eb=$(head -n 1 "$work/eb")
        if grep -q "^FINDING missing-toolchain high governance-drift derived:zgpathtool .*(sha256 $sa)" <<<"$oa" && ! grep -q ' derived:zgpathtool ' <<<"$ob" \
            && [[ "$ea" == "[class $CLASS] probe PATH (sha256 $sa;"* ]] && [[ "$eb" == "[class $CLASS] probe PATH (sha256 $sb;"* ]] \
            && [[ "$ea" != */home/* ]] && [[ "$eb" != */home/* ]]; then ok "P22 PATH recorded: derived:zgpathtool under PATH $sa, absent under PATH $sb; first stderr line names each sha, no /home/ path"
        else bad "P22 PATH record: [$ea] [$eb] $(grep zgpathtool <<<"$oa" | cut -c1-160)"; fi
    else bad "P22 could not build the throwaway git tree"; fi

    env -i PATH="$PATH" bash "$SELF" --root /nonexistent >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq 2 ]; then ok "P13 --root /nonexistent => rc 2"; else bad "P13 rc=$rc"; fi

    after=$(cd "$repo" && sha256sum "$SELF" "$fx/expect.tsv" "$repo/$CAT_REL" 2>/dev/null | sha256sum)
    if [ "$before" = "$after" ]; then ok "P14 the live script, catalogue and expect.tsv are byte-identical before and after"; else bad "P14 a live file changed during the proof"; fi
    echo "PROVE-FAILURE $CLASS: $pass passed, $fail failed"
    [ "$fail" -eq 0 ]
}
if [ "$PROVE" -eq 1 ]; then prove_failure; exit $?; fi

# ---------------------------------------------------------------------------------------------
# inspection
# ---------------------------------------------------------------------------------------------
if [ -z "$ROOT" ] || [ ! -d "$ROOT" ]; then echo "COULD-NOT-INSPECT - --root is not a directory"; echo "INSPECTED 0"; echo "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; exit 2; fi
if [ -n "$CORPUS" ] && [ ! -d "$CORPUS" ]; then echo "COULD-NOT-INSPECT - --corpus is not a directory"; echo "INSPECTED 0"; echo "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; exit 2; fi
ROOT=$(cd "$ROOT" && pwd)
EMPTY_SHA_TAIL() { echo "INSPECTED 0"; echo "POPULATION-SHA e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; }
if [ -n "$CORPUS" ]; then BASE=$(cd "$CORPUS" && pwd); PROBE_PATH=$BASE/bin; else BASE=$ROOT; PROBE_PATH=${PATH:-}; fi
# PATH RECORD (T038 review rev-base-A): host-tool results depend on the probe PATH, so the FIRST stderr
# line records it (HOME shown as ~, any other /home/<user> as ~<user>) and every host-dependent finding
# carries the sha256 prefix of the exact probe PATH string, so two registers measured under different
# PATHs can never be mistaken for one another.
show_path() {
    local p=$1
    if [ -n "${HOME:-}" ] && [ "$HOME" != / ]; then p=${p//"$HOME"/"~"}; fi
    printf '%s' "$p" | LC_ALL=C sed 's#/home/\([^/:]*\)#~\1#g' | LC_ALL=C tr -d '\000-\037\177'
}
PATH_SHA=$(printf '%s' "$PROBE_PATH" | sha256sum 2>/dev/null | cut -c1-12)
echo "[class $CLASS] probe PATH (sha256 ${PATH_SHA:-unknown}; HOME shown as ~): $(show_path "$PROBE_PATH")" >&2
# fail closed: every tool this class itself runs must be on PATH, or the run is COULD-NOT-INSPECT
# (a missing perl would silently drop the derived population; a missing iconv would read as bad UTF-8)
NEED="awk perl iconv sort xargs sha256sum od sed tr cut head wc find mktemp"
[ -n "$CORPUS" ] || NEED="$NEED git"
MISSING=""
for t in $NEED; do type -P -- "$t" >/dev/null 2>&1 || MISSING="$MISSING $t"; done
if [ -n "$MISSING" ]; then
    for t in $MISSING; do echo "COULD-NOT-INSPECT host-tool:$t $t is not on PATH; the class cannot run without it"; done
    [ "$EMIT" -eq 1 ] || EMPTY_SHA_TAIL
    exit 2
fi

W=$(mktemp -d "$TMP/zg-mt.XXXXXX") || { echo "COULD-NOT-INSPECT - cannot create a scratch directory"; exit 2; }
trap 'rm -rf "$W"' EXIT
CNI=0
cni() { if [ "$EMIT" -eq 1 ]; then echo "COULD-NOT-INSPECT $1 $2" >&2; else echo "COULD-NOT-INSPECT $1 $2"; fi; CNI=1; }

# all_files -> NUL list of the files the scan may read: tracked files (live) or every file (corpus)
if [ -n "$CORPUS" ]; then
    ( cd "$BASE" && find . -type f -print0 ) | sed -z 's|^\./||' >"$W/all.z"
else
    if ! git -C "$BASE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "COULD-NOT-INSPECT - --root is not a git work tree"; exit 2; fi
    git -C "$BASE" ls-files -z >"$W/all.z" 2>/dev/null || { echo "COULD-NOT-INSPECT - git ls-files failed"; exit 2; }
fi
# shared self-scan exclusion (T038 review rev-base-A): the sweep-class scripts and their corpora are
# never scanned — their proof and self-test text names tools no gate needs (maybetool, newghost, zgselftest)
awk 'BEGIN { RS = ORS = "\0" } index($0, "'"$FIXPFX"'") != 1 && $0 !~ /^scripts\/zero-gap-class-[^\/]*\.sh$/' "$W/all.z" >"$W/files.z"

# scan set: scripts/verify-*.sh, scripts/prove-*.sh, plus the `check` entrypoints of the registry
awk 'BEGIN { RS = ORS = "\0" } /^scripts\/(verify|prove)-[^\/]*\.sh$/' "$W/files.z" >"$W/scan0.z"
if [ -f "$BASE/$REG_REL" ]; then
    awk -F'\t' '$1 == "check" && $3 != "" { print $3 }' "$BASE/$REG_REL" | LC_ALL=C sort -u >"$W/reg.txt"
    awk 'BEGIN { RS = ORS = "\0" } NR == FNR { keep[$0] = 1; next } ($0 in keep)' \
        <(tr '\n' '\0' <"$W/reg.txt") "$W/files.z" >>"$W/scan0.z" 2>/dev/null
fi
LC_ALL=C sort -zu "$W/scan0.z" | awk 'BEGIN { RS = ORS = "\0" } !/[\t\n]/' >"$W/scan.z"
if [ "$(tr -cd '\0' <"$W/scan0.z" | wc -c)" -gt 0 ] && [ -n "$(LC_ALL=C sort -zu "$W/scan0.z" | awk 'BEGIN { RS = ORS = "\0" } /[\t\n]/ { print "x"; exit }' | tr -d '\0')" ]; then
    cni scan-list "a scanned script path contains a tab or newline and was skipped"
fi

# derived preconditions: line <TAB> tool <TAB> file <TAB> consequence (1 = the probe is followed by
# `exit 2`, `return 2` or an undet* call in command position on its own line, or — when the probe
# opens a block (`if`, trailing `{` `||` `&&` `\`) — within the next 3 lines of that block; else 0).  Comments, echo/printf lines and heredoc bodies are never probe sites.
PERL_DERIVE='
my $term; my @pend; my $CONS = qr/\b(?:exit|return)\s+2\b|(?:^\s*|[;&|{(!]\s*|\bthen\s+)undet\w*\b/;
sub flush_pend { for my $p (@pend) { print "$p->[0]\t$p->[1]\t$p->[2]\t0\n"; } @pend = (); }
while (<>) {
    if (@pend) {
        my @keep;
        for my $p (@pend) {
            if (/$CONS/ && !/^\s*#/) { print "$p->[0]\t$p->[1]\t$p->[2]\t1\n"; }
            elsif (!/^\s*(?:fi|else|elif|\}|done|esac)\b/ && --$p->[3] > 0) { push @keep, $p; }
            else { print "$p->[0]\t$p->[1]\t$p->[2]\t0\n"; }
        }
        @pend = @keep;
    }
    if (defined $term) { undef $term if /^\s*\Q$term\E\s*$/; goto NEXTLINE; }
    next_scan: {
        last if /^\s*#/;
        last if /^\s*(echo|printf|p_ok|p_bad|say|note)\b/;
        while (/(?:command\s+-v|type\s+-P|(?:^|[;&|(]\s*|\bif\s+!?\s*|\$\()which|^\s*need)\s+["\x27]?([A-Za-z][A-Za-z0-9._+-]*)["\x27]?(?=[\s;&|)]|$)/g) {
            my ($tool, $rest) = ($1, substr($_, pos($_)));
            if ($rest =~ $CONS) { print "$.\t$tool\t$ARGV\t1\n"; }
            # the next lines count only when the probe OPENS a block or continues: an `if` condition,
            # a trailing `{`, `||`, `&&` or `\`; the window ends at fi / else / elif / } / done / esac
            elsif (/\bif\b/ || /(?:\{|\|\||&&|\\)\s*$/) { push @pend, [$., $tool, $ARGV, 4]; }
            else { print "$.\t$tool\t$ARGV\t0\n"; }
        }
        if (/<<-?\s*["\x27]?([A-Za-z_][A-Za-z0-9_]*)["\x27]?/ && !/<<</) { $term = $1; }
    }
    NEXTLINE:
    if (eof) { flush_pend(); close ARGV; undef $term; }
}'
# self-test: a stub or broken perl must not pass for "no derived tool" (fail closed)
if [ "$(printf 'command -v zgselftest || exit 2\n' | perl -e "$PERL_DERIVE" 2>/dev/null)" != "$(printf '1\tzgselftest\t-\t1')" ]; then
    cni perl "the derived-precondition scanner (perl) failed its self-test; the derived population cannot be enumerated"
    [ "$EMIT" -eq 1 ] || EMPTY_SHA_TAIL
    exit 2
fi
( cd "$BASE" && xargs -0 -r perl -e "$PERL_DERIVE" <"$W/scan.z" ) >"$W/derived.raw" 2>"$W/perl.err"; prc=$?
if [ "$prc" -ne 0 ]; then
    cni perl "the derived-precondition scanner (xargs perl) exited $prc; the derived population cannot be enumerated"
    [ "$EMIT" -eq 1 ] || EMPTY_SHA_TAIL
    exit 2
fi
LC_ALL=C sort -t$'\t' -k2,2 -k3,3 -k1,1n "$W/derived.raw" >"$W/derived.tsv"

# catalogue
CAT=$BASE/$CAT_REL
if [ ! -f "$CAT" ]; then cni "$CAT_REL" "the catalogue is absent"; echo "INSPECTED 0"; echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; exit 2; fi
if ! iconv -f UTF-8 -t UTF-8 "$CAT" >/dev/null 2>&1; then cni "$CAT_REL" "the catalogue is not valid UTF-8"; echo "INSPECTED 0"; echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; exit 2; fi
awk -F'\t' -v OFS='\037' '
    /^[[:space:]]*$/ || /^#/ { next }
    !hdr { hdr = 1; if ($0 != "tool\tprobe\tgate_that_needs_it\tremedy\tsource\tcontainer_route") print "BADHEADER", NR; next }
    { bad = (NF != 6); for (i = 1; i <= NF; i++) if ($i == "") bad = 1
      if (bad) print "BADROW", NR; else print "ROW", NR, $1, $2, $3, $4, $5, $6 }' "$CAT" >"$W/cat.txt"

declare -A CAT_STATE=() CAT_LINE=() CAT_GATE=() CAT_INSTALL=() CAT_PROBE=() CAT_KIND=() CAT_TARGET=() SEEN=()
declare -A RT_SRC=() RT_BIN=() RT_BUILD=() RT_RUNTIMES=()
# a route path: repo-relative, no leading '/', no '.' or '..' segment, no empty segment
rpath_ok() { [[ "$1" =~ ^[A-Za-z0-9_+-][A-Za-z0-9._+-]*(/[A-Za-z0-9_+-][A-Za-z0-9._+-]*)*$ ]] && [[ "/$1/" != */../* ]]; }
POP=()
while IFS=$'\037' read -r kind ln tool probe gate inst src route; do
    case "$kind" in
    BADHEADER) cni "$CAT_REL:$ln" "the catalogue header is not the expected six-column header (tool probe gate_that_needs_it remedy source container_route)"; continue ;;
    BADROW) cni "$CAT_REL:$ln" "a catalogue row does not have six non-empty tab-separated columns"; continue ;;
    esac
    case "$tool" in [!A-Za-z0-9]*|*[!A-Za-z0-9._+-]*) cni "$CAT_REL:$ln" "unparseable tool name in the catalogue row"; continue ;; esac
    if [ -n "${SEEN[$tool]:-}" ]; then cni "$CAT_REL:$ln" "tool $tool is catalogued twice"; continue; fi
    SEEN[$tool]=1
    if [[ "$probe" =~ ^command\ -v\ ([A-Za-z0-9._+-]+)$ ]]; then CAT_KIND[$tool]=path; CAT_TARGET[$tool]=${BASH_REMATCH[1]}
    elif [[ "$probe" =~ ^dpkg-query\ -W\ ([a-z0-9][a-z0-9.+-]*)$ ]]; then CAT_KIND[$tool]=dpkg; CAT_TARGET[$tool]=${BASH_REMATCH[1]}
    else cni "$CAT_REL:$ln" "unparseable probe for $tool (only 'command -v <tool>' and 'dpkg-query -W <pkg>' are executed)"; unset "SEEN[$tool]"; continue; fi
    # container_route: `none`, or `src=<tracked resolver source> bin=<built resolver> build=<build tool> runtime=<rt>[,<rt>...]`
    if [ "$route" != none ]; then
        m=()
        if [[ "$route" =~ ^src=([^ ]+)\ bin=([^ ]+)\ build=([A-Za-z0-9][A-Za-z0-9._+-]*)\ runtime=([A-Za-z0-9][A-Za-z0-9._+-]*(,[A-Za-z0-9][A-Za-z0-9._+-]*)*)$ ]]; then
            m=("${BASH_REMATCH[@]}")   # captured first: rpath_ok's own =~ resets BASH_REMATCH
        fi
        if [ "${#m[@]}" -gt 4 ] && rpath_ok "${m[1]}" && rpath_ok "${m[2]}"; then
            RT_SRC[$tool]=${m[1]} RT_BIN[$tool]=${m[2]} RT_BUILD[$tool]=${m[3]} RT_RUNTIMES[$tool]=${m[4]}
        else cni "$CAT_REL:$ln" "unparseable container_route for $tool (expected 'none' or 'src=<path> bin=<path> build=<tool> runtime=<rt>[,<rt>]' with repo-relative paths)"; unset "SEEN[$tool]"; continue; fi
    fi
    CAT_LINE[$tool]=$ln CAT_GATE[$tool]=$gate CAT_INSTALL[$tool]=$inst CAT_PROBE[$tool]=$probe
    POP+=("tool:$tool")
done <"$W/cat.txt"

# derived tools without a catalogue row
declare -A DER_FIRST=() DER_COUNT=() DER_FILES=() DER_CONS=()
while IFS=$'\t' read -r ln tool file cons; do
    [ -n "$tool" ] || continue
    ref="$file:$ln"
    DER_COUNT[$tool]=$(( ${DER_COUNT[$tool]:-0} + 1 ))
    [ -n "${DER_FIRST[$tool]:-}" ] || DER_FIRST[$tool]=$ref
    if [ "$cons" = 1 ] && [ -z "${DER_CONS[$tool]:-}" ]; then DER_CONS[$tool]=$ref; fi
    case " ${DER_FILES[$tool]:-} " in *" $file "*) ;; *) DER_FILES[$tool]="${DER_FILES[$tool]:-} $file" ;; esac
done <"$W/derived.tsv"
for t in "${!DER_FIRST[@]}"; do
    if [ -z "${SEEN[$t]:-}" ]; then POP+=("derived:$t"); fi
done

if [ "${#POP[@]}" -eq 0 ]; then
    cni - "population enumerated to zero items: a class that inspects nothing is never clean"
    echo "INSPECTED 0"; echo "POPULATION-SHA $(printf '' | sha256sum | cut -d' ' -f1)"; exit 2
fi
POPTXT=$(printf '%s\n' "${POP[@]}" | LC_ALL=C sort -u)
if [ "$EMIT" -eq 1 ]; then printf '%s\n' "$POPTXT"; exit 0; fi

# probe helpers (read-only; the probe PATH is confined to a subshell)
have_path() { ( PATH=$PROBE_PATH; type -P -- "$1" >/dev/null 2>&1 ); }
dpkg_state() { # -> prints present|absent|error
    local st rc
    if ! have_path dpkg-query; then echo error; return; fi
    st=$( PATH=$PROBE_PATH; dpkg-query -W -f='${Status}' "$1" 2>/dev/null ); rc=$?
    if [ "$rc" -eq 0 ] && [ "$st" = "install ok installed" ]; then echo present
    elif [ "$rc" -le 1 ]; then echo absent
    else echo error; fi
}
# route_state <tool> -> prints a description; rc 0 usable, 1 unusable, 2 could not inspect.
# Structural only (read-only, nothing is built, started or pulled): the resolver source is a tracked
# regular file; the resolver binary is a built regular executable OR its build tool is on the probe PATH;
# at least one catalogued container runtime is on the probe PATH. A symlinked source or binary is never
# followed (rc 2). Whether the container workload then SUCCEEDS end to end is not measured here.
route_state() {
    local t=$1 s=${RT_SRC[$1]} b=${RT_BIN[$1]} bt=${RT_BUILD[$1]} rt r have="" built
    if [ -L "$BASE/$s" ]; then echo "its resolver source $s is a symlink (not followed)"; return 2; fi
    if ! awk -v p="$s" 'BEGIN { RS = "\0" } $0 == p { f = 1; exit } END { exit !f }' "$W/files.z"; then
        echo "its resolver source $s is not a tracked file"; return 1
    fi
    if [ -L "$BASE/$s" ] || [ ! -f "$BASE/$s" ]; then echo "its resolver source $s is a symlink or not a regular file (not followed)"; return 2; fi
    if [ -L "$BASE/$b" ]; then echo "its resolver binary $b is a symlink (not followed)"; return 2; fi
    if [ -f "$BASE/$b" ] && [ -x "$BASE/$b" ]; then built="binary $b built"
    elif have_path "$bt"; then built="binary $b not built, build tool $bt on PATH"
    else echo "its resolver binary $b is not built and its build tool $bt is not on the probe PATH"; return 1; fi
    IFS=, read -r -a rt <<<"${RT_RUNTIMES[$t]}"
    for r in "${rt[@]}"; do if have_path "$r"; then have=$r; break; fi; done
    if [ -z "$have" ]; then echo "none of its container runtimes (${RT_RUNTIMES[$t]}) is on the probe PATH"; return 1; fi
    echo "resolver $s tracked, $built, runtime $have on PATH"
    return 0
}
clean_text() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' | LC_ALL=C sed 's/[^ -~]/?/g'; }
FOUND=0
finding() { # sev cat location desc ref
    printf 'FINDING %s %s %s %s %s %s\n' "$CLASS" "$1" "$2" "$3" "$(clean_text "$4")" "$5"
    FOUND=$((FOUND + 1))
}
docs_hit() { # <tool> -> first "file:line" of a live "missing" claim naming the tool, else nothing
    local f
    for f in CLAUDE.md CONTINUATION.md; do
        [ -f "$BASE/$f" ] || continue
        awk -v f="$f" -v t="$1" '
            function word(line,   p, b, a, rest, off) {
                off = 0; rest = line
                while ((p = index(rest, t)) > 0) {
                    b = (off + p > 1) ? substr(line, off + p - 1, 1) : " "
                    a = substr(line, off + p + length(t), 1); if (a == "") a = " "
                    if (b !~ /[A-Za-z0-9._+-]/ && a !~ /[A-Za-z0-9_+-]/) return 1
                    off += p; rest = substr(line, off + 1)
                }
                return 0
            }
            /NOT INSTALLED|is absent|are absent|all absent|MISSING/ && !/WITHDRAWN|SUPERSEDED|no longer|was true when/ && word($0) { print f ":" FNR; exit }' "$BASE/$f"
    done | head -n 1
}

INSP=0
for item in $POPTXT; do
    INSP=$((INSP + 1))
    case "$item" in
    tool:*)
        t=${item#tool:}; state=""
        if [ "${CAT_KIND[$t]}" = path ]; then
            if have_path "${CAT_TARGET[$t]}"; then state=present; else state=absent; fi
        else
            state=$(dpkg_state "${CAT_TARGET[$t]}")
            if [ "$state" = error ]; then cni "$item" "dpkg-query is unavailable or failed, so ${CAT_TARGET[$t]} could not be probed"; continue; fi
        fi
        ref=$CAT_REL:${CAT_LINE[$t]}
        if [ "$state" = absent ]; then
            gate=${CAT_GATE[$t]}; users=""
            if [ -n "${DER_FILES[$t]:-}" ]; then users=" Named as a precondition in:${DER_FILES[$t]}."; fi
            case "$gate" in
            UNCONFIRMED*)
                if [ -z "$users" ]; then echo "[class $CLASS] $item absent; its gate is UNCONFIRMED and no scanned script names it, so it is inspected and not reported" >&2; continue; fi ;;
            esac
            if [ -n "${RT_SRC[$t]:-}" ]; then
                why=$(route_state "$t"); rrc=$?
                if [ "$rrc" -eq 2 ]; then cni "$item" "$why"; continue; fi
                if [ "$rrc" -eq 0 ]; then
                    echo "[class $CLASS] $item host binary absent from the probe PATH, container route usable ($why), so it is inspected and not reported" >&2
                    continue
                fi
                finding medium host-capability "$item" "Operator-blocked: $t is absent from the probe PATH (probe: ${CAT_PROBE[$t]}; PATH sha256 $PATH_SHA) AND its catalogued container route is unusable: $why; gate that exits 2 (never a pass) until the route is usable: $gate.$users Remedy (operator action, never run by the sweep): ${CAT_INSTALL[$t]}" "$(zg_pct_encode "$ref")"
                continue
            fi
            finding medium host-capability "$item" "Operator-blocked: $t is absent from the probe PATH (probe: ${CAT_PROBE[$t]}; PATH sha256 $PATH_SHA) and no container route is catalogued; gate that exits 2 (never a pass) until installed: $gate.$users Remedy (operator action, never run by the sweep): ${CAT_INSTALL[$t]}" "$(zg_pct_encode "$ref")"
        else
            hit=$(docs_hit "$t")
            if [ -n "$hit" ]; then
                finding low docs-drift "$item" "docs drift: $t is present on this host (probe: ${CAT_PROBE[$t]}) but a tracked document still records it missing at $hit" "$(zg_pct_encode "$hit")"
            fi
        fi ;;
    derived:*)
        t=${item#derived:}
        if ! have_path "$t"; then
            n=${DER_COUNT[$t]}; first=${DER_FIRST[$t]}
            if [ -n "${DER_CONS[$t]:-}" ]; then
                finding high governance-drift "$item" "catalogue missing derived tool: $t is absent from the probe PATH (sha256 $PATH_SHA) and has no row in $CAT_REL, and the probe at ${DER_CONS[$t]} is followed by exit 2 / return 2 / an undet call, so that gate exits 2 (never a pass) here ($n precondition(s) in total); add a row with its install command" "$(zg_pct_encode "${DER_CONS[$t]}")"
            else
                finding low governance-drift "$item" "catalogue missing derived tool: $t is absent from the probe PATH (sha256 $PATH_SHA) and has no row in $CAT_REL; none of its $n probe(s) (first $first) is followed by exit 2 / return 2 / an undet call, so no gate is shown to exit 2 on it; add a row or record why it is optional" "$(zg_pct_encode "$first")"
            fi
        fi ;;
    esac
done

echo "INSPECTED $INSP"
echo "POPULATION-SHA $(printf '%s\n' "$POPTXT" | sha256sum | cut -d' ' -f1)"
if [ "$FOUND" -gt 0 ]; then exit 1; fi
if [ "$CNI" -gt 0 ]; then exit 2; fi
exit 0
