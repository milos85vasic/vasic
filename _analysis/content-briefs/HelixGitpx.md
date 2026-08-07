# HelixGitpx

**Tagline:** One source of truth, mirrored everywhere — federated Git across a dozen hosts.

**Summary:** HelixGitpx (Helix Git Proxy eXtended) is a federated Git proxy that keeps a single source of truth mirrored across many upstream Git hosts and resolves the inevitable conflicts with policy- and AI-assisted flows. It reached v1.0.0 GA.

**Short description (~40 words):** HelixGitpx is a federated Git proxy that mirrors one source of truth across a dozen-plus Git hosts — GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit and more — and resolves sync conflicts with policy- and AI-assisted flows. Shipped as v1.0.0 GA.

**Long description (150-250 words):**
HelixGitpx — "Helix Git Proxy eXtended" — is a federated Git proxy that mirrors a single source of truth across many upstream Git hosts and resolves the conflicts that inevitably arise when the same repository lives in multiple places. Supported upstreams include GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut, and generic Git-over-HTTPS. Where a naive multi-remote push would fail or silently diverge, HelixGitpx applies policy- and AI-assisted resolution flows.

The project is at v1.0.0 GA, with milestones `m1-foundation` through `m8-ga` tagged. It is built as a Go monorepo (a platform plus eighteen services, code generation, and scaffolding tools), an Angular 19 + Nx web application, and Kotlin-Multiplatform + Compose client shells for Android, iOS, and Desktop. Platform delivery is Kubernetes-native: Helm charts, Argo CD applications, Kustomize overlays, SQL, and OPA policies, with CI pipelines gated behind explicit dispatch. Public documentation ships as a Docusaurus site (docs.helixgitpx.io) alongside an Astro marketing site (helixgitpx.io).

Governance is strict and constitution-driven: the load-bearing document is the project Constitution, whose Article II mandates a seven-type testing matrix at 100% coverage per type per module touched, with mocks allowed only in unit tests and no skipped tests. A one-shot verifier runs every artifact check plus `go vet`/`go test` across the workspace, and every push fans out to all configured upstreams.

**Why we built it:** Keeping a repository authentic across many Git hosts — for redundancy, sovereignty, or reach into regional platforms — is fragile and manual, and divergent mirrors are hard to reconcile. HelixGitpx was built to make multi-upstream mirroring a first-class, conflict-aware capability.

**Why it's a game-changer:** It turns "push to many remotes and hope" into a governed federation with a single source of truth and automated, policy-plus-AI conflict resolution — across an unusually broad set of hosts, including regional ones (GitFlic, GitVerse, Gitee) that most tooling ignores.

**What's innovative:**
- **Breadth of upstreams** — a dozen-plus Git hosts, including regional platforms, behind one proxy.
- **Policy- and AI-assisted conflict resolution** rather than manual reconciliation.
- **Single-source-of-truth federation** with an all-upstreams push model.
- **Rigorous, constitution-enforced testing** (seven test types, 100% per-type coverage, no skips) verified by a one-shot green-suite script.

**Biggest technical challenges + how solved:**
- *Divergence and conflicts across many upstreams* — solved with policy- and AI-assisted resolution flows over a single source of truth, plus an all-upstreams synchronized push.
- *Uniform support for heterogeneous Git hosts* — solved with per-upstream configuration scripts under `Upstreams/` and a platform layer abstracting the host differences.
- *Proving correctness before every merge* — solved with a mandatory seven-type test matrix and `verify-everything.sh` that also short-circuits cleanly when no cluster is reachable.

**Tech stack:**
- **Go monorepo** — platform + 18 services + codegen + scaffolding; core proxy/federation engine.
- **Angular 19 + Nx** — web application.
- **Kotlin Multiplatform + Compose** — Android / iOS / Desktop client shells from shared code.
- **Kubernetes + Helm + Argo CD + Kustomize** — cloud-native deployment and GitOps.
- **OPA (Rego)** — policy enforcement for resolution and access.
- **Docusaurus** — public documentation site; **Astro** — marketing site.
- **mise** — pinned, reproducible toolchain.

**Public links:**
- GitHub: https://github.com/HelixDevelopment/HelixGitpx (public, v1.0.0 GA)
- Docs: docs.helixgitpx.io · Marketing: helixgitpx.io (URLs per README; not independently fetched — UNVERIFIED live status)
- License: Apache-2.0 (code) / CC-BY-SA-4.0 (documentation).

**Suggested diagrams/illustrations (OpenDesign):**
1. Hub-and-spoke federation: one source-of-truth hub pushing to a ring of host logos (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit, GitFlic, GitVerse, Gitee, Forgejo, SourceHut).
2. Conflict-resolution flow: divergent mirrors → policy/AI resolver → reconciled single truth.
3. Delivery stack: Go platform + Angular web + KMP clients over a Kubernetes/Argo platform layer.

**Site relevance:** both (vasic.digital as a shipped GA developer-infrastructure product; milosvasic.ru as a strong flagship — a GA, broadly-integrated system).

**Priority tier:** Helix-primary.

**Source provenance:**
- `gh api repos/HelixDevelopment/HelixGitpx` (metadata: public, Go, MIT per API top-level field — but README states Apache-2.0 code / CC-BY-SA-4.0 docs; see note, created 2026-04-19, pushed 2026-05-08).
- `gh api repos/HelixDevelopment/HelixGitpx/readme` (upstream list, GA status/milestones, monorepo layout, test matrix, docs/marketing sites).
- `/Volumes/T7/Projects/vasic/_analysis/github-helix-others.{md,json}` (description).
- UNVERIFIED: license mismatch — GitHub API reports `MIT` while the README's License section states Apache-2.0 (code) / CC-BY-SA-4.0 (docs); resolve against the actual LICENSE file before publishing. Docs/marketing site liveness not fetched. "v1.0.0 GA" is the project's own README claim.
