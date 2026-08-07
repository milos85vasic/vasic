---
name: HelixCluster
slug: helixcluster
tier: helix-primary
order: 14
status: in-development
license: TBD
private: false
tech:
  - Go (1.25 / toolchain 1.26.4)
  - Zig + C/C++
  - gRPC + Protocol Buffers
  - Raft (etcd-raft) + SWIM gossip
  - PostgreSQL 16 / Redis 7 / etcd v3.5 / SQLite
  - NATS / Kafka / RabbitMQ
  - WireGuard + ML-KEM-768/X25519 + AEAD
  - SPIFFE + JWT + OPA
  - Prometheus / Grafana / Jaeger
  - HashiCorp Vault
  - Kubernetes + Helm
  - React + TypeScript + Vite
  - TLA+
repos:
  - https://github.com/HelixDevelopment/helix_cluster
  - https://github.com/HelixDevelopment/HelixConstitution
diagrams:
  - Helix Cluster architecture — the seven-layer stack (L0 hardware → L7 federation) with the 14 control-plane microservices, SWIM gossip + Raft consensus, and the Omega scheduler at the core.
  - Heterogeneous node fabric — tiers T1-T8 (datacenter GPU → edge SBC → handheld) unified under one control plane, with GPU pools and burst-to-cloud marketplace adapters.
  - Post-quantum confidential inference path — X25519 + ML-KEM-768 hybrid handshake → AEAD record protection with replay rejection → attested node (full round-trip labeled PLANNED/gated).
  - Anti-bluff / DST loop — seeded deterministic simulation with fault injection → replay → Porcupine linearizability check, plus the paired mutation gate required to mark work complete.
---

# HelixCluster

**Distribuirani operativni sistem za AI računanje — od GPU-ova u podatkovnim centrima do ručnih uređaja na ivici mreže, pod jedinstvenom kontrolnom ravni.**

## Sažetak

Helix Cluster OS je operativni sistem sledeće generacije koji orkestrira računanje na heterogenim čvorovima — od GPU-ova u podatkovnim centrima do jednopločnih računara na ivici mreže i ručnih uređaja — objedinjujući rasporedivanje HPC zadataka, orkestraciju kontejnera, AI/ML inferenciju, federisano upravljanje više klastera i sigurne sesije za više korisnika pod jedinstvenom kontrolnom ravni.

## Kratak opis

Distribuirani OS zasnovan na Go / klaster za deljenje GPU resursa. Objedinjuje rasporedivanje HPC zadataka (dvoslojni rasporednik po modelu Omega), orkestraciju kontejnera, rutiranje AI inferencije, federaciju i sigurne sesije za više korisnika na heterogenim čvorovima, koordinisano putem SWIM trača i Raft konsenzusa, sa postkvantnim enkripcijom od kraja do kraja.

## Detaljan opis

Helix Cluster OS orkestrira računarske zadatke na radikalno heterogenom hardveru — GPU-ovima u podatkovnim centrima, jednopločnim računarima na ivici mreže, pa čak i ručnim uređajima — pod jedinstvenom kontrolnom ravni, tretirajući policu A100 čipova i šaku jednopločnih računara kao jedan adresabilni sistem umesto kao desetak nepovezanih ostrva. To je Go radni prostor (monorepozitorijum sa git podmodulima) koji implementira sedmoslojni stek, od L0 hardverskog sloja do L7 federacije i opservabilnosti, koordinisan četrnaest mikroservisa kontrolne ravni. Članstvo čvorova prati se putem SWIM trača i otkrivanja, tako da se sistem sam popravlja kako čvorovi pristupaju i napuštaju mrežu; konzistentno stanje osigurava Raft konsenzus, organizovan u Raft grupe po segmentima sa lokalnim čitanjem kod vlasnika zakupa radi brzine i STONITH ogradom kako bi se garantovalo da particionisani čvor ne može oštetiti deljeno stanje. Rasporedivanje zadataka prolazi kroz dvoslojni rasporednik po modelu Omega — optimistična konkurentnost, uparivanje ClassAd-ova, grupno rasporedivanje, preemptivno rasporedivanje na osnovu multiplikatora vrednosti i postavljanje zasnovano na ograničenjima — a zatim ide dalje od klasičnog HPC rasporednika: rutiranje svesno ugljeničnog otiska i troškova/TCO-a, automatsko skaliranje prema oblaku u slučaju naglog opterećenja i adapteri za tržišta (Akash, io.net, RunPod, AWS Spot, Chutes) koji omogućavaju da se poslovi prebace na iznajmljene resurse kada lokalni kapaciteti budu iscrpljeni.

