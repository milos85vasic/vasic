package main

import (
	"regexp"
	"strings"
)

var (
	boldRe = regexp.MustCompile(`\*\*(.+?)\*\*`)
	codeRe = regexp.MustCompile("`([^`]+)`")
)

// escText escapes body text for HTML content (quotes stay raw, as in the
// reference product pages).
func escText(s string) string {
	r := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;")
	return r.Replace(s)
}

// inline renders the minimal inline markdown subset (bold, code) on body text.
func inline(s string) string {
	s = escText(s)
	s = boldRe.ReplaceAllString(s, "<strong>$1</strong>")
	s = codeRe.ReplaceAllString(s, "<code>$1</code>")
	return s
}

// renderBody converts a product .md body into the product-page inner HTML,
// matching the validated pages: leading "# Title" dropped; "## X" -> <h2>;
// "- " runs -> <ul>; blank-separated paragraphs -> <p>. Blocks are indented
// with six spaces (list items eight) to match the reference output.
func renderBody(body string) string {
	lines := strings.Split(body, "\n")
	var out []string
	var para []string
	var list []string

	flushPara := func() {
		if len(para) == 0 {
			return
		}
		out = append(out, "      <p>"+inline(strings.Join(para, " "))+"</p>")
		para = nil
	}
	flushList := func() {
		if len(list) == 0 {
			return
		}
		out = append(out, "      <ul>")
		for _, it := range list {
			out = append(out, "        <li>"+inline(it)+"</li>")
		}
		out = append(out, "      </ul>")
		list = nil
	}
	flush := func() { flushPara(); flushList() }

	for _, raw := range lines {
		line := strings.TrimRight(raw, " ")
		t := strings.TrimSpace(line)
		switch {
		case t == "":
			flush()
		case strings.HasPrefix(t, "## "):
			flush()
			out = append(out, "      <h2>"+inline(strings.TrimSpace(t[3:]))+"</h2>")
		case strings.HasPrefix(t, "# "):
			flush() // page title comes from frontmatter name; drop body H1
		case strings.HasPrefix(t, "- "):
			flushPara()
			list = append(list, strings.TrimSpace(t[2:]))
		default:
			flushList()
			para = append(para, t)
		}
	}
	flush()
	return strings.Join(out, "\n")
}
