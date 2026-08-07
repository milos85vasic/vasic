---
site: vasic.digital
type: company-site
title: Vasic Digital — AI-Native Software Engineering
tagline: We build AI development systems — and the governance that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Vasic Digital

## 英雄

**AI原生软件工程，值得信赖。**

任何人都能在一个下午将应用接入LLM模型。难点——决定一个AI系统是演示品还是可靠产品的关键——在于模型之外的一切：能在故障中幸存的供应商抽象层、确保智能体保持任务导向的编排机制、捕捉模型虚张声势的验证机制，以及证明整个系统行为可控的治理框架。这些难点正是Vasic Digital所构建的。我们设计并交付AI开发系统——包括模型、智能体、编排和基础设施，将大型语言模型转化为可靠的软件——同时配备确保其诚实可信的治理层。这一切都遵循一条不容妥协的原则：功能在测试通过时并不算"完成"；只有当真实用户能够实际使用，且有捕获的证据证明其有效时，才算真正完成。

## 关于

Vasic Digital是一个专注的工程实践团队，构建一系列相互关联的AI开发产品与可复用模块。与单一庞然大物不同，我们的工作以"舰队"形式组织：顶层是大型产品应用，底层则是数十个独立测试、解耦的小型模块——已验证的组件被跨产品复用，而非重复构建。核心语言为**Go**，辅以**Kotlin / Kotlin Multiplatform**、**TypeScript/React**、**Python**、**Swift**及**Shell**，按需选择：Go用于高吞吐量服务与库，Kotlin用于配置工具与跨平台移动端，TypeScript用于类型化前端，Python则用于AI/ML的粘合层。

将"舰队"凝聚在一起的，是机械化而非口号式的纪律。每个项目都通过Git子模块继承共享的工程**Constitution**——一条规则的收紧，即可传播至140多个代码库——且每项产品宣称的功能，都必须在通过自动化、产生证据的测试后，才算正式交付。这不是包装工作的营销话术，而是工作运行的底层模式。其复利效应才是真正的优势：由于通用功能被解耦为独立测试的模块，一处修复或改进即可同时提升所有产品，而每个新系统都由已赢得信任的组件组装而成。

## 我们的工作

**基于AI的开发。**我们构建AI系统的端到端基础设施：

- **多供应商LLM接入**——在统一接口下整合40多家供应商（Anthropic/Claude、OpenAI、DeepSeek、Gemini、Mistral、Cohere、Groq、xAI/Grok、Qwen、Perplexity、OpenRouter、Together AI、Replicate、Cerebras、Cloudflare Workers AI、SiliconFlow，并以本地Ollama作为后备），配备重试机制、熔断器及健康检查。
- **智能体编排**——无界面CLI编码智能体控制平面、基于图的智能工作流、多轮"AI辩论"共识机制，以及DAG/管道运行时。
- **LLM验证**——信任层通过强制理解门槛（"你能理解我的代码吗？"）及延迟、流式处理、函数调用、视觉与embeddings测试对模型进行评分，输出仅包含已验证的配置。
- **检索与记忆**——RAG、vector数据库、embeddings，以及融合智能体记忆引擎（Mem0 + Cognee + Letta），支持无限上下文压缩。
- **防御性LLM**——防护栏、PII检测、对抗性红队测试用例，以及输入规范化处理。

**Helix 产品系列**
我们的旗舰产品线涵盖完整的 AI 开发生命周期：

- **HelixTrack** —— 替代 JIRA（Helix-Track 系列旗舰产品）的开放世界方案。
- **HelixAgent** —— 一种集成式 LLM 服务，允许多个模型进行辩论，并输出共识结果。
- **HelixCode** —— 分布式 AI 开发平台，通过 SSH 管理的工作节点分配任务，支持检查点/回滚。
- **HelixLLM** —— 单一二进制文件，六种模式：从笔记本电脑到集群，兼容 OpenAI 和 Anthropic 推理，基于 HTTP/3 架构。
- **HelixCluster** —— 面向 AI 计算的分布式操作系统，覆盖数据中心 GPU 到边缘手持设备。
- **LLMProvider / LLMOrchestrator / LLMsVerifier** —— 服务提供抽象层、智能体控制平面及验证真值源。
- **HelixMemory、HelixSkills、HelixSpecifier、HelixBuilder、HelixTranslate、HelixTerminator、HelixGitpx、HelixOTA、HelixPlay** —— 记忆管理、受控技能、规约驱动开发、应用构建、可验证翻译、零信任终端、联邦 Git、安全 OTA 更新及自托管云游戏。

