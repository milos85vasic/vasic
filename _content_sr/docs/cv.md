---
doc: cv
title: Curriculum Vitae — Miloš Vasić
role: AI Engineer / Software Engineer
contact:
  email: milos85vasic@gmail.com
  site: https://milosvasic.ru
  company: https://vasic.digital
  github_orgs:
    - https://github.com/vasic-digital
    - https://github.com/HelixDevelopment
    - https://github.com/Server-Factory
sources:
  - _analysis/content-briefs/*.md
  - _analysis/content-briefs/_TECH-STACK.md
note: Skills and projects are evidence-based (repository READMEs + analysis). Experience and Education are sourced verbatim from the candidate's own verified record at milosvasic.ru/README.md — real employers, roles, and dates; nothing fabricated (Constitution §11.4.6).
---

# Miloš Vasić

**AI inženjer — LLM infrastruktura, autonomni agenti i upravljanje koje ih čini pouzdanim.**

- Email: milos85vasic@gmail.com
- Web: https://milosvasic.ru · https://vasic.digital
- GitHub: vasic-digital · HelixDevelopment · Server-Factory

---

## Sažetak

AI/softverski inženjer koji gradi sisteme za razvoj AI od početka do kraja — od LLM infrastrukture sa više provajdera i autonomnih agenata do slojeva za kontrolu kvaliteta i upravljanje koji ih drže pod nadzorom. Ne isporučujem demo verzije; isporučujem platforme. Više od 15 godina profesionalnog inženjeringa (od 2009. godine) u oblasti mobilnih SDK-ova, integracije hardvera u realnom vremenu i distribuiranih backend sistema sada se usredsređuje na jedan cilj: učiniti autonomni razvoj AI pouzdanim na velikoj skali.

Projektujem flote, a ne monolitne sisteme — velike aplikacije koje se oslanjaju na desetine malih, odvojenih i nezavisno testiranih modula, od kojih svaki nasleđuje zajednički inženjerski Constitution i proverava se kroz disciplinu kontrole kvaliteta zasnovanu na dokazima, bez varanja. Primarni jezik je Go, uz Kotlin/KMP, TypeScript/React, Python, Swift i Shell. Vođeno načelo, koje se primenjuje mehanički, a ne samo deklarativno: funkcionalnost je gotova tek kada je stvarni korisnik može koristiti i kada postoje prikupljeni dokazi koji to potvrđuju.

**Šta donosim na sto:** sposobnost da se AI mogućnost prevede iz istraživačke ideje u upravljani, samoverifikujući sistem prilagođen produkciji — LLM rutiranje koje dokazuje da svaki model zaista funkcioniše pre nego što mu se poveri, agenti koji raspravljaju i postižu konsenzus umesto da nagađaju, slojevi za memoriju i RAG koji ne gube kontekst, i čitav ekosistem povezan tako da „testovi su zeleni" nikada ne znači „funkcionalnost je pokvarena".

## Ključne kompetencije

- **AI / LLM sistemi:** apstrakcija LLM infrastrukture sa više provajdera (40+ provajdera), integracija MCP alata, RAG, vektorske baze podataka i embedinzi, orkestracija agenata (bezglavi CLI agenti, grafovski tokovi poslova, višestruke runde debate/konsenzusa), planiranje (HiPlan/MCTS/Tree-of-Thoughts), LLMOps, benchmarking (SWE-bench/HumanEval/MMLU), verifikacija LLM, odbrambeni LLM sigurnosni mehanizmi, računarski vid + LLM-vid.
- **Backend inženjering:** Go (Gin), gRPC + Protobuf, HTTP/3 (QUIC), WebSockets, distribuirani sistemi (uključujući formalne TLA+ specifikacije), visokopropusni REST servisi i konkurentni radnici.
- **Podaci:** PostgreSQL, SQLite, SQLCipher (šifrovanje u mirovanju), Redis, Neo4j, ClickHouse, objekti skladištenja (MinIO/S3/GCS/Azure).
- **Frontend / cross-platform:** TypeScript/React (Tailwind, Redux Toolkit, i18next), Angular, Electron, React Native, Kotlin Multiplatform, Android/Android TV (Kotlin), iOS (Swift), Tauri/Rust.
- **Infra / DevOps:** Docker i Compose, Kubernetes + Helm, Prometheus + Grafana, OpenTelemetry, QEMU/Libvirt/Parallels; CI/CD putem GitHub Actions, Gradle, Make.
- **Kontrola kvaliteta / inženjering kvaliteta:** kontrola kvaliteta zasnovana na dokazima bez varanja (HelixQA), okviri za izazove sa mutacionim kapijama, `go test -race`, vizuelno-regresiono testiranje, testiranje uređaja preko ADB-a, SonarQube, skeniranje sigurnosti (semgrep/gosec/trivy/snyk/gitleaks/nancy).
- **Upravljanje inženjeringom:** Constitution kao podmodul; kapije za nasleđivanje i propagaciju; disciplina dokumentacije i pokrivenosti kroz flotu od 140+ repozitorijuma.


## Izabrani projekti

### Upravljanje i kontrola kvaliteta
- **HelixConstitution** — univerzalni inženjerski priručnik distribuiran kao Git podmodul i nasleđen u preko 140 repozitorijuma: inženjerski zakon isporučuje se i verzionira tačno kao kod. Jedno ažuriranje podmodula unapređuje pravila za ceo sistem, a propagacioni filteri doslovno pretražuju svaki repozitorijum koji ga koristi u potrazi za obaveznom klauzulom — svaki filter uparen je sa mutacionim metatestom koji dokazuje da sam filter nije lažan. Pretvara „najbolje prakse koje ljudi žele da prate" u nasleđeno, proverljivo, mehanički sprovodivo pravo bez prevare.
- **HelixQA** — orkestracija kontrole kvaliteta bez prevare (Go) zasnovana na jednom nepopustljivom pravilu: mera nije „testovi prolaze", već „korisnici mogu da koriste funkciju". Pokreće pisane YAML test-banke *i* potpuno autonomne LLM-i-vizuelne sesije kontrole kvaliteta koje otvaraju stvarnu aplikaciju, proveravaju svaku dokumentovanu funkciju, tragaju za nedokumentovanim greškama na Androidu/Android TV/Webu/desktopu i odbijaju da ocene prolazak bez snimljenih dokaza u realnom vremenu — snimaka ekrana, logcat-a, video-zapisa, stek-trejsova — plus tiketa spremnih za AI ispravke.

### Razvoj AI i LLM infrastruktura
- **HelixAgent** — produkcijski ansambl LLM usluga (Go/Gin) koja odbija da veruje jednom modelu: šalje upit na više provajdera, vodi strukturisanu višestepenu debatu (Predlog → Kritika → Pregled → Sinteza) i usmerava prema rezultatima provere uživo sa postupnim povlačenjem — sve iza OpenAI-kompatibilnog API interfejsa sa HA slojem podataka, opservabilnošću i zaštitnim mehanizmima. *Go, Gin, PostgreSQL, Redis, Prometheus/Grafana/OpenTelemetry, MCP, Neo4j/ClickHouse/Kafka.*
- **HelixCode** — distribuirana platforma za razvoj AI koja deli posao na inteligentne zadatke svesne zavisnosti, raspoređene na radničkoj mreži pod upravom SSH, a zatim čuva kontrolne tačke i vraća se unazad tako da ništa nikada ne bude izgubljeno ako se zadatak prekine; izbor modela svesnih hardvera i ceo ciklus planiranja/izrade/testiranja/refaktorisanja iza REST/CLI/TUI/MCP. *Go, Gin, PostgreSQL, Redis, SSH, MCP, llama.cpp/Ollama.*
- **HelixLLM** — jedan binarni fajl, šest režima implementacije: OpenAI- i Anthropic-kompatibilno zaključivanje preko HTTP/3 koje skaliramo od laptopa do višenamenskog klastera, sa lokalnim zaključivanjem preko llama.cpp (CUDA/Metal/ROCm) i automatski otkrivajućim, verifikaciono ocenjenim lancem rezervnog rešenja u oblaku koji uvek degradira na zagarantovani lokalni model. *Go, HTTP/3 QUIC, gRPC/SSE/Kafka, llama.cpp.*
- **LLMProvider / LLMOrchestrator / LLMsVerifier** — kičma LLM infrastrukture: jedan interfejs preko 43 provajdera sa prekidačima strujnog kola, monitoringom zdravlja, ponovnim pokušajima sa eksponencijalnim odlaganjem i poštenim (bez unapred zadatih rezervnih rešenja) otkrivanjem modela; thread-safe kontrolna ravan koja pokreće i upravlja headless CLI agentima (OpenCode, Claude Code, Gemini, Junie, Qwen Code) preko hibridnog protokola cevi i fajlova; i izvor istine za verifikaciju čiji obavezni filter „Vidiš li moj kod?" znači da se kao upotrebljivi ili za izvoz označavaju samo modeli za koje je dokazano da stvarno rade.
- **HelixMemory / HelixSpecifier** — objedinjeni kognitivno-memorijski pogon koji spaja četiri vrhunska backend-a (Mem0, Cognee, Letta, Graphiti) iza jednog interfejsa sa paralelnim pretraživanjem i ponovnim rangiranjem iz više izvora; i pogon za razvoj zasnovan na specifikacijama koji prilagođava sopstvenu proceduru obimu posla i podržava specifikacije višestrukom agentskom debatnom.
- **HelixTrack** — alternativa JIRA + Confluence-u otvorenog sveta (zastavni projekat Helix-Track linije): Go mikroservisi sa jedinstvenim API interfejsom usmerenim akcijama preko HTTP/3, SQLCipher enkripcijom u mirovanju i klijentima za Web/Desktop/Android/iOS.


### Alati profesionalnog nivoa (vasic-digital utils)
- **Catalogizer** — višenamenski, enkriptovan, samostalno hostovan sistem za upravljanje medijskim kolekcijama (Go/Gin + React), otporan na nestabilne mrežne skladišne sisteme, izgrađen na 21 ponovo upotrebljivom potmodulu.
- **Courses-Creator** — pipeline za konverziju markdown-a u video AI sa TTS i plejerima za desktop, mobilne i veb platforme.
- **VisionEngine** — računarski vid + višenamenski LLM vizuelni interfejs sa navigacionim grafovima.
- **DocProcessor** · **Docs Chain** · **Herald** · **task_bridge** · **Vasic Digital Paket ponovo upotrebljivih modula** — mapiranje funkcija za kontrolu kvaliteta, sinhornizacija dokumenata/baza podataka sa heširanim sadržajem, obaveštenja na prirodnom jeziku, sinhornizacija zadataka/tabli i flota standardne biblioteke `digital.vasic.*`.

### Automatizacija infrastrukture (Server Factory)
- **Mail Server Factory** — deklarativni JSON → potpuno konfigurisani, dokerizovani mail serveri za 12 vrsta konekcija i 25 Linux distribucija; izveštava o 439 uspešno položenih testova i čistoj SonarQube kapiji.
- **Server Factory Osnovni okvir**, **Qemu-Utils**, **Parallels-Utils** — zajednički provisioning pogon i alati za kreiranje VM slika.

## Jezici i alati (kratak spisak)

Go · Kotlin · Kotlin Multiplatform · TypeScript · JavaScript · Python · Swift · Java · Rust · Shell · PL/pgSQL · TLA+ · Gin · gRPC · HTTP/3 · React · Angular · Electron · React Native · PostgreSQL · SQLite · SQLCipher · Redis · Neo4j · ClickHouse · Docker · Kubernetes · Prometheus · Grafana · OpenTelemetry · QEMU · GitHub Actions · Gradle · Make

## Iskustvo

*Softverski inženjer od 2009. godine, sa iskustvom u celom razvojnom ciklusu — planiranje, razvoj, vođenje tima i implementacija. Potpuna istorija u nastavku preuzeta je iz kandidatovog verifikovanog zapisa (milosvasic.ru).*

### Stalni poslovi

- **SDK Developer — Harness** (harness.io), Beograd, Srbija · 03/2020 – 12/2024. Glavni programer na porodici SDK-ova za kompanijin odsek Feature Flag, sa fokusom na sve glavne mobilne platforme i šire. Klijenti i partneri uključivali su AWS, Google i razne banke. *Tehnologije: Android, iOS, Flutter, React Native, TypeScript, JavaScript, Java, Kotlin, Swift, Go, Ruby.*
- **Softverski inženjer — Leica Geosystems** (leica-geosystems.com), Herbrugg, Švajcarska · 02/2016 – 02/2020. Primarno iOS i Android programiranje za vrhunske 3D skenere kompanije Leica Geosystems — komunikacija u realnom vremenu sa hardverom, obrada podataka i sinhornizacija. Partner: Autodesk. *Tehnologije: Android, iOS, Java, Kotlin, Swift, C++.*
- **SDK Developer — Bosch** (bosch.rs), Beograd, Srbija · 01/2010 – 01/2016. Glavni SDK programer na projektu Connected Vehicles SDK — komunikacija u realnom vremenu sa Bluetooth sabirnicom OBD2, obrada podataka visokih performansi i njihovo čuvanje. *Tehnologije: Android, Java, Kotlin.*


### Ostale profesionalne aktivnosti

- **TN-TECH** (tn-tech.co.rs), Novi Sad, Srbija · honorarno, od 03/2017. Rad za Globex Data (Kanada i Švajcarska) — Sekur (SekurMessenger), SekurMail, SekurSuite — i platformu BusRide. *Tehnologije: Android, Java, Kotlin, C++, Qt.*
- **Increment Loop** (incrementloop.com), Beograd, Srbija · honorarno, od 09/2023. Aplikacija Yuno. *Tehnologije: Android, Kotlin.*
- **Otvoreni kod / sopstvene organizacije** — HelixTrack, Server Factory (Mail Server Factory, Parallels-Utils, Qemu-Utils) i Vasic Digital (Android-Toolkit, Network-Binder), detaljnije opisano u odeljku Izabrani projekti iznad.

## Publikacije

- **Fundamentalni Kotlin** — samostalno objavljeni autor; poslednje revidirano izdanje septembar 2022. (Fundamentalni Kotlin, 3. izdanje). Takođe autor za Packt Publishing (Velika Britanija).

## Obrazovanje

- **M.Sc, Savremene informacione tehnologije** — Univerzitet Singidunum, Beograd, Srbija · 2014.
- **B.Sc, Informatika i računarstvo** — Univerzitet Singidunum, Beograd, Srbija · 2008.

