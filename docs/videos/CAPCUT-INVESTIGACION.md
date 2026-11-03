# Edición agéntica con CapCut: investigación (03-11-2026)

Estado de cada dato: **V** = verificado en este equipo o en el repo; **F** = lo dice una fuente de terceros, sin confirmar con CapCut; **?** = no se pudo comprobar.

## Lo verificado en este equipo

| Dato | Estado |
|---|---|
| CapCut de escritorio 9.7.0.4153 instalado (`%LOCALAPPDATA%\CapCut`, también quedan 9.4 y 9.5) | V |
| Los borradores `trailer esp` y `trailer en` (creados con 9.5.0) tienen `draft_content.json` en **texto plano** (empieza por `{`, 400 KB, versión de formato 360000 / 187.0.0). El cifrado de borradores **no** afecta a esta versión internacional en 9.5 | V |
| Esos borradores ya tienen 39 clips de vídeo, textos, 14-15 pistas de audio, 1920×1080, 75 s: el tráiler existe en CapCut | V |
| Pantalla 1920×1080 a 59 Hz, RTX 4070 Ti, 57 GB libres en C: | V |
| `ffmpeg` y `auto-editor` **no** están instalados; sí `winget`, Python 3.13, Node, Pillow | V |
| `faster-whisper` no está instalado | V |
| El repo ya tiene guion del tráiler (`docs/videos/trailer.md`), subtítulos ES/EN (`.srt`), reglas de contenido, la herramienta `ServerStorage.Tools.Trailer` para las tomas y portadas en `art/portada` | V |
| Las skills `turntable`, `slow-zoom`, `crane-shot`, `dolly-rotate`, `perfect-loop`, `product-polish`, `threejs-export` y `polyhaven-*` son de Blender (renders de modelos); sirven para tomas de producto, no para montar | V (leídas las cabeceras) |
| Las herramientas de *computer use* **no están cargadas** en esta sesión (la búsqueda no las encuentra) | V |

## Opciones para controlar CapCut

| Opción | Qué permite | Fiabilidad | Coste / mantenimiento | Riesgo |
|---|---|---|---|---|
| **a. Computer use** (capturas, clics, teclado) | Todo lo que hace la interfaz, incluidos exportar y las funciones IA | Sin datos específicos de CapCut (F: ~85-93 % en tareas multiapp en Windows; en vista previa desde abril de 2026). Un editor de línea de tiempo es lo peor para un agente visual | Lento (una captura por paso), ocupa el PC y exige plan Pro/Max de Claude con la herramienta activada; se rompe con cada rediseño | Medio: clics equivocados; borra o mueve clips |
| **b. Escribir el borrador** (`pyCapCut`, `VectCutAPI`, `capcut-cli`, `capcut-mate`) | Crear/editar vídeo, audio, texto, SRT, keyframes, máscaras, efectos, transiciones, filtros; plantillas a partir de un borrador | Alta en lo básico. `pyCapCut` marca como verificado 8.2.0 y 9.5.0.4050; no hay fechas ni releases (34 commits). `capcut-cli` es MIT, 79 commits, 0 estrellas. Formato **sin documentar**: puede romperse en una versión nueva | Rápido, local, gratis. **No exporta**: hay que pulsar Exportar a mano. Hay que cerrar el proyecto antes de editar o CapCut lo pisa | Bajo si se trabaja en una copia; CapCut 9.x reescribe espejos al cerrar (F, caso JianYing 9.0.0) |
| **c. API / CLI / MCP oficial** | No existe API pública de edición ni MCP oficial (F, varias fuentes). Hay MCP no oficiales que envuelven (b). Una fuente habla de un plugin de ChatGPT, sin confirmar | — | — | Los términos (F, resumen de terceros) prohíben «scripts automatizados para interactuar con los Servicios»: aplica a la nube más que a escribir archivos locales (?) |
| **d. CapCut Web / móvil** | Sin API; el móvil solo por computer use del teléfono | Baja | Alto | Nube: los vídeos suben a ByteDance |

**Cifrado de borradores:** el cifrado AES de `draft_content.json` es de JianYing (la versión china) desde 6.0 (F: nota de `capcut-cli`, caso 11.4); la versión internacional no lo tiene (F), y aquí se comprobó con la 9.5 (V). Para 9.7 hay que repetir la prueba (spike).

## Plan gratis de CapCut (las fuentes se contradicen)

| Dato | Estado |
|---|---|
| Exportación hasta 1080p; 4K/60 fps y HDR son de pago | F (consenso de las fuentes); en la web, el 4K gratis puede llevar marca o bitrate limitado |
| Sin marca de agua en el plan gratis, **salvo** que el proyecto use un recurso, efecto o plantilla marcado Pro: uno solo bloquea la exportación limpia | F |
| Subtítulos automáticos | **Contradictorio**: gratis; 10 min por vídeo; 5 generaciones cada 30 días; solo Pro | ? |
| Recorte de silencios | **Contradictorio**: gratis o solo Pro | ? |
| Reencuadre automático | Gratis en escritorio según una fuente; «ilimitado» solo Pro según otra | ? |
| Pro cuesta ~19,99 USD/mes o 179,99/año; Estándar ~9,99/mes sin 4K | F |
| La página oficial de precios no se pudo leer (404) | ? |

