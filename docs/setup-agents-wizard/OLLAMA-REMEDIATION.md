# Runbook: ollama embeddings on a Vulkan iGPU

**Audience:** the operator of the machine running the embedding backend.
**Applies to:** any host where `ollama` serves the Lumen embedding model from a GPU driven by
Vulkan — in practice an Intel iGPU (`library=Vulkan`, `type=iGPU`) with the i915 kernel driver.
**Does not apply to:** hosts where `ollama ps` reports `100% CPU`, or where `inference compute`
reports a library other than `Vulkan`.

This is the *what to do about it* document. The evidence, the harness, the controlled
conditions and the upstream bug links live in
[OLLAMA-NAN-WEDGE.md](./OLLAMA-NAN-WEDGE.md) — read that if you want to know *why*; read this
if you want to know *what to type*.

**One-line verdict:** take the iGPU out of the embedding path. Do not upgrade ollama hoping it
is fixed — it is not fixed upstream, and on ALT Sisyphus there is no newer package anyway.

---

## 1. The symptom, as a user experiences it

You do not see "Vulkan". You see one of these, in roughly this order of escalation:

**a. Lumen prints its usage text after a failed index.** This is the one that wastes the most
time, because it reads like *you* mistyped the command:

```
{"error":"failed to encode response: json: unsupported value: NaN"}

Usage:
  lumen index <project-path> [flags]
...
```

The command was fine. The backend returned HTTP 500, Lumen surfaced the error and then printed
its help — and the help is the last thing on screen, so it is the thing you read.

**b. Searches hang, then time out.** `OLLAMA_NUM_PARALLEL=1` means one embedding request at a
time. A request that is quietly waiting out a ~20 s GPU fence timeout blocks every other
client behind it. Interactive search latency goes from ~0.3 s to tens of seconds, then to
nothing.

**c. Searches "work" but return nonsense, or return nothing for files you know exist.** This is
the dangerous one and it produces **no error at all**. See §3.

**d. The wizard says the backend is wedged.** `scripts/setup-agents-wizard.sh` catches the hard
form:

```
❌ Embedding backend is WEDGED at http://localhost:11434 - it returns NaN for every input.
⚠️  Fix: ollama stop ordis/jina-embeddings-v2-base-code   (a fresh runner clears it)
```

`ollama stop` *does* clear it — for a while. It is first aid, not treatment: the next
context-filling chunk wedges it again. That is what this runbook is for.

---

## 2. Thirty-second diagnosis

Paste the whole block. Nothing here writes, restarts, or reconfigures anything.

```bash
# 1. Is the embedding model being served from a GPU at all?
ollama ps
#    PROCESSOR column: "100% GPU" -> affected path.  "100% CPU" -> you are already safe.

# 2. Which compute library did ollama pick?
journalctl -u ollama --no-pager | grep -F 'inference compute' | tail -1
#    library=Vulkan  + type=iGPU  -> this runbook applies.

# 3. Has the kernel already been abandoning GPU work?
journalctl -k --no-pager --since "24 hours ago" | grep -c 'Fence expiration time out'
journalctl -k --no-pager --since "24 hours ago" | grep -c 'GPU HANG'
#    Any non-zero fence count while only embeddings ran -> confirmed.

# 4. Is the backend wedged right now?
curl -s http://localhost:11434/api/embed \
  -d '{"model":"ordis/jina-embeddings-v2-base-code","input":"health check"}' | head -c 80
#    healthy -> {"model":"...","embeddings":[[0.0...
#    wedged  -> {"error":"failed to encode response: json: unsupported value: NaN"}

# 5. Has indexing already failed on it?
grep -F 'unsupported value: NaN' ~/.local/share/lumen/debug.log | tail -3
```

**Reading the result**

| What you saw | Verdict |
| :--- | :--- |
| `100% GPU` **and** `library=Vulkan` | Affected. Pick a tier below. |
| `100% GPU`, library is something else (CUDA, ROCm) | Not this defect. The tiers still work but you probably do not want them. |
| `100% CPU` | Already remediated (or the model was never offloaded). Nothing to do. |
| Step 4 returned `NaN` | Wedged **right now**. `ollama stop <model>` unblocks you this minute; then fix it properly. |
| Step 3 non-zero, step 4 healthy | Silent corruption is in progress. Step 4 passing proves nothing — see §3. |

> **A passing health check is not a healthy index.** Step 4 sends a 12-character input. Twelve
> characters never trip the bug. The bug needs a chunk that fills the model's 8192-token
> context. The wizard's own probe has exactly the same blind spot, on purpose — a probe large
> enough to detect the fault is a probe large enough to *cause* it.

