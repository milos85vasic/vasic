#!/usr/bin/env bash
# Build the content generator and render ALL site content dynamically from
# _content/** + design-system/**. No page is hardcoded.
#
#   build.sh                 # build + generate both sites into the live dirs, rebuild _site
#   build.sh --out DIR       # generate both sites under DIR/<site> (temp validation)
#   build.sh --no-jekyll     # skip the milosvasic.ru Jekyll _site rebuild
#   build.sh --lang xx       # language (default en)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BIN="$HERE/gen"

OUT=""
LANG_CODE="en"
DO_JEKYLL=1
PROVE_BUILDYEAR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --lang) LANG_CODE="$2"; shift 2 ;;
    --no-jekyll) DO_JEKYLL=0; shift ;;
    --prove-buildyear) PROVE_BUILDYEAR=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ── portable epoch → UTC year (Environment Adaptability) ─────────────────────
# GNU coreutils spells this `-d @EPOCH`; BSD/macOS spells it `-r EPOCH`. THE TWO
# CANNOT BE `||`-CHAINED, and the chain that stood here until 2026-09-01 --
# BSD-first, GNU second, current-year last -- was a latent defect of exactly the
# class documented at length in _tools/pdf/build-pdfs.sh:portable_mtime.
#
#   * On GNU, `-r` is --reference=FILE, so the epoch is resolved as a PATHNAME.
#     With no such file it fails cleanly and the fallback wins -- measured
#     2026-09-01, SOURCE_DATE_EPOCH=1700000000 yielded BUILD_YEAR=2023, 4 bytes,
#     which is why this never misbehaved here. But a FILE NAMED WITH THE EPOCH
#     in the current directory makes it SUCCEED with that file's mtime year.
#     Measured, same date, with a file `1700000000` whose mtime is 1999-01-01:
#     BUILD_YEAR became 1999 instead of 2023 -- rc 0, no diagnostic, and because
#     the command succeeded the `||` never fired, so the correct spelling
#     sitting on the same line was never consulted.
#   * Symmetrically, BSD/macOS `-d` sets the kernel daylight-saving flag rather
#     than parsing a date, so on that side the GNU spelling can silently print
#     TODAY's year for any epoch.
#
# Both failures return a WELL-FORMED four-digit year, so validating the SHAPE of
# the output -- the `^[0-9]+$` test that suffices for an mtime -- is not enough
# here: it accepts both wrong answers. Each spelling is therefore run SEPARATELY
# against a KNOWN-ANSWER ORACLE (1000000000 == 2001-09-09T01:46:40Z, far from
# any year boundary in any timezone) and is used only if it reproduces it.
# Validate the OUTPUT, never the exit status -- one idiom for this problem
# across the tree, not five.
#
# Returns 1 WITH NO OUTPUT when neither spelling can be trusted on this host, so
# a caller may safely write `portable_epoch_year "$E" || date -u +%Y` without
# risking the concatenation this function exists to prevent.
portable_epoch_year() {
  local _e="$1" _y=""
  if [ "$(date -u -d '@1000000000' +%Y 2>/dev/null)" = "2001" ]; then
    _y="$(date -u -d "@$_e" +%Y 2>/dev/null)"
  elif [ "$(date -u -r 1000000000 +%Y 2>/dev/null)" = "2001" ]; then
    _y="$(date -u -r "$_e" +%Y 2>/dev/null)"
  fi
  case "$_y" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$_y"
}

