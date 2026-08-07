---
name: Courses-Creator
slug: courses-creator
tier: vasic-util-secondary
order: 22
status: production
license: UNVERIFIED
private: false
tech:
  - Go
  - TypeScript
  - React
  - Electron
  - React Native
  - PostgreSQL
  - Python
  - LLM providers (OpenAI, Anthropic, Ollama)
  - TTS (Bark, SpeechT5)
  - MCP
  - Docker Compose
  - nginx
  - Prometheus
  - Grafana
repos:
  - https://github.com/vasic-digital/Courses-Creator
diagrams:
  - Pipeline flow (markdown → LLM enrichment → TTS + music → video assembly → publish)
  - One-backend-three-clients topology (desktop/mobile/web over shared API)
  - Deployment stack (Docker Compose services)
  - Optional-AI toggle (basic vs enhanced path by provider keys)
---

**Markdown unutra, profesionalni video kurs napolje — poboljšan AI, za više platformi.**

## Sažetak

Courses-Creator je alat koji pretvara markdown skripte u profesionalne video kurseve s poboljšanjima pokretanim AI: obogaćivanje sadržaja putem više LLM pružaoca (OpenAI/Anthropic/Ollama), visokokvalitetni TTS i pozadinska muzika, te desktop, mobilni i veb plejeri — sve raspoređeno putem Docker sa Prometheus/Grafana monitoringom.

## Kratak opis

Pretvara markdown u privlačne video kurseve. Go procesorski motor obogaćuje sadržaj preko više LLM pružaoca, generiše naraciju (Bark/SpeechT5 TTS) i muziku, te isporučuje na Electron desktop, React Native mobilne i React veb plejere, uz potpuno Docker raspoređivanje i monitoring.

## Detaljan opis

Proizvodnja video kursa obično zahteva rad cele male produkcijske kuće: pisanje scenarija, snimanje naracije, pronalaženje muzike, montaža, kodiranje, a zatim izrada plejera za svaku platformu koju polaznici mogu koristiti. Courses-Creator ceo taj proces sabija u jedan ulaz — markdown skriptu — i jednu komandu. U njegovom središtu nalazi se Go procesorski jezgro koje pokreće kompletnu video/audio liniju: obogaćuje pisani sadržaj preko više LLM pružaoca (OpenAI, Anthropic i lokalni Ollama), sintetizuje prirodnu naraciju pomoću tekst-u-govor motora (Bark, SpeechT5), dodaje pozadinsku muziku i sastavlja sve delove u gotove video kurseve. Autorov posao ostaje na nivou ideja i reči; sistem se brine o glasu, muzici i produkciji. A budući da kurs ima smisla samo ako ga ljudi mogu gledati, isporuka je dizajnirana za više platformi: Electron desktop aplikacija za kreiranje, React Native mobilni plejer i React veb plejer, svi napajani istim REST API sistemom i pozadinskim procesima — jedan backend, tri vrhunska klijenta, bez ponovne implementacije za svaku platformu.

Ključno je da se radi o produkcijskoj infrastrukturi, a ne o demo snimku. Backend podržava PostgreSQL perzistenciju, obradu pozadinskih poslova tako da duge TTS/video renderovanje nikada ne blokira API, MCP serverske implementacije za poboljšanja uz pomoć alata, Prometheus metrike, JWT autentifikaciju i nginx reverse proxy — a sve se to isporučuje kao Docker Compose raspoređivanje sa Grafana/Prometheus monitoring profilima koje možete pokrenuti u jednom koraku. AI je sloj za poboljšanje, a ne zavisnost: svaki LLM pružalac je opcioni, tako da linija radi i bez API ključeva za osnovni rad, a premium obogaćenja se aktiviraju čim se ključevi dodaju. Ta jedna odluka čini isti alat pogodnim i za hobiste koji rade offline na laptopu i za preduzeća koja integrišu svog omiljenog pružaoca — a cela medijska linija pokrivena je jediničnim, integracionim i end-to-end testovima, umesto da se sve zasniva na poverenju.

## Zašto smo ga napravili

Ručna proizvodnja video kurseva je spora: pisanje, naracija, muzika i montaža zahtevaju trud i specijalizovane alate. Courses-Creator sve to sabija u markdown liniju vođenu jednim izvorom, gde skripta postaje gotov kurs, a AI popunjava praznine koje bi ljudi inače ručno popunjavali.


## Zašto je ovo revolucionarno

Proces izrade kurseva pretvara iz specijalizovanog zanata koji zahteva više alata u ponovljivu softversku cevovodnu strukturu: pisanje, obogaćivanje AI, generisanje naracije i muzike, kao i reprodukcija na više platformi – sve je to integrisano u jedan raspoloživi paket. Elegantno snižavanje performansi pri radu bez ključa API predstavlja tihu nadmoć – isti kodni bazen opslužuje i samostalnog kreatora s ograničenim budžetom i preduzeće s ugovorom o premium uslugama, bez potrebe za prepravkama.

## Šta je inovativno

- Cevovod od Markdowna do videa s priključivim obogaćivanjem LLM (OpenAI/Anthropic/Ollama).
- Ugrađena generacija TTS (Bark, SpeechT5) i pozadinske muzike.
- Implementacije MCP servera unutar procesnog motora za poboljšanje uz pomoć alata.
- Jedan backend koji opslužuje tri primarna klijenta (Electron za desktop, React Native za mobilne uređaje, React za veb).

## Izazovi i rešenja

- **Zahtevna obrada medija:** rešeno pomoću Go cevovoda i obrade pozadinskih poslova, tako da dugotrajni poslovi TTS/videa ne blokiraju API.
- **Opciono, ali moćno obogaćivanje AI:** rešeno tako što su provajderi LLM opcioni i priključivi, s elegantnim povratkom na osnovne funkcionalnosti.
- **Isporuka na više platformi:** rešeno zajedničkim REST API i tri namenska plejer aplikacije.
- **Operativnost:** rešeno pomoću Docker Compose profila, Prometheus/Grafana i ugrađene JWT autentifikacije.

## Tehnološki stek (zašto + kako)

- **Go** – osnovni procesni motor, REST API, izvršitelj poslova, cevovod (972K+ bajtova, dominantni jezik).
- **TypeScript / React** – veb plejer i zajednički korisnički interfejs.
- **Electron** – desktop aplikacija za kreiranje.
- **React Native** – mobilni plejer.
- **PostgreSQL** – perzistencija kurseva/poslova.
- **Provajderi LLM (OpenAI, Anthropic, Ollama)** – poboljšanje sadržaja.
- **TTS (Bark, SpeechT5)** – sinteza naracije.
- **MCP serveri** – integracija alata unutar motora.
- **Docker Compose + nginx** – raspoređivanje celog steka i reverse proxy.
- **Prometheus + Grafana** – nadgledanje.

> Napomena: javni README vodič za brzi početak koristi rezervisani klon `your-org` URL.

