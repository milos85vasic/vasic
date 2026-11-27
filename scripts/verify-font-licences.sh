#!/usr/bin/env bash
# =============================================================================
# verify-font-licences.sh -- does EVERY font file shipped under design-system/
# carry a licence record?
#
# A shipped font is third-party software. The record is a row in
# design-system/THIRD_PARTY_NOTICES.md:
#   | `<path relative to design-system/>` | family | version | licence | `<licence file>` | sha256 | source |
# The gate FAILS (exit 1) when
#   F1  a font file (woff2 woff ttf otf ttc eot) under design-system/ has no row,
#   F2  a row's licence column is not OFL-1.1 or its licence file does not exist,
#   F3  the licence file is not an OFL*.txt file or lacks the SIL Open Font License text,
#   F4  the row's sha256 differs from the file's actual sha256 (font replaced, record not updated),
#   F5  a row names a font file that is not on disk (stale record).
# Exit 0 clean, 1 finding, 2 COULD NOT DETERMINE (no python3, no notices file, bad --root) -- never a pass.
#
# USAGE
#   bash scripts/verify-font-licences.sh [--root DIR]
#   bash scripts/verify-font-licences.sh --prove-failure
#       paired mutations (section 1.1) on throwaway copies: M1 rogue font without a row, M2 licence file deleted,
#       M3 licence file with the licence text stripped, M4 font bytes changed, M5 row removed, M6 stale row,
#       M7 empty licence column, M8 font under node_modules, M9 font under a symlinked directory, M10 licence file that is not an OFL*.txt, M11 non-OFL licence column; the unmutated control must pass; a nonexistent root must be exit 2.
# =============================================================================
set -uo pipefail
SELF_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROOT="$SELF_ROOT"; PROVE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prove-failure) PROVE=1; shift ;;
    --root) [ "$#" -ge 2 ] || { echo "UNDETERMINED: --root needs a value" >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,24p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "UNDETERMINED: unknown argument: $1" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "UNDETERMINED: python3 missing" >&2; exit 2; }

check() {  # $1 = checkout root
  python3 -I - "$1" <<'PY'
import hashlib, os, re, sys
root = sys.argv[1]
ds = os.path.join(root, "design-system")
notices = os.path.join(ds, "THIRD_PARTY_NOTICES.md")
if not os.path.isdir(ds) or not os.path.isfile(notices):
    print("UNDETERMINED: %s or %s missing" % (ds, notices)); sys.exit(2)
EXT = (".woff2", ".woff", ".ttf", ".otf", ".ttc", ".eot", ".otb", ".pfb", ".pfa", ".svgz")
files = {}
for dp, dn, fn in os.walk(ds, followlinks=True):
    dn[:] = [d for d in dn if d != ".git"]
    for f in fn:
        if f.lower().endswith(EXT):
            files[os.path.relpath(os.path.join(dp, f), ds)] = os.path.join(dp, f)
rows = {}
for line in open(notices, encoding="utf-8"):
    m = re.match(r"\|\s*`([^`]+)`\s*\|(.*)\|\s*$", line)
    if m:
        c = [x.strip() for x in m.group(2).split("|")]
        if len(c) >= 5:
            rows[m.group(1)] = c
bad = []
for rel, p in sorted(files.items()):
    r = rows.get(rel)
    if r is None:
        bad.append("F1 %s: no licence record in THIRD_PARTY_NOTICES.md" % rel); continue
    lic, licfile, sha = r[2], r[3].strip("`"), r[4]
    if lic != "OFL-1.1":
        bad.append("F2 %s: licence column is %r, only OFL-1.1 is accepted" % (rel, lic))
    lp = os.path.join(ds, licfile)
    if not licfile or not os.path.isfile(lp):
        bad.append("F2 %s: licence file %r does not exist" % (rel, licfile))
    else:
        txt = open(lp, encoding="utf-8", errors="replace").read().lower()
        parts = licfile.split("/")
        if not (re.fullmatch(r"ofl[-\w]*\.txt", parts[-1].lower()) and parts[:-1] == rel.split("/")[:-1]):
            bad.append("F3 %s: licence file %s is not an OFL*.txt file in the same directory as the font" % (rel, licfile))
        elif not all(k in txt for k in ("sil open font license", "permission", "disclaimer")):
            bad.append("F3 %s: licence file %s lacks the OFL text (title, permission, disclaimer)" % (rel, licfile))
    if hashlib.sha256(open(p, "rb").read()).hexdigest() != sha:
        bad.append("F4 %s: sha256 in the record differs from the file" % rel)
for rel in sorted(rows):
    if rel.lower().endswith(EXT) and rel not in files:
        bad.append("F5 %s: record names a font file that is not on disk" % rel)
for b in bad:
    print("FAIL " + b)
if bad:
    print("FAIL %d finding(s) over %d font file(s)" % (len(bad), len(files))); sys.exit(1)
print("OK %d font file(s), every one with a licence record, a present OFL text and a matching sha256" % len(files))
PY
}

