---
name: HelixQA
slug: helixqa
tier: helix-primary
order: 20
status: beta
license: Apache-2.0
private: false
tech:
  - Go 1.24+
  - YAML test banks (pkg/testbank)
  - Crash/ANR detectors (ADB, pgrep)
  - Evidence collection (screenshots/logcat/video/stack traces)
  - Autonomous session (LLM + computer vision)
  - LLMsVerifier
  - LLMOrchestrator
  - VisionEngine (GoCV + LLM Vision)
  - DocProcessor
  - Anti-bluff gates + mutation ratchet
repos:
  - https://github.com/HelixDevelopment/helixqa
  - https://github.com/vasic-digital/HelixQA
diagrams:
  - Autonomous QA-session loop — the 4 phases (Setup → Doc-Driven Verification → Curiosity-Driven Exploration → Report & Cleanup) as a cycle, with evidence artefacts dropping out at each step.
  - Anti-bluff evidence pipeline — test step → detector + vision oracle → captured evidence (screenshot/logcat/video/stack trace) → PASS, with a "no evidence → critical defect" reject branch.
  - Cross-platform navigator — one orchestrator fanning to ADB (Android/TV), Playwright (Web), X11 (Desktop) action executors.
  - Constitution → HelixQA governance — §11.4.169's 13 mandatory test types with helix_qa highlighted as the QA pillar, feeding the 15-row coverage matrix.
---

# HelixQA

**Anti-bluff orkestracija QA testa — autonomne, cross-platform sesije u kojima svako USPEŠNO izvršenje nosi prikupljene dokaze da stvarni korisnik može da koristi funkcionalnost.**

## Sažetak

HelixQA je anti-bluff okvir za orkestraciju QA testa na više platformi (Android, Android TV, Web, Desktop) koji kombinuje YAML banke testova, detekciju pada u realnom vremenu, prikupljanje dokaza korak po korak i LLM-plus-računarski-vidom vođene autonomne QA sesije kako bi dokazao da funkcionalnosti zaista rade od početka do kraja. Predstavlja obavezni tip QA testa prema Constitution (§11.4.169).

## Kratak opis

Anti-bluff QA orkestrator (Go) koji pokreće napisane banke testova i potpuno autonomne, LLM-i-računarskim-vidom vođene QA sesije na različitim platformama — otkriva padove, validira svaki korak u odnosu na prikupljene dokaze (snimke ekrana, logcat, video, stack trace), i automatski generiše tikete bogate dokazima za AI pipeline popravki.

## Detaljan opis

HelixQA je Go okvir čiji jedini, nepopustljivi dizajnerski centar predstavlja §11.4 Operativno pravilo Constitution: kriterijum za isporuku nije „testovi prolaze", već „korisnici mogu da koriste funkcionalnost", pa svako USPEŠNO izvršenje koje emituje mora da nosi pozitivne dokaze prikupljene tokom izvršavanja — bez dokaza, nema zelenog svetla, bez izuzetaka. Radi u dva komplementarna moda koji zajedno pokrivaju i pisane i nepoznate scenarije. Prvo, **pisane banke testova** — YAML paketi `TC-XXX` slučajeva sa ciljanjem na platformu, prioritetima, uređenim koracima (naziv/akcija/očekivano), oznakama i referencama na dokumentaciju — izvršavaju se uz validaciju svakog koraka, detekciju pada/ANR-a u realnom vremenu (ADB za Android, praćenje procesa za web/desktop), centralizovano prikupljanje dokaza i automatski generisane Markdown tikete već prilagođene za downstream AI pipeline popravki. Drugo, **potpuno autonomna QA sesija** koja aplikaciju predaje agentima pokretanim LLM i računarskim vidom i pušta ih da je samostalno kontrolišu kroz četiri disciplinovane faze: podešavanje (izbor LLM-ova, izrada mape funkcionalnosti iz projektnog dokumenta, pokretanje CLI agenata, inicijalizacija motora za vizuelnu analizu), verifikacija vođena dokumentacijom koja prolazi kroz svaku dokumentovanu funkcionalnost, istraživanje vođeno radoznalošću koje namerno testira granične slučajeve i nedokumentovano ponašanje, a zatim izveštavanje i čišćenje u Markdown/HTML/JSON formatu, pri čemu je svaki nalaz povezan sa dokazima označenim vremenskim pečatom u video-zapisu.

