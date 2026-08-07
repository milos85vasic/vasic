package main

// backToTopButton is the shared floating "back to top" control emitted just
// before </body> in every self-contained shell. It is hidden AND non-focusable
// (pointer-events:none) until motion.js adds `.is-visible` after the scroll
// threshold; clicking it smooth-scrolls to the top (instant under reduced
// motion). An inline up-arrow <svg> keeps it self-contained across all shells
// regardless of which symbol sprite the page emits. The aria-label is localized
// server-side per page language; data-i18n-aria lets od-i18n.js re-localize it on
// a client-side language switch (home).
func backToTopButton(lang string) string {
	return `  <button class="od-to-top" type="button" data-i18n-aria="aria.backToTop" aria-label="` + esc(T(lang, "aria.backToTop")) + `"><svg class="od-icon" aria-hidden="true" focusable="false" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V5"/><path d="M5 12l7-7 7 7"/></svg></button>`
}

const vasicToggleScript = productToggleScript

const vasicSymbols = `  <svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">
    <symbol id="i-external" viewBox="0 0 24 24"><path d="M14 5h5v5"/><path d="M19 5l-9 9"/><path d="M19 13v6H5V5h6"/></symbol>
    <symbol id="i-arrow-right" viewBox="0 0 24 24"><path d="M4 12h16"/><path d="M14 6l6 6-6 6"/></symbol>
    <symbol id="i-check" viewBox="0 0 24 24"><path d="M4 12l5 5L20 6"/></symbol>
    <symbol id="i-mail" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></symbol>
    <symbol id="i-sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="M4.9 4.9l1.4 1.4"/><path d="M17.7 17.7l1.4 1.4"/><path d="M19.1 4.9l-1.4 1.4"/><path d="M6.3 17.7l-1.4 1.4"/></symbol>
    <symbol id="i-moon" viewBox="0 0 24 24"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></symbol>
  </svg>`

const vasicHeadExtras = `  <style>
    .od-icon{width:1.25em;height:1.25em;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;vertical-align:middle}
    /* Accessible skip link: on-screen 1px (SR-reachable) instead of transformed off-screen; reveals on focus */
    .od-skip-link{position:absolute;top:0;left:0;transform:none;width:1px;height:1px;overflow:hidden;white-space:nowrap;clip:rect(0 0 0 0);clip-path:inset(50%);padding:0}
    .od-skip-link:focus{width:auto;height:auto;overflow:visible;clip:auto;clip-path:none;padding:var(--od-space-2) var(--od-space-4)}
    .od-brand{display:inline-flex;align-items:center;gap:var(--od-space-2);font-family:var(--od-font-display);font-weight:700;font-size:var(--od-fs-lg);color:var(--od-text);text-decoration:none}
    .od-brand__logo{width:28px;height:28px;object-fit:contain;background:#fff;border:1px solid var(--od-border);border-radius:var(--od-radius-md);padding:2px;flex:none}
    /* restored hero logo lockup — rounded white chip reads in light + dark (fix #3) */
    .vd-hero__logo{display:flex;justify-content:center;margin-bottom:var(--od-space-6)}
    .vd-hero__logo img{width:112px;height:112px;object-fit:contain;background:#fff;border:1px solid var(--od-border);border-radius:var(--od-radius-xl);padding:var(--od-space-3);box-shadow:var(--od-shadow-md)}
    /* header/nav wrap so 375px never overflows horizontally */
    .od-header{flex-wrap:wrap;row-gap:var(--od-space-3)}
    .od-nav{flex-wrap:wrap;align-items:center}
    .od-header__actions{display:flex;flex-wrap:wrap;align-items:center;gap:var(--od-space-4)}
    .od-theme-toggle{display:inline-flex;align-items:center;justify-content:center;gap:var(--od-space-2);padding:var(--od-space-2) var(--od-space-3)}
    .od-theme-toggle .od-icon--sun{display:none}
    :root[data-theme="dark"] .od-theme-toggle .od-icon--sun{display:inline-block}
    :root[data-theme="dark"] .od-theme-toggle .od-icon--moon{display:none}
    @media (prefers-color-scheme:dark){:root:not([data-theme="light"]) .od-theme-toggle .od-icon--moon{display:none}:root:not([data-theme="light"]) .od-theme-toggle .od-icon--sun{display:inline-block}}
    img,svg{max-width:100%}
    .vd-hero__cta{display:flex;flex-wrap:wrap;justify-content:center;gap:var(--od-space-3);margin-top:var(--od-space-6)}
    .vd-lede{font-size:var(--od-fs-lg);line-height:var(--od-lh-normal);color:var(--od-text);max-width:72ch;margin:0 0 var(--od-space-4)}
    .vd-muted{color:var(--od-text-muted)}
    .vd-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(260px,100%),1fr));gap:var(--od-space-6);align-items:stretch}
    .vd-grid--two{grid-template-columns:repeat(auto-fit,minmax(min(300px,100%),1fr))}
    .vd-card__blurb{font-size:var(--od-fs-base);line-height:var(--od-lh-normal);color:var(--od-text);margin:0 0 var(--od-space-4)}
    .vd-card__actions{margin-top:auto;padding-top:var(--od-space-3)}
    .od-product-card__tech{display:flex;flex-wrap:wrap;gap:var(--od-space-2)}
    /* grid cards must be allowed to shrink below their min-content (≤320px) */
    .vd-grid>*,.od-product-card{min-width:0}
    .od-product-card__title{overflow-wrap:anywhere}
    .vd-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:var(--od-space-6);max-width:56rem;margin:var(--od-space-8) auto 0}
    .vd-contact{display:flex;flex-wrap:wrap;gap:var(--od-space-8)}
    .vd-contact a{color:var(--od-accent)}
    .od-section__lede{font-size:var(--od-fs-lg);color:var(--od-text-muted);max-width:72ch;margin:0 0 var(--od-space-6)}
    /* status badge extensions — OpenDesign tokens only (§11.4.162) */
    .od-badge--status--production,.od-badge--status--shipped,.od-badge--status--active,.od-badge--status--stable{background-color:var(--od-success);color:var(--od-on-accent)}
    .od-badge--status--scaffold,.od-badge--status--mixed{background-color:var(--od-surface-2);color:var(--od-text)}
  </style>`

