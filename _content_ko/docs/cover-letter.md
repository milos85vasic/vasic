---
doc: cover-letter
title: Cover Letter — Miloš Vasić, AI Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: General-purpose letter — no employer, project outcome, or metric is fabricated. The published edition is placeholder-free; per-application tailoring (specific role/company) is done from this master in a separate, unpublished copy.
---

# 자기소개서

채용 담당자님께,

AI 시스템 구축에 중점을 둔 엔지니어링 직무에 관심을 표명하고자 이 글을 씁니다. 저는 AI 엔지니어로, AI 소프트웨어의 겉으로 드러나지 않지만 핵심적인 하중을 지탱하는 부분—LLM 인프라, 자율 에이전트와 오케스트레이션, 그리고 이를 프로덕션 환경에서 신뢰할 수 있게 만드는 QA 및 거버넌스 레이어—을 구축하는 일을 해왔습니다.

지난 몇 년간 저는 서로 연결된 AI 개발 제품군을 설계하고 출시했습니다. Helix 제품군은 전체 라이프사이클을 아우르며, HelixAgent(여러 모델이 토론하고 합의한 답변을 제공하는 앙상블 LLM 서비스), HelixCode(SSH로 관리되는 워커에 작업을 분산하는 분산형 AI 개발 플랫폼), HelixLLM(HTTP/3를 통해 OpenAI 및 Anthropic 호환 추론을 제공하는 단일 바이너리), 그리고 LLM 인프라 트리오인 LLMProvider, LLMOrchestrator, LLMsVerifier(43개 제공업체를 아우르는 단일 인터페이스, 헤드리스 CLI 에이전트를 위한 컨트롤 플레인, 검증의 진실 공급원) 등으로 구성됩니다. 이 제품들을 중심으로 Catalogizer(다중 프로토콜 암호화 미디어 관리)와 Courses-Creator(AI 마크다운-비디오 강의 파이프라인) 같은 프로덕션급 도구를 구축했으며, 이들은 모두 작고 독립적이며 개별 테스트가 가능한 Go 및 Kotlin Multiplatform 모듈로 이루어진 플랫폼 위에서 작동합니다.

제 작업의 차별점은 제가 진지하게 여기는 원칙, 바로 **블러핑 없는 엔지니어링**에 있습니다. 저는 140개 이상의 저장소에 걸쳐 상속되는 범용 엔지니어링 Constitution(깃 서브모듈로 배포)을 유지하며, 한 가지 규칙을 기계적으로 강제합니다—테스트가 통과했다고 기능이 완성된 것이 아니라, 실제 사용자가 사용할 수 있고 그 증거가 확보되었을 때 비로소 완성된 것입니다. 이를 보완하기 위해 HelixQA라는 블러핑 없는 QA 오케스트레이터를 도입해 안드로이드, 웹, 데스크톱 환경에서 자율 LLM 및 컴퓨터 비전 세션을 실행하며, 스크린샷, 로그캣, 또는 영상 증거가 없으면 PASS 판정을 내리지 않습니다. 저는 단순히 완성된 것처럼 보이는 시스템이 아니라, 실제로 완성되었다고 입증할 수 있는 시스템을 구축합니다.

기술적으로는 주로 Go를 사용하며, Kotlin/KMP, TypeScript/React, Python, Swift, Shell 등을 활용해 REST/gRPC/HTTP/3 서비스, PostgreSQL/SQLite/Redis/ClickHouse 데이터 레이어, 그리고 Docker/Kubernetes/Prometheus 운영 환경에서 작업합니다. 제공업체 추상화와 검색부터 시스템이 실제로 작동한다는 증거를 남기는 과정까지, 시스템 전체를 책임지는 데 익숙합니다.

이러한 조합—심층적인 AI 시스템 엔지니어링과 검증 가능한 품질 원칙—을 귀사에 aport하고 싶습니다. 관심 가져주셔서 감사합니다. 제 포트폴리오와 공개 저장소는 milosvasic.ru와 vasic.digital에서 확인하실 수 있습니다.

감사합니다.
Miloš Vasić
milos85vasic@gmail.com

