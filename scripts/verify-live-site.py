#!/usr/bin/env python3
"""verify-live-site.py -- deterministic, read-only verifier for a deployed site.

Purpose: prove (with machine-produced evidence) that a site such as
https://milosvasic.ru works, and that a change did not regress it.

Usage:
  verify-live-site.py --base https://milosvasic.ru|http://HOST:PORT
        [--sitemap-from-dir milosvasic.ru/_site] [--evidence-dir D]
        [--baseline FILE] [--report-json FILE] [--max-concurrent 6]
        [--private-path /admin/ ...] [--crawl] [--max-pages 2000]

Discovery: the sitemap when present; --crawl (or an absent sitemap.xml, as on
https://digital.vasic.dev) adds a BFS from the home page over same-origin <a href>
(fragment-stripped dedupe, language dirs included, bounded by --max-pages,
at most --max-concurrent in flight, 50 ms politeness delay). In crawl mode a
canonical is checked only when the page declares one; hreflang reciprocity is
always only checked for pages that declare hreflang.
  verify-live-site.py --prove-failure     # paired proof against a seeded fixture

Exit: 0 every assertion held | 1 a failed assertion or a REGRESSION against
the baseline | 2 could not determine (network down, sitemap unreadable, tool
missing). A 2 is NEVER a pass.  A failure (1) outranks a 2.

Only GET requests are issued (read-only), at most --max-concurrent (<=6) in
flight, with retries and timeouts.  Nothing is written outside the paths given
by --evidence-dir / --report-json.
"""
import argparse, concurrent.futures as cf, hashlib, html.parser, http.server
import json, os, re, shutil, socket, subprocess, sys, tempfile, threading
import time, urllib.error, urllib.parse, urllib.request, xml.etree.ElementTree as ET
from datetime import datetime, timezone

UA = "verify-live-site/1.0 (read-only QA probe)"
MAX_BODY = 60 * 1024 * 1024
DEFAULT_PRIVATE = ["/admin/", "/downloads/vault/"]


# ----------------------------------------------------------------- fetching
class _Redirects(urllib.request.HTTPRedirectHandler):
    max_redirections = 6

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        hops = getattr(req, "_hops", 0) + 1
        if hops > self.max_redirections:
            raise urllib.error.URLError("redirect loop / too many redirects")
        nr = super().redirect_request(req, fp, code, msg, headers, newurl)
        if nr is not None:
            setattr(nr, "_hops", hops)  # dynamic per-request hop counter
        return nr


_opener = urllib.request.build_opener(_Redirects())


def fetch(url, timeout=25, retries=3):
    """GET with retries. transport=True means no HTTP answer (undetermined)."""
    # Fail closed: even with retries <= 0 the caller gets a transport=True
    # (undetermined) result, never None.
    last = {"url": url, "status": 0, "transport": True, "error": "no fetch attempt made",
            "body": b"", "final_url": url, "ctype": "", "bytes": 0, "sha256": ""}
    for attempt in range(max(1, retries)):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Encoding": "identity"})
            with _opener.open(req, timeout=timeout) as r:
                body = r.read(MAX_BODY + 1)
                res = _result(url, r.status, r.headers, body, r.geturl())
            if res["status"] in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(1.5 * (attempt + 1)); continue
            return res
        except urllib.error.HTTPError as e:
            res = _result(url, e.code, e.headers, e.read(MAX_BODY + 1), e.geturl() or url)
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(1.5 * (attempt + 1)); continue
            return res
        except Exception as e:  # DNS, refused, timeout, redirect loop
            last = {"url": url, "status": 0, "transport": True, "error": f"{type(e).__name__}: {e}",
                    "body": b"", "final_url": url, "ctype": "", "bytes": 0, "sha256": ""}
            time.sleep(1.0 * (attempt + 1))
    return last


def _result(url, st, headers, body, final):
    ct = (headers.get("Content-Type") or "").split(";")[0].strip().lower()
    return {"url": url, "status": st, "transport": False, "final_url": final,
            "ctype": ct, "bytes": len(body), "sha256": hashlib.sha256(body).hexdigest(), "body": body}


