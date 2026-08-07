---
name: VisionEngine
slug: visionengine
tier: vasic-util-secondary
order: 23
status: active
license: UNVERIFIED
private: false
tech:
  - Go (1.25+)
  - GoCV / OpenCV (build-tag-gated)
  - LLM vision providers (GPT-4o, Claude, Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama)
  - Graph algorithms (BFS)
  - DOT / JSON / Mermaid exporters
  - i18n Translator seam
repos:
  - https://github.com/HelixDevelopment/VisionEngine
  - https://github.com/vasic-digital/VisionEngine
diagrams:
  - Four-layer stack (Analyzer / NavigationGraph / LLM Vision / Config)
  - Navigation graph rendered (Mermaid) with BFS path highlighted
  - Vision fallback chain across providers
  - Build-tag split (default stub build vs -tags vision OpenCV build)
---

**Posmatrajte korisnički interfejs kao korisnik — računarski vid plus LLM vid za analizu i navigaciju.**

## Sažetak

VisionEngine je odvojeni Go alat koji kombinuje klasični računarski vid sa LLM zasnovanim vidom kako bi analizirao korisničke interfejse, otkrivao UI elemente i vizuelne probleme, te gradio navigacione grafove prelaza između ekrana aplikacije — sa priključivim višekorisničkim vidovnim pozadinama i OpenCV-om zaštićenim iza oznake za izgradnju.

## Kratak opis

Ponovo upotrebljiv Go modul za analizu UI-a i izgradnju navigacionog grafa. Nudi sloj analizatora (UI elementi, razlike između ekrana, vizuelni problemi), navigacioni graf sa BFS pretragom puteva i izvozom u DOT/JSON/Mermaid formatu, kao i LLM-vizijske adaptere za GPT-4o, Claude, Gemini, Qwen-VL i druge.

## Detaljan opis

Većina automatizovanih testova korisničkog interfejsa je u suštini slepa. Oslanja se na stabla pristupačnosti i DOM selektore — mašinski pojam interfejsa — i propušta sve ono što čovek stvarno doživljava: da li je dugme vidljivo renderovano, da li je raspored pokvaren, da li je ekran na koji je stigao onaj koji je očekivao. VisionEngine premošćuje tu prazninu dajući automatizaciji pravo opažanje, sposobnost da pogleda UI i razmišlja o njemu na način na koji bi to učinila osoba. Organizovan je u četiri kooperativna sloja koji se grade od sirovih piksela do razumevanja cele aplikacije. **Analizator** definiše stabilan ugovor — interfejse (`Analyzer`, `VideoProcessor`) i tipove vrednosti (`UIElement`, `ScreenAnalysis`, `ScreenDiff`, `Rect`, `Size`, `TextRegion`, `VisualIssue`, `ScreenIdentity`, `Action`, `KeyFrame`) sa referentnom implementacijom `StubAnalyzer` — tako da korisnici mogu da otkrivaju elemente, upoređuju ekrane i otkrivaju vizuelne probleme u odnosu na ugovor koji se neće menjati pod njima. **Navigacioni graf** podiže perspektivu sa pojedinačnog ekrana na celu aplikaciju, modelujući je kao usmereni graf prelaza između ekrana sa BFS pretragom puteva i tri izvozna formata (DOT, JSON, Mermaid), tako da automatizacija ne samo da vidi ekran, već može da planira put do bilo kog drugog — a isporučuje se sa testovima za stres, automatizaciju, integraciju i bezbednost kako bi se to dokazalo. Sloj **LLM vida** dodaje savremeno multimodalno rezonovanje: interfejs `VisionProvider` sa adapterima za OpenAI (GPT-4o), Anthropic (Claude), Gemini, Qwen-VL, Kimi, StepGUI, Astica i Ollama, sastavljen preko `FallbackChain`-a tako da neuspešan, ograničen brojem zahteva ili slabiji provajder otkazuje postupno, umesto da povuče ceo proces sa sobom. Sloj **Konfiguracije** obrađuje učitavanje i validaciju promenljivih okruženja, pri čemu se svaka poruka o grešci koja je vidljiva korisniku prosleđuje kroz `i18n.Translator`.

