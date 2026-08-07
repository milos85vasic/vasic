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

// creativeHeadings maps each canonical brief heading to a set of editorial
// variants. A per-slug hash picks one, so each product page reads bespoke
// rather than templated, while staying deterministic across rebuilds.
var creativeHeadings = map[string][]string{
	"why we built it": {
		"The problem we set out to solve",
		"Why this exists",
		"What drove us to build it",
		"The itch we had to scratch",
		"Origin story",
	},
	"why it's a game-changer": {
		"Why it changes the game",
		"The leap it delivers",
		"What sets it apart",
		"Why it matters",
	},
	"why it's a game-changer (measured)": {
		"Why it changes the game",
		"The leap it delivers",
		"What sets it apart",
		"Why it matters",
	},
	"what's innovative": {
		"Where the novelty lives",
		"What's genuinely new",
		"The innovations inside",
		"Ideas worth stealing",
	},
	"biggest technical challenges & how we solved them": {
		"Hard problems, honest solutions",
		"The tough parts — and the fixes",
		"Engineering the hard bits",
		"Where it got hard, and how we won",
	},
	"challenges & solutions": {
		"Hard problems, honest solutions",
		"The tough parts — and the fixes",
		"Engineering the hard bits",
		"Where it got hard, and how we won",
	},
	"tech stack (why + how)": {
		"The stack, and why",
		"How it's built",
		"Under the hood",
		"The engineering stack",
	},
	"tech stack": {
		"The stack, and why",
		"How it's built",
		"Under the hood",
		"The engineering stack",
	},
	"status & honesty notes": {
		"Status, told straight",
		"Where it really stands",
		"The honest status",
		"No-spin status",
	},
	"how it is used across all products (the powers it gives)": {
		"The powers it gives",
		"What it unlocks across the fleet",
		"How the fleet leans on it",
	},
}

// editorialHeading returns a varied, engaging heading for a canonical brief
// heading; unknown headings are kept verbatim (robust for all products).
func editorialHeading(orig, slug string) string {
	key := strings.ToLower(strings.TrimSpace(orig))
	variants, ok := creativeHeadings[key]
	if !ok || len(variants) == 0 {
		return orig
	}
	h := fnv.New32a()
	h.Write([]byte(slug))
	return variants[int(h.Sum32())%len(variants)]
}

var specialProductSections = map[string]bool{
	"summary":           true,
	"short description": true,
	"long description":  true,
}

// renderProductBody is the rich product-page body renderer (see doc above).
func renderProductBody(body, slug string) string {
	preamble, sections := splitSections(body)
	var out []string

	find := func(name string) (string, bool) {
		for _, s := range sections {
			if strings.EqualFold(strings.TrimSpace(s.head), name) {
				return strings.TrimSpace(s.body), true
			}
		}
		return "", false
	}

	if tag := collapse(preamble); tag != "" {
		out = append(out, `      <p class="od-product-detail__tagline">`+inline(tag)+`</p>`)
	}
	if s, ok := find("short description"); ok && s != "" {
		out = append(out, `      <p class="od-product-detail__lede">`+inline(collapse(s))+`</p>`)
	}
	if s, ok := find("summary"); ok && s != "" {
		out = append(out, renderContentBlocks(s))
	}
	if s, ok := find("long description"); ok && s != "" {
		out = append(out, renderContentBlocks(s))
	}
	var deep []mdSection
	for _, s := range sections {
		if specialProductSections[strings.ToLower(strings.TrimSpace(s.head))] {
			continue
		}
		deep = append(deep, s)
	}
	if len(deep) > 0 {
		out = append(out, renderProductAccordion(slug, deep))
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
func renderProductAccordion(slug string, sections []mdSection) string {
	var b strings.Builder
	b.WriteString(`      <div class="od-accordion">` + "\n")
	for i, s := range sections {
		tid := fmt.Sprintf("od-acc-%s-%d", slug, i)
		pid := tid + "-panel"
		heading := inline(editorialHeading(s.head, slug))
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
