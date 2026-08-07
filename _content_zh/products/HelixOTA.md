---
name: HelixOTA
slug: helixota
tier: helix-primary
order: 9
status: in-development
license: Apache-2.0
private: false
tech:
  - Go
  - Gin
  - Kotlin / KMP
  - HTTP/3 QUIC
  - PostgreSQL
  - MinIO / S3
  - AOSP update_engine + AVB/dm-verity
  - React
  - OpenTelemetry
  - Prometheus / Grafana
repos:
  - https://github.com/HelixDevelopment/helix_ota
diagrams:
  - Three-planes architecture — control plane (Go/Gin) ↔ data plane (PostgreSQL/MinIO/OTel) ↔ device (KMP agent + update_engine), with the two extractable seams highlighted.
  - Staged rollout funnel — 5% → 10% → 30% → … → 100% with halt/advance thresholds.
  - Zero-brick A/B slot swap — slot A active, slot B updated + verified, automatic rollback on boot failure.
  - Six ota-* submodules as decoupled building blocks feeding the umbrella system.
---

# HelixOTA

**通用、解耦的无线空中更新系统——零砖化设计**

## 概要

Helix OTA 是一套通用、深度解耦的无线空中（OTA）更新系统：包含 Go 控制平面及针对各操作系统的客户端代理，旨在为从单板设备到数百万台设备的规模化部署提供安全、分阶段的固件/应用更新。其首个目标平台为搭载 Android 15 的 Orange Pi 5 Max。

## 简要说明

Helix OTA 是一套通用的无线空中更新系统——由 Go 控制平面及针对各操作系统的客户端代理组成——专为实现零系统损坏、验证上传及精细化分阶段推送而设计。其首个目标平台为 Orange Pi 5 Max 上的 Android 15，后续计划支持 Linux/Windows 适配器。

## 详细说明

Helix OTA 是一套通用、泛化且深度解耦的无线空中（OTA）更新系统，其核心承诺只有一个：更新绝不能将正常运行的设备变成"砖头"。该系统由 Go 服务器**控制平面**、针对各操作系统的客户端**SDK/代理**及**管理仪表盘**组成，并通过可插拔的操作系统适配器（而非针对每个平台重新构建）从底层设计为可嵌入*任何*操作系统。首个交付目标为 Orange Pi 5 Max 上的 Android 15（所有变体），其构建流水线会生成刷机镜像及经过验证的 OTA `.zip` 文件，并附带强制性哈希校验文件，确保任何更新包在部署前均有可验证的指纹；Linux、Windows 及其他操作系统则通过同一适配器接口纳入路线图，仅需添加适配器而无需重写系统。

该设计围绕运营商明确的硬性保障展开，并将其视为不可动摇的架构不变量：零系统损坏、每个更新包在部署前的强制验证、精细化推送（全量或分阶段推送，比例可设为5/10/30…100%，并支持暂停与继续控制）、全面的设备群监控，以及从实验室单板设备到现场数百万台设备的线性扩展能力。其锁定架构将设备端原生的 Android A/B 更新（基于 AOSP `update_engine`，结合 AVB/dm-verity 及自动启动失败回滚）与定制的解耦 Go 控制平面相结合，确保安全性同时存在于硬件启动路径与服务器端，而非依赖单一脆弱层。系统刻意保留了两个可抽取的接口：一个是操作系统适配器接口，承载真正的通用性；另一个是推送引擎接口，使分阶段推送策略与操作系统无关。整个系统被解构为六个独立版本化的公开 `ota-*` 子模块——可复用的构建模块而非单体架构。

Helix OTA 目前处于规范/研究及测试覆盖度构建阶段；代码仓库包含权威设计文档、文档导出流水线及子模块脚手架，并根据其"反虚假宣传"的治理原则明确指出：完整的生产级服务器及代理尚未完成。当前发布的仅为设计蓝图及其脚手架，并如实标注其状态。

内容

## 我们为何构建它

OTA 通常针对每种设备和操作系统重新设计，而一次糟糕的更新可能导致整个设备群组瘫痪。Helix OTA 的诞生，是为了打造一个通用且安全优先的更新系统，任何操作系统均可通过适配器接入，且回滚与验证机制内嵌于架构之中，而非事后补救。

## 它为何改变游戏规则

它拒绝将"不让设备变砖"和"分阶段、可观测地推送更新"视为依赖负载稳定性的尽力而为功能——这些是架构层面的不变性原则，深植于启动路径与控制平面之中。同时，通过将推送引擎与操作系统层设计为可替换的接缝而非硬编码假设，同一套控制平面既能驱动当下的 Android，也能随时通过添加适配器支持其他操作系统——无需分叉、重写或重新构建已信赖的安全保障。

