package main

import (
	"fmt"
	"strings"
)

func i18nAttr(t I18nText) string {
	if t.I18n == "" {
		return ""
	}
	return fmt.Sprintf(` data-i18n="%s"`, t.I18n)
}

// render returns the visible text for HTML content. Quotes stay raw (as in the
// validated pages); only &, <, > are escaped. Trusted HTML passes through.
func (t I18nText) render() string {
	if t.HTML {
		return t.Text
	}
	return escText(t.Text)
}

func productHref(doc *HomeDoc, slug string) string {
	if doc.Kind == "jekyll" {
		return fmt.Sprintf("{{ '/products/%s.html' | relative_url }}", slug)
	}
	return fmt.Sprintf("products/%s.html", slug)
}

func renderHomeCTA(doc *HomeDoc, c CTA) string {
	variant := c.Variant
	if variant == "" {
		variant = "secondary"
	}
	if c.DL != "" { // milosvasic download buttons
		icon := ""
		if c.Icon != "" {
			icon = fmt.Sprintf(`<svg class="od-icon" aria-hidden="true"><use href="#%s"/></svg> `, c.Icon)
		}
		return fmt.Sprintf(`<button class="od-btn od-btn--%s" type="button" data-dl="%s">%s<span%s>%s</span></button>`,
			variant, c.DL, icon, i18nAttr(I18nText{I18n: c.I18n}), esc(c.Label))
	}
	return fmt.Sprintf(`<a class="od-btn od-btn--%s" href="%s"%s>%s</a>`,
		variant, c.Href, i18nAttr(I18nText{I18n: c.I18n}), esc(c.Label))
}

func renderCard(doc *HomeDoc, p *Portfolio, prefix string, c Card) string {
	var b strings.Builder
	badge := ""
	if !c.NoBadge {
		st := c.Status
		if st == "" && c.Slug != "" {
			if e := p.bySlug(c.Slug); e != nil {
				st = e.Status
			}
		}
		if st != "" {
			badge = fmt.Sprintf(` <span class="od-badge--status od-badge--status--%s">%s</span>`, esc(st), esc(st))
		}
	}
	b.WriteString(`        <article class="od-card od-product-card" style="padding:var(--od-space-6)">` + "\n")
	b.WriteString(fmt.Sprintf(`          <h3 class="od-product-card__title"%s>%s%s</h3>`+"\n",
		i18nAttr(I18nText{I18n: c.NameI18n}), esc(c.Name), badge))
	if len(c.Tech) > 0 {
		var chips strings.Builder
		for _, t := range c.Tech {
			chips.WriteString(`<span class="od-chip">` + esc(t) + `</span>`)
		}
		b.WriteString(`          <div class="od-product-card__tech">` + chips.String() + `</div>` + "\n")
	}
	if c.Blurb.Text != "" {
		b.WriteString(fmt.Sprintf(`          <p class="%s-card__blurb"%s>%s</p>`+"\n",
			prefix, i18nAttr(c.Blurb), c.Blurb.render()))
	}
	if c.Readmore.Text != "" || c.Slug != "" && c.Readmore.I18n != "" {
		href := productHref(doc, c.Slug)
		b.WriteString(fmt.Sprintf(`          <div class="%s-card__actions"><a class="od-btn od-btn--secondary" href="%s"%s>%s</a></div>`+"\n",
			prefix, href, i18nAttr(c.Readmore), c.Readmore.render()))
	}
	b.WriteString(`        </article>`)
	return b.String()
}

func renderGroupHeader(g Group) string {
	if g.Eyebrow.Text == "" {
		return ""
	}
	var b strings.Builder
	style := ""
	if g.MarginTop {
		style = ` style="margin-top:var(--od-space-10)"`
	}
	b.WriteString(fmt.Sprintf(`      <p class="od-section__eyebrow"%s%s>%s</p>`+"\n",
		style, i18nAttr(g.Eyebrow), g.Eyebrow.render()))
	b.WriteString(fmt.Sprintf(`      <h2 class="od-section__title"%s>%s</h2>`+"\n",
		i18nAttr(g.Title), g.Title.render()))
	if g.Lede.Text != "" {
		b.WriteString(fmt.Sprintf(`      <p class="od-section__lede"%s>%s</p>`+"\n",
			i18nAttr(g.Lede), g.Lede.render()))
	}
	return b.String()
}