# ── §1.1 paired-mutation gate for the epoch→year probe ───────────────────────
#   bash _tools/gen/build.sh --prove-buildyear
# Three-valued, like every check in this tree: 0 the probe works, 1 the probe is
# broken, 2 COULD NOT DETERMINE (never a pass). It returns before ANY build,
# generation, commit or push happens, writes only inside a `mktemp -d`, and
# touches no tracked artifact -- safe to run at any time.
#
# B1 is the assertion that DISCRIMINATES fixed from broken. It reconstructs the
# adversarial case that makes the historical chain flip: a current directory
# containing a file NAMED with the epoch, whose mtime is a different year. Under
# the old BSD-first chain that returns the FILE's year at rc 0; under the
# oracle-checked form it returns the EPOCH's year.
#
# B1's fixture is not assumed to bite -- it is PROVEN to. The historical
# expression is written out longhand here (never a call to the subject) and must
# actually get the fixture wrong; if it does not, B1 is reported as NOT EXERCISED
# and the gate ends at rc 2 rather than banking an assertion it never made. A
# fixture established with the function under test can only ever report
# UNDETERMINED when that function breaks, which launders a real defect into
# "could not verify".
#
# B4 puts a stub `date` FIRST on PATH. WHAT THAT STUB MODELS HAS BEEN CORRECTED.
#
# It was described as "the BSD/macOS contract", with `-d` consuming a
# daylight-saving integer and then printing TODAY. That is REFUTED as a
# statement about any BSD shipping now, established 2026-09-01:
#
#   * FreeBSD 14.2 bin/date, built from vendor source and RUN on this host:
#     `date -u -d @1000000000 +%Y` -> "invalid option -- 'd'", usage on STDERR,
#     NOTHING on stdout, rc 1. The getopt string is "f:I::jnRr:uv:z:" and has
#     no `d` at all.
#   * Current macOS is the same: Apple shell_cmds date.c (main) uses the very
#     same option string.
#   * The DST reading WAS true, and the stub is not fiction: Apple shell_cmds
#     through tag shell_cmds-216.60.1 used "d:f:jnRr:t:uv:", i.e. `-d` taking an
#     argument. It is gone by shell_cmds-302.60.2. So B4 models a HISTORICAL
#     macOS contract that real machines still in service may present -- which is
#     exactly why it is kept rather than deleted.
#
# B4 remains load-bearing for the reason it always was: it is the assertion that
# fails if anyone later "simplifies" the known-answer oracle down to a bare
# four-digit shape test, because on that stub the GNU spelling returns a
# well-formed but WRONG year. Note that the MODERN BSD behaviour cannot make
# that point: `-d` there returns EMPTY, which even a shape test rejects.
#
# B5 is the measurement B4 is not. It runs the CURRENT BSD contract against a
# genuine BSD `date` when one is supplied in VASIC_BSD_DATE, after probing that
# binary to confirm it really answers like a BSD date. Measured this way
# 2026-09-01 against FreeBSD 14.2 bin/date, in a working directory containing a
# file NAMED 1000000000 whose mtime year is 1999 -- the adversarial fixture of
# B1 -- the two platforms genuinely diverge:
#
#   GNU  date -u -r 1000000000 +%Y  -> 1999   (-r is --reference=FILE)
#   BSD  date -u -r 1000000000 +%Y  -> 2001   (-r is epoch seconds)
#
# so the `date -r` flip this function exists to survive is CONFIRMED, not
# assumed. (BSD `-r` accepts either: a fully-numeric argument is an epoch, and
# anything else is retried as a pathname. That is why the known-answer oracle,
# not a shape test, is the thing that makes the dispatch safe.)
if [ "${PROVE_BUILDYEAR:-0}" = "1" ]; then
  echo "BUILD-YEAR-PORTABILITY §1.1 PAIRED MUTATION PROOF — portable_epoch_year"
  echo "----------------------------------------------------------------------"
  BY_PASS=0; BY_FAIL=0; B1_RAN=0
  by_ok()   { BY_PASS=$((BY_PASS+1)); printf '✅ %-24s %s\n' "$1" "$2"; }
  by_bad()  { BY_FAIL=$((BY_FAIL+1)); printf '❌ %-24s %s\n' "$1" "$2"; }
  by_note() { printf 'ℹ %-24s %s\n' "$1" "$2"; }

  BYW="$(mktemp -d "${TMPDIR:-/tmp}/buildyear-proof.XXXXXX")" || {
    echo "UNDETERMINED: cannot create a sandbox, so nothing was proved." >&2; exit 2; }
  trap 'rm -rf "$BYW"' EXIT INT TERM

  # B2 — the ordinary path: three known epochs, none of them near a year
  # boundary, checked against their UTC years.
  for pair in 1000000000:2001 946684800:2000 1700000000:2023; do
    e="${pair%%:*}"; want="${pair##*:}"
    if got="$(portable_epoch_year "$e")"; then :; else got=""; fi
    if [ "$got" = "$want" ]; then
      by_ok "B2 epoch-$e" "resolved to $want"
    else
      by_bad "B2 epoch-$e" "expected $want, got '${got}' (${#got} bytes)"
    fi
  done

  # B1 — the adversarial current directory.
  : >"$BYW/1000000000"
  touch -d '@915148800' "$BYW/1000000000" 2>/dev/null \
    || touch -t 199901010000 "$BYW/1000000000" 2>/dev/null || true
  hist="$(cd "$BYW" && { date -u -r 1000000000 +%Y 2>/dev/null \
                         || date -u -d '@1000000000' +%Y 2>/dev/null \
                         || date -u +%Y; })"
  if [ "$hist" = "2001" ]; then
    by_note "B1 adversarial-cwd" "NOT EXERCISED — the historical expression is not wrong on this"
    by_note "" "host's fixture (it returned $hist), so this sandbox cannot discriminate."
  else
    B1_RAN=1
    if got="$(cd "$BYW" && portable_epoch_year 1000000000)"; then :; else got=""; fi
    if [ "$got" = "2001" ]; then
      by_ok "B1 adversarial-cwd" "a file named 1000000000 (mtime year $hist) did NOT hijack the answer"
    else
      by_bad "B1 adversarial-cwd" "expected 2001, got '${got}' — the epoch was resolved as a PATHNAME"
    fi
  fi

  # B3 — a non-epoch argument must fail SILENTLY, so `|| date -u +%Y` at the
  # call site cannot concatenate onto a partial answer.
  if got="$(portable_epoch_year 'not-an-epoch')"; then
    by_bad "B3 garbage-input" "returned 0 with '${got}' instead of failing"
  elif [ -n "$got" ]; then
    by_bad "B3 garbage-input" "failed but still wrote ${#got} bytes to stdout: '${got}'"
  else
    by_ok "B3 garbage-input" "failed with EMPTY stdout, so a caller fallback cannot concatenate"
  fi

  # B4 — HISTORICAL macOS contract (Apple shell_cmds <= 216.60.1), SIMULATED.
  mkdir -p "$BYW/bin-bsd"
  { printf '#!/usr/bin/env bash\nREAL_DATE=%q\n' "$(command -v date)"
    cat <<'BY_BSD_STUB'
# Simulates the HISTORICAL macOS date contract (Apple shell_cmds through tag
# shell_cmds-216.60.1, option string "d:f:jnRr:t:uv:"): -d takes a
# daylight-saving integer (atoi-parsed, so a junk argument is silently accepted
# and the command then prints the CURRENT time), and -r takes SECONDS SINCE THE
# EPOCH. Current FreeBSD and current macOS have NO -d; see B5 for that, measured.
ref=""; fmt="+%Y"
while [ $# -gt 0 ]; do
  case "$1" in
    -u) shift ;;
    -d) shift; [ $# -gt 0 ] && shift; ;;
    -r) ref="${2:-}"; shift; [ $# -gt 0 ] && shift; ;;
    +*) fmt="$1"; shift ;;
    *)  shift ;;
  esac
