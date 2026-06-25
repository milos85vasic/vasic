# GitLab Project Inventory

**Generated:** 2026-06-17 · **Account:** milos85vasic · **Tool:** `glab` / `glab api` (real GitLab REST API v4)

## 1. Scope & group resolution

Five groups were requested. Only two exist as accessible GitLab groups; the other three could not be found as groups, user namespaces, or projects under any accessible namespace.

| Requested name | Resolution | Evidence |
|---|---|---|
| `vasic-digital` | **EXISTS** as group `vasic-digital` (id 117203414) | `groups/vasic-digital/projects` returned data |
| `HelixDevelopment` | **EXISTS** as group `helixdevelopment1` (id 115733553, display name "HelixDevelopment") | top-level path 404'd; found via `namespaces?search=Helix`; group has no subgroups |
| `Helix-Track` | **NOT FOUND** | 404 as group; empty `users?username=`; no namespace match; no membership project match for track/Track |
| `Helix-Flow` | **NOT FOUND** | 404 as group; empty `users?username=`; no namespace match; no membership project match for flow/Flow |
| `Server-Factory` | **NOT FOUND** | 404 as group; empty `users?username=`; no namespace match for Server-Factory/ServerFactory/server/factory |

The authenticated user is a member of exactly three groups (`groups?min_access_level=10`): `atmosphere1234321`, `helixdevelopment1`, `vasic-digital`. "Helix-Track", "Helix-Flow", and "Server-Factory" appear only as *concepts/keywords* inside existing projects (e.g. `vasic-digital/tracker_sdk`, `helixdevelopment1/PipelineRuntime`, `helixdevelopment1/ota-telemetry-schema`), not as their own groups. `atmosphere1234321` was not in the requested scope and is not inventoried here (its content is mirrored into `vasic-digital` as the `ATMOSphere-*` projects).

> Note: the group `projects` endpoint silently ignored `statistics=true` (requires elevated access), so `repository_size` was fetched per-project via `projects/:id?statistics=true` (all 189 populated). Primary language fetched via `projects/:id/languages`.

## 2. Counts

| Group | Projects | Archived |
|---|---:|---:|
| vasic-digital | 164 | 0 |
| HelixDevelopment | 25 | 0 |
| **TOTAL** | **189** | **0** |

Total repository size across all 189 projects: **7.87 GB** (8,453,350,399 bytes). No archived projects in either group.

## 3. All projects by repository size (DESC)

