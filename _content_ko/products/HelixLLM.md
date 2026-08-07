---
name: HelixLLM
slug: helixllm
tier: helix-primary
order: 4
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - HTTP/3 QUIC
  - TLS 1.3
  - llama.cpp
  - LLMsVerifier
  - gRPC
  - SSE
  - Kafka
  - Prometheus
  - OpenTelemetry
repos:
  - https://github.com/HelixDevelopment/HelixLLM
diagrams:
  - Mode-system diagram — one binary deploying as full on a laptop vs. gateway/brain/knowledge/agents/control split across cluster hosts.
  - Fallback-chain flow — request → ranked cloud providers (429/5xx skip arrows) → guaranteed llama.cpp local fallback, annotated with LLMsVerifier scoring.
  - Compatibility layer — OpenAI and Anthropic client SDKs both hitting the same HTTP/3 gateway.
  - RAG + ReAct agent loop — document ingestion → vector search → agent tool-calling with conversation sessions.
---

# HelixLLM

**하나의 바이너리, 여섯 가지 모드 — 노트북부터 멀티 호스트 클러스터까지 OpenAI 및 Anthropic 호환 추론 지원**

## 요약

HelixLLM는 Go로 구축된 엔터프라이즈급 분산 LLM 시스템으로, 단일 바이너리에 모드 시스템을 탑재해 단일 호스트 개발 환경부터 멀티 호스트 운영 환경까지 확장 가능합니다. HTTP/3를 통해 완전한 OpenAI 및 Anthropic 호환 API를 제공하며, 로컬 llama.cpp 추론, 점수 기반 멀티 프로바이더 폴백 체인, RAG 파이프라인, ReAct 에이전트 시스템을 지원합니다.

## 간략 설명

HelixLLM는 단일 바이너리로 동작하는 Go 기반 분산 LLM 시스템입니다. HTTP/3를 통해 OpenAI 및 Anthropic 호환 API를 제공하고, 로컬 llama.cpp 추론을 실행하며, 무료 클라우드 프로바이더를 자동 탐지해 장애 복구 체인으로 구성합니다. 여기에 RAG 지식 파이프라인과 도구 호출이 가능한 ReAct 에이전트를 추가한 통합 솔루션으로, 여섯 가지 모드로 배포할 수 있습니다.

## 상세 설명

HelixLLM는 Go와 Gin로 구축된 엔터프라이즈급 분산 LLM 시스템으로, 핵심 강점은 하나의 바이너리가 모든 규모에 대응한다는 점입니다. 이 시스템은 단일 바이너리로 컴파일되며, 배포 시점에 모드 시스템이 해당 바이너리의 역할을 결정합니다. 노트북에서 `full` 모드로 실행하면 올인원 인스턴스로 동작하며, `gateway`, `brain`, `knowledge`, `agents`, `control` 모드로 기능을 분산해 여러 호스트에 배포할 수도 있습니다. 개발자의 머신에서 운영 클러스터까지 동일한 코드를 재배치하는 방식으로 확장 가능합니다.

HelixLLM는 두 가지 API 방언을 유연하게 지원합니다. 완전한 OpenAI 및 Anthropic 호환 API를 제공해 기존 SDK 클라이언트들이 별도의 수정 없이 사용할 수 있으며, 모든 통신은 HTTP/3(QUIC)를 통해 이루어집니다. HTTP/2 자동 폴백과 TLS 1.3을 지원하며, 로컬 추론은 llama.cpp를 통해 CUDA, Metal, ROCm을 지원해 Nvidia, Apple, AMD 하드웨어에서 동일한 빌드로 가속화됩니다. 특히 주목할 만한 기능은 멀티 프로바이더 폴백 체인으로, 무료 클라우드 추론의 불안정성을 관리 가능한 자가 치유 리소스로 변환합니다. HelixLLM는 7개 이상의 클라우드 프로바이더(Chutes, OpenRouter, HuggingFace, Nvidia, Cerebras, SambaNova, Together)에서 무료 모델을 자동 탐지하고, LLMsVerifier를 통해 5분 간격으로 점수를 산정해 순위화된 체인을 통해 요청을 라우팅합니다. 429/5xx 오류 발생 시 자동으로 폴백하며, 최종적으로는 로컬 llama.cpp를 보장된 대안으로 사용해 요청이 실패하지 않도록 합니다.

