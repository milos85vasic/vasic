# MASTER Inventory — Single Source of Truth for Both Sites

**Date:** 2026-06-17 · All data verified from `gh`/`glab` API (no estimates, no bluff).
Sources: `github-vasic-digital.json` (185), `github-helix-others.json` (56), `gitlab-all.json` (189).

## 1. Totals (verified)

| Platform | Scope | Count | Notes |
|---|---|---|---|
| GitHub | vasic-digital | 185 | 53 forks, 4 archived, 20 private; 2 AOSP firmware repos ≈182 GB dominate size |
| GitHub | HelixDevelopment | 30 | constitution-driven Go product family |
| GitHub | Helix-Track | 13 | JIRA-alternative product line (most clients private) |
| GitHub | Helix-Flow | 1 | Platform (AI inference) |
| GitHub | Server-Factory | 12 | older Kotlin/Shell infra automation; mostly forks |
| GitLab | vasic-digital | 164 | mostly mirrors of GitHub; 49 `caf-*` vendored upstreams |
| GitLab | HelixDevelopment (`helixdevelopment1`) | 25 | mirrors |
| **GitHub total** | 5 orgs | **241** | |
| **GitLab total** | 2 groups | **189** | Helix-Track / Helix-Flow / Server-Factory **do not exist on GitLab** |

## 2. Exclusion rules for showcase (why size alone misleads)
- **AOSP firmware mirrors** `ATMOSphere-*` (~182 GB) — backups of external sources, one archived. EXCLUDE from showcase.
- **`caf-*` (≈49)** — vendored copies of upstream OSS (warp, codex, aider, superset, goose, open-interpreter…). EXCLUDE.
- **Backup mirrors (≈14)** — descriptions name a `git@github.com:` source. EXCLUDE.
- **Archived (8 total)** — EXCLUDE.
- **Private repos** — may be MENTIONED but must NOT be linked publicly (broken links). 

## 3. FEATURED set — public, first-party, advanced (links verified non-404)

Ranked by showcase merit (advancement + activity + role as flagship), size noted but not the sole driver.

| # | Project | Org | Lang | Public | Pushed | What it is (verified description) | Link |
|---|---|---|---|---|---|---|---|
| 1 | **HelixTrack Core** | Helix-Track | Go | ✅ 5★ | 2026-06-17 | "The Open-Source JIRA Alternative for the Free World" — enterprise project/issue tracking | github.com/Helix-Track/Core |
| 2 | **HelixCode** | HelixDevelopment | Go | ✅ 1★ | 2026-06-17 | AI coding agent / distributed multi-LLM development platform | github.com/HelixDevelopment/HelixCode |
| 3 | **HelixAgent** | HelixDevelopment | Go | ✅ 1★ | 2026-06-16 | LLMs agent — multi-LLM ensemble service | github.com/HelixDevelopment/HelixAgent |
| 4 | **HelixTranslate** | HelixDevelopment | Go | ✅ | 2026-06-17 | High-performance enterprise universal ebook translation toolkit; any format/language; multiple engines; REST + HTTP/3; real-time WebSocket | github.com/HelixDevelopment/HelixTranslate |
| 5 | **Helix-Flow Platform** | Helix-Flow | Go | ✅ | 2026-04-27 | "One platform for all your AI inference needs" — run AI models faster at any scale with predictable costs | github.com/Helix-Flow/Platform |
| 6 | **LLMsVerifier** | vasic-digital | Go | ✅ | 2026-06-16 | Benchmark and verify LLMs | github.com/vasic-digital/LLMsVerifier |
| 7 | **Catalogizer** | vasic-digital | Go | ✅ | 2026-05-03 | Advanced multi-protocol media collection management system | github.com/vasic-digital/Catalogizer |
| 8 | **Mail Server Factory** | Server-Factory | Shell | ✅ 3★ | 2025-11-12 | Automated mail-server deployment ("run your mail server like the boss") *(fork/mirror flag set)* | github.com/Server-Factory/Mail-Server-Factory |
| 9 | **Panoptic** | vasic-digital | Go | ✅ | 2026-06-17 | Automated testing, UI recording, screenshot capture across web/desktop/mobile | github.com/vasic-digital/Panoptic |
| 10 | **ShareConnect** | vasic-digital | Kotlin | ✅ 1★ | 2025-12-13 | Share downloadable URLs to remote/local processing endpoints | github.com/vasic-digital/ShareConnect |
| 11 | **GrabTube** | vasic-digital | Dart | ✅ | 2025-12-04 | Tube-services video downloader (Flutter) | github.com/vasic-digital/GrabTube |
| 12 | **Android-Toolkit** | vasic-digital | Kotlin | ✅ | 2026-03-24 | Common Android abstractions & implementations | github.com/vasic-digital/Android-Toolkit |

**Bench (also public, secondary):** Courses-Creator (Go), Asinka (Kotlin, IPC sync), Herald (Go, event fan-out/notifications), HelixPlay (Go, gaming), Core-Framework (Server-Factory, Kotlin).

## 4. Product families (for navigation grouping)
- **HelixTrack** (Helix-Track org) — Core (Go backend, JIRA alt) + clients: Web/Desktop (TypeScript), Android (Kotlin), iOS (Swift), Aurora, Harmony-OS. ⚠️ **All clients are PRIVATE** → present as "multi-platform clients" WITHOUT public links (or link only the org).
- **HelixDevelopment** — AI/LLM platform family: HelixCode, HelixAgent, HelixTranslate, HelixPlay, helix_cluster, helix_ota (+ ota-* libs), HelixConstitution (governance), plus decoupled libs (LLMProvider, LLMOrchestrator, HelixMemory, HelixSpecifier).
- **Helix-Flow** — Platform (AI inference).
- **Server-Factory** — Mail-Server-Factory, Core-Framework, per-service factories (Kotlin/Shell; older, 2022–2023; many forks).
- **vasic-digital (apps/libs)** — Catalogizer, GrabTube, ShareConnect, Panoptic, Yole, Android-Toolkit, Asinka, LLMsVerifier, Courses-Creator, Herald, Network-Binder(private), + many small Go microservice libs (auth, cache, database, observability, containers…).

## 5. FLAGS / corrections for the rebuild
- ⚠️ Current `vasic.digital` links to **private** Helix-Track clients → fix (404 risk).
- ⚠️ Current site references org **`Bear-Suite`** (Bear Mail/Messenger) — NOT in user's listed orgs and not found in inventory → confirm or remove.
- ⚠️ Unverified superlatives on current site ("50,000+ req/s", "102% parity with Confluence", "387 API actions") → verify against Core README or soften.
- ⚠️ Date inconsistency: "since 2023/2024" + "© 2025" → standardize.
- Brand color signals: personal `#a31e39` crimson; company `#dc3545` red. Keep distinct identities; preserve company `Logo.jpeg`.
- HelixAgent exists in BOTH vasic-digital (private copy) and HelixDevelopment (public) → link the **public** HelixDevelopment one.
