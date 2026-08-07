---
name: HelixConstitution
slug: helixconstitution
tier: helix-primary
order: 19
status: shipped
license: TBD
private: false
tech:
  - Git-submodule inheritance
  - find_constitution.sh (parent-walk + superproject recursion)
  - install_upstreams.sh (multi-provider push)
  - §1.1 mutation meta-tests
  - Propagation gates (CM-COVENANT-114-NNN-PROPAGATION)
  - submodules-catalogue.md
  - Multi-format export (md/html/pdf/docx)
repos:
  - https://github.com/HelixDevelopment/HelixConstitution
  - https://github.com/vasic-digital/HelixConstitution
diagrams:
  - Constitution inheritance layers — a three-tier stack (universal base submodule → project layer → subdirectory overrides) with arrows showing "extend, never weaken."
  - Fleet propagation — one Constitution repo at the centre, submodule links radiating to 140+ consuming repos, each stamped with a green CM-COVENANT-…-PROPAGATION check.
  - Anti-bluff evidence pipeline — code change → four-layer gate (source / build / runtime / mutation) → captured-evidence artefact → PASS, with a "no evidence = bluff = blocker" reject branch.
  - Multi-upstream push topology — a single git push fanning out to GitHub / GitLab / GitFlic / GitVerse.
---

# HelixConstitution

**Univerzalni inženjerski ustav koji svaki projekat nasleđuje — zakon protiv blefiranja, mehanički sproveden, deljen kao jedan Git podmodul.**

## Rezime

HelixConstitution je jedinstven, projektno-agnostičan pravilnik — dodavan kao Git podmodul u svakom Helix/vasic-digital projektu — koji kodira nepregovorljivu inženjersku disciplinu (anti-blefiranje, validacija isključivo na osnovu dokaza, bezbednost podataka i hosta, dokumentacija i pokrivenost testovima) i prenosi je na flotu od preko 140 repozitorijuma. On je upravljačka kičma koja čitavoj porodici daje koherentnost.

## Kratak opis

Univerzalni, nasledivi Constitution isporučen kao Git podmodul. Definiše obavezna, nepregovorljiva pravila — kontrolne tačke protiv blefiranja zasnovane na dokazima, imunitet na lažno pozitivne rezultate, bezbednost podataka i hosta, disciplinu pokrivenosti testovima i dokumentacije — koja svaki projekat koji ga koristi automatski nasleđuje i može da proširi, ali nikada da oslabi.

## Detaljan opis

HelixConstitution je kanonski, jedini izvor istine za inženjerske prakse koje dele svi projekti koji se opredele za njega dodavanjem kao Git podmodula — inženjerski zakon, distribuiran i verzioniran tačno kao kod. Njegov centralni deo — `Constitution.md` — jeste dokument od ~1 MB, neprestano verzioniran, sa numerisanim klauzulama (porodica zaveta §11.4.x, trenutno do §11.4.170) i priručnicima za pojedine agente (`CLAUDE.md`, `AGENTS.md`, `QWEN.md`, `GEMINI.md`), koji ga uvoze referencom tako da ljudi i svaki CLI agent čitaju iz jednog identičnog pravilnika. Nasleđivanje je namerno trostruko: univerzalna osnova (ovaj podmodul), sloj projekta (projektov sopstveni Constitution/CLAUDE/AGENTS koji ga proširuje) i opcioni sloj po poddirektorijumu — evaluiran odozgo nadole, gde projekat može da *pojača* pravila, ali je arhitektonski sprečen da ih *oslabi*. Rezultat je flota od preko 140 repozitorijuma koji ne mogu tiho da se udalje jedni od drugih, jer je disciplina koju dele fiksirana, a ne puko zapamćena.

