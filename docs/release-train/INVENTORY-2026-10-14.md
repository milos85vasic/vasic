# Release-train inventory, 2026-10-14

| Field | Value |
|---|---|
| Generated | 2026-10-14 (read-only; `git fetch --all` run on the 14 top-level repos only; nested ahead/behind use existing remote-tracking refs and may be stale) |
| Scope | 14 top-level repos under `/home/milosvasic/Projects` + every nested submodule (`git submodule status --recursive`, nothing initialised or updated) |
| Raw data | full per-repo TSV (945 rows) kept outside the repo in the agent scratch dir; not committed |
| Status | Inventory only. No release action was taken. |

## 1. Summary

| Metric | Count |
|---|---:|
| Top-level repos | 14 |
| Nested submodule entries (recursive, parent-relative; the same repo appears under many parents) | 931 |
| Nested initialised | 772 |
| Nested UNINITIALISED (reported, not touched) | 159 (helix_code_005 139, helix_code 15, vasic 4, catalogizer 1) |
| Distinct nested origins | 305 |
| Distinct nested origins in owned orgs (vasic-digital, milos85vasic, HelixDevelopment, red-elf) | 183 |

Out of the requested scope but present in the directory: `helix_code_ws_006`, `jev`, `vasic-digital/` (not inventoried).

## 2. Top-level repos

| Repo | origin (org/name) | Remotes | Multi-push origin | Branch | HEAD | Modified | Untracked | Ahead/behind (current branch, non-zero only) | Latest tag | Tag scheme | Version source | Changelog head |
|---|---|---|---|---|---|---:|---:|---|---|---|---|---|
| ai_interviewing | milos85vasic/ai_interviewing | github,origin,upstream | no | main | 0fdab74ab5 | 0 | 0 | 0/0 all | - | none (no tags) |  | - |
| boba | milos85vasic/Boba-Base | github,gitlab,origin,upstream | no | main | d109cb1934 | 1 | 0 | gitlab +1/-0; upstream +1/-0 | 1.3.0 | bare semver (1.3.0), one legacy v1.0.0-rc | pyproject.toml; | CHANGELOG.md: # Changelog |
| catalogizer | vasic-digital/catalogizer | gitflicvasicdigital,github,githubvasicdigital,gitlab,gitlabvasicdigital,gitversevasicdigital,origin,upstream | origin(6)  | main | 232be3b6af | 1 | 0 | gitflicvasicdigital +1/-0; github +1/-0; githubvasicdigital +1/-0; gitlab +1/-0; gitlabvasicdigital +1/-0; gitversevasicdigital +1/-0; origin +1/-0; upstream +1/-0 | - | none (no tags; versions.json present) |  | - |
| claude_toolkit | vasic-digital/claude_toolkit | gitflic,github,gitlab,gitverse,origin,upstream | origin(4)  | main | 223c7025d2 | 0 | 0 | 0/0 all | v1.30.5 | dual: vX.Y.Z and claude_toolkit-X.Y.Z (prefixed per 11.4.151) | package.json;  pkg="version":"1.30.5" | CHANGELOG.md: # Changelog |
| helix_code | HelixDevelopment/code | github,gitlab,origin,upstream | origin(3)  | main | 9d24c5e829 | 4 | 2 | github +0/-5; gitlab +0/-5; origin +0/-5; upstream +0/-5 | helix-code-1.1.0-dev-0.0.4 | helix-code-1.1.0-dev-0.0.N (prefixed) | VERSION;go.mod; VERSION=1.0.0 gomod=module dev.helix.code/meta | CHANGELOG.md: # Changelog |
| helix_code_005 | HelixDevelopment/code | github,gitlab,origin,upstream | origin(3)  | 005-helixllm-provider-toolkit-binding | 8dbe13c5cc | 53 | 0 | 0/0 all | helix-code-1.1.0-dev-0.0.4 | same as helix_code (same origin) | VERSION;go.mod; VERSION=1.0.0 gomod=module dev.helix.code/meta | CHANGELOG.md: # Changelog |
| lava | milos85vasic/Lava | github,gitlab,origin,upstream | origin(2)  | master | d795293c36 | 1 | 0 | 0/0 all | Lava-API-Go-2.3.35-2335 | Lava-<Component>-X.Y.Z-<code> (component-prefixed) |  | CHANGELOG.md: # Changelog |
| llmctl | vasic-digital/llmctl | codeberg,gitflic,github,gitlab,gitverse,origin,upstream | origin(5)  | main | fc77be21a4 | 3 | 0 | codeberg +1/-0; gitflic +1/-0; github +1/-0; gitlab +1/-0; gitverse +1/-0; origin +1/-0; upstream +1/-0 | v3.2.2 | vX.Y.Z (unprefixed) | VERSION;go.mod; VERSION=3.2.2 gomod=module github.com/vasic-digital/llmctl | CHANGELOG.md: # Changelog |
| notes | milos85vasic/notes | gitflic,github,gitlab,gitverse,origin,upstream | origin(4)  | main | 79a03c352d | 0 | 0 | gitflic +8/-16; github +8/-0; gitlab +8/-0; gitverse +5/-0; origin +8/-0; upstream +8/-16 | - | none |  | - |
| project_toolkit | red-elf/Project-Toolkit | gitflic,github,origin,upstream | origin(2)  | main | 76cdfa9311 | 0 | 0 | 0/0 all | v1.0.0 | v1.0.0 only |  | - |
| tmux | vasic-digital/tmux | github,gitlab,origin,upstream | origin(2)  | main | 18595c8194 | 1 | 0 | 0/0 all | tmux-1.0.44 | dual: tmux-X.Y.Z and vX.Y.Z | VERSION;go.mod; VERSION=version=1.0.44versionCode=45released=2 gomod=module gith | CHANGELOG.md: # Changelog — vasic-digital/tmux |
| vasic | milos85vasic/vasic | github,origin,upstream | no | main | 305d6c8e0d | 10 | 1 | github +35/-0; origin +35/-0; upstream +35/-0 | v1.8.0 | vX.Y.Z (unprefixed) + pre-restyle |  | - |
| workshop | milos85vasic/workshop_curriculum | github,origin,upstream | no | main | c4c2a65294 | 8 | 13 | github +0/-144; origin +0/-144; upstream +0/-144 | - | none |  | - |
| ytdlp | milos85vasic/YT-DLP | github,gitlab,origin,upstream | no | main | 41e67ae3cf | 1 | 0 | 0/0 all | ytdlp-1.4.2 | ytdlp-X.Y.Z (prefixed); older v1.2.0 | VERSION; VERSION=VERSION_NAME=ytdlp-1.4.2VERSION_CODE=10 | CHANGELOG.md: # Changelog |