Krajnji korisnici ne vide direktno nijedan od tih mehanizama; oni komuniciraju putem čistog modela sesija (alokacija računarskih resursa), interaktivnog WebSocket/PTY terminala, interne rute za AI inferenciju i očitavanja iskorišćenosti resursa. Sigurnost je integralni sloj, a ne naknadni dodatak: SPIFFE identitet, atestacija uređaja (izazov/odgovor, dokaz GPU rada, zapečaćivanje), kontrolna tačka za izvoz (KYC), kao i postkvantni enkriptovani transport od kraja do kraja, zasnovan na hibridnoj razmeni ključeva X25519 + ML-KEM-768 sa AEAD zaštitom zapisa i odbacivanjem ponovljenih poruka — projektovan tako da i danas uhvaćen saobraćaj ostane poverljiv čak i pred budućim kvantnim protivnikom. Ispravnost se ne proglašava, već *dokazuje*: determinističko simulaciono testiranje (FoundationDB-stil sa unapred zadatim izvršavanjima, ubacivanjem grešaka, simulacijom mreže, bajt-po-bajt reprodukcijom i Porcupine proverom linearnosti) reprodukuje distribuirane greške po potrebi, a obavezni upareni testovi mutacija dokazuju da zaštitni testovi zaista hvataju greške. Arhitektura i dokumentacija održavaju se pouzdanim pomoću mehaničkih provera koje prekidaju izgradnju čim se stvarnost i dokumentacija razilaze.


## Zašto smo ga izgradili

Da bismo pokretali AI i HPC poslove na krajnje različitim hardverskim nivoima bez spajanja zasebnih rasporedivača, orkestratora i stekova za inferenciju — i to uz inženjersku garanciju da svaka isporučena funkcija dokazuje *stvarno ponašanje krajnjih korisnika* (nikad zeleni testovi umesto stubova) i da svaka specifična mogućnost operativnog sistema koristi stvarni nativni alat po platformi (nema lažnih Linux simulacija). Motivacioni problem, naveden u upravljanju repozitorijuma, jeste režim greške „testovi prolaze, ali funkcija zapravo ne radi", koji je projekat eksplicitno izgrađen da eliminiše.

## Zašto je revolucionaran

On spaja pet stvari koje su obično pet odvojenih stekova — HPC rasporedivanje, orkestraciju kontejnera, AI inferenciju, federaciju više klastera i sigurne sesije za više korisnika — u jedinstvenu kontrolnu ravan koja se proteže od GPU-ova u podatkovnim centrima sve do ručnih uređaja na ivici mreže. I to čini uz rigorozan budžet koji se obično rezerviše za specijalizovanu infrastrukturu: korektnost na nivou formalnih metoda (TLA+ specifikacije, deterministička simulacija, provera linearnosti) i poverljivi transport otporan na kvantne napade, garancije koje većina orkestratora jednostavno ne pokušava da ostvari. Pored tehničke diferencijacije, rasporedivanje svesno troškova i ugljeničnog otiska, kao i mogućnost proširenja putem tržišta u oblaku, čine ga i *ekonomskim* polugama — rasporedivač automatski traži jeftiniji, ekološki prihvatljiviji ili rezervni kapacitet, tako da isti posao košta manje i proizvodi manje emisija bez potrebe da iko prepisuje kod.

## Šta je inovativno

