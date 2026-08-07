# Technology Stack — vasic-digital + HelixDevelopment

Consolidated, deduped technology inventory for AI-development-centric positioning. Drawn from harvested language data (`_analysis/top20/*.langs.json`), repo metadata (`_analysis/github-vasic-digital.md`, `_analysis/github-helix-others.md`), the local Catalogizer repo, and per-repo READMEs (`gh repo view`). Scope is the two first-party orgs; the 49 `caf-*` fork/mirror repos and the ATMOSphere backup mirrors are **excluded** because their languages reflect upstream projects, not first-party work. Items not directly evidenced are marked **UNVERIFIED**.

---

## Languages

- **Go** — the dominant first-party language and backbone of nearly every product and reusable module (HelixAgent 28.7M bytes, HelixCode 18.5M, helix_cluster 15.4M, LLMsVerifier 6.4M, Helix-Track/Core 5.1M, HelixTranslate 5.1M, Courses-Creator 972K, Catalogizer, and the entire `digital.vasic.*` module fleet). Used for high-throughput REST services, concurrent workers, and libraries.
- **Kotlin** — Server Factory family (Core-Framework 990K, Mail-Server-Factory 179K), Kotlin Multiplatform modules, Android clients, and Games. Used for JVM provisioning tooling and cross-platform mobile.
- **TypeScript** — React web apps and typed client libraries (Catalogizer web + `*-React`/`*-TS` packages, HelixTrack Desktop/Web clients, Courses-Creator players). Used for frontends and shared type contracts.
- **JavaScript / HTML / CSS** — web UIs and generated documentation sites (large HTML byte counts in LLMOrchestrator/DocProcessor/Open-Rag are generated docs).
- **Python** — AI/ML glue and tooling: TTS and enhancement in Courses-Creator, scripts across Helix repos, Parallels-Utils helpers. Also the LLMsVerifier Python SDK.
- **Shell** — pervasive: build pipelines, provisioning (Server Factory is majority Shell), QEMU/ISO managers, and module scaffolding.
- **Swift** — HelixTrack iOS client; small native pieces in HelixAgent.
- **Java** — Android-adjacent code and ATMOSphere-SmartTube (mirror; excluded from first-party count but Java appears in Games/Android).
- **Rust** — present first-party in HelixAgent (316K bytes); otherwise mostly `caf-*` forks (excluded). Catalogizer uses Rust/Tauri for desktop builds.
- **PL/pgSQL** — PostgreSQL stored procedures/migrations (HelixAgent 276K, Helix-Track/Core 62K, Courses-Creator 4K).
- **TLA+** — formal specification in helix_cluster (316K bytes); evidence of formal-methods rigor in distributed-systems work.
- **HCL / Terraform** — infrastructure-as-code in Helix-Flow/Platform (19K bytes). **UNVERIFIED** beyond presence; treat as IaC-managed deployment.
- **C / C++** — small native components (ffmpeg-kit; SmartTube mirror). Minor first-party footprint.

## AI / LLM

