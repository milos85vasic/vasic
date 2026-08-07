---
name: LLMOrchestrator
slug: llmorchestrator
tier: helix-primary
order: 12
status: beta
license: Apache-2.0
private: false
tech:
  - Go (1.25)
  - Go stdlib (+ testify, yaml.v3)
  - Pipe transport (JSON-lines over stdio)
  - File transport (inbox/outbox/shared)
  - sync.Mutex / sync.Cond
  - Circuit breaker + HealthMonitor
  - pkg/i18n Translator
  - Challenge harness
repos:
  - https://github.com/HelixDevelopment/LLMOrchestrator
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Control-plane fan-out — MultiProviderPool spawning and driving OpenCode, Claude Code, Gemini, Junie, and Qwen Code, with a selector (round-robin / preference) choosing among them.
  - Hybrid protocol — side-by-side pipe path (interactive, JSON-lines, deadline+cap) vs file path (durable inbox/outbox/shared).
  - Resilience loop — per-agent circuit breaker state machine (closed → open → half-open) plus the health-monitor ping enabling recovery.
  - Anti-bluff gate — fixture → real parser/disk/JSON round-trip → asserted outcome, with the mutation branch shown failing (exit 99).
---

# LLMOrchestrator

**Jedinstvena kontrolna ravan za sve headless CLI kodirajuće agente.**

## Sažetak

LLMOrchestrator je samostalni, višekratno upotrebljiv Go modul za pokretanje, upravljanje i komunikaciju sa headless CLI agentima (OpenCode, Claude Code, Gemini, Junie, Qwen Code) putem hibridnog protokola cevi i fajlova, sa prekidačima kola po agentu, priključivim izborom više provajdera, odvojenom apstrakcijom za internacionalizaciju i garancijama protiv lažnih testova.

## Kratak opis

Višeput upotrebljiv Go modul koji pruža jedinstveni interfejs za pokretanje i upravljanje više LLM-om pokretanih CLI agenata putem hibridnog protokola cevi i fajlova. Nitno bezbedno grupisanje agenata sa prekidačima kola i izbornim strategijama rutiranja, namerno nezavisno od potrošača, sa priključivim prevodiocem za internacionalizaciju.

## Detaljan opis

LLMOrchestrator predstavlja zajedničku infrastrukturu za orkestriranje headless CLI kodirajućih agenata — onu pozadinsku strukturu koju svaki multiagentski sistem tiho zahteva, a obično se loše ponovo implementira. Umesto da svaki projekat ponovo razvija pokretanje procesa, uokvirivanje poruka i parsiranje rezultata za alate poput OpenCode-a, Claude Code-a, Gemini CLI, Junie i Qwen Code-a, ovaj modul nudi jedinstveni interfejs `Agent`, nitno bezbedan `AgentPool` i `MultiProviderPool` koji objedinjuje agente iz više provajdera iza jedinstvenog fasadnog interfejsa. Rutiranje je priključivo preko `AgentSelector`-a — kružno raspoređivanje koje preskače provajdere koji ne ispunjavaju zahteve, ili raspoređivanje po prioritetu sa rezervnim opcijama — tako da način distribucije posla predstavlja politiku koju birate, a ne unapred zadatu pretpostavku. Svaki konkretan agent je tanak adapter nad zajedničkim `BaseAdapter`-om koji upravlja celim životnim ciklusom procesa: pokretanje sa podešavanjem cevi, uredno zaustavljanje putem SIGTERM-a pa SIGKILL-a, ponovno pokretanje i provera aktivnosti — sve one zamorne, podložne greškama delove, rešene jednom za svagda.

