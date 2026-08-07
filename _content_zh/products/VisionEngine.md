---
name: VisionEngine
slug: visionengine
tier: vasic-util-secondary
order: 23
status: active
license: UNVERIFIED
private: false
tech:
  - Go (1.25+)
  - GoCV / OpenCV (build-tag-gated)
  - LLM vision providers (GPT-4o, Claude, Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama)
  - Graph algorithms (BFS)
  - DOT / JSON / Mermaid exporters
  - i18n Translator seam
repos:
  - https://github.com/HelixDevelopment/VisionEngine
  - https://github.com/vasic-digital/VisionEngine
diagrams:
  - Four-layer stack (Analyzer / NavigationGraph / LLM Vision / Config)
  - Navigation graph rendered (Mermaid) with BFS path highlighted
  - Vision fallback chain across providers
  - Build-tag split (default stub build vs -tags vision OpenCV build)
---

**像用户一样观察 UI —— 结合计算机视觉与 LLM 视觉进行分析与导航**

## 概要

VisionEngine 是一个解耦的 Go 工具包，融合了经典计算机视觉与基于 LLM 的视觉技术，用于分析用户界面、检测 UI 元素及视觉问题，并构建应用屏幕转换的导航图谱。其多后端视觉提供程序可插拔，且 OpenCV 依赖通过构建标签隔离。

## 简要说明

一个可复用的 Go 模块，用于 UI 分析与导航图谱构建。提供分析层（UI 元素、屏幕差异、视觉问题）、带 BFS 路径查找的导航图谱（支持 DOT/JSON/Mermaid 导出），以及针对 GPT-4o、Claude、Gemini、Qwen-VL 等的 LLM 视觉适配器。

## 详细说明

大多数 UI 自动化测试实际上是"盲目"的。它们依赖无障碍树和 DOM 选择器——即机器眼中的界面——却忽略了人类真正感知的一切：按钮是否可见渲染、布局是否崩溃、跳转后的屏幕是否符合预期。VisionEngine 弥合了这一鸿沟，赋予自动化真正的感知能力，使其能像人类一样观察并理解 UI。该工具包由四个协同层次构成，从原始像素逐步构建至整个应用的理解：

**分析器（Analyzer）** 定义了稳定的契约——包括接口（`Analyzer`、`VideoProcessor`）和值类型（`UIElement`、`ScreenAnalysis`、`ScreenDiff`、`Rect`、`Size`、`TextRegion`、`VisualIssue`、`ScreenIdentity`、`Action`、`KeyFrame`），并提供 `StubAnalyzer` 参考实现。用户可基于这一不变的契约检测元素、比对屏幕差异并发现视觉问题。

**导航图谱（NavigationGraph）** 将视角从单一屏幕扩展至整个应用，将其建模为带有 BFS 路径查找的有向屏幕转换图，并支持三种导出后端（DOT、JSON、Mermaid）。这使自动化不仅能"看见"单个屏幕，还能规划通往任意目标的路径。同时，工具包内置压力测试、自动化测试、集成测试及安全测试套件，验证其有效性。

**LLM 视觉层** 增强了现代多模态推理能力：通过 `VisionProvider` 接口，集成了 OpenAI（GPT-4o）、Anthropic（Claude）、Gemini、Qwen-VL、Kimi、StepGUI、Astica 及 Ollama 等适配器。这些适配器通过 `FallbackChain` 组合，确保在某个提供程序失效、限流或能力不足时，能优雅降级至下一个，避免拖垮整个运行流程。

**配置层** 负责环境变量加载与验证，所有面向用户的错误信息均通过 `i18n.Translator` 处理。

让这一切真正可落地的关键在于：重型原生依赖是可选的。OpenCV 绑定通过构建标签 `-tags vision` 隔离，默认构建版本仅提供占位实现。这意味着整个模块可在任何 Go 1.25+ 环境下编译、测试和运行，无需 OpenCV 工具链，仅在用户明确选择时才引入原生依赖。这一设计使 VisionEngine 能轻松集成至普通 CI 环境，无需定制镜像。

完全遵循解耦原则（CONST-051(B)），VisionEngine 以同代码库子模块的形式被集成（如 HelixQA），为基于证据的 UI 测试提供了一双真正的"眼睛"。

## 为何构建

仅依赖无障碍树或选择器的 UI 自动化测试，无法捕捉用户实际看到的内容。VisionEngine 增加了真正的视觉理解能力——元素检测、屏幕对比以及 LLM 视觉推理，并提供可导航的应用界面地图，使自动化既能感知 UI，又能在其中规划路径。

## 为何是颠覆性变革

它将两种通常互不兼容的方法——快速、确定性的经典计算机视觉与灵活、语义化的 LLM 视觉——整合于同一接口之下，并通过回退链机制，让用户无需取舍，即可同时获得前者的精准与后者的推理能力。此外，通过严格将 OpenCV 设为可选项，它消除了通常与之相伴的性能代价：任何 Go 项目均可获得真正的 UI 感知能力，而无需在构建中引入原生视觉工具链。

## 创新之处

- **双重感知**：经典计算机视觉（OpenCV/GoCV）与多提供商 LLM 视觉，配备回退链。
- **导航图谱**：支持广度优先搜索（BFS）路径规划，并可导出 DOT/JSON/Mermaid 格式。
- **构建标签门控 OpenCV**：通过构建标签控制，确保模块在无原生依赖的情况下仍可构建与测试。
- **完全解耦、国际化接缝、代码库统一的子模块**（由 HelixQA 使用）。

## 挑战与解决方案

- **原生依赖冲突**：通过 `-tags vision` 标签门控及默认存根解决，确保无 OpenCV 的 CI/主机环境仍可正常构建与测试。
- **视觉提供商不稳定**：通过 `VisionProvider` 接口与 `FallbackChain` 组合器解决。
- **复杂应用流程映射**：通过有向导航图谱、BFS 路径规划及多格式导出解决。
- **耦合问题**：通过 CONST-051(B) 解耦方案及国际化翻译层解决。

## 技术栈（选择与实现）

- **Go（1.25+）**：模块核心及全部四层架构。
- **GoCV / OpenCV**：经典计算机视觉，通过构建标签门控。
- **LLM 视觉提供商（GPT-4o、Claude、Gemini、Qwen-VL、Kimi、StepGUI、Astica、Ollama）**：通过适配器实现多模态 UI 推理。
- **图算法（BFS）**：导航路径规划。
- **DOT / JSON / Mermaid 导出器**：导航图谱可视化。
- **国际化翻译层**：解耦用户界面字符串。

