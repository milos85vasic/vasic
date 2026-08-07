---
name: Mail Server Factory
slug: mail-server-factory
tier: serverfactory-tertiary
order: 29
status: production (reports 439 tests at 100% pass and a clean SonarQube gate)
license: UNVERIFIED
private: false
tech:
  - Kotlin (2.0.21)
  - Shell
  - Docker
  - QEMU
  - JSON (declarative config)
  - Gradle 8.14.3 / Java 17
  - Caffeine
  - G1GC-tuned JVM
  - Prometheus-compatible metrics
  - Sieve
repos:
  - https://github.com/Server-Factory/Mail-Server-Factory
  - https://github.com/Server-Factory/Mail-Server-Factory-Website
diagrams:
  - JSON-in → Factory engine → installed Docker mail stack (Postfix/Dovecot/TLS)
  - Connection-type fan-out (local/SSH/Docker/K8s/AWS SSM/Azure/GCP/Libvirt) to targets
  - Distribution matrix (Western/Russian/Chinese families) with unattended-install badges
  - Security layer callouts (AES-256-GCM, firewall ports, TLS/HSTS, RBAC, audit log)
---

**Upravljajte svojim mail serverom kao šef — opišite ga u JSON, implementirajte ga bilo gde.**

## Sažetak

Mail Server Factory je alat za automatizovano postavljanje mail servera, spreman za produkciju. Korisnik piše jednostavnu JSON konfiguraciju; Fabrika je interpretira i izvršava sve instalacije i inicijalizacije na ciljnom OS-u, postavljajući labavo povezani mail stek zasnovan na Docker preko 12 tipova veza.

## Kratak opis

Alat Kotlin/Shell koji pretvara JSON opis u potpuno instaliran, Dockerizovan mail server. Podržava 12 tipova veza (SSH, Docker, Kubernetes, AWS SSM, Azure, GCP, Libvirt i druge), potpuni sigurnosni okvir, 25 Linux distribucija i isporučuje se sa 439 uspešno položenih testova.

## Detaljan opis

Postavljanje pravog, sigurnog mail servera jedno je od klasičnih inicijacijskih iskustava u sistemskoj administraciji — i jedno od najpouzdanije mučnih. Postfix, Dovecot, TLS sertifikati, DNS zapisi, pravila vatrozida i specifičnosti pojedinih distribucija moraju da se savršeno usaglase, a jedna jedina pogrešna direktiva znači tiho odbijanje pošte ili otvoreni relej. Mail Server Factory preuzima ceo taj skup teško stečenog, podložnog greškama znanja i ugrađuje ga u softver. Umesto ručnog podešavanja svakog dela na nepoznatom OS-u, krajnji korisnik opisuje željeni rezultat kao jednostavan JSON dokument; Fabrika čita taj JSON i izvršava tačno određene korake instalacije i inicijalizacije na ciljnom operativnom sistemu, postavljajući mail stek koji radi na Docker, pri čemu je svaka komponenta labavo povezana — dizajnerski izbor koji omogućava horizontalno skaliranje i omogućava nadogradnju ili zamenu bilo koje pojedinačne komponente u izolaciji. Namerno je agnostičan u pogledu okruženja: 12 tipova veza omogućava da isti alat i isti JSON ciljaju lokalnu mašinu, udaljeni host preko SSH, Docker ili Kubernetes runtime, cloud instance putem AWS SSM / Azure Serial Console / GCP OS Login, ili virtuelne mašine preko Libvirt — isti deklarativni opis, implementiran tamo gde ga uputite. Podržava 25 Linux distribucija iz zapadnih (Ubuntu, Debian, CentOS, Fedora, AlmaLinux, Rocky, openSUSE), ruskih (ALT, Astra, ROSA) i kineskih (openEuler, openKylin, Deepin) porodica, sa automatskom instalacijom putem preseed/kickstart/cloud-init/autoyast i QEMU-baziranom automatizacijom virtuelnih mašina za testiranje. Enterprise funkcije su opsežne: AES-256-GCM enkripcija, obavezne politike lozinki i SSH ključeva, automatska konfiguracija vatrozida za mail portove (25/587/465/993/995), TLS/SSL sa validacijom sertifikata i HSTS, audit logovanje i RBAC. Operativne funkcije uključuju podešavanje JVM-a (G1GC), Caffeine keširanje, pooling veza, Prometheus-kompatibilne metrike, struktuirano logovanje, hot-reloading konfiguracije i upravljanje tajnama. Projekat ima 439 testova sa 100% uspešnosti i čist SonarQube kvalitetni prolaz. Predstavlja vodeći projekat organizacije Server-Factory.


