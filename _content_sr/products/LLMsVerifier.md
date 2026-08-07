---
name: LLMsVerifier
slug: llmsverifier
tier: helix-primary
order: 11
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - SQLite + SQLCipher
  - Redis
  - RabbitMQ + Kafka
  - gRPC + Protocol Buffers
  - QUIC / HTTP-3 (quic-go)
  - JWT + LDAP/NTLM
  - Angular
  - Python + JavaScript SDKs
  - Docker / Kubernetes / Helm
  - Prometheus + Grafana
repos:
  - https://github.com/vasic-digital/LLMsVerifier
diagrams:
  - Mandatory verification gate — a model entering a gate labeled "Do you see my code?"; PASS → marked usable + (llmsvd) suffix + eligible for export; FAIL → rejected (never exported).
  - Verification test matrix — a grid of capability checks (existence, responsiveness, latency, streaming, function calling, vision, embeddings) across provider columns, with pass/fail cells.
  - Failover orchestration — provider chain with circuit-breaker states (closed/open/half-open), latency-based rerouting, and weighted traffic split.
  - Verified-only export flow — verified model pool → config generator → AI CLI tool configs (OpenCode / Crush / Claude Code), with unverified models visibly filtered out.
---

# LLMsVerifier

**Verifikuj. Nadgledaj. Optimizuj.**

## Sažetak

LLMsVerifier je platforma poslovne klase za verifikaciju, nadgledanje i optimizaciju velikih jezičkih modela (LLM) kod različitih provajdera, izgrađena na obaveznom testu verifikacije *„Vidiš li moj kod?"* kako bi samo modeli za koje je dokazano da zaista funkcionišu ikada bili označeni kao upotrebljivi ili izvezani.

## Kratak opis

Platforma Go koja verifikuje, testira performanse, nadgleda i optimizuje LLM-ove kod više provajdera. Svaki model mora proći obavezni test vidljivosti koda pre upotrebe; zatim se proveravaju latencija, strimovanje, pozivi funkcija, vizuelna obrada i ugradnja, a izvoze se samo verifikovane konfiguracije za alate AI i CLI.

## Detaljan opis

LLMsVerifier je sveobuhvatna platforma za verifikaciju, nadgledanje i optimizaciju performansi LLM modela kod različitih provajdera. Njen osnovni princip je *obavezna verifikacija*, i u tome je nepopustljiva: pre nego što se bilo koji model označi kao upotrebljiv — ili dozvoli u izvoznu konfiguraciju — mora izričito da prođe test *„Vidiš li moj kod?"*, koji šalje stvarne HTTP zahteve provajderu i analizira odgovor kako bi utvrdio stvarno razumevanje, a ne samo verodostojan odjek. Model koji ne može nedvosmisleno da vidi i razume vaš unos jednostavno nikada ne dobija oznaku „upotrebljiv". Nakon te provere, Verifikacioni motor sprovodi kompletnu seriju testova sposobnosti — postojanje, responsivnost, latencija, strimovanje, pozivi funkcija, vizuelna obrada, embeddings — a Izveštajni motor rezultate pretvara u markdown i JSON izveštaje na osnovu kojih možete preduzimati akcije.

Sistem je modularan i vođen događajima, nudeći CLI, TUI, veb i REST API interfejse preko jezgra koje čine Verifikacioni motor, Izveštajni motor i Menadžer konfiguracija, i ne zaustavlja se na verifikaciji. Napredni slojevi dodaju Supervizor/Radnik obrazac za dekompoziciju zadataka pokretanih LLM modelima, upravljanje kontekstom pomoću klizećeg prozora i LLM sumarizacije kako veoma duge sesije ne bi doživele kolaps, čuvanje kontrolnih tačaka u oblaku i sistem za preuzimanje u slučaju otkaza sa prekidačima strujnog kola i rutiranjem zasnovanim na latenciji. Okolna infrastruktura je prilagođena produkciji: magistrala događaja tipa pub/sub, raspored cron poslova, detekcija cena i ograničenja, vector baza podataka za RAG, i sistem za izvoz. Posebna konvencija brendiranja dodaje sufiks *(llmsvd)* svakom generisanom provajderu/modelu, tako da se verifikovani izlaz može prepoznati na prvi pogled i nikada ne može biti pomešan sa neproverenim — a samo verifikovani modeli se ikada upisuju u izvezene konfiguracije za AI CLI alate poput OpenCode, Crush i Claude Code. Dolazi sa operativnim alatima koje timovi zaista koriste u produkciji: Docker/Kubernetes/Helm implementacija, Prometheus/Grafana nadgledanje, LDAP/SSO i SQLCipher enkriptovano skladištenje.