Ključno je da ovaj okvir ne ocenjuje sam sebe: integriše četiri spoljna Go potmodula (LLMsVerifier, LLMOrchestrator, VisionEngine, DocProcessor) i koristi zajedničku infrastrukturu `challenges` i `containers`, tako da komponenta koja navigira aplikacijom nije ista kao ona koja ocenjuje da li je sve prošlo kako treba. Njegov sopstveni paket testova podvrgava se istom standardu koji nameće drugima putem `make anti-bluff` (statičko skeniranje + manifest sidrenih ponašanja + mutacioni zupčanik) i Challenge orkestracije u 8 faza sa ugrađenom §1.1 mutacijom. Matrica pokrivenosti tipova testova od 15 redova precizno povezuje svaku reklamiranu mogućnost sa konkretnim izvršnim sredstvom i specifičnim oblikom prikupljenih dokaza — tako da tvrdnje okvira o samom sebi imaju isto toliko dokaza koliko i presude koje donosi za proizvode koje testira.


## Zašto smo ga izgradili

Konvencionalni QA daje zeleno svetlo uz obrazloženje „asertacija je prošla", što je upravo način na koji klasa grešaka koju Constitution naziva *blefiranjem* prolazi kroz sistem — funkcija je prijavljena kao funkcionalna, iako je za krajnjeg korisnika neispravna. HelixQA je izgrađen upravo da to spreči u okviru QA procesa: on odbija da dodeli status PROŠAO bez fizičkog dokaza (snimka ekrana, logcat, video, stek trejs, izveštaj) snimljenog tokom stvarnog izvršavanja, a zeleni rezime bez takvog dokaza tretira kao kritičnu grešku ravnu nedostajućoj funkciji. Takođe rešava problem radne snage — sveobuhvatno ručno testiranje na više platformi nije skalabilno — omogućavajući potpuno autonomne sesije.

## Zašto je revolucionarno

Spaja dve stvari koje gotovo nikada nisu deo istog alata: rigoroznu, dokazima potkrepljenu kontrolu kvaliteta i autonomno, samostalno istraživanje. Agent LLM sa vizuelnim modulom otvara *stvarnu* aplikaciju, proverava svaku dokumentovanu funkciju, traga za nedokumentovanim bagovima za koje niko nije napisao test, *i* istovremeno generiše dokazni materijal sudskog kvaliteta — tako da se „testirali smo to" zamenjuje sa „evo snimka, evo logcat-a, evo tiketa". A pošto je deo QA podsistema nazvanog po Constitution, njegovo usvajanje ne unapređuje poštenje QA procesa samo za jedan tim — već podiže standard za svaki proizvod u porodici u jednom potezu.

## Šta je inovativno

- **Ugovor o nedokazivom blefu** — svaki PROŠAO status je vezan za snimljeni dokaz tokom izvršavanja; zelena linija u CI-u smatra se neophodnom, ali nikada dovoljnom, a zeleni rezime bez dokaza ocenjuje se kao kritična greška.
- **Autonomno istraživanje vođeno dokumentacijom i radoznalošću** — proverava svaku dokumentovanu funkciju *i* zatim skreće sa scenarija, istražujući rubne slučajeve na koje nailaze stvarni korisnici (prazni unosi, brze interakcije, nedokumentovani putevi) koje nijedan ručno napisan set testova nije predvideo.
- **Vizuelni orakul** — mehanički vid zasnovan na GoCV-u i LLM Vision API bukvalno *vidi* pokrenuti UI na ekranu, otkrivajući vizuelno oštećena stanja koja promiču pored asertacija na nivou tokena i svojstava.
- **Strukturne, a ne prozne baze testova** — stringovi u bazi opisuju strukturu i generišu pitanja za LLM tokom izvršavanja (CONST-046), tako da jedna baza funkcioniše na svim lokalizacijama umesto da se raspadne čim se UI tekst prevede.
- **Tiketi prilagođeni AI protoku popravki** — automatski generisani Markdown tiketi stižu sa kompletnim paketom dokaza, spremni za direktno prosleđivanje agentu za popravke umesto ljudskom trijažeru.

