---
name: HelixLLM
slug: helixllm
tier: helix-primary
order: 4
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - HTTP/3 QUIC
  - TLS 1.3
  - llama.cpp
  - LLMsVerifier
  - gRPC
  - SSE
  - Kafka
  - Prometheus
  - OpenTelemetry
repos:
  - https://github.com/HelixDevelopment/HelixLLM
diagrams:
  - Mode-system diagram — one binary deploying as full on a laptop vs. gateway/brain/knowledge/agents/control split across cluster hosts.
  - Fallback-chain flow — request → ranked cloud providers (429/5xx skip arrows) → guaranteed llama.cpp local fallback, annotated with LLMsVerifier scoring.
  - Compatibility layer — OpenAI and Anthropic client SDKs both hitting the same HTTP/3 gateway.
  - RAG + ReAct agent loop — document ingestion → vector search → agent tool-calling with conversation sessions.
---

# HelixLLM

**Jedan binarni fajl, šest režima — OpenAI- i Anthropic-kompatibilno zaključivanje od laptopa do klastera sa više hostova.**

## Sažetak

HelixLLM je distribuirani LLM sistem za preduzeća napravljen u Go: jedan binarni fajl sa sistemom režima koji se skaluje od razvoja na jednom hostu do produkcije na više hostova. Pruža potpuno OpenAI- i Anthropic-kompatibilne API-je preko HTTP/3, sa lokalnim zaključivanjem putem llama.cpp, lancom rezervnih rešenja sa ocenjivanjem više provajdera, RAG protokom i sistemom ReAct agenata.

## Kratak opis

HelixLLM je distribuirani LLM sistem zasnovan na jednom binarnom fajlu i Go. Izlaže OpenAI- i Anthropic-kompatibilne API-je preko HTTP/3, pokreće lokalno zaključivanje putem llama.cpp, automatski otkriva i ocenjuje besplatne provajdere u oblaku kako bi formirao lanac rezervnih rešenja, te dodaje RAG protočni sistem znanja i ReAct agenta sa pozivanjem alata — raspoloživ u šest režima implementacije.

## Detaljan opis

HelixLLM je distribuirani LLM sistem za preduzeća izgrađen u Go sa Gin, a njegova glavna prednost je da jedan artefakt pokriva sve scenarije. Kompajlira se u jedan binarni fajl čiji sistem režima određuje prilikom implementacije šta taj fajl *zapravo jeste*: pokrenite ga kao `full` za sveobuhvatnu instancu na laptopu ili podelite odgovornosti između režima `gateway`, `brain`, `knowledge`, `agents` i `control` raspoređenih na više hostova — isti kod, samo preuređen, a ne prepravljen, od razvojnog računara do produkcijskog klastera.

Govori dva dijalekta tečno: potpuno OpenAI- i Anthropic-kompatibilne API-je, tako da postojeći SDK klijenti iz oba ekosistema rade nepromenjeno, a sve se servira preko HTTP/3 (QUIC) sa automatskim HTTP/2 rezervnim rešenjem i TLS 1.3. Lokalno zaključivanje pokreće se preko llama.cpp sa podrškom za CUDA, Metal i ROCm, pa isti build ubrzava rad na Nvidia, Apple i AMD hardveru. Najistaknutija karakteristika je lanac rezervnih rešenja sa više provajdera, koji pretvara ozloglašenu nepouzdanost besplatnih oblaka za zaključivanje u upravljivi, samolečeći resurs: HelixLLM automatski otkriva besplatne modele od preko 7 provajdera u oblaku (Chutes, OpenRouter, HuggingFace, Nvidia, Cerebras, SambaNova, Together), ocenjuje ih putem LLMsVerifier na svakih pet minuta i usmerava saobraćaj kroz rangirani lanac sa automatskim rezervnim rešenjem za greške 429/5xx — uvek sa lokalnim llama.cpp kao garantovanom poslednjom opcijom, tako da zahtev nikada ne propadne samo zbog nedostupnosti provajdera.

