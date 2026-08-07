# Courses-Creator

**Tagline:** Markdown in, professional video course out — AI-enhanced, multi-platform.

**Summary:** Courses-Creator is a toolkit that converts markdown scripts into professional video courses with AI-powered enhancements: multi-LLM content enrichment (OpenAI/Anthropic/Ollama), high-quality TTS and background music, and desktop, mobile, and web players — all Docker-deployed with Prometheus/Grafana monitoring.

**Short description (~40 words):** Transforms markdown into engaging video courses. A Go processing engine enriches content via multiple LLM providers, generates narration (Bark/SpeechT5 TTS) and music, and delivers to Electron desktop, React Native mobile, and React web players, with full Docker deployment and monitoring.

**Long description (150–250 words):**
Courses-Creator turns plain markdown scripts into finished, professional video courses. At its center is a Go core-processor that runs a video/audio pipeline: it enhances written content through multiple LLM providers (OpenAI, Anthropic, and local Ollama), generates natural narration with text-to-speech engines (Bark, SpeechT5), layers background music, and assembles the result into course videos. Content authors work in markdown; the system handles enrichment, voicing, and production. It is deliberately multi-platform for both creation and consumption: an Electron desktop creator app, a React Native mobile player, and a React web player, all fed by the same REST API and background job system. The backend is production-shaped rather than a demo — PostgreSQL persistence, background job processing, MCP server implementations for tool integration, Prometheus metrics, JWT authentication, and an nginx reverse proxy — and the whole stack ships as a Docker Compose deployment with Grafana/Prometheus monitoring profiles. LLM features are optional (the system runs without API keys for basic functionality), which keeps it usable offline or on a budget while still offering premium AI enhancement when keys are supplied. The result is an end-to-end course-production toolchain that treats AI as an enhancement layer over a solid, testable media pipeline, with unit, integration, and e2e coverage.

**Why we built it:** Producing course videos manually is slow: writing, narrating, scoring, and editing each take effort and specialist tools. Courses-Creator collapses that into a markdown-driven pipeline so a single source script becomes a produced course, with AI filling the gaps humans would otherwise fill by hand.

**Why it's a game-changer:** It unifies authoring, AI enrichment, TTS/music generation, and multi-platform playback in one deployable stack — and degrades gracefully to no-API-key operation, so it works for hobbyists and enterprises alike.

**What's innovative:**
- Markdown-to-video pipeline with pluggable multi-LLM enrichment (OpenAI/Anthropic/Ollama).
- Built-in TTS (Bark, SpeechT5) and background-music generation.
- MCP server implementations inside the processing engine for tool-augmented enhancement.
- One backend serving three first-class clients (Electron desktop, React Native mobile, React web).

**Biggest technical challenges + how solved:**
- *Heavy media processing:* solved with a Go pipeline plus background job processing so long TTS/video jobs don't block the API.
- *Optional-but-powerful AI:* solved by making LLM providers optional and pluggable, with graceful fallback to basic functionality.
- *Multi-platform delivery:* solved with a shared REST API and three dedicated player apps.
- *Operability:* solved with Docker Compose profiles, Prometheus/Grafana, and JWT auth built in.

**Tech stack (why + how):**
- **Go** — core-processor engine, REST API, job runner, pipeline (972K+ bytes, dominant language).
- **TypeScript / React** — web player and shared UI.
- **Electron** — desktop creator app.
- **React Native** — mobile player.
- **PostgreSQL** — course/job persistence.
- **LLM providers (OpenAI, Anthropic, Ollama)** — content enhancement.
- **TTS (Bark, SpeechT5)** — narration synthesis.
- **MCP servers** — tool integration inside the engine.
- **Docker Compose + nginx** — full-stack deployment and reverse proxy.
- **Prometheus + Grafana** — monitoring.

**Public links:**
- GitHub: https://github.com/vasic-digital/Courses-Creator (public). Note: README quick-start uses a placeholder `your-org` clone URL.
- No private-repo dependency noted.

**Suggested diagrams/illustrations (OpenDesign):**
1. Pipeline flow: markdown → LLM enrichment → TTS + music → video assembly → publish.
2. One-backend-three-clients topology (desktop/mobile/web over shared API).
3. Deployment stack: Docker Compose services (API, players, PostgreSQL, nginx, Prometheus, Grafana).
4. Optional-AI toggle: basic vs enhanced path depending on provider keys.

**Site relevance:** vasic.digital (AI-for-content-production narrative). Could also feature on milosvasic.ru as a portfolio project.

**Priority tier:** vasic-util-secondary

**Source provenance:** `_analysis/top20/Courses-Creator.readme.txt` (features, project structure, env vars, providers, TTS); `_analysis/top20/Courses-Creator.langs.json` (Go/TypeScript/Python/PLpgSQL bytes); `_analysis/github-vasic-digital.md` (description, size).
