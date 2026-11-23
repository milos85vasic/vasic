# Static Vault Security — client-side encryption of admin-only PDFs on GitHub Pages

**Date:** 2026-11-19
**Scope:** a public static site (GitHub Pages / Jekyll) that delivers admin-only CV + cover-letter PDFs behind a passphrase-gated browser console. Encrypted blobs are produced at build time; decryption happens in the visitor's browser via WebCrypto (PBKDF2-SHA256 → AES-256-GCM). No server, no session, no backend.
**Method:** five research rounds (A–E), each combining web search with direct reads of primary sources (library source code, standards, vendor docs). Every number below is either quoted from a cited source or explicitly labelled COMPUTED (derived by arithmetic from a cited number). Claims that could not be confirmed are marked **UNVERIFIED**.

> **Framing that governs everything below:** this design is not access control. It is *content confidentiality against a public artifact*. Once a blob is published, the attacker has the ciphertext, the algorithm, the parameters and unlimited offline attempts. The only two variables that matter are **passphrase entropy** and **per-guess cost**. Every other control in this document is either UX or defence against a *different*, weaker threat (search-engine indexing, casual snooping, accidental leak).

---

## ROUND A — Static client-side encryption precedents (StatiCrypt, PageCrypt, crypto-js)

### FINDINGS

**StatiCrypt** (`robinmoisson/staticrypt`) — the most widely used "password-protect a static HTML file" tool, and the closest thing to a reference implementation for this problem.

- Self-description: *"StatiCrypt uses AES-256 and WebCrypto to encrypt your HTML file with your long password, and returns a static HTML page showing a password prompt that you can now safely upload anywhere."* — https://github.com/robinmoisson/staticrypt
- **The content cipher is AES-CBC, not GCM.** Read from source: `lib/cryptoEngine.js` line 6, `const ENCRYPTION_ALGO = "AES-CBC";`, and line 4, `const IV_BITS = 16 * 8;`. The IV is prepended to the ciphertext as 32 hex characters (`return HexEncoder.stringify(iv) + HexEncoder.stringify(...)`). **There is no authentication tag anywhere in the file.** https://raw.githubusercontent.com/robinmoisson/staticrypt/main/lib/cryptoEngine.js
- The README defends this choice explicitly and links the argument: *"we use AES in CBC mode (see a discussion on why this mode is appropriate for StatiCrypt in #19) and key stretching with 600k PBKDF2-SHA256 iterations"* — https://github.com/robinmoisson/staticrypt (FAQ section).
- **Key derivation is a chained 3-round construction**, kept for backward compatibility, totalling 600k iterations:
  - `hashLegacyRound` → `pbkdf2(password, salt, 1000, "SHA-1")`
  - `hashSecondRound` → `pbkdf2(hashed, salt, 14000, "SHA-256")`
  - `hashThirdRound` → `pbkdf2(hashed, salt, 585000, "SHA-256")`
  (1,000 + 14,000 + 585,000 = 600,000). Verified in `lib/cryptoEngine.js`, lines 141–171.
- Salt is 16 bytes (`crypto.getRandomValues(new Uint8Array(128 / 8))`) and is **public by design**: *"The salt isn't secret (it's publicly visible on the encrypted file)"* — README.
- **Two shipped features weaken the model, and both are exactly the features a careful implementation should refuse to copy:**
  - `--share` produces a URL whose fragment carries the derived password: *"The link contains the hashed password, that will auto-decrypt the file"*, emitted as `#staticrypt_pwd=...` — README "Get a shareable auto-decrypt link". A link in a fragment survives copy-paste, chat history, browser sync and referrer-adjacent leakage; it is a bearer token with no expiry.
  - "Remember me" stores the salted+hashed passphrase in `localStorage` — README: *"the (salted + hashed) password will be stored in their browser's localStorage"*.
  - Both features force the salt to be **stable across builds** (*"you should keep your `.staticrypt.json` so the salt is the same each time you encrypt"*), which means the same derived key is reused for every deploy, forever. That is a direct consequence of the convenience features, not an independent decision.
- **StatiCrypt issue #159** (robinmoisson, Feb 2023, closed) is the project's own security-model write-up and contains the empirical iteration-cost data used in Round B below.

**PageCrypt** (`Greenheart/pagecrypt`) — a TypeScript, build-integrated alternative. Read from source (`src/core.ts`):