## Zašto smo ga napravili

Postavljanje sigurnog, produkcijskog mail servera poznato je po tome što je sklono greškama i specifično za operativni sistem. Mail Server Factory tu stručnost obuhvata u deklarativnom JSON modelu uz pomoć izvršnog motora, tako da se ispravan, osiguran, Dockerizovan mail stek može reprodukovati na bilo kom podržanom cilju bez ručnog korak-po-korak rada.

## Zašto je revolucionarno

Ovaj alat pretvara postavljanje mail servera iz specijalističkog, višednevnog i precizno zahtevnog procesa u čin pisanja konfiguracije — a zatim taj čin čini prenosivim na 12 tipova veza i 25 Linux distribucija, uz unapred podešenu sigurnost na nivou preduzeća. Rezultat je reproduktivan i *verifikovan*: isti JSON uvek daje isti osiguran stek, a 439 uspešno položenih testova i čist SonarQube kontrolni punkt znače da je motor koji obavlja posao pod strogom kontrolom, a ne da se oslanja samo na reputaciju.

## Šta je inovativno

- Deklarativni JSON → interpretirana instalacija/inicijalizacija na ciljnom OS-u.
- 12 tipova veza (lokalna, SSH, Docker, Kubernetes, AWS SSM, Azure, GCP, Libvirt i još) iza jednog alata.
- Podrška za 25 distribucija sa instalacijom bez nadzora (preseed/kickstart/cloud-init/autoyast) i QEMU automatizacijom.
- Labavo povezani Dockerizovan stek za nezavisno skaliranje/nadogradnje.

## Izazovi i rešenja

- **Heterogenost OS-a/distribucija:** rešeno receptima specifičnim za svaku distribuciju, konfiguracijama za instalaciju bez nadzora i QEMU testiranjem na više distribucija.
- **Dostizanje mnogih ciljeva za implementaciju:** rešeno sa 12 priključivih tipova veza pod zajedničkim instalacionim motorom.
- **Sigurnost podrazumevano:** rešeno AES-256-GCM enkripcijom, obaveznom politikom ključeva/lozinki, automatizovanim pravilima zaštitnog zida i TLS/HSTS-om.
- **Poverenje u ispravnost:** rešeno paketom od 439 testova (100% uspešno položenih) i čistim SonarQube kontrolnim punktom.

## Tehnički stek (zašto + kako)

- **Kotlin** — Fabrički motor i logika instalacionih koraka (179K bajtova; Kotlin 2.0.21).
- **Shell** — skripte za provizionisanje, menadžeri ISO/QEMU datoteka i automatizacija OS-a (dominantno po veličini).
- **Docker** — runtime za implementiran, labavo povezani mail stek.
- **QEMU** — automatizacija virtuelnih mašina za instalaciju i testiranje na više distribucija.
- **JSON** — deklarativni format konfiguracije koji korisnik koristi.
- **Gradle 8.14.3 / Java 17** — alat za izgradnju.
- **Caffeine** — keširanje u više regiona; **JVM podešen za G1GC** radi performansi.
- **Prometheus-kompatibilne metrike** — monitoring; spreman za Grafana/ELK.
- **Sieve** — pravila za filtriranje pošte (mali utisak u statistici jezika).

> Napomena: GitHub označava repozitorijum kao fork unutar Server-Factory organizacije. Prethodi AI liniji proizvoda; predstavljen kao zrela DevOps/provizionerska zastava, a ne kao AI uslužni alat.

