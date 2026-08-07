---
name: HelixAgent
slug: helixagent
tier: helix-primary
order: 3
status: beta
license: MIT
private: false
tech:
  - Go
  - Gin
  - PostgreSQL
  - Redis
  - LLMsVerifier
  - Prometheus
  - Grafana
  - OpenTelemetry
  - Model Context Protocol
  - Neo4j
  - ClickHouse
  - Kafka
repos:
  - https://github.com/HelixDevelopment/HelixAgent
diagrams:
  - Ensemble/debate flow — a prompt fanning out to N providers, through the Proposal→Critique→Review→Synthesis phases, converging to one synthesized answer.
  - Dynamic routing — LLMsVerifier scores feeding a router that selects confidence-weighted providers with fallback arrows.
  - Production architecture — Gin API → orchestrator → provider pool, with PostgreSQL/Redis and the Prometheus/Grafana/OpenTelemetry observability plane.
  - Module map — the ~20 extracted modules grouped by concern (data, security, AI, infra).
---

# HelixAgent

**No elijas un solo modelo: deja que debatan y entrega la respuesta en la que coincidan.**

## Resumen

HelixAgent es un servicio de *ensemble* LLM listo para producción, impulsado por AI, que combina de manera inteligente respuestas de múltiples modelos de lenguaje —incluyendo un sistema de debate AI en varias rondas y una selección dinámica de proveedores basada en verificación— para generar el resultado más preciso y confiable.

## Descripción breve

HelixAgent es un servicio de *ensemble* LLM basado en Go que integra múltiples proveedores en una única respuesta precisa. Ejecuta debates AI en varias rondas, evalúa proveedores dinámicamente mediante LLMsVerifier, aplica estrategias de enrutamiento ponderadas por confianza y ofrece funciones listas para producción: almacenamiento en caché, monitoreo, salvaguardas de seguridad y APIs al estilo OpenAI.

## Descripción detallada

HelixAgent es un servicio de *ensemble* LLM (MIT) listo para producción, impulsado por AI, que trata la respuesta de un solo modelo como una hipótesis, no como un veredicto. En lugar de apostar el resultado a un único proveedor que podría estar equivocado, sesgado o temporalmente inaccesible, combina respuestas de múltiples modelos de lenguaje para converger en la salida más precisa y fiable. Y cuando una pregunta es lo suficientemente compleja como para justificarlo, somete a los modelos a un debate estructurado en varias rondas. Su catálogo es amplio: el archivo README documenta numerosos proveedores LLM en `internal/llm/providers/`, entre ellos Claude, DeepSeek, Gemini, Mistral, Qwen y xAI/Grok.

Lo crucial es que la selección de proveedores no se basa en una lista estática de preferencias, sino que se gana en tiempo real. Las puntuaciones de verificación en vivo, proporcionadas por un LLMsVerifier integrado, dirigen el enrutamiento y permiten un *fallback* elegante hacia el proveedor con mejor desempeño, con informes de errores categorizados cuando alguno se degrada. El Orquestador de Debates AI convierte el desacuerdo en señal: admite múltiples topologías (malla, estrella, cadena) y un protocolo de fases disciplinado —Propuesta → Crítica → Revisión → Síntesis— con aprendizaje entre debates para que el sistema mejore en la reconciliación de modelos con el tiempo. Las estrategias de enrutamiento abarcan selección ponderada por confianza, consenso por mayoría y detección de intención semántica, todo con respuestas en *streaming* en tiempo real para que las respuestas lleguen token a token, en lugar de esperar a que todo el *ensemble* se estabilice.

El servicio está diseñado para sobrevivir en producción, no solo para brillar en demostraciones: PostgreSQL y Redis conforman una capa de datos de alta disponibilidad, Prometheus/Grafana/OpenTelemetry proporcionan métricas, paneles de control y trazabilidad, y JWT (autenticación, limitación de tasa, un motor de salvaguardas y detección de PII) envuelve al *ensemble* con los controles que requiere un despliegue real. Está organizado en alrededor de veinte módulos independientes (EventBus, Observabilidad, Autenticación, Almacenamiento, VectorDB, Incrustaciones, RAG, Memoria, MCP y otros), cada uno con una responsabilidad clara, e incluye un marco de optimización LLM (caché semántica, salida estructurada, *streaming* mejorado) con integraciones para SGLang, LlamaIndex, LangChain, Guidance y LMQL. Dado que los puntos finales de finalización y *ensemble* son compatibles con OpenAI, un cliente existente puede apuntar a HelixAgent y obtener razonamiento de *ensemble* sin necesidad de reescribir código.


## Por qué lo creamos

Cualquier modelo LLM individual puede estar equivocado, sesgado o no estar disponible. HelixAgent se construyó para que las aplicaciones puedan consultar múltiples modelos a la vez, ponderar sus respuestas según su fiabilidad medida y retroceder con elegancia, transformando una dependencia frágil de un único proveedor en un conjunto resiliente y autoevaluado.

## Por qué cambia las reglas del juego

Operativiza el consenso multimodelo, sacando el "consultar varios modelos y reconciliarlos" de scripts ad hoc para integrarlo en un servicio de producción. En lugar de codificar un solo proveedor y confiar en que funcione, los equipos obtienen enrutamiento basado en puntuaciones de verificación en tiempo real, un protocolo estructurado de debate para las preguntas en las que una sola respuesta no es suficiente, y resiliencia de nivel productivo (una capa de datos de alta disponibilidad, observabilidad completa y salvaguardas) todo ello detrás de una API compatible con OpenAI y API. El avance radica en la adopción sin disrupción: una dependencia frágil de un único proveedor se convierte en un conjunto resiliente y autoevaluado, y los clientes existentes pueden migrar simplemente cambiando un endpoint en lugar de modificar su código.

