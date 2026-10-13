# Lanzamiento (Fase 6)

Todo el código del lanzamiento está hecho. Lo que queda son **ajustes en el Creator Hub y en Studio**, que solo puedes hacer tú con tu cuenta. Sigue esta lista en orden.

## 1. Antes de nada: probar

1. Repasa la lista de pruebas de las Fases 2 a 6 (está en el mensaje de entrega de Claude y en [PLAN.md](PLAN.md)).
2. Activa **StreamingEnabled** en la Isla y prueba en un móvil ([RENDIMIENTO.md](RENDIMIENTO.md)).
3. Activa el acceso a las API en Studio para probar el guardado ([SETUP.md](SETUP.md#guardado-de-datos-fase-28)).

## 2. Sonido

1. En Studio, abre la **Caja de herramientas → Audio** (o el Creator Store en el navegador).
2. Busca música con licencia de Roblox (por ejemplo, de **APM Music**: es gratis usarla en tus juegos). Ideas:
   - **Lobby y día:** algo tropical y tranquilo (marimbas, percusión suave).
   - **Noche:** ambiente tenso, selva nocturna.
   - **Asedio y La Gran Tropa:** tambores rápidos.
   - **Jefe:** épica.
3. Copia el ID de cada pista (botón derecho → *Copiar ID del recurso*) y pégalo en `src/shared/Data/Sounds.luau` con el formato `"rbxassetid://123456789"`.
4. La tecla **M** silencia la música.

## 3. Tienda cosmética (Robux)

1. **Creator Hub → tu experiencia → Monetización → Pases → Crear pase**.
2. Crea un pase por cosmético de `src/shared/Data/Cosmetics.luau`: Estela dorada, Estela de la selva, Título "Rey de la selva" y Aura de banana. Ponle imagen (512×512) y precio (los cosméticos suelen ir de 50 a 200 Robux).
3. Copia el **ID** de cada pase en su `gamePassId`. Con `0` sale como "Próximamente".
4. Los huevos y las mascotas **no se venden** con Robux (solo se consiguen jugando). Es una decisión del GDD para cumplir las normas de Roblox sobre objetos aleatorios de pago: no lo cambies.

## 4. Servidores privados

**Creator Hub → tu experiencia → Monetización → Servidores privados → Activar** (gratis o con precio). El código ya lo soporta: quien entra al Lobby privado viaja a una Isla reservada solo para su grupo.

## 5. Página del juego

| Qué | Dónde | Recomendación |
|---|---|---|
| Nombre | Configuración de la experiencia → Información básica | **Primal Banana Island: Monkey Survival** (si cambias el nombre, cámbialo también en `Config.GameName`) |
| Descripción | Igual | Usa el pitch del GDD (§1) y menciona: 20 jugadores, roles, jefes, mascotas, PvP opcional |
| Icono | Igual | 512×512, un mono enfadado + banana brillante, colores vivos, legible en pequeño |
| Miniaturas | Igual | 3–5 capturas a 1920×1080: asedio nocturno, un jefe, el Basecamp construido, una mascota |
| Género | Igual | Supervivencia |
| Dispositivos | Igual | Ordenador, móvil, tableta (y consola si lo pruebas con mando) |
| Cuestionario de madurez | Configuración → Cuestionario | ✅ Ya lo hiciste. Repásalo si añades contenido nuevo |

## 6. Analítica

**Creator Hub → tu experiencia → Analítica**. El juego ya envía:

- **Incorporación (embudo):** cada paso del tutorial y "Completado". Si mucha gente abandona en un paso, ese paso se explica mal.
- **Economía:** Ámbar ganado (al terminar cada partida) y gastado (tienda del Lobby).
- **Eventos propios:** `MatchVictory` y `MatchDefeat`, con los días sobrevividos.
- **Retención** (D1, D7) y sesiones: Roblox las calcula solo.

## 7. Beta cerrada

1. Deja la experiencia en **Privada** o limita el acceso a **Amigos** (Configuración → Permisos), o usa un servidor privado.
2. Invita a 10–20 personas. Pídeles que jueguen al menos una partida completa (hasta perder o ganar).
3. Revisa la Salida de los servidores (F9 → Server) buscando errores en rojo, y la analítica.
4. Ajusta números en `src/shared/Config.luau` y en `src/shared/Data/`.
5. Cuando una partida típica dure 3 o más días y la gente quiera repetir: pasa al punto 8.

## 8. Lanzamiento

1. Pon la experiencia en **Pública** (los dos places ya están publicados).
2. Opcional: **Anuncios patrocinados** en el Creator Hub con un presupuesto pequeño los primeros días, para que el algoritmo tenga datos.
3. Vigila la Salida, la analítica y los comentarios la primera semana.

## Después del lanzamiento (Fase 7)

Temporadas con lore (tarjetas del laboratorio), jefes y eventos nuevos, mutadores de partida ("Luna roja", "Temporada de lluvias") y balance según los datos.
