# HelixTerminator

**Tagline:** The zero-trust terminal platform for teams — every SSH session, secured, shared, and AI-assisted.

**Summary:** HelixTerminator is an enterprise terminal and SSH session-management platform built as a Go microservices system with cross-platform Flutter clients. It brokers, records, and secures remote sessions under a zero-trust model, adds real-time collaboration, and layers AI assistance over the terminal.

**Short description (~40 words):** HelixTerminator is a zero-trust, enterprise terminal/SSH management platform: a Go microservices backend plus Flutter clients across six platforms. It manages hosts, brokers connections, records sessions, enables real-time collaboration, and adds AI-assisted command help, output explanation, and incident response.

**Long description (150-250 words):**
HelixTerminator is an enterprise-grade terminal and remote-access platform, structured as two modules — a Terminal Platform and a Connection Broker — implemented across a catalogue of Go microservices with a Flutter client for six platforms. It is designed to replace ad-hoc SSH tooling with a governed, auditable, collaborative system.

The backend covers the full lifecycle of remote access: host and group management with bastion/jump-host chains, an SSH proxy brokering password/pubkey/certificate auth, a terminal I/O proxy over WebSocket, SFTP with resumable transfers, port-forwarding, snippet and workspace management, and session recording assembled into signed asciinema playback. Security is zero-trust by design: a vault for zero-knowledge secret storage, a PKI service issuing short-lived SSH certificates, hardware-backed keychains (Secure Enclave / Android Keystore / DPAPI / HSM), FIDO2/WebAuthn and OIDC/SAML auth, and an append-only Merkle-chained audit log for SOC 2 / ISO 27001 evidence. Real-time collaboration lets multiple operators share a session (observer / co-pilot / owner) with CRDT buffer sync.

An AI service augments the terminal with command autocomplete, output explanation, anomaly detection, runbook generation, and incident assistance. The platform is container-native — Kubernetes, Helm, Terraform, and a full observability stack (OpenTelemetry, Grafana, Jaeger, Loki) — and integrates with the wider Helix family via a HelixTrack bridge and local HelixLLM. It is governed by the Helix Constitution with anti-bluff inheritance-verification gates.

**Why we built it:** Teams run remote infrastructure through scattered SSH clients with no shared audit trail, no consistent secret handling, and no way to collaborate live on an incident. HelixTerminator was built to make remote access a governed, zero-trust, team-native platform rather than a per-laptop tool.

**Why it's a game-changer:** It combines things usually bought separately — an SSH client, a secrets vault, a bastion/PKI layer, session recording, compliance auditing, and live collaboration — into one platform, then adds an AI layer that explains output and drafts runbooks during incidents.

**What's innovative:**
- **Dual-module design** (Terminal Platform + Connection Broker) over a 25-service registry.
- **Zero-trust security**: short-lived SSH certificates via PKI, zero-knowledge vault, hardware-backed keychains, Merkle-chained audit log.
- **Real-time session collaboration** with CRDT buffer sync and observer/co-pilot/owner roles.
- **AI-assisted operations**: autocomplete, output explanation, anomaly detection, runbook/incident assist.
- **Cross-platform Flutter client** targeting six platforms from one codebase.

**Biggest technical challenges + how solved:**
- *Securing remote access without standing credentials* — solved with a PKI service issuing short-lived SSH certificates plus a zero-knowledge vault and hardware-backed key storage.
- *Live multi-operator sessions without conflicts* — solved with CRDT-based buffer synchronization (chosen over operational transformation, per ADR-006).
- *Tamper-evident compliance* — solved with an append-only, Merkle-chained audit log producing exportable SOC 2 / ISO 27001 / FedRAMP evidence.
- *Consistent UX across desktop, mobile, and web* — solved with a single Flutter/Dart + BLoC client (Flutter chosen over Electron, per ADR-001).

**Tech stack:**
- **Go microservices** — backend services (SSH proxy, terminal, vault, PKI, audit, etc.); chosen for concurrency and small footprint (ADR-002: Go over Rust/Node).
- **Flutter / Dart (BLoC)** — one client across six platforms (ADR-001: Flutter over Electron).
- **PostgreSQL** — primary datastore (ADR-004: Postgres over CockroachDB).
- **Kafka + RabbitMQ** — messaging/streaming for session segments and events (ADR-003).
- **Redis** — terminal scrollback buffers and hot state.
- **SPIFFE/SPIRE + mTLS** — workload identity (ADR-005) for service-to-service zero trust.
- **Ed25519 (EdDSA)** — JWT signing and recording signatures (ADR-009).
- **Kubernetes + Helm + Terraform** — container-native deployment and IaC (ADR-007/008).
- **OpenTelemetry, Grafana, Jaeger, Loki** — observability; **Falco, Trivy, Cosign, Sealed Secrets** — runtime security and supply chain.

**Public links:**
- GitHub: https://github.com/HelixDevelopment/terminator (public, Apache-2.0)
- License: Apache-2.0 (per GitHub API).
- Note: this project was NOT in the June 2026 harvested inventory; it was created 2026-07-04 and verified to exist via live `gh` calls.

**Suggested diagrams/illustrations (OpenDesign):**
1. Three-channel architecture: Flutter clients ↔ gateway ↔ Go service mesh ↔ host agent / SSH proxy (from the README's runtime-domain sketch).
2. Zero-trust security flow: PKI issuing a short-lived SSH cert, vault-stored secret, mTLS between services.
3. Live collaboration panel: observer / co-pilot / owner sharing one terminal with CRDT sync.
4. AI-assist callout: terminal output with an inline "explain this output / draft runbook" overlay.

**Site relevance:** both (vasic.digital as a flagship enterprise product; milosvasic.ru as the most substantial recent build to highlight).

**Priority tier:** Helix-primary.

**Source provenance:**
- `gh api repos/HelixDevelopment/terminator` (metadata: public, Go, Apache-2.0, created 2026-07-04, pushed 2026-07-26, size ~44.7 MB).
- `gh api repos/HelixDevelopment/terminator/readme` (service catalogue, security services, AI service, ADRs, module/scope structure).
- `gh search repos terminator --owner HelixDevelopment` and `gh repo list HelixDevelopment` (confirmed existence; absent from June harvest).
- UNVERIFIED: numeric spec figures in the MVP research package (e.g., "221 REST endpoints", "120 tables", "25-service registry", "1,840"-style counts) are design/spec targets from `docs/research/mvp/`, not confirmed as fully implemented — presented above as architecture scope, not shipped metrics. Latency/SLO and "production-ready" claims not independently verified.
