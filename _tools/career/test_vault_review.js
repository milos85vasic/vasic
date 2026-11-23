// Review-finding tests for vault.js: size limits on bytes actually read; every slot record validated in openVault.
// Usage: node test_vault_review.js   (self-contained: builds a vault with node:crypto; exit 1 on any failure)
const crypto = require("crypto");
const V = require("../../milosvasic.ru/assets/js/vault.js");
const results = [];
const rec = (n, ok, d) => { results.push(ok); console.log((ok ? "PASS " : "FAIL ") + n + (d ? " :: " + d : "")); };

const b64 = (b) => Buffer.from(b).toString("base64url");
function build(pw, slots, tamper) {
  const salt = crypto.randomBytes(16), saltS = b64(salt);
  const key = crypto.pbkdf2Sync(pw.normalize("NFC"), salt, 600000, 32, "sha256");
  const files = {}, m = { v: 1, alg: "AES-256-GCM", kdf: "sha256", iters: 600000, salt: saltS, slots: {} };
  for (const slot of slots) {
    const name = slot.replace(/\//g, "-") + ".pdf", mime = "application/pdf";
    const aad = V.buildAAD({ salt: saltS, slot, name, mime });
    const nonce = crypto.randomBytes(12);
    const c = crypto.createCipheriv("aes-256-gcm", key, nonce); c.setAAD(Buffer.from(aad));
    const ct = Buffer.concat([c.update(Buffer.alloc(100, 1)), c.final(), c.getAuthTag()]);
    const file = `${slot}.${b64(nonce)}.bin`;
    files["/v/" + file] = ct;
    m.slots[slot] = { name, mime, nonce: b64(nonce), aad, file };
  }
  if (tamper) tamper(m);
  files["/v/manifest.json"] = Buffer.from(JSON.stringify(m));
  return files;
}
// fake fetch: NO content-length header; body served from memory.  `bigBlob` replaces every blob.
const mkFetch = (files, bigBlob) => async (url) => {
  const p = new URL(url).pathname; let buf = files[p];
  if (!buf) return { ok: false, status: 404, headers: new Map() };
  if (bigBlob && p.endsWith(".bin")) buf = bigBlob;
  return { ok: true, status: 200, headers: new Map(),
    text: async () => buf.toString("utf8"),
    arrayBuffer: async () => buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
};
const opts = (files, extra) => Object.assign({ fetch: mkFetch(files), base: "https://x.test/a.html", manifestUrl: "/v/manifest.json" }, extra);

(async () => {
  const pw = "correct-Horse-" + crypto.randomBytes(6).toString("hex");
  // 1. oversize blob without content-length is refused by byte count
  const f = build(pw, ["a/en/cv"]);
  try { await V.openVault(pw, opts(f, { maxBlob: 50 })); rec("blob-size-by-bytes-read", false, "opened"); }
  catch (e) { rec("blob-size-by-bytes-read", e.code === "FORMAT", e.code); }
  // 2. oversize manifest without content-length
  try { await V.openVault(pw, opts(f, { maxManifest: 20 })); rec("manifest-size-by-bytes-read", false, "opened"); }
  catch (e) { rec("manifest-size-by-bytes-read", e.code === "FORMAT", e.code); }
  // 3. a malformed NON-first slot record is rejected at open time
  const g = build(pw, ["a/en/cv", "b/en/cv"], (m) => { m.slots["b/en/cv"].extra = 1; });
  try { await V.openVault(pw, opts(g)); rec("validate-every-record-at-open", false, "opened"); }
  catch (e) { rec("validate-every-record-at-open", e.code === "FORMAT", e.code); }
  const h = build(pw, ["a/en/cv", "b/en/cv"], (m) => { m.slots["b/en/cv"].file = "../x.bin"; });
  try { await V.openVault(pw, opts(h)); rec("bad-file-name-at-open", false, "opened"); }
  catch (e) { rec("bad-file-name-at-open", e.code === "FORMAT", e.code); }
  // 4. control: a good vault still opens; NFD passphrase opens the NFC-sealed vault
  const pu = "Ünï-" + crypto.randomBytes(6).toString("hex");
  const k = build(pu, ["a/en/cv"]);
  try { const v = await V.openVault(pu.normalize("NFD"), opts(k)); rec("control-opens-nfd", v.slots.length === 1); }
  catch (e) { rec("control-opens-nfd", false, e.code + " " + e.message); }
  process.exit(results.every(Boolean) ? 0 : 1);
})();
