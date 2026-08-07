---
name: task_bridge
slug: task-bridge
tier: vasic-util-secondary
order: 26
status: P1 scaffold (interfaces & decoupling boundary in place; sync logic and live ClickUp calls not yet implemented)
license: UNVERIFIED
private: false
tech:
  - Go
  - SQLite (workable-items SSoT)
  - raksul/go-clickup (MIT dependency)
  - HMAC-SHA256 webhook verification
  - cron + webhooks
  - pkg/config runtime injection boundary
repos:
  - https://github.com/vasic-digital/task_bridge
diagrams:
  - Three-way sync triangle (SQLite SSoT ↔ tracker docs ↔ ClickUp)
  - Decoupling boundary (consumer injects creds/IDs → generic engine)
  - Conflict resolution flow (last-edit-wins outcomes)
  - Daemon architecture (webhook receiver + cron reconcile)
---

**任务看板与单一事实源，双向完美同步**

## 概述

task_bridge 是 Go 中的一个通用、解耦的双向任务/看板同步引擎。它通过确定性的「最后编辑优先」机制、先执行「干运行」测试、确保数据绝不损坏的语义，将项目的可执行项（SQLite）单一事实源与追踪文档及远程看板（首个目标平台为 ClickUp；Jira/Linear 计划中）保持同步。

## 简要说明

一个与项目无关的 Go 子模块，双向同步 SQLite 可执行项单一事实源 ↔ 追踪文档 ↔ 远程看板（首选 ClickUp）。采用确定性「最后编辑优先」机制、先执行「干运行」测试、HMAC 验证的 Webhook；所有凭证与 ID 均由使用方在运行时注入。

## 详细说明

每个团队最终都会维护同一项工作的两本账：一本是真实状态——代码、文档、内部数据库；另一本则是管理者关注的看板，如 ClickUp。两者在任意一方被修改的瞬间便开始偏离，而手动调和它们正是那种枯燥易错、无人可靠完成的苦差事。task_bridge 旨在消除这一鸿沟，将三种表现形式视为一个需严格同步的系统：项目的**可执行项（SQLite）单一事实源**、其**追踪文档**以及**远程看板**（首个支持的看板为 ClickUp，未来计划接入 Jira 和 Linear）。同步过程采用确定性机制（最后编辑优先）、先执行「干运行」测试，并以一项不可动摇的承诺为核心：绝不损坏或丢失数据，绝不让任何一方悄然过时。在一个粗心的同步操作可能覆盖一周工作成果的领域，这种安全性设计才是关键所在。

从架构上看，它是一个严格遵循解耦协议（§11.4.28）的子模块，供其他项目调用，且完全与项目无关：不内置任何项目特定值，所有凭证、看板/文件夹 ID、项键字段及数据库路径均由使用方在运行时通过 `pkg/config.Config` 注入。模块分层清晰：包含 CLI（`reconcile`/`push`/`pull`/`resolve`/`status`/`conflicts`/`init`）及长期运行的守护进程（Webhook 接收器 + 定时同步）；基于 MIT 许可的 `raksul/go-clickup` 的轻量客户端封装；通过实时 API 探测（而非 URL 语法猜测）将看板/文件夹 URL 解析为 ID 的解析器；本地可执行项与远程任务字段的映射器；明确冲突处理结果的「最后编辑优先」同步引擎；以及验证 `X-Signature` HMAC-SHA256 的 Webhook 接收器。它对成熟度坦诚以待：当前为 P1 阶段框架——布局、接口、入口及解耦边界均已就绪，但同步逻辑与实时 ClickUp 调用尚未实现（所有占位符均返回明确的「未实现」错误，遵循「无伪造」规则）。

## 为何开发

团队将工作的「真实」状态保存在代码/文档中，而管理者则依赖 ClickUp 等看板——两者不断偏离。task_bridge 将它们整合为一个系统，通过确定性且安全的同步，确保双方始终保持一致，不再出现过时或错误的情况。

内容

## 为何是颠覆性变革

双向看板同步通常是一次性的硬编码集成，每个团队都在重复造轮子且效果不佳。task_bridge 将其重新定义为可复用、注入凭证的库，内置严格的数据安全保障——先模拟运行、确定性「最后编辑优先」、HMAC 验证事件——任何项目只需注入配置即可实现可靠的看板集成，无需再编写与内部逻辑紧密耦合的脆弱连接器。

## 创新之处

- 三向双向同步：SQLite 单一事实源 ↔ 跟踪文档 ↔ 远程看板。
- 完全解耦（§11.4.28）：零项目硬编码，全部在运行时注入。
- 实时 API URL→ID 解析，摒弃脆弱的 URL 语法解析。
- HMAC-SHA256 验证的 Webhook 实时事件接收。

## 挑战与解决方案

- **三方数据安全**：通过确定性「最后编辑优先」、先模拟运行及明确冲突处理方案解决。
- **解耦下的可复用性**：通过 `pkg/config` 注入边界实现（无项目特定代码）。
- **可靠的看板识别**：通过实时 API 探测将 URL 解析为 ID 解决。
- **透明的脚手架**：未实现的占位代码明确返回「未实现」错误（不使用假数据）。

## 技术栈（选择与实现）

- **Go** —— 引擎、CLI（`cmd/task_bridge`）及守护进程（`cmd/task_bridged`）。
- **SQLite** —— 可执行项的单一事实源。
- **`raksul/go-clickup`（MIT 协议）** —— ClickUp 传输封装。
- **HMAC-SHA256** —— Webhook 签名验证。
- **cron + Webhook** —— 守护进程协调 + 实时事件接收。
- **`pkg/config`** —— 运行时凭证/ID 注入边界。

> 状态说明：此为 **P1 阶段脚手架** —— 同步逻辑尚未实现，切勿宣称为已交付功能。

