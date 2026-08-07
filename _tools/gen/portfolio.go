package main

import (
	"fmt"
	"regexp"
	"strings"
)

var licHideRe = regexp.MustCompile(`(?i)^(unverified|tbd)`)

// tierI18nKey maps a portfolio tier id to the ui-i18n key prefix whose
// .eyebrow/.title carry the localized section header. EN source strings live in
// ui-i18n.en.json (tier1/2/3.eyebrow/title).
var tierI18nKey = map[string]string{
	"helix-primary":          "tier1",
	"vasic-util-secondary":   "tier2",
	"serverfactory-tertiary": "tier3",
}

// portfolioProductHref resolves the "Read more" target for a card. On the Jekyll
// site the link is baseurl-resolved from the site root (works at any URL depth,
// including localized /portfolio/<lang>/); on self-contained sites it is relative
// to /portfolio/.
func portfolioProductHref(jekyll bool, slug, lang string) string {
	if jekyll {
		return "{{ '/products/" + slug + ".html' | relative_url }}"
	}
	// EN portfolio (/portfolio/) → depth 1 → ../products/<slug>.html.
	// Localized portfolio (/portfolio/<lang>/) → depth 2 → the localized
	// product one level further out: ../../products/<lang>/<slug>.html.
	if lang != "" && lang != "en" {
		return "../../products/" + lang + "/" + slug + ".html"
	}
	return "../products/" + slug + ".html"
}

func portfolioCard(root string, e *PortfolioEntry, jekyll bool, lang string) string {
	var chips strings.Builder
	n := len(e.Tech)
	limit := n
	if limit > 6 {
		limit = 6
	}
	for _, t := range e.Tech[:limit] {
		chips.WriteString(`<span class="od-chip">` + esc(t) + `</span>`)
	}
	if n > 6 {
		chips.WriteString(fmt.Sprintf(`<span class="od-chip">+%d</span>`, n-6))
	}
	lic := ""
	if e.License != "" && !licHideRe.MatchString(e.License) {
		lic = `<span class="od-tag--license">` + esc(e.License) + `</span>`
	}
	blTag, blSum := localizedBlurb(root, e, lang)
	blurb := blTag
	if blurb == "" {
		blurb = blSum
	}
	return fmt.Sprintf(`        <article class="od-card od-product-card" style="padding:var(--od-space-6)">
          <h3 class="od-product-card__title">%s <span class="od-badge--status od-badge--status--%s">%s</span></h3>
          <div class="od-product-card__tech">%s</div>
          <p class="pf-card__blurb">%s</p>
          <div class="pf-card__meta">%s</div>
          <div class="pf-card__actions"><a class="od-btn od-btn--secondary" href="%s">%s</a></div>
        </article>`,
		esc(e.Name), esc(e.Status), esc(T(lang, "status."+e.Status)),
		chips.String(), esc(blurb), lic, portfolioProductHref(jekyll, e.Slug, lang), esc(T(lang, "pf.readmore")))
}

func portfolioTierSection(root string, p *Portfolio, tier string, jekyll bool, lang string) string {
	key := tierI18nKey[tier]
	eyebrow := T(lang, key+".eyebrow")
	title := T(lang, key+".title")
	var cards []string
	count := 0
	for i := range p.Entries {
		if p.Entries[i].Tier == tier {
			cards = append(cards, portfolioCard(root, &p.Entries[i], jekyll, lang))
			count++
		}
	}
	return fmt.Sprintf(`    <section class="od-section od-reveal">
      <p class="od-section__eyebrow">// %s</p>
      <h2 class="od-section__title">%s <span class="od-chip">%d</span></h2>
      <div class="pf-grid od-stagger">
%s
      </div>
    </section>`, esc(eyebrow), esc(title), count, strings.Join(cards, "\n"))
}

const portfolioSymbols = `  <svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">
    <symbol id="i-sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="M4.9 4.9l1.4 1.4"/><path d="M17.7 17.7l1.4 1.4"/><path d="M19.1 4.9l-1.4 1.4"/><path d="M6.3 17.7l-1.4 1.4"/></symbol>
    <symbol id="i-moon" viewBox="0 0 24 24"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></symbol>
  </svg>`

