---
name: HelixCode
slug: helixcode
tier: helix-primary
order: 2
status: beta
license: MIT
private: false
tech:
  - Go
  - Gin
  - PostgreSQL
  - Redis
  - SSH
  - Model Context Protocol
  - llama.cpp
  - Ollama
repos:
  - https://github.com/HelixDevelopment/HelixCode
diagrams:
  - Layered architecture — API layer (REST/WebSocket/MCP) over core services (auth, worker pool, task/checkpointing, project/workflow, LLM) over the PostgreSQL + Redis data layer.
  - Distributed worker topology — a HelixCode server orchestrating SSH-connected workers across Linux/macOS/Windows/Aurora/SymphonyOS with health-monitoring indicators.
  - Task lifecycle / work-preservation flow — task division → distributed execution → checkpoint → rollback/resume, as a timeline.
  - Development workflow pipeline — planning → building → testing → refactoring with dependency arrows and multi-session context.
---

# HelixCode

**分布式AI开发平台，智能分工、进度保存、永不迷失方向。**

## 概要

HelixCode是一款企业级、基于Go的分布式AI开发平台，能将开发工作智能拆分为多个任务，分发至由SSH管理的工作节点网络，并通过自动检查点保存与回滚机制确保工作进度永不丢失。该平台统一整合多供应商LLM集成、完整开发生命周期流程，并支持REST、CLI、TUI及MCP等多种交互界面。

## 简介

HelixCode是一款基于Go开发的分布式AI开发平台。它将工作智能拆解为任务，分发至基于SSH的工作节点网络，通过自动检查点保存与回滚机制保障进度，整合多种LLM供应商，并通过REST、CLI、TUI及MCP等界面驱动完整开发生命周期。

## 详细描述

HelixCode是一款企业级分布式AI开发平台（`dev.helix.code`，MIT许可），其核心承诺如其宣传语所述：分解工作、保存进度、永不迷失方向。该平台专为智能任务拆分、自动进度保存及跨平台开发流程而设计，采用Go编写，以满足分布式计算对并发性和单二进制可移植性的需求——自动检查点保存、回滚及实时监控均作为核心功能而非可选插件提供。

其架构在一组专注的核心服务之上构建了REST + WebSocket + MCP的API交互层，包括：JWT认证与会话管理、基于SSH的工作节点池管理（带健康监控）、支持检查点保存与依赖处理的任务管理、项目与工作流管理，以及统一的LLM供应商层——所有数据均持久化存储于PostgreSQL，并可选配Redis作为协调与缓存层。分布式工作节点可自动部署至网络，扩展集群仅需将服务器指向目标机器而无需手动配置。多客户端界面涵盖CLI、终端UI、REST及移动框架，确保同一平台可通过脚本、终端或应用程序访问。

HelixCode全面驱动开发生命周期的端到端流程：规划、构建、测试及重构工作流均自动执行，具备依赖感知与多会话上下文跟踪能力，确保长期运行的任务在中断或跨设备迁移时仍能保持连贯性。平台整合了多种LLM供应商（如llama.cpp、Ollama及OpenAI），并通过统一接口提供硬件感知的模型选择功能，能自动检测可用的CPU/GPU/内存资源并匹配适合的模型。对于需要多轮推理的复杂问题，平台还支持链式思维（chain-of-thought）及树状思维（tree-of-thoughts）等高级推理策略。Model Context Protocol协议实现了跨多种传输层的标准化工具与上下文交换，并通过多渠道通知（Slack、Discord、电子邮件、Telegram）保持团队对分布式工作进度的实时掌握。平台支持Linux、macOS、Windows、Aurora OS及SymphonyOS等操作系统。

内容

## 我们为何构建它

分布式与 AI 辅助开发通常在任务跨机器分配或中断时丢失上下文与进度。HelixCode 的诞生，是为了让任务划分变得智能，工作保存实现自动化——从而将大型开发工作拆解、分发至工作节点网络，并通过检查点机制随时暂停、恢复或回滚，且不丢失任何状态。

## 为何它是颠覆性的

