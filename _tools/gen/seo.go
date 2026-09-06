package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ---- Design-system asset wiring -------------------------------------------------

// assetLinks returns the ordered stylesheet <link>s a page must carry, resolved
// from the deployed site root via `prefix` ("" for the site root index, "../"
// for /products/*.html and /portfolio/). Order matters: fonts.css defines the
// @font-face families BEFORE the brand CSS references them, then the extended
// component library, then motion, then overlay blur.
func assetLinks(prefix, cssName string) string {
	p := prefix + "assets/od/"
	return strings.Join([]string{
		`<link rel="stylesheet" href="` + p + `fonts.css"/>`,
		`<link rel="stylesheet" href="` + p + cssName + `.css"/>`,
		`<link rel="stylesheet" href="` + p + `components-extended.css"/>`,
		`<link rel="stylesheet" href="` + p + `animations.css"/>`,
		`<link rel="stylesheet" href="` + p + `overlays.css"/>`,
	}, "\n")
}

// motionScript is the deferred motion controller (scroll-reveal, overlays, etc.).
func motionScript(prefix string) string {
	return `<script defer src="` + prefix + `assets/od/motion.js"></script>`
}

// ---- Languages present on disk (drives hreflang) --------------------------------

// availableLangs reads _content_<xx> directories at gen time and returns the set
// of language codes that have authored content, always including "en" first.
// _*_proof scratch dirs are ignored. The set grows automatically as translation
// batches land new _content_<lang> directories.
func availableLangs(root string) []string {
	langs := []string{"en"}
	entries, err := os.ReadDir(root)
	if err != nil {
		return langs
	}
	seen := map[string]bool{"en": true}
	var extra []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.HasPrefix(name, "_content_") {
			continue
		}
		code := strings.TrimPrefix(name, "_content_")
		if strings.Contains(code, "_") { // e.g. de_proof
			continue
		}
		if code == "" || seen[code] {
			continue
		}
		seen[code] = true
		extra = append(extra, code)
	}
	sort.Strings(extra)
	return append(langs, extra...)
}

// langPath maps an EN root-relative path (e.g. "products/x.html", "portfolio/",
// "") to its localized variant for `lang`. EN is the canonical (unprefixed) path.
func langPath(lang, enPath string) string {
	if lang == "" || lang == "en" { // "" is the EN default (pageSEO.lang) — treat as EN
		return enPath
	}
	switch {
	case enPath == "":
		return lang + "/"
	case strings.HasPrefix(enPath, "products/"):
		return "products/" + lang + "/" + strings.TrimPrefix(enPath, "products/")
	case enPath == "portfolio/":
		return "portfolio/" + lang + "/"
	default:
		return lang + "/" + enPath
	}
}

// hreflangLinks emits reciprocal <link rel="alternate" hreflang> tags across all
// languages that exist on disk, plus x-default (EN). Every page emits the full
// matrix, so the set is reciprocal by construction.
func hreflangLinks(site *Site, langs []string, enPath string) string {
	var b strings.Builder
	for _, l := range langs {
		u := site.URL(langPath(l, enPath))
		fmt.Fprintf(&b, `<link rel="alternate" hreflang="%s" href="%s"/>`+"\n", l, u)
	}
	fmt.Fprintf(&b, `<link rel="alternate" hreflang="x-default" href="%s"/>`, site.URL(enPath))
	return b.String()
}

// Localized homes are now generated (main.go emits /<lang>/index.html for every
// language with authored home data), so the home carries the SAME reciprocal
// hreflang matrix as the product/portfolio pages: the full `langs` set + x-default
// → EN root. Every alternate resolves (no 404s) because the localized home exists
// on disk under /<lang>/ before the sitemap/hreflang are written.

