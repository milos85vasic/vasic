---
doc: cover-letter
title: Cover Letter — Miloš Vasić, AI Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: General-purpose letter. Placeholders in [brackets] are to be filled per application; no employer, project outcome, or metric is fabricated.
---

# Motivaciono pismo

Poštovani [Rukovodilac tima / Tim],

Pišem Vam kako bih se prijavio za poziciju [uloga] u [kompanija]. Ja sam AI inženjer koji gradi ono što je neugledno, ali nosivo u AI softveru: LLM infrastrukturu, autonomne agente i orkestraciju, kao i slojeve za kontrolu kvaliteta i upravljanje koji ih čine pouzdanim u produkciji.

Tokom proteklih godina dizajnirao sam i isporučio porodicu međusobno povezanih proizvoda za razvoj AI. Linija Helix obuhvata ceo životni ciklus — HelixAgent (ansambl LLM servisa u kojem više modela raspravlja i isporučuje odgovor na koji se svi slažu), HelixCode (distribuiranu platformu za razvoj AI koja deli zadatke među radnicima upravljanim od strane SSH sa mogućnošću checkpoint/rollback), HelixLLM (jedan binarni fajl koji služi za inferenciju kompatibilnu sa OpenAI i Anthropic preko HTTP/3), kao i trio LLM infrastrukture: LLMProvider, LLMOrchestrator i LLMsVerifier (jedan interfejs za 43 provajdera, kontrolnu ravan za headless CLI agente i verifikacioni izvor istine). Oko svega toga izgradio sam alate za profesionalnu upotrebu kao što su Catalogizer (višeprotokolni, enkriptovani sistem za upravljanje medijima) i Courses-Creator (AI pipeline za konverziju markdown-a u video kurseve), a sve to stoji na floti malih, odvojenih i nezavisno testiranih Go i Kotlin Multiplatform modula.

Ono što, po mom mišljenju, izdvaja moj rad jeste disciplina koju ozbiljno shvatam: **inženjering bez blefiranja**. Održavam univerzalni inženjerski Constitution, distribuiran kao Git submodul i nasleđen u floti od preko 140 repozitorijuma, koji mehanički nameće jedno pravilo — funkcionalnost nije gotova kada testovi prođu, već kada je stvarni korisnik može da koristi i kada postoje dokazi koji to potvrđuju. U kombinaciji sa tim koristim HelixQA, QA orkestrator protiv blefiranja koji pokreće autonomne sesije LLM i računarskog vida na Androidu, Vebu i Desktop platformama i odbija da dodeli status PROŠAO bez snimka ekrana, logcat-a ili video zapisa. Gradeći sisteme koji ne samo da *izgledaju* gotovo, već su *dokazivo* takvi.

Tehnički, uglavnom radim u Go, sa Kotlin/KMP, TypeScript/React, Python, Swift i Shell, na REST/gRPC/HTTP/3 servisima, PostgreSQL/SQLite/Redis/ClickHouse slojevima podataka i Docker/Kubernetes/Prometheus operacijama. Ugodno mi je da posedujem sistem od apstrakcije provajdera i preuzimanja podataka sve do tragova dokaza koji potvrđuju njegovu funkcionalnost.

Bio bih srećan da tu kombinaciju — duboko AI sistemsko inženjerstvo i autentičnu, proverljivu disciplinu kvaliteta — donesem u [kompanija]. Hvala na razmatranju; moj portfolio i javni repozitorijumi dostupni su na milosvasic.ru i vasic.digital.

Srdačno,
Miloš Vasić
milos85vasic@gmail.com