const portfolioStyle = `  <style>
    .od-icon{width:1.25em;height:1.25em;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;vertical-align:middle}
    .od-theme-toggle{display:inline-flex;align-items:center;justify-content:center;gap:var(--od-space-2);padding:var(--od-space-2) var(--od-space-3)}
    .od-theme-toggle .od-icon--sun{display:none}
    :root[data-theme="dark"] .od-theme-toggle .od-icon--sun{display:inline-block}
    :root[data-theme="dark"] .od-theme-toggle .od-icon--moon{display:none}
    @media (prefers-color-scheme:dark){:root:not([data-theme="light"]) .od-theme-toggle .od-icon--moon{display:none}:root:not([data-theme="light"]) .od-theme-toggle .od-icon--sun{display:inline-block}}
    .pf-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(280px,100%),1fr));gap:var(--od-space-6);align-items:stretch;}
    .od-product-card__tech{display:flex;flex-wrap:wrap;gap:var(--od-space-2);}
    .pf-card__blurb{font-size:var(--od-fs-base);line-height:var(--od-lh-normal);color:var(--od-text);margin:0 0 var(--od-space-4);}
    .pf-card__meta{display:flex;flex-wrap:wrap;gap:var(--od-space-2);}
    .pf-card__meta:empty{display:none;}
    .pf-card__actions{margin-top:auto;padding-top:var(--od-space-3);}
    .pf-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:var(--od-space-6);max-width:48rem;margin:var(--od-space-8) auto 0;}
    /* status badge extensions — OpenDesign tokens only (§11.4.162) */
    .od-badge--status--production,.od-badge--status--shipped,.od-badge--status--active,.od-badge--status--stable{background-color:var(--od-success);color:var(--od-on-accent);}
    .od-badge--status--scaffold,.od-badge--status--mixed{background-color:var(--od-surface-2);color:var(--od-text);}
    /* skip link stays keyboard-focusable but is excluded from the visible layout until focused */
    .od-skip-link{opacity:0;}
    .od-skip-link:focus{opacity:1;}
  </style>`

// portfolioMainInner renders the shared portfolio body — hero (with the
// download CTA + stats), the overview section, and the tier sections — used by
// both the self-contained and the Jekyll shells. dlHref is resolved by the
// caller for its link style.
func portfolioMainInner(p *Portfolio, helixCount int, dlHref, sections, lang string) string {
	return fmt.Sprintf(`    <section class="od-hero od-reveal">
      <p class="od-section__eyebrow">// %s</p>
      <h1 class="od-hero__title">%s</h1>
      <p class="od-hero__lede">%s</p>
      <div class="pf-hero__cta" style="display:flex;flex-wrap:wrap;gap:var(--od-space-3);justify-content:center;margin:0 0 var(--od-space-6)">
        <a class="od-btn od-btn--primary" href="%s" download>%s</a>
      </div>
      <div class="pf-stats">
        <div class="od-stat"><div class="od-stat__value">%d</div><div class="od-stat__label">%s</div></div>
        <div class="od-stat"><div class="od-stat__value">%d</div><div class="od-stat__label">%s</div></div>
        <div class="od-stat"><div class="od-stat__value">%d</div><div class="od-stat__label">%s</div></div>
      </div>
    </section>

    <section class="od-section od-reveal">
      <p class="od-section__eyebrow">// %s</p>
      <h2 class="od-section__title">%s</h2>
      <p class="pf-card__blurb" style="max-width:70ch">%s</p>
    </section>

%s`,
		esc(T(lang, "pf.eyebrow")), esc(T(lang, "pf.title")), esc(T(lang, "pf.lede")),
		dlHref, esc(T(lang, "pf.download")),
		p.Count, esc(T(lang, "pf.stat.products")),
		len(p.Tiers), esc(T(lang, "pf.stat.tiers")),
		helixCount, esc(T(lang, "pf.stat.helix")),
		esc(T(lang, "pf.overview.eyebrow")), esc(T(lang, "pf.overview.title")),
		esc(T(lang, "pf.summary")), sections)
}

