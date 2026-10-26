# Diseño del juego: estado y cómo proponer (para ideas y mejoras)

<!-- Resumen de docs/GDD.md (v0.4) y docs/PLAN.md, 26-10-2026. Para el detalle, lee solo la sección del GDD que necesites. -->

## La idea

Naufragas en una isla tropical llena de monos salvajes que roban la comida. Con **hasta 4 amigos** (5 jugadores por partida) eliges rol (guerrero, cazador, mago o médico), fortificas el Basecamp, sobrevives a noches cada vez más duras y derrotas a los 4 jefes para encender la baliza de rescate. El público tiene unos 10–16 años y juega en móvil y PC. El estilo es voxel y colorido, sin sangre.

**Pilares:** cooperar por necesidad · la isla está viva (tropas, alfas, ladrones, clima) · tú eliges el riesgo (el PvP es voluntario) · siempre progresas.

## Bucles

- **Partida (Isla):** explorar → recolectar y cazar → volver al Basecamp → fabricar y construir → aguantar la noche → ir a zonas más peligrosas. Un día dura 10 min y una noche 7. Hay un jefe cada 2 días (días 2, 4, 6 y 8) y la baliza se puede encender desde el día 8. Una victoria lleva unas 2 h 16 min.
- **Entre partidas (Lobby):** Ámbar y XP de rol → mejoras y talentos; huevos → nido con horas reales → mascota o montura; bestiario; pase de temporada; tienda de cosméticos en Ámbar.
- **Retención:** calendario de 7 días (faltar no lo reinicia), misiones diarias (fácil, media del rol y difícil), semanales (5 de 13), contratos de partida y el pase de 30 niveles (premium solo cosmético).
- **Dunas:** arena PvP de captura la bandera, con equipo horizontal comprado con Ámbar.

## Qué está hecho

Las fases 0–11 están cerradas en código. Lo último: Combate v2 (Fase 10: cadena de golpes, guardia, parry, Evasivo, proyectiles, rebote contra muros) y Monturas (Fase 11: Llama Andina, M1–M3). La tabla completa está en `docs/PLAN.md` §3.

## Qué falta (lo pendiente de verdad)

- Pruebas con 2 jugadores (PvP, vida de los jefes, defensa del huevo) y en el juego publicado.
- Publicar los tres places a la vez.
- Lo que hace el usuario en `docs/LANZAMIENTO.md`: música, pases, página, beta cerrada.
- Equilibrio pendiente: rendimientos decrecientes del control sobre los enemigos, la mascota Mono X-7 (45 % del DPS de un arma, el límite es 40 %), talentos al máximo, golpes de los monos al día 20 y el daño de los jefes, que no crece con los días.
- Preguntas abiertas del GDD §17: orden fijo o aleatorio de los jefes, el nombre final de la moneda, qué hacen las bananas primales y la duración final del día y la noche.

## Cómo proponer una idea

1. Lee primero la sección del GDD que toca. Índice: §5 partida, §6 jugador y roles, §7 isla, §8 monos, §9 botín y fabricación, §10 Basecamp, §11 huevo y mascotas, §12 PvP, §13 lore, §14 economía.
2. Escribe la idea como **ficha**:
   - qué es y para quién (casual, habitual, intenso, grupo de amigos);
   - qué problema resuelve (pilar, hueco del bucle, retención);
   - cómo se ve y se juega en el **móvil**;
   - qué sistemas toca (archivos `Data/*` y `Config`);
   - riesgos: ¿rompe una regla de pago?, ¿da poder?, ¿necesita equilibrio?
3. Si toca números, di qué calculadora la mediría: `Economia` para premios, misiones y precios, y `Equilibrio` para daño y control.
4. Propón **2–3 variantes** con la recomendada primero. No escribas código hasta que el usuario elija.
5. Si el usuario aprueba una idea, escríbela como entrada nueva para `docs/PLAN.md` (grupo, contenido y estado "pendiente"), pero **no cambies el GDD** sin que te lo pida.

## Límites del diseño

- Robux: solo cosmético. Lo aleatorio nunca es de pago.
- Las misiones se pueden hacer jugando solo.
- El título "Superviviente de la Isla" es solo para quien gana una partida.
- Las monturas y mascotas se consiguen jugando (huevos), nunca con Robux.
- Nada de gore. La violencia es estilizada y el público es infantil o juvenil.
