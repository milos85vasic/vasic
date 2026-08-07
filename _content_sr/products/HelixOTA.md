---
name: HelixOTA
slug: helixota
tier: helix-primary
order: 9
status: in-development
license: Apache-2.0
private: false
tech:
  - Go
  - Gin
  - Kotlin / KMP
  - HTTP/3 QUIC
  - PostgreSQL
  - MinIO / S3
  - AOSP update_engine + AVB/dm-verity
  - React
  - OpenTelemetry
  - Prometheus / Grafana
repos:
  - https://github.com/HelixDevelopment/helix_ota
diagrams:
  - Three-planes architecture — control plane (Go/Gin) ↔ data plane (PostgreSQL/MinIO/OTel) ↔ device (KMP agent + update_engine), with the two extractable seams highlighted.
  - Staged rollout funnel — 5% → 10% → 30% → … → 100% with halt/advance thresholds.
  - Zero-brick A/B slot swap — slot A active, slot B updated + verified, automatic rollback on boot failure.
  - Six ota-* submodules as decoupled building blocks feeding the umbrella system.
---

# HelixOTA

**Univerzalne, potpuno nezavisne over-the-air ažuriranja — dizajnirano da nikada ne dovede do blokade uređaja.**

## Sažetak

Helix OTA je univerzalni, duboko nezavisni sistem za over-the-air ažuriranja: Go kontrolna ravan uz klijentske agente po operativnom sistemu, namenjen bezbednom, faznom isporučivanju ažuriranja firmvera/aplikacija na flote uređaja — od jedne ploče do miliona uređaja. Prvi cilj je Android 15 na Orange Pi 5 Max.

## Kratak opis

Helix OTA je univerzalni sistem za over-the-air ažuriranja — Go kontrolna ravan uz klijentske agente po operativnom sistemu — projektovan da garantuje nultu korupciju sistema, validaciju svih isporuka i detaljno fazno objavljivanje. Prvi cilj je Android 15 na Orange Pi 5 Max, a planirani su adapteri za Linux i Windows.

## Detaljan opis

Helix OTA je univerzalni, generički, duboko nezavisni sistem za over-the-air (OTA) ažuriranja, izgrađen na jednom nepopustljivom principu: ažuriranje nikada ne sme pretvoriti ispravan uređaj u beskoristan. Sastoji se od Go serverske **kontrolne ravni**, **SDK-ova/klijentskih agenata** po operativnom sistemu i **nadzorne table**, a projektovan je od temelja da bude ugradiv u *bilo koji* operativni sistem putem priključivih adaptera, umesto da se za svaku platformu gradi ispočetka. Prvi cilj isporuke je Android 15 (sve varijante) na Orange Pi 5 Max, gde tok izgradnje generiše slike za flaširanje uz validiran OTA `.zip` fajl i obavezne heš fajlove, tako da nijedan artefakt ne stiže na uređaj bez proverljivog otiska; Linux, Windows i drugi operativni sistemi čekaju u planu iza istog adapterskog spoja, spremni za integraciju — bez potrebe za prepravkama.

Dizajn se zasniva na čvrstim garancijama koje postavlja operater, tretiranim kao neprikosnovene arhitektonske invarijante: nulta korupcija sistema, obavezna validacija svakog artefakta pre isporuke, detaljno fazno objavljivanje (odjednom ili u fazama od 5/10/30…100% sa mogućnošću pauziranja i nastavka), potpuna vidljivost flote i linearna skalabilnost — od jedne ploče na stolu do miliona uređaja na terenu. Zaključana arhitektura kombinuje uređajske native Android A/B ažuriranja — AOSP `update_engine` sa AVB/dm-verity i automatskim vraćanjem na prethodnu verziju u slučaju greške pri podizanju sistema — sa prilagođenom, nezavisnom Go kontrolnom ravni, tako da se bezbednost nalazi i u boot putanji bliskoj hardveru *i* na serveru, a ne u jednom ranjivom sloju. Dva spoja su namerno izdvojiva: adapterski spoj za operativne sisteme, koji nosi obećanje prave univerzalnosti, i spoj za mehanizam faznog objavljivanja, koji omogućava kampanje nezavisne od operativnog sistema. Ceo sistem je rastavljen na šest javnih, nezavisno verzionisanih `ota-*` potmodula — ponovljivo upotrebljivih gradivnih blokova umesto monolitne strukture.

