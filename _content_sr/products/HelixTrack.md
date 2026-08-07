---
name: HelixTrack
slug: helixtrack
tier: helix-primary
order: 1
status: beta
license: TBD
private: false
tech:
  - Go
  - Gin
  - HTTP/3 QUIC
  - PostgreSQL
  - SQLite
  - SQLCipher
  - Redis
  - Angular 19
  - Tauri 2.0
  - Kotlin
  - Swift
  - Docker
repos:
  - https://github.com/Helix-Track/Core
  - https://github.com/Helix-Track/Website
diagrams:
  - HelixTrack architecture map — Core (Go/Gin) exposing the unified /do API over HTTP/3 QUIC to decoupled Auth, Permissions, and Localization services, with SQLCipher-encrypted PostgreSQL/SQLite and Redis, and native clients fanning out via UDP discovery.
  - Unified /do request/response envelope — single action-routed endpoint vs. a sprawling REST surface (action/jwt/object/data → errorCode/errorMessage/data).
  - JIRA + Confluence, unified — issue tracking / agile boards alongside the Documents V2 spaces/pages workspace, framed as one open platform.
  - Multi-space isolation — --space-root producing per-project isolated databases and asset stores.
---

# HelixTrack

**JIRA alternativa za slobodan svet.**

## Sažetak

HelixTrack je sveobuhvatna, moderna, open-source alternativa JIRA (a preko proširenja Documents i Confluence-u) — višeplatformski sistem za upravljanje projektima i praćenje problema, izgrađen na Go mikroservisnoj pozadini s izvornim klijentima za veb, desktop i mobilne uređaje.

## Kratak opis

