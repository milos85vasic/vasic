---
name: HelixTranslate
slug: helixtranslate
tier: helix-primary
order: 10
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - QUIC / HTTP/3 (quic-go)
  - gRPC + Protocol Buffers
  - Gorilla WebSocket
  - PostgreSQL
  - SQLite
  - Redis
  - unidoc/unioffice + unipdf
  - Cobra
  - LLMsVerifier bridge
  - Docker / Podman
repos:
  - https://github.com/HelixDevelopment/HelixTranslate
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Provider-routing / no-silent-fallback flow (signature) — request → is provider explicit? → is a verified model available? → strongest-verified selection with deterministic fallback chain; every "no" branch terminating in a red honest hard error, with local runtimes crossed out.
  - Verification-gated model selection — LLMsVerifier scores models (responsiveness / code / feature-richness / reliability) → only verified, positively-scored models enter the eligible pool → HelixTranslate picks the top one.
  - Real-time monitoring pipeline — Translation CLI → typed WebSocket events → Monitoring Server → live Web Dashboard, with remote SSH workers feeding distributed translation.
  - Multi-format ebook flow — FB2/EPUB/PDF/DOCX/HTML/TXT in → parse → translate (verified model) → multi-pass polish → regenerate target format.
---

# HelixTranslate

**Verifikovani prevod knjiga — pošten po dizajnu, nikada nijemi fallback.**

## Sažetak

HelixTranslate je visoko performantna platforma za prevođenje e-knjiga zasnovana na Go, koja prevodi knjige između 100+ jezika koristeći verifikovane pružaoce LLM, uz praćenje u realnom vremenu putem WebSocket i strogu politiku bez nijemog fallback-a — sistem propada glasno umesto da se tiho degradira.

## Kratak opis

Univerzalni alat za prevođenje e-knjiga zasnovan na Go. Prevodi formate FB2, EPUB, TXT, HTML, PDF i DOCX na 100+ jezika koristeći najjače verifikovane modele LLM (putem mosta LLMsVerifier), sa REST/HTTP-3 i gRPC API-jima, distribuiranom obradom i kontrolnom tablom za praćenje u realnom vremenu putem WebSocket.

## Detaljan opis

HelixTranslate je sistem za prevođenje celih knjiga između jezika na nivou preduzeća, zasnovan na Go, koji koristi pružaoce LLM — ne prevodi paragrafe ili fragmente, već kompletna dela, od početka do kraja. Obrađuje i generiše više formata e-knjiga (FB2, EPUB, TXT, HTML, PDF, DOCX), podržava 100+ jezika sa automatskim prepoznavanjem i nudi kako CLI alate, tako i API servere (REST preko HTTP/3, gRPC i tok događaja WebSocket), što ga čini podjednako pogodnim za rad u terminalu i za servisnu mrežu. Njegova ključna odlika je *način izbora modela*: umesto da se hardkodira pružalac i nada da će ostati stabilan, HelixTranslate delegira svu ovlašćenost za modele mostu LLMsVerifier (`pkg/bridge`), koji bira najjači *verifikovani* API model i vraća deterministički, rangirani lanac fallback opcija. Izbor modela zasniva se na ponderisanom skoriranju po brzini odgovora, kodu, bogatstvu funkcija i pouzdanosti — tako da model koji prevodi vašu knjigu zaslužuje svoje mesto dokazanim performansama, a ne time što je naveden u konfiguracionoj datoteci.

Ključno je da sistem u kodu strogo primenjuje pravilo „bez nijemog fallback-a": ako ključ API pružaoca nije prisutan ili operater eksplicitno zahteva nedostupnog pružaoca, cevovod vraća otvorenu grešku umesto da tiho menja pružaoce ili prelazi na lokalni runtime i pravi se da je sve u redu — ovo pravilo je fiksirano posebnom pre-build proverom i uparenim mutacionim testom. Lokalni runtime-ovi (Ollama, llama.cpp) namerno su uklonjeni iz podrazumevanog toka kako slabiji mehanizam nikada ne bi mogao da tiho zameni verifikovani. Oko jezgra za prevođenje nalazi se podsistem za praćenje u realnom vremenu putem WebSocket: alat za prevođenje emituje tipizovane događaje na monitoring server koji pokreće uživo veb kontrolnu tablu, dok udaljeni SSH radnici raspoređuju posao za distribuirano prevođenje. Dodatni slojevi uključuju višestruko poliranje za doslednost, analizu kvaliteta u fazi pripreme, keširanje prevoda kako bi se kontrolisali troškovi za duge ulaze i vizuelno vođenu kontrolu kvaliteta. Cela platforma odgovara ustavu inženjeringa protiv blefiranja: testovi moraju da dokažu stvarne, vidljive rezultate za korisnike, podržani obaveznim mutacionim testiranjem umesto zelenih kvačica koje ništa ne dokazuju.