Dokument je nepopustljivo agnostičan prema domenu: sve što imenuje određenog dobavljača, hardverski SKU, port ili verziju biblioteke mora da se pomeri nadole u sopstveni Constitution projekta koji ga koristi, a univerzalnost se nikada ne podrazumeva — mora da se *zasluži* prolaskom kroz eksplicitni četvorodelni test pre nego što se neko pravilo dopusti u osnovu. Njegov filozofski stub je anti-blefiranje, izražen kao međusobno povezan niz zaveta — §1.1 imunitet na lažno pozitivne rezultate, §11.4 zavet o kvalitetu za krajnjeg korisnika, §11.4.6 zabrana nagađanja, §11.4.69 taksonomija pozitivnih dokaza — čiji kombinovani efekat je jedna jasna crvena linija: standard za isporuku nikada nije „testovi prolaze", već „pravi korisnik može da koristi funkciju", i svaki pozitivan rezultat mora da navede uhvaćene fizičke dokaze ili se ne računa. Prateći `submodules-catalogue.md` (142 repoa) pretvara pitanje „da li već imamo nešto što ovo radi?" u refleks „prvo katalog, pa tek onda proširi, ne implementiraj ponovo" pre nego što se napiše ijedna nova linija koda. Pomoćni skriptovi pronalaze podmodul sa bilo koje dubine ugnežđenosti i rasprostiru svaki komit na četiri nezavisna Git provajdera, tako da je jedini autoritativni pravilnik ujedno i nemoguć za gubljenje.


## Zašto smo ga izgradili