# ------------------------------------------------------------------ parsing
class PageParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = None; self._in_title = False; self.desc = None; self.canonical = None
        self.lang = None; self.dir = None; self.og_image = None
        self.hreflang = {}; self.refs = []; self.ldjson = []; self._in_ld = False; self._ld = ""
        self.inline_css = []; self._in_style = False

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        if tag == "html":
            self.lang = a.get("lang"); self.dir = a.get("dir")
        elif tag == "title" and self.title is None:
            self._in_title = True; self.title = ""
        elif tag == "meta":
            n = a.get("name", "").lower(); p = a.get("property", "").lower()
            if n == "description": self.desc = a.get("content")
            if p == "og:image" or n == "og:image": self.og_image = a.get("content")
        elif tag == "link":
            rel = a.get("rel", "").lower().split(); href = a.get("href")
            if "canonical" in rel and href: self.canonical = href
            elif "alternate" in rel and a.get("hreflang") and href:
                self.hreflang[a["hreflang"].lower()] = href
            elif href and any(r in rel for r in ("stylesheet", "icon", "preload", "manifest", "apple-touch-icon", "shortcut")):
                self.refs.append(("link", href))
        elif tag == "script":
            if a.get("type", "").lower() == "application/ld+json":
                self._in_ld = True; self._ld = ""
            if a.get("src"): self.refs.append(("script", a["src"]))
        elif tag == "style":
            self._in_style = True; self.inline_css.append("")
        elif tag in ("img", "source", "video", "audio", "iframe", "embed", "track"):
            if a.get("src"): self.refs.append((tag, a["src"]))
            for part in a.get("srcset", "").split(","):
                u = part.strip().split(" ")[0]
                if u: self.refs.append((tag, u))
            if a.get("poster"): self.refs.append((tag, a["poster"]))
        elif tag == "a" and a.get("href"):
            self.refs.append(("a", a["href"]))
        if a.get("style"): self.inline_css.append(a["style"])

    def handle_endtag(self, tag):
        if tag == "title": self._in_title = False
        if tag == "script" and self._in_ld:
            self._in_ld = False; self.ldjson.append(self._ld)
        if tag == "style": self._in_style = False

    def handle_data(self, data):
        if self._in_title and self.title is not None: self.title += data
        if self._in_ld: self._ld += data
        if self._in_style and self.inline_css: self.inline_css[-1] += data


CSS_URL = re.compile(r"url\(\s*(['\"]?)(.*?)\1\s*\)", re.I)
CSS_IMPORT = re.compile(r"@import\s+['\"]([^'\"]+)['\"]", re.I)


def css_refs(text):
    return [m.group(2) for m in CSS_URL.finditer(text)] + CSS_IMPORT.findall(text)


def _canon_key(u):
    s = urllib.parse.urlsplit(u)
    p = s.path
    if p.endswith("/index.html"): p = p[: -len("index.html")]
    return (s.netloc, p.rstrip("/") or "/")


def _path_key(u):
    s = urllib.parse.urlsplit(u)
    return (s.path or "/") + (("?" + s.query) if s.query else "")