HelixLLM는 단순한 추론 엔진을 넘어 완전한 애플리케이션 플랫폼입니다. 동일한 바이너리에는 RAG 지식 파이프라인(수집, 청킹, 임베딩, vector 검색)과 도구 호출, 대화 세션, RAG 통합을 지원하는 ReAct 에이전트 시스템이 포함되어 있습니다. 모드 시스템은 네트워크 수준에서도 효율성을 발휘합니다. `full` 모드에서는 모든 계층이 프로세스 내 Go 호출로 직접 통신해 네트워크 오버헤드가 없지만, 동일한 바이너리를 호스트 간에 분산 배포하면 gRPC, SSE, Kafka를 통해 조정됩니다. 또한 Brotli/gzip 콘텐츠 협상, OpenAI 및 Anthropic 형식과 바이트 단위로 호환되는 SSE 스트리밍, API 키 및 JWT 인증과 요율 제한, Prometheus 메트릭스, OpenTelemetry 트레이싱, 그리고 다양한 운영 인프라용 Go 서브모듈을 지원합니다.

콘텐츠

## 왜 만들었는가

팀에는 이식이 가능하고 표준 호환되며 회복력이 뛰어난 추론이 필요합니다. 클라이언트를 다시 작성하거나 특정 제공업체나 특정 머신에 종속되지 않고도 말이죠. HelixLLM는 동일한 바이너리가 개발용 로컬 환경에서 실행될 수 있고, 다중 호스트 프로덕션 클러스터로 확장될 수 있도록 설계되었으며, 클라이언트가 이미 사용 중인 OpenAI 및 Anthropic 방언을 지원합니다.

## 혁신적인 이유

HelixLLM는 게이트웨이, 로컬 추론, 클라우드 폴백, RAG, 에이전트 등 전체 추론 스택을 하나의 바이너리로 통합합니다. 모드 전환 하나로 제어되므로 배포 아키텍처는 재플랫폼 프로젝트가 아닌 런타임 결정 사항이 됩니다. 또한 이전에는 약점이었던 부분을 기능으로 전환했습니다. 클라우드 제공업체의 신뢰성은 이제 최우선으로 관리되는 요소로, 지속적으로 측정되며 점수 기반의 자가 치유 폴백 체인에 의해 처리됩니다. 이 체인은 몇 분마다 제공업체를 재평가하고, 항상 로컬 추론으로 안전하게 전환되도록 보장합니다. 이로써 얻을 수 있는 것은 진정한 의존성을 갖춘 단일 엔드포인트입니다. 표준 호환성이 유지되고 노트북에서 클러스터까지 이식 가능하며, 업스트림 제공업체가 제한을 걸거나 장애가 발생하더라도 절대 중단되지 않습니다.

## 혁신적인 점

- **여섯 가지 모드를 지원하는 단일 바이너리**: `full` 모드에서는 프로세스 내 직접 Go 호출을 지원하고, 분산 모드에서는 gRPC/SSE/Kafka를 사용합니다. 배포 토폴로지가 변경되어도 코드 수정이나 불필요한 네트워크 오버헤드 없이 유연하게 대응할 수 있습니다.
- **7개 이상의 무료 제공업체를 아우르는 점수 기반 자동 발견 폴백 체인**: LLMsVerifier로 지속적으로 순위를 매기고, 429/5xx 오류 발생 시 자동으로 폴백하며, 최후의 수단으로 llama.cpp를 보장합니다. 무료 티어의 용량이 안정적인 용량으로 변모합니다.
- **OpenAI와 Anthropic 호환 표면 동시 지원**: HTTP/3를 통해 제공되며 HTTP/2 자동 폴백을 지원합니다. 두 생태계의 클라이언트가 수정 없이 바로 연결됩니다.
- **단일 코드베이스로 CUDA, Metal, ROCm 지원**: 동일한 빌드가 Nvidia, Apple, AMD 하드웨어에서 가속화되어 실행됩니다.

## 가장 큰 기술적 도전 과제와 해결 방법

- **하나의 호스트에서 다수로 확장 시 재작성 없이 가능하게 하기**
  대부분의 시스템은 "로컬 개발"과 "분산 프로덕션" 사이에 명확한 경계를 두며, 이를 넘으려면 아키텍처를 재설계해야 합니다. 우리는 단일 바이너리에 모드 시스템을 도입해 이 경계를 없앴습니다. `full` 모드에서는 동일한 레이어가 프로세스 내 직접 호출로 통신하고, 분산 모드에서는 gRPC/SSE/Kafka로 투명하게 전환됩니다. 따라서 확장은 포팅이 아닌 설정 변경만으로 가능합니다.

