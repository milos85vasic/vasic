---
name: Docs Chain
slug: docs-chain
tier: vasic-util-secondary
order: 25
status: active (Phases 1–5 implemented & GREEN; Phases 6–7 PLANNED / operator-gated)
license: UNVERIFIED
private: false
tech:
  - Go
  - DAG + Kahn topological sort
  - SQLite (pure-Go modernc)
  - fsnotify
  - YAML config
  - exec transforms (Markdown → HTML/PDF/DOCX)
repos:
  - https://github.com/vasic-digital/docs_chain
diagrams:
  - DAG of chain members (Markdown ↔ HTML/PDF/DOCX ↔ SQLite) with a change propagating
  - Content-hash vs mtime comparison
  - Atomic-commit sequence (temp write → rename / SQLite txn)
  - Phase status board (implemented vs planned)
---

**任何被追踪的文档均无法失去同步——基于内容哈希、双向、原子化的同步机制。**

## 概述

Docs Chain 是一款通用的、基于 Go 实现的双向文档与数据库依赖传播引擎。当注册链中的任一成员发生变化——无论是 Markdown 源文件、HTML/PDF/DOCX 导出文件，还是 SQLite 数据库——系统均会通过内容哈希检测变更，并以原子化方式将其传播至所有关联成员。

## 简要说明

一款基于 Go 的同步引擎，确保文档与数据库始终保持一致。它采用 Salsa 风格的内容哈希增量重算机制，基于 DAG（Kahn 拓扑排序、提前终止、双向同步边、原子重命名 + SQLite 事务提交），在任一关联文件变动时自动重新生成导出内容。

## 详细说明

Docs Chain 的诞生，源于你第 N+1 次编写那种脆弱的"Markdown 变动时重新生成 PDF"脚本后的顿悟。它彻底取代了这一类手工拼凑的同步胶水代码，转而提供一个真正的引擎。它将项目中的文档与数据库视为链式结构的成员，当任一成员变动时，系统会将变更沿所有声明方向传播至每一个关联成员，并以原子化方式重新生成和导出，确保任何被追踪的文件永不失去同步。其设计严谨性直接借鉴自增量构建系统而非脚本逻辑：**变更检测基于内容哈希而非修改时间**，因此 `touch` 命令不会触发任何操作，而单字节修改则会精准触发必要的重建——无误报，无遗漏。用一行话精确概括：它是基于 DAG 的 Salsa 风格内容哈希增量重算系统，采用 Kahn 拓扑排序、提前终止以剪枝未变子树、显式声明的双向 `sync` 权威边，以及原子重命名 + SQLite 事务提交机制，确保即使在传播过程中崩溃，也绝不会留下半成品导出文件。该引擎以 `vasic-digital` 子模块形式发布，并作为 HelixConstitution 子模块的核心组件被集成，因此任何采用该框架的项目均可开箱即用 Docs Chain，并通过上下文特定的 YAML 注册自定义链。实现状态遵循框架 §11.4.6 的透明原则：阶段 1–4（核心 DAG + 哈希、节点适配器/转换器、原子化传播协调器、配置驱动的多上下文 CLI，包含 `sync`/`verify`/`doctor`/`graph`/`watch`）已实现并测试通过；阶段 4b 增加通用双向 `md-to-sqlite`/`sqlite-to-md` 内置功能（纯 Go 实现、行级漂移检测、字节稳定的往返转换）及 `colorize-html` 内置功能；阶段 5 的全面端到端真实二进制测试已实现并通过。阶段 6–7（框架分发、ATMOSphere 集成）仍处于规划阶段，且需操作员手动启用。Herald 是首个实际下游用户，同步包含 66 份多格式文档的语料库，验证过程无误。

## 为何构建它

文档、导出内容与数据库在手动维护或脆弱脚本的管理下，瞬间便会失去同步。Docs Chain 将同步过程机械化、内容哈希精确化且原子化，确保链中任意位置的变更都能安全、准确地更新所有下游（及上游）内容。

内容

## 为何是颠覆性变革

它将编译器和构建系统作者视为理所当然的严格保障机制——基于内容哈希的依赖图、最小化重新计算、原子提交——应用于文档和数据库领域，而这一领域长期以来依赖定时任务和良好愿望勉力维持。真正的双向同步意味着源与导出之间的关系在两个方向上均受强制约束，因此"文档过时"和"导出内容与源不符"不再是反复出现的错误，而是引擎无法容许的状态。

## 创新之处

- 基于内容哈希（而非修改时间）的 DAG 增量重算，支持提前终止。
- 双向、明确权威的同步链路（文档 ↔ 导出 ↔ SQLite）。
- 原子重命名 + SQLite 事务提交，确保崩溃安全的传播。
- 纯 Go 的 `md-to-sqlite`/`sqlite-to-md` 往返转换，支持行级偏差检测。

## 挑战与解决方案

- **误触重建**：通过内容哈希检测而非时间戳解决。
- **部分/损坏更新**：通过原子重命名和 SQLite 事务解决。
- **多成员顺序正确性**：通过 Kahn 拓扑排序 + 提前终止解决。
- **能力真实报告**：通过标记每个阶段为"已实现"或"计划中"（依据 §11.4.6）解决。

## 技术栈（为何选择及如何实现）

- **Go** —— 整个引擎（`internal/hash`、`graph`、`adapter`、`orchestrator`、`config`、`state`、`runner`、`cmd/docs_chain`）。
- **DAG + Kahn 拓扑排序** —— 依赖顺序排列，支持提前终止。
- **SQLite（纯 Go modernc）** —— 数据库成员及事务性提交。
- **fsnotify** —— `watch` 守护进程，实现实时传播。
- **YAML 配置** —— 每个上下文的链路注册。
- **exec: 转换** —— 可插拔的 Markdown→HTML/PDF/DOCX 生成。

> 路线图透明度：阶段 6–7（宪法分发、ATMOSphere 集成）为"计划中"/运营商控制 —— 尚未发布。