# --------------------------------------------------------------------- core
class Verifier:
    expect_version = None      # --expect-version X: every HTML page must show the version footer link
    version_url_prefix = None  # --version-url-prefix URL: link must equal <prefix><X>, which must answer 200

    def __init__(self, base, sitemap_dir=None, private=None, conc=6, crawl=False, max_pages=2000, legacy_hosts=None):
        self.crawl = crawl; self.max_pages = max(1, max_pages)
        self.crawled = set(); self.cache = {}; self.crawl_mode = False
        self.legacy_hosts = [h.lower() for h in (legacy_hosts or [])]; self.legacy = []
        self.base = base.rstrip("/")
        self.bo = urllib.parse.urlsplit(self.base)
        self.sitemap_dir = sitemap_dir
        self.private = private or DEFAULT_PRIVATE
        self.conc = max(1, min(6, conc))
        self.canon_origin = None
        self.failures = []; self.undet = []; self.notes = []
        self.pages = {}; self.resources = {}

    def norm(self, url: str) -> str:
        """Map URLs on the sitemap's canonical origin onto --base; drop fragment."""
        s = urllib.parse.urlsplit(url)
        if s.netloc and s.netloc != self.bo.netloc and self.canon_origin and s.netloc == self.canon_origin:
            s = s._replace(scheme=self.bo.scheme, netloc=self.bo.netloc)
        return urllib.parse.urlunsplit(s._replace(fragment=""))

    def internal(self, url): return urllib.parse.urlsplit(url).netloc == self.bo.netloc
    def fail(self, aid, url, msg): self.failures.append({"id": aid, "url": url, "msg": msg})
    def und(self, aid, url, msg): self.undet.append({"id": aid, "url": url, "msg": msg})

    def get(self, url):
        r = fetch(url)
        if r["transport"]: self.und("transport", url, r["error"])
        return r

    def sitemap_urls(self):
        urls = []; seen = set(); queue = [self.base + "/sitemap.xml"]
        while queue:
            su = queue.pop(0)
            if su in seen: continue
            seen.add(su)
            r = self.get(su)
            if r["transport"]: continue
            if r["status"] == 404 and su == self.base + "/sitemap.xml":
                self.notes.append("no sitemap.xml (HTTP 404); relying on crawl discovery"); continue
            if r["status"] != 200:
                self.fail("sitemap-fetch", su, f"sitemap HTTP {r['status']}"); continue
            try:
                root = ET.fromstring(r["body"])
            except ET.ParseError as e:
                self.fail("sitemap-parse", su, f"invalid XML: {e}"); continue
            locs = [e.text.strip() for e in root.iter() if e.tag.split("}")[-1] == "loc" and e.text]
            if root.tag.split("}")[-1] == "sitemapindex":
                if not self.canon_origin and locs: self.canon_origin = urllib.parse.urlsplit(locs[0]).netloc
                queue += [self.norm(l) for l in locs]
            else:
                urls += locs
        if urls and not self.canon_origin:
            self.canon_origin = urllib.parse.urlsplit(urls[0]).netloc
        out = []
        for u in urls:
            if urllib.parse.urlsplit(u).netloc not in (self.bo.netloc, self.canon_origin):
                self.fail("sitemap-foreign-origin", u, "sitemap lists a URL on a different origin")
            out.append(self.norm(u))
        return list(dict.fromkeys(out))

    def urls_of_local_dir(self):
        d = self.sitemap_dir; out = []
        if not d: return out
        sm = os.path.join(d, "sitemap.xml")
        if not os.path.isfile(sm):
            self.und("local-dir", sm, "--sitemap-from-dir has no sitemap.xml"); return out
        try:
            for e in ET.parse(sm).getroot().iter():
                if e.tag.split("}")[-1] == "loc" and e.text: out.append(self.norm(e.text.strip()))
        except ET.ParseError as e:
            self.fail("local-sitemap-parse", sm, str(e))
        return out

    def run(self):
        t0 = time.time()
        urls = self.sitemap_urls()
        for u in self.urls_of_local_dir():
            if u not in urls:
                self.notes.append(f"in local _site sitemap but not in served sitemap: {u}")
                urls.append(u)
        if self.crawl or not urls:
            self.crawl_mode = True
            for u in self.crawl_urls():
                if u not in urls: urls.append(u)
        if not urls:
            self.und("sitemap-empty", self.base, "no URLs discovered; cannot determine")
            return self.report(t0, urls)
        with cf.ThreadPoolExecutor(self.conc) as ex:
            results = list(ex.map(lambda u: self.cache.get(u) or self.get(u), urls))
        parsed = {}
        for u, r in zip(urls, results): self.check_page(u, r, parsed)
        self.check_hreflang(parsed)
        self.check_resources(parsed)
        self.check_private(urls)
        self.check_robots()
        self.check_404()
        if self.expect_version: self.check_release_url()
        return self.report(t0, urls)

    _VER = re.compile(r'<[^>]+class="[^"]*\bmv-ver__link\b[^"]*"[^>]*>(.*?)</a>', re.S)

    def check_version_footer(self, u, html_text, info):
        """Every HTML page carries the footer version link: href == prefix+X, text == vX."""
        want = f"{self.version_url_prefix}{self.expect_version}"
        links = re.findall(r'<a\b[^>]*\bmv-ver__link\b[^>]*>.*?</a>', html_text, re.S)
        if len(links) != 1:
            self.fail("version-footer-missing", u, f"{len(links)} .mv-ver__link element(s), expected exactly 1"); return
        m = re.search(r'href="([^"]*)"', links[0]); href = m.group(1) if m else ""
        text = re.sub(r"<[^>]+>", "", links[0]).strip()
        info["version_link"] = href
        if href != want: self.fail("version-footer-link", u, f"href {href!r} != {want!r}")
        if text != f"v{self.expect_version}": self.fail("version-footer-text", u, f"text {text!r} != 'v{self.expect_version}'")

    def check_release_url(self):
        url = f"{self.version_url_prefix}{self.expect_version}"
        r = fetch(url)
        if r["transport"]: self.und("version-release-url", url, r["error"]); return
        if r["status"] != 200: self.fail("version-release-url", url, f"release page HTTP {r['status']}")
        else: self.notes.append(f"release page {url} -> HTTP 200")

    def _polite_get(self, u):
        time.sleep(0.05)
        return self.get(u)

    def crawl_urls(self):
        """BFS over same-origin <a href> from the home page; returns discovered URLs."""
        home = self.base + "/"
        seen = {home}; order = [home]; frontier = [home]
        self.cache[home] = self.get(home); truncated = False
        while frontier:
            nxt = []
            for u in frontier:
                r = self.cache[u]
                if r["transport"] or r["status"] != 200 or "html" not in r["ctype"]: continue
                p = PageParser()
                try:
                    p.feed(r["body"].decode("utf-8", "replace")); p.close()
                except Exception:
                    continue  # reported by check_page as html-parse
                if u == home and p.canonical and not self.canon_origin:
                    cn = urllib.parse.urlsplit(p.canonical).netloc
                    if cn and cn != self.bo.netloc and self.bo.hostname in ("127.0.0.1", "localhost"):
                        self.canon_origin = cn
                for kind, ref in p.refs:
                    if kind != "a": continue
                    n = self._abs(u, ref)
                    if not n or n in seen: continue
                    if any(urllib.parse.urlsplit(n).path.startswith(x) for x in self.private): continue
                    if len(seen) >= self.max_pages:
                        truncated = True; continue
                    seen.add(n); order.append(n); nxt.append(n); self.crawled.add(n)
            if nxt:
                with cf.ThreadPoolExecutor(self.conc) as ex:
                    for u, r in zip(nxt, ex.map(self._polite_get, nxt)): self.cache[u] = r
            frontier = nxt
        if truncated:
            self.und("crawl-truncated", self.base, f"--max-pages {self.max_pages} reached; coverage incomplete")
        self.notes.append(f"crawl discovered {len(order)} URL(s) (max-pages {self.max_pages})")
        return order

    def check_page(self, u, r, parsed):
        info = {"status": r["status"], "final_url": r["final_url"], "ctype": r["ctype"],
                "bytes": r["bytes"], "sha256": r["sha256"]}
        self.pages[u] = info
        if r["transport"]:
            info["error"] = r["error"]; return
        if r["status"] != 200:
            self.fail("link-dead" if u in self.crawled else "sitemap-url-status", u, f"HTTP {r['status']}"); return
        if _canon_key(self.norm(r["final_url"])) != _canon_key(u):
            info["redirected_to"] = r["final_url"]
        if "html" not in r["ctype"]: return
        if r["bytes"] == 0:
            self.fail("empty-body", u, "0 bytes"); return
        p = PageParser()
        try:
            p.feed(r["body"].decode("utf-8", "replace")); p.close()
        except Exception as e:
            self.fail("html-parse", u, str(e)); return
        title = (p.title or "").strip()
        info.update(title=title, description=p.desc, canonical=p.canonical, lang=p.lang, dir=p.dir,
                    og_image=p.og_image, hreflang=p.hreflang)
        parsed[u] = p
        if self.expect_version: self.check_version_footer(u, r["body"].decode("utf-8", "replace"), info)
        if not title: self.fail("title-empty", u, "missing or empty <title>")
        if not p.canonical:
            if not self.crawl_mode: self.fail("canonical-missing", u, "no rel=canonical")
        else:
            c = self.norm(urllib.parse.urljoin(u, p.canonical))
            if self.crawl_mode and not self.internal(c):
                self.note_legacy("canonical", u, c)
            elif _canon_key(c) != _canon_key(u):
                self.fail("canonical-mismatch", u, f"canonical {c} != own URL")
        for i, raw in enumerate(p.ldjson):
            try: json.loads(raw)
            except Exception as e: self.fail("jsonld-invalid", u, f"JSON-LD block {i}: {e}")
        if self.bo.scheme == "https":
            for kind, ref in p.refs:
                if kind != "a" and ref.lower().startswith("http://"):
                    self.fail("mixed-content", u, f"{kind} {ref}")
            if (p.og_image or "").lower().startswith("http://"):
                self.fail("mixed-content", u, f"og:image {p.og_image}")

    def note_legacy(self, kind, page, ref):
        """Foreign-origin reference (e.g. old domain): reported as a pre-existing finding, never a failure."""
        self.legacy.append({"kind": kind, "page": page, "ref": ref,
                            "legacy_host": urllib.parse.urlsplit(ref).netloc.lower() in self.legacy_hosts})

    def scan_foreign_refs(self, parsed):
        for u, p in parsed.items():
            cands = [("og:image", p.og_image)] + [(f"hreflang[{k}]", v) for k, v in p.hreflang.items()]
            cands += [(kind, ref) for kind, ref in p.refs]
            for kind, ref in cands:
                if not ref: continue
                a = urllib.parse.urljoin(u, ref.strip())
                host = urllib.parse.urlsplit(a).netloc.lower()
                if host in self.legacy_hosts: self.note_legacy(kind, u, a)

    def check_hreflang(self, parsed):
        if self.crawl_mode: self.scan_foreign_refs(parsed)
        alts = {u: {k: self.norm(urllib.parse.urljoin(u, v)) for k, v in p.hreflang.items()}
                for u, p in parsed.items() if p.hreflang}
        if self.crawl_mode:
            alts = {u: {k: t for k, t in a.items() if self.internal(t)} for u, a in alts.items()}
            alts = {u: a for u, a in alts.items() if a}
        self._hreflang_targets = set()
        for u, a in alts.items():
            if _canon_key(u) not in {_canon_key(t) for t in a.values()}:
                self.fail("hreflang-no-self", u, "hreflang set does not include the page itself")
            for lang, t in a.items():
                self._hreflang_targets.add(t)
                if lang == "x-default" or _canon_key(t) == _canon_key(u): continue
                if t in alts:
                    if _canon_key(u) not in {_canon_key(x) for x in alts[t].values()}:
                        self.fail("hreflang-nonreciprocal", u, f"{lang} -> {t} does not link back")
                elif t in self.pages:
                    self.fail("hreflang-nonreciprocal", u, f"{lang} -> {t} carries no hreflang set")

    def _abs(self, base_url, ref):
        ref = ref.strip()
        if not ref or ref.startswith(("#", "mailto:", "tel:", "javascript:", "data:", "blob:", "about:", "sms:")):
            return None
        n = self.norm(urllib.parse.urljoin(base_url, ref))
        if not n.startswith(("http://", "https://")) or not self.internal(n): return None
        return n

    def check_resources(self, parsed):
        refs = {}
        def add(page, ref):
            n = self._abs(page, ref)
            if n: refs.setdefault(n, set()).add(page)
        for u, p in parsed.items():
            for _, ref in p.refs: add(u, ref)
            if p.og_image: add(u, p.og_image)
            for css in p.inline_css:
                for ref in css_refs(css): add(u, ref)
        for t in self._hreflang_targets:
            if self.internal(t): refs.setdefault(t, set()).add("hreflang")
        for u in list(refs):
            if u in self.pages: del refs[u]
        done = set(); todo = sorted(refs)
        while todo:
            with cf.ThreadPoolExecutor(self.conc) as ex:
                batch = list(zip(todo, ex.map(self.get, todo)))
            done.update(todo); todo = []
            for u, r in batch:
                if r["transport"]:
                    self.resources[u] = {"status": 0, "error": r["error"]}; continue
                self.resources[u] = {"status": r["status"], "ctype": r["ctype"], "bytes": r["bytes"],
                                     "sha256": r["sha256"]}
                if r["status"] != 200:
                    self.fail("resource-dead", u, f"HTTP {r['status']} (from {sorted(refs[u])[:2]})"); continue
                path = urllib.parse.urlsplit(u).path.lower()
                if path.endswith(".pdf") or r["ctype"] == "application/pdf": self.check_pdf(u, r)
                if r["ctype"] == "text/css" or path.endswith(".css"):
                    for ref in css_refs(r["body"].decode("utf-8", "replace")):
                        n = self._abs(u, ref)
                        if n and n not in self.pages and n not in done and n not in todo:
                            refs.setdefault(n, set()).add(u); todo.append(n)
        for u, info in list(self.pages.items()):
            if info.get("ctype") == "application/pdf" and info.get("status") == 200:
                self.check_pdf(u, fetch(u))

    def check_pdf(self, u, r):
        if r["ctype"] != "application/pdf":
            self.fail("pdf-content-type", u, f"content-type {r['ctype']!r}")
        if not r["body"].startswith(b"%PDF"):
            self.fail("pdf-magic", u, "does not start with %PDF"); return
        if not shutil.which("pdftotext"):
            self.und("pdftotext-missing", u, "pdftotext not installed"); return
        with tempfile.TemporaryDirectory() as td:
            fp = os.path.join(td, "a.pdf")
            with open(fp, "wb") as f: f.write(r["body"])
            try:
                out = subprocess.run(["pdftotext", "-q", fp, "-"], capture_output=True, timeout=60)
            except subprocess.TimeoutExpired:
                self.und("pdftotext-timeout", u, "timeout"); return
        txt = out.stdout.decode("utf-8", "replace").strip()
        if out.returncode != 0 or not txt:
            self.fail("pdf-no-text", u, f"pdftotext rc={out.returncode}, {len(txt)} chars")

    def check_private(self, sitemap_urls):
        for pth in self.private:
            u = self.base + pth
            r = self.get(u)
            if not r["transport"] and r["status"] not in (404, 410):
                self.fail("private-exposed", u, f"HTTP {r['status']} (must be 404)")
            for s in sitemap_urls:
                if urllib.parse.urlsplit(s).path.startswith(pth):
                    self.fail("private-in-sitemap", s, f"sitemap lists private path {pth}")

    def check_robots(self):
        u = self.base + "/robots.txt"
        r = self.get(u)
        if r["transport"]: return
        if r["status"] != 200:
            self.fail("robots-missing", u, f"HTTP {r['status']}"); return
        t = r["body"].decode("utf-8", "replace")
        if "html" in r["ctype"]: self.fail("robots-insane", u, "served as HTML")
        if not re.search(r"(?im)^\s*user-agent\s*:", t): self.fail("robots-insane", u, "no User-agent line")
        if re.search(r"(?im)^\s*disallow\s*:\s*/\s*$", t): self.fail("robots-insane", u, "blanket 'Disallow: /'")
        if not re.search(r"(?im)^\s*sitemap\s*:", t): self.notes.append("robots.txt has no Sitemap: line")

    def check_404(self):
        u = f"{self.base}/__verify-no-such-page-{int(time.time())}__/"
        r = self.get(u)
        if r["transport"]: return
        if r["status"] != 404: self.fail("404-status", u, f"unknown path returned HTTP {r['status']}")
        elif "html" not in r["ctype"] or r["bytes"] == 0:
            self.fail("404-page", u, f"404 body not an HTML page ({r['ctype']!r}, {r['bytes']} B)")

    def compare_baseline(self, path):
        try:
            with open(path) as f: b = json.load(f)
        except Exception as e:
            self.und("baseline-read", path, str(e)); return {}
        old = {}
        for sec in ("pages", "resources"):
            for u, i in (b.get(sec) or {}).items(): old[_path_key(u)] = (i.get("status"), sec)
        cur = {}
        for d in (self.pages, self.resources):
            for u, i in d.items(): cur[_path_key(u)] = i.get("status")
        regress = []
        for k, (st, sec) in sorted(old.items()):
            if st == 200 and cur.get(k) != 200:
                now = cur.get(k, "ABSENT")
                regress.append({"path": k, "was": 200, "now": now, "section": sec})
                self.fail("REGRESSION", k, f"was 200 in baseline, now {now}")
        return {"baseline": path, "regressions": regress, "new_paths": sorted(k for k in cur if k not in old)}

    def report(self, t0, urls):
        return {"base": self.base, "canonical_origin": self.canon_origin,
                "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "duration_s": round(time.time() - t0, 1), "sitemap_urls": len(urls),
                "pages": self.pages, "resources": self.resources, "notes": self.notes,
                "preexisting_foreign_refs": self.legacy}