- **신뢰할 수 없고 제한이 많은 무료 클라우드 제공업체**
  무료 티어 추론은 빠르지만 429 오류가 발생하거나 요청 중간에 사라질 수 있습니다. 우리는 사용 가능한 모델을 자동으로 발견하고, LLMsVerifier로 점수를 매기며, 제한 임박 제공업체를 사전에 탐지해 라우팅을 우회합니다. 또한 순위 기반 체인을 따라 자동으로 폴백하며, 최후의 수단으로 로컬 llama.cpp로 전환되도록 설계했습니다. 덕분에 호출자에게는 제공업체의 불안정성이 전달되지 않습니다.

- **두 생태계 간 클라이언트 호환성**
  새로운 추론 백엔드를 채택하기 위해 클라이언트를 재작성하는 것은 현실적으로 불가능합니다. 우리는 OpenAI와 Anthropic의 API 형태를 모두 구현했으며, 각기 다른 SSE 스트리밍 형식까지 지원합니다. 따라서 두 진영의 SDK는 HelixLLM를 가리키기만 하면 즉시 작동합니다.

## 기술 스택

- **Go + Gin** — 단일 바이너리 기반의 동시성 우선 런타임으로, 전체 모드 시스템을 가능하게 하는 핵심 요소입니다. 노트북 서버부터 클러스터 역할까지 하나의 빌드로 구동되며, 시스템 전체와 게이트웨이의 HTTP 레이어를 포함합니다.
- **HTTP/3(QUIC) + TLS 1.3(HTTP/2 대체 지원)** — 현대적이고 저지연, 연결 안정성을 갖춘 전송 계층으로, 서버 인터페이스로 노출됩니다. QUIC를 지원하지 않는 클라이언트는 자동으로 HTTP/2로 전환됩니다.
- **llama.cpp(CUDA/Metal/ROCm)** — Nvidia, Apple, AMD 백엔드를 아우르는 이식 가능한 로컬 추론 가속기로, 하나의 코드베이스로 다양한 플랫폼에서 동작합니다. 또한 최종 대체 수단으로 활용되어 대체 체인이 완전히 실패하지 않도록 보장합니다.
- **LLMsVerifier** — "현재 어떤 제공자가 가장 적합한가"를 수치화하는 도구로, 5분마다 클라우드 대체 체인의 품질을 실시간으로 평가하고 순위를 매겨 라우팅이 최신 상태를 반영하도록 합니다.
- **클라우드 제공자(Chutes, OpenRouter, HuggingFace, Nvidia, Cerebras, SambaNova, Together)** — 다양한 업스트림의 무료 티어 용량을 활용하기 위해 선택되었습니다. 자동으로 발견 및 순위화되어 단일 대체 체인으로 통합되며, 특정 제공자에 의존하지 않도록 합니다.
- **gRPC + SSE + Kafka** — 분산 배포 환경에서 모드 간 통신을 위한 전송 계층으로, gRPC는 서비스 간 호출, SSE는 스트리밍, Kafka는 역할 간 이벤트 흐름 분리를 담당합니다.
- **벡터 스토어 / embeddings** — RAG 지식 파이프라인의 종단 간 구동을 위해 선택되었습니다. 문서의 수집, 분할, 임베딩, 검색을 통해 모델 응답의 근거를 제공합니다.
- **Prometheus + OpenTelemetry** — 배포된 모드에 관계없이 요청을 추적하는 메트릭 및 분산 추적 시스템으로 활용됩니다.
- **vasic-digital Go 서브모듈** — 검증된 프로덕션 인프라 구성 요소를 재사용하여 시스템의 기반을 일관되게 유지하며, 불필요한 재구축을 방지합니다.

## 현황 및 투명성 안내

- **현황: 베타.** 기능적이며, 활발히 개발 중인 분산 추론 시스템입니다.
- **라이선스: 미정.** 저장소 메타데이터에 라이선스 정보가 명시되어 있지 않으며(`licenseInfo` null), 이는 **미검증 상태**로 라이선스 확정 전에 반드시 해결해야 합니다.
- 공식 저장소는 현재 `github.com/HelixDevelopment/llm`으로 연결되며, `HelixLLM` 경로는 해당 저장소로 리다이렉트됩니다. README에 기재된 커버리지 임계값 및 서브모듈 수는 자체 보고된 수치입니다.

**우선 순위 계층:** Helix-주요.

