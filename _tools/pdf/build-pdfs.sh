#!/usr/bin/env bash
#
# build-pdfs.sh — render the downloadable career documents as themed A4 PDFs.
#
# Purpose:
#   Render each EN master document (CV, Cover Letter, Portfolio) as an
#   enterprise-grade, world-class-looking PDF, themed by the OpenDesign design
#   system (Milos Vasic personal brand = crimson; Portfolio = the unified
#   accent) and laid out for A4 print by the Constitution canonical print
#   stylesheet, WITHOUT breaking §11.4.168 export validation.
#
# Pipeline (per document):
#   markdown  --pandoc-->  themed HTML  (inlines the OpenDesign tokens
#             (milosvasic.css) + the Constitution print stylesheet
#             (default-pdf.css) + a brand bridge + a branded COVER PAGE +
#             an at-a-glance metrics strip + (Portfolio) embedded, rasterised
#             architecture diagrams)  --weasyprint-->  PDF
#
# Enterprise-grade upgrades (all token-driven from
# design-system/brand-milosvasic/milosvasic.css + default-pdf.css; no hardcoded
# design values beyond what a print stylesheet legitimately needs):
#   * A branded COVER PAGE (@page:first) — name, title, crimson accent rule, a
#     subtle geometric section accent, the letterhead photo and a contact line.
#     The cover carries the identity ONCE — the body's redundant leading H1 is
#     suppressed, fixing the earlier "name appears twice" letterhead+H1 defect.
#   * Refined typographic hierarchy + vertical rhythm — display-weight headings,
#     section eyebrows, an accent rule under H1/H2, comfortable measure.
#   * An "At a glance" metrics strip (CV + Portfolio) of evidence-based figures.
#   * Running header (name / document) + footer (site · page N / total) via
#     @page margin boxes; the cover page suppresses them via @page:first.
#   * break-inside:avoid on cards/figures/rows; break-after:avoid on headings.
#   * Portfolio embeds 2–4 architecture diagrams from design-system/diagrams/*.svg.
#     WeasyPrint's SVG engine does NOT resolve the diagrams' CSS custom
#     properties (`var(--…)`) or their `@media (prefers-color-scheme: dark)`
#     blocks, so we RASTERISE honestly: flatten each SVG's tokens to their
#     light-theme hex values, render to a raster PNG via a WeasyPrint→pdftoppm
#     round-trip, and embed the PNG as a data-URI. This keeps `pdftotext` clean
#     (no raw markup leak) and guarantees `pdfimages` finds the figures.
#
# Anti-bluff / a11y notes (unchanged rationale):
#   * default-pdf.css pins body text to the Liberation/DejaVu safe sans stack to
#     avoid the documented WeasyPrint text-run-reordering defect (§11.4.115), so
#     `pdftotext` extraction stays clean. This script therefore NEVER overrides
#     font-family for body/headings with an uninstalled display face — the
#     display hierarchy is expressed through weight, size, tracking, colour and
#     rules on the SAME safe family, never a re-triggering face.
#   * A real raster letterhead photo is embedded (data-URI PNG) so every PDF
#     carries >= 1 embedded image, satisfying the §11.4.168 FULL-VISUAL layer.
#   * YAML front-matter is consumed by pandoc as metadata, never rendered into
#     the body, so it cannot leak as raw markup in the extracted text.
#
# Inputs:
#   _content/docs/{cv,cover-letter,portfolio}.md   (EN masters)
#   design-system/brand-milosvasic/milosvasic.css  (OpenDesign tokens)
#   submodules/constitution/styles/default-pdf.css (A4 print stylesheet)
#   design-system/diagrams/*.svg                   (architecture diagrams)
#   milosvasic.ru/assets/images/milosvasic.png     (letterhead photo)
#
# Outputs:
#   milosvasic.ru/downloads/Milos_Vasic_CV_EN.pdf
#   milosvasic.ru/downloads/Milos_Vasic_Cover_Letter_EN.pdf
#   milosvasic.ru/downloads/Portfolio_EN.pdf
#
# Dependencies: pandoc, weasyprint, pdftoppm, python3, base64.
#
# Usage:  bash _tools/pdf/build-pdfs.sh [lang]      (default: en)
#
# Per-language behaviour:
#   * Source docs are read from _content_<lang>/docs/*.md when that directory
#     exists; otherwise the EN masters in _content/docs are used (fallback).
#   * Output files are suffixed with the UPPERCASE language code, e.g.
#     Milos_Vasic_CV_DE.pdf, Portfolio_DE.pdf (company variant to vasic.digital).
#   * The generated HTML carries the correct `lang` (and `dir="rtl"` for ar/fa)
#     so WeasyPrint applies the right hyphenation / bidi.
#   * Non-Latin scripts (ar/fa RTL, zh/ja/ko CJK) are rendered with self-hosted
#     Noto faces (SIL OFL 1.1) committed under _tools/pdf/fonts/ and wired via
#     an @font-face + per-glyph font-family fallback (see lang_font_css). The
#     Latin safe stack still resolves all Latin runs (metrics + pdftotext stay
#     identical to the EN path); only Arabic/CJK glyphs fall through to Noto, so
#     those PDFs show real characters instead of tofu boxes. No fontconfig
#     install required. Latin languages emit NO override (byte-identical HTML).
#
set -euo pipefail

# ---- resolve repo root (this script lives at <root>/_tools/pdf/) ------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

# ---- language selection -----------------------------------------------------
LANG_CODE="${1:-en}"
LANG_CODE="$(printf '%s' "$LANG_CODE" | tr '[:upper:]' '[:lower:]')"
LANG_UP="$(printf '%s' "$LANG_CODE" | tr '[:lower:]' '[:upper:]')"

