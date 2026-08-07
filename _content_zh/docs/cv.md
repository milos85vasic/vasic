---
doc: cv
title: Curriculum Vitae — Miloš Vasić
role: AI Engineer / Software Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
  company: https://vasic.digital
  github_orgs:
    - https://github.com/vasic-digital
    - https://github.com/HelixDevelopment
    - https://github.com/Server-Factory
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: Skills and projects are evidence-based (repository READMEs + analysis). Experience and Education are sourced verbatim from the candidate's own verified record at milosvasic.ru/README.md — real employers, roles, and dates; nothing fabricated (Constitution §11.4.6).
---

# Miloš Vasić

**工程师——构建可信赖的基础设施、自主代理及其治理体系**

- 电子邮箱：milos85vasic@gmail.com
- 网站：https://milosvasic.ru · https://vasic.digital
- 平台：vasic-digital · HelixDevelopment · Server-Factory

---

## 概述

我是一名AI/软件工程师，专注于端到端构建AI开发系统——从多供应商LLM基础设施与自主代理，到确保其可靠性的质量保证与治理层。我交付的不是演示产品，而是成熟的平台。拥有15年以上专业工程经验（自2009年起），涵盖移动SDK、实时硬件集成及分布式后端，如今专注于一个核心目标：在规模化应用中确保自主AI开发的可信度。

我设计的是机群而非单体架构——庞大的产品应用由数十个小型、解耦且独立测试的模块支撑，每个模块均继承共享的工程Constitution，并通过反虚假、证据驱动的质量保证流程验证。主要编程语言为Go，辅以Kotlin/KMP、TypeScript/React、Python、Swift及Shell。核心原则通过机械化手段强制执行，而非仅停留于口号：功能只有在真实用户能够使用且有确凿证据证明其有效时，才算完成。

**我的价值所在：** 能够将AI能力从研究构想转化为受治理、自验证且具备生产级形态的系统——LLM路由在信任模型前先验证其有效性，代理通过辩论达成共识而非盲目猜测，记忆与RAG层确保上下文不丢失，整个生态系统的设计确保"测试通过"绝不隐晦地意味着"功能失效"。

## 核心能力

- **AI / LLM系统：** 多供应商LLM抽象（40+供应商）、MCP工具集成、RAG、vector数据库与embeddings、代理编排（无头CLI代理、图工作流、多轮辩论/共识）、规划（HiPlan/MCTS/思维树）、LLMOps、基准测试（SWE-bench/HumanEval/MMLU）、LLM验证、防御性LLM防护、计算机视觉+LLM视觉。
- **后端工程：** Go（Gin）、gRPC + Protobuf、HTTP/3（QUIC）、WebSockets、分布式系统（含TLA+形式化规约）、高吞吐REST服务与并发工作进程。
- **数据：** PostgreSQL、SQLite、SQLCipher（静态加密）、Redis、Neo4j、ClickHouse、对象存储（MinIO/S3/GCS/Azure）。
- **前端 / 跨平台：** TypeScript/React（Tailwind、Redux Toolkit、i18next）、Angular、Electron、React Native、Kotlin Multiplatform、Android/Android TV（Kotlin）、iOS（Swift）、Tauri/Rust。
- **基础设施 / DevOps：** Docker与Compose、Kubernetes + Helm、Prometheus + Grafana、OpenTelemetry、QEMU/Libvirt/Parallels；通过GitHub Actions实现CI/CD、Gradle、Make。
- **质量保证 / 质量工程：** 反虚假证据驱动的质量保证（HelixQA）、带变异门的挑战测试框架、`go test -race`、视觉回归测试、ADB设备测试、SonarQube、安全扫描（semgrep/gosec/trivy/snyk/gitleaks/nancy）。
- **工程治理：** Constitution作为子模块；继承与传播门控；跨140+代码库的文档/覆盖率纪律。

## 精选项目