## Zašto smo ga izgradili

Da bismo pouzdano i *iskreno* prevodili knjige u celini — nikada ne dostavljajući prevod koji je „prisutan, ali degradiran". Osnovna pretpostavka dizajna je da nedostajući ili neprovereni prevod mora biti glasna, jasna greška, i da izbor modela uvek mora da se rešava u korist zaista proverenog pružaoca, a ne nekog unapred zadatog nagađanja ili tihog lokalnog rezervnog rešenja.

## Zašto je ovo revolucionarno

Većina LLM prevodilačkih tokova neuspehe prikriva — tiho prelazi na slabiji model, spušta se na lokalno izvršavanje ili emituje delimičan rezultat dok testni skup i dalje sija zeleno i niko ne primećuje pad kvaliteta. HelixTranslate čitav taj način otkazivanja čini strukturalno nemogućim: izbor modela je zaštićen verifikacijom, lanac rezervnih rešenja je deterministički i potpuno transparentan, a „nema ključa / nema proverenog modela" rezultira iskrenom, jasnom greškom umesto tihog sleganja ramenima. Ta jedina odluka u dizajnu pretvara pitanje *„Da li je ovaj prevod zaista izvršen na sposobnom, proverenom modelu?"* iz nade koju ne možete proveriti u garanciju koju sistem nameće u vaše ime.

## Šta je inovativno

- **Verifikacijom kontrolisano usmeravanje modela** preko LLMsVerifier mosta — automatski se bira najjači *provereni* model, tako da operatori izražavaju nameru, a ne imena dobavljača, i nikada ne biraju pružaoca koji možda nije dostupan.
- **Garancija bez tihih rezervnih rešenja, sprovedena u kodu** — četiri eksplicitne grane usmeravanja (mock / eksplicitni-verifikator / eksplicitni-pružalac / most-po-podrazumevanom), od kojih svaka javlja grešku umesto da tiho pređe na drugo rešenje, uz namerno uklanjanje lokalnih izvršavanja iz podrazumevanog toka kako ne bi postojalo ništa slabije na šta bi se moglo preći.
- **Mehanička provera** — `CM-NO-LOCAL-RUNTIME` pre-build kontrola, zajedno sa uparenim mutacionim testom, potvrđuje prilikom kompajliranja da se na podrazumevanom putu nikada ne kreira klijent za lokalno izvršavanje: garancija ne može da zastari jer se build prekida ako do toga dođe.
- **Deterministički, po-rejtingu uređen lanac rezervnih rešenja** — dozvoljeno je i potpuno transparentno prebacivanje sa jednog na drugi *provereni* model, što je principijelno drugačije od zabranjenog tihog prebacivanja: uvek znate koji je sposoban model preuzeo posao.
- **Praćenje u realnom vremenu putem WebSocket** — tipizovani događaji prevođenja se uživo strimuju na kontrolnu tablu, uz distribuirane SSH radnike tako da posao veličine knjige postaje vidljiv i paralelan, a ne crna kutija.
- **Režim anti-bluf testiranja** — mutaciono testiranje, negativne tvrdnje, testovi na stvarnim sistemima i vizuelno vođena kontrola kvaliteta zajedno osiguravaju da „testovi prolaze" nikada ne može tiho da prikrije činjenicu da „funkcija zapravo ne radi".

## Najveći tehnički izazovi i kako smo ih rešili

