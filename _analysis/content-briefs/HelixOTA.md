# HelixOTA

**Tagline:** Universal, decoupled over-the-air updates — zero-brick by design.

**Summary:** Helix OTA is a universal, deeply decoupled over-the-air update system: a Go control plane plus per-OS client agents, designed to deliver safe, staged firmware/app updates to fleets ranging from a single board to millions of devices. Its first target is Android 15 on the Orange Pi 5 Max.

**Short description (~40 words):** Helix OTA is a universal over-the-air update system — a Go control plane plus per-OS client agents — engineered for zero system corruption, validated uploads, and granular staged rollouts. Its first target is Android 15 on Orange Pi 5 Max, with Linux/Windows adapters planned.

**Long description (150-250 words):**
Helix OTA is a universal, generic, deeply decoupled over-the-air (OTA) update system. It comprises a Go server **control plane**, per-OS client **SDKs/agents**, and a management **dashboard**, designed to be embeddable into any operating system through pluggable OS adapters. The first delivery target is Android 15 (all variants) on the Orange Pi 5 Max, where the build pipeline emits flashing images plus a validated OTA `.zip` and mandatory hash files; Linux, Windows, and other OSes are on the roadmap behind the same adapter seam.

The design centers on operator-stated hard guarantees: zero system corruption (an update must never brick a working device), mandatory validation of every artifact before deployment, granular rollout (all-at-once or staged at 5/10/30…100%), full observability, and scale from one board to millions of devices. The locked architecture pairs device-side native Android A/B updates (AOSP `update_engine` with AVB/dm-verity and automatic boot-failure rollback) with a custom, decoupled Go control plane. Two seams are deliberately extractable — an OS-adapter seam (for universality) and a rollout-engine seam (for OS-agnostic campaigns) — and the system is decomposed into six public, independently-versioned `ota-*` submodules.

Helix OTA is currently in a specification/research and test-coverage build-out phase; the repository holds the authoritative design corpus, the documentation export pipeline, and submodule scaffolding, and it is explicit (per its anti-bluff governance) that a finished production server and agent do not yet exist.

**Why we built it:** OTA is usually reinvented per device and per OS, and a bad update can brick a fleet. Helix OTA was built to be one universal, safety-first update system that any OS can adopt via adapters, with rollback and validation guarantees baked into the architecture rather than bolted on.

**Why it's a game-changer:** It treats "never brick a device" and "roll out gradually and observably" as architectural invariants, and it makes the rollout engine and OS layer swappable seams — so the same control plane can drive Android today and other operating systems later without a rewrite.

**What's innovative:**
- **Two extractable seams** (OS-adapter + OS-agnostic rollout engine) for genuine universality.
- **Defense-in-depth safety**: native A/B (`update_engine`) + AVB/dm-verity + automatic boot-failure rollback, on top of server-side artifact validation.
- **Catalogue-first, decoupled** decomposition into six reusable `ota-*` submodules.
- **HTTP/3 (QUIC) primary transport** with automatic HTTP/2 fallback and Brotli/gzip negotiation.
- **Anti-bluff engineering**: design and status are explicitly marked as spec-phase; nothing unbuilt is claimed as shipped.

**Biggest technical challenges + how solved:**
- *Guaranteeing a bad update never bricks a device* — solved by mandating device-side native Android A/B (`update_engine` + AVB/dm-verity) with automatic boot-failure rollback, plus mandatory pre-deploy artifact validation.
- *One system, many operating systems* — solved with a pluggable OS-adapter seam and an OS-agnostic rollout engine seam, kept as separate submodules.
- *Staged, halt-able rollouts* — solved with a dedicated rollout engine (percentage cohorts, success/error thresholds, halt/advance) with no HTTP coupling.

**Tech stack:**
- **Go + Gin** — control plane, rollout engine, and validators; REST `/api/v1` primary surface.
- **Kotlin/KMP** — the on-device Android OTA agent (poll / download / verify / apply / report).
- **HTTP/3 (QUIC) → HTTP/2** — transport with automatic fallback; **Brotli/gzip** negotiated compression.
- **PostgreSQL** — relational persistence (device registry, campaigns, telemetry).
- **MinIO / S3** — artifact blob storage.
- **AOSP `update_engine` + AVB/dm-verity + `boot_control`** — device-side Virtual A/B and verified boot.
- **React** — management dashboard (login, upload, rollout, fleet health).
- **OpenTelemetry + Prometheus/Grafana** — observability.

**Public links:**
- GitHub (umbrella): https://github.com/HelixDevelopment/helix_ota (public; the repo may also be reachable as `ota` in the org listing)
- Public reusable submodules: `ota-protocol`, `ota-artifact-validator`, `ota-rollout-engine`, `ota-update-engine-bridge`, `ota-android-agent`, `ota-telemetry-schema` (all under github.com/HelixDevelopment/).
- License: Apache-2.0.

**Suggested diagrams/illustrations (OpenDesign):**
1. Three-planes architecture: control plane (Go/Gin) ↔ data plane (PostgreSQL/MinIO/OTel) ↔ device (KMP agent + `update_engine`), with the two extractable seams highlighted.
2. Staged rollout funnel: 5% → 10% → 30% → … → 100% with halt/advance thresholds.
3. Zero-brick A/B slot swap: slot A active, slot B updated + verified, automatic rollback on boot failure.
4. Six `ota-*` submodules as decoupled building blocks feeding the umbrella system.

**Site relevance:** both (vasic.digital as an embedded/IoT platform product; milosvasic.ru as a systems-engineering highlight — noting it is spec/research phase).

**Priority tier:** Helix-primary.

**Source provenance:**
- Local repo `/Volumes/T7/Projects/helix_ota/README.md` (Rev 2, 2026-06-23): scope, guarantees, locked stack, locked architecture, six submodules, governance, status.
- `/Volumes/T7/Projects/vasic/_analysis/github-helix-others.{md,json}` (repo metadata + the six `ota-*` public submodule entries).
- UNVERIFIED (flagged in-source by the project): no working production server/agent yet — specification/research + test-coverage phase; the `main_specs/README.md` corpus index and the six NEW `ota-*` repos are noted as not-yet-created in the README (though harvested data shows the `ota-*` repos now exist publicly); HelixConstitution clause numbers cited in the README are UNVERIFIED. Test-coverage figures (e.g., store 85.5%, HTTP p99 ~14 ms) are the project's own in-progress ledger, not independently confirmed.
