const { test, expect } = require('@playwright/test');
const { AxeBuilder } = require('@axe-core/playwright');
const BASE = 'http://localhost:8401';

// Accessibility coverage for the COMPANY site vasic.digital. Mirrors the
// milosvasic.ru a11y spec: axe-core scans the three surfaces a visitor
// navigates — the homepage, a representative product detail page, and the
// portfolio index — and fails on any critical/serious WCAG violation.
// We disable only heading-order (sub-headings nest intentionally) and
// link-in-text-block (inline accent-coloured links, a common accessible
// pattern). Every other rule, INCLUDING color-contrast (a "serious" rule),
// stays enforced — Constitution §11.4.107 requires WCAG contrast verified
// from rendered pixels.
test.describe('vasic.digital — accessibility', () => {

  const PAGES = [
    { name: 'homepage',  url: BASE },
    { name: 'product',   url: `${BASE}/products/helixagent.html` },
    { name: 'portfolio', url: `${BASE}/portfolio/` },
  ];

  for (const p of PAGES) {
    test(`axe-core accessibility scan — ${p.name} (no critical/serious violations)`, async ({ page }) => {
      await page.goto(p.url);
      const results = await new AxeBuilder({ page })
        .disableRules(['heading-order', 'link-in-text-block'])
        .analyze();
      const critical = results.violations.filter(v => v.impact === 'critical' || v.impact === 'serious');
      // Surface the exact offending nodes so any failure is precisely actionable.
      if (critical.length > 0) {
        console.log(`AXE ${p.name} critical/serious:`, JSON.stringify(
          critical.map(v => ({ id: v.id, impact: v.impact, help: v.help,
            nodes: v.nodes.slice(0, 6).map(n => ({ target: n.target, summary: n.failureSummary })) })), null, 2));
      }
      if (results.violations.length > 0) {
        console.log(`INFO ${p.name} non-critical:`, JSON.stringify(results.violations.map(v => ({ id: v.id, impact: v.impact, help: v.help }))));
      }
      expect(critical, `${p.name} must have no critical/serious a11y violations`).toEqual([]);
    });
  }

  for (const p of PAGES) {
    test(`landmark & skip-link structure — ${p.name}`, async ({ page }) => {
      await page.goto(p.url);

      // Exactly one <main> landmark per page.
      const mainCount = await page.locator('main').count();
      expect(mainCount, `${p.name} should have exactly one <main> landmark`).toBe(1);

      // A skip link exists, is the first focusable-style bypass, and targets an
      // in-page anchor that actually resolves to an element.
      const skip = page.locator('a.od-skip-link, a.skip-link').first();
      await expect(skip, `${p.name} should have a skip link`).toHaveCount(1);
      const target = await skip.getAttribute('href');
      expect(target, `${p.name} skip link should point to an in-page anchor`).toMatch(/^#/);
      const targetId = target.slice(1);
      const targetExists = await page.evaluate((id) => !!document.getElementById(id), targetId);
      expect(targetExists, `${p.name} skip-link target #${targetId} must exist`).toBeTruthy();
    });
  }

  for (const p of PAGES) {
    test(`all images have an alt attribute — ${p.name}`, async ({ page }) => {
      await page.goto(p.url);
      // Every <img> must carry an alt attribute (alt="" is valid for decorative
      // images; a MISSING attribute is the violation we guard against).
      const imgsMissingAlt = await page.evaluate(() =>
        Array.from(document.querySelectorAll('img'))
          .filter(img => !img.hasAttribute('alt'))
          .map(img => img.getAttribute('src') || '(no src)')
      );
      expect(imgsMissingAlt, `${p.name} images missing alt: ${JSON.stringify(imgsMissingAlt)}`).toEqual([]);
    });
  }

});
