---
name: HelixPlay
slug: helixplay
tier: helix-primary
order: 18
status: beta
license: TBD
private: false
tech:
  - Go (1.26 root / 1.25+ submodules)
  - Wails v2
  - Flutter 3.29+
  - Angular 17+ (Go → WASM)
  - WebRTC / Pion v4
  - QUIC / quic-go
  - Custom UDP
  - Hardware encoders (NVENC / QSV / AMF / VideoToolbox)
  - Platform capture (DXGI / ScreenCaptureKit / PipeWire)
  - Docker / Podman
  - mDNS / rendezvous
repos:
  - https://github.com/HelixDevelopment/HelixPlay
diagrams:
  - Media pipeline — Capture → Encode → Packetize → Transmit → Decode → Render, annotated with per-stage technologies.
  - Triple-stack convergence — Wails / Flutter / Angular clients all pointing at one Go core.
  - Self-hosted topology — a GPU host + host agent streaming over WebRTC/QUIC to phone, TV, laptop, and browser.
  - White-label layer — one platform, multiple branded tenant skins.
---

# HelixPlay

**Pretvorite svaki uređaj sa GPU u sopstveni uređaj za cloud gejming.**

## Sažetak

HelixPlay je samostalno hostovana platforma za cloud gejming koja pretvara svaki uređaj opremljen GPU u udaljeni streaming host, pružajući gejming iskustvo konzola na desktop, mobilnim, TV i veb klijentima. Izgrađena je kao Go-centrični monorepo sa 46 potmodula, sa trostrukim klijentskim stekom, i može se belo-etiketirati za partnere.

## Kratak opis

HelixPlay je samostalno hostovana, otvorena i belo-etiketirajuća platforma za cloud gejming. Pretvara svaki uređaj opremljen GPU u udaljeni streaming host i pruža gejming iskustvo konzola na desktop, mobilnim, TV i veb klijentima preko WebRTC/QUIC, sa Go jezgrom i Wails/Flutter/Angular klijentskom stekom.

## Detaljan opis

HelixPlay je platforma za cloud gejming izgrađena kao Go-centrični monorepo sastavljen od 46 Git potmodula. Pretvara svaki gejming PC koji već posedujete u streaming host, pružajući iskustvo konzola na desktop, mobilnim, TV i veb klijentima — samostalno hostovano, otvoreno i belo-etiketirajuće za partnere. Poruka je jasna: vaš hardver, vaša usluga, vaš brend, bez treće strane u sredini.

Njena ključna odluka u dizajnu je konvergencija trostrukog klijentskog steka — teška arhitektonska opklada koja se isplati na svim ostalim poljima. Wails desktop aplikacija, Flutter mobilna/TV aplikacija i Angular veb klijent svi se oslanjaju na *jedno* Go jezgro, kompajlirano u WASM za pretraživač, tako da se ponašanje piše jednom i deli na svim površinama umesto da se grana na tri puta. Ispod toga nalazi se putanja za medije u realnom vremenu: Snimanje → Enkodiranje → Pakovanje → Prenos → Dekodiranje → Renderovanje, povezana sa platformski-nativnim snimanjem (DXGI / ScreenCaptureKit / PipeWire) i hardverskim enkoderima (NVENC / QSV / AMF / VideoToolbox) tako da GPU obavlja glavni posao, a prenos se odvija preko WebRTC (Pion v4), QUIC (quic-go) i prilagođenih UDP datagrama izabranih zbog latencije, a ne praktičnosti. Backend jezgro upravlja sesijama, tenantima, katalogom i autentifikacijom; host agent obrađuje snimanje, enkodiranje i prenos na ivici mreže; a mDNS/rendezvous spaja otkrivanje tako da klijenti pronalaze svoj host bez ručnog podešavanja.

HelixPlay je od osnove projektovan za belo-etiketiranje SaaS-a — tematsko prilagođavanje po tenantu, filtriranje kataloga, OAuth2 i naplata — tako da partner može da pokrene potpuno brendiranu uslugu umesto površinske promene izgleda. Takođe je potpuno kontejnerizovan do poslednjeg detalja: svaka usluga, baza podataka, build, test i skeniranje odvija se unutar kontejnera, što čitavu platformu čini reproduktivnom za implementaciju i verifikaciju. Kao i ostatak porodice Helix, zasnovan je na ustavu protiv blefiranja gde zeleni test treba da garantuje stvarno, krajnje korisniku upotrebljivo ponašanje — a ne samo prolazni mock.

## Zašto smo ga napravili

Komercijalni cloud gejming je zatvoren, centralizovan i iznajmljen. HelixPlay je napravljen kako bi svako sa GPU uređajem mogao da pokrene sopstveni streaming host — otvoren, samostalno hostovan i belo-etiketirajući — umesto da zavisi od usluga treće strane.


## Zašto je ovo revolucionarno

