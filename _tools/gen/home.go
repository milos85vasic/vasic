package main

import (
	"encoding/json"
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

// homeAssetPrefix returns the relative hop from a home page back to the site
// root: "" for the canonical EN home (which sits at the site root) and "../" for
// a localized home at /<lang>/index.html. Drives root-relative asset links and
// cross-page hrefs on the self-contained (vasic.digital) home.
func homeAssetPrefix(lang string) string {
	if lang == "" || lang == "en" {
		return ""
	}
	return "../"
}

// productHref resolves a product-detail link from the home to the localized
// product page for the home's own language. EN → products/<slug>.html; a
// localized home at /<lang>/ points at ../products/<lang>/<slug>.html (standalone)
// or the root-absolute /products/<lang>/<slug>.html via relative_url (Jekyll).
func productHref(doc *HomeDoc, slug string) string {
	lp := langPath(htmlLang(doc.Lang), "products/"+slug+".html")
	if doc.Kind == "jekyll" {
		return fmt.Sprintf("{{ '/%s' | relative_url }}", lp)
	}
	return homeAssetPrefix(doc.Lang) + lp
}

// renderHomeCTA renders a hero/section call-to-action. `extra` is an optional
// space-free extra class list (e.g. "od-magnetic") appended after the variant
// class so a site can opt a button into a decorative motion effect without
// changing its href/label/i18n contract.
func renderHomeCTA(doc *HomeDoc, c CTA, extra string) string {
	variant := c.Variant
	if variant == "" {
		variant = "secondary"
	}
	if extra != "" {
		extra = " " + extra
	}
	if c.DL != "" { // milosvasic download buttons
		icon := ""
		if c.Icon != "" {
			icon = fmt.Sprintf(`<svg class="od-icon" aria-hidden="true"><use href="#%s"/></svg> `, c.Icon)
		}
		return fmt.Sprintf(`<button class="od-btn od-btn--%s%s" type="button" data-dl="%s">%s<span%s>%s</span></button>`,
			variant, extra, c.DL, icon, i18nAttr(I18nText{I18n: c.I18n}), esc(c.Label))
	}
	return fmt.Sprintf(`<a class="od-btn od-btn--%s%s" href="%s"%s>%s</a>`,
		variant, extra, c.Href, i18nAttr(I18nText{I18n: c.I18n}), esc(c.Label))
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
	// vasic.digital cards carry `.od-glow` — an opacity-only accent sheen that
	// fades in on hover/focus (GPU-safe, neutralized under reduced motion). Scoped
	// to the "vd" prefix so it stays part of vasic's distinct motion signature.
	cardFx := ""
	if prefix == "vd" {
		cardFx = " od-glow"
	}
	b.WriteString(`        <article class="od-card od-product-card` + cardFx + `" style="padding:var(--od-space-6)">` + "\n")
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
		// Descriptive aria-label so screen-reader users (and SEO crawlers) get the
		// destination context, not 23 identical bare "Read more" links (perf/a11y).
		aria := firstNonEmpty(c.Readmore.Text, "Read more")
		if c.Name != "" {
			aria = aria + ": " + c.Name
		}
		b.WriteString(fmt.Sprintf(`          <div class="%s-card__actions"><a class="od-btn od-btn--secondary" href="%s" aria-label="%s"%s>%s</a></div>`+"\n",
			prefix, href, esc(aria), i18nAttr(c.Readmore), c.Readmore.render()))
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
		b.WriteString(fmt.Sprintf(`      <div class="%s od-stagger">`+"\n", g.Grid))
		b.WriteString(strings.Join(cards, "\n"))
		b.WriteString("\n      </div>\n")
	}
	return b.String()
}

func renderSection(doc *HomeDoc, p *Portfolio, prefix string, blk HomeBlock) string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf(`    <section class="od-section od-reveal" id="%s">`+"\n", blk.ID))
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
			ctas = append(ctas, renderHomeCTA(doc, c, ""))
		}
		b.WriteString(fmt.Sprintf(`      <div class="%s"%s>`+"\n        %s\n      </div>\n", wrap, style, strings.Join(ctas, "\n        ")))
	}
	b.WriteString("    </section>")
	return b.String()
}