# Source docs: prefer the localized _content_<lang>/docs, else fall back to EN.
DOCS_FALLBACK="no"
if [ "$LANG_CODE" != "en" ] && [ -d "$ROOT/_content_${LANG_CODE}/docs" ] \
     && ls "$ROOT/_content_${LANG_CODE}/docs"/*.md >/dev/null 2>&1; then
  DOCS_DIR="$ROOT/_content_${LANG_CODE}/docs"
else
  DOCS_DIR="$ROOT/_content/docs"
  [ "$LANG_CODE" != "en" ] && DOCS_FALLBACK="yes"
fi

# Optional opt-in source override (unset in normal deploy runs, so behaviour is
# byte-identical). Used only to drive mechanism/verification builds from a
# scratch doc set when a real _content_<lang>/docs is not yet present.
if [ -n "${DOCS_DIR_OVERRIDE:-}" ]; then
  DOCS_DIR="$DOCS_DIR_OVERRIDE"
  DOCS_FALLBACK="no"
fi

# HTML lang attribute + bidi direction (ar/fa are RTL).
HTML_LANG="$LANG_CODE"
case "$LANG_CODE" in
  ar|fa|he|ur) HTML_DIR="rtl" ;;
  *)           HTML_DIR="ltr" ;;
esac

# ---- portable file mtime ----------------------------------------------------
# A CHAIN OF `||` IS NOT ENOUGH, and the obvious repair is itself broken.
# `stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null` LOOKS like a
# BSD-first dispatch, but on GNU coreutils `-f` is --file-system and takes no
# argument, so `%m` is parsed as a FILE operand. GNU stat then fails on `%m`
# (stderr, swallowed by 2>/dev/null) AND SUCCEEDS on "$f", writing a full
# filesystem report to STDOUT, exiting 1 because one operand failed. The `||`
# fires on that rc=1, the GNU spelling appends the real epoch, and the command
# substitution returns BOTH CONCATENATED. Measured on GNU coreutils 9.4:
#   stat -f %m _content/docs/cv.md; echo "rc=$?"     # 5 lines of btrfs stats, rc=1
#   m=$(stat -f %m f 2>/dev/null || stat -c %Y f 2>/dev/null || echo 0); echo "[$m]"
# yielded a 244-byte string, not an epoch. The `[ "$m" -gt "$newest" ]`
# comparison downstream then died with "integer expression expected" on every
# file after the first, so `newest` stayed pinned to whatever the FIRST glob
# entry produced and the newest-mtime selection never ran at all - silently,
# with the block still exiting 0.
#
# THE BSD HALF, NOW MEASURED AND NOT ONLY REASONED ABOUT (2026-09-01). The text
# above measured what GNU does; what BSD does was previously asserted. It has
# since been exercised against FreeBSD 14.2 usr.bin/stat, built from vendor
# source and run on this host:
#
#   BSD  stat -f %m <file>   -> "1788279584", rc 0, NOTHING on stderr
#   GNU  stat -f %m <file>   -> 233 bytes of filesystem report on STDOUT, rc 1
#   BSD  stat -c %Y <file>   -> EMPTY stdout, rc 1, "invalid option -- 'c'" on
#                               stderr (the option string is "f:FHlLnqrst:x",
#                               which contains no `c`)
#
# So the two spellings fail ASYMMETRICALLY, and that asymmetry is the whole
# hazard: the GNU-only spelling fails CLEANLY on BSD, while the BSD-only
# spelling fails DIRTILY on GNU. A BSD-first `||` chain is therefore safe on
# BSD and broken on GNU — which is exactly how the historical defect hid.
#
# A third implementation makes the rule non-negotiable: toybox 0.8.13, measured
# the same day, writes 215 bytes of filesystem report to stdout for `stat -f`
# AND EXITS 0. There an exit-status test does not merely accept garbage, it
# never fires at all.
#
# So each spelling is run ON ITS OWN and its OUTPUT is validated, not its exit
# status. An exit status cannot distinguish "worked" from "half-worked and
# printed garbage", which is the entire lesson of that defect. A host where
# neither spelling yields a bare epoch is UNDETERMINED (rc 1), never a silent 0.
# Same shape as submodules/{RAG,LLMProvider}/challenges/scripts/
# host_no_auto_suspend_challenge.sh:portable_mtime - one idiom, not two.
portable_mtime() {
  local m
  for m in "$(stat -c %Y "$1" 2>/dev/null)" "$(stat -f %m "$1" 2>/dev/null)"; do
    if [[ "$m" =~ ^[0-9]+$ ]]; then
      printf '%s\n' "$m"
      return 0
    fi
  done
  return 1
}

# ---- §1.1 paired-mutation gate for the mtime probe --------------------------
#   bash _tools/pdf/build-pdfs.sh --prove-mtime
# Three-valued, as every check in this tree must be: 0 the probe works, 1 the
# probe is broken, 2 COULD NOT DETERMINE (never a pass). It builds a synthetic
# doc set with three KNOWN, distinct mtimes whose oldest sorts FIRST in glob
# order - that ordering is load-bearing, because the historical defect pinned
# `newest` to the first entry, so a fixture where the newest came first would
# have passed while broken. It then re-invokes this script through
# DOCS_DIR_OVERRIDE and asserts the pinned value, NOT the exit status: the
# defect this guards exited 0 the whole time.
# Mutation proof: restore the `stat -f %m ... || stat -c %Y ...` one-liner in
# portable_mtime and this gate returns 1 on all three assertions.
# It writes only into a mktemp dir, needs no pandoc/weasyprint, and touches no
# tracked artifact - safe to run at any time.
if [ "${1:-}" = "--prove-mtime" ]; then
  pw="$(mktemp -d)"; trap 'rm -rf "$pw"' EXIT
  mkdir -p "$pw/docs"
  : > "$pw/docs/cover-letter.md"; : > "$pw/docs/cv.md"; : > "$pw/docs/portfolio.md"
  # GNU touch spells this `-d @EPOCH`; BSD/macOS touch needs `-t CCYYMMDDhhmm`.
  # Try both, then CONFIRM by reading back - an unverified fixture is not a
  # fixture, and a host where neither spelling lands is UNDETERMINED.
  set_mtime() {
    touch -d "@$2" "$1" 2>/dev/null && return 0
    touch -t "$(date -u -r "$2" +%Y%m%d%H%M 2>/dev/null \
                || date -u -d "@$2" +%Y%m%d%H%M 2>/dev/null)" "$1" 2>/dev/null
  }
  set_mtime "$pw/docs/cover-letter.md" 1000000000 || true   # oldest, glob-first
  set_mtime "$pw/docs/cv.md"           1500000000 || true
  set_mtime "$pw/docs/portfolio.md"    2000000000 || true   # newest = expected
  # The readback deliberately does NOT call portable_mtime. A gate that
  # establishes its own fixture with the function under test cannot fail when
  # that function breaks - it can only report UNDETERMINED, which would launder
  # a real defect into "could not verify". These three lines are duplicated on
  # purpose so the gate stays independent of its subject.
  readback() {
    local v
    for v in "$(stat -c %Y "$1" 2>/dev/null)" "$(stat -f %m "$1" 2>/dev/null)"; do
      case "$v" in ''|*[!0-9]*) ;; *) printf '%s' "$v"; return 0 ;; esac
    done
    return 1
  }
  for chk in cover-letter:1000000000 cv:1500000000 portfolio:2000000000; do
    if [ "$(readback "$pw/docs/${chk%%:*}.md" || echo x)" != "${chk##*:}" ]; then
      echo "UNDETERMINED: cannot establish a known mtime on this host - the" >&2
      echo "  fixture is unverified, so this gate reports neither pass nor fail." >&2
      exit 2
    fi
  done
  pe="$(env -u SOURCE_DATE_EPOCH DOCS_DIR_OVERRIDE="$pw/docs" \
        PDF_EMIT_EPOCH_AND_EXIT=1 bash "${BASH_SOURCE[0]}" en 2>"$pw/err")" || true
  pf=0
  echo "--prove-mtime: SOURCE_DATE_EPOCH = <<<$pe>>> (${#pe} bytes)"
  case "$pe" in
    ''|*[!0-9]*) echo "  FAIL  probe returned no bare integer"; pf=1 ;;
    *)           echo "  PASS  probe returned a bare integer" ;;
  esac
  if [ "$pe" = 2000000000 ]; then echo "  PASS  newest mtime selected"
  else echo "  FAIL  newest mtime not selected (expected 2000000000)"; pf=1; fi
  if grep -q 'integer expression expected' "$pw/err" 2>/dev/null; then
    echo "  FAIL  numeric comparison broke and was masked"; pf=1
  else echo "  PASS  no masked numeric-comparison failure"; fi

  # M4 - THE BSD SIDE, MEASURED when a genuine BSD `stat` is supplied in
  # VASIC_BSD_STAT. The binary is probed for the BSD contract first (`-c` must
  # give EMPTY stdout, `-f %m` a bare epoch) so a non-BSD binary cannot be
  # mislabelled. With nothing supplied this prints NOT MEASURED and asserts
  # nothing: an untested platform claim stays could-not-determine and is never
  # relabelled into a pass.
  bsd_stat="${VASIC_BSD_STAT:-}"
  if [ -n "$bsd_stat" ] && [ -x "$bsd_stat" ]; then
    # `|| true` under `set -e`: the FIRST probe is expected to fail, because a
    # genuine BSD stat rejects `-c`. Without it the gate would die measuring
    # exactly the fact it exists to record.
    pc="$("$bsd_stat" -c %Y "$pw/docs/portfolio.md" 2>/dev/null || true)"
    pm="$("$bsd_stat" -f %m "$pw/docs/portfolio.md" 2>/dev/null || true)"
    if [ -z "$pc" ] && [ "$pm" = "2000000000" ]; then
      mkdir -p "$pw/bin-bsd"; ln -sf "$bsd_stat" "$pw/bin-bsd/stat"
      got="$(PATH="$pw/bin-bsd:$PATH"; hash -r; portable_mtime "$pw/docs/portfolio.md" || echo x)"
      if [ "$got" = "2000000000" ]; then
        echo "  PASS  BSD-measured: portable_mtime returned 2000000000 through $bsd_stat"
      else
        echo "  FAIL  BSD-measured: expected 2000000000, got '$got' through $bsd_stat"; pf=1
      fi
    else
      echo "  NOTE  VASIC_BSD_STAT did not answer to the BSD contract"
      echo "        (-c gave ${#pc} bytes, -f %m gave '$pm'); BSD side NOT measured"
    fi
  else
    echo "  NOTE  BSD side NOT MEASURED in this run - no VASIC_BSD_STAT supplied."
    echo "        Build recipe: docs/environment-adaptability/AUDIT.md"
  fi

  [ "$pf" -eq 0 ] && { echo "--prove-mtime: GREEN"; exit 0; }
  echo "--prove-mtime: RED"; exit 1
fi

# ---- reproducible output (idempotent re-runs) -------------------------------
# WeasyPrint may stamp /CreationDate + /ModDate (it does so only when the source
# HTML carries dcterms.created / dcterms.modified), so naive re-runs can differ
# byte-wise and would make every deploy cycle look "changed". Pin
# SOURCE_DATE_EPOCH to the NEWEST mtime among the source docs: identical content
# ⇒ identical bytes ⇒ git no-op; changed content ⇒ fresh timestamp ⇒ a real
# commit. Caller-provided SOURCE_DATE_EPOCH is respected.
#
# Honest boundary (§11.4.6): this pin is defence in depth, not a measured
# dependency. WeasyPrint 69.0 contains ZERO references to SOURCE_DATE_EPOCH
# (verified by grep over weasyprint/ and pydyf/), and this script emits no
# dcterms metadata, so on that version the PDFs are already date-free and
# byte-stable without the pin. Do not delete it on that basis: the value also
# documents build provenance, the metadata may be added later, and the mechanism
# must be correct before it is relied upon. Re-derive before claiming otherwise.
if [ -z "${SOURCE_DATE_EPOCH:-}" ]; then
  newest=""
  for f in "$DOCS_DIR"/*.md; do
    [ -f "$f" ] || continue
    # A file whose mtime cannot be read is skipped LOUDLY rather than folded
    # into the pin as a 0, which would silently drag the epoch to 1970.
    if ! m="$(portable_mtime "$f")"; then
      echo "WARN: cannot read mtime of $f - excluded from SOURCE_DATE_EPOCH pin" >&2
      continue
    fi
    if [ -z "$newest" ] || [ "$m" -gt "$newest" ]; then
      newest="$m"
    fi
  done
  export SOURCE_DATE_EPOCH="${newest:-1700000000}"
fi

# Probe seam for --prove-mtime (below). Unset in every normal run, so the build
# path is byte-identical; set only by the gate re-invoking this same script, so
# the gate exercises the REAL pinning code rather than a copy of it.
if [ -n "${PDF_EMIT_EPOCH_AND_EXIT:-}" ]; then
  printf '%s' "$SOURCE_DATE_EPOCH"
  exit 0
fi

TOKENS_CSS="$ROOT/design-system/brand-milosvasic/milosvasic.css"
PRINT_CSS="$ROOT/submodules/constitution/styles/default-pdf.css"
DIAG_DIR="$ROOT/design-system/diagrams"
FONT_DIR="$ROOT/_tools/pdf/fonts"        # self-hosted Noto Arabic + CJK (OFL 1.1)
PHOTO="$ROOT/milosvasic.ru/assets/images/milosvasic.png"
# Output dir is overridable (OUT_DIR_OVERRIDE) so verification builds can target a
# scratch dir WITHOUT touching the committed site downloads/. Unset in deploy runs.
OUT_DIR="${OUT_DIR_OVERRIDE:-$ROOT/milosvasic.ru/downloads}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for tool in pandoc weasyprint pdftoppm python3 base64; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FATAL: required tool '$tool' not found on PATH" >&2; exit 1; }
done
for f in "$TOKENS_CSS" "$PRINT_CSS" "$PHOTO"; do
  [ -f "$f" ] || { echo "FATAL: missing input: $f" >&2; exit 1; }
done
mkdir -p "$OUT_DIR"

# ---- localized PDF "chrome" strings (#65) -----------------------------------
# The cover eyebrow/role/tagline, metrics-strip labels, running headers, and the
# Portfolio "Selected architecture" heading + figure captions were previously
# HARDCODED in English, leaking English into every non-EN PDF. They now live in
# _tools/pdf/pdf-i18n.json (EN populated from the old literals; 14 langs via the
# HelixTranslate pipeline + reviewer). `t <key>` returns the string for the
# active LANG_CODE and falls back to EN for a genuinely-missing key WITH A WARNING
# — never a silent English leak.
I18N_JSON="$ROOT/_tools/pdf/pdf-i18n.json"
[ -f "$I18N_JSON" ] || { echo "FATAL: missing chrome-i18n table: $I18N_JSON" >&2; exit 1; }
t() {
  python3 - "$I18N_JSON" "$LANG_CODE" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
lang, key = sys.argv[2], sys.argv[3]
v = data.get(lang, {}).get(key)
if v is None or v == "":
    v = data.get("en", {}).get(key, "")
    sys.stderr.write("  WARN: pdf-i18n missing '%s' for lang '%s' — EN fallback\n" % (key, lang))
sys.stdout.write(v)
PY
}

# ---- photo as a data URI (guarantees an embedded raster image) --------------
PHOTO_B64="$(base64 < "$PHOTO" | tr -d '\n')"
PHOTO_URI="data:image/png;base64,${PHOTO_B64}"

# ---- vasic.digital company variant inputs -----------------------------------
# The Portfolio PDF is also published for the company site, branded with the
# vasic-digital DEEP-DARK-RED tokens and the company logo (not Miloš's photo).
VASIC_TOKENS_CSS="$ROOT/design-system/brand-vasic-digital/vasic-digital.css"
VASIC_LOGO="$ROOT/vasic.digital/Assets/Logo.jpeg"
VASIC_OUT_DIR="${VASIC_OUT_DIR_OVERRIDE:-$ROOT/vasic.digital/downloads}"
LOGO_URI=""
if [ -f "$VASIC_LOGO" ]; then
  LOGO_URI="data:image/jpeg;base64,$(base64 < "$VASIC_LOGO" | tr -d '\n')"
fi
mkdir -p "$VASIC_OUT_DIR"

# ---- rasterise one architecture SVG -> embeddable data:image/png -------------
# WeasyPrint cannot resolve the diagrams' `var(--…)` tokens / dark @media, so we
# flatten the tokens to their documented LIGHT hex values, render the concrete
# SVG to a raster PNG via a WeasyPrint->pdftoppm round-trip (only installed
# tools), and return a base64 data-URI. Rasterising also guarantees pdfimages
# finds the figures. Prints the data-URI on stdout.
raster_datauri() {
  local svg="$1"
  local base; base="$(basename "${svg%.svg}")"
  python3 - "$svg" "$WORK/${base}.wrap.html" <<'PY'
import sys, re
src = open(sys.argv[1]).read()
light = {'ink':'#1e293b','muted':'#475569','line':'#94a3b8','accent':'#a31e39',
         'panel':'#f8fafc','panel2':'#eef2f7','tint':'#f4dde1','good':'#dcfce7',
         'goodln':'#16a34a','goodink':'#14532d'}
for k, v in light.items():
    src = src.replace('var(--%s)' % k, v)
# drop the dark-mode @media block (nested braces) so nothing shadows the light hex
src = re.sub(r'@media\(prefers-color-scheme:dark\)\{[^}]*\{[^}]*\}[^}]*\}', '', src)
m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', src)
w, h = (int(float(m.group(1))), int(float(m.group(2)))) if m else (960, 560)
html = ('<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
        '@page{size:%dpx %dpx;margin:0}html,body{margin:0;padding:0}'
        'svg{display:block;width:%dpx;height:%dpx}</style></head><body>%s</body></html>'
        % (w, h, w, h, src))
open(sys.argv[2], 'w').write(html)
PY
  weasyprint "$WORK/${base}.wrap.html" "$WORK/${base}.raster.pdf" >/dev/null 2>&1
  pdftoppm -r 200 -png "$WORK/${base}.raster.pdf" "$WORK/${base}.raster" >/dev/null 2>&1
  local png; png="$(ls "$WORK/${base}.raster"*.png 2>/dev/null | head -1)"
  [ -f "$png" ] || { echo "FATAL: rasterise failed for $svg" >&2; exit 1; }
  echo "data:image/png;base64,$(base64 < "$png" | tr -d '\n')"
}

# ---- brand + layout CSS: OpenDesign tokens applied over pandoc's plain HTML ---
# Colours/spacing/rules/scale only — font-family is left to the safe stack from
# default-pdf.css so pdftotext extraction stays clean per §11.4.115.
#   $1 accent var   $2 header-left (name)   $3 header-right (document)
brand_css() {
  local accent="$1" hleft="$2" hright="$3"
  cat <<CSS
/* ===== OpenDesign PDF theme (enterprise typographic system) ============== */

