---
site: milosvasic.ru
type: personal-site
title: Miloš Vasić — AI Engineer
tagline: I build AI development systems — and the discipline that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Miloš Vasić

## 英雄

**AI 工程师，构建可验证的 AI 开发系统。**

我打造的是 AI 工程中将可靠产品与炫目演示区分开来的部分：能在供应商宕机时依然稳定运行的多供应商 LLM 基础设施、确保工作持续推进的自主代理与编排系统，以及防止 AI 系统悄然夸大能力的治理与质量保障层。将大型语言模型转化为真正可交付的产品，核心是纪律问题——而这正是我的专长。我的北极星原则只有一条：功能只有在真实用户能够使用且有捕获的证据证明时，才算完成。

## 概述

我的主要工作领域是 **Go**，并根据需求涉及 **Kotlin / Kotlin Multiplatform**、**TypeScript/React**、**Python**、**Swift** 和 **Shell**。我最关注的是工作的*结构化*方式：不是一堆一次性应用，而是一个产品舰队——大型应用程序构建于数十个小型、解耦、独立测试的模块之上，所有模块均通过 Git 子模块继承共享的工程 **Constitution**。这一架构选择使整个工作体系实现复利效应：修复与改进能即时传播至所有产品，新产品可由已验证的组件快速组装，且每一项宣称的功能都由生成证据的测试支撑，而非空洞承诺。这是为单人规模化信任而设计的工程。本页从概览逐步深入至各个项目，每个项目均链接至完整产品页面。

## 我的工作方式——治理与质量保障优先

在产品之前，是支撑它们的纪律：

- **HelixConstitution** —— 我维护一套通用的、可继承的工程规则手册，以 Git 子模块形式分发至 140+ 个代码库。它固化了反虚假宣传的证据门控、假阳性免疫机制、数据/主机安全规则及覆盖率要求；项目可收紧但不可放宽标准，且每个治理门控均配有一项变异测试，以验证门控本身的有效性。→ 查看 HelixConstitution 产品页面。
- **HelixQA** —— 我构建反虚假宣传的质量保障编排系统，在 Android、Android TV、Web 及桌面平台上运行书面测试库与全自动的 LLM 及视觉驱动 QA 会话，仅在捕获运行时证据后才判定为通过。→ 查看 HelixQA 产品页面。

## 我在 Helix 家族中的工作

Helix 产品线覆盖 AI 开发生命周期。按优先级排序：

- **HelixTrack** —— 自由世界的 JIRA 替代方案；Helix-Track 系列的旗舰产品。
- **HelixAgent** —— 一种集成式 LLM 服务，支持多轮模型辩论与基于验证的供应商选择。
- **HelixCode** —— 分布式 AI 开发平台，通过 SSH 管理的工作节点自动执行检查点/回滚。
- **HelixLLM** —— 单一二进制文件，提供六种模式，通过 HTTP/3 服务兼容 OpenAI 与 Anthropic 的 API，内置本地 llama.cpp 推理及评分回退链。
- **HelixCluster** —— AI 计算的分布式操作系统，覆盖数据中心 GPU 至边缘手持设备。
- **LLMProvider** —— 统一接口，整合 43 家供应商，内置熔断器、重试机制及健康检查。
- **LLMOrchestrator** —— 所有无界面 CLI 编码代理的统一控制平面。
- **LLMsVerifier** —— 验证、监控、优化：LLM/供应商/验证元数据的唯一真实来源。
- **HelixMemory、HelixSkills、HelixSpecifier、HelixBuilder、HelixTranslate、HelixTerminator、HelixGitpx、HelixOTA、HelixPlay** —— 代理记忆、受治理的代理技能、规约驱动开发、AI 应用构建、验证书籍翻译、零信任终端、联邦 Git、零砖化 OTA 更新，以及自托管云游戏。

内容

## 我开发的跨领域数字工具

我构建并维护的产品级工具（每项均有完整产品页面）：

- **Catalogizer** —— 支持多协议（SMB/FTP/NFS/WebDAV/本地）、加密、可自托管的媒体资源管理系统，配备 Go/Gin API 界面及 React 用户体验。
- **Courses-Creator** —— 从 Markdown 转视频的课程生产流水线，支持多 LLM 内容增强、TTS 处理，并提供桌面端/移动端/网页端播放器。
- **VisionEngine** —— 解耦的 Go 工具包，结合经典计算机视觉与多供应商 LLM 视觉技术，用于界面分析与导航图生成。
- **DocProcessor** —— 将文档转化为可验证的功能地图，用于 QA 自动化测试（支持 LLM 或启发式提取）。
- **Docs Chain** —— 基于内容哈希的双向原子化文档/数据库同步引擎。
- **Herald** —— 可靠的多渠道通知系统，具备自然语言三层意图解析能力。
- **task_bridge** —— 解耦的双向任务/看板同步引擎（P1 阶段框架，同步逻辑开发中）。
- **Vasic Digital 可复用模块套件** —— `digital.vasic.*` 基础设施「标准库」，包含 AI 原语及防护模块。

## 基础设施传承（Server Factory）

早于 AI 系列，我构建的 DevOps 工具链：**Mail Server Factory**（声明式 JSON → 完全预置的 Docker 化邮件服务器，通过 439 项测试及 SonarQube 检查点），其底层的 **Server Factory 核心框架**，以及 VM 镜像工具（**Qemu-Utils**、**Parallels-Utils**）及配套服务工厂。

## 一句话总结

我交付的不是「绿色对勾」——而是经过验证、能真正运行的 AI 系统，以及确保其持续稳定的治理机制。

## 联系方式

欢迎全球范围内的高级 AI/平台工程师职位合作。

- **邮箱：** [milos85vasic@gmail.com](mailto:milos85vasic@gmail.com) · [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub：** [milos85vasic](https://github.com/milos85vasic)
- **Telegram：** [@milos85vasic](https://t.me/milos85vasic)