func renderPortfolio(root string, p *Portfolio, site *Site, langs []string, lang string) string {
	helixCount := 0
	for i := range p.Entries {
		if p.Entries[i].Tier == "helix-primary" {
			helixCount++
		}
	}
	if site.Jekyll {
		return renderPortfolioJekyll(root, p, site, langs, lang, helixCount)
	}

	// Language-aware download wiring: the current page's language serves the
	// matching-language Portfolio PDF (Portfolio_<LANG>.pdf), and English is the
	// fallback. Localized portfolio pages live one directory deeper
	// (portfolio/<lang>/index.html) so the downloads/ path is one level further.
	// pfx = path from THIS page to the site root. EN portfolio is /portfolio/
	// (depth 1 → "../"); localized is /portfolio/<lang>/ (depth 2 → "../../").
	// Used for downloads, assets, motion, and the switcher script alike — a
	// depth-1 prefix on a depth-2 page 404s every asset (D1 regression).
	htmlLang := "en"
	pfx := "../"
	if lang != "" && lang != "en" {
		htmlLang = lang
		pfx = "../../"
	}
	htmlDir := "ltr"
	switch lang {
	case "ar", "fa", "he", "ur":
		htmlDir = "rtl"
	}
	dlHref := pfx + "downloads/Portfolio_" + strings.ToUpper(htmlLang) + ".pdf"

	var sections []string
	for _, tier := range p.Tiers {
		sections = append(sections, portfolioTierSection(root, p, tier, false, lang))
	}
	homeHref := "../index.html"
	if lang != "" && lang != "en" {
		homeHref = "../../" + lang + "/"
	}
	head := seoHead(site, langs, pageSEO{
		title:    T(lang, "pf.title") + " — " + site.Brand,
		desc:     T(lang, "pf.lede"),
		keywords: siteKeywords(site, lang),
		lang:     lang,
		enPath:   "portfolio/",
		ogType:   "website",
		jsonLD:   site.baseGraphLang(htmlLang),
		prefix:   pfx,
		cssName:  site.CSSName,
	})
	return fmt.Sprintf(`<!doctype html>
<html lang="%s" dir="%s">
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
  <header class="od-header">
    <a class="od-nav__link" href="%s" style="font-family:var(--od-font-display);font-weight:700">%s</a>
    <nav class="od-nav" aria-label="%s">
      <a class="od-nav__link" href="%s">%s</a>
      <a class="od-nav__link" href="#main">%s</a>
      %s
      <button class="od-btn od-btn--ghost od-theme-toggle" id="pf-theme-toggle" type="button" aria-label="%s">
        <svg class="od-icon od-icon--moon" aria-hidden="true"><use href="#i-moon"/></svg>
        <svg class="od-icon od-icon--sun" aria-hidden="true"><use href="#i-sun"/></svg>
      </button>
    </nav>
  </header>
%s

  <main id="main">
%s
  </main>

  <footer class="od-footer">© %s %s — %s</footer>
  <script>
    (function(){
      var btn=document.getElementById('pf-theme-toggle');
      if(!btn)return;
      function cur(){var a=document.documentElement.getAttribute('data-theme');if(a)return a;return (window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)?'dark':'light';}
      btn.addEventListener('click',function(){var n=cur()==='dark'?'light':'dark';document.documentElement.setAttribute('data-theme',n);try{localStorage.setItem('od-theme',n);}catch(e){}});
    })();
  </script>
%s
%s
%s
</body>
</html>
`,
		htmlLang, htmlDir,
		assetLinks(pfx, site.CSSName), head, portfolioStyle,
		esc(T(lang, "skip")),
		homeHref, esc(site.Brand),
		esc(T(lang, "aria.primaryNav")),
		homeHref, esc(T(lang, "nav.home")),
		esc(T(lang, "nav.portfolio")),
		odLangMount(),
		esc(T(lang, "toggle")),
		portfolioSymbols,
		portfolioMainInner(p, helixCount, dlHref, strings.Join(sections, "\n\n"), lang),
		copyrightYear(), esc(site.Brand), esc(T(lang, "footer.suffix")),
		backToTopButton(lang),
		motionScript(pfx),
		odSwitcher(site, langs, "portfolio", "portfolio/", pfx))
}

// renderPortfolioJekyll renders the portfolio page as a Jekyll document so it
// inherits the shared _layouts/default.html chrome (the SAME header/nav/theme/
// language switcher/downloads as the landing page). Only the OpenDesign portfolio
// body + its assets/styles live here; the header is a single source of truth.
func renderPortfolioJekyll(root string, p *Portfolio, site *Site, langs []string, lang string, helixCount int) string {
	dlLang := "EN"
	if lang != "" && lang != "en" {
		dlLang = strings.ToUpper(lang)
	}
	dlHref := "{{ '/downloads/Portfolio_" + dlLang + ".pdf' | relative_url }}"

	var sections []string
	for _, tier := range p.Tiers {
		sections = append(sections, portfolioTierSection(root, p, tier, true, lang))
	}
	inner := portfolioMainInner(p, helixCount, dlHref, strings.Join(sections, "\n\n"), lang)

	return fmt.Sprintf(`---
layout: default
lang: %s
title: %s
description: %s
seo_hreflang: %s
---

<!-- OpenDesign assets (fonts → brand → components → animations → overlays), linked from the page so the default layout head stays untouched. -->
%s
<script defer src="{{ '/assets/od/motion.js' | relative_url }}"></script>
<!-- window.MV_PAGE feeds the shared layout's language switcher (assets/js/main.js):
     choosing a language on the portfolio navigates to that language's portfolio
     page (/portfolio/<lang>/) so its translated BODY loads — not a chrome-only
     swap. (BUG #63) -->
<script>window.MV_PAGE=%s;</script>
%s
%s
%s

%s
`,
		htmlLang(lang),
		yamlQuote(T(lang, "pf.title")+" — "+site.Brand),
		yamlQuote(T(lang, "pf.lede")),
		yamlQuote(hreflangInline(site, langs, "portfolio/")),
		assetLinksJekyll(site.CSSName),
		mvPagePathsJSON("portfolio", "portfolio/", langs),
		portfolioSymbols,
		portfolioStyle,
		site.baseGraphLang(htmlLang(lang)),
		inner)
}
