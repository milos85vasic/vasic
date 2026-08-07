---
name: Vasic Digital Reusable Module Suite
slug: vasic-digital-reusable-module-suite
tier: vasic-util-secondary
order: 28
status: mixed (many stable, independently-tested modules; several self-marked SCAFFOLD/WIP — UNVERIFIED)
license: UNVERIFIED (varies per module)
private: false
tech:
  - Go (digital.vasic.*)
  - Kotlin Multiplatform (*-KMP)
  - Redis / PostgreSQL / SQLite
  - Prometheus / OpenTelemetry
  - WebSocket / HTTP/3 (quic-go) / mDNS
  - Vector DB / Embeddings / RAG / MCP
  - YAML (RedTeam fixtures, config)
repos:
  - https://github.com/vasic-digital
diagrams:
  - Three-cluster module map (Infrastructure / AI primitives / Guardrails) with product apps on top
  - "Standard library" grid of modules, colored by maturity (stable vs scaffold)
  - Go ↔ KMP mirror pairs
  - A product (Catalogizer or HelixAgent) exploded into the modules it consumes
---

**Izgradi jednom, koristi svuda — flota malih, odvojenih, nezavisno testiranih Go i KMP modula.**

## Sažetak

Velika porodica generičkih, ponovo upotrebljivih modula objavljenih pod `digital.vasic.*` (Go) i Kotlin Multiplatform imenskim prostorima. Svaki modul je samostalan, nezavisno testiran i verzioniran, a koristi se kao podmodul sa jednakom kodnom bazom u većim proizvodima (Catalogizer, HelixAgent i šira flota). Ova stranica objedinjuje brojne male alate koji bi, prikazani pojedinačno, predstavljali suvišan šum.

## Kratak opis

Kurirana kolekcija odvojenih `digital.vasic.*` modula — infrastrukturni primitivi (autentifikacija, keš, baza podataka, konfiguracija, opservabilnost), gradivni blokovi za AI/agente (RAG, VectorDB, Embeddings, MCP, Agentic, Planiranje) i odbrambeni LLM sigurnosni mehanizmi (RedTeam, Normalize) — uz paralelni set Kotlin Multiplatform modula. Svaki je generički, testiran i ponovo upotrebljiv.

## Detaljan opis

Organizacija vasic-digital zasniva se na jednoj strukturalnoj opkladi: filozofiji „ustava + mnoštva odvojenih, ponovo upotrebljivih podmodula" u kojoj se generička funkcionalnost nikada ne piše dvaput. Umesto monolitnih rešenja, svaki ponovo upotrebljivi segment izdvaja se u sopstveni mali modul — sopstveni repozitorijum, sopstvene testove, sopstvenu dokumentaciju — i strogo se odvaja kako specifičnosti jednog korisnika nikada ne bi procurele u njega. Ova stranica ih grupiše jer bi, posmatrani pojedinačno, svaki predstavlja biblioteku koja bi kao samostalna stranica proizvela samo šum. Zajedno, oni su pravi multiplikator snage organizacije: privatni inženjerski resurs koji pretvara „izgradnju novog proizvoda" u „sastavljanje dokazanih delova", i konkretna potvrda tvrdnje da ova flota ne izmišlja toplu vodu — ona održava jedno veoma dobro točak i kotrlja ga svuda.

Skup obuhvata tri klastera. **Infrastrukturni primitivi** (Go) pružaju osnovnu strukturu koju svaka usluga zahteva: `auth` (JWT/bcrypt), `cache` (Redis/TTL), `database` (migracije, dualni SQLite/PostgreSQL), `config`, `middleware`, `observability` (Prometheus/OpenTelemetry), `ratelimiter`, `security`, `storage` (S3/MinIO), `streaming` (WebSocket čvorište), `eventbus`, `filesystem` (višeprotokolni), `discovery`/`mdns`, `http3`, `recovery`, `concurrency`, `lazy` i još mnogo toga. **Gradivni blokovi za AI/agente** (Go) pružaju podlogu za sisteme zasnovane na AI: `rag`, `vectordb`, `embeddings`, `memory`, `conversation` (kompresija beskonačnog konteksta, event sourcing), `mcp` (Model Context Protocol), `toolschema`, `skillregistry`, `agentic` (orkestracija tokova rada zasnovana na grafovima), `planning` (HiPlan/MCTS/Stablo-mišljenja), `benchmark` (SWE-bench/HumanEval/MMLU), `llmops`, `selfimprove` (modelovanje nagrada/RLHF) i `toon` (Token-Oriented Object Notation). **Odbrambeni LLM sigurnosni mehanizmi** nude alate za robusnost u uslovima napada: `RedTeam` (adverzarijalni scenariji vođeni YAML), `Normalize` (kanonizacija ulaza pod napadom). Paralelni **Kotlin Multiplatform** set preslikava ključne module (Auth-KMP, Database-KMP, Security-KMP, UI-Components-KMP itd.) za cross-platform aplikacije.


