---
site: milosvasic.ru
type: personal-site
title: Miloš Vasić — AI Engineer
tagline: I build AI development systems — and the discipline that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Miloš Vasić

## 히어로

**AI 엔지니어로서 검증 가능한 AI 개발 시스템을 구축합니다.**

제가 만드는 것은 AI 엔지니어링의 핵심 부분으로, 단순한 인상적인 데모와 신뢰할 수 있는 제품을 가르는 요소입니다. 바로 멀티 프로바이더 LLM 인프라(한 곳의 프로바이더가 다운되어도 시스템이 유지됨), 작업을 지속적으로 관리하는 자율 에이전트와 오케스트레이션, 그리고 AI 시스템이 제 기능을 제대로 수행하는지 확인하는 거버넌스와 품질 보증 계층입니다. 대규모 언어 모델을 실제로 출시 가능한 제품으로 만드는 것은 대부분 '규율’의 문제이며, 저는 바로 그 규율에 특화되어 있습니다. 제 지향점은 단 하나의 원칙입니다—실제 사용자가 사용할 수 있고, 그 증거가 확보된 경우에만 기능이 완성되었다고 간주합니다.

## 요약

주로 **Go** 분야에서 작업하며, 필요에 따라 **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift**, **Shell** 등을 다룹니다. 제가 가장 중요하게 생각하는 것은 작업의 *구조*입니다. 즉, 일회성 앱의 집합체가 아니라 수십 개의 작은 모듈로 구성된 '함대’와 같은 대규모 제품입니다. 각 모듈은 독립적으로 테스트되며, 느슨하게 결합되어 있고, Git 서브모듈을 통해 공통 엔지니어링 **Constitution**를 상속받습니다. 이러한 단일한 아키텍처 선택이 전체 작업의 가치를 배가시킵니다. 수정 사항과 개선 사항은 한 번에 모든 제품에 전파되며, 새로운 제품은 이미 검증된 구성 요소로 조립됩니다. 또한 모든 광고된 기능은 단순한 주장이 아니라 증거를 생성하는 테스트로 뒷받침됩니다. 이는 한 사람이 대규모로 신뢰할 수 있는 엔지니어링을 구축하는 방법입니다. 이 페이지는 이러한 개요에서 시작해 개별 프로젝트로 이어지며, 각 프로젝트는 해당 제품 페이지로 연결됩니다.

## 제 작업 방식 — 거버넌스와 품질 보증 우선

제품 이전에, 이를 뒷받침하는 규율부터:

- **HelixConstitution** — 140개 이상의 저장소에 걸쳐 Git 서브모듈로 배포되는 보편적이고 상속 가능한 엔지니어링 규칙집을 유지합니다. 이는 허위 진술 방지 증거 게이트, 오탐지 방지, 데이터/호스트 안전성, 커버리지 규칙 등을 명문화한 것입니다. 프로젝트에서는 이를 강화할 수는 있지만 약화시킬 수는 없으며, 각 거버넌스 게이트는 해당 게이트 자체가 작동함을 증명하는 변이 테스트와 짝을 이룹니다. → HelixConstitution 제품 페이지 보기.
- **HelixQA** — 허위 진술을 방지하는 품질 보증 오케스트레이션을 구축합니다. 이는 서면 테스트 뱅크와 완전 자율적인 LLM 및 비전 기반 QA 세션을 Android, Android TV, 웹, 데스크톱에서 실행하며, 런타임 증거가 확보된 경우에만 PASS로 평가됩니다. → HelixQA 제품 페이지 보기.

## Helix 제품군 전반에 걸친 제 작업

Helix 라인은 AI 개발 라이프사이클 전반에 걸쳐 있습니다. 우선순위 순으로:

- **HelixTrack** — 자유 세계의 JIRA 대체 제품; Helix-Track 라인의 플래그십.
- **HelixAgent** — 멀티 라운드 모델 토론과 검증 기반 프로바이더 선택을 지원하는 앙상블 LLM 서비스.
- **HelixCode** — SSH로 관리되는 워커에 작업을 분산 처리하는 분산형 AI 개발 플랫폼(자동 체크포인트/롤백 지원).
- **HelixLLM** — HTTP/3를 통해 OpenAI 및 Anthropic 호환 API를 제공하는 6가지 모드를 지원하는 단일 바이너리(로컬 llama.cpp 추론 및 점수 기반 폴백 체인 포함).
- **HelixCluster** — 데이터센터 GPU부터 엣지 핸드헬드까지 AI 컴퓨팅을 위한 분산 운영체제.
- **LLMProvider** — 43개 프로바이더에 대한 단일 인터페이스(서킷 브레이커, 재시도, 헬스 체크 내장).
- **LLMOrchestrator** — 모든 헤드리스 CLI 코딩 에이전트를 위한 단일 제어 플레인.
- **LLMsVerifier** — 검증, 모니터링, 최적화: LLM/프로바이더/검증 메타데이터의 단일 진실 공급원.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** — 에이전트 메모리, 거버넌스 기반 에이전트 스킬, 스펙 기반 개발, AI 애플리케이션 구축, 검증된 도서 번역, 제로 트러스트 터미널, 연합형 Git, 무결점 OTA 업데이트, 셀프 호스팅 클라우드 게임.

콘텐츠

## 다양한 바식-디지털 유틸리티를 아우르는 나의 작업

내가 개발하고 유지 관리하는 프로덕션급 도구들(각각 상세 제품 페이지 보유):

- **Catalogizer** — 멀티 프로토콜(SMB/FTP/NFS/WebDAV/로컬) 지원, 암호화, 자가 호스팅 가능한 미디어 컬렉션 관리 도구. Go/Gin API 및 React UI 제공.
- **Courses-Creator** — 마크다운을 비디오 강의로 변환하는 파이프라인. 멀티 LLM 강화 기능, TTS, 데스크톱/모바일/웹 플레이어 지원.
- **VisionEngine** — 고전 컴퓨터 비전과 멀티 공급자 LLM 비전을 융합한 디커플드 Go 툴킷. UI 분석 및 내비게이션 그래프 구축에 활용.
- **DocProcessor** — 문서를 검증 가능한 기능 맵으로 변환하여 QA 자동화 지원(LLM 또는 휴리스틱 추출 방식).
- **Docs Chain** — 콘텐츠 해싱 기반 양방향 원자적 문서/DB 동기화 엔진.
- **Herald** — 자연어 기반 3단계 의도 해석을 통한 신뢰성 높은 멀티 채널 알림 시스템.
- **task_bridge** — 디커플드 양방향 태스크/보드 동기화 엔진(P1 스캐폴드; 동기화 로직 개발 중).
- **Vasic Digital 재사용 가능 모듈 스위트** — `digital.vasic.*` 인프라, AI 프리미티브, 가드레일 모듈의 "표준 라이브러리".

## 인프라 유산(Server Factory)

AI 라인 이전부터 구축한 나의 DevOps 도구 체인: **Mail Server Factory**(선언형 JSON → 완전 프로비저닝된 도커화 메일 서버, 439개 테스트 통과 및 깨끗한 SonarQube 게이트), 이를 기반으로 한 **Server Factory 코어 프레임워크**, VM 이미지 도구(**Qemu-Utils**, **Parallels-Utils**) 및 지원 서비스 팩토리.

## 한 줄로 요약

나는 '작동 확인' 체크마크를 제공하지 않습니다. 실제로 작동한다는 증거와 그 상태를 유지하는 거버넌스를 갖춘 AI 시스템을 제공합니다.

## 연락처

글로벌 시니어 AI/플랫폼 엔지니어링 역할에 관심 있습니다.

- **이메일:** [milos85vasic@gmail.com](mailto:milos85vasic@gmail.com) · [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [milos85vasic](https://github.com/milos85vasic)
- **텔레그램:** [@milos85vasic](https://t.me/milos85vasic)

