#!/usr/bin/env python3
"""Build the self-hosted Noto script subsets (SIL OFL 1.1) shipped under design-system/fonts/noto/.

WHY: the console speaks 15 languages. Inter covers Latin / Latin-ext / Cyrillic / Cyrillic-ext (ru sr be kk de es fr tr);
it has no Arabic (ar fa), Devanagari (hi) or CJK (zh ja ko). Without a shipped face those scripts fall to whatever the
visitor's OS has, or to tofu. This script cuts woff2 subsets from the OPEN-SOURCE Noto sources installed on the host
(packages fonts-noto-core and fonts-noto-cjk) and regenerates, deterministically and in place:

  design-system/fonts/noto/*.woff2          the subsets (weights 400 and 700)
  design-system/fonts/noto/SOURCES.tsv      machine record: source file + sha256, package + version, glyphs, bytes
  design-system/fonts/fonts.css             the block between the BEGIN/END generated:noto markers (@font-face, unicode-range)
  design-system/THIRD_PARTY_NOTICES.md      the block between the BEGIN/END generated:noto markers (one row per shipped file)

WEIGHTS: Arabic and Devanagari ship 400 and 700. CJK ships 400 only (a 700 face would double a payload that is already
~1 MB per language); the browser synthesises bold for CJK, which is the common practice for CJK web text.

GLYPH SETS (documented decision, see design-system/THIRD_PARTY_NOTICES.md):
  ar fa     Noto Sans Arabic, the whole Arabic block set (small; the Persian letters and digits are inside it).
  hi        Noto Sans Devanagari, the whole Devanagari block set.
  zh ja ko  CJK is too large to ship whole. Each face carries  FLOOR + CATALOGUE:
            FLOOR      a documented common-character floor that needs no network and no frequency list, taken from the
                       national standards' own commonly-used tiers through the Python codecs:
                         zh  GB2312 level 1 (3755 hanzi) + GB2312 symbols and punctuation
                         ja  hiragana + katakana + JIS X 0208 level 1 kanji (2965) + symbols and punctuation
                         ko  KS X 1001 hangul syllables (2350) + compatibility jamo + symbols and punctuation
            CATALOGUE  every character of the matching <lang>.json catalogue that falls in the face's script ranges,
                       added on top of the floor (this is what keeps later strings from becoming tofu).
            CORPUS     optional (--corpus LANG=DIR): characters of existing translated text in the repository (the site
                       content) - real vocabulary of this product's domain, used to decide what is CORE.
            Each CJK family is split into two faces, so a page downloads only what it shows:
              core  = (CATALOGUE + CORPUS) characters, declared with their EXACT unicode-range, loaded first and alone by
                      any page that stays inside the product vocabulary;
              rest  = FLOOR minus core, declared with the script-block range MINUS the core codepoints. The two ranges are
                      DISJOINT on purpose: measured in chromium, overlapping ranges make the browser fetch BOTH files for any
                      CJK text, so a page inside the vocabulary would still pay for the large rest file.
            Anything outside FLOOR+CATALOGUE+CORPUS falls through the font stack to the system CJK font; and
            --check-coverage fails when a catalogue character is in no shipped face.

USAGE (from the repository root; re-runnable, output is byte-deterministic):
  python3 design-system/fonts/tools/build_noto_subsets.py --catalogue-dir ../job_seeker/internal/i18n/messages \\
      --corpus zh=_content_zh --corpus ja=_content_ja --corpus ko=_content_ko
  python3 design-system/fonts/tools/build_noto_subsets.py --catalogue-dir DIR --check-coverage   # rebuild + verify coverage
  python3 design-system/fonts/tools/build_noto_subsets.py --check-only                           # build to a temp dir, diff, write nothing
  --catalogue-dir and --corpus may be given more than once; a missing directory or no <lang>.json is not an error (floor only, and the
  run prints it). Exit 0 ok, 1 an uncovered catalogue character or drift, 2 could not determine (missing source font or tool).
"""
import argparse, hashlib, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.dirname(HERE)                      # design-system/fonts
DS = os.path.dirname(FONTS)                        # design-system
TTF = "/usr/share/fonts/truetype/noto"
OTC = "/usr/share/fonts/opentype/noto"
WEIGHTS = {400: "Regular", 700: "Bold"}

