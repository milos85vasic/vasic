#!/usr/bin/env python3
"""check-site-version-footer.py -- footer "Website version" gate for the static sites.

Every full HTML page under --root (a built site tree) must carry, inside its
<footer>, exactly one

    <span class="site-version"><span data-i18n="footer.version">LABEL</span>
        <a href="https://github.com/<repo>/releases/tag/v<VERSION>">v<VERSION></a></span>

LABEL must be non-empty and, for non-English pages, differ from the English
label (an untranslated footer is a defect). Files without <html> (article
fragments) are counted and skipped, never silently passed as pages.

Modes
  --root DIR --repo owner/name --version X     check a local tree
  --base URL --sitemap-sample N ...            fetch N sitemap pages (spread over
                                               every language) from a live host
  --online                                     also require the release page -> 200
  --self-test                                  mutation proof: a good fixture must
                                               pass and each seeded defect must fail

Exit: 0 all held | 1 a violation | 2 could not determine (never a pass).
"""
import argparse, os, re, sys, tempfile, shutil, urllib.request, urllib.error

SEMVER = re.compile(r"\A\d+\.\d+\.\d+\Z")
FOOTER = re.compile(r"<footer\b[^>]*>(.*?)</footer>", re.S | re.I)
BADGE_ANY = re.compile(r'class="[^"]*\bsite-version\b')
LABEL = re.compile(r'<span\b[^>]*data-i18n="footer\.version"[^>]*>(.*?)</span>', re.S)
LINK = re.compile(r"<a\b([^>]*)>(.*?)</a>", re.S)
HLANG = re.compile(r"<html\b[^>]*\blang=\"([^\"]+)\"", re.I)
TAG = re.compile(r"<[^>]+>")


def check_html(html, rel, repo, version, en_label=None):
    """Return list of violation strings for one full-document page."""
    v = []
    fm = FOOTER.findall(html)
    if not fm:
        return [f"{rel}: no <footer>"]
    foot = "\n".join(fm)
    if len(BADGE_ANY.findall(foot)) != 1:
        return [f"{rel}: {len(BADGE_ANY.findall(foot))} .site-version element(s) in footer, expected exactly 1"]
    i = foot.index("site-version")
    seg = foot[i:]
    lm = LABEL.search(seg)
    lk = LINK.search(seg)
    if not lk:
        return [f"{rel}: .site-version has no link"]
    hm = re.search(r'href="([^"]*)"', lk.group(1))
    href = hm.group(1) if hm else ""
    want = f"https://github.com/{repo}/releases/tag/v{version}"
    if href != want:
        v.append(f"{rel}: link {href!r} != {want!r}")
    text = TAG.sub("", lk.group(2)).strip()
    if text != f"v{version}":
        v.append(f"{rel}: link text {text!r} != 'v{version}'")
    label = TAG.sub("", lm.group(1)).strip() if lm else ""
    if not label:
        v.append(f"{rel}: no localized label (data-i18n=footer.version)")
    else:
        lg = ((HLANG.search(html) or [None, "en"])[1]).split("-")[0].lower()
        if en_label and lg != "en" and label == en_label:
            v.append(f"{rel}: label {label!r} is the English text on lang={lg}")
    return v


def is_page(html):
    return re.search(r"<html\b", html, re.I) is not None


