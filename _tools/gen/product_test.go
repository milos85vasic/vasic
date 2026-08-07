package main

import (
	"strings"
	"testing"
)

func TestFirstNonEmpty(t *testing.T) {
	if got := firstNonEmpty("", "  ", "x", "y"); got != "x" {
		t.Errorf("firstNonEmpty = %q, want x", got)
	}
	if got := firstNonEmpty("", "   "); got != "" {
		t.Errorf("firstNonEmpty all-blank = %q, want empty", got)
	}
	if got := firstNonEmpty("first", "second"); got != "first" {
		t.Errorf("firstNonEmpty = %q, want first", got)
	}
}

func TestXMLDeclStripped(t *testing.T) {
	in := `<?xml version="1.0" encoding="UTF-8"?>` + "\n<svg></svg>"
	got := xmlDeclRe.ReplaceAllString(in, "")
	if strings.Contains(got, "<?xml") {
		t.Errorf("xml decl not stripped: %q", got)
	}
	if !strings.HasPrefix(got, "<svg>") {
		t.Errorf("expected leading <svg>, got %q", got)
	}
}

func TestProductHref(t *testing.T) {
	standalone := &HomeDoc{Kind: "standalone"}
	if got := productHref(standalone, "helixtrack"); got != "products/helixtrack.html" {
		t.Errorf("standalone href = %q", got)
	}
	jekyll := &HomeDoc{Kind: "jekyll"}
	got := productHref(jekyll, "helixtrack")
	if !strings.Contains(got, "relative_url") || !strings.Contains(got, "/products/helixtrack.html") {
		t.Errorf("jekyll href must use relative_url filter, got %q", got)
	}
}

func TestI18nAttr(t *testing.T) {
	if got := i18nAttr(I18nText{I18n: "nav.work"}); got != ` data-i18n="nav.work"` {
		t.Errorf("i18nAttr = %q", got)
	}
	if got := i18nAttr(I18nText{}); got != "" {
		t.Errorf("i18nAttr empty = %q, want empty", got)
	}
}
