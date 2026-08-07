---
name: HelixSpecifier
slug: helixspecifier
tier: helix-primary
order: 7
status: beta
license: TBD
private: false
tech:
  - Go
  - logrus
  - SpecKit pillar
  - Superpowers pillar
  - GSD pillar
  - Spec memory store
repos:
  - https://github.com/HelixDevelopment/specifier
diagrams:
  - Three-pillars-to-one-flow — SpecKit + Superpowers + GSD → fusion engine → executed flow with quality score.
  - Adaptive-ceremony dial — effort level in → ceremony level out, shown as a scaling gauge.
  - Debate architecture — multiple agents proposing/scoring positions across rounds converging on a spec.
---

# HelixSpecifier

**Razvoj vođen specifikacijama koji sam prilagođava ceremonijal obimu posla.**

## Sažetak

HelixSpecifier je Go motor koji spaja tri metodologije razvoja — tok rada vođen specifikacijama iz SpecKit-a, disciplinu TDD-a iz Superpowers-a i životni ciklus prekretnica iz GSD-a — u jedan prilagodljivi proces. Svaki zadatak klasifikuje prema potrebnom trudu i prilagođava količinu procesa prema tome.

## Kratak opis

HelixSpecifier je motor za razvoj vođen specifikacijama namenjen AI agentima. Kombinuje SpecKit, Superpowers i GSD, klasifikuje posao prema nivou truda, sprovodi faze specifikacije uz podršku debate, nameće minimalni odnos testova i koda, i uči iz svakog završenog toka.

## Detaljan opis

HelixSpecifier je motor za razvoj vođen specifikacijama (SDD) napisan u Go (modul `digital.vasic.helixspecifier`), izgrađen kao komponenta HelixAgent ansambla AI agenata. Spaja tri prakse razvoja koje obično postoje u tri odvojena alata — i tri odvojena načina razmišljanja — u jedan prilagodljivi tok rada: sedmofazni SDD proces iz SpecKit-a (Constitution, Specifikacija, Razjašnjenje, Planiranje, Zadaci, Analiza, Implementacija), TDD disciplinu iz Superpowers-a sa paralelnim izvršavanjem podagenta, i upravljanje životnim ciklusom prekretnica iz GSD-a. Svaki stub nastavlja da radi ono u čemu je najbolji; motor je ono što ih povezuje u jedinstven koherentan tok umesto ručno spajanog procesa.

Njegova centralna ideja je *prilagodljivi ceremonijal*: motor klasifikuje dolazne zadatke prema nivou truda i prilagođava količinu procesa, tako da jednolinijska ispravka ne prolazi kroz isti zahtevni ritual kao velika funkcionalnost — a velika funkcionalnost se ne propušta sa rigoroznošću namenjenom tipografskoj grešci. Na toj osnovi izgrađeno je deset ključnih funkcionalnosti: paralelno izvršavanje zadataka sa ograničenom konkurentnošću, mašinski čitljivi „Constitution kao Kod" koji automatski nameće obavezna pravila, „Njuiistov TDD" koji prati i nameće minimalni odnos testova i implementacije, višestruka debata sa više agenata za dorađivanje specifikacije, adaptivno učenje nivoa veština, analiza postojećeg koda, prediktivna specifikacija zasnovana na istorijskim obrascima, prenos znanja između projekata, prilagođavanje ceremonijala u toku izvršavanja i trajna memorija specifikacija sa semantičkom pretragom.

Koristi se kao Go modul — putem `go get` ili lokalne `replace` direktive — iza namerno jednostavnog API motora: registruju se tri stuba plus skaler ceremonijala i memorija specifikacija, klasifikuje se trud potreban za posao, zatim se izvršava ceo tok i dobija rezultat sa ocenom kvaliteta. Površina je jednostavna; orkestracija iza nje nije. Kao i ostatak Helix porodice, razvija se pod režimom verifikacije bez blefiranja, sa testovima koji proveravaju stvaran kod umesto simulacija.

## Zašto smo ga izgradili

Razvoj vođen specifikacijama, rigorozan TDD i upravljanje prekretnicama obično su tri odvojene prakse sa tri odvojena alata. HelixSpecifier je izgrađen kako bi AI agent (HelixAgent) mogao da izvršava sva tri kao jedan koherentan, samoprilagođavajući tok umesto da ih ručno spaja.


## Zašto je ovo revolucionarno

