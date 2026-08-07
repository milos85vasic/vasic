---
name: HelixMemory
slug: helixmemory
tier: helix-primary
order: 6
status: beta
license: TBD
private: false
tech:
  - Go
  - Mem0
  - Cognee
  - Letta
  - Graphiti
  - PostgreSQL
  - Neo4j
  - Redis
  - Prometheus
repos:
  - https://github.com/HelixDevelopment/memory
diagrams:
  - Fusion architecture — four backend boxes (Mem0 / Cognee / Letta / Graphiti) feeding a central router and a three-stage fusion pipeline into one unified result.
  - Write-vs-read flow — a memory being classified and routed on write; a query fanning out and re-ranking on read.
  - Circuit-breaker state machine (closed → open → half-open) illustrating graceful degradation.
---

# HelixMemory

**Jedan memorijski mozak za agente AI — četiri vrhunska motora, spojena u jedno.**

## Sažetak

HelixMemory je Go SDK koji objedinjuje četiri vodeća memorijska sistema (Mem0, Cognee, Letta, Graphiti) u jedinstveni kognitivni memorijski motor koji ih pretražuje paralelno i spaja rezultate. Agensima AI pruža jedan trajan, deduplikovani i prerangirani memorijski sloj umesto četiri nepovezana.

## Kratak opis

HelixMemory je Go SDK koji spaja Mem0, Cognee, Letta i Graphiti u jedinstveni kognitivni memorijski motor za aplikacije AI. Inteligentno usmerava upise, paralelno pretražuje sve pozadinske sisteme i spaja rezultate kroz trostepeni tok prikupljanja, deduplikacije i prerangiranja.

## Detaljan opis

HelixMemory je jedinstveni kognitivni memorijski motor za aplikacije AI, isporučen kao Go SDK (modul `digital.vasic.helixmemory`, verzija Go 1.25+). Njegova temeljna pretpostavka je da nijedan memorijski projekat nikada neće biti najbolji u svemu — umesto da se memorija ponovo implementira od nule i nasledi slepa mesta jednog projekta, on orkestrira četiri vrhunska sistema i omogućava svakom da igra na svojim snagama: Mem0 za dinamično izdvajanje činjenica i upravljanje preferencijama, Cognee za semantičke mreže znanja izgrađene kroz ECL tokove, Letta za stanje agenta sa izmenjivim memorijskim blokovima i računanjem tokom „sna", i Graphiti za bitemporalnu mrežu znanja koja rasuđuje o tome kako se činjenice menjaju kroz vreme.

Motor za spajanje je ono što te četiri nezavisne memorije pretvara u jedan mozak. Na putu upisa, svaka nova memorija se klasifikuje prema sadržaju i usmerava ka pozadinskom sistemu koji je za nju najpogodniji. Na putu čitanja, upit se istovremeno šalje svim pozadinskim sistemima, a dobijeni rezultati ulaze u trostepeni tok spajanja — prikupljanje, deduplikacija, a zatim prerangiranje na osnovu više izvora — tako da pozivalac nikada ne vidi četiri bučna, preklapajuća skupa rezultata, već samo jedan čist, rangirani odgovor. Zaštitni prekidači obavijaju svaki pozadinski sistem kako bi omogućili postupno smanjenje performansi: kada jedan motor otkaže, njegov prekidač se aktivira i preostali sistemi nastavljaju da rade, umesto da povuku ceo memorijski sloj sa sobom. Pošto motor implementira interfejs `MemoryStore` koji se može direktno zameniti, on se ugrađuje kao direktna zamena za običnog pružaoca memorije — bez potrebe za preuređenjem pozivaoca — a Prometheus metrike otkrivaju unutrašnje procese usmeravanja i spajanja radi potpune uočljivosti.

HelixMemory je razvijen kao memorijski sloj za HelixAgent, širi ansambl agenata Helix AI, i unosi porodičnu disciplinu testiranja bez blefiranja u domen memorije: ugrađeni izazivač testira stvarne produkcione tokove — usmeravanje, spajanje, prevod, zaštitni prekidač — dok upareni mutacioni omotač namerno narušava invarijante kako bi dokazao da testovi stvarno padaju kada je logika pokvarena, tako da zeleni set znači nešto.

## Zašto smo ga napravili


AI agentima potrebna je dugovečna, visokokvalitetna memorija, ali je ekosistem fragmentiran – svaki memorijski projekat (Mem0, Cognee, Letta, Graphiti) snažan je u jednoj oblasti, a slab u drugima. HelixMemory stvoren je kako bi HelixAgent agentima pružio jedinstvenu memorijsku površinu koja objedinjuje njihove prednosti, a da ih pritom ne veže za bilo koji od njih.

## Zašto je ovo revolucionarno

Ukida prinudni izbor. Četiri memorijska sistema, koji se inače takmiče za isto mesto, postaju komplementarni pozadinski sistemi iza jednog jedinstvenog interfejsa – tako da aplikacija dobija dinamično izdvajanje činjenica, semantičke grafove znanja, memoriju agenta sa stanjem i bitemporalno rezonovanje *istovremeno*, uz automatsko uklanjanje duplikata i ponovnu rangiranost na osnovu više izvora. Ono što ranije nije bilo praktično – tretirati pitanje „koji memorijski pogon da usvojimo?" kao lažnu dilemu – HelixMemory omogućava da istovremeno iskoristite sve njihove prednosti, iza jednog jednostavnog `MemoryStore`-a, bez nasleđivanja slabosti nijednog pogona ili obaveze na zaključavanje.