Pored samog zaključivanja, HelixLLM je potpuna aplikativna platforma: RAG protočni sistem znanja (unos, segmentacija, ugradnja, vector pretraga) i sistem ReAct agenata sa pozivanjem alata, sesijama razgovora i integracijom RAG isporučuju se u istom binarnom fajlu. Sistem režima se isplati i na mrežnom nivou — u `full` režimu svi slojevi komuniciraju direktnim Go pozivima unutar procesa bez mrežnog opterećenja, dok isti binarni fajl, raspoređen na više hostova, koordinira preko gRPC, SSE i Kafka. Zaokružuju ga pregovaranje o sadržaju sa Brotli/gzip kompresijom, SSE strimovanje koje bajt-po-bajt odgovara formatima OpenAI i Anthropic, autentifikacija putem API ključa i JWT sa ograničenjem broja zahteva, Prometheus metrike, OpenTelemetry praćenje i veliki skup Go podmodula za produkcijsku infrastrukturu.


## Zašto smo ga napravili

Timovima je potreban zaključak koji je prenosiv, kompatibilan sa standardima i otporan – bez prepisivanja klijenata ili zavisnosti od jednog provajdera ili jedne mašine. HelixLLM je napravljen tako da isti binarni fajl može da radi lokalno tokom razvoja i da se skaluje na klaster u produkciji sa više hostova, govoreći dijalektima OpenAI i Anthropic koje klijenti već koriste.

## Zašto je revolucionaran

On sažima čitav stek zaključivanja – gejtvej, lokalno zaključivanje, rezervni oblak, RAG i agente – u jedan binarni fajl kontrolisan prekidačem režima, tako da arhitektura koju implementirate postaje odluka u vreme izvršavanja, a ne projekat ponovne platformizacije. Takođe pretvara ono što je ranije bilo slabost u prednost: pouzdanost provajdera u oblaku postaje primarna, neprestano merena briga, koju rešava ocenjivani, samolečeći lanac rezervnih rešenja koji svakih nekoliko minuta ponovo rangira provajdere i uvek degradira na zagarantovano lokalno zaključivanje. Ono što to omogućava jeste jedna krajnja tačka na koju se možete zaista osloniti – kompatibilna sa standardima, prenosiva sa laptopa na klaster i nesposobna da se ugasi jer je neki uzvodni provajder ograničio broj zahteva ili otkazao.

## Šta je inovativno

- Jedan binarni fajl sa sistemom od šest režima koji radi sve-u-jednom ili kao distribuirane uloge – direktni pozivi Go u procesu u režimu `full`, gRPC/SSE/Kafka kada je podeljen – tako da se topologija implementacije menja bez izmene koda ili nepotrebnog opterećenja mreže.
- Ocenjivani, automatski otkrivajući lanac rezervnih rešenja sa više provajdera preko 7+ besplatnih provajdera, neprestano rangiranih prema LLMsVerifier sa automatskim prebacivanjem na rezervu pri greškama 429/5xx i zagarantovanim llama.cpp kao poslednjim rešenjem – besplatni kapacitet pretvoren u pouzdan kapacitet.
- Dvostruke površine kompatibilne sa OpenAI *i* Anthropic, servisirane preko HTTP/3 sa automatskim prebacivanjem na HTTP/2, tako da se klijenti iz oba ekosistema povezuju bez modifikacija.
- Lokalno zaključivanje koje pokriva CUDA, Metal i ROCm iz jednog kodnog izvora – isti build radi ubrzano na Nvidia, Apple i AMD hardveru.

## Najveći tehnički izazovi i kako smo ih rešili

