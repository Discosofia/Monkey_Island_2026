# Guía de instalación (Fase 0)

Esta guía te lleva desde cero hasta tener el **Lobby** y la **Isla** funcionando y conectados, con el código del repositorio sincronizado en Roblox Studio.

> ⏱️ Tiempo estimado: 1 a 2 horas la primera vez.
> 💡 Si un paso falla, copia el mensaje de error y pásamelo: lo resolvemos juntos.

---

## Cómo funciona todo junto

```mermaid
flowchart LR
  R["Repositorio en GitHub (código)"] -->|"GitHub Desktop: Pull"| L["Carpeta en tu PC"]
  L -->|"rojo serve"| P["Plugin de Rojo en Studio"]
  P --> S["Roblox Studio: tu juego"]
  S -->|"Publicar"| RB["Roblox (jugadores)"]
```

- El **código** vive en GitHub. Yo lo escribo y tú lo descargas con *Pull*.
- **Rojo** copia ese código dentro de Studio automáticamente.
- El **mapa** (terreno, modelos) lo construyes en Studio y se guarda en Roblox, no en GitHub.

> ⚠️ **No edites en Studio los scripts que vienen del repositorio** (las carpetas `Shared`, `ServerShared`, `Server` y `Client`). Rojo los sobrescribe y perderías los cambios. Los cambios de código se hacen en el repo.

---

## Paso 1: Instalar los programas

| Programa | Para qué | Descarga |
|---|---|---|
| **Roblox Studio** | Editor del juego | https://create.roblox.com/ (botón "Start Creating") |
| **VS Code** | Ver y editar el código | https://code.visualstudio.com/ |
| **GitHub Desktop** | Descargar el código del repo sin usar comandos | https://desktop.github.com/ |
| **Rokit** | Instala Rojo, StyLua y Selene en las versiones del proyecto | https://github.com/rojo-rbx/rokit |

**Instalar Rokit:**

- **Windows:** en https://github.com/rojo-rbx/rokit/releases descarga el `.zip` que termina en `windows-x86_64.zip`, descomprímelo, abre una terminal (PowerShell) en esa carpeta y ejecuta:
  ```
  ./rokit self-install
  ```
- **Mac:** abre la Terminal y ejecuta:
  ```
  curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
  ```

Después **cierra y vuelve a abrir** la terminal y comprueba que funciona con `rokit --version`.

---

## Paso 2: Descargar el repositorio

1. Abre **GitHub Desktop** e inicia sesión con tu cuenta de GitHub.
2. **File → Clone repository** → elige `Discosofia/Monkey_Island_2026` → **Clone**.
3. Arriba, en **Current branch**, elige la rama con los últimos cambios (por ahora `claude/monkey-island-roblox-design-ro2mg4`).
4. Pulsa **Open in Visual Studio Code**.
5. VS Code te ofrecerá instalar las **extensiones recomendadas** (Rojo, Luau, StyLua, Selene). Acepta.

---

## Paso 3: Instalar las herramientas del proyecto

En VS Code abre una terminal (**Terminal → New Terminal**) y ejecuta:

```
rokit install
```

Si pregunta si confías en las herramientas (*trust*), responde que sí. Comprueba que funciona con:

```
rojo --version
```

Debería mostrar `Rojo 7.6.1`.

---

## Paso 4: Instalar el plugin de Rojo en Studio

En la misma terminal ejecuta:

```
rojo plugin install
```

Abre (o reinicia) Roblox Studio. Debería aparecer un botón **Rojo** en la pestaña **Plugins**.

---

## Paso 5: Crear la experiencia con sus 2 places

