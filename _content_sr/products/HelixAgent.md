---
name: HelixAgent
slug: helixagent
tier: helix-primary
order: 3
status: beta
license: MIT
private: false
tech:
  - Go
  - Gin
  - PostgreSQL
  - Redis
  - LLMsVerifier
  - Prometheus
  - Grafana
  - OpenTelemetry
  - Model Context Protocol
  - Neo4j
  - ClickHouse
  - Kafka
repos:
  - https://github.com/HelixDevelopment/HelixAgent
diagrams:
  - Ensemble/debate flow — a prompt fanning out to N providers, through the Proposal→Critique→Review→Synthesis phases, converging to one synthesized answer.
  - Dynamic routing — LLMsVerifier scores feeding a router that selects confidence-weighted providers with fallback arrows.
  - Production architecture — Gin API → orchestrator → provider pool, with PostgreSQL/Redis and the Prometheus/Grafana/OpenTelemetry observability plane.
  - Module map — the ~20 extracted modules grouped by concern (data, security, AI, infra).
---

# HelixAgent

**Ne biraj jedan model — pusti ih da debatuju i isporuči odgovor na kojem se slože.**

## Sažetak

HelixAgent je proizvodno spremna usluga ansambla LLM pokretana AI tehnologijom u Go okruženju, koja inteligentno kombinuje odgovore iz više jezičkih modela — uključujući višestepeni sistem debate AI i dinamički izbor provajdera zasnovan na verifikaciji — kako bi proizvela najtačniji i najpouzdaniji rezultat.

## Kratak opis

HelixAgent je usluga ansambla LLM zasnovana na Go platformi koja objedinjuje više provajdera u jedan precizan odgovor. Pokreće višestepene debate AI, dinamički boduje provajdere putem LLMsVerifier, usmerava saobraćaj strategijama ponderisanim poverenjem i isporučuje proizvodne funkcionalnosti: keširanje, nadzor, sigurnosne zaštitne mere i API-je u stilu OpenAI.

## Detaljan opis

HelixAgent je proizvodno spremna usluga ansambla LLM pokretana AI tehnologijom (MIT licenca) koja tretira odgovor jednog modela kao hipotezu, a ne kao konačnu presudu. Umesto da se ishod oslanja na jednog provajdera koji može biti pogrešan, pristrasan ili privremeno nedostupan, ona kombinuje odgovore iz više jezičkih modela kako bi se došlo do najtačnijeg i najpouzdanijeg rezultata — a kada je pitanje dovoljno složeno da to opravda, pokreće modele kroz strukturiranu, višestepenu debatu. Spisak je širok: u README fajlu dokumentovani su brojni provajderi LLM pod `internal/llm/providers/`, uključujući Claude, DeepSeek, Gemini, Mistral, Qwen i xAI/Grok.

Ključno je da izbor provajdera nije statička lista preferenci — on se zaslužuje u realnom vremenu. Rezultati verifikacije uživo iz integrisanog LLMsVerifier sistema pokreću usmeravanje i elegantno prebacivanje na najbolje performirajućeg provajdera, uz kategorizovano izveštavanje o greškama kada neki od njih počne da slabije radi. AI Debatni orkestrator pretvara neslaganje u signal: podržava više topologija (mreža, zvezda, lanac) i disciplinovan protokol faza — Predlog → Kritika → Pregled → Sinteza — uz učenje iz prethodnih debata kako bi sistem vremenom bolje usaglašavao modele. Strategije usmeravanja obuhvataju izbor ponderisan poverenjem, konsenzus većinom glasova i detekciju semantičke namere, sve uz strimovanje odgovora u realnom vremenu tako da rezultati stižu token po token, umesto da se čeka da se ceo ansambl usaglasi.