| group | name | size (MB) | language | last activity | description | web_url |
|---|---|---:|---|---|---|---|
| vasic-digital | ATMOSphere-Android-15 | 1678.00 | Shell | 2026-05-31 | ATMOSphere main repo backup mirror | https://gitlab.com/vasic-digital/ATMOSphere-Android-15 |
| HelixDevelopment | HelixCode | 1431.58 | Go | 2026-06-17 |  | https://gitlab.com/helixdevelopment1/HelixCode |
| vasic-digital | HelixAgent | 806.06 | Go | 2026-04-30 |  | https://gitlab.com/vasic-digital/HelixAgent |
| vasic-digital | LLMsVerifier | 517.51 | Go | 2026-06-16 |  | https://gitlab.com/vasic-digital/LLMsVerifier |
| vasic-digital | caf-agent-deck | 462.27 | Go | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-agent-deck |
| vasic-digital | caf-warp | 167.13 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-warp |
| vasic-digital | caf-bridle | 166.51 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-bridle |
| vasic-digital | caf-superset | 152.74 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-superset |
| vasic-digital | ATMOSphere-Rhythm-Player | 140.66 | Kotlin | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Rhythm-Player.git | https://gitlab.com/vasic-digital/ATMOSphere-Rhythm-Player |
| vasic-digital | HelixConstitution | 139.14 | HTML | 2026-06-16 | ATMOSphere submodule backup mirror — git@github.com:HelixDevelopment/HelixConstitution.git | https://gitlab.com/vasic-digital/HelixConstitution |
| vasic-digital | caf-aider | 137.00 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-aider |
| vasic-digital | caf-codex | 132.40 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-codex |
| vasic-digital | caf-codename-goose | 109.48 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-codename-goose |
| vasic-digital | ATMOSphere-SmartTube | 105.94 | Java | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-SmartTube.git | https://gitlab.com/vasic-digital/ATMOSphere-SmartTube |
| vasic-digital | caf-open-interpreter | 97.60 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-open-interpreter |
| HelixDevelopment | HelixCluster | 95.64 | Go | 2026-06-17 |  | https://gitlab.com/helixdevelopment1/helix_cluster |
| vasic-digital | caf-cline | 93.12 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-cline |
| vasic-digital | caf-vtcode | 92.27 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-vtcode |
| HelixDevelopment | ShareConnect | 91.81 | Kotlin | 2025-12-13 |  | https://gitlab.com/helixdevelopment1/shareconnect |
| vasic-digital | Herald | 87.59 | Go | 2026-06-02 |  | https://gitlab.com/vasic-digital/herald |
| vasic-digital | caf-gemini-cli | 78.25 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-gemini-cli |
| HelixDevelopment | Helix Ota | 72.25 | Go | 2026-06-11 |  | https://gitlab.com/helixdevelopment1/helix_ota |
| vasic-digital | ATMOSphere-VLC-Player | 67.83 | Kotlin | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-VLC-Player.git | https://gitlab.com/vasic-digital/ATMOSphere-VLC-Player |
| vasic-digital | caf-codai | 67.01 | Go Template | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-codai |
| vasic-digital | caf-qwen-code | 63.95 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-qwen-code |
| HelixDevelopment | HelixPlay | 55.53 | Go | 2026-05-03 |  | https://gitlab.com/helixdevelopment1/HelixPlay |
| vasic-digital | caf-plandex | 55.52 | Go | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-plandex |
| HelixDevelopment | HelixConstitution | 52.28 | HTML | 2026-06-16 |  | https://gitlab.com/helixdevelopment1/helixconstitution |
| vasic-digital | ATMOSphere-Lampa | 52.11 | Kotlin | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Lampa.git | https://gitlab.com/vasic-digital/ATMOSphere-Lampa |
| vasic-digital | ATMOSphere-Gramophone-Player | 44.47 | Kotlin | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Gramophone-Player.git | https://gitlab.com/vasic-digital/ATMOSphere-Gramophone-Player |
| vasic-digital | caf-noi | 38.05 | TSX | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-noi |
| vasic-digital | caf-swe-agent | 36.16 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-swe-agent |
| vasic-digital | caf-nanocoder | 32.81 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-nanocoder |
| vasic-digital | ATMOSphere-Strep-Player | 32.29 | HTML | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Strep-Player.git | https://gitlab.com/vasic-digital/ATMOSphere-Strep-Player |
| vasic-digital | ATMOSphere-MPV-Player | 32.01 | HTML | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:milos85vasic/ATMOSphere-MPV-Player.git | https://gitlab.com/vasic-digital/ATMOSphere-MPV-Player |
| vasic-digital | caf-x-cmd | 30.78 | Awk | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-x-cmd |
| vasic-digital | caf-git-mcp | 30.07 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-git-mcp |
| vasic-digital | Catalogizer | 29.07 | Go | 2026-05-08 |  | https://gitlab.com/vasic-digital/catalogizer |
| vasic-digital | caf-claude-code | 27.52 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-claude-code |
| vasic-digital | tmux | 24.84 | HTML | 2026-06-17 | vasic-digital optimized + verified containerized tmux build — reproducible across hosts, jemalloc-aware, OOM-protected,  | https://gitlab.com/vasic-digital/tmux |
| vasic-digital | HelixQA | 24.50 | Go | 2026-06-15 | AI-driven QA orchestration for multi-platform testing | https://gitlab.com/vasic-digital/HelixQA |
| vasic-digital | caf-crush | 24.47 | Go | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-crush |
| HelixDevelopment | HelixQA | 23.79 | Go | 2026-06-09 | AI-driven QA orchestration for multi-platform testing | https://gitlab.com/helixdevelopment1/HelixQA |
| vasic-digital | caf-get-shit-done | 22.35 | JavaScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-get-shit-done |
| vasic-digital | caf-gptme | 20.89 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-gptme |
| vasic-digital | caf-amazon-q | 20.88 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-amazon-q |
| vasic-digital | containers | 20.55 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/containers |
| vasic-digital | caf-gpt-engineer | 17.48 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-gpt-engineer |
| vasic-digital | caf-snow-cli | 15.38 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-snow-cli |
| vasic-digital | ATMOSphere-TorrServe | 13.85 | Kotlin | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-TorrServe.git | https://gitlab.com/vasic-digital/ATMOSphere-TorrServe |
| vasic-digital | panoptic | 11.24 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/panoptic |
| vasic-digital | ATMOSphere-Presenter | 11.06 | Kotlin | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Presenter.git | https://gitlab.com/vasic-digital/ATMOSphere-Presenter |
| vasic-digital | caf-forge | 10.70 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-forge |
| vasic-digital | caf-xela-cli | 9.22 | TSX | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-xela-cli |
| vasic-digital | caf-spec-kit | 8.82 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-spec-kit |
| vasic-digital | caf-taskweaver | 8.34 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-taskweaver |
| vasic-digital | caf-zeroshot | 7.70 | JavaScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-zeroshot |
| HelixDevelopment | LLMOrchestrator | 7.27 | HTML | 2026-04-27 |  | https://gitlab.com/helixdevelopment1/LLMOrchestrator |
| HelixDevelopment | VisionEngine | 6.63 | HTML | 2026-05-29 | Computer vision and LLM Vision for UI analysis and navigation | https://gitlab.com/helixdevelopment1/VisionEngine |
| HelixDevelopment | DocProcessor | 6.56 | HTML | 2026-06-17 |  | https://gitlab.com/helixdevelopment1/DocProcessor |
| vasic-digital | VisionEngine | 5.87 | HTML | 2026-06-15 | Computer vision and LLM Vision for UI analysis and navigation | https://gitlab.com/vasic-digital/VisionEngine |
| vasic-digital | caf-junie | 5.70 | Shell | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-junie |
| vasic-digital | DocProcessor | 5.44 | HTML | 2026-06-09 | Documentation processing and feature map extraction for QA automation | https://gitlab.com/vasic-digital/DocProcessor |
| HelixDevelopment | Builder | 5.38 | Shell | 2025-10-28 |  | https://gitlab.com/helixdevelopment1/builder |
| HelixDevelopment | HelixGitpx | 5.17 | Go | 2026-05-08 |  | https://gitlab.com/helixdevelopment1/helixgitpx |
| vasic-digital | LLMOrchestrator | 4.99 | HTML | 2026-06-09 | Headless CLI agent management for LLM orchestration | https://gitlab.com/vasic-digital/LLMOrchestrator |
| vasic-digital | LLMProvider | 4.99 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/LLMProvider |
| vasic-digital | challenges | 4.69 | Go | 2026-06-16 | digital.vasic.challenges - Reusable Go module | https://gitlab.com/vasic-digital/challenges |
| vasic-digital | caf-ui-ux-pro-max | 4.61 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-ui-ux-pro-max |
| vasic-digital | caf-mistral-code | 4.44 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-mistral-code |
| vasic-digital | caf-aichat | 4.20 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-aichat |
| vasic-digital | assets | 4.20 | HTML | 2026-04-29 |  | https://gitlab.com/vasic-digital/assets |
| HelixDevelopment | HelixLLM | 3.99 | Go | 2026-06-15 |  | https://gitlab.com/helixdevelopment1/helixllm |
| vasic-digital | caf-fauxpilot | 3.53 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-fauxpilot |
| vasic-digital | caf-shai | 3.44 | Rust | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-shai |
| vasic-digital | caf-claude-squad | 3.24 | Go | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-claude-squad |
| vasic-digital | ATMOSphere-Nova-Player | 3.18 | HTML | 2026-06-15 | ATMOSphere submodule backup mirror — git@github.com:milos85vasic/ATMOSphere-Nova-Player.git | https://gitlab.com/vasic-digital/ATMOSphere-Nova-Player |
| vasic-digital | claude-toolkit | 2.33 | HTML | 2026-06-16 |  | https://gitlab.com/vasic-digital/claude-toolkit |
| vasic-digital | caf-codex-skills | 2.30 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-codex-skills |
| vasic-digital | recovery | 2.28 | Go | 2026-06-09 |  | https://gitlab.com/vasic-digital/recovery |
| vasic-digital | config | 2.26 | Go | 2026-06-09 | digital.vasic.config - Reusable Go module | https://gitlab.com/vasic-digital/config |
| vasic-digital | DebateOrchestrator | 2.08 | Go | 2026-04-29 |  | https://gitlab.com/vasic-digital/DebateOrchestrator |
| vasic-digital | RedTeam | 2.04 | Shell | 2026-06-17 | YAML-driven adversarial prompt fixture harness for defensive LLM guardrail regression testing | https://gitlab.com/vasic-digital/RedTeam |
| vasic-digital | Normalize | 1.92 | Shell | 2026-06-17 | Adversarial-input canonicalisation library for defensive LLM guardrail pipelines | https://gitlab.com/vasic-digital/Normalize |
| vasic-digital | ratelimiter | 1.89 | Go | 2026-06-09 | digital.vasic.ratelimiter - Reusable Go module | https://gitlab.com/vasic-digital/ratelimiter |
| vasic-digital | document | 1.71 | Shell | 2026-06-09 | Go document model with format detection and change tracking | https://gitlab.com/vasic-digital/document |
| vasic-digital | caf-multiagent-coding | 1.70 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-multiagent-coding |
| vasic-digital | caf-octogen | 1.65 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-octogen |
| vasic-digital | docs_chain | 1.64 | Go | 2026-06-17 | docs_chain — universal bidirectional document/database dependency-propagation engine (Salsa-style content-hashed increme | https://gitlab.com/vasic-digital/docs_chain |
| vasic-digital | i18n | 1.61 | Shell | 2026-06-09 | digital.vasic.i18n - Generic internationalization Go module | https://gitlab.com/vasic-digital/i18n |
| vasic-digital | security | 1.33 | Go | 2026-06-16 | digital.vasic.security - Reusable Go module | https://gitlab.com/vasic-digital/security |
| HelixDevelopment | HelixSpecifier | 1.32 | Go | 2026-06-17 |  | https://gitlab.com/helixdevelopment1/HelixSpecifier |
| HelixDevelopment | HelixMemory | 1.31 | Go | 2026-06-17 |  | https://gitlab.com/helixdevelopment1/HelixMemory |
| vasic-digital | eventbus | 1.28 | Go | 2026-06-17 | digital.vasic.eventbus - Reusable Go module | https://gitlab.com/vasic-digital/eventbus |
| vasic-digital | SkillRegistry | 1.25 | Go | 2026-06-17 | CLI agent skill registration and management for AI agent systems | https://gitlab.com/vasic-digital/SkillRegistry |
| vasic-digital | database | 1.23 | Go | 2026-06-17 | digital.vasic.database - Reusable Go module | https://gitlab.com/vasic-digital/database |
| vasic-digital | observability | 1.22 | Go | 2026-06-17 | digital.vasic.observability - Reusable Go module | https://gitlab.com/vasic-digital/observability |
| vasic-digital | cache | 1.21 | Go | 2026-06-17 | digital.vasic.cache - Reusable Go module | https://gitlab.com/vasic-digital/cache |
| vasic-digital | concurrency | 1.20 | Go | 2026-06-17 | digital.vasic.concurrency - Reusable Go module | https://gitlab.com/vasic-digital/concurrency |
| vasic-digital | auth | 1.18 | Go | 2026-06-17 | digital.vasic.auth - Reusable Go authentication module | https://gitlab.com/vasic-digital/auth |
| vasic-digital | storage | 1.14 | Go | 2026-06-17 | digital.vasic.storage - Reusable Go module | https://gitlab.com/vasic-digital/storage |
| vasic-digital | middleware | 1.11 | Go | 2026-06-09 | digital.vasic.middleware - Reusable Go module | https://gitlab.com/vasic-digital/middleware |
| vasic-digital | streaming | 1.10 | Go | 2026-06-17 | digital.vasic.streaming - Reusable Go module | https://gitlab.com/vasic-digital/streaming |
| vasic-digital | MCP_Module | 1.08 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/MCP_Module |
| vasic-digital | RAG | 1.06 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/RAG |
| vasic-digital | Optimization | 1.06 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/Optimization |
| vasic-digital | plugins | 1.04 | Go | 2026-06-17 | digital.vasic.plugins - Reusable Go module | https://gitlab.com/vasic-digital/plugins |
| vasic-digital | Embeddings | 1.02 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/Embeddings |
| vasic-digital | LLMOps | 1.02 | Go | 2026-06-17 | LLM operations: evaluation, experiments, datasets, prompt versioning | https://gitlab.com/vasic-digital/LLMOps |
| vasic-digital | conversation | 1.01 | Go | 2026-06-17 | Conversation context management, infinite context compression, and event sourcing for AI agents | https://gitlab.com/vasic-digital/conversation |
| vasic-digital | Benchmark | 1.01 | Go | 2026-06-17 | LLM benchmarking: SWE-bench, HumanEval, MMLU, leaderboard | https://gitlab.com/vasic-digital/Benchmark |
| vasic-digital | ToolSchema | 1.00 | Go | 2026-06-17 | Generic tool schema definition, validation, and execution for AI agent tool systems | https://gitlab.com/vasic-digital/ToolSchema |
| vasic-digital | Planning | 1.00 | Go | 2026-06-17 | AI planning algorithms: HiPlan, MCTS, Tree of Thoughts | https://gitlab.com/vasic-digital/Planning |
| vasic-digital | SelfImprove | 0.99 | Go | 2026-06-17 | AI self-improvement: reward modelling, RLHF, optimizer | https://gitlab.com/vasic-digital/SelfImprove |
| vasic-digital | Agentic | 0.99 | Go | 2026-06-17 | Graph-based agentic workflow orchestration | https://gitlab.com/vasic-digital/Agentic |
| vasic-digital | VectorDB | 0.97 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/VectorDB |
| vasic-digital | messaging | 0.97 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/messaging |
| vasic-digital | filesystem | 0.85 | Go | 2026-06-09 | digital.vasic.filesystem - Reusable Go module | https://gitlab.com/vasic-digital/filesystem |
| vasic-digital | caf-postgres-mcp | 0.73 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-postgres-mcp |
| vasic-digital | lazy | 0.73 | Go | 2026-06-09 |  | https://gitlab.com/vasic-digital/lazy |
| vasic-digital | watcher | 0.72 | Go | 2026-06-09 | digital.vasic.watcher - Reusable Go module | https://gitlab.com/vasic-digital/watcher |
| vasic-digital | Models | 0.63 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/Models |
| HelixDevelopment | LLMProvider | 0.54 | Go | 2026-04-27 |  | https://gitlab.com/helixdevelopment1/LLMProvider |
| vasic-digital | BackgroundTasks | 0.52 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/BackgroundTasks |
| vasic-digital | memory | 0.52 | Go | 2026-06-17 |  | https://gitlab.com/vasic-digital/memory |
| vasic-digital | formatters | 0.46 | Go | 2026-06-17 | digital.vasic.formatters - Reusable Go module | https://gitlab.com/vasic-digital/formatters |
| vasic-digital | caf-copilot-cli | 0.37 | Shell | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-copilot-cli |
| HelixDevelopment | DebateOrchestrator | 0.33 | Go | 2026-06-17 | Debate Orchestrator (GitLab mirror of HelixDevelopment/DebateOrchestrator) | https://gitlab.com/helixdevelopment1/DebateOrchestrator |
| vasic-digital | tracker_sdk | 0.31 | Kotlin | 2026-05-20 | Generic, tracker-agnostic SDK primitives: mirror manager, plugin registry, testing harness. | https://gitlab.com/vasic-digital/tracker_sdk |
| vasic-digital | caf-aichat-llm-functions | 0.31 | Shell | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-aichat-llm-functions |
| vasic-digital | mdns | 0.18 | Go | 2026-05-20 | Generic Go module for RFC 6762/6763 mDNS service announcement and discovery — drop-in LAN service registration | https://gitlab.com/vasic-digital/mdns |
| HelixDevelopment | ota-android-agent | 0.17 | Kotlin | 2026-06-10 | Helix OTA — Kotlin/KMP device agent (poll, download, verify, apply, report). Reusable submodule. | https://gitlab.com/helixdevelopment1/ota-android-agent |
| vasic-digital | ui-components-react | 0.16 | TSX | 2026-04-29 | Reusable TypeScript/React module | https://gitlab.com/vasic-digital/ui-components-react |
| vasic-digital | caf-deepseek-cli-youkpan | 0.13 |  | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-deepseek-cli-youkpan |
| vasic-digital | caf-cli-agent | 0.12 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-cli-agent |
| vasic-digital | caf-deepseek-cli | 0.12 | TypeScript | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-deepseek-cli |
| vasic-digital | PliniusCommon | 0.12 | Go | 2026-04-29 | SCAFFOLD / WIP -- Common types/errors library (shared foundation for the 8 sibling modules) | https://gitlab.com/vasic-digital/PliniusCommon |
| HelixDevelopment | ota-rollout-engine | 0.11 | Go | 2026-06-11 | Helix OTA — OS-agnostic staged-rollout + halt/advance engine (percentage cohorts, success/error thresholds). Reusable su | https://gitlab.com/helixdevelopment1/ota-rollout-engine |
| HelixDevelopment | ota-artifact-validator | 0.11 | Go | 2026-06-11 | Helix OTA — OTA artifact structure/hash/signature/metadata validation pipeline. Reusable submodule. | https://gitlab.com/helixdevelopment1/ota-artifact-validator |
| HelixDevelopment | ota-update-engine-bridge | 0.10 | Kotlin | 2026-06-08 | Helix OTA — thin bridge over AOSP update_engine / boot_control for A/B apply. Android submodule. | https://gitlab.com/helixdevelopment1/ota-update-engine-bridge |
| vasic-digital | Ouroborous | 0.10 | Go | 2026-04-29 | SCAFFOLD / WIP -- Recursive/self-referential safety patterns | https://gitlab.com/vasic-digital/Ouroborous |
| vasic-digital | Veritas | 0.10 | Go | 2026-04-29 | SCAFFOLD / WIP -- Truth/verification auxiliary | https://gitlab.com/vasic-digital/Veritas |
| HelixDevelopment | ota-protocol | 0.09 | Go | 2026-06-11 | Helix OTA — shared wire protocol, manifest schema, status/event types (Go + KMP). Reusable submodule. | https://gitlab.com/helixdevelopment1/ota-protocol |
| vasic-digital | entities | 0.09 | Go | 2026-04-29 |  | https://gitlab.com/vasic-digital/entities |
| HelixDevelopment | ota-telemetry-schema | 0.09 | Go | 2026-06-08 | Helix OTA — telemetry event/metric schema + codecs shared by server and agents. Reusable submodule. | https://gitlab.com/helixdevelopment1/ota-telemetry-schema |
| vasic-digital | caf-conduit | 0.08 |  | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-conduit |
| vasic-digital | media | 0.08 | Go | 2026-04-29 | digital.vasic.media - Reusable Go module | https://gitlab.com/vasic-digital/media |
| vasic-digital | calling-engine-ts | 0.08 | TypeScript | 2026-03-07 | Generic SIP.js + WebRTC calling engine | https://gitlab.com/vasic-digital/calling-engine-ts |
| vasic-digital | state-management-ts | 0.07 | TypeScript | 2026-03-07 | Generic Redux Toolkit state management utilities | https://gitlab.com/vasic-digital/state-management-ts |
| vasic-digital | http3 | 0.06 | Go | 2026-06-03 | Generic Go module wrapping quic-go/http3 for net/http.Handler servers — drop-in HTTP/3 support | https://gitlab.com/vasic-digital/http3 |
| vasic-digital | discovery | 0.06 | Go | 2026-06-03 | digital.vasic.discovery - Reusable Go module | https://gitlab.com/vasic-digital/discovery |
| vasic-digital | websocket-client-ts | 0.06 | TypeScript | 2026-03-06 | Reusable TypeScript/React module | https://gitlab.com/vasic-digital/websocket-client-ts |
| vasic-digital | testing-utils-ts | 0.05 | TypeScript | 2026-03-07 | Generic React + Redux testing utilities | https://gitlab.com/vasic-digital/testing-utils-ts |
| vasic-digital | formatters-kmp | 0.05 | Kotlin | 2026-05-01 | Cross-platform KMP text format detection, parsing interfaces, and format registry | https://gitlab.com/vasic-digital/formatters-kmp |
| vasic-digital | api-client-ts | 0.05 | TypeScript | 2026-03-07 | Generic REST API client for TypeScript | https://gitlab.com/vasic-digital/api-client-ts |
| vasic-digital | database-kmp | 0.05 | Kotlin | 2026-05-01 | digital.vasic.database - KMP network storage database interfaces and entity types | https://gitlab.com/vasic-digital/database-kmp |
| vasic-digital | auth-kmp | 0.05 | Kotlin | 2026-05-01 | Kotlin Multiplatform OAuth2 authentication: flows, token management, secure storage interface | https://gitlab.com/vasic-digital/auth-kmp |
| vasic-digital | document-kmp | 0.05 | Kotlin | 2026-05-01 | Kotlin Multiplatform document model with format detection and change tracking | https://gitlab.com/vasic-digital/document-kmp |
| vasic-digital | config-kmp | 0.05 | Kotlin | 2026-05-01 | Kotlin Multiplatform storage configuration types for network protocols | https://gitlab.com/vasic-digital/config-kmp |
| vasic-digital | Claritas | 0.05 | Go | 2026-04-29 | SCAFFOLD / WIP -- System-prompt extraction detection | https://gitlab.com/vasic-digital/Claritas |
| vasic-digital | concurrency-kmp | 0.05 | Shell | 2026-05-01 | Kotlin Multiplatform concurrency utilities: lazy loading, platform synchronization, flow-based loaders | https://gitlab.com/vasic-digital/concurrency-kmp |
| vasic-digital | AutoTemp | 0.05 | Go | 2026-04-29 | SCAFFOLD / WIP -- Benchmark-driven temperature auto-tuning orchestration | https://gitlab.com/vasic-digital/AutoTemp |
| vasic-digital | I-LLM | 0.04 | Go | 2026-04-29 | SCAFFOLD / WIP -- Introspection layer for LLM providers | https://gitlab.com/vasic-digital/I-LLM |
| vasic-digital | GandalfSolutions | 0.04 | Go | 2026-04-29 | SCAFFOLD / WIP -- Read-only solutions archive for prompt-leak-defense testing | https://gitlab.com/vasic-digital/GandalfSolutions |
| vasic-digital | HyperTune | 0.04 | Go | 2026-04-29 | SCAFFOLD / WIP -- Hyperparameter tuning orchestration | https://gitlab.com/vasic-digital/HyperTune |
| vasic-digital | LeakHub | 0.04 | Go | 2026-04-29 | SCAFFOLD / WIP -- Prompt-leak corpus / defensive-use fixtures (red-team training) | https://gitlab.com/vasic-digital/LeakHub |
| HelixDevelopment | DagOrchestrator | 0.04 | Go | 2026-06-10 | Pure-data DAG scheduler (dev.helix.dag) | https://gitlab.com/helixdevelopment1/DagOrchestrator |
| vasic-digital | i18n-client-ts | 0.04 | TypeScript | 2026-03-07 | Generic client-side i18n wrapper around i18next | https://gitlab.com/vasic-digital/i18n-client-ts |
| vasic-digital | task_bridge | 0.03 | Go | 2026-06-09 | Generic, decoupled bidirectional task/board sync engine (SQLite workable-items SSoT <-> tracker docs <-> ClickUp/Jira/Li | https://gitlab.com/vasic-digital/task_bridge |
| vasic-digital | ui-components-kmp | 0.03 | Kotlin | 2026-05-05 | Kotlin Multiplatform UI components: theme system, animations, accessibility utilities for Compose | https://gitlab.com/vasic-digital/ui-components-kmp |
| vasic-digital | storage-kmp | 0.02 | Shell | 2026-05-01 | digital.vasic.storage - KMP network storage service interfaces and abstractions | https://gitlab.com/vasic-digital/storage-kmp |
| vasic-digital | ratelimiter-kmp | 0.02 | Shell | 2026-05-01 | Kotlin Multiplatform rate limiting: semaphore, token bucket, adaptive, throttler | https://gitlab.com/vasic-digital/ratelimiter-kmp |
| vasic-digital | security-kmp | 0.02 | Kotlin | 2026-05-01 | Kotlin Multiplatform secure storage: AES encryption, platform Keychain/KeyStore integration | https://gitlab.com/vasic-digital/security-kmp |
| vasic-digital | LLMGateway | 0.02 | Go | 2026-04-14 |  | https://gitlab.com/vasic-digital/llmgateway |
| HelixDevelopment | PipelineRuntime | 0.02 | Go | 2026-06-10 | Staged streaming dataflow runtime (dev.helix.pipeline) | https://gitlab.com/helixdevelopment1/PipelineRuntime |
| vasic-digital | VisualRegression | 0.02 | Go | 2026-03-30 | Reusable VisualRegression module | https://gitlab.com/vasic-digital/VisualRegression |
| vasic-digital | ReplayBuffer | 0.01 | Go | 2026-03-30 | Reusable ReplayBuffer module | https://gitlab.com/vasic-digital/ReplayBuffer |
| vasic-digital | ScreenDiff | 0.01 | Go | 2026-03-30 | Reusable ScreenDiff module | https://gitlab.com/vasic-digital/ScreenDiff |
| vasic-digital | TrainingCollector | 0.01 | Go | 2026-03-30 | Reusable TrainingCollector module | https://gitlab.com/vasic-digital/TrainingCollector |
| vasic-digital | caf-aiagent | 0.01 | Python | 2026-06-10 |  | https://gitlab.com/vasic-digital/caf-aiagent |
| vasic-digital | TOON | 0.00 | Go | 2026-04-04 | Generic reusable Go module: digital.vasic.toon - Token-Oriented Object Notation wrapper | https://gitlab.com/vasic-digital/TOON |
| vasic-digital | Media-Types-TS | 0.00 |  | 2026-03-30 | Vasic Digital Media-Types-TS | https://gitlab.com/vasic-digital/Media-Types-TS |
| vasic-digital | Media-Player-React | 0.00 |  | 2026-03-30 | Vasic Digital Media-Player-React | https://gitlab.com/vasic-digital/Media-Player-React |
| vasic-digital | Media-Browser-React | 0.00 |  | 2026-03-30 | Vasic Digital Media-Browser-React | https://gitlab.com/vasic-digital/Media-Browser-React |
| vasic-digital | Dashboard-Analytics-React | 0.00 |  | 2026-03-30 | Vasic Digital Dashboard-Analytics-React | https://gitlab.com/vasic-digital/Dashboard-Analytics-React |
| vasic-digital | Collection-Manager-React | 0.00 |  | 2026-03-30 | Vasic Digital Collection-Manager-React | https://gitlab.com/vasic-digital/Collection-Manager-React |
| vasic-digital | Catalogizer-API-Client-TS | 0.00 |  | 2026-03-30 | Vasic Digital Catalogizer-API-Client-TS | https://gitlab.com/vasic-digital/Catalogizer-API-Client-TS |
| vasic-digital | Auth-Context-React | 0.00 |  | 2026-03-30 | Vasic Digital Auth-Context-React | https://gitlab.com/vasic-digital/Auth-Context-React |
| vasic-digital | bear-messenger | 0.00 |  | 2026-03-06 | Bear Messenger - Multi-platform encrypted messenger | https://gitlab.com/vasic-digital/bear-messenger |

## 4. Top 15 deep dive

Summaries written from each project's README (fetched via `projects/:id/repository/files/README.md/raw`). All 15 had a `README.md`.

1. **ATMOSphere-Android-15** (vasic-digital, 1678.0 MB, Shell) — Backup mirror of the Android 15 (API 35) AOSP source tree, repackaged for git hosting using a hybrid storage scheme (~15GB source in git, ~20GB of compressed toolchain archives in `.compressed/` extracted by `setup.sh`). Ships helper scripts for compression, phased pushing, and build-env setup. Largest repo in the inventory at ~1.68 GB.

2. **HelixCode** (HelixDevelopment, 1431.6 MB, Go) — Enterprise-grade distributed AI development platform written in Go (`dev.helix.code`, MIT). Provides distributed worker pools over SSH, intelligent task division with checkpointing/rollback, multi-provider LLM integration (Llama.cpp/Ollama/OpenAI), MCP protocol support, and REST/WebSocket/CLI/TUI clients. README marks all 5 implementation phases complete.

3. **HelixAgent** (vasic-digital, 806.1 MB, Go) — Production AI-powered ensemble LLM service in Go that combines responses from 47+ LLM providers (Claude, DeepSeek, Gemini, Mistral, etc.) with dynamic provider selection scored via LLMsVerifier. Features an AI debate/consensus system, intelligent routing, streaming, and 20 extracted modules (auth, storage, RAG, memory, observability) with Prometheus/Grafana/OpenTelemetry monitoring.

4. **LLMsVerifier** (vasic-digital, 517.5 MB, Go) — Enterprise LLM verification/monitoring/optimization platform in Go. Enforces mandatory model verification (the "Do you see my code?" check) across 12 provider adapters, with real-time health monitoring, failover, analytics, LDAP/SSO, SQLCipher encryption, and an (llmsvd) branding-suffix system. Ships Python and JS SDKs and Docker/Kubernetes deployment.

5. **caf-agent-deck** (vasic-digital, 462.3 MB, Go) — Vendored copy of `asheshgoplani/agent-deck` (Go, MIT) — an "AI agent command center" that orchestrates fleets of CLI coding agents (e.g. Claude Code) via a conductor session, with Telegram/Slack/Discord bridges, watchers/doorbells for external events, and TUI/CLI management.

6. **caf-warp** (vasic-digital, 167.1 MB, Rust) — Vendored copy of `warpdotdev/warp` — Warp, an agentic development environment born from the terminal (Rust). UI crates are MIT-licensed, the rest AGPLv3. Supports built-in and bring-your-own CLI coding agents.

7. **caf-bridle** (vasic-digital, 166.5 MB, Python) — Vendored copy of `jeremylongshore/claude-code-plugins-plus-skills` ("Tons of Skills") — a validated Claude Code plugins/skills marketplace catalog (430+ plugins, 2,700+ skills) with a CLI (`ccpi`), spec validator, and grading rubric.

8. **caf-superset** (vasic-digital, 152.7 MB, TypeScript) — Vendored copy of `superset-sh/superset` (TypeScript) — "the code editor for AI agents" that orchestrates swarms of CLI coding agents (Claude Code, Codex, etc.) in parallel across isolated git worktrees, with a built-in terminal, diff viewer, and editor handoff.

9. **ATMOSphere-Rhythm-Player** (vasic-digital, 140.7 MB, Kotlin) — Backup mirror of `cromaguy/Rhythm` (Kotlin, GPLv3) — a Material 3 Expressive Android music player built on Media3 ExoPlayer with bit-perfect/Dolby Atmos playback, synced lyrics, a 10-band EQ, and FOSS/privacy focus. Mirrored as an ATMOSphere submodule.

10. **HelixConstitution** (vasic-digital, 139.1 MB, HTML) — The universal, project-agnostic engineering "constitution" (rules/conventions) shared as a git submodule by every Helix project. Defines a three-layer override model (base/project/subdir), anti-bluff covenant, data/host safety, commit discipline, and a 142-repo submodule catalogue. Pushed to multiple upstreams (GitHub/GitLab/GitFlic/GitVerse).

11. **caf-aider** (vasic-digital, 137.0 MB, Python) — Vendored copy of `Aider-AI/aider` (Python) — AI pair-programming in the terminal that works with most LLMs (Claude, DeepSeek, GPT, local models), maps the codebase, supports 100+ languages, and auto-commits changes with git integration.

12. **caf-codex** (vasic-digital, 132.4 MB, Rust) — Vendored copy of `openai/codex` (Rust, Apache-2.0) — OpenAI's Codex CLI coding agent that runs locally, installable via curl/npm/Homebrew, with IDE integrations and ChatGPT-plan or API-key auth.

13. **caf-codename-goose** (vasic-digital, 109.5 MB, Rust) — Vendored copy of `block/goose` (Rust, Apache-2.0) — "codename goose", a local, extensible, open-source on-machine AI agent that automates engineering tasks end-to-end (builds projects, writes/executes code, debugs, orchestrates workflows) and works with any LLM via MCP.

14. **ATMOSphere-SmartTube** (vasic-digital, 105.9 MB, Java) — Backup mirror of `yuliskov/SmartTube` (Java) — a free, open-source media client for Android TVs/TV boxes with SponsorBlock, 8K/60fps/HDR support, and no Google-Services requirement. README carries an upstream security advisory about a compromised build environment.

15. **caf-open-interpreter** (vasic-digital, 97.6 MB, Python) — Vendored copy of `OpenInterpreter/open-interpreter` (Python, AGPL) — lets LLMs run code (Python/JS/Shell) locally through a ChatGPT-like terminal interface, providing a natural-language interface to the computer with user approval before execution.

## 5. GitHub overlap (likely mirrors / vendored duplicates)

Two distinct duplication patterns were found, totalling **63 of 189 projects (~33%)** that are very likely dedup candidates:

### 5a. `caf-*` vendored upstream copies (49 projects)

Every project whose name starts with `caf-` is a vendored copy of a well-known upstream GitHub project (confirmed by READMEs pointing at the upstream repos). Examples verified from READMEs: `caf-warp` → `github.com/warpdotdev/warp`; `caf-codex` → `github.com/openai/codex`; `caf-aider` → `github.com/Aider-AI/aider`; `caf-superset` → `github.com/superset-sh/superset`; `caf-codename-goose` → `github.com/block/goose`; `caf-open-interpreter` → `github.com/OpenInterpreter/open-interpreter`; `caf-bridle` → `github.com/jeremylongshore/claude-code-plugins-plus-skills`; `caf-agent-deck` → `github.com/asheshgoplani/agent-deck`. Full `caf-*` list:

`caf-agent-deck`, `caf-aiagent`, `caf-aichat`, `caf-aichat-llm-functions`, `caf-aider`, `caf-amazon-q`, `caf-bridle`, `caf-claude-code`, `caf-claude-squad`, `caf-cli-agent`, `caf-cline`, `caf-codai`, `caf-codename-goose`, `caf-codex`, `caf-codex-skills`, `caf-conduit`, `caf-copilot-cli`, `caf-crush`, `caf-deepseek-cli`, `caf-deepseek-cli-youkpan`, `caf-fauxpilot`, `caf-forge`, `caf-gemini-cli`, `caf-get-shit-done`, `caf-git-mcp`, `caf-gpt-engineer`, `caf-gptme`, `caf-junie`, `caf-mistral-code`, `caf-multiagent-coding`, `caf-nanocoder`, `caf-noi`, `caf-octogen`, `caf-open-interpreter`, `caf-plandex`, `caf-postgres-mcp`, `caf-qwen-code`, `caf-shai`, `caf-snow-cli`, `caf-spec-kit`, `caf-superset`, `caf-swe-agent`, `caf-taskweaver`, `caf-ui-ux-pro-max`, `caf-vtcode`, `caf-warp`, `caf-x-cmd`, `caf-xela-cli`, `caf-zeroshot`

### 5b. Explicit GitHub backup mirrors (14 projects)

These projects' GitLab descriptions explicitly state they are backup mirrors of a GitHub repo (`git@github.com:...`):

| group | name | mirrors (from description) |
|---|---|---|
| vasic-digital | ATMOSphere-Android-15 | ATMOSphere main repo backup mirror |
| vasic-digital | HelixConstitution | ATMOSphere submodule backup mirror — git@github.com:HelixDevelopment/HelixConstitution.git |
| vasic-digital | ATMOSphere-VLC-Player | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-VLC-Playe |
| vasic-digital | ATMOSphere-TorrServe | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-TorrServe |
| vasic-digital | ATMOSphere-Strep-Player | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Strep-Pla |
| vasic-digital | ATMOSphere-SmartTube | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-SmartTube |
| vasic-digital | ATMOSphere-Rhythm-Player | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Rhythm-Pl |
| vasic-digital | ATMOSphere-Presenter | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Presenter |
| vasic-digital | ATMOSphere-Nova-Player | ATMOSphere submodule backup mirror — git@github.com:milos85vasic/ATMOSphere-Nova-Player.gi |
| vasic-digital | ATMOSphere-MPV-Player | ATMOSphere submodule backup mirror — git@github.com:milos85vasic/ATMOSphere-MPV-Player.git |
| vasic-digital | ATMOSphere-Lampa | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Lampa.git |
| vasic-digital | ATMOSphere-Gramophone-Player | ATMOSphere submodule backup mirror — git@github.com:ATMOSphere1234321/ATMOSphere-Gramophon |
| vasic-digital | tracker_sdk | Generic, tracker-agnostic SDK primitives: mirror manager, plugin registry, testing harness |
| HelixDevelopment | DebateOrchestrator | Debate Orchestrator (GitLab mirror of HelixDevelopment/DebateOrchestrator) |

`DebateOrchestrator` (HelixDevelopment) is described as a GitLab mirror of `HelixDevelopment/DebateOrchestrator`. The `ATMOSphere-*` set (11 projects) are backup mirrors of GitHub repos under the `ATMOSphere1234321` / `milos85vasic` orgs.
