// Real-browser proof: drive admin/console.html (rendered from the real layout) against a local static server.
// env: VAULT_DIR, VAULT_PW, EXPECT ({slot: sha256}). Prints {results:[...]}.
const fs = require("fs"), path = require("path"), http = require("http"), crypto = require("crypto"), os = require("os");
const ROOT = path.resolve(__dirname, "../..");
const SITE = path.join(ROOT, "milosvasic.ru");
const { chromium } = require(path.join(ROOT, "_tests/node_modules/playwright-core"));
const vaultDir = process.env.VAULT_DIR, pw = process.env.VAULT_PW;
const expect = JSON.parse(fs.readFileSync(process.env.EXPECT, "utf8"));
const results = [];
const rec = (name, ok, detail) => results.push({ name, ok: !!ok, detail: String(detail === undefined ? "" : detail) });

// Minimal stand-in for the Jekyll build of this one page (no jekyll on this host).
function renderConsole() {
  const layout = fs.readFileSync(path.join(SITE, "_layouts/admin_console.html"), "utf8");
  const page = fs.readFileSync(path.join(SITE, "admin/console.html"), "utf8");
  const fm = page.match(/^---\n([\s\S]*?)\n---\n/);
  const title = /title:\s*"([^"]*)"/.exec(fm[1])[1];
  return layout.replace(/\{\{ page\.title \| escape_once \}\}/g, title)
    .replace(/\{\{ '([^']+)' \| relative_url \}\}/g, "$1")
    .replace("{{ content }}", page.slice(fm[0].length));
}
const mime = { ".js": "text/javascript", ".css": "text/css", ".json": "application/json" };
const server = http.createServer((req, res) => {
  const p = decodeURIComponent(req.url.split("?")[0]);
  let file = null, body = null;
  if (p === "/admin/console.html") body = renderConsole();
  else if (p.startsWith("/downloads/vault/")) file = path.join(vaultDir, p.slice("/downloads/vault/".length));
  else if (p.startsWith("/assets/")) file = path.join(SITE, p);
  if (file && !path.resolve(file).startsWith(path.resolve(file.startsWith(vaultDir) ? vaultDir : SITE))) file = null;
  if (body === null && file && fs.existsSync(file) && fs.statSync(file).isFile()) body = fs.readFileSync(file);
  if (body === null) { res.writeHead(404); return res.end("nf"); }
  res.writeHead(200, { "content-type": mime[path.extname(p)] || (p.endsWith(".html") ? "text/html" : "application/octet-stream") });
  res.end(body);
});

(async () => {
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch();
  try {
    const ctx = await browser.newContext({ acceptDownloads: true });
    const page = await ctx.newPage();
    const errors = []; page.on("pageerror", (e) => errors.push(String(e)));
    page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    await page.goto(base + "/admin/console.html");
    rec("meta-robots-noindex", /noindex/.test(await page.locator('meta[name="robots"]').getAttribute("content")));

    await page.fill("#passphrase", pw + "-wrong");
    await page.click("#unlock-btn");
    await page.waitForFunction(() => /Authentication failed/.test(document.getElementById("status").textContent), null, { timeout: 60000 });
    rec("wrong-passphrase-generic-failure", await page.locator("#picker").isHidden() && !/hash|tag|salt|decrypt/i.test(await page.locator("#status").textContent()),
        await page.locator("#status").textContent());
    // throttle: an immediate retry is refused
    await page.fill("#passphrase", pw); await page.click("#unlock-btn");
    rec("throttled-after-failure", /wait/i.test(await page.locator("#status").textContent()), await page.locator("#status").textContent());
    await page.waitForTimeout(1200);
    await page.click("#unlock-btn");
    await page.waitForSelector("#picker:not([hidden])", { timeout: 60000 });
    rec("unlock-succeeds", /Authentication succeeded/.test(await page.locator("#status").textContent()), await page.locator("#status").textContent());
    rec("passphrase-field-cleared", (await page.inputValue("#passphrase")) === "");

    let matched = 0, tried = 0;
    for (const slot of Object.keys(expect).sort()) {
      const [area, lang, kind] = slot.split("/");
      await page.selectOption("#area", area); await page.selectOption("#lang", lang);
      const btn = page.locator(`#files button[data-slot="${slot}"]`);
      if (!(await btn.count())) { rec("button-" + slot, false, "no button"); continue; }
      const [dl] = await Promise.all([page.waitForEvent("download", { timeout: 60000 }), btn.click()]);
      const p = await dl.path(); tried++;
      const h = crypto.createHash("sha256").update(fs.readFileSync(p)).digest("hex");
      const ok = h === expect[slot]; if (ok) matched++;
      rec("download-bytes-" + slot, ok, `suggested=${dl.suggestedFilename()} sha256=${h.slice(0, 16)}`);
    }
    rec("all-downloads-match", tried > 0 && matched === tried, `${matched}/${tried}`);

    await page.click("#lock-btn");
    rec("lock-hides-picker", await page.locator("#picker").isHidden());
    rec("no-page-errors", errors.length === 0, errors.join(" | "));
  } catch (e) { rec("browser-run", false, e.stack || e); }
  await browser.close(); server.close();
  console.log(JSON.stringify({ results }));
})();