def verdict(rep):
    return 1 if rep["failures"] else (2 if rep["undetermined"] else 0)


def summarize(rep, rc):
    from collections import Counter
    c = Counter(f["id"] for f in rep["failures"]); uc = Counter(f["id"] for f in rep["undetermined"])
    pg = rep["pages"]; ok = sum(1 for i in pg.values() if i.get("status") == 200)
    bad_res = sum(1 for i in rep["resources"].values() if i.get("status") != 200)
    L = [f"verify-live-site  base={rep['base']}  at={rep['generated_utc']}  took={rep['duration_s']}s",
         f"sitemap URLs: {rep['sitemap_urls']}   pages HTTP 200: {ok}/{len(pg)}   "
         f"resources checked: {len(rep['resources'])} (non-200: {bad_res})",
         f"FAILED assertions: {len(rep['failures'])}   UNDETERMINED: {len(rep['undetermined'])}"]
    L += [f"  FAIL  {k}: {v}" for k, v in sorted(c.items())]
    L += [f"  UNDET {k}: {v}" for k, v in sorted(uc.items())]
    L += [f"    - [{f['id']}] {f['url']} :: {f['msg']}" for f in rep["failures"][:40]]
    if len(rep["failures"]) > 40: L.append(f"    ... {len(rep['failures']) - 40} more in JSON")
    L += [f"    ? [{f['id']}] {f['url']} :: {f['msg']}" for f in rep["undetermined"][:10]]
    bc = rep.get("baseline_compare")
    if bc:
        L.append(f"baseline {bc['baseline']}: regressions={len(bc['regressions'])} new_paths={len(bc['new_paths'])}")
        L += [f"    + new: {n}" for n in bc["new_paths"][:20]]
    lg = rep.get("preexisting_foreign_refs") or []
    if lg:
        from collections import Counter as _C
        L.append(f"PRE-EXISTING foreign-origin references (not failures): {len(lg)}  by kind: "
                 + ", ".join(f"{k}={v}" for k, v in sorted(_C(x['kind'] for x in lg).items())))
        L += [f"    ~ [{x['kind']}] {x['page']} -> {x['ref']}" for x in lg[:15]]
    L += [f"  note: {n}" for n in rep["notes"][:10]]
    L.append({0: "VERDICT: PASS (rc 0)", 1: "VERDICT: FAIL (rc 1)",
              2: "VERDICT: COULD NOT DETERMINE (rc 2) -- NOT a pass"}[rc])
    return "\n".join(L)


