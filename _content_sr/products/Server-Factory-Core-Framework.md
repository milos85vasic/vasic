---
name: Server Factory Core Framework
slug: server-factory-core-framework
tier: serverfactory-tertiary
order: 30
status: stable (foundational framework; internal API specifics UNVERIFIED)
license: UNVERIFIED
private: false
tech:
  - Kotlin (~990K bytes)
  - Shell (minimal supporting scripts)
  - Gradle
repos:
  - https://github.com/Server-Factory/Core-Framework
diagrams:
  - Hub-and-spoke (Core Framework at center, factories as spokes)
  - Layered stack (Core Framework → factory product → target system)
  - Shared-engine benefit (one fix in Core → propagates to all factories)
---

**Zajednički pogon iza svakog Server Factory.**

## Sažetak

Core Framework je Kotlin okvir koji čini temelj porodice alata za provizioniranje Server Factory. Pruža zajednički pogon i apstrakcije na kojima grade projekti poput Mail Server Factory, tako da svaka „fabrika" koristi jednu isprobanu osnovu umesto da ponovo implementira primitivne funkcije provizioniranja.

## Kratak opis

Zajednički Kotlin okvir u osnovi ekosistema Server Factory. On obezbeđuje zajednički provizioni pogon, apstrakcije konekcija i mehanizam koraka instalacije koje koriste fabrike nizvodno (Mail Server Factory, Web Service Factory, SonarQube Factory i druge).

## Detaljan opis

Core Framework je tiha inženjerska komponenta koja omogućava čitavu porodicu Server-Factory: ponovljivi pogon na kojem se gradi svaki pojedinačni proizvod „fabrike" (Mail Server Factory, Web Service Factory, SonarQube Factory, Caching Proxy Factory). Pristup Server Factory je deklarativan — korisnik opisuje infrastrukturu koju želi putem konfiguracije, a fabrika tumači taj opis kako bi instalirala i inicijalizovala softver na ciljnom sistemu — a Core Framework je mesto gde se nalazi zajednička mašinerija tog obrasca: apstrakcije konekcija i transporta koje dosežu svaku vrstu cilja, model koraka instalacije koji kodira *način* na koji se softver provizionira, kao i zajednička infrastruktura koju bi inače svaka fabrika morala da piše za sebe. On je odgovor na strukturalno pitanje sa kojim se pre ili kasnije suočava svaki višenamenski lanac alata — gde smeštati zajednički pogon? — a pravilno rešenje tog pitanja jednom za svagda održava porodicu koherentnom umesto da se raspadne na četiri blago različita provizionera. Centralizacijom u jedan Kotlin okvir, porodica izbegava dupliranje logike provizioniranja u proizvodima i održava konzistentno ponašanje: svako poboljšanje tipa konekcije ili primitiva instalacije u Core Framework-u koristi svim fabrikama nizvodno. Gotovo u potpunosti je Kotlin (oko 990K bajtova Kotlin koda sa tankim slojem Shell), što odražava njegovu ulogu biblioteke koda, a ne zbirke skripti. Repozitorijumi nizvodno ga navode kao svoju kanoničku zavisnost (Parallels-Utils, Qemu-Utils, Utils i Definitions paketi svi referenciraju Core Framework repozitorijum kao čvorište ekosistema). Njegov README je namerno minimalan — on je infrastruktura za druge projekte, verzionisan putem `version.txt`/`version_code.txt` — i prethodi kasnijem radu na AI, što ga čini delom zrelog DevOps alata nasleđa organizacije.

## Zašto smo ga izgradili

Svaki alat za provizioniranje zahteva isto jezgro: načine za povezivanje sa ciljevima i korake za instalaciju/konfiguraciju softvera. Ponovno izgradnja tog jezgra za svaki proizvod dovela bi do fragmentacije ponašanja i umnožavanja grešaka. Core Framework ga centralizuje tako da sve fabrike dele jedan pouzdan pogon.

## Zašto je revolucionaran

To je tačka najvećeg uticaja u čitavoj porodici: svako otvrdnjavanje tipa konekcije ili poboljšanje primitiva instalacije ovde odmah se prenosi na sve fabrike, tako da čitav lanac alata napreduje zahvaljujući jednoj investiciji. To je filozofija „izgradi jednom, koristi svuda" primenjena tamo gde najviše isplati — na sloju osnove infrastrukturne automatizacije, gde popravka na pravom mestu popravlja sve nizvodno.


## Šta je inovativno

- Jedinstveni višekratno upotrebljiv okvir za obezbeđivanje koji apstrahuje logiku povezivanja i koraka instalacije.
- Čista podela između motora (Osnovni okvir) i fabrika specifičnih za proizvod.
- Distribucija sa fiksiranom verzijom (`version.txt`/`version_code.txt`) za reproduktivnu potrošnju.

## Izazovi i rešenja

- **Izbegavanje dupliranja logike obezbeđivanja:** rešeno izdvajanjem zajedničke mašinerije u jedan okvir koji koriste sve fabrike.
- **Konzistentno ponašanje u svim proizvodima:** rešeno zajedničkim apstrakcijama tako da se tipovi veza i koraci ponašaju identično svuda.
- **(NEVERIFIKOVANO):** određeni interni API-ji nisu dokumentovani u javnom README fajlu; detalje interfejsa tretirati kao neverifikovane izvan „zajedničkog okvira koji koriste fabrike".

## Tehnološki stek (zašto + kako)

- **Kotlin** — ceo okvir (~990K bajtova); jezik iz porodice Server Factory.
- **Shell** — minimalni pomoćni skriptovi.
- **Gradle** — alat za izgradnju (u skladu sa upotrebom `./gradlew` u porodici).

> Napomena: GitHub označava repozitorijum kao fork unutar organizacije Server-Factory. Nije fokusiran na AI; predstavljen kao kičma alata za obezbeđivanje.

