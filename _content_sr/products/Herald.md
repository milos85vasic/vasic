---
name: Herald
slug: herald
tier: vasic-util-secondary
order: 27
status: active (early production consumer of Docs Chain)
license: UNVERIFIED
private: false
tech:
  - Go
  - Shell
  - Claude Code (LLM intent inference)
  - Messenger channel adapters
  - Docs Chain
  - Helix Constitution submodule
repos:
  - https://github.com/vasic-digital/Herald
diagrams:
  - Fan-out topology (event source → Herald → many channels)
  - Three-tier intent ladder (command → LLM inference → clarify)
  - Attribution flow (message → participant contract → created_by/assigned_to + @-tag)
  - Docs Chain integration for Herald's doc corpus
---

**Svaka uzbuna stiže na pravo odredište — bez potrebe za sintaksom komandi.**

## Rezime

Herald prihvata sistemske događaje i pouzdano ih distribuira na više kanala za obaveštavanje, tako da svaka uzbuna stiže na pravo mesto. Pretplatnici komuniciraju na prirodnom jeziku; Herald razrešava namere kroz trostepenu disciplinu (brzi put komandi → zaključivanje namere preko LLM → rezervni mehanizam za razjašnjavanje).

## Kratak opis

Sistem za prihvatanje događaja i distribuciju obaveštenja na više kanala. Herald pouzdano usmerava sistemske događaje na prava odredišta preko kanala za razmenu poruka i omogućava pretplatnicima da koriste običan prirodni jezik — razrešavajući namere kroz brzi put komandi, zaključivanje putem LLM i rezervni mehanizam za razjašnjavanje i pitanja.

## Detaljan opis

Herald je okosnica obaveštavanja koja garantuje da sistemski događaj zaista stigne tamo gde ga čovek može preduzeti — neugledan, ali ključan sloj u kojem većina improvizovanih sistema za uzbunjivanje tiho otkazuje. Prihvata događaje i pouzdano ih distribuira na više kanala za obaveštavanje, sprečavajući uobičajene greške gde se uzbuna izgubi, pogrešno usmeri na mrtav kanal ili zaguši u buci dok više nije bitno. Ali pouzdana isporuka je samo pola priče; druga polovina odnosi se na to šta se dešava kada čovek želi da reaguje. Ovde Herald odbija uobičajeni kompromis gde korisnici moraju da pamte krutu sintaksu komandi kako bi komunicirali sa botom za uzbunjivanje. Pretplatnici jednostavno pišu na običnom prirodnom jeziku, a Herald razrešava šta su mislili kroz namernu trostepenu disciplinu: brzi put koji odmah prepoznaje eksplicitne komande, zatim zaključivanje namere zasnovano na LLM (putem Claude koda) za poruke u slobodnom obliku, i na kraju rezervni mehanizam `razjašnjenja` koji odgovara, označava i postavlja pitanje kada je namera zaista nejasna. Ta lestvica „prepoznaj → zaključi → razjasni" ukratko je čitava filozofija dizajna — uobičajeni slučaj ostaje trenutni i deterministički, fleksibilni slučaj obrađuje model, a neizvestan slučaj nikada se ne razrešava slepim nagađanjem koje pokreće pogrešnu radnju. Herald takođe modelira učešće i pripisivanje: promenljiva okruženja za korisničko ime operatera (`HERALD_<CHANNEL>_OPERATOR_USERNAME`) i ugovor o učesnicima/pripisivanju pokreću polja `created_by`/`assigned_to` i označavanje obaveštenja sa @, tako da je jasno ko je šta uradio i koga se obaveštava. Što se upravljanja tiče, Herald nasleđuje Helix Constitution kao ko-locirani podmodul i poštuje njegova pravila, a rani je proizvodni korisnik Docs Chain — njegov kompletan korpus od 66 dokumenata u Markdown formatu → HTML/PDF/DOCX povezan je kroz `exec:` transformacije Docs Chain i proverava se bez grešaka. Herald je prvenstveno alat za Shell/Go sa slojevitim specifikacijama (zamena verzija V1→V2→V3→V4) i vodičima za podešavanje operatera po kanalima za razmenu poruka i dispečere LLM/agenta.

## Zašto smo ga napravili

Uzbune tiho otkazuju — šalju se na pogrešan kanal, gube se ili zahtevaju krutu sintaksu komandi koju korisnici neće pamtiti. Herald je napravljen da garantuje pouzdanu distribuciju i omogući ljudima da odgovaraju na prirodnom jeziku, tako da su obaveštenja i pouzdana i bez napora za preduzimanje akcije.


## Zašto je ovo revolucionarno

Spaja dve stvari koje se obično kupuju kao odvojeni proizvodi – pouzdano rutiranje događaja kroz više kanala i interfejs koji razume prirodni jezik – u jedan sistem u kojem operatori jednostavno govore, a softver shvata šta žele. Ključna karakteristika koja ga čini pouzdanim za produkciju jeste mehanizam za razjašnjenje: sistem za obaveštavanje koji radije pita nego da pogreši bolji je od onog koji može da utiče na stvarno stanje.

## Šta je inovativno

- Trostepena disciplina namere: brza putanja komande → zaključivanje pomoću LLM → razjašnjenje i pitanje.
- Interakcija sa pretplatnicima putem prirodnog jezika (nema potrebe za učenjem sintakse komandi).
- Ugovor o dodeli učesnika koji pokreće `created_by`/`assigned_to` + označavanje sa @.
- Pravi Docs Chain potrošač (korpus od 66 dokumenata, više formata, verifikovan).

## Izazovi i rešenja

- **Nejasna namera izražena prirodnim jezikom:** rešeno trostepenim lestvicama prepoznavanja, zaključivanja i razjašnjavanja umesto slepog nagađanja.
- **Pouzdano širenje obaveštenja:** rešeno dizajnom koji obuhvata unos → distribuciju kroz više kanala kako bi obaveštenja stigla na pravo odredište.
- **Ispravna dodela kroz kanale:** rešeno pomoću promenljive okruženja sa korisničkim imenom operatora i ugovora o dodeli učesnika.
- **Odstupanje dokumentacije:** rešeno povezivanjem korpusa dokumentacije kroz Docs Chain sa verifikovanim transformacijama.

## Tehnološki stek (zašto + kako)

- **Go** – osnovna logika događaja i distribucije (po obrascima jezika organizacije).
- **Shell** – alati za operatore i skripte za podešavanje.
- **Claude Kod (LLM)** – nivo zaključivanja namere za poruke u slobodnom formatu.
- **Adapteri za kanale za razmenu poruka** – distribucija obaveštenja kroz više kanala.
- **Docs Chain** – pipeline za izradu i verifikaciju dokumentacije (Markdown→HTML/PDF/DOCX).
- **Helix Constitution podmodul** – nasleđena upravljačka pravila.