/* Running header / footer via @page margin boxes; cover page clears them. */
@page {
  size: A4;
  margin: 24mm 17mm 20mm 17mm;
  @top-left     { content: "${hleft}"; font-size: 7.5pt; letter-spacing: 0.06em;
                  text-transform: uppercase; color: var(--od-text-muted); }
  @top-right    { content: "${hright}"; font-size: 7.5pt; letter-spacing: 0.06em;
                  text-transform: uppercase; color: ${accent}; }
  @bottom-left  { content: "milosvasic.ru · vasic.digital"; font-size: 7.5pt;
                  color: var(--od-text-muted); }
  @bottom-right { content: counter(page) " / " counter(pages); font-size: 7.5pt;
                  color: var(--od-text-muted); }
  @bottom-center { content: ""; }
}
@page:first {
  margin: 0;
  @top-left { content: ""; } @top-right { content: ""; }
  @bottom-left { content: ""; } @bottom-right { content: ""; } @bottom-center { content: ""; }
}

.od-doc { color: var(--od-text); font-size: 10.3pt; line-height: 1.5; }

/* ---- Cover page --------------------------------------------------------- */
.od-cover {
  break-after: page;
  box-sizing: border-box;
  min-height: 296mm;
  padding: 34mm 24mm 28mm 24mm;
  display: flex; flex-direction: column;
  position: relative;
  border-top: 10mm solid ${accent};
}
/* subtle geometric section accent — a tinted band + offset rule */
.od-cover::before {
  content: "";
  position: absolute; top: 10mm; right: 0; width: 62mm; height: 62mm;
  background: var(--od-accent-50);
  border-left: 2px solid var(--od-accent-200);
}
.od-cover__eyebrow {
  font-family: "Liberation Mono", "DejaVu Sans Mono", "Courier New", monospace;
  font-size: 9pt; letter-spacing: 0.22em; text-transform: uppercase;
  color: ${accent}; margin: 0 0 6mm 0; position: relative;
}
.od-cover__id { display: flex; align-items: flex-start; gap: 10mm; position: relative; margin-top: 4mm; }
.od-cover__id > div { max-width: 118mm; }
.od-cover__photo {
  width: 34mm; height: 45mm; object-fit: cover; flex: none;
  border-radius: var(--od-radius-md); border: 1px solid var(--od-border);
  box-shadow: 0 2mm 5mm rgba(0,0,0,0.10);
}
.od-cover__name {
  font-size: 40pt; font-weight: 700; line-height: 1.02;
  letter-spacing: -0.02em; color: var(--od-text); margin: 0;
}
.od-cover__role { font-size: 15pt; font-weight: 600; color: ${accent}; margin: 5mm 0 0 0; letter-spacing: -0.01em; }
.od-cover__rule { border: 0; border-top: 3px solid ${accent}; width: 46mm; margin: 8mm 0 0 0; }
.od-cover__tagline {
  font-size: 12.5pt; line-height: 1.5; color: var(--od-text-muted);
  max-width: 128mm; margin: 8mm 0 0 0;
}
.od-cover__spacer { flex: 1 1 auto; }
.od-cover__contact {
  position: relative; border-top: 1px solid var(--od-border); padding-top: 6mm;
  font-size: 9.5pt; color: var(--od-text-muted); line-height: 1.7;
}
.od-cover__contact b { color: var(--od-text); font-weight: 600; }