Open-source alternativa JIRA/Confluence-u. Go mikroservisna pozadina („HelixTrack Core") izlaže jedinstveni REST API za praćenje projekata i problema, uz Confluence-stilski radni prostor za dokumente, koji se servira izvorno na veb, desktop, Android i iOS klijentima preko HTTP/3 QUIC protokola.

## Detaljan opis

HelixTrack je open-source platforma za upravljanje projektima i praćenje problema, postavljena kao alternativa iz slobodnog sveta JIRA i Confluence-u — potpuna zamena za dva proizvoda kojima su inženjerske organizacije najčešće vezane, ponovo izgrađena kao softver koji posedujete i možete pokretati bilo gde. U njenom srcu je **HelixTrack Core**, REST API mikroservis napisan u Go-u s okvirom Gin, koji nudi potpuno praćenje problema, agilne/scrum table, upravljanje timovima i hijerarhijski sistem dozvola čija se implementacija može zameniti između lokalnog procesa i HTTP servisa — tako da isti model autorizacije skalira od jednog laptopa do distribuiranog klastera bez menjanja aplikativnog koda. Umesto da širi REST površinu preko desetina ruta, Core sve usmerava kroz jednu, akcijom usmerenu `/do` krajnju tačku s jedinstvenim omotačem zahteva i odgovora (`action`/`jwt`/`object`/`data` na ulazu, `errorCode`/`errorMessage`/`data` na izlazu): svaki klijent govori isti mali ugovor, a dodavanje nove funkcionalnosti znači dodavanje akcije, a ne novog URL-a koji treba dokumentovati, osigurati i verzionisati. Core se integriše s odvojenim servisima za autentifikaciju, dozvole i lokalizaciju koji komuniciraju preko HTTP/3 QUIC protokola i mogu raditi na odvojenim mašinama ili klasterima, ili se potpuno isključiti u testnim konfiguracijama. Podaci se čuvaju u SQLite-u za razvoj bez podešavanja i u PostgreSQL-u u produkciji, a šifruju se u mirovanju pomoću SQLCipher (AES-256), tako da su osetljivi podaci o projektima podrazumevano zaštićeni na disku, a ne naknadno. **Documents V2** proširenje pretvara tragač u potpunu platformu znanja: Confluence-stilski radni prostor sa prostorima, stranicama, kontrolom verzija, šablonima, saradnjom u realnom vremenu (WebSocket) i analitikom — wiki i tragač za problemima konačno žive iza jednog backend-a umesto kao dva proizvoda spojena na silu. Oko Core-a se nalaze različite klijentske aplikacije: Angular veb klijent, Tauri + Angular desktop klijent, izvorne Android (Kotlin) i iOS (Swift) aplikacije, kao i klijenti za HarmonyOS i Aurora OS, uz screensaver — sve komunicira s istom pozadinom i automatski je pronalazi na lokalnoj mreži putem UDP emitovanja, tako da novi klijent pronalazi server bez ručnog podešavanja. Klijentske aplikacije se održavaju kao odvojena, privatna repozitorijuma i ovde su predstavljene samo na nivou proizvoda.


## Zašto smo ga napravili

Da bismo timovima ponudili zaista otvorenu, samostalno hostovanu zamenu za JIRA + Confluence stek — „za slobodan svet" — bez zavisnosti od dobavljača, kombinujući praćenje poslova, dokumente i saradnju na nivou preduzeća pod jednom otvorenom licencom.

## Zašto je ovo revolucionarno

Spaja dva komercijalna teškaška — praćenje problema i stek za vikije/dokumente — u jednu otvorenu, visokoperformantnu, samostalno hostovanu platformu, i uparuje ih sa nečim što konkurencija nikada nije ponudila: istinski multiplatformske *native* klijente (veb, desktop, Android, iOS, plus HarmonyOS i Aurora OS), sve pokretane jednim ugovorom na backendu. Ključna prednost je vlasništvo bez kompromisa. Dizajn zasnovan na HTTP/3 svuda, potpuno razdvojenim mikroservisima i enkripciji SQLCipher AES-256 pri mirovanju donosi performanse i sigurnosni nivo koji su inače rezervisani za vlasničke SaaS sisteme — u sistem koji sami hostujete, bez licenci po korisniku, bez zavisnosti od dobavljača i bez podataka koji napuštaju vašu infrastrukturu. Timovi dobijaju iskustvo JIRA-plus-Confluence koje već poznaju, na sopstvenom hardveru, pod jednom otvorenom licencom.

## Šta je inovativno

- Ujedinjeni akcioni `/do` API — jedna krajnja tačka, jedan omotač, usmeravanje akcija. Nove mogućnosti stižu kao nove akcije, a ne kao nove URL adrese, što smanjuje napadnu površinu, klijentski kod i teret dokumentacije na jedan ugovor koji dele sve platforme.
- HTTP/3 QUIC kao *podrazumevani* interservisni transport — moderna mrežna komunikacija sa niskom latencijom i otporna na prekide veze između servisa od prvog dana, a ne naknadno dodata.
- Mehanizam za dozvole koji se može zameniti između lokalne implementacije u procesu i servisa pokretanog preko HTTP-a, uz opcione, nezavisno implementirane servise za autentifikaciju, dozvole i lokalizaciju — isti model autorizacije bez obzira da li pokrećete jedan proces ili klaster.
- Izolacija podataka u više prostora pomoću `--space-root` zastavice: svaki projekat dobija svoju izolovanu bazu podataka i skladište resursa, tako da su stanari i projekti razdvojeni na nivou skladišta, a ne pomoću filtera u upitima.
- Enkripcija SQLCipher AES-256 pri mirovanju — osetljivi podaci projekta su podrazumevano zaštićeni na disku, transparentno.
- Automatsko otkrivanje klijenta i servera putem UDP emitovanja na lokalnim mrežama — klijent pronalazi Core bez ikakve ručne konfiguracije.
- Dokumenti V2, prava „alternativa Confluence-u", sa optimističkim zaključavanjem paralelne obrade, detekcijom konflikata i kompletnom istorijom izmena — pravi kolaborativni dokumenti koji žive iza istog backenda kao i tragač.

## Najveći tehnički izazovi i kako smo ih rešili

- **Šest klijentskih platformi, jedan backend, nula odstupanja u ugovoru.** Održavanje klijenata za Web/Angular, Desktop/Tauri, Android/Kotlin, iOS/Swift, HarmonyOS i Aurora obično znači šest različitih integracija API koje vremenom gube sinhronizaciju. Taj rizik smo eliminisali tako što smo učinili jedini ugovor akciono usmereni `/do` API sa fiksnim omotačem — svaki klijent ga cilja na identičan način — i dodali UDP emitovanje za otkrivanje servisa kako bi klijenti pronalazili Core na mreži bez ručno podešenih krajnjih tačaka.
- **Razdvajanje servisa bez plaćanja cene latencije.** Podela autentifikacije, dozvola i lokalizacije na nezavisno implementirane servise obično dodaje mrežni skok po pozivu. Usvojili smo HTTP/3 QUIC za sve interservisne pozive kako bismo zadržali te skokove brzim i otpornim na prekide veze, a svaki servis učinili nezavisno pokretljivim — čak i potpuno isključenim u testnim konfiguracijama — tako da razdvajanje postane izbor pri implementaciji, a ne fiksni trošak.
- **Kolaboracija na nivou Confluence-a bez gubitka izmena.** Uređivanje u realnom vremenu sa više autora podstiče konflikte. Dokumenti V2 to rešavaju pomoću prostora/stranica/verzionisanja pod optimističkim zaključavanjem, uz eksplicitnu detekciju konflikata, kompletnu istoriju izmena kao rezervnu opciju i sinhronizaciju u realnom vremenu WebSocket — kolaboracija koja ostaje konzistentna umesto da tiho pregazi izmene.
- **Enkripcija pri mirovanju bez žrtvovanja propusnosti.** SQLCipher AES-256 štiti podatke na disku, ali dodaje troškove po upitu; to smo kompenzovali višeslojnim keširanjem (LRU u memoriji ispred Redis u servisu za lokalizaciju) tako da vrući putevi poput višjezičnih pretraga ostaju brzi, a podaci i dalje enkriptovani.


## Tehnološki stack

- **Go + Gin** — izabrani za HTTP usluge visokog protoka i niske latencije sa scenarijem implementacije u obliku jednog binarnog fajla; sadrže Core-ov REST API, njegov JWT/CORS middleware i ruter sa akcijama na `/do` koji stoji ispred celog sistema.
- **HTTP/3 QUIC** — izabran kao transportni sloj između Core-a i njegovih usluga za autentifikaciju, dozvole i lokalizaciju, jer QUIC-ov dizajn sa multipleksiranim vezama i migracijom konekcija smanjuje kašnjenje u repnom delu i preživljava nestabilne veze gde TCP zastaje.
- **PostgreSQL (prod) / SQLite (dev)** — jedan relacion model koji podržava veliku šemu za praćenje i dokumente na oba motora: SQLite omogućava lokalni razvoj bez podešavanja i zasnovan na fajlovima, dok Postgres preuzima ulogu u produkciji putem namenski definisanog `production` Compose profila.
- **SQLCipher (AES-256)** — izabran za transparentnu enkripciju na nivou baze podataka u mirovanju, tako da zaštita osetljivih projekatskih podataka ne zahteva kriptografiju na nivou aplikacije niti izmene u načinu pisanja upita.
- **Redis** — izabran kao zajednički keš sloj iza keša u memoriji sa LRU algoritmom u okviru Lokalizacione usluge, što obezbeđuje dvoslojni keš koji održava brzinu pregleda u više jezika čak i uz dodatni teret enkripcije.
- **Uber Zap + Lumberjack** — izabrani za strukturirano, efikasno logovanje sa ugrađenom rotacijom, kako bi Core ostao uočljiv u produkciji bez neograničenog rasta log fajlova.
- **golang-jwt / JWT** — izabrani kao mehanizam za bezstanjnu autentifikaciju; potpisani token putuje u `jwt` polju svakog `/do` omotača, čime je autentifikacija ujednačena za sve klijente.
- **Angular 19 (+ Material, RxJS)** — izabran za reaktivni, komponentno vođeni veb klijent sa zrelim Material dizajnerskim sistemom odmah na raspolaganju.
- **Tauri 2.0 + Rust + Angular** — izabrani za isporuku nativnog desktop omotača sa minimalnim zauzećem prostora, ponovnim korišćenjem Angular UI-a unutar Rust webview-a umesto uključivanja kompletnog browser runtime-a.
- **Kotlin (Android) / Swift + SwiftUI (iOS)** — izabrani kako bi mobilni korisnici dobili zaista nativne, platformski prilagođene klijente umesto omotanog veb prikaza.
- **Docker / Docker Compose (kompatibilno sa Podman)** — izabrani za reproduktivno, kontejnerizovano implementiranje sa ugrađenim `/health` proverama, kao i kompatibilnost sa Podman, čime se ne nameće potreba za daemonima ili specifičnim dobavljačima.
- **Testify (Go); Cypress/Playwright/Karma+Jasmine (klijenti)** — izabrani za višeslojno automatizovano testiranje koje pokriva ugovor sa backend-om i klijentske UI-ove nezavisno, u skladu sa arhitekturom jednog backend-a i više klijenata.

## Status i napomene o iskrenosti

- **Status: beta.** HelixTrack Core je funkcionalni REST API mikroservis; **Documents V2** ekstenzija je dokumentovana kao otprilike 95% kompletirana sa poznatim problemom mapiranja polja u bazi podataka, te se ne predstavlja kao potpuno isporučena.
- **Licenca: nije definitivno određena.** `CLAUDE.md` navodi MIT, ali `core/LICENSE` fajl zvaničnog zapisa je Apache 2.0 — ova nesaglasnost mora biti razrešena pre nego što se licenca konačno odredi.
- Performansni podaci navedeni u README fajlu projekta (npr. 50.000+ zahteva u sekundi, vreme upita ispod milisekunde) predstavljaju projektovane/marketinške ciljeve, a ne nezavisno objavljene benchmark rezultate, te su stoga izostavljeni iz navedenih tvrdnji.
- Klijentske aplikacije (Web, Desktop, Android, iOS, Aurora, HarmonyOS) nalaze se u **privatnim** repozitorijumima i opisuju se isključivo na nivou proizvoda.

**Prioritetni nivo:** Helix-primary i vodeći proizvod linije Helix-Track — rangiran ispred svih projekata Server Factory.