def run_once(base, sitemap_dir=None, private=None, conc=6, baseline=None, crawl=False, max_pages=2000, legacy_hosts=None,
             expect_version=None, version_url_prefix=None):
    v = Verifier(base, sitemap_dir, private, conc, crawl, max_pages, legacy_hosts)
    v.expect_version = expect_version; v.version_url_prefix = version_url_prefix
    rep = v.run()
    if baseline: rep["baseline_compare"] = v.compare_baseline(baseline)
    rep["failures"] = v.failures; rep["undetermined"] = v.undet
    rc = verdict(rep); rep["verdict_rc"] = rc
    return rep, rc


# ------------------------------------------------------------ prove-failure
def _mk_pdf(text):
    stream = f"BT /F1 12 Tf 10 50 Td ({text}) Tj ET".encode()
    objs = [b"<</Type/Catalog/Pages 2 0 R>>", b"<</Type/Pages/Kids[3 0 R]/Count 1>>",
            b"<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 100]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>",
            b"<</Length %d>>\nstream\n" % len(stream) + stream + b"\nendstream",
            b"<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>"]
    out = b"%PDF-1.4\n"; offs = []
    for i, o in enumerate(objs, 1):
        offs.append(len(out)); out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    x = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for o in offs: out += b"%010d 00000 n \n" % o
    return out + b"trailer\n<</Size %d/Root 1 0 R>>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, x)


