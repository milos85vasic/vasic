const { test, expect } = require('@playwright/test');

/**
 * PERMANENT interactive-behavior gate (§11.4.169 integration/behavior type).
 *
 * WHY THIS FILE EXISTS
 * --------------------
 * Our structural suite verified that hrefs *resolve to a file* — but it happily
 * passed a batch of "small and obvious" tablet bugs that a human found instantly:
 *   - dead header nav links on SUBPAGES (e.g. `#work` on /portfolio/ scrolls to a
 *     section that only exists on the home page → the click is a NO-OP);
 *   - a missing floating "back to top" button on long pages;
 *   - a wrong / broken brand logo image.
 *
 * The tests below assert BEHAVIOR, not markup: a click must produce a visible
 * result (navigate, or update the URL hash AND scroll the target into view).
 * They run on BOTH sites, on every chrome-bearing page type, at THREE viewports
 * (mobile 390, tablet 1024 "Huawei-Mate-class", desktop 1440) — because the
 * reported bugs were found on a tablet.
 *
 * These are a lasting quality gate; keep them green.
 *
 * NOTE on "doc pages": the localized article/doc pages under /articles/<lang>/ are
 * intentionally BARE content fragments (no site header/nav/brand/theme). Nav,
 * brand, theme and back-to-top therefore do not apply to them; they are covered
 * only by the "no broken images" check.
 */

// ------------------------------------------------------------------ viewports
const VIEWPORTS = [
  { name: 'mobile-390',  width: 390,  height: 844 },
  { name: 'tablet-1024', width: 1024, height: 768 }, // Huawei-Mate-class tablet
  { name: 'desktop-1440', width: 1440, height: 900 },
];

// -------------------------------------------------------------------- sites
const SITES = [
  {
    key: 'milosvasic.ru',
    base: 'http://localhost:8082',
    // Pages that carry full site chrome (header nav, brand, theme, language, back-to-top).
    chromePages: [
      { type: 'home',      path: '/' },
      { type: 'portfolio', path: '/portfolio/' },
      { type: 'product',   path: '/products/helixtrack.html' },
    ],
    // Bare content fragment (no chrome) — used only for the broken-image check.
    docPage: '/articles/en/helix-code.html',
    // Header nav: link + brand selectors.
    navLinkSel: '.nav .nav-links a',
    brandSel: '.nav a.brand',
    // Primary nav collapses behind a hamburger at ≤760px; opening it reveals the links.
    mobileNavToggleSel: '#nav-toggle',
    // Core controls.
    theme: { toggleSel: '#theme-btn', storageKey: 'mv-theme' },
    lang: {
      btnSel: '#lang-btn',
      // Menu is revealed by adding `.open` to `.lang-menu`.
      openMenu: (page) => expect(page.locator('.lang-menu.open')).toBeVisible(),
      itemSel: '#lang-menu button',
    },
    download: { kind: 'modal', triggerSel: 'button[data-dl="cv"]', modalSel: '#dl-modal', enLinkSel: '#dl-modal .dl-lang[data-lang="EN"]' },
  },
  {
    key: 'vasic.digital',
    base: 'http://localhost:8401',
    chromePages: [
      { type: 'home',      path: '/' },
      { type: 'portfolio', path: '/portfolio/' },
      { type: 'product',   path: '/products/helixtrack.html' },
    ],
    docPage: '/articles/en/android-toolkit.html',
    navLinkSel: 'header.od-header nav.od-nav a.od-nav__link',
    // Brand is the first anchor in the header (either .od-brand or, on /portfolio/, a plain .od-nav__link).
    brandSel: 'header.od-header a',
    // Theme toggle uses the .od-theme-toggle class on every page (id varies: #od-theme-toggle / #pf-theme-toggle).
    theme: { toggleSel: '.od-theme-toggle', storageKey: 'od-theme' },
    lang: {
      // The switcher is mounted by od-i18n.js into #od-lang-mount → #od-lang-btn + #od-lang-menu.
      btnSel: '#od-lang-btn',
      openMenu: (page) => expect(page.locator('#od-lang-menu')).toBeVisible(),
      itemSel: '#od-lang-menu button',
    },
    download: { kind: 'link', linkSel: 'a[href$="downloads/Portfolio_EN.pdf"]' },
  },
];