Automatski prilagođava proces obimu posla. Timovi obično zapadnu u jednu od dve krajnosti: preteranu ceremonijalnost u svemu (bezbedno, ali sporo i potajno omraženo) ili potpuni nedostatak ceremonijalnosti (brzo dok ne prestane da bude). HelixSpecifier ukida taj kompromis tako što prilagođava ceremonijalnost klasifikovanom naporu za svaki zadatak i ponovo je podešava tokom izvršavanja, kako se posao otkriva. Mogućnost koja ranije nije bila praktična jeste proces koji se sam prilagođava svakom zadatku — a povrh toga, specifikacione odluke podržane višestrukom, višekorisničkom raspravom sa ocenjivanjem stavova, umesto prvog nagađanja jednog agenta.

## Šta je inovativno

- **Adaptivna ceremonijalnost** — nivo procesa vođen metrikama kvaliteta u realnom vremenu i prilagođavan tokom izvršavanja, a ne unapred fiksiran.
- **Najkvist TDD** — kontrola odnosa testova i implementacije (minimum 2x), zasnovana na logici Najkvistove teoreme o uzorkovanju: da biste verno uhvatili ponašanje, morate ga uzorkovati znatno iznad njegove frekvencije, pa testovi moraju nadmašiti kod koji pokrivaju.
- **Arhitektura rasprave** — višestepeno, višekorisničko dorađivanje specifikacije, gde se predlozi iznose, ocenjuju i konvergiraju, zamenjujući pojedinačno mišljenje protivničkim pristupom.
- **Prediktivna specifikacija** i **prenos znanja između projekata** — motor analizira akumulirane tokove kako bi predvideo specifikacije i preneo stečeno znanje iz jednog projekta u sledeći.
- **Constitution kao kod** — obavezna pravila projekta pretvorena u mašinski čitljive i sprovođena pomoću motora, umesto da se oslanjaju na budnost revizora.

## Najveći tehnički izazovi i kako smo ih rešili

- **Spajanje tri metodologije bez međusobnog sukoba** — SpecKit, Superpowers i GSD svaka pretpostavlja da ima kontrolu nad radnim tokom. Rešeno fuzionim motorom koji registruje svaki stub iza zajedničkog interfejsa i pokreće ih kroz jedan zajednički životni ciklus toka, tako da se stapaju u jedinstven proces umesto da se sudaraju.
- **Određivanje koliko procesa određeni zadatak zapravo zahteva** — previše procene i sve se vuče; premalo i rizičan posao stiže na produkciju nekontrolisan. Rešeno klasifikatorom napora koji procenjuje posao i napaja skaler ceremonijalnosti koji dinamički prilagođava nivo procesa tokom izvršavanja.
- **Održavanje visokog kvaliteta specifikacije bez ljudskog kontrolora za svaku odluku** — rešeno zamenom jednokratnih specifikacija dorađivanjem zasnovanim na raspravi, gde agenti ocenjuju konkurentske predloge kroz runde, i sprovođenjem Najkvist TDD odnosa kako implementacija ne bi pretekla svoje testove.

## Tehnološki stek

- **Go** — izabran kako bi motor bio isporučivan kao jedan uvozni binarni fajl bez dodatnog tereta tokom izvršavanja; njegov model konkurentnosti omogućava ograničeno paralelno raspoređivanje zadataka i višestepene runde rasprave umesto problema sa nitima.
- **logrus** — strukturirano logovanje koje se provlači kroz motor i sva tri stuba, tako da su odluke toka (klasifikacija, promene ceremonijalnosti, ishodi rasprave) čitljive i naknadno.
- **Stub SpecKit** — sedmofazni proces razvoja vođen specifikacijom (Constitution → Specifikacija → Razjašnjenje → Planiranje → Zadaci → Analiza → Implementacija), koji pruža disciplinovanu osnovu za pretvaranje specifikacije u kod.
- **Stub Superpowers** — disciplina TDD sa paralelnim izvršavanjem podagenta, koja obezbeđuje rigoroznost testiranja pre implementacije i paralelizaciju koja održava iskrenost i brzinu implementacije.
- **Stub GSD** — upravljanje prekretnicama i životnim ciklusom, dajući toku osećaj „završenosti" i napredovanja kroz faze.
- **Memorija specifikacija** — trajna, semantički pretraživa baza prošlih specifikacija, osnova koja omogućava prediktivnu specifikaciju i prenos znanja između projekata umesto da se svaki put kreće od nule.


## Napomene o statusu i iskrenosti

- **Status: beta.** Koristi se kao komponenta modula Go unutar HelixAgent.
- **Licenca: nije određena.** Nije pronađena LICENCA putem GitHub API — NEVERIFIKOVANO / nije navedeno.
- Prikazano ime "HelixSpecifier" upućuje na repozitorijum `specifier`.

**Prioritetni nivo:** Helix-primarni.