/* ---- At-a-glance metrics strip ----------------------------------------- */
.od-metrics {
  display: flex; gap: 4mm; margin: 0 0 8mm 0;
  break-inside: avoid; page-break-inside: avoid;
}
.od-metric {
  flex: 1 1 0; background: var(--od-surface); border: 1px solid var(--od-border);
  border-top: 2.5px solid ${accent}; border-radius: var(--od-radius-md);
  padding: 4mm 4mm 3.5mm 4mm; text-align: left;
}
.od-metric__v { font-size: 22pt; font-weight: 700; line-height: 1; letter-spacing: -0.02em; color: ${accent}; }
.od-metric__l { font-size: 7.6pt; letter-spacing: 0.03em; text-transform: uppercase; color: var(--od-text-muted); margin-top: 2.4mm; line-height: 1.35; }

/* ---- Body typographic hierarchy + rhythm -------------------------------- */
.od-doc > h1:first-of-type { display: none; }   /* identity lives on the cover — no duplicate */

.od-doc h1 {
  font-size: 20pt; font-weight: 700; letter-spacing: -0.02em; color: ${accent};
  margin: 0 0 4mm 0; padding-bottom: 2.5mm; border-bottom: 2px solid var(--od-accent-200);
  break-after: avoid; page-break-after: avoid;
}
.od-doc h2 {
  font-size: 14pt; font-weight: 700; letter-spacing: -0.01em; color: var(--od-text);
  margin: 7mm 0 3mm 0; padding-left: 3.5mm; border-left: 3px solid ${accent};
  break-after: avoid; page-break-after: avoid;
}
.od-doc h3 {
  font-size: 11.4pt; font-weight: 700; color: var(--od-accent-800);
  margin: 5mm 0 1.6mm 0; break-after: avoid; page-break-after: avoid;
}
.od-doc h4 { font-size: 10.4pt; font-weight: 700; color: var(--od-text); margin: 3.5mm 0 1mm 0; }
.od-doc p  { margin: 0 0 2.6mm 0; }
.od-doc a  { color: ${accent}; text-decoration: none; }
.od-doc strong { color: var(--od-accent-900); font-weight: 700; }
.od-doc em { color: var(--od-text-muted); }
.od-doc ul, .od-doc ol { padding-inline-start: 6mm; margin: 0 0 2.6mm 0; }
.od-doc li { margin-bottom: 1.4mm; }
.od-doc li::marker { color: ${accent}; }
.od-doc code {
  font-family: "Liberation Mono", "DejaVu Sans Mono", "Courier New", monospace;
  background: var(--od-surface-2); border-radius: var(--od-radius-sm);
  padding: 0 1mm; font-size: 8.6pt; color: var(--od-accent-900);
}
.od-doc hr { border: 0; border-top: 1px solid var(--od-border); margin: 5mm 0; }
.od-doc blockquote {
  border-inline-start: 3px solid ${accent}; padding-inline-start: 4mm;
  margin: 0 0 3mm 0; color: var(--od-text-muted); font-style: italic;
}
.od-doc p, .od-doc li { orphans: 2; widows: 2; }

