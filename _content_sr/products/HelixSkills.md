---
name: HelixSkills
slug: helixskills
tier: helix-primary
order: 5
status: beta
license: Apache-2.0
private: false
tech:
  - Shell
  - Git submodules
  - Model Context Protocol
  - Claude Code plugins
  - Reusable engines (continuum, token_optimizer)
repos:
  - https://github.com/HelixDevelopment/skills
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Governance-inheritance diagram — HelixSkills mounting the Constitution submodule, with universal rules cascading to every registered skill and consuming agent.
  - Skill catalog map — the 7 constitution skills + 4 draft skills grouped by domain/complexity, feeding the auto-generated skill-graph index.
  - Multi-surface exposure — one skill set reaching agents through MCP tool servers and Claude Code plugins.
  - Engine/dependency graph — token_optimizer and the other depth-1 engines with their cross-repo dependencies (TOON, Embeddings, VectorDB, Normalize, conversation, LLMProvider).
---

# HelixSkills

**Regulisan, ustavno zasnovan sistem veština za agente CLI AI.**

## Sažetak

HelixSkills je sistem veština za agente CLI AI koji nasleđuje Helix Constitution kao podmodul, tako da se svako univerzalno pravilo upravljanja primenjuje bezuslovno. Obuhvata instalabilne veštine agenata, MCP serverske alate, Claude dodatke za Code i ponovo upotrebljive motore iza registrovane, dokumentovane kataloga.

## Kratak opis

HelixSkills je sistem veština za agente CLI AI. Ugrađuje Helix Constitution kao podmodul kako bi sva univerzalna pravila bila na snazi, a zatim isporučuje registrovane veštine (akcioni prefiks, validator medija, multitrak, sinhronizaciju sesija, životni ciklus radnih jedinica i još mnogo toga), dva MCP serverska alata, dva Claude dodatka za Code i ponovo upotrebljive motore.

## Detaljan opis

HelixSkills (repozitorijum `skills`, Apache-2.0) je sistem veština za agente CLI AI, a počinje od namernog obrnutog pristupa uobičajenom redosledu: upravljanje dolazi pre mogućnosti. Nasleđuje Helix Constitution kao svoj `constitution/` podmodul, tako da se svako univerzalno pravilo iz `constitution/CLAUDE.md` i `constitution/Constitution.md` primenjuje bezuslovno — ne kao konvencija koju agent može poštovati, već kao skup pravila fizički ugrađenih u strukturu projekta. Agent koji usvoji HelixSkills ne može se odreći ustava; pravila putuju zajedno sa kodom.

Dok većina „okvira za veštine" trguje apstrakcijama, HelixSkills isporučuje konkretan, registrovani inventar na koji možete ukazati i instalirati ga. Sedam ustavnih veština instalira se preko `register.sh`: action-prefix-system, media-validator, multitrack, reporting-workable-items, scheduled-work-queue, session-sync i workable-item-lifecycle — spektar ocenjen od srednjeg do naprednog nivoa, koji pokriva sve od disciplinovanog imenovanja akcija do validacije medija i punog životnog ciklusa radne jedinice. Dodatne veštine u razvoju (Android pregled, Java/Kotlin jezik, Linux OS) već su indeksirane i pripremljene za aktivaciju. Dva MCP serverska alata (media-validator, scheduled-work) izlažu te veštine agentima preko Model Context Protocol, dok dva Claude dodatka za Code (helix, scheduled-work) ubacuju iste mogućnosti direktno u radno okruženje agenta — jedan skup veština, dostupan agentima bez obzira na to kojim interfejsom komuniciraju.

Ispod kataloga nalaze se četiri ponovo upotrebljiva motora prvog nivoa — continuum (implementiran), plus session_orchestrator, token_optimizer i clickup_sync (u fazi dizajna) — zajednička infrastruktura koja sprečava da veštine ponovo izmišljaju istu osnovnu logiku. Samo token_optimizer deklariše eksplicitan graf zavisnosti koji se proteže do paketa ekosistema vasic-digital (TOON, Embeddings, VectorDB, Normalize, conversation) i HelixDevelopment-ovog LLMProvider, tako da je umrežavanje između repozitorijuma proverljivo, a ne implicitno. Oko svega toga funkcioniše disciplinovana dokumentacija: katalog veština, automatski generisan indeks grafa veština, detaljne stranice po repozitorijumima i otvoren registar Nedostataka i rizika koji jasno navodi šta još nije urađeno. Ceo sistem je ogledalo na GitHub, GitLab, GitFlic i GitVerse radi otpornosti i regionalnog pristupa.


## Zašto smo ga izgradili

Agentima CLI i AI potrebne su mogućnosti koje su dosledne, regulisane i ponovo upotrebljive – a ne ad hok skripte koje svaka iznova izmišljaju pravila. HelixSkills je stvoren da agentima pruži paket registrovivih veština vezanih za zajednički ustav, kako bi ponašanje ostalo dosledno i proverljivo u svakom agentu i projektu koji ga usvoje.

## Zašto je revolucionarno

