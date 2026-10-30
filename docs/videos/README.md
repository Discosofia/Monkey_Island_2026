# Vídeos promocionales

Guiones y guía de grabación de los vídeos del juego para YouTube, Shorts y TikTok.

| Archivo | Qué |
|---|---|
| [trailer.md](trailer.md) | Tráiler de YouTube (16:9, unos 75 s), plano a plano, en español e inglés |
| [trailer.es.srt](trailer.es.srt), [trailer.en.srt](trailer.en.srt) | Subtítulos del tráiler con los tiempos del guion (solo la voz; las etiquetas en pantalla van como gráficos). Se suben a YouTube o se importan en el editor |

Los Shorts y TikTok (9:16, 15–30 s) van en la tanda TR2 de [PLAN.md](../PLAN.md) y reutilizan las tomas del tráiler.

## Reglas de contenido

- **Solo se ve juego real.** Nada que no esté en el juego publicado.
- **Sin gore.** Los monos desaparecen con un "¡puf!". Es lo que dice el cuestionario de madurez ([LANZAMIENTO.md §9](../LANZAMIENTO.md#9-menores-de-16-roblox-kids-y-select)).
- **Nada de Robux ni de "gana dinero"** en la voz ni en los textos. El pase y los cosméticos no salen.
- **Nombre:** *Primal Banana Islands: Monkey Survival*. La portada y el icono están en [art/portada](../../art/portada/README.md).
- **Texto en pantalla en el tercio central**, para que el recorte vertical de los Shorts lo conserve.

## Ajustes de grabación

| Qué | Valor |
|---|---|
| Resolución | 1920×1080 a 60 fps para el tráiler. Para Shorts, grabar igual en 16:9 y recortar en el montaje a 1080×1920 |
| OBS | Captura de ventana de Studio o del cliente, MP4/MKV, bitrate 20 000 kbps, codificador por hardware |
| Gráficos de Roblox | Calidad 10 (Studio: Ajustes → Rendering), sombras y luz en máximo |
| Composición | Dejar libre el recuadro central 9:16 (el 31,6 % del ancho). `TrailerCamara.guia(true)` lo dibuja y se apaga antes de grabar |
| Cuenta atrás | Las tomas de `Trailer` esperan 3 s para dar a grabar en OBS |
| Cámara de edición | Al acabar, `Trailer.limpiar()` la deja en `Fixed`: Studio guarda ese estado en el place |

## Música y sonido

- La música de la biblioteca de audio de Roblox **solo vale dentro de Roblox**. En un vídeo de YouTube o TikTok se usa música sin derechos: la **Biblioteca de audio de YouTube Studio** (YouTube) y la **Biblioteca de sonidos comerciales** (TikTok).
- Voz en off: grabada por una persona o con una voz sintética de licencia comercial. Una versión por idioma, con los mismos tiempos.
- Los sonidos del juego (golpes, rugidos) se graban con la propia captura, sin música dentro del juego (tecla **M** la silencia).

## Cómo se graban las tomas

Hay tres tipos de toma, y el guion dice cuál es cada una:

1. **Dioramas preparados** (`roles`, `jefes`, `huevo`, `mascotas`, `monturas`) y el **vuelo sobre la isla** (`isla`). Se hacen en el Studio de la Isla, en modo edición:

   ```lua
   local m = game.ServerStorage.Tools.Trailer:Clone() -- el Clone evita la caché de require
   local T = require(m)
   T.toma("jefes")   -- monta la escena y lanza la cámara tras la cuenta atrás
   T.limpiar()       -- la quita, devuelve la luz y deja la cámara en Fixed
   ```

   Si en edición la cámara no avanza, se graba en **Run (F8)**.
2. **Juego real** en Play. Se activa **🎬 Modo grabación** en el panel de pruebas (esconde el HUD y la barra de Roblox; se pulsa otra vez para volver) y los botones del panel (👑 Siguiente jefe, 🌕 La Gran Tropa ya, 📡 4 piezas + baliza…) preparan cada situación. Para una cámara libre: Shift+P (Freecam de Roblox) en el juego publicado.
3. **Dunas y Laboratorio.** Los constructores de esos mapas no están en el Studio de la Isla, así que se graban en sus propios places, con partidas reales con amigos.

> Antes de probar en Play, hay que hacer copia del perfil real (ver CLAUDE.md, "Studio y MCP: trampas conocidas").

## Lista de comprobación antes de publicar

1. Las dos versiones de voz duran lo mismo que el montaje.
2. Ningún HUD de pruebas ni texto de depuración en cuadro.
3. El primer segundo tiene movimiento y el gancho del texto.
4. Título, ficha del juego y enlace al final (la miniatura es [portada-principal-1920x1080.png](../../art/portada/portada-principal-1920x1080.png)).
5. Descripción con el enlace del juego y las etiquetas: `roblox`, `survival`, `monkeys`, `co-op`, `pvp`.
