---
name: HelixGitpx
slug: helixgitpx
tier: helix-primary
order: 17
status: shipped
license: TBD
private: false
tech:
  - Go monorepo
  - Angular 19 + Nx
  - Kotlin Multiplatform + Compose
  - Kubernetes + Helm + Argo CD + Kustomize
  - OPA (Rego)
  - Docusaurus
  - Astro
  - mise
repos:
  - https://github.com/HelixDevelopment/HelixGitpx
diagrams:
  - Hub-and-spoke federation — one source-of-truth hub pushing to a ring of host logos (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit, GitFlic, GitVerse, Gitee, Forgejo, SourceHut).
  - Conflict-resolution flow — divergent mirrors → policy/AI resolver → reconciled single truth.
  - Delivery stack — Go platform + Angular web + KMP clients over a Kubernetes/Argo platform layer.
---

# HelixGitpx

**One source of truth, mirrored everywhere — federated Git across a dozen hosts.**

## Summary

HelixGitpx (Helix Git Proxy eXtended) is a federated Git proxy that keeps a single source of truth mirrored across many upstream Git hosts and resolves the inevitable conflicts with policy- and AI-assisted flows. It reached v1.0.0 GA.

## Short description

HelixGitpx is a federated Git proxy that mirrors one source of truth across a dozen-plus Git hosts — GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit and more — and resolves sync conflicts with policy- and AI-assisted flows. Shipped as v1.0.0 GA.

## Long description

HelixGitpx — "Helix Git Proxy eXtended" — is a federated Git proxy that keeps a single source of truth mirrored across many upstream Git hosts and resolves the conflicts that inevitably arise the moment the same repository lives in more than one place. Its supported upstreams read like a map of the entire Git ecosystem: GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut, and generic Git-over-HTTPS. Where a naive `git push` to a dozen remotes would either fail outright or, worse, let the mirrors silently drift apart, HelixGitpx steps in with policy- and AI-assisted resolution flows that reconcile divergence back to one authoritative truth.

The project is at v1.0.0 GA, with milestones `m1-foundation` through `m8-ga` tagged — a fully sequenced road from foundation to general availability. It is engineered as three tiers of one product: a Go monorepo (a platform plus eighteen services, code generation, and scaffolding tools) carrying the federation engine; an Angular 19 + Nx web application; and Kotlin-Multiplatform + Compose client shells that ship native experiences to Android, iOS, and Desktop from shared code. Platform delivery is Kubernetes-native to the core — Helm charts, Argo CD applications, Kustomize overlays, SQL, and OPA policies — with CI pipelines gated behind explicit dispatch so nothing rolls out by accident. Public documentation ships as a Docusaurus site (docs.helixgitpx.io) alongside an Astro marketing site (helixgitpx.io).

Governance is strict and constitution-driven, and that is a feature, not ceremony: the load-bearing document is the project Constitution, whose Article II mandates a seven-type testing matrix at 100% coverage *per type, per module touched*, with mocks permitted only in unit tests and not a single skipped test tolerated. A one-shot verifier runs every artifact check plus `go vet` and `go test` across the whole workspace, and every push fans out to all configured upstreams — so "the mirrors are in sync" is something the system enforces on every commit rather than something a human remembers to check.

## Why we built it

Keeping a repository authentic across many Git hosts — for redundancy, sovereignty, or reach into regional platforms — is fragile and manual, and divergent mirrors are hard to reconcile. HelixGitpx was built to make multi-upstream mirroring a first-class, conflict-aware capability.

## Why it's a game-changer

It turns "push to many remotes and hope" — the fragile, manual status quo — into a governed federation with one authoritative source of truth and automated, policy-plus-AI conflict resolution. And it does it across an unusually broad set of hosts, deliberately including the regional platforms (GitFlic, GitVerse, Gitee) that most tooling quietly ignores, so redundancy, data sovereignty, and reach into those ecosystems stop being a maintenance burden and become a single capability you configure once.

## What's innovative

- **Breadth of upstreams** — a dozen-plus Git hosts, from GitHub and GitLab to regional platforms like GitFlic, GitVerse, and Gitee, all normalised behind one proxy.
- **Policy- and AI-assisted conflict resolution** — divergence is reconciled by a policy engine and AI resolver, not by a human diffing mirrors by hand.
- **Single-source-of-truth federation** — an all-upstreams push model where one authoritative repo is the truth and every host is a mirror kept in lock-step.
- **Rigorous, constitution-enforced testing** — seven test types at 100% per-type coverage with no skips, proven by a one-shot green-suite script rather than trusted on faith.

## Biggest technical challenges & how we solved them

- **Divergence and conflicts across many upstreams.** The same repo living in a dozen places drifts the moment two hosts accept different writes. Solved with policy- and AI-assisted resolution flows anchored to a single source of truth, plus an all-upstreams synchronized push that keeps every mirror converging on that one truth.
- **Uniform support for heterogeneous Git hosts.** Every host has its own auth, quirks, and API. Solved with per-upstream configuration scripts under `Upstreams/` and a platform layer that abstracts those differences away, so adding a new host is configuration, not a rewrite.
- **Proving correctness before every merge.** Solved with a mandatory seven-type test matrix and a `verify-everything.sh` one-shot gate that runs the full check set — and short-circuits cleanly when no cluster is reachable, so correctness is provable locally as well as in CI.

## Tech stack

- **Go monorepo** — the core proxy and federation engine: a platform plus 18 services, code generation, and scaffolding, kept in one repo so the whole engine builds and tests as a unit.
- **Angular 19 + Nx** — the web application, with Nx providing the monorepo build/caching structure a large front end needs.
- **Kotlin Multiplatform + Compose** — native Android, iOS, and Desktop client shells generated from one shared codebase, so three platforms don't mean three implementations.
- **Kubernetes + Helm + Argo CD + Kustomize** — cloud-native delivery: Helm packages the release, Kustomize overlays adapt it per environment, and Argo CD reconciles it via GitOps so the cluster state matches Git.
- **OPA (Rego)** — policy as code for both conflict resolution and access control, keeping authorization decisions declarative and auditable.
- **Docusaurus** — the public documentation site (docs.helixgitpx.io); **Astro** — the marketing site (helixgitpx.io), each tool matched to its content type.
- **mise** — a pinned, reproducible toolchain so every contributor and CI runner builds against exactly the same versions.

## Status & honesty notes

- **Status: shipped.** The project's README declares v1.0.0 GA with milestones `m1-foundation` through `m8-ga` tagged. ("v1.0.0 GA" is the project's own README claim.)
- **License: TBD.** The GitHub API reports `MIT` while the README's License section states Apache-2.0 (code) / CC-BY-SA-4.0 (documentation) — resolve against the actual LICENSE file before publishing.
- The docs (docs.helixgitpx.io) and marketing (helixgitpx.io) URLs are per the README and were not independently fetched — live status UNVERIFIED.

**Priority tier:** Helix-primary.
