// Real-browser throttle/load proof for admin/console.html (the static vault has no server to DDoS; the only
// brute-force-facing control is the client-side throttle, which is UX, not defence -- see vault.py threat model).
// env: VAULT_DIR, VAULT_PW.  Prints {results:[{name,ok,detail}], metrics:{...}}.
const { startServer, launch } = require("./vault_browser_harness.js");
const vaultDir = process.env.VAULT_DIR, pw = process.env.VAULT_PW;
const results = [], metrics = {};
const rec = (name, ok, detail) => results.push({ name, ok: !!ok, detail: String(detail === undefined ? "" : detail) });
const statusText = (page) => page.locator("#status").textContent();

(async () => {
  const srv = await startServer(vaultDir);
  const browser = await launch();
  try {
    const page = await (await browser.newContext()).newPage();
    const errors = []; page.on("pageerror", (e) => errors.push(String(e)));
    await page.clock.install({ time: new Date("2026-01-01T00:00:00Z") });   // deterministic Date.now() for the throttle
    await page.goto(srv.base + "/admin/console.html");

    // ---- Phase 1: one real failed attempt arms the throttle -------------------------------------------
    await page.fill("#passphrase", pw + "-wrong"); await page.click("#unlock-btn");
    await page.waitForFunction(() => /Authentication failed/.test(document.getElementById("status").textContent), null, { timeout: 60000 });
    const after1 = srv.hits.manifest;
    rec("first-wrong-attempt-did-one-real-attempt", after1 === 1, `manifest fetches=${after1}`);

    // ---- Phase 2: 200 rapid wrong attempts in ONE task (Date.now frozen) --------------------------------
    const burst = await page.evaluate(() => {
      const f = document.getElementById("unlock"), pwi = document.getElementById("passphrase");
      const seen = new Set();
      for (let i = 0; i < 200; i++) { pwi.value = "wrong-guess-" + i; f.requestSubmit(); seen.add(document.getElementById("status").textContent); }
      return [...seen];
    });
    await page.waitForTimeout(300);
    metrics.burst200_manifest_fetches_added = srv.hits.manifest - after1;
    rec("200-rapid-attempts-all-refused-no-network", srv.hits.manifest === after1,
        `manifest fetches before=${after1} after=${srv.hits.manifest}; statuses=${JSON.stringify(burst)}`);
    rec("refusal-message-shown", burst.length === 1 && /Too many failures; wait [0-9]+ s/.test(burst[0]), burst[0]);
    rec("unlock-button-not-stuck-disabled", await page.locator("#unlock-btn").isEnabled());

    // ---- Phase 3: exponential back-off 1,2,4,8,16,30,30 s (capped) via fake clock ------------------------
    const waits = [];
    const readWait = async () => { const t = await statusText(page); const m = /wait ([0-9]+) s/.exec(t); return m ? +m[1] : null; };
    waits.push(await readWait());                              // after failure #1
    for (let k = 2; k <= 7; k++) {
      await page.clock.fastForward(31000);                     // lock expired
      const before = srv.hits.manifest;
      await page.fill("#passphrase", pw + "-wrong-" + k); await page.click("#unlock-btn");
      await page.waitForFunction(() => /Authentication failed/.test(document.getElementById("status").textContent), null, { timeout: 60000 });
      await page.fill("#passphrase", "x"); await page.click("#unlock-btn");     // immediate retry -> refused
      waits.push(await readWait());
      if (srv.hits.manifest !== before + 1) rec("attempt-" + k + "-one-fetch", false, `fetches=${srv.hits.manifest - before}`);
    }
    metrics.backoff_seconds = waits;
    rec("exponential-backoff-capped-at-30s", JSON.stringify(waits) === JSON.stringify([1, 2, 4, 8, 16, 30, 30]), JSON.stringify(waits));

    // ---- Phase 4: lockout is temporary and the right passphrase still works afterwards ----------------
    await page.clock.fastForward(31000);
    await page.fill("#passphrase", pw); await page.click("#unlock-btn");
    await page.waitForSelector("#picker:not([hidden])", { timeout: 60000 });
    rec("correct-passphrase-unlocks-after-lock-expiry", /Authentication succeeded/.test(await statusText(page)), await statusText(page));
    rec("success-resets-failure-counter", await (async () => {
      await page.click("#lock-btn");
      await page.fill("#passphrase", pw + "-w"); await page.click("#unlock-btn");
      await page.waitForFunction(() => /Authentication failed/.test(document.getElementById("status").textContent), null, { timeout: 60000 });
      await page.fill("#passphrase", "x"); await page.click("#unlock-btn");
      return (await readWait()) === 1;
    })(), "first failure after a success locks for 1 s again");
    rec("no-page-errors", errors.length === 0, errors.join(" | "));

    // ---- Phase 5 (finding probe): burst BEFORE any failure is registered (lockedUntil = 0) -------------
    const p2 = await (await browser.newContext()).newPage();
    await p2.goto(srv.base + "/admin/console.html");
    const b0 = srv.hits.manifest;
    await p2.evaluate(() => {
      const f = document.getElementById("unlock"), pwi = document.getElementById("passphrase");
      for (let i = 0; i < 200; i++) { pwi.value = "cold-burst-" + i; f.requestSubmit(); }
    });
    await p2.waitForFunction(() => /failed|Could not|Too many/i.test(document.getElementById("status").textContent), null, { timeout: 120000 });
    await p2.waitForTimeout(500);
    metrics.coldburst200_manifest_requests = srv.hits.manifest - b0;
    const finalStatus = await p2.locator("#status").textContent();
    const stuck = await p2.locator("#picker").isHidden();
    rec("cold-burst-survives-and-ends-failed-locked-out", /Authentication failed/.test(finalStatus) && stuck && errors.length === 0,
        `${srv.hits.manifest - b0} manifest requests for 200 submits issued before the first failure (throttle arms only AFTER a failure; in-flight attempts abort each other); final status="${finalStatus}"`);
  } catch (e) { rec("browser-run", false, e.stack || e); }
  await browser.close(); srv.close();
  console.log(JSON.stringify({ results, metrics }));
})();
