---
name: Docs Chain
slug: docs-chain
tier: vasic-util-secondary
order: 25
status: active (Phases 1–5 implemented & GREEN; Phases 6–7 PLANNED / operator-gated)
license: UNVERIFIED
private: false
tech:
  - Go
  - DAG + Kahn topological sort
  - SQLite (pure-Go modernc)
  - fsnotify
  - YAML config
  - exec transforms (Markdown → HTML/PDF/DOCX)
repos:
  - https://github.com/vasic-digital/docs_chain
diagrams:
  - DAG of chain members (Markdown ↔ HTML/PDF/DOCX ↔ SQLite) with a change propagating
  - Content-hash vs mtime comparison
  - Atomic-commit sequence (temp write → rename / SQLite txn)
  - Phase status board (implemented vs planned)
---

**Nijedan praćeni dokument ne može izaći iz sinhronizacije — sadržajno heširan, dvosmeran, atomičan.**

## Sažetak

Docs Chain je univerzalni, Go-implementiran dvosmerni motor za propagaciju zavisnosti između dokumenata i baza podataka. Kada se bilo koji član registrovanog lanca promeni — Markdown izvor, HTML/PDF/DOCX izvoz ili SQLite baza podataka — on to otkriva putem heša sadržaja i propagira promenu kroz sve povezane članove atomično.

## Kratak opis

Go motor koji održava dokumente i baze podataka u sinhronizaciji. Koristeći Salsa-stil inkrementalnog prekomputiranja zasnovanog na hešu sadržaja preko DAG-a (Kanov topološki redosled, rano odsecanje, dvosmerne sinhronizacione grane, atomično preimenovanje + SQLite transakcioni komitovi), on regeneriše izvoze kad god se bilo koji povezan artefakt promeni.

## Detaljan opis

Docs Chain je ono što napravite kada ste već jednom previše puta napisali isti krhki shell skript „regeneriši PDF kada se Markdown promeni". On zamenjuje čitav taj žanr ručno pisane sinhronizacione lepila pravim motorom. Modelira dokumente i baze podataka projekta kao članove lanca i, kada se bilo koji član promeni, propagira tu promenu kroz sve povezane članove u svim deklarisanim smerovima — regenerišući i izvozeći atomično tako da nijedan praćeni artefakt nikada ne može izaći iz sinhronizacije. Dizajn pozajmljuje svoju strogost direktno iz sveta inkrementalnih build sistema, a ne iz skriptovanja: otkrivanje promena zasniva se na **hešu sadržaja, a ne na vremenu modifikacije**, pa `touch` ne pokreće ništa, a jednobajtna izmena pokreće tačno one ponovne izgradnje koje treba — bez lažnih alarma, bez propuštenih promena. Formalno izraženo u jednoj rečenici, to je Salsa-stil inkrementalnog prekomputiranja zasnovanog na hešu sadržaja preko DAG-a, sa Kanovim topološkim redosledom, ranim odsecanjem koje eliminiše nepromenjene podstabla, deklarisanim dvosmernim `sync` granama sa autoritetom, i atomičnim preimenovanjem plus SQLite transakcionim komitovima, tako da pad sistema usred propagacije nikada ne može ostaviti delimično napisan izvoz. Distribuira se kao `vasic-digital` podmodul i koristi kao osnovni deo HelixConstitution podmodula, pa svaki projekat koji usvoji ustav dobija Docs Chain odmah i registruje sopstvene lance preko YAML po kontekstu. Implementacija je iskrena u pogledu statusa (prema ustavu §11.4.6): Faze 1–4 (osnovni DAG + heširanje, adapteri/transformacije čvorova, koordinator propagacije sa atomičnošću, konfiguraciono vođeni multi-kontekstni CLI sa `sync`/`verify`/`doctor`/`graph`/`watch`) su implementirane i testirane; Faza 4b dodaje generičke dvosmerne ugrađene funkcije `md-to-sqlite`/`sqlite-to-md` (čisti Go, promena na nivou reda, bajt-stabilan kružni tok) i ugrađenu funkciju `colorize-html`; Faza 5 obuhvata sveobuhvatne real-binary end-to-end testove i označena je kao GREEN. Faze 6–7 (distribucija ustava, ATMOSphere povezivanje) ostaju PLANIRANE i dostupne samo operaterima. Herald je prvi pravi downstream potrošač, sinhronizujući korpus od 66 dokumenata u više formata koji verifikuje čistoću.

## Zašto smo ga napravili

Dokumentacija, izvozi i baze podataka se razilaze čim se održavaju ručno ili pomoću krhkih skripti. Docs Chain sinhronizaciju čini mehaničkom, preciznom na osnovu heša sadržaja i atomičnom, tako da promena bilo gde u lancu ispravno i bezbedno ažurira sve nizvodno (i uzvodno).


## Zašto je ovo revolucionarno

Ono što donosi su rigorozne garancije ispravnosti, koje autori kompajlera i build-sistema smatraju samorazumljivim – grafovi zavisnosti zasnovani na heširanju sadržaja, minimalno ponavljanje izračunavanja, atomične promene – ali ih usmerava na dokumentaciju i baze podataka, domen koji je do sada preživljavao zahvaljujući cron poslovima i dobrim namerama. Prava dvosmerna sinhronizacija znači da se odnos između izvornog materijala i njegovog izvoza održava u oba smera, tako da „dokumentacija nije ažurna" i „izvoz se ne poklapa sa izvorom" prestaju da budu ponavljajući bagovi i postaju stanja koja sistem jednostavno neće dozvoliti.

## Šta je inovativno

- Inkrementalno ponovno izračunavanje zasnovano na hešu sadržaja (a ne na vremenu izmene) nad usmerenim acikličnim grafom (DAG) sa ranim prekidom.
- Dvosmerna sinhronizacija sa eksplicitno definisanim autoritetom (dokumentacija ↔ izvoz ↔ SQLite).
- Atomična promena imena + SQLite transakcioni komit za bezbedno širenje promena čak i u slučaju pada sistema.
- Čist Go `md-to-sqlite`/`sqlite-to-md` kružni proces sa detekcijom odstupanja na nivou redova.

## Izazovi i rešenja

- **Lažna ponovna izgradnja:** rešeno detekcijom heša sadržaja umesto vremenskih oznaka.
- **Delimične/korumpirane izmene:** rešeno atomičnom promenom imena i SQLite transakcijama.
- **Ispravno redosled izvršavanja sa više članova:** rešeno Kahnovim topološkim sortiranjem sa ranim prekidom.
- **Pošteno izveštavanje o mogućnostima:** rešeno označavanjem svake faze kao IMPLEMENTIRANO ili PLANIRANO prema §11.4.6.

## Tehnološki stek (zašto + kako)

- **Go** — ceo pogon (`internal/hash`, `graph`, `adapter`, `orchestrator`, `config`, `state`, `runner`, `cmd/docs_chain`).
- **DAG + Kahnovo topološko sortiranje** — redosled zavisnosti sa ranim prekidom.
- **SQLite (čist Go modernc)** — članovi baze podataka i transakcioni komiti.
- **fsnotify** — `watch` daemon za prenošenje promena u realnom vremenu.
- **YAML config** — registracija lanaca po kontekstu.
- **exec: transformacije** — priključivi generatori Markdown→HTML/PDF/DOCX.

> Poštenje u planu razvoja: Faze 6–7 (distribucija ustava, povezivanje sa ATMOSferom) su PLANIRANE / dostupne samo operaterima – nisu još isporučene.