**工具与实用程序（vasic-digital 工具集）**
可独立使用的生产级工具：**Catalogizer**（多协议加密媒体资源管理）、**Courses-Creator**（Markdown 转视频的 AI 课程制作）、**VisionEngine**（计算机视觉 + LLM 视觉 UI 感知）、**DocProcessor**（文档到功能地图的 QA 转换）、**Docs Chain**（内容哈希双向文档/数据库同步）、**Herald**（自然语言多渠道通知）、**task_bridge**（双向任务/看板同步），以及 **Vasic Digital 可复用模块套件** —— `digital.vasic.*` 基础设施、AI 原语及防护模块的"标准库"。

**基础设施自动化（Server Factory）**
我们的 DevOps 传承：**Mail Server Factory** 及 **Server Factory 核心框架**，将声明式 JSON 转化为跨多种连接类型和 Linux 发行版的全配置 Docker 化服务器，并提供虚拟机镜像工具（Qemu-Utils、Parallels-Utils）及支持服务工厂。

## 技术栈

基于我们的实际技术架构：

- **编程语言：** Go（主导）、Kotlin & Kotlin Multiplatform、TypeScript、Python、Swift、Shell，在分布式系统工作中还采用 PL/pgSQL 甚至 TLA+ 形式化规约。
- **AI / LLM：** 多供应商接入（43+ 适配器）、Model Context Protocol（MCP）、RAG、vector 数据库及 embeddings、规划算法（HiPlan、MCTS、Tree of Thoughts）、LLMOps、基准测试（SWE-bench/HumanEval/MMLU）及 TTS（Bark、SpeechT5）。
- **后端：** Gin（Go）、gRPC + Protocol Buffers、HTTP/3（QUIC）、WebSocket、Angular 及 React 前端、Kafka/RabbitMQ 消息系统。
- **数据：** PostgreSQL、SQLite、SQLCipher（静态加密）、Redis、Neo4j、ClickHouse 及对象存储（MinIO/S3/GCS/Azure）。
- **基础设施 / DevOps：** Docker & Compose、Kubernetes + Helm、Prometheus + Grafana、OpenTelemetry、QEMU/Libvirt/Parallels，以及通过 GitHub Actions、Gradle 和 Make 实现的 CI/CD。
- **测试 / 质量保障：** 反虚假框架 HelixQA、带变异门的单模块挑战测试套件、`go test -race`、视觉回归测试工具、ADB 设备测试、SonarQube 门控，以及安全扫描（semgrep、gosec、trivy、snyk、gitleaks、nancy）。

内容

## 品质与治理——我们的核心竞争力

两大支柱确保整个代码库体系的统一性与可信度：

- **HelixConstitution** —— 一套通用的、不受项目限制的工程规范手册，以 Git 子模块形式发布，并被 140 多个代码库中的每个项目所继承。它固化了不可妥协的工程纪律：防止虚假承诺的验证门禁、假阳性免疫机制、数据与主机安全保障、文档与覆盖率规则等，项目可在此基础上扩展，但绝不可削弱。一次子模块更新即可同步规则至全局；传播门禁会通过字符串匹配确保所有代码库遵循必要条款，且每个门禁均配有变异测试，以证明其本身并非虚设。治理不再是愿景，而是可审计的事实。
- **HelixQA** —— 防虚假承诺的质量保证编排系统。它在 Android、Android TV、Web 及桌面端运行预定义的 **YAML** 测试库，并执行完全自动化的 **LLM** + 计算机视觉 QA 流程，且在未捕获运行时证据（截图、logcat 日志、视频、堆栈跟踪）的情况下，绝不判定为「通过」。「我们测试过」不再是空口无凭，而是「这是视频、日志和工单记录」。

## 定位宣言

任何人都能将应用与 **LLM** 连接，**Vasic Digital** 打造的是更难的部分：**AI** 系统——可验证、可复用且诚实可信。我们提供的是不依赖特定供应商的 **AI** 底层架构，基于此构建的 **Helix** 产品全生命周期，以及一套「宪法 + 证据」的纪律体系，确保交付的产品真正可用。我们不要求你相信绿色勾选，而是向你展示其背后的证据。

## 联系我们

让我们一起构建可验证的产品。

- **邮箱：** [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub：** [github.com/vasic-digital](https://github.com/vasic-digital)

