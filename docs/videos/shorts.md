# Shorts de YouTube y TikTok (9:16, 15–30 s)

Guion de cada Short en `docs/videos/shorts/<id>.json`. Los borradores de CapCut se crean con:

```bash
build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/<id>.json [--lang es|en] [--solo-vista]
```

Crean `build/videos/borradores/<id>-<idioma>-vN/` (cada ejecución, una carpeta nueva) con CapCut cerrado. Para abrirlos se copia la carpeta a `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft\`. Reglas de contenido y de grabación: [README.md](README.md).

## Formato del guion

| Campo | Qué |
|---|---|
| `cortes[].toma` | Ruta de la toma en `O:/`, o `portada` (cierre; entra entera a lo ancho) |
| `desde`, `dura`, `velocidad` | Trozo de la toma (segundos) y su velocidad; en la línea dura `dura / velocidad` |
| `cx`, `cy`, `zoom` | Centro del recuadro 9:16 (fracción de la toma) y zoom. El script lo mete en la zona útil de la toma (sin la barra de herramientas ni la franja de Studio): el zoom mínimo es 1,28 |
| `textos.es` / `textos.en` | `en` (segundo de inicio), `dura`, `texto`, `y` (altura, de -0,33 a 0,33: el tercio central; por defecto -0,2) y `chico` |

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
