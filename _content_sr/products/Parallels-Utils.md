---
name: Parallels-Utils
slug: parallels-utils
tier: serverfactory-tertiary
order: 32
status: active (niche, macOS-specific Shell/Python toolkit)
license: UNVERIFIED
private: false
tech:
  - Shell (~5.3K bytes)
  - Python 3 (~3K bytes)
  - Parallels (macOS)
  - Settings files (.settings)
repos:
  - https://github.com/Server-Factory/Parallels-Utils
diagrams:
  - Image lifecycle (build → compress → publish → retrieve → run)
  - One provider endpoint → many workstations pulling the same image matrix
  - Settings-file map (location/provider/sync) feeding the scripts
---

**Kompresujte, objavite i ponovo koristite svoje Parallels VM slike na svakom računaru.**

## Sažetak

Parallels-Utils je Server Factory alat za upravljanje Parallels (macOS) slikama virtuelnih mašina: kompresovanje i sinhronizovanje „matrica" slika koje se koriste za razvoj i testiranje, njihovo objavljivanje na udaljenom čvorištu te preuzimanje i pokretanje na više radnih stanica ili servera. Može se koristiti samostalno ili kao deo Server Factory.

## Kratak opis

Shell/Python alat za upravljanje životnim ciklusom Parallels VM slika na macOS-u. Kompresuje i sinhronizuje Parallels slike, objavljuje ih na udaljeno čvorište te ih preuzima i pokreće na više računara — vođen jednostavnim konfiguracionim datotekama, upotrebljiv samostalno ili u okviru Server Factory.

## Detaljan opis

Parallels-Utils rešava praktičan DevOps problem u razvoju zasnovanom na macOS-u: timovi kreiraju „matrice" Parallels virtuelnih mašina (različiti operativni sistemi/konfiguracije koje se koriste za razvoj i testiranje), a te slike moraju biti kompresovane, objavljene, preuzete i dosledno pokrenute na više računara. Alat pruža upravo taj životni ciklus. Mehanizam za sinhronizaciju kompresuje Parallels slike i održava ih ažurnim; mehanizam za objavljivanje šalje slike na udaljeno čvorište; a mehanizam za preuzimanje omogućava svakoj radnoj stanici ili serveru da povuče objavljene slike i pokrene ih kao VM. Konfiguracija je namerno jednostavna i vođena datotekama: `image_location.settings` definiše lokaciju slika u fajl sistemu, `image_provider.settings` definiše osnovni URL za objavljene slike, a `image_sync.sh` definiše skriptu za otpremanje — uz primere koji se isporučuju u direktorijumu `Examples`. Operatori koriste `publish_images.sh` za objavljivanje i `run.sh` za pokretanje VM. Potreban je Parallels za odgovarajuću verziju macOS-a i Python 3. Alat je dizajniran za dvostruku upotrebu: može da funkcioniše kao deo većeg Server Factory projekta ili potpuno samostalno, što odražava filozofiju odvajanja organizacije. Čak sadrži i link ka kratkom video tutorijalu. Kao deo porodice Server-Factory, dopunjava Qemu-Utils (Linux/QEMU ekvivalent), pružajući ekosistemu upravljanje VM slikama na macOS/Parallels i cross-platform/QEMU backendima.

## Zašto smo ga napravili

Deljenje konzistentnih VM okruženja za razvoj i testiranje među timom je zamorno — slike su velike, a svaki računar zahteva istu matricu. Parallels-Utils automatizuje kompresiju, objavljivanje i preuzimanje tako da se kanonski skup Parallels VM može reprodukovati svuda.

## Zašto je revolucionaran

Pretvara teške i nespretne Parallels slike u objavljiv, sinhronizovani skup artefakata koji svaki računar može da povuče i pokrene — tako da kanonsko razvojno/testno okruženje prestaje da bude nešto što svaki inženjer ručno ponovo kreira i postaje nešto što jednostavno preuzmete. Radi to uz trivijalnu konfiguraciju putem datoteka i bez ikakve zavisnosti od ostatka Server Factory, ostajući veran filozofiji odvajanja organizacije: koristan sam za sebe, dobar građanin u većem alatu.


## Šta je inovativno

- Kompresija + sinhronizacija „matrica" slika Parallels za razvojno/testiranje.
- Tok rada objavljivanja/preuzimanja kako bi slike bile ponovo upotrebljive na više računara.
- Konfiguracija vođena datotekama podešavanja (lokacija/pružalac/sinhronizacija) uz priložene primere.
- Dvostruka namena: samostalno ili kao komponenta Server Factory.

## Izazovi i rešenja

- **Distribucija velikih slika:** rešeno kompresijom i tokom rada objavljivanja na udaljeni krajnji čvor + preuzimanja.
- **Ponovljivost na različitim mašinama:** rešeno podešavanjima pružaoca/lokacije tako da svaki host razrešava isti skup slika.
- **Jednostavnost korišćenja:** rešeno jednostavnim skriptama `publish_images.sh` / `run.sh` i primerima datoteka podešavanja.

## Tehnološki stek (zašto + kako)

- **Shell** — skripte za objavljivanje/pokretanje/sinhronizaciju (primarni jezik, ~5,3K bajtova).
- **Python 3** — pomoćni alati (obavezna zavisnost, ~3K bajtova).
- **Parallels (macOS)** — virtualizacioni backend koji se upravlja.
- **Datoteke podešavanja (`.settings`)** — deklarativna konfiguracija za lokaciju/pružaoca/sinhronizaciju.

> Napomena: GitHub označava repozitorijum kao fork unutar organizacije Server-Factory. Specifično za macOS, niša. Nije povezano sa AI.

