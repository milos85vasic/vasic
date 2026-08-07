---
name: HelixGitpx
slug: helixgitpx
tier: helix-primary
order: 17
status: shipped
license: TBD
private: false
tech:
  - Go monorepo
  - Angular 19 + Nx
  - Kotlin Multiplatform + Compose
  - Kubernetes + Helm + Argo CD + Kustomize
  - OPA (Rego)
  - Docusaurus
  - Astro
  - mise
repos:
  - https://github.com/HelixDevelopment/HelixGitpx
diagrams:
  - Hub-and-spoke federation — one source-of-truth hub pushing to a ring of host logos (GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit, GitFlic, GitVerse, Gitee, Forgejo, SourceHut).
  - Conflict-resolution flow — divergent mirrors → policy/AI resolver → reconciled single truth.
  - Delivery stack — Go platform + Angular web + KMP clients over a Kubernetes/Argo platform layer.
---

# HelixGitpx

**Une source unique de vérité, reflétée partout — Git fédéré sur une douzaine d’hôtes.**

## Résumé

HelixGitpx (Helix Git Proxy eXtended) est un proxy Git fédéré qui maintient une source unique de vérité reflétée sur plusieurs hôtes Git en amont et résout les conflits inévitables grâce à des flux assistés par politique et par AI. Il a atteint la version 1.0.0 GA.

## Description courte

HelixGitpx est un proxy Git fédéré qui reflète une source unique de vérité sur une douzaine d’hôtes Git ou plus — GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit et bien d’autres — et résout les conflits de synchronisation grâce à des flux assistés par politique et par AI. Livré en version 1.0.0 GA.

## Description longue

HelixGitpx — « Helix Git Proxy eXtended » — est un proxy Git fédéré qui maintient une source unique de vérité reflétée sur plusieurs hôtes Git en amont et résout les conflits qui surviennent inévitablement dès qu’un même dépôt existe en plusieurs endroits. Ses hôtes en amont pris en charge couvrent l’ensemble de l’écosystème Git : GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut, ainsi que les dépôts génériques Git-over-HTTPS. Là où un simple `git push` vers une douzaine de dépôts distants échouerait purement et simplement ou, pire, laisserait les miroirs diverger silencieusement, HelixGitpx intervient avec des flux de résolution assistés par politique et par AI, qui ramènent les divergences vers une vérité unique et autoritaire.

Le projet est en version 1.0.0 GA, avec des jalons marqués de `m1-foundation` à `m8-ga` — un parcours complet de la fondation à la disponibilité générale. Il est conçu en trois niveaux d’un même produit : un monorepo Go (une plateforme accompagnée de dix-huit services, d’outils de génération de code et de scaffolding) hébergeant le moteur de fédération ; une application web Angular 19 + Nx ; et des interfaces clientes Kotlin-Multiplatform + Compose, qui offrent des expériences natives sur Android, iOS et Desktop à partir d’un code partagé. La livraison de la plateforme est native Kubernetes dans son essence — avec des charts Helm, des applications Argo CD, des overlays Kustomize, du SQL et des politiques OPA — et les pipelines CI sont protégés par des déclenchements explicites pour éviter tout déploiement accidentel. La documentation publique est publiée sous forme de site Docusaurus (docs.helixgitpx.io), accompagnée d’un site marketing Astro (helixgitpx.io).

La gouvernance est stricte et régie par une constitution, et c’est une caractéristique, pas une simple formalité : le document porteur est le Constitution du projet, dont l’Article II impose une matrice de tests à sept types, avec une couverture à 100 % *par type et par module modifié*, les mocks n’étant autorisés que dans les tests unitaires, sans qu’aucun test ne soit jamais ignoré. Un vérificateur unique exécute toutes les vérifications d’artefacts ainsi que `go vet` et `go test` sur l’ensemble de l’espace de travail, et chaque push est répercuté sur tous les hôtes en amont configurés — de sorte que « les miroirs sont synchronisés » est une garantie que le système impose à chaque commit, plutôt qu’une vérification laissée à la mémoire humaine.

## Pourquoi nous l’avons créé

Maintenir l’authenticité d’un dépôt sur plusieurs hôtes Git — pour des raisons de redondance, de souveraineté ou d’accès à des plateformes régionales — est une tâche fragile et manuelle, et les miroirs divergents sont difficiles à réconcilier. HelixGitpx a été conçu pour faire de la réplication multi-hôtes une capacité native, consciente des conflits.

Contenu

## Pourquoi c'est un changement de paradigme