1. En Studio: **New → Baseplate**.
2. **File → Publish to Roblox** → **Create new experience** → nombre: `Primal Banana Island`. Este primer place es el **Lobby** (el lugar de inicio).
3. Crea el segundo place, la **Isla**:
   - En Studio abre **View → Asset Manager → Places**, haz clic derecho y elige **Add New Place**.
   - (También se puede hacer desde el [Creator Hub](https://create.roblox.com/dashboard/creations), en tu experiencia → **Places**. La interfaz de Roblox cambia a veces: si no ves la opción, avísame.)
   - Cámbiale el nombre a `Isla`.

---

## Paso 6: Copiar los IDs de los places al código

Cada place tiene un número de ID. El código lo necesita para viajar del Lobby a la Isla.

1. Abre el place **Lobby** en Studio.
2. En la **barra de comandos** (**View → Command Bar**) escribe y pulsa Enter:
   ```lua
   print(game.PlaceId)
   ```
3. Copia el número que aparece en la ventana **Output**.
4. Repite lo mismo con el place **Isla**.
5. Pon ambos números en `src/shared/Config.luau`:
   ```lua
   PlaceIds = {
   	Lobby = 1234567890, -- tu número
   	Island = 9876543210, -- tu número
   },
   ```
6. Guarda el archivo. Si quieres que quede guardado en el repo, pásame los dos IDs y los subo yo (no son secretos).

---

## Paso 7: Tamaño del servidor de la Isla (20 jugadores)

En el [Creator Hub](https://create.roblox.com/dashboard/creations), entra en tu experiencia → **Places** → **Isla** → configuración del place, y pon el **tamaño del servidor (Server Size / Max Players)** en **20**.

---

## Paso 8: Sincronizar el código con Rojo

Hay un proyecto de Rojo para cada place:

| Place | Comando (en la terminal de VS Code) | Puerto |
|---|---|---|
| Lobby | `rojo serve lobby.project.json` | 34872 |
| Isla | `rojo serve island.project.json` | 34873 |

1. Abre el place **Lobby** en Studio.
2. En VS Code ejecuta `rojo serve lobby.project.json` y deja la terminal abierta.
3. En Studio: **Plugins → Rojo → Connect**. Revisa que el puerto sea **34872** y conecta.
4. Aparecerán las carpetas `Shared` (en ReplicatedStorage), `ServerShared` y `Server` (en ServerScriptService) y `Client` (en StarterPlayer → StarterPlayerScripts).
5. **File → Publish to Roblox** para guardar el place con el código.
6. Repite con la **Isla**: ábrela en Studio, ejecuta `rojo serve island.project.json`, conecta usando el puerto **34873** y publica.

---

## Paso 9: Probar

**En Studio (botón Play):**
- **Lobby:** verás el título *Primal Banana Island* y el botón **Ir a la Isla**. Al pulsarlo aparecerá el mensaje *"Los viajes no funcionan en Studio…"*. Es normal: Roblox no permite viajar entre places desde Studio.
- **Isla:** verás arriba a la izquierda los minutos de día y noche leídos de `Config`, y el botón **Volver al Lobby**.

**En el juego publicado** (desde la web de Roblox o la app, entrando a tu experiencia):
- Pulsa **Ir a la Isla**: deberías viajar a la Isla.
- Pulsa **Volver al Lobby**: deberías volver.

**Prueba de sincronización:** con Rojo conectado, cambia en `Config.luau` el valor `DayLengthSeconds = 10 * 60` por `12 * 60` y guarda. En la Isla, al darle a Play, el HUD dirá *"Día 12 min"*. Después vuelve a dejarlo en `10 * 60`.

✅ **Criterio de salida de la Fase 0:** todo lo anterior funciona.

---

## Rutina de trabajo diaria

1. **GitHub Desktop → Fetch origin → Pull** para bajar los últimos cambios.
2. `rojo serve <proyecto>.project.json` y conectar en Studio.
3. Probar en Studio y, si hace falta, publicar.
4. Contarme qué funcionó, qué no y qué se siente raro. Con eso preparo el siguiente cambio.

---

## Problemas comunes

| Problema | Solución |
|---|---|
| `rokit` o `rojo` "no se reconoce como comando" | Cierra y vuelve a abrir VS Code o la terminal. Si sigue igual, repite el paso 1. |
| Rojo no conecta | Comprueba que `rojo serve` sigue abierto y que el puerto del plugin coincide (34872 Lobby, 34873 Isla). |
| *"Falta configurar el ID de…"* | No se completó el paso 6. |
| El botón de viaje no hace nada en el juego publicado | Revisa que **ambos** places estén publicados con el código (paso 8) y que los IDs del paso 6 sean correctos. |
| *"Infinite yield possible on ReplicatedStorage:WaitForChild("Remotes")"* | El código del servidor no se cargó. Revisa que la carpeta `Server` exista en ServerScriptService (paso 8). |
