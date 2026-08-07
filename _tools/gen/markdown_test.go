package main

import (
	"strings"
	"testing"
)

func TestEscText(t *testing.T) {
	cases := []struct{ in, want string }{
		{"a & b", "a &amp; b"},
		{"<tag>", "&lt;tag&gt;"},
		{"plain", "plain"},
		// escText must NOT escape double quotes (they stay raw in body content).
		{`say "hi"`, `say "hi"`},
		{"a & <b> & c", "a &amp; &lt;b&gt; &amp; c"},
	}
	for _, c := range cases {
		if got := escText(c.in); got != c.want {
			t.Errorf("escText(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestInline(t *testing.T) {
	cases := []struct{ in, want string }{
		{"**bold**", "<strong>bold</strong>"},
		{"a `code` b", "a <code>code</code> b"},
		{"**b** and `c`", "<strong>b</strong> and <code>c</code>"},
		// escaping happens before markdown substitution
		{"**<x>**", "<strong>&lt;x&gt;</strong>"},
		{"a & b", "a &amp; b"},
	}
	for _, c := range cases {
		if got := inline(c.in); got != c.want {
			t.Errorf("inline(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestRenderBody(t *testing.T) {
	body := "# Dropped Title\n" +
		"Intro line one.\n" +
		"line two.\n" +
		"\n" +
		"## Section\n" +
		"- item a\n" +
		"- item b\n" +
		"\n" +
		"Final **para** with `code`."
	got := renderBody(body)

	// The body H1 must be dropped (title comes from frontmatter).
	if strings.Contains(got, "Dropped Title") {
		t.Errorf("renderBody kept body H1; got:\n%s", got)
	}
	want := strings.Join([]string{
		"      <p>Intro line one. line two.</p>",
		"      <h2>Section</h2>",
		"      <ul>",
		"        <li>item a</li>",
		"        <li>item b</li>",
		"      </ul>",
		"      <p>Final <strong>para</strong> with <code>code</code>.</p>",
	}, "\n")
	if got != want {
		t.Errorf("renderBody mismatch.\n got:\n%s\nwant:\n%s", got, want)
	}
}

func TestRenderBodyIndentation(t *testing.T) {
	// Paragraphs indent 6 spaces, list items 8 — matches the reference pages.
	got := renderBody("para\n\n- one")
	for _, line := range strings.Split(got, "\n") {
		switch {
		case strings.Contains(line, "<li>"):
			if !strings.HasPrefix(line, "        <li>") {
				t.Errorf("list item not indented 8 spaces: %q", line)
			}
		case strings.Contains(line, "<p>"):
			if !strings.HasPrefix(line, "      <p>") {
				t.Errorf("paragraph not indented 6 spaces: %q", line)
			}
		}
	}
}

func TestRenderBodyEmpty(t *testing.T) {
	if got := renderBody(""); got != "" {
		t.Errorf("renderBody(\"\") = %q, want empty", got)
	}
}

func TestRenderProductBodyRichEditorial(t *testing.T) {
	body := strings.Join([]string{
		"**A punchy hook line.**",
		"",
		"## Summary",
		"Summary paragraph text.",
		"",
		"## Short description",
		"Short lede text.",
		"",
		"## Long description",
		"Long narrative paragraph one.",
		"",
		"## Why we built it",
		"Because reasons.",
		"",
		"## Status & honesty notes",
		"> Honest note here.",
	}, "\n")
	got := renderProductBody(body, "demo-slug")

	// Labels for summary/short/long must NOT appear as headings.
	for _, banned := range []string{"<h2>Summary</h2>", "Short description", "Long description"} {
		if strings.Contains(got, banned) {
			t.Errorf("renderProductBody leaked boring label %q:\n%s", banned, got)
		}
	}
	// Hook -> tagline, short -> lede, and all body content must be present.
	for _, want := range []string{
		`class="od-product-detail__tagline"`, "A punchy hook line.",
		`class="od-product-detail__lede"`, "Short lede text.",
		"Summary paragraph text.", "Long narrative paragraph one.",
		"Because reasons.", "<blockquote><p>Honest note here.</p></blockquote>",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("renderProductBody dropped/omitted %q:\n%s", want, got)
		}
	}
	// Deeper sections get an editorial (non-verbatim) heading.
	if strings.Contains(got, "<h2>Why we built it</h2>") {
		t.Errorf("expected an editorial heading for 'Why we built it', got verbatim:\n%s", got)
	}
	// Determinism.
	if renderProductBody(body, "demo-slug") != got {
		t.Errorf("renderProductBody not deterministic for same slug")
	}
}

// TestRenderProductBodyAccordion pins the exact class/ARIA contract that
// motion.js (initAccordions) wires up, and the progressive-enhancement
// invariants (open by default, not hidden, content visible without JS).
func TestRenderProductBodyAccordion(t *testing.T) {
	body := strings.Join([]string{
		"**Hook.**",
		"",
		"## Short description",
		"Lede.",
		"",
		"## Why we built it",
		"Because reasons.",
		"",
		"## Tech stack",
		"- Go",
		"- HTML",
	}, "\n")
	got := renderProductBody(body, "demo")

	for _, want := range []string{
		`<div class="od-accordion">`,
		`<div class="od-accordion__item">`,
		`class="od-accordion__trigger" type="button" id="od-acc-demo-0"`,
		`aria-expanded="true"`,
		`aria-controls="od-acc-demo-0-panel"`,
		`<svg class="od-icon od-accordion__icon"`,
		`<div class="od-accordion__panel is-open" id="od-acc-demo-0-panel" role="region" aria-labelledby="od-acc-demo-0">`,
		`<div class="od-accordion__inner">`,
		"Because reasons.",
		"<li>Go</li>",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("accordion markup missing %q:\n%s", want, got)
		}
	}
	// Progressive enhancement: panels must NOT be [hidden] in generated markup.
	if strings.Contains(got, "od-accordion__panel") && strings.Contains(got, "hidden>") {
		t.Errorf("accordion panel ships [hidden]; breaks no-JS/crawler visibility:\n%s", got)
	}
	// The special narrative sections stay OUT of the accordion (tagline/lede/etc).
	if strings.Contains(got, `>Short description<`) {
		t.Errorf("special section leaked into accordion heading:\n%s", got)
	}
}