done
if [ -n "$ref" ]; then "$REAL_DATE" -u -d "@$ref" "$fmt"; else "$REAL_DATE" -u "$fmt"; fi
BY_BSD_STUB
  } >"$BYW/bin-bsd/date"
  chmod 755 "$BYW/bin-bsd/date"
  if got="$(PATH="$BYW/bin-bsd:$PATH"; hash -r; portable_epoch_year 1000000000)"; then :; else got=""; fi
  if [ "$got" = "2001" ]; then
    by_ok "B4 macos-hist (SIM)" "the oracle rejected the GNU spelling and used -r (simulated historical macOS date)"
  else
    by_bad "B4 macos-hist (SIM)" "expected 2001, got '${got}' — a four-digit shape test is not an oracle"
  fi

  # B5 — the CURRENT BSD contract, MEASURED against a genuine BSD date when one
  # is supplied. The binary is probed first: it must reject `-d @<epoch>` with
  # EMPTY stdout and resolve `-r <epoch>` to the oracle year. A binary failing
  # that probe is not called BSD, and B5 is reported as not exercised rather
  # than banked. Absent VASIC_BSD_DATE this prints a NOTE and asserts nothing —
  # an untested platform claim stays could-not-determine, it is never upgraded.
  B5_RAN=0
  if [ -n "${VASIC_BSD_DATE:-}" ] && [ -x "${VASIC_BSD_DATE}" ]; then
    # `|| true` is load-bearing under `set -e`: the whole POINT of the first
    # probe is that a genuine BSD date REJECTS `-d`, i.e. exits non-zero, and a
    # bare assignment from a failing command substitution would abort the gate
    # before it could record the very fact it is measuring.
    p_d="$("$VASIC_BSD_DATE" -u -d '@1000000000' +%Y 2>/dev/null || true)"
    p_r="$("$VASIC_BSD_DATE" -u -r 1000000000 +%Y 2>/dev/null || true)"
    if [ -z "$p_d" ] && [ "$p_r" = "2001" ]; then
      B5_RAN=1
      mkdir -p "$BYW/bin-real"
      ln -sf "$VASIC_BSD_DATE" "$BYW/bin-real/date"
      # Run inside the ADVERSARIAL directory built for B1: a file named with the
      # epoch, mtime year 1999. GNU resolves that as a pathname; BSD must not.
      if got="$(cd "$BYW" && PATH="$BYW/bin-real:$PATH"; hash -r; portable_epoch_year 1000000000)"; then :; else got=""; fi
      if [ "$got" = "2001" ]; then
        by_ok "B5 bsd-contract (MEASURED)" "genuine BSD date resolved the epoch, not the same-named file: $VASIC_BSD_DATE"
      else
        by_bad "B5 bsd-contract (MEASURED)" "expected 2001, got '${got}' on $VASIC_BSD_DATE"
      fi
    else
      by_note "B5 bsd-contract" "VASIC_BSD_DATE did not answer to the BSD contract (-d gave ${#p_d} bytes, -r gave '${p_r}'); not exercised"
    fi
  else
    by_note "B5 bsd-contract" "NOT EXERCISED — no VASIC_BSD_DATE supplied. The BSD side is asserted"
    by_note "" "only by the historical simulation B4. Build recipe: docs/environment-adaptability/AUDIT.md"
  fi

  echo "----------------------------------------------------------------------"
  if [ "$BY_FAIL" -gt 0 ]; then
    echo "❌ portable_epoch_year §1.1 PROOF: FAIL — ${BY_FAIL} of $((BY_PASS + BY_FAIL)) assertion(s) did not hold."
    echo "   Restore the oracle-checked form; an || chain over these two spellings resolves"
    echo "   the epoch as a PATHNAME on GNU and as a daylight-saving flag on BSD."
    exit 1
  fi
  if [ "$B1_RAN" -eq 0 ]; then
    echo "◍ portable_epoch_year §1.1 PROOF: COULD NOT DETERMINE — ${BY_PASS} assertion(s) held,"
    echo "   but the DISCRIMINATING one (B1) could not be exercised on this host. That is not"
    echo "   a pass; it is an unproven claim, and it is reported as one."
    exit 2
  fi
  echo "✅ portable_epoch_year §1.1 MUTATION PROOF: PASS — ${BY_PASS} assertions, including the"
  echo "   adversarial current directory (B1) that the historical || chain cannot survive."
  echo "   B4 is a SIMULATION of the HISTORICAL macOS date contract (shell_cmds <= 216.60.1)."
  if [ "$B5_RAN" -eq 1 ]; then
    echo "   B5 is a MEASUREMENT of the CURRENT BSD contract on ${VASIC_BSD_DATE}."
  else
    echo "   The CURRENT BSD contract was NOT measured in this run (B5 not exercised); set"
    echo "   VASIC_BSD_DATE to a genuine BSD date to measure it."
  fi
  exit 0