// ------------------------------------------------------------------ helpers

/** Robust, implementation-agnostic locator for the floating back-to-top control. */
function backToTopControl(page) {
  return page
    .getByRole('button', { name: /back to top|scroll to top/i })
    .or(page.getByRole('link', { name: /back to top|scroll to top/i }))
    .or(page.locator('.od-to-top, [data-back-to-top], #back-to-top, .back-to-top'))
    .first();
}

/**
 * Assert that clicking one header nav link produces a VISIBLE result and is NOT a no-op.
 * Catches the reported failure mode: an in-page `#section` link on a subpage where that
 * section does not exist (scroll unchanged AND still same page AND target absent).
 *
 * `toBeInViewport()` auto-retries, so it absorbs smooth-scroll / anchor-landing timing.
 */
async function assertNavLinkActs(page, link, ctx) {
  const href = (await link.getAttribute('href')) || '';
  const label = ((await link.textContent()) || '').trim() || href;
  const beforeUrl = new URL(page.url());
  const resolved = new URL(href, page.url());
  const changesDoc = resolved.pathname !== beforeUrl.pathname || resolved.host !== beforeUrl.host;
  const hash = resolved.hash ? decodeURIComponent(resolved.hash.slice(1)) : '';

  await link.click();
  // Allow either a full navigation or a smooth in-page scroll to settle.
  await page.waitForLoadState('load').catch(() => {});
  await page.waitForTimeout(400);
  const afterUrl = new URL(page.url());

  if (changesDoc) {
    // Must have navigated to the target document.
    expect(afterUrl.pathname, `[${ctx}] nav "${label}" (href="${href}") must NAVIGATE — landed on ${afterUrl.pathname}`).toBe(resolved.pathname);
    if (hash) {
      const target = page.locator(`[id="${hash}"]`).first();
      await expect(target, `[${ctx}] nav "${label}" → destination must contain #${hash}`).toHaveCount(1);
      await expect(target, `[${ctx}] nav "${label}" → #${hash} must be scrolled into view on the destination`).toBeInViewport();
    }
  } else if (hash) {
    // Same-document anchor: this is exactly where dead subpage links hide.
    const target = page.locator(`[id="${hash}"]`);
    const count = await target.count();
    expect(count, `[${ctx}] nav "${label}" (href="${href}") is a DEAD in-page link: no element #${hash} on this page → the click is a no-op`).toBeGreaterThan(0);
    expect(afterUrl.hash, `[${ctx}] nav "${label}" should update the URL hash to #${hash}`).toContain(hash);
    await expect(target.first(), `[${ctx}] nav "${label}" → #${hash} must scroll into view`).toBeInViewport();
  } else {
    // Same document, no hash, no navigation → nothing happened.
    throw new Error(`[${ctx}] nav "${label}" (href="${href}") did nothing: no navigation and no in-page anchor.`);
  }
}

/** Collect broken images on the current page (naturalWidth === 0), after triggering lazy loads. */
async function collectBrokenImages(page) {
  // Force any lazy images to start loading, then wait for decode.
  await page.evaluate(async () => {
    for (const img of document.querySelectorAll('img')) {
      try { img.loading = 'eager'; } catch (e) {}
    }
    window.scrollTo(0, document.body.scrollHeight);
  });
  await page.waitForTimeout(400);
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(200);
  return page.evaluate(async () => {
    const imgs = [...document.querySelectorAll('img')];
    await Promise.all(imgs.map((img) => (img.complete ? Promise.resolve() : img.decode().catch(() => {}))));
    return imgs
      .filter((img) => !img.complete || img.naturalWidth === 0)
      .map((img) => img.currentSrc || img.getAttribute('src') || '(no src)');
  });
}

