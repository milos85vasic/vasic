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

**메일 서버를 보스처럼 운영하세요 — JSON로 정의하고 어디서든 배포하세요.**

## 요약

Mail Server Factory는 프로덕션 환경에 바로 적용 가능한 자동화된 메일 서버 프로비저닝 도구입니다. 사용자는 간단한 JSON 설정 파일을 작성하면, 팩토리가 이를 해석해 대상 OS에 필요한 모든 설치 및 초기화를 수행하며, Docker 기반의 느슨하게 결합된 메일 스택을 12가지 연결 유형에 걸쳐 배포합니다.

## 간략 설명

Kotlin/Shell 도구로, JSON 설명을 완전 설치된 도커화된 메일 서버로 변환합니다. 12가지 연결 유형(SSH, Docker, Kubernetes, AWS SSM, Azure, GCP, Libvirt 등)을 지원하며, 완전한 보안 프레임워크와 25종의 Linux 배포판을 제공하고, 439개의 테스트를 모두 통과했습니다.

## 상세 설명

안정적이고 안전한 메일 서버를 구축하는 것은 시스템 관리자의 전통적인 통과의례이자, 동시에 가장 고통스러운 작업 중 하나입니다. Postfix, Dovecot, TLS 인증서, DNS 레코드, 방화벽 규칙, 그리고 배포판별 특이사항까지 모든 요소가 완벽하게 맞아떨어져야 하며, 단 하나의 설정 오류로 인해 메일이 묵묵히 반송되거나 오픈 릴레이가 될 수 있습니다. Mail Server Factory는 이러한 오랜 경험과 오류가 발생하기 쉬운 노하우를 소프트웨어로 구현한 도구입니다. 낯선 OS에서 각 구성 요소를 수동으로 설정하는 대신, 사용자는 원하는 결과를 간단한 JSON 문서로 작성하면 됩니다. 그러면 팩토리가 해당 JSON를 읽고 대상 운영체제에서 필요한 설치 및 초기화 단계를 정확히 실행하여, Docker 위에서 모든 구성 요소가 느슨하게 결합된 메일 스택을 구축합니다. 이러한 설계는 스택의 수평 확장성을 보장하며, 개별 구성 요소를 독립적으로 업그레이드하거나 교체할 수 있게 합니다. 또한 의도적으로 연결 방식에 구애받지 않도록 설계되어, 동일한 도구와 동일한 JSON로 로컬 머신, SSH를 통한 원격 호스트, Docker 또는 Kubernetes 런타임, AWS SSM / Azure 시리얼 콘솔 / GCP OS 로그인을 통한 클라우드 인스턴스, 또는 Libvirt를 통한 가상 머신 등 12가지 연결 유형 어디에든 동일한 선언형 설명을 배포할 수 있습니다.

서양(우분투, 데비안, 센트OS, 페도라, 알마Linux, 록키, 오픈수세), 러시아(ALT, 아스트라, 로사), 중국(오픈오일러, 오픈카일린, 딥인) 계열을 포함해 25종의 Linux 배포판을 지원하며, preseed/kickstart/cloud-init/autoyast를 통한 무인 설치와 테스트를 위한 QEMU 기반 VM 자동화가 가능합니다. 엔터프라이즈급 기능도 풍부합니다. AES-256-GCM 암호화, 강제 비밀번호 및 SSH 키 정책, 메일 포트(25/587/465/993/995)에 대한 자동 방화벽 설정, 인증서 검증 및 HSTS를 지원하는 TLS/SSL, 감사 로깅, RBAC 등이 포함됩니다. 운영 측면에서는 JVM 튜닝(G1GC), 카페인 캐싱, 커넥션 풀링, Prometheus 호환 메트릭스, 구조화 로깅, 핫 리로딩 설정, 시크릿 관리 등 다양한 기능을 제공합니다. 이 프로젝트는 439개의 테스트를 100% 통과했으며, SonarQube 품질 게이트도 깨끗하게 통과했습니다. Server-Factory 조직의 플래그십 프로젝트입니다.

## 왜 만들었는가

안전하고 운영 환경에 적합한 메일 서버를 구축하는 일은 오류가 발생하기 쉽고 운영체제에 따라 달라지는 것으로 악명이 높습니다. Mail Server Factory는 이러한 전문 지식을 선언형 JSON 모델과 실행 엔진에 담아, 정확하고 보안이 강화된 도커 기반 메일 스택을 지원되는 모든 타겟에서 수동으로 단계별 작업을 거치지 않고도 재현할 수 있도록 합니다.

## 혁신적인 이유

메일 서버 프로비저닝을 전문가만 할 수 있는 며칠이 걸리는 완벽해야 하는 고된 작업에서, 설정 파일 작성이라는 단순한 행위로 바꿔줍니다. 그리고 이 행위를 12가지 연결 유형과 25개 Linux 배포판에서 사용할 수 있도록 이식 가능하게 만들며, 기업 수준의 보안 기본 설정을 즉시 적용합니다. 그 결과는 재현 가능하고 *검증 가능*합니다. 동일한 JSON는 매번 동일한 보안 스택을 생성하며, 프로젝트의 439개 테스트 통과 기록과 깨끗한 SonarQube 검증 절차는 작업을 수행하는 엔진 자체의 신뢰성을 보장합니다. 단순한 명성에 의존하지 않습니다.

## 혁신적인 점

- 선언형 JSON → 타겟 OS에서 해석되어 설치/초기화 수행.
- 하나의 도구로 지원되는 12가지 연결 유형(로컬, SSH, Docker, Kubernetes, AWS SSM, Azure, GCP, Libvirt 등).
- 25개 배포판 지원 및 무인 설치(preseed/kickstart/cloud-init/autoyast) 및 QEMU 자동화.
- 느슨하게 결합된 도커화된 스택으로 독립적인 확장/업그레이드 가능.

## 도전 과제와 해결 방안

- **운영체제/배포판 이질성:** 배포판별 레시피, 무인 설치 구성, QEMU 기반 크로스 배포판 테스트로 해결.
- **다양한 배포 타겟 지원:** 12가지 플러그형 연결 유형을 공통 설치 엔진 하에 통합하여 해결.
- **기본 보안 강화:** AES-256-GCM, 강제 키/비밀번호 정책, 자동 방화벽 규칙, TLS/HSTS로 해결.
- **정확성에 대한 신뢰:** 439개 테스트 스위트(100% 통과)와 깨끗한 SonarQube 검증 절차로 해결.

## 기술 스택(이유와 방법)

- **Kotlin** — 팩토리 엔진 및 설치 단계 로직(179K 바이트; Kotlin 2.0.21).
- **Shell** — 프로비저닝 스크립트, ISO/QEMU 관리자, OS 자동화(용량상 주요 구성 요소).
- **Docker** — 배포된 느슨하게 결합된 메일 스택의 런타임.
- **QEMU** — 크로스 배포판 설치 및 테스트를 위한 VM 자동화.
- **JSON** — 사용자가 직접 작성하는 선언형 설정 형식.
- **Gradle 8.14.3 / Java 17** — 빌드 도구 체인.
- **Caffeine** — 다중 지역 캐싱; **G1GC 튜닝 JVM**으로 성능 최적화.
- **Prometheus 호환 메트릭** — 모니터링; Grafana/ELK 준비 완료.
- **Sieve** — 메일 필터링 규칙(언어 통계상 작은 비중).

> 참고: GitHub는 Server-Factory 조직 내 포크 저장소를 의미합니다. AI 제품군보다 앞서 개발되었으며, AI 유틸리티가 아닌 성숙한 DevOps/프로비저닝 플래그십으로 소개됩니다.

