// D3 regression (live-health 2026-11-24): main.js used to persist mv-lang on
// EVERY page view, including English ones. In one browser context, loading `/`
// then `/ar/` therefore stored mv-lang=en on the first view, and the second
// page rendered lang=en dir=ltr with English chrome over Arabic content.
// Contract: mv-lang is written ONLY by an explicit language-switcher choice.
const { test, expect } = require('@playwright/test');
const { MV_BASE } = require('../env.js');

const readStored = (page) => page.evaluate(() => {
  try { return localStorage.getItem('mv-lang'); } catch (e) { return 'UNAVAILABLE'; }
});

test('milosvasic.ru D3: viewing / then /ar/ in one context keeps Arabic lang+dir+chrome', async ({ page }) => {
  await page.goto(`${MV_BASE}/`);
  await expect(page.locator('html')).toHaveAttribute('lang', 'en');
  expect(await readStored(page)).toBeNull(); // a page VIEW is not a choice
  await page.goto(`${MV_BASE}/ar/`);
  await expect(page.locator('html')).toHaveAttribute('lang', 'ar');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  expect(await readStored(page)).toBeNull();
  const chrome = await page.locator('#lang-btn').innerText();
  expect(chrome.trim().toUpperCase()).toBe('AR');
});

test('milosvasic.ru D3: an explicit switcher choice still persists and navigates', async ({ page }) => {
  await page.goto(`${MV_BASE}/`);
  await page.locator('#lang-btn').click();
  await page.locator('#lang-menu button[data-code="ru"]').click();
  await page.waitForURL('**/ru/');
  await expect(page.locator('html')).toHaveAttribute('lang', 'ru');
  expect(await readStored(page)).toBe('ru');
});
