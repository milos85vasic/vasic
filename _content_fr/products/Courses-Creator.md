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

**Markdown en entrée, formation vidéo professionnelle en sortie — améliorée par AI, multiplateforme.**

## Résumé

Courses-Creator est une boîte à outils qui transforme des scripts en Markdown en formations vidéo professionnelles, enrichies par la technologie AI : enrichissement multi-LLM du contenu (OpenAI/Anthropic/Ollama), voix off TTS de haute qualité et musique d’ambiance, avec des lecteurs pour ordinateur, mobile et web — le tout déployé en Docker avec surveillance Prometheus/Grafana.

## Description courte

Transforme le Markdown en formations vidéo captivantes. Un moteur de traitement Go enrichit le contenu via plusieurs fournisseurs LLM, génère des narrations (Bark/SpeechT5 TTS) et de la musique, puis les diffuse sur des lecteurs Electron pour ordinateur, React Native pour mobile et React pour web, avec un déploiement Docker complet et une surveillance intégrée.

## Description détaillée

Créer une formation vidéo représente habituellement le travail d’un petit studio de production : scénarisation, enregistrement de la voix off, recherche de musique, montage, encodage, puis développement de lecteurs pour chaque plateforme susceptible d’être utilisée par les apprenants. Courses-Creator condense toute cette chaîne en un seul élément d’entrée — un script en Markdown — et une seule commande. Au cœur du système se trouve un processeur central Go qui exécute une chaîne complète de traitement vidéo et audio : il enrichit le contenu écrit via plusieurs fournisseurs LLM (OpenAI, Anthropic et Ollama local), synthétise une narration naturelle grâce à des moteurs de synthèse vocale (Bark, SpeechT5), ajoute une musique d’ambiance, puis assemble le tout en vidéos de formation finalisées. Le rôle de l’auteur se limite à l’élaboration des idées et des mots ; le système se charge de la voix, de la bande-son et de la production. Et comme une formation n’a d’utilité que si les apprenants peuvent la consulter, la diffusion est conçue pour être multiplateforme : une application de création Electron pour ordinateur, un lecteur React Native pour mobile et un lecteur React pour web, tous alimentés par le même système REST API et de traitement en arrière-plan — un backend unique, trois clients de premier ordre, sans réimplémentation pour chaque support.

Surtout, il s’agit d’une infrastructure de production, et non d’une simple démonstration. Le backend gère la persistance PostgreSQL, le traitement des tâches en arrière-plan afin que les rendus TTS/vidéo longs n’entravent jamais le API, des implémentations serveur MCP pour l’enrichissement assisté par outils, des métriques Prometheus, une authentification JWT, ainsi qu’un reverse proxy nginx — le tout déployé en Docker Compose avec des profils de surveillance Grafana/Prometheus que vous pouvez activer en une seule étape. La couche AI est un module d’amélioration, et non une dépendance : chaque fournisseur LLM est optionnel, ce qui permet à la chaîne de traitement de fonctionner sans clés API pour un usage basique, tout en activant les enrichissements premium dès que les clés sont fournies. Cette seule décision rend l’outil adapté aussi bien à un passionné travaillant hors ligne sur un ordinateur portable qu’à une entreprise intégrant son fournisseur préféré — et l’ensemble du pipeline multimédia sous-jacent est couvert par des tests unitaires, d’intégration et de bout en bout, plutôt que de reposer sur la confiance.

## Pourquoi nous l’avons créé

Produire manuellement des vidéos de formation est un processus lent : rédaction, narration, composition musicale et montage demandent chacun des efforts et des outils spécialisés. Courses-Creator réduit cette chaîne à un pipeline piloté par Markdown, où un seul script source devient une formation produite, avec AI comblant automatiquement les étapes que les humains devraient autrement effectuer à la main.

## Pourquoi c'est un tournant

Il transforme la production de cours, passant d'un artisanat spécialisé et multi-outils à un pipeline logiciel reproductible : rédaction, enrichissement AI, génération de narration et de musique, ainsi que la lecture multiplateforme s'intègrent tous dans une seule pile déployable. La dégradation élégante vers un fonctionnement sans clé API est son atout discret – le même codebase sert aussi bien un créateur solo soucieux de son budget qu'une entreprise sous contrat avec un fournisseur premium, sans rien à réécrire entre les deux.

## Ce qui est innovant

- Pipeline Markdown vers vidéo avec enrichissement multi-LLM pluggable (OpenAI/Anthropic/Ollama).
- Génération intégrée de TTS (Bark, SpeechT5) et de musique d'ambiance.
- Implémentations de serveurs MCP au sein du moteur de traitement pour un enrichissement assisté par outils.
- Un backend unique alimentant trois clients de premier plan (Electron desktop, React Native mobile, React web).

## Défis et solutions

- **Traitement lourd des médias** : résolu grâce à un pipeline Go associé à un traitement en arrière-plan, de sorte que les tâches longues de TTS/vidéo n'encombrent pas la API.
- **Enrichissement AI optionnel mais puissant** : résolu en rendant les fournisseurs LLM optionnels et modulables, avec un retour élégant vers les fonctionnalités de base.
- **Diffusion multiplateforme** : résolu via une API REST partagée et trois applications de lecture dédiées.
- **Exploitabilité** : résolu avec des profils Docker Compose, Prometheus/Grafana, et une authentification JWT intégrée.

## Pile technologique (pourquoi + comment)

- **Go** – moteur de traitement principal, API REST, exécuteur de tâches, pipeline (972K+ octets, langage dominant).
- **TypeScript / React** – lecteur web et interface utilisateur partagée.
- **Electron** – application de création pour ordinateur.
- **React Native** – lecteur mobile.
- **PostgreSQL** – persistance des cours/tâches.
- **Fournisseurs LLM (OpenAI, Anthropic, Ollama)** – enrichissement de contenu.
- **TTS (Bark, SpeechT5)** – synthèse de narration.
- **Serveurs MCP** – intégration d'outils au sein du moteur.
- **Docker Compose + nginx** – déploiement full-stack et proxy inverse.
- **Prometheus + Grafana** – supervision.

> Remarque : le guide de démarrage rapide du README public utilise un clone URL avec un espace réservé `your-org`.

