---
name: HelixTranslate
slug: helixtranslate
tier: helix-primary
order: 10
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - QUIC / HTTP/3 (quic-go)
  - gRPC + Protocol Buffers
  - Gorilla WebSocket
  - PostgreSQL
  - SQLite
  - Redis
  - unidoc/unioffice + unipdf
  - Cobra
  - LLMsVerifier bridge
  - Docker / Podman
repos:
  - https://github.com/HelixDevelopment/HelixTranslate
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Provider-routing / no-silent-fallback flow (signature) — request → is provider explicit? → is a verified model available? → strongest-verified selection with deterministic fallback chain; every "no" branch terminating in a red honest hard error, with local runtimes crossed out.
  - Verification-gated model selection — LLMsVerifier scores models (responsiveness / code / feature-richness / reliability) → only verified, positively-scored models enter the eligible pool → HelixTranslate picks the top one.
  - Real-time monitoring pipeline — Translation CLI → typed WebSocket events → Monitoring Server → live Web Dashboard, with remote SSH workers feeding distributed translation.
  - Multi-format ebook flow — FB2/EPUB/PDF/DOCX/HTML/TXT in → parse → translate (verified model) → multi-pass polish → regenerate target format.
---

# HelixTranslate

**검증된 모델 기반 도서 번역 — 설계상 정직하며, 결코 조용한 대체 수단이 되지 않습니다.**

## 요약

HelixTranslate는 고성능 Go 기반 전자책 번역 플랫폼으로, 검증된 LLM 제공자를 통해 100개 이상의 언어로 도서를 번역합니다. 실시간 WebSocket 모니터링과 엄격한 '조용한 대체 수단 없음' 라우팅 정책을 적용해, 성능 저하를 조용히 감추기보다는 명시적으로 실패합니다.

## 간략 설명

Go 기반 범용 전자책 번역 도구 모음입니다. FB2, EPUB, TXT, HTML, PDF, DOCX 등 다양한 형식을 100개 이상의 언어로 번역하며, 검증된 최상위 LLM( LLMsVerifier 브릿지를 통해)를 사용합니다. REST/HTTP-3 및 gRPC API, 분산 처리, 실시간 WebSocket 모니터링 대시보드를 지원합니다.

## 상세 설명

HelixTranslate는 기업급 Go 기반 시스템으로, LLM 제공자를 이용해 전자책을 언어 간에 번역합니다. 이는 단락이나 일부분이 아닌, 책 전체를 처음부터 끝까지 번역하는 시스템입니다. 여러 전자책 형식(FB2, EPUB, TXT, HTML, PDF, DOCX)을 파싱하고 재생성하며, 100개 이상의 언어를 자동 감지하고 지원합니다. 또한 CLI 도구와 API 서버(REST over HTTP/3, gRPC, WebSocket 이벤트 스트림)를 제공해 터미널 워크플로와 서비스 메시 환경 모두에 적합합니다.

이 시스템의 핵심 특징은 *모델 선택 방식*에 있습니다. 특정 제공자를 하드코딩하고 그 상태를 기대하는 대신, HelixTranslate는 모든 모델 권한을 LLMsVerifier 브릿지(`pkg/bridge`)에 위임합니다. 이 브릿지는 가장 강력한 *검증된* API 모델을 선택하고, 결정론적이며 점수 순으로 정렬된 대체 체인을 제공합니다. 모델의 적합성은 응답성, 코드 품질, 기능 다양성, 신뢰성을 종합한 가중 점수로 결정됩니다. 즉, 번역을 수행하는 모델은 설정 파일에 등장했다는 이유만으로 선택되는 것이 아니라, 실제로 검증된 성능으로 그 자리를 차지합니다.

더욱 중요한 점은 시스템이 코드 수준에서 "조용한 대체 수단 없음" 원칙을 엄격히 적용한다는 것입니다. 제공자 API 키가 없거나, 운영자가 사용할 수 없는 제공자를 명시적으로 요청할 경우, 시스템은 조용히 대체 제공자로 전환하거나 로컬 런타임으로 넘어가 문제를 숨기지 않습니다. 대신 명시적인 오류를 반환합니다. 이 규칙은 전용 사전 빌드 게이트와 뮤테이션 테스트를 통해 엄격히 관리됩니다. 로컬 런타임(Ollama, llama.cpp)은 의도적으로 기본 경로에서 제외되어, 검증되지 않은 약한 엔진이 조용히 대체 역할을 수행할 수 없도록 설계되었습니다.