- **Multi-provider LLM access** — first-party abstraction over 40+ providers via LLMProvider (43 adapters + a generic OpenAI-compatible adapter), 47+ in HelixAgent, 12 verified adapters in LLMsVerifier. Providers evidenced in READMEs: **Anthropic/Claude, OpenAI, DeepSeek, Gemini, Mistral, Cohere, Groq, xAI/Grok, Qwen, Perplexity, OpenRouter, Together AI, Replicate, Cerebras, Cloudflare Workers AI, SiliconFlow, Ollama (local, fallback)**. Used behind one interface with retry/circuit-breaker/health.
- **LLM verification** — LLMsVerifier's mandatory "Do you see my code?" comprehension gate plus latency/streaming/function-calling/vision/embeddings tests; verified-only config export. The trust layer for model selection.
- **Model Context Protocol (MCP)** — first-party `MCP_Module` and 45+ MCP adapters in HelixAgent; MCP servers in Courses-Creator. Used to extend agents with external tools/context.
- **RAG (retrieval-augmented generation)** — `RAG` module; RAG optimization in LLMsVerifier and HelixAgent context management.
- **Vector databases & embeddings** — `VectorDB` and `Embeddings` modules; semantic search/knowledge retrieval.
- **Agent orchestration** — LLMOrchestrator (headless CLI agents: OpenCode, Claude Code, Gemini, Junie, Qwen Code), `Agentic` (graph-based workflows), DebateOrchestrator + HelixAgent "AI debate ensemble" (multi-round consensus), DagOrchestrator + PipelineRuntime (dataflow/DAG).
- **Planning algorithms** — `Planning` module implements HiPlan, MCTS, and Tree of Thoughts.
- **LLMOps** — `LLMOps` module: evaluation, experiments, datasets, prompt versioning.
- **Benchmarking** — `Benchmark` module targets SWE-bench, HumanEval, MMLU.
- **Self-improvement / RLHF** — `SelfImprove` module: reward modeling, RLHF, optimizer. **UNVERIFIED** maturity.
- **Agent memory** — HelixMemory (fuses Mem0 + Cognee + Letta), plus `Memory` and `conversation` (infinite-context compression, event sourcing).
- **Spec-driven development** — HelixSpecifier (fuses SpecKit + Superpowers + GSD); SpecKit auto-activation (7-phase flow) in HelixAgent.
- **Skill / tool systems** — `SkillRegistry`, `ToolSchema` for AI agent tool/skill registration and validation.
- **Text-to-speech** — Bark and SpeechT5 in Courses-Creator.
- **Computer vision + LLM vision** — VisionEngine (GoCV/OpenCV build-tag-gated + vision providers GPT-4o/Claude/Gemini/Qwen-VL/Kimi/StepGUI/Astica/Ollama, fallback chain) for UI analysis.
- **Guardrails / defensive-LLM** — HelixAgent guardrails engine + PII detection; `RedTeam` (YAML adversarial fixtures) and `Normalize` (adversarial-input canonicalisation). WIP scaffolds `Claritas`/`LeakHub`/`GandalfSolutions`/`Veritas`/`Ouroborous` are **UNVERIFIED / early-stage**.
- **Semantic cache** — GPTCache-inspired response cache in HelixAgent.

## Backend / Frameworks

- **Gin (Go)** — the standard REST framework across HelixAgent, HelixCode, Helix-Track/Core, LLMsVerifier, and Catalogizer. Chosen for throughput (Helix-Track/Core claims 50k+ req/s).
- **gRPC + Protocol Buffers** — inter-service comms/event transport in LLMsVerifier; gRPC support in HelixAgent.
- **HTTP/3 (QUIC via quic-go)** — first-party `http3` module; used by HelixTranslate and LLMsVerifier for modern transport.
- **WebSockets** — `streaming` module (hub with rooms/topics); real-time UIs in Catalogizer, HelixTranslate, Courses-Creator.
- **Angular** — LLMsVerifier web SPA (per repo docs).
- **React (+ Tailwind, Redux Toolkit, i18next)** — Catalogizer web, Courses-Creator players, HelixTrack web, and reusable `*-React`/`*-TS` modules.
- **Messaging/event bus** — first-party `EventBus` module; RabbitMQ + Kafka in LLMsVerifier; Kafka in HelixAgent BigData.

## Mobile / Desktop

- **Android (Kotlin)** — HelixTrack Android client, Catalogizer Android + Android TV apps, Games.
- **Kotlin Multiplatform (KMP)** — cross-platform module set (Auth-KMP, Database-KMP, Security-KMP, UI-Components-KMP with Compose, Concurrency-KMP, RateLimiter-KMP, Config-KMP, Document-KMP, Formatters-KMP, Storage-KMP).
- **iOS (Swift)** — HelixTrack iOS client.
- **Electron** — desktop apps for Courses-Creator (creator) and Catalogizer.
- **React Native** — Courses-Creator mobile player.
- **Tauri + Rust** — Catalogizer desktop builds (routed through a `catalogizer-builder` container).
- **AOSP / Android 15** — ATMOSphere firmware for Orange Pi 5 Max (mirror family; noted for completeness, excluded from product scope).

## Data / DB

