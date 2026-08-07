---
name: HelixCode
slug: helixcode
tier: helix-primary
order: 2
status: beta
license: MIT
private: false
tech:
  - Go
  - Gin
  - PostgreSQL
  - Redis
  - SSH
  - Model Context Protocol
  - llama.cpp
  - Ollama
repos:
  - https://github.com/HelixDevelopment/HelixCode
diagrams:
  - Layered architecture — API layer (REST/WebSocket/MCP) over core services (auth, worker pool, task/checkpointing, project/workflow, LLM) over the PostgreSQL + Redis data layer.
  - Distributed worker topology — a HelixCode server orchestrating SSH-connected workers across Linux/macOS/Windows/Aurora/SymphonyOS with health-monitoring indicators.
  - Task lifecycle / work-preservation flow — task division → distributed execution → checkpoint → rollback/resume, as a timeline.
  - Development workflow pipeline — planning → building → testing → refactoring with dependency arrows and multi-session context.
---

# HelixCode

**Distribuirana AI razvojna platforma koja deli posao, čuva ga i nikada ne gubi vaše mesto.**

## Sažetak

HelixCode je preduzetnička, Go-bazirana distribuirana AI razvojna platforma koja deli razvojne zadatke na inteligentno podeljene podzadatke raspoređene po mreži radnika upravljanih putem SSH, sa automatskim čuvanjem stanja i povratkom na prethodne verzije kako ni jedan deo posla nikada ne bi bio izgubljen. Ona objedinjuje integraciju više LLM provajdera, radne tokove tokom celog razvojnog ciklusa i isporuku na više platformi iza REST, CLI, TUI i MCP interfejsa.

## Kratak opis

HelixCode je distribuirana AI razvojna platforma napisana u Go. Deli posao na inteligentne zadatke raspoređene po mreži radnika zasnovanoj na SSH, čuva napredak automatskim čuvanjem stanja i povratkom na prethodne verzije, integriše više LLM provajdera i pokreće ceo razvojni ciklus preko REST, CLI, TUI i MCP interfejsa.

## Detaljan opis

HelixCode je preduzetnička distribuirana AI razvojna platforma (`dev.helix.code`, MIT) izgrađena oko jednostavnog obećanja koje njen slogan doslovno ispunjava: podeli posao, sačuvaj ga i nikada ne izgubi svoje mesto. Dizajnirana je za inteligentnu podelu zadataka, automatsko čuvanje napretka i razvojne tokove na više platformi, a napisana je u Go zbog konkurentnosti i prenosivosti u vidu jednog binarnog fajla koje distribuirano računarstvo zahteva — sa automatskim čuvanjem stanja, povratkom na prethodne verzije i praćenjem u realnom vremenu kao osnovnim, a ne opcionim funkcijama.

Njena arhitektura postavlja REST + WebSocket + MCP API sloj iznad skupa fokusiranih osnovnih servisa — JWT autentifikaciju i upravljanje sesijama, upravljanje bazenom radnika zasnovanim na SSH sa praćenjem stanja, upravljanje zadacima sa čuvanjem stanja i rukovanjem zavisnostima, upravljanje projektima i radnim tokovima, kao i objedinjeni sloj LLM provajdera — sve sačuvano na PostgreSQL, dok je Redis dostupan kao opcioni sloj za koordinaciju i keširanje. Distribuirani radnici se automatski instaliraju preko mreže, tako da je proširivanje sistema jednostavno usmeravanje servera na mašinu umesto ručnog podešavanja, a multi-klient interfejsi obuhvataju CLI, terminalski interfejs, REST i mobilne okvire, čime je ista platforma dostupna iz skripte, terminala ili aplikacije.

HelixCode pokreće kompletan razvojni ciklus od početka do kraja: planiranje, izgradnja, testiranje i refaktorisanje se izvršavaju automatski uz praćenje zavisnosti i konteksta više sesija, tako da dugoročni napori zadržavaju svoju nit kroz prekide i granice između mašina. Integriše više LLM provajdera — llama.cpp, Ollama i OpenAI — iza jednog interfejsa, a zatim dodaje izbor modela svestan hardvera koji detektuje dostupne CPU/GPU/memoriju i prilagođava model mašini, kao i podršku za napredne strategije rezonovanja poput lančanog razmišljanja i stabla razmišljanja za probleme koji zahtevaju više od jednog prolaza. Model Context Protocol je implementiran preko više transportnih protokola za standardizovanu razmenu alata i konteksta, a obaveštenja na više kanala (Slack, Discord, Email, Telegram) obaveštavaju timove o napretku distribuiranog rada. Podržane su platforme Linux, macOS, Windows, Aurora OS i SymphonyOS.

## Zašto smo ga izgradili

Razvoj koji se odvija na više mašina uz pomoć AI obično gubi kontekst i napredak kada se zadaci razdvoje ili prekinu. HelixCode je stvoren da podelu zadataka učini inteligentnom, a očuvanje rada automatskim — kako bi se veliki razvojni napor mogao razložiti, rasporediti po mreži radnika, kontrolisati tačkama provera i nastaviti ili vratiti unazad bez gubitka stanja.

## Zašto je revolucionaran

On čini razvoj uz pomoć AI *izdržljivim* — sposobnost koja nikada ranije nije bila praktična kada su timovi ručno spajali ove delove. Tri stvari koje obično postoje u tri odvojena alata sada postaju jedna platforma: distribuirano izračunavanje (mreže radnika SSH sa automatskom instalacijom i praćenjem zdravlja), pomoć u razvoju uz AI (LLM-ovi sa više pružalaca usluga, sposobni za rezonovanje i pozivanje alata) i automatizacija radnih tokova tokom celog životnog ciklusa. Spojno tkivo je provera tačaka oslonjena na bazu podataka: pošto se stanje zadatka, tačke provera i zavisnosti čuvaju u PostgreSQL, posao koji se proteže preko više mašina i sesija može se vratiti unazad ili nastaviti tačno tamo gde je stao. Prekidi i podela rada prestaju da budu izvor izgubljenog napretka i postaju rutinski, obnovljivi događaji.