번역 핵심 주변에는 실시간 WebSocket 모니터링 하위 시스템이 구축되어 있습니다. 번역 CLI는 타입화된 이벤트를 모니터링 서버로 전송하며, 이는 실시간 웹 대시보드를 구동합니다. 원격 SSH 워커는 작업을 분산 처리합니다. 여기에 일관성 유지 위한 다중 패스 교정, 사전 품질 분석, 긴 입력에 대한 비용 절감을 위한 번역 캐싱, 시각 기반 품질 보증(QA) 기능이 추가됩니다. 전체 플랫폼은 '허세 없는 엔지니어링' 원칙에 따라 운영됩니다. 테스트는 실제 사용자가 확인할 수 있는 결과를 증명해야 하며, 단순한 '녹색 체크'가 아닌 필수 뮤테이션 테스트로 뒷받침됩니다.

콘텐츠

## 왜 만들었는가

장편 도서를 신뢰할 수 있고 *정직하게* 번역하기 위해서다. '어느 정도 완성된’ 번역을 내놓는 일은 결코 없다. 설계의 대전제는 '누락되었거나 검증 불가능한 번역은 반드시 명백하고 확실한 오류로 드러나야 한다’는 것이며, 모델 선택은 항상 하드코딩된 추측이나 묵인되는 로컬 대체 수단이 아닌, 진정으로 검증된 제공자로 귀결되어야 한다.

## 왜 혁신적인가

대부분의 HelixTranslate 번역 파이프라인은 조용히 실패한다. 더 약한 모델로 대체되거나 로컬 런타임으로 전환되거나, 부분 출력을 내보내면서도 테스트 스위트는 여전히 초록불이 켜지고 아무도 품질의 급락을 눈치채지 못한다. HelixTranslate는 이러한 실패 모드를 구조적으로 불가능하게 만든다. 모델 선택은 검증에 의해 통제되며, 대체 경로는 결정론적이고 완전히 투명하며, '키 없음/검증된 모델 없음’은 묵인되는 무관심이 아닌 정직한 오류로 처리된다. 이 단 하나의 설계 결정으로 '이 번역이 실제로 유능하고 검증된 모델에서 실행되었는가?’라는 질문은 확인할 수 없는 희망에서 시스템이 대신 보장하는 확실성으로 바뀐다.

## 무엇이 혁신적인가

- **LLMsVerifier 브릿지를 통한 검증 기반 모델 라우팅** – 가장 강력한 *검증된* 모델이 자동 선택되므로 운영자는 의도만 명시하고 공급사 이름은 언급하지 않으며, 다운될 수 있는 특정 제공자를 수동으로 선택하지 않는다.
- **코드에 강제된 무묵인 대체 금지 보장** – 네 가지 명시적 라우팅 경로(모의/명시적 검증기/명시적 제공자/브릿지 기본값)가 각각 묵인 전환 대신 명백한 오류를 발생시키며, 기본 경로에서 로컬 런타임을 의도적으로 제거해 대체할 약한 대상이 없게 만든다.
- **기계적 강제** – `CM-NO-LOCAL-RUNTIME` 사전 빌드 게이트와 페어링된 변이 테스트가 빌드 시점에 기본 경로에서 로컬 런타임 클라이언트가 생성되지 않도록 보장한다. 보장이 깨지면 빌드가 실패하므로 시간이 지나도 약화될 수 없다.
- **결정론적, 점수 순 대체 체인** – *검증된* 모델 간 제공자 대체는 허용되며 완전히 투명하다. 이는 묵인 대체와는 원칙적으로 구분된다. 어떤 유능한 모델이 작업을 처리했는지 항상 알 수 있다.
- **실시간 WebSocket 모니터링** – 타입화된 번역 이벤트가 대시보드로 실시간 스트리밍되며, 분산된 SSH 워커 덕분에 장편 작업도 병렬적으로 가시화된다. 블랙박스가 아니다.
- **반허위 테스트 체계** – 변이 테스트, 부정 단언, 실제 시스템 실행, 비전 기반 QA를 결합해 '테스트 통과’가 '기능이 실제로 작동하지 않음’을 조용히 숨기지 못하게 한다.

## 가장 큰 기술적 도전 과제와 해결 방법