ARABIC = "0600-06FF,0750-077F,08A0-08FF,FB50-FDFF,FE70-FEFF,200C-200F,2010-2011,25CC"
DEVA = "0900-097F,A8E0-A8FF,1CD0-1CF9,200C-200D,20B9,25CC,A830-A839"
CJK_PUNCT = "3000-303F,FF01-FF5E,FF5F-FF65,FFE0-FFEE,2E80-2FDF,FE30-FE4F"
# unicode-range sent to the browser: script blocks, not the exact glyph list (a glyph the subset lacks falls through the stack)
URANGE = {
    "arabic": "U+0600-06FF, U+0750-077F, U+08A0-08FF, U+FB50-FDFF, U+FE70-FEFF, U+200C-200F, U+25CC",
    "devanagari": "U+0900-097F, U+1CD0-1CF9, U+200C-200D, U+20B9, U+25CC, U+A830-A839, U+A8E0-A8FF",
    "sc": "U+2E80-2FDF, U+3000-303F, U+3400-4DBF, U+4E00-9FFF, U+F900-FAFF, U+FE30-FE4F, U+FF00-FFEF",
    "jp": "U+2E80-2FDF, U+3000-30FF, U+31F0-31FF, U+3400-4DBF, U+4E00-9FFF, U+F900-FAFF, U+FE30-FE4F, U+FF00-FFEF",
    "kr": "U+1100-11FF, U+3000-303F, U+3130-318F, U+A960-A97F, U+AC00-D7FF, U+FF00-FFEF",
}
# family key -> (css family, source path pattern, ttc index or None, package, catalogue languages)
FAMILIES = {
    "arabic": ("Noto Sans Arabic", TTF + "/NotoSansArabic-%s.ttf", None, "fonts-noto-core", ["ar", "fa"]),
    "devanagari": ("Noto Sans Devanagari", TTF + "/NotoSansDevanagari-%s.ttf", None, "fonts-noto-core", ["hi"]),
    "sc": ("Noto Sans SC", OTC + "/NotoSansCJK-%s.ttc", 2, "fonts-noto-cjk", ["zh"]),
    "jp": ("Noto Sans JP", OTC + "/NotoSansCJK-%s.ttc", 0, "fonts-noto-cjk", ["ja"]),
    "kr": ("Noto Sans KR", OTC + "/NotoSansCJK-%s.ttc", 1, "fonts-noto-cjk", ["ko"]),
}
CJK = ("sc", "jp", "kr")
CJK_FEATURES = ["ccmp", "locl", "kern", "palt", "vert", "vrt2", "vkrn", "vpal", "mark", "mkmk", "liga", "calt", "halt"]
CSS_B, CSS_E = "/* BEGIN generated:noto */", "/* END generated:noto */"
MD_B, MD_E = "<!-- BEGIN generated:noto -->", "<!-- END generated:noto -->"


def parse_ranges(spec):
    out = set()
    for p in spec.split(","):
        a, _, b = p.partition("-")
        out.update(range(int(a, 16), int(b or a, 16) + 1))
    return out


def urange_set(u):
    return parse_ranges(",".join(x.strip()[2:] for x in u.split(",")))


def codec_chars(codec, lead_lo, lead_hi, trail_lo=0xA1, trail_hi=0xFE):
    s = set()
    for a in range(lead_lo, lead_hi + 1):
        for b in range(trail_lo, trail_hi + 1):
            try:
                t = bytes([a, b]).decode(codec)
            except UnicodeDecodeError:
                continue
            if len(t) == 1:
                s.add(ord(t))
    return s


def floor(key):
    if key == "arabic":
        return parse_ranges(ARABIC)
    if key == "devanagari":
        return parse_ranges(DEVA)
    if key == "sc":
        return codec_chars("gb2312", 0xB0, 0xD7) | codec_chars("gb2312", 0xA1, 0xA9) | parse_ranges(CJK_PUNCT)
    if key == "jp":
        return (codec_chars("euc_jp", 0xB0, 0xCF) | codec_chars("euc_jp", 0xA1, 0xA8)
                | parse_ranges("3040-30FF,31F0-31FF") | parse_ranges(CJK_PUNCT))
    if key == "kr":
        return (codec_chars("euc_kr", 0xB0, 0xC8) | codec_chars("euc_kr", 0xA1, 0xAC)
                | parse_ranges("3131-318E,3000-303F,FF01-FF5E"))
    raise KeyError(key)


