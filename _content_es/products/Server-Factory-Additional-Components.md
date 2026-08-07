---
name: Server Factory — Additional Components
slug: server-factory-additional-components
tier: serverfactory-tertiary
order: 33
status: mixed / early-stage (service factories are placeholder-documented — UNVERIFIED; Definitions & Utils are supporting data/tooling)
license: UNVERIFIED
private: false
tech:
  - Kotlin (service factories, on Core Framework)
  - Shell (Utils, Definitions packs)
  - Gradle
  - Docker (target runtime)
  - SSH / OpenSSH (Utils bootstrap)
  - SonarQube
repos:
  - https://github.com/Server-Factory/Web-Service-Factory
  - https://github.com/Server-Factory/SonarQube-Factory
  - https://github.com/Server-Factory/Caching-Proxy-Factory
  - https://github.com/Server-Factory/Docker-Definitions
  - https://github.com/Server-Factory/Stack-Definitions
  - https://github.com/Server-Factory/Software-Definitions
  - https://github.com/Server-Factory/Utils
diagrams:
  - Family tree (Core Framework → {Mail, Web, SonarQube, Caching-Proxy} factories)
  - Data-vs-engine split (Definitions packs feeding the factory execution engine)
  - Utils spotlight (init_ssh_access.sh bootstrap flow)
  - Maturity legend distinguishing flagship (Mail) from early-stage service factories
---

**El elenco de apoyo de la cadena de herramientas de aprovisionamiento Server Factory.**

## Resumen

Más allá de Mail Server Factory y el Marco Central, la organización Server-Factory incluye varios componentes más pequeños: "fábricas" por servicio (Servicio Web, SonarQube, Proxy de Caché), paquetes de configuración declarativa (Docker/Stack/Definiciones de Software) y utilidades compartidas. Esta página consolidada los aborda con honestidad —varios se encuentran en etapas tempranas o con documentación incompleta—, en lugar de presentarlos como productos plenamente especificados.

## Descripción breve

Un conjunto de repositorios de soporte para Server Factory: Web-Service-Factory, SonarQube-Factory y Caching-Proxy-Factory (herramientas de aprovisionamiento por servicio, en su mayoría en fase inicial); Docker/Stack/Software-Definitions (paquetes de configuración declarativa consumidos por el marco de trabajo); y Utils (ayudantes de acceso a SSH y herramientas generales). Todos se basan en el Marco Central.

## Descripción detallada

Esta página agrupa los repositorios restantes de Server-Factory porque, de manera individual, la mayoría son pequeños o están intencionalmente poco documentados, y presentarlos como productos terminados exageraría su grado de madurez. Se dividen en tres categorías. **Las fábricas de servicios** siguen el patrón de Mail Server Factory para otros roles de servidor: **Caching-Proxy-Factory** ("Ejecuta tu propio servidor proxy de caché") enumera como características clave un proxy de caché, un certificado autofirmado y un punto final HTTP para obtener certificados de seguridad; **SonarQube-Factory** ("Ejecuta tu propio servidor SonarQube") está orientado al uso en desarrollo de software; y **Web-Service-Factory** instancia y configura un servidor web para desplegar objetivos como sitios web y microservicios. Los tres son proyectos Kotlin construidos sobre el Marco Central, pero sus archivos README públicos son en gran medida marcadores de posición ("Por definir" en compatibilidad, especificaciones, configuración y uso), por lo que sus capacidades concretas más allá de lo declarado están SIN VERIFICAR. **Los paquetes de definiciones** —**Docker-Definitions**, **Stack-Definitions** y **Software-Definitions**— son repositorios de configuración declarativa que el marco de trabajo consume para saber cómo construir/desplegar imágenes, pilas y software de Docker; son paquetes de datos con versiones fijas, no aplicaciones. **Utils** ofrece herramientas generales para la familia, incluyendo un script `init_ssh_access.sh` que genera una clave SSH e la instala en un host remoto para habilitar el acceso root sin contraseña en aprovisionamientos posteriores. En conjunto, estos componentes completan la cadena de herramientas de aprovisionamiento en torno al buque insignia Mail Server Factory.

## Por qué lo creamos

El modelo Server Factory está diseñado para generalizarse: una vez que puedes aprovisionar un servidor de correo a partir de una descripción declarativa, el mismo motor debería ser capaz de aprovisionar servidores web, proxies de caché y servidores de calidad de código, alimentados por paquetes de definiciones reutilizables y utilidades compartidas, en lugar de lógica ad hoc para cada rol. Estos repositorios son esa generalización en proceso, extendiendo el patrón probado a nuevos tipos de servidores. Su valor aquí radica en demostrar el alcance del modelo; su madurez varía, y esta página deja claro cuáles son directrices y cuáles están terminados.


## Por qué es un cambio de juego (medido)

En conjunto, demuestran la reutilización del Marco Central en distintos tipos de servidores y separan los datos declarativos (Definiciones) de la ejecución (fábricas). Individualmente, las fábricas de servicios se encuentran en una fase temprana y deben presentarse como una dirección, no como productos terminados.

## Qué hay de innovador

- Un marco de aprovisionamiento generalizado para roles de correo/web/proxy de caché/SonarQube.
- Paquetes de Definiciones declarativas (Docker/Stack/Software) desacoplados del motor de ejecución.
- Utilidades compartidas (por ejemplo, el arranque sin contraseña con un solo comando SSH) reutilizadas en todas las fábricas.

## Desafíos y soluciones

- **Reutilizar un mismo motor en distintos roles de servidor:** resuelto al construir cada fábrica sobre el Marco Central.
- **Separar la configuración del código:** resuelto mediante los repositorios de Definiciones como paquetes de datos con versiones fijadas.
- **(SIN VERIFICAR):** los archivos README de las fábricas de servicios son provisionales; su grado de implementación no es verificable a partir de la documentación pública —presentarlos como fase temprana.

## Pila tecnológica (por qué + cómo)

- **Kotlin** — Fábrica de Servicios Web, Fábrica SonarQube, Fábrica de Proxy de Caché (construidas sobre el Marco Central).
- **Shell** — Utilidades y los paquetes de Definiciones (scripts/configuración).
- **Gradle** — Flujo de construcción/pruebas `./gradlew test` en todas las fábricas.
- **Docker** — Entorno de ejecución objetivo descrito por las Definiciones Docker.
- **SSH / OpenSSH** — Arranque de acceso sin contraseña de las Utilidades.
- **SonarQube** — El servidor que aprovisiona la Fábrica SonarQube (y contra el que Mail Server Factory informa una compuerta limpia).

> Nota de honestidad: la mayoría de estos repositorios son bifurcaciones dentro de la organización; las fábricas de servicios están documentadas como provisionales y marcadas como SIN VERIFICAR según el artículo 11.4.6 de los estatutos. Su relevancia está claramente por debajo de Mail Server Factory y el Marco Central.

