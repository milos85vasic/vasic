---
name: LLMProvider
slug: llmprovider
tier: helix-primary
order: 13
status: beta
license: TBD
private: false
tech:
  - Go (1.25.3)
  - net/http (stdlib)
  - logrus
  - testify
  - yaml.v3
  - digital.vasic.models
  - circuit / health / retry / apikeys / discovery packages
  - 43 provider adapters + generic OpenAI-compatible adapter
repos:
  - https://github.com/HelixDevelopment/LLMProvider
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Interface hub — application → single LLMProvider interface → 43 adapters + the generic OpenAI-compatible adapter (fanning out to vendor endpoints).
  - Circuit-breaker state machine — closed → open → half-open, wrapping both Complete and the CompleteStream channel.
  - Retry timeline — exponential backoff + jitter with status-aware retry/skip decisions and context cancellation.
  - Honest discovery — live provider /v1/models + TTL cache; failure path returns nothing (old hardcoded tier crossed out), contrasted with the credential single-source (apikeys).
---

# LLMProvider

**Jedan interfejs, 43 provajdera — sa ugrađenim prekidačima strujnog kola, ponovnim pokušajima i monitoringom zdravlja.**

## Sažetak

LLMProvider je generički, višekratno upotrebljiv modul Go koji definiše ujedinjeni interfejs `LLMProvider`, zajedno sa obrascima otpornosti na greške — prekidačem strujnog kola, monitoringom zdravlja, ponovnim pokušajima sa eksponencijalnim odlaganjem, lenjim učitavanjem — i isporučuje 43 konkretne implementacije provajdera iza tog jednog ugovora, uz generički adapter kompatibilan sa OpenAI i poštenim, bez unapred kodiranih rezervnih rešenja za otkrivanje modela.

## Kratak opis

Višeput upotrebljiv modul Go koji izlaže jedan interfejs `LLMProvider` (`Complete`, `CompleteStream`, `HealthCheck`, `GetCapabilities`, `ValidateConfig`) zajedno sa primitivima za toleranciju grešaka — prekidačem strujnog kola, monitorom zdravlja, ponovnim pokušajima sa eksponencijalnim odlaganjem i nasumičnim kašnjenjem, lenjom inicijalizacijom — preko 43 adaptera provajdera i generičkog adaptera kompatibilnog sa OpenAI. Bezbedan za rad u više niti.

## Detaljan opis

LLMProvider je apstrakcioni sloj koji svaka usluga koja koristi LLM treba, ali ga gotovo niko ne gradi kako treba — neugledna infrastruktura koja razdvaja demonstraciju od sistema koji preživljava kontakt sa stvarnim saobraćajem. Definiše jedan interfejs svestan mogućnosti — `Complete`, `CompleteStream`, `HealthCheck`, `GetCapabilities`, `ValidateConfig` — tako da aplikativni kod cilja tačno jedan ugovor, bez obzira koji od 43 pozadinska sistema odgovara na poziv, a zatim isporučuje operativno učvršćivanje koje pretvara krhke pozive provajdera u nešto što možete pokrenuti u produkciji bez zadržavanja daha. Trostanjni prekidač strujnog kola (zatvoren → otvoren → polu-otvoren) transparentno obavija bilo kog provajdera — *uključujući i njegov streaming kanal*, gde se prazan tok ispravno računa kao greška — tako da jedan loše ponašajući pozadinski sistem može da aktivira prekidač i spreči da obori celu uslugu; centralni `CircuitBreakerManager` prati sve prekidače odjednom. Konfigurabilni monitor zdravlja kontinuirano proverava provajdere kroz stanja zdravo / degradirano / nezdravo / nepoznato na osnovu provera sa pragovima i intervalima, tako da se degradacija uočava, a ne otkriva tek kada dođe do prekida u radu. Logika ponovnih pokušaja kombinuje eksponencijalno odlaganje sa nasumičnim kašnjenjem, donoseći odluke na osnovu statusa — ponavlja greške vredne ponavljanja (429, 5xx, prolazne mrežne greške), nikada ne troši resurse na 4xx ili otkazani kontekst — sa ograničenim kašnjenjima kako bi se sprečila oluja odlaganja. Lenja inicijalizacija odlaže konstrukciju svakog provajdera do njegove prve stvarne upotrebe — namerni dizajnerski izbor koji čini registraciju svih 43 provajdera praktično besplatnom.