def strings_of(path):
    out = []

    def walk(v):
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, dict):
            [walk(x) for x in v.values()]
        elif isinstance(v, list):
            [walk(x) for x in v]
    walk(json.load(open(path, encoding="utf-8")))
    return out


def catalogue_chars(dirs, langs, key):
    """characters of <lang>.json string values inside this face's unicode-range, and the files read."""
    ur, got, files = urange_set(URANGE[key]), set(), []
    for d in dirs:
        for lg in langs:
            p = os.path.join(d, lg + ".json")
            if os.path.isfile(p):
                files.append(p)
                for s in strings_of(p):
                    got.update(ord(c) for c in s if ord(c) in ur)
    return got, files


def corpus_chars(corpora, langs, key):
    """characters inside this face's unicode-range from any text file under the --corpus LANG=DIR directories."""
    ur, got, files = urange_set(URANGE[key]), set(), 0
    for lg, d in corpora:
        if lg not in langs or not os.path.isdir(d):
            continue
        for dp, dn, fn in os.walk(d):
            dn.sort()
            for f in sorted(fn):
                if f.endswith((".md", ".json", ".html", ".txt", ".yml", ".yaml")):
                    files += 1
                    got.update(ord(c) for c in open(os.path.join(dp, f), encoding="utf-8", errors="ignore").read() if ord(c) in ur)
    return got, files


def ranges_of(cps):
    cps = sorted(cps)
    out, i = [], 0
    while i < len(cps):
        j = i
        while j + 1 < len(cps) and cps[j + 1] == cps[j] + 1:
            j += 1
        out.append((cps[i], cps[j]))
        i = j + 1
    return out