## Zašto smo je izgradili

Zato što je provera samo na osnovu konfiguracije nepouzdana — API ključ može isteći, model može biti zastareo, a konfiguracioni fajl vam ne govori ništa o stvarnoj latenciji, stvarnim greškama ili tome da li model zaista vidi i razume vaš unos. LLMsVerifier zamenjuje *„nalazi se u konfiguraciji, dakle mora da radi"* dokazom: samo modeli koji nedvosmisleno odgovaraju ispravno bivaju označeni kao upotrebljivi i izvoze se.


## Zašto je ovo revolucionarno

Čini LLM flote *pouzdanim* — reč koja se retko zaslužuje u svemiru podešavanja koja lažu izostavljanjem. Umesto da se timovi nadaju da će konfigurisani model raditi, dobijaju strogo sprovedenu, testabilnu garanciju da je svaki model u upotrebi prošao stvarnu verifikaciju, uz monitoring, preusmeravanje u slučaju greške i izvoz samo verifikovanih modela koji zatvaraju krug od dokaza do produkcije. U okviru Helix ekosistema postaje jedini izvor istine za LLM modele, provajdere i metapodatke verifikacije: drugi servisi (među njima i HelixTranslate) usmeravaju saobraćaj prema njemu, pa cela platforma nasleđuje jedan pošten odgovor na pitanje *„koji modeli zaista sada rade?"* umesto da svaki tim održava sopstveno optimistično nagađanje.

## Šta je inovativno

- **Obavezna verifikacija *„Vidiš li moj kod?"*** — stvarna, HTTP-oslonjena provera razumevanja koju model mora da prođe pre nego što uopšte postane upotrebljiv; potpisna karakteristika proizvoda i razlog što ništa neprovereno ne proklizne.
- **Izvoz konfiguracije samo verifikovanih modela** — generisane konfiguracije za AI CLI alate sadrže *samo* modele koji su prošli verifikaciju, tako da konfiguracija koju šaljete ne može tiho da reintrodukuje pokvaren model.
- **Sistem sufiksa brendiranja `(llmsvd)`** — svaki generisani provajder/model nosi uočljiv sufiks, čineći verifikovano poreklo vidljivim svuda gde se izlaz širi.
- **Detekcija mogućnosti** na mnogim CLI agentima i provajderima — otiskuje tipove striminga (SSE, WebSocket, JSONL, EventStream), kompresiju i ponašanje keširanja umesto da ih pretpostavlja.
- **Otpormo preusmeravanje** — prekidači strujnog kola, rutiranje zasnovano na latenciji koje preusmerava kada vreme do prvog tokena pređe prag, probe zdravlja i ponderisana raspodela saobraćaja održavaju flotu reagljivom kada pojedini provajderi zakažu.
- **Dugotrajna autonomija** — obrazac dekompozicije Supervizor/Radnik uz kontrolne tačke i integraciju memorije podržava produžene sesije koje bi inače iscrple kontekst.
- **Integracija sa RAG / vector-DB** za poboljšanje konteksta zasnovanog na činjenicama.

## Najveći tehnički izazovi i kako smo ih rešili

- **Dokazivanje da model zaista radi, a ne samo da je konfigurisan.** Cela poenta, i najteži deo. Rešeno obaveznim testom vidljivosti koda koji pravi stvarne API pozive i analizira odgovore na potvrdno razumevanje, podržano širokim skupom testova mogućnosti — a zatim odbijanjem izvoza svega što nije prošlo, tako da produkciju ne kontroliše konfiguracija, već dokaz.
- **Pouzdanost na mnogim nestabilnim provajderima trećih strana.** Rešeno orkestrom za preusmeravanje koji nestabilnost provajdera tretira kao normalan slučaj: prekidači strujnog kola označavaju provajdera kao degradiranog nakon N grešaka u M sekundi, rutiranje zasnovano na latenciji skreće sa sporih krajnjih tačaka, periodične probe zdravlja proveravaju oporavak, a ponderisano rutiranje balansira između ekonomičnih i premium modela.
- **Održavanje veoma dugih, autonomnih sesija.** Rešeno obrascem dekompozicije Supervizor/Radnik koji deli veliki posao na upravljive delove, periodičnim kontrolnim tačkama u cloud skladištu kako bi napredak preživeo prekide, i slojevitim upravljanjem kontekstom (klizeći prozor + sumarizacija LLM + RAG) kako model ne bi izgubio nit a da se ne udavi u tokenima.
- **Širenje provajdera.** Rešeno skrivanjem mnogih Go adaptera za pojedine provajdere iza jednog zajedničkog interfejsa, uz centralno nabrajanje stvarnih krajnjih tačaka — tako da dodavanje provajdera predstavlja izolovanu promenu, a ne talas koji se širi kroz kodnu bazu.


