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

**마크다운 입력, 프로급 비디오 강의 출력 — AI 강화, 멀티 플랫폼 지원**

## 요약

Courses-Creator는 마크다운 스크립트를 AI 기반의 강화 기능을 갖춘 프로급 비디오 강의로 변환하는 툴킷입니다. 다중 LLM 콘텐츠 강화(OpenAI/Anthropic/Ollama), 고품질 TTS 및 배경 음악, 데스크톱/모바일/웹 플레이어 지원 — 모든 기능이 Docker 배포 및 Prometheus/Grafana 모니터링과 함께 제공됩니다.

## 간략 설명

마크다운을 매력적인 비디오 강의로 변환합니다. Go 처리 엔진이 다중 LLM 제공자를 통해 콘텐츠를 강화하고, 내레이션(Bark/SpeechT5 TTS)과 음악을 생성하며, Electron 데스크톱, React Native 모바일, React 웹 플레이어로 전달합니다. 또한 완전한 Docker 배포 및 모니터링 기능을 지원합니다.

## 상세 설명

비디오 강의를 제작하는 과정은 보통 작은 제작 스튜디오 수준의 작업이 필요합니다. 스크립트 작성, 내레이션 녹음, 음악 소싱, 편집, 인코딩, 그리고 학습자가 사용할 모든 플랫폼에 맞는 플레이어 개발까지 — 이 모든 단계를 거쳐야 합니다. Courses-Creator는 이 복잡한 과정을 단 하나의 입력(마크다운 스크립트)과 단 하나의 명령어로 압축합니다. 핵심에는 Go 코어 프로세서가 자리 잡고 있으며, 이는 전체 비디오/오디오 파이프라인을 실행합니다. 이 프로세서는 여러 LLM 제공자(OpenAI, Anthropic, 로컬 Ollama)를 통해 서면 콘텐츠를 강화하고, 텍스트-음성 변환 엔진(Bark, SpeechT5)을 이용해 자연스러운 내레이션을 합성하며, 배경 음악을 입히고, 완성된 강의 비디오로 조립합니다. 저자는 아이디어와 단어에만 집중하면 되고, 시스템이 음성 녹음, 음악 편곡, 제작을 담당합니다. 또한 강의가 실제로 유용하려면 사람들이 시청할 수 있어야 하므로, 배포는 멀티 플랫폼을 기본으로 설계되었습니다. Electron 데스크톱 제작 앱, React Native 모바일 플레이어, React 웹 플레이어는 모두 동일한 REST API 및 백그라운드 작업 시스템에서 제공됩니다. 하나의 백엔드, 세 개의 최상급 클라이언트, 플랫폼별 재구현은 필요 없습니다.

중요한 점은 이것이 단순한 데모가 아니라 실제 운영 인프라라는 점입니다. 백엔드는 PostgreSQL 지속성, 백그라운드 작업 처리(긴 TTS/비디오 렌더링이 API를 차단하지 않도록), 도구 기반 강화용 MCP 서버 구현, Prometheus 메트릭스, JWT 인증, nginx 리버스 프록시를 포함합니다. 또한 이 모든 기능은 Docker Compose 배포로 제공되며, 한 번의 설정으로 구동 가능한 Grafana/Prometheus 모니터링 프로파일을 갖추고 있습니다. AI는 강화 레이어일 뿐, 필수 종속성이 아닙니다. 모든 LLM 제공자는 선택 사항이므로, 기본 운영에는 API 키가 필요하지 않으며, 키가 제공되는 즉시 프리미엄 강화 기능이 활성화됩니다. 이러한 설계 덕분에 동일한 도구가 오프라인에서 노트북으로 작업하는 취미 사용자와 기업이 선호하는 제공자를 연동하는 엔터프라이즈 환경 모두에 적합합니다. 그리고 이 모든 미디어 파이프라인은 신뢰에 의존하지 않고 유닛 테스트, 통합 테스트, 엔드투엔드 테스트로 철저히 검증됩니다.

## 개발 동기

수동으로 강의 비디오를 제작하는 과정은 느립니다. 작성, 내레이션 녹음, 음악 편곡, 편집 — 각각이 노력과 전문 도구를 요구합니다. Courses-Creator는 이러한 과정을 마크다운 기반 파이프라인으로 압축하여 하나의 소스 스크립트가 완성된 강의로 변환되도록 합니다. AI는 인간이 수작업으로 처리해야 할 부분을 자동으로 메워줍니다.

콘텐츠

## 왜 혁신적인가

이 기술은 강좌 제작을 전문가의 다기능 작업에서 반복 가능한 소프트웨어 파이프라인으로 전환합니다. 콘텐츠 작성, AI 강화, 내레이션 및 음악 생성, 멀티 플랫폼 재생까지 모든 과정이 하나의 배포 가능한 스택에 통합됩니다. API 키 없이도 자연스럽게 기능이 축소되는 '그레이스풀 디그레이션(graceful degradation)’이야말로 숨은 강점입니다. 동일한 코드베이스가 예산에 민감한 개인 창작자와 프리미엄 공급 계약을 맺은 기업을 모두 지원하며, 그 사이에는 어떤 수정도 필요하지 않습니다.

## 혁신적인 요소

- 플러그형 멀티 LLM 강화(OpenAI/Anthropic/Ollama)를 지원하는 마크다운-비디오 파이프라인.
- 내장형 TTS(Bark, SpeechT5) 및 배경 음악 생성 기능.
- 툴 기반 강화 기능을 위한 MCP 서버 구현이 프로세싱 엔진 내부에 통합됨.
- 하나의 백엔드가 세 가지 주요 클라이언트(Electron 데스크톱, React Native 모바일, React 웹)를 동등하게 지원.

## 도전 과제와 해결 방안

- **대용량 미디어 처리**: Go 파이프라인과 백그라운드 작업 처리로 긴 TTS/비디오 작업이 API를 차단하지 않도록 해결.
- **선택적이지만 강력한 AI**: LLM 공급자를 선택적이고 플러그형으로 설계해 기본 기능으로 자연스럽게 대체되도록 해결.
- **멀티 플랫폼 배포**: 공유 REST API와 세 개의 전용 플레이어 앱으로 해결.
- **운영 효율성**: Docker Compose 프로파일, Prometheus/Grafana, 내장형 JWT 인증으로 해결.

## 기술 스택 (선택 이유 및 구현 방식)

- **Go** — 핵심 프로세서 엔진, REST API, 작업 실행기, 파이프라인(972K+ 바이트, 주요 언어).
- **TypeScript / React** — 웹 플레이어 및 공유 UI.
- **Electron** — 데스크톱 제작 앱.
- **React Native** — 모바일 플레이어.
- **PostgreSQL** — 강좌/작업 데이터 저장.
- **LLM 공급자(OpenAI, Anthropic, Ollama)** — 콘텐츠 강화.
- **TTS(Bark, SpeechT5)** — 내레이션 합성.
- **MCP 서버** — 엔진 내부의 툴 통합.
- **Docker Compose + nginx** — 풀스택 배포 및 리버스 프록시.
- **Prometheus + Grafana** — 모니터링.

> 참고: 공개 README의 빠른 시작 가이드는 `your-org` 클론 URL를 사용합니다.

