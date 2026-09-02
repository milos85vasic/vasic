const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;
const path = require('path');

// vasic.digital — visual-effects evidence + a11y gate.
// Captures the animated hero, a card hover-glow state, mobile, and a
// prefers-reduced-motion render (motion disabled), and runs axe on the home.
const { VD_BASE: BASE } = require('./env.js');
const EV = path.resolve(__dirname, 'evidence/visual-effects');

async function setTheme(page, theme) {
  await page.evaluate((t) => {
    localStorage.setItem('od-theme', t);
    document.documentElement.setAttribute('data-theme', t);
  }, theme);
}

test.describe('vasic.digital visual effects', () => {
  test('hero effects present in DOM', async ({ page }) => {
    await page.goto(BASE);
    await expect(page.locator('.vd-hero')).toBeVisible();
    await expect(page.locator('.vd-hero__fx .vd-hero__aurora')).toHaveCount(1);
    await expect(page.locator('.vd-hero__fx .vd-hero__grid')).toHaveCount(1);
    await expect(page.locator('hr.vd-hero__rule.od-divider')).toHaveCount(1);
    // fx layer is decorative / non-interactive
    await expect(page.locator('.vd-hero__fx')).toHaveAttribute('aria-hidden', 'true');
    // count-up + magnetic hooks
    expect(await page.locator('.od-stat__value[data-od-count]').count()).toBe(3);
    expect(await page.locator('.vd-hero__cta .od-btn.od-magnetic').count()).toBeGreaterThanOrEqual(2);
    // product cards carry the glow class
    expect(await page.locator('.od-product-card.od-glow').count()).toBeGreaterThanOrEqual(8);
  });

  test('count-up settles on the authored final value', async ({ page }) => {
    await page.goto(BASE);
    const first = page.locator('.od-stat__value[data-od-count]').first();
    await first.scrollIntoViewIfNeeded();
    // easeOutCubic over 1200ms — allow it to finish, then assert authored text.
    await page.waitForTimeout(1600);
    await expect(first).toHaveText('40+');
  });

  test('desktop hero — light + dark', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto(BASE);
    await setTheme(page, 'light');
    await page.waitForTimeout(1700); // let reveal + count-up complete
    await page.locator('.vd-hero').screenshot({ path: `${EV}/hero-desktop-light.png` });
    await page.screenshot({ path: `${EV}/home-desktop-light-full.png`, fullPage: true });
    await setTheme(page, 'dark');
    await page.waitForTimeout(300);
    await page.locator('.vd-hero').screenshot({ path: `${EV}/hero-desktop-dark.png` });
  });

  test('card hover-glow state', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto(BASE);
    await setTheme(page, 'light');
    const card = page.locator('#products .od-product-card.od-glow').first();
    await card.scrollIntoViewIfNeeded();
    await page.waitForTimeout(700); // reveal
    await card.hover();
    await page.waitForTimeout(450); // glow opacity transition
    await card.screenshot({ path: `${EV}/card-hover-glow.png` });
  });

  test('mobile hero (390px) — no horizontal overflow', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(BASE);
    await page.waitForTimeout(1200);
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth
    );
    expect(overflow).toBeLessThanOrEqual(2);
    await page.screenshot({ path: `${EV}/hero-mobile.png` });
  });

  test('prefers-reduced-motion — motion disabled, hero still readable', async ({ browser }) => {
    const ctx = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();
    await page.goto(BASE);
    await setTheme(page, 'light');
    await page.waitForTimeout(600);
    // Reveal/stagger neutralized: hero copy is at rest (no transform) and visible.
    await expect(page.locator('.od-hero__title')).toBeVisible();
    // Divider is shown at full scale (scaleX(1)) rather than animating in.
    const sx = await page.locator('hr.vd-hero__rule.od-divider').evaluate((el) => {
      const t = getComputedStyle(el).transform;
      if (t === 'none') return 1;
      const m = t.match(/matrix\(([^)]+)\)/);
      return m ? parseFloat(m[1].split(',')[0]) : 1;
    });
    expect(sx).toBeGreaterThan(0.99);
    // Count-up did NOT run — the authored final value is shown immediately.
    await expect(page.locator('.od-stat__value[data-od-count]').first()).toHaveText('40+');
    await page.locator('.vd-hero').screenshot({ path: `${EV}/hero-reduced-motion.png` });
    await ctx.close();
  });

  test('axe: no serious/critical violations on the home', async ({ page }) => {
    await page.goto(BASE);
    await setTheme(page, 'light');
    await page.waitForTimeout(1600);
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();
    const serious = results.violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
    if (serious.length) {
      console.log('axe serious/critical:', JSON.stringify(serious.map((v) => ({ id: v.id, nodes: v.nodes.length })), null, 2));
    }
    require('fs').writeFileSync(`${EV}/axe-home.json`, JSON.stringify(results.violations, null, 2));
    expect(serious).toEqual([]);
  });
});
