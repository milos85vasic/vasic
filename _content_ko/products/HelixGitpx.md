---
name: HelixGitpx
slug: helixgitpx
tier: helix-primary
order: 17
status: shipped
license: TBD
private: false
tech:
  - Go monorepo
  - Angular 19 + Nx
  - Kotlin Multiplatform + Compose
  - Kubernetes + Helm + Argo CD + Kustomize
  - OPA (Rego)
  - Docusaurus
  - Astro
  - mise
repos:
  - https://github.com/HelixDevelopment/HelixGitpx
diagrams:
  - Hub-and-spoke federation — one source-of-truth hub pushing to a ring of host logos (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit, GitFlic, GitVerse, Gitee, Forgejo, SourceHut).
  - Conflict-resolution flow — divergent mirrors → policy/AI resolver → reconciled single truth.
  - Delivery stack — Go platform + Angular web + KMP clients over a Kubernetes/Argo platform layer.
---

# HelixGitpx

**하나의 진실 원천, 모든 곳에 동기화 — 수십 개의 호스트에 걸친 연합 Git**

## 요약

HelixGitpx(Helix Git Proxy eXtended)는 하나의 진실 원천을 여러 업스트림 Git 호스트에 동기화하고, 불가피하게 발생하는 충돌을 정책 및 AI 지원 프로세스로 해결하는 연합 Git 프록시입니다. 현재 v1.0.0 GA 버전에 도달했습니다.

## 간략 설명

HelixGitpx는 수십 개 이상의 Git 호스트(GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit 등)에 하나의 진실 원천을 동기화하는 연합 Git 프록시로, 동기화 충돌을 정책 및 AI 지원 프로세스로 해결합니다. v1.0.0 GA 버전으로 출시되었습니다.

## 상세 설명

HelixGitpx("Helix Git Proxy eXtended")는 하나의 진실 원천을 여러 업스트림 Git 호스트에 동기화하고, 동일한 저장소가 여러 곳에 존재할 때 불가피하게 발생하는 충돌을 해결하는 연합 Git 프록시입니다. 지원하는 업스트림은 Git 생태계 전체를 아우르는 수준입니다: GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut, 그리고 일반적인 Git-over-HTTPS까지 포함됩니다. 단순한 `git push` 명령으로 수십 개의 원격 저장소에 푸시할 경우, 아예 실패하거나 더 나쁜 경우 각 미러가 조용히 동기화되지 않는 문제가 발생할 수 있습니다. 반면 HelixGitpx는 정책 및 AI 지원 해결 프로세스를 통해 이러한 분산을 하나의 권위 있는 진실 원천으로 조율합니다.

이 프로젝트는 v1.0.0 GA 버전에 이르렀으며, `m1-foundation`부터 `m8-ga`까지의 마일스톤이 태그되어 있습니다. 이는 기초부터 일반 공개까지 완전한 로드맵을 의미합니다. 이 프로젝트는 하나의 제품으로 세 가지 계층으로 구성되어 있습니다: 연합 엔진을 탑재한 Go 모노레포(플랫폼 및 18개 서비스, 코드 생성 및 스캐폴딩 도구); Angular 19 + Nx 웹 애플리케이션; 그리고 Kotlin-Multiplatform + Compose 클라이언트 셸로, 공유 코드 기반에서 안드로이드, iOS, 데스크톱에 네이티브 경험을 제공합니다. 플랫폼 배포는 Kubernetes의 핵심 요소인 Helm 차트, Argo CD 애플리케이션, Kustomize 오버레이, SQL, OPA 정책을 기반으로 하며, CI 파이프라인은 명시적인 디스패치 게이트로 보호되어 실수로 배포되는 일이 없습니다. 공개 문서는 Docusaurus 사이트(docs.helixgitpx.io)와 Astro 마케팅 사이트(helixgitpx.io)로 제공됩니다.

거버넌스는 엄격하며 헌법에 기반한 방식으로 운영됩니다. 이는 형식적인 절차가 아니라 프로젝트의 핵심 기능입니다. 프로젝트의 중추 문서는 Constitution로, 제2조에서는 *수정된 모듈별로 유형별 100% 테스트 커버리지*를 의무화하며, 모의 객체는 유닛 테스트에서만 허용되고 단 하나의 테스트도 건너뛰지 않도록 규정하고 있습니다. 모든 아티팩트 검증과 `go vet`, `go test`를 전체 워크스페이스에 걸쳐 실행하는 원샷 검증기가 있으며, 모든 푸시는 구성된 모든 업스트림으로 전파됩니다. 따라서 "미러가 동기화되어 있다"는 것은 시스템이 모든 커밋마다 강제하는 사항이지, 사람이 기억해야 할 체크리스트가 아닙니다.

## 개발 배경

여러 Git 호스트에 걸쳐 저장소를 일관되게 유지하는 작업은 취약하고 수동적이며, 분산된 미러를 조율하는 것은 어렵습니다. HelixGitpx는 이러한 다중 업스트림 미러링을 충돌 인식 기능으로 일급 시민으로 만들기 위해 개발되었습니다.

콘텐츠

## 왜 혁신적인가