Visibility and latest release: `gh` is not usable (token invalid, section 6), so GitHub visibility and `gh release list` are **rc 2 (not determined)** for every repo; none were guessed. `glab release list` works for GitLab (verified read-only on `vasic-digital/claude_toolkit`: 30 releases); only claude_toolkit was spot-checked, the remaining GitLab mirrors were not queried (light-resources constraint). Visibility known from the vasic carrier (dated, not re-measured here): `workshop_curriculum`, `ai_interviewing`, `monetization` private; `vasic` public.

### 2.1 Governance and wrapper conventions (one line each, from each project's CLAUDE.md/AGENTS.md headings, not exhaustive)

- **ai_interviewing**: CLAUDE.md/AGENTS.md present; upstreams/GitHub.sh only; no CHANGELOG, no tags.
- **boba**: CHANGELOG.md (Keep-a-Changelog style `# Changelog`), pyproject.toml version, bare semver tags; gitlab and upstream remotes present.
- **catalogizer**: No tags, versions.json as version map; origin pushes to 6 hosts (gitflic, github, gitlab, gitverse variants); no upstreams/ dir at root.
- **claude_toolkit**: Four mirrors via upstreams/*.sh (GitHub, GitLab, GitFlic, GitVerse); package.json version 1.30.5; CHANGELOG.md; dual tag scheme.
- **helix_code**: VERSION=1.0.0 and go.mod, but tags are helix-code-1.1.0-dev-0.0.N (project-prefixed per 11.4.151); VERSION lags the tag; upstreams GitHub.sh + GitLab.sh.
- **helix_code_005**: Same origin as helix_code but on branch 005-helixllm-provider-toolkit-binding; same version/tag scheme.
- **lava**: Component-prefixed tags with version code; CHANGELOG.md mandatory per its 6.P distribution rule; master branch (not main).
- **llmctl**: VERSION=3.2.2 matches tag v3.2.2; CHANGELOG.md; five mirrors (codeberg, gitflic, github, gitlab, gitverse).
- **notes**: No tags/version/changelog; origin pushes to 4 hosts; local diverged from gitflic.
- **project_toolkit**: Own commit wrapper `./commit` (Conventional Commits, push to all upstreams) via Upstreamable; Version/Versionable subprojects; tag v1.0.0.
- **tmux**: VERSION file uses key=value (version, versionCode); CHANGELOG.md; dual tag scheme tmux-X.Y.Z + vX.Y.Z; CLAUDE.md documents 11.4.88 background push.
- **vasic**: Commit wrapper `commit`; upstreams/GitHub.sh (GitLab recipe disabled); vX.Y.Z tags, no root CHANGELOG.md; CONTINUATION.md must be updated per commit (12.10).
- **workshop**: Private; origin milos85vasic/workshop_curriculum; no tags/changelog.
- **ytdlp**: VERSION holds VERSION_NAME=ytdlp-X.Y.Z + VERSION_CODE; CHANGELOG.md; prefixed tags.

Constitution 11.4.151 (read from `submodules/constitution/Constitution.md`): every release tag and version name on the main repo and every owned submodule MUST be `<PREFIX>-<version>` (example `myproject-1.0.0-dev-0.0.1`); PREFIX = `HELIX_RELEASE_PREFIX` from `.env` if set, else the lowercased snake_case project root dir name; the prefix MUST be identical across the main repo and all owned submodules within a release; tag only after the 11.4.40 full-suite retest is green; push by merge-onto-latest-main, never force. No escape flags. **Measured compliance:** helix_code, helix_code_005, ytdlp, tmux (dual), claude_toolkit (dual), lava (component-prefixed) use a prefix; llmctl, vasic, project_toolkit, boba use unprefixed semver; ai_interviewing, catalogizer, notes, workshop have no tags. Whether `HELIX_RELEASE_PREFIX` is set per project was not inspected (`.env` is secret-bearing and was not read).

## 3. Nested submodules

All 931 nested entries are listed in the scratch TSV. Because the same repository is vendored under many parents, the table below groups by origin for the **owned** orgs (183 distinct origins); third-party origins (122 distinct, e.g. allure2, appium, llama_index, cli agent forks under `caf-*` excepted) are counted only.

### 3.1 Owned origins appearing as nested submodules (parent count, parents, distinct pinned HEADs, latest tag seen)

| Origin | Parents | #parents | Distinct pins | Latest tag seen |
|---|---|---:|---:|---|
| HelixDevelopment/constitution | helix_code | 1 | 1 | helixconstitution-v69 |
| HelixDevelopment/DagOrchestrator | helix_code | 1 | 1 | helixcode-v1.1.0 |
| HelixDevelopment/DebateOrchestrator | helix_code | 1 | 1 | helixcode-v1.1.0 |
| HelixDevelopment/DocProcessor | catalogizer,helix_code,vasic | 3 | 2 | helix-code-1.0.0-dev-0.0.1 |
| HelixDevelopment/helix_perf_cache | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 1 | - |
| HelixDevelopment/HelixAgent | helix_code,helix_code_005,ytdlp | 3 | 2 | helix-code-1.0.0-dev-0.0.1 |
| HelixDevelopment/HelixConstitution | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,tmux,vasic,ytdlp | 10 | 10 | helixconstitution-v68 |
| HelixDevelopment/HelixLLM | helix_code | 1 | 1 | helixllm-0.2.0 |
| HelixDevelopment/HelixMemory | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| HelixDevelopment/HelixQA | catalogizer,helix_code | 2 | 2 | hxs-v1 |
| HelixDevelopment/helixqa | lava,ytdlp | 2 | 2 | hxs-v1 |
| HelixDevelopment/HelixSpecifier | helix_code | 1 | 1 | helixcode-v1.1.0 |
| HelixDevelopment/LLMOrchestrator | catalogizer,helix_code,lava,vasic | 4 | 3 | helix-code-1.0.0-dev-0.0.1 |
| HelixDevelopment/LLMProvider | catalogizer,helix_code,vasic | 3 | 2 | helix-code-1.0.0-dev-0.0.1 |
| HelixDevelopment/PipelineRuntime | helix_code | 1 | 1 | helixcode-v1.1.0 |
| HelixDevelopment/qa | boba,vasic | 2 | 2 | hxs-v1 |
| HelixDevelopment/skills | helix_code | 1 | 1 | - |
| HelixDevelopment/VisionEngine | catalogizer,helix_code,vasic | 3 | 2 | helix-code-1.0.0-dev-0.0.1 |
| milos85vasic/ai_interviewing | vasic | 1 | 1 | - |
| milos85vasic/BuildCheck | helix_code,ytdlp | 2 | 1 | - |
| milos85vasic/ccode-private | helix_code,helix_code_005 | 2 | 1 | - |
| milos85vasic/milosvasic.ru | vasic | 1 | 1 | v1.8.0 |
| milos85vasic/monetization | vasic | 1 | 1 | - |
| milos85vasic/workshop_curriculum | vasic | 1 | 1 | - |
| red-elf/Dependable | project_toolkit | 1 | 1 | - |
| red-elf/Iconic | project_toolkit | 1 | 1 | - |
| red-elf/Installable | project_toolkit | 1 | 1 | - |
| red-elf/Project | project_toolkit | 1 | 1 | - |
| red-elf/Software-Toolkit | project_toolkit | 1 | 1 | - |
| red-elf/Testable | project_toolkit | 1 | 1 | - |
| red-elf/Upstreamable | project_toolkit,vasic | 2 | 2 | - |
| red-elf/Versionable | project_toolkit | 1 | 1 | - |
| vasic-digital/Agentic | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/anti_bluff | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 1 | - |
| vasic-digital/Assets | catalogizer | 1 | 1 | - |
| vasic-digital/Auth | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/auth | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Auth-Context-React | catalogizer | 1 | 1 | - |
| vasic-digital/AutoTemp | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/BackgroundTasks | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Benchmark | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Cache | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/cache | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Catalogizer-API-Client-TS | catalogizer | 1 | 1 | - |
| vasic-digital/Challenges | boba,catalogizer,helix_code,ytdlp | 4 | 2 | helixcode-v1.1.0 |
| vasic-digital/challenges | claude_toolkit,helix_code,lava,vasic | 4 | 2 | helixcode-v1.1.0 |
| vasic-digital/Claritas | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/claude-code-router | claude_toolkit,helix_code | 2 | 1 | v0.4.9 |
| vasic-digital/claude-toolkit | helix_code | 1 | 1 | v1.28.0 |
| vasic-digital/Collection-Manager-React | catalogizer | 1 | 1 | - |
| vasic-digital/Concurrency | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/concurrency | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Config | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/config | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Containers | boba,catalogizer,helix_code,llmctl,tmux,vasic | 6 | 3 | helixcode-v1.1.0 |
| vasic-digital/containers | claude_toolkit,helix_code,lava,vasic,ytdlp | 5 | 2 | helixcode-v1.1.0 |
| vasic-digital/continuum | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 2 | - |
| vasic-digital/conversation | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/curriculum-kit | vasic | 1 | 1 | - |
| vasic-digital/Dashboard-Analytics-React | catalogizer | 1 | 1 | - |
| vasic-digital/Database | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/database | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/design-toolkit | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 5 | v0.2.2 |
| vasic-digital/Discovery | catalogizer | 1 | 1 | - |
| vasic-digital/discovery | lava | 1 | 1 | - |
| vasic-digital/DocProcessor | lava | 1 | 1 | helix-code-1.0.0-dev-0.0.1 |
| vasic-digital/docs_chain | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 1 | helixcode-v1.1.0 |
| vasic-digital/Document | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Embeddings | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Entities | catalogizer | 1 | 1 | - |
| vasic-digital/EventBus | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/Filesystem | catalogizer,helix_code | 2 | 2 | helixcode-v1.1.0 |
| vasic-digital/Formatters | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/GandalfSolutions | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/http3 | lava | 1 | 1 | - |
| vasic-digital/HyperTune | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/I-LLM | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/I18n | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Lazy | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/LeakHub | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/llmctl | vasic | 1 | 1 | v3.2.2 |
| vasic-digital/LLMOps | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/LLMProvider | lava,vasic | 2 | 2 | helix-code-1.0.0-dev-0.0.1 |
| vasic-digital/LLMsVerifier | claude_toolkit,helix_code,lava,vasic | 4 | 4 | llmsverifier-v1.12.2 |
| vasic-digital/MCP_Module | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/mdns | lava | 1 | 1 | - |
| vasic-digital/Media | catalogizer,ytdlp | 2 | 1 | - |
| vasic-digital/Media-Browser-React | catalogizer | 1 | 1 | - |
| vasic-digital/Media-Player-React | catalogizer | 1 | 1 | - |
| vasic-digital/Media-Types-TS | catalogizer | 1 | 1 | - |
| vasic-digital/Memory | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/Messaging | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Middleware | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/middleware | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Models | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Normalize | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Observability | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/observability | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Optimization | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Ouroborous | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Panoptic | helix_code,lava | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/passage | vasic | 1 | 1 | v0.2.0 |
| vasic-digital/Planning | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/PliniusCommon | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Plugins | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/RAG | helix_code,vasic | 2 | 2 | helixcode-v1.1.0 |
| vasic-digital/RateLimiter | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/ratelimiter | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Recovery | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/recovery | lava | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/RedTeam | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/ReplayBuffer | catalogizer | 1 | 1 | - |
| vasic-digital/ScreenDiff | catalogizer | 1 | 1 | - |
| vasic-digital/Security | catalogizer,helix_code | 2 | 2 | helixcode-v1.1.0 |
| vasic-digital/security | lava,vasic | 2 | 2 | helixcode-v1.1.0 |
| vasic-digital/SelfImprove | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/session_orchestrator | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 1 | - |
| vasic-digital/SkillRegistry | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/Storage | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/Streaming | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/token_optimizer | boba,catalogizer,claude_toolkit,helix_code,lava,llmctl,project_toolkit,vasic,ytdlp | 9 | 1 | - |
| vasic-digital/ToolSchema | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/TOON | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/tracker_sdk | lava | 1 | 1 | v0.2.0 |
| vasic-digital/TrainingCollector | catalogizer | 1 | 1 | - |
| vasic-digital/UI-Components-React | catalogizer | 1 | 1 | - |
| vasic-digital/vasic-digital.github.io | vasic | 1 | 1 | v1.8.0 |
| vasic-digital/VectorDB | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/verdict | vasic | 1 | 1 | v0.1.1 |
| vasic-digital/Veritas | helix_code | 1 | 1 | helixcode-v1.1.0 |
| vasic-digital/VisionEngine | lava | 1 | 1 | 1.0.2-dev-0.0.2 |
| vasic-digital/VisualRegression | catalogizer | 1 | 1 | - |
| vasic-digital/Watcher | catalogizer,helix_code | 2 | 1 | helixcode-v1.1.0 |
| vasic-digital/WebSocket-Client-TS | catalogizer | 1 | 1 | - |
| vasic-digital/caf-* (49 repos, one per vendored CLI agent) | helix_code, helix_code_005 | 2 | - | - |

### 3.2 Nested repos with local changes (counts only)

| Path | Modified | Untracked |
|---|---:|---:|
| catalogizer/submodules/helix_qa | 4 | 4 |
| catalogizer/submodules/helix_qa/tools/opensource/docling | 1 | 0 |
| helix_code/constitution | 2 | 0 |
| helix_code/submodules/helix_qa/tools/opensource/docling | 1 | 0 |
| helix_code_005/awesome-ai-memory | 11 | 0 |
| tmux/constitution | 3 | 0 |
| vasic/submodules/challenges | 0 | 15 |
| vasic/submodules/constitution | 0 | 1 |
| vasic/submodules/qa | 21 | 0 |
| vasic/workshop | 4 | 2 |
| ytdlp/HelixAgent | 1 | 0 |
| ytdlp/HelixAgent/cli_agents/kilo-code | 0 | 1 |
| ytdlp/helixqa/tools/opensource/docling | 1 | 0 |

Plus 50 vendored `helix_code_005/cli_agents/*` checkouts that each report modifications (3 to 15560 entries, 59k+ total); these are third-party/vendored trees and the mass is consistent with mode or line-ending noise, **UNCONFIRMED** (contents not inspected).

### 3.3 Uninitialised nested submodules

159 entries: helix_code_005 139 (cli_agents/awesome lists), helix_code 15, vasic 4 (submodules/constitution/submodules/llmctl/{constitution,colibri,llama.cpp,superspec}), catalogizer 1. They are not touched and not part of any release unless the operator decides to init them.

### 3.4 Case-variant duplicates (same project, two origins)

`vasic-digital/{Challenges,challenges}`, `{Containers,containers}`, `{Auth,auth}`, `{Cache,cache}`, `{Concurrency,concurrency}`, `{Config,config}`, `{Database,database}`, `{Discovery,discovery}`, `{Middleware,middleware}`, `{Observability,observability}`, `{RateLimiter,ratelimiter}`, `{Recovery,recovery}`, `{Security,security}`, `HelixDevelopment/{HelixQA,helixqa}`, `vasic-digital/{claude-toolkit,claude_toolkit}`. Also vendor splits across orgs: `HelixDevelopment/LLMProvider` (vasic submodules/llm_provider, pin e05ec64ebc) vs `vasic-digital/LLMProvider` (vasic submodules/LLMProvider, **same pin e05ec64ebc**), `HelixDevelopment/DocProcessor` vs `vasic-digital/DocProcessor`, `HelixDevelopment/VisionEngine` vs `vasic-digital/VisionEngine`, `HelixDevelopment/qa` (submodules/qa) vs `HelixDevelopment/HelixQA`/`helixqa`, `HelixDevelopment/constitution` vs `HelixDevelopment/HelixConstitution`. Whether each pair is a GitHub redirect/rename or a genuine fork was not determined (needs authenticated API; rc 2).

## 4. Release dependency order

Derived from nesting evidence (what is a submodule of what); no manifest was parsed for semantic dependencies, so treat as a proposed order to be confirmed.

1. **Third-party leaves** (never released by us): everything under `submodules/qa/tools/opensource/*`, `helix_code*/cli_agents/*` forks except `vasic-digital/caf-*`, rdkcentral/MVT, etc. Pins only; no tags from us.
2. **Shared owned leaves** pinned inside every project via the constitution tree: `anti_bluff`, `continuum`, `docs_chain`, `session_orchestrator`, `token_optimizer`, `helix_perf_cache`, `design-toolkit` (v0.2.2), `llmctl` (also a top-level project; nested in vasic and in constitution), `containers`/`Containers`.
3. **Owned library modules** (leaf-ish Go/TS libs): `vasic-digital/{Auth,Cache,Config,Database,Security,...}` (catalogizer, helix_code), lowercase twins in lava, `LLMProvider`, `RAG`, `verdict`, `passage`, `curriculum-kit`, `doc_processor`, `llm_orchestrator`, `vision_engine`, `llms_verifier`, `challenges`, `qa`/`helixqa`/`helix_qa`.
4. **Mid-level products that other repos vendor**: `llmctl` (nested in vasic), `ai_interviewing`, `workshop`, `monetization`, `milosvasic.ru`, `vasic.digital`, `claude_toolkit` (nested in helix_code as claude-toolkit), `HelixAgent`, `HelixQA`.
5. **Top-level projects with no dependants among the 14**: boba, catalogizer, lava, tmux, ytdlp, project_toolkit, notes, claude_toolkit, helix_code / helix_code_005 (the latter two share one origin; see cycles).
6. **`vasic` (umbrella)**: after llmctl, workshop, ai_interviewing and its owned submodules, since it pins them. The umbrella pins its own `submodules/constitution`.
7. **`HelixDevelopment/HelixConstitution` consumers last**: every one of the 10 consuming top-level repos (boba, catalogizer, claude_toolkit, helix_code, lava, llmctl, project_toolkit, tmux, vasic, ytdlp) pins the constitution (10 distinct pins observed), so a constitution release forces a pin-bump commit in each consumer; do the constitution bump **after** each repo's own release tag, or release the constitution first and bump all consumers in one wave. Decide one; do not interleave.

**Cycles / duplicates to resolve before tagging:**
- `llmctl` is both a top-level repo and a submodule of `vasic` and of `constitution`; the constitution (nested in everything) itself pins `llmctl` (a consumer of the constitution that the constitution vendors): a genuine cycle (constitution -> llmctl -> constitution, with llmctl/constitution left uninitialised).
- The constitution vendors `design-toolkit`, `anti_bluff`, `docs_chain`, `session_orchestrator`, `token_optimizer`, `continuum`, which are also direct submodules of other projects: pins diverge (e.g. 10 distinct constitution pins and 5 `design-toolkit` pins across the fleet), so one release wave leaves mixed pins.
- `helix_code` and `helix_code_005` share origin `HelixDevelopment/code`; `_005` is a feature branch checkout. Release helix_code only; treat `_005` as a branch, not a repo.
- `claude_toolkit` also nested in helix_code as `vasic-digital/claude-toolkit` (hyphen/underscore twin).
- LLMProvider/llm_provider duplicate (above): both vasic submodule paths pin the same commit from two different org URLs.

## 5. Blockers

- **helix_code_005** top-level: 53 modified entries on branch 005-helixllm-provider-toolkit-binding (in-flight), plus ~59k modified entries across 50 vendored `cli_agents/*` checkouts and 139 uninitialised submodules.
- **workshop** (private): 8 modified + 13 untracked = 21 entries (matches the 21 expected, including the other agent's uncommitted `knowledge/` edits - paths not read); **0 ahead / 144 behind** origin/main after fetch, so a release needs a merge onto latest main first (11.4.113, no force).
- **vasic** (this repo): +35 ahead of origin/main (unpushed), 10 modified + 1 untracked at inventory time (modified `ai_interviewing`, `submodules/constitution`, `submodules/qa` gitlinks plus 4 harness evidence files; `submodules/qa` has 21 dirty entries; `submodules/challenges` 15 untracked; `workshop` nested 4 modified + 2 untracked). The nested `workshop` pin (fb798e98c9) differs from the standalone workshop checkout (c4c2a65294).
- **helix_code**: 4 modified + 2 untracked at top, 0 ahead / **5 behind** all remotes; nested `constitution` 2 modified and **13 commits ahead** of origin/upstream main (unpushed constitution work); `submodules/claude-toolkit` +7 on upstream, `submodules/claude-toolkit/constitution` +15 on github, `submodules/helix_qa` +5 upstream, `submodules/skills` +10, `mcp_servers` branch refs ahead.
- **catalogizer**: only 1 modified now (not ~820; the earlier large set is no longer in the tree - status at inventory time), but **+1 ahead** on every one of its remotes (unpushed commit); no tags at all; nested `submodules/helix_qa` 4 modified + 4 untracked; origin pushes to 6 URLs.
- **notes**: diverged from gitflic: **+8 ahead / -16 behind**; github, gitlab +8, gitverse +5 ahead; origin pushes to 4 hosts. Needs merge-onto-latest (not force) before any push; gitflic has 16 commits the others lack.
- **llmctl**: +1 ahead on all five remotes (codeberg, gitflic, github, gitlab, ...); 3 modified. Tag v3.2.2 matches VERSION; the unpushed commit post-dates it.
- **boba**: +1 ahead of gitlab and upstream; 1 modified. **tmux**: 1 modified. **ytdlp**: 1 modified (+ nested HelixAgent 1, helixqa docling 1, kilo-code 1 untracked). **lava**: 1 modified. **tmux/constitution**: 3 modified.
- **Missing CLI auth**: `gh` token for milos85vasic is INVALID (HTTP 401); every GitHub visibility check and `gh release list` is rc 2. Releases to GitHub cannot be created until `gh auth login -h github.com` is re-run by the operator. (git over SSH works: fetches succeeded.)
- **No CLI adapter** for gitflic and gitverse (and codeberg: no `tea`/API checked): releases there are manual/API only; git push over SSH works where the remotes are configured.
- **Remote-tracking staleness**: nested ahead/behind figures use existing refs (only the 14 top-level repos were fetched); third-party noise rows excluded here.
- **Uninitialised submodules** (159) cannot be validated for the "git submodule status --recursive clean" proof: `-` flags will remain unless the operator inits them.
- **Tag-scheme drift vs 11.4.151**: llmctl, vasic, boba, project_toolkit use unprefixed tags; four repos have no tags; helix_code VERSION (1.0.0) disagrees with its tag line (1.1.0-dev-0.0.4).

## 6. CLI authentication state

| CLI / host | State |
|---|---|
| `gh` (github.com) | Account `milos85vasic` (default, active) **token invalid**; "Failed to log in". Not usable. rc 2 for all GitHub API calls. Token and scopes were not printed. |
| `glab` (gitlab.com) | Logged in as `milos85vasic`, API over https, git ops over ssh, token in plaintext config (a keyring warning is shown). Read calls work (`glab release list` succeeded). Scopes not listed by glab status. |
| gitflic.ru | no CLI adapter; manual/API |
| gitverse.ru | no CLI adapter; manual/API |
| codeberg.org | llmctl has a codeberg remote; no CLI checked; manual/API |

## 7. Proposed per-repo release checklist (template)

Run from the repo root, one repo at a time, in the order of section 4. Nothing here has been run.

1. Fetch all remotes; confirm branch, `git status` (record dirty paths; stop if another agent's edits are in flight), and ahead/behind per remote. If behind or diverged: merge onto the latest main, never force (11.4.113).
2. Resolve the release prefix (`HELIX_RELEASE_PREFIX` from `.env`, else lowercased snake_case dir name) and confirm it is identical across the main repo and all owned submodules in this wave (11.4.151).
3. Run the project's own test suite and gates (11.4.40 full-suite retest before tag); capture output as evidence. Use bounded resources (no tmpfs).
4. Install/build the artifact and run a live end-user test against it (anti-bluff; PASS needs captured runtime evidence).
5. Update the changelog in the project's convention (CHANGELOG.md top entry: version and date).
6. Bump the version at the single source of truth (VERSION / package.json / go.mod constant / pyproject / versions.json), consistent with the tag.
7. Commit via the project wrapper (`commit` / `./commit` as documented) with the required trailer; update CONTINUATION.md where the project requires it.
8. Create the prefixed tag `<PREFIX>-<version>` on the release commit.
9. Fast-forward push branch and tag to ALL upstreams (every remote and every push URL of origin: github, gitlab, gitflic, gitverse, codeberg as configured); verify each remote head equals local HEAD with `git ls-remote`.
10. Create GitHub release (`gh release create`, needs re-auth) and GitLab release (`glab release create`); for gitflic/gitverse/codeberg create manually or via API.
11. Proof: `git status` clean, `git submodule status --recursive` shows no `+`/`-`/`U` flags for the repo, ahead/behind 0/0 on every remote.
12. In the parent repos, bump the submodule pin and the dependency manifest ref together in one change, then repeat this checklist for the parent.

## 8. Evidence and limits

- Counts come from `git submodule status --recursive` per top-level (14 TOP + 931 NESTED = 945 rows) and per-repo `git` reads; the TSV is in `~/.cache/agent-scratch/relinv/inv.tsv`.
- `git fetch --all` ran concurrently with the collector, so a handful of early rows may predate the fetch; top-level figures in section 2 were cross-checked after the fetch for the headline blockers.
- GitHub visibility and releases: not determined (gh auth invalid). GitLab visibility and releases: only claude_toolkit queried.
- No credentials, tokens or private file contents appear in this file.