## Šta je inovativno

- **Fuzija više pozadinskih sistema** (prikupljanje → uklanjanje duplikata → ponovna rangiranost na osnovu više izvora) koja vraća jedan rangirani skup rezultata, umesto da pozivaoca veže za jedan skladište.
- **Inteligentno usmeravanje upisa** koje klasifikuje svaku memoriju prema sadržaju i šalje je pogonu najpogodnijem za njeno čuvanje, tako da pravi podaci završe u pravom skladištu.
- **Elegantna degradacija** putem prekidača po pojedinačnim pozadinskim sistemima – otkazivanje jednog pogona nije fatalno, već se izoluje, a ostali nastavljaju da rade.
- **Konsolidacija tokom „vremena spavanja"** (putem Letta) koja preuređuje memoriju tokom perioda neaktivnosti, umesto samo u trenutku upita.
- **Provera protiv obmanjivanja**: pokretač izazova nad stvarnim produkcijskim kodom, uparen sa omotačem za mutacije koji mora da otkaže kada se naruši invarijanta – čime se dokazuje da je testna kapija stvarna provera, a ne tautologija.

## Najveći tehnički izazovi i kako smo ih rešili

- **Usklađivanje četiri heterogena pozadinska sistema u jedan koherentan skup rezultata** – svaki pogon vraća memoriju u svom obliku, a njihovo naivno spajanje dovodi do duplikata i neuporedivih rangova. Rešeno pomoću tipizovanog fuzionog pogona koji prikuplja podatke iz više izvora, uklanja preklapanja i sve ponovo rangira na zajedničkoj osnovi, uz tvrdnju o fuzionisanom broju u testovima kako spajanje ne bi tiho izgubilo ili dvostruko računalo rezultate.
- **Održavanje rada kada otkaže pozadinski sistem** – jedan nedostupan memorijski pogon ne sme da zaustavi ceo sloj. Rešeno pomoću prekidača po pojedinačnim pozadinskim sistemima koji prate mašinu stanja zatvoreno → otvoreno (nakon praga otkaza) → poluotvoreno (nakon isteka vremena), izolujući neispravan pogon i nastavljajući da služi iz onih koji rade, sve dok se neispravan ne oporavi.
- **Dokazivanje da memorijska logika zaista funkcioniše, a ne samo da se kompajlira** – zeleni set testova nema smisla ako testovi ne mogu da otkažu. Rešeno pomoću pokretača izazova u procesu koji pokreće stvarni produkcijski kod (usmeravanje, fuziju, prevodilac, prekidač) i uparenog omotača za mutacije koji menja invarijante i zahteva da testovi „pocrvene", čime se dokazuje da kapija nije tautologija.


## Tehnološki stek

- **Go (1.25+)** — jedinstveni SDK i izvršno okruženje; izabran jer paralelno čitanje sa četiri pozadinska sistema predstavlja problem konkurentnosti, a gorutine u Go-u to čine jeftinim, dok njegovi interfejsni tipovi čitavom sistemu pružaju jednu čistu spojnu tačku (`MemoryStore`) na koju se pozivači mogu osloniti.
- **Mem0** — dinamički backend za izdvajanje činjenica i upravljanje preferencijama; koristi se za segment memorije koji odgovara na pitanja „šta ovaj korisnik zapravo preferira / koje su činjenice izronile".
- **Cognee** — semantički backend zasnovan na grafovima znanja, izgrađen na ECL protočnim sistemima; koristi se za čuvanje strukturiranog, povezanog znanja umesto ravnih činjenica.
- **Letta** — backend za izvršno okruženje agenata sa stanjem, sa mogućnošću uređivanja blokova memorije i računanja tokom perioda neaktivnosti; koristi se tamo gde memorija mora da opstane kao živo stanje agenta i da se konsoliduje tokom mirovanja.
- **Graphiti** — backend za dvovremenski graf znanja; koristi se za rasuđivanje o tome kako se činjenice i odnosi menjaju tokom vremena, a ne samo o njihovoj trenutnoj vrednosti.
- **PostgreSQL + Neo4j + Redis** — stvarne podatkovne baze na kojima rade backendovi, postavljene za autentično integraciono testiranje putem `make infra-start`, kako bi testni skupovi koristili stvarnu infrastrukturu umesto simulacija.
- **Prometheus** — metrički podaci i mogućnost posmatranja integrisani kroz fuzioni pipeline, tako da se ponašanje rutiranja i fuzije može meriti u produkciji, a ne ostaje crna kutija.
- **i18n spojni sloj za prevođenje** — imenovani (`helixmemory_`) nizovi znakova zadržani na mestu kako bi svaki budući korisnički interfejs mogao da se lokalizuje bez naknadnog prilagođavanja jezgra.

## Status i napomene o iskrenosti

- **Status: beta.** Funkcionalan SDK; izgrađen kao sloj memorije za HelixAgent.
- **Licenca: nije određena.** Nije pronađena LICENCA putem GitHub API — NEVERIFIKOVANO / nije deklarisano.
- Prikazano ime „HelixMemory" odgovara repozitorijumu `memory`. Navedene vrednosti tačnosti u README fajlu preuzete su od dobavljača, a nisu merene od strane HelixMemory, te su izostavljene ovde.

**Prioritetni nivo:** Helix-osnovni.

