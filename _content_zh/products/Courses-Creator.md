---
name: Courses-Creator
slug: courses-creator
tier: vasic-util-secondary
order: 22
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - TypeScript
  - React
  - Electron
  - React Native
  - PostgreSQL
  - Python
  - LLM providers (OpenAI, Anthropic, Ollama)
  - TTS (Bark, SpeechT5)
  - MCP
  - Docker Compose
  - nginx
  - Prometheus
  - Grafana
repos:
  - https://github.com/vasic-digital/Courses-Creator
diagrams:
  - Pipeline flow (markdown → LLM enrichment → TTS + music → video assembly → publish)
  - One-backend-three-clients topology (desktop/mobile/web over shared API)
  - Deployment stack (Docker Compose services)
  - Optional-AI toggle (basic vs enhanced path by provider keys)
---

内容

**Markdown 输入，专业视频课程输出——AI 增强，多平台兼容。**

## 概要

Courses-Creator 是一款工具套件，可将 Markdown 脚本转换为由 AI 驱动的专业视频课程，具备多 LLM 内容增强（OpenAI/Anthropic/Ollama）、高质量 TTS 及背景音乐，并支持桌面端、移动端及网页播放器——全程通过 Docker 部署，配备 Prometheus/Grafana 监控。

## 简要说明

将 Markdown 转化为引人入胜的视频课程。Go 处理引擎通过多个 LLM 服务商丰富内容，生成旁白（Bark/SpeechT5 TTS）与音乐，并交付至 Electron 桌面端、React Native 移动端及 React 网页播放器，实现全面的 Docker 部署与监控。

## 详细说明

制作视频课程通常需要一整个小型工作室的工作量：编写脚本、录制旁白、采集音乐、剪辑、编码，再为学习者可能使用的每个平台开发播放器。Courses-Creator 将这一整套流程压缩为单一输入——一个 Markdown 脚本——和单一指令。其核心是一个 Go 处理器，运行完整的视频/音频流水线：通过多个 LLM 服务商（OpenAI、Anthropic 及本地 Ollama）增强文本内容，利用文本转语音引擎（Bark、SpeechT5）合成自然旁白，叠加背景音乐，并将各部分组装为成品课程视频。作者只需专注于内容与文字，系统则负责配音、配乐及制作。而课程只有在学习者能观看时才有意义，因此设计上支持多平台交付：Electron 桌面端创作应用、React Native 移动端播放器及 React 网页播放器，三者均由同一套 REST API 后台及任务系统驱动——一个后端，三个一流客户端，无需为每个平台重复开发。

关键在于，这是一套生产级基础设施，而非演示样板。后端具备 PostgreSQL 持久化存储、后台任务处理（确保长时间 TTS/视频渲染不会阻塞 API）、MCP 服务器实现（支持工具增强型优化）、Prometheus 指标监控、JWT 身份验证，以及 Nginx 反向代理——整套系统以 Docker Compose 部署，配备 Grafana/Prometheus 监控配置，可一键启动。AI 是增强层，而非依赖项：每个 LLM 服务商均为可选，流水线在无 API 密钥的情况下也能运行基本功能，而一旦提供密钥，即可激活高级增强功能。这一设计使同一工具既适用于离线笔记本电脑上的个人爱好者，也适用于接入企业首选服务商的大型机构——底层媒体流水线均经过单元测试、集成测试及端到端测试验证，而非仅凭信任。

## 我们为何开发它

手动制作课程视频耗时费力：编写、配音、配乐及剪辑各环节均需投入精力与专业工具。Courses-Creator 将这一流程压缩为由 Markdown 驱动的流水线，单一源脚本即可生成成品课程，AI 则填补了原本需人工完成的空白。

内容

## 为何这是一场变革

它将课程制作从一项需要专业技能与多种工具的复杂工艺，转变为可重复执行的软件流水线：从内容创作、AI 丰富化、旁白与音乐生成，再到多平台播放，全部整合于一个可部署的完整系统中。而其悄然无声的强大之处，在于对无 API 密钥操作的优雅降级——同一套代码库既能服务预算有限的独立创作者，也能满足与高端供应商签约的企业需求，无需中途重写任何代码。

## 创新之处

- 基于 Markdown 的视频生成流水线，支持可插拔的多 LLM 丰富化（OpenAI/Anthropic/Ollama）。
- 内置 TTS（Bark、SpeechT5）及背景音乐生成功能。
- 处理引擎内嵌 MCP 服务器实现，实现工具增强型优化。
- 一个后端服务三大一流客户端（Electron 桌面端、React Native 移动端、React 网页端）。

## 挑战与解决方案

- **大规模媒体处理**：通过 Go 流水线结合后台任务处理解决，确保长时间 TTS/视频任务不阻塞 API。
- **可选但强大的 AI**：通过将 LLM 供应商设计为可选且可插拔，实现优雅降级至基础功能。
- **多平台交付**：通过共享的 REST API 与三个专用播放器应用解决。
- **可运维性**：通过 Docker Compose 配置文件、Prometheus/Grafana 监控及内置的 JWT 认证机制解决。

## 技术栈（选择原因与实现方式）

- **Go** —— 核心处理引擎、REST API、任务调度器、流水线（代码量 972K+ 字节，主导语言）。
- **TypeScript / React** —— 网页播放器及共享 UI。
- **Electron** —— 桌面端创作应用。
- **React Native** —— 移动端播放器。
- **PostgreSQL** —— 课程/任务持久化存储。
- **LLM 供应商（OpenAI、Anthropic、Ollama）** —— 内容增强。
- **TTS（Bark、SpeechT5）** —— 旁白合成。
- **MCP 服务器** —— 引擎内的工具集成。
- **Docker Compose + nginx** —— 全栈部署与反向代理。
- **Prometheus + Grafana** —— 系统监控。

> 注：公开的 README 快速入门指南使用了占位符 `your-org` 克隆的 URL。