Modul isporučuje 43 konkretna paketa provajdera uz generički adapter kompatibilan sa OpenAI, koji implementira ceo interfejs za *bilo koji* endpoint `/v1/chat/completions` — autentifikaciju putem Bearer tokena, SSE streaming sa ispravnim rukovanjem `[DONE]` — tako da provajder bez namenskog paketa i dalje postaje prvoklasni građanin čim adapter usmerite na njegov URL. Kredencijali se razrešavaju na tačno jednom mestu (`apikeys`, koristeći striktnu konvenciju `ApiKey_<Provider>`), čime se na izvoru zatvara cela klasa grešaka tipa „hardkodirani ključ prolazi testove, pravi ključ nije povezan, proizvod otkazuje u produkciji". Otkrivanje modela je namerno, gotovo uporno pošteno: ispituje žive API-je provajdera iza keša sa ograničenim trajanjem, a — prema pravilima upravljanja — stari sloj sa hardkodiranim rezervnim rešenjima je potpuno uklonjen. Kada otkrivanje uživo ne uspe, LLMProvider ne vraća *ništa* umesto zastarelog kataloga, tako da pozivalac nikada ne dobije ID modela koji izgleda validno, a zatim se ne može pozvati. Svaki deo ovog sistema napravljen je da bude bezbedan za rad u više niti.


## Zašto smo ga izgradili

Naivni pozivi LLM u produkciji otkazuju — provajderi ograničavaju brzinu, degradiraju ili padaju, a jedan loš backend može povući čitavu uslugu sa sobom. Katalozi modela se menjaju, a hardkodirane liste prosleđuju pozivaocima ID-eve koji više ne rade. LLMProvider centralizuje interfejs, obrasce otpornosti i pouzdano otkrivanje, tako da svaki potrošač automatski nasleđuje toleranciju na greške i istinitost.

## Zašto je ovo revolucionarno

Smanjuje „integraciju provajdera LLM" na jedan jedini potez — implementirajte jedan interfejs ili jednostavno usmerite generički adapter na krajnju tačku — a zatim taj provajder automatski i transparentno obavijaju prekidač kola, praćenje zdravlja i ponovni pokušaji sa eksponencijalnim odlaganjem i nasumičnim kašnjenjem. Otpornost prestaje da bude nešto što svaki tim ponovo izmišlja (loše, pod pritiskom roka, nakon prvog pada) i postaje podrazumevano ponašanje biblioteke za svih 43 backenda. Inženjering pouzdanosti je napisan jednom, strogo testiran i besplatno nasleđen od svakog ko ga uvozi.

## Šta je inovativno

- **Jedan interfejs svestan mogućnosti** — kompletiranje, strimovanje, zdravlje, mogućnosti i validacija konfiguracije svedeni na jedan ugovor koji svaki backend poštuje na identičan način.
- **Transparentno obavijanje prekidačem kola — uključujući strimove.** Prekidač štiti kanal `CompleteStream`, a ne samo zahtev/odgovor, i tretira prazan strim kao grešku kakva zaista jeste — sa obaveštenjima za slušaoce koja su bezbedna od mrtve petlje i izvan zaključavanja.
- **43 paketa za provajdere + generički adapter kompatibilan sa OpenAI** — namenski paketi ostaju lagani, a svaki nenabrojani prodavac koji podržava `/v1/chat/completions` radi čim usmerite adapter na njega.
- **Jedinstveni autoritet za kredencijale (`apikeys`)** — tačno jedno mesto čita promenljive okruženja `ApiKey_<Provider>`, strukturalno eliminišući nesklad „zeleni testovi, pokvaren proizvod" umesto da samo upozorava na njega.
- **Pošteno otkrivanje modela (bez hardkodiranog fallback-a)** — živi API-ji provajdera iza keša sa vremenom trajanja; u slučaju greške vraća `nil`, nikad zastareo ili izmišljen katalog koji prosleđuje ID-eve koji se ne mogu pozvati.
- **Lenja inicijalizacija sa `sync.Once`** — konstrukcija se odlaže do prve upotrebe, tako da registracija svih 43 provajdera gotovo ništa ne košta dok zapravo ne pozovete nekog.
- **Antibluf, višeregionalni Challenge stek** — pravi pokretač koji testira ponašanje prekidača kola, zdravlja i ponovnih pokušaja u pet regiona, kontrolisan uparenim mutacionim testiranjem (nemutirani kod mora izaći sa statusom 0; ubrizgana mutacija mora forsirati izlaz 99), tako da uspešno izvršen testni skup dokazivo znači da ponašanje radi.

## Najveći tehnički izazovi i kako smo ih rešili