Il transforme le modèle « pousser vers plusieurs dépôts distants et croiser les doigts » — ce statu quo fragile et manuel — en une fédération gouvernée, dotée d'une source unique de vérité et d'une résolution automatisée des conflits, basée sur des politiques et AI. Et il le fait sur un éventail exceptionnellement large de plateformes hôtes, incluant délibérément les plateformes régionales (GitFlic, GitVerse, Gitee) que la plupart des outils ignorent discrètement. Ainsi, la redondance, la souveraineté des données et l'accès à ces écosystèmes cessent d'être un fardeau de maintenance pour devenir une capacité unique, configurée une seule fois.

## Ce qui est innovant

- **Large couverture des dépôts amont** — plus d'une douzaine d'hébergeurs Git, de GitHub et GitLab aux plateformes régionales comme GitFlic, GitVerse et Gitee, tous normalisés derrière un seul proxy.
- **Résolution des conflits assistée par politiques et AI** — les divergences sont réconciliées par un moteur de politiques et un résolveur AI, et non par un humain comparant manuellement les miroirs.
- **Fédération à source unique de vérité** — un modèle de poussée vers tous les dépôts amont où un référentiel autoritaire fait office de vérité, et chaque hébergeur est un miroir maintenu en parfaite synchronisation.
- **Tests rigoureux et contraints par une constitution** — sept types de tests avec une couverture de 100 % par type, sans exceptions, validés par un script de suite verte exécuté en une seule passe, plutôt que sur la base de la confiance.

## Principaux défis techniques et solutions apportées

- **Divergences et conflits entre de multiples dépôts amont.** Un même référentiel présent sur une douzaine de plateformes dérive dès que deux hébergeurs acceptent des modifications différentes. Résolu grâce à des flux de résolution assistés par politiques et AI, ancrés à une source unique de vérité, complétés par une synchronisation de poussée vers tous les dépôts amont qui maintient chaque miroir en convergence vers cette vérité unique.
- **Prise en charge uniforme des hébergeurs Git hétérogènes.** Chaque plateforme a ses propres mécanismes d'authentification, ses particularités et ses API. Résolu via des scripts de configuration par dépôt amont sous `Upstreams/` et une couche d'abstraction qui masque ces différences, permettant d'ajouter un nouvel hébergeur par simple configuration, sans réécriture.
- **Preuve de la justesse avant chaque fusion.** Résolu par une matrice de tests obligatoire couvrant sept types, et un script `verify-everything.sh` agissant comme un verrou en une seule passe, exécutant l'ensemble des vérifications — et s'interrompant proprement si aucun cluster n'est accessible, garantissant ainsi que la justesse est démontrable localement comme en CI.

## Pile technologique

- **Monorepo Go** — le cœur du proxy et du moteur de fédération : une plateforme avec 18 services, de la génération de code et des outils de scaffolding, le tout maintenu dans un seul dépôt pour que l'ensemble du moteur soit construit et testé comme une unité cohérente.
- **Angular 19 + Nx** — l'application web, avec Nx fournissant la structure de construction et de mise en cache en monorepo nécessaire à un large frontend.
- **Kotlin Multiplatform + Compose** — les interfaces clientes natives pour Android, iOS et Desktop, générées à partir d'une base de code partagée, évitant ainsi de devoir implémenter trois fois la même solution pour trois plateformes.
- **Kubernetes + Helm + Argo CD + Kustomize** — livraison cloud-native : Helm empaquette la version, Kustomize adapte les surcouches par environnement, et Argo CD la déploie via GitOps, assurant que l'état du cluster correspond à celui du dépôt Git.
- **OPA (Rego)** — les politiques sous forme de code pour la résolution des conflits et le contrôle d'accès, gardant les décisions d'autorisation déclaratives et auditable.
- **Docusaurus** — le site de documentation publique (docs.helixgitpx.io) ; **Astro** — le site marketing (helixgitpx.io), chaque outil étant adapté à son type de contenu.
- **mise** — une chaîne d'outils verrouillée et reproductible, garantissant que chaque contributeur et chaque exécuteur CI utilise exactement les mêmes versions.

Contenu

## Notes sur l'état et la transparence

- **État : livré.** Le fichier README du projet annonce la version v1.0.0 GA avec les jalons `m1-foundation` à `m8-ga` marqués. (« v1.0.0 GA » est l'affirmation du README du projet.)
- **Licence : à déterminer.** Les rapports GitHub et API mentionnent `MIT`, tandis que la section Licence du README indique Apache-2.0 (code) / CC-BY-SA-4.0 (documentation) — à vérifier par rapport au fichier LICENSE effectif avant publication.
- Les URL de la documentation (docs.helixgitpx.io) et du marketing (helixgitpx.io) proviennent du README et n'ont pas été récupérées de manière indépendante — statut en ligne NON VÉRIFIÉ.

**Niveau de priorité :** Helix-primaire.

