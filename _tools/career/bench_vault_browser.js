// Browser-side vault benchmark (real Chromium, real vault.js).  env: VAULT_DIR, VAULT_PW, REPEAT (default 3).
// Prints {derive_ms:[...], unlock_ms:[...], download_ms:[...]}.  Deterministic inputs; wall times are the measurement.
const { startServer, launch } = require("./vault_browser_harness.js");
const vaultDir = process.env.VAULT_DIR, pw = process.env.VAULT_PW, N = +(process.env.REPEAT || 3);
(async () => {
  const srv = await startServer(vaultDir), browser = await launch();
  const out = { derive_ms: [], unlock_ms: [], download_ms: [] };
  try {
    const page = await (await browser.newContext({ acceptDownloads: true })).newPage();
    await page.goto(srv.base + "/admin/console.html");
    for (let i = 0; i < N; i++)
      out.derive_ms.push(await page.evaluate(async () => {
        const t = performance.now(), s = crypto.subtle;
        const base = await s.importKey("raw", new TextEncoder().encode("bench-passphrase"), "PBKDF2", false, ["deriveKey"]);
        await s.deriveKey({ name: "PBKDF2", hash: "SHA-256", salt: new Uint8Array(16), iterations: 600000 }, base,
                          { name: "AES-GCM", length: 256 }, false, ["decrypt"]);
        return performance.now() - t;
      }));
    for (let i = 0; i < N; i++) {
      await page.fill("#passphrase", pw);
      const t = Date.now(); await page.click("#unlock-btn");
      await page.waitForSelector("#picker:not([hidden])", { timeout: 60000 });
      out.unlock_ms.push(Date.now() - t);
      const btn = page.locator("#files button").first();
      const t2 = Date.now();
      await Promise.all([page.waitForEvent("download", { timeout: 60000 }), btn.click()]);
      out.download_ms.push(Date.now() - t2);
      await page.click("#lock-btn");
    }
  } catch (e) { out.error = String(e && e.stack || e); }
  await browser.close(); srv.close();
  console.log(JSON.stringify(out));
})();