const mvSymbols = `<svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">
  <symbol id="i-external" viewBox="0 0 24 24"><path d="M14 5h5v5"/><path d="M19 5l-9 9"/><path d="M19 13v6H5V5h6"/></symbol>
  <symbol id="i-arrow-right" viewBox="0 0 24 24"><path d="M4 12h16"/><path d="M14 6l6 6-6 6"/></symbol>
  <symbol id="i-mail" viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/></symbol>
  <symbol id="i-download" viewBox="0 0 24 24"><path d="M12 3v12"/><path d="M7 10l5 5 5-5"/><path d="M4 20h16"/></symbol>
</svg>`

const mvHeadStyle = `<style>
  .od-icon{width:1.25em;height:1.25em;fill:none;stroke:currentColor;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;vertical-align:middle}
  .mvx-hero__cta{display:flex;flex-wrap:wrap;gap:var(--od-space-3);margin-top:var(--od-space-6);justify-content:center}
  /* restored portrait beside the hero copy (fix #2) */
  .mvx-hero__grid{display:grid;grid-template-columns:1fr;gap:var(--od-space-8);align-items:center;text-align:left}
  .mvx-hero__body{min-width:0}
  .mvx-hero__body .mvx-hero__cta{justify-content:flex-start}
  .mvx-hero__portrait{margin:0;justify-self:center;position:relative;isolation:isolate}
  .mvx-hero__portrait img{position:relative;z-index:1;width:min(300px,72vw);height:auto;aspect-ratio:4/5;object-fit:cover;border-radius:var(--od-radius-xl);border:1px solid var(--od-border);box-shadow:var(--od-shadow-lg);display:block}
  /* restored crimson corner accents (#a31e39 via --od-accent) — brand framing on the
     portrait; theme-adaptive (lighter crimson in dark), static (no motion). */
  .mvx-hero__portrait::before,.mvx-hero__portrait::after{content:"";position:absolute;z-index:2;width:clamp(38px,11vw,60px);height:clamp(38px,11vw,60px);pointer-events:none;opacity:.65}
  .mvx-hero__portrait::after{top:-9px;right:-9px;border-top:2px solid var(--od-accent);border-right:2px solid var(--od-accent);border-top-right-radius:var(--od-radius-xl)}
  .mvx-hero__portrait::before{bottom:-9px;left:-9px;border-bottom:2px solid var(--od-accent);border-left:2px solid var(--od-accent);border-bottom-left-radius:var(--od-radius-xl)}
  @media(min-width:768px){.mvx-hero__grid{grid-template-columns:minmax(0,1.5fr) minmax(0,0.9fr)}}
  .mvx-lede{font-size:var(--od-fs-lg);line-height:var(--od-lh-normal);color:var(--od-text);max-width:72ch;margin:0 0 var(--od-space-4)}
  .mvx-muted{color:var(--od-text-muted)}
  .mvx-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(260px,100%),1fr));gap:var(--od-space-6);align-items:stretch}
  .mvx-grid--two{grid-template-columns:repeat(auto-fit,minmax(min(300px,100%),1fr))}
  .mvx-card__blurb{font-size:var(--od-fs-base);line-height:var(--od-lh-normal);color:var(--od-text);margin:0 0 var(--od-space-4)}
  .mvx-card__actions{margin-top:auto;padding-top:var(--od-space-3)}
  .od-product-card__tech{display:flex;flex-wrap:wrap;gap:var(--od-space-2)}
  /* grid cards must be allowed to shrink below their min-content (≤320px) */
  .mvx-grid>*,.od-product-card{min-width:0}
  .od-product-card__title{overflow-wrap:anywhere}
  .mvx-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:var(--od-space-6);max-width:56rem;margin:var(--od-space-8) auto 0}
  .od-section__lede{font-size:var(--od-fs-lg);color:var(--od-text-muted);max-width:72ch;margin:0 0 var(--od-space-6)}
  .mvx-contact{display:flex;flex-wrap:wrap;gap:var(--od-space-8)}
  .mvx-contact a{color:var(--od-accent)}
  img,svg{max-width:100%}
  /* status badge extensions — OpenDesign tokens only (§11.4.162) */
  .od-badge--status--production,.od-badge--status--shipped,.od-badge--status--active,.od-badge--status--stable{background-color:var(--od-success);color:var(--od-on-accent)}
  .od-badge--status--scaffold,.od-badge--status--mixed{background-color:var(--od-surface-2);color:var(--od-text)}
</style>`