- **Determinističko testiranje simulacijom (DST)** — zasejana, u potpunosti reproduktivna simulacija koja ubacuje greške, vremenske razlike i particionisanje mreže, ponavlja ih bajt po bajt i provodi rezultat kroz Porcupine proveravač linearnosti, tako da se Hajzenbag uhvaćen jednom može reprodukovati po komandi zauvek.
- **Dvonivovski rasporedivač po Omegi-modelu** — optimističko rasporedivanje s konkurentnošću uz podudaranje ClassAd, grupno rasporedivanje i preemptivno rasporedivanje s multiplikatorom vrednosti, dizajn deljenog stanja koji omogućava da više rasporedivača istovremeno pristupa jednom klasteru bez centralnog uskog grla.
- **Post-kvantna E2EE / poverljiva inferencija** — hibridna razmena ključeva X25519 + ML-KEM-768 s vezivanjem para ključeva za odgovor po zahtevu i AEAD s odbacivanjem ponovljenih poruka (kriptografski primitivi su stvarni i testirani; potpuna poverljiva razmena između više čvorova eksplicitno je PLANIRANA/ograničena).
- **Dokazno zasnovano poverenje** — čvorovi moraju *da dokažu* šta jesu: SPIFFE identitet, dokaz o GPU radu, zapečaćivanje uređaja, kontrolna kapija za izvoz i generisanje dokumentacije za usklađenost sa AI zakonom EU, tako da se poverenje zasniva na dokazima, a ne pretpostavlja na osnovu položaja u mreži.
- **Orkestracija svesna troškova i ugljeničnog otiska** — modeliranje ukupnih troškova vlasništva, rasporedivanje svesno ugljeničnog otiska, proširenje u oblak, N+K rezervni kapacitet i adapteri za tržišta u oblaku, čineći cenu i emisije primarnim ulaznim parametrima rasporedivanja umesto naknadnih razmišljanja.
- **Konsenzus s više Raft grupa** — Raft grupe po segmentima s lokalnim čitanjem kod nosioca zakupa za konzistentnost niske latencije, podržane STONITH ogradom (IPMI / EC2 / Azure / SBD) tako da se zaglavljeni čvor odlučno uklanja, a ne ostavlja da naruši stanje.
- **Mehaničke provere protiv odstupanja** — `archlint` prekida izgradnju čim dokumentovana komponenta mapira na putanju paketa koja ne postoji, a lanac dokumentacije održava bajt-preciznu konzistentnost između Markdowna, HTML, PDF i DOCX, tako da dokumentacija ne može tiho da laže o kodu.


## Najveći tehnički izazovi i kako smo ih rešili

- **"PASS-bluf" (testovi prolaze na nefunkcionalnim karakteristikama).** Režim greške koji je ceo projekat dizajniran da eliminiše: zeleni set testova nad šablonima. Rešeno obaveznim uparenim mutacionim testiranjem — svaka radna stavka nosi imenovani test-čuvar koji *mora da padne* pod nezavisnu mutaciju koda pre nego što se stavka označi kao završenom, tako da prolazni test dokazivo proverava stvarno ponašanje, a ne samo maketu.
- **Paritet između platformi (nema maketa samo za Linux).** Rešeno zajedničkim interfejsom podeljenim pomoću build tagova na autentične OS-specifične funkcionalnosti — Linux cgroup / `/proc` / WireGuard jezgra, macOS `sysctl` / `vm_stat` / IOKit / `wireguard-go` — a zatim unakrsno provereno pomoću nezavisnog OS orakla, tako da svaka platforma prikazuje stvarno stanje sistema umesto fikcije zasnovane na Linuxu.
- **Distribuirana ispravnost u uslovima grešaka.** Rešeno determinističkim simulacionim testiranjem i checkerom linearnosti koji generiše i reprodukuje particionisanje, padove sistema i vremenske razlike, podržano formalnim specifikacijama TLA+ koje precizno definišu invarijante konsenzusa i raspoređivanja pre nego što se napiše ijedna linija koda.
- **Dokumentacija i odstupanje arhitekture.** Rešeno pomoću `archlint`-a, koji prekida build ako postoji dokumentovani ali nepostojeći mapirani paket, i verifikacionog gejta `docs_chain` bez mogućnosti zaobilaženja — odstupanje je prekid builda, a ne zastarela viki stranica.
- **Pošteno definisanje obima nedovršenog posla.** Povratna sprega za multinodnu inferenciju s poverljivim podacima namerno je zaštićena tiketom i označena kao "još nije validirana od kraja do kraja" umesto da se predstavlja kao isporučena — ista disciplina primenjena je na ono što *još nije urađeno* kao i na ono što jeste.

## Tehnički stek

