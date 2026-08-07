---
name: Parallels-Utils
slug: parallels-utils
tier: serverfactory-tertiary
order: 32
status: active (niche, macOS-specific Shell/Python toolkit)
license: UNVERIFIED
private: false
tech:
  - Shell (~5.3K bytes)
  - Python 3 (~3K bytes)
  - Parallels (macOS)
  - Settings files (.settings)
repos:
  - https://github.com/Server-Factory/Parallels-Utils
diagrams:
  - Image lifecycle (build → compress → publish → retrieve → run)
  - One provider endpoint → many workstations pulling the same image matrix
  - Settings-file map (location/provider/sync) feeding the scripts
---

**모든 기기에서 Parallels VM 이미지를 압축, 배포, 재사용하세요.**

## 요약

Parallels-Utils는 Parallels(macOS) 가상 머신 이미지를 관리하는 Server Factory 도구 키트입니다. 개발 및 테스트에 사용되는 이미지 "매트릭스"를 압축하고 동기화하며, 원격 엔드포인트로 배포하고 여러 워크스테이션이나 서버에서 검색 및 실행할 수 있습니다. 독립적으로 사용하거나 Server Factory의 일부로 활용할 수 있습니다.

## 간략 설명

macOS에서 Parallels VM 이미지의 라이프사이클을 관리하는 Shell/Python 도구 키트입니다. Parallels 이미지를 압축하고 동기화하며 원격 엔드포인트로 배포하고, 여러 컴퓨터에서 검색 및 실행할 수 있습니다. 간단한 설정 파일로 제어되며, 독립적으로 사용하거나 Server Factory 내에서 활용할 수 있습니다.

## 상세 설명

Parallels-Utils는 macOS 기반 개발에서 실질적인 DevOps 문제를 해결합니다. 팀은 개발 및 테스트에 사용되는 다양한 운영체제/구성으로 이루어진 Parallels 가상 머신 "매트릭스"를 구축하며, 이러한 이미지를 여러 기기에서 일관되게 압축, 배포, 검색, 실행해야 합니다. 이 도구 키트는 바로 이러한 라이프사이클을 제공합니다. 동기화 메커니즘은 Parallels 이미지를 압축하고 동기화 상태를 유지하며, 배포 메커니즘은 이미지를 원격 엔드포인트로 업로드합니다. 또한 검색 메커니즘을 통해 모든 워크스테이션이나 서버가 배포된 이미지를 가져와 VM으로 실행할 수 있습니다.

설정은 의도적으로 단순하고 파일 기반으로 이루어집니다. `image_location.settings`는 파일 시스템에서 이미지가 저장되는 위치를 정의하고, `image_provider.settings`는 배포된 이미지의 기본 URL를 정의하며, `image_sync.sh`는 업로드 스크립트를 정의합니다. 예제 파일은 `Examples` 디렉터리에 포함되어 있습니다. 운영자는 `publish_images.sh`로 이미지를 배포하고 `run.sh`로 VM을 실행합니다. 해당 macOS 버전에 맞는 Parallels와 Python 3이 필요합니다.

이 도구 키트는 이중 용도로 설계되었습니다. 더 큰 Server Factory 프로젝트의 일부로 작동할 수도 있고, 완전히 독립적으로 사용할 수도 있어 조직의 디커플링 철학을 반영합니다. 심지어 짧은 동영상 튜토리얼 링크도 제공합니다. Server-Factory 제품군의 일원으로, Qemu-Utils(Linux/QEMU 대응 버전)를 보완하여 macOS/Parallels와 크로스 플랫폼/QEMU 백엔드 모두에서 VM 이미지 관리를 지원합니다.

## 개발 배경

팀 내에서 일관된 VM 개발/테스트 환경을 공유하는 것은 번거로운 작업입니다. 이미지 용량이 크고 모든 기기에서 동일한 매트릭스가 필요하기 때문입니다. Parallels-Utils는 압축, 배포, 검색을 자동화하여 표준화된 Parallels VM 세트를 어디서나 재현할 수 있도록 합니다.

## 혁신적인 이유

무겁고 다루기 힘든 Parallels 이미지를 배포 및 동기화 가능한 아티팩트 세트로 변환하여, 어떤 기기에서도 가져와 실행할 수 있게 합니다. 따라서 표준 개발/테스트 환경은 각 엔지니어가 수동으로 재구축하는 대상이 아니라, 간단히 가져올 수 있는 대상이 됩니다. 이를 위해 간단한 설정 파일만으로 구성되며, Server Factory의 나머지 부분에 의존하지 않아 조직의 디커플링 철학을 충실히 따릅니다. 독립적으로 유용하면서도 더 큰 도구 체인 내에서도 잘 작동하는 도구입니다.

내용

## 혁신적인 점

- 개발 및 테스트용 Parallels 이미지 "매트릭스"의 압축 및 동기화 기능
- 여러 컴퓨터에서 재사용 가능한 이미지를 위한 게시/검색 워크플로우
- 기본 제공 예제와 함께 제공되는 설정 파일 기반 구성(위치/공급자/동기화)
- 독립 실행형 또는 Server Factory 구성 요소로 활용 가능

## 도전 과제 및 해결 방안

- **대용량 이미지 배포**: 압축과 원격 엔드포인트로의 게시 및 검색 워크플로우로 해결
- **다양한 기기에서의 재현성**: 공급자/위치 설정을 통해 모든 호스트가 동일한 이미지 세트를 인식하도록 해결
- **사용 편의성**: 간단한 `publish_images.sh` / `run.sh` 스크립트와 예제 설정 파일로 해결

## 기술 스택(이유 및 방법)

- **Shell** — 게시/실행/동기화 스크립트(주 언어, 약 5.3K 바이트)
- **Python 3** — 지원 도구(필수 종속성, 약 3K 바이트)
- **Parallels(macOS)** — 관리 대상 가상화 백엔드
- **설정 파일(`.settings`)** — 위치/공급자/동기화에 대한 선언적 구성

> 참고: GitHub는 Server-Factory 조직 내 포크 저장소를 의미합니다. macOS 전용으로, AI와는 관련이 없습니다.

