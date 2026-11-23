#!/usr/bin/env python3
"""check_version_footer.py -- version-drift gate for the milosvasic.ru footer.

Single source of truth: <repo>/VERSION (semver). Every built HTML page must
carry the footer element

    <p class="mv-ver ..."><span ... data-i18n="footer.version">LABEL</span>
       <a class="mv-ver__link" href="<PREFIX><VERSION>">v<VERSION></a></p>

where PREFIX = https://github.com/milos85vasic/milosvasic.ru/releases/tag/v and
LABEL is the localized string from _data/ui.json for the page's <html lang>.

Checks:
  (a) every full-document page in --site-dir has exactly the expected footer
      link (href AND visible text) and the localized label;
  (b) VERSION equals the newest v<semver> git tag of --repo (a VERSION ahead of
      every tag is "unreleased": rc 1, or a NOTE with --allow-unreleased);
  (c) with --online the release page https://github.com/.../releases/tag/v<VERSION>
      answers HTTP 200 (network failure = rc 2, never a pass);
  (d) --prove-failure: seeded wrong VERSION / link / text / label / missing
      footer / unreleased tag must each be caught (rc 1) and a good fixture rc 0.

Exit: 0 all held | 1 a violation | 2 could not determine (never a pass).
"""
import argparse, json, os, re, subprocess, sys, tempfile, urllib.request, urllib.error, shutil

PREFIX = "https://github.com/milos85vasic/milosvasic.ru/releases/tag/v"
SEMVER = re.compile(r"\A\d+\.\d+\.\d+\Z")
FOOTER = re.compile(r'<footer\b[^>]*class="[^"]*\bfooter\b[^"]*"[^>]*>(.*?)</footer>', re.S)
VERP = re.compile(r'<p\b[^>]*class="[^"]*\bmv-ver\b[^"]*"[^>]*>(.*?)</p>', re.S)
LABEL = re.compile(r'<span\b[^>]*data-i18n="footer\.version"[^>]*>(.*?)</span>', re.S)
LINK = re.compile(r'<a\b[^>]*class="[^"]*\bmv-ver__link\b[^"]*"[^>]*>(.*?)</a>', re.S)
HREF = re.compile(r'href="([^"]*)"')
HLANG = re.compile(r'<html\b[^>]*\blang="([^"]+)"', re.I)


def read_version(repo):
    p = os.path.join(repo, "VERSION")
    try:
        v = open(p, encoding="utf-8").read().strip()
    except OSError as e:
        return None, f"cannot read {p}: {e}"
    if not SEMVER.match(v):
        return None, f"VERSION {v!r} is not semver MAJOR.MINOR.PATCH"
    return v, None


def check_pages(site_dir, version, ui):
    viol, pages, frags = [], 0, 0
    want_href = PREFIX + version
    for root, _d, files in os.walk(site_dir):
        for f in files:
            if not f.endswith(".html"):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, site_dir)
            try:
                html = open(path, encoding="utf-8", errors="replace").read()
            except OSError as e:
                viol.append(f"{rel}: unreadable ({e})"); continue
            if not re.search(r"<html\b", html, re.I):
                frags += 1; continue  # Jekyll fragment (article body), not a page
            pages += 1
            fm = FOOTER.search(html)
            if not fm:
                viol.append(f"{rel}: no <footer class=footer>"); continue
            vm = VERP.search(fm.group(1))
            if not vm:
                viol.append(f"{rel}: footer has no .mv-ver element"); continue
            lm, km = LABEL.search(vm.group(1)), LINK.search(vm.group(1))
            if not km:
                viol.append(f"{rel}: no .mv-ver__link"); continue
            hm = HREF.search(km.group(0))
            href = hm.group(1) if hm else ""
            text = re.sub(r"<[^>]+>", "", km.group(1)).strip()
            if href != want_href:
                viol.append(f"{rel}: link {href!r} != {want_href!r}")
            if text != "v" + version:
                viol.append(f"{rel}: link text {text!r} != 'v{version}'")
            if not lm or not lm.group(1).strip():
                viol.append(f"{rel}: no localized label")
            elif ui is not None:
                lg = (HLANG.search(html) or [None, "en"])[1].split("-")[0].lower()
                exp = (ui.get(lg) or ui.get("en", {})).get("footer.version")
                if exp and lm.group(1).strip() != exp:
                    viol.append(f"{rel}: label {lm.group(1).strip()!r} != ui.json[{lg}] {exp!r}")
    return viol, pages, frags


def semver_key(t):
    return tuple(int(x) for x in t[1:].split("."))


def check_tags(repo, version, allow_unreleased):
    try:
        out = subprocess.run(["git", "-C", repo, "tag", "--list", "v*"], capture_output=True,
                             text=True, check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError) as e:
        return 2, [f"git tag --list failed: {e}"], []
    tags = sorted([t for t in out if re.fullmatch(r"v\d+\.\d+\.\d+", t)], key=semver_key)
    if not tags:
        return 1, ["no v<semver> tags exist"], []
    latest, want = tags[-1], "v" + version
    if want == latest:
        return 0, [], [f"VERSION {version} == latest tag {latest}"]
    if want in tags:
        return 1, [f"VERSION {version} is older than latest tag {latest} (stale VERSION)"], []
    if semver_key(want) > semver_key(latest):
        if allow_unreleased:
            return 0, [], [f"NOTE unreleased: VERSION {version} is ahead of latest tag {latest}"]
        return 1, [f"VERSION {version} is ahead of latest tag {latest}: tag/release not cut yet"], []
    return 1, [f"VERSION {version} not among tags (latest {latest})"], []


