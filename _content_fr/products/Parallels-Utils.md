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

**Compressez, publiez et réutilisez vos images VM Parallels sur n’importe quelle machine.**

## Résumé

Parallels-Utils est une boîte à outils Server Factory dédiée à la gestion des images de machines virtuelles Parallels (macOS) : compression et synchronisation des « matrices » d’images utilisées pour le développement et les tests, publication vers un point d’accès distant, et récupération/exécution sur plusieurs postes de travail ou serveurs. Utilisable en autonomie ou intégré à Server Factory.

## Description courte

Une boîte à outils Shell/Python pour le cycle de vie des images VM Parallels sous macOS. Elle compresse et synchronise les images Parallels, les publie vers un point d’accès distant, puis les récupère et les exécute sur plusieurs ordinateurs — le tout piloté par des fichiers de configuration simples, utilisable indépendamment ou au sein de Server Factory.

## Description détaillée

Parallels-Utils répond à un problème concret en DevOps pour le développement sous macOS : les équipes créent des « matrices » de machines virtuelles Parallels (différentes versions de systèmes d’exploitation/configurations pour le développement et les tests), et ces images doivent être compressées, publiées, récupérées et exécutées de manière cohérente sur plusieurs machines. La boîte à outils offre précisément ce cycle de vie. Un mécanisme de synchronisation compresse les images Parallels et les maintient à jour ; un mécanisme de publication les envoie vers un point d’accès distant ; et un mécanisme de récupération permet à n’importe quel poste ou serveur de télécharger les images publiées et de les exécuter en tant que VM. La configuration est volontairement simple et basée sur des fichiers : `image_location.settings` définit l’emplacement des images dans le système de fichiers, `image_provider.settings` spécifie la base URL des images publiées, et `image_sync.sh` définit le script de téléversement — des exemples sont fournis dans un répertoire `Examples`. Les opérateurs utilisent `publish_images.sh` pour publier et `run.sh` pour lancer les VM. L’outil nécessite Parallels pour la version macOS correspondante et Python 3. Conçu pour un double usage, il peut fonctionner dans le cadre d’un projet Server Factory plus large ou en totale autonomie, reflétant la philosophie de découplage de l’organisation. Il inclut même un lien vers un tutoriel vidéo. Intégré à la famille Server-Factory, il complète Qemu-Utils (l’équivalent Linux/QEMU), offrant ainsi une gestion des images VM à la fois pour macOS/Parallels et pour les environnements multiplateformes/QEMU.

## Pourquoi nous l’avons créé

Partager des environnements de développement et de test VM cohérents au sein d’une équipe est fastidieux : les images sont volumineuses, et chaque machine doit disposer de la même matrice. Parallels-Utils automatise la compression, la publication et la récupération pour qu’un ensemble canonique de VM Parallels soit reproductible partout.

## Pourquoi c’est révolutionnaire

Il transforme des images Parallels lourdes et peu maniables en un ensemble d’artefacts publiables et synchronisables, que n’importe quelle machine peut télécharger et exécuter. Ainsi, un environnement de développement/test canonique cesse d’être quelque chose que chaque ingénieur reconstruit manuellement pour devenir une ressource que l’on récupère simplement. Le tout avec une configuration minimaliste via des fichiers de paramètres et sans dépendre du reste de Server Factory, respectant ainsi la philosophie de découplage de l’organisation : utile en soi, et parfaitement intégré à la chaîne d’outils globale.

Contenu

## Ce qui est innovant

- Compression et synchronisation des « matrices » d'images Parallels pour le développement et les tests.
- Workflow de publication/récupération permettant la réutilisation des images sur plusieurs ordinateurs.
- Configuration pilotée par fichiers de paramètres (emplacement/fournisseur/synchronisation) avec des exemples fournis.
- Double usage : autonome ou en tant que composant de Server Factory.

## Défis et solutions

- **Distribution d'images volumineuses** : résolu par la compression associée à un workflow de publication vers un point distant et de récupération.
- **Reproductibilité sur différentes machines** : résolu grâce aux paramètres de fournisseur et d'emplacement, garantissant que chaque hôte résout le même ensemble d'images.
- **Facilité d'utilisation** : résolu par des scripts simples `publish_images.sh` / `run.sh` et des fichiers de paramètres d'exemple.

## Pile technologique (pourquoi et comment)

- **Shell** — les scripts de publication/exécution/synchronisation (langage principal, ~5,3 Ko).
- **Python 3** — outils d'assistance (dépendance requise, ~3 Ko).
- **Parallels (macOS)** — le backend de virtualisation géré.
- **Fichiers de paramètres (`.settings`)** — configuration déclarative pour l'emplacement, le fournisseur et la synchronisation.

> Remarque : GitHub indique que le dépôt est un fork au sein de l'organisation Server-Factory. Spécifique à macOS et de niche. Sans lien avec AI.