---

## 3. What is actually going wrong (the 90-second version)

1. A chunk arrives that fills the model's 8192-token context — roughly 8 000 characters of
   source. ~4 000 characters is reliably fine; ~8 000 reliably is not.
2. ggml-vulkan issues one large compute dispatch to the iGPU.
3. The i915 driver's fence wait expires (~20 s). The kernel logs
   `Fence expiration time out i915-…:ollama[pid]` and **abandons the dispatch**.
4. **ollama reads the result buffer anyway.** It was never validly written.
5. What you get back depends on what garbage was in that buffer:
   - a *slightly wrong* vector (cosine 0.985 against the CPU answer) — **HTTP 200**, passes
     every sanity check, quietly poisons retrieval;
   - an *all-zero* vector — **HTTP 200**, poisons retrieval harder;
   - *NaN* — **HTTP 500**, the only one a status-code check can see.
6. Repeated timeouts degrade the Vulkan context until the kernel resets the device
   (`context reset due to GPU hang`). Past that point every request fails instantly — even
   `"hi"`, in 0.06 s — until the runner process is destroyed.

**The HTTP 500 is the tombstone, not the fault.** By the time you see `NaN`, corrupt vectors
have already been written to the index under HTTP 200. That is why every tier below is
paired with a recommendation to reindex, and why "just restart it when it breaks" is not a
remediation.

The GPU is not even buying you speed at the size that matters: at full context it "finishes"
in ~20 s because it is *timing out*, not computing. The CPU takes ~70–110 s and returns a
correct, bit-deterministic vector.

---

## 4. Before you choose: the index trade-off

**This is the decision that actually matters, and it is not about performance.**

Lumen keys each index database by **(project path, embedding model)**. Evidence:

- Every index lives in `~/.local/share/lumen/<opaque-hash>/index.db`, and each database records
  its own identity in `project_meta`:

  ```
  $ sqlite3 ~/.local/share/lumen/<hash>/index.db 'select key, value from project_meta;'
  vec_dimensions|768
  root_hash|3df357055b55bac731ba96837b817238d3476767ed0144d558e7358dda94641b
  embedding_model|ordis/jina-embeddings-v2-base-code
  project_path|/run/media/milosvasic/DATA4TB/Projects/vasic
  last_indexed_at|...
  total_files|2413
  ```

- `lumen purge --help` documents the consequence in as many words:

  > *"Each path is normalized to its git root first, then matched against the `project_path`
  > recorded inside each index database, **so switching embedding models or using custom models
  > never leaves orphan indexes**."*

  Purge matches on the recorded `project_path` **because** the directory name alone cannot
  find every index for a project — a model switch puts the new index somewhere else. Purge was
  built to clean up exactly the orphan this trade-off creates.

- Vectors from two different models are not comparable. `vec_dimensions` is fixed per database
  and cosine similarity across two different embedding spaces is meaningless, so reuse is not
  merely unimplemented — it is not possible.

### Therefore

| | Changes `LUMEN_EMBED_MODEL`? | Existing index | Cost |
| :--- | :--- | :--- | :--- |
| **Tier 1** (`options.num_gpu`) | no | **preserved** | not usable by Lumen — see §5 |
| **Tier 2** (CPU-pinned model tag) | **yes** | **DISCARDED — orphaned, and a second index is built from zero** | full reindex of every project, plus the disk of both copies until you purge |
| **Tier 3** (`GGML_VK_VISIBLE_DEVICES=-1`) | no | **preserved and resumable** | one `sudo`, one service restart |

**Verdict: Tier 3 is the better durable fix.** It keeps the model name, so it keeps the index.
Tier 2 changes the model name, and a different model name means a second index built from
scratch while the original is orphaned on disk. On this host that is a **113 MiB** index over
**2 413 tracked files** thrown away — and thrown away *per project*, for every project you have
ever indexed, not just the one in front of you.

Tier 2 remains the right answer in exactly one situation: **you cannot get sudo.** It is the
only tier that survives a restart without root.

> **Do not reach for Tier 2 as "the safe one because it does not need a restart."** The restart
> is the cheap part. The reindex is the expensive part, and only Tier 2 forces it on you as a
> permanent, per-project cost.

### The restart is safe for a running index

Tier 3 needs `systemctl restart ollama`, which will kill whatever embedding request is in
flight and fail the indexing job that issued it. **That is recoverable and cheap**, because
Lumen's index is incremental and resumes:

```
01:35:33 ERROR "indexing failed"  project=".../vasic"
         err="... embed error (HTTP 500): {"error":"...unsupported value: NaN"}"
01:36:31 INFO  "indexing started" project=".../vasic"
01:36:33 INFO  "indexing plan"    total_files=2413 files_unchanged=662 files_to_add=1553 ...
```

Observed in `~/.local/share/lumen/debug.log` on this host: a run killed mid-flight by the NaN
fault, restarted a minute later, and picked up with **662 files already done** (the previous
plan had recorded 526). Nothing was lost; the work already committed stayed committed.

Still, prefer to restart when nothing is indexing:

```bash
pgrep -af 'lumen.*index'     # empty output = nothing in flight, restart freely
```

If it is not empty, either wait, or accept the interruption and re-run `lumen index <path>`
afterwards. Do **not** `kill -9` the indexer to "clean up first" — let it die on its own or
let it finish.

---

## 5. Tier 1 — per-request `num_gpu: 0`

**What it is:** every embedding request explicitly asks for zero GPU layers.

```bash
curl -s http://localhost:11434/api/embed -d '{
  "model": "ordis/jina-embeddings-v2-base-code",
  "input": ["…your text…"],
  "options": { "num_gpu": 0 }
}'
```

**Cost:** none to set up. ~3–4x slower per request at full context (~70–110 s vs a ~20 s GPU
"answer" that is really a timeout). No restart, no root, no config file.

**What it does NOT fix — read this before choosing it:** **Lumen cannot use it.** Lumen exposes
`LUMEN_EMBED_MODEL`, `LUMEN_BACKEND`, `LUMEN_EMBED_CTX`, `LUMEN_EMBED_DIMS`,
`LUMEN_MAX_CHUNK_TOKENS`, `LUMEN_FRESHNESS_TTL`, `LUMEN_REINDEX_TIMEOUT` and `LUMEN_LOG_LEVEL`
— and nothing that injects `options` into the request body. Neither does any other client you
did not write. Tier 1 protects **your own scripts and probes only**; it leaves the indexer,
which is the thing generating the full-context chunks in the first place, completely exposed.

**Rollback:** stop sending `options`. There is no persistent state to undo.

---

## 6. Tier 2 — a CPU-pinned model tag

**What it is:** a derived model that carries `num_gpu 0` inside itself, so *any* caller gets
CPU without sending options.

