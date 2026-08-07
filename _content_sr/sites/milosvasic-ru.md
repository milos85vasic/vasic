---
site: milosvasic.ru
type: personal-site
title: Miloš Vasić — AI Engineer
tagline: I build AI development systems — and the discipline that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Miloš Vasić

## Heroj

**AI inženjer koji gradi verifikovane sisteme za razvoj AI.**

Ja gradim onaj deo AI inženjeringa koji razdvaja pouzdan proizvod od impresivne demonstracije: LLM infrastrukturu sa više provajdera koja preživljava pad nekog od njih, autonomne agente i orkestraciju koji održavaju posao na pravom putu, kao i slojeve upravljanja i kontrole kvaliteta koji sprečavaju da AI sistem tiho laže o svojim mogućnostima. Pretvaranje velikog jezičkog modela u nešto što se stvarno može isporučiti uglavnom je problem discipline, a ta disciplina je ono u čemu se ja specijalizujem. Moj severnjača je jednostavno pravilo — funkcija je gotova tek kada je stvarni korisnik može da koristi i kada postoji prikupljen dokaz koji to potvrđuje.

## Pregled

Pretežno radim u **Go**, sa **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift** i **Shell**, u zavisnosti od zahteva posla. Ono što mi je najvažnije jeste kako je posao *strukturiran*: ne gomila jednokratnih aplikacija, već flota — velike aplikacije koje se oslanjaju na desetine malih, odvojenih i nezavisno testiranih modula, a svi nasleđuju zajednički inženjerski **Constitution** kao Git podmodul. To jedino arhitektonsko rešenje omogućava da ceo korpus rada bude kumulativan: ispravke i poboljšanja se odmah šire na sve, novi proizvodi se sklapaju od delova koji su već dokazani, a svaka reklamirana mogućnost ima test koji proizvodi dokaze, umesto pukog tvrdjenja. To je inženjering stvoren da bude pouzdan u velikim razmerama, a da ga gradi jedna osoba. Ova stranica polazi od tog pregleda i spušta se do pojedinačnih projekata; svaki vodi do svoje pune stranice proizvoda.

## Kako radim — upravljanje i kontrola kvaliteta na prvom mestu

Pre proizvoda, disciplina koja ih podupire:

- **HelixConstitution** — održavam univerzalni, nasledivi inženjerski pravilnik, distribuiran kao Git podmodul preko flote od preko 140 repozitorijuma. On kodifikuje kontrolne tačke protiv obmanjivanja, imunitet na lažno pozitivne rezultate, bezbednost podataka i hostova, kao i pravila pokrivenosti; projekti mogu da ga pooštravaju, ali nikada ne smeju da ga oslabe, a svaka kontrolna tačka upravljanja uparena je sa mutacionim testom koji dokazuje da sama ta tačka funkcioniše. → pogledajte stranicu proizvoda HelixConstitution.
- **HelixQA** — gradim orkestraciju kontrole kvaliteta protiv obmanjivanja koja pokreće pisane testove i potpuno autonomne sesije kontrole kvaliteta vođene LLM i vizijom na Androidu, Android TV-u, vebu i desktopu, a prolazak se boduje samo kada je prikupljen dokaz o radu u realnom vremenu. → pogledajte stranicu proizvoda HelixQA.

## Moj rad u okviru porodice Helix

Linija Helix obuhvata ceo životni ciklus razvoja AI. Po prioritetu:

- **HelixTrack** — alternativa JIRA u slobodnom svetu; vodeći proizvod linije Helix-Track.
- **HelixAgent** — ansambl LLM servisa sa višestrukim debatom modela i verifikacionim izborom provajdera.
- **HelixCode** — distribuirana platforma za razvoj AI koja deli posao na radnike kojima upravlja SSH sa automatskim čuvanjem stanja i vraćanjem na prethodnu verziju.
- **HelixLLM** — jedan binarni fajl sa šest režima koji služi OpenAI- i Anthropic-kompatibilnim API-jima preko HTTP/3, sa lokalnom inferencijom llama.cpp i ocenjenim lancem rezervnih rešenja.
- **HelixCluster** — distribuirani operativni sistem za AI računanje, od GPU-a u podatkovnim centrima do ručnih uređaja na ivici mreže.
- **LLMProvider** — jedan interfejs za 43 provajdera sa ugrađenim prekidačima kola, ponovnim pokušajima i monitoringom zdravlja.
- **LLMOrchestrator** — jedna kontrolna ravan za sve bezglave CLI kodirajuće agente.
- **LLMsVerifier** — verifikuj, prati, optimizuj: jedini izvor istine za LLM/provajder/verifikacione metapodatke.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** — memorija agenata, kontrolisane veštine agenata, razvoj vođen specifikacijama, izgradnja AI aplikacija, verifikovan prevod knjiga, terminali sa nultim poverenjem, federisani Git, ažuriranja OTA bez rizika od oštećenja i samostalni cloud gaming.


## Moj rad na alatima iz okvira vasic-digital

Alati profesionalnog nivoa koje sam razvio i održavam (svaki ima kompletnu stranicu proizvoda):

- **Catalogizer** — višenamenski protokol (SMB/FTP/NFS/WebDAV/lokalno), enkriptovan, samostalno hostovan sistem za upravljanje medijskim kolekcijama sa Go/Gin API i React korisničkim interfejsom.
- **Courses-Creator** — tok za kreiranje video-kurseva iz Markdown formata sa višestrukim LLM obogaćivanjem, TTS i plejerima za desktop, mobilne i veb platforme.
- **VisionEngine** — odvojeni Go alat za spajanje klasičnog računarskog vida sa višepružavačkim LLM vidom za analizu korisničkog interfejsa i navigacione grafove.
- **DocProcessor** — pretvara dokumentaciju u proverljivu mapu funkcionalnosti za automatizaciju QA (LLM ili heurističko izdvajanje).
- **Docs Chain** — sistem za sinhornizaciju dokumenata/baza podataka sa sadržajnim heširanjem, dvosmernom i atomskom sinhronizacijom.
- **Herald** — pouzdane obaveštenja kroz više kanala sa razumevanjem prirodnog jezika i trostepenom rezolucijom namere.
- **task_bridge** — odvojeni, dvosmerni sistem za sinhronizaciju zadataka/tabli (P1 okvir; logika sinhronizacije u razvoju).
- **Vasic Digital Paket ponovljivo upotrebljivih modula** — „standardna biblioteka" `digital.vasic.*` infrastrukturnih, AI-primitivnih i zaštitnih modula.

## Nasleđe infrastrukture (Server Factory)

Pre AI linije, moj DevOps lanac alata: **Mail Server Factory** (deklarativni JSON → potpuno opskrbljeni Dockerizovani mejl serveri, sa 439 uspešno položenih testova i čistom SonarQube proverom), **Server Factory Osnovni okvir** na kojem se gradi, kao i alati za VM slike (**Qemu-Utils**, **Parallels-Utils**) uz prateće fabrike servisa.

## U jednoj rečenici

Ne isporučujem zelene kvačice — isporučujem AI sisteme sa dokazima da stvarno rade, i upravljačke mehanizme koji ih takvima i održavaju.

## Kontakt

Otvoren za pozicije višeg nivoa u oblasti AI/platform inženjeringa širom sveta.

- **Mejl:** [milos85vasic@gmail.com](mailto:milos85vasic@gmail.com) · [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [milos85vasic](https://github.com/milos85vasic)
- **Telegram:** [@milos85vasic](https://t.me/milos85vasic)

