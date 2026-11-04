# Vídeos del juego: Shorts, Reels y YouTube

Tres tipos: **short** (9:16, 15–60 s), **reel** (9:16, hasta 90 s) y **youtube** (16:9, devlog de 1–3 min). Primero va el guion narrativo por escenas (`docs/videos/guiones/`), después se buscan los planos en la carpeta de tomas con `tools/video/tomas.py` (`inventario`, `explorar`, `detalle`, `storyboard`), y con el guion técnico se crea el borrador. Las tomas de cada vídeo están en `O:\Videos Primal banana\<vídeo>\`; la plantilla de notas es `notas-plantilla.txt`.

Guion técnico de cada vídeo en `docs/videos/shorts/<id>.json`. Los borradores de CapCut se crean con:

```bash
build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/<id>.json [--lang es|en] [--solo-vista]
```

Crean `build/videos/borradores/<id>-<idioma>-vN/` (cada ejecución, una carpeta nueva) con CapCut cerrado. Para abrirlos se copia la carpeta a `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft\`. Reglas de contenido y de grabación: [README.md](README.md).

## Formato del guion

| Campo | Qué |
|---|---|
| `formato` | `short` (por defecto), `reel` o `youtube`: el lienzo (1080×1920 o 1920×1080) y la duración que se espera (aviso si no cuadra) |
| `carpeta` | Opcional: carpeta de las tomas dentro de `O:/Videos Primal banana`. Con ella, `toma` puede ser solo el nombre del archivo |
| `cortes[].toma` | Ruta de la toma en `O:/` (o el nombre, con `carpeta`), o `portada` (cierre; entra entera a lo ancho) |
| `desde`, `dura`, `velocidad` | Trozo de la toma (segundos) y su velocidad; en la línea dura `dura / velocidad` |
| `clase` | Opcional: `juego` (el juego a pantalla completa), `studio` (el juego dentro de Studio, sin cinta ni Explorador) o `visor` (el visor 3D de Studio en edición). Define la zona útil y el volumen (juego 0,5; Studio 0). Sin `clase`: la zona de siempre y volumen 1 |
| `cx`, `cy`, `zoom` | Centro del recuadro (fracción de la toma) y zoom. El script lo mete en la zona útil de la clase. En vertical el zoom 1 es la toma entera de alto (mínimo 1,28 sin clase); en `youtube`, la zona útil entera |
| `textos.es` / `textos.en` | `en` (segundo de inicio), `dura`, `texto`, `y` (altura, de -0,33 a 0,33 en vertical, el tercio central, y de -0,45 a 0,45 en `youtube`; por defecto -0,2) y `chico` |
| `voz.es` / `voz.en` | Opcional: las frases que se leerán con el texto a voz de CapCut, en una pista `voz` como subtítulos pequeños abajo (por defecto `y` -0,3). Mismos campos que los textos |
| `musica` | Opcional: `{ "pista": "docs/videos/musica/alta/<archivo>.mp3", "volumen": 0.3 }`. Solo vale una pista con fila en el registro de licencias |
| `faltan` | Opcional, solo para el storyboard: lista de `{ "plano", "como", "sustituto" }` con las tomas que hay que grabar |

Para ver un guion con fotogramas: `build/videos/.venv/Scripts/python -I tools/video/tomas.py storyboard docs/videos/shorts/<id>.json` crea `build/videos/proyectos/<id>/storyboard.html` (autocontenido; se publica como Artifact).

## Short 1: Ladrones y jefes (`jefes.json`, 15,99 s)

| Tiempo | Plano (plano del tráiler) | ES | EN |
|---|---|---|---|
| 0:00–0:03 | Capuchinos ladrones (1) | ¡Te roban la comida! | They steal your food! |
| 0:03–0:06,7 | Los 4 jefes a ×3 (7) | Derrota a los jefes de la isla. | Defeat the island's bosses. |
| 0:06,7–0:13 | Gorila de Ceniza y lluvia de rocas (7) | Sobrevive a la erupción. | Survive the eruption. |
| 0:13–0:16 | Portada | ¡Ven con tus amigos! · Gratis en Roblox · Hasta 5 amigos | Bring your friends! · Free on Roblox · Up to 5 friends |

Música: la del usuario, de las bibliotecas de YouTube o TikTok (no va en el borrador).

## Short 2: Mascotas y monturas (`mascotas.json`, 17,7 s)

| Tiempo | Plano (plano del tráiler) | ES | EN |
|---|---|---|---|
| 0:00–0:03,6 | El huevo manchado (8) | ¡Salva el huevo legendario! | Save the legendary egg! |
| 0:03,6–0:10,2 | Desfile de mascotas, dos recuadros (8) | Colecciona 16 mascotas. | Collect 16 pets. |
| 0:10,2–0:14,7 | Quetzalcóatl planeando (8) | Y vuela con 3 monturas. | And fly with 3 mounts. |
| 0:14,7–0:17,7 | Portada | ¡Ven con tus amigos! · Gratis en Roblox · Hasta 5 amigos | Bring your friends! · Free on Roblox · Up to 5 friends |

## Short 3: Elige tu rol (`roles.json`, 14,1 s: 0,9 s menos del mínimo de 15 s; si el usuario lo quiere más largo, se alarga un corte)

| Tiempo | Plano (plano del tráiler) | ES | EN |
|---|---|---|---|
| 0:00–0:06,3 | Los roles con su equipo, 3 recuadros de la misma toma (4) | Elige tu rol. · Guerrero · Cazador · Mago · Médico | Pick your role. · Warrior · Hunter · Mage · Medic |
| 0:06,3–0:11,3 | Habilidad de tres roles (4) | Cada uno, su habilidad. | Each one, its own skill. |
| 0:11,3–0:14,1 | Portada | ¡Ven con tus amigos! · Gratis en Roblox · Hasta 5 amigos | Bring your friends! · Free on Roblox · Up to 5 friends |

Solo hay tomas de habilidad de tres roles (guerrero, cazador y mago); el médico sale solo en el texto.

## Short 4: Arenas PvP (`pvp.json`, 15,2 s)

| Tiempo | Plano (plano del tráiler) | ES | EN |
|---|---|---|---|
| 0:00–0:03,6 | Dunas: explosión y bandera (9) | ¿Prefieres pelear? (hasta 0:04) | Rather fight? |
| 0:03,6–0:06,2 | Dunas: la bandera en su base (9) | Captura la bandera en Dunas. (desde 0:04,3) | Capture the flag in Dunes. |
| 0:06,2–0:12,2 | Laboratorio: dos miras y un pasillo en primera persona (9) | Dispara en el Laboratorio. | Shoot it out in the Laboratory. |
| 0:12,2–0:15,2 | Portada | ¡Ven con tus amigos! · Gratis en Roblox · Arenas PvP por equipos | Bring your friends! · Free on Roblox · Team PvP arenas |

Los cortes de Dunas y el Laboratorio son más largos que en el tráiler (hasta 1 s de margen de la toma). Los textos de este Short usan los tiempos del guion (`pvp.json`).

## Título, descripción y etiquetas (los sube el usuario)

Reglas: sin Robux ni «gana dinero» (README.md). El enlace del juego lo pone el usuario al publicar. Para TikTok se usan las mismas etiquetas con `#fyp` si quiere. Los títulos llevan `#Shorts` solo en YouTube.