## Zašto smo ga izgradili

Isporuka mnogih proizvoda (Catalogizer, HelixAgent, Herald i drugih) od nule svaki put je rasipanje resursa i nedoslednost. Izvlačenje svih generičkih zahteva u odvojene, testirane module znači da se ispravke i poboljšanja šire kroz ceo sistem, a svaki novi proizvod sastavlja se od proverenih delova.

## Zašto je revolucionarno

U suštini, radi se o privatnoj „standardnoj biblioteci" za izgradnju backend sistema usmerenih na AI – sloj koji većina timova nikada ne stigne da izgradi jer su previše zauzeti ponovnim rešavanjem autentifikacije, keširanja i infrastrukturnih detalja RAG po peti put. Ovde infrastrukturne primitive, gradivni blokovi za AI i odbrambeni mehanizmi LLM postoje kao gotovi, nezavisno testirani moduli, što malom timu omogućava da isporuči sisteme na nivou finalnog proizvoda tempom koji obično zahteva mnogo veći tim – i to bez duga dupliciranja koji obično prati takav proces.

## Šta je inovativno

- Disciplina razdvajanja na nivou celog sistema (CONST-051): podmoduli tretirani kao ravnopravne kodne baze, bez specifičnosti potrošača.
- Namenski sloj primitiva za AI (RAG, VectorDB, Embeddings, MCP, ToolSchema, Agentic, Planning, LLMOps) kao ponovo upotrebljivi moduli.
- Klaster odbrambenih mehanizama LLM (RedTeam, Normalize) za robusnost u uslovima napada.
- Paralelni setovi modula Go + Kotlin Multiplatform koji dele iste konvencije.

## Izazovi i rešenja

- **Izbegavanje truljenja sprega između desetina modula:** rešeno ugovorom o razdvajanju iz ustava i dinamičkim ubrizgavanjem specifičnosti potrošača.
- **Održavanje doslednosti i testiranosti mnogih modula:** rešeno zajedničkom konvencijom (testovi/dokumentacija/Izazovi po modulu) i upravljačkom kičmom HelixConstitution.
- **Pokrivenost više platformi:** rešeno ogledalom osnovnih modula za Kotlin Multiplatform.

## Tehnološki stek (zašto + kako)

- **Go** — većina modula (`digital.vasic.*`).
- **Kotlin Multiplatform** — moduli-ogledala za više platformi (Auth/Database/Security/UI/Concurrency/RateLimiter-KMP).
- **Redis / PostgreSQL / SQLite** — primitive za keš, bazu podataka i skladištenje.
- **Prometheus / OpenTelemetry** — modul za opservabilnost.
- **WebSocket / HTTP/3 (quic-go) / mDNS** — mrežni moduli.
- **Vector DB / embeddings / RAG / MCP** — moduli primitiva za AI.
- **YAML** — RedTeam napadački scenariji i konfiguracija.

> NEVERIFIKOVANO / U RAZVOJU: nekoliko organizacionih repozitorijuma označeno je kao „SCAFFOLD / U RAZVOJU" (npr. `PliniusCommon`, `I-LLM`, `HyperTune`, `AutoTemp`, `Veritas`, `Ouroborous`, `Claritas`, `LeakHub`, `GandalfSolutions`). Predstaviti ih kao rane faze/skelu, a ne kao isporučene proizvode.

