---
name: DocProcessor
slug: docprocessor
tier: vasic-util-secondary
order: 24
status: active
license: Apache-2.0
private: false
tech:
  - Go (1.25+)
  - LLM agents (optional extraction)
  - Heuristic parser (offline fallback)
  - i18n Translator (pkg/i18n)
  - Challenge harness
repos:
  - https://github.com/HelixDevelopment/DocProcessor
  - https://github.com/vasic-digital/DocProcessor
diagrams:
  - Docs → feature map → verification-coverage matrix
  - Dual-extractor switch (LLM path vs heuristic/offline path)
  - QA loop (DocProcessor extract → HelixQA prove with evidence → convergence)
  - Coverage dashboard concept (documented vs verified features)
---

**Pretvorite dokumentaciju u proverljivu mapu funkcija za automatizaciju QA.**

## Sažetak

DocProcessor je samostalni, potpuno odvojeni Go modul koji učitava projektnu dokumentaciju, gradi strukturirane mape funkcija i prati pokrivenost verifikacije. Dizajniran je da radi sa LLM agentima za inteligentnu ekstrakciju funkcija, ali uključuje i heurističku ekstrakciju za offline upotrebu.

## Kratak opis

Projektno-agnostički Go modul za obradu dokumentacije i ekstrakciju mapa funkcija. On parsira dokumentaciju u strukturirane mape funkcija i prati koje su funkcije verifikovane — koristeći LLM agente za inteligentnu ekstrakciju ili heuristiku offline — i snabdeva automatizaciju QA garancijom „bez obmane, uvek odgovara stvarnosti".

## Detaljan opis

Svaki softverski tim živi sa istom sporom laži: dokumentacija obećava funkcije, testovi pokrivaju nešto slično, a niko ne može sa sigurnošću reći da li ta dva opisa govore o istom proizvodu. DocProcessor postoji da bi taj jaz učinio vidljivim i merljivim. Na osnovu projektne dokumentacije, on gradi strukturiranu mapu funkcija — nabrojani, mašinski čitljivi model svega što proizvod tvrdi da radi — i prati pokrivenost verifikacije u odnosu na nju, tako da pitanje „da li je ova dokumentovana funkcija zaista dokazana?" prestaje da bude tema hodničke rasprave i postaje upit sa odgovorom. Namerno je dvorežimski: koristi LLM agente za inteligentnu, semantičku ekstrakciju funkcija kada su dostupni, a u slučaju potpune offline upotrebe prelazi na heuristički parser, tako da nikada ne zavisi od prisustva modela i radi identično u izolovanom CI okruženju ili na laptopu programera u režimu aviona.

Arhitektonski je samostalni, projektno-nesvesni, potpuno odvojeni Go modul (CONST-051(B)): ne sadrži nikakve projektno-specifične vrednosti i uključuje se kao podmodul jednakog koda, tako da ga svaki projekat može usvojiti bez nasleđivanja tuđih pretpostavki. Takođe, drži se istog standarda koji nameće drugima — njegove sopstvene tvrdnje su vezane za princip „bez obmane" (CONST-035) i pravila potpune automatizovane pokrivenosti (CONST-048), što znači da je svaka mogućnost navedena u README-u proverena automatskim testom ili Challenge skriptom koja potvrđuje stvarno, krajnje korisničko ponašanje, a ne samo uspešan završetak; korisnički vidljivi stringovi prolaze kroz CONST-046 i18n prevodilački sloj. Smisao svega ovoga je zatvorena petlja: DocProcessor je ulazna strana QA ciklusa koju HelixQA zatvara — on ekstrahuje mapu funkcija iz dokumentacije, HelixQA dokazuje svaku mapiranu funkciju uhvaćenim dokazima u runtime-u, a dokumentacija, testovi i isporučeno ponašanje su primorani da konvergiraju umesto da se tiho udaljavaju iz verzije u verziju.

## Zašto smo ga napravili

Dokumentacija i testovi se udaljavaju: dokumentacija obećava funkcije koje nijedan test ne dokazuje, a QA ne može lako da utvrdi šta znači „potpuno". DocProcessor pretvara dokumentaciju u mašinski čitljivu mapu funkcija kako bi se pokrivenost verifikacije mogla meriti u odnosu na ono što je stvarno obećano.


## Zašto je ovo revolucionarno

Pretvara najnejasnije pitanje u isporuci softvera — *„Da li ono što smo isporučili odgovara onome što smo rekli da ćemo isporučiti?"* — u nešto što se može automatizovati i kontinuirano proveravati, i to bez čvrste AI zavisnosti: LLM ekstrakcija kada je model dostupan, heuristika kada nije, tako da ista garancija važi u svakom okruženju — od oflajn pokretača do potpuno agenstke pipeline-a.

## Šta je inovativno

- Ekstrakcija mape funkcionalnosti iz dokumentacije uz praćenje pokrivenosti verifikacijom.
- Dvostruka ekstrakcija: vođena LLM agentima ili heuristikom/u oflajn režimu.
- Nezavisnost od projekta, potpuno odvojeno bez podešavanja (CONST-051(B)).
- Anti-bluf samoverifikacija: tvrdnje iz README fajla potkrepljene su testovima/Izazovima (CONST-035/048).

## Izazovi i rešenja

- **Rad bez obaveznog modela:** rešeno heurističkim ekstraktorom kao rezervnim rešenjem, tako da modul radi i oflajn.
- **Usklađivanje dokumentacije i stvarnosti:** rešeno strukturiranim mapama funkcionalnosti i praćenjem pokrivenosti verifikacijom, integrisanim u QA proces.
- **Ponovna upotrebljivost:** rešeno striktnim odvajanjem i potrošnjom podmodula iz istog kodnog repozitorijuma.
- **Kredibilitet sopstvenih tvrdnji:** rešeno anti-bluf testovima/Izazovima za svaku reklamiranu mogućnost.

## Tehnološki stack (zašto + kako)

- **Go (1.25+)** — jezgro modula; licenca Apache-2.0.
- **LLM agenti** — inteligentna semantička ekstrakcija funkcionalnosti (opciono).
- **Heuristički parser** — rezervno rešenje za ekstrakciju funkcionalnosti u oflajn režimu.
- **i18n Prevodilac (`pkg/i18n`)** — CONST-046 lokalizovani stringovi.
- **Okvir za Izazove** — anti-bluf verifikacija sopstvenih tvrdnji modula.