// hreflangInline returns the reciprocal hreflang matrix as a single line (no
// newlines), suitable for embedding as a Jekyll front-matter scalar that the
// shared layout emits verbatim into <head>. jekyll-seo-tag owns the rest of the
// head; hreflang is the one signal it does not emit, so the Go generator supplies
// it here (matching the self-contained pages' seoHead output).
func hreflangInline(site *Site, langs []string, enPath string) string {
	return strings.ReplaceAll(hreflangLinks(site, langs, enPath), "\n", "")
}

// ---- Per-page SEO head ----------------------------------------------------------

type pageSEO struct {
	title    string // full <title>
	desc     string // meta description
	keywords string // meta keywords (per-language); empty omits the tag
	lang     string // page language (drives og:locale, html lang); "" => en
	enPath   string // EN root-relative path ("products/x.html", "portfolio/", "")
	ogType   string // "website" | "article"
	jsonLD   string // pre-rendered <script type=application/ld+json>
	prefix   string // asset/link prefix ("" or "../")
	cssName  string
}

// seoHead renders the full data-driven SEO head: title, description, canonical,
// robots, Open Graph, Twitter Card, reciprocal hreflang, and the JSON-LD graph.
func seoHead(site *Site, langs []string, s pageSEO) string {
	// Self-referential canonical + og:url: a localized page points at its OWN
	// localized URL, not the EN one (langPath returns enPath unchanged for en/"").
	// Cross-language canonicals contradict the hreflang cluster and risk the
	// localized URLs being dropped from search indexes (D-SEO-1).
	canon := site.URL(langPath(s.lang, s.enPath))
	lang := htmlLang(s.lang)
	var b strings.Builder
	fmt.Fprintf(&b, "<title>%s</title>\n", esc(s.title))
	fmt.Fprintf(&b, `<meta name="description" content="%s"/>`+"\n", esc(s.desc))
	if s.keywords != "" {
		fmt.Fprintf(&b, `<meta name="keywords" content="%s"/>`+"\n", esc(s.keywords))
	}
	fmt.Fprintf(&b, `<link rel="canonical" href="%s"/>`+"\n", canon)
	if site.Favicon != "" {
		ft := "image/png"
		if strings.HasSuffix(site.Favicon, ".svg") {
			ft = "image/svg+xml"
		}
		fmt.Fprintf(&b, `<link rel="icon" type="%s" href="%s"/>`+"\n", ft, site.URL(site.Favicon))
		touch := site.TouchIcon
		if touch == "" {
			touch = site.OGImage
		}
		fmt.Fprintf(&b, `<link rel="apple-touch-icon" href="%s"/>`+"\n", site.URL(touch))
	}
	b.WriteString(`<meta name="robots" content="index, follow, max-image-preview:large"/>` + "\n")
	// Open Graph
	fmt.Fprintf(&b, `<meta property="og:type" content="%s"/>`+"\n", s.ogType)
	fmt.Fprintf(&b, `<meta property="og:site_name" content="%s"/>`+"\n", esc(site.Brand))
	fmt.Fprintf(&b, `<meta property="og:title" content="%s"/>`+"\n", esc(s.title))
	fmt.Fprintf(&b, `<meta property="og:description" content="%s"/>`+"\n", esc(s.desc))
	fmt.Fprintf(&b, `<meta property="og:url" content="%s"/>`+"\n", canon)
	fmt.Fprintf(&b, `<meta property="og:image" content="%s"/>`+"\n", site.URL(site.OGImage))
	fmt.Fprintf(&b, `<meta property="og:locale" content="%s"/>`+"\n", ogLocale(lang))
	// Twitter Card
	b.WriteString(`<meta name="twitter:card" content="summary_large_image"/>` + "\n")
	fmt.Fprintf(&b, `<meta name="twitter:title" content="%s"/>`+"\n", esc(s.title))
	fmt.Fprintf(&b, `<meta name="twitter:description" content="%s"/>`+"\n", esc(s.desc))
	fmt.Fprintf(&b, `<meta name="twitter:image" content="%s"/>`+"\n", site.URL(site.OGImage))
	// hreflang matrix
	b.WriteString(hreflangLinks(site, langs, s.enPath) + "\n")
	// JSON-LD graph
	b.WriteString(s.jsonLD)
	return b.String()
}

