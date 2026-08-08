// Command gen renders all site content for vasic.digital and milosvasic.ru
// dynamically from _content/** and design-system/**. No page is hardcoded:
// Go holds only layout/templates; every product name, status, tech, repo, and
// copy string comes from _content/products/*.md, _content/portfolio/portfolio.json,
// _content/sites/*.home.json, and design-system/diagrams|icons.
//
// Usage:
//
//	gen -site <vasic.digital|milosvasic.ru> [-lang en] [-what all|products|portfolio|home]
//	    [-root <repo>] [-out <dir>]
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// buildYear stamps the footer copyright year. It is derived (current year) so it
// never silently goes stale (§11.4.35 "as data" / §11.4.6 honesty), and is
// overridable for reproducible builds via -ldflags "-X main.buildYear=YYYY".
var buildYear = ""

// copyrightYear returns the footer copyright year: the pinned buildYear when set,
// otherwise the current calendar year.
func copyrightYear() string {
	if buildYear != "" {
		return buildYear
	}
	return strconv.Itoa(time.Now().Year())
}

type Site struct {
	Key      string
	Brand    string
	CSSName  string // basename of the deployed brand CSS at <site>/assets/od/<CSSName>.css
	HomeJSON string // path (relative to root) of the homepage content data
	Dir      string // default output dir (relative to root)
	Jekyll   bool   // true → pages are rendered as Jekyll documents that inherit the
	// shared _layouts/default.html chrome (header/nav/footer), so the header is one
	// source of truth across index/portfolio/product. false → self-contained pages.

	Domain  string // production host (from CNAME), no scheme
	OGImage string // root-relative Open Graph / letterhead image that exists on disk
	Favicon string // root-relative favicon that exists on disk
	// TouchIcon is the root-relative apple-touch / launcher icon. If empty the
	// apple-touch-icon falls back to OGImage. Kept separate so the launcher icon
	// (a brand monogram) never has to double as the Open Graph share image.
	TouchIcon string
	LDKind    string   // JSON-LD identity: "Organization" | "Person"
	SameAs    []string // JSON-LD sameAs profile URLs
}

// URL builds an absolute production URL from a root-relative path (no leading /).
func (s *Site) URL(path string) string {
	return "https://" + s.Domain + "/" + strings.TrimPrefix(path, "/")
}

var sites = map[string]*Site{
	"vasic.digital": {
		Key:      "vasic.digital",
		Brand:    "Vasic Digital",
		CSSName:  "vasic-digital",
		HomeJSON: "_content/sites/vasic-digital.home.json",
		Dir:      "vasic.digital",
		Domain:   "vasic.digital",
		OGImage:  "Assets/Logo.jpeg",
		Favicon:  "Assets/logo.svg",
		LDKind:   "Organization",
		SameAs:   []string{"https://github.com/Helix-Track", "https://github.com/nexu-io"},
	},
	"milosvasic.ru": {
		Key:       "milosvasic.ru",
		Brand:     "Miloš Vasić",
		CSSName:   "milosvasic",
		HomeJSON:  "_content/sites/milosvasic-ru.home.json",
		Dir:       "milosvasic.ru",
		Jekyll:    true,
		Domain:    "milosvasic.ru",
		OGImage:   "assets/images/profile-800.jpg",
		Favicon:   "assets/images/mv-monogram.svg",
		TouchIcon: "assets/images/mv-monogram-180.png",
		LDKind:    "Person",
		SameAs: []string{
			"https://github.com/milos85vasic",
			"https://gitlab.com/milos85vasic",
			"https://t.me/milos85vasic",
		},
	},
}

func writeFile(path, content string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}

