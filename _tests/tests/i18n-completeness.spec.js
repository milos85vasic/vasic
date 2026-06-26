const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

// Pure-Node unit test (no browser): loads the i18n dictionary by evaluating the
// file in a sandbox with a fake `window`, then asserts every key present in the
// English table also exists in every other supported language.
test.describe('i18n dictionary completeness (milosvasic.ru)', () => {
  test('every EN key exists in all languages from MV_LANGS', () => {
    const src = fs.readFileSync(
      path.resolve(__dirname, '../../milosvasic.ru/assets/js/i18n.js'), 'utf8');
    const sandbox = { window: {} };
    vm.createContext(sandbox);
    vm.runInContext(src, sandbox);

    const dict = sandbox.window.MV_I18N;
    const langs = sandbox.window.MV_LANGS.map((l) => l.code);
    // Core langs must always be present.
    expect(langs).toEqual(expect.arrayContaining(['en', 'ru', 'sr', 'de', 'es', 'fr']));

    const enKeys = Object.keys(dict.en);
    expect(enKeys.length).toBeGreaterThan(20);

    for (const code of langs) {
      expect(dict[code], `language table "${code}" exists in MV_I18N`).toBeTruthy();
      const missing = enKeys.filter((k) => !(k in dict[code]));
      expect(missing, `"${code}" is missing keys`).toEqual([]);
    }
  });

  test('new feature keys are present in all languages', () => {
    const src = fs.readFileSync(
      path.resolve(__dirname, '../../milosvasic.ru/assets/js/i18n.js'), 'utf8');
    const sandbox = { window: {} };
    vm.createContext(sandbox);
    vm.runInContext(src, sandbox);
    const dict = sandbox.window.MV_I18N;
    const langs = sandbox.window.MV_LANGS.map((l) => l.code);
    const required = ['ds.based_v', 'ds.langs_v', 'dl.heading', 'dl.choose', 'dl.cv', 'dl.cl', 'card.more'];
    for (const code of langs) {
      expect(dict[code], `language table "${code}" exists`).toBeTruthy();
      for (const key of required) {
        expect(dict[code][key], `${code}.${key}`).toBeTruthy();
      }
    }
  });
});
