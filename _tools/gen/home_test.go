package main

import "testing"

// Regression for the localized-home broken-link bug: on the self-contained
// (vasic.digital) build, home CTA hrefs like "portfolio/" and
// "downloads/Portfolio_EN.pdf" are page-relative, so from a localized home at
// /<lang>/index.html they resolved to /<lang>/portfolio/ and
// /<lang>/downloads/... → 404. homeCTAHref must apply the depth hop and localize
// the well-known targets, while leaving EN (root) output byte-identical and never
// touching fragments, absolute, protocol, or Jekyll hrefs.
func TestHomeCTAHref(t *testing.T) {
	standalone := func(lang string) *HomeDoc { return &HomeDoc{Kind: "standalone", Lang: lang} }
	jekyll := func(lang string) *HomeDoc { return &HomeDoc{Kind: "jekyll", Lang: lang} }

	cases := []struct {
		name string
		doc  *HomeDoc
		in   string
		want string
	}{
		// EN home sits at the site root → unchanged (byte-identical output).
		{"en portfolio unchanged", standalone("en"), "portfolio/", "portfolio/"},
		{"en pdf unchanged", standalone("en"), "downloads/Portfolio_EN.pdf", "downloads/Portfolio_EN.pdf"},
		{"en empty-lang unchanged", standalone(""), "portfolio/", "portfolio/"},

		// Localized homes live one dir deep → must hop up AND localize the target.
		{"sr portfolio localized", standalone("sr"), "portfolio/", "../portfolio/sr/"},
		{"de portfolio localized", standalone("de"), "portfolio/", "../portfolio/de/"},
		{"sr portfolio pdf localized", standalone("sr"), "downloads/Portfolio_EN.pdf", "../downloads/Portfolio_SR.pdf"},
		{"ar portfolio pdf localized", standalone("ar"), "downloads/Portfolio_EN.pdf", "../downloads/Portfolio_AR.pdf"},
		{"hi generic relative gets depth hop", standalone("hi"), "some/page.html", "../some/page.html"},

		// Never rewrite fragments, absolute, protocol, or Jekyll hrefs.
		{"fragment untouched", standalone("sr"), "#products", "#products"},
		{"root-absolute untouched", standalone("sr"), "/portfolio/", "/portfolio/"},
		{"external untouched", standalone("sr"), "https://github.com/x", "https://github.com/x"},
		{"mailto untouched", standalone("sr"), "mailto:i@mvasic.ru", "mailto:i@mvasic.ru"},
		{"jekyll untouched", jekyll("sr"), "{{ '/portfolio/' | relative_url }}", "{{ '/portfolio/' | relative_url }}"},
		{"empty untouched", standalone("sr"), "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := homeCTAHref(c.doc, c.in); got != c.want {
				t.Errorf("homeCTAHref(%q, %q) = %q; want %q", c.doc.Lang, c.in, got, c.want)
			}
		})
	}
}

// homeHTMLHrefs must apply the same depth-hop/localization to EVERY internal
// relative href/src inside a rendered HTML blob (contact/blurb HTML that bypasses
// the single-href CTA path), while leaving EN root, absolute, fragment, protocol,
// and Jekyll hrefs byte-identical — so current (all-absolute) data never changes.
func TestHomeHTMLHrefs(t *testing.T) {
	std := func(lang string) *HomeDoc { return &HomeDoc{Kind: "standalone", Lang: lang} }
	cases := []struct {
		name     string
		doc      *HomeDoc
		in, want string
	}{
		{"en unchanged (root)", std("en"),
			`<a href="portfolio/">P</a>`, `<a href="portfolio/">P</a>`},
		{"sr relative portfolio hopped+localized", std("sr"),
			`<a href="portfolio/">P</a>`, `<a href="../portfolio/sr/">P</a>`},
		{"sr relative pdf localized", std("sr"),
			`<a href="downloads/Portfolio_EN.pdf">CV</a>`, `<a href="../downloads/Portfolio_SR.pdf">CV</a>`},
		{"sr generic relative src hopped", std("sr"),
			`<img src="img/x.png">`, `<img src="../img/x.png">`},
		{"absolute/mailto/fragment/root untouched", std("sr"),
			`<a href="https://x/">a</a><a href="mailto:i@x">b</a><a href="#c">d</a><a href="/abs/">e</a>`,
			`<a href="https://x/">a</a><a href="mailto:i@x">b</a><a href="#c">d</a><a href="/abs/">e</a>`},
		{"jekyll untouched", &HomeDoc{Kind: "jekyll", Lang: "sr"},
			`<a href="portfolio/">P</a>`, `<a href="portfolio/">P</a>`},
		{"empty", std("sr"), "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := homeHTMLHrefs(c.doc, c.in); got != c.want {
				t.Errorf("homeHTMLHrefs(%q, %q)\n got=%q\nwant=%q", c.doc.Lang, c.in, got, c.want)
			}
		})
	}
}
