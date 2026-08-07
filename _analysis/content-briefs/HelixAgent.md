# HelixAgent

**Tagline:** Don't pick one model — let them debate, and ship the answer they agree on.

**Summary**
HelixAgent is a production-ready, AI-powered ensemble LLM service in Go that intelligently combines responses from many language models — including a multi-round AI debate system and dynamic verification-based provider selection — to produce the most accurate and reliable output.

**Short description**
HelixAgent is a Go-based ensemble LLM service that combines many providers into one accurate answer. It runs multi-round AI debates, scores providers dynamically via LLMsVerifier, routes with confidence-weighted strategies, and ships production features: caching, monitoring, security guardrails, and OpenAI-style APIs.

**Long description**
HelixAgent is a production-ready, AI-powered ensemble LLM service (MIT) that intelligently combines responses from multiple language models to deliver the most accurate and reliable outputs. Rather than trusting a single model, it orchestrates an ensemble — and, when useful, a structured multi-round debate — across a large roster of providers (its README documents 47+ LLM providers under `internal/llm/providers/`, including Claude, DeepSeek, Gemini, Mistral, Qwen, and xAI/Grok).

Provider selection is dynamic: real-time verification scores from an integrated LLMsVerifier drive routing and graceful fallback to the best-performing provider, with categorized error reporting. The AI Debate Orchestrator supports multiple topologies (mesh/star/chain) and a phase protocol (Proposal → Critique → Review → Synthesis) with cross-debate learning. Routing strategies include confidence-weighted, majority-vote, and semantic-intent detection, with real-time streaming responses.

The service is built for production: PostgreSQL + Redis for high availability, Prometheus/Grafana/OpenTelemetry observability, JWT auth, rate limiting, a guardrails engine, and PII detection. It is organized as ~20 extracted modules (EventBus, Observability, Auth, Storage, VectorDB, Embeddings, RAG, Memory, MCP, and more) and ships an LLM optimization framework (semantic caching, structured output, enhanced streaming) with integrations for SGLang, LlamaIndex, LangChain, Guidance, and LMQL. OpenAI-compatible completion and ensemble endpoints make adoption straightforward.

**Why we built it**
Any single LLM can be wrong, biased, or unavailable. HelixAgent was built so applications can consult many models at once, weigh their answers by measured reliability, and fall back gracefully — turning a fragile single-provider dependency into a resilient, self-scoring ensemble.

**Why it's a game-changer**
It operationalizes multi-model consensus. Instead of hard-coding one provider, teams get verification-scored routing, structured debate for hard questions, and production-grade resilience (HA data layer, observability, guardrails) behind an OpenAI-compatible API — so existing clients can adopt ensemble reasoning with minimal change.

**What's innovative**
- Structured multi-round AI debate with selectable topologies and a Proposal→Critique→Review→Synthesis protocol, plus cross-debate learning.
- Dynamic provider selection driven by live LLMsVerifier scores rather than static preference lists.
- A native Go LLM-optimization framework (semantic cache, structured output, enhanced streaming) alongside optional external optimizers (SGLang, LlamaIndex, LangChain, Guidance, LMQL).
- A modular architecture (~20 extracted modules) enabling BigData features like distributed memory and knowledge-graph streaming.

**Biggest technical challenges + how solved**
- *Choosing among many unequal providers* — solved with LLMsVerifier-driven dynamic scoring and confidence-weighted/majority-vote routing with graceful fallback.
- *Getting a reliable answer to hard questions* — solved with the Debate Orchestrator's multi-topology, phased debate and synthesis.
- *Running an ensemble in production* — solved with a PostgreSQL+Redis HA data layer, Prometheus/Grafana/OpenTelemetry observability, and security controls (JWT, rate limiting, guardrails, PII detection).

**Tech stack**
- **Go:** Chosen for concurrency and single-binary deployment; used across the service and its ~20 internal modules.
- **Gin (Web API):** Chosen for a fast HTTP surface; used to serve OpenAI-compatible `/v1` completion, chat, streaming, and ensemble endpoints.
- **PostgreSQL:** Chosen as durable store for sessions, analytics, and debate records; part of the HA data layer.
- **Redis:** Chosen for caching and queues/tasks; powers response caching and the semantic cache layer.
- **LLMsVerifier (integrated):** Chosen to quantify provider reliability; used to score and rank providers for routing and fallback.
- **Prometheus + Grafana + OpenTelemetry:** Chosen for metrics, dashboards, and tracing; expose `helixagent_*` metrics and request tracing.
- **Model Context Protocol (MCP) adapters:** Chosen for extensibility; the README lists 45+ MCP adapters.
- **Neo4j / ClickHouse / Kafka (BigData):** Chosen for distributed memory and knowledge-graph streaming at scale.
- **Optimization integrations (SGLang, LlamaIndex, LangChain, Guidance, LMQL):** Chosen to add prefix caching, retrieval, task decomposition, and constrained generation as optional services.

**Public links**
- Repo: https://github.com/HelixDevelopment/HelixAgent (public; GitHub description "LLMs Agent")

**Suggested diagrams/illustrations**
1. Ensemble/debate flow: a prompt fanning out to N providers, through the Proposal→Critique→Review→Synthesis phases, converging to one synthesized answer.
2. Dynamic routing diagram: LLMsVerifier scores feeding a router that selects confidence-weighted providers with fallback arrows.
3. Production architecture: Gin API → orchestrator → provider pool, with PostgreSQL/Redis, and the Prometheus/Grafana/OpenTelemetry observability plane.
4. Module map: the ~20 extracted modules grouped by concern (data, security, AI, infra).

**Site relevance**
Both — company framing on vasic.digital (production ensemble LLM service) and personal authorship framing on milosvasic.ru.

**Priority tier:** Helix-primary

**Source provenance**
- `/Volumes/T7/Projects/vasic/_analysis/top20/HelixAgent.readme.txt` (primary; ensemble system, debate orchestrator, provider roster, modules, optimization framework, security, observability, endpoints).
- `/Volumes/T7/Projects/vasic/_analysis/github-helix-others.md` and `.json` (repo metadata: "LLMs Agent", Go, public; described as the central AI-debate ensemble consumer for HelixMemory/HelixSpecifier/DebateOrchestrator).
- UNVERIFIED: performance benchmarks in the README (e.g., "1000+ requests/second", "<500ms cached", coverage percentages, "47+ providers", "193+ validation scripts") are self-reported project claims, not independently verified — present them as project-stated or omit hard numbers from public copy. Provider counts vary within the README itself (47+ vs. a "21 LLM Providers" diagram); prefer the qualitative "many providers" framing publicly.