- **정직한 번역 파이프라인 보장(묵인 품질 저하 없음).** LLMsVerifier 브릿지에 모든 모델 권한을 집중시켜 단일 결정 지점을 확보하고, 네 가지 명시적 라우팅 분기를 코드화해 각각 추측 대신 명백한 오류를 발생시키며, 기본 경로에서 로컬 런타임 대체 경로를 완전히 제거했다. 또한 빌드 게이트와 변이 테스트로 규칙을 고정해 보장이 훼손되면 빌드가 실패하도록 만들었다.
- **'테스트는 통과하지만 기능은 망가진’ 문제.** 이 실패 모드를 헌장에 명시하고 반허위 테스트 체계로 해결했다. 구현 세부 사항이 아닌 사용자가 실제로 확인할 수 있는 단언, 실제 시스템을 활용한 테스트(모의는 단위 테스트로 제한), 필수 변이 테스트(기능을 의도적으로 망가뜨렸을 때 테스트가 반드시 실패해야 함), 그리고 실제 출력을 눈으로 확인하는 비전 기반 QA를 도입했다.
- **장편, 다중 포맷 품질.** 장편 입력은 일관성과 예산을 모두 압박한다. 이를 해결하기 위해 다중 패스 교정으로 텍스트를 재검토하고, 준비 단계에서 작업 규모를 사전 분석하며, 동일한 구절에 대해 중복 비용이 발생하지 않도록 번역 캐싱을 적용했다.

기술 스택

- **Go** — 동시성 프리미티브가 파싱, 번역, 스트리밍 작업에 자연스럽게 대응하며, 고동시성 백엔드 모듈 `digital.vasic.translator`에 적합한 선택.
- **Gin** — REST API 인터페이스를 제공하는 빠르고 간결한 HTTP 라우터.
- **QUIC / HTTP/3 (quic-go)** — 불안정한 네트워크에서도 안정적인 저지연, 최신 전송 계층을 REST API에 제공하기 위한 선택.
- **gRPC + Protocol Buffers** — REST와 함께 동작하는 강력하게 타입화된 고성능 서비스 인터페이스를 구현하기 위한 선택.
- **Gorilla WebSocket** — 실시간으로 모니터링 대시보드에 공급되는 타입화된 번역 이벤트 스트림을 전송하기 위한 선택.
- **PostgreSQL, SQLite, Redis** — 의도적인 3단계 분리: PostgreSQL는 내구성 있는 관계형 데이터, SQLite는 임베디드/로컬 상태(검증 모델 저장소 `data/verified_models.db`도 지원), Redis는 핫 캐시로 사용.
- **unidoc/unioffice + unipdf** — 어려운 형식인 DOCX 및 PDF 파싱과 재생성을 처리하여 멀티포맷 전자책의 무결성 유지.
- **Cobra** — `unified-translator` 및 관련 도구를 구동하는 CLI 프레임워크.
- **golang-jwt (JWT HS256)** — 상태 비저장 API 인증을 위한 선택으로, IP별 토큰 버킷 속도 제한 및 TLS/QUIC 전송 보안과 결합하여 인터페이스 보안 강화.
- **LLMsVerifier 브리지(`pkg/bridge`)** — 핵심 요소: 최적의 검증 모델과 결정론적 대체 체인을 제공하며, 무음 대체 금지 보장을 단일 집행 지점으로 구현.
- **Testify** — Go 테스트 스위트용으로 선택되었으며, `provider_routing_test.go` 전용 테스트와 정직성 규칙을 유지하는 변이 게이트 포함.
- **Docker / Podman (루트리스) + Compose** — 컨테이너화된 분산 배포(`docker-compose.distributed.yml`)를 위한 선택으로, 루트리스 Podman를 통해 보안 강화.

상태 및 정직성 참고 사항

- **상태: 베타.** 기능적 플랫폼이지만 `VERSION`/Makefile/`AGENTS.md` 간 버전 정보가 일관되지 않아 안정되지 않은 상태로 간주.
- **라이선스: 미정.** README에는 MIT로 명시되어 있으나 LICENSE 파일과 일치 여부가 확인되지 않음 — 명시 전 반드시 확인 필요.
- 대시보드/모니터링 엔드포인트는 로컬호스트 전용이며 공개되지 않음. 문서상의 WebSocket 성능 수치는 검증되지 않은 목표치임. `ARCHITECTURE.md`에는 제거된 Ollama/로컬 엔진이 여전히 기재되어 있음(구식 정보).

**우선순위 계층:** Helix-주요(LLM-인프라 클러스터). Helix 플랫폼 계열 내 HelixTrack 다음 순위.

