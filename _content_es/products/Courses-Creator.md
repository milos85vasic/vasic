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

**De Markdown a curso profesional en vídeo — mejorado con AI, multiplataforma.**

## Resumen

Courses-Creator es un conjunto de herramientas que convierte guiones en Markdown en cursos de vídeo profesionales con mejoras potenciadas por AI: enriquecimiento de contenido multi-LLM (OpenAI/Anthropic/Ollama), TTS y música de fondo de alta calidad, y reproductores para escritorio, móvil y web — todo desplegado con Docker e integrado con monitorización Prometheus/Grafana.

## Descripción breve

Transforma Markdown en cursos de vídeo atractivos. Un motor de procesamiento Go enriquece el contenido mediante múltiples proveedores LLM, genera narración (Bark/SpeechT5 TTS) y música, y los distribuye en reproductores Electron para escritorio, React Native para móvil y React para web, con despliegue Docker completo y monitorización.

## Descripción detallada

Producir un curso en vídeo suele requerir el trabajo de un pequeño estudio: guionizar, grabar la narración, buscar música, editar, codificar y luego desarrollar reproductores para cada plataforma que puedan usar los alumnos. Courses-Creator comprime toda esa cadena en una única entrada —un guion en Markdown— y un solo comando. En su núcleo, cuenta con un procesador Go que ejecuta una completa cadena de producción de vídeo y audio: enriquece el contenido escrito mediante múltiples proveedores LLM (OpenAI, Anthropic y Ollama local), sintetiza narración natural con motores de texto a voz (Bark, SpeechT5), añade música de fondo y ensambla las piezas en vídeos de curso terminados. La tarea del autor se limita a las ideas y las palabras; el sistema se encarga de la locución, la banda sonora y la producción. Y como un curso solo es útil si la gente puede verlo, la entrega está diseñada para ser multiplataforma: una aplicación creadora Electron para escritorio, un reproductor React Native para móvil y un reproductor React para web, todos alimentados por el mismo sistema REST API y de trabajos en segundo plano —un backend, tres clientes de primera categoría, sin necesidad de reimplementar para cada superficie.

Lo crucial es que se trata de infraestructura de producción, no de un *demo reel*. El backend incluye persistencia PostgreSQL, procesamiento de trabajos en segundo plano para que los renders largos de TTS/vídeo nunca bloqueen el API, implementaciones de servidor MCP para mejoras asistidas por herramientas, métricas Prometheus, autenticación JWT y un proxy inverso nginx —y todo el conjunto se despliega como un *Compose* Docker con perfiles de monitorización Grafana/Prometheus que pueden ponerse en marcha en un solo paso. La capa AI es un nivel de mejora, no una dependencia: cada proveedor LLM es opcional, por lo que la cadena de producción funciona sin claves API para operaciones básicas y activa el enriquecimiento premium en cuanto se proporcionan las claves. Esta única decisión hace que la misma herramienta sea viable tanto para un aficionado que trabaja sin conexión en un portátil como para una empresa que integra su proveedor preferido —y toda la cadena de producción multimedia subyacente está respaldada por pruebas unitarias, de integración y *end-to-end*, en lugar de basarse en la fe.

## Por qué lo creamos

Producir vídeos de cursos de forma manual es lento: escribir, narrar, musicalizar y editar requieren esfuerzo y herramientas especializadas. Courses-Creator reduce todo ese proceso a una cadena impulsada por Markdown, de modo que un único guion fuente se convierte en un curso producido, con AI cubriendo los vacíos que, de otro modo, los humanos tendrían que llenar a mano.


## Por qué es un cambio radical

Transforma la producción de cursos de un oficio especializado y multietapa en una cadena de software reproducible: la creación de contenidos, el enriquecimiento con AI, la generación de narración y música, y la reproducción multiplataforma conviven en un único stack implementable. La degradación elegante a un funcionamiento sin clave API es su superpoder silencioso: el mismo código base sirve tanto a un creador independiente con presupuesto ajustado como a una empresa con contrato premium, sin necesidad de reescribir nada en el proceso.

## Qué lo hace innovador

- Cadena de Markdown a vídeo con enriquecimiento multi-LLM conectable (OpenAI/Anthropic/Ollama).
- Generación integrada de TTS (Bark, SpeechT5) y música de fondo.
- Implementaciones de servidores MCP dentro del motor de procesamiento para potenciar herramientas.
- Un backend que da servicio a tres clientes de primera categoría (Electron de escritorio, React Native móvil, React web).

## Desafíos y soluciones

- **Procesamiento intensivo de medios:** resuelto con una cadena Go más procesamiento de trabajos en segundo plano, de modo que las tareas largas de TTS/vídeo no bloqueen la API.
- **AI opcional pero potente:** resuelto al hacer que los proveedores de LLM sean opcionales y conectables, con retroceso elegante a funcionalidades básicas.
- **Entrega multiplataforma:** resuelto con una API REST compartida y tres aplicaciones de reproducción dedicadas.
- **Operatividad:** resuelto con perfiles de Docker Compose, Prometheus/Grafana y autenticación JWT integrada.

## Tecnologías empleadas (por qué y cómo)

- **Go** — motor de procesamiento principal, API REST, ejecutor de trabajos y cadena de procesamiento (972K+ bytes, lenguaje dominante).
- **TypeScript / React** — reproductor web y UI compartida.
- **Electron** — aplicación de creación para escritorio.
- **React Native** — reproductor móvil.
- **PostgreSQL** — persistencia de cursos/trabajos.
- **Proveedores LLM (OpenAI, Anthropic, Ollama)** — enriquecimiento de contenidos.
- **TTS (Bark, SpeechT5)** — síntesis de narración.
- **Servidores MCP** — integración de herramientas dentro del motor.
- **Docker Compose + nginx** — implementación full-stack y proxy inverso.
- **Prometheus + Grafana** — monitorización.

> Nota: el *README* público de inicio rápido utiliza un clon URL con marcador de posición `your-org`.

