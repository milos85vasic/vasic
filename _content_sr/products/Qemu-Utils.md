---
name: Qemu-Utils
slug: qemu-utils
tier: serverfactory-tertiary
order: 31
status: active (documented Shell toolkit)
license: UNVERIFIED
private: false
tech:
  - Shell (~79.5K bytes)
  - QEMU
  - Bridge / TAP networking
  - ISO images
repos:
  - https://github.com/Server-Factory/Qemu-Utils
diagrams:
  - VM lifecycle (ISO/image → cache (compressed/uncompressed) → run → publish)
  - Networking diagram (host bridge + TAP interfaces → VMs)
  - Cross-platform split (Linux vs macOS acceleration paths)
  - Image distribution (remote endpoint ↔ local cache ↔ running VM)
---

**QEMU VM slike, upravljane kao artefakti — preuzimanje, pokretanje, umrežavanje, objavljivanje**

## Sažetak

Qemu-Utils je Server Factory alat za sveobuhvatno upravljanje QEMU virtualizacijom: automatizovana distribucija i kompresija VM slika, lokalno keširanje, konfiguracija mreža sa mostovima/TAP-om, instalacija operativnih sistema sa ISO-a i izvršavanje na više platformi (Linux/macOS) uz hardversko ubrzanje. Može se koristiti samostalno ili unutar Server Factory okruženja.

## Kratak opis

Shell alat za upravljanje životnim ciklusom QEMU virtuelnih mašina. Preuzima, kešira i pokreće unapred konfigurisane QEMU disk slike, kompresuje ih i objavljuje na udaljene krajnje tačke, automatizuje umrežavanje preko mostova/TAP-a, podržava instalacije sa ISO-a i radi na Linuxu i macOS-u uz odgovarajuće hardversko ubrzanje.

## Detaljan opis

Qemu-Utils primenjuje disciplinu upravljanja artefaktima — način na koji timovi već tretiraju izlaze iz build procesa i kontejnerske slike — na nešto što je obično ostavljeno kao gomila ad-hoc poziva `qemu-system-*`: virtuelne mašine. Poput svog Parallels „brata", ovaj alat tretira VM slike kao prvoklasne distributivne resurse, matrice sistema koje se koriste u razvoju i testiranju, ali cilja na istinski višeplatformski QEMU backend. Njegov životni ciklus zatvara pun krug: preuzima i kešira unapred konfigurisane QEMU disk slike, automatski ih preuzima sa udaljenih krajnjih tačaka, održava odvojene lokalne keš memorije za kompresovane i nekompresovane slike kako bi se velika slika preuzela samo jednom i potom jeftino pokretala, te kompresuje i objavljuje slike nazad na udaljene servere za ostatak tima. A budući da je VM kojoj niko ne može pristupiti beskorisna, automatizuje deo koji svi mrze — umrežavanje — upravljajući mostovima i TAP interfejsima za VM konektivnost umesto da operateru ostavlja da ih ručno podešava. Podržava instalacije operativnih sistema sa ISO slika i zaista je višeplatformski — radi na Linuxu i macOS-u uz odgovarajuće hardversko ubrzanje za svaku platformu. Konfiguracija i rad prate isti jednostavan, skriptom vođen Server Factory obrazac, a alat može da se koristi kao deo većeg Server Factory projekta ili potpuno samostalno, u skladu sa filozofijom odvajanja organizacije. Dokumentacija je opsežnija nego kod većine manjih Server Factory repozitorijuma (sa odeljcima za pregled, funkcije, zahteve, brzi početak, konfiguraciju, upotrebu, umrežavanje, rešavanje problema i arhitekturu), što odražava njegovu ulogu kao glavnog puta za upravljanje VM-ovima u Linux/QEMU okruženjima. Zajedno sa Parallels-Utils, Server Factory ekosistemu pruža upravljanje VM slikama na macOS/Parallels i Linux-plus-macOS/QEMU virtualizaciji.

## Zašto smo ga napravili

Priprema i testiranje na više operativnih sistema zahtevaju reproduktivne VM-ove, a čisti QEMU je niskog nivoa i komplikovan — posebno kada su u pitanju umrežavanje i distribucija slika. Qemu-Utils obuhvata QEMU u upravljiv alat kako bi slike i njihove mreže bile reproduktivne na različitim mašinama.

## Zašto je revolucionaran

Obuhvata četiri stvari koje čisti QEMU čine bolnim — distribuciju slika, keširanje, umrežavanje i instalaciju sa ISO-a — u jedan višeplatformski alat, pretvarajući zid komplikovanih komandnih zastavica u ponovljiv, objavljiv VM tok rada koji ceo tim može da deli i reprodukuje identično na Linuxu i macOS-u.


## Šta je inovativno

- Potpun životni ciklus slike **QEMU**: preuzimanje/keširanje/izvršavanje + kompresija/objavljivanje, sa komprimovanim i nekomprimovanim kešom.
- Automatska konfiguracija mosta/TAP mreže za povezivanje virtuelnih mašina.
- Podrška za instalaciju sa ISO medija.
- Višeplatformska podrška (Linux + macOS) sa hardverskim ubrzanjem.

## Izazovi i rešenja

- **Složenost umrežavanja virtuelnih mašina:** rešeno automatskim upravljanjem mostom i TAP interfejsima.
- **Distribucija velikih slika:** rešeno kompresijom, udaljenim objavljivanjem/preuzimanjem i lokalnim keširanjem.
- **Višeplatformska virtualizacija:** rešeno podrškom za Linux i macOS uz odgovarajuće ubrzanje.
- **Inicijalno postavljanje:** rešeno podrškom za instalaciju sa ISO medija.

## Tehnološki stek (zašto + kako)

- **Shell** — kompletan alat (~79,5K bajtova); skripte za upravljanje slikama, mrežom i virtuelnim mašinama.
- **QEMU** — virtuelizacioni pogon koji se upravlja.
- **Mreža sa mostom/TAP** — infrastruktura za umrežavanje virtuelnih mašina na Linuxu i macOS-u.
- **ISO slike** — izvor za instalaciju operativnog sistema.

> Napomena: **GitHub** označava repozitorijum kao fork unutar organizacije Server-Factory. Višeplatformski pratilac **Parallels-Utils**. Nije povezano sa **AI**.