### 治理与质量保障
- **HelixConstitution** —— 一套以 Git 子模块形式分发的通用工程规范库，跨越 140 多个代码库继承使用：工程法则如同代码般发布与版本锁定。单次子模块更新即可升级整个系统的规则，且传播检查机制会逐一扫描所有依赖仓库，确保必备条款无一遗漏——每项检查均配有变异元测试，以验证检查本身并非虚设。它将"人们期望遵循的最佳实践"转化为代代相承、可审计、机械强制的反虚假法则。
- **HelixQA** —— 基于一条不容妥协的原则构建的反虚假质量保障编排系统（Go）：评判标准不是"测试通过"，而是"用户能否真正使用该功能"。它既运行预设的 YAML 测试库，也执行完全自主的 LLM 视觉联动质检流程，在真实应用环境中验证每一项文档记载的功能，同时在 Android/Android TV/Web/桌面平台上搜寻未记录的缺陷，且在未获取运行时证据（截图、logcat 日志、视频、堆栈跟踪）及生成 AI 修复就绪工单前，绝不给出"通过"评分。

### AI 开发与 LLM 基础设施
- **HelixAgent** —— 面向生产环境的 LLM 集成服务（Go/Gin），拒绝依赖单一模型：它将提示分发至多家供应商，通过结构化多轮辩论（提案→批评→审核→综合）进行决策，并基于实时验证评分智能路由，支持优雅降级——所有流程均构建于兼容 OpenAI 的 API 之上，具备高可用数据层、可观测性及防护机制。*涉及组件：Go、Gin、PostgreSQL、Redis、Prometheus/Grafana/OpenTelemetry、MCP、Neo4j/ClickHouse/Kafka。*
- **HelixCode** —— 分布式 AI 开发平台，将工作拆解为智能、依赖感知的任务，分发至由 SSH 管理的工作节点集群，并支持检查点保存与回滚，确保任务中断时数据不丢失；支持硬件感知的模型选择，覆盖完整的计划/构建/测试/重构生命周期，并集成 REST/CLI/TUI/MCP 等工具。*涉及组件：Go、Gin、PostgreSQL、Redis、SSH、MCP、llama.cpp/Ollama。*
- **HelixLLM** —— 单一二进制文件，六种部署模式：兼容 OpenAI 与 Anthropic 的 HTTP/3 推理引擎，可从笔记本电脑扩展至多主机集群，支持本地 llama.cpp 推理（CUDA/Metal/ROCm），并具备自动发现、验证评分的云端降级链路，确保始终能回退至本地保障模型。*涉及组件：Go、HTTP/3 QUIC、gRPC/SSE/Kafka、llama.cpp。*
- **LLMProvider / LLMOrchestrator / LLMsVerifier** —— LLM 基础设施的核心支柱：统一接口覆盖 43 家供应商，内置熔断机制、健康监控、抖动退避重试及诚实的模型发现机制（无硬编码降级）；线程安全的控制平面，可生成并驱动无头 CLI 代理（OpenCode、Claude Code、Gemini、Junie、Qwen Code），基于混合管道+文件协议通信；验证真值源，其强制性的"能否看到我的代码？"检查机制确保仅经过实际验证的模型才会被标记为可用或导出。
- **HelixMemory / HelixSpecifier** —— 统一认知记忆引擎，融合四大顶尖后端（Mem0、Cognee、Letta、Graphiti），通过单一接口实现并行搜索与跨源重排序；基于规范驱动开发的融合引擎，能根据工作规模自动调整流程复杂度，并通过多智能体辩论为规范提供支撑。
- **HelixTrack** —— 自由世界的 JIRA + Confluence 替代方案（Helix-Track 系列的旗舰产品）：基于 Go 微服务架构，通过统一的动作路由 API 实现 HTTP/3 服务，支持静态数据加密，并提供原生 Web/桌面/Android/iOS 客户端。

内容