Komunikacija je namerno hibridna, prilagođena zadatku. Cevni transport prenosi JSON poruke ograničene novim redom, sa vremenskim ograničenjem za čitanje po zahtevu i ograničenjem dužine odgovora za brzu interaktivnu razmenu, dok fajl-transport koristi direktorijume za ulazne/izlazne fajlove i deljene resurse po sesiji za velike ili trajne artefakte koji ne bi trebalo da borave u cevi. Otpornost na greške nije naknadna zamisao — ona je strukturna: prekidač kola po agentu se aktivira nakon tri uzastopna neuspeha, sa 60-sekundnim hlađenjem pre poluaktivne probe, a pozadinski monitor zdravlja pinguje agente kako bi onaj koji je pao mogao da se oporavi bez čekanja da ga saobraćaj primeti. Preuzimanje iz bazena blokira se na promenljivom uslovu umesto da troši procesorsko vreme u beskorisnom čekanju, a parser odgovora je bez stanja i bezbedan za konkurentno pozivanje. Modul je strogo odvojen — nikakve specifičnosti potrošača nisu dozvoljene da procure unutra — a svaki string vidljiv korisniku prolazi kroz priključivi i18n `Translator`, sa `NoopTranslator`-om koji vraća identifikatore poruka doslovno, tako da nedostajući prevod bude odmah uočljiv umesto da se krije.

## Zašto smo ga napravili

Svaki multiagentski sistem mora pouzdano da pokreće i komunicira sa CLI agentima. Ponovno rešavanje pokretanja, uokvirivanja, parsiranja i rukovanja greškama po projektu je rasipanje vremena i podložno greškama. LLMOrchestrator to centralizuje u jedan odvojeni, višekratno upotrebljiv modul čija specijalizovana odgovornost ga čini ponovo upotrebljivim — a ta ponovna upotrebljivost se gubi u trenutku kada bilo kakve specifičnosti potrošača procure unutra.


## Zašto je ovo revolucionarno

Pretvara "upravljanje vojskom heterogenih CLI agenata" iz prilagođenog inženjerskog muka po projektu u jednostavan uvoz biblioteke — sa rešenim i ojačanim grupisanjem, prekidanjem kola, upravljanjem životnim ciklusom i zamjenjivim rutiranjem. A pošto anti-bluf testovi proveravaju stvarni sistem od kraja do kraja umesto da se zadovolje sa "kompajlira se", dobijate apstrakciju kojoj možete zaista verovati da radi pod konkurentnošću i otkazima, a ne onu koja samo izgleda ispravno na dijagramu.

## Šta je inovativno

- **Hibridni protokol cev+datoteka** — interaktivna brzina (JSON linije preko stdin/stdout, rokovi za čitanje, ograničenja odgovora) *i* trajna razmena zasnovana na datotekama (inbox/outbox/zajednički prostor) za velike artefakte, tako da nikada ne morate da žrtvujete latenciju zarad trajnosti ili obrnuto.
- **Multi-provajderski bazen sa zamjenjivim selektorima** — jedan fasadni sloj preko više CLI provajdera, sa rutiranjem kružnim redom ili po prioritetu izabranim kao politika, a ne ugrađenim.
- **Prekidač kola po agentu + monitor zdravlja u pozadini** — automatska degradacija *i* oporavak (3 neuspeha → 60s otvoreno kolo → poluotvorena proba), tako da nestabilan agent bude izolovan, a zatim tiho vraćen u rad bez ručne intervencije.
- **Bazen bez zauzetog čekanja** — `Acquire` blokira na `sync.Cond` dok se ne oslobodi odgovarajući, zdrav agent ili dok se kontekst ne otkaže, tako da čekanje ne troši procesorsko vreme.
- **Stroga razdvojenost + anti-bluf i18n** — `NoopTranslator` vraća identifikatore poruka doslovno, tako da nedostajući prevod nije moguće prevideti umesto da se tiho ostavi prazan.
- **Sigurnost podrazumevano** — lista dozvoljenih binarnih putanja znači da nema interpolacije ljuske i stoga nema površine za ubacivanje komandi, podržano zaštitom od prelaska putanja, ograničenjem odgovora na 1 MiB protiv nekontrolisanog izlaza i maskiranjem API ključeva u zapisnicima.
- **Anti-bluf okvir za izazove** — stvarni ciklusi disk/JSON/parser kroz pet lokalizacija, sa uparenom mutacionom kapijom koja mora izaći sa nenultim statusom kada je funkcionalnost pokvarena — test koji dokazuje da stvarno može da otkaže.

## Najveći tehnički izazovi i kako smo ih rešili

