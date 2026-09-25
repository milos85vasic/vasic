const { test, expect } = require('@playwright/test');
const { VD_BASE, MV_BASE } = require('../env.js');

// Above-the-fold content must NOT slide in. Measured 2026-09-22/23: the hero
// section (and its Download CV / Cover Letter / Portfolio buttons) was an
// `.od-reveal` revealed by an IntersectionObserver, so it slid into place on
// every page load; under load the observer fired after a click had been aimed
// and the click landed where the button used to be (Playwright call log:
// "element is not stable" x3, then a click that missed). The fix lives in the
// canonical design-system/motion/motion.js, copied into both sites.
//
// The assertion is event-based, not timing-based: an init script counts every
// `transitionrun` on an `.od-reveal` that is inside the viewport, from before
// the first page script executes. The old code fires it on every load, however
// fast the machine; the fixed code never does. A CONTROL proves the fix did not
// simply turn motion off: a reveal below the fold must still become visible
// once scrolled to.
const SITES = [
  { key: 'milosvasic.ru', base: MV_BASE },
  { key: 'vasic.digital', base: VD_BASE },
];

// A reveal element that is INSIDE the viewport must never be left hidden, at any
// viewport height. Found 2026-09-24 by a live audit: on /ar/ at 1280x800 the
// decorative `.vd-hero__rule.od-divider` sat at y=744 of 800, inside the bottom
// 8% band that the observer's rootMargin '0px 0px -8% 0px' excludes, and layout
// had shifted after initReveal's in-view pass — so it was neither frozen-final
// nor observed as intersecting, and stayed at scaleX(0) until the page scrolled.
// (At the very end of a page an element in that band can never scroll out of
// it, so it would stay hidden for good.) The heights below straddle the band for
// this layout; a single fixed height would pass by luck.
const HEIGHTS = [700, 720, 768, 800, 900, 1080];
for (const site of SITES) {
  test.describe(`nothing inside the viewport stays hidden — ${site.key}`, () => {
    for (const path of ['/', '/ar/']) {
      for (const h of HEIGHTS) {
        test(`${path} at 1280x${h}`, async ({ page }) => {
          await page.setViewportSize({ width: 1280, height: h });
          await page.goto(site.base + path, { waitUntil: 'load' });
          await page.waitForTimeout(1500);
          const res = await page.evaluate(() => {
            const els = Array.from(document.querySelectorAll('.od-reveal, .od-stagger, .od-divider'));
            // "In view" = the observer's own definition: at least 5% of the element is
            // inside the viewport (threshold 0.05). A 1px sliver of a 900px section is
            // not a visible defect and the design never promised to reveal it.
            const vis = (el) => { const r = el.getBoundingClientRect(); const h = Math.max(r.height, 1);
              return Math.max(0, Math.min(r.bottom, innerHeight) - Math.max(r.top, 0)) / h; };
            const inView = els.filter((el) => vis(el) >= 0.05);
            return { total: els.length, inView: inView.length,
              hidden: inView.filter((el) => !el.classList.contains('is-visible'))
                .map((el) => `${el.className} top=${Math.round(el.getBoundingClientRect().top)}/${innerHeight}`) };
          });
          expect(res.inView, 'the page must have in-view reveal content for this test to mean anything').toBeGreaterThan(0);
          expect(res.hidden, `in-view reveal elements left hidden at ${h}px`).toEqual([]);
        });
      }
    }
    test('end of page: an element in the last viewport band is revealed (it cannot scroll further)', async ({ page }) => {
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(site.base + '/', { waitUntil: 'load' });
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      await page.waitForTimeout(1200);
      const hidden = await page.evaluate(() => Array.from(document.querySelectorAll('.od-reveal, .od-stagger, .od-divider'))
        .filter((el) => { const r = el.getBoundingClientRect(); const h = Math.max(r.height, 1);
          return Math.max(0, Math.min(r.bottom, innerHeight) - Math.max(r.top, 0)) / h >= 0.05; })
        .filter((el) => !el.classList.contains('is-visible')).map((el) => `${el.className} top=${Math.round(el.getBoundingClientRect().top)}`));
      expect(hidden, 'at the bottom of the page nothing in view may stay hidden').toEqual([]);
    });
  });
}

for (const site of SITES) {
  test.describe(`above-the-fold reveals do not move — ${site.key}`, () => {
    test('no in-viewport .od-reveal transitions on load', async ({ page }) => {
      await page.addInitScript(() => {
        window.__aboveFoldTransitions = [];
        document.addEventListener('transitionrun', (e) => {
          const el = e.target;
          if (!(el instanceof Element)) return;
          // The reveal targets AND the stagger's children (animations.css puts
          // the stagger transition on `.od-stagger > *`) AND dividers.
          const isTarget = el.classList.contains('od-reveal') || el.classList.contains('od-divider')
            || (el.parentElement && el.parentElement.classList.contains('od-stagger'));
          if (!isTarget) return;
          if (e.propertyName !== 'transform') return;
          const r = el.getBoundingClientRect();
          if (r.bottom > 0 && r.top < window.innerHeight) {
            window.__aboveFoldTransitions.push(el.className);
          }
        }, true);
      });
      await page.goto(site.base + '/', { waitUntil: 'load' });
      // Give any observer callback ample time to fire and any transition to start.
      await page.waitForTimeout(1500);
      // Not vacuous: there must BE above-the-fold motion content to protect.
      const inView = await page.evaluate(() => Array.from(document.querySelectorAll('.od-reveal, .od-stagger, .od-divider'))
        .filter((el) => { const r = el.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; }).length);
      expect(inView, 'the page must have at least one in-view reveal for this test to mean anything').toBeGreaterThan(0);
      const moved = await page.evaluate(() => window.__aboveFoldTransitions);
      expect(moved, 'above-the-fold .od-reveal elements must not slide in').toEqual([]);
      // ...and they are in their final state.
      const notShown = await page.evaluate(() => Array.from(document.querySelectorAll('.od-reveal, .od-stagger, .od-divider'))
        .filter((el) => { const r = el.getBoundingClientRect(); return r.bottom > 0 && r.top < innerHeight; })
        .filter((el) => !el.classList.contains('is-visible')).length);
      expect(notShown, 'in-view reveals must be in their final state').toBe(0);
    });

    test('CONTROL: a below-the-fold reveal still reveals on scroll', async ({ page }) => {
      await page.goto(site.base + '/', { waitUntil: 'load' });
      const below = await page.evaluate(() => {
        const els = Array.from(document.querySelectorAll('.od-reveal, .od-stagger'));
        const i = els.findIndex((el) => el.getBoundingClientRect().top > innerHeight * 1.5);
        if (i < 0) return -1;
        els[i].setAttribute('data-test-below', '1');
        return els[i].classList.contains('is-visible') ? 1 : 0;
      });
      // A CONTROL that can skip proves nothing (§11.4.201 / §11.4.252): if the page
      // has no below-the-fold reveal, the control cannot run, and that must be red.
      expect(below, 'CONTROL precondition: the page must have a below-the-fold reveal to exercise').not.toBe(-1);
      expect(below, 'a below-the-fold reveal must NOT be pre-revealed').toBe(0);
      await page.locator('[data-test-below="1"]').scrollIntoViewIfNeeded();
      await expect(page.locator('[data-test-below="1"]')).toHaveClass(/is-visible/);
    });
  });
}
