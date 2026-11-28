# LUMEN GPU Remediation Investigation Report

**Date:** 2026-11-28
**Host:** anton
**Decision:** Remediation NOT applied — findings only. The operator will decide.

---

## 1. Ollama server log — `cat /home/milosvasic/.ollama/logs/server.log`

```
cat: /home/milosvasic/.ollama/logs/server.log: No such file or directory
```
**Exit code:** 0

The per-user log file does not exist on this host. Ollama is logging through the systemd journal instead (see #2).

---

## 2. `systemctl show ollama -p ActiveEnterTimestamp --value`

```
Fri 2026-11-27 12:50:38 CET
```
**Exit code:** 0

The ollama service started on 2026-11-27 at 12:50:38 CET and has been running for ~11h.

---

## 3. `grep library= /home/milosvasic/.ollama/logs/server.log`

```
/usr/bin/grep: /home/milosvasic/.ollama/logs/server.log: No such file or directory
```
**Exit code:** 2

Same missing file as #1. The `library=` line is not available from this path. The remediation script reads it via `journalctl -u ollama --since <start>` instead (see #5).

---

## 4. Remediation script — `scripts/ollama-vulkan-remediation.sh` (full read)

**Purpose:** Take the GPU out of ollama's embedding path by writing a GPU-hiding environment flag into the systemd unit's `EnvironmentFile`, then restarting the service.

**The defect (measured on this host, 2026-08-26/27):** ollama running with a GPU acceleration library (Vulkan/CUDA) in the embedding path silently corrupts embeddings. Failure modes: HTTP 500 with NaN, HTTP 200 with all-zero vectors, runner wedge (every later request returns NaN until unloaded), and — worst — HTTP 200 with a well-formed stale repeated vector that passes NaN/Inf/zero/L2 checks (this corrupted 758 vectors across 55 files upstream).

**Upstream status:** Aware and unfixed (llama.cpp #18969, #26044; ollama #13086, #15248). Upgrading ollama does NOT fix it.

**What does NOT work (tested on this host):** `OLLAMA_VULKAN=false` and `OLLAMA_LLM_LIBRARY=cpu` are both no-ops.

**Approach:** Disable the GPU daemon-wide via an env flag in the unit's `EnvironmentFile`. This keeps the model name (and therefore the lumen index keyed by `project_meta.embedding_model`) unchanged. The cost, stated plainly: disables the GPU for ALL ollama work, not just embeddings.

**Modes:** `--check` (read-only diagnosis), `--apply` (needs sudo + restart), `--verify`, `--rollback` (needs sudo).

**Exit codes:** 0 = GPU is out of the path · 1 = the corrupting state is present · 2 = could not determine.

**Key detection logic:**
- Service manager detected at runtime (systemd/launchd/openrc/never assumed).
- `EnvironmentFile` resolved by asking systemd (`systemctl show -p EnvironmentFiles`), falling back to `/etc/sysconfig/ollama`, `/etc/default/ollama`, `/etc/conf.d/ollama`.
- GPU vendor/driver read from `/sys/class/drm/card*/device/uevent` (PCI vendor id → intel/amd/nvidia/none).
- GPU-hiding flag derived from detected backend library: CUDA → `CUDA_VISIBLE_DEVICES=-1`, ROCm/HIP → `HIP_VISIBLE_DEVICES=-1`, Vulkan/other → `GGML_VK_VISIBLE_DEVICES=-1`.
- Backend library read from the service log (`library=...`) since the service start timestamp.
- Kernel fault scan greps `journalctl -k` since service start using a driver-specific regex.
- Batch probe: sends N distinct texts to `/api/embed` and verifies N distinct vectors are returned (detects failure mode 4 — stale duplicates — which per-vector checks cannot see).

**Overrides:** `OLLAMA_ENV_FILE`, `OLLAMA_SERVICE`, `OLLAMA_GPU_FLAG`, `OLLAMA_GPU_DRIVER`, `OLLAMA_GPU_VENDOR`, `OLLAMA_FAULT_REGEX`, `LUMEN_EMBED_MODEL`, `LUMEN_BACKEND`, `OLLAMA_HOST`, `LM_STUDIO_HOST`, `LUMEN_CONFIG`, `LUMEN_PROBE_TEXTS`.

---

## 5. `bash scripts/ollama-vulkan-remediation.sh --check`

**Output:**

```
── host ──────────────────────────────────────────────────
ℹ️  os=Linux  service-manager=systemd  service=ollama
ℹ️  gpu vendor=nvidia driver=nvidia (/sys/class/drm/card1 (PCI 10DE:2503))
── ollama embedding backend ──────────────────────────────
ℹ️  backend=ollama host=http://localhost:11434 model=ordis/jina-embeddings-v2-base-code
❌ library=CUDA - THIS IS THE CORRUPTING PATH
⚠️  /etc/default/ollama does not exist (the unit sources it via EnvironmentFile=-)
✅ 0 nvidia faults since ollama started (Fri 2026-11-27 12:50:38 CET)
ℹ️  batch probe (32 distinct texts must give as many distinct vectors)...
✅ batch probe: OK 32/32 distinct
```
**Exit code:** 1

**Interpretation of each check:**

| Check | Result | Meaning |
|---|---|---|
| Service manager | systemd | Systemd is in use; automatic restart is supported. |
| GPU | NVIDIA, driver `nvidia`, PCI `10DE:2503` (`/sys/class/drm/card1`) | An NVIDIA GPU is present; the GPU path exists and can be remediated. |
| Backend library | `library=CUDA` | **THIS IS THE CORRUPTING PATH.** Ollama is using CUDA for embeddings. |
| EnvironmentFile | `/etc/default/ollama` does not exist (`EnvironmentFile=-`) | The flag has NOT been applied yet; no EnvironmentFile is present to append to. |
| Kernel faults since start | 0 | No NVIDIA GPU faults/hangs recorded since ollama started. |
| Batch probe | OK 32/32 distinct | All 32 distinct texts produced 32 distinct vectors — no stale-duplicate corruption detected right now. |

**Overall verdict (exit 1):** The corrupting state is present — `library=CUDA` means the GPU is in ollama's embedding path. The batch probe is currently clean and there are no kernel faults, but the script explicitly warns that failure mode 4 (stale duplicate vectors) is invisible to per-vector checks and can strike without warning. The script's own header documents that this defect corrupted 758 vectors across 55 files upstream before anyone noticed.

---

## 6. `ps aux | grep ollama`

```
ollama      9849  7.8  0.1 3152896 36664 ?       Ssl  Nov27  56:19 /usr/local/bin/ollama serve
ollama   3786054  339  4.3 43714532 1364256 ?    Rl   00:24  72:04 /usr/local/lib/ollama/llama-server --model /usr/share/ollama/.ollama/models/blobs/sha256-33a8a1b6a1cbba662f292d32bb55f8d109c0e6cb02de2d243a1b70705ea20986 --port 34559 --host 127.0.0.1 --no-webui --offline -c 8192 -np 1 --log-verbosity 4 --no-log-prefix --no-log-timestamps --no-jinja --chat-template chatml --flash-attn auto --embedding -b 2048 -ub 2048 --context-shift --keep 4
```
**Exit code:** 0

Two ollama processes are running:
1. `ollama serve` (PID 9849) — the main daemon.
2. `llama-server` (PID 3786054) — the embedding worker, launched with `--embedding` flag.

**No `--library` flag is visible** on either command line. The `library=CUDA` determination came from the service log (`journalctl`), not from a command-line flag. This means the GPU library selection is happening inside ollama/llama-server itself based on what it detects at startup, and it is NOT overridable via a `--library` CLI flag (consistent with the script's finding that `OLLAMA_VULKAN=false` / `OLLAMA_LLM_LIBRARY=cpu` are no-ops).

---

## 7. `systemctl status ollama`

```
● ollama.service - Ollama Service
     Loaded: loaded (/etc/systemd/system/ollama.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-11-27 12:50:38 CET; 11h ago
   Invocation: 53b98db8a0ad41f7b8a6dbc74aebd01f
     Main PID: 9849 (ollama)
      Tasks: 75 (limit: 37107)
     Memory: 1.6G (peak: 1.6G, swap: 1.1M, swap peak: 1.5M)
        CPU: 11h 39min 34.431s
     CGroup: /system.slice/ollama.service
             ├─   9849 /usr/local/bin/ollama serve
             └─3786054 /usr/local/lib/ollama/llama-server --model ... --embedding ...
```
**Exit code:** 0

The service is active, running, enabled, and healthy per systemd.

---

## Summary

| Item | Finding |
|---|---|
| GPU present | Yes — NVIDIA, driver `nvidia`, PCI `10DE:2503` |
| Backend library | `library=CUDA` — **the corrupting path** |
| GPU-hiding flag applied | No — `/etc/default/ollama` does not exist |
| Kernel faults since start | 0 |
| Batch probe (32 distinct texts) | OK 32/32 distinct — clean right now |
| `--check` exit code | **1** (corrupting state present) |

**Remediation NOT applied.** The script is ready to run with `--apply` (requires sudo + restart) which would append `CUDA_VISIBLE_DEVICES=-1` to `/etc/default/ollama` and restart `ollama.service`. The operator should decide whether to apply it, weighing the documented risk (silent embedding corruption, including undetectable stale duplicates) against the cost (GPU disabled for all ollama work, not just embeddings).
