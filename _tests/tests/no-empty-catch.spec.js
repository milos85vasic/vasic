const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// GUARD (2026-09-24): no shipped HTML or JS may contain an EMPTY catch block.
// `catch (e) {}` swallows a failure with no trace. Every one found by the live
// audit was a best-effort localStorage guard, but an empty block is
// indistinguishable from a real swallowed error, so the class is banned and each
// site must make it visible (console.debug) — behaviour otherwise identical.
// The first sweep missed `} catch (e) {}` (spaces) in milosvasic.ru's hand-
// maintained Jekyll layout, so ALL 525 built pages still shipped it; the pattern
// below is whitespace/newline tolerant and also matches `catch {}` and `catch(_){}`.
//
// SCOPE IS DERIVED, not listed: every .html and .js under the two BUILT site
// roots the harness itself serves (same roots as playwright.config.js: the
// vasic.digital tree and milosvasic.ru/_site). Only the EXEMPTIONS below are
// declared, each with its reason; a path outside them that matches is a defect.
const REPO = path.resolve(__dirname, '..', '..');
const ROOTS = [
  { key: 'vasic.digital', dir: path.join(REPO, 'vasic.digital') },
  { key: 'milosvasic.ru', dir: path.join(REPO, 'milosvasic.ru', '_site') },
];
// A body holding ONLY whitespace and comments is an empty swallow: a comment is
// not visibility. Found 2026-09-24: milosvasic.ru/assets/js/i18n.js wrapped its
// whole apply routine in `catch (e) { /* never block page render on i18n */ }`,
// which the whitespace-only pattern passed.
const EMPTY_CATCH = /catch\s*(\([^)]*\))?\s*\{(?:\s|;|\/\*[\s\S]*?\*\/|\/\/[^\n]*\n)*\}/g;
const EXEMPT = [
  { re: /(^|\/)node_modules\//, why: 'third-party dependencies' },
];

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== '.git') walk(p, out); }
    else if (/\.(html|js)$/.test(e.name)) out.push(p);
  }
  return out;
}

for (const root of ROOTS) {
  test(`no empty catch block ships — ${root.key}`, () => {
    expect(fs.existsSync(root.dir), `${root.key} built root must exist: ${root.dir}`).toBe(true);
    const files = walk(root.dir);
    // Non-vacuous: the scan must actually have looked at pages AND scripts.
    expect(files.filter((f) => f.endsWith('.html')).length, 'html files scanned').toBeGreaterThan(50);
    expect(files.filter((f) => f.endsWith('.js')).length, 'js files scanned').toBeGreaterThan(0);
    const hits = [];
    for (const f of files) {
      const rel = path.relative(root.dir, f).split(path.sep).join('/');
      if (EXEMPT.some((x) => x.re.test(rel))) continue;
      const n = (fs.readFileSync(f, 'utf8').match(EMPTY_CATCH) || []).length;
      if (n) hits.push(`${rel} x${n}`);
    }
    // Summarise by directory when there are many, but always print an example.
    expect(hits.length, `${hits.length} file(s) ship an empty catch, e.g. ${hits.slice(0, 5).join('; ')}`).toBe(0);
  });
}

test('the pattern itself: matches every empty-swallow spelling, ignores handled catches', () => {
  const bad = ['} catch (e) {}', 'catch(e){}', 'catch (_) { }', 'catch {}', 'catch (e) {\n  }', 'catch(err){ \t }',
    'catch (e) { /* ignore */ }', 'catch (e) { /* never block page render on i18n */ }',
    'catch (e) {\n  // ignore\n}', 'catch(e){/*a*/ /*b*/}', 'catch (e) {\n  /* multi\n  line */\n  // and a line\n}',
    'catch(e){;}', 'catch({a}){}', 'catch ({ message }) { ; }'];
  const good = ['catch(e){console.debug(e)}', 'catch(e){handle(e)}', 'catch({a}){use(a)}', 'catch (e) { return null; }', 'catch (e) { x(); }',
    'catch (e) { /* note */ console.debug(e); }', 'catch (e) {\n // note\n log(e);\n}', "catch (e) { var u = 'http://x'; }"];
  for (const s of bad) expect(s.match(EMPTY_CATCH), `must match: ${JSON.stringify(s)}`).not.toBeNull();
  for (const s of good) expect(s.match(EMPTY_CATCH), `must NOT match: ${JSON.stringify(s)}`).toBeNull();
});
