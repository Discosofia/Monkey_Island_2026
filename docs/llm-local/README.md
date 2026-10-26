# Modelo local: gpt-oss-20b con LM Studio y CodeGPT

Cómo trabajar en el juego con `openai/gpt-oss-20b` en local. El modelo trabaja desde dos sitios:

| Dónde | Para qué | MCP |
|---|---|---|
| **Chat de LM Studio** | Trabajar en Roblox Studio: inspeccionar, modelos voxel, calculadoras `Economia` y `Equilibrio`, ideas de diseño | `Roblox_Studio` (`~/.lmstudio/mcp.json`) |
| **CodeGPT en VS Code** | Leer y editar `src/`, auditorías | Ninguno: solo sus herramientas de archivos (ver paso 4 de la sección 3) |

El MCP de Studio es el oficial de Roblox: `%LOCALAPPDATA%\Roblox\mcp.bat` lanza `StudioMCP.exe`, el mismo que usa Claude (`.mcp.json`). Paquetes como `@roblox/mcp-server` o `@roblox/explorer-mcp-server` **no existen**.

## Archivos de esta carpeta

| Archivo | Qué es |
|---|---|
| `base.md` | Reglas y arquitectura del proyecto (resumen de `CLAUDE.md`). Va en todos los presets |
| `modelos.md`, `animaciones.md`, `interfaz.md`, `combate.md`, `economia.md` | Resúmenes de las skills de `.claude/skills/` |
| `diseno.md` | Estado del GDD y del PLAN, y cómo proponer ideas |
| `auditoria.md` | Método de auditoría archivo por archivo, con cada riesgo citado literal, y formato del informe |
| `generar_presets.py` | Crea los presets "Monos – …" de LM Studio con `base.md` más cada resumen, y copia `base.md` a `AGENTS.md` (raíz del repo) para CodeGPT |
| `informes/` | Informes de auditoría que genere el modelo |

Los resúmenes salen de las skills. Si cambia una skill o `CLAUDE.md`, actualiza su resumen y vuelve a ejecutar `python docs/llm-local/generar_presets.py`.

## 1. LM Studio: cargar el modelo (una vez)

1. **My Models** → `gpt-oss-20b` → ⚙️ (configuración por defecto del modelo):
   - **Context Length:** `65536`.
   - **GPU Offload:** el máximo. Si no cabe en los 12 GB de la 4070 Ti, LM Studio deja el resto en la RAM.
   - **Flash Attention:** activado.
   - **K Cache / V Cache Quantization:** `Q8_0`. La mitad de memoria para el contexto, casi sin pérdida.
   - **Reasoning Effort:** `Medium`. Pon `High` para la auditoría y el equilibrio.
2. Guarda la configuración como predeterminada del modelo. Si no, el servidor lo carga con 4096 de contexto y las extensiones fallan a mitad de tarea. Eso es probablemente lo que pasó con Cline.
3. Mide la velocidad con una pregunta larga. Si con 64k va demasiado lento, baja a `49152`.

## 2. LM Studio: chat con Roblox Studio

1. Abre Roblox Studio con el place y su servidor MCP activado, igual que cuando trabajas con Claude.
2. En LM Studio, la pestaña **Program** de la barra derecha → **Install → Edit mcp.json** muestra el archivo, ya configurado con `Roblox_Studio`. En el chat, activa el interruptor de ese servidor (sale como `mcp/…`).
3. Elige el preset de la tarea (desplegable de presets, arriba): **Monos – Modelos**, **Animaciones**, **Interfaz**, **Combate**, **Economía**, **Diseño** o **Auditoría**.
4. Primera prueba: *"Lista los Studios abiertos y dime en qué estado está cada uno"*. Después: *"Ejecuta la calculadora Economia y enséñame las Alertas"*.

LM Studio pide confirmación antes de cada herramienta. Deja la confirmación activada para `execute_luau` y `multi_edit`.

**Leer archivos del repo desde el chat (opcional).** Los procedimientos de modelos, animaciones e interfaz mandan a Studio scripts de `.claude/skills/*/scripts/`. El chat de LM Studio no lee archivos por sí solo. Puedes:
- pegar el script en el chat;
- usar CodeGPT, que sí lee archivos;
- o añadir a `~/.lmstudio/mcp.json` el servidor de archivos oficial de MCP, limitado al repo. Ojo: también puede escribir.
  ```json
  "repo": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:\\Users\\jose\\Documents\\GitHub\\Monkey_Island_2026"]
  }
  ```

## 3. CodeGPT en VS Code

1. **Provider:** LM Studio (local), URL `http://localhost:1234`. El servidor tiene que estar encendido: LM Studio → **Developer → Start server**, con *Just-in-Time model loading* activado.
2. **Model:** `openai/gpt-oss-20b`.
3. **Instrucciones del agente:** CodeGPT no tiene un cuadro para pegarlas: lee `AGENTS.md` en la raíz del repo. Ese archivo es una copia de `base.md` que escribe `generar_presets.py`; no lo edites a mano. Para una tarea concreta, empieza la conversación con *"Lee docs/llm-local/combate.md y …"*. CodeGPT puede leer archivos, así que basta con nombrarlos.
4. **MCP: sin Roblox Studio.** CodeGPT 3.24.79 manda a LM Studio las herramientas MCP con un formato que LM Studio rechaza (error `invalid_literal … expected "function"` en las posiciones 12 a 39, que son las 28 herramientas de Studio). Por eso `~/.codegpt/mcp_config.json` está vacío. Studio se usa desde el chat de LM Studio. La configuración con Studio está guardada en `~/.codegpt/mcp_config.roblox.json` para probarla con una versión nueva de CodeGPT.
5. **Herramientas de terminal:** CodeGPT puede ejecutar comandos. Permítele `stylua`, `selene` y `rojo build`, y nunca `git commit` ni `git push`.

Prueba: *"Lee src/shared/Config.luau y dime cuánto dura el día y la noche de la Isla"*. La respuesta correcta es 10 min de día y 7 de noche (`Config.Match`).

## 4. Qué dejarle al modelo local y qué a Claude

| Bien con gpt-oss-20b | Mejor con Claude |
|---|---|
| Preguntas sobre el código ("¿dónde se calcula X?") | Cambios que tocan varios sistemas o el perfil guardado |
| Ideas de diseño y fichas para `docs/PLAN.md` | Equilibrio fino con la calculadora (muchas iteraciones) |
| Cambios pequeños en `Data/*` y `Config` | Modelos voxel complejos: Claude ve las capturas, gpt-oss no |
| Resumir un archivo: qué hace y sus funciones (ver el límite en auditoria.md) | Buscar riesgos (auditoría) y corregirlos |
| Inspeccionar Studio y ejecutar las calculadoras | Animaciones (hay que mirar las tiras) |

gpt-oss-20b **no ve imágenes**, así que `screen_capture` no le sirve. Los resúmenes le dicen que revise con números y te pida mirar.

## Si algo falla

- **"Context length exceeded" o respuestas que se cortan:** el modelo se cargó con otro contexto. Expulsa el modelo y vuelve a cargarlo (paso 1).
- **El MCP de Studio no aparece:** Studio cerrado o su MCP apagado. `mcp.bat` busca `StudioMCP.exe` en la versión instalada de Studio, así que tras una actualización de Studio basta con reiniciar LM Studio o VS Code.
- **Inventa archivos o paquetes:** pídele que primero liste la carpeta o haga grep. Las reglas de `base.md` le piden leer antes de editar.
- **Cambió algo que no debía:** `git status` y `git diff`. Nada se sube sin "aprobado".