// mvPortrait is the milosvasic.ru hero portrait — a responsive <picture> using
// the existing profile-*.{webp,jpg} assets, arranged beside the hero copy
// (fix #2). Jekyll relative_url resolves the paths under the site baseurl. The
// alt text is DATA (T(lang,"alt.portrait")), localized for all 15 languages.
func mvPortrait(lang string) string {
	return `      <figure class="mvx-hero__portrait">
        <picture>
          <source type="image/webp" srcset="{{ '/assets/images/profile-400.webp' | relative_url }} 400w, {{ '/assets/images/profile-600.webp' | relative_url }} 600w, {{ '/assets/images/profile-800.webp' | relative_url }} 800w" sizes="(max-width: 767px) 66vw, 320px">
          <img src="{{ '/assets/images/profile-800.jpg' | relative_url }}" srcset="{{ '/assets/images/profile-400.jpg' | relative_url }} 400w, {{ '/assets/images/profile-600.jpg' | relative_url }} 600w, {{ '/assets/images/profile-800.jpg' | relative_url }} 800w" sizes="(max-width: 767px) 66vw, 320px" width="800" height="1000" alt="` + esc(T(lang, "alt.portrait")) + `" loading="eager" decoding="async" fetchpriority="high">
        </picture>
      </figure>
`
}

// vdHeroLogo is the Vasic Digital hero logo lockup — the restored brand mark
// (fix #3) on a rounded white chip so its background reads cleanly in light AND
// dark themes. `prefix` ("" root / "../" localized) hops back to the site root so
// the brand image resolves from a localized home at /<lang>/index.html too. The
// alt text is DATA (T(lang,"alt.brandLogo")), localized for all 15 languages.
func vdHeroLogo(prefix, lang string) string {
	return `      <div class="vd-hero__logo"><picture><source srcset="` + prefix + `Assets/logo.webp" type="image/webp"><img src="` + prefix + `Assets/Logo.jpeg" alt="` + esc(T(lang, "alt.brandLogo")) + `" width="112" height="112" decoding="async"></picture></div>
`
}

func renderHero(doc *HomeDoc, prefix string, blk HomeBlock) string {
	lang := htmlLang(doc.Lang)
	var body strings.Builder
	body.WriteString(fmt.Sprintf(`      <p class="od-section__eyebrow"%s>%s</p>`+"\n", i18nAttr(blk.Eyebrow), blk.Eyebrow.render()))
	body.WriteString(fmt.Sprintf(`      <h1 class="od-hero__title"%s>%s</h1>`+"\n", i18nAttr(blk.Title), blk.Title.render()))
	body.WriteString(fmt.Sprintf(`      <p class="od-hero__lede"%s>%s</p>`+"\n", i18nAttr(blk.Lede), blk.Lede.render()))
	// vasic.digital hero CTAs are `.od-magnetic`: on a fine pointer they ease a
	// few px toward the cursor (motion.js, transform-only). No-op on touch and
	// under reduced motion; keyboard focus/activation are untouched.
	ctaExtra := ""
	if prefix == "vd" {
		ctaExtra = "od-magnetic"
	}
	var ctas []string
	for _, c := range blk.CTAs {
		ctas = append(ctas, renderHomeCTA(doc, c, ctaExtra))
	}
	body.WriteString(fmt.Sprintf(`      <div class="%s-hero__cta">`+"\n        %s\n      </div>\n", prefix, strings.Join(ctas, "\n        ")))

	// Stats strip: `.od-stagger` makes the metrics count-in (staggered GPU slide)
	// on scroll-reveal via motion.js, and each value carries `.od-highlight` for
	// the library's compositor-only accent-ring micro-effect. Both are neutralized
	// under prefers-reduced-motion by animations.css. Only emit the stagger hook
	// when there are metrics to reveal.
	var stats strings.Builder
	staggerCls := ""
	if len(blk.Stats) > 0 {
		staggerCls = " od-stagger"
	}
	// `data-od-count` (vasic only) makes each metric count up from 0 to its final
	// value when it scrolls into view (motion.js). The FINAL value is what's in the
	// HTML, so no-JS / reduced-motion / crawlers see the real number immediately.
	countAttr := ""
	if prefix == "vd" {
		countAttr = " data-od-count"
	}
	stats.WriteString(fmt.Sprintf(`      <div class="%s-stats%s">`+"\n", prefix, staggerCls))
	for _, s := range blk.Stats {
		stats.WriteString(fmt.Sprintf(`        <div class="od-stat"><div class="od-stat__value od-highlight"%s>%s</div><div class="od-stat__label"%s>%s</div></div>`+"\n",
			countAttr, esc(s.Value), i18nAttr(I18nText{I18n: s.I18n}), esc(s.Label)))
	}
	stats.WriteString("      </div>\n")

	var b strings.Builder
	// vasic.digital adds `.vd-hero`, which turns the hero into the positioning
	// context for its decorative aurora/grid backdrop (see vasic-digital.css).
	heroCls := "od-hero od-reveal"
	if prefix == "vd" {
		heroCls += " vd-hero"
	}
	b.WriteString(fmt.Sprintf(`    <section class="%s">`+"\n", heroCls))
	switch prefix {
	case "mvx": // milosvasic.ru — copy beside the restored portrait
		b.WriteString("      <div class=\"mvx-hero__grid\">\n")
		b.WriteString("      <div class=\"mvx-hero__body\">\n")
		b.WriteString(body.String())
		b.WriteString("      </div>\n")
		b.WriteString(mvPortrait(lang))
		b.WriteString("      </div>\n")
		b.WriteString(stats.String())
	case "vd": // vasic.digital — engineered backdrop + logo lockup + count-up metrics
		// Decorative, aria-hidden backdrop: drifting deep-red aurora mesh + a faint
		// technical grid. Purely presentational (pointer-events:none) and fully
		// static under prefers-reduced-motion.
		b.WriteString(`      <div class="vd-hero__fx" aria-hidden="true"><span class="vd-hero__aurora"></span><span class="vd-hero__grid"></span></div>` + "\n")
		b.WriteString(vdHeroLogo(homeAssetPrefix(doc.Lang), lang))
		b.WriteString(body.String())
		b.WriteString(stats.String())
		// Precision divider — a thin accent rule that scales in (scaleX) on reveal.
		b.WriteString(`      <hr class="vd-hero__rule od-divider" aria-hidden="true"/>` + "\n")
	default:
		b.WriteString(body.String())
		b.WriteString(stats.String())
	}
	b.WriteString("    </section>")
	return b.String()
}