// ---- JSON-LD graph --------------------------------------------------------------

func jsonLDScript(v interface{}) string {
	// json.Marshal HTML-escapes <, >, & (safe to embed inside <script>).
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return ""
	}
	return `<script type="application/ld+json">` + "\n" + string(b) + "\n</script>"
}

// identityNode is the Organization (vasic.digital) or Person (milosvasic) node.
func (site *Site) identityNode() map[string]interface{} {
	id := site.URL("") + "#identity"
	node := map[string]interface{}{
		"@type": site.LDKind,
		"@id":   id,
		"name":  site.Brand,
		"url":   site.URL(""),
	}
	if site.LDKind == "Organization" {
		node["logo"] = site.URL(site.OGImage)
	} else {
		node["image"] = site.URL(site.OGImage)
	}
	if len(site.SameAs) > 0 {
		node["sameAs"] = site.SameAs
	}
	return node
}

func (site *Site) websiteNode(lang string) map[string]interface{} {
	return map[string]interface{}{
		"@type":      "WebSite",
		"@id":        site.URL("") + "#website",
		"name":       site.Brand,
		"url":        site.URL(""),
		"inLanguage": htmlLang(lang),
		"publisher":  map[string]string{"@id": site.URL("") + "#identity"},
	}
}

// baseGraph is the identity + website graph shared by every page (EN inLanguage).
// baseGraphLang is the language-aware variant used by localized pages.
func (site *Site) baseGraph(extra ...map[string]interface{}) string {
	return site.baseGraphLang("en", extra...)
}

// baseGraphLang sets the WebSite node's inLanguage so each localized page
// advertises its own language in JSON-LD.
func (site *Site) baseGraphLang(lang string, extra ...map[string]interface{}) string {
	graph := []interface{}{site.identityNode(), site.websiteNode(lang)}
	for _, e := range extra {
		graph = append(graph, e)
	}
	return jsonLDScript(map[string]interface{}{
		"@context": "https://schema.org",
		"@graph":   graph,
	})
}

// softwareApplicationNode describes a product as a schema.org SoftwareApplication
// (EN inLanguage). softwareApplicationNodeLang is the language-aware variant.
func (site *Site) softwareApplicationNode(e *PortfolioEntry) map[string]interface{} {
	return site.softwareApplicationNodeLang(e, "en", "")
}

// softwareApplicationNodeLang builds the JSON-LD SoftwareApplication node. desc
// is the already-localized description resolved by the caller; when empty it
// falls back to the EN portfolio.json summary/tagline (used by the "en" path).
func (site *Site) softwareApplicationNodeLang(e *PortfolioEntry, lang string, desc string) map[string]interface{} {
	url := site.URL("products/" + e.Slug + ".html")
	if desc == "" {
		desc = e.Summary
		if desc == "" {
			desc = e.Tagline
		}
	}
	node := map[string]interface{}{
		"@type":               "SoftwareApplication",
		"@id":                 url + "#app",
		"name":                e.Name,
		"url":                 url,
		"applicationCategory": "DeveloperApplication",
		"operatingSystem":     "Cross-platform",
		"inLanguage":          htmlLang(lang),
		"description":         desc,
		"author":              map[string]string{"@id": site.URL("") + "#identity"},
	}
	if e.License != "" && !licHideRe.MatchString(e.License) {
		node["license"] = e.License
	}
	return node
}

// ---- sitemap.xml + robots.txt ---------------------------------------------------