## Qué tiene de innovador

- Debate estructurado en múltiples rondas AI que trata el desacuerdo entre modelos como un recurso: topologías seleccionables en malla/estrella/cadena, un protocolo disciplinado de Propuesta→Crítica→Revisión→Síntesis, y aprendizaje entre debates que se acumula con el tiempo.
- Selección dinámica de proveedores basada en puntuaciones LLMsVerifier en vivo, en lugar de una lista estática de preferencias: el conjunto redirige las consultas al proveedor que esté rindiendo mejor en ese momento y retrocede con elegancia cuando alguno falla.
- Un marco nativo de optimización Go para LLM (caché semántica, salida estructurada, streaming mejorado) que funciona por sí mismo, con la opción de integrar optimizadores externos (SGLang, LlamaIndex, LangChain, Guidance, LMQL) cuando se deseen, sin que sean obligatorios.
- Una arquitectura modular compuesta por unos veinte módulos independientes que mantiene las preocupaciones separadas y abre la puerta a funciones de Big Data como memoria distribuida y transmisión de grafos de conocimiento.

## Principales desafíos técnicos y cómo los resolvimos

- **Elegir entre múltiples proveedores desiguales.** Los proveedores varían en calidad y su rendimiento fluctúa con el tiempo, por lo que cualquier clasificación fija queda obsoleta al día siguiente. Lo resolvimos haciendo que la selección se mida de forma continua: las puntuaciones LLMsVerifier alimentan un enrutamiento ponderado por confianza y basado en mayoría, con retroceso elegante para evitar depender de un proveedor en declive.
- **Obtener una respuesta fiable a preguntas realmente difíciles.** Un solo modelo, consultado una vez, no tiene mecanismo para detectar sus propios errores. El Orquestador de Debates proporciona uno: un debate en múltiples topologías y fases (Propuesta → Crítica → Revisión → Síntesis) que obliga a los modelos a cuestionarse y refinar sus respuestas antes de generar una respuesta final.
- **Ejecutar un conjunto en producción, no solo en un cuaderno.** Distribuir las consultas entre muchos proveedores multiplica las posibles fallas. Lo controlamos con una capa de datos de alta disponibilidad PostgreSQL+Redis, observabilidad Prometheus/Grafana/OpenTelemetry para detectar comportamientos anómalos en proveedores o rutas, y un perímetro de seguridad con autenticación JWT, limitación de tasa, un motor de salvaguardas y detección de PII.


## Pila tecnológica

- **Go** — elegido porque distribuir una única solicitud entre varios proveedores de forma concurrente es precisamente para lo que están diseñadas las goroutines, y el despliegue en un solo binario mantiene el servicio de ~20 módulos sencillo de implementar; sustenta todo el servicio y cada módulo interno.
- **Gin (Web API)** — elegido por su rápida superficie HTTP de bajo consumo; sirve los endpoints compatibles con OpenAI `/v1` para completado, chat, streaming y ensamblaje, permitiendo que los clientes existentes adopten el ensamblaje sin cambios.
- **PostgreSQL** — elegido como almacenamiento duradero para sesiones, analíticas y registros de debates, de modo que las decisiones por consenso y el historial de debates sean auditables; ancla la capa de datos de alta disponibilidad.
- **Redis** — elegido para el almacenamiento en caché de baja latencia y la gestión de colas de tareas; impulsa tanto el caché de respuestas como la capa de caché semántica que permite omitir inferencias redundantes en prompts repetidos o casi idénticos.
- **LLMsVerifier (integrado)** — elegido para convertir la fiabilidad de los proveedores en una métrica cuantificable en lugar de una suposición; sus puntuaciones clasifican a los proveedores para el enrutamiento y activan el respaldo cuando alguno se degrada.
- **Prometheus + Grafana + OpenTelemetry** — elegidos para que un ensamblaje que abarca múltiples proveedores sea observable; exponen métricas `helixagent_*`, paneles de control y seguimiento de solicitudes de extremo a extremo en la distribución.
- **Adaptadores Model Context Protocol (MCP)** — elegidos por su extensibilidad mediante un protocolo abierto; el archivo README enumera numerosos adaptadores MCP para conectar herramientas externas y contexto.
- **Neo4j / ClickHouse / Kafka (BigData)** — elegidos para superar los límites de un solo nodo: Neo4j y ClickHouse respaldan la memoria distribuida y las funciones de grafo de conocimiento, mientras que Kafka transmite ese grafo y los datos de eventos a escala.
- **Integraciones de optimización (SGLang, LlamaIndex, LangChain, Guidance, LMQL)** — elegidas para incorporar caché de prefijos, recuperación, descomposición de tareas y generación restringida como servicios opcionales, de modo que las optimizaciones más complejas estén disponibles sin ser obligatorias.

## Estado y notas de transparencia

- **Estado: beta.** El servicio se describe como listo para producción, pero las cifras de rendimiento y cobertura en el README (por ejemplo, "1000+ solicitudes/segundo", "<500 ms en caché", conteos de proveedores y scripts de validación) son afirmaciones autoinformadas del proyecto, no verificadas de forma independiente, y se mantienen deliberadamente cualitativas en este documento.
- El número de proveedores varía dentro del propio README; la página emplea el enfoque cualitativo de "múltiples proveedores".

**Nivel de prioridad:** Helix-primary.

