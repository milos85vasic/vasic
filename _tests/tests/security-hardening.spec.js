const { test, expect } = require('@playwright/test');

// Security / meta-hardening checks (§11.4.169). For a static GitHub Pages site
// there is NO application server, so runtime concerns (WAF, rate-limiting,
// server security headers) are N/A — see _tests/TEST-TYPES.md. What IS in scope
// for shipped static HTML, and is asserted here per key page:
//   * no inline secrets in the shipped markup
//   * no mixed content (no http:// subresources)
//   * no inline on*= event-handler attributes (XSS surface on a CSP-less page)
//   * every target=_blank link carries rel=noopener (reverse-tabnabbing guard)
//   * CSP <meta> presence is RECORDED (informational; absent is acceptable and
//     documented, since GitHub Pages cannot set a CSP response header).

const PAGES = [
  { site: 'vasic.digital', base: 'http://localhost:8401', path: '/' },
  { site: 'vasic.digital', base: 'http://localhost:8401', path: '/products/helixtrack.html' },
  { site: 'milosvasic.ru', base: 'http://localhost:8082', path: '/' },
  { site: 'milosvasic.ru', base: 'http://localhost:8082', path: '/products/helixtrack.html' },
];

const SECRET_PATTERNS = [
  /-----BEGIN (?:RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----/,
  /AKIA[0-9A-Z]{16}/,                 // AWS access key id
  /\bsk-[A-Za-z0-9]{20,}\b/,          // OpenAI-style secret key
  /\bghp_[A-Za-z0-9]{30,}\b/,         // GitHub personal access token
  /\bxox[baprs]-[A-Za-z0-9-]{10,}\b/, // Slack token
  /(?:api[_-]?key|secret|passwd|password)\s*[:=]\s*['"][^'"]{8,}['"]/i,
];

for (const p of PAGES) {
  test.describe(`security — ${p.site}${p.path}`, () => {
    test.beforeEach(async ({ page }) => {
      const r = await page.goto(p.base + p.path, { waitUntil: 'domcontentloaded' });
      expect(r.status()).toBeLessThan(400);
    });

    test('no inline secrets in shipped HTML', async ({ page }) => {
      const html = await page.content();
      const hits = [];
      for (const re of SECRET_PATTERNS) {
        const m = html.match(re);
        if (m) hits.push(m[0].slice(0, 24));
      }
      expect(hits, `possible secrets in markup: ${hits.join(', ')}`).toHaveLength(0);
    });

    test('no mixed content (no http:// subresources)', async ({ page }) => {
      const bad = await page.evaluate(() => {
        const out = [];
        const attrs = [['img', 'src'], ['script', 'src'], ['link', 'href'], ['iframe', 'src'], ['source', 'src'], ['audio', 'src'], ['video', 'src']];
        for (const [tag, attr] of attrs) {
          for (const el of document.querySelectorAll(`${tag}[${attr}]`)) {
            const v = el.getAttribute(attr) || '';
            if (/^http:\/\//i.test(v)) out.push(`${tag}[${attr}]=${v}`);
          }
        }
        return out;
      });
      expect(bad, `insecure http:// subresources: ${bad.join(', ')}`).toHaveLength(0);
    });

    test('no inline on*= event-handler attributes', async ({ page }) => {
      const handlers = await page.evaluate(() => {
        const out = [];
        for (const el of document.querySelectorAll('*')) {
          for (const a of el.attributes) {
            if (/^on/i.test(a.name)) out.push(`${el.tagName.toLowerCase()}[${a.name}]`);
          }
        }
        return out;
      });
      expect(handlers, `inline event handlers present: ${handlers.join(', ')}`).toHaveLength(0);
    });

    test('target=_blank links carry rel=noopener', async ({ page }) => {
      const unsafe = await page.locator('a[target="_blank"]').evaluateAll(
        (els) => els.filter((e) => !/noopener/i.test(e.getAttribute('rel') || '')).map((e) => e.getAttribute('href'))
      );
      expect(unsafe, `target=_blank without rel=noopener: ${unsafe.join(', ')}`).toHaveLength(0);
    });

    test('CSP <meta> presence recorded (informational)', async ({ page }, testInfo) => {
      const csp = await page.locator('head meta[http-equiv="Content-Security-Policy" i]').count();
      // Not a failure either way: server-header CSP is N/A on GitHub Pages, and a
      // meta CSP is optional. We only record the state as evidence.
      // eslint-disable-next-line no-console
      console.log(`[security] ${p.site}${p.path} meta-CSP present: ${csp > 0}`);
      expect(csp).toBeGreaterThanOrEqual(0);
    });
  });
}