它让分布式 AI 开发首次具备了*持久性*——这一能力在团队手动拼接各环节时从未真正实现。三项原本分散在三个独立工具中的功能，如今整合为一个平台：分布式计算（SSH 工作节点网络，支持自动安装与健康监测）、AI 开发辅助（多供应商大语言模型，具备推理与工具调用能力）以及全生命周期工作流自动化。而连接这一切的核心，是基于数据库的检查点机制：由于任务状态、检查点及依赖关系均持久化存储于 PostgreSQL 中，跨越多台机器、多个会话的作业能够精准回滚或从中断处继续执行。中断与任务拆分不再意味着进度丢失，而成为一种可常规恢复的事件。

## 创新之处

- **工作保存作为核心基础能力**：将自动检查点与回滚机制应用于*分布式*开发任务，确保进度在中断或机器故障时依然保留，而非随之消散。
- **硬件感知的模型选择**：自动检测 CPU/GPU/内存配置，为每项任务匹配机器实际可高效运行的模型——无需手动为每个工作节点调优。
- **一个平台，五种交互入口**：REST、WebSocket、CLI、终端用户界面（TUI）及 MCP，其中 MCP 自身支持多种传输协议，方便工具与代理以任意连接方式集成。
- **跨平台覆盖范围超越常规桌面系统**：支持 Aurora OS 与 SymphonyOS，将工作节点扩展至大多数工具忽略的平台，拓宽了可用资源池。

## 最大技术挑战及解决方案

- **确保分布式、可中断任务不丢失工作进度**。当作业分散于多台机器时，任何崩溃或中断通常会导致正在执行的任务进度搁浅。我们将任务本身建模为携带检查点与依赖关系的载体，并持久化存储于 PostgreSQL 中，使系统能够回滚至上一个有效状态或从中断点恢复——这种持久性植根于数据层，而非脆弱的内存状态。
- **管理异构工作节点网络**。由 Linux、macOS、Windows、Aurora 及 SymphonyOS 组成的节点网络，其可用性与配置环境始终处于动态变化中。我们通过专门的工作节点池服务应对这一挑战，该服务基于 SSH 实现节点注册、新节点自动安装及持续健康监测，确保节点网络在机器加入或退出时依然可控。
- **应对供应商与硬件的异构性**。LLM 后端及其运行机器的能力千差万别。我们通过统一的 LLM 供应商接口屏蔽差异，并结合硬件检测（CPU/GPU/内存）驱动智能模型选择，确保合适的模型部署到合适的机器上，无需调用方考虑两者的具体细节。

内容

## 技术栈

- **Go（1.26+ 内核模块）**——选用该技术是因其基于 goroutine 的并发机制和单二进制输出，正好满足分布式工作节点系统的需求：低成本的并行编排能力，以及可自动部署至任意节点的独立二进制文件。它集成了所有核心服务及 CLI/server 二进制组件。
- **Gin（HTTP 框架）**——选用该框架是为构建高速、轻量的 REST 层，开销极低；其提供 `/api/v1` 接口（认证、工作节点、任务、项目等），供所有客户端调用。
- **PostgreSQL 15+（通过 pgx/v5）**——选用该数据库作为持久化系统，因检查点和回滚操作需依赖事务性存储；其维护包含 11 张表的分布式计算模式（用户、工作节点、任务、项目、会话、LLM 供应商、通知等），确保工作状态得以保留。
- **Redis 7+（可选，go-redis/v9）**——选用该组件作为可选的缓存与协调层，在不引入硬性依赖的前提下加速热点路径，确保最小化部署仍可仅依赖 Postgres 运行。
- **SSH**——选用该传输协议用于工作节点控制，正是因其已广泛部署且安全性高；无需预先部署定制化代理，即可驱动整个节点池的注册、自动安装及远程命令执行。
- **Model Context Protocol（MCP）**——选用该标准用于工具与上下文交换，使外部工具和代理能通过统一开放协议集成；实现多传输支持，以适应客户端的不同连接方式。
- **LLM 供应商（llama.cpp、Ollama、OpenAI）**——选用这些供应商以统一接口覆盖本地与托管推理服务，使硬件感知的任务路由能在本地模型或托管模型间无缝切换，调用方无需感知差异。

## 状态与诚信说明

- **状态：测试版。**README 自称已"完全完成/所有 5 个阶段"，但该完整性声明系项目方自述，而非独立验证结果，故本文档将其视为测试版。
- 上述所有细节均源自代码库 README；营销性表述（如标语）为编辑加工，而非源自技术指标。

**优先级别：** Helix 主要。

