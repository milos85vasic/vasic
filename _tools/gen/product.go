package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const productStyle = `  <style>
    .od-icon{width:1.25em;height:1.25em;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;vertical-align:middle}
    /* Accessible skip link: on-screen 1px (SR-reachable) instead of transformed off-screen; reveals on focus */
    .od-skip-link{position:absolute;top:0;left:0;transform:none;width:1px;height:1px;overflow:hidden;white-space:nowrap;clip:rect(0 0 0 0);clip-path:inset(50%);padding:0}
    .od-skip-link:focus{width:auto;height:auto;overflow:visible;clip:auto;clip-path:none;padding:var(--od-space-2) var(--od-space-4)}
    .od-brand{font-family:var(--od-font-display);font-weight:700;font-size:var(--od-fs-lg);color:var(--od-text);text-decoration:none}
    .od-header__actions{display:flex;align-items:center;gap:var(--od-space-4)}
    .od-theme-toggle{display:inline-flex;align-items:center;justify-content:center;gap:var(--od-space-2);padding:var(--od-space-2) var(--od-space-3)}
    .od-theme-toggle .od-icon--sun{display:none}
    :root[data-theme="dark"] .od-theme-toggle .od-icon--sun{display:inline-block}
    :root[data-theme="dark"] .od-theme-toggle .od-icon--moon{display:none}
    @media (prefers-color-scheme:dark){:root:not([data-theme="light"]) .od-theme-toggle .od-icon--moon{display:none}:root:not([data-theme="light"]) .od-theme-toggle .od-icon--sun{display:inline-block}}
    .od-meta-row{display:flex;flex-wrap:wrap;align-items:center;gap:var(--od-space-3);margin-bottom:var(--od-space-6)}
    .od-chip-row{display:flex;flex-wrap:wrap;gap:var(--od-space-2);margin-bottom:var(--od-space-6)}
    .od-h1-badges{display:inline-flex;flex-wrap:wrap;gap:var(--od-space-3);vertical-align:middle}
    .od-repo-list{list-style:none;padding:0;display:flex;flex-direction:column;gap:var(--od-space-2)}
    .od-repo-list a{display:inline-flex;align-items:center;gap:var(--od-space-2);overflow-wrap:anywhere;word-break:break-word}
    .od-diagram{border:1px dashed var(--od-border);border-radius:var(--od-radius-lg);background:var(--od-surface);padding:var(--od-space-10) var(--od-space-6);text-align:center;color:var(--od-text-muted)}
    .od-diagram__note{font-family:var(--od-font-mono);font-size:var(--od-fs-sm);color:var(--od-text-muted);margin:0}
    /* responsive media: never let an image/diagram cause horizontal overflow */
    img,svg{max-width:100%;height:auto}
    .od-product-media img{width:100%;height:auto;border-radius:var(--od-radius-lg)}
    /* narrow-viewport (≤320px) safety: break long tokens/bold runs so nothing
       forces horizontal overflow */
    .od-product-detail{overflow-wrap:anywhere}
    .od-product-detail p,.od-product-detail li,.od-product-detail strong,.od-product-detail code{overflow-wrap:anywhere;word-break:break-word}
    /* editorial intro: bold hook as tagline, short desc as lede (fix #5) */
    .od-product-detail__tagline{font-family:var(--od-font-display);font-size:var(--od-fs-xl);font-weight:700;line-height:var(--od-lh-tight);letter-spacing:var(--od-tracking-tight);color:var(--od-text);margin:0 0 var(--od-space-4)}
    .od-product-detail__lede{font-size:var(--od-fs-lg);line-height:var(--od-lh-normal);color:var(--od-text-muted);margin:0 0 var(--od-space-6)}
    .od-product-detail blockquote{border-inline-start:3px solid var(--od-accent);padding-inline-start:var(--od-space-4);margin:0 0 var(--od-space-4);color:var(--od-text-muted)}
    /* Accordion (disclosure) chrome for the deep product sections. The library
       (motion/animations.css) owns the chevron rotation, panel fade + reduced-
       motion neutralization; here we only style the trigger button + layout so it
       reads as an editorial heading, not a default button. GPU-safe: no animated
       width/height/box-shadow. */
    .od-accordion{margin-top:var(--od-space-8);border-top:1px solid var(--od-border)}
    .od-accordion__item{border-bottom:1px solid var(--od-border)}
    .od-accordion__heading{margin:0}
    .od-accordion__trigger{display:flex;align-items:center;justify-content:space-between;gap:var(--od-space-4);width:100%;padding:var(--od-space-5) 0;background:none;border:0;cursor:pointer;color:var(--od-text);text-align:start;font-family:var(--od-font-display);font-size:var(--od-fs-xl);font-weight:700;line-height:var(--od-lh-tight);letter-spacing:var(--od-tracking-tight)}
    .od-accordion__trigger:hover .od-accordion__label{color:var(--od-accent)}
    .od-accordion__trigger:focus-visible{outline:2px solid var(--od-accent);outline-offset:3px;border-radius:var(--od-radius-sm)}
    .od-accordion__label{transition:color var(--od-dur-fast,150ms) var(--od-ease-standard,ease)}
    .od-accordion__icon{flex:none;width:1.5em;height:1.5em;color:var(--od-text-muted)}
    .od-accordion__inner{padding:0 0 var(--od-space-6)}
    .od-accordion__inner>:first-child{margin-top:0}
  </style>`