def build_fixture(root, defect, port, sitemap=True):
    def w(rel, data):
        p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as f: f.write(data if isinstance(data, bytes) else data.encode())
    B = f"http://127.0.0.1:{port}"
    def vfoot(path):
        if defect == "version-missing" and path == "/b/": return ""
        href = f"{B}/rel/v9.9.8" if (defect == "version-wrong-link" and path == "/b/") else f"{B}/rel/v9.9.9"
        txt = "v9.9.7" if (defect == "version-wrong-text" and path == "/b/") else "v9.9.9"
        return (f'<footer class="footer"><p class="mv-ver"><span data-i18n="footer.version">Website version:</span> '
                f'<a class="mv-ver__link" href="{href}">{txt}</a></p></footer>')
    def page(path, title, canon, alts, extra):
        alt = "".join(f'<link rel="alternate" hreflang="{l}" href="{B}{u}">' for l, u in (alts or {}).items())
        return (f'<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{title}</title>'
                f'<meta name="description" content="d"><link rel="canonical" href="{B}{canon or path}">{alt}'
                f'<link rel="stylesheet" href="/a.css"></head><body><a href="/b/">b</a><a href="/de/">de</a>{extra}{vfoot(path)}</body></html>')
    both = {"en": "/", "de": "/de/"}
    pages = {"/": ("Home", both), "/de/": ("Heim", both), "/b/": ("B", None)}
    if defect == "hreflang-nonreciprocal": pages["/de/"] = ("Heim", {"de": "/de/"})
    for pth, (t, alts) in pages.items():
        if pth == "/b/" and defect == "drop-b": continue
        canon = "/wrong/" if (defect == "canonical-mismatch" and pth == "/b/") else None
        extra = ""
        if pth == "/b/":
            extra = ('<a href="/doc.pdf">pdf</a>' + ('<img src="/missing.png">' if defect in ("resource-dead", "crawl-resource-dead") else "")
                     + ('<a href="/gone/">gone</a>' if defect == "crawl-dead-link" else "")
                     + ('<link rel="canonical" href="https://old.example/b/">' if defect == "legacy-canon" else ""))
        w(pth.lstrip("/") + "index.html", page(pth, t, canon, alts, extra))
    w("a.css", "body{background:url(/bg.png)}")
    w("bg.png", b"\x89PNG\r\n\x1a\n0000")
    w("doc.pdf", b"this is not a pdf at all" if defect == "pdf-magic" else _mk_pdf("Hello CV"))
    w("404.html", "<!doctype html><html><head><title>404</title></head><body>nf</body></html>")
    w("robots.txt", f"User-agent: *\nAllow: /\nSitemap: {B}/sitemap.xml\n")
    locs = ["/", "/de/"] + ([] if defect == "drop-b" else ["/b/"]) + (["/gone/"] if defect == "sitemap-url-status" else [])
    if sitemap: w("sitemap.xml", '<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
      + "".join(f"<url><loc>{B}{l}</loc></url>" for l in locs) + "</urlset>")
    if defect != "version-no-release": w("rel/v9.9.9/index.html", "<title>release</title>")
    if defect == "private-exposed": w("admin/index.html", "<title>secret</title>")