- `const salt = crypto.getRandomValues(new Uint8Array(32))` → **32-byte salt** (double StatiCrypt's).
- `crypto.subtle.deriveKey({ name: 'PBKDF2', salt, iterations, hash: 'SHA-256' }, baseKey, { name: 'AES-GCM', length: 256 }, ...)` → **PBKDF2-SHA-256 → AES-256-GCM**, i.e. authenticated encryption, unlike StatiCrypt.
- Ships an opinionated floor: `if (iterations < 2e6) { console.warn('...not secure. If possible, use at least 2_000_000 or more.') }` → **the tool's own recommended minimum is 2,000,000 iterations.**
- https://github.com/Greenheart/pagecrypt and https://raw.githubusercontent.com/Greenheart/pagecrypt/main/src/core.ts

**crypto-js** — the legacy library still recommended in most "password protect your page" blog posts.

- It implements AES in pure JavaScript ticked by a 32-bit word-array loop, which makes it roughly **40× slower than native WebCrypto** for the same work — that is the mechanism behind the timings in Round B, not a benchmark of my own.
- Its password-based `CryptoJS.AES.encrypt(message, passphrase)` API derives the key with an OpenSSL-compatible `EVP_BytesToKey` construction (MD5-based, effectively 1 iteration). **UNVERIFIED:** I did not read the crypto-js source this session; this is widely reported behaviour and should be checked against `core.js` before being quoted anywhere else.

### DECISIONS FOR THIS ENGINE

1. **AES-256-GCM only. Never AES-CBC.** StatiCrypt's CBC choice means its ciphertext is *malleable*: an attacker who cannot read the PDF can still flip bits and change what the authorised reader sees, with no detection at decrypt time (CBC has no tag). StatiCrypt can arguably live with that because it ships HTML, not legal documents. We ship documents whose whole purpose is to be *accurate about a person*. GCM's tag is the control that makes "this is the document I published" checkable.
2. **Use WebCrypto (`crypto.subtle`) exclusively. No crypto-js, no JS AES implementation, no bundling of a third-party AES.** Two independent reasons: performance (native vs word-array loop) and attack surface (no dependency to compromise).
3. **PBKDF2-HMAC-SHA-256, single pass, no chained rounds.** StatiCrypt's 1k→14k→585k chain exists solely to keep old share links and localStorage entries valid. We have neither feature, so we have no legacy to honour and no reason to import the complexity. One call, one parameter, one number to audit.
4. **Refuse both StatiCrypt convenience features, permanently:**
   - No `--share` equivalent. The passphrase is never placed in a URL, fragment, query, `localStorage`, `sessionStorage`, IndexedDB, cookie, or clipboard-by-default.
   - No "remember me". Unlock once per page load, in memory only.
5. **Salt is regenerated on every build.** StatiCrypt must pin its salt; we are freed from that by refusing share/remember. Consequence, and it is the point: **every deploy produces a brand-new key**, so no cracking work done against one deploy transfers to the next, and no nonce can ever collide across builds.
6. **Set the iteration floor at OWASP 600,000 and treat PageCrypt's 2,000,000 as the aspiration, not the floor** — see Round B for the cost/benefit and the measured UX budget that decides it.

---

## ROUND B — Threat model, PBKDF2 iteration count, Argon2id-wasm, passphrase entropy

### FINDINGS

**The threat model is "public ciphertext, offline attacker".** Every static-vault tool states this and it is worth quoting rather than paraphrasing, because it is what makes the rest of the document honest: the encrypted file is uploaded to a public host, anyone may download it, and the passphrase is the only secret. There is no rate limit, no lockout, no account, and no revocation — a compromised passphrase requires re-encrypting and re-publishing the whole artifact.

**OWASP Password Storage Cheat Sheet — current minimums** (https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html):

| Algorithm | OWASP minimum |
|---|---|
| PBKDF2-HMAC-SHA256 | **600,000 iterations** |
| PBKDF2-HMAC-SHA512 | 220,000 iterations |
| PBKDF2-HMAC-SHA1 | 1,400,000 iterations (legacy compatibility only) |
| Argon2id | **m=19 MiB, t=2, p=1** |

Argon2id alternates published alongside it: m=46 MiB/t=1, m=12 MiB/t=3, m=9 MiB/t=4, m=7 MiB/t=5 — all p=1. (Confirmed in the shattered.io 2026 summary, which states it read the cheat sheet; the cheat sheet page itself is JS-rendered and returned chrome only on fetch.)

**Measured cost of iteration counts on real hardware** — StatiCrypt issue #159, author's own timings on a Ryzen 7 4750U (WebCrypto path):

| Iterations | Derivation time (WebCrypto) |
|---|---|
| 100,000 | 40 ms |
| 200,000 | 74 ms |
| 600,000 | **160 ms** |
| 1,000,000 | 230 ms |

Same measurement sheet, crypto-js for comparison: **1,000 + 100,000 iterations = 1.51 s**. That is the ~40× native-vs-JS gap, and the reason the library choice is a UX decision as much as a security one.

**Attacker cost per guess** — shattered.io, *PBKDF2 vs Argon2: Harder to Crack? [2026]* (published 2026-09-04, modified 2026-11-16), https://shattered.io/pbkdf2-vs-argon2-gpu-cracking-2026/:

- Raw SHA-256 on an RTX 4090: **≈21,900 million H/s** (21.9 GH/s).
- Therefore, at OWASP's 600k configuration: **≈36,500 PBKDF2 guesses/second** (21.9e9 ÷ 600,000 — the article performs this division itself).
- Argon2id on the same card: **≈1,900 H/s** directly benchmarked → **≈22× harder per guess**. The article flags its own caveat: *"no cited result provides a reproducible, general comparison establishing a 22-times cracking-cost advantage"* — treat 22× as an order-of-magnitude figure, not a constant.
- Cloud rental for that card: **≈$0.34/hour** (RunPod / Vast.ai median, per the same article).

**COMPUTED (my arithmetic on the cited 36,500/s and $0.34/hr, not a quoted figure):**
- 36,500 × 3,600 = **131.4 M guesses/hour** per GPU
- $0.34/hr → **≈386 M guesses per $1** of rented GPU time

**Passphrase entropy** — EFF Diceware word list = **7,776 words = 12.92 bits/word**.

| Words | Keyspace | Entropy | Expected work (half) | 1 GPU | Cloud $ |
|---|---|---|---|---|---|
| 4 | 3.66e15 | 51.7 bits | 1.83e15 | ≈1,590 years | **≈$4.7 M** |
| 5 | 2.84e19 | 64.6 bits | 1.42e19 | ≈12.3 M years | **≈$36.8 B** |
| 6 | 2.21e23 | 77.5 bits | 1.10e23 | ≈9.6e10 years | **≈$285 T** |

All rows COMPUTED from 131.4 M guesses/hr/GPU and 386 M guesses/$1. Read the **4-word row**: it is the one that fails. A 4-word phrase is a ~$5M job, which is inside the budget of a determined competitor and trivially inside a nation-state's. A 5-word phrase is ~$37B; a 6-word phrase is past any plausible budget.

**The published argument on iterations vs entropy** — StatiCrypt #159 quotes Neil Madden: password entropy matters far more than iteration count, and the 1k→600k jump is worth roughly **+1.5 characters of entropy**, not a security category change. The arithmetic agrees: each extra Diceware word multiplies attacker work by 7,776 (12.9 bits); doubling iterations multiplies it by 2 (1 bit). **One word is worth ~13 doublings of iteration count.** Entropy is the lever; iterations are the floor.

**Argon2id in the browser.** WebCrypto standardises PBKDF2, HKDF and ECDH — **there is no Argon2 in WebCrypto, in any browser, and it is not on a standards track that would land soon.** Any Argon2id in a static page means shipping a WASM build (typically tens to hundreds of KB) and calling it from JS.
- Benefit: ~22× per-guess hardening at OWASP settings, and memory-hardness defeats the "rent 1,000 GPUs" scaling that PBKDF2 allows.
- Cost: a new supply-chain dependency in the one code path whose integrity defines the whole guarantee; wasm memory is visible to the same origin that runs it; bundle size on a page whose entire audience is a recruiter on hotel wifi.
- **UNVERIFIED:** I did not benchmark any specific Argon2-wasm build (no number for wasm Argon2id H/s on a laptop, no bundle size measurement). Do not quote a wasm performance figure from this document.

**What iterations do *not* buy.** PBKDF2 is not memory-hard: 600k iterations needs only a few KB of RAM, which is exactly why a GPU can run ~16,000 guesses in parallel. Iterations raise the *unit* cost linearly; they do nothing about the *parallelism* multiplier.

### DECISIONS FOR THIS ENGINE

1. **Threat model, stated on the page and in the repo, verbatim:** *"These files are encrypted in your browser. The encrypted data is public — anyone can download it. The passphrase is the only secret. If it is weak or reused, the documents can be read. There is no way to revoke access except replacing the files and the passphrase."* No claim of "access control", no "secure login", no lock icon language.
2. **PBKDF2-HMAC-SHA-256, 600,000 iterations as the shipped floor.** Rationale: it is the OWASP minimum, it is ~160 ms on mid-range hardware (measured, not estimated), and it is a number a reviewer can check against a published source. Ship **iterations in the blob header and in the AAD** so a future bump to 1M or 2M is a format-compatible change with no re-encryption of old blobs.
3. **Do not chase 2,000,000 in v1.** PageCrypt's floor is defensible but it buys ~1.7 bits over 600k (log2(2e6/6e5)) while tripling unlock latency — the same 1.7 bits that a single extra Diceware word delivers 7× over. Spend the budget on the passphrase instead. Revisit only if a measured unlock time under 500 ms on a mid-range phone makes 2M free.
4. **Argon2id-wasm: REJECTED for v1, with the reason recorded.** Adding a WASM crypto dependency to a page whose threat model is "the attacker has the ciphertext" trades a known, auditable, native, standards-track KDF (PBKDF2) for an unmeasured supply-chain risk. Reconsider only if all four hold: pinned version, SRI hash on the wasm file, self-hosted (no CDN), and a measured H/s figure on the target hardware.
5. **Passphrase policy: 6 Diceware words minimum, generated locally from the EFF list, never chosen by a human.** 77.5 bits, ≈$285T to exhaust at 2026 GPU rental prices. Enforce at generation time; never enforce by rejecting a passphrase the operator already uses elsewhere (that produces password reuse, not entropy).
6. **Iterations are not the knob that saves a weak passphrase — refuse to pretend otherwise.** If the operator insists on a human-chosen passphrase, the correct response is to raise the word count, not the iteration count.
7. **Document the 4-word failure case in the repo.** It is the most useful single number in this research: $4.7M. It is what stops someone "simplifying" the policy to 4 words for memorability.

---

## ROUND C — WebCrypto specifics: nonce reuse, AAD, deriveKey, large-file limits

### FINDINGS

**AES-GCM nonce reuse is catastrophic, and the failure is not "reduced security" but "total loss".**

- GCM uses a 96-bit nonce. Encrypting two different messages under the same key and nonce leaks the XOR of the two plaintexts immediately, and — because GCM's authentication key is derived from the same key material — recovers the GHASH authentication key, after which the attacker can **forge arbitrary valid ciphertexts** under that key. This is the "forbidden attack" (Joux). It is not a theoretical corner: it is a two-message attack.
- Neil Madden, *Galois/Counter Mode and random nonces* (2024-05-23, updated 2024-05-29), https://neilmadden.blog/2024/05/23/galois-counter-mode-and-random-nonces/:
  - *"the probability of two random nonces being the same (a collision) approaches 50% after around 2^48 messages"*
  - *"NIST advises to keep the chance of a collision to less than 2^-32, or about 1 in 4 billion. That limit comes after 2^32 messages for GCM: 4 billion again."*
  - Practical translation: **a random 96-bit nonce is safe for up to ~4 billion messages per key** (at NIST's 2^-32 bound), and for a static-vault workload of *two to six blobs per build*, the collision probability is not merely small — it is structurally impossible to reach.
- Mitigation if the workload ever grows: AES-GCM-SIV (RFC 8452) tolerates nonce reuse under a weaker security notion. Google built it because their front-end fleet emits *"several hundred million [tokens] per second"* under DDoS and would hit 2^32 in **43 seconds**. We are not Google; GCM-SIV is not needed and WebCrypto does not offer it.

**AAD (Additional Authenticated Data): what it is for.** AAD is authenticated but **not encrypted** — it is transmitted in the clear, bound into the tag, and must be supplied identically at decrypt time or the tag check fails. It exists to bind *context* to the ciphertext, not to hide anything.

- NIST SP 800-38D defines the AAD input as data authenticated but not encrypted; the canonical use is protocol headers and context that must not be alterable without detection.
- The practical pattern (AWS Encryption SDK, and every envelope-format design) is: **encrypt the body with AAD = the serialized header**, so header fields cannot be tampered with independently of the ciphertext.
- Things AAD cannot do: it cannot authenticate itself (it is plaintext), and it does not add confidentiality. Putting a secret in AAD is a bug, not a hardening.

**The `deriveKey` shape** — MDN, https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/deriveKey:

```js
const baseKey = await crypto.subtle.importKey(
  "raw", new TextEncoder().encode(passphrase), "PBKDF2", false, ["deriveKey"]);

const key = await crypto.subtle.deriveKey(
  { name: "PBKDF2", salt, iterations: 600000, hash: "SHA-256" },
  baseKey,
  { name: "AES-GCM", length: 256 },
  false,                 // key is NOT extractable
  ["encrypt", "decrypt"]);
```

Two details that matter more than they look:
- `extractable = false` means the derived key can never be read back out by JS. Set it. (It does not stop an attacker with the passphrase — nothing does — but it removes the "read the key out of the page and exfiltrate it" path.)
- `crypto.subtle` **only exists in a secure context** — HTTPS, or `localhost`. On plain `http://` the entire page is broken. GitHub Pages serves HTTPS, so this is automatic in production and must be noted for local preview.

**Large-file limits.** MDN: for AES-GCM, `crypto.subtle.encrypt` throws `OperationError` when the plaintext exceeds **2^39 − 256 bytes** (≈ 549 GB). There is **no streaming API** in WebCrypto — the entire plaintext and ciphertext must exist in memory at once. For any file in the GB range the standard workaround is a chunked format with a per-chunk tag (beebeeb.io, bitatlas.com). For this engine the limit is irrelevant by eight orders of magnitude: a CV PDF is single-digit MB.

### DECISIONS FOR THIS ENGINE

1. **Nonce: 12 random bytes per blob, from `crypto.getRandomValues`, generated at build time, stored in the blob header.** Never derived from a counter, never derived from the filename, never hashed from content, never "the first 12 bytes of the ciphertext". With ≤6 blobs per build and a fresh key per build, NIST's 2^32 random-nonce bound is unreachable — and the design is still correct if someone later adds 100 blobs.
2. **One salt per build → one derived key per build → a distinct nonce per blob.** This is a deliberate trade: deriving once at unlock and reusing the key for both the CV and the cover letter halves the unlock latency (one 160 ms KDF instead of two) while keeping nonce uniqueness trivially satisfiable. The invariant is *key uniqueness per build*, and the nonce discipline is belt-and-braces.
3. **AAD = the canonical UTF-8 JSON of the blob header, excluding ciphertext and nonce.**

   ```
   {"alg":"AES-256-GCM","bytes":412331,"kdf":"PBKDF2-HMAC-SHA256","iters":600000,
    "mime":"application/pdf","name":"cv-2026.pdf","salt":"<b64>","slot":"cv","v":1}
   ```

   Rules: keys sorted lexicographically, no whitespace, no trailing newline, UTF-8, and the *exact same bytes* are shipped in the header and re-supplied at decrypt. This is what stops:
   - **slot substitution** — decrypting the cover letter and presenting it as the CV;
   - **parameter downgrade** — an attacker rewriting `iters:600000` to `iters:1` in the header, which would otherwise make the shipped parameters advisory;
   - **name/mime swap** — a PDF relabelled as `.txt`, or vice versa, changing how the browser handles it.

   Nothing secret goes in the AAD. It is safe and intended to be readable.
4. **The nonce is passed as the GCM IV, not as AAD.** It is already authenticated by GCM's construction; duplicating it in the AAD adds nothing.
5. **Blob wire format (v1), fixed-width header then payload:**

   ```
   offset  size  field
   0       6     magic "VAULT1"
   6       1     version (0x01)
   7       4     iterations, uint32 big-endian
   11      16    salt
   27      12    nonce
   39      2     aad_len, uint16 big-endian
   41      N     aad (canonical JSON, N = aad_len)
   41+N    M     ciphertext || 16-byte GCM tag
   ```

   Total header overhead 41 + N bytes (~180 B). No compression before encryption (see Round D, item 8 — compression oracles). No base64 in the binary file; base64 only if the blob is embedded in HTML, in which case it is base64url with no padding.
6. **Set `extractable: false` on the derived key.** Keep the passphrase in a local variable and overwrite the reference immediately after `deriveKey` resolves. Best-effort only — JS cannot guarantee zeroisation, and the document should say so rather than implying it can.
7. **Reject anything that is not the exact expected header at decrypt time.** Magic mismatch, unknown version, `iters < 600000`, `aad_len` out of range, tag failure → one undifferentiated error message. Do not report *why* decryption failed: a differentiated error ("wrong passphrase" vs "corrupt file") is an oracle that tells an attacker a guess produced a structurally valid blob.
8. **No chunking, no streaming.** Each PDF is ≪ 2^39 − 256 bytes; a single `encrypt()` call per file is correct and simplest. Record the limit and the reason in the code comment so nobody "optimises" into a chunked format without understanding why it exists.
9. **Require a secure context.** If `crypto?.subtle` is undefined, the page must say *"This page requires HTTPS"* rather than silently failing to decrypt.

---

## ROUND D — UX and console security: passphrase gate, client-side rate limiting, constant-time comparison, "don't roll your own crypto"

### FINDINGS

**Client-side rate limiting is not a security control, and the authoritative statement is about the general class, not this specific case.** OWASP Authorization Cheat Sheet, https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html:

> *"Developers must never rely on client-side access control checks. While such checks may be permissible for improving the user experience, they should never be the decisive factor in granting or denying access to a resource; client-side logic is often easy to bypass."*

Applied here, the argument is mechanical rather than doctrinal: **an attacker never runs our page.** They download `*.bin`, and run PBKDF2 in hashcat or a 20-line script at whatever rate their hardware allows. A `setTimeout` that delays the 4th attempt, an attempt counter in `localStorage`, a "locked for 5 minutes" banner — none of these exist in the attacker's process. Rate limiting in the console imposes cost on exactly one party: the legitimate reader who mistyped.

**Constant-time comparison: the correct answer is to not compare.** Timing attacks against `if (candidate === secret)` work because the comparison returns early at the first mismatched byte, and the timing difference is measurable over enough samples. Two ways to remove the class:

- Compare with a constant-time primitive. Cloudflare Workers exposes `crypto.subtle.timingSafeEqual` and documents the reasoning: *"When strings are compared using the equality operator (== or ===), the comparison will end at the first mismatched character... Note that this function is not constant time with respect to the length of the parameters and also does not guarantee constant time for the surrounding code."* — https://developers.cloudflare.com/workers/examples/protect-against-timing-attacks/
- **Or — better — never compare at all.** Derive the key from the entered passphrase and let AES-GCM's tag verification decide. The tag check happens inside native code (constant-time by construction in any competent implementation), and there is no secret string in JS for a timing attack to bisect. **This is the design that makes constant-time comparison a non-question.**

Corollary, and it is the one that matters most for this engine: **if you do not store a hash of the passphrase, you cannot leak it.** StatiCrypt's `--share` and remember-me both exist *because* it stores a hash — and each of those features is a place the derived secret escapes the page.

**"Don't roll your own crypto" — the operational reading.** The advice is routinely misquoted as "don't use cryptography", which is useless for a system whose entire purpose is encryption. The actionable version, as practised by every design reviewed here, is four rules:
1. **Compose vetted primitives; never implement one.** Use `crypto.subtle` for PBKDF2 and AES-GCM. Never write an AES S-box, a GHASH, or a KDF loop in JS.
2. **Never invent a construction.** "PBKDF2 then take the first 16 bytes", "AES-CBC plus an HMAC I designed", "XOR the nonce with the filename" — each is a novel protocol with zero review.
3. **Never invent a format.** Follow an existing envelope shape (header + nonce + AAD-bound body), which is what Round C's blob format does.
4. **The dangerous code is the code around the primitive**: nonce generation, parameter serialisation, error messages, and key lifetime. The primitives are not where systems break.

**UNVERIFIED:** I found no single authoritative document that says, in one sentence, "client-side rate limiting is meaningless" — the OWASP authorization statement is about client-side checks generally and I am extending it by argument, not by quotation. Do not attribute the specific claim to a source.

**UX findings that are consistent across all three tools** (StatiCrypt's prompt page, PageCrypt's decrypt template, and the general static-site-vault write-ups):
- A single password field, submit on Enter, and a visible error on failure is the whole correct flow. Multi-step wizards, "hint" fields and per-document passphrases all reduce completion without adding security.
- The unlock should be **one KDF**, then all documents for that session become available — not one KDF per document.
- The failure state must be a single message. Distinguishing "wrong passphrase" from "file damaged" is an oracle.
- The page must state what it cannot do: no revocation, public ciphertext, weak passphrase is fatal.

### DECISIONS FOR THIS ENGINE

1. **No client-side rate limiting as a security claim. Ship none, and say none.** The console MAY add a **1,000 ms throttle after a failed attempt** — but it is labelled in code as *UX* (it stops a double-submit from a stuck Enter key) and the README must state plainly that it has zero effect on an offline attacker. If a reviewer reads "rate limited" in the UI copy, that copy is wrong and must be removed.
2. **Never store, hash, cache or compare the passphrase.** No `localStorage`, no hash in a variable, no `if (x === y)`. The passphrase exists only as the input to `importKey`, and the derived key only as a non-extractable `CryptoKey`. This single rule removes: the timing-oracle class, the share-link class, the remember-me class, and the "stale localStorage keeps working after the passphrase is rotated" class.
3. **Correctness of a guess is decided by the GCM tag, and only by the tag.** On failure emit exactly one message: `Could not decrypt. Check the passphrase.` On success, do not report which document was decrypted first.
4. **Unlock flow:** one passphrase field → one `deriveKey` (600k) → decrypt all blobs for that salt → render PDFs as in-memory Blob URLs. `URL.revokeObjectURL()` on `pagehide`. Clearing is best-effort; browsers may write the decrypted PDF to their own disk cache and **we cannot prevent that on GitHub Pages** (no `Content-Disposition`, no cache headers) — record it as a residual risk rather than claiming it away.
5. **UI copy, exact strings** (these are the deliverables, not suggestions):
   - Heading: `Encrypted documents`
   - Body: `These files are stored encrypted. Your browser decrypts them locally — nothing is sent anywhere.`
   - Field label: `Passphrase`
   - Button: `Decrypt`
   - Failure: `Could not decrypt. Check the passphrase.`
   - What this is NOT: `Encryption protects the files from being read. It does not control who can download them.`
   - On a non-secure context: `This page needs HTTPS to decrypt files.`
6. **Ship no "remember me", no share link, no passphrase hint, no recovery path.** State the consequence positively in the README: *"If the passphrase is lost, the documents are lost. Re-encrypt from source and redeploy."*
7. **Compose, never implement.** The only crypto imports permitted in the console bundle are `crypto.getRandomValues`, `crypto.subtle.importKey`, `crypto.subtle.deriveKey`, `crypto.subtle.encrypt`, `crypto.subtle.decrypt`, `TextEncoder`, `TextDecoder`, `btoa`/`atob` (or a 20-line base64 that is unit-tested against known vectors). A lint rule or a build-time `grep` should fail the build on any other crypto import.
8. **No compression of the plaintext before encryption.** PDFs are already compressed, so it buys ~nothing, and compress-then-encrypt is where compression side channels live. Skip it.
9. **Build-time encryption uses an OS CSPRNG** (`crypto.randomBytes` / `os.urandom`), never `Math.random`, and the build must assert `iterations >= 600000` before writing a blob. A build that silently emits 100 iterations is the single most likely way this system fails in practice.

---

## ROUND E — Search-engine hygiene: keeping the admin URL out of indexes on GitHub Pages

### FINDINGS

**`robots.txt` Disallow and `noindex` are not interchangeable — combining them breaks both.** Google, *Block Search indexing with `noindex`*, https://developers.google.com/search/docs/crawling-indexing/block-indexing:

> *"For the `noindex` rule to be effective, the page or resource must not be blocked by a robots.txt file, and it has to be otherwise accessible to the crawler. If the page is blocked by a robots.txt file or the crawler can't access the page, the crawler will never see the `noindex` rule, and the page can still appear in search results, for example if other pages link to it."*

The mechanism is simple and is the whole lesson: `Disallow` prevents the fetch; `noindex` is a *response header or meta tag inside the fetched document*. Disallow the URL and the crawler never reads the tag — while other sites can still link to the URL and the URL can still surface in results with no content. The correct combination is **allow crawling, serve `noindex`**.

Two implementations, same effect:
- `<meta name="robots" content="noindex">` in the document `<head>`
- `X-Robots-Tag: noindex` response header

For Google specifically, `googlebot` can be targeted as `content="noindex"` on a `<meta name="googlebot">`; `robots` covers all engines and is the right default.

**GitHub Pages cannot set custom HTTP response headers.** No `X-Robots-Tag`, no custom `Cache-Control`, no custom CSP via headers. Confirmed by the GitHub community discussion requesting exactly this (github.com/community discussions #84963) and by static-hosting SEO write-ups (runxbuild.com/blog/github-pages-seo). **Consequence: the header path is unavailable, so the meta-tag path is the only one.** The same limitation is what removes `Content-Disposition` from Round D's options and what forces the PDFs to be rendered from Blob URLs.

**Removal after the fact is slow and temporary unless the tag is in place.** Google, *Remove Your Site Info from Google*, https://developers.google.com/search/docs/crawling-indexing/remove-information:
- The [Removals tool](https://support.google.com/webmasters/answer/9689846) removes a page from results *"within a day"*.
- **Requests last about 6 months.**
- To make it permanent you must *"remove or update the content on your page"* — i.e. ship the `noindex`, or delete the page. The doc's own reasoning: *"This is the most secure way to prevent your information from appearing in other search engines that might not respect the `noindex` tag."*

That last point is the one that should drive the design: **`noindex` is a request, not a guarantee, and it is not honoured by every engine.** The only control that does not depend on crawler goodwill is *not publishing a page that says what it is*.

**Jekyll/sitemap interaction.** If `jekyll-sitemap` is in use, every page gets into `sitemap.xml` regardless of a `noindex` meta tag. The two must agree: sitemap exclusion (front matter `sitemap: false`, or `_config.yml` `exclude:`) AND the meta tag. A page in the sitemap with `noindex` is a contradictory signal that Search Console reports as an error.

### DECISIONS FOR THIS ENGINE

1. **`<meta name="robots" content="noindex,nofollow">` in the `<head>` of the gated console page — hardcoded in the template, not injected by JS.** A crawler that does not execute JS (most of them, for indexing decisions) must still see it. Also add `<meta name="googlebot" content="noindex,nofollow">` for belt-and-braces.
2. **Do NOT `Disallow` the console path in `robots.txt`.** This is the single most commonly-got-wrong item in this whole document, and Google states it directly. The console must remain crawlable precisely so the crawler can read the `noindex`.
3. **Do not put the blob paths in `robots.txt` either.** The `.bin` files are ciphertext; indexing them is a nuisance, not a disclosure, and a `Disallow` on them makes their URLs discoverable by anyone reading `robots.txt` — which is a *worse* outcome than letting them be crawled and ignored. If a blob must be de-indexed, it gets `noindex` too (or, better, it is not linked from any page).
4. **No link from any public page to the console.** No nav entry, no footer link, no `README` link on the deployed site, no `sitemap.xml` entry, no `llms.txt` entry. The URL is shared out-of-band. Discovery-by-link is the only way a `noindex` page gets surfaced, per Google's own caveat.
5. **`sitemap: false` in the console page's front matter** (Jekyll) plus a `_config.yml` `exclude:` entry, so `jekyll-sitemap` cannot contradict the meta tag.
6. **Filename discipline.** The gated page and its blobs must not carry descriptive, guessable, indexable names (`cv.pdf`, `cover-letter.pdf`, `admin.html`). Use an opaque path segment (e.g. a 16-byte random hex directory generated per build) alongside encryption. **This is not security — the ciphertext is the security — it is index hygiene and log hygiene.** A URL that contains "cv" is a URL that appears in a referrer log, a proxy log, and a shared screenshot.
7. **Verification is part of the deliverable, not an afterthought.** After deploy:
   - `site:<domain> <opaque-path>` in Google → expect zero results.
   - Search Console → URL Inspection → Live test → confirm "Indexing allowed: No" and that Googlebot sees the `noindex`.
   - If a URL is already indexed: Removals tool (≈1 day, ≈6 months validity) **and** ship the `noindex` in the same change, so the removal outlives the request.
8. **Do not rely on `robots.txt` for anything.** It is advisory, it is public, and it is the wrong tool for confidentiality. The README should say: *"Search-engine exclusion here is `noindex` via meta tag. It is a request, not an access control, and it is not honoured by every engine. The encryption is the control."*

---

## Consolidated engine specification

### Cryptographic parameters (v1)

| Parameter | Value | Source |
|---|---|---|
| KDF | PBKDF2-HMAC-SHA-256 | OWASP |
| Iterations | **600,000** (floor; shipped in header + AAD) | OWASP minimum |
| Salt | **16 bytes**, CSPRNG, **regenerated every build** | — |
| Cipher | **AES-256-GCM** | — |
| Nonce | **12 bytes**, CSPRNG, **fresh per blob** | NIST 800-38D |
| Tag | 16 bytes (GCM default, not truncated) | — |
| AAD | canonical JSON header, keys sorted, no whitespace | AWS Encryption SDK pattern |
| Key extractable | `false` | MDN |
| Passphrase | **6 Diceware words** (77.5 bits), EFF list, generated locally | EFF |
| Compression | none | — |

### Blob format (v1)

```
"VAULT1" | u8 version=1 | u32be iterations | 16B salt | 12B nonce
        | u16be aad_len | aad JSON | ciphertext || 16B tag
```

### Invariants a build must assert before writing

1. `iterations >= 600000`
2. salt and nonce both came from a CSPRNG, not from a pattern, hash, counter or timestamp
3. nonce is exactly 12 bytes and never appears twice under the same derived key
4. AAD bytes are byte-identical in header and at decrypt
5. each blob decrypts successfully with the intended passphrase in a round-trip test
6. the passphrase appears in no file, no URL, no log line, no commit

### Residual risks — stated, not hidden

| Risk | Status |
|---|---|
| Weak or reused passphrase | Mitigated by policy (6 words); fatal if violated |
| Attacker with the ciphertext cracking offline | Inherent. Only entropy + iterations defend |
| Decrypted PDF cached in browser/OS | **Cannot be prevented on GitHub Pages** (no headers) |
| Search-engine indexing | `noindex` only; a request, not a control |
| JS zeroisation of the passphrase | Best-effort; not a guarantee |
| Compromised build machine | Out of scope; the plaintext lives there |
| No revocation | Inherent. Rotate passphrase + re-encrypt + redeploy |
| Browser extension / XSS on the same origin | Out of scope, and total |

### Rejected, with reasons (do not re-litigate without new evidence)

- **AES-CBC** (StatiCrypt's choice) — no integrity; ciphertext is malleable.
- **A share link carrying the derived password in a URL fragment** (StatiCrypt `--share`) — a permanent bearer token in chat logs and browser history.
- **"Remember me" storing a salted hash in `localStorage`** (StatiCrypt) — an offline-crackable artifact plus a stale-credential path.
- **Pinned salt across builds** — forced by the two features above; without them, fresh salt per build is strictly better.
- **Argon2id via WASM** — unmeasured supply-chain risk in the one path that defines the guarantee; revisit only with SRI + self-hosting + measurements.
- **Client-side rate limiting as security** — the attacker does not run the page.
- **A stored hash or a string comparison of the passphrase** — removes the need for constant-time comparison entirely.
- **`robots.txt` Disallow of the console** — actively defeats `noindex`.
- **`X-Robots-Tag`** — GitHub Pages cannot set response headers.

### UNVERIFIED (do not quote as fact)

- crypto-js's exact KDF (reported as OpenSSL `EVP_BytesToKey` / MD5 / 1 iteration) and its default cipher mode — not read from source this session.
- Any Argon2id-wasm performance or bundle-size figure on target hardware.
- A single authoritative source stating "client-side rate limiting is meaningless" — the OWASP authorization statement is about client-side checks generally; the specific claim is my argument.
- Whether the 22× Argon2id-vs-PBKDF2 multiplier generalises (the source itself disclaims a reproducible general comparison).
- Googlebot's treatment of a JS-gated page: the deployed console is a shell plus a `noindex` meta tag with ciphertext in separate `.bin` files, so the crawler never sees a document body — but this specific behaviour was not tested on the live domain.