def check_online(version):
    url = PREFIX + version
    req = urllib.request.Request(url, headers={"User-Agent": "check-version-footer/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return (0, [], [f"release page {url} -> HTTP {r.status}"]) if r.status == 200 \
                else (1, [f"release page {url} -> HTTP {r.status}"], [])
    except urllib.error.HTTPError as e:
        return 1, [f"release page {url} -> HTTP {e.code}"], []
    except (urllib.error.URLError, OSError) as e:
        return 2, [f"release page {url} unreachable: {e}"], []


def run(site_dir, repo, online, allow_unreleased, quiet=False):
    version, err = read_version(repo)
    if err:
        print("FAIL", err); return 1
    ui = None
    up = os.path.join(repo, "_data", "ui.json")
    if os.path.isfile(up):
        ui = json.load(open(up, encoding="utf-8"))
    if not os.path.isdir(site_dir):
        print(f"CANNOT DETERMINE: site dir {site_dir} missing"); return 2
    viol, pages, frags = check_pages(site_dir, version, ui)
    rc = 1 if viol else 0
    if pages == 0:
        print("CANNOT DETERMINE: zero pages found"); return 2
    notes = [f"pages checked {pages}, fragments skipped {frags}, VERSION {version}"]
    trc, tv, tn = check_tags(repo, version, allow_unreleased)
    viol += tv; notes += tn
    orc = 0
    if online:
        orc, ov, on = check_online(version); viol += ov; notes += on
    for n in notes:
        if not quiet: print("INFO", n)
    for v in viol[:40]:
        print("FAIL", v)
    if len(viol) > 40: print(f"FAIL ... {len(viol) - 40} more")
    if viol and any(x == 1 for x in (rc, trc, orc)): return 1
    if 2 in (trc, orc): return 2
    print(f"PASS version footer: {pages} pages carry v{version} -> {PREFIX}{version}")
    return 0


def prove_failure():
    base = tempfile.mkdtemp(prefix="vfoot-")
    results = []

    def mk(name, version="2.0.0", href=None, text=None, label="Website version:", footer=True,
           tags=("v1.8.0", "v2.0.0"), lang="en"):
        d = os.path.join(base, name); site = os.path.join(d, "_site"); os.makedirs(site)
        os.makedirs(os.path.join(d, "_data"))
        open(os.path.join(d, "VERSION"), "w").write(version + "\n")
        json.dump({"en": {"footer.version": "Website version:"}}, open(os.path.join(d, "_data", "ui.json"), "w"))
        v = "2.0.0"
        href = href or PREFIX + v; text = text or "v" + v
        ft = (f'<footer class="footer"><p class="mv-ver mono"><span data-i18n="footer.version">{label}</span> '
              f'<a class="mv-ver__link" href="{href}">{text}</a></p></footer>') if footer else ""
        open(os.path.join(site, "index.html"), "w").write(f'<!doctype html><html lang="{lang}"><body>{ft}</body></html>')
        subprocess.run(["git", "-C", d, "init", "-q"], check=True)
        subprocess.run(["git", "-C", d, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q",
                        "--allow-empty", "-m", "x"], check=True)
        for t in tags:
            subprocess.run(["git", "-C", d, "tag", t], check=True)
        return site, d

    cases = [("good", {}, 0), ("wrong-link", dict(href=PREFIX + "1.9.9"), 1),
             ("wrong-text", dict(text="v2.0.1"), 1), ("wrong-label", dict(label="Version"), 1),
             ("no-footer", dict(footer=False), 1), ("unreleased", dict(tags=("v1.8.0",)), 1),
             ("stale-version", dict(version="1.8.0"), 1), ("bad-semver", dict(version="2.0"), 1)]
    ok = True
    try:
        for name, kw, want in cases:
            site, d = mk(name, **kw)
            import io, contextlib
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = run(site, d, False, False, quiet=True)
            good = rc == want; ok &= good
            print(f"{'PASS' if good else 'FAIL'} prove[{name}]: rc={rc} expected={want}")
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print("PROVE-FAILURE:", "all seeded faults caught" if ok else "A FAULT WAS NOT CAUGHT")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--site-dir"); ap.add_argument("--repo")
    ap.add_argument("--online", action="store_true")
    ap.add_argument("--allow-unreleased", action="store_true",
                    help="pre-release PR state: VERSION may be ahead of the latest tag (NOTE only)")
    ap.add_argument("--prove-failure", action="store_true")
    a = ap.parse_args()
    if a.prove_failure:
        return prove_failure()
    if not (a.site_dir and a.repo):
        ap.error("--site-dir and --repo required"); 
    return run(a.site_dir, a.repo, a.online, a.allow_unreleased)


if __name__ == "__main__":
    sys.exit(main())
