package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode/utf8"
)

// writeFeeds emits Atom (RFC 4287) feeds for a Jekyll site's product pages:
//
//	<out>/feed.xml          the English pages   (products/<slug>.html)
//	<out>/<lang>/feed.xml   one per language    (products/<lang>/<slug>.html)
//
// WHY THIS EXISTS. milosvasic.ru shipped a VALID BUT EMPTY /feed.xml: jekyll-feed
// lists Jekyll _posts, the site has none, and nothing linked to it (live audit
// 2026-09-24). The operator chose to build a real feed. The entries are the
// site's product pages — real, styled, canonical pages that are already in the
// sitemap — and deliberately NOT the articles/<lang>/*.html fragments: those
// carry no <html>, <title> or canonical link (see writeSitemapRobots), so a feed
// entry pointing at one would publish exactly the chrome-less document the
// sitemap excludes on purpose.
//
// A feed is written ONLY when it has entries — an empty feed is the defect this
// replaces. Only Jekyll sites (front-matter pages carrying title/description) get
// one; vasic.digital's self-contained pages are not touched.
//
// DETERMINISM. <updated> is the source page's own date at day granularity (the
// same rule as the sitemap's <lastmod>), never the time of the feed write, so two
// generations on the same day are byte-identical and the feed files' own mtimes
// cannot leak into their content. Entries are sorted by id.
func writeFeeds(site *Site, out string) error {
	if !site.Jekyll {
		return nil
	}
	pdir := filepath.Join(out, "products")
	entries, err := os.ReadDir(pdir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	// English = the files directly under products/; every subdirectory is a language.
	if err := writeOneFeed(site, out, "en", "feed.xml", "", pdir, "products/"); err != nil {
		return err
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		lang := e.Name()
		if err := writeOneFeed(site, out, lang, filepath.Join(lang, "feed.xml"), lang+"/",
			filepath.Join(pdir, lang), "products/"+lang+"/"); err != nil {
			return err
		}
	}
	return nil
}

type feedEntry struct {
	id, title, summary string
	updated            time.Time
}

func writeOneFeed(site *Site, out, lang, feedRel, urlDir, dir, urlPrefix string) error {
	files, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	var es []feedEntry
	for _, f := range files {
		name := f.Name()
		if f.IsDir() || !strings.HasSuffix(name, ".html") || strings.HasSuffix(name, ".legacy.html") {
			continue
		}
		raw, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return err
		}
		info, err := f.Info()
		if err != nil {
			return err
		}
		title, desc := frontMatterTitleDesc(string(raw))
		if title == "" {
			continue // not a titled page: never invent an entry title
		}
		d := info.ModTime().UTC()
		es = append(es, feedEntry{
			id:      site.URL(urlPrefix + name),
			title:   title,
			summary: desc,
			updated: time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.UTC),
		})
	}
	feedPath := filepath.Join(out, feedRel)
	if len(es) == 0 {
		// Never leave (or write) an empty feed; drop one a previous run wrote.
		_ = os.Remove(feedPath)
		return nil
	}
	sort.Slice(es, func(i, j int) bool { return es[i].id < es[j].id })
	newest := es[0].updated
	for _, e := range es {
		if e.updated.After(newest) {
			newest = e.updated
		}
	}
	selfURL := site.URL(feedRel)
	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="utf-8"?>` + "\n")
	fmt.Fprintf(&b, `<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="%s">`+"\n", esc(lang))
	fmt.Fprintf(&b, "  <id>%s</id>\n", xmlText(selfURL))
	fmt.Fprintf(&b, "  <title>%s</title>\n", xmlText(site.Brand))
	fmt.Fprintf(&b, "  <updated>%s</updated>\n", newest.Format("2006-01-02T15:04:05Z"))
	fmt.Fprintf(&b, "  <author><name>%s</name></author>\n", xmlText(site.Brand))
	fmt.Fprintf(&b, `  <link rel="self" type="application/atom+xml" href="%s"/>`+"\n", xmlAttr(selfURL))
	fmt.Fprintf(&b, `  <link rel="alternate" type="text/html" href="%s"/>`+"\n", xmlAttr(site.URL(urlDir)))
	for _, e := range es {
		b.WriteString("  <entry>\n")
		fmt.Fprintf(&b, "    <id>%s</id>\n", xmlText(e.id))
		fmt.Fprintf(&b, "    <title>%s</title>\n", xmlText(e.title))
		fmt.Fprintf(&b, `    <link rel="alternate" type="text/html" href="%s"/>`+"\n", xmlAttr(e.id))
		fmt.Fprintf(&b, "    <updated>%s</updated>\n", e.updated.Format("2006-01-02T15:04:05Z"))
		if e.summary != "" {
			fmt.Fprintf(&b, "    <summary>%s</summary>\n", xmlText(e.summary))
		}
		b.WriteString("  </entry>\n")
	}
	b.WriteString("</feed>\n")
	return writeFile(feedPath, b.String())
}

// frontMatterTitleDesc reads title/description from a Jekyll page's front matter
// (values are the double-quoted scalars yamlQuote writes).
func frontMatterTitleDesc(page string) (title, desc string) {
	if !strings.HasPrefix(page, "---\n") {
		return "", ""
	}
	end := strings.Index(page[4:], "\n---")
	if end < 0 {
		return "", ""
	}
	for _, ln := range strings.Split(page[4:4+end], "\n") {
		switch {
		case strings.HasPrefix(ln, "title:"):
			title = yamlUnquote(strings.TrimSpace(strings.TrimPrefix(ln, "title:")))
		case strings.HasPrefix(ln, "description:"):
			desc = yamlUnquote(strings.TrimSpace(strings.TrimPrefix(ln, "description:")))
		}
	}
	return strings.TrimSpace(title), strings.TrimSpace(desc)
}

// yamlUnquote inverts yamlQuote (\\ and \" only).
func yamlUnquote(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		s = s[1 : len(s)-1]
		return strings.NewReplacer(`\"`, `"`, `\\`, `\`).Replace(s)
	}
	return s
}

// xmlClean drops every rune XML 1.0 forbids (control characters other than tab,
// LF, CR; lone surrogates; U+FFFE/U+FFFF) — they can never be represented, even
// escaped, and one of them makes the whole feed unparseable.
func xmlClean(s string) string {
	if !utf8.ValidString(s) {
		s = strings.ToValidUTF8(s, "")
	}
	return strings.Map(func(r rune) rune {
		switch {
		case r == 0x9 || r == 0xA || r == 0xD:
			return r
		case r >= 0x20 && r <= 0xD7FF, r >= 0xE000 && r <= 0xFFFD, r >= 0x10000 && r <= 0x10FFFF:
			return r
		}
		return -1
	}, s)
}

func xmlText(s string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;").Replace(xmlClean(s))
}

func xmlAttr(s string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;").Replace(xmlClean(s))
}
