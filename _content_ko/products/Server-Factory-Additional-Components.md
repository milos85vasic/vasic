---
name: Server Factory — Additional Components
slug: server-factory-additional-components
tier: serverfactory-tertiary
order: 33
status: mixed / early-stage (service factories are placeholder-documented — UNVERIFIED; Definitions & Utils are supporting data/tooling)
license: UNVERIFIED
private: false
tech:
  - Kotlin (service factories, on Core Framework)
  - Shell (Utils, Definitions packs)
  - Gradle
  - Docker (target runtime)
  - SSH / OpenSSH (Utils bootstrap)
  - SonarQube
repos:
  - https://github.com/Server-Factory/Web-Service-Factory
  - https://github.com/Server-Factory/SonarQube-Factory
  - https://github.com/Server-Factory/Caching-Proxy-Factory
  - https://github.com/Server-Factory/Docker-Definitions
  - https://github.com/Server-Factory/Stack-Definitions
  - https://github.com/Server-Factory/Software-Definitions
  - https://github.com/Server-Factory/Utils
diagrams:
  - Family tree (Core Framework → {Mail, Web, SonarQube, Caching-Proxy} factories)
  - Data-vs-engine split (Definitions packs feeding the factory execution engine)
  - Utils spotlight (init_ssh_access.sh bootstrap flow)
  - Maturity legend distinguishing flagship (Mail) from early-stage service factories
---

**Server Factory 프로비저닝 툴체인의 보조 구성 요소들**

## 개요

Mail Server Factory와 코어 프레임워크를 넘어, Server-Factory 조직에는 여러 작은 구성 요소들이 포함되어 있습니다. 서비스별 '팩토리'(웹 서비스, SonarQube, 캐싱 프록시), 선언형 설정 팩(Docker/스택/소프트웨어 정의), 그리고 공유 유틸리티 등이 그것입니다. 이 통합 페이지는 이들을 완전한 제품으로 포장하기보다는 초기 단계이거나 문서화가 미흡한 부분까지 솔직하게 다루고 있습니다.

## 간략 설명

Server Factory를 지원하는 레포지토리 그룹으로, Web-Service-Factory, SonarQube-Factory, Caching-Proxy-Factory(서비스별 프로비저닝 도구, 대부분 초기 단계), Docker/Stack/Software-Definitions(프레임워크에서 사용하는 선언형 설정 팩), 그리고 Utils(SSH 접근 도우미 및 일반 툴링)가 있습니다. 모두 코어 프레임워크를 기반으로 합니다.

## 상세 설명

이 페이지는 나머지 Server-Factory 레포지토리들을 통합하여 설명합니다. 개별적으로 보면 대부분 규모가 작거나 의도적으로 문서화가 부족한 경우가 많아, 각각을 완성된 제품처럼 소개하는 것은 성숙도를 과장하는 셈이기 때문입니다. 이들은 크게 세 가지 그룹으로 나뉩니다.

**서비스 팩토리**는 Mail Server Factory 패턴을 다른 서버 역할에 적용한 것으로, **Caching-Proxy-Factory**("자체 캐싱 프록시 서버 구동")는 캐싱 프록시, 자체 서명 인증서, 보안 인증서 발급 HTTP 엔드포인트를 주요 기능으로 소개합니다. **SonarQube-Factory**("자체 SonarQube 서버 구동")는 소프트웨어 개발 용도로 설계되었으며, **Web-Service-Factory**는 웹사이트나 마이크로서비스 같은 배포 대상을 인스턴스화하고 구성하는 웹 서버를 제공합니다. 세 가지 모두 코어 프레임워크를 기반으로 한 Kotlin 프로젝트이지만, 공개된 README는 대부분 임시 문서("호환성, 사양, 설정, 사용법 등 추후 업데이트")에 불과해 명시된 기능 외의 실제 성능은 **확인되지 않았습니다**.

