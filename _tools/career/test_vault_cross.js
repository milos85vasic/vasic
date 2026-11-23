// Cross-language vault test: decrypt a vault sealed by Python using the REAL vault.js decrypt path.
// env: VAULT_DIR, VAULT_PW, EXPECT (json file: {slot: sha256hex}), VECTOR (json: {aad_inputs..., aad})
// Prints one JSON object {results:[{name,ok,detail}]}; exit 0 always (Python judges).
const fs = require("fs"), os = require("os"), path = require("path"), crypto = require("crypto");
const V = require("../../milosvasic.ru/assets/js/vault.js");
const dir = process.env.VAULT_DIR, pw = process.env.VAULT_PW;
const expect = JSON.parse(fs.readFileSync(process.env.EXPECT, "utf8"));
const vector = JSON.parse(fs.readFileSync(process.env.VECTOR, "utf8"));
const results = [];
const rec = (name, ok, detail) => results.push({ name, ok: !!ok, detail: String(detail === undefined ? "" : detail) });

const fakeFetch = (root) => async (url) => {
  const u = new URL(url);
  const p = path.join(root, decodeURIComponent(u.pathname.replace(/^\/downloads\/vault\//, "")));
  if (!fs.existsSync(p)) return { ok: false, status: 404, headers: new Map() };
  const buf = fs.readFileSync(p);
  return { ok: true, status: 200, headers: new Map(),
    text: async () => buf.toString("utf8"),
    arrayBuffer: async () => buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
};
const opts = (root) => ({ fetch: fakeFetch(root), base: "https://site.test/admin/console.html" });
const sha = (ab) => crypto.createHash("sha256").update(Buffer.from(ab)).digest("hex");
const tmpCopy = () => { const d = fs.mkdtempSync(path.join(os.tmpdir(), "vcross-")); fs.cpSync(dir, d, { recursive: true }); return d; };
const manifestOf = (d) => JSON.parse(fs.readFileSync(path.join(d, "manifest.json"), "utf8"));
const saveManifest = (d, m) => fs.writeFileSync(path.join(d, "manifest.json"), JSON.stringify(m));

async function expectFail(name, root, pass, code) {
  try { await V.unlockAll(pass, opts(root)); rec(name, false, "unexpectedly decrypted"); }
  catch (e) { rec(name, e.code === code, `code=${e.code} name=${e.name}`); }
}

(async () => {
  // 1. positive: every slot decrypts to the Python plaintext (sha256 + count)
  try {
    const files = await V.unlockAll(pw, opts(dir));
    const bad = files.filter((f) => sha(f.bytes) !== expect[f.slot]);
    rec("decrypt-all-match-python", files.length === Object.keys(expect).length && !bad.length,
        `${files.length} slots, mismatches=${bad.length}`);
  } catch (e) { rec("decrypt-all-match-python", false, `${e.code} ${e.message}`); }

  // 2. AAD canonicalization vector (non-ASCII, astral, controls)
  const aad = V.buildAAD(vector.fields);
  rec("aad-bytes-identical-nonascii", aad === vector.aad, aad);

  await expectFail("wrong-passphrase", dir, pw + "x", "AUTH_FAILED");

  let d = tmpCopy(); let m = manifestOf(d); const slots = Object.keys(m.slots).sort();
  const first = slots[0], last = slots[slots.length - 1];
  const f = path.join(d, m.slots[last].file); const b = fs.readFileSync(f); b[5] ^= 1; fs.writeFileSync(f, b);
  await expectFail("flipped-bit", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d); m.slots[first].name = "evil.pdf"; saveManifest(d, m);
  await expectFail("edited-name", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d); m.slots[first].name = "evil.pdf"; m.slots[first].aad = V.buildAAD({ salt: m.salt, slot: first, name: "evil.pdf", mime: m.slots[first].mime }); saveManifest(d, m);
  await expectFail("edited-name-with-recomputed-aad", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d); const other = slots[1];
  // slot substitution: serve slot[1]'s blob+record under slot[0]'s id
  fs.copyFileSync(path.join(d, m.slots[other].file), path.join(d, m.slots[first].file));
  m.slots[first] = Object.assign({}, m.slots[other], { file: m.slots[first].file }); saveManifest(d, m);
  await expectFail("slot-substitution", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d); const mv = Object.assign({}, m.slots[last]); const lastFile = mv.file; delete m.slots[last]; mv.file = "zz/xx/forged." + mv.nonce + ".bin"; m.slots["zz/xx/forged"] = mv;
  fs.copyFileSync(path.join(d, lastFile), (fs.mkdirSync(path.join(d, "zz/xx"), { recursive: true }), path.join(d, mv.file)));
  saveManifest(d, m);
  await expectFail("edited-slot", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d);
  const tf = path.join(d, m.slots[last].file); const tb = fs.readFileSync(tf); fs.writeFileSync(tf, tb.subarray(0, tb.length - 7));
  await expectFail("truncated-blob", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d); fs.writeFileSync(path.join(d, m.slots[last].file), Buffer.alloc(3));
  await expectFail("blob-shorter-than-tag", d, pw, "AUTH_FAILED"); fs.rmSync(d, { recursive: true });

  d = tmpCopy(); m = manifestOf(d); fs.rmSync(path.join(d, m.slots[last].file));
  await expectFail("missing-blob-404", d, pw, "NETWORK"); fs.rmSync(d, { recursive: true });

  for (const [label, mut] of [["version-2", (x) => { x.v = 2; }], ["iters-1", (x) => { x.iters = 1; }],
      ["alg-changed", (x) => { x.alg = "AES-128-GCM"; }], ["kdf-changed", (x) => { x.kdf = "sha1"; }],
      ["iters-string", (x) => { x.iters = "600000"; }]]) {
    d = tmpCopy(); m = manifestOf(d); mut(m); saveManifest(d, m);
    await expectFail("header-" + label, d, pw, "FORMAT"); fs.rmSync(d, { recursive: true });
  }
  d = tmpCopy(); m = manifestOf(d); m.slots["../evil"] = m.slots[first]; saveManifest(d, m);
  try { const v = await V.openVault(pw, opts(d)); await v.decryptSlot("../evil"); rec("slot-path-traversal", false, "accepted"); }
  catch (e) { rec("slot-path-traversal", e.code === "FORMAT", e.code); } fs.rmSync(d, { recursive: true });

  // blob URL is resolved against the manifest URL, not the page
  const seen = [];
  const spy = async (url, o) => { seen.push(url); return fakeFetch(dir)(url, o); };
  await V.openVault(pw, { fetch: spy, base: "https://site.test/deep/page/x.html", manifestUrl: "/downloads/vault/manifest.json" });
  rec("blob-url-relative-to-manifest", seen[1] && seen[1].startsWith("https://site.test/downloads/vault/"), seen[1]);

  // abort support
  const ac = new AbortController(); ac.abort();
  try { await V.openVault(pw, Object.assign(opts(dir), { signal: ac.signal, fetch: async (u, o) => { if (o.signal.aborted) { const e = new Error("a"); e.name = "AbortError"; throw e; } return fakeFetch(dir)(u, o); } })); rec("abort", false, "no abort"); }
  catch (e) { rec("abort", e.name === "AbortError", e.name); }

  console.log(JSON.stringify({ results }));
})();
