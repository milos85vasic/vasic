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

**Una única fuente de verdad, reflejada en todas partes — Git federado en una docena de hosts.**

## Resumen

HelixGitpx (Helix Git Proxy eXtended) es un proxy federado de Git que mantiene una única fuente de verdad reflejada en múltiples hosts Git upstream y resuelve los inevitables conflictos mediante flujos asistidos por políticas y AI. Ha alcanzado la versión v1.0.0 GA.

## Descripción breve

HelixGitpx es un proxy federado de Git que refleja una única fuente de verdad en más de una docena de hosts Git —GitHub, GitLab, Gitea, Bitbucket, Azure DevOps, AWS CodeCommit y otros— y resuelve los conflictos de sincronización mediante flujos asistidos por políticas y AI. Lanzado como v1.0.0 GA.

## Descripción detallada

HelixGitpx —"Helix Git Proxy eXtended"— es un proxy federado de Git que mantiene una única fuente de verdad reflejada en múltiples hosts Git upstream y resuelve los conflictos que surgen inevitablemente cuando un mismo repositorio existe en más de un lugar. Sus upstreams compatibles abarcan todo el ecosistema Git: GitHub, GitLab, GitFlic, GitVerse, Gitea, Gitee, Bitbucket, Azure DevOps, AWS CodeCommit, Forgejo, SourceHut y Git genérico sobre HTTPS. Mientras que un `git push` ingenuo a una docena de remotos fallaría directamente o, peor aún, permitiría que los espejos divergieran en silencio, HelixGitpx interviene con flujos de resolución asistidos por políticas y AI que reconcilian las divergencias para restablecer una única verdad autoritativa.

El proyecto se encuentra en la versión v1.0.0 GA, con hitos etiquetados desde `m1-foundation` hasta `m8-ga` —un camino completamente trazado desde los cimientos hasta la disponibilidad general—. Está diseñado en tres capas de un mismo producto: un monorepo Go (una plataforma con dieciocho servicios, herramientas de generación de código y andamiaje) que alberga el motor de federación; una aplicación web Angular 19 + Nx; y shells cliente Kotlin-Multiplatform + Compose que ofrecen experiencias nativas para Android, iOS y escritorio a partir de código compartido. La entrega de la plataforma es nativa de Kubernetes en su núcleo —gráficos Helm, aplicaciones Argo CD, superposiciones Kustomize, SQL y políticas OPA—, con pipelines de CI protegidos por un despacho explícito para evitar despliegues accidentales. La documentación pública se distribuye como un sitio Docusaurus (docs.helixgitpx.io), junto a un sitio de marketing en Astro (helixgitpx.io).

La gobernanza es estricta y basada en una constitución, y esto es una característica, no un formalismo: el documento fundamental es el Constitution del proyecto, cuyo Artículo II exige una matriz de pruebas de siete tipos con cobertura del 100% *por tipo y por módulo modificado*, permitiendo mocks solo en pruebas unitarias y sin tolerar ni una sola prueba omitida. Un verificador de un solo uso ejecuta todas las comprobaciones de artefactos junto con `go vet` y `go test` en todo el espacio de trabajo, y cada push se propaga a todos los upstreams configurados —de modo que "los espejos están sincronizados" es algo que el sistema garantiza en cada commit, en lugar de algo que un humano debe recordar verificar.

## Por qué lo creamos

Mantener un repositorio auténtico en múltiples hosts Git —ya sea por redundancia, soberanía o acceso a plataformas regionales— es frágil y manual, y los espejos divergentes son difíciles de reconciliar. HelixGitpx se creó para convertir el mirroring multi-upstream en una capacidad de primera clase, consciente de los conflictos.


## Por qué es un cambio de juego

Transforma el modelo de "enviar a muchos remotos y esperar" —el frágil *statu quo* manual— en una federación gobernada con una única fuente autoritativa de verdad y resolución automatizada de conflictos basada en políticas y AI. Y lo logra abarcando un conjunto inusualmente amplio de hosts, incluyendo deliberadamente las plataformas regionales (GitFlic, GitVerse, Gitee) que la mayoría de las herramientas ignoran sin hacer ruido, de modo que la redundancia, la soberanía de datos y el alcance en esos ecosistemas dejan de ser una carga de mantenimiento para convertirse en una única capacidad que configuras una sola vez.