| Short | Idioma | Título | Descripción |
|---|---|---|---|
| `jefes` | ES | ¡Te roban la comida! Derrota a los 4 jefes de la isla 🌋 #Shorts | Naufragas en una isla llena de monos salvajes: derrota a los jefes y sobrevive a la erupción. Juega gratis en Roblox con hasta 5 amigos. |
| `jefes` | EN | They steal your food! Beat the island's 4 bosses 🌋 #Shorts | Shipwrecked on an island full of wild monkeys: defeat the bosses and survive the eruption. Play free on Roblox with up to 5 friends. |
| `mascotas` | ES | Salva el huevo legendario y vuela con tu montura 🥚 #Shorts | Colecciona 16 mascotas y 3 monturas en Primal Banana Islands. Gratis en Roblox, hasta 5 amigos. |
| `mascotas` | EN | Save the legendary egg and fly your mount 🥚 #Shorts | Collect 16 pets and 3 mounts in Primal Banana Islands. Free on Roblox, up to 5 friends. |
| `roles` | ES | Elige tu rol: guerrero, cazador, mago o médico ⚔️ #Shorts | Cada rol tiene sus habilidades. Sobrevive a la isla con hasta 5 amigos. Gratis en Roblox. |
| `roles` | EN | Pick your role: warrior, hunter, mage or medic ⚔️ #Shorts | Every role has its own skills. Survive the island with up to 5 friends. Free on Roblox. |
| `pvp` | ES | ¿Prefieres pelear? Bandera en Dunas y tiros en el Laboratorio 🎯 #Shorts | Arenas PvP por equipos en Primal Banana Islands. Gratis en Roblox. |
| `pvp` | EN | Rather fight? Capture the flag and shoot it out 🎯 #Shorts | Team PvP arenas in Primal Banana Islands. Free on Roblox. |

**Etiquetas ES:** #Roblox #PrimalBananaIslands #Monos #Supervivencia #Shorts #Gaming #RobloxEspañol #Mascotas #PvP
**Etiquetas EN:** #Roblox #PrimalBananaIslands #Monkeys #Survival #Shorts #Gaming #RobloxGames #Pets #PvP
