package main

import (
	"strings"
	"testing"
)

func TestRepoLabel(t *testing.T) {
	cases := []struct{ in, want string }{
		{"https://github.com/Helix-Track/Core", "Helix-Track/Core"},
		{"http://github.com/foo/bar/", "foo/bar"},
		{"https://gitlab.com/milos85vasic/x", "https://gitlab.com/milos85vasic/x"},
	}
	for _, c := range cases {
		if got := repoLabel(c.in); got != c.want {
			t.Errorf("repoLabel(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestLicHideRe(t *testing.T) {
	hidden := []string{"TBD", "tbd", "UNVERIFIED", "unverified", "UNVERIFIED (varies per module)"}
	for _, l := range hidden {
		if !licHideRe.MatchString(l) {
			t.Errorf("license %q should be hidden", l)
		}
	}
	shown := []string{"MIT", "Apache-2.0", "GPL-3.0"}
	for _, l := range shown {
		if licHideRe.MatchString(l) {
			t.Errorf("license %q should be shown", l)
		}
	}
}

func TestPortfolioCardChipCap(t *testing.T) {
	e := &PortfolioEntry{
		Name:   "Big",
		Slug:   "big",
		Status: "beta",
		Tech:   []string{"a", "b", "c", "d", "e", "f", "g", "h"}, // 8 -> 6 chips + "+2"
	}
	card := portfolioCard(e, false, "en")
	if n := strings.Count(card, "od-chip"); n != 7 { // 6 tech chips + 1 "+N" chip
		t.Errorf("expected 7 chip spans (6 + overflow), got %d\n%s", n, card)
	}
	if !strings.Contains(card, "+2") {
		t.Errorf("expected +2 overflow chip:\n%s", card)
	}
	// Status becomes the badge modifier class verbatim.
	if !strings.Contains(card, "od-badge--status--beta") {
		t.Errorf("status badge class missing:\n%s", card)
	}
	// Read-more points at the product page for the slug.
	if !strings.Contains(card, `href="../products/big.html"`) {
		t.Errorf("read-more href wrong:\n%s", card)
	}
}

func TestPortfolioCardHidesTBDLicense(t *testing.T) {
	tbd := &PortfolioEntry{Name: "T", Slug: "t", Status: "active", License: "TBD", Tech: []string{"Go"}}
	if strings.Contains(portfolioCard(tbd, false, "en"), "od-tag--license") {
		t.Errorf("TBD license tag must not render on card")
	}
	mit := &PortfolioEntry{Name: "M", Slug: "m", Status: "active", License: "MIT", Tech: []string{"Go"}}
	if !strings.Contains(portfolioCard(mit, false, "en"), "MIT") {
		t.Errorf("MIT license tag must render on card")
	}
}
