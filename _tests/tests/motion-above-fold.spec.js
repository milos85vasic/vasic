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