- **Go (go.mod: 1.25 / toolchain 1.26.4)** — jezik kontrolne ravni u radnom prostoru od ~30 modula; izabran zbog jeftine goroutine konkurentnosti i statičkih binarnih fajlova koji se identično raspoređuju od podatkovnog centra do ivice mreže.
- **Zig (0.14+) + C/C++** — korišćen tamo gde Go runtime predstavlja prepreku: za niskonivojske sistemske primitive i GPU jezgra kojima je potreban deterministički, alokacijski kontrolisan pristup hardveru.
- **gRPC + Protocol Buffers** — svaka međusubsystemska API (`api/v1/`) je tipizirani, verzionirani ugovor, tako da četrnaest mikroservisa evoluira bez međusobnog narušavanja ili ručnog kreiranja formata za prenos podataka.
- **Raft (etcd-raft) + SWIM gossip** — namerna podela: Raft prenosi stanje koje *mora* biti strogo konzistentno, dok SWIM gossip upravlja članstvom i otkrivanjem na velikoj skali gde bi konsenzus bio previše zahtevan.
- **PostgreSQL 16, Redis 7 klaster, etcd v3.5, SQLite** — pravo skladište za svaki zadatak: PostgreSQL za trajno relaciono stanje, Redis za vrući keš, etcd za koordinaciju, a ugrađeni SQLite za lokalni registar radnih stavki HXC čvora.
- **NATS 2.10 (JetStream), Kafka 4.0 (KRaft), RabbitMQ 3.13** — tri okosnice za poruke za tri vrste saobraćaja: NATS/JetStream za brzo interno slanje događaja, Kafka za trajna strujanja podataka visokog protoka, RabbitMQ za klasičnu sematiku brokera.
- **WireGuard mreža + ML-KEM-768/X25519 + AES-256-GCM/ChaCha20-Poly1305 + HKDF** — WireGuard za mršavu mrežu čvor-čvor, umotan u hibridni postkvantni handshake i AEAD zapise kako bi transport bio poverljiv i pred klasičnim i pred kvantnim napadačima.
- **SPIFFE + JWT (HS256) + RBAC zasnovan na opsezima + OPA** — slojevita identifikacija i autorizacija: SPIFFE za identitet radnog opterećenja, JWT za tokene, RBAC zasnovan na opsezima za grubu kontrolu pristupa, a OPA za izražavanje fino granulirane politike kao koda.
- **Prometheus v2.50, Grafana 10.4, Jaeger 1.55, W3C praćenje** — metričke vrednosti, kontrolne table i distribuirano praćenje s propagacijom W3C konteksta, tako da se zahtev može pratiti kroz servise i hardverske slojeve.
- **HashiCorp Vault 1.16** — tajne i kriptografski materijal drže se izvan koda i konfiguracije i izdaju pod revizijom.
- **Docker Compose, Kubernetes (kustomize, ojačani securityContext), Helm** — Compose za lokalno pokretanje, a Kubernetes/Helm s ojačanim securityContext-om za stvarne implementacije, s jednom definicijom koja se promoviše kroz različita okruženja.
- **React + TypeScript + Vite (Node 20+)** — brzo, tipizirano veb sučelje za sesije, terminale i iskorišćenost resursa.
- **TLA+** — formalna specifikacija invarijanata konsenzusa i raspoređivanja, tako da se najteže testabilna svojstva dokazuju na nivou dizajna pre same implementacije.


## Napomene o statusu i iskrenosti

- **Status: u razvoju.** Verzija je rana (`0.1.0-dev`). Nekoliko naprednih funkcija — potpuno poverljiva multi-čvorovna inferencija sa povratnom spregom, obračun na tržištu i popunjavanje rasporeda vođeno potvrdama — eksplicitno su označene kao ZAMIŠLJENE / infrastrukturno ograničene u repozitorijumu i **nisu** predstavljene kao potpuno funkcionalne. Pokrivenost je samoprijavljena.
- **Licenca: nije određena.** Nije jasno navedena; dijagram `Helm` sadrži neproverene privremene oznake `HelixCluster/HelixCluster` i URL-ove `helixcluster.io` koji se ne poklapaju sa stvarnim udaljenim resursima.
- Projekti u sklopu LLM steka (LLMOrchestrator, LLMProvider, LLMsVerifier) jesu odvojeni potmoduli, a ne model serveri koji se hostuju unutar klastera.

**Prioritetni nivo:** Helix-primer (LLM-infrastrukturni klaster — računarska osnova koja može da hostuje zadatke inferencije i računanja). Rangira se iza HelixTrack.