## Kako se koristi u svim proizvodima (moći koje pruža)

Kao **obavezni stub kvaliteta** (Constitution §11.4.169 navodi `helix_qa` podsistem kao jedan od obaveznih tipova testova), HelixQA svim proizvodima u porodici pruža isti skup mogućnosti:

- **Autonomne QA sesije:** jedna naredba `helixqa autonomous --project … --platforms android,desktop,web` pušta agenta LLM sa vizuelnim modulom da samostalno testira stvarne aplikacije prema cilju pokrivenosti, generišući izveštaje, tikete i snimke bez ljudske intervencije.
- **Baze testova / setovi:** baze YAML (nivo 219 sa minimalno 30 testova), ciljane na platforme, rangirane po prioritetu i povezane red po red sa dokumentacijom koju proveravaju.
- **Snimljeni dokazi:** snimci ekrana, logcat, video, stek trejsovi i kompletna vremenska linija — centralizovani i povezani sa svakim izveštajem, tako da se svaka odluka može reprodukovati i revidirati naknadno.
- **Nezavisne presude (§11.4.141 princip nezavisnosti):** njegov `issuedetector` i vizuelni orakul na bazi LLM ocenjuju ponašanje pokrenute aplikacije nezavisno od agenta koji ju je navigirao, čime se strukturno eliminiše klasična greška u kojoj sistem sam sebe proglašava ispravnim.
- **Kontrola i mutacioni mehanizam:** `make qa-all` / `make anti-bluff` i `challenges/scripts/helixqa_orchestrator_challenge.sh` (8 faza, ugrađena §1.1 mutacija) neprestano proveravaju poštenje samog HelixQA — i namerno ne postoji `--skip-helixqa` prečica kojom bi se disciplina mogla isključiti pod pritiskom rokova.


## Najveći tehnički izazovi i kako smo ih rešili

- **Sprečavanje lažno pozitivnih rezultata u samom QA procesu** — alat koji otkriva blefove ne sme sam postati jedan → svaki korak se validira na osnovu prikupljenih dokaza, prolaz bez dokaza ocenjuje se kao greška, a ne kao prolaz, a manifest ponašajnih sidrišta povezuje svaku reklamiranu funkcionalnost sa izvršnim testom (CONST-035), tako da se nijedna funkcija ne može tvrditi bez nečega što je proverava.
- **Upravljanje heterogenim platformama iz jednog centra** — Android, Android TV, Web i Desktop nemaju zajednički model unosa → jedan paket `navigator` apstrahuje platformski specifične ActionExecutors (ADB, Playwright, X11) i detektore padova za svaku platformu (android/web/desktop), tako da se logika orkestracije piše jednom, a razlike između platformi ostaju na ivicama sistema.
- **Korišćenje autonomnih agenata na koristan, a ne haotičan način** — neregulisani LLM u aplikaciji može besciljno lutati večito → LLMsVerifier ocenjuje i bira odgovarajuće modele, LLMOrchestrator upravlja headless CLI agentima (opencode, claude-code, gemini, junie, qwen-code), DocProcessor gradi mapu funkcionalnosti koja istraživanju daje cilj, a VisionEngine svaku odluku zasniva na stvarnim pikselima na ekranu, a ne na mašti modela.
- **Baze testova bezbedne za lokalizaciju** — paket koji hardkodira engleski tekst korisničkog interfejsa otkazuje u petnaest jezika → baze opisuju samo strukturu, a tekst korisničkog upita se učitava dinamički putem LLM/resursa tokom izvršavanja (CONST-046), tako da ista baza proverava isto ponašanje bez obzira na lokalizaciju.
- **Dokazivanje da kontrolni mehanizmi nisu lažni** — anti-blef kontrola koja sama ne može da otkaže predstavlja vrhunski blef → upareni §1.1 mutanti uklanjaju prikupljanje dokaza ili anti-blef tvrdnju iz tipa i zahtevaju da kontrola OTKAŽE, a mehanizam za postepeno povećanje zahteva sprečava da se ta garancija vremenom neprimetno naruši.

