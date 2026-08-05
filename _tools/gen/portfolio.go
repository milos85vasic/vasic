package main

import (
	"fmt"
	"regexp"
	"strings"
)

var licHideRe = regexp.MustCompile(`(?i)^(unverified|tbd)`)

type tierMeta struct{ eyebrow, title string }

var portfolioTierMeta = map[string]tierMeta{
	"helix-primary":          {"// tier 1 — flagship", "Helix family & LLM infrastructure"},
	"vasic-util-secondary":   {"// tier 2 — utilities", "Vasic Digital utilities"},
	"serverfactory-tertiary": {"// tier 3 — heritage", "Server Factory"},
}

const portfolioLede = "A unified, evidence-based portfolio of the Helix family, vasic-digital utilities, and the Server Factory toolchain."
const portfolioSummary = "One fleet: large product applications on top of dozens of small, decoupled, independently-tested modules — governed by a shared engineering Constitution and verified by anti-bluff QA. The dominant language is Go, with Kotlin/KMP, TypeScript/React, Python, Swift, and Shell where they fit best. The unifying thesis: a feature is done only when a real user can use it and there is captured evidence to prove it."

func portfolioCard(e *PortfolioEntry) string {
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
	blurb := e.Tagline
	if blurb == "" {
		blurb = e.Summary
	}
	return fmt.Sprintf(`        <article class="od-card od-product-card" style="padding:var(--od-space-6)">
          <h3 class="od-product-card__title">%s <span class="od-badge--status od-badge--status--%s">%s</span></h3>
          <div class="od-product-card__tech">%s</div>
          <p class="pf-card__blurb">%s</p>
          <div class="pf-card__meta">%s</div>
          <div class="pf-card__actions"><a class="od-btn od-btn--secondary" href="../products/%s.html">Read more</a></div>
        </article>`,
		esc(e.Name), esc(e.Status), esc(e.Status),
		chips.String(), esc(blurb), lic, esc(e.Slug))
}

func portfolioTierSection(p *Portfolio, tier string) string {
	meta := portfolioTierMeta[tier]
	var cards []string
	count := 0
	for i := range p.Entries {
		if p.Entries[i].Tier == tier {
			cards = append(cards, portfolioCard(&p.Entries[i]))
			count++
		}
	}
	return fmt.Sprintf(`    <section class="od-section">
      <p class="od-section__eyebrow">%s</p>
      <h2 class="od-section__title">%s <span class="od-chip">%d</span></h2>
      <div class="pf-grid">
%s
      </div>
    </section>`, esc(meta.eyebrow), esc(meta.title), count, strings.Join(cards, "\n"))
}

const portfolioStyle = `  <style>
    .pf-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:var(--od-space-6);align-items:stretch;}
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

func renderPortfolio(p *Portfolio, site *Site) string {
	var sections []string
	for _, tier := range p.Tiers {
		sections = append(sections, portfolioTierSection(p, tier))
	}
	helixCount := 0
	for i := range p.Entries {
		if p.Entries[i].Tier == "helix-primary" {
			helixCount++
		}
	}
	return fmt.Sprintf(`<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>Portfolio — %s</title>
  <meta name="description" content="%s"/>
  <link rel="stylesheet" href="%s"/>
  <script>(function(){try{var t=localStorage.getItem('od-theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t);}}catch(e){}})();</script>
%s
</head>
<body>
  <a class="od-skip-link" href="#main">Skip to content</a>
  <header class="od-header">
    <a class="od-nav__link" href="../index.html" style="font-family:var(--od-font-display);font-weight:700">%s</a>
    <nav class="od-nav">
      <a class="od-nav__link" href="../index.html">Home</a>
      <a class="od-nav__link" href="#main">Portfolio</a>
      <button class="od-btn od-btn--ghost" id="pf-theme-toggle" type="button" aria-label="Toggle color theme">Theme</button>
    </nav>
  </header>

  <main id="main">
    <section class="od-hero">
      <p class="od-section__eyebrow">// unified portfolio</p>
      <h1 class="od-hero__title">Portfolio</h1>
      <p class="od-hero__lede">%s</p>
      <div class="pf-stats">
        <div class="od-stat"><div class="od-stat__value">%d</div><div class="od-stat__label">Products</div></div>
        <div class="od-stat"><div class="od-stat__value">3</div><div class="od-stat__label">Tiers</div></div>
        <div class="od-stat"><div class="od-stat__value">%d</div><div class="od-stat__label">Helix products</div></div>
      </div>
    </section>

    <section class="od-section">
      <p class="od-section__eyebrow">// overview</p>
      <h2 class="od-section__title">One fleet, one discipline</h2>
      <p class="pf-card__blurb" style="max-width:70ch">%s</p>
    </section>

%s
  </main>

  <footer class="od-footer">© 2026 %s — built on the OpenDesign system</footer>
  <script>
    (function(){
      var btn=document.getElementById('pf-theme-toggle');
      if(!btn)return;
      function cur(){var a=document.documentElement.getAttribute('data-theme');if(a)return a;return (window.matchMedia&&window.matchMedia('(prefers-color-scheme: dark)').matches)?'dark':'light';}
      btn.addEventListener('click',function(){var n=cur()==='dark'?'light':'dark';document.documentElement.setAttribute('data-theme',n);try{localStorage.setItem('od-theme',n);}catch(e){}});
    })();
  </script>
</body>
</html>
`,
		esc(site.Brand), esc(portfolioLede), site.PortfolioCSS, portfolioStyle,
		esc(site.Brand), esc(portfolioLede), p.Count, helixCount, esc(portfolioSummary),
		strings.Join(sections, "\n\n"), esc(site.Brand))
}
