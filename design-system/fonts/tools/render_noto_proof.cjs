#!/usr/bin/env node
// Rendered proof for the Noto script faces: serves a design-system directory on a loopback port, opens
// fonts/noto/preview.html?lang=XX&theme=light|dark in HEADLESS chromium with a throw-away profile (never the user's),
// screenshots it, and asks the browser which font actually drew every glyph (CDP CSS.getPlatformFontsForNode).
//
//   node render_noto_proof.cjs --root DIR --out DIR [--langs ru,zh,...] [--themes light,dark]
//   --root  a directory that contains fonts/ (a design-system checkout; or job_seeker's web/static/design with --brand /brand/vasic-digital.css)
//   env     PLAYWRIGHT_MODULE=/path/to/node_modules/playwright (default: require('playwright'))
//
// PASS for a (lang, theme) means: the page text is drawn ONLY by shipped web fonts (isCustomFont) - zero glyphs from an OS
// font - and, for the CJK / Arabic / Devanagari languages, the face that drew the script glyphs is the expected Noto family.
// Exit 0 all pass, 1 a combination drew a glyph with a system font or the wrong family, 2 could not run.
const http = require("http"), fs = require("fs"), path = require("path"), os = require("os");
const arg = (k, d) => { const i = process.argv.indexOf("--" + k); return i > 0 ? process.argv[i + 1] : d; };
const root = path.resolve(arg("root", ".")), out = path.resolve(arg("out", "proof"));
const langs = arg("langs", "ru,sr,be,kk,zh,ja,ko,hi,ar,fa").split(","), themes = arg("themes", "light,dark").split(",");
const previewPath = arg("preview", "/fonts/noto/preview.html"), brand = arg("brand", "");
// CDP reports a CJK face by the family name inside the font file ("Noto Sans CJK SC"), not the @font-face name, so both count.
const EXPECT = { zh: ["Noto Sans SC", "Noto Sans CJK SC"], ja: ["Noto Sans JP", "Noto Sans CJK JP"], ko: ["Noto Sans KR", "Noto Sans CJK KR"], hi: ["Noto Sans Devanagari"], ar: ["Noto Sans Arabic"], fa: ["Noto Sans Arabic"],
                 ru: ["Inter"], sr: ["Inter"], be: ["Inter"], kk: ["Inter"] };
let pw;
try { pw = require(process.env.PLAYWRIGHT_MODULE || "playwright"); } catch (e) { console.error("UNDETERMINED: playwright not loadable: " + e.message); process.exit(2); }
const MIME = { ".html": "text/html", ".css": "text/css", ".woff2": "font/woff2", ".js": "text/javascript" };
const srv = http.createServer((q, s) => {
  const f = path.join(root, decodeURIComponent(q.url.split("?")[0]));
  if (!f.startsWith(root) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { s.writeHead(404); return s.end(); }
  s.writeHead(200, { "content-type": MIME[path.extname(f)] || "application/octet-stream" }); fs.createReadStream(f).pipe(s);
});
(async () => {
  fs.mkdirSync(out, { recursive: true });
  await new Promise(r => srv.listen(0, "127.0.0.1", r));
  const base = "http://127.0.0.1:" + srv.address().port;
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "noto-proof-"));
  const ctx = await pw.chromium.launchPersistentContext(profile, { headless: true, viewport: { width: 980, height: 560 } });
  const results = []; let bad = 0;
  for (const lang of langs) for (const theme of themes) {
    const page = await ctx.newPage(); const fetched = [];
    page.on("response", r => { if (r.url().endsWith(".woff2")) fetched.push(path.basename(r.url()) + ":" + r.status()); });
    await page.goto(base + previewPath + "?lang=" + lang + "&theme=" + theme + (brand ? "&brand=" + encodeURIComponent(brand) : ""));
    await page.waitForSelector("body[data-fonts-ready='1']", { timeout: 20000 });
    const cdp = await ctx.newCDPSession(page); await cdp.send("DOM.enable"); await cdp.send("CSS.enable");
    const doc = await cdp.send("DOM.getDocument", { depth: -1 });
    let custom = 0, system = 0; const used = {}, sysUsed = {};
    for (const id of ["h1", "lead", "bold", "h2", "mix", "num"]) {
      const n = await cdp.send("DOM.querySelector", { nodeId: doc.root.nodeId, selector: "#" + id });
      const pf = await cdp.send("CSS.getPlatformFontsForNode", { nodeId: n.nodeId });
      for (const f of pf.fonts) { if (f.isCustomFont) { custom += f.glyphCount; used[f.familyName] = (used[f.familyName] || 0) + f.glyphCount; } else { system += f.glyphCount; sysUsed[f.familyName] = (sysUsed[f.familyName] || 0) + f.glyphCount; } }
    }
    const png = path.join(out, "noto-" + lang + "-" + theme + ".png");
    await page.screenshot({ path: png });
    const want = EXPECT[lang];
    const ok = system === 0 && want.some(n => (used[n] || 0) > 0);
    if (!ok) bad++;
    results.push({ lang, theme, ok, expectFamily: want.join("|"), customGlyphs: custom, systemGlyphs: system, customFonts: used, systemFonts: sysUsed, woff2: fetched, png: path.basename(png) });
    console.log((ok ? "PASS " : "FAIL ") + lang + "/" + theme + " expect=" + want.join("|") + " custom=" + JSON.stringify(used) + " system=" + JSON.stringify(sysUsed) + " fetched=" + fetched.join(","));
    await page.close();
  }
  fs.writeFileSync(path.join(out, "report.json"), JSON.stringify(results, null, 1));
  await ctx.close(); srv.close(); fs.rmSync(profile, { recursive: true, force: true });
  console.log(bad ? "FAIL " + bad + " of " + results.length : "OK " + results.length + " of " + results.length);
  process.exit(bad ? 1 : 0);
})().catch(e => { console.error("UNDETERMINED: " + e.message); srv.close(); process.exit(2); });
