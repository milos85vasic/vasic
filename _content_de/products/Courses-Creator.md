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

**Markdown rein, professioneller Videokurs raus – AI-optimiert, plattformübergreifend.**

## Zusammenfassung

Courses-Creator ist ein Toolkit, das Markdown-Skripte in professionelle Videokurse mit AI-gestützten Erweiterungen umwandelt: Inhaltsanreicherung durch mehrere LLM-Anbieter (OpenAI/Anthropic/Ollama), hochwertige TTS-Audioaufnahmen und Hintergrundmusik sowie Desktop-, Mobile- und Web-Player – alles Docker-bereitgestellt mit Prometheus/Grafana-Überwachung.

## Kurzbeschreibung

Verwandelt Markdown in fesselnde Videokurse. Eine Go-Verarbeitungsengine reichert Inhalte über verschiedene LLM-Anbieter an, generiert Sprachausgabe (Bark/SpeechT5 TTS) und Musik und liefert sie an Electron-Desktop-, React Native-Mobile- und React-Web-Player aus – mit vollständiger Docker-Bereitstellung und Überwachung.

## Ausführliche Beschreibung

Die Erstellung eines Videokurses ist normalerweise ein Aufwand, der einem kleinen Produktionsstudio entspricht: Drehbuch, Sprachaufnahme, Musikauswahl, Schnitt, Kodierung und schließlich die Entwicklung von Playern für jede Plattform, die Lernende nutzen könnten. Courses-Creator komprimiert diese gesamte Prozesskette in eine einzige Eingabe – ein Markdown-Skript – und einen einzigen Befehl. Im Zentrum steht ein Go-Kernprozessor, der eine vollständige Video-/Audio-Pipeline durchläuft: Er erweitert den geschriebenen Inhalt durch mehrere LLM-Anbieter (OpenAI, Anthropic und lokale Ollama), synthetisiert natürliche Sprachausgabe mit Text-to-Speech-Engines (Bark, SpeechT5), fügt Hintergrundmusik hinzu und setzt die Elemente zu fertigen Kursvideos zusammen. Die Aufgabe des Autors bleibt auf der Ebene von Ideen und Worten; das System übernimmt die Vertonung, die musikalische Untermalung und die Produktion. Da ein Kurs jedoch nur nützlich ist, wenn ihn die Nutzer auch abspielen können, ist die Auslieferung von vornherein plattformübergreifend konzipiert: eine Electron-Desktop-Creator-App, ein React Native-Mobile-Player und ein React-Web-Player, die alle vom selben REST-API- und Hintergrundjob-System gespeist werden – ein Backend, drei erstklassige Clients, keine Neuentwicklung pro Oberfläche.

Entscheidend ist, dass es sich hierbei um eine Produktionsinfrastruktur handelt, nicht um eine Demo. Das Backend umfasst PostgreSQL-Persistenz, Hintergrundjob-Verarbeitung, sodass lange TTS-/Video-Renderings den API nie blockieren, MCP-Serverimplementierungen für toolgestützte Erweiterungen, Prometheus-Metriken, JWT-Authentifizierung und einen Nginx-Reverse-Proxy – und das gesamte System wird als Docker-Compose-Bereitstellung mit Grafana/Prometheus-Überwachungsprofilen ausgeliefert, die sich in einem Schritt einrichten lassen. Die AI ist eine Erweiterungsebene, keine Abhängigkeit: Jeder LLM-Anbieter ist optional, sodass die Pipeline auch ohne API-Schlüssel für den Basisbetrieb läuft und Premium-Erweiterungen sofort aktiviert werden, sobald Schlüssel hinterlegt sind. Diese eine Entscheidung macht dasselbe Tool sowohl für Hobbyisten, die offline an einem Laptop arbeiten, als auch für Unternehmen, die ihren bevorzugten Anbieter einbinden, nutzbar – und die gesamte Medienpipeline darunter ist durch Unit-, Integrations- und End-to-End-Tests abgesichert, statt auf Vertrauen angewiesen zu sein.

## Warum wir es entwickelt haben

Die manuelle Produktion von Kursvideos ist langsam: Schreiben, Vertonen, musikalische Untermalung und Schnitt erfordern jeweils Aufwand und spezialisierte Tools. Courses-Creator bündelt diesen Prozess in einer Markdown-gesteuerten Pipeline, sodass aus einem einzigen Quellskript ein fertiger Kurs entsteht – wobei AI die Lücken füllt, die sonst von Hand geschlossen werden müssten.


## Warum es ein Game-Changer ist

Es verwandelt die Kursproduktion von einem spezialisierten, werkzeugintensiven Handwerk in eine reproduzierbare Software-Pipeline: Autorentools, AI-Anreicherung, Sprach- und Musikgenerierung sowie Multiplattform-Wiedergabe sind in einem einsatzbereiten Stack vereint. Die elegante Degradierung auf den Betrieb ohne API-Key ist die stille Superkraft – derselbe Code dient sowohl dem budgetbewussten Solo-Creator als auch einem Unternehmen mit Premium-Anbietervertrag, ohne dass dazwischen etwas umgeschrieben werden muss.

## Was innovativ ist

- Markdown-zu-Video-Pipeline mit austauschbarer Multi-LLM-Anreicherung (OpenAI/Anthropic/Ollama).
- Integrierte TTS-Generierung (Bark, SpeechT5) und Hintergrundmusik-Erstellung.
- MCP-Server-Implementierungen direkt im Verarbeitungsmodul für toolgestützte Optimierungen.
- Ein Backend, das drei erstklassige Clients bedient (Electron-Desktop, React Native-Mobile, React-Web).

## Herausforderungen & Lösungen

- **Aufwändige Medienverarbeitung:** gelöst durch eine Go-Pipeline plus Hintergrund-Jobverarbeitung, sodass lange TTS-/Video-Jobs den API-Betrieb nicht blockieren.
- **Optionale, aber leistungsstarke AI:** gelöst durch optionale und austauschbare LLM-Anbieter mit sanftem Fallback auf Basisfunktionen.
- **Multiplattform-Auslieferung:** gelöst durch einen gemeinsamen REST-API und drei dedizierte Player-Apps.
- **Betreibbarkeit:** gelöst durch Docker-Compose-Profile, Prometheus/Grafana sowie integrierte JWT-Authentifizierung.

## Technologie-Stack (Warum + Wie)

- **Go** – Kernverarbeitungsmodul, REST-API, Job-Scheduler, Pipeline (972K+ Bytes, Hauptsprache).
- **TypeScript / React** – Web-Player und gemeinsame Benutzeroberfläche.
- **Electron** – Desktop-Creator-App.
- **React Native** – Mobile-Player.
- **PostgreSQL** – Kurs-/Job-Persistenz.
- **LLM-Anbieter (OpenAI, Anthropic, Ollama)** – Inhaltsanreicherung.
- **TTS (Bark, SpeechT5)** – Sprachsynthese.
- **MCP-Server** – Tool-Integration im Verarbeitungsmodul.
- **Docker Compose + nginx** – Full-Stack-Deployment und Reverse-Proxy.
- **Prometheus + Grafana** – Monitoring.

> Hinweis: Die öffentliche README-Schnellstartanleitung verwendet einen Platzhalter-`your-org`-Klon URL.