Usluga je projektovana da preživi u produkciji, a ne samo da dobro izgleda na demonstracijama: PostgreSQL i Redis čine sloj podataka visoke dostupnosti, Prometheus/Grafana/OpenTelemetry obezbeđuju metrike, kontrolne table i praćenje, a JWT autentifikacija, ograničenje broja zahteva, motor zaštitnih mera i detekcija PII obavijaju ansambl kontrolama koje su neophodne za stvarnu primenu. Organizovana je u oko dvadeset izdvojenih modula (EventBus, Observability, Auth, Storage, VectorDB, Embeddings, RAG, Memory, MCP i drugi), od kojih je svaki zasebna celina, a isporučuje i okvir za optimizaciju LLM (semantičko keširanje, strukturirani izlaz, poboljšano strimovanje) sa integracijama za SGLang, LlamaIndex, LangChain, Guidance i LMQL. Pošto su endpointi za kompletiranje i ansambl kompatibilni sa OpenAI standardom, postojeći klijent može da se poveže na HelixAgent i dobije ansamblirano rezonovanje bez potrebe za prepravkama.

## Zašto smo ga izgradili

Svaki pojedinačni LLM može biti pogrešan, pristrasan ili nedostupan. HelixAgent je stvoren kako bi aplikacije mogle da se konsultuju sa više modela istovremeno, da odmere njihove odgovore prema merenoj pouzdanosti i da se elegantno povuku – pretvarajući krhku zavisnost od jednog provajdera u otporan, samoprocenjujući ansambl.

## Zašto je revolucionaran

Operacionalizuje konsenzus više modela – prebacuje „pitaj nekoliko modela i uskladi odgovore" iz improvizovanih skripti u proizvodnu uslugu. Umesto da se oslanjaju na jednog provajdera i nadaju se najboljem, timovi dobijaju rutiranje vođeno rezultatima verifikacije uživo, strukturirani protokol debate za pitanja gde jedan pokušaj nije dovoljan, i otpornost na nivou produkcije (HA sloj podataka, potpunu opservabilnost i zaštitne mehanizme) – sve iza OpenAI-kompatibilnog API. Ključna prednost je usvajanje bez prekida: jedna krhka zavisnost od provajdera postaje otporan, samoprocenjujući ansambl, a postojeći klijenti prelaze na njega promenom krajnje tačke umesto koda.

## Šta je inovativno

- Strukturirana višestepena AI debata koja tretira neslaganje modela kao resurs: izbor mrežnih/zvezdastih/lančanih topologija, disciplinovan protokol Predlog→Kritika→Pregled→Sinteza, i učenje na osnovu prethodnih debata koje se akumulira tokom vremena.
- Dinamički izbor provajdera zasnovan na rezultatima LLMsVerifier ocenjivanja uživo umesto na statičkoj listi preferenci – ansambl usmerava upite ka onome ko trenutno najbolje funkcioniše i elegantno se povlači kada neko zakazuje.
- Izvorni Go okvir optimizovan za LLM (semantički keš, strukturirani izlaz, poboljšan striming) koji stoji sam za sebe, sa opcionim spoljnim optimizatorima (SGLang, LlamaIndex, LangChain, Guidance, LMQL) koji se mogu dodati po potrebi, a ne obavezno.
- Modularna arhitektura sastavljena od dvadesetak izdvojenih modula koja održava razdvojenost odgovornosti i otvara vrata za funkcije velikih podataka poput distribuirane memorije i striminga grafova znanja.

## Najveći tehnički izazovi i kako smo ih rešili