### 产品级工具（vasic-digital 实用工具）
- **Catalogizer** —— 多协议、加密、可自托管的媒体资源管理系统（Go/Gin + React），对不稳定的网络存储具有高容错性，基于21个可复用子模块构建。
- **Courses-Creator** —— Markdown 转视频的 AI 课程流水线，配备 TTS 及桌面/移动/网页播放器。
- **VisionEngine** —— 计算机视觉 + 多供应商 LLM 视觉 UI 感知系统，结合导航图谱。
- **DocProcessor** · **Docs Chain** · **Herald** · **task_bridge** · **Vasic Digital 可复用模块套件** —— 质量保证功能映射、内容哈希化文档/数据库同步、自然语言通知、任务/看板同步，以及 `digital.vasic.*` 标准库集群。

### 基础设施自动化（Server Factory）
- **Mail Server Factory** —— 声明式 JSON → 全自动部署的 Docker 化邮件服务器，支持12种连接类型和25种 Linux 发行版；通过439项测试，并通过 SonarQube 门禁验证。
- **Server Factory 核心框架**、**Qemu-Utils**、**Parallels-Utils** —— 共享的自动化部署引擎及虚拟机镜像工具链。

## 编程语言与工具（快速列表）

Go · Kotlin · Kotlin Multiplatform · TypeScript · JavaScript · Python · Swift · Java · Rust · Shell · PL/pgSQL · TLA+ · Gin · gRPC · HTTP/3 · React · Angular · Electron · React Native · PostgreSQL · SQLite · SQLCipher · Redis · Neo4j · ClickHouse · Docker · Kubernetes · Prometheus · Grafana · OpenTelemetry · QEMU · GitHub Actions · Gradle · Make

## 工作经历

*自2009年起从事软件工程师工作，涵盖完整开发生命周期——规划、开发、团队领导及部署。以下完整履历均源自候选人经验证的记录（milosvasic.ru）。*

### 全职岗位

- **SDK 开发工程师 —— Harness**（harness.io），塞尔维亚贝尔格莱德 · 2020年3月 – 2024年12月
  担任公司功能标记（Feature Flag）部门 SDK 系列的首席开发工程师，专注于主流移动平台及其他领域。客户与合作伙伴包括 AWS、Google 及多家银行。
  *技术栈：Android、iOS、Flutter、React Native、TypeScript、JavaScript、Java、Kotlin、Swift、Go、Ruby。*

- **软件工程师 —— Leica Geosystems**（leica-geosystems.com），瑞士海尔布鲁格 · 2016年2月 – 2020年2月
  主要负责 Leica Geosystems 尖端3D扫描仪的 iOS 与 Android 开发，实现与硬件的实时通信、数据处理及同步。合作伙伴：Autodesk。
  *技术栈：Android、iOS、Java、Kotlin、Swift、C++。*

- **SDK 开发工程师 —— Bosch**（bosch.rs），塞尔维亚贝尔格莱德 · 2010年1月 – 2016年1月
  担任「联网车辆 SDK」项目的首席 SDK 开发工程师，实现与 OBD2 总线的实时 Bluetooth 通信，以及高性能数据处理与持久化。
  *技术栈：Android、Java、Kotlin。*

内容

### 其他工作经历

- **TN-TECH**（tn-tech.co.rs），塞尔维亚诺维萨德 · 兼职，自2017年3月起。任职于Globex Data（加拿大及瑞士）——Sekur（SekurMessenger）、SekurMail、SekurSuite——及BusRide平台。*技术：Android、Java、Kotlin、C++、Qt。*
- **Increment Loop**（incrementloop.com），塞尔维亚贝尔格莱德 · 兼职，自2023年9月起。Yuno应用程序开发。*技术：Android、Kotlin。*
- **开源项目 / 自主组织**——HelixTrack、Server Factory（Mail Server Factory、Parallels-Utils、Qemu-Utils）及Vasic Digital（Android-Toolkit、Network-Binder），详情见上文「精选项目」部分。

## 著作出版

- **《Kotlin基础》**——自主出版；最新修订版于2022年9月发布（《Kotlin基础》第三版）。亦曾为Packt出版社（英国）撰稿。

## 教育背景

- **当代信息技术理学硕士**——Singidunum大学，塞尔维亚贝尔格莱德 · 2014年。
- **信息学与计算机科学理学学士**——Singidunum大学，塞尔维亚贝尔格莱德 · 2008年。