## Qué hay de innovador

- **Amplitud de *upstreams*** — más de una docena de hosts de Git, desde GitHub y GitLab hasta plataformas regionales como GitFlic, GitVerse y Gitee, todos normalizados tras un único proxy.
- **Resolución de conflictos asistida por políticas y AI** — las divergencias se reconcilian mediante un motor de políticas y un resolvedor AI, no mediante un humano comparando espejos a mano.
- **Federación con fuente única de verdad** — un modelo de *push* a todos los *upstreams* donde un repositorio autoritativo es la verdad y cada host es un espejo mantenido en sincronía absoluta.
- **Pruebas rigurosas con aplicación constitucional** — siete tipos de pruebas con cobertura del 100 % por tipo, sin excepciones, validadas por un *script* de suite verde de ejecución única, en lugar de confiar en la fe.

## Principales desafíos técnicos y cómo los resolvimos

- **Divergencias y conflictos entre múltiples *upstreams***. Un mismo repositorio alojado en una docena de lugares se desvía en cuanto dos hosts aceptan cambios distintos. Solucionado con flujos de resolución asistidos por políticas y AI, anclados a una única fuente de verdad, junto con un *push* sincronizado a todos los *upstreams* que mantiene cada espejo convergiendo hacia esa única verdad.
- **Soporte uniforme para hosts de Git heterogéneos**. Cada host tiene su propio sistema de autenticación, peculiaridades y API. Solucionado con *scripts* de configuración por *upstream* bajo `Upstreams/` y una capa de plataforma que abstrae esas diferencias, de modo que añadir un nuevo host es cuestión de configuración, no de reescribir código.
- **Demostrar corrección antes de cada fusión**. Solucionado con una matriz de pruebas obligatoria de siete tipos y un *script* de validación única `verify-everything.sh` que ejecuta el conjunto completo de comprobaciones —y falla limpiamente si no hay acceso al clúster—, de modo que la corrección es demostrable tanto localmente como en CI.

## Pila tecnológica

- **Monorrepositorio Go** — el núcleo del proxy y el motor de federación: una plataforma más 18 servicios, generación de código y *scaffolding*, mantenidos en un solo repositorio para que todo el motor se compile y pruebe como una unidad.
- **Angular 19 + Nx** — la aplicación web, con Nx proporcionando la estructura de compilación y caché para monorrepositorios que necesita un *frontend* grande.
- **Kotlin Multiplatform + Compose** — *shells* nativos para Android, iOS y escritorio generados a partir de una única base de código compartida, de modo que tres plataformas no implican tres implementaciones distintas.
- **Kubernetes + Helm + Argo CD + Kustomize** — entrega nativa en la nube: Helm empaqueta la versión, Kustomize adapta los *overlays* por entorno y Argo CD la reconcilia mediante GitOps, de modo que el estado del clúster coincide con Git.
- **OPA (Rego)** — políticas como código para la resolución de conflictos y el control de acceso, manteniendo las decisiones de autorización declarativas y auditables.
- **Docusaurus** — el sitio de documentación pública (docs.helixgitpx.io); **Astro** — el sitio de marketing (helixgitpx.io), cada herramienta adaptada a su tipo de contenido.
- **mise** — una cadena de herramientas fijada y reproducible para que cada colaborador y ejecutor de CI compile exactamente con las mismas versiones.


## Notas sobre estado y honestidad

- **Estado: enviado.** El archivo README del proyecto declara la versión v1.0.0 GA con los hitos etiquetados desde `m1-foundation` hasta `m8-ga`. ("v1.0.0 GA" es la declaración del propio README del proyecto).
- **Licencia: por determinar.** Los informes GitHub y API indican `MIT`, mientras que la sección de Licencia del README establece Apache-2.0 (código) / CC-BY-SA-4.0 (documentación). Resolver según el archivo LICENSE real antes de publicar.
- Las URLs de la documentación (docs.helixgitpx.io) y de marketing (helixgitpx.io) figuran en el README y no se han obtenido de forma independiente; estado en vivo SIN VERIFICAR.

**Nivel de prioridad:** Helix-principal.