Omogućava da sposobnosti agenta budu prenosive i usklađene s pravilima *po samoj konstrukciji*, a ne zahvaljujući disciplini. Svaka veština je regulisana, verzionirana i instalabilna jedinica podržana ustavnim podmodulom – tako da u trenutku kada agent registruje veštinu, istovremeno nasleđuje i kanonski skup pravila, bez mogućnosti odstupanja. To otključava nešto što ranije nije bilo praktično: prenošenje sposobnosti s jednog agenta ili projekta na drugi uz uverenje da ona stiže već vezana za istu upravu, izložena preko standardnih interfejsa (MCP serveri i Claude Code dodaci) umesto hrpe prilagođenih skripti koje svaka iznova definišu pravila.

## Šta je inovativno

- **Constitution kao podmodul**: univerzalna upravljačka pravila se nasleđuju, a ne kopiraju – montiraju se u stablo tako da svaki agent koji ih koristi bude vezan za isti kanonski skup pravila, s ažuriranjima koja dolaze iz jednog izvora istine umesto iz desetak zastarelih kopija.
- Veštine isporučene kao samoregistrujuće jedinice (`register.sh`) i uvezane u automatski generisan indeks grafova veština, tako da katalog ostaje otkrljiv i nikada ne izlazi iz sinhronizacije s onim što je zapravo instalirano.
- Izlaganje na više interfejsa: isti skup veština dolazi do agenata preko MCP alata-servera *i* Claude Code dodataka – piše se jednom, a koristi se u bilo kom okruženju koje agent koristi.
- Ponovo upotrebljivi motori prvog nivoa (continuum, token_optimizer, session_orchestrator, clickup_sync) deljeni širom ekosistema, od kojih svaki nosi eksplicitne, proverljive deklaracije međuzavisnosti umesto skrivenog sprezanja.

## Najveći tehnički izazovi i kako smo ih rešili

- **Održavanje doslednog i usklađenog ponašanja agenata kroz mnoge veštine i agente** – ponovna implementacija upravljanja po veštini garantuje odstupanje tokom vremena. Rešeno montiranjem Helix Constitution kao podmodula, tako da pravila u `constitution/CLAUDE.md` i `constitution/Constitution.md` važe bezuslovno i ažuriraju se iz jednog izvora, umesto da se kopiraju i ostave da zastare.
- **Omogućavanje instalacije i otkrivanja rastućeg skupa veština** – katalog je beskoristan ako niko ne može da pronađe ili instalira ono što se u njemu nalazi. Rešeno registracijom po veštini pomoću `register.sh`, koja povezuje svaku veštinu pri instalaciji, uz automatski generisan INDEX graf veština i detaljnu dokumentaciju po repozitorijumu, tako da otkrivanje prati stvarnost u realnom vremenu.
- **Dostizanje agenata koji koriste različita okruženja** – ista sposobnost ne bi trebalo da se ponovo gradi za svaki host. Rešeno pakovanjem jednog skupa veština iza definicija MCP alata-servera (u `constitution/mcp/`) i Claude Code dodataka (u `constitution/plugins/`), tako da se jedna implementacija izlaže na svim interfejsima.


## Tehnološki stek

- **Shell (primarni jezik)** — izabran jer alati za instalaciju i registraciju moraju da rade na svakom mestu gde postoji agent, bez potrebe za prethodnim pokretanjem runtime-a; pokreće `register.sh` i `install_upstreams`, čime se ulazna tačka održava bez zavisnosti i prenosivom.
- **Git podmoduli** — izabrani kako bi se nasleđivalo upravljanje bez dupliciranja: Helix Constitution je montiran na `constitution/` kao aktivna referenca, pa se ažuriranja pravila šire preko jednog pokazivača umesto da se kopiraju i zaborave.
- **Model Context Protocol (MCP)** — izabran kao standardni, runtime-agnostički interfejs alata za agente; dva MCP servera (media-validator, scheduled-work) definisana su pod `constitution/mcp/` kako bi veštine bile dostupne kao pozivi alata.
- **Claude Code pluginovi** — izabrani da bi se veštine direktno ubacile u runtime agenta bez dodatnog koda; dva plugina (helix, scheduled-work) isporučuju se pod `constitution/plugins/`, odražavajući MCP površinu za drugi host.
- **Ponovo upotrebljivi motori (continuum, token_optimizer, session_orchestrator, clickup_sync)** — izabrani da bi se zajednička mehanika izdvojila iz pojedinačnih veština za ponovnu upotrebu u različitim projektima; token_optimizer, na primer, povezan je sa paketima vasic-digital (TOON, Embeddings, VectorDB, Normalize, conversation) i HelixDevelopment-ovim LLMProvider preko deklarisanih zavisnosti umesto dupliciranog koda.
- **Git ogledalo na više hostova (GitHub, GitLab, GitFlic, GitVerse)** — izabrano kako bi otkaz jednog hosta ili regionalna blokada nisu mogli da prekinu pristup; isti repozitorijum održava se aktivnim na četiri platforme radi otpornosti i dostupnosti.

## Status i napomene o iskrenosti

- **Status: beta.** Sedam ustavnih veština, dva MCP servera i dva plugina isporučeni su; nacrtane veštine su indeksirane i čekaju aktivaciju, a tri od četiri motora prvog nivoa (session_orchestrator, token_optimizer, clickup_sync) još uvek su u fazi dizajna.
- U README fajlu projekat se naziva `helix_skills`; kanonski GitHub put je `HelixDevelopment/skills`. Broj pronađenih nalaza u README fajlu je samoprijavljena cifra.

**Prioritetni nivo:** Helix-primary.