func renderContact(prefix string, blk HomeBlock) string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf(`    <section class="od-section od-reveal" id="%s">`+"\n", blk.ID))
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

func renderHomeStandalone(doc *HomeDoc, p *Portfolio, site *Site, langs []string) string {
	prefix := "vd"
	lang := htmlLang(doc.Lang)
	// Localized homes live at /<lang>/index.html; the EN home sits at the site
	// root. `pfx` is the "../" hop that makes root-relative assets/links resolve
	// from the localized home (empty on EN → byte-identical output).
	pfx := homeAssetPrefix(doc.Lang)
	portfolioHref := "portfolio/"
	if pfx != "" {
		portfolioHref = pfx + langPath(doc.Lang, "portfolio/")
	}
	brandLogo := fmt.Sprintf(`<picture><source srcset="%sAssets/logo.webp" type="image/webp"><img class="od-brand__logo" src="%sAssets/Logo.jpeg" alt="" width="28" height="28" decoding="async"></picture>`, pfx, pfx)
	// EN home keeps the bare <html lang="en"> (byte-identical). Localized homes add
	// an explicit dir so RTL languages (ar/fa) lay out correctly for no-JS crawlers
	// and before od-i18n.js runs; ltr is emitted for the rest for symmetry.
	htmlOpen := fmt.Sprintf(`<html lang="%s">`, doc.Lang)
	if pfx != "" {
		htmlOpen = fmt.Sprintf(`<html lang="%s" dir="%s">`, doc.Lang, htmlDir(doc.Lang))
	}
	body := renderHomeBlocks(doc, p, prefix)
	// Localized homes now exist on disk, so the home carries the full reciprocal
	// hreflang matrix (all `langs` + x-default → EN root), same as product/
	// portfolio pages — every alternate resolves.
	head := seoHead(site, langs, pageSEO{
		title:    doc.Title,
		desc:     doc.Desc,
		keywords: siteKeywords(site, lang),
		lang:     lang,
		enPath:   "",
		ogType:   "website",
		jsonLD:   site.baseGraphLang(lang),
		prefix:   pfx,
		cssName:  site.CSSName,
	})
	return fmt.Sprintf(`<!doctype html>
%s
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<script>(function(){try{var t=localStorage.getItem('od-theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t);}}catch(e){}})();</script>
%s
%s
%s
</head>
<body>
<a class="od-skip-link" href="#main">%s</a>
%s

  <header class="od-header">
    <a class="od-brand" href="index.html">%s %s</a>
    <div class="od-header__actions">
      <nav class="od-nav" aria-label="%s" data-i18n-aria="aria.primaryNav">
        <a class="od-nav__link" href="#work" data-i18n="nav.work">%s</a>
        <a class="od-nav__link" href="#products" data-i18n="nav.products">%s</a>
        <a class="od-nav__link" href="%s" data-i18n="nav.portfolio">%s</a>
        <a class="od-nav__link" href="#contact" data-i18n="nav.contact">%s</a>
      </nav>
      %s
      <button id="od-theme-toggle" class="od-btn od-btn--ghost od-theme-toggle" type="button" aria-label="%s" data-i18n-aria="aria.toggleTheme">
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
%s
%s
%s
</body>
</html>
`, htmlOpen, assetLinks(pfx, site.CSSName), head, vasicHeadExtras,
		esc(tOr(lang, "skip", "Skip to content")), vasicSymbols,
		brandLogo, esc(doc.Brand),
		esc(T(lang, "aria.primaryNav")),
		esc(tOr(lang, "nav.work", "Work")), esc(tOr(lang, "nav.products", "Products")),
		portfolioHref, esc(tOr(lang, "nav.portfolio", "Portfolio")),
		esc(tOr(lang, "nav.contact", "Contact")),
		odLangMount(), esc(T(lang, "aria.toggleTheme")),
		body, esc(footerText(site, lang)), backToTopButton(lang), vasicToggleScript,
		motionScript(pfx), odSwitcher(site, langs, "home", "", pfx))
}

