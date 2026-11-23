// DOM-stub tests for vault-console.js lifecycle: per-operation abort controllers + generation counter.
// Usage: node test_vault_console.js   (no browser needed; exit 1 on failure)
const fs = require("fs"), path = require("path"), vm = require("vm");
const SRC = fs.readFileSync(path.join(__dirname, "../../milosvasic.ru/assets/js/vault-console.js"), "utf8");
const results = [];
const rec = (n, ok, d) => { results.push(ok); console.log((ok ? "PASS " : "FAIL ") + n + (d ? " :: " + d : "")); };
const tick = () => new Promise((r) => setImmediate(r));

function mkEl(id) {
  const l = {};
  return { id, value: "", textContent: "", hidden: false, disabled: false, className: "", dataset: {}, children: [],
    addEventListener(t, f) { (l[t] = l[t] || []).push(f); },
    fire(t, ev) { (l[t] || []).forEach((f) => f(ev || { preventDefault() {} })); },
    appendChild(c) { this.children.push(c); return c; }, click() { this.clicked = true; }, remove() {} };
}
function setup() {
  const els = {}; ["status", "picker", "lock-btn", "files", "passphrase", "unlock", "unlock-btn", "area", "lang"].forEach((i) => (els[i] = mkEl(i)));
  els.area.value = "a"; els.lang.value = "en";
  els.picker.hidden = true; els["lock-btn"].hidden = true;
  const created = []; let objUrls = 0;
  const win = mkEl("window");
  const document = { getElementById: (i) => els[i], createElement: () => mkEl("x"), body: mkEl("body") };
  const pending = { open: [], dec: [] };
  const MVVault = {
    openVault: (pw, o) => new Promise((res, rej) => pending.open.push({ pw, o, res, rej })),
  };
  const ctx = { document, window: win, MVVault, AbortController, Blob, setTimeout: () => 0, Date, Math, Array, Set,
    URL: { createObjectURL: () => { objUrls++; return "blob:x" + objUrls; }, revokeObjectURL() {} } };
  vm.runInNewContext(SRC, ctx);
  return { els, win, pending, objUrls: () => objUrls, created };
}
const handle = (pending, slots) => ({ slots, decryptSlot: (slot, o) => new Promise((res, rej) => pending.dec.push({ slot, o, res, rej })) });
const SLOTS = [{ slot: "a/en/cv", name: "a.pdf", mime: "application/pdf" }];
const abortErr = () => Object.assign(new Error("x"), { name: "AbortError" });

(async () => {
  { // 1. lock() while unlock pending: signal aborted; late success does nothing
    const t = setup(); t.els.passphrase.value = "secret-phrase";
    t.els.unlock.fire("submit");
    const op = t.pending.open[0];
    t.els["lock-btn"].fire("click");
    rec("lock-aborts-pending-unlock", op.o.signal.aborted === true);
    op.res(handle(t.pending, SLOTS)); await tick(); await tick();
    rec("late-unlock-after-lock-does-nothing", t.els.picker.hidden === true && t.els.passphrase.value === "" &&
        !/succeeded/.test(t.els.status.textContent), `picker.hidden=${t.els.picker.hidden} status=${t.els.status.textContent}`);
    rec("unlock-button-reenabled-after-lock", t.els["unlock-btn"].disabled === false);
  }
  { // 2. lock() while a download is pending: aborted; late completion creates no object URL
    const t = setup(); t.els.passphrase.value = "secret-phrase";
    t.els.unlock.fire("submit"); t.pending.open[0].res(handle(t.pending, SLOTS)); await tick(); await tick();
    const btn = t.els.files.children[0]; rec("download-button-rendered", !!btn);
    btn.fire("click"); const d1 = t.pending.dec[0];
    btn.disabled = false; btn.fire("click"); const d2 = t.pending.dec[1];     // second concurrent download
    rec("per-download-controllers-distinct", d1.o.signal !== d2.o.signal);
    t.els["lock-btn"].fire("click");
    rec("lock-aborts-all-downloads", d1.o.signal.aborted && d2.o.signal.aborted);
    d1.res({ bytes: new Uint8Array(3), mime: "application/pdf", name: "a.pdf" }); await tick(); await tick();
    rec("late-download-after-lock-does-nothing", t.objUrls() === 0 && !/Downloaded/.test(t.els.status.textContent), `objUrls=${t.objUrls()} status=${t.els.status.textContent}`);
  }
  { // 3. failure clears the passphrase field
    const t = setup(); t.els.passphrase.value = "wrong-phrase";
    t.els.unlock.fire("submit"); t.pending.open[0].rej(Object.assign(new Error("Authentication failed"), { code: "AUTH_FAILED" }));
    await tick(); await tick();
    rec("failure-clears-passphrase", t.els.passphrase.value === "", JSON.stringify(t.els.passphrase.value));
  }
  { // 4. a new unlock aborts the previous pending one and a late result of the old one is ignored
    const t = setup(); t.els.passphrase.value = "first-phrase";
    t.els.unlock.fire("submit"); const first = t.pending.open[0];
    t.els.passphrase.value = "second-phrase"; t.els.unlock.fire("submit");
    rec("new-unlock-aborts-previous", first.o.signal.aborted === true);
    first.res(handle(t.pending, SLOTS)); await tick(); await tick();
    rec("stale-unlock-result-ignored", t.els.picker.hidden === true);
  }
  process.exit(results.every(Boolean) ? 0 : 1);
})();