- **Pouzdan I/O agenata.** Komunikacija sa pokrenutim CLI procesom je varljivo teška; rešeno hibridnim transportom cev+datoteka, definisanim ugovorom poruka/parsera tako da obe strane dogovore format na žici, i `BaseAdapter`-om koji centralizuje ceo životni ciklus procesa, uključujući elegantan SIGTERM tajmaut koji eskalira na SIGKILL kao rezervnu opciju.
- **Konkurentnost bez zauzetog čekanja.** Rešeno pomoću `AgentPool`-a sa mutexom i uslovnom promenljivom, gde `Acquire` spava dok se ne oslobodi agent sa odgovarajućim mogućnostima, upareno sa bezstanjskim parserom bez sporednih efekata koji je bezbedan za pozivanje iz više gorutina istovremeno.
- **Izolacija otkaza provajdera.** Rešeno tako da jedan loš provajder ne može da povuče ostale: prekidači kola po agentu ograničavaju radijus eksplozije, a gorutina monitora zdravlja pokreće oporavak čak i kada nema zahteva koji bi ga aktivirali.
- **Dokazivanje ispravnosti, a ne samo kompajliranja.** Rešeno pomoću pokretača izazova: desetine invarijanti na en/sr/ja/es/de koje testiraju stvarni sistem, plus uparena mutaciona kapija (`LLMORCH_MUTATE_RUNNER=1` mora da otkaže → omotač izlazi sa 99) koja namerno kvari funkcionalnost kako bi dokazala da sama kapija nije bluf.
- **Lokalizacija bez tihog otkaza.** Rešeno šavom `NoopTranslator`-a sa doslovnim identifikatorima i ubrizgavanjem prevodioca po potrošaču, tako da praznina u prevodima uvek bude vidljiva umesto da se prikrije.


## Tehnološki stek

- **Go (1.25)** — izabran zbog vrhunske konkurentnosti i čiste kontrole procesa, što je upravo ono što zahteva orkestracija procesa živih agenata; implementira modul, njegove adaptere za agente, transportne mehanizme i parser.
- **Go stdlib (uz testify, yaml.v3)** — namerni izbor da se površina zavisnosti svede na minimum i da se *ne* uvlače LLM SDK-ovi, kako bi modul ostao lagan i mogao da se ugradi u bilo kog korisnika bez prenošenja dodatnog tereta.
- **Transport putem cevi (JSON-lines preko stdio)** — izabran za brzu interaktivnu razmenu poruka, ojačan vremenskim ograničenjima za čitanje i ograničenjima dužine odgovora kako bi se sprečilo da zablokiran ili nekontrolisan agent blokira pozivaoca.
- **Transport putem fajlova (inbox/outbox/zajednički)** — izabran za trajniju razmenu velikih artefakata po sesiji, gde bi cev bila pogrešan alat.
- **`sync.Mutex`/`sync.Cond`** — izabrani za implementaciju blokirajućeg, pravičnog preuzimanja agenata iz bazena bez aktivnog čekanja.
- **Prekidač strujnog kola + Nadglednik zdravlja** — izabrani zajedno kako bi obezbedili otpornost po agentu *i* aktivan oporavak, a ne samo detekciju grešaka.
- **`pkg/i18n` Prevodilac** — izabran kao odvojeni sloj za lokalizaciju koji drži specifične stringove korisnika izvan jezgra.
- **Okvir za izazove (`challenges/runner`) + Makefile (`test -race`, `fuzz`, `cover`)** — izabran za proveru zasnovanu na dokazima, uključujući detekciju trka i fuzzing parsera kako bi se ispravnost dokazala u nepovoljnim uslovima, a ne samo pretpostavila.

## Status i napomene o iskrenosti

- **Status: beta.** Odvojeni modul za višekratnu upotrebu, koji se koristi kao podmodul u više Helix/vasic projekata. **Licenca: Apache-2.0**; repozitorijum GitHub je javno dostupan.
- Metapodaci modela dolaze iz LLMsVerifier preko HelixQA; ovaj modul ne uvozi LLMsVerifier/VisionEngine/DocProcessor direktno. Stekovi navedeni u `CLAUDE.md` matične aplikacije (Gin/PostgreSQL itd.) opisuju `helix_code`, a ne ovaj modul.

**Prioritetni nivo:** Helix-primarni (LLM-infrastrukturni klaster — odvojeni modul za višekratnu upotrebu). Rangira se iza HelixTrack.

