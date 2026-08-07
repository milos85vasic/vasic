---
name: HelixGitpx
slug: helixgitpx
tier: helix-primary
order: 17
status: shipped
license: TBD
private: false
tech:
  - Go monorepo
  - Angular 19 + Nx
  - Kotlin Multiplatform + Compose
  - Kubernetes + Helm + Argo CD + Kustomize
  - OPA (Rego)
  - Docusaurus
  - Astro
  - mise
repos:
  - https://github.com/HelixDevelopment/HelixGitpx
diagrams:
  - Hub-and-spoke federation — one source-of-truth hub pushing to a ring of host logos (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit, GitFlic, GitVerse, Gitee, Forgejo, SourceHut).
  - Conflict-resolution flow — divergent mirrors → policy/AI resolver → reconciled single truth.
  - Delivery stack — Go platform + Angular web + KMP clients over a Kubernetes/Argo platform layer.
---

# HelixGitpx

**Jedan izvor istine, ogledalo svuda — federisani Git na desetak hostova.**

## Sažetak

HelixGitpx (Helix Git Proxy eXtended) je federisani Git proxy koji održava jedan izvor istine ogledan na više Git hostova i rešava neizbežne konflikte pomoću tokova vođenih politikama i AI. Stigao je do verzije v1.0.0 GA.

## Kratak opis

HelixGitpx je federisani Git proxy koji ogleda jedan izvor istine na desetak i više Git hostova — GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit i druge — i rešava sinhronizacione konflikte pomoću tokova vođenih politikama i AI. Izdat je kao v1.0.0 GA.

## Detaljan opis

HelixGitpx — „Helix Git Proxy eXtended" — je federisani Git proxy koji održava jedan izvor istine ogledan na više Git hostova i rešava konflikte koji se neizbežno javljaju čim isti repozitorijum postoji na više mesta. Podržani hostovi čitaju se kao mapa celog Git ekosistema: GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut i generički Git preko HTTPS-a. Dok bi naivni `git push` na desetak udaljenih repozitorijuma ili odmah pao ili, što je gore, dozvolio da se ogledala tiho razilaze, HelixGitpx stupa na scenu sa tokovima rešavanja vođenim politikama i AI, koji usaglašavaju razilaženja i vraćaju ih na jedan autoritativni izvor istine.

Projekat je stigao do verzije v1.0.0 GA, sa označenim prekretnicama od `m1-foundation` do `m8-ga` — potpuno definisanim putem od osnove do opšte dostupnosti. Projektovan je kao tri sloja jednog proizvoda: Go monorepo (platforma plus osamnaest servisa, alati za generisanje koda i skafolding), Angular 19 + Nx veb aplikacija i Kotlin-Multiplatform + Compose klijentske ljuske koje isporučuju izvorne iskustvo za Android, iOS i desktop iz deljenog koda. Isporuka platforme je u potpunosti Kubernetes-native — Helm šeme, Argo CD aplikacije, Kustomize slojevi, SQL i OPA politike — sa CI cevovodima zaštićenim eksplicitnim okidačima kako se ništa ne bi slučajno objavilo. Javna dokumentacija isporučuje se kao sajt na Docusaurusu (docs.helixgitpx.io), uz Astro marketinški sajt (helixgitpx.io).

Upravljanje je strogo i zasnovano na ustavu, što je odlika, a ne puka formalnost: nosivi dokument je projekat Constitution, čiji Član II propisuje matricu od sedam tipova testiranja sa 100% pokrivenošću *po tipu, po modulu koji je izmenjen*, pri čemu su mock-ovi dozvoljeni samo u jediničnim testovima, a nijedan test se ne sme preskočiti. Verifikator koji se pokreće jednom proverava sve artefakte, kao i `go vet` i `go test` u celom radnom prostoru, a svaki push se širi na sve konfigurisane hostove — tako da je „ogledala sinhronizovana" nešto što sistem nameće na svakom komitu, umesto da se čovek seća da proveri.

## Zašto smo ga napravili

Održavanje autentičnog repozitorijuma na više Git hostova — zbog redundancije, suvereniteta ili dostupnosti na regionalnim platformama — je krhko i zahteva ručni rad, a razilaženja ogledala teško je uskladiti. HelixGitpx je napravljen da sinhronizacija na više hostova postane primarna, konfliktima svesna funkcionalnost.


## Zašto je ovo revolucionarno