- **Garantovanje iskrenog prevodilačkog toka (bez tihog pogoršanja).** Rešeno centralizacijom svih ovlašćenja za izbor modela u LLMsVerifier mostu, tako da postoji jedinstvena tačka odlučivanja koju je moguće nadzirati, kodiranjem četiri eksplicitne grane usmeravanja koje svaka javljaju grešku umesto da nagađaju, potpunim uklanjanjem lokalnih rezervnih rešenja iz podrazumevanog toka i zavarivanjem pravila pomoću pre-build kontrole i mutacionog testa koji prekida kompajliranje ako se garancija ikada ukine.
- **„Zeleni testovi, pokvarene funkcije."** Ustav direktno imenuje ovaj način otkazivanja i suzbija ga režimom Anti-Bluf Testiranja: konkretne, korisniku vidljive tvrdnje umesto tehničkih detalja, stvarni sistemi u petlji (mockovi ograničeni na unit testove), obavezno mutaciono testiranje (namerno se kvari funkcija i test *mora* da pocrveni) i vizuelno potvrđena kontrola kvaliteta koja stvarno pregleda rezultat.
- **Kvalitet dugih formata i više formata.** Ulazi veličine knjige opterećuju i konzistentnost i budžet; rešeno višestrukim prolazima dorade koji ponovo razmatraju tekst, analizom u fazi pripreme koja procenjuje obim posla unapred i keširanjem prevoda kako se ne bi dvaput plaćao isti odlomak.


## Tehnološki stek

- **Go** — izabran zbog svojih primitiva za konkurentnost, koji se prirodno mapiraju na paralelno parsiranje, prevođenje i strimovanje više poglavlja istovremeno; backend visokog stepena konkurentnosti, modul `digital.vasic.translator`.
- **Gin** — izabran kao brz i minimalistički HTTP ruter za servisiranje REST API interfejsa.
- **QUIC / HTTP/3 (quic-go)** — izabrani kako bi REST API dobio niskolatentni, moderan transportni protokol koji izdržava nesavršene mreže.
- **gRPC + Protocol Buffers** — izabrani za strogo tipiziran, visokoperformansni servisni interfejs koji radi paralelno sa REST za programatske pozivaoce.
- **Gorilla WebSocket** — izabran za prenos strima događaja prevođenja u realnom vremenu koji napaja monitoring kontrolnu tablu uživo.
- **PostgreSQL, SQLite, Redis** — namerno podeljen u tri nivoa: PostgreSQL za trajne relacione podatke, SQLite za lokalno/ugrađeno stanje (takođe podržava skladište verifikovanih modela mosta, `data/verified_models.db`), a Redis kao vrući keš.
- **unidoc/unioffice + unipdf** — izabrani za obradu zahtevnih formata: parsiranje i regeneraciju DOCX i PDF fajlova kako bi e-knjige u više formata bile verno konvertovane u oba smera.
- **Cobra** — izabran kao CLI okvir koji pokreće `unified-translator` i prateće alate.
- **golang-jwt (JWT HS256)** — izabran za bezstanično API autentifikaciju, u kombinaciji sa ograničenjem protoka tokena po IP adresi i TLS/QUIC sigurnošću transporta kako bi se površina dodatno ojačala.
- **LLMsVerifier most (`pkg/bridge`)** — ključni element: obezbeđuje najjači verifikovani model zajedno sa determinističkim lancem rezervnih rešenja i služi kao jedina tačka sprovođenja garancije da neće biti tihih rezervnih opcija.
- **Testify** — izabran za Go testni paket, uključujući posvećeni `provider_routing_test.go` i mutacione provere koje održavaju poštenost pravila.
- **Docker / Podman (rootless) + Compose** — izabrani za kontejnerizovano, distribuirano raspoređivanje (`docker-compose.distributed.yml`), sa rootless Podman varijantom radi boljeg sigurnosnog profila.

## Status i napomene o poštenju

- **Status: beta.** Funkcionalna platforma; verzija je navedena nedosledno u `VERSION`/Makefile/`AGENTS.md`, pa se smatra nedefinisanom.
- **Licenca: nije konačno određena.** U README-u se navodi MIT, ali to nije potvrđeno u odnosu na LICENSE fajl — proveriti pre navođenja.
- Endpointi kontrolne table/monitora su dostupni samo lokalno, nisu javni. Performanse WebSocket navedene u dokumentaciji su ciljne vrednosti, a ne verifikovane. `ARCHITECTURE.md` još uvek navodi uklonjene Ollama/lokalne motore (zastarelo).

**Prioritetni nivo:** Helix-primary (LLM-infrastrukturni klaster). Rangiran unutar porodice Helix platforme, iza HelixTrack.