**정의 팩**인 **Docker-Definitions**, **Stack-Definitions**, **Software-Definitions**은 프레임워크가 Docker 이미지, 스택, 소프트웨어를 빌드/배포하는 방법을 정의하는 선언형 설정 레포지토리입니다. 이들은 애플리케이션이 아닌 버전 고정된 데이터 팩입니다.

**Utils**는 이 툴체인군을 위한 일반 도우미 기능을 제공하며, `init_ssh_access.sh` 스크립트를 포함합니다. 이 스크립트는 SSH 키를 생성하고 원격 호스트에 설치하여 후속 프로비저닝을 위한 비밀번호 없는 루트 접근을 가능하게 합니다. 이러한 구성 요소들이 모여 Mail Server Factory를 중심으로 한 프로비저닝 툴체인을 완성합니다.

## 개발 배경

Server Factory 모델은 일반화를 목표로 설계되었습니다. 선언형 기술서만으로 메일 서버를 프로비저닝할 수 있다면, 동일한 엔진으로 웹 서버, 캐싱 프록시, 코드 품질 서버도 프로비저닝할 수 있어야 합니다. 재사용 가능한 정의 팩과 공유 유틸리티를 활용해 역할별 맞춤 로직 없이도 가능하도록 한 것입니다. 이 레포지토리들은 바로 그러한 일반화의 과정으로, 검증된 패턴을 새로운 서버 유형으로 확장하는 시도입니다. 이들의 가치는 모델의 확장성을 보여주는 증거로, 성숙도는 제각각이며 이 페이지는 어떤 부분이 방향성 제시인지, 어떤 부분이 완성된 상태인지를 명확히 밝히고 있습니다.

콘텐츠

## 왜 혁신적인 변화인가 (신중하게 평가된 관점)

이 세트들은 Core Framework가 다양한 서버 유형에 걸쳐 재사용 가능함을 보여주며, 선언적 데이터(Definitions)와 실행(factories)을 분리합니다. 개별적으로 서비스 팩토리는 초기 단계에 있으며, 완성된 제품이 아닌 방향성으로 제시되어야 합니다.

## 혁신적인 점

- 메일/웹/캐싱 프록시/SonarQube 역할에 걸쳐 일반화된 하나의 프로비저닝 프레임워크.
- 실행 엔진과 분리된 선언적 Definitions 팩(Docker/Stack/Software).
- 팩토리 간 재사용되는 공유 유틸리티(예: 원클릭 무비밀번호 SSH 부트스트랩).

## 도전 과제 및 해결 방안

- **서버 역할 간 하나의 엔진 재사용:** 각 팩토리를 Core Framework 기반으로 구축하여 해결.
- **설정과 코드 분리:** Definitions 저장소를 버전 고정된 데이터 팩으로 활용하여 해결.
- **(미검증):** 서비스 팩토리의 README는 임시 문서이며, 공개 문서로는 구현 완결성을 검증할 수 없음 — 초기 단계로 제시.

## 기술 스택 (이유 및 방법)

- **Kotlin** — Web-Service-Factory, SonarQube-Factory, Caching-Proxy-Factory (Core Framework 기반).
- **Shell** — 유틸리티 및 Definitions 팩(스크립트/설정).
- **Gradle** — `./gradlew test` 팩토리 간 빌드/테스트 흐름.
- **Docker** — Docker-Definitions로 기술된 대상 런타임.
- **SSH / OpenSSH** — 유틸리티의 무비밀번호 접근 부트스트랩.
- **SonarQube** — SonarQube-Factory가 프로비저닝하는 서버(Mail Server Factory가 클린 게이트로 보고).

> 정직성 고지: 대부분의 저장소는 조직 내 포크이며, 서비스 팩토리는 임시 문서로 작성되어 헌법 §11.4.6에 따라 미검증으로 표시됨. Mail Server Factory 및 Core Framework보다 명확히 하위 등급으로 분류.