// writeSitemapRobots walks the generated site output for .html files and writes a
// well-formed sitemap.xml (every URL maps to a real file, so all resolve) plus a
// robots.txt that points crawlers at it. The walk descends into the per-language
// output dirs (products/<lang>/, portfolio/<lang>/), so localized pages are indexed
// alongside the canonical EN routes; only languages whose HTML actually exists on
// disk are listed, so no <loc> 404s. Called on every full build (see main), so the
// last localized run refreshes the sitemap with the complete multilingual set.
func writeSitemapRobots(site *Site, out string) error {
	type smURL struct{ loc, mod string }
	var urls []smURL
	err := filepath.Walk(out, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			base := info.Name()
			// Skip assets, dot/underscore dirs, the Jekyll build output, and the
			// `articles/` tree (those .html are page fragments, not standalone
			// indexable pages).
			//
			// THE EXCLUSION IS CORRECT AND MUST STAY. Measured 2026-09-06 over
			// all 270 fragments in vasic.digital: NONE carries a <!DOCTYPE>,
			// <html>, <title> or a canonical link. A sitemap row pointing at one
			// would put a title-less, chrome-less document into a search index —
			// the exclusion is what prevents a real SEO defect, not a nicety.
			//
			// THE REASON THIS COMMENT USED TO GIVE IS WITHDRAWN AS MEASURED
			// FALSE. It read "they are injected into product/portfolio pages".
			// Nothing injects them. In vasic.digital, `git grep` for `articles`
			// outside articles/ and _article_src/ returns ZERO lines; there are
			// zero data-src attributes in any of the 795 pages, and no JS
			// mentions articles or read-more. The mechanism is in the history,
			// not a mystery: 697ed42 (2026-06-25) added js/articles.js, whose
			// fetch path was document-relative ("articles/"+lang+"/"+slug) and
			// so would have 404'd from every page except "/", and 5a4c3bb
			// (2026-08-10) replaced the whole js/+css/ tree with assets/od/,
			// deleting that loader. It was never re-implemented. The fragments
			// also style themselves with .hx-* rules that no longer exist in any
			// served stylesheet, so they could not render even if reached.
			//
			// The 270 fragments are still SERVED — https://vasic.digital/articles/
			// en/asinka.html returns 200 — so a direct visitor gets unstyled
			// quirks-mode text. Whether to re-wire a loader (root-relative this
			// time) or delete articles/ and _article_src/ is an operator
			// decision about content and is deliberately not made here.
			//
			// milosvasic.ru carries the same defect one stage earlier: its
			// loader survives and is still document-relative, so it would 404 on
			// 524 of its 525 pages if any page still emitted a trigger. None does.
			if base == "assets" || base == "articles" || base == "_site" ||
				strings.HasPrefix(base, ".") || strings.HasPrefix(base, "_") {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(info.Name(), ".html") {
			return nil
		}
		if strings.HasSuffix(info.Name(), ".legacy.html") {
			return nil
		}
		rel, err := filepath.Rel(out, path)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		// Pretty-URL the index files.
		switch {
		case rel == "index.html":
			rel = ""
		case strings.HasSuffix(rel, "/index.html"):
			rel = strings.TrimSuffix(rel, "index.html")
		}
		// <lastmod> = generation date of the file (day granularity keeps churn low
		// while honestly reflecting the last content refresh).
		urls = append(urls, smURL{site.URL(rel), info.ModTime().UTC().Format("2006-01-02")})
		return nil
	})
	if err != nil {
		return err
	}
	sort.Slice(urls, func(i, j int) bool { return urls[i].loc < urls[j].loc })

	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8"?>` + "\n")
	b.WriteString(`<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` + "\n")
	for _, u := range urls {
		fmt.Fprintf(&b, "  <url><loc>%s</loc><lastmod>%s</lastmod></url>\n", esc(u.loc), u.mod)
	}
	b.WriteString(`</urlset>` + "\n")
	if err := writeFile(filepath.Join(out, "sitemap.xml"), b.String()); err != nil {
		return err
	}

	robots := "User-agent: *\nAllow: /\n\nSitemap: " + site.URL("sitemap.xml") + "\n"
	return writeFile(filepath.Join(out, "robots.txt"), robots)
}