func renderGroup(doc *HomeDoc, p *Portfolio, prefix string, g Group) string {
	var b strings.Builder
	b.WriteString(renderGroupHeader(g))
	switch g.Kind {
	case "prose":
		for _, para := range g.Paras {
			cls := para.Class
			b.WriteString(fmt.Sprintf(`      <p class="%s"%s>%s</p>`+"\n", cls, i18nAttr(para), para.render()))
		}
	case "cards", "tech":
		var cards []string
		for _, c := range g.Cards {
			cards = append(cards, renderCard(doc, p, prefix, c))
		}
		b.WriteString(fmt.Sprintf(`      <div class="%s">`+"\n", g.Grid))
		b.WriteString(strings.Join(cards, "\n"))
		b.WriteString("\n      </div>\n")
	}
	return b.String()
}

func renderSection(doc *HomeDoc, p *Portfolio, prefix string, blk HomeBlock) string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf(`    <section class="od-section" id="%s">`+"\n", blk.ID))
	// Optional section-level header (single-group sections).
	if blk.Eyebrow.Text != "" {
		b.WriteString(fmt.Sprintf(`      <p class="od-section__eyebrow"%s>%s</p>`+"\n", i18nAttr(blk.Eyebrow), blk.Eyebrow.render()))
		b.WriteString(fmt.Sprintf(`      <h2 class="od-section__title"%s>%s</h2>`+"\n", i18nAttr(blk.Title), blk.Title.render()))
		if blk.Lede.Text != "" {
			b.WriteString(fmt.Sprintf(`      <p class="od-section__lede"%s>%s</p>`+"\n", i18nAttr(blk.Lede), blk.Lede.render()))
		}
	}
	for _, g := range blk.Groups {
		b.WriteString(renderGroup(doc, p, prefix, g))
	}
	if len(blk.CTAs) > 0 {
		wrap := blk.CTAWrap
		if wrap == "" {
			wrap = prefix + "-hero__cta"
		}
		style := ""
		if blk.CTAStyle != "" {
			style = fmt.Sprintf(` style="%s"`, blk.CTAStyle)
		}
		var ctas []string
		for _, c := range blk.CTAs {
			ctas = append(ctas, renderHomeCTA(doc, c))
		}
		b.WriteString(fmt.Sprintf(`      <div class="%s"%s>`+"\n        %s\n      </div>\n", wrap, style, strings.Join(ctas, "\n        ")))
	}
	b.WriteString("    </section>")
	return b.String()
}

func renderHero(doc *HomeDoc, prefix string, blk HomeBlock) string {
	var b strings.Builder
	b.WriteString(`    <section class="od-hero">` + "\n")
	b.WriteString(fmt.Sprintf(`      <p class="od-section__eyebrow"%s>%s</p>`+"\n", i18nAttr(blk.Eyebrow), blk.Eyebrow.render()))
	b.WriteString(fmt.Sprintf(`      <h1 class="od-hero__title"%s>%s</h1>`+"\n", i18nAttr(blk.Title), blk.Title.render()))
	b.WriteString(fmt.Sprintf(`      <p class="od-hero__lede"%s>%s</p>`+"\n", i18nAttr(blk.Lede), blk.Lede.render()))
	var ctas []string
	for _, c := range blk.CTAs {
		ctas = append(ctas, renderHomeCTA(doc, c))
	}
	b.WriteString(fmt.Sprintf(`      <div class="%s-hero__cta">`+"\n        %s\n      </div>\n", prefix, strings.Join(ctas, "\n        ")))
	b.WriteString(fmt.Sprintf(`      <div class="%s-stats">`+"\n", prefix))
	for _, s := range blk.Stats {
		b.WriteString(fmt.Sprintf(`        <div class="od-stat"><div class="od-stat__value">%s</div><div class="od-stat__label"%s>%s</div></div>`+"\n",
			esc(s.Value), i18nAttr(I18nText{I18n: s.I18n}), esc(s.Label)))
	}
	b.WriteString("      </div>\n    </section>")
	return b.String()
}