if [ "$PROVE" -eq 1 ]; then
  [ -d "$ROOT/design-system" ] || { echo "UNDETERMINED: $ROOT has no design-system" >&2; exit 2; }
  T="$(mktemp -d)" || exit 2
  trap 'rm -rf -- "${T:?}"' EXIT
  mk() { mkdir -p "$T/$1" && cp -r "$ROOT/design-system" "$T/$1/"; }
  for n in ctl m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 m11; do mk "$n"; done
  N="design-system/THIRD_PARTY_NOTICES.md"
  victim="$(cd "$T/ctl/design-system" && find . -name '*.woff2' | sort | head -1 | sed 's|^\./||')"
  [ -n "$victim" ] || { echo "UNDETERMINED: no font file to mutate" >&2; exit 2; }
  licf="$(grep -F "\`$victim\`" "$T/ctl/$N" | python3 -I -c 'import sys,re;print(re.findall(r"`([^`]+)`",sys.stdin.readline())[1])')"
  printf 'wOF2rogue' > "$T/m1/design-system/fonts/rogue-font.woff2"
  rm -f -- "$T/m2/design-system/$licf"
  printf 'no licence here\n' > "$T/m3/design-system/$licf"
  printf 'x' >> "$T/m4/design-system/$victim"
  grep -vF "\`$victim\`" "$T/m5/$N" > "$T/m5/n.tmp" && mv "$T/m5/n.tmp" "$T/m5/$N"
  rm -f -- "$T/m6/design-system/$victim"
  python3 -I - "$T/m7/$N" "$victim" <<'PY'
import sys
p, v = sys.argv[1], sys.argv[2]
out = []
for l in open(p, encoding="utf-8"):
    if l.startswith("| `%s`" % v):
        c = l.split("|"); c[4] = " "; l = "|".join(c)
    out.append(l)
open(p, "w", encoding="utf-8").write("".join(out))
PY
  mkdir -p "$T/m8/design-system/fonts/node_modules/x" && printf 'wOF2rogue' > "$T/m8/design-system/fonts/node_modules/x/rogue.woff2"
  mkdir -p "$T/m9/real" && printf 'wOF2rogue' > "$T/m9/real/rogue.woff2" && ln -s "$T/m9/real" "$T/m9/design-system/fonts/linked"
  sed "s#\`$licf\`#\`THIRD_PARTY_NOTICES.md\`#" "$T/m10/$N" > "$T/m10/n.tmp" && mv "$T/m10/n.tmp" "$T/m10/$N"
  sed "s#| OFL-1.1 |#| Commercial EULA |#" "$T/m11/$N" > "$T/m11/n.tmp" && mv "$T/m11/n.tmp" "$T/m11/$N"
  check "$T/ctl" >/dev/null; c=$?
  res="control rc=$c"; ok=1; [ "$c" -eq 0 ] || ok=0
  for n in m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 m11; do
    check "$T/$n" >/dev/null; r=$?; res="$res $n=$r"; [ "$r" -eq 1 ] || ok=0
  done
  check "$T/nonexistent" >/dev/null; u=$?; res="$res nonexistent=$u"; [ "$u" -eq 2 ] || ok=0
  if [ "$ok" -eq 1 ]; then echo "PROVE-FAILURE OK: 11 mutations (M1..M11) caught as rc=1, control rc=0, missing root rc=2 ($res)"; exit 0; fi
  echo "PROVE-FAILURE BAD: want control=0, M1..M11=1, nonexistent=2; got: $res"; exit 1
fi
check "$ROOT"
