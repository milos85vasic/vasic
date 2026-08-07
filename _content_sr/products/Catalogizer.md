---
name: Catalogizer
slug: catalogizer
tier: vasic-util-secondary
order: 21
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - Gin
  - TypeScript
  - React
  - Tailwind
  - WebSockets
  - SQLCipher
  - PostgreSQL
  - Redis
  - SMB/FTP/NFS/WebDAV
  - Prometheus
  - OpenTelemetry
  - Docker
  - Tauri/Rust
  - S3
  - Google Cloud Storage
repos:
  - https://github.com/vasic-digital/Catalogizer
  - https://github.com/vasic-digital/Media-Types-TS
  - https://github.com/vasic-digital/Catalogizer-API-Client-TS
  - https://github.com/vasic-digital/Media-Player-React
  - https://github.com/vasic-digital/Media-Browser-React
  - https://github.com/vasic-digital/Collection-Manager-React
  - https://github.com/vasic-digital/Dashboard-Analytics-React
  - https://github.com/vasic-digital/Auth-Context-React
diagrams:
  - Layered architecture (React UI ↔ Go API ↔ SQLCipher) with multi-protocol fan-out
  - Resilience sequence (SMB outage → circuit breaker → offline cache → backoff reconnect)
  - Enrichment pipeline (detected file → classifier → external providers → catalog entry)
  - Module map (Catalogizer over the 21 digital.vasic.* submodules)
---

**Napredno upravljanje multimedijalnim kolekcijama sa podrškom za više protokola — otkrivanje, katalogizacija i obogaćivanje svega što posedujete.**

## Sažetak

Catalogizer je sistem za upravljanje multimedijalnim kolekcijama koji se može samostalno hostovati i automatski otkriva, kategorizuje i organizuje medije na SMB, FTP, NFS, WebDAV i lokalnim fajl-sistemima, uz praćenje u realnom vremenu, šifrovano skladištenje, obogaćivanje spoljnim metapodacima i moderan React interfejs podržan visokoperformansnim Go API backendom.

## Kratak opis

Profesionalni upravljač multimedijalnih biblioteka sa podrškom za više protokola. Go/Gin REST API prepoznaje preko 50 vrsta medija sa izvora poput SMB/FTP/NFS/WebDAV/lokalnih sistema, obogaćuje ih podacima iz TMDB/IMDB/MusicBrainz/Steam i drugih izvora, te služi React veb-aplikaciju u realnom vremenu preko šifrovane SQLCipher baze podataka.

## Detaljan opis

Većina upravljača medijima zahteva da se prvo predate: sve prebacite na jedan disk, u jednom formatu, jedne vrste, i tek onda će vam pomoći. Catalogizer polazi od suprotne premise — vaša kolekcija već postoji tamo gde postoji, rasprostranjena na NAS deljenim resursima i protokolima koji se nikada neće usaglasiti — i prilazi joj na njenom terenu. Podržava protokole koje skladišta već koriste — SMB/CIFS, FTP/FTPS, NFS, WebDAV i lokalne fajl-sisteme — iza jedinstvene klijentske apstrakcije, tako da Windows deljeni resurs, FTP arhiva i WebDAV tačka montiranja izgledaju identično višim slojevima i mogu se mešati, zamenjivati ili povlačiti bez dodirivanja aplikativnog koda. Go backend (Gin REST API) neprestano nadgleda te izvore, otkriva i klasifikuje preko 50 vrsta medija (filmovi, serije, muzika, igre, softver, dokumentarci) čim se fajlovi pojave, te obogaćuje svaku stavku iz niza spoljnjih provajdera — TMDB, IMDB, TVDB, MusicBrainz, Spotify, Steam i drugih — tako da običan naziv fajla postaje potpuno opremljen katalogizovan unos sa umetničkim delima, glumačkom postavom i metapodacima. Rezultati se strimuju na TypeScript React frontend putem WebSocket-a, tako da se biblioteka ažurira uživo tokom ingestije, umesto na ručno osvežavanje, a svaki bajt metapodataka čuva se u šifrovanoj SQLCipher bazi podataka zaštićenoj JWT autentifikacijom zasnovanom na ulogama.

Dok većina katalogizatora pada čim deljeni resurs otkaže, Catalogizer je projektovan da ostane upotrebljiv i tokom prekida. Privremeni kvar na SMB-u se apsorbuje eksponencijalnim ponovnim povezivanjem, prekidačem kola koji sprečava bombardovanje neaktivnog hosta, stalnim praćenjem zdravlja sistema i kešom metapodataka koja nastavlja da odgovara na korisničke zahteve iz poslednjeg poznatog ispravnog stanja — razlika između „cela aplikacija je pala jer se jedan NAS restartovao" i „jedan izvor je degradiran, ali sve ostalo radi". Pored katalogizacije, služi i kao operativni alat za kolekciju: analitika o trendovima rasta i praćenju kvaliteta/verzija, generisanje profesionalnih PDF izveštaja, usluga konverzije PDF u sliku/tekst/HTML, izvoz/uvoz favorita (JSON/CSV) i sinhronizacija sa oblakom na S3, Google Cloud Storage ili lokalnim folderima. I nije to monolit koji je slučajno veliki — namerno je sastavljen od 21 ponovo upotrebljivog `digital.vasic.*` Go podmodula i TypeScript klijentskih paketa, od kojih je svaki nezavisno testiran i verziran, tako da iste isprobane komponente za autentifikaciju, fajl-sisteme, strimovanje i nadgledanje koje pokreću Catalogizer pokreću i širu porodicu proizvoda. Kontrola kvaliteta nije samo deklarativna: okvir Challenges i HelixQA podvrgavaju svaku reklamiranu funkcionalnost proveri zasnovanoj na dokazima, bez praznih obećanja.

