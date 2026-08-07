---
name: Catalogizer
slug: catalogizer
tier: vasic-util-secondary
order: 21
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - Gin
  - TypeScript
  - React
  - Tailwind
  - WebSockets
  - SQLCipher
  - PostgreSQL
  - Redis
  - SMB/FTP/NFS/WebDAV
  - Prometheus
  - OpenTelemetry
  - Docker
  - Tauri/Rust
  - S3
  - Google Cloud Storage
repos:
  - https://github.com/vasic-digital/Catalogizer
  - https://github.com/vasic-digital/Media-Types-TS
  - https://github.com/vasic-digital/Catalogizer-API-Client-TS
  - https://github.com/vasic-digital/Media-Player-React
  - https://github.com/vasic-digital/Media-Browser-React
  - https://github.com/vasic-digital/Collection-Manager-React
  - https://github.com/vasic-digital/Dashboard-Analytics-React
  - https://github.com/vasic-digital/Auth-Context-React
diagrams:
  - Layered architecture (React UI ↔ Go API ↔ SQLCipher) with multi-protocol fan-out
  - Resilience sequence (SMB outage → circuit breaker → offline cache → backoff reconnect)
  - Enrichment pipeline (detected file → classifier → external providers → catalog entry)
  - Module map (Catalogizer over the 21 digital.vasic.* submodules)
---

**고급 멀티 프로토콜 미디어 컬렉션 관리 — 소유한 모든 콘텐츠 감지, 분류, 정보 강화**

## 요약

Catalogizer는 자가 호스팅 가능한 미디어 컬렉션 관리 시스템으로, SMB, FTP, NFS, WebDAV 및 로컬 파일 시스템 전반에 걸쳐 미디어를 자동으로 감지, 분류, 정리합니다. 실시간 모니터링, 암호화 저장, 외부 메타데이터 강화 기능과 함께 React 기반의 현대적인 UI를 제공하며, 고성능 Go API 백엔드로 지원됩니다.

## 간략 설명

프로덕션급 멀티 프로토콜 미디어 라이브러리 관리자. Go/Gin REST API는 SMB/FTP/NFS/WebDAV/로컬 소스에서 50여 가지 미디어 유형을 감지하고, TMDB/IMDB/MusicBrainz/Steam 등 외부 소스에서 메타데이터를 강화하며, 암호화된 SQLCipher 데이터베이스 위에 실시간 React 웹 앱을 제공합니다.

## 상세 설명

대부분의 미디어 관리자는 먼저 양보를 요구합니다. 모든 콘텐츠를 하나의 디스크에, 하나의 형식으로, 하나의 유형으로 통합한 후에야 비로소 도움을 주죠. Catalogizer는 정반대의 접근에서 출발합니다. 여러분의 컬렉션은 이미 NAS 공유 공간과 서로 호환되지 않는 프로토콜에 분산되어 존재한다는 전제에서 시작해, 그곳에서부터 만납니다. 이 시스템은 스토리지에서 이미 사용 중인 프로토콜 — SMB/CIFS, FTP/FTPS, NFS, WebDAV, 로컬 파일 시스템 — 을 지원하며, 단일한 통합 클라이언트 추상화 계층을 통해 윈도우 공유, FTP 아카이브, WebDAV 마운트 등이 상위 레이어에서는 동일하게 인식됩니다. 따라서 애플리케이션 코드를 건드리지 않고도 소스를 혼합하거나 교체, 제거할 수 있습니다.

Go 백엔드(Gin REST API)는 이러한 소스를 지속적으로 모니터링하며, 파일이 추가될 때마다 50여 가지 미디어 유형(영화, TV 프로그램, 음악, 게임, 소프트웨어, 다큐멘터리 등)을 감지하고 분류합니다. 또한 TMDB, IMDB, TVDB, MusicBrainz, Spotify, Steam 등 외부 제공업체 스택에서 각 항목의 메타데이터를 강화해, 단순한 파일 이름에서 아트워크, 출연진, 상세 정보가 포함된 완전한 카탈로그 항목으로 변환합니다. 그 결과는 WebSocket을 통해 TypeScript React 프론트엔드로 실시간 스트리밍되므로, 수동 새로고침 없이도 라이브러리가 실시간으로 업데이트됩니다. 모든 메타데이터는 JWT 기반의 역할 기반 인증으로 보호되는 암호화된 SQLCipher 데이터베이스에 저장됩니다.

대부분의 카탈로거가 공유 연결이 끊어지면 조용히 작동을 멈추는 것과 달리, Catalogizer는 장애 상황에서도 유용성을 유지하도록 설계되었습니다. 일시적인 SMB 장애는 지수 백오프 재연결, 서킷 브레이커(죽은 호스트에 대한 반복 요청 차단), 지속적인 상태 모니터링, 오프라인 메타데이터 캐시로 대응합니다. 오프라인 캐시는 마지막 정상 상태의 데이터를 기반으로 사용자 요청에 응답해, "NAS 한 대가 재부팅했다고 전체 앱이 다운되는" 상황 대신 "하나의 소스가 일시적으로 불안정하지만 나머지는 정상 작동"하는 환경을 제공합니다.