func main() {
	var siteKey, lang, what, root, out string
	flag.StringVar(&siteKey, "site", "", "target site: vasic.digital | milosvasic.ru")
	flag.StringVar(&lang, "lang", "en", "language code")
	flag.StringVar(&what, "what", "all", "what to render: all | products | portfolio | home")
	flag.StringVar(&root, "root", ".", "repository root")
	flag.StringVar(&out, "out", "", "output base dir (default: <root>/<site>)")
	flag.Parse()

	site, ok := sites[siteKey]
	if !ok {
		fmt.Fprintln(os.Stderr, "error: -site must be vasic.digital or milosvasic.ru")
		os.Exit(2)
	}
	absRoot, err := filepath.Abs(root)
	if err != nil {
		fatal(err)
	}
	if out == "" {
		out = filepath.Join(absRoot, site.Dir)
	} else {
		out, _ = filepath.Abs(out)
	}
	langSeg := ""
	if lang != "" && lang != "en" {
		langSeg = lang
	}

	p, err := loadPortfolio(filepath.Join(absRoot, "_content", "portfolio", "portfolio.json"))
	if err != nil {
		fatal(fmt.Errorf("portfolio: %w", err))
	}

	langs := availableLangs(absRoot)

	nProducts := 0
	if what == "all" || what == "products" {
		for i := range p.Entries {
			e := &p.Entries[i]
			html, err := renderProduct(absRoot, site, e, langs, lang)
			if err != nil {
				fatal(err)
			}
			var dest string
			if langSeg != "" {
				dest = filepath.Join(out, "products", langSeg, e.Slug+".html")
			} else {
				dest = filepath.Join(out, "products", e.Slug+".html")
			}
			if err := writeFile(dest, html); err != nil {
				fatal(err)
			}
			nProducts++
		}
	}

	if what == "all" || what == "portfolio" {
		html := renderPortfolio(root, p, site, langs, lang)
		var dest string
		if langSeg != "" {
			dest = filepath.Join(out, "portfolio", langSeg, "index.html")
		} else {
			dest = filepath.Join(out, "portfolio", "index.html")
		}
		if err := writeFile(dest, html); err != nil {
			fatal(err)
		}
	}

	if what == "all" || what == "home" {
		// Localized homes: for a non-en lang, load the per-language home data
		// (_content/sites/<base>.home.<lang>.json) so the hero/sections/cards BODY
		// is translated; fall back to the EN data (reported) when it's missing. The
		// EN home stays at the site root; localized homes land at /<lang>/index.html
		// (self-contained vasic) or the Jekyll equivalent for milosvasic.
		homeJSON := filepath.Join(absRoot, site.HomeJSON)
		if langSeg != "" {
			localized := filepath.Join(absRoot, strings.TrimSuffix(site.HomeJSON, ".json")+"."+lang+".json")
			if _, statErr := os.Stat(localized); statErr == nil {
				homeJSON = localized
			} else {
				fmt.Printf("[gen] %s: no localized home data for lang=%s (%s missing) — falling back to EN body\n",
					site.Key, lang, filepath.Base(localized))
			}
		}
		doc, err := loadHome(homeJSON)
		if err != nil {
			fatal(fmt.Errorf("home: %w", err))
		}
		// Pin the doc language to the target lang so the <html lang>/dir, server-side
		// chrome (T(lang)), and switcher paths are localized even on EN fallback.
		if langSeg != "" {
			doc.Lang = lang
		}
		html := renderHome(doc, p, site, langs)
		dest := filepath.Join(out, "index.html")
		if langSeg != "" {
			dest = filepath.Join(out, langSeg, "index.html")
		}
		if err := writeFile(dest, html); err != nil {
			fatal(err)
		}
	}

	// sitemap.xml + robots.txt are rebuilt on EVERY full ("all") build — EN and
	// each localized run alike — by walking the current output tree. This is what
	// gets the ~288 translated product/portfolio pages into the sitemap: they land
	// on disk under products/<lang>/ and portfolio/<lang>/ during localized runs,
	// and whichever full build runs last captures the complete on-disk set. Writing
	// only on the EN run (langSeg == "") stranded the sitemap at EN-only routes when
	// EN was built before the localized pages existed (from-scratch en→ru→sr order).
	// The walk indexes only real files, so every <loc> resolves (no 404s) and langs
	// authored but not yet emitted (e.g. hi/ja/ko) are naturally excluded.
	if what == "all" {
		if err := writeSitemapRobots(site, out); err != nil {
			fatal(fmt.Errorf("sitemap/robots: %w", err))
		}
	}

	fmt.Printf("[gen] site=%s lang=%s what=%s out=%s products=%d\n", site.Key, lang, what, out, nProducts)
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}