Conclusión: **no hay que contar con ninguna función IA del plan gratis**. Lo que importa para el tráiler (cortar, mover, texto, SRT importado, 1080p) no depende de ellas.

## Alternativas de respaldo

| Herramienta | Para qué | Estado |
|---|---|---|
| **ffmpeg** (`winget install Gyan.FFmpeg`) | Cortar, recortar a 9:16, unir, quemar subtítulos, normalizar audio, exportar | Estándar; no instalado |
| **faster-whisper** (GPU local) | Transcribir y sacar tiempos de palabra; hace el SRT | Proyectos de agentes lo usan (AI ShortForm Editor, Super Video Maker); ~1 GB con torch |
| **auto-editor** | Quitar silencios | No encontré integraciones con agentes; opcional |
| **Remotion / HyperFrames** | Gráficos animados y títulos programados | Hay proyectos con agentes (OpenMontage, Kinocut). Más pesado de lo que pide el MVP |
| **Kinocut / mcp-video** | MCP de ffmpeg con comprobaciones | Joven; no necesario si hay scripts propios |

Patrón común de los proyectos agénticos (F): transcribir → el agente escribe una lista de cortes (EDL) en JSON → ffmpeg la renderiza. Lo que cambia con CapCut es que la EDL se escribe como **borrador** y el acabado final se hace a mano.

## Riesgos

| Riesgo | Estado |
|---|---|
| Términos de CapCut sobre automatización | F: resúmenes de terceros, no el texto oficial. Hay que leerlos antes de usar la nube |
| Pérdida de proyectos | V el mecanismo (CapCut reescribe el borrador al cerrar); mitigación: copia del borrador antes de tocarlo |
| Música y plantillas | V la regla del repo (`docs/videos/README.md`): solo música libre de derechos; Pro marca la exportación |
| Privacidad | Escribir borradores y ffmpeg/Whisper son 100 % locales; la nube de CapCut y sus funciones IA suben el vídeo |
| Subida automática | Las plataformas la prohíben (F, README de `capcut-cli`); publicar es manual |

## Recomendación inicial (confianza: media-alta)

**Híbrido: ffmpeg + faster-whisper para lo mecánico y escribir el borrador de CapCut con `pyCapCut` para el acabado a mano. Computer use solo para pulsar Exportar y como último recurso.**

- Confianza alta en que (b) funciona con 9.5 en este equipo (los borradores son de texto plano).
- Confianza media en que siga funcionando con 9.7: falta el spike.
- Confianza baja en (a) como método principal.
- Primera tarea: spike de medio día para (1) comprobar que 9.7 crea borradores en texto plano, (2) generar con `pyCapCut` un borrador con 3 clips y un SRT y abrirlo, (3) exportar a mano.

## Fuentes (consultadas el 03-11-2026)

- pyCapCut: <https://github.com/GuanYixuan/pyCapCut>, <https://pypi.org/project/pycapcut/>
- capcut-cli (MIT): <https://github.com/rupy1014/capcut-cli>, <https://github.com/renezander030/capcut-cli/blob/master/docs/jianying-encryption.md>
- Cifrado de JianYing 6.0+: <https://gist.github.com/renezander030/521e6c6e8590a2a6e917009d9313bc55>
- Esquema de `draft_content.json`: <https://gist.github.com/renezander030/80823f1d47081c312d2c1f9edd20dc22>
- Caso JianYing 9.0.0 (reescribe espejos): <https://github.com/renezander030/capcut-cli/issues/148>
- VectCutAPI: <https://docsearch.algolia.com/mcp/docs/repo/sun-guannan/vectcutapi>
- MCP no oficiales: <https://github.com/Atx-Guy/capcut-mcp-server>, <https://github.com/MigueDuque/capcut-mcp-server-extended>
- API y MCP de CapCut en 2026: <https://www.wireflow.ai/blog/capcut-api>, <https://voyager.so/blog/capcut-mcp>, <https://www.wireflow.ai/blog/capcut-mcp>
- Planes y límites: <https://www.eesel.ai/blog/capcut-pricing>, <https://vidpros.com/capcut-pro-vs-free/>, <https://dupple.com/learn/is-capcut-free>, <https://www.allable.ai/blog/capcut-pricing/>, <https://reelvideocaptions.com/blog/capcut-auto-captions-not-free-anymore.html>, <https://fluxnote.io/guides/capcut-ai-features-free-vs-paid-2026>, <https://blitzcutai.com/blog/capcut-remove-silence>
- Edición agéntica: <https://github.com/KyaniteLabs/kinocut>, <https://github.com/Bomx/super-video-maker-skill>, <https://github.com/FeezRM/AI-ShortForm-Editor>, <https://pinggy.io/blog/openmontage_agentic_video_production/>
- Computer use en Windows: <https://www.thurrott.com/a-i/anthropic/334498/anthropic-brings-claude-computer-use-to-windows>, <https://agentatlas.pages.dev/news/claude-windows-stable-2026.html>, <https://www.usecarly.com/blog/claude-capcut-integration/>