카탈로깅을 넘어, 이 시스템은 컬렉션 운영 도구로서의 역할도 수행합니다. 성장 추세 및 품질/버전 추적 분석, 전문적인 PDF 보고서 생성, PDF에서 이미지/텍스트/HTML로의 변환 서비스, 즐겨찾기 내보내기/가져오기(JSON/CSV), S3, Google 클라우드 스토리지 또는 로컬 폴더로의 동기화 기능까지 지원합니다. 또한 단순히 덩치가 큰 모놀리식이 아니라, 21개의 재사용 가능한 `digital.vasic.*` Go 하위 모듈과 TypeScript 클라이언트 패키지로 의도적으로 구성되어 있습니다. 각 모듈은 독립적으로 테스트되고 버전 관리되며, Catalogizer를 구동하는 것과 동일한 검증된 인증, 파일 시스템, 스트리밍, 관측 가능성 모듈이 더 넓은 제품군에서도 활용됩니다. 품질 보증은 자가 보고에 의존하지 않습니다. Challenges 프레임워크와 HelixQA는 모든 광고된 기능을 증거 기반 검증을 통해 엄격히 확인합니다.

## 왜 만들었는가

기존 미디어 관리 도구들은 단일 저장소 백엔드와 단일 미디어 유형만을 가정합니다. 실제 컬렉션은 여러 NAS 공유 폴더와 프로토콜에 분산되어 있으며, 공유 폴더 하나가 끊어지면 시스템이 불안정해지고, 영화, 음악, 게임, 소프트웨어 등이 뒤섞여 있습니다. Catalogizer는 모든 프로토콜을 동등하게 다루고, 불안정한 네트워크 저장소에서도 견딜 수 있도록 설계되었으며, 모든 데이터를 아우르는 하나의 신뢰할 수 있고 풍부하며 암호화된 카탈로그를 제공합니다.

## 왜 혁신적인가

일반적으로 여러 도구가 쌓여야 하는 기능을 Catalogizer는 하나의 자체 호스팅 가능하고 암호화된 패키지로 통합했습니다. 저장소 백엔드를 가리지 않는 프로토콜 중립적 수집, 저장소 장애 시에도 카탈로그를 유지하는 복원력, 여러 제공업체의 메타데이터를 활용해 원시 파일을 탐색 가능한 라이브러리로 변환하는 풍부한 강화 기능까지 모두 포함합니다. 모듈화된 아키텍처의 장점은 복리로 작용합니다. 파일 시스템 클라이언트의 보안 패치나 새로운 제공업체 플러그인이 한 번 적용되면 모든 사용자에게 즉시 혜택이 돌아가므로, 주변 생태계가 발전할수록 Catalogizer도 꾸준히 개선됩니다. 한마디로, 단순한 미디어 색인이 아니라 *미디어 시스템* 그 자체입니다. 소유자가 직접 관리하고, 불안정한 인프라에서도 살아남으며, 약속이 아닌 검증된 기술로 구축된 시스템입니다.

## 혁신적인 점

- 하나의 인터페이스 뒤에서 통합된 다중 프로토콜 파일 시스템 클라이언트(SMB/FTP/NFS/WebDAV/로컬).
- 저장소 장애 시에도 오프라인 캐시와 서킷 브레이커로 카탈로그 사용 가능.
- 21개의 재사용 가능한 `digital.vasic.*` Go 하위 모듈 및 TS 클라이언트 모듈로 완전한 모듈화.
- 암호화된 카탈로그(SQLCipher)와 UI로의 실시간 WebSocket 동기화.
- Challenges 프레임워크와 HelixQA 통합을 통한 증거 기반 품질 보증.

## 도전 과제와 해결 방안

- **불안정한 네트워크 저장소**: 지수 백오프, 서킷 브레이커, 헬스 체크, 소스가 연결되지 않을 때 캐시된 메타데이터를 제공하는 퇴거 정책 오프라인 캐시로 해결.
- **프로토콜 이질성**: 모든 프로토콜을 공통 `digital.vasic.filesystem` 클라이언트로 추상화해 상위 계층이 프로토콜을 인식하지 않도록 해결.
- **데이터 보안**: SQLCipher의 저장 시 암호화와 JWT/RBAC 인증 및 요청 검증 미들웨어로 해결.
- **대규모 유지보수성**: 모든 공통 로직을 독립적으로 테스트 가능한 하위 모듈로 분리해 모놀리식 구조를 피함으로써 해결.

## 기술 스택(선택 이유 및 구현 방식)

- **Go + Gin** — 고성능 REST API 코어(`catalog-api`); 지속적인 모니터링 워크로드에서 동시성과 처리량을 위해 선택.
- **TypeScript + React + Tailwind(Vite)** — 실시간 업데이트가 가능한 반응형 `catalog-web` UI.
- **WebSocket** — 백엔드 허브와 UI 간의 실시간 데이터 동기화.
- **SQLCipher(암호화된 SQLite)** — 저장 시 암호화된 메타데이터 저장소; `digital.vasic.database`를 통해 SQLite/PostgreSQL 이중 지원.
- **SMB/FTP/NFS/WebDAV 클라이언트** — `digital.vasic.filesystem`을 통한 다중 프로토콜 수집.
- **외부 메타데이터 API(TMDB, IMDB, TVDB, MusicBrainz, Spotify, Steam)** — 강화 기능을 위한 제공업체 플러그인.
- **Prometheus + OpenTelemetry** — `digital.vasic.observability`를 통한 메트릭/트레이싱.
- **Docker / 빌더 컨테이너** — 재현 가능한 빌드(Tauri/Rust는 `catalogizer-builder`를 통해 라우팅).
- **Redis** — `digital.vasic.cache`/`ratelimiter`를 통한 캐싱/요율 제한.
- **S3 / Google 클라우드 스토리지** — 클라우드 동기화 및 체크포인트 저장.

