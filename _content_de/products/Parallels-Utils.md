---
name: Parallels-Utils
slug: parallels-utils
tier: serverfactory-tertiary
order: 32
status: active (niche, macOS-specific Shell/Python toolkit)
license: UNVERIFIED
private: false
tech:
  - Shell (~5.3K bytes)
  - Python 3 (~3K bytes)
  - Parallels (macOS)
  - Settings files (.settings)
repos:
  - https://github.com/Server-Factory/Parallels-Utils
diagrams:
  - Image lifecycle (build → compress → publish → retrieve → run)
  - One provider endpoint → many workstations pulling the same image matrix
  - Settings-file map (location/provider/sync) feeding the scripts
---

**Komprimieren, veröffentlichen und wiederverwenden Sie Ihre Parallels-VM-Images auf jedem Rechner.**

---

## Zusammenfassung

Parallels-Utils ist ein Server Factory-Toolkit zur Verwaltung von Parallels-(macOS)-Virtual-Machine-Images: Es komprimiert und synchronisiert Image-„Matrizen", die für Entwicklung und Tests genutzt werden, veröffentlicht sie auf einem Remote-Endpunkt und ermöglicht deren Abruf und Ausführung auf mehreren Arbeitsstationen oder Servern. Kann eigenständig oder als Teil von Server Factory verwendet werden.

---

## Kurzbeschreibung

Ein Shell/Python-Toolkit für den Lebenszyklus von Parallels-VM-Images unter macOS. Es komprimiert und synchronisiert Parallels-Images, veröffentlicht sie auf einem Remote-Endpunkt und ruft sie ab, um sie auf mehreren Rechnern auszuführen – gesteuert durch einfache Konfigurationsdateien, nutzbar unabhängig oder innerhalb von Server Factory.

---

## Ausführliche Beschreibung

Parallels-Utils löst ein praktisches DevOps-Problem für die macOS-basierte Entwicklung: Teams erstellen „Matrizen" von Parallels-Virtual Machines (verschiedene Betriebssysteme/Konfigurationen für Entwicklung und Tests), und diese Images müssen konsistent komprimiert, veröffentlicht, abgerufen und auf vielen Rechnern ausgeführt werden. Das Toolkit deckt genau diesen Lebenszyklus ab. Ein Synchronisationsmechanismus komprimiert Parallels-Images und hält sie aktuell; ein Veröffentlichungsmechanismus lädt die Images auf einen Remote-Endpunkt hoch; und ein Abrufmechanismus ermöglicht es jeder Arbeitsstation oder jedem Server, die veröffentlichten Images zu beziehen und als VMs auszuführen. Die Konfiguration ist bewusst einfach und dateibasiert: `image_location.settings` definiert den Speicherort der Images im Dateisystem, `image_provider.settings` legt die Basis-URL für veröffentlichte Images fest, und `image_sync.sh` definiert das Upload-Skript – mit Beispielen im Verzeichnis `Examples`. Anwender nutzen `publish_images.sh` zur Veröffentlichung und `run.sh` zum Starten der VMs. Vorausgesetzt werden Parallels für die entsprechende macOS-Version und Python 3. Das Toolkit ist für den doppelten Einsatz konzipiert: Es kann als Teil eines größeren Server Factory-Projekts oder vollständig eigenständig betrieben werden – ganz im Sinne der organisationsweiten Entkopplungsphilosophie. Selbst ein kurzes Video-Tutorial ist enthalten. Als Teil der Server-Factory-Familie ergänzt es Qemu-Utils (das Linux/QEMU-Äquivalent) und ermöglicht so das VM-Image-Management sowohl für macOS/Parallels- als auch für plattformübergreifende/QEMU-Backends.

---

## Warum wir es entwickelt haben

Die gemeinsame Nutzung konsistenter VM-Entwicklungs- und Testumgebungen in einem Team ist mühsam – die Images sind groß, und jeder Rechner benötigt dieselbe Matrix. Parallels-Utils automatisiert Komprimierung, Veröffentlichung und Abruf, sodass ein einheitlicher Satz von Parallels-VMs überall reproduzierbar ist.

---

## Warum es ein Game-Changer ist

Es verwandelt schwere, unhandliche Parallels-Images in ein veröffentlichbares, synchronisierbares Artefakt-Set, das jeder Rechner abrufen und ausführen kann – sodass eine einheitliche Entwicklungs- und Testumgebung nicht mehr von jedem Entwickler manuell neu aufgebaut werden muss, sondern einfach bezogen wird. Möglich wird das durch triviale Konfigurationsdateien und ohne Abhängigkeit vom Rest von Server Factory – ganz im Einklang mit der Entkopplungsphilosophie der Organisation: nützlich für sich allein, ein guter Baustein im größeren Tool-Ökosystem.


## Was innovativ ist

- Komprimierung + Synchronisierung der Parallels-„Matrizen" für Entwicklung und Test.
- Veröffentlichungs-/Abruf-Workflow, sodass Images auf mehreren Rechnern wiederverwendet werden können.
- Konfiguration über Einstellungsdateien (Speicherort/Anbieter/Synchronisierung) mit mitgelieferten Beispielen.
- Doppelte Nutzung: eigenständig oder als Komponente von Server Factory.

## Herausforderungen & Lösungen

- **Verteilung großer Images:** gelöst durch Komprimierung sowie einen Workflow zum Veröffentlichen auf einem Remote-Endpunkt und anschließenden Abruf.
- **Reproduzierbarkeit auf verschiedenen Rechnern:** gelöst durch Anbieter-/Speicherort-Einstellungen, sodass jeder Host dieselbe Image-Sammlung auflöst.
- **Benutzerfreundlichkeit:** gelöst durch einfache Skripte (`publish_images.sh` / `run.sh`) und Beispiel-Einstellungsdateien.

## Technologie-Stack (Begründung + Umsetzung)

- **Shell** — die Veröffentlichungs-/Ausführungs-/Synchronisierungsskripte (Hauptsprache, ~5,3 KB).
- **Python 3** — unterstützende Tools (erforderliche Abhängigkeit, ~3 KB).
- **Parallels (macOS)** — das verwaltete Virtualisierungs-Backend.
- **Einstellungsdateien (`.settings`)** — deklarative Konfiguration für Speicherort, Anbieter und Synchronisierung.

> Hinweis: GitHub kennzeichnet das Repository als Fork innerhalb der Server-Factory-Organisation. Spezifisch für macOS. Kein Bezug zu AI.

