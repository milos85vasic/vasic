package main

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
)

// Portfolio is the single source of truth for product metadata, shared by both sites.
type Portfolio struct {
	Schema   string           `json:"schema"`
	Count    int              `json:"count"`
	Tiers    []string         `json:"tiers"`
	Excluded []string         `json:"excluded"`
	Entries  []PortfolioEntry `json:"entries"`
}

type PortfolioEntry struct {
	Name    string   `json:"name"`
	Slug    string   `json:"slug"`
	Tier    string   `json:"tier"`
	Order   int      `json:"order"`
	Status  string   `json:"status"`
	License string   `json:"license"`
	Private bool     `json:"private"`
	Tech    []string `json:"tech"`
	Repos   []string `json:"repos"`
	Summary string   `json:"summary"`
	Tagline string   `json:"tagline"`
	Source  string   `json:"source"`
}

func loadPortfolio(path string) (*Portfolio, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var p Portfolio
	if err := json.Unmarshal(b, &p); err != nil {
		return nil, err
	}
	return &p, nil
}

func (p *Portfolio) bySlug(slug string) *PortfolioEntry {
	for i := range p.Entries {
		if p.Entries[i].Slug == slug {
			return &p.Entries[i]
		}
	}
	return nil
}

// esc escapes text for safe HTML output (matches the reference renderer: & < > ").
func esc(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", "\"", "&quot;")
	return r.Replace(s)
}

// yamlQuote returns s as a YAML double-quoted scalar, safe for use as a Jekyll
// front-matter value (title/description). Backslashes and double quotes are
// escaped per the YAML double-quoted flow-scalar rules.
func yamlQuote(s string) string {
	return `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(s) + `"`
}

var fmRe = regexp.MustCompile(`(?s)^---\n(.*?)\n---\n(.*)$`)

// frontmatter is the minimal YAML subset used by product .md files
// (scalars + simple string lists), matching _tools/portfolio/generate.mjs.
type frontmatter struct {
	scalars map[string]string
	lists   map[string][]string
}

func parseFrontmatter(md string) (frontmatter, string, error) {
	m := fmRe.FindStringSubmatch(md)
	if m == nil {
		return frontmatter{}, "", fmt.Errorf("no frontmatter")
	}
	fm := frontmatter{scalars: map[string]string{}, lists: map[string][]string{}}
	var listKey string
	kvRe := regexp.MustCompile(`^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$`)
	itemRe := regexp.MustCompile(`^\s+-\s+(.*)$`)
	for _, line := range strings.Split(m[1], "\n") {
		if it := itemRe.FindStringSubmatch(line); it != nil && listKey != "" {
			fm.lists[listKey] = append(fm.lists[listKey], strings.TrimSpace(it[1]))
			continue
		}
		kv := kvRe.FindStringSubmatch(line)
		if kv == nil {
			continue
		}
		key, val := kv[1], kv[2]
		if val == "" {
			fm.lists[key] = []string{}
			listKey = key
		} else {
			fm.scalars[key] = val
			listKey = ""
		}
	}
	return fm, m[2], nil
}

// ---- Homepage content model (per-site, authored under _content/sites/*.home.json) ----

type HomeDoc struct {
	Site   string      `json:"site"`
	Kind   string      `json:"kind"` // "standalone" (vasic) or "jekyll" (milosvasic)
	Brand  string      `json:"brand"`
	Lang   string      `json:"lang"`
	Title  string      `json:"title"`
	Desc   string      `json:"description"`
	CSS    string      `json:"css"`    // stylesheet href
	Footer string      `json:"footer"` // standalone only
	Blocks []HomeBlock `json:"blocks"`
}

type HomeBlock struct {
	Type     string    `json:"type"` // hero | section | contact
	ID       string    `json:"id"`
	Eyebrow  I18nText  `json:"eyebrow"` // hero, or section-level header
	Title    I18nText  `json:"title"`
	Lede     I18nText  `json:"lede"`
	CTAs     []CTA     `json:"ctas"`     // hero CTAs, or section trailing CTA row
	CTAWrap  string    `json:"ctaWrap"`  // class for trailing CTA row (default {prefix}-hero__cta)
	CTAStyle string    `json:"ctaStyle"` // inline style for trailing CTA row
	Stats    []Stat    `json:"stats"`    // hero
	Groups   []Group   `json:"groups"`   // section
	Contacts []Contact `json:"contacts"` // contact
}

// Group is a sub-block of a section: a prose run, a card grid, or a tech grid.
type Group struct {
	Eyebrow   I18nText   `json:"eyebrow"`
	Title     I18nText   `json:"title"`
	Lede      I18nText   `json:"lede"`
	MarginTop bool       `json:"marginTop"` // eyebrow gets margin-top:var(--od-space-10)
	Kind      string     `json:"kind"`      // prose | cards | tech
	Grid      string     `json:"grid"`      // grid class for cards/tech
	Paras     []I18nText `json:"paras"`     // prose
	Cards     []Card     `json:"cards"`     // cards/tech
}

// I18nText carries the visible (English) text plus its data-i18n key and an optional class.
type I18nText struct {
	I18n  string `json:"i18n"`
	Text  string `json:"text"`
	Class string `json:"class"`
	HTML  bool   `json:"html"` // Text is trusted HTML (already escaped)
}

type CTA struct {
	I18n    string `json:"i18n"`
	Label   string `json:"label"`
	Href    string `json:"href"`    // relative_url-wrapped where needed
	Variant string `json:"variant"` // primary | secondary | ghost
	DL      string `json:"dl"`      // data-dl value (milosvasic hero buttons); if set, renders <button>
	Icon    string `json:"icon"`    // icon symbol id (e.g. i-download)
}

type Stat struct {
	I18n  string `json:"i18n"`
	Value string `json:"value"`
	Label string `json:"label"`
}

type Card struct {
	Slug     string   `json:"slug"`     // product cards: identity + status lookup + href
	Name     string   `json:"name"`     // display title
	NameI18n string   `json:"nameI18n"` // data-i18n on the title (tiles / tech cards)
	Status   string   `json:"status"`   // override; if empty and slug set, pulled from portfolio
	NoBadge  bool     `json:"noBadge"`  // suppress status badge even if slug set
	Tech     []string `json:"tech"`     // curated chips (verbatim, no +N)
	Blurb    I18nText `json:"blurb"`
	Readmore I18nText `json:"readmore"` // read-more link label + i18n; href derived from slug
}

type Contact struct {
	I18n  string `json:"i18n"`
	Label string `json:"label"`
	HTML  string `json:"html"` // trusted inner HTML for the value line
}

func loadHome(path string) (*HomeDoc, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var h HomeDoc
	if err := json.Unmarshal(b, &h); err != nil {
		return nil, err
	}
	return &h, nil
}