Helix OTA se trenutno nalazi u fazi razrade specifikacije/istraživanja i izgradnje testnog pokrića; repozitorijum sadrži autoritativni korpus dizajna, tok izvoza dokumentacije i skele potmodula, a eksplicitno je — u skladu sa principima transparentnog upravljanja — da konačni produkcioni server i agent još ne postoje. Ono što se danas isporučuje jeste nacrt i njegove skele, jasno označen kao takav.

## Zašto smo ga izgradili

OTA se obično reinventira za svaki uređaj i svaki operativni sistem, a loša ažuriranja mogu da onesposobe čitavu flotu. Helix OTA je stvoren kao jedan univerzalni sistem za ažuriranja s prioritetom bezbednosti, koji svaki operativni sistem može da usvoji putem adaptera, s ugrađenim garancijama vraćanja na prethodnu verziju i validacije – a ne kao naknadno dodate funkcije.

## Zašto je revolucionaran

On odbija da tretira „nikada ne onesposobi uređaj" i „postepeno i uočljivo ažuriranje" kao najbolje napore koje se nadate da će izdržati pod opterećenjem – to su arhitektonske invarijante ugrađene u put pokretanja i kontrolnu ravan. A time što su motor za ažuriranje i sloj operativnog sistema zamenljivi šavovi, a ne čvrsto ugrađene pretpostavke, ista kontrolna ravan danas pokreće Android, a spremna je da pokreće i druge operativne sisteme u budućnosti – samo dodavanjem adaptera, bez grananja, prepisivanja ili ponovnog izmišljanja sigurnosnih garancija kojima već verujete.

## Šta je inovativno

- **Dva izdvojiva šava** – šav adaptera za operativni sistem i šav motora za ažuriranje nezavisnog od operativnog sistema – koji pretvaraju „univerzalnost" iz marketinške parole u strukturno svojstvo kodne baze.
- **Sigurnost u dubini**: uređajska A/B ažuriranja na nivou operativnog sistema (`update_engine`) + AVB/dm-verity + automatsko vraćanje na prethodnu verziju u slučaju greške pri pokretanju, slojevito *povrh* serverske validacije artefakata – ažuriranje mora da prođe kroz više nezavisnih provera pre nego što se trajno primeni.
- **Decompozicija zasnovana na katalogu, odvojeno**: podela na šest ponovo upotrebljivih, nezavisno verzionisanih `ota-*` potmodula koje možete koristiti po izboru, umesto da gutate monolit.
- **Primarni transport HTTP/3 (QUIC)** sa automatskim povratkom na HTTP/2 i pregovaranom Brotli/gzip kompresijom – moderan, niskolatentni prenos koji se prilagođava umesto da otkaže.
- **Inženjering bez blefiranja**: dizajn i status su eksplicitno označeni kao faza specifikacije, a ništa što nije izgrađeno nikada se ne predstavlja kao isporučeno – poštenje je ugrađeno kao osnovna inženjerska vrednost, a ne kao odricanje u fusnotama.

## Najveći tehnički izazovi i kako smo ih rešili