func renderContact(prefix string, blk HomeBlock) string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf(`    <section class="od-section" id="%s">`+"\n", blk.ID))
	b.WriteString(fmt.Sprintf(`      <p class="od-section__eyebrow"%s>%s</p>`+"\n", i18nAttr(blk.Eyebrow), blk.Eyebrow.render()))
	b.WriteString(fmt.Sprintf(`      <h2 class="od-section__title"%s>%s</h2>`+"\n", i18nAttr(blk.Title), blk.Title.render()))
	if blk.Lede.Text != "" {
		b.WriteString(fmt.Sprintf(`      <p class="od-section__lede"%s>%s</p>`+"\n", i18nAttr(blk.Lede), blk.Lede.render()))
	}
	b.WriteString(fmt.Sprintf(`      <div class="%s-contact">`+"\n", prefix))
	for _, c := range blk.Contacts {
		b.WriteString(fmt.Sprintf(`        <p><strong%s>%s</strong><br/>%s</p>`+"\n",
			i18nAttr(I18nText{I18n: c.I18n}), esc(c.Label), c.HTML))
	}
	b.WriteString("      </div>\n    </section>")
	return b.String()
}

func renderHomeBlocks(doc *HomeDoc, p *Portfolio, prefix string) string {
	var out []string
	for _, blk := range doc.Blocks {
		switch blk.Type {
		case "hero":
			out = append(out, renderHero(doc, prefix, blk))
		case "section":
			out = append(out, renderSection(doc, p, prefix, blk))
		case "contact":
			out = append(out, renderContact(prefix, blk))
		}
	}
	return strings.Join(out, "\n\n")
}

// ---- Site shells (layout chrome) ----

func renderHomeStandalone(doc *HomeDoc, p *Portfolio) string {
	prefix := "vd"
	body := renderHomeBlocks(doc, p, prefix)
	return fmt.Sprintf(`<!doctype html>
<html lang="%s">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>%s</title>
<meta name="description" content="%s"/>
<script>(function(){try{var t=localStorage.getItem('od-theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t);}}catch(e){}})();</script>
<link rel="stylesheet" href="%s"/>
%s
</head>
<body>
<a class="od-skip-link" href="#main">Skip to content</a>
%s

  <header class="od-header">
    <a class="od-brand" href="index.html">%s</a>
    <div class="od-header__actions">
      <nav class="od-nav" aria-label="Primary">
        <a class="od-nav__link" href="#work" data-i18n="nav.work">Work</a>
        <a class="od-nav__link" href="#products" data-i18n="nav.products">Products</a>
        <a class="od-nav__link" href="portfolio/" data-i18n="nav.portfolio">Portfolio</a>
        <a class="od-nav__link" href="#contact" data-i18n="nav.contact">Contact</a>
      </nav>
      <button id="od-theme-toggle" class="od-btn od-btn--ghost od-theme-toggle" type="button" aria-label="Toggle light or dark theme">
        <svg class="od-icon od-icon--moon" aria-hidden="true"><use href="#i-moon"/></svg>
        <svg class="od-icon od-icon--sun" aria-hidden="true"><use href="#i-sun"/></svg>
      </button>
    </div>
  </header>

  <main id="main">

%s

  </main>

  <footer class="od-footer" data-i18n="footer.text">%s</footer>

%s
</body>
</html>
`, doc.Lang, esc(doc.Title), esc(doc.Desc), doc.CSS, vasicHeadExtras, vasicSymbols, esc(doc.Brand), body, esc(doc.Footer), vasicToggleScript)
}

func renderHomeJekyll(doc *HomeDoc, p *Portfolio) string {
	prefix := "mvx"
	body := renderHomeBlocks(doc, p, prefix)
	return fmt.Sprintf(`---
layout: default
---

<!-- OpenDesign brand stylesheet (linked from the page so the existing default layout head stays untouched). -->
<link rel="stylesheet" href="%s"/>
%s

%s

%s
`, doc.CSS, mvSymbols, mvHeadStyle, body)
}

func renderHome(doc *HomeDoc, p *Portfolio) string {
	if doc.Kind == "jekyll" {
		return renderHomeJekyll(doc, p)
	}
	return renderHomeStandalone(doc, p)
}