기존의 "여러 리모트에 푸시하고 기도하기"라는 취약하고 수동적인 방식에서 벗어나, 하나의 신뢰할 수 있는 진실 공급원과 자동화된 정책 기반 AI 충돌 해결 체계를 갖춘 거버넌스형 연합 시스템으로 전환합니다. 또한 대부분의 도구가 조용히 무시하는 지역 플랫폼(GitFlic, GitVerse, Gitee)을 의도적으로 포함해, 중복성, 데이터 주권, 해당 생태계로의 접근이 더 이상 유지 관리 부담이 되지 않고 한 번 설정으로 구현 가능한 단일 기능이 됩니다.

## 혁신적인 점

- **광범위한 업스트림 지원** — GitHub, GitLab부터 GitFlic, GitVerse, Gitee와 같은 지역 플랫폼까지, 10여 개 이상의 Git 호스트를 하나의 프록시로 표준화.
- **정책 및 AI 기반 충돌 해결** — 분기가 발생하면 정책 엔진과 AI 리졸버가 자동으로 조정하며, 더 이상 사람이 수동으로 미러를 비교할 필요가 없음.
- **단일 진실 공급원 연합 시스템** — 모든 업스트림에 푸시하는 모델로, 하나의 신뢰할 수 있는 저장소가 진실 공급원이 되고 모든 호스트는 동기화된 미러로 유지.
- **엄격한 헌법 수준의 테스팅** — 100% 유형별 커버리지를 보장하는 7가지 테스트 유형으로, 한 번의 그린 스위트 스크립트로 검증되며 더 이상 신뢰에 의존하지 않음.

## 가장 큰 기술적 도전 과제와 해결 방법

- **다수의 업스트림 간 분기와 충돌.** 동일한 저장소가 여러 곳에 존재하면 두 호스트가 서로 다른 쓰기를 허용하는 순간부터 분기가 발생. 이를 해결하기 위해 단일 진실 공급원을 기준으로 정책 및 AI 기반 해결 흐름을 적용하고, 모든 업스트림에 동기화된 푸시를 통해 모든 미러가 하나의 진실로 수렴하도록 유지.
- **이질적인 Git 호스트에 대한 균일한 지원.** 각 호스트는 고유한 인증 방식, 특성, API을 가짐. `Upstreams/` 하위의 호스트별 설정 스크립트와 플랫폼 레이어를 통해 이러한 차이를 추상화하여, 새로운 호스트 추가가 재작성이 아닌 설정으로 가능.
- **모든 병합 전 정확성 검증.** 7가지 유형의 필수 테스트 매트릭스와 `verify-everything.sh` 원샷 게이트로 전체 검증 세트를 실행하며, 클러스터에 접근할 수 없을 때도 깔끔하게 중단되어 CI뿐만 아니라 로컬에서도 정확성을 입증 가능.

## 기술 스택

- **Go 모노레포** — 핵심 프록시 및 연합 엔진: 플랫폼과 18개의 서비스, 코드 생성 및 스캐폴딩을 하나의 저장소에 통합하여 전체 엔진이 단일 단위로 빌드 및 테스트.
- **Angular 19 + Nx** — 웹 애플리케이션으로, Nx가 대규모 프론트엔드에 필요한 모노레포 빌드/캐싱 구조 제공.
- **Kotlin Multiplatform + Compose** — 하나의 공유 코드베이스로 생성된 네이티브 Android, iOS, Desktop 클라이언트 셸로, 세 플랫폼이 세 가지 구현을 의미하지 않음.
- **Kubernetes + Helm + Argo CD + Kustomize** — 클라우드 네이티브 배포: Helm가 릴리즈를 패키징하고, Kustomize 오버레이가 환경별로 조정하며, Argo CD가 GitOps를 통해 클러스터 상태를 Git과 일치시킴.
- **OPA (Rego)** — 충돌 해결과 접근 제어를 위한 정책 코드로, 인가 결정이 선언적이고 감사 가능하도록 유지.
- **Docusaurus** — 공개 문서 사이트(docs.helixgitpx.io); **Astro** — 마케팅 사이트(helixgitpx.io)로, 각 도구가 콘텐츠 유형에 최적화됨.
- **mise** — 고정된 재현 가능한 툴체인으로, 모든 기여자와 CI 러너가 동일한 버전으로 빌드.

## 상태 및 정직성 고지

- **상태: 출고 완료.** 프로젝트의 README에는 v1.0.0 GA가 선언되어 있으며, `m1-foundation`부터 `m8-ga`까지의 마일스톤에 태그가 지정되어 있음. ("v1.0.0 GA"는 프로젝트 자체 README의 주장임.)
- **라이선스: 미확정.** GitHub 및 API 보고서에서는 `MIT`로 명시된 반면, README의 라이선스 섹션에는 Apache-2.0(코드) / CC-BY-SA-4.0(문서)으로 기재되어 있음 — 게시 전 실제 LICENSE 파일과 대조하여 확인 요망.
- 문서(docs.helixgitpx.io) 및 마케팅(helixgitpx.io) URL은 README를 기반으로 하며, 독립적으로 확인되지 않았음 — 실시간 상태 **미검증**.

**우선순위 등급:** Helix-주요.