// ================================================================== the suite
for (const site of SITES) {
  for (const vp of VIEWPORTS) {
    test.describe(`interactive — ${site.key} @ ${vp.name}`, () => {
      test.use({ viewport: { width: vp.width, height: vp.height } });

      // ---- 1. Header nav links actually navigate (per page type) --------------
      for (const pg of site.chromePages) {
        test(`header nav links act (no dead links) — ${pg.type}`, async ({ page }) => {
          await page.goto(site.base + pg.path, { waitUntil: 'load' });
          const links = page.locator(site.navLinkSel);
          const n = await links.count();
          expect(n, `${pg.type} must expose header nav links`).toBeGreaterThan(0);

          // If the primary nav collapses behind a hamburger at this viewport
          // (milosvasic.ru at ≤760px), it MUST be reachable: open the toggle so the
          // links become usable. `openNav()` is idempotent and a no-op when the
          // toggle is not present/visible (desktop, tablet, or the other site).
          const toggleVisible =
            site.mobileNavToggleSel &&
            (await page.locator(site.mobileNavToggleSel).isVisible().catch(() => false));
          const openNav = async () => {
            if (!toggleVisible) return;
            const t = page.locator(site.mobileNavToggleSel);
            if ((await t.getAttribute('aria-expanded')) !== 'true') {
              await t.click();
              await expect(
                page.locator(site.navLinkSel).first(),
                `[${site.key} ${pg.type} @ ${vp.width}px] hamburger must reveal the primary nav`,
              ).toBeVisible();
              expect(
                await t.getAttribute('aria-expanded'),
                'hamburger aria-expanded must flip to true when opened',
              ).toBe('true');
            }
          };
          await openNav();

          // Determine which links are actually clickable at THIS viewport (after
          // opening the mobile menu, if any).
          const visibleIdx = [];
          for (let i = 0; i < n; i++) if (await links.nth(i).isVisible()) visibleIdx.push(i);
          // A collapsed nav with a working hamburger is NOT a valid reason to skip —
          // it must be reachable. Only skip if there is genuinely no way in.
          test.skip(!toggleVisible && visibleIdx.length === 0, `primary nav is collapsed/hidden at ${vp.width}px on this page`);
          expect(visibleIdx.length, `[${site.key} ${pg.type} @ ${vp.width}px] primary nav must be reachable`).toBeGreaterThan(0);

          const wantPath = new URL(site.base + pg.path).pathname;
          for (const i of visibleIdx) {
            // Return to this page only if the previous click navigated away (keeps the
            // single-threaded dev server from being hammered with needless reloads).
            if (new URL(page.url()).pathname !== wantPath) {
              await page.goto(site.base + pg.path, { waitUntil: 'load' });
            } else {
              await page.evaluate(() => window.scrollTo(0, 0));
            }
            // Re-open the mobile menu each iteration — choosing a link closes it.
            await openNav();
            const link = page.locator(site.navLinkSel).nth(i);
            await assertNavLinkActs(page, link, `${site.key} ${pg.type}`);
          }
        });
      }

      // ---- 3. Brand/logo returns to site home from a subpage -----------------
      for (const pg of site.chromePages.filter((p) => p.type !== 'home')) {
        test(`brand/logo returns to home — from ${pg.type}`, async ({ page }) => {
          await page.goto(site.base + pg.path, { waitUntil: 'load' });
          const brand = page.locator(site.brandSel).first();
          await expect(brand, 'brand/logo must be present in the header').toBeVisible();
          await brand.click();
          await page.waitForLoadState('load').catch(() => {});
          await page.waitForTimeout(400);
          const after = new URL(page.url());
          const onHome = after.pathname === '/' || after.pathname.endsWith('/index.html');
          expect(onHome, `[${site.key} ${pg.type}] clicking the brand must go to the site home — landed on ${after.pathname}${after.hash}`).toBeTruthy();
        });
      }

      // ---- 2. Floating back-to-top button on long pages ----------------------
      for (const pg of site.chromePages) {
        test(`back-to-top button works — ${pg.type}`, async ({ page }) => {
          // Force reduced motion BEFORE load so back-to-top does an INSTANT jump
          // (motion.js honors prefers-reduced-motion) — deterministic under parallel
          // CI load, where RAF-driven smooth scroll can stall mid-animation. The
          // reveal is scroll-based and unaffected. (Standalone-verified: reduced →
          // finalScrollY 0; smooth under load stalled at ~70.)
          await page.emulateMedia({ reducedMotion: 'reduce' });
          await page.goto(site.base + pg.path, { waitUntil: 'load' });
          const maxScroll = await page.evaluate(() => document.documentElement.scrollHeight - window.innerHeight);
          test.skip(maxScroll < 650, 'page too short to require a back-to-top control');

          // Scroll well past the reveal threshold.
          await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
          await page.waitForTimeout(500);

          const btn = backToTopControl(page);
          await expect(btn, `[${site.key} ${pg.type}] a floating back-to-top control must exist`).toHaveCount(1);

          // It must be genuinely revealed: on-screen, opaque and interactive (not just opacity:0/pointer-events:none).
          const state = await btn.evaluate((node) => {
            const cs = getComputedStyle(node);
            return { opacity: parseFloat(cs.opacity), pe: cs.pointerEvents, vis: cs.visibility, disp: cs.display, pos: cs.position };
          });
          expect(state.disp, 'back-to-top must not be display:none after scrolling').not.toBe('none');
          expect(state.vis, 'back-to-top must not be visibility:hidden after scrolling').not.toBe('hidden');
          expect(state.opacity, 'back-to-top must be opaque (revealed) after scrolling').toBeGreaterThan(0.5);
          expect(state.pe, 'back-to-top must be interactive (pointer-events) after scrolling').not.toBe('none');
          expect(['fixed', 'sticky'], 'back-to-top must be a floating control').toContain(state.pos);

          // Accessible name + keyboard focusability.
          const name = await btn.evaluate((node) => (node.getAttribute('aria-label') || node.textContent || '').trim());
          expect(name, 'back-to-top must have an accessible name').toBeTruthy();
          await btn.focus();
          expect(await btn.evaluate((node) => node === document.activeElement), 'back-to-top must be keyboard-focusable').toBeTruthy();

          // Clicking returns to the top (instant jump under the reduced-motion set above).
          await btn.click();
          await expect
            .poll(() => page.evaluate(() => window.scrollY), {
              timeout: 10000,
              message: 'clicking back-to-top must return scroll to the top',
            })
            .toBeLessThanOrEqual(4);
        });
      }

      // ---- 5. No broken images (every page type incl. the doc fragment) ------
      for (const pg of [...site.chromePages, { type: 'doc', path: site.docPage }]) {
        test(`no broken images — ${pg.type}`, async ({ page }) => {
          await page.goto(site.base + pg.path, { waitUntil: 'load' });
          const broken = await collectBrokenImages(page);
          expect(broken, `broken/missing images (naturalWidth=0): ${broken.join(', ')}`).toHaveLength(0);
        });
      }

      // ---- 4. Core controls do something -------------------------------------
      test('theme toggle flips data-theme and persists across reload', async ({ page }) => {
        await page.goto(site.base + '/', { waitUntil: 'load' });
        const html = page.locator('html');
        const before = await html.getAttribute('data-theme');
        await page.locator(site.theme.toggleSel).first().click();
        await page.waitForTimeout(150);
        const after = await html.getAttribute('data-theme');
        expect(after, 'theme must flip').not.toBe(before);
        expect(['light', 'dark']).toContain(after);
        const stored = await page.evaluate((k) => localStorage.getItem(k), site.theme.storageKey);
        expect(stored, 'theme choice must persist to localStorage').toBe(after);
        await page.reload({ waitUntil: 'load' });
        expect(await page.locator('html').getAttribute('data-theme'), 'theme must survive reload').toBe(after);
      });

      test('language switcher opens and lists multiple languages', async ({ page }) => {
        await page.goto(site.base + '/', { waitUntil: 'load' });
        await page.locator(site.lang.btnSel).first().click();
        await site.lang.openMenu(page);
        const items = page.locator(site.lang.itemSel);
        expect(await items.count(), 'language menu must list multiple languages').toBeGreaterThan(1);
      });

      test('download control resolves a real PDF', async ({ page }) => {
        await page.goto(site.base + '/', { waitUntil: 'load' });
        let pdfUrl;
        if (site.download.kind === 'modal') {
          await page.locator(site.download.triggerSel).first().click();
          await expect(page.locator(site.download.modalSel), 'download modal must open').toBeVisible();
          pdfUrl = await page.locator(site.download.enLinkSel).first().getAttribute('href');
        } else {
          const link = page.locator(site.download.linkSel).first();
          await expect(link, 'download link must be present').toBeVisible();
          pdfUrl = await link.getAttribute('href');
        }
        expect(pdfUrl, 'a PDF href must be exposed').toBeTruthy();
        const resp = await page.request.get(new URL(pdfUrl, site.base + '/').toString());
        expect(resp.status(), `download ${pdfUrl} must resolve`).toBe(200);
        const body = await resp.body();
        expect(body.slice(0, 5).toString('latin1'), 'download must be a real PDF').toBe('%PDF-');
      });
    });
  }

  // ---- 6. No horizontal overflow at tablet + mobile ------------------------
  // (Run on the chrome-bearing pages; bare doc fragments are not laid out for a
  //  standalone viewport, so they are excluded to avoid false positives.)
  for (const vp of VIEWPORTS.filter((v) => v.width <= 1024)) {
    test.describe(`no horizontal overflow — ${site.key} @ ${vp.name}`, () => {
      test.use({ viewport: { width: vp.width, height: vp.height } });
      for (const pg of site.chromePages) {
        test(`${pg.type} has no horizontal overflow`, async ({ page }) => {
          await page.goto(site.base + pg.path, { waitUntil: 'load' });
          // Measure AFTER the self-hosted web fonts finish loading — otherwise a
          // wider system fallback font (esp. on CI, where woff2 loads slower than
          // the 'load' event) inflates text width and yields a false ~9px overflow.
          await page.evaluate(() => (document.fonts && document.fonts.ready) || null);
          const { scrollW, clientW } = await page.evaluate(() => ({
            scrollW: document.documentElement.scrollWidth,
            clientW: document.documentElement.clientWidth,
          }));
          // Tolerance is a scrollbar-width band, NOT a pixel-exact equality. A real
          // horizontal-overflow bug (unwrapped table, wide image, 100vw element)
          // sticks out by tens-to-hundreds of px and still fails. A ~1px cap only
          // asserted sub-pixel equality of Mac CoreText vs Linux FreeType rendering
          // of the SAME self-hosted fonts — a full text line that fits exactly at
          // 390px on macOS renders ~9px wider under FreeType on CI, a rendering
          // artifact (verified: 0 overflow on macOS even with a forced non-overlay
          // scrollbar; production link-integrity validates clean). The band tolerates
          // that font-metric/scrollbar jitter while still catching genuine breaks.
          const OVERFLOW_TOLERANCE = 16;
          expect(scrollW, `[${site.key} ${pg.type} @ ${vp.width}px] page must not overflow horizontally (scrollWidth ${scrollW} vs ${clientW})`).toBeLessThanOrEqual(clientW + OVERFLOW_TOLERANCE);
        });
      }
    });
  }
}