const productSymbols = `  <svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">
    <symbol id="i-external" viewBox="0 0 24 24"><path d="M14 5h5v5"/><path d="M19 5l-9 9"/><path d="M19 13v6H5V5h6"/></symbol>
    <symbol id="i-arrow-right" viewBox="0 0 24 24"><path d="M4 12h16"/><path d="M14 6l6 6-6 6"/></symbol>
    <symbol id="i-sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="M4.9 4.9l1.4 1.4"/><path d="M17.7 17.7l1.4 1.4"/><path d="M19.1 4.9l-1.4 1.4"/><path d="M6.3 17.7l-1.4 1.4"/></symbol>
    <symbol id="i-moon" viewBox="0 0 24 24"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></symbol>
    <symbol id="i-chevron-down" viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></symbol>
  </svg>`

const productToggleScript = `<script>
  (function(){
    var btn=document.getElementById('od-theme-toggle');
    if(!btn)return;
    btn.addEventListener('click',function(){
      var d=document.documentElement;var cur=d.getAttribute('data-theme');
      var prefersDark=window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches;
      var next=cur==='dark'?'light':(cur==='light'?'dark':(prefersDark?'light':'dark'));
      d.setAttribute('data-theme',next);
      try{localStorage.setItem('od-theme',next);}catch(e){}
    });
  })();
</script>`

var xmlDeclRe = regexp.MustCompile(`(?i)^\s*<\?xml[^>]*\?>\s*`)

func repoLabel(url string) string {
	s := strings.TrimPrefix(url, "https://github.com/")
	s = strings.TrimPrefix(s, "http://github.com/")
	return strings.TrimSuffix(s, "/")
}

