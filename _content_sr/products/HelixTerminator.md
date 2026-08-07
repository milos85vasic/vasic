---
name: HelixTerminator
slug: helixterminator
tier: helix-primary
order: 8
status: beta
license: Apache-2.0
private: false
tech:
  - Go microservices
  - Flutter / Dart (BLoC)
  - PostgreSQL
  - Kafka
  - RabbitMQ
  - Redis
  - SPIFFE/SPIRE + mTLS
  - Ed25519
  - Kubernetes + Helm + Terraform
  - OpenTelemetry
  - Grafana
  - Jaeger
  - Loki
repos:
  - https://github.com/HelixDevelopment/terminator
diagrams:
  - Three-channel architecture — Flutter clients ↔ gateway ↔ Go service mesh ↔ host agent / SSH proxy.
  - Zero-trust security flow — PKI issuing a short-lived SSH cert, vault-stored secret, mTLS between services.
  - Live collaboration panel — observer / co-pilot / owner sharing one terminal with CRDT sync.
  - AI-assist callout — terminal output with an inline "explain this output / draft runbook" overlay.
---

# HelixTerminator

**Platforma terminala sa nultim poverenjem za timove — svaka SSH sesija osigurana, deljena i podržana AI asistentom.**

## Sažetak

HelixTerminator je preduzetnička platforma za terminal i upravljanje SSH sesijama, izgrađena kao sistem Go mikroservisa sa Flutter klijentima za više platformi. Ona posreduje, snima i osigurava udaljene sesije po modelu nultog poverenja, omogućava saradnju u realnom vremenu i dodaje AI asistenciju direktno u terminal.

## Kratak opis

HelixTerminator je preduzetnička platforma za terminal i upravljanje SSH sesijama zasnovana na nultom poverenju: Go mikroservisni backend sa Flutter klijentima za šest platformi. Upravlja hostovima, posreduje veze, snima sesije, omogućava saradnju u realnom vremenu i dodaje AI asistenciju za pomoć pri komandama, objašnjavanje izlaza i reagovanje na incidente.

## Detaljan opis

HelixTerminator je preduzetnička platforma za terminal i udaljeni pristup, strukturirana u dva modula — Terminalsku platformu i Posrednika veza — implementirana kroz katalog Go mikroservisa sa jednim Flutter klijentom koji podržava šest platformi. Njen cilj je da potpuno zameni improvizovane SSH alate: više nema klijenata po laptopu, rasipanja privatnih ključeva i praznina u reviziji, već jednu kontrolisanu, revizijsku i kolaborativnu platformu koja udaljeni pristup tretira kao infrastrukturu, a ne kao ličnu naviku.

Backend upravlja celim životnim ciklusom udaljenog pristupa od početka do kraja. Hostovi i grupe se upravljaju lancima bastion/jump hostova; SSH proxy posreduje autentifikaciju putem lozinki, javnih ključeva i sertifikata; terminalski I/O proxy prenosi sesiju preko WebSocket; SFTP podržava nastavljive prenose; tu su i prosleđivanje portova, upravljanje isječcima i radnim prostorima, kao i snimanje sesija u obliku potpisanih asciinema zapisa koje možete reprodukovati i kojima možete verovati. Sigurnost je dizajnirana po principu nultog poverenja, a ne naknadno: trezor pruža skladištenje tajni bez znanja, PKI servis izdaje kratkoročne SSH sertifikate tako da nijedan stalni kredencijal ne ostaje na raspolaganju za krađu, hardverski podržani kešovi (Secure Enclave / Android Keystore / DPAPI / HSM) drže ključeve van diska, FIDO2/WebAuthn i OIDC/SAML vode autentifikaciju, a nepromenljivi, Merkle-lančani revizijski zapis generiše nepodmitljive dokaze za SOC 2 / ISO 27001. Pored toga, saradnja u realnom vremenu omogućava više operatera da dele jednu aktivnu sesiju u ulogama posmatrača, kopilota ili vlasnika, a konzistentnost se održava sinhronizacijom CRDT bafera.