Više velikih aplikacija za proizvode i desetine odvojenih, ponovo upotrebljivih potmodula, koje je kreirao isti vlasnik, stalno su ponovo izvodili iste, mukotrpno stečene pravila — i stalno nailazili na istu vrstu grešaka: testove i izveštaje o statusu koji tvrde da je sve u redu dok je funkcija zapravo neispravna za krajnjeg korisnika („lažni PASS" i „lažni FAIL"). Svaka forenzička referenca u Constitution beleži stvaran incident (npr. lažni PASS rutiranja zvuka D3 od 20. maja 2026, gde je validacija bila zelena uprkos praznom polju „Kodek u upotrebi", ili džinovski UI dugmić od 25. juna 2026. koji je prošao testove jednakosti tokena dok je stvarni ekran bio pokvaren). Constitution postoji da celu ovu klasu nepoštenog uspeha učini mehanički nemogućom — jednom, univerzalno — kako disciplina ne bi klizila između projekata niti bila tiho zaboravljena.

## Zašto je revolucionarno

On pretvara inženjersku kulturu iz dokumentacije-koju-se-nadaju-da-će-pratiti u nasleđeno, verzirano, mehanički nametnuto pravilo — razliku između vodiča za stil i kompajlera. Jedno ažuriranje potmodula istovremeno unapređuje pravila za ceo sistem, atomski i sa mogućnošću praćenja. Jedan anti-lažni zavet je *zagaranotvano* prisutan u svakom repozitorijumu koji ga koristi, ne zahvaljujući poverenju, već konstrukciji: propagacioni mehanizam bukvalno pretražuje klauzulu po broju u celom sistemu, a upareni mutacioni test dokazuje da sam mehanizam ne laže — tako da je čak i nametanje pravila nametnuto. Upravljanje prestaje da bude želja zapisana na vikiju koji niko ne čita i postaje proverljiva, testabilna činjenica na koju možete uputiti CI posao.

## Šta je inovativno

- **Constitution kao potmodul** — inženjerski zakon distribuiran i verziran tačno kao kod, sa namernim oznakama u stilu `v1.0.0` i fiksiranjem verzija po projektu, tako da svaki repozitorijum *tačno* zna koju reviziju zakona mora da poštuje.
- **Anti-laž kao prvoklasna, forenzička doktrina** — svaka klauzula vodi poreklo od bukvalne naredbe operatera, a često i od tačnog incidenta iz stvarnog sveta koji ju je motivisao, tako da zbirka pravila čita kao sudska praksa, a ne kao mišljenje.
- **Meta-testiranje samih pravila (§1.1)** — svaki mehanizam je uparen sa mutacijom koja mora da promeni PASS→FAIL, tako da „mehanizam nije lažan" nije samo tvrdnja, već se dokazuje pri svakom pokretanju; mehanizam koji nikada ne može da zakazuje smatra se gorim od odsustva mehanizma.
- **Zaslužena univerzalnost** — eksplicitan test u četiri dela odlučuje da li je pravilo zaista univerzalno ili samo specifično za projekat, čime se baza održava vitkom, prenosivom i oslobođenom uticaja pojedinih dobavljača.

## Kako se koristi u svim proizvodima (moći koje pruža)

Kao **obavezni stub upravljanja**, HelixConstitution nije dokument koji porodica konsultuje — to je noseća konstrukcija na kojoj je porodica izgrađena:

- **Stub upravljanja:** svaki projekat Helix/vasic-digital dodaje ga kao potmodul i uvozi iz `CLAUDE.md` / `AGENTS.md` / `QWEN.md` / sopstvenog `Constitution.md`; pravila se primenjuju bezuslovno, od prvog komita, bez mogućnosti izuzetka po projektu.
- **Mehanizmi i obaveze:** definiše četvoroslojni model pokrivenosti — prisutan-u-kodu, preživi-kompilaciju, ponaša-se-u-runtime-u, mehanizam-nije-lažan — koji funkcija mora da prođe na sva četiri nivoa pre nego što se smatra završenom, uz rastući spisak imenovanih obaveza: rukovanje akreditivima (§11.4.10), uvek-sinhronizovana dokumentacija (§11.4.60), obaveza potmodula za kontejnere (§11.4.76), CodeGraph (§11.4.78), obavezno pokrivanje tipova testova (§11.4.169) i još mnogo toga.
- **Propagacija:** `CM-COVENANT-114-NNN-PROPAGATION` mehanizmi potvrđuju da je *bukvalan* tekst klauzule prisutan u svim repozitorijumima koji ga koriste, tako da se obaveza ne može tiho izostaviti u nekom delu sistema; neusaglašenost je tvrda blokada izdanja bez mogućnosti zaobilaženja.
- **Otkrivanje:** `submodules-catalogue.md` pretvara pitanje „da li već imamo nešto što radi X?" u odgovor na prvi pogled, pre nego što se bilo koji novi modul inicijalizuje, sprečavajući dupliranje na izvoru.
- **Konzistentnost AI agenata:** isti zakon se identično izražava svakom agentu CLI (Claude Code, Codex/Cursor/Aider/OpenCode/Crush/Kimi preko AGENTS.md, Qwen Code preko QWEN.md), tako da bez obzira koji alat dodirne kod, on poštuje jedan te isti zavet.


## Najveći tehnički izazovi i kako smo ih rešili

- **Lokalizacija podmodula iz proizvoljne ugnježdene dubine** — pravilo zakopano tri podmodula duboko i dalje mora pronaći zakon bez obzira na to gde se nalazi → `find_constitution.sh` penje se kroz roditeljske direktorijume i rekurzivno prati pokazivač git superprojekta, poštujući nadjačavanje `CONSTITUTION_DIR` i dva podržana rasporeda (`constitution/`, `submodules/constitution/`), tako da je razrešenje determinističko bez obzira na dubinu ugnježdenosti.
- **Održavanje jednog repozitorijuma kao autoritativnog na četiri Git provajdera** — ogledala su beskorisna ako se razilaze → `install_upstreams.sh` čita deklarativne `Upstreams/*.sh` udaljene repozitorijume i konfigurise `origin` sa više URL-ova za slanje, tako da jedan `git push` atomski šalje promene na GitHub (primarni), GitLab, GitFlic i GitVerse, a nijedno ogledalo ne može zaostati.
- **Sprečavanje bujanja pravila / curenja projekta u univerzalnu bazu** — svako primamljivo „samo dodaj ovde" narušava prenosivost → primenjuje se četvorodelni test stečene univerzalnosti plus klasifikacija univerzalno-projektno po §11.4.17 na *svako* novo pravilo, što projektno-specifične probleme vraća nazad u projektni sloj gde im je mesto.
- **Dokazivanje da mehanizam nasleđivanja stvarno funkcioniše** — kapija koju nikada ne vidite da otkazuje je kapija kojoj ne možete verovati → `meta_test_inheritance.sh`, meta-test čuvar, namerno briše sidro §11.4 i proverava da li kapija to hvata, tako da se sam mehanizam provere neprestano ponovo verifikuje protiv tihog otkazivanja.

## Tehnološki stek

- **Nasleđivanje Git podmodula** — *zašto:* Git podmoduli su jedini mehanizam koji omogućava da zbirka pravila bude autoritativna *i* verzijski zaključana po potrošaču, nadograđena eksplicitnim, pregledljivim ažuriranjem umesto tihim kopiranjem i lepljenjem; *kako:* projekti koji koriste zbirku dodaju podmodul i `@import`-uju njegove agentske fajlove, a tri sloja se evaluiraju odozgo nadole sa strogim ugovorom „proširuje, ne slabi" na svakoj granici.
- **`find_constitution.sh`** — *zašto:* pravila su beskorisna ako ih duboko ugnježđeni kod ne može pouzdano pronaći, a hardkodiranje puteva bi otkazalo čim bi projekat promenio strukturu; *kako:* penjanje kroz roditeljske direktorijume plus rekurzija `git rev-parse --show-superproject-working-tree`, podržano nadjačavanjem `CONSTITUTION_DIR`, razrešava oba podržana rasporeda.
- **`install_upstreams.sh` + `Upstreams/`** — *zašto:* četvorostruka redundansa je stvarna samo ako ne zahteva dodatni napor za održavanje, inače ogledala propadaju; *kako:* deklarativni `.sh` fajlovi po udaljenom repozitorijumu se materijalizuju u jedan multi-URL `origin`, spajajući četiri slanja u jedno.
- **Meta-testovi mutacija po §1.1** — *zašto:* kapija koja nikada ne otkazuje je gora od nepostojeće jer stvara lažnu sigurnost; *kako:* svaka kapija je uparena sa mutacijom brisanja/preimenovanja koja mora da promeni status iz PROLAZI u PADA, a zatim se vraća u prvobitno stanje, tako da svaka kapija dokazuje da i dalje „ugristi" pri svakom pokretanju.
- **Kapije propagacije (`CM-COVENANT-114-NNN-PROPAGATION`)** — *zašto:* ugovor je univerzalno primenjiv samo ako je proverljivo prisutan u *svakom* potrošaču, a ne samo u vodećem repozitorijumu; *kako:* bukvalna pretraga broja klauzule po potrošačima, podržana uparenim §1.1 meta-testom mutacije koji dokazuje da sama provera propagacije može da otkaže.
- **`submodules-catalogue.md` (§11.4.74)** — *zašto:* najbrži način da se naruši disciplina protiv dupliranja je da ne znate šta već posedujete; *kako:* inventar od 142 repozitorijuma grupisanih po mogućnostima, sa proverom kataloga zabeleženom u tragaču *pre* nego što se išta novo postavi.
- **Izvoz u više formata** — *zašto:* isti zakon mora biti jednako dostupan ljudima koji ga čitaju, alatima koji ga obrađuju i arhivama koje ga čuvaju; *kako:* svaki kanonski dokument se izvozi kao `.md` / `.html` / `.pdf` / `.docx` iz jednog izvora.


## Napomene o statusu i iskrenosti

- **Status: isporučeno.** Aktivno verzionirano i koristi se kao potmodul širom flote (javni kanonski i mirror repozitoriji).
- **Licenca: treba utvrditi** — nije eksplicitno navedena u pregledanom izvornom materijalu; potvrditi prema fajlu LICENSE u repozitorijumu pre objavljivanja.
- Dodatna uzvodna ogledala: GitLab `helixdevelopment1/helixconstitution`, GitFlic `helixdevelopment/helixconstitution`, GitVerse `helixdevelopment/HelixConstitution`.

**Prioritetni nivo:** Helix-primarni — obavezan upravljački stub na kojem počiva izgradnja svega u porodici Helix.

