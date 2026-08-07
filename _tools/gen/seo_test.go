package main

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

func testSite() *Site {
	return &Site{
		Key:     "vasic.digital",
		Brand:   "Vasic Digital",
		CSSName: "vasic-digital",
		Domain:  "vasic.digital",
		OGImage: "Assets/Logo.jpeg",
		LDKind:  "Organization",
		SameAs:  []string{"https://github.com/nexu-io"},
	}
}

func TestSiteURL(t *testing.T) {
	s := testSite()
	cases := []struct{ in, want string }{
		{"", "https://vasic.digital/"},
		{"products/x.html", "https://vasic.digital/products/x.html"},
		{"/portfolio/", "https://vasic.digital/portfolio/"}, // leading slash trimmed
		{"sitemap.xml", "https://vasic.digital/sitemap.xml"},
	}
	for _, c := range cases {
		if got := s.URL(c.in); got != c.want {
			t.Errorf("URL(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestLangPath(t *testing.T) {
	cases := []struct{ lang, en, want string }{
		{"en", "", ""},
		{"en", "products/x.html", "products/x.html"},
		{"de", "", "de/"},
		{"de", "portfolio/", "portfolio/de/"},
		{"de", "products/x.html", "products/de/x.html"},
		{"ru", "articles/a.html", "ru/articles/a.html"},
	}
	for _, c := range cases {
		if got := langPath(c.lang, c.en); got != c.want {
			t.Errorf("langPath(%q,%q) = %q, want %q", c.lang, c.en, got, c.want)
		}
	}
}

func TestAvailableLangs(t *testing.T) {
	langs := availableLangs(repoRoot())
	if len(langs) == 0 || langs[0] != "en" {
		t.Fatalf("availableLangs must start with en, got %v", langs)
	}
	// en first, remainder sorted, no dupes, no _proof scratch dirs.
	rest := langs[1:]
	if !sort.StringsAreSorted(rest) {
		t.Errorf("non-en langs not sorted: %v", rest)
	}
	seen := map[string]bool{}
	for _, l := range langs {
		if seen[l] {
			t.Errorf("duplicate lang %q", l)
		}
		seen[l] = true
		if strings.Contains(l, "_") {
			t.Errorf("scratch/proof dir leaked into langs: %q", l)
		}
	}
	// The repo has authored _content_ru/sr on disk (more languages are added by
	// the translation batch as they complete; availableLangs must reflect what
	// actually exists, not a hardcoded set).
	for _, want := range []string{"ru", "sr"} {
		if !seen[want] {
			t.Errorf("expected lang %q present (from _content_%s/), got %v", want, want, langs)
		}
	}
}

func TestHreflangLinksReciprocal(t *testing.T) {
	s := testSite()
	langs := []string{"en", "de", "ru"}
	out := hreflangLinks(s, langs, "products/x.html")
	// One alternate per lang + x-default.
	for _, l := range langs {
		want := `hreflang="` + l + `"`
		if !strings.Contains(out, want) {
			t.Errorf("missing %s in hreflang block:\n%s", want, out)
		}
	}
	if !strings.Contains(out, `hreflang="x-default"`) {
		t.Errorf("missing x-default:\n%s", out)
	}
	// x-default points at the EN canonical path.
	if !strings.Contains(out, `hreflang="x-default" href="https://vasic.digital/products/x.html"`) {
		t.Errorf("x-default must map to EN canonical:\n%s", out)
	}
	// German alternate must use the localized products/de/ path.
	if !strings.Contains(out, `hreflang="de" href="https://vasic.digital/products/de/x.html"`) {
		t.Errorf("de alternate wrong:\n%s", out)
	}
}

func TestJSONLDScriptHasType(t *testing.T) {
	s := testSite()
	ld := s.baseGraph()
	if !strings.Contains(ld, `<script type="application/ld+json">`) {
		t.Errorf("baseGraph not wrapped in ld+json script: %s", ld)
	}
	if !strings.Contains(ld, `"@context": "https://schema.org"`) {
		t.Errorf("missing @context: %s", ld)
	}
	if !strings.Contains(ld, `"@type": "Organization"`) {
		t.Errorf("missing Organization @type: %s", ld)
	}
	if !strings.Contains(ld, `"@type": "WebSite"`) {
		t.Errorf("missing WebSite @type: %s", ld)
	}
}

func TestSoftwareApplicationNodeHidesTBDLicense(t *testing.T) {
	s := testSite()
	tbd := &PortfolioEntry{Name: "X", Slug: "x", Summary: "sum", License: "TBD"}
	node := s.softwareApplicationNode(tbd)
	if node["@type"] != "SoftwareApplication" {
		t.Errorf("@type = %v", node["@type"])
	}
	if _, ok := node["license"]; ok {
		t.Error("TBD license must be suppressed from JSON-LD")
	}
	mit := &PortfolioEntry{Name: "Y", Slug: "y", Summary: "sum", License: "MIT"}
	if s.softwareApplicationNode(mit)["license"] != "MIT" {
		t.Error("MIT license must be present in JSON-LD")
	}
}

func TestSeoHeadSingletons(t *testing.T) {
	s := testSite()
	head := seoHead(s, []string{"en", "de"}, pageSEO{
		title:  "HelixTrack — Vasic Digital",
		desc:   "A JIRA alternative.",
		enPath: "products/helixtrack.html",
		ogType: "article",
		jsonLD: s.baseGraph(),
	})
	if n := strings.Count(head, "<title>"); n != 1 {
		t.Errorf("expected exactly one <title>, got %d", n)
	}
	must := []string{
		`<title>HelixTrack — Vasic Digital</title>`,
		`<meta name="description" content="A JIRA alternative."/>`,
		`<link rel="canonical" href="https://vasic.digital/products/helixtrack.html"/>`,
		`<meta property="og:type" content="article"/>`,
		`<meta property="og:title"`,
		`<meta name="twitter:card" content="summary_large_image"/>`,
		`hreflang="x-default"`,
	}
	for _, m := range must {
		if !strings.Contains(head, m) {
			t.Errorf("seoHead missing %q\n---\n%s", m, head)
		}
	}
}

func TestWriteSitemapRobots(t *testing.T) {
	s := testSite()
	tmp := t.TempDir()
	// Pages that must appear (index.html pretty-URLed; nested index too).
	writeMust := map[string]string{
		"index.html":               "<html></html>",
		"products/helixtrack.html": "<html></html>",
		"portfolio/index.html":     "<html></html>",
		"products/x.legacy.html":   "<html></html>", // excluded
		"articles/frag.html":       "<html></html>", // excluded dir
		"assets/od/thing.html":     "<html></html>", // excluded dir
		"_site/index.html":         "<html></html>", // excluded dir
	}
	for rel, body := range writeMust {
		if err := writeFile(filepath.Join(tmp, rel), body); err != nil {
			t.Fatal(err)
		}
	}
	if err := writeSitemapRobots(s, tmp); err != nil {
		t.Fatalf("writeSitemapRobots: %v", err)
	}
	sm, err := os.ReadFile(filepath.Join(tmp, "sitemap.xml"))
	if err != nil {
		t.Fatal(err)
	}
	xml := string(sm)
	// index.html -> root; nested index.html -> dir slash.
	wantURLs := []string{
		"<loc>https://vasic.digital/</loc>",
		"<loc>https://vasic.digital/products/helixtrack.html</loc>",
		"<loc>https://vasic.digital/portfolio/</loc>",
	}
	for _, u := range wantURLs {
		if !strings.Contains(xml, u) {
			t.Errorf("sitemap missing %q\n%s", u, xml)
		}
	}
	// Excluded paths must NOT appear.
	for _, bad := range []string{"legacy", "articles/frag", "assets/od", "_site"} {
		if strings.Contains(xml, bad) {
			t.Errorf("sitemap leaked excluded path %q:\n%s", bad, xml)
		}
	}
	// robots.txt points at the sitemap.
	rb, err := os.ReadFile(filepath.Join(tmp, "robots.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(rb), "Sitemap: https://vasic.digital/sitemap.xml") {
		t.Errorf("robots.txt missing sitemap line:\n%s", string(rb))
	}
}