## Tehnološki stek

- **Go** — izabran kao osnovni programski jezik zbog podrške konkurentnosti; pokreće višedretveni Verifikacioni motor koji može istovremeno da ispituje više modela, kao i okolne servise.
- **Gin** — izabran kao REST API server, koji podržava JWT autentifikaciju, ograničenje broja zahteva i WebSocket/SSE krajnje tačke.
- **SQLite + SQLCipher** — izabrani za ugrađeno skladištenje sa enkripcijom na nivou baze podataka, jer su verifikacioni podaci (ključevi, rezultati) osetljivi i podrazumevano treba da budu šifrovani u mirovanju.
- **Redis** — izabran kao sloj za keširanje kako bi brze provere i pretrage metapodataka ostale brze.
- **RabbitMQ + Kafka** — izabrani za pokretanje arhitekture vođene događajima: razmenu poruka i strimovanje koje odvaja proizvođače od potrošača na nivou platforme.
- **gRPC + Protocol Buffers** — izabrani za strogo tipiziranu komunikaciju između servisa i prenos događaja između komponenti.
- **QUIC / HTTP-3 (quic-go)** — izabrani za podršku modernom transportu (u dokumentaciji repozitorijuma navodi se da je dostupnost HTTP/3 provajdera ograničena — to je ponuđena mogućnost, a ne univerzalna tvrdnja).
- **JWT + LDAP/NTLM** — izabrani za preduzetničku autentifikaciju kako bi se platforma uklopila u postojeći korporativni identitet (u dokumentaciji se navode SSO/SAML/OIDC).
- **Viper (konfiguracija), Logrus (evidencija), Brotli/compress (kompresija)** — operativna infrastruktura: fleksibilna konfiguracija, strukturirani zapisi i kompresija korisnog opterećenja.
- **Angular** — izabran za veb aplikaciju u vidu jedne stranice, vizuelni ulaz u verifikaciju i nadzor.
- **Python + JavaScript SDK-ovi** — izabrani kako bi timovima klijenata pružili prvoklasan pristup, dokumentovan putem OpenAPI/Swagger-a.
- **Docker, Kubernetes, Helm** — izabrani za produkcijsko postavljanje sa praćenjem zdravlja sistema i automatskim skaliranjem, kako bi flota za verifikaciju skalirala poput svakog modernog servisa.
- **Prometheus + Grafana** — izabrani za metriku i kontrolne table, čineći zdravlje same platforme jednako uočljivim kao i modele koje nadgleda.
- **Testify (Go) + node --test/jsdom (veb)** — izabrani za višeslojno testiranje Go jezgra i veb interfejsa.

## Status i napomene o iskrenosti

- **Status: beta.** Izvorni kod Go implementira stvarnu HTTP verifikaciju (jedan zastareli dokument koji verifikaciju opisuje kao isključivo konfiguracionu predstavlja aspiraciju i zastareo je — autoritativan je kod).
- **Licenca: treba utvrditi.** U README fajlu navodi se MIT, dok Dockerfile oznaka navodi Apache-2.0 — pitanje treba razrešiti pre objavljivanja.
- Broj provajdera: u README fajlu stoji „12 adaptera", ali direktorijum provajdera navodi oko 26 — tretirajte kao „12+ / više u razvoju". Postoji mnogo fajlova sa statusom „FINALNO/KOMPLETNO" koji predstavljaju aspiraciju; autoritativni su kod, dokumentacija i `go.mod`.
- Repozitorijum se nalazi u organizaciji `vasic-digital`, ali funkcionalno predstavlja sloj poverenja Helix LLM infrastrukturnog klastera.

**Prioritetni nivo:** Helix-primer (LLM infrastrukturni klaster; jedini izvor istine za LLM/provajder/verifikacione metapodatke). Rangira se iza HelixTrack.