/* ---- Embedded architecture figures (Portfolio) -------------------------- */
.od-figures { margin-top: 3mm; }
.od-figure { break-inside: avoid; page-break-inside: avoid; margin: 0 0 7mm 0; }
.od-figure img {
  width: 100%; height: auto; display: block;
  border: 1px solid var(--od-border); border-radius: var(--od-radius-md);
  background: #ffffff;
}
.od-figure figcaption {
  font-size: 8.6pt; color: var(--od-text-muted); margin-top: 2mm;
  padding-left: 3mm; border-left: 2px solid ${accent};
}
.od-figure figcaption b { color: var(--od-text); font-weight: 700; }
CSS
}

# ---- per-language non-Latin font wiring -------------------------------------
# default-pdf.css hard-pins body/headings to the Liberation/DejaVu Latin safe
# stack (§11.4.115) — that stack has NO Arabic or CJK glyphs, so ar/fa/zh/ja/ko
# text would render as tofu boxes. Here we self-host the matching Noto face
# (SIL OFL 1.1, committed under _tools/pdf/fonts/), register it via @font-face,
# and APPEND it as a per-glyph fallback AFTER the Latin faces. Because font
# fallback is per-glyph, Latin runs still resolve to Liberation/DejaVu (metrics
# + pdftotext stay identical to the EN/Latin path) while Arabic/CJK glyphs
# resolve to the Noto face — real characters, not boxes. This function prints
# NOTHING for Latin languages, so the EN/Latin generated HTML is byte-identical.
#
#   ar, fa  -> Noto Sans Arabic  (Arabic script; covers Persian peh/che/yeh/gaf)
#   zh      -> Noto Sans SC       ja -> Noto Sans JP       ko -> Noto Sans KR
lang_font_css() {
  local family="" file=""
  case "$LANG_CODE" in
    ar|fa) family="Noto Sans Arabic"; file="$FONT_DIR/noto-sans-arabic/NotoSansArabic.ttf" ;;
    zh)    family="Noto Sans CJK";    file="$FONT_DIR/noto-sans-cjk/NotoSansSC.ttf" ;;
    ja)    family="Noto Sans CJK";    file="$FONT_DIR/noto-sans-cjk/NotoSansJP.ttf" ;;
    ko)    family="Noto Sans CJK";    file="$FONT_DIR/noto-sans-cjk/NotoSansKR.ttf" ;;
    *)     return 0 ;;   # Latin languages: no override — path stays byte-identical
  esac
  [ -f "$file" ] || { echo "FATAL: missing self-hosted font for lang '$LANG_CODE': $file" >&2; exit 1; }

  # Arabic goes first in the stack (correct RTL shaping/joining); CJK goes after
  # the Latin faces (Latin stays on Liberation, CJK glyphs fall through to Noto).
  local sans mono
  case "$LANG_CODE" in
    ar|fa) sans="\"Liberation Sans\", \"${family}\", \"DejaVu Sans\", sans-serif"
           mono="\"Liberation Mono\", \"${family}\", \"DejaVu Sans Mono\", monospace" ;;
    *)     sans="\"Liberation Sans\", \"DejaVu Sans\", \"${family}\", \"Noto Sans\", sans-serif"
           mono="\"Liberation Mono\", \"DejaVu Sans Mono\", \"${family}\", monospace" ;;
  esac

  cat <<CSS