- **PostgreSQL** — primary relational store for HelixAgent (HA with clustering), Courses-Creator, and others (PL/pgSQL evidence).
- **SQLite** — embedded store used widely: task_bridge SSoT, docs_chain DB members (pure-Go modernc driver), and the `database` module's dual SQLite/PostgreSQL support.
- **SQLCipher** — encrypted-at-rest databases in Catalogizer, LLMsVerifier, and Helix-Track/Core.
- **Redis** — caching and rate limiting (`cache`, `ratelimiter` modules; HelixAgent, LLMsVerifier).
- **Neo4j** — knowledge-graph streaming in HelixAgent BigData.
- **ClickHouse** — analytical/BigData store in HelixAgent.
- **Object storage (MinIO / Amazon S3 / Google Cloud Storage / Azure)** — `storage` module abstraction; Catalogizer cloud sync; LLMsVerifier cloud checkpoint backup.
- **Vector databases** — `VectorDB` module for semantic search (specific engine not named — **UNVERIFIED**).

## Infra / DevOps / Containers

- **Docker & Docker Compose** — near-universal packaging/deployment (HelixAgent, Catalogizer, Courses-Creator, LLMsVerifier, Mail Server Factory stack).
- **Kubernetes (+ Helm)** — LLMsVerifier deployment; a Mail Server Factory connection type; HelixAgent scaling.
- **Prometheus + Grafana** — metrics/dashboards across HelixAgent, Catalogizer, Courses-Creator, LLMsVerifier, Mail Server Factory.
- **OpenTelemetry** — tracing via the `observability` module.
- **QEMU / Libvirt / Parallels** — VM image management (Qemu-Utils, Parallels-Utils; Mail Server Factory unattended-install testing).
- **Cloud provider integrations** — AWS SSM, Azure Serial Console, GCP OS Login as Mail Server Factory connection types; S3/GCS/Azure for storage.
- **Terraform / HCL** — IaC in Helix-Flow/Platform (**UNVERIFIED** beyond presence).
- **nginx** — reverse proxy (Courses-Creator).
- **systemd hardening** — OOM-Protect (workstation OOM protection).
- **mDNS / service discovery** — `mdns` and `discovery` modules (RFC 6762/6763 LAN discovery).
- **jemalloc** — memory allocator in the containerized `tmux` build.
- **CI/CD** — GitHub Actions (HelixAgent, LLMsVerifier); Gradle for Kotlin/Server Factory; Make for Go builds.
- **Governance-as-submodule** — HelixConstitution (CLAUDE.md/AGENTS.md/CONST-* rules) + Docs Chain (content-hashed doc/DB sync) shared across the fleet.

## Testing / QA

- **Anti-bluff QA framework** — HelixQA (evidence-gated cross-platform testing) built on the `digital.vasic.challenges` framework; every PASS must carry runtime evidence.
- **Challenge harnesses** — per-module real-behavior invariants with paired mutation gates (evidenced in LLMOrchestrator, LLMProvider, DocProcessor) that must fail when the feature is broken.
- **Go testing** — `go test -race`, testify assertions, and parser fuzzing across modules.
- **Visual regression testing** — `VisualRegression`, `ScreenDiff`, `ReplayBuffer`, `TrainingCollector` modules for UI/visual automation.
- **ADB-based device testing** — Android/Android TV crash/ANR detection in HelixQA.
- **SonarQube** — code-quality gates (Mail Server Factory reports 100% gate; SonarQube-Factory provisions the server).
- **Security scanning** — Catalogizer repo configures semgrep, gosec, trivy, snyk, gitleaks, and nancy (dependency/secret/SAST scanning).
- **TLA+ model checking** — formal specs in helix_cluster.
- **Playwright** — browser E2E used in the milosvasic.ru localization work (per repo commit history); **UNVERIFIED** as a standard across the two orgs — treat as project-specific tooling.

---

### Provenance & caveats
- Language byte counts: `_analysis/top20/*.langs.json` and `gh api .../languages`.
- Feature/tech claims: repo READMEs via `gh repo view` (HelixAgent, LLMsVerifier, Courses-Creator, LLMProvider, LLMOrchestrator, VisionEngine, DocProcessor, Herald, docs_chain, task_bridge, Mail-Server-Factory, Qemu-Utils, Parallels-Utils) and the local Catalogizer README.
- Org overviews: `_analysis/github-vasic-digital.md`, `_analysis/github-helix-others.md`.
- `caf-*` forks and ATMOSphere backup mirrors are excluded as non-first-party. WIP/scaffold repos and any tech not directly evidenced are marked **UNVERIFIED** per Constitution §11.4.6 (no fabrication).
