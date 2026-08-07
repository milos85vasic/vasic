---
name: Mail Server Factory
slug: mail-server-factory
tier: serverfactory-tertiary
order: 29
status: production (reports 439 tests at 100% pass and a clean SonarQube gate)
license: UNVERIFIED
private: false
tech:
  - Kotlin (2.0.21)
  - Shell
  - Docker
  - QEMU
  - JSON (declarative config)
  - Gradle 8.14.3 / Java 17
  - Caffeine
  - G1GC-tuned JVM
  - Prometheus-compatible metrics
  - Sieve
repos:
  - https://github.com/Server-Factory/Mail-Server-Factory
  - https://github.com/Server-Factory/Mail-Server-Factory-Website
diagrams:
  - JSON-in → Factory engine → installed Docker mail stack (Postfix/Dovecot/TLS)
  - Connection-type fan-out (local/SSH/Docker/K8s/AWS SSM/Azure/GCP/Libvirt) to targets
  - Distribution matrix (Western/Russian/Chinese families) with unattended-install badges
  - Security layer callouts (AES-256-GCM, firewall ports, TLS/HSTS, RBAC, audit log)
---

**像高手一样运行你的邮件服务器——用 JSON 描述，部署在任何地方**

## 概述

Mail Server Factory 是一款生产级、自动化的邮件服务器配置工具。用户仅需编写简单的 JSON 配置文件，Factory 便会解析并执行目标操作系统上的所有安装与初始化操作，部署基于 Docker 的松耦合邮件服务栈，支持 12 种连接类型。

## 简介

一款 Kotlin/Shell 工具，能将 JSON 描述文件转化为完整安装、Docker 化的邮件服务器。支持 12 种连接类型（SSH、Docker、Kubernetes、AWS SSM、Azure、GCP、Libvirt 等），完整的安全框架，25 种 Linux 发行版，并通过 439 项测试验证。

## 详细说明

搭建一个真正安全的邮件服务器，是系统管理员的经典成人礼——也是最让人头疼的任务之一。Postfix、Dovecot、TLS 证书、DNS 记录、防火墙规则，以及各发行版的特殊配置，都必须精准对齐，任何一处错误都可能导致邮件被悄然退回或服务器成为开放中继。Mail Server Factory 将这一整套来之不易、极易出错的专业知识封装为软件。用户无需在陌生的操作系统上手动配置每个组件，只需用简单的 JSON 文档描述预期结果，Factory 便会读取该文档，在目标操作系统上执行所需的安装与初始化步骤，搭建基于 Docker 的邮件服务栈，且每个组件均为松耦合设计——这一架构使服务栈具备水平扩展能力，并允许单独升级或替换任一组件。此外，它刻意保持部署无关性：12 种连接类型让同一工具和同一份 JSON 文件可部署于本地机器、通过 SSH 连接的远程主机、Docker 或 Kubernetes 运行时、通过 AWS SSM / Azure 串行控制台 / GCP OS Login 管理的云实例，或通过 Libvirt 管理的虚拟机——无论指向何处，相同的声明式描述均可完成部署。它支持 25 种 Linux 发行版，涵盖西方（Ubuntu、Debian、CentOS、Fedora、AlmaLinux、Rocky、openSUSE）、俄罗斯（ALT、Astra、ROSA）及中国（openEuler、openKylin、Deepin）主流发行版家族，并通过 preseed/kickstart/cloud-init/autoyast 实现无人值守安装，结合 QEMU 的虚拟机自动化测试。企业级功能全面：AES-256-GCM 加密、强制密码与 SSH 密钥策略、邮件端口（25/587/465/993/995）的自动防火墙配置、TLS/SSL 证书验证与 HSTS、审计日志及 RBAC。运维特性包括 JVM 调优（G1GC）、Caffeine 缓存、连接池、兼容 Prometheus 的指标监控、结构化日志、配置热重载及密钥管理。项目拥有 439 项测试，通过率 100%，并通过 SonarQube 质量门禁。它是 Server-Factory 组织的旗舰项目。

## 我们为何构建它

搭建一个安全、可用于生产环境的邮件服务器向来以易出错且高度依赖操作系统而闻名。Mail Server Factory 将这份专业知识凝聚于一个声明式的 JSON 模型与执行引擎之中，从而能在任何支持的目标系统上复现一套正确、安全且基于 Docker 的邮件服务栈，无需手动逐步操作。

## 它为何改变游戏规则

它将邮件服务器的部署从一项需要专家耗时数日、必须精准无误的艰巨任务，简化为编写配置文件的简单操作——并使这一操作能够跨越 12 种连接类型和 25 种 Linux 发行版，且默认集成企业级安全防护。最终结果可复现且*可验证*：相同的 JSON 配置每次都能生成相同的安全服务栈，而项目通过 439 项测试（全部通过）及干净的 SonarQube 检查点，确保执行引擎本身接受严格审核，而非仅凭声誉取信。

## 创新之处

- **声明式 JSON** → 在目标操作系统上解释执行安装/初始化。
- **12 种连接类型**（本地、SSH、Docker、Kubernetes、AWS SSM、Azure、GCP、Libvirt 等）集成于同一工具。
- **支持 25 种发行版**，提供无人值守安装（preseed/kickstart/cloud-init/autoyast）及 QEMU 自动化。
- **松耦合 Docker 化服务栈**，支持独立扩展与升级。

## 挑战与解决方案

- **操作系统/发行版差异性**：通过针对各发行版的配置模板、无人值守安装配置及基于 QEMU 的跨发行版测试解决。
- **覆盖多种部署目标**：通过 12 种可插拔连接类型，统一于同一安装引擎解决。
- **默认安全防护**：通过 AES-256-GCM 加密、强制密钥/密码策略、自动防火墙规则及 TLS/HSTS 解决。
- **可信度验证**：通过 439 项测试套件（100% 通过）及干净的 SonarQube 检查点解决。

## 技术栈（原因与实现）

- **Kotlin** —— 工厂引擎与安装步骤逻辑（179K 字节；Kotlin 2.0.21 版）。
- **Shell** —— 部署脚本、ISO/QEMU 管理器及操作系统自动化（体量最大）。
- **Docker** —— 已部署的松耦合邮件服务栈运行时。
- **QEMU** —— 用于跨发行版安装与测试的虚拟机自动化。
- **JSON** —— 面向用户的声明式配置格式。
- **Gradle 8.14.3 / Java 17** —— 构建工具链。
- **Caffeine** —— 多区域缓存；**G1GC 调优 JVM** 以提升性能。
- **Prometheus 兼容指标** —— 监控；Grafana/ELK 就绪。
- **Sieve** —— 邮件过滤规则（在语言统计中占比较小）。

> 注：GitHub 标记该仓库为 Server-Factory 组织下的一个分支。其历史早于 AI 产品线，定位为成熟的 DevOps/部署旗舰项目，而非 AI 工具。