fi

# Deterministic footer © year (§11.4.65 render-twin determinism): pin main.buildYear
# so rebuilds are byte-identical and the year never floats mid-January. Resolution:
# caller's SOURCE_DATE_EPOCH → last git commit year → current year (ad-hoc builds).
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  BUILD_YEAR="$(portable_epoch_year "$SOURCE_DATE_EPOCH" || date -u +%Y)"
else
  BUILD_YEAR="$(git -C "$ROOT" log -1 --format=%cd --date=format:%Y 2>/dev/null || date -u +%Y)"
fi
echo "[build] go build (buildYear=$BUILD_YEAR) ..."
( cd "$HERE" && go build -ldflags "-X main.buildYear=$BUILD_YEAR" -o "$BIN" . )
echo "[build] built $BIN"

DS="$ROOT/design-system"

# sync_assets: COPY every design-system asset a deployed page needs into
# <site>/assets/od/ so pages are self-contained and never link back into the
# repo (fixes the stale-copy bug class). Paths resolve from the site root:
#   assets/od/fonts.css          + assets/od/<family>/*.woff2 (+ OFL)
#   assets/od/<brand>.css        (brand tokens/components)
#   assets/od/components-extended.css
#   assets/od/animations.css     (design-system/motion/animations.css)
#   assets/od/overlays.css       (blur/layered overlay entrances)
#   assets/od/motion.js          (+ assets/od/vendor/*  + assets/od/lottie/*)
#   assets/od/icons.svg
sync_assets() {
  local site="$1" brand="$2"
  local od="$ROOT/$site/assets/od"
  mkdir -p "$od" "$od/vendor" "$od/lottie"

  cp "$DS/brand-$brand/$brand.css"          "$od/$brand.css"
  cp "$DS/components-extended.css"           "$od/components-extended.css"
  cp "$DS/motion/animations.css"            "$od/animations.css"
  cp "$DS/motion/overlays.css"              "$od/overlays.css"
  cp "$DS/motion/motion.js"                 "$od/motion.js"
  cp "$DS/icons/icons.svg"                  "$od/icons.svg"
  cp "$DS/motion/vendor/"* "$od/vendor/" 2>/dev/null || true
  cp "$DS/motion/lottie/"* "$od/lottie/" 2>/dev/null || true

  # Fonts: fonts.css references '<family>/<file>.woff2' relative to itself, so
  # the family dirs must sit next to the copied fonts.css.
  cp "$DS/fonts/fonts.css" "$od/fonts.css"
  local fam
  for fam in inter space-grotesk jetbrains-mono; do
    mkdir -p "$od/$fam"
    cp "$DS/fonts/$fam/"*.woff2 "$od/$fam/" 2>/dev/null || true
    cp "$DS/fonts/$fam/OFL.txt" "$od/$fam/OFL.txt" 2>/dev/null || true
  done

  # Brand-scoped display faces (e.g. vasic.digital's bold display typeface).
  # The brand CSS @font-face references them relative to itself as
  # 'display/<file>.woff2', so they land in <site>/assets/od/display/. No-op for
  # brands without a brand-<brand>/fonts/ directory (e.g. milosvasic).
  if [ -d "$DS/brand-$brand/fonts" ]; then
    mkdir -p "$od/display"
    cp "$DS/brand-$brand/fonts/"*.woff2 "$od/display/" 2>/dev/null || true
    cp "$DS/brand-$brand/fonts/"OFL-*.txt "$od/display/" 2>/dev/null || true
  fi
  echo "[build] synced design-system assets -> $od"
}

sync_assets vasic.digital vasic-digital
sync_assets milosvasic.ru  milosvasic

gen_site() {
  local site="$1"
  if [ -n "$OUT" ]; then
    "$BIN" -site "$site" -lang "$LANG_CODE" -root "$ROOT" -out "$OUT/$site"
  else
    "$BIN" -site "$site" -lang "$LANG_CODE" -root "$ROOT"
  fi
}

gen_site vasic.digital
gen_site milosvasic.ru

if [ -z "$OUT" ] && [ "$DO_JEKYLL" -eq 1 ]; then
  echo "[build] rebuilding milosvasic.ru/_site (jekyll) ..."
  # Pin the footer © year deterministically (§11.4.65) via an ephemeral,
  # gitignored config override; falls back to 'now' if absent (ad-hoc builds).
  printf 'build_year: %s\n' "$BUILD_YEAR" > "$ROOT/milosvasic.ru/_config.deploy.yml"
  ( cd "$ROOT/milosvasic.ru" && jekyll build --quiet --config _config.yml,_config.deploy.yml )
  rm -f "$ROOT/milosvasic.ru/_config.deploy.yml"
  echo "[build] _site rebuilt"
fi

echo "[build] done"
