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

**单一真相源，全平台同步——跨十余个主机的联邦式 Git 代理**

## 概述

HelixGitpx（Helix Git 代理扩展）是一款联邦式 Git 代理，能在多个上游 Git 主机间保持单一真相源的同步镜像，并通过策略与 AI 辅助流程解决不可避免的冲突。该项目已发布 v1.0.0 正式版。

## 简介

HelixGitpx 是一款联邦式 Git 代理，能在十余个 Git 主机（包括 GitHub、GitLab、Gitea、Bitbucket、Azure DevOps、AWS CodeCommit 等）间同步单一真相源，并通过策略与 AI 辅助流程解决同步冲突。现已发布 v1.0.0 正式版。

## 详细说明

HelixGitpx（全称"Helix Git 代理扩展"）是一款联邦式 Git 代理，能在多个上游 Git 主机间保持单一真相源的同步镜像，并解决同一仓库存在于多个平台时不可避免的冲突。其支持的上游平台涵盖整个 Git 生态系统：GitHub、GitLab、GitFlic、GitVerse、Gitea、Gitee、Bitbucket、Azure DevOps、AWS CodeCommit、Forgejo、SourceHut 以及通用的 Git-over-HTTPS。若简单地使用 `git push` 向十余个远程仓库推送，要么直接失败，要么更糟——各镜像会悄然偏离。而 HelixGitpx 则通过策略与 AI 辅助的冲突解决流程介入，将分歧重新统一为单一权威真相。

该项目现已发布 v1.0.0 正式版，从 `m1-foundation` 到 `m8-ga` 的里程碑均已标记完成，完整记录了从基础构建到正式发布的全过程。其架构分为三层一体化产品：Go 单体仓库（包含平台、十八项服务、代码生成与脚手架工具）承载联邦引擎；Angular 19 + Nx Web 应用；以及 Kotlin-Multiplatform + Compose 客户端框架，通过共享代码为 Android、iOS 及桌面端提供原生体验。平台交付完全采用 Kubernetes 原生技术栈——Helm 图表、Argo CD 应用、Kustomize 覆盖层、SQL 及 OPA 策略，CI 流水线均设有显式触发机制，确保无误发布。公开文档以 Docusaurus 网站（docs.helixgitpx.io）形式发布，同时配有 Astro 营销网站（helixgitpx.io）。

项目治理严格且以章程为本，这并非形式主义，而是核心特性：其基石文件为项目 Constitution，第二章明确要求七类测试矩阵覆盖率必须达到 *每类 100%、每个修改模块 100%*，且仅允许在单元测试中使用模拟对象，绝不容忍任何跳过的测试。每次构建均运行一次性验证器，对所有工件进行检查，并全面执行 `go vet` 和 `go test`，每次推送均同步至所有配置的上游仓库——因此，"镜像保持同步"不再是人工记忆的检查项，而是系统在每次提交时强制执行的规则。

## 为何开发

在多个 Git 主机间保持仓库的真实性——无论是出于冗余、主权还是区域平台覆盖的需求——既脆弱又繁琐，而分歧的镜像难以协调。HelixGitpx 的诞生，正是为了将多上游镜像功能提升为一项一流的、冲突感知的能力。

内容

## 为何这是一场变革

它将"推送至多个远程仓库并祈祷成功"的脆弱手动现状，转变为一个受管控的联邦系统——拥有一个权威的单一真相来源，并通过自动化策略与AI冲突解决机制实现协调。不仅如此，它还覆盖了异常广泛的主机范围，刻意纳入大多数工具默默忽略的区域平台（如GitFlic、GitVerse、Gitee），使冗余、数据主权及对这些生态的覆盖不再成为维护负担，而成为只需一次配置即可实现的单一能力。

## 创新之处

- **上游广度**——支持十余种Git托管平台，从GitHub、GitLab到GitFlic、GitVerse、Gitee等区域平台，全部统一于一个代理层后端。
- **基于策略与AI的冲突解决**——分歧由策略引擎与AI解析器自动协调，无需人工逐一比对镜像。
- **单一真相来源的联邦模式**——全上游推送模型，以一个权威仓库为真相源，所有托管平台均为与之保持同步的镜像。
- **严格的宪章式测试**——七种测试类型，每类覆盖率均达100%，且无跳过，通过一次性执行的绿色测试套件验证，而非依赖信任。

## 最大技术挑战及解决方案

- **多上游的分歧与冲突**。同一仓库存在于十余个平台，一旦两个主机接受不同的写入操作，便会立即产生偏差。解决方案：以单一真相源为锚点，结合基于策略与AI的冲突解决流程，辅以全上游同步推送机制，确保所有镜像始终向该真相源收敛。
- **异构Git托管平台的统一支持**。每个平台都有各自的认证机制、特性及API。解决方案：通过`Upstreams/`目录下的每上游配置脚本，以及一个抽象平台差异的层，使添加新平台仅需配置，无需重写代码。
- **合并前的正确性验证**。解决方案：强制执行七类测试矩阵，并通过`verify-everything.sh`一次性检查门禁脚本运行完整测试集——若无法连接集群，则干净短路，确保正确性在本地与CI中均可验证。

## 技术栈

- **Go单体仓库**——核心代理与联邦引擎：包含一个平台、18个服务、代码生成及脚手架，统一于一个仓库中，确保整个引擎可作为一个整体构建与测试。
- **Angular 19 + Nx**——Web应用程序，Nx提供大型前端所需的单体仓库构建/缓存结构。
- **Kotlin Multiplatform + Compose**——原生Android、iOS及桌面端客户端外壳，均从同一共享代码库生成，实现"一套代码，三端适配"。
- **Kubernetes + Helm + Argo CD + Kustomize**——云原生交付：Helm打包发布版本，Kustomize按环境调整覆盖层，Argo CD通过GitOps协调，确保集群状态与Git保持一致。
- **OPA（Rego）**——将冲突解决与访问控制以代码形式定义的策略，确保授权决策可声明化且可审计。
- **Docusaurus**——公共文档站点（docs.helixgitpx.io）；**Astro**——营销站点（helixgitpx.io），每种工具均与其内容类型匹配。
- **mise**——固定且可复现的工具链，确保每位贡献者与CI运行器均使用完全相同的版本构建。

内容

## 状态与诚信说明

- **状态：已发布。** 项目的 README 文件宣布 v1.0.0 GA 版本，并标记了从 `m1-foundation` 到 `m8-ga` 的里程碑。（"v1.0.0 GA" 为项目 README 自行声明的版本。）
- **许可证：待定。** GitHub 与 API 报告显示为 `MIT` 许可，而 README 的许可证章节则标注为 Apache-2.0（代码） / CC-BY-SA-4.0（文档）——发布前需核对实际 LICENSE 文件。
- 文档（docs.helixgitpx.io）与营销（helixgitpx.io）网址均依据 README 提供，未独立获取——实时状态**未验证**。

**优先级：** Helix-主线。