def serve(root, port):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args): pass
        def do_GET(self):
            p = urllib.parse.urlsplit(self.path).path
            fp = os.path.normpath(os.path.join(root, p.lstrip("/")))
            if os.path.isdir(fp): fp = os.path.join(fp, "index.html")
            if fp.startswith(root) and os.path.isfile(fp):
                code = 200
                with open(fp, "rb") as f: data = f.read()
                ct = {".html": "text/html", ".css": "text/css", ".pdf": "application/pdf", ".png": "image/png",
                      ".xml": "application/xml", ".txt": "text/plain"}.get(os.path.splitext(fp)[1], "application/octet-stream")
            else:
                code, ct = 404, "text/html"
                with open(os.path.join(root, "404.html"), "rb") as f: data = f.read()
            self.send_response(code); self.send_header("Content-Type", ct)
            self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", port), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def _free_port():
    s = socket.socket(); s.bind(("127.0.0.1", 0)); p = s.getsockname()[1]; s.close(); return p


def prove_failure():
    ok = True; lines = []
    def case(name, defect, expect_rc, expect_id=None, baseline=None, crawl=False, sitemap=True, max_pages=2000,
             want_page=None, want_legacy=False, version=False):
        nonlocal ok
        td = tempfile.mkdtemp(prefix="vls-fixture-"); port = _free_port(); srv = None
        try:
            build_fixture(td, defect, port, sitemap); srv = serve(td, port)
            rep, rc = run_once(f"http://127.0.0.1:{port}", baseline=baseline, crawl=crawl, max_pages=max_pages,
                              legacy_hosts=["old.example"],
                              expect_version="9.9.9" if version else None,
                              version_url_prefix=f"http://127.0.0.1:{port}/rel/v" if version else None)
        finally:
            if srv: srv.shutdown(); srv.server_close()
            shutil.rmtree(td, ignore_errors=True)
        ids = sorted({f["id"] for f in rep["failures"]})
        good = rc == expect_rc and (expect_id is None or expect_id in ids)
        if want_page: good = good and any(k.endswith(want_page) for k in rep["pages"])
        if want_legacy: good = good and bool(rep["preexisting_foreign_refs"])
        lines.append(f"  {'PASS' if good else 'FAIL'} {name}: rc={rc} (want {expect_rc}) ids={ids[:6]}")
        ok &= good
        return rep
    rep0 = case("control: clean fixture is green", None, 0)
    for d in ["sitemap-url-status", "canonical-mismatch", "hreflang-nonreciprocal",
              "resource-dead", "pdf-magic", "private-exposed"]:
        case(f"seeded defect detected: {d}", d, 1, d)
    case("version footer: control green (every page links vX, release URL 200)", None, 0, version=True)
    for d, i in [("version-wrong-link", "version-footer-link"), ("version-wrong-text", "version-footer-text"),
                 ("version-missing", "version-footer-missing"), ("version-no-release", "version-release-url")]:
        case(f"seeded defect detected: {d}", d, 1, i, version=True)
    case("crawl (no sitemap): control green, hidden page /b/ discovered", None, 0, crawl=True, sitemap=False, want_page="/b/")
    case("crawl auto-fallback when sitemap absent", None, 0, sitemap=False, want_page="/b/")
    case("crawl seeded defect detected: dead link", "crawl-dead-link", 1, "link-dead", crawl=True, sitemap=False)
    case("crawl seeded defect detected: broken asset", "crawl-resource-dead", 1, "resource-dead", crawl=True, sitemap=False)
    case("crawl: foreign canonical reported, not failed", "legacy-canon", 0, crawl=True, sitemap=False, want_legacy=True)
    case("crawl bounded: --max-pages 2 -> rc 2 (incomplete), never a pass", None, 2, crawl=True, sitemap=False, max_pages=2)
    bf = tempfile.mktemp(suffix=".json", prefix="vls-base-")
    with open(bf, "w") as f: json.dump({k: rep0[k] for k in ("pages", "resources")}, f)
    case("baseline REGRESSION detected (page 200 -> gone)", "drop-b", 1, "REGRESSION", baseline=bf)
    os.unlink(bf)
    rep, rc = run_once(f"http://127.0.0.1:{_free_port()}")
    good = rc == 2
    lines.append(f"  {'PASS' if good else 'FAIL'} unreachable base -> rc 2, never a pass: rc={rc}"); ok &= good
    print("verify-live-site --prove-failure"); print("\n".join(lines))
    print("PROOF: " + ("OK -- every seeded defect detected, control green, rc 2 honoured" if ok else "FAILED"))
    return 0 if ok else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base"); ap.add_argument("--sitemap-from-dir")
    ap.add_argument("--evidence-dir"); ap.add_argument("--baseline")
    ap.add_argument("--report-json", help="also write the JSON report (+ .txt summary) to this path")
    ap.add_argument("--max-concurrent", type=int, default=6)
    ap.add_argument("--private-path", action="append")
    ap.add_argument("--crawl", action="store_true", help="discover pages by BFS crawl (auto when sitemap absent)")
    ap.add_argument("--max-pages", type=int, default=2000)
    ap.add_argument("--legacy-host", action="append", help="old host whose remaining references are reported as pre-existing")
    ap.add_argument("--expect-version", help="assert every crawled HTML page has the footer version link v<X> and the release URL answers 200")
    ap.add_argument("--version-url-prefix", help="release URL prefix, e.g. https://github.com/OWNER/REPO/releases/tag/v (required with --expect-version)")
    ap.add_argument("--prove-failure", action="store_true")
    a = ap.parse_args(argv)
    if a.prove_failure: return prove_failure()
    if not a.base:
        print("--base is required", file=sys.stderr); return 2
    if bool(a.expect_version) != bool(a.version_url_prefix):
        print("--expect-version and --version-url-prefix go together", file=sys.stderr); return 2
    rep, rc = run_once(a.base, a.sitemap_from_dir, a.private_path, a.max_concurrent, a.baseline,
                      a.crawl, a.max_pages, a.legacy_host, a.expect_version, a.version_url_prefix)
    text = summarize(rep, rc)
    blob = json.dumps(rep, indent=1, sort_keys=True, ensure_ascii=False)
    sha = hashlib.sha256(blob.encode()).hexdigest()
    print(text); print(f"report sha256: {sha}")
    outs = []
    if a.evidence_dir:
        os.makedirs(a.evidence_dir, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        host = re.sub(r"[^A-Za-z0-9]+", "_", urllib.parse.urlsplit(a.base).netloc)
        stem = os.path.join(a.evidence_dir, f"verify-live-site-{host}-{stamp}")
        outs += [(stem + ".json", blob), (stem + ".txt", text + f"\nreport sha256: {sha}\n"),
                 (stem + ".json.sha256", f"{sha}  {os.path.basename(stem)}.json\n")]
    if a.report_json:
        outs += [(a.report_json, blob), (os.path.splitext(a.report_json)[0] + ".txt", text + f"\nreport sha256: {sha}\n")]
    for p, d in outs:
        with open(p, "w") as f: f.write(d)
        print("wrote", p)
    return rc


if __name__ == "__main__":
    sys.exit(main())