def check_tree(root, repo, version):
    viol, pages, frags, en_label = [], 0, 0, None
    files = []
    for d, _s, fs in os.walk(root):
        if "/.git" in d or d.endswith(".git"):
            continue
        for f in fs:
            if f.endswith(".html"):
                files.append(os.path.join(d, f))
    # English label comes from the English home (root index.html).
    idx = os.path.join(root, "index.html")
    if os.path.isfile(idx):
        m = LABEL.search(open(idx, encoding="utf-8", errors="replace").read())
        en_label = TAG.sub("", m.group(1)).strip() if m else None
    langs = {}
    for p in sorted(files):
        html = open(p, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(p, root)
        if not is_page(html):
            frags += 1
            continue
        pages += 1
        lg = ((HLANG.search(html) or [None, "en"])[1]).split("-")[0].lower()
        langs[lg] = langs.get(lg, 0) + 1
        viol += check_html(html, rel, repo, version, en_label)
    return viol, pages, frags, langs


def http(url, method="GET"):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": "check-site-version-footer/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, ""


def check_release(repo, version):
    url = f"https://github.com/{repo}/releases/tag/v{version}"
    try:
        st, _ = http(url)
    except (urllib.error.URLError, OSError) as e:
        return 2, [f"release page {url} unreachable: {e}"], []
    if st != 200:
        return 1, [f"release page {url} -> HTTP {st}"], []
    return 0, [], [f"release page {url} -> HTTP 200"]


def check_live(base, repo, version, sample):
    try:
        st, xml = http(base.rstrip("/") + "/sitemap.xml")
    except (urllib.error.URLError, OSError) as e:
        return 2, [], [], f"sitemap unreachable: {e}"
    if st != 200:
        return 2, [], [], f"sitemap HTTP {st}"
    locs = re.findall(r"<loc>([^<]+)</loc>", xml)
    if not locs:
        return 2, [], [], "sitemap empty"
    by = {}
    for u in locs:
        m = re.match(r"https?://[^/]+/([a-z]{2})/", u)
        by.setdefault(m.group(1) if m else "en", []).append(u)
    picks, i = [], 0
    while len(picks) < min(sample, len(locs)):
        added = False
        for lg in sorted(by):
            if i < len(by[lg]) and len(picks) < sample:
                picks.append(by[lg][(i * 5) % len(by[lg])]); added = True
        i += 1
        if not added or i > 200:
            break
    picks = list(dict.fromkeys(picks))
    host = base.rstrip("/")
    viol, seen = [], {}
    en_label = None
    try:
        st, h = http(host + "/")
        m = LABEL.search(h); en_label = TAG.sub("", m.group(1)).strip() if m else None
    except (urllib.error.URLError, OSError):
        pass
    for u in picks:
        path = re.sub(r"^https?://[^/]+", "", u)
        try:
            st, html = http(host + path)
        except (urllib.error.URLError, OSError) as e:
            return 2, viol, [], f"{path} unreachable: {e}"
        if st != 200:
            viol.append(f"{path}: HTTP {st}"); continue
        lg = ((HLANG.search(html) or [None, "en"])[1]).split("-")[0].lower()
        seen[lg] = seen.get(lg, 0) + 1
        viol += check_html(html, path, repo, version, en_label)
    return (1 if viol else 0), viol, [f"live pages sampled {len(picks)} across {len(seen)} languages {sorted(seen)}"], None


GOOD = """<!doctype html><html lang="{lang}"><head></head><body><footer class="od-footer"><span class="od-footer__copy">c</span><span class="site-version"><span data-i18n="footer.version">{label}</span> <a href="https://github.com/o/r/releases/tag/v1.2.3" rel="noopener">v1.2.3</a></span></footer></body></html>"""


def self_test():
    ok = True
    d = tempfile.mkdtemp()
    try:
        def build(mut=None):
            shutil.rmtree(d); os.makedirs(os.path.join(d, "ru"))
            en = GOOD.format(lang="en", label="Website version:")
            ru = GOOD.format(lang="ru", label="Версия сайта:")
            frag = "<p>fragment without html tag</p>"
            if mut == "wrong-href": ru = ru.replace("v1.2.3\"", "v9.9.9\"")
            if mut == "wrong-text": ru = ru.replace(">v1.2.3<", ">1.2.3<")
            if mut == "no-badge": ru = ru.replace("site-version", "other")
            if mut == "untranslated": ru = GOOD.format(lang="ru", label="Website version:")
            if mut == "empty-label": ru = GOOD.format(lang="ru", label="")
            if mut == "no-footer": ru = ru.replace("<footer", "<div").replace("</footer>", "</div>")
            if mut == "two-badges": ru = ru.replace("</footer>", '<span class="site-version"></span></footer>')
            open(os.path.join(d, "index.html"), "w").write(en)
            open(os.path.join(d, "ru", "index.html"), "w").write(ru)
            open(os.path.join(d, "frag.html"), "w").write(frag)
        build()
        viol, pages, frags, _ = check_tree(d, "o/r", "1.2.3")
        good = (not viol and pages == 2 and frags == 1)
        print(("PASS" if good else "FAIL"), "control: good fixture clean, 2 pages, 1 fragment skipped", viol)
        ok &= good
        for mut in ["wrong-href", "wrong-text", "no-badge", "untranslated", "empty-label", "no-footer", "two-badges"]:
            build(mut)
            viol, *_ = check_tree(d, "o/r", "1.2.3")
            caught = bool(viol)
            print(("PASS" if caught else "FAIL"), f"mutation {mut}: caught={caught}")
            ok &= caught
        build()
        viol, *_ = check_tree(d, "o/r", "9.9.9")
        print(("PASS" if viol else "FAIL"), "mutation VERSION drift (tree 1.2.3 vs expected 9.9.9): caught =", bool(viol))
        ok &= bool(viol)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root"); ap.add_argument("--repo"); ap.add_argument("--version")
    ap.add_argument("--version-file", help="read the version from this file instead of --version")
    ap.add_argument("--base"); ap.add_argument("--sitemap-sample", type=int, default=30)
    ap.add_argument("--online", action="store_true"); ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    version = a.version
    if a.version_file:
        try:
            version = open(a.version_file, encoding="utf-8").read().strip()
        except OSError as e:
            print("CANNOT DETERMINE:", e); return 2
    if not a.repo or not version or not SEMVER.match(version) or not (a.root or a.base):
        print("usage error: need --repo, a semver --version/--version-file and --root or --base", file=sys.stderr); return 2
    rc, viol, notes = 0, [], []
    if a.root:
        if not os.path.isdir(a.root):
            print("CANNOT DETERMINE: root missing"); return 2
        viol, pages, frags, langs = check_tree(a.root, a.repo, version)
        if pages == 0:
            print("CANNOT DETERMINE: zero pages found"); return 2
        notes.append(f"tree pages checked {pages}, fragments skipped {frags}, languages {len(langs)}, version {version}")
        rc = 1 if viol else 0
    if a.base:
        lrc, lv, ln, err = check_live(a.base, a.repo, version, a.sitemap_sample)
        if lrc == 2:
            print("CANNOT DETERMINE:", err); return 2
        viol += lv; notes += ln; rc = max(rc, lrc)
    if a.online:
        orc, ov, on = check_release(a.repo, version)
        if orc == 2:
            print("CANNOT DETERMINE:", on[0]); return 2
        viol += ov; notes += on; rc = max(rc, orc)
    for n in notes: print("INFO", n)
    for x in viol[:40]: print("VIOLATION", x)
    if len(viol) > 40: print(f"... and {len(viol)-40} more")
    print("RESULT", "FAIL" if rc else "PASS", f"({len(viol)} violation(s))")
    return rc


if __name__ == "__main__":
    sys.exit(main())
