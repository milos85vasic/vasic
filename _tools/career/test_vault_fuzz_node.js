// Batch helper for test_vault_fuzz.py (ONE node invocation for many cases).
// argv[2]: json file {mode:"aad"|"canon"|"vault", ...}.  Prints one JSON object to stdout.
const fs = require("fs"), path = require("path"), crypto = require("crypto");
const V = require("../../milosvasic.ru/assets/js/vault.js");
const job = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const sha = (ab) => crypto.createHash("sha256").update(Buffer.from(ab)).digest("hex");
(async () => {
  if (job.mode === "aad") {
    console.log(JSON.stringify({ out: job.cases.map((c) => V.buildAAD(c)) }));
  } else if (job.mode === "canon") {
    console.log(JSON.stringify({ out: job.cases.map((o) => V.canonicalJSON(o)) }));
  } else if (job.mode === "vault") {
    const root = job.root;
    const fetch = async (url) => {
      const p = path.join(root, decodeURIComponent(new URL(url).pathname.replace(/^\/downloads\/vault\//, "")));
      if (!fs.existsSync(p)) return { ok: false, status: 404, headers: new Map() };
      const buf = fs.readFileSync(p);
      return { ok: true, status: 200, headers: new Map(), text: async () => buf.toString("utf8"),
        arrayBuffer: async () => buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength) };
    };
    const files = await V.unlockAll(job.pw, { fetch, base: "https://site.test/admin/console.html" });
    console.log(JSON.stringify({ out: files.map((f) => ({ slot: f.slot, name: f.name, mime: f.mime, sha: sha(f.bytes) })) }));
  }
})().catch((e) => { console.log(JSON.stringify({ error: String(e && (e.code || e.message)) })); process.exit(1); });
