package main

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
    .od-brand{font-family:var(--od-font-display);font-weight:700;font-size:var(--od-fs-lg);color:var(--od-text);text-decoration:none}
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
    .vd-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:var(--od-space-6);align-items:stretch}
    .vd-grid--two{grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
    .vd-card__blurb{font-size:var(--od-fs-base);line-height:var(--od-lh-normal);color:var(--od-text);margin:0 0 var(--od-space-4)}
    .vd-card__actions{margin-top:auto;padding-top:var(--od-space-3)}
    .od-product-card__tech{display:flex;flex-wrap:wrap;gap:var(--od-space-2)}
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
  .mvx-lede{font-size:var(--od-fs-lg);line-height:var(--od-lh-normal);color:var(--od-text);max-width:72ch;margin:0 0 var(--od-space-4)}
  .mvx-muted{color:var(--od-text-muted)}
  .mvx-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:var(--od-space-6);align-items:stretch}
  .mvx-grid--two{grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
  .mvx-card__blurb{font-size:var(--od-fs-base);line-height:var(--od-lh-normal);color:var(--od-text);margin:0 0 var(--od-space-4)}
  .mvx-card__actions{margin-top:auto;padding-top:var(--od-space-3)}
  .od-product-card__tech{display:flex;flex-wrap:wrap;gap:var(--od-space-2)}
  .mvx-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:var(--od-space-6);max-width:56rem;margin:var(--od-space-8) auto 0}
  .od-section__lede{font-size:var(--od-fs-lg);color:var(--od-text-muted);max-width:72ch;margin:0 0 var(--od-space-6)}
  .mvx-contact{display:flex;flex-wrap:wrap;gap:var(--od-space-8)}
  .mvx-contact a{color:var(--od-accent)}
  img,svg{max-width:100%}
  /* status badge extensions — OpenDesign tokens only (§11.4.162) */
  .od-badge--status--production,.od-badge--status--shipped,.od-badge--status--active,.od-badge--status--stable{background-color:var(--od-success);color:var(--od-on-accent)}
  .od-badge--status--scaffold,.od-badge--status--mixed{background-color:var(--od-surface-2);color:var(--od-text)}
</style>`