It already exists on this host and is validated 3/3 in
[OLLAMA-NAN-WEDGE.md §8](./OLLAMA-NAN-WEDGE.md#8-validation-of-the-fix). Confirm before you
rely on it:

```bash
ollama list | grep jina-embeddings-code-cpu
ollama show jina-embeddings-code-cpu --modelfile | grep -E '^(FROM|PARAMETER)'
#   -> PARAMETER num_gpu 0        <- this line is the whole fix
```

If it is missing, recreate it (shares blobs with the original — no re-download, no extra disk
for the weights):

```bash
printf 'FROM ordis/jina-embeddings-v2-base-code\nPARAMETER num_gpu 0\n' > /tmp/Modelfile.cpu
ollama create jina-embeddings-code-cpu -f /tmp/Modelfile.cpu
```

Point Lumen at it — **this is the line that costs you the index**:

```bash
export LUMEN_EMBED_MODEL=jina-embeddings-code-cpu     # and add it to ~/.bashrc to persist
```

**Cost:** the same ~3–4x CPU slowdown as Tier 1, **plus a full reindex of every project**,
**plus** the orphaned original index sitting on disk until you purge it (§4). Agent-spawned
MCP servers only inherit the variable if they are started from a shell that has it, so a
half-applied Tier 2 gives you *two* live indexes and searches whose results depend on which
process asked.

**What it does NOT fix:** anything that ignores `LUMEN_EMBED_MODEL` — another user's shell, a
service unit, an MCP server launched from a session started before you exported it. Those keep
using the GPU model and keep corrupting its index.

**Rollback:**

```bash
unset LUMEN_EMBED_MODEL                 # and delete the line from ~/.bashrc
ollama rm jina-embeddings-code-cpu      # optional; frees the tag, keeps the shared blobs
```

Your original index is still there and still valid — that is the one upside of the orphaning.
Searches go back to it the moment the variable is gone. The CPU-model index then becomes the
orphan; clear it with `lumen purge <path>` (which matches by recorded `project_path` and so
removes **all** indexes for that project, both models — you will reindex from zero afterwards).

---

## 7. Tier 3 — disable Vulkan service-wide (recommended)

**What it is:** ollama never discovers the Vulkan device, so it never offloads anything to it.
The model name does not change, so **the existing index is preserved and keeps resuming**.

`OLLAMA_VULKAN=0` and `OLLAMA_LLM_LIBRARY=cpu` were both tested and both do **nothing** on this
build — `OLLAMA_VULKAN` is already `false` in the running service and Vulkan is used anyway.
`GGML_VK_VISIBLE_DEVICES=-1` is the only variable that works.

**This tier requires `sudo`. There is no passwordless sudo on this machine** (`sudo -n true` →
`sudo: a password is required`), so it cannot be automated and the wizard will never attempt
it. An operator has to run it.

### Step 1 — confirm the seam (no changes yet)

```bash
systemctl show ollama -p FragmentPath -p DropInPaths -p EnvironmentFiles
```

Expect:

```
FragmentPath=/usr/lib/systemd/system/ollama.service
DropInPaths=
EnvironmentFiles=/etc/sysconfig/ollama (ignore_errors=yes)
```

The unit **already** sources `/etc/sysconfig/ollama` optionally (`EnvironmentFile=-`), and the
file does not exist yet. Creating it sets service-wide environment **without editing any unit
file and without a drop-in**. Nothing packaged is modified.

### Step 2 — create the file

```bash
sudo tee /etc/sysconfig/ollama >/dev/null <<'EOF'
# Intel iGPU + Mesa Vulkan corrupts embeddings at full context and wedges the
# ollama runner (i915 fence timeouts -> GPU hang). Upstream, still open:
#   https://github.com/ggml-org/llama.cpp/issues/18969
#   https://github.com/ggml-org/llama.cpp/issues/26044
# NOTE: OLLAMA_VULKAN=0 does NOT work on this build - it is already false and
# Vulkan is used anyway. GGML_VK_VISIBLE_DEVICES=-1 is what actually disables it.
# See docs/setup-agents-wizard/OLLAMA-REMEDIATION.md
GGML_VK_VISIBLE_DEVICES=-1
EOF
sudo chmod 0644 /etc/sysconfig/ollama
```

### Step 3 — pick your moment, then restart

```bash
pgrep -af 'lumen.*index'          # ideally empty; if not, see §4 "the restart is safe"
sudo systemctl restart ollama
```

### Step 4 — verify (do not skip)

```bash
journalctl -u ollama --no-pager --since '2 min ago' | grep -F 'inference compute'
#   must now show library=cpu, and no Vulkan device line at all.

ollama ps
#   after the next embed, PROCESSOR must read "100% CPU".

journalctl -k --no-pager --since '10 min ago' | grep -c 'Fence expiration time out'
#   must stay at 0 while indexing runs.
```

If `inference compute` still says `library=Vulkan`, the environment file was not read — check
for a typo in the path (`/etc/sysconfig/ollama`, no extension) and that `systemctl show ollama
-p EnvironmentFiles` still lists it.

**Cost:** one `sudo`, one restart, and the same ~3–4x CPU slowdown on embeddings — now applied
to everything the daemon serves, including any chat model you also run through it. If you use
this ollama for generation as well, that is the real price of Tier 3, and it is the one reason
to prefer Tier 2 despite the index cost.

**What it does NOT fix:** vectors already written. The corruption is in the index, not in the
daemon — see §9.

**Rollback:**

```bash
sudo rm /etc/sysconfig/ollama          # or comment the GGML_VK_VISIBLE_DEVICES line out
sudo systemctl restart ollama
journalctl -u ollama --no-pager --since '2 min ago' | grep -F 'inference compute'
#   -> library=Vulkan again
```

Rollback restores the defect. It does not damage the index, because the model name never
changed.

---

## 8. What none of these tiers fix

Be explicit about the boundaries, so nobody reports these back as "the fix did not work":

- **Vectors already in the index.** Every tier changes what happens *next*. Nothing repairs an
  all-zero vector that was written last week under HTTP 200. See §9.
- **The upstream bug.** It is open in ggml/llama.cpp with no merged fix
  ([#18969](https://github.com/ggml-org/llama.cpp/issues/18969),
  [#26044](https://github.com/ggml-org/llama.cpp/issues/26044)) and reported against ollama
  ([#13086](https://github.com/ollama/ollama/issues/13086),
  [#15248](https://github.com/ollama/ollama/issues/15248)). These tiers *avoid* it.
- **Upgrading ollama.** Installed 0.23.4 is the newest package in ALT Sisyphus, and the defect
  is unfixed upstream regardless. Upgrading is a gamble on an open bug *and* a step outside the
  distro. Upgrade for other reasons, on their own merits, after a tier is in place.
- **Serialisation.** `json: unsupported value: NaN` is the Go encoder refusing to encode a NaN
  float. It is a symptom. There is nothing to fix in any JSON layer.
- **Throughput.** `OLLAMA_NUM_PARALLEL=1` still serialises embeddings. CPU embeddings are
  slower per request; on a large corpus that is hours, not minutes. Plan the reindex.
- **Other GPU workloads.** Tier 3 disables Vulkan for the whole daemon. If something else on
  this host needs iGPU acceleration through ollama, Tier 3 takes it away.

### Partial mitigations that are *not* fixes

Listed so you do not rediscover them and mistake them for solutions:

- **`ollama stop <model>`** clears a wedged runner. The next full-context chunk wedges it
  again. First aid only.
- **Capping chunk size** (`LUMEN_MAX_CHUNK_TOKENS`) keeps chunks below the context-fill
  boundary that triggers the fault, and would also cut latency. **Untested here** — the
  boundary is bracketed between 4 000 and 8 000 characters on one synthetic corpus, not pinned,
  and it moves with content. Treat as defence in depth on top of a tier, never instead of one.
- **`GGML_VK_DISABLE_F16=1`** is exposed by `libggml-vulkan.so` and might fix the corruption
  while keeping the iGPU. **Untested.** If you try it, verify with the behavioural signature in
  [OLLAMA-NAN-WEDGE.md §8](./OLLAMA-NAN-WEDGE.md#8-validation-of-the-fix), not with a journal
  grep.

---

## 9. After you apply a tier: reindex clean

Any index built against the Vulkan path may contain zero-norm or subtly-wrong vectors for its
**largest chunks** — which are usually its most information-dense files. Those entries return
HTTP 200 and are invisible to every status-code check.

An incremental re-run will **not** repair them: Lumen skips files whose content has not
changed, so a poisoned vector for an unmodified file stays exactly where it is. Force it:

```bash
lumen index /path/to/repo -f      # -f = force full re-index; re-embeds everything
```

Budget for it. On CPU this is materially slower than the run that produced the bad data, and
`OLLAMA_NUM_PARALLEL=1` means it cannot be parallelised by throwing more clients at it.

If you took Tier 2 and want the orphaned GPU-model index gone as well:

```bash
lumen purge /path/to/repo         # removes ALL indexes for that project, both models
lumen index /path/to/repo         # rebuild
```

`lumen purge` with **no arguments** wipes every index for every project on the machine. Pass
the path.

---

## 10. What the setup wizard does, and deliberately does not do

`scripts/setup-agents-wizard.sh` → `verify_lumen` will, when the backend is reachable:

- send a real embedding round-trip and require a vector back (test `A33`);
- name the wedged-NaN state explicitly rather than reporting a generic failure (test `A34`);
- ask `/api/ps` whether the embedding model is GPU-resident, read ollama's own
  `inference compute` line for the library it actually chose, and **warn with a pointer to this
  runbook** when that library is Vulkan (tests `A35`–`A41`).

It deliberately does **not**:

- change `LUMEN_EMBED_MODEL` — that would orphan your index (§4);
- write `/etc/sysconfig/ollama` — that needs root;
- restart any service — that would interrupt a running index without asking;
- use `sudo` anywhere in this path.

When it cannot read the journal, it says the library is *unknown* rather than assuming. A
warning you can trust is worth more than a warning that guesses; tests `A37` and `A38`
keep it that way, and `A41` keeps the check read-only.

---

## Appendix: the state of this host when the runbook was written

Everything below was read, not assumed. Reproduce any line with the commands in §2.

```
ollama version is 0.23.4                       (ollama-0.23.4-alt1.x86_64, newest in Sisyphus)
inference compute ... library=Vulkan name=Vulkan0
                      description="Intel(R) Iris(R) Xe Graphics (TGL GT2)" type=iGPU
ollama ps          ordis/jina-embeddings-v2-base-code:latest   396 MB   100% GPU   ctx 8192
/api/ps            "size_vram": 396324864        (== size: fully resident on the GPU)
journalctl -k --since "24 hours ago"
                   551 x "Fence expiration time out"
                     3 x "GPU HANG"
systemctl show ollama -p EnvironmentFiles
                   /etc/sysconfig/ollama (ignore_errors=yes)     <- referenced, absent
sudo -n true    -> "sudo: a password is required"                <- no passwordless sudo
ollama list     -> jina-embeddings-code-cpu:latest   (Tier 2 tag present, PARAMETER num_gpu 0)
                   ordis/jina-embeddings-v2-base-code:latest
index           ~/.local/share/lumen/<hash>/index.db  113 MiB, 2413 files tracked,
                   embedding_model=ordis/jina-embeddings-v2-base-code
```
