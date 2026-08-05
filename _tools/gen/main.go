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
)

type Site struct {
	Key          string
	Brand        string
	CSSName      string // basename of the deployed brand CSS at <site>/assets/od/<CSSName>.css
	PortfolioCSS string // stylesheet href used by the portfolio page
	HomeJSON     string // path (relative to root) of the homepage content data
	Dir          string // default output dir (relative to root)
}

var sites = map[string]*Site{
	"vasic.digital": {
		Key:          "vasic.digital",
		Brand:        "Vasic Digital",
		CSSName:      "vasic-digital",
		PortfolioCSS: "../../design-system/brand-vasic-digital/vasic-digital.css",
		HomeJSON:     "_content/sites/vasic-digital.home.json",
		Dir:          "vasic.digital",
	},
	"milosvasic.ru": {
		Key:          "milosvasic.ru",
		Brand:        "Miloš Vasić",
		CSSName:      "milosvasic",
		PortfolioCSS: "../../design-system/brand-milosvasic/milosvasic.css",
		HomeJSON:     "_content/sites/milosvasic-ru.home.json",
		Dir:          "milosvasic.ru",
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

	nProducts := 0
	if what == "all" || what == "products" {
		for i := range p.Entries {
			e := &p.Entries[i]
			html, err := renderProduct(absRoot, site, e)
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
		html := renderPortfolio(p, site)
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
		if langSeg != "" {
			fmt.Printf("[gen] %s: skipping homepage for lang=%s (EN-only content data)\n", site.Key, lang)
		} else {
			doc, err := loadHome(filepath.Join(absRoot, site.HomeJSON))
			if err != nil {
				fatal(fmt.Errorf("home: %w", err))
			}
			html := renderHome(doc, p)
			if err := writeFile(filepath.Join(out, "index.html"), html); err != nil {
				fatal(err)
			}
		}
	}

	fmt.Printf("[gen] site=%s lang=%s what=%s out=%s products=%d\n", site.Key, lang, what, out, nProducts)
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}