## Tehnološki stek

- **Go 1.24+ orkestrator** — *zašto:* QA mora da radi svuda gde rade i proizvodi, pa jedan statički povezan, brz i prenosiv binarni fajl pobeđuje alternative koje zahtevaju runtime; *kako:* jedan `cmd/helixqa` CLI koji izlaže kompozitne potkomande `run` / `list` / `report` / `autonomous` / `version`.
- **Baze testova YAML (`pkg/testbank`)** — *zašto:* paketi testova treba da budu deklarativni i čitljivi, menjivi od strane ljudi bez dodirivanja Go; *kako:* `version`/`name`/`test_cases[]` sa `id`, `category`, `priority`, `platforms`, uređenim nizom `steps[]` i `documentation_refs[]` za povratno praćenje do dokumentacije funkcionalnosti.
- **Detektori padova/ANR-a (`pkg/detector`)** — *zašto:* najvažnije greške su one koje se dešavaju uživo, tokom interakcije, a ne u naknadnoj proveri; *kako:* ADB (`pidof`/`logcat`/`screencap`) za Android i `pgrep` za web/desktop, koji prate proces dok ga test pokreće.
- **Prikupljanje dokaza (`pkg/evidence`, `pkg/session`)** — *zašto:* ugovor o anti-blefu je stvaran samo ako je svaki PROLAZ podržan fizičkim dokazom; *kako:* snimci ekrana, logcat, video i stack trace-ovi se prikupljaju u vremensku liniju `SessionRecorder`, na koju svaki izveštaj upućuje.
- **Autonomna sesija (`pkg/autonomous`, `pkg/navigator`, `pkg/issuedetector`)** — *zašto:* sveobuhvatno ručno QA testiranje na četiri platforme ne može da se skalira, pa istraživanje mora da bude samostalno; *kako:* 4-fazni `SessionCoordinator` plus ActionExecutors (ADB/Playwright/X11) i LLM detekcija grešaka koja obuhvata vizuelne, UX, pristupačne i funkcionalne nedostatke.
- **Spoljašnji potmoduli** — *zašto:* ponovna upotreba i razdvajanje (CONST-051), a — ključno — razdvajanje navigatora od suca; *kako:* LLMsVerifier (ocenjivanje modela), LLMOrchestrator (headless CLI agenti), VisionEngine (GoCV + LLM Vision), DocProcessor (mapa funkcionalnosti/pokrivenost), svaki kao nezavisno vođena komponenta.
- **Anti-blef kontrole + mehanizam postepenog povećanja zahteva** — *zašto:* da se HelixQA drži tačno onog §1.1 sporazuma koji nameće svemu ostalom; *kako:* skeniranje `make anti-bluff` plus manifest ponašajnih sidrišta i mehanizam postepenog povećanja zahteva, sa `helixqa_orchestrator_challenge.sh` kao 8-faznim validatorom od kraja do kraja.
- **Matrica pokrivenosti od 15 redova (`docs/test-coverage.md`)** — *zašto:* CONST-050(B) zahteva zatvoren, potpuno obračunat skup tipova testova bez praznina; *kako:* svaki red je vezan za konkretan izvršni resurs i specifičan oblik prikupljenih dokaza, tako da je pokrivenost proverena činjenica, a ne samo tvrdnja.


## Napomene o statusu i iskrenosti

- **Status: beta.** Aktivno u razvoju (README statusna traka, verzija 219). Podvrgava se sopstvenom standardu protiv obmane.
- **Licenca: Apache-2.0.** Instalacija: `go install digital.vasic.helixqa/cmd/helixqa@latest`.

**Prioritetni nivo:** Helix-osnovni — obavezni stub kvaliteta/protiv obmane u okviru porodice Helix, kojim se proverava da funkcije zaista rade.

