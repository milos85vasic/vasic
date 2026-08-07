---
name: Server Factory — Additional Components
slug: server-factory-additional-components
tier: serverfactory-tertiary
order: 33
status: mixed / early-stage (service factories are placeholder-documented — UNVERIFIED; Definitions & Utils are supporting data/tooling)
license: UNVERIFIED
private: false
tech:
  - Kotlin (service factories, on Core Framework)
  - Shell (Utils, Definitions packs)
  - Gradle
  - Docker (target runtime)
  - SSH / OpenSSH (Utils bootstrap)
  - SonarQube
repos:
  - https://github.com/Server-Factory/Web-Service-Factory
  - https://github.com/Server-Factory/SonarQube-Factory
  - https://github.com/Server-Factory/Caching-Proxy-Factory
  - https://github.com/Server-Factory/Docker-Definitions
  - https://github.com/Server-Factory/Stack-Definitions
  - https://github.com/Server-Factory/Software-Definitions
  - https://github.com/Server-Factory/Utils
diagrams:
  - Family tree (Core Framework → {Mail, Web, SonarQube, Caching-Proxy} factories)
  - Data-vs-engine split (Definitions packs feeding the factory execution engine)
  - Utils spotlight (init_ssh_access.sh bootstrap flow)
  - Maturity legend distinguishing flagship (Mail) from early-stage service factories
---

**Sporedni elementi alata Server Factory za provizioniranje.**

## Sažetak

Pored Mail Server Factory i Osnovnog okvira, organizacija Server-Factory obuhvata nekoliko manjih komponenti: „fabrike" po usluzi (Web Service, SonarQube, Keširajući proxy), deklarativne konfiguracione pakete (Docker/Stack/Definicije softvera) i zajedničke pomoćne alate (Utils). Ova konsolidovana stranica prikazuje ih iskreno – neke su u ranoj fazi ili tek delimično dokumentovane – umesto da ih predstavlja kao potpuno definisane proizvode.

## Kratak opis

Grupa repozitorijuma koji podržavaju Server Factory: Web-Service-Factory, SonarQube-Factory i Caching-Proxy-Factory (alati za provizioniranje po usluzi, uglavnom u ranoj fazi); Docker/Stack/Software-Definitions (deklarativni konfiguracioni paketi koje koristi okvir); i Utils (pomoćni alati za pristup SSH i opštu alatku). Sve se oslanjaju na Osnovni okvir.

## Detaljan opis

Ova stranica objedinjuje preostale repozitorijume Server-Factoryja jer su, pojedinačno, većina njih mali ili namerno nedovoljno dokumentovani, pa bi ih predstavljanje kao gotovih proizvoda precenilo njihovu zrelost. Mogu se podeliti u tri grupe. **Fabrike usluga** slede obrazac Mail Server Factory za druge uloge servera: **Caching-Proxy-Factory** („Pokrenite sopstveni keširajući proxy server") navodi keširajući proxy, sertifikat sa samopotpisom i HTTP krajnju tačku za dobijanje sigurnosnog sertifikata kao ključne funkcije; **SonarQube-Factory** („Pokrenite sopstveni SonarQube server") namenjen je razvoju softvera; a **Web-Service-Factory** instancira i konfigurira veb-server za implementaciju ciljeva kao što su veb-sajtovi i mikrousluge. Sve tri su Kotlin projekti izgrađeni na Osnovnom okviru, ali njihovi javni README fajlovi uglavnom služe kao privremeni sadržaj („Tbd." za kompatibilnost, specifikacije, podešavanje i upotrebu) – pa su njihove konkretne mogućnosti izvan navedene namene NEVERIFIKOVANE. **Definicioni paketi** – **Docker-Definitions**, **Stack-Definitions** i **Software-Definitions** – jesu deklarativni konfiguracioni repozitorijumi koje okvir koristi da bi znao kako da gradi/implementira slike Docker, stekove i softver; to su verzijski vezani paketi podataka, a ne aplikacije. **Utils** pruža opšte pomoćne alate za porodicu, uključujući skript `init_ssh_access.sh` koji generiše ključ SSH i instalira ga na udaljeni host kako bi omogućio root pristup bez lozinke za naknadno provizioniranje. Zajedno, ove komponente zaokružuju lanac alata za provizioniranje oko vodećeg Mail Server Factory.

## Zašto smo ga napravili

Model Server Factory stvoren je da bude univerzalno primenljiv: kada jednom možete da provizionirate mejl-server iz deklarativnog opisa, isti mehanizam bi trebalo da može da provizionira i veb-server, keširajuće proxyje i servere za kontrolu kvaliteta koda – napajane ponovljivo upotrebljivim definicionim paketima i zajedničkim pomoćnim alatima, umesto prilagođene logike za svaku ulogu. Ovi repozitorijumi predstavljaju upravo tu generalizaciju u razvoju, proširujući dokazani obrazac na nove tipove servera. Njihova vrednost ovde je kao dokaz dosega modela; njihova zrelost varira, a ova stranica namerno razjašnjava šta je tek u planu, a šta je već ostvareno.


## Zašto je ovo revolucionarno (umereno)

Kao skup, ovi alati demonstriraju ponovnu upotrebljivost Osnovnog okvira na različitim tipovima servera i razdvajaju deklarativne podatke (Definicije) od izvršavanja (fabrike). Pojedinačno, fabrike usluga su u ranoj fazi i treba ih predstaviti kao smernice, a ne kao gotove proizvode.

## Šta je inovativno

- Jedan okvir za obezbeđivanje generalizovan za uloge mejla, veba, keširajućeg proksija i SonarQube.
- Deklarativni paketi Definicija (Docker/Stack/Software) odvojeni od izvršnog motora.
- Deljene alatke (npr. jednokomandno podizanje sistema bez lozinke putem SSH) ponovo korišćene u fabrikama.

## Izazovi i rešenja

- **Korišćenje jednog motora za različite uloge servera:** rešeno izgradnjom svake fabrike na Osnovnom okviru.
- **Razdvajanje konfiguracije od koda:** rešeno repozitorijumima Definicija kao verzijski označenim paketima podataka.
- **(NEVERIFIKOVANO):** README fajlovi fabrika usluga su privremeni; njihova potpunost implementacije nije proverljiva iz javne dokumentacije — predstaviti kao rano-stadijumske.

## Tehnološki stek (zašto + kako)

- **Kotlin** — Fabrika veb-usluga, Fabrika SonarQube, Fabrika keširajućeg proksija (izgrađene na Osnovnom okviru).
- **Shell** — Alatke i paketi Definicija (skripte/konfiguracije).
- **Gradle** — tok izgradnje/testiranja `./gradlew test` u fabrikama.
- **Docker** — ciljno izvršno okruženje opisano Definicijama Docker.
- **SSH / OpenSSH** — podizanje sistema bez lozinke putem alatki.
- **SonarQube** — server koji obezbeđuje Fabrika SonarQube (i protiv kojeg Mail Server Factory izveštava o čistoj proveri).

> Napomena o iskrenosti: većina ovih repozitorijuma su forkovi unutar organizacije; fabrike usluga su dokumentovane kao privremene i označene kao NEVERIFIKOVANE prema ustavu §11.4.6. Jasno rangirane ispod Mail Server Factory i Osnovnog okvira.