Spaja tri stvari koje komercijalne usluge drže odvojeno: samostalno hostovanje na hardveru koji kontrolišete, jedan zajednički Go kernel koji pokreće tri klijentska steka tako da funkcije stižu svuda istovremeno, i white-label višekorisničku arhitekturu. Rezultat je da partner može da pokrene potpuno brendiranu uslugu cloud-gaminga na *svojim* GPU-ima – poseduje iskustvo, korisnike i ekonomiju – umesto da preprodaje kapacitete tuđeg clouda i živi unutar njegovih ograničenja.

## Šta je inovativno

- **Konvergencija trostrukog klijentskog steka** – Wails, Flutter i Angular pokreću se na jednom Go kernelu (WASM u pregledaču), pa desktop, mobilni, TV i veb uređaji dele jednu implementaciju umesto tri koje se razilaze.
- **Samostalno hostovani, white-label SaaS** – ugrađena podrška za prilagođavanje teme po korisniku, filtriranje kataloga, OAuth2 i naplatu, tako da platforma dolazi kao proizvod koji se može brendirati, a ne kao demo.
- **Savremeni transport sa niskom latencijom** – WebRTC (Pion), QUIC i prilagođeni UDP u kombinaciji sa izborom hardverskog enkodera po platformi (NVENC / QSV / AMF / VideoToolbox), optimizovano za brzinu reakcije umesto praktičnosti.
- **Arhitektura sa 46 odvojenih modula** – jasno razdvojeni komponenti sa potpuno kontejnerizovanim pristupom: svaka usluga, baza podataka, build, test i skeniranje pokreće se u kontejneru.

## Najveći tehnički izazovi i kako smo ih rešili

- **Strimovanje sa niskom latencijom na heterogenom hardveru.** Svaki operativni sistem i GPU nudi različite načine za hvatanje i enkodiranje slike, a latencija ne oprašta greške. Rešeno putem platformski svesnog toka za hvatanje/enkodiranje – DXGI / ScreenCaptureKit / PipeWire šalju podatke NVENC-u / QSV-u / AMF-u / VideoToolbox-u – prenoseći ih preko WebRTC-a / QUIC / UDP tako da svaki uređaj koristi svoj najbrži put do piksela.
- **Jedan proizvod za desktop, mobilne, TV i veb.** Rešeno trostrukim klijentskim stekovima (Wails, Flutter, Angular) koji dele jedan Go kernel kompajliran u WASM za pretraživač, pa ispravka ili funkcija napisana jednom pojavljuje se na sve četiri platforme umesto da se portuje četiri puta.
- **Višekorisnička white-label operacija.** Rešeno ugradnjom prilagođavanja teme, filtriranja kataloga, OAuth2 i naplate direktno u osnovni backend, tako da izolacija korisnika i brendiranje postaju osnovne funkcije platforme, a ne prilagođavanja za svakog klijenta posebno.

## Tehnički stek

- **Go (1.26.2 root / 1.25+ submoduli)** – zajednički osnovni backend i host agent; jedan jezik koji se kompajlira u native binarne fajlove *i* u WASM, što omogućava dizajn sa jednim kernelom i više klijenata.
- **Wails v2** – desktop klijent, koji povezuje Go kernel sa ugrađenim web pregledačem tako da desktop aplikacija direktno koristi osnovnu logiku umesto da je ponovo implementira.
- **Flutter 3.29+** – mobilni/TV klijent, koji poziva Go kernel preko FFI-ja za native UI na telefonima i televizorima bez drugog backenda.
- **Angular 17+** – veb klijent, koji pokreće isti Go kernel kompajliran u WASM, pa je pretraživač punopravna platforma, a ne osakaćena verzija.
- **WebRTC / Pion v4, QUIC / quic-go, prilagođeni UDP** – tri transportna protokola za strimovanje u realnom vremenu, tako da platforma može da odabere put sa najnižom latencijom za svaku mrežu i klijenta.
- **Hardverski enkoderi (NVENC / QSV / AMF / VideoToolbox)** i **platformsko hvatanje slike (DXGI / ScreenCaptureKit / PipeWire)** – GPU-ubrzani tok za hvatanje i enkodiranje, izabran po platformi tako da enkodiranje nikada ne postane usko grlo na CPU-u.
- **Kontejneri (Docker/Podman)** – svaka usluga, baza podataka, build, test i skeniranje pokreće se u kontejneru, što čitav sistem reproduktivnim za deploy i verifikaciju.
- **mDNS / rendezvous** – otkrivanje hosta bez podešavanja, tako da klijenti automatski pronalaze streaming host na mreži.


## Napomene o statusu i iskrenosti

- **Status: beta.** Ciljevi kašnjenja u README fajlu (≤30 ms LAN / ≤50 ms WAN p999), okvir „konzolne klase / klase PS4 Pro", kao i broj ćelija u test-matriksu predstavljaju projektom navedene ciljeve dizajna, a nisu nezavisno provereni i prezentuju se kao takvi.
- **Licenca: nije određena.** Nije pronađena LICENCA putem GitHub API — NIJE PROVERENO / nije deklarisano.

**Prioritetni nivo:** Helix-osnovni.