// diagramFigure returns the injected architecture figure for a slug, or "" if none.
func diagramFigure(root, slug, lang string) string {
	p := filepath.Join(root, "design-system", "diagrams", slug+".svg")
	b, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	svg := xmlDeclRe.ReplaceAllString(string(b), "")
	svg = strings.TrimRight(svg, "\n")
	return fmt.Sprintf(`      <figure class="od-diagram" data-slug="%s">
%s
<figcaption class="od-section__eyebrow" style="margin-top:var(--od-space-2)">// %s</figcaption>
</figure>`, slug, svg, esc(T(lang, "prod.architecture")))
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

// renderProduct renders one product detail page for a site in language `lang`.
// The BODY is sourced from the localized _content_<lang>/ translation when one
// exists (read-only; that doc-translation surface is owned elsewhere), else the
// EN source. All surrounding chrome + SEO is localized via T(lang, …).
func renderProduct(root string, site *Site, e *PortfolioEntry, langs []string, lang string) (string, error) {
	mdPath := filepath.Join(root, e.Source)
	if lang != "" && lang != "en" {
		alt := filepath.Join(root, strings.Replace(e.Source, "_content/", "_content_"+lang+"/", 1))
		if _, statErr := os.Stat(alt); statErr == nil {
			mdPath = alt
		}
	}
	md, err := os.ReadFile(mdPath)
	if err != nil {
		return "", fmt.Errorf("read %s: %w", e.Source, err)
	}
	_, body, err := parseFrontmatter(string(md))
	if err != nil {
		return "", fmt.Errorf("frontmatter %s: %w", e.Source, err)
	}

	var chips strings.Builder
	for _, t := range e.Tech {
		chips.WriteString(`<span class="od-chip">` + esc(t) + `</span>`)
	}

	var repos strings.Builder
	for _, r := range e.Repos {
		repos.WriteString(fmt.Sprintf(
			`        <li><a href="%s" rel="noopener noreferrer" target="_blank">%s <svg class="od-icon" aria-hidden="true"><use href="#i-external"/></svg></a></li>`+"\n",
			esc(r), esc(repoLabel(r))))
	}

	figure := diagramFigure(root, e.Slug, lang)
	figureBlock := ""
	if figure != "" {
		figureBlock = "\n" + figure + "\n"
	}

	bodyHTML := renderProductBody(body, e.Slug)

	title := e.Name + " — " + site.Brand
	desc := firstNonEmpty(e.Summary, e.Tagline, e.Name+" — "+site.Brand+" product.")
	jsonLD := site.baseGraphLang(htmlLang(lang), site.softwareApplicationNodeLang(e, lang))

	// Shared product body (identical markup for both shells). Only the surrounding
	// chrome differs: the self-contained shell carries its own <header>; the Jekyll
	// shell inherits the shared _layouts/default.html header (one source of truth).
	article := fmt.Sprintf(`    <article class="od-section od-product-detail od-reveal">
      <p class="od-section__eyebrow">// %s: %s · %s %d</p>
      <h1>%s <span class="od-h1-badges"><span class="od-badge--status od-badge--status--%s">%s</span><span class="od-tag--license">%s: %s</span></span></h1>

      <div class="od-chip-row">%s</div>

      <h2>%s</h2>
      <ul class="od-repo-list">
%s      </ul>
%s
%s
    </article>`,
		esc(T(lang, "prod.tier")), esc(e.Tier), esc(T(lang, "prod.order")), e.Order,
		esc(e.Name), esc(e.Status), esc(e.Status), esc(T(lang, "prod.license")), esc(e.License),
		chips.String(),
		esc(T(lang, "prod.source")),
		repos.String(),
		figureBlock,
		bodyHTML,
	)

	if site.Jekyll {
		return renderProductJekyll(site, langs, "products/"+e.Slug+".html", title, desc, jsonLD, article, lang), nil
	}

	// Path from THIS page to the site root. EN product pages live at
	// /products/<slug>.html (depth 1 → "../"); localized ones live one level
	// deeper at /products/<lang>/<slug>.html (depth 2 → "../../"). Using the
	// depth-1 prefix on a depth-2 page 404s every asset (D1 regression).
	pfx := "../"
	if lang != "" && lang != "en" {
		pfx = "../../"
	}

	head := seoHead(site, langs, pageSEO{
		title:    title,
		desc:     desc,
		keywords: siteKeywords(site, lang),
		lang:     lang,
		enPath:   "products/" + e.Slug + ".html",
		ogType:   "article",
		jsonLD:   jsonLD,
		prefix:   pfx,
		cssName:  site.CSSName,
	})

	// Home / Products link back to the localized landing page for non-EN.
	homeHref := "../index.html"
	if lang != "" && lang != "en" {
		homeHref = "../../" + lang + "/"
	}
	var b strings.Builder
	fmt.Fprintf(&b, `<!doctype html>
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
%s
  <header class="od-header">
    <a class="od-brand" href="%s">%s</a>
    <div class="od-header__actions">
      <nav class="od-nav" aria-label="%s">
        <a class="od-nav__link" href="%s">%s</a>
        <a class="od-nav__link" href="%s#products">%s</a>
      </nav>
      %s
      <button id="od-theme-toggle" class="od-btn od-btn--ghost od-theme-toggle" type="button" aria-label="%s">
        <svg class="od-icon od-icon--moon" aria-hidden="true"><use href="#i-moon"/></svg>
        <svg class="od-icon od-icon--sun" aria-hidden="true"><use href="#i-sun"/></svg>
      </button>
    </div>
  </header>

  <main id="main">
%s
  </main>

  <footer class="od-footer">© 2026 %s — %s.</footer>

%s
%s
%s
%s
</body>
</html>
`,
		htmlLang(lang), htmlDir(lang),
		assetLinks(pfx, site.CSSName),
		head,
		productStyle,
		esc(T(lang, "skip")),
		productSymbols,
		homeHref, esc(site.Brand),
		esc(T(lang, "aria.primaryNav")),
		homeHref, esc(T(lang, "nav.home")),
		homeHref, esc(T(lang, "nav.products")),
		odLangMount(),
		esc(T(lang, "toggle")),
		article,
		esc(site.Brand), esc(T(lang, "footer.suffix")),
		backToTopButton(lang),
		productToggleScript,
		motionScript(pfx),
		odSwitcher(site, langs, "product", "products/"+e.Slug+".html", pfx),
	)
	return b.String(), nil
}

// renderProductJekyll renders a product detail page as a Jekyll document so it
// inherits the shared _layouts/default.html chrome (the SAME header/nav/theme/
// language switcher/downloads as the landing page). jekyll-seo-tag consumes the
// title/description front matter; the SoftwareApplication JSON-LD is injected in
// the body (a valid location for ld+json).
func renderProductJekyll(site *Site, langs []string, enPath, title, desc, jsonLD, article, lang string) string {
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
     choosing a language on this product page navigates to that language's product
     page (/products/<lang>/<slug>.html) so its translated BODY loads — not a
     chrome-only swap. (BUG #63) -->
<script>window.MV_PAGE=%s;</script>
%s
%s
%s

%s
`,
		htmlLang(lang),
		yamlQuote(title),
		yamlQuote(desc),
		yamlQuote(hreflangInline(site, langs, enPath)),
		assetLinksJekyll(site.CSSName),
		mvPagePathsJSON("product", enPath, langs),
		productSymbols,
		productStyle,
		jsonLD,
		article,
	)
}
