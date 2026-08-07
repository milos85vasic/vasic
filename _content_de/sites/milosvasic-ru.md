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

## Held

**AI-Ingenieur, der verifizierbare AI-Entwicklungssysteme aufbaut.**

Ich baue den Teil der AI-Entwicklung, der ein zuverlässiges Produkt von einer beeindruckenden Demo unterscheidet: die Multi-Provider-LLM-Infrastruktur, die den Ausfall eines Anbieters übersteht, die autonomen Agenten und Orchestrierungssysteme, die die Arbeit auf Kurs halten, sowie die Governance- und QS-Ebenen, die verhindern, dass ein AI-System heimlich falsche Versprechungen macht. Einen großen Sprachmodell in ein Produkt zu verwandeln, das man tatsächlich ausliefern kann, ist vor allem eine Frage der Disziplin – und genau diese Disziplin ist meine Spezialität. Mein Leitstern ist eine einzige Regel: Ein Feature ist erst dann fertig, wenn ein echter Nutzer es verwenden kann und es nachweisbare Belege dafür gibt.

## Zusammenfassung

Ich arbeite hauptsächlich in **Go**, mit **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift** und **Shell**, je nach Anforderungen der Aufgabe. Was mir am wichtigsten ist, ist die *Struktur* der Arbeit: kein Haufen einzelner Anwendungen, sondern eine Flotte – große Produktanwendungen, die auf Dutzenden kleinen, entkoppelten und unabhängig getesteten Modulen aufbauen, die alle ein gemeinsames technisches **Constitution** als Git-Submodul erben. Diese eine architektonische Entscheidung ist es, die das gesamte Werk skalierbar macht: Fehlerbehebungen und Verbesserungen verbreiten sich sofort über alle Projekte, neue Produkte setzen sich aus bereits bewährten Bausteinen zusammen, und jede beworbene Funktion wird durch einen beweisgenerierenden Test gestützt – nicht durch bloße Behauptungen. Es ist Ingenieurskunst, die darauf ausgelegt ist, im großen Maßstab von einer einzelnen Person vertrauenswürdig betrieben zu werden. Diese Seite führt von dieser Übersicht hin zu den einzelnen Projekten; jedes verweist auf seine vollständige Produktseite.

## Meine Arbeitsweise – Governance und Qualitätssicherung zuerst

Bevor es um die Produkte geht, steht die Disziplin, die ihnen zugrunde liegt:

- **HelixConstitution** – Ich pflege ein universelles, vererbbares Regelwerk für die technische Entwicklung, das als Git-Submodul über eine Flotte von mehr als 140 Repositories verteilt ist. Es kodifiziert Anti-Bluff-Nachweisschranken, Immunität gegen falsch-positive Ergebnisse, Datensicherheit, Host-Sicherheit und Abdeckungsregeln; Projekte können es verschärfen, aber niemals abschwächen, und jede Governance-Schranke wird von einem Mutationstest begleitet, der beweist, dass die Schranke selbst funktioniert. → siehe die HelixConstitution-Produktseite.
- **HelixQA** – Ich entwickle Anti-Bluff-Qualitätssicherungs-Orchestrierung, die Testbanken abarbeitet und vollautonome, LLM- und bildgesteuerte QS-Sitzungen auf Android, Android TV, Web und Desktop durchführt, wobei ein Test nur dann als BESTANDEN gilt, wenn er Laufzeitbeweise erfasst hat. → siehe die HelixQA-Produktseite.

## Meine Arbeit in der Helix-Familie

Die Helix-Reihe deckt den gesamten AI-Entwicklungszyklus ab. Nach Priorität geordnet:

- **HelixTrack** – eine freiheitliche Alternative zu JIRA; das Flaggschiff der Helix-Track-Linie.
- **HelixAgent** – ein Ensemble-LLM-Dienst mit mehrstufiger Modelldebatte und verifizierungsbasierter Anbieterauswahl.
- **HelixCode** – eine verteilte AI-Entwicklungsplattform, die Aufgaben auf SSH-gesteuerte Worker mit automatischer Checkpoint-/Rollback-Funktion aufteilt.
- **HelixLLM** – ein einzelnes Binary mit sechs Modi, das OpenAI- und Anthropic-kompatible APIs über HTTP/3 bereitstellt, mit lokaler llama.cpp-Inferenz und einer bewerteten Fallback-Kette.
- **HelixCluster** – ein verteiltes Betriebssystem für AI-Computing, von Rechenzentrums-GPUs bis zu Edge-Handhelds.
- **LLMProvider** – eine einheitliche Schnittstelle für 43 Anbieter mit integrierten Schutzschaltern, Wiederholungsversuchen und Gesundheitsüberwachung.
- **LLMOrchestrator** – eine zentrale Steuerungsebene für jeden kopflosen CLI-Coding-Agenten.
- **LLMsVerifier** – verifizieren, überwachen, optimieren: die einzige Quelle der Wahrheit für LLM-/Anbieter-/Verifizierungsmetadaten.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** – Agentengedächtnis, kontrollierte Agentenfähigkeiten, spezifikationsgetriebene Entwicklung, Aufbau von AI-Anwendungen, verifizierte Buchübersetzungen, Zero-Trust-Terminals, föderiertes Git, ausfallsichere OTA-Updates und selbstgehostetes Cloud-Gaming.


## Meine Arbeit im Bereich vasic-digital-Tools

Produktreife Werkzeuge, die ich entwickelt habe und pflege (jedes verfügt über eine vollständige Produktseite):

- **Catalogizer** — Multiprotokoll-fähig (SMB/FTP/NFS/WebDAV/lokal), verschlüsselt, selbsthostbares Medienverwaltungssystem mit einer Go/Gin-API- und React-Benutzeroberfläche.
- **Courses-Creator** — Eine Markdown-zu-Video-Kurs-Pipeline mit Multi-LLM-Anreicherung, TTS sowie Desktop-, Mobile- und Web-Playern.
- **VisionEngine** — Ein entkoppeltes Go-Toolkit, das klassische Computer Vision mit Multi-Provider-LLM-Vision für UI-Analysen und Navigationsgraphen verbindet.
- **DocProcessor** — Wandelt Dokumentation in eine überprüfbare Funktionslandkarte für QA-Automatisierung um (LLM- oder heuristische Extraktion).
- **Docs Chain** — Ein inhaltsgehashtes, bidirektionales, atomares Dokumenten-/Datenbank-Synchronisierungssystem.
- **Herald** — Zuverlässige Multi-Channel-Benachrichtigungen mit natürlichsprachlicher Drei-Stufen-Intent-Auflösung.
- **task_bridge** — Ein entkoppeltes, bidirektionales Aufgaben-/Board-Synchronisierungssystem (P1-Grundgerüst; Synchronisierungslogik in Arbeit).
- **Vasic Digital Wiederverwendbare Modul-Suite** — Die `digital.vasic.*`-„Standardbibliothek" für Infrastruktur, AI-Primitiven und Sicherheitsmodule.

## Infrastruktur-Hintergrund (Server Factory)

Vor der AI-Reihe entwickelte ich meine DevOps-Toolchain: **Mail Server Factory** (deklarative JSON → vollständig provisionierte, dockerisierte Mailserver mit 439 bestandenen Tests und einem sauberen SonarQube-Gate), das **Server Factory Core Framework**, auf dem es aufbaut, sowie VM-Image-Tools (**Qemu-Utils**, **Parallels-Utils**) und unterstützende Service-Fabriken.

## In einem Satz

Ich liefere keine grünen Häkchen — ich liefere AI-Systeme mit dem Nachweis, dass sie funktionieren, und der Governance, die sie so erhält.

## Kontakt

Offen für Positionen im Bereich Senior-AI-/Platform-Engineering weltweit.

- **E-Mail:** [milos85vasic@gmail.com](mailto:milos85vasic@gmail.com) · [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [milos85vasic](https://github.com/milos85vasic)
- **Telegram:** [@milos85vasic](https://t.me/milos85vasic)