Odluka koja sve ovo čini zaista primenjivim jeste činjenica da teška zavisnost od nativnih biblioteka nije obavezna. OpenCV veze su zaštićene oznakom za izgradnju iza `-tags vision`, a podrazumevana verzija isporučuje se sa stubovima — tako da ceo modul može da se kompajlira, testira i pokreće na bilo kom Go 1.25+ hostu bez OpenCV alata u vidokrugu, a nativni stek se uključuje samo kada korisnik to eksplicitno zahteva. Upravo to omogućava da se VisionEngine integriše u običan CI pokretač bez potrebe za prilagođenom slikom. Potpuno odvojen u skladu sa ustavom (CONST-051(B)), uključuje se u sisteme korisnika — posebno u HelixQA — kao podmodul jednakog koda, dajući testiranju UI-a zasnovanom na dokazima pravi par očiju.

## Zašto smo ga napravili

Automatizacija testiranja korisničkog interfejsa koja se oslanja isključivo na stabla pristupačnosti ili selektore propušta ono što korisnik zapravo vidi. VisionEngine dodaje pravu vizuelnu inteligenciju — detekciju elemenata, poređenje ekrana i zaključivanje zasnovano na LLM-viziji — uz mapu navigacije kroz ekrane aplikacije, tako da automatizacija može i da opaža i da se kreće kroz korisnički interfejs.

## Zašto je revolucionarno

Spaja dva inače nekompatibilna pristupa — brzu, determinističku klasičnu računarsku viziju i fleksibilnu, semantičku LLM-viziju — iza jedinstvenog interfejsa sa lancem rezervnih rešenja, tako da korisnik dobija preciznost jednog i zaključivanje drugog bez potrebe za izborom. A zadržavanjem OpenCV-a kao strogo opcione komponente, uklanja se uobičajeni trošak te moći: svaki Go projekat može steći pravu percepciju korisničkog interfejsa bez uvođenja native vizuelnog alata u svoj build proces.

## Šta je inovativno

- Dvostruka percepcija: klasična računarska vizija (OpenCV/GoCV) plus LLM-vizija sa više provajdera i lancem rezervnih rešenja.
- Graf navigacije sa BFS algoritmom za pronalaženje putanja i izvozom u DOT/JSON/Mermaid formatima.
- OpenCV kontrolisan build-tagovima kako bi modul ostao izgradiv/testabilan bez native zavisnosti.
- Potpuno odvojen, internacionalizovan, podmodul sa istom kodnom bazom (koristi ga HelixQA).

## Izazovi i rešenja

- **Problem sa teškim native zavisnostima:** rešeno pomoću `-tags vision` gate-a i podrazumevanih stubova kako bi CI/host sistemi bez OpenCV-a i dalje mogli da se grade i testiraju.
- **Nepouzdanost provajdera vizije:** rešeno interfejsom `VisionProvider` i kompozitorom `FallbackChain`.
- **Mapiranje složenih tokova aplikacije:** rešeno usmerenim grafom navigacije uz BFS algoritam za pronalaženje putanja i izvoz u više formata.
- **Spajanje komponenata:** rešeno pomoću CONST-051(B) decoupling-a i šava za internacionalizaciju.

## Tehnološki stack (zašto + kako)

- **Go (1.25+)** — jezgro modula i sva četiri sloja.
- **GoCV / OpenCV** — klasična računarska vizija, kontrolisana build-tagovima.
- **Provajderi LLM-vizije (GPT-4o, Claude, Gemini, Qwen-VL, Kimi, StepGUI, Astica, Ollama)** — multimodalno zaključivanje o korisničkom interfejsu putem adaptera.
- **Grafovski algoritmi (BFS)** — pronalaženje putanja u navigaciji.
- **DOT / JSON / Mermaid izvoznici** — vizualizacija grafa navigacije.
- **i18n prevodilac** — odvojene korisničke stringove.

