package main

import (
	"fmt"
	"hash/fnv"
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

// ---- product-page renderer (rich, editorial) --------------------------------
//
// renderProductBody turns a product .md body into a rich, nicely-written detail
// page WITHOUT dropping any content. It renders EVERY section from the brief;
// the only transformation is editorial framing (fix #5 / content-richness):
//   - the bold hook line (preamble) becomes a prominent tagline (no label),
//   - "Short description" becomes the hero LEDE (no label),
//   - "Summary" + "Long description" become the opening narrative (no labels),
//   - every deeper section keeps its full content under an editorial heading
//     whose wording varies per product (rotating set keyed off the slug).
// Paragraphs, bullet lists, blockquotes, inline bold/code and H3s all render.

type mdSection struct {
	head string
	body string
}

// splitSections separates the preamble (text before the first "## ") from the
// ordered list of "## Heading" sections. A leading body H1 ("# Title") is
// dropped (the page title comes from frontmatter).
func splitSections(body string) (string, []mdSection) {
	lines := strings.Split(body, "\n")
	var preamble []string
	var sections []mdSection
	started := false
	var head string
	var buf []string
	for _, raw := range lines {
		t := strings.TrimSpace(raw)
		if strings.HasPrefix(t, "## ") {
			if started {
				sections = append(sections, mdSection{head, strings.Join(buf, "\n")})
			}
			head = strings.TrimSpace(t[3:])
			buf = nil
			started = true
			continue
		}
		if strings.HasPrefix(t, "# ") { // drop body H1
			continue
		}
		if started {
			buf = append(buf, raw)
		} else {
			preamble = append(preamble, raw)
		}
	}
	if started {
		sections = append(sections, mdSection{head, strings.Join(buf, "\n")})
	}
	return strings.Join(preamble, "\n"), sections
}

// renderContentBlocks renders a section body (no "## " headings) into indented
// HTML: paragraphs, "- " bullet lists, "> " blockquotes, and "### " sub-heads.
// Nothing is dropped.
func renderContentBlocks(text string) string {
	lines := strings.Split(text, "\n")
	var out, para, list, quote []string

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
	flushQuote := func() {
		if len(quote) == 0 {
			return
		}
		out = append(out, "      <blockquote><p>"+inline(strings.Join(quote, " "))+"</p></blockquote>")
		quote = nil
	}
	flush := func() { flushPara(); flushList(); flushQuote() }

	for _, raw := range lines {
		t := strings.TrimSpace(raw)
		switch {
		case t == "":
			flush()
		case strings.HasPrefix(t, "### "):
			flush()
			out = append(out, "      <h3>"+inline(strings.TrimSpace(t[4:]))+"</h3>")
		case strings.HasPrefix(t, ">"):
			flushPara()
			flushList()
			quote = append(quote, strings.TrimSpace(strings.TrimPrefix(t, ">")))
		case strings.HasPrefix(t, "- "):
			flushPara()
			flushQuote()
			list = append(list, strings.TrimSpace(t[2:]))
		default:
			flushList()
			flushQuote()
			para = append(para, t)
		}
	}
	flush()
	return strings.Join(out, "\n")
}

// collapse joins a multi-line block into one spaced line (for tagline/lede).
func collapse(s string) string {
	var parts []string
	for _, ln := range strings.Split(s, "\n") {
		if t := strings.TrimSpace(ln); t != "" {
			parts = append(parts, t)
		}
	}
	return strings.Join(parts, " ")
}

// headingGroup maps each canonical brief heading (lowercased) to an editorial
// i18n GROUP key. The visitor-facing editorial heading VARIANTS for each group are
// DATA, not baked-in English prose: they live in ui-i18n.json under
// prod.head.<group>.<n> (EN source of truth, reviewer-gated 15-language
// translations — §11.4.35/§11.4.140/§11.4.216). The English canonical headings
// below are MATCH KEYS against the source markdown, not rendered content.
var headingGroup = map[string]string{
	"why we built it":                    "whywebuilt",
	"why it's a game-changer":            "gamechanger",
	"why it's a game-changer (measured)": "gamechanger",
	"what's innovative":                  "innovative",
	"biggest technical challenges & how we solved them": "challenges",
	"challenges & solutions":                            "challenges",
	"tech stack (why + how)":                            "techstack",
	"tech stack":                                        "techstack",
	"status & honesty notes":                            "status",
	"how it is used across all products (the powers it gives)": "powers",
}

// headingGroupSet is the reverse-lookup set (used to recognize a translated
// product .md heading via its localized canonical name, prod.head.<group>.name).
var headingGroupSet = []string{"whywebuilt", "gamechanger", "innovative", "challenges", "techstack", "status", "powers"}

// editorialGroup resolves a section heading to its i18n group. It matches the
// English canonical headings (source .md) AND, for a localized doc, the localized
// canonical name (prod.head.<group>.name in ui-i18n.json) so translated product
// headings also receive the editorial rewording. Unknown headings return !ok and
// are kept verbatim.
func editorialGroup(orig, lang string) (string, bool) {
	key := strings.ToLower(strings.TrimSpace(orig))
	if g, ok := headingGroup[key]; ok {
		return g, true
	}
	if lang != "" && lang != "en" {
		for _, g := range headingGroupSet {
			name := strings.ToLower(strings.TrimSpace(T(lang, "prod.head."+g+".name")))
			if name != "" && name == key {
				return g, true
			}
		}
	}
	return "", false
}

// editorialVariantCount returns how many prod.head.<group>.<n> variants exist in
// the EN source dictionary — the single source of truth for the count, so the
// deterministic per-slug selection stays stable across languages and rebuilds.
func editorialVariantCount(group string) int {
	en := uiDict["en"]
	n := 0
	for {
		if _, ok := en[fmt.Sprintf("prod.head.%s.%d", group, n)]; !ok {
			return n
		}
		n++
	}
}

// editorialHeading returns a varied, engaging heading for a canonical brief
// heading, sourced from ui-i18n.json (localized per lang). A per-slug hash picks
// one variant deterministically. Unknown headings are kept verbatim (robust for
// all products / any language).
func editorialHeading(orig, slug, lang string) string {
	group, ok := editorialGroup(orig, lang)
	if !ok {
		return orig
	}
	n := editorialVariantCount(group)
	if n == 0 {
		return orig
	}
	h := fnv.New32a()
	h.Write([]byte(slug))
	return T(lang, fmt.Sprintf("prod.head.%s.%d", group, int(h.Sum32())%n))
}

// specialSectionKey maps the English canonical narrative-section heading to the
// ui-i18n key carrying its localized name, so the hero-lede / opening-narrative
// framing is applied on localized product pages too (not only EN).
var specialSectionKey = map[string]string{
	"summary":           "prod.sec.summary",
	"short description": "prod.sec.short",
	"long description":  "prod.sec.long",
}

// isSpecialSection reports whether a section head is one of the special narrative
// sections — by English canonical name OR its localized name (T(lang,key)).
func isSpecialSection(head, lang string) bool {
	if _, ok := specialSectionKey[strings.ToLower(strings.TrimSpace(head))]; ok {
		return true
	}
	if lang != "" && lang != "en" {
		for _, k := range specialSectionKey {
			if strings.EqualFold(strings.TrimSpace(head), T(lang, k)) {
				return true
			}
		}
	}
	return false
}

// renderProductBody is the rich product-page body renderer (see doc above). lang
// drives the localized special-section detection and editorial headings so a
// translated product .md gets the SAME hero-lede framing + editorial rewording EN
// gets (§11.4.237); an empty lang is treated as EN.
func renderProductBody(body, slug, lang string) string {
	preamble, sections := splitSections(body)
	var out []string

	// find a section by its English canonical name OR its localized name.
	find := func(enName, i18nKey string) (string, bool) {
		for _, s := range sections {
			h := strings.TrimSpace(s.head)
			if strings.EqualFold(h, enName) ||
				(lang != "" && lang != "en" && strings.EqualFold(h, T(lang, i18nKey))) {
				return strings.TrimSpace(s.body), true
			}
		}
		return "", false
	}

	if tag := collapse(preamble); tag != "" {
		out = append(out, `      <p class="od-product-detail__tagline">`+inline(tag)+`</p>`)
	}
	if s, ok := find("short description", "prod.sec.short"); ok && s != "" {
		out = append(out, `      <p class="od-product-detail__lede">`+inline(collapse(s))+`</p>`)
	}
	if s, ok := find("summary", "prod.sec.summary"); ok && s != "" {
		out = append(out, renderContentBlocks(s))
	}
	if s, ok := find("long description", "prod.sec.long"); ok && s != "" {
		out = append(out, renderContentBlocks(s))
	}
	var deep []mdSection
	for _, s := range sections {
		if isSpecialSection(s.head, lang) {
			continue
		}
		deep = append(deep, s)
	}
	if len(deep) > 0 {
		out = append(out, renderProductAccordion(slug, deep, lang))
	}
	return strings.Join(out, "\n")
}

// renderProductAccordion wraps the deep/secondary product sections in the
// OpenDesign disclosure pattern the motion controller wires up
// (design-system/motion/motion.js -> initAccordions). Contract:
//
//	.od-accordion > .od-accordion__item
//	  <h2 class="od-accordion__heading">
//	    <button class="od-accordion__trigger" aria-expanded aria-controls id> … </button>
//	  .od-accordion__panel[is-open] (role=region, aria-labelledby)
//	    .od-accordion__inner  (the section content)
//
// Progressive enhancement: every item ships OPEN (aria-expanded="true", panel
// carries .is-open and is NOT [hidden]), so with no JS / for crawlers the full
// content is rendered and visible. motion.js reads aria-expanded on boot, keeps
// the panel open, and adds click/keyboard collapse (the button is natively
// keyboard-operable; Enter/Space toggle it). The <h2> is preserved for document
// outline / SEO; its text lives inside the button. Reduced motion is honored by
// animations.css (no height/opacity/transform animation; content stays visible).
func renderProductAccordion(slug string, sections []mdSection, lang string) string {
	var b strings.Builder
	b.WriteString(`      <div class="od-accordion">` + "\n")
	for i, s := range sections {
		tid := fmt.Sprintf("od-acc-%s-%d", slug, i)
		pid := tid + "-panel"
		heading := inline(editorialHeading(s.head, slug, lang))
		inner := renderContentBlocks(s.body)
		b.WriteString(fmt.Sprintf(`        <div class="od-accordion__item">
          <h2 class="od-accordion__heading">
            <button class="od-accordion__trigger" type="button" id="%s" aria-expanded="true" aria-controls="%s">
              <span class="od-accordion__label">%s</span>
              <svg class="od-icon od-accordion__icon" aria-hidden="true"><use href="#i-chevron-down"/></svg>
            </button>
          </h2>
          <div class="od-accordion__panel is-open" id="%s" role="region" aria-labelledby="%s">
            <div class="od-accordion__inner">
%s
            </div>
          </div>
        </div>
`, tid, pid, heading, pid, tid, inner))
	}
	b.WriteString(`      </div>`)
	return b.String()
}