## Zašto smo ga napravili

Postojeći upravljači medijskim sadržajem polaze od pretpostavke da postoji jedan skladišni backend i jedan tip medija. Prave kolekcije rasprostiru se preko više NAS deljenih resursa i protokola, propadaju kada neki resurs otkaže i mešaju filmove, muziku, igre i softver. Catalogizer je stvoren da sve protokole tretira jednako, preživi nestabilna mrežna skladišta i pruži jedan autoritativan, obogaćen i enkriptovan katalog nad svim sadržajima.

## Zašto je revolucionaran

U jednom samostalno hostovanom, enkriptovanom paketu objedinjuje ono što inače zahteva čitav niz odvojenih alata: unos nezavisan od protokola koji sve skladišne backendove tretira podjednako, otpornost koja katalog održava živim tokom prekida skladišta umesto da s njima pada, i bogato obogaćivanje iz više izvora koje pretvara sirove fajlove u preglednu, atributiranu biblioteku. Dobitak modularne arhitekture je kumulativan: svako poboljšanje u klijentu fajl sistema ili novi dodatak za provajdera primeni se jednom i unapređuje sve potrošače, tako da Catalogizer postepeno postaje bolji kako i okruženje oko njega napreduje. Ukratko, to je razlika između medijskog indeksa i medijskog *sistema* – onog koji je vaš, koji preživljava nestabilnu infrastrukturu i čija je unutrašnja logika dokazana, a ne samo obećana.

## Šta je inovativno

- Ujedinjeni klijent fajl sistema za više protokola (SMB/FTP/NFS/WebDAV/lokalno) iza jednog interfejsa.
- Oflajn keš + prekidač strujnog kola kako bi katalog ostao upotrebljiv tokom prekida skladišta.
- Potpuno izdvajanje u 21 ponovo upotrebljiv `digital.vasic.*` Go podmodul i TS klijentske module.
- Katalog enkriptovan na mestu skladištenja (SQLCipher) sa sinhronizacijom u realnom vremenu (WebSocket) prema UI.
- Dokazani kvalitet putem Challenges okvira i HelixQA integracije.

## Izazovi i rešenja

- **Nestabilna mrežna skladišta:** rešeno eksponencijalnim povlačenjem, prekidačem strujnog kola, zdravstvenim proverama i oflajn kešom sa politikom izbacivanja koji služi keširanim metapodacima kada izvori nisu dostupni.
- **Heterogenost protokola:** rešeno apstrakcijom svakog protokola iza zajedničkog `digital.vasic.filesystem` klijenta tako da viši slojevi nisu svesni protokola.
- **Sigurnost podataka:** rešeno enkripcijom na mestu skladištenja (SQLCipher) uz JWT/RBAC autentifikaciju i middleware za sanitizaciju zahteva.
- **Održivost na velikoj skali:** rešeno izdvajanjem sve generičke logike u nezavisno testirane podmodule umesto u monolit.

## Tehnološki stek (zašto + kako)

- **Go + Gin** — visokoperformativno REST API jezgro (`catalog-api`); izabrano zbog konkurentnosti i propusnosti pri neprekidnom praćenju.
- **TypeScript + React + Tailwind (Vite)** — responsivan `catalog-web` UI sa ažuriranjima u realnom vremenu.
- **WebSockets** — sinhronizacija podataka uživo između backend čvorišta i UI.
- **SQLCipher (enkriptovani SQLite)** — enkriptovano skladište metapodataka na mestu skladištenja; dvostruka podrška za SQLite/PostgreSQL preko `digital.vasic.database`.
- **Klijenti za SMB/FTP/NFS/WebDAV** — unos preko više protokola putem `digital.vasic.filesystem`.
- **Spoljašnji API-ji za metapodatke (TMDB, IMDB, TVDB, MusicBrainz, Spotify, Steam)** — dodaci za obogaćivanje.
- **Prometheus + OpenTelemetry** — metrike i praćenje putem `digital.vasic.observability`.
- **Docker / builder kontejner** — reproduktivne izrade (Tauri/Rust usmerene kroz `catalogizer-builder`).
- **Redis** — keširanje i ograničavanje broja zahteva putem `digital.vasic.cache` / `ratelimiter`.
- **S3 / Google Cloud Storage** — sinhronizacija u oblaku i skladištenje kontrolnih tačaka.