- **Skaliranje sa jednog hosta na više bez prepisivanja.** Većina sistema nameće čvrstu granicu između „lokalnog razvoja" i „distribuirane produkcije", a prelazak te granice zahteva preuređenje arhitekture. Mi smo tu granicu izbrisali sistemom režima na jednom binarnom fajlu: isti slojevi komuniciraju putem direktnih poziva u procesu u režimu `full`, a transparentno prelaze na gRPC/SSE/Kafka u distribuiranim režimima, tako da je skaliranje samo pitanje konfiguracije, a ne portiranja.
- **Nepouzdani, ograničeni besplatni provajderi u oblaku.** Besplatni zaključak je brz dok ne dođe do greške 429 ili dok ne nestane usred zahteva. Mi smo ga učinili pouzdanim automatskim otkrivanjem dostupnih modela, ocenjivanjem pomoću LLMsVerifier, proaktivnim praćenjem zaglavlja koja ograničavaju broj zahteva kako bismo zaobišli provajdere koji su na ivici gušenja, i automatskim prebacivanjem na rezervu niz rangirani lanac do lokalnog llama.cpp – tako da nestabilnost tog bazena nikada ne stigne do pozivaoca.
- **Kompatibilnost klijenata u dva ekosistema.** Prepisivanje klijenata kako bi prihvatili novi backend za zaključivanje nije opcija. Implementirali smo i OpenAI *i* Anthropic oblike API – uključujući njihove različite formate strimovanja SSE – tako da SDK-ovi iz oba tabora pokazuju na HelixLLM i jednostavno rade.


## Tehnološki stek

- **Go + Gin** — izabrani jer jedinstvena binarna datoteka sa pristupom koji prioritet daje konkurentnost omogućava ceo sistem modova: jedna verzija koja može biti serverska aplikacija na laptopu ili čvor u klasteru. Ona nosi ceo sistem i HTTP sloj gejtveja.
- **HTTP/3 (QUIC) + TLS 1.3, sa HTTP/2 rezervnim rešenjem** — izabrani za moderan, niskolatentni i otporan transport veza, izložen kao serverska površina sa automatskom negocijacijom, tako da klijenti koji ne podržavaju QUIC tiho prelaze na HTTP/2.
- **llama.cpp (CUDA/Metal/ROCm)** — izabran za prenosivu lokalnu inferenciju koja ubrzava rad na Nvidia, Apple i AMD backendovima iz jednog koda; služi i kao garantovani krajnji rezervni provajder koji sprečava da lanac rezervnih rešenja ikada ostane bez opcija.
- **LLMsVerifier** — izabran da pretvori pitanje „koji je provajder trenutno dobar" u broj; ocenjuje i rangira lanac rezervnih provajdera u oblaku na svakih pet minuta, tako da usmeravanje prati trenutni kvalitet, a ne zastarele pretpostavke.
- **Provajderi u oblaku (Chutes, OpenRouter, HuggingFace, Nvidia, Cerebras, SambaNova, Together)** — izabrani da iskoriste kapacitete besplatnih nivoa usluga kod više provajdera; automatski se otkrivaju i rangiraju u jedan lanac rezervnih rešenja, tako da nijedan provajder nije jedina tačka otkaza.
- **gRPC + SSE + Kafka** — izabrani kao transportni protokoli između modova za distribuirane implementacije: gRPC za pozive između servisa, SSE za strimovanje, a Kafka za odvojeni tok događaja između uloga.
- **Vektorsko skladište / embeddings** — izabrano da pokreće RAG pipeline znanja od početka do kraja: unos, segmentaciju, ugradnju i pretragu dokumenata koji osiguravaju osnovu za odgovore modela.
- **Prometheus + OpenTelemetry** — izabrani za metriku i distribuirano praćenje koje prati zahtev kroz sve raspoređene modove.
- **vasic-digital Go potmoduli** — izabrani da se ponovo iskoriste provereni primitivi infrastrukture za produkciju umesto da se grade ispočetka, čime se osigurava doslednost osnove sistema sa širim stekom.

## Status i napomene o iskrenosti

- **Status: beta.** Funkcionalan, aktivno razvijan sistem distribuirane inferencije.
- **Licenca: nije određena.** U metapodacima repozitorijuma nije navedena licenca (`licenseInfo` null) — ovo je NEVERIFIKOVANO i mora biti rešeno pre nego što se navede licenca.
- Kanonski repozitorijum trenutno vodi na `github.com/HelixDevelopment/llm`; putanja `HelixLLM` preusmerava na njega. Podaci o pragu pokrivenosti i broju potmodula u README fajlu su samoprijavljeni.

**Prioritetni nivo:** Helix-primary.