AI servis nadograđuje sam terminal, dodajući automatsko dopunjavanje komandi, objašnjavanje izlaza na razumljivom jeziku, otkrivanje anomalija, generisanje runbookova i praktičnu pomoć pri incidentima — pretvarajući terminal iz običnog kanala u asistenta upravo u trenucima koji su najvažniji. Cela platforma je prilagođena kontejnerima — Kubernetes, Helm, Terraform, i kompletan opservabilni stek sa OpenTelemetry, Grafana, Jaegerom i Loki — i integriše se sa širom Helix porodice preko HelixTrack mosta i lokalnog HelixLLM. Sve to radi pod Helix Constitution sa proverom nasleđivanja i anti-bluf mehanizmima.


## Zašto smo ga izgradili

Timovi upravljaju udaljenom infrastrukturom preko razbacanih SSH klijenata bez zajedničkog revizijskog traga, bez doslednog rukovanja tajnama i bez mogućnosti da u realnom vremenu sarađuju na incidentu. HelixTerminator je stvoren da udaljeni pristup pretvori u upravljivu, zero-trust platformu prilagođenu timovima, umesto u alat koji se koristi po pojedinačnom laptopu.

## Zašto je revolucionaran

Sve svedi na jednu platformu. SSH klijent, trezor tajni, bastion/PKI sloj, snimanje sesija, revizija usklađenosti i saradnja uživo – sve su to stvari koje timovi obično kupuju, spajaju i usklađuju odvojeno, pri čemu svaka ima praznine na spojevima. HelixTerminator ih isporučuje kao jedinstven upravljivi sistem, a onda radi nešto što nijedan od tih alata ne može samostalno: postavlja AI sloj direktno preko terminala koji objašnjava nepoznat ispis i kreira uputstva *dok je incident u toku*. Funkcionalnost koja ranije nije bila praktična sada je udaljena sesija koja je istovremeno osigurana po principu zero-trust, nepromenljivo snimljena, deljena uživo među operaterima i podržana AI – sve odjednom, iz jednog prozora.

## Šta je inovativno

- **Dvostruki modularni dizajn** (Terminalska platforma + Broker veza) usklađeni preko servisnog registra, tako da platforma i sloj za posredovanje mogu nezavisno da skaliraju i evoluiraju.
- **Zero-trust sigurnost** od kraja do kraja: kratkoročni SSH sertifikati koje izdaje PKI, trezor sa nultim znanjem, hardverski podržani ključevi i Merkle-vezani revizijski zapis – bez trajnih akreditiva, bez neproverljivog traga.
- **Saradnja na sesiji u realnom vremenu** sa CRDT sinhronizacijom bafera i jasno definisanim ulogama posmatrača, kopilota i vlasnika, tako da više operatera može da radi na jednom terminalu bez međusobnog ometanja.
- **AI podrška operacijama** integrisana u aktivni terminal: automatsko dopunjavanje, objašnjenje izlaza, detekcija anomalija i pomoć pri izradi uputstava i upravljanju incidentima – tačno tamo gde je operateru potrebna.
- **Višeplatformski Flutter klijent** koji pokreće šest platformi iz jedne kodne baze, tako da korisničko iskustvo na desktopu, mobilnim uređajima i vebu ostaje usklađeno.

## Najveći tehnički izazovi i kako smo ih rešili

