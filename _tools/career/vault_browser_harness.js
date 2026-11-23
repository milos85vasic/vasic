// Shared helper for the NEW browser-driven vault tests (throttle test, benchmark).  Mirrors the static-server +
// console-page rendering of test_vault_browser.js (which self-executes on require and therefore cannot be imported
// without editing it; it is deliberately NOT modified).  Exposes: startServer(vaultDir) -> {base, close, hits},
// launch() -> chromium browser.
const fs = require("fs"), path = require("path"), http = require("http");
const ROOT = path.resolve(__dirname, "../..");
const SITE = path.join(ROOT, "milosvasic.ru");
const { chromium } = require(path.join(ROOT, "_tests/node_modules/playwright-core"));

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

async function startServer(vaultDir) {
  const hits = { manifest: 0, blob: 0, other: 0 };
  const server = http.createServer((req, res) => {
    const p = decodeURIComponent(req.url.split("?")[0]);
    let file = null, body = null;
    if (p === "/downloads/vault/manifest.json") hits.manifest++;
    else if (p.startsWith("/downloads/vault/")) hits.blob++;
    else hits.other++;
    if (p === "/admin/console.html") body = renderConsole();
    else if (p.startsWith("/downloads/vault/")) file = path.join(vaultDir, p.slice("/downloads/vault/".length));
    else if (p.startsWith("/assets/")) file = path.join(SITE, p);
    const rootOf = file && file.startsWith(vaultDir) ? vaultDir : SITE;
    if (file && !path.resolve(file).startsWith(path.resolve(rootOf))) file = null;
    if (body === null && file && fs.existsSync(file) && fs.statSync(file).isFile()) body = fs.readFileSync(file);
    if (body === null) { res.writeHead(404); return res.end("nf"); }
    res.writeHead(200, { "content-type": mime[path.extname(p)] || (p.endsWith(".html") ? "text/html" : "application/octet-stream") });
    res.end(body);
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  return { base: `http://127.0.0.1:${server.address().port}`, hits, close: () => server.close() };
}
const launch = () => chromium.launch();
module.exports = { startServer, launch, SITE, ROOT };