// assetLinksJekyll emits the same ordered stylesheet links, but resolved through
// Jekyll's `relative_url` filter so they work under the site's baseurl.
func assetLinksJekyll(cssName string) string {
	one := func(f string) string {
		return `<link rel="stylesheet" href="{{ '/assets/od/` + f + `' | relative_url }}"/>`
	}
	return strings.Join([]string{
		one("fonts.css"),
		one(cssName + ".css"),
		one("components-extended.css"),
		one("animations.css"),
		one("overlays.css"),
	}, "\n")
}

// mvPagePathsJSON builds the MV_PAGE per-language URL map for a milosvasic.ru
// (Jekyll) page so assets/js/main.js NAVIGATES to the localized variant of THIS
// page type when a language is chosen — not just a client-side chrome swap that
// leaves the body in the old language (BUG #63). enPath is the EN root-relative
// path ("" home, "products/<slug>.html", "portfolio/"); langPath maps it to each
// language's real static route ("/", "/de/", "/products/de/x.html", …). Every
// milos product/portfolio page is emitted for all langs, so every path resolves;
// main.js additionally falls back to the localized home if a path is ever absent.
func mvPagePathsJSON(pageType, enPath string, langs []string) string {
	paths := map[string]string{}
	for _, l := range langs {
		paths[l] = "/" + langPath(l, enPath)
	}
	b, _ := json.Marshal(map[string]interface{}{"type": pageType, "paths": paths})
	return string(b)
}

// homePathsJSON builds the OD_PAGE/MV_PAGE per-language home URL map
// ({"en":"/","ru":"/ru/",…}) the switchers navigate to when a language is picked.
func homePathsJSON(langs []string) string {
	return mvPagePathsJSON("home", "", langs)
}

func renderHomeJekyll(doc *HomeDoc, p *Portfolio, site *Site, langs []string) string {
	prefix := "mvx"
	body := renderHomeBlocks(doc, p, prefix)
	// The <head> (title/meta/SEO) is owned by the Jekyll `default` layout + jekyll-seo-tag;
	// here we wire the OpenDesign assets (fonts→brand→components→motion→overlays) and the
	// deferred motion controller into the page body, which the layout leaves untouched.
	// seo_hreflang is consumed by the shared default.html layout (jekyll-seo-tag
	// does not emit hreflang). Localized homes now exist at /<lang>/, so the home
	// carries the full reciprocal matrix (all langs + x-default → EN root).
	//
	// window.MV_PAGE feeds the layout's language switcher (assets/js/main.js): when
	// a language is chosen on the home, main.js navigates to the localized home URL
	// (/, /ru/, …) so the fully-translated home body loads — not just a chrome swap.
	return fmt.Sprintf(`---
layout: default
lang: %s
seo_hreflang: %s
---

<!-- OpenDesign assets (fonts → brand → components → animations → overlays), linked from the page so the default layout head stays untouched. -->
%s
<script defer src="{{ '/assets/od/motion.js' | relative_url }}"></script>
<script>window.MV_PAGE=%s;</script>
%s

%s

%s
`, htmlLang(doc.Lang), yamlQuote(hreflangInline(site, langs, "")), assetLinksJekyll(site.CSSName), homePathsJSON(langs), mvSymbols, mvHeadStyle, body)
}

func renderHome(doc *HomeDoc, p *Portfolio, site *Site, langs []string) string {
	if doc.Kind == "jekyll" {
		return renderHomeJekyll(doc, p, site, langs)
	}
	return renderHomeStandalone(doc, p, site, langs)
}