- **Osiguravanje udaljenog pristupa bez ikakvih trajnih akreditiva koje bi se mogle ukrasti** – dugoročni ključevi su klasična meta napada vector. Rešeno pomoću PKI servisa koji izdaje kratkoročne SSH sertifikate na zahtev, trezora sa nultim znanjem koji čuva tajne koje sam server ne može da pročita, i hardverski podržanog skladištenja ključeva (Secure Enclave / Android Keystore / DPAPI / HSM), tako da privatni materijal nikada nije izložen na disku.
- **Omogućavanje više operatera da upravljaju jednom sesijom bez oštećenja bafera** – istovremeno uređivanje deljenog terminala je složen problem konzistentnosti. Rešeno pomoću CRDT sinhronizacije bafera, izabrane umesto operativne transformacije (prema ADR-006), upravo zato što CRDT-ovi konvergiraju bez centralnog arbitra.
- **Obezbeđivanje da dokazi o usklađenosti ne mogu biti neprimetno izmenjeni** – revizijski zapis koji se može uređivati ne dokazuje ništa. Rešeno pomoću zapisnika koji se može samo dodavati, vezanog Merkle lancom, gde svaka promena narušava lanac hešova, stvarajući izvozive dokaze za SOC 2 / ISO 27001 / FedRAMP.
- **Jedinstveno korisničko iskustvo na desktopu, mobilnim uređajima i vebu bez tri odvojene kodne baze** – rešeno pomoću jednog Flutter/Dart klijenta zasnovanog na BLoC obrascu, pri čemu je Flutter izabran umesto Electron (prema ADR-001) kako bi se šest platformi pokrilo iz jednog izvora istine.


## Tehnološki stek

- **Go mikroservisi** — flota pozadinskih servisa (SSH proxy, terminal, trezor, PKI, revizija i još mnogo toga); izabrani zbog modela konkurentnosti i malog zauzeća tokom izvršavanja, idealni za servise koji istovremeno održavaju brojne dugotrajne striming sesije (ADR-002: Go umesto Rust/Node).
- **Flutter / Dart (BLoC)** — jedan klijentski kod za šest platformi, gde BLoC osigurava predvidljivost stanja; Flutter izabran umesto Electron (ADR-001) kako bi se izbeglo održavanje zasebnih nativnih i veb interfejsa.
- **PostgreSQL** — primarna baza podataka, izabrana umesto CockroachDB (ADR-004) zbog zrelog, dobro razumljivog transakcionog jezgra.
- **Kafka + RabbitMQ** — sloj za razmenu poruka i striming koji prenosi segmente sesija i događaje (ADR-003), kombinujući trajan log sa fleksibilnim redovima.
- **Redis** — čuva bafer za pomeranje terminala i trenutno stanje sesija gde je niska latencija važnija od trajnosti.
- **SPIFFE/SPIRE + mTLS** — izdaje kriptografske identitete radnih opterećenja (ADR-005) kako bi saobraćaj između servisa bio međusobno autentifikovan, proširujući princip nultog poverenja unutar mreže, a ne samo na njenim granicama.
- **Ed25519 (EdDSA)** — potpisuje JWT tokene i snimke sesija (ADR-009), pružajući brze, moderne potpise koji omogućavaju verifikaciju snimljenih sesija.
- **Kubernetes + Helm + Terraform** — implementacija zasnovana na kontejnerima sa reproduktivnom, verzionisanom infrastrukturom (ADR-007/008).
- **OpenTelemetry, Grafana, Jaeger, Loki** — stek za opservabilnost koji obuhvata tragove, metrike, kontrolne table i logove; **Falco, Trivy, Cosign, Sealed Secrets** — detekcija pretnji u realnom vremenu, skeniranje slika, potpisivanje artefakata i šifrovana distribucija tajni kroz lanac snabdevanja.

## Status i napomene o iskrenosti

- **Status: beta.** Značajna, aktivno razvijana kodna baza (kreirana 04.07.2026). Numerički podaci iz istraživačkog paketa MVP projekta (broj krajnjih tačaka, tabela i servisa) predstavljaju ciljeve iz dokumentacije `docs/research/mvp/`, a nisu potvrđeni kao potpuno implementirani, te su stoga navedeni kao obim arhitekture, a ne kao dostignute metrike. Tvrdnje o latenciji/SLO i „spremnosti za produkciju" nisu nezavisno verifikovane.
- **Licenca: Apache-2.0** (prema GitHub API).

**Prioritetni nivo:** Helix-primary.