<style>
/* Self-hosted non-Latin glyph fallback (OFL 1.1) — WeasyPrint embeds it. */
@font-face {
  font-family: "${family}";
  src: url("file://${file}") format("truetype");
  font-weight: 100 900;
  font-style: normal;
}
/* Append the Noto face as a per-glyph fallback. !important + .od-doc scoping
   beat default-pdf.css's element-level pin without touching the Latin path. */
.od-doc, .od-doc p, .od-doc li, .od-doc h1, .od-doc h2, .od-doc h3, .od-doc h4,
.od-doc td, .od-doc th, .od-doc dt, .od-doc dd, .od-doc caption,
.od-doc a, .od-doc strong, .od-doc em, .od-doc blockquote,
.od-cover__name, .od-cover__role, .od-cover__tagline, .od-cover__contact,
.od-metric__v, .od-metric__l, .od-figure figcaption {
  font-family: ${sans} !important;
}
.od-doc code, .od-doc pre, .od-cover__eyebrow {
  font-family: ${mono} !important;
}
</style>
CSS
}

# ---- cover-page HTML --------------------------------------------------------
#   $1 name  $2 role  $3 eyebrow  $4 tagline  $5 contact-html  $6 cover-image-uri
cover_html() {
  local cover_img="${6:-$PHOTO_URI}"
  cat <<HTML
<section class="od-cover">
  <p class="od-cover__eyebrow">$3</p>
  <div class="od-cover__id">
    <img class="od-cover__photo" src="${cover_img}" alt="$1">
    <div>
      <p class="od-cover__name">$1</p>
      <p class="od-cover__role">$2</p>
      <hr class="od-cover__rule">
      <p class="od-cover__tagline">$4</p>
    </div>
  </div>
  <div class="od-cover__spacer"></div>
  <div class="od-cover__contact">$5</div>
</section>
HTML
}

