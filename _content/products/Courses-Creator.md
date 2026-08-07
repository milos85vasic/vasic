---
name: Courses-Creator
slug: courses-creator
tier: vasic-util-secondary
order: 22
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - TypeScript
  - React
  - Electron
  - React Native
  - PostgreSQL
  - Python
  - LLM providers (OpenAI, Anthropic, Ollama)
  - TTS (Bark, SpeechT5)
  - MCP
  - Docker Compose
  - nginx
  - Prometheus
  - Grafana
repos:
  - https://github.com/vasic-digital/Courses-Creator
diagrams:
  - Pipeline flow (markdown → LLM enrichment → TTS + music → video assembly → publish)
  - One-backend-three-clients topology (desktop/mobile/web over shared API)
  - Deployment stack (Docker Compose services)
  - Optional-AI toggle (basic vs enhanced path by provider keys)
---

**Markdown in, professional video course out — AI-enhanced, multi-platform.**

## Summary

Courses-Creator is a toolkit that converts markdown scripts into professional video courses with AI-powered enhancements: multi-LLM content enrichment (OpenAI/Anthropic/Ollama), high-quality TTS and background music, and desktop, mobile, and web players — all Docker-deployed with Prometheus/Grafana monitoring.

## Short description

Transforms markdown into engaging video courses. A Go processing engine enriches content via multiple LLM providers, generates narration (Bark/SpeechT5 TTS) and music, and delivers to Electron desktop, React Native mobile, and React web players, with full Docker deployment and monitoring.

## Long description

Producing a video course is normally a small production studio's worth of work: scripting, recording narration, sourcing music, editing, encoding, and then building players for every platform learners might use. Courses-Creator compresses that entire chain into a single input — a markdown script — and a single command. At its center is a Go core-processor that runs a full video/audio pipeline: it enhances the written content through multiple LLM providers (OpenAI, Anthropic, and local Ollama), synthesizes natural narration with text-to-speech engines (Bark, SpeechT5), layers background music, and assembles the pieces into finished course videos. The author's job stays at the level of ideas and words; the system does the voicing, scoring, and production. And because a course is only useful if people can watch it, delivery is multi-platform by design: an Electron desktop creator app, a React Native mobile player, and a React web player, all fed by the same REST API and background job system — one backend, three first-class clients, no reimplementation per surface.

Crucially, this is production infrastructure, not a demo reel. The backend carries PostgreSQL persistence, background job processing so long TTS/video renders never block the API, MCP server implementations for tool-augmented enhancement, Prometheus metrics, JWT authentication, and an nginx reverse proxy — and the whole thing ships as a Docker Compose deployment with Grafana/Prometheus monitoring profiles you can stand up in one step. The AI is an enhancement layer, not a dependency: every LLM provider is optional, so the pipeline runs with zero API keys for basic operation and lights up premium enrichment the moment keys are supplied. That single decision makes the same tool viable for a hobbyist working offline on a laptop and for an enterprise wiring in its provider of choice — and the whole media pipeline underneath is covered by unit, integration, and e2e tests rather than taken on faith.

## Why we built it

Producing course videos manually is slow: writing, narrating, scoring, and editing each take effort and specialist tools. Courses-Creator collapses that into a markdown-driven pipeline so a single source script becomes a produced course, with AI filling the gaps humans would otherwise fill by hand.

## Why it's a game-changer

It turns course production from a specialist, multi-tool craft into a repeatable software pipeline: authoring, AI enrichment, narration and music generation, and multi-platform playback all live in one deployable stack. The graceful degradation to no-API-key operation is the quiet superpower — the same codebase serves a budget-conscious solo creator and an enterprise with a premium provider contract, with nothing to rewrite in between.

## What's innovative

- Markdown-to-video pipeline with pluggable multi-LLM enrichment (OpenAI/Anthropic/Ollama).
- Built-in TTS (Bark, SpeechT5) and background-music generation.
- MCP server implementations inside the processing engine for tool-augmented enhancement.
- One backend serving three first-class clients (Electron desktop, React Native mobile, React web).

## Challenges & solutions

- **Heavy media processing:** solved with a Go pipeline plus background job processing so long TTS/video jobs don't block the API.
- **Optional-but-powerful AI:** solved by making LLM providers optional and pluggable, with graceful fallback to basic functionality.
- **Multi-platform delivery:** solved with a shared REST API and three dedicated player apps.
- **Operability:** solved with Docker Compose profiles, Prometheus/Grafana, and JWT auth built in.

## Tech stack (why + how)

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

> Note: the public README quick-start uses a placeholder `your-org` clone URL.