- **Garantovanje da loše ažuriranje nikada ne onesposobi uređaj** – najteže obećanje u OTA. Rešeno obaveznom uređajskom A/B ažuriranjem na nivou operativnog sistema: `update_engine` upisuje u neaktivni slot dok aktivni slot i dalje radi, AVB/dm-verity kriptografski proverava lanac pokretanja, a ako novi slot ne uspe da se pokrene, uređaj se automatski vraća na prethodnu verziju – sve to podržano obaveznom predimplementacionom validacijom artefakata, tako da se oštećeni sadržaj uhvati pre nego što ikada napusti server.
- **Jedan sistem, više operativnih sistema** – rešeno odbijanjem da se pretpostavke specifične za Android ugrade u jezgro. Zamenljivi šav adaptera za operativni sistem izoluje specifičnosti platforme, a šav motora za ažuriranje nezavisnog od operativnog sistema čuva logiku kampanje prenosivom, pri čemu je svaki zadržan kao poseban potmodul, tako da je dodavanje novog operativnog sistema proširenje, a ne hirurška intervencija na celom sistemu.
- **Postepena, zaustavljiva ažuriranja** – rešeno posvećenim motorom za ažuriranje koji razmišlja u procentualnim kohortama sa pragovima uspeha/greške i eksplicitnom kontrolom zaustavljanja/nastavljanja, namerno oslobođenim od sprega sa HTTP-om, tako da isti motor može da pokreće kampanje nezavisno od transportnog sloja.


## Tehnološki stek

- **Go + Gin** — izabrani zbog modela konkurentnosti i minimalnog otiska pri implementaciji; pokreću kontrolnu ravan, motor za isporuku ažuriranja i validator artefakata, nudeći primarni interfejs REST `/api/v1`.
- **Kotlin/KMP** — izabrani kako bi Android agent OTA na uređaju mogao da deli logiku na različitim ciljnim platformama; upravlja celim ciklusom uređaja: provera / preuzimanje / verifikacija / primena / izveštavanje.
- **HTTP/3 (QUIC) → HTTP/2** — QUIC izabran kao primarni transportni protokol za isporuku sa niskom latencijom i otpornošću na nestabilne mobilne veze, uz automatsko vraćanje na HTTP/2 kako nijedan uređaj ne bi ostao izolovan; **Brotli/gzip** se pregovaraju po zahtevu radi smanjenja veličine paketa.
- **PostgreSQL** — izabran zbog relacionog integriteta u registru uređaja, kampanjama i telemetriji, gde je ispravnost stanja flote važnija od brzine upisa.
- **MinIO / S3** — izabrani kao skladište artefakata kako bi velike slike firmvera bile smeštene u standardno skladište objekata, odvojeno od relacionog sloja.
- **AOSP `update_engine` + AVB/dm-verity + `boot_control`** — izabrani jer je ponovna upotreba Androidovog već isprobanog mehanizma Virtual A/B i verifikacije pokretanja sigurnija od kreiranja sopstvenog rešenja za ažuriranje; koriste se za upravljanje promenom slotova i kriptografskom verifikacijom pokretanja na uređaju.
- **React** — izabran za upravljački panel gde operatori prijavljuju, otpremaju artefakte, pokreću isporuke i prate stanje flote na jednom mestu.
- **OpenTelemetry + Prometheus/Grafana** — izabrani za neutralnu instrumentaciju proizvođača; koriste se kako bi svaka faza isporuke bila vidljiva u metrikama i panelima, umesto da se nagađa.

## Status i napomene o iskrenosti

- **Status: u razvoju.** U skladu sa pravilima projekta protiv preuveličavanja, **još ne postoji funkcionalni produkcioni server niti agent** — ovo je faza specifikacije/istraživanja i izgradnje testnog pokrića. Repozitorijum sadrži autoritativni korpus dizajna, pipeline za izvoz dokumentacije i skelu za podmodule.
- Šest javnih, ponovo upotrebljivih podmodula (`ota-protocol`, `ota-artifact-validator`, `ota-rollout-engine`, `ota-update-engine-bridge`, `ota-android-agent`, `ota-telemetry-schema`) nalazi se na `github.com/HelixDevelopment/`.
- Pokrivenost testovima i podaci o latenciji u repozitorijumu predstavljaju projektnu evidenciju u toku, a nisu nezavisno potvrđeni. Brojevi klauzula HelixConstitution navedeni u README fajlu SU NEVERIFIKOVANI.
- **Licenca: Apache-2.0.**

**Prioritetni nivo:** Helix-primary.

