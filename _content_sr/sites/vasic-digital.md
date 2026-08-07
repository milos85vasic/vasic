---
site: vasic.digital
type: company-site
title: Vasic Digital — AI-Native Software Engineering
tagline: We build AI development systems — and the governance that makes them trustworthy.
sources:
  - _analysis/content-briefs/_TECH-STACK.md
  - _analysis/content-briefs/*.md
---

# Vasic Digital

## Heroj

**AI inženjering izvorne softverske arhitekture, stvoren da bude pouzdan.**

Bilo ko može da poveže aplikaciju sa LLM modelom za jedno popodne. Težak deo — onaj koji odlučuje da li je AI sistem samo demonstracija ili pouzdan proizvod — jeste sve ono oko modela: apstrakcija provajdera koja preživljava prekide u radu, orkestracija koja drži agente na zadatku, verifikacija koja hvata model u blefiranju i upravljanje koje dokazuje da ceo sistem funkcioniše kako treba. Taj težak deo je ono što Vasic Digital gradi. Projektujemo i isporučujemo sisteme za razvoj AI rešenja — modele, agente, orkestraciju i infrastrukturu koji pretvaraju velike jezičke modele u pouzdan softver — zajedno sa slojem upravljanja koji ih drži pod kontrolom. Sve je to zasnovano na jednom nepopustljivom pravilu: funkcija nije „gotova" kada testovi prođu; gotova je tek kada je stvarni korisnik zaista može da koristi, i kada postoji prikupljen dokaz koji to potvrđuje.

## O nama

Vasic Digital je usredsređena inženjerska praksa koja gradi međusobno povezanu porodicu proizvoda i ponovljivih modula za razvoj AI rešenja. Umesto jednog monolitnog sistema, rad je organizovan kao flota: velike aplikacije izgrađene na desetinama malih, nezavisno testiranih i odvojenih modula — tako da se dokazani delovi ponovo koriste u svakom proizvodu umesto da se ponovo grade. Osnovni jezik je **Go**, dopunjen sa **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift** i **Shell**, izabranim prema potrebi: Go za servise i biblioteke visokog protoka, Kotlin za alate za raspoređivanje i cross-platform mobilne aplikacije, TypeScript za tipizirane frontendove, Python za povezivanje AI/ML.

Ono što povezuje flotu nije samo želja, već disciplina pretvorena u mehanizam. Svaki projekat nasleđuje zajednički inženjerski **Constitution** kao Git potmodul — tako da se jednom zategnuto pravilo proširi na flotu od preko 140 repozitorijuma — a svaka funkcija koju proizvod reklamira mora biti podržana automatizovanim testom koji generiše dokaze pre nego što se smatra isporučenom. Ovo nije samo marketinški jezik koji se dodaje poslu; to je operativni model na kojem posao počiva. Prava prednost je u kumulativnom efektu: pošto se generičke funkcionalnosti nalaze u odvojenim, nezavisno testiranim modulima, svaka ispravka ili poboljšanje primenjuje se na jednom mestu i podiže sve proizvode odjednom, a svaki novi sistem se sastavlja od delova koji su već stekli poverenje.

## Šta radimo

**Razvoj zasnovan na AI.** Gradimo osnovu za AI sisteme od početka do kraja:

- **Višestruki pristup LLM modelima** — sopstvena apstrakcija preko 40+ provajdera (Anthropic/Claude, OpenAI, DeepSeek, Gemini, Mistral, Cohere, Groq, xAI/Grok, Qwen, Perplexity, OpenRouter, Together AI, Replicate, Cerebras, Cloudflare Workers AI, SiliconFlow i lokalni Ollama kao rezervna opcija) iza jednog interfejsa sa ponovnim pokušajima, prekidačima kola i proverama zdravlja.
- **Orkestracija agenata** — headless CLI kontrolne ravni za kodirajuće agente, grafički zasnovani agentički tokovi, višestepeni „AI debati" za postizanje konsenzusa i DAG/pipeline runtime okruženja.
- **Verifikacija LLM modela** — sloj poverenja koji ocenjuje modele obaveznim testom razumevanja („Da li vidiš moj kod?") uz dodatne provere latencije, striminga, poziva funkcija, vizuelnih i embeddings testova, izvozeći konfiguraciju koja je isključivo verifikovana.
- **Pretraga i memorija** — RAG, vector baze podataka, embeddings i integrisani motori za pamćenje agenata (Mem0 + Cognee + Letta) sa kompresijom beskonačnog konteksta.
- **Odbrana LLM modela** — sigurnosne barijere, detekcija PII, protivničke red-tim simulacije i normalizacija ulaza.


**Porodica proizvoda Helix.** Naša vodeća linija obuhvata ceo AI razvojni ciklus:

- **HelixTrack** — alternativa otvorenog sveta za JIRA (zastavni proizvod linije Helix-Track).
- **HelixAgent** — ansamblski LLM servis koji omogućava raspravu više modela i isporučuje odgovor na koji se svi slože.
- **HelixCode** — distribuirana AI razvojna platforma koja deli posao među radnicima upravljanim putem SSH sa mogućnostima čuvanja stanja i vraćanja na prethodne verzije.
- **HelixLLM** — jedan binarni fajl, šest režima: OpenAI- i Anthropic-kompatibilno izvođenje zaključivanja, od laptopa do klastera, preko HTTP/3.
- **HelixCluster** — distribuirani operativni sistem za AI računanje, od GPU-ova u podatkovnim centrima do prenosnih uređaja na ivici mreže.
- **LLMProvider / LLMOrchestrator / LLMsVerifier** — apstrakcija provajdera, kontrolna ravan agenata i provereni izvor istine.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** — memorija, kontrolisane veštine, razvoj vođen specifikacijama, izgradnja aplikacija, verifikovani prevod, terminali sa nultim poverenjem, federisani Git, bezbedna ažuriranja OTA i samostalno hostovani cloud gaming.

**Alati i pomoćni programi (vasic-digital utils).** Alati profesionalnog nivoa koji funkcionišu samostalno: **Catalogizer** (višeprotokolno, enkriptovano upravljanje kolekcijama medija), **Courses-Creator** (proizvodnja AI kurseva od markdown-a do videa), **VisionEngine** (računarski vid + LLM vizuelna percepcija korisničkog interfejsa), **DocProcessor** (mapiranje dokumentacije u funkcionalnosti za kontrolu kvaliteta), **Docs Chain** (dvosmerna sinhornizacija dokumenata i baza podataka sa heširanim sadržajem), **Herald** (obaveštenja na više kanala na prirodnom jeziku), **task_bridge** (dvosmerna sinhornizacija zadataka i tabela), i **Vasic Digital Paket ponovljivo upotrebljivih modula** — „standardna biblioteka" infrastrukture, AI primitiva i modula za zaštitne mehanizme pod nazivom `digital.vasic.*`.

**Automatizacija infrastrukture (Server Factory).** Naše DevOps nasleđe: **Mail Server Factory** i **Server Factory Osnovni okvir**, koji pretvaraju deklarativne JSON specifikacije u potpuno konfigurisane, dokirizovane servere na različitim vrstama veza i Linux distribucijama, uz dodatne alate za VM slike (Qemu-Utils, Parallels-Utils) i fabrike pomoćnih servisa.

## Tehnologije

Ukorijenjeno u našem stvarnom tehnološkom steku:

- **Programski jezici:** Go (dominantan), Kotlin i Kotlin Multiplatform, TypeScript, Python, Swift, Shell, uz PL/pgSQL pa čak i TLA+ formalne specifikacije u radu na distribuiranim sistemima.
- **AI / LLM:** pristup preko više provajdera (43+ adaptera), Model Context Protocol (MCP), RAG, vector baze podataka i embeddings, algoritmi za planiranje (HiPlan, MCTS, Tree of Thoughts), LLMOps, benchmarking (SWE-bench/HumanEval/MMLU) i TTS (Bark, SpeechT5).
- **Backend:** Gin (Go), gRPC + Protocol Buffers, HTTP/3 (QUIC), WebSockets, Angular i React frontendovi, Kafka/RabbitMQ razmena poruka.
- **Podaci:** PostgreSQL, SQLite, SQLCipher (enkriptovani u mirovanju), Redis, Neo4j, ClickHouse i skladištenje objekata (MinIO/S3/GCS/Azure).
- **Infra / DevOps:** Docker i Compose, Kubernetes + Helm, Prometheus + Grafana, OpenTelemetry, QEMU/Libvirt/Parallels, i CI/CD preko GitHub Actions, Gradle i Make.
- **Testiranje / Kvalitet:** anti-bluf HelixQA okvir, Challenge okviri po modulu sa mutacionim kapijama, `go test -race`, alati za vizuelnu regresiju, testiranje na ADB uređajima, SonarQube kapije i skeniranje sigurnosti (semgrep, gosec, trivy, snyk, gitleaks, nancy).

## Kvalitet i upravljanje — naša prepoznatljiva odlika

Dva stuba čine ceo vozni park koherentnim i pouzdanim:

- **HelixConstitution** — univerzalni, projekat-agnostički inženjerski priručnik isporučen kao Git podmodul, koji nasleđuje svaki projekat u voznom parku od preko 140 repozitorijuma. On kodira neupitnu disciplinu — kapije protiv lažnih tvrdnji, imunitet na lažno pozitivne rezultate, sigurnost podataka i hostova, pravila dokumentacije i pokrivenosti — koju projekat može proširiti, ali nikada oslabiti. Jedan update podmodula ažurira pravila svuda; propagacione kapije doslovno pretražuju tražene klauzule širom voznog parka, a svaka kapija je uparena sa mutacionim testom koji dokazuje da sama kapija nije prevara. Upravljanje postaje proverljiva činjenica, a ne samo želja.
- **HelixQA** — orkestracija QA protiv lažnih tvrdnji. Pokreće napisane banke testova **YAML** i potpuno autonomne QA sesije sa **LLM** i računarskim vidom na Androidu, Android TV-u, Vebu i Desktopu, i odbija da dodeli status PROLAZ bez snimljenih dokaza o izvršavanju (snimci ekrana, logcat, video, stack trace). „Testirali smo to" postaje „evo video-snimka, logcat-a i tiketa."

## Pozicioniranje

Bilo ko može da poveže aplikaciju sa **LLM**. **Vasic Digital** gradi deo koji je težak: **AI** sisteme koji su proverljivi, ponovo upotrebljivi i iskreni — agnostički **AI** supstrat nezavisan od pružaoca, životni ciklus **Helix** proizvoda iznad njega i disciplinu ustava-plus-dokazi koja garantuje da ono što se isporučuje zaista funkcioniše. Ne tražimo od vas da verujete zelenom kvačicu. Pokazujemo vam dokaze iza nje.

## Kontakt

Hajde da napravimo nešto proverljivo.

- **Mejl:** [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [github.com/vasic-digital](https://github.com/vasic-digital)

