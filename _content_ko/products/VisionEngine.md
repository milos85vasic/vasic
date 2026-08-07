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

**사용자처럼 UI를 바라보세요 — 컴퓨터 비전과 LLM 비전을 결합한 분석 및 탐색 도구**

## 요약

VisionEngine는 고전적인 컴퓨터 비전과 LLM 기반 비전을 결합한 탈중앙화 Go 툴킷으로, 사용자 인터페이스를 분석하고 UI 요소 및 시각적 문제를 감지하며 앱 화면 전환의 내비게이션 그래프를 구축합니다. 플러그형 멀티 프로바이더 비전 백엔드와 OpenCV는 빌드 태그로 제어됩니다.

## 간략 설명

UI 분석 및 내비게이션 그래프 구축을 위한 재사용 가능한 Go 모듈입니다. 분석 레이어(UI 요소, 화면 차이, 시각적 문제), BFS 경로 탐색과 DOT/JSON/Mermaid 내보내기를 지원하는 내비게이션 그래프, 그리고 GPT-4o, Claude, Gemini, Qwen-VL 등 다양한 LLM 비전 어댑터를 제공합니다.

## 상세 설명

대부분의 UI 테스트 자동화는 사실상 눈이 멀어 있습니다. 접근성 트리와 DOM 선택자를 활용하지만, 이는 기계가 인식하는 인터페이스에 불과하며 실제 사용자가 경험하는 요소—버튼이 제대로 렌더링되었는지, 레이아웃이 깨졌는지, 예상한 화면으로 이동했는지—는 놓치기 일쑤입니다. VisionEngine는 이러한 격차를 해소합니다. 자동화에 진정한 인식 능력을 부여해, 사람이 UI를 바라보듯 분석하고 추론할 수 있도록 합니다. 이 모듈은 원시 픽셀부터 전체 앱 이해까지 네 개의 협력 레이어로 구성됩니다.

**Analyzer**는 안정적인 계약을 정의합니다. 인터페이스(`Analyzer`, `VideoProcessor`)와 값 유형(`UIElement`, `ScreenAnalysis`, `ScreenDiff`, `Rect`, `Size`, `TextRegion`, `VisualIssue`, `ScreenIdentity`, `Action`, `KeyFrame`)을 제공하며, `StubAnalyzer` 참조 구현체를 포함합니다. 이를 통해 사용자는 요소 감지, 화면 비교, 시각적 문제 발견을 계약에 기반해 안정적으로 수행할 수 있습니다.

**NavigationGraph**는 단일 화면에서 전체 애플리케이션으로 시야를 확장합니다. 화면 전환을 방향 그래프로 모델링하고 BFS 경로 탐색을 지원하며, 세 가지 내보내기 백엔드(DOT, JSON, Mermaid)를 제공합니다. 이를 통해 자동화는 화면을 인식할 뿐만 아니라 다른 화면으로의 경로를 계획할 수 있으며, 스트레스, 자동화, 통합, 보안 테스트 스위트를 통해 검증됩니다.

**LLM Vision** 레이어는 현대적인 멀티모달 추론 기능을 추가합니다. `VisionProvider` 인터페이스와 GPT-4o(OpenAI), Claude(Anthropic), Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama 등 다양한 어댑터를 지원하며, `FallbackChain`을 통해 실패하거나 속도 제한이 걸린 프로바이더가 다음 프로바이더로 우아하게 대체됩니다.

**Configuration** 레이어는 환경 변수 로딩 및 검증을 처리하며, 모든 사용자 대상 오류 메시지는 `i18n.Translator`를 통해 전달됩니다.

이 모든 것을 실제로 채택 가능하게 만드는 결정적인 요소는 무거운 네이티브 종속성이 선택 사항이라는 점입니다. OpenCV 바인딩은 `-tags vision` 빌드 태그로 제어되며, 기본 빌드에는 스텁이 포함됩니다. 따라서 Go 1.25+ 호스트에서 OpenCV 툴체인 없이도 전체 모듈이 컴파일, 테스트, 실행되며, 네이티브 스택은 사용자가 명시적으로 선택할 때만 로드됩니다. 이는 VisionEngine가 맞춤형 이미지 없이 일반 CI 러너에 바로 적용될 수 있게 합니다. CONST-051(B) 규정에 따른 완전한 탈중앙화 모듈로서, 특히 HelixQA와 같은 소비자에 의해 동등한 코드베이스 하위 모듈로 통합되어, 증거 기반 UI 테스트에 진정한 시각을 제공합니다.

콘텐츠

## 왜 만들었는가

접근성 트리나 선택자에만 의존하는 UI 테스트 자동화는 사용자가 실제로 보는 화면을 놓치게 됩니다. VisionEngine는 실제 시각적 이해를 더합니다—요소 감지, 화면 비교, LLM 비전 추론—그리고 앱 화면의 탐색 가능한 맵을 제공하여 자동화가 UI를 인식하고 경로를 탐색할 수 있도록 합니다.

## 왜 혁신적인가

빠르고 결정론적인 고전 컴퓨터 비전과 유연하고 의미론적인 LLM 비전을 단일한 인터페이스에 통합하고, 폴백 체인을 통해 두 가지 접근 방식의 장점을 모두 활용할 수 있게 합니다. 사용자는 한 가지를 선택할 필요 없이 하나의 정밀성과 다른 하나의 추론 능력을 동시에 얻을 수 있습니다. 또한 OpenCV를 엄격히 선택 사항으로 유지함으로써, 그 강력한 기능을 활용하는 데 따르는 일반적인 부담을 제거합니다. 어떤 Go 프로젝트라도 네이티브 비전 툴체인을 빌드에 포함시키지 않고도 실제 UI 인식을 얻을 수 있습니다.

## 혁신적인 점

- 이중 인식: 고전 CV(OpenCV/GoCV)와 다중 제공자 LLM 비전, 폴백 체인 지원.
- BFS 경로 탐색과 DOT/JSON/Mermaid 내보내기를 지원하는 내비게이션 그래프.
- 빌드 태그로 제어되는 OpenCV 지원으로 네이티브 종속성 없이도 모듈을 빌드하고 테스트할 수 있음.
- 완전히 분리된 i18n 인터페이스와 동일 코드베이스의 하위 모듈(HelixQA에서 사용).

## 도전 과제와 해결 방안

- **무거운 네이티브 종속성 문제:** `-tags vision` 게이팅과 기본 스텁을 통해 OpenCV가 없는 CI/호스트에서도 빌드 및 테스트 가능.
- **비전 제공자 불안정성:** `VisionProvider` 인터페이스와 `FallbackChain` 컴포저로 해결.
- **복잡한 앱 흐름 매핑:** 방향성 내비게이션 그래프, BFS 경로 탐색, 다중 형식 내보내기로 해결.
- **결합도 문제:** CONST-051(B) 분리 원칙과 i18n 번역기 인터페이스로 해결.

## 기술 스택 (이유와 방법)

- **Go (1.25+)** — 모듈 코어 및 네 가지 레이어.
- **GoCV / OpenCV** — 고전 컴퓨터 비전, 빌드 태그로 제어됨.
- **LLM 비전 제공자(GPT-4o, Claude, Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama)** — 어댑터를 통한 멀티모달 UI 추론.
- **그래프 알고리즘(BFS)** — 내비게이션 경로 탐색.
- **DOT / JSON / Mermaid 내보내기** — 내비게이션 그래프 시각화.
- **i18n 번역기** — 분리된 사용자 대상 문자열.