## 创新之处

- **两大可抽取接缝**：操作系统适配器接缝与操作系统无关的推送引擎接缝，将"通用性"从营销口号转化为代码库的结构性特征。
- **纵深防御安全**：设备端原生 A/B（`update_engine`）+ AVB/dm-verity + 自动启动失败回滚，叠加服务器端制品验证——更新必须通过多重独立关卡才能持久化。
- **目录优先、解耦设计**：分解为六个可独立版本化的 `ota-*` 子模块，支持按需取用，无需全盘接纳单体架构。
- **HTTP/3（QUIC）主传输协议**：自动回退至 HTTP/2，并协商 Brotli/gzip 压缩，实现现代化低延迟交付，优雅降级而非直接失败。
- **反虚假工程**：设计与状态明确标注为规范阶段，未实现的功能绝不宣称为已交付——诚实被视为工程核心价值，而非脚注中的免责声明。

## 最大技术挑战及解决方案

- **确保糟糕更新绝不导致设备变砖**——OTA 面临的最严苛承诺。通过强制采用设备端原生 Android A/B 解决：`update_engine` 在非活动分区写入更新，同时保持活动分区运行；AVB/dm-verity 通过密码学验证启动链；若新分区启动失败，设备自动回滚——所有机制均由强制性部署前制品验证兜底，确保损坏的更新包在离开服务器前即被拦截。
- **一套系统，多种操作系统**——通过拒绝将 Android 假设内嵌于核心解决。可插拔的操作系统适配器接缝隔离平台特性，操作系统无关的推送引擎接缝保持推送逻辑的可移植性，两者均作为独立子模块设计，新增操作系统支持仅需添加模块，无需对整体架构动刀。
- **分阶段、可中止的推送**——通过专用推送引擎解决，该引擎基于百分比队列设定成功/错误阈值，并提供明确的中止/推进控制，刻意与 HTTP 解耦，使同一引擎能独立于传输协议驱动推送活动。

内容

## 技术栈

- **Go + Gin** —— 选用此组合因其并发模型及精简部署占用；驱动控制平面、推送引擎及工件验证器，对外暴露 REST `/api/v1` 主接口。
- **Kotlin/KMP** —— 选用该组合以便设备端 Android OTA 代理能跨目标共享逻辑；全权负责设备端完整轮询/下载/验证/应用/上报流程。
- **HTTP/3（QUIC）→ HTTP/2** —— QUIC 作为主传输协议，针对高延迟、不稳定的移动网络链路提供低延迟、高弹性的传输能力，并自动回退至 HTTP/2 确保无设备掉队；**Brotli/gzip** 按请求协商压缩负载。
- **PostgreSQL** —— 选用该数据库以确保设备注册表、推送活动及遥测数据间的关系完整性，此处车队状态的准确性重于原始写入速度。
- **MinIO / S3** —— 选用为工件二进制存储方案，使大型固件镜像存储于通用对象存储中，与关系型数据层解耦。
- **AOSP `update_engine` + AVB/dm-verity + `boot_control`** —— 选用此组合因复用 Android 自身久经考验的虚拟 A/B 及安全启动机制，较自研更新器更为安全可靠；用于驱动设备端分区切换及启动加密验证。
- **React** —— 选用为管理面板，运维人员可在此登录、上传工件、推送更新并实时监控车队健康状态。
- **OpenTelemetry + Prometheus/Grafana** —— 选用为厂商中立的监测工具；确保推送流程每一环节均可通过指标与仪表盘实时观测，而非依赖推测。

## 状态与诚信说明

- **状态：开发中。** 依据项目自身的"反虚假治理"原则，**目前尚无可用的生产服务器或代理**——当前处于规格/研究及测试覆盖率构建阶段。代码库包含权威设计文档、文档导出流水线及子模块脚手架。
- 六个公开可复用子模块（`ota-protocol`、`ota-artifact-validator`、`ota-rollout-engine`、`ota-update-engine-bridge`、`ota-android-agent`、`ota-telemetry-schema`）位于 `github.com/HelixDevelopment/` 下。
- 代码库中的测试覆盖率及延迟数据均为项目自行记录的阶段性结果，未经独立验证。README 中引用的 HelixConstitution 条款编号**未经核实**。
- **许可证：Apache-2.0。**

**优先级别：** Helix-主优先。