- **Kaskadne greške provajdera.** Jedan nestabilan backend ne sme povući čitavu uslugu sa sobom. Rešeno trostanjim prekidačem kola (zatvoren → otvoren → poluotvoren) koji transparentno obavija bilo kog provajdera *i njegov strim*, otvara se pri trajnom otkazu, ispituje oporavak u poluotvorenom stanju i centralno koordinira `CircuitBreakerManager`.
- **Prolazne greške i ograničenja brzine.** Rešeno eksponencijalnim odlaganjem sa nasumičnim kašnjenjem koje je svesno statusa — `min(PočetnoOdlaganje·Množilac^(n-1), MaksimalnoOdlaganje) ± nasumičnoKašnjenje` — tako da se ponovni pokušaji rasporede umesto da se sinhronizuju u „gromoglasno stado". Ponavlja tačno ono što treba ponoviti (429, 500, 502, 503, 504 i mrežne greške) i odbija da troši pokušaje na otkazani kontekst ili bilo koji drugi 4xx.
- **Skaliranje na mnogo registrovanih, a neiskorišćenih provajdera.** Sa 43 registrovanih provajdera, od kojih je samo nekoliko aktivno u datoj usluzi, rana inicijalizacija bila bi čista gubitak. Rešeno lenjom inicijalizacijom zaštićenom sa `sync.Once`, tako da samo provajderi koje zapravo pozovete plaćaju troškove podešavanja.
- **Dodeljivanje nevažećih ID-eva modela.** Rešeno potpunim uklanjanjem hardkodiranog fallback nivoa za otkrivanje (prema CONST-036) i vraćanjem ničega pri otkazu živog otkrivanja — uz defanzivno kopiranje pri vraćanju, tako da pozivalac ne može da mutira keš ili da se utrkuje sa drugim čitačem. Istinitost je strukturalno nametnuta, a ne konvencijom.
- **Strimovanje + ispravnost konkurentnosti.** Suptilni način otkaza je mrtva petlja između zaključavanja prekidača i njegovih povratnih poziva za slušaoce. Rešeno snimkom slušalaca i obaveštavanjem van zaključavanja sa vremenskim ograničenjem od 5 sekundi, kao i otključavanjem pre obaveštavanja pri resetovanju — uz sve komponente izgrađene za konkurentnu upotrebu i proverene testovima za utrke (`-race` skup).


## Tehnološki stek

- **Go (1.25.3)** — izabran zbog vrhunske konkurentnosti, statičkih binarnih fajlova i snažne standardne biblioteke; sadrži modul, interfejs, sve primitive za otpornost i svih 43 adaptera.
- **`net/http` (stdlib)** — namerno nezavisni HTTP: pokreće klijente za pojedinačne provajdere, generički adapter kompatibilan sa OpenAI i pozive za dinamičko otkrivanje, tako da nema potrebe za revizijom ili ažuriranjem trećepartijskog transporta.
- **logrus** — strukturirano, nivoom svesti logovanje tačno tamo gde operaterima treba vidljivost: unutar promena stanja prekidača kola i putanje otkrivanja.
- **testify** — pokreće testni set i, ključno, fiksiranje mutacionih grana koje daju smisao uspešnom izvršavanju.
- **yaml.v3** — parsira i18n pakete i konfiguraciju u formatu koji ostaje čitljiv za ljude.
- **`digital.vasic.models`** — zajednički tipovi `LLMRequest` / `LLMResponse` / `ProviderCapabilities`, smešteni na jednom mestu kako bi svi adapteri govorili istim rečnikom (dokumentovana runtime zavisnost).
- **Interni paketi** — `circuit`, `health`, `retry`, `apikeys`, `discovery`, `providers/` (43 provajdera + `generic`) i `i18n`: površina za otpornost i integraciju podeljena na male, nezavisno testirane jedinice umesto jednog monolitnog sistema.
- **`.env` + `~/api_keys.sh` (konvencija `ApiKey_<Provider>`)** — jedinstven, nedvosmislen izvor istine za akreditive, tako da se ključevi povezuju na isti način i u testovima i u produkciji.
- **Makefile race suite (`-race -p 1`) + Challenge pokretač** — stub otporan na blefiranje: detektor trka dokazuje ispravnost konkurentnosti, a Challenge pokretač testira stvarno ponašanje kroz haos, ddos, skaliranje, stres, dinamičko otkrivanje i scenarije bez pauza.

## Status i napomene o iskrenosti

- **Status: beta.** Odvojeni, ponovo upotrebljivi modul; repozitorijum GitHub je javno dostupan.
- **Licenca: nije definitivno određena.** Nedosledna — `doc.go` navodi MIT, dok je prisutan fajl LICENSE u stilu Apache-2.0 — proveriti pre objavljivanja.
- LLMsVerifier je uzvodni jedini izvor istine za kanonički katalog modela. Manifest `helix-deps.yaml` izgleda zastareo (navodi `deps: []`, dok dokumentacija tvrdi da postoji zavisnost od `digital.vasic.models`); „Tier 2 (models.dev)" u okviru otkrivanja je planirana, ali još neaktivna zamena.

**Prioritetni nivo:** Helix-primary (klaster LLM-infrastructure — odvojeni, ponovo upotrebljivi modul). Rangira se iza HelixTrack.

