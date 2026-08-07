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

## Héroe

**Ingeniero AI especializado en la construcción de sistemas AI verificables y en desarrollo.**

Construyo la parte de la ingeniería AI que marca la diferencia entre un producto confiable y una demostración impresionante: la infraestructura LLM multi-proveedor que sobrevive a la caída de un proveedor, los agentes autónomos y la orquestación que mantienen el trabajo en curso, y las capas de gobernanza y control de calidad que evitan que un sistema AI mienta discretamente sobre lo que puede hacer. Convertir un modelo de lenguaje grande en algo que realmente se pueda lanzar al mercado es, sobre todo, un problema de disciplina, y esa disciplina es mi especialidad. Mi estrella polar es una única regla: una funcionalidad está terminada solo cuando un usuario real puede utilizarla y existe evidencia capturada que lo demuestre.

## Resumen

Trabajo principalmente en **Go**, con **Kotlin / Kotlin Multiplatform**, **TypeScript/React**, **Python**, **Swift** y **Shell**, según lo requiera el proyecto. Lo que más me importa es cómo se *estructura* el trabajo: no un montón de aplicaciones aisladas, sino una flota —grandes aplicaciones de producto que se asientan sobre docenas de módulos pequeños, desacoplados y probados de forma independiente, todos heredando una **Constitution** de ingeniería compartida como submódulo de Git—. Esa única decisión arquitectónica es lo que hace que todo el conjunto de trabajo se potencie: las correcciones y mejoras se propagan de inmediato a todo, los nuevos productos se ensamblan a partir de componentes ya probados, y cada capacidad anunciada está respaldada por una prueba que genera evidencia, no por una simple afirmación. Es ingeniería diseñada para ser confiable a escala, incluso cuando la desarrolla una sola persona. Esta página parte de esta visión general para adentrarse en los proyectos individuales; cada uno enlaza a su página de producto completa.

## Mi método de trabajo: gobernanza y control de calidad primero

Antes que los productos, la disciplina que los sustenta:

- **HelixConstitution** — Mantengo un manual de reglas de ingeniería universal y heredable, distribuido como submódulo de Git en una flota de más de 140 repositorios. Este codifica compuertas de evidencia contra el engaño, inmunidad a falsos positivos, seguridad de datos y hosts, y normas de cobertura; los proyectos pueden endurecerlas, pero nunca relajarlas, y cada compuerta de gobernanza va acompañada de una prueba de mutación que demuestra que la propia compuerta funciona. → Ver la página del producto HelixConstitution.
- **HelixQA** — Desarrollo orquestación de control de calidad anti-engaño que ejecuta bancos de pruebas escritos y sesiones de QA totalmente autónomas, impulsadas por LLM y visión, en Android, Android TV, Web y Escritorio, otorgando un APROBADO solo cuando se ha capturado evidencia en tiempo de ejecución. → Ver la página del producto HelixQA.

## Mi trabajo en la familia Helix

La línea Helix abarca todo el ciclo de vida del desarrollo AI. Por orden de prioridad:

- **HelixTrack** — una alternativa JIRA de código abierto; el buque insignia de la línea Helix-Track.
- **HelixAgent** — un servicio LLM de conjunto con debate entre modelos en múltiples rondas y selección de proveedores basada en verificación.
- **HelixCode** — una plataforma de desarrollo AI distribuida que divide el trabajo entre trabajadores gestionados por SSH con puntos de control y retroceso automáticos.
- **HelixLLM** — un único binario con seis modos que ofrece APIs compatibles con OpenAI y Anthropic sobre HTTP/3, con inferencia local mediante llama.cpp y una cadena de respaldo con puntuación.
- **HelixCluster** — un sistema operativo distribuido para cómputo AI, desde GPUs en centros de datos hasta dispositivos de borde portátiles.
- **LLMProvider** — una única interfaz para 43 proveedores con disyuntores, reintentos y estado de salud integrados.
- **LLMOrchestrator** — un plano de control para cada agente de codificación CLI sin interfaz gráfica.
- **LLMsVerifier** — verificar, monitorear, optimizar: la única fuente de verdad para metadatos de LLM, proveedores y verificación.
- **HelixMemory, HelixSkills, HelixSpecifier, HelixBuilder, HelixTranslate, HelixTerminator, HelixGitpx, HelixOTA, HelixPlay** — memoria de agentes, habilidades de agentes gobernadas, desarrollo basado en especificaciones, construcción de aplicaciones AI, traducción de libros verificada, terminales de confianza cero, Git federado, actualizaciones OTA sin riesgo de bloqueo y juegos en la nube autoalojados.


## Mi trabajo en utilidades vasic-digital

Herramientas de nivel profesional que he desarrollado y mantengo (cada una cuenta con una página de producto completa):

- **Catalogizer** — gestión de colecciones multimedia con soporte multiprotocolo (SMB/FTP/NFS/WebDAV/local), cifrado y autoalojamiento, con interfaz de usuario Go/Gin API y React.
- **Courses-Creator** — sistema de conversión de cursos de markdown a vídeo con enriquecimiento multi-LLM, TTS y reproductores para escritorio, móvil y web.
- **VisionEngine** — kit de herramientas Go desacoplado que fusiona visión por computadora clásica con visión multi-LLM para análisis de interfaces y grafos de navegación.
- **DocProcessor** — convierte documentación en un mapa de características verificable para automatización de control de calidad (extracción LLM o heurística).
- **Docs Chain** — motor de sincronización bidireccional y atómica de documentos/bases de datos con hash de contenido.
- **Herald** — notificaciones multicanal confiables con resolución de intenciones en tres niveles mediante lenguaje natural.
- **task_bridge** — motor de sincronización bidireccional y desacoplado de tareas/tableros (esqueleto P1; lógica de sincronización en desarrollo).
- **Vasic Digital Suite de Módulos Reutilizables** — la "biblioteca estándar" `digital.vasic.*` de infraestructura, módulos de primitivas AI y de protección.

## Herencia en infraestructura (Server Factory)

Anterior a la línea AI, mi cadena de herramientas DevOps: **Mail Server Factory** (JSON declarativo → servidores de correo completamente aprovisionados en Docker, con 439 pruebas superadas y un paso limpio por la puerta SonarQube), el **Marco Central Server Factory** en el que se basa, y herramientas para imágenes de VM (**Qemu-Utils**, **Parallels-Utils**) junto con fábricas de servicios de soporte.

## En una línea

No entrego marcas de verificación verdes: entrego sistemas AI con pruebas de que funcionan y el gobierno que garantiza que sigan así.

## Contacto

Abierto a puestos sénior de ingeniería AI/plataforma a nivel mundial.

- **Correo electrónico:** [milos85vasic@gmail.com](mailto:milos85vasic@gmail.com) · [i@mvasic.ru](mailto:i@mvasic.ru)
- **GitHub:** [milos85vasic](https://github.com/milos85vasic)
- **Telegram:** [@milos85vasic](https://t.me/milos85vasic)

