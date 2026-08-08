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