Prelazi sa pristupa „guraj na više udaljenih repozitorija i nadaj se najboljem" – krhkog, ručnog statusa kvo – na uređenu federaciju sa jednim autoritativnim izvorom istine i automatskim rešavanjem konflikata zasnovanim na pravilima i AI. To čini na neuobičajeno širokom spektru hostova, namerno uključujući regionalne platforme (GitFlic, GitVerse, Gitee) koje većina alata tiho ignoriše, tako da redundansa, suverenitet podataka i doseg u tim ekosistemima prestaju da budu teret za održavanje i postaju jedinstvena funkcionalnost koju konfigurišete jednom.

## Šta je inovativno

- **Širina upstream repozitorija** – preko desetak Git hostova, od GitHub i GitLab do regionalnih platformi poput GitFlic, GitVerse i Gitee, sve normalizovano iza jednog proxyja.
- **Rešavanje konflikata uz pomoć pravila i AI** – divergencija se usklađuje pomoću policy motora i AI rešavača, a ne ručnim poređenjem ogledala.
- **Federacija sa jednim izvorom istine** – model slanja na sve upstream repozitorije gde je jedan autoritativni repozitorij istina, a svaki host je ogledalo koje se održava u sinhronizaciji.
- **Strogo testiranje zasnovano na ustavu** – sedam vrsta testova sa 100% pokrivenošću po tipu, bez preskakanja, dokazano jednim skriptom za proveru celog seta, a ne zasnovano na poverenju.

## Najveći tehnički izazovi i kako smo ih rešili

- **Divergencija i konflikti na više upstream repozitorija.** Isti repozitorij koji postoji na desetak mesta počinje da odstupa čim dva hosta prihvate različite izmene. Rešeno pomoću tokova za rešavanje zasnovanih na pravilima i AI, usidrenih na jednom izvoru istine, uz sinhronizovano slanje na sve upstream repozitorije koje održava sva ogledala u konvergenciji ka toj jednoj istini.
- **Jedinstvena podrška za heterogene Git hostove.** Svaki host ima sopstvenu autentifikaciju, specifičnosti i API. Rešeno pomoću skripti za konfiguraciju po upstream-u u direktorijumu `Upstreams/` i sloja platforme koji apstrahuje te razlike, tako da dodavanje novog hosta postaje pitanje konfiguracije, a ne prepisivanja.
- **Dokazivanje ispravnosti pre svakog spajanja.** Rešeno obaveznom matricom testova sa sedam tipova i jednim „jednokratnim" skriptom `verify-everything.sh` koja pokreće ceo set provera – i prekida se čisto kada klaster nije dostupan, tako da se ispravnost može dokazati lokalno kao i u CI okruženju.

## Tehnološki stek

- **Go monorepo** – osnovni proxy i federacioni engine: platforma sa 18 servisa, generisanjem koda i skeltonima, smeštena u jednom repozitorijumu tako da se ceo engine gradi i testira kao celina.
- **Angular 19 + Nx** – veb-aplikacija, gde Nx obezbeđuje strukturu za izgradnju i keširanje monorepoa koja je neophodna za veliku frontend aplikaciju.
- **Kotlin Multiplatform + Compose** – native Android, iOS i Desktop klijentske shellove generisane iz jedne zajedničke kodne baze, tako da tri platforme ne znače tri različite implementacije.
- **Kubernetes + Helm + Argo CD + Kustomize** – cloud-native isporuka: Helm pakuje izdanje, Kustomize overlays prilagođavaju ga po okruženjima, a Argo CD ga usklađuje putem GitOps-a tako da stanje klastera odgovara Git-u.
- **OPA (Rego)** – politika kao kod za rešavanje konflikata i kontrolu pristupa, čime se odluke o autorizaciji čuvaju deklarativnim i proverljivim.
- **Docusaurus** – javni sajt dokumentacije (docs.helixgitpx.io); **Astro** – marketinški sajt (helixgitpx.io), gde je svaki alat prilagođen tipu sadržaja.
- **mise** – fiksiran, reproduktivan toolchain tako da svaki saradnik i CI runner gradi na tačno istim verzijama.


## Napomene o statusu i iskrenosti

- **Status: isporučeno.** U README fajlu projekta navedena je verzija v1.0.0 GA sa označenim prekretnicama od `m1-foundation` do `m8-ga`. („v1.0.0 GA" je navod iz samog README fajla projekta.)
- **Licenca: treba utvrditi.** Izveštaji GitHub i API navode `MIT`, dok odeljak License u README fajlu navodi Apache-2.0 (kod) / CC-BY-SA-4.0 (dokumentacija) — pre objavljivanja rešiti neslaganje u odnosu na stvarni LICENSE fajl.
- Dokumentacija (docs.helixgitpx.io) i marketinški sadržaj (helixgitpx.io) preuzeti su iz README fajla i nisu nezavisno provereni — status uživo NIJE POTVRĐEN.

**Prioritetni nivo:** Helix-osnovni.