- **Izbor među mnogim nejednakim provajderima.** Provajderi se razlikuju po kvalitetu i vremenom menjaju performanse, pa je svako fiksno rangiranje već sutra zastarelo. Rešili smo to kontinuiranim merenjem: LLMsVerifier ocene napajaju rutiranje zasnovano na ponderisanom poverenju i većinskom glasanju, sa elegantnim povlačenjem kako bi se zaobišao provajder koji se pogoršava umesto da mu se veruje.
- **Dobijanje pouzdanog odgovora na zaista teška pitanja.** Jedan model, pitan jednom, nema mehanizam da uhvati sopstvenu grešku. Debatni orkestrator to omogućava – višestruke topologije, fazna debata (Predlog → Kritika → Pregled → Sinteza) koja primorava modele da se međusobno preispituju i usavršavaju pre nego što se konačan odgovor sintetizuje.
- **Pokretanje ansambla u produkciji, a ne samo u beležnici.** Rasprostiranje na više provajdera umnožava površinu za greške. Ograničili smo je pomoću HA sloja podataka PostgreSQL+Redis, opservabilnosti Prometheus/Grafana/OpenTelemetry za slučajeve kada provajder ili ruta ne funkcionišu kako treba, i sigurnosnog perimetra koji uključuje JWT autentifikaciju, ograničenje broja zahteva, motor zaštitnih mehanizama i detekciju PII.


## Tehnološki stek

- **Go** — izabran zato što je raspršivanje jednog zahteva na više provajdera istovremeno upravo ono za šta su gorutine namenjene, a isporuka u vidu jednog binarnog fajla čuva jednostavnost servisa od ~20 modula; čini temelj celog servisa i svakog internog modula.
- **Gin (Web API)** — izabran zbog brzog, niskoopterećenog HTTP interfejsa; služi OpenAI-kompatibilnim `/v1` endpointima za dopunjavanje, ćaskanje, strimovanje i ansambl, koji omogućavaju postojećim klijentima da usvoje ansambl bez promena.
- **PostgreSQL** — izabran kao trajna memorija za sesije, analitiku i zapise debata, kako bi odluke postignute konsenzusom i istorija debata bile proverljive; osigurava visoku dostupnost sloja podataka.
- **Redis** — izabran za keširanje niske latencije i upravljanje redovima zadataka; pokreće i keširanje odgovora i semantički keš sloj koji omogućava da se ponovljeni ili gotovo identični upiti preskoče kako bi se izbeglo suvišno zaključivanje.
- **LLMsVerifier (integrisan)** — izabran da pouzdanost provajdera bude merljiva veličina, a ne pretpostavka; njegovi rezultati rangiraju provajdere za rutiranje i pokreću rezervne opcije kada neki od njih počne da gubi na kvalitetu.
- **Prometheus + Grafana + OpenTelemetry** — izabrani kako bi ansambl koji obuhvata više provajdera ostao uočljiv; izlažu `helixagent_*` metrike, kontrolne table i praćenje zahteva od kraja do kraja tokom raspršivanja.
- **Model Context Protocol (MCP) adapteri** — izabrani zbog proširivosti kroz otvoreni protokol; u README fajlu navedeno je mnogo MCP adaptera za povezivanje spoljašnjih alata i konteksta.
- **Neo4j / ClickHouse / Kafka (BigData)** — izabrani da bi se prevazišao okvir jednog čvora: Neo4j i ClickHouse podržavaju distribuiranu memoriju i funkcije znanja-grafa, a Kafka strimuje te grafove i podatke o događajima na velikoj skali.
- **Integrisane optimizacije (SGLang, LlamaIndex, LangChain, Guidance, LMQL)** — izabrane da bi se kao opcione usluge dodali keširanje prefiksa, preuzimanje, dekompozicija zadataka i generisanje sa ograničenjima, tako da naprednije optimizacije budu dostupne, ali ne i obavezne.

## Napomene o statusu i iskrenosti

- **Status: beta.** Servis je opisan kao spreman za produkciju, ali su performanse i podaci o pokrivenosti navedeni u README fajlu (npr. „1000+ zahteva u sekundi", „<500 ms sa kešom", broj provajdera i skripti za validaciju) samo tvrdnje projekta, nisu nezavisno potvrđeni i ovde su namerno zadržani u kvalitativnom obliku.
- Broj provajdera varira u samom README fajlu; stranica koristi kvalitativni okvir „mnogi provajderi".

**Prioritetni nivo:** Helix-primary.