## Šta je inovativno

- Očuvanje rada kao osnovni princip: automatska provera tačaka i vraćanje unazad primenjeno na *distribuirane* razvojne zadatke, tako da napredak preživi prekide i otkazivanje mašina umesto da nestane s njima.
- Izbor modela svesnog hardvera koji analizira detektovani CPU/GPU/memoriju i svakom zadatku dodeljuje model koji mašina zaista može dobro da pokrene — bez ručnog podešavanja po radnicima.
- Jedna platforma, pet ulaza: REST, WebSocket, CLI, TUI i MCP, pri čemu je sam MCP dostupan preko više protokola tako da se alati i agenti mogu integrisati bez obzira na način povezivanja.
- Podrška za više platformi koja prevazilazi uobičajeni trio desktop sistema i uključuje Aurora OS i SymphonyOS, proširujući mrežu radnika na platforme koje većina alata ignoriše.

## Najveći tehnički izazovi i kako smo ih rešili

- **Da se ne izgubi rad na distribuiranim, prekidivim zadacima.** Kada je posao podeljen na više mašina, svaki pad sistema ili prekid obično ostavlja u vazduhu sve što je bilo u toku. Mi smo zadatak modelovali kao nosioca tačaka provera i zavisnosti, sačuvanih u PostgreSQL, tako da sistem može da se vrati na poslednje ispravno stanje ili nastavi odatle — izdržljivost koja postoji u sloju podataka, a ne u krhkom stanju u memoriji.
- **Upravljanje heterogenom mrežom radnika.** Mreža mašina sa Linuxom, macOS-om, Windowsom, Aurorom i SymphonyOS-om stalno se menja u pogledu dostupnosti i podešavanja. Mi to rešavamo posvećenom uslugom za upravljanje bazenom radnika koja obavlja registraciju zasnovanu na SSH, automatsku instalaciju na nove čvorove i neprestano praćenje zdravlja, tako da mreža ostaje poznata i kontrolisana kako mašine dolaze i odlaze.
- **Različitost pružalaca usluga i hardvera.** LLM backendovi i mašine na kojima se pokreću veoma se razlikuju po mogućnostima. Mi smo to sakrili iza jedinstvenog interfejsa za pružaoce LLM i uparili ga sa detekcijom hardvera (CPU/GPU/memorija) koja pokreće inteligentan izbor modela, tako da pravi model stigne na pravu mašinu bez potrebe da korisnik razmišlja o bilo čemu od toga.


## Tehnološki stek

- **Go (1.26+ unutrašnji modul)** — izabran jer njegova konkurentnost zasnovana na gorutinama i izlaz u vidu jednog binarnog fajla upravo odgovaraju potrebama distribuiranog radničkog sistema: jeftin paralelizam za orkestraciju i samostalni binarni fajl koji se automatski instalira na bilo koji čvor. Sadrži sve osnovne servise i binarne fajlove CLI/servera.
- **Gin (HTTP okvir)** — izabran zbog brzog, minimalističkog sloja REST sa niskim režijskim troškovima; služi `/api/v1` površinu (autentifikacija, radnici, zadaci, projekti) sa kojom komunicira svaki klijent.
- **PostgreSQL 15+ (putem pgx/v5)** — izabran kao trajan sistem evidencije jer čuvanje stanja i povratak na prethodnu verziju zahtevaju transakcionu perzistenciju; sadrži šemu distribuiranog računarstva sa 11 tabela (korisnici, radnici, zadaci, projekti, sesije, dobavljači LLM-a, obaveštenja) koja omogućava očuvanje rada.
- **Redis 7+ (opciono, go-redis/v9)** — izabran kao opcioni sloj keširanja i koordinacije koji ubrzava „vruće" puteve bez pretvaranja u obaveznu zavisnost, tako da minimalna implementacija i dalje funkcioniše samo sa Postgresom.
- **SSH** — izabran kao transport za kontrolu radnika upravo zato što je već svuda prisutan i već obezbeđen; pokreće registraciju radnika, automatsku instalaciju i izvršavanje udaljenih komandi širom celog klastera bez potrebe za prethodnim postavljanjem posebnog agenta.
- **Model Context Protocol (MCP)** — izabran za standardizovanu razmenu alata i konteksta kako bi se spoljašnji alati i agenti integrisali preko jednog otvorenog protokola; implementiran sa podrškom za više transportnih mehanizama kako bi se prilagodio klijentima gde god se povežu.
- **Dobavljači LLM (llama.cpp, Ollama, OpenAI)** — izabrani da obuhvate i lokalno i hostovano izvođenje zaključivanja iza jedinstvenog interfejsa, tako da se izbor hardvera može usmeriti na lokalni model ili hostovani, a pozivalac ne mora da zna razliku.

## Status i napomene o iskrenosti

- **Status: beta.** U README fajlu stoji da je projekat „POTPUNO ZAVRŠEN / svih 5 faza"; ta potpunost je navedena od strane projekta, a ne nezavisno potvrđena, pa se stranica prema tome odnosi kao prema beti.
- Sve navedene pojedinosti potiču iz README fajla u repozitorijumu; marketinške fraze (slogani) su uredničke prirode, a ne metrički podaci iz izvora.

**Prioritetni nivo:** Helix-osnovni.

