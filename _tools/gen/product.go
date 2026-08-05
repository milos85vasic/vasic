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
  </style>`

const productSymbols = `  <svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">
    <symbol id="i-external" viewBox="0 0 24 24"><path d="M14 5h5v5"/><path d="M19 5l-9 9"/><path d="M19 13v6H5V5h6"/></symbol>
    <symbol id="i-arrow-right" viewBox="0 0 24 24"><path d="M4 12h16"/><path d="M14 6l6 6-6 6"/></symbol>
    <symbol id="i-sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="M4.9 4.9l1.4 1.4"/><path d="M17.7 17.7l1.4 1.4"/><path d="M19.1 4.9l-1.4 1.4"/><path d="M6.3 17.7l-1.4 1.4"/></symbol>
    <symbol id="i-moon" viewBox="0 0 24 24"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></symbol>
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
func diagramFigure(root, slug string) string {
	p := filepath.Join(root, "design-system", "diagrams", slug+".svg")
	b, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	svg := xmlDeclRe.ReplaceAllString(string(b), "")
	svg = strings.TrimRight(svg, "\n")
	return fmt.Sprintf(`      <figure class="od-diagram" data-slug="%s">
%s
<figcaption class="od-section__eyebrow" style="margin-top:var(--od-space-2)">// architecture</figcaption>
</figure>`, slug, svg)
}

// renderProduct renders one product detail page for a site.
func renderProduct(root string, site *Site, e *PortfolioEntry) (string, error) {
	mdPath := filepath.Join(root, e.Source)
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

	figure := diagramFigure(root, e.Slug)
	figureBlock := ""
	if figure != "" {
		figureBlock = "\n" + figure + "\n"
	}

	bodyHTML := renderBody(body)

	var b strings.Builder
	fmt.Fprintf(&b, `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>%s — %s</title>
<meta name="description" content="%s — %s · %s product."/>
<script>(function(){try{var t=localStorage.getItem('od-theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t);}}catch(e){}})();</script>
<link rel="stylesheet" href="../assets/od/%s.css"/>
%s
</head>
<body>
<a class="od-skip-link" href="#main">Skip to content</a>
%s
  <header class="od-header">
    <a class="od-brand" href="../index.html">%s</a>
    <div class="od-header__actions">
      <nav class="od-nav" aria-label="Primary">
        <a class="od-nav__link" href="../index.html">Home</a>
        <a class="od-nav__link" href="../index.html#products">Products</a>
      </nav>
      <button id="od-theme-toggle" class="od-btn od-btn--ghost od-theme-toggle" type="button" aria-label="Toggle light or dark theme">
        <svg class="od-icon od-icon--moon" aria-hidden="true"><use href="#i-moon"/></svg>
        <svg class="od-icon od-icon--sun" aria-hidden="true"><use href="#i-sun"/></svg>
      </button>
    </div>
  </header>

  <main id="main">
    <article class="od-section od-product-detail">
      <p class="od-section__eyebrow">// tier: %s · order %d</p>
      <h1>%s <span class="od-h1-badges"><span class="od-badge--status od-badge--status--%s">%s</span><span class="od-tag--license">license: %s</span></span></h1>

      <div class="od-chip-row">%s</div>

      <h2>Source</h2>
      <ul class="od-repo-list">
%s      </ul>
%s
%s
    </article>
  </main>

  <footer class="od-footer">© 2026 %s — built on the OpenDesign system.</footer>

%s
</body>
</html>
`,
		esc(e.Name), esc(site.Brand),
		esc(e.Name), esc(e.Status), esc(site.Brand),
		site.CSSName,
		productStyle,
		productSymbols,
		esc(site.Brand),
		esc(e.Tier), e.Order,
		esc(e.Name), esc(e.Status), esc(e.Status), esc(e.License),
		chips.String(),
		repos.String(),
		figureBlock,
		bodyHTML,
		esc(site.Brand),
		productToggleScript,
	)
	return b.String(), nil
}