def urange_css(cps):
    return ", ".join("U+%04X" % a if a == b else "U+%04X-%04X" % (a, b) for a, b in ranges_of(cps))


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def pkg_version(pkg):
    try:
        return subprocess.run(["dpkg-query", "-W", "-f=${Version}", pkg], capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return "UNKNOWN"


def build(outdir, dirs, corpora):
    from fontTools import subset, ttLib
    os.makedirs(outdir, exist_ok=True)
    rows, notes = [], []
    pv = {p: pkg_version(p) for p in ("fonts-noto-core", "fonts-noto-cjk")}
    for key, (fam, pat, idx, pkg, langs) in FAMILIES.items():
        cat, files = catalogue_chars(dirs, langs, key)
        cor, nfiles = corpus_chars(corpora, langs, key)
        base = floor(key)
        weights = [400] if key in CJK else [400, 700]
        for w in weights:
            src = pat % WEIGHTS[w]
            if not os.path.isfile(src):
                print("UNDETERMINED: source font missing: " + src, file=sys.stderr)
                sys.exit(2)
            probe = ttLib.TTFont(src, fontNumber=idx if idx is not None else -1)
            cmap = set(probe.getBestCmap())
            fver = probe["name"].getDebugName(5) or "UNKNOWN"
            if key in CJK:
                core = (cat | cor) & cmap
                tiers = [("core", sorted(core)), ("rest", sorted((base & cmap) - core))]
                tiers = [t for t in tiers if t[1]]
            else:
                tiers = [("", sorted((base | cat) & cmap))]
            for tier, keep in tiers:
                font = ttLib.TTFont(src, fontNumber=idx if idx is not None else -1, recalcTimestamp=False)
                opts = subset.Options()
                opts.flavor = "woff2"
                opts.layout_features = CJK_FEATURES if key in CJK else ["*"]
                opts.notdef_outline = True
                opts.name_IDs = ["*"]
                opts.name_languages = ["*"]
                opts.hinting = False
                opts.desubroutinize = key in CJK
                opts.recalc_timestamp = False
                opts.glyph_names = False
                opts.drop_tables = list(opts.drop_tables) + ["DSIG"]
                ss = subset.Subsetter(opts)
                ss.populate(unicodes=keep)
                ss.subset(font)
                name = "noto-sans-%s-%d%s.woff2" % (key, w, "-" + tier if tier else "")
                dst = os.path.join(outdir, name)
                font.flavor = "woff2"
                font.save(dst)
                if tier == "core":
                    ur = urange_css(keep)
                elif tier == "rest":  # the script block MINUS core: the two ranges are disjoint, so a page loads only the face it needs
                    ur = urange_css(urange_set(URANGE[key]) - set(core))
                else:
                    ur = URANGE[key]
                rows.append((name, fam, w, os.path.basename(src) + ("#%d" % idx if idx is not None else ""), sha(src), pkg,
                             pv[pkg], fver, len(keep), os.path.getsize(dst), sha(dst), key, tier or "all", ur))
        notes.append((key, len(base), len(cat), len(cat - base), len(cor), len(cor - base), files, nfiles))
    return rows, notes


def css_block(rows):
    L = [CSS_B,
         "/* Generated by design-system/fonts/tools/build_noto_subsets.py - do not edit by hand; re-run the script.",
         " * Noto Sans Arabic / Devanagari / SC / JP / KR, SIL OFL 1.1, woff2 subsets. Arabic and Devanagari: weights 400 and 700.",
         " * CJK: weight 400 only (bold is synthesised), two faces per family with DISJOINT ranges - 'core' (the exact characters of",
         " * the catalogue and site corpus) and 'rest' (the rest of the script block); disjoint, so a page loads only what it shows.",
         " * unicode-range keeps a page from downloading a script it does not show; a glyph a subset lacks falls through the",
         " * --od-font-* stack. Provenance: noto/SOURCES.tsv and ../THIRD_PARTY_NOTICES.md. */"]
    order = sorted(rows, key=lambda r: (list(FAMILIES).index(r[11]), r[2], 0 if r[12] == "rest" else 1))
    for (name, fam, w, _s, _h, _p, _v, _f, _n, _b, _sh, key, tier, ur) in order:
        L.append("@font-face {\n  font-family: '%s';\n  font-style: normal;\n  font-weight: %d;\n  font-display: swap;\n"
                 "  src: url('noto/%s') format('woff2');\n  unicode-range: %s;\n}" % (fam, w, name, ur))
    L.append(CSS_E)
    return "\n".join(L)


def md_block(rows):
    L = [MD_B, "", "### Noto script subsets (generated)", "",
         "| File | Family / weight | Version | Licence | Licence file | sha256 | Source |", "|---|---|---|---|---|---|---|"]
    for (name, fam, w, src, _ssha, pkg, pver, fver, ncp, _nb, osha, _k, tier, _u) in rows:
        lic = "OFL.txt" if pkg == "fonts-noto-core" else "OFL-CJK.txt"
        L.append("| `fonts/noto/%s` | %s %d %s | %s (source `%s`) | OFL-1.1 | `fonts/noto/%s` | %s | Debian `%s` %s, subset by `fonts/tools/build_noto_subsets.py` (%d codepoints) |"
                 % (name, fam, w, tier, fver, src, lic, osha, pkg, pver, ncp))
    L += ["", MD_E]
    return "\n".join(L)


def tsv(rows):
    h = "file\tfamily\tweight\tsource_file\tsource_sha256\tsource_package\tsource_package_version\tfont_version\tcodepoints\tbytes\tsha256\tscript\ttier\n"
    return h + "".join("\t".join(str(x) for x in r[:13]) + "\n" for r in rows)


def splice(text, b, e, block):
    if b in text and e in text:
        return re.sub(re.escape(b) + r".*?" + re.escape(e), lambda m: block, text, flags=re.S)
    return None


def coverage(dirs, outdir):
    """every catalogue character (non-ASCII, non-space) must be in a shipped face of the language's script, or in Inter."""
    from fontTools import ttLib
    inter = set()
    for f in sorted(os.listdir(os.path.join(FONTS, "inter"))):
        if f.endswith(".woff2"):
            inter |= set(ttLib.TTFont(os.path.join(FONTS, "inter", f)).getBestCmap())
    cm = {f: set(ttLib.TTFont(os.path.join(outdir, f)).getBestCmap()) for f in sorted(os.listdir(outdir)) if f.endswith(".woff2")}
    langmap = {lg: k for k, v in FAMILIES.items() for lg in v[4]}
    bad = []
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            m = re.fullmatch(r"([a-z]{2})\.json", fn)
            if not m:
                continue
            lg = m.group(1)
            chars = set("".join(strings_of(os.path.join(d, fn))))
            have = set(inter)
            k = langmap.get(lg)
            if k:
                for f, c in cm.items():
                    if f.startswith("noto-sans-%s-" % k):
                        have |= c
            for ch in sorted(chars):
                o = ord(ch)
                if o < 0x80 or ch.isspace() or o in (0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0xFEFF):
                    continue
                if o not in have:
                    bad.append((lg, "U+%04X" % o, ch))
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--catalogue-dir", action="append", default=[])
    ap.add_argument("--corpus", action="append", default=[], metavar="LANG=DIR")
    ap.add_argument("--check-coverage", action="store_true")
    ap.add_argument("--check-only", action="store_true", help="build into a temp dir and diff against the tree; write nothing")
    a = ap.parse_args()
    try:
        import fontTools, brotli  # noqa: F401
    except Exception as e:
        print("UNDETERMINED: fonttools/brotli missing: %s" % e, file=sys.stderr)
        return 2
    dirs = [os.path.abspath(d) for d in a.catalogue_dir]
    corpora = []
    for c in a.corpus:
        lg, _, d = c.partition("=")
        if not d:
            print("UNDETERMINED: --corpus wants LANG=DIR, got %r" % c, file=sys.stderr)
            return 2
        corpora.append((lg, os.path.abspath(d)))
    live = os.path.join(FONTS, "noto")
    out = tempfile.mkdtemp(prefix="noto-subsets-") if a.check_only else live
    rows, notes = build(out, dirs, corpora)
    for key, nb, nc, nce, nk, nke, files, nf in notes:
        print("%-10s floor=%d catalogue=%d (beyond floor %d) corpus=%d (beyond floor %d) catalogue-files=%s corpus-files=%d"
              % (key, nb, nc, nce, nk, nke, ",".join(os.path.basename(f) for f in files) or "NONE", nf))
    for r in rows:
        print("%-34s %8d B  %5d cp  sha256=%s" % (r[0], r[9], r[8], r[10][:16]))
    print("total %d bytes in %d files" % (sum(r[9] for r in rows), len(rows)))
    css_p, md_p = os.path.join(FONTS, "fonts.css"), os.path.join(DS, "THIRD_PARTY_NOTICES.md")
    tsv_p = os.path.join(live, "SOURCES.tsv")
    new = {}
    for p, b, e, blk in ((css_p, CSS_B, CSS_E, css_block(rows)), (md_p, MD_B, MD_E, md_block(rows))):
        cur = open(p, encoding="utf-8").read() if os.path.exists(p) else ""
        sp = splice(cur, b, e, blk)
        new[p] = sp if sp is not None else cur.rstrip("\n") + "\n\n" + blk + "\n"
    want_tsv = tsv(rows)
    rc = 0
    if a.check_only:
        for p, t in ((css_p, new[css_p]), (md_p, new[md_p]), (tsv_p, want_tsv)):
            cur = open(p, encoding="utf-8").read() if os.path.exists(p) else None
            if cur != t:
                print("DRIFT: %s differs from a fresh build" % p)
                rc = 1
        names = {r[0] for r in rows}
        for r in rows:
            p = os.path.join(live, r[0])
            if not os.path.exists(p) or sha(p) != r[10]:
                print("DRIFT: %s differs from a fresh build" % r[0])
                rc = 1
        for f in sorted(os.listdir(live)):
            if f.endswith(".woff2") and f not in names:
                print("DRIFT: %s is shipped but a fresh build does not produce it" % f)
                rc = 1
        if rc == 0:
            print("OK shipped subsets, fonts.css block, notices block and SOURCES.tsv equal a fresh build")
    else:
        for f in sorted(os.listdir(live)):
            if f.endswith(".woff2") and f not in {r[0] for r in rows}:
                os.unlink(os.path.join(live, f))  # a tier that no longer exists must not stay shipped
        for p, t in new.items():
            open(p, "w", encoding="utf-8").write(t)
        open(tsv_p, "w", encoding="utf-8").write(want_tsv)
    if a.check_coverage or dirs:
        bad = coverage(dirs, out)
        for lg, cp, ch in bad:
            print("UNCOVERED %s %s %r" % (lg, cp, ch))
        if bad:
            print("FAIL %d catalogue character(s) are in no shipped face" % len(bad))
            rc = 1
        elif a.check_coverage:
            print("OK every catalogue character is covered by a shipped face")
    return rc


if __name__ == "__main__":
    sys.exit(main())
