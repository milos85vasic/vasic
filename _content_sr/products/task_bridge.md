---
name: task_bridge
slug: task-bridge
tier: vasic-util-secondary
order: 26
status: P1 scaffold (interfaces & decoupling boundary in place; sync logic and live ClickUp calls not yet implemented)
license: UNVERIFIED
private: false
tech:
  - Go
  - SQLite (workable-items SSoT)
  - raksul/go-clickup (MIT dependency)
  - HMAC-SHA256 webhook verification
  - cron + webhooks
  - pkg/config runtime injection boundary
repos:
  - https://github.com/vasic-digital/task_bridge
diagrams:
  - Three-way sync triangle (SQLite SSoT ↔ tracker docs ↔ ClickUp)
  - Decoupling boundary (consumer injects creds/IDs → generic engine)
  - Conflict resolution flow (last-edit-wins outcomes)
  - Daemon architecture (webhook receiver + cron reconcile)
---

**Vaša radna tabla i vaš izvor istine, besprekorno sinhronizovani — u oba smera.**

## Sažetak

task_bridge je generički, odvojeni, dvosmerni motor za sinhronizaciju zadataka/tabli u Go. Održava sinhronizaciju izvodljivih stavki projekta (SQLite) kao izvora istine sa dokumentima za praćenje i udaljenom tablom (prvi cilj: ClickUp; planirani Jira/Linear) koristeći determinističko pravilo poslednje izmene pobeđuje, prvo suvo izvođenje i semantiku koja nikada ne kvari podatke.

## Kratak opis

Projektno-agnostički potmodul Go koji dvosmerno sinhronizuje izvodljive stavke SQLite (SSoT) ↔ dokumente za praćenje ↔ udaljenu tablu (prvi ClickUp). Determinističko pravilo poslednje izmene pobeđuje, prvo suvo izvođenje, HMAC-verifikovani vebhukovi; svaki kredencijal i ID ubacuje korisnik tokom izvršavanja.

## Detaljan opis

Svaki tim na kraju vodi dve knjige istog posla: pravu — kod, dokumentaciju, internu bazu — i onu koju prate menadžeri, tablu poput ClickUp-a. One se razilaze čim se bilo koja strana promeni, a ručno usklađivanje je upravo ona dosadna, sklona greškama zaduženja koja niko pouzdano ne obavlja. task_bridge je stvoren da ukloni taj jaz tretirajući sva tri prikaza kao jedan sistem koji se održava u savršenoj sinhronizaciji: **izvodljive stavke projekta (SQLite) kao jedinstveni izvor istine**, **dokumentaciju za praćenje** i **udaljenu tablu** — prvi podržani sistem je ClickUp, dok su Jira i Linear planirani za budućnost. Sinhronizacija je deterministička (poslednja izmena pobeđuje), prvo se izvršava suva proba, a osmišljena je oko jedne nepregovorive garancije: nikada neće oštetiti ili izgubiti podatke, niti će tiho ostaviti jednu stranu zastarelom. U domenu gde nepažljiva sinhronizacija može pregaziti nedeljni rad, ta sigurnosna pozicija je čitava poenta. Arhitektonski, radi se o strogo definisanom potmodulu koji koriste drugi projekti i potpuno je agnostičan u odnosu na projekat, u skladu sa ugovorom o odvajanju iz ustava (§11.4.28): ne isporučuje nikakve projektno-specifične vrednosti, a svaki kredencijal, ID table/foldera, polje ključa stavke i putanja do baze podataka ubacuje korisnik tokom izvršavanja putem `pkg/config.Config`. Modul je jasno slojevit: CLI (`reconcile`/`push`/`pull`/`resolve`/`status`/`conflicts`/`init`) i dugoročni demon (primalac vebhukova + cron sinhronizacija); tanak klijentski omotač oko MIT-licenciranog `raksul/go-clickup`; rezolver koji pretvara URL-ove tabela/foldera u ID-e putem uživo API sondi (bez nagađanja URL gramatike); maper između lokalnih izvodljivih stavki i polja udaljenih zadataka; motor za sinhronizaciju po principu poslednje izmene sa eksplicitnim ishodima sukoba; i primalac vebhukova koji verifikuje `X-Signature` HMAC-SHA256. Iskren je po pitanju zrelosti: ovo je P1 skelet — raspored, interfejsi, ulazne tačke i granica odvajanja su postavljeni, ali logika sinhronizacije i pozivi uživo ka ClickUp-u još nisu implementirani (svaki stub vraća eksplicitnu grešku *not-implemented*, prema pravilu bez lažnih podataka).

## Zašto smo ga napravili

Timovi čuvaju „pravu" sliku posla u kodu/dokumentaciji, dok menadžeri žive na tabli poput ClickUp-a — i one se stalno razilaze. task_bridge ih čini jednim sistemom, sinhronizujući deterministički i bezbedno tako da nijedna strana ne postane zastarela ili netačna.

## Zašto je ovo revolucionarno

Dvosmerna sinhronizacija tabela obično je jednokratna, čvrsto povezana integracija koju svaki tim loše ponovo izgrađuje. task_bridge je preoblikuje u ponovo upotrebljivu biblioteku s ubrizganim poverljivim podacima i ugrađenim strogim garancijama bezbednosti podataka — prvo simulacija, determinističko rešavanje sukoba poslednjom izmenom, HMAC-verifikovani događaji — tako da svaki projekat može da usvoji pouzdanu integraciju tabela ubrizgavanjem konfiguracije umesto pisanja još jednog krhkog konektora povezanog s internim strukturama.

## Šta je inovativno

- Trostruka dvosmerna sinhronizacija: SQLite SSoT ↔ dokumenti tragača ↔ udaljena tabela.
- Potpuna razdvojenost (§11.4.28): nijedna vrednost projekta nije ugrađena; sve se ubrizgava tokom izvršavanja.
- Resolucija Live-API URL→ID umesto krhkog parsiranja URL-gramatike.
- HMAC-SHA256-verifikovani unos vebhukova za događaje u realnom vremenu.

## Izazovi i rešenja

- **Bezbednost podataka između tri izvora:** rešeno determinističkim rešavanjem sukoba poslednjom izmenom, prvom simulacijom i eksplicitnim ishodima konflikata.
- **Ponovna upotrebljivost bez sprezanja:** rešeno preko granice ubrizgavanja `pkg/config` (nema isporučenih specifičnosti projekta).
- **Pouzdana identifikacija tabela:** rešeno razrešavanjem URL-ova u ID-ove putem Live-API sondi.
- **Iskrena skela:** rešeno tako što neimplementirani stubovi vraćaju eksplicitne greške tipa „nije implementirano" (nema lažnih rešenja).

## Tehnički stek (zašto + kako)

- **Go** — motor, CLI (`cmd/task_bridge`) i demon (`cmd/task_bridged`).
- **SQLite** — jedinstveni izvor istine za radne stavke.
- **`raksul/go-clickup` (MIT)** — omotač za ClickUp transport.
- **HMAC-SHA256** — verifikacija potpisa vebhukova.
- **cron + vebhukovi** — usklađivanje demona + unos događaja u realnom vremenu.
- **`pkg/config`** — granica ubrizgavanja poverljivih podataka/ID-ova tokom izvršavanja.

> Iskrenost o statusu: ovo je **P1 skela** — logika sinhronizacije još nije implementirana. Ne predstavljati kao isporučeno rešenje.