# ---- metric strip HTML ------------------------------------------------------
metric() { printf '<div class="od-metric"><div class="od-metric__v">%s</div><div class="od-metric__l">%s</div></div>' "$1" "$2"; }

# ---- render one document -----------------------------------------------------
# args: <md-basename> <out-basename> <accent-var> [tokens-css] [cover-img-uri] [out-dir] [variant]
build() {
  local base="$1" out="$2" accent="$3"
  local tokens="${4:-$TOKENS_CSS}"
  local coverimg="${5:-$PHOTO_URI}"
  local outdir="${6:-$OUT_DIR}"
  local variant="${7:-personal}"
  local md="$DOCS_DIR/${base}.md"
  [ -f "$md" ] || { echo "  -- skip ${out}: no source ${md}"; return 0; }

  pandoc "$md" -f markdown+yaml_metadata_block -t html5 --syntax-highlighting=none \
    -o "$WORK/${out}.frag.html"

  # per-document identity + extras
  local name role eyebrow tagline contact hleft hright metrics figures
  name="Miloš Vasić"; hleft="Miloš Vasić"
  metrics=""; figures=""
  case "$base" in
    cv)
      role="$(t cv.role)"; hright="$(t cv.eyebrow)"
      eyebrow="$(t cv.eyebrow)"
      tagline="$(t cv.tagline)"
      contact='<b>milos85vasic@gmail.com</b> &nbsp;·&nbsp; milosvasic.ru &nbsp;·&nbsp; vasic.digital<br>GitHub: vasic-digital &nbsp;·&nbsp; HelixDevelopment &nbsp;·&nbsp; Server-Factory'
      metrics="<div class=\"od-metrics\">$(metric 2009 "$(t cv.metric.since)")$(metric '140+' "$(t cv.metric.repos)")$(metric 43 "$(t cv.metric.providers)")$(metric '6+' "$(t cv.metric.langs)")</div>"
      ;;
    cover-letter)
      role="$(t cover.role)"; hright="$(t cover.eyebrow)"
      eyebrow="$(t cover.eyebrow)"
      tagline="$(t cover.tagline)"
      contact='<b>milos85vasic@gmail.com</b> &nbsp;·&nbsp; milosvasic.ru &nbsp;·&nbsp; vasic.digital'
      ;;
    portfolio)
      if [ "$variant" = "company" ]; then
        name="Vasic Digital"; hleft="Vasic Digital"
        role="$(t pf.role.company)"; hright="$(t pf.header)"
        eyebrow="$(t pf.eyebrow)"
        tagline="$(t pf.tagline.company)"
        contact='<b>vasic.digital</b> &nbsp;·&nbsp; milosvasic.ru &nbsp;·&nbsp; github.com/vasic-digital &nbsp;·&nbsp; github.com/HelixDevelopment'
      else
        name="Miloš Vasić"; hleft="Miloš Vasić"
        role="$(t pf.role)"; hright="$(t pf.header)"
        eyebrow="$(t pf.eyebrow)"
        tagline="$(t pf.tagline)"
        contact='<b>milosvasic.ru</b> &nbsp;·&nbsp; vasic.digital &nbsp;·&nbsp; github.com/HelixDevelopment &nbsp;·&nbsp; github.com/vasic-digital'
      fi
      metrics="<div class=\"od-metrics\">$(metric '140+' "$(t pf.metric.fleet)")$(metric 43 "$(t pf.metric.providers)")$(metric 25 "$(t pf.metric.distros)")$(metric 439 "$(t pf.metric.tests)")</div>"
      # rasterise 3 relevant architecture diagrams and embed them
      local d_agent d_cluster d_verifier fig_heading
      d_agent="$(raster_datauri "$DIAG_DIR/helixagent.svg")"
      d_cluster="$(raster_datauri "$DIAG_DIR/helixcluster.svg")"
      d_verifier="$(raster_datauri "$DIAG_DIR/llmsverifier.svg")"
      fig_heading="$(t pf.figures.heading)"
      # Product names (HelixAgent/HelixCluster/LLMsVerifier) are non-translatable
      # glossary brands and stay verbatim; only the caption PROSE is localized.
      figures="$(cat <<FIG
<section class="od-figures">
<h2>${fig_heading}</h2>
<figure class="od-figure"><img src="${d_agent}" alt="HelixAgent ensemble debate flow"><figcaption><b>HelixAgent</b> — $(t pf.figure.helixagent)</figcaption></figure>
<figure class="od-figure"><img src="${d_cluster}" alt="HelixCluster distributed compute control plane"><figcaption><b>HelixCluster</b> — $(t pf.figure.helixcluster)</figcaption></figure>
<figure class="od-figure"><img src="${d_verifier}" alt="LLMsVerifier verification source of truth"><figcaption><b>LLMsVerifier</b> — $(t pf.figure.llmsverifier)</figcaption></figure>
</section>
FIG
)"
      ;;
    *)
      role="AI Engineer"; hright="Document"; eyebrow="Document"; tagline=""; contact="milosvasic.ru"
      ;;
  esac

  {
    echo "<!DOCTYPE html><html lang=\"${HTML_LANG}\" dir=\"${HTML_DIR}\"><head><meta charset=\"utf-8\">"
    echo "<title>${name} — ${role}</title>"
    echo '<style>'; cat "$tokens"; echo '</style>'
    echo '<style>'; cat "$PRINT_CSS";  echo '</style>'
    echo '<style>'; brand_css "$accent" "$hleft" "$hright"; echo '</style>'
    if [ "$HTML_DIR" = "rtl" ]; then
      # Bidi fixes: mirror the cover identity row and the accent band; the body
      # already uses logical (inline) properties so it flips automatically.
      cat <<'RTLCSS'
<style>
.od-doc { direction: rtl; }
.od-cover__id { flex-direction: row-reverse; }
.od-cover::before { right: auto; left: 0; border-left: 0; border-right: 2px solid var(--od-accent-200); }
.od-metrics, .od-metric { text-align: right; }
</style>
RTLCSS
    fi
    # Non-Latin glyph fallback (ar/fa Arabic, zh/ja/ko CJK); prints nothing for
    # Latin langs so the EN/Latin generated HTML stays byte-identical.
    lang_font_css
    echo '</head><body><div class="od-doc">'
    cover_html "$name" "$role" "$eyebrow" "$tagline" "$contact" "$coverimg"
    echo "$metrics"
    cat "$WORK/${out}.frag.html"
    echo "$figures"
    echo '</div></body></html>'
  } > "$WORK/${out}.html"

  weasyprint "$WORK/${out}.html" "$outdir/${out}.pdf" >/dev/null 2>&1
  echo "  -> $outdir/${out}.pdf ($(du -h "$outdir/${out}.pdf" | cut -f1))"
}

echo "Building OpenDesign-themed A4 PDFs [lang=${LANG_CODE} dir=${HTML_DIR}] -> $OUT_DIR"
echo "  source docs: $DOCS_DIR$([ "$DOCS_FALLBACK" = "yes" ] && echo '  (EN fallback — _content_'"${LANG_CODE}"'/docs not present yet)')"

# CV / Cover Letter = personal crimson brand (accent-700).
build "cv"           "Milos_Vasic_CV_${LANG_UP}"           "var(--od-accent-700)"
build "cover-letter" "Milos_Vasic_Cover_Letter_${LANG_UP}" "var(--od-accent-700)"
# Portfolio = the unified accent (accent-800), shared by vasic.digital & milosvasic.ru.
build "portfolio"    "Portfolio_${LANG_UP}"                "var(--od-accent-800)"

# vasic.digital company Portfolio — deep-dark-red company tokens + company logo,
# published at vasic.digital/downloads/Portfolio_<LANG>.pdf.
if [ -n "$LOGO_URI" ]; then
  build "portfolio" "Portfolio_${LANG_UP}" "var(--od-accent-800)" "$VASIC_TOKENS_CSS" "$LOGO_URI" "$VASIC_OUT_DIR" "company"
else
  echo "  -- WARN: vasic logo missing ($VASIC_LOGO); skipping vasic Portfolio PDF"
fi

echo "Done [lang=${LANG_CODE}]."
