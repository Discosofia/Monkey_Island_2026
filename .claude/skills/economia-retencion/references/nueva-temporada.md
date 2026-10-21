# Preparar una temporada del pase

Lista para cada temporada nueva (la Temporada 1 es "El Despertar del Volcán"). El sistema es del grupo
G3 de la Fase 9 (`docs/PLAN.md`): temporadas en `src/shared/Data/Seasons.luau` (en orden; la nueva va
detrás), cuentas en `src/shared/SeasonPass.luau`, servidor en `src/serverShared/SeasonPass.luau` y
ventana en `src/shared/UI/SeasonPassPanel.luau`. En Studio, el panel de pruebas del Lobby tiene
"⭐ +500 XP de pase", "⭐ Siguiente nivel del pase", "🌋 Premium del pase (sí/no)" y "📆 Reloj del pase
+7 días" (última semana, descanso y cierre).

1. **Tema y fechas.** Un tema que encaje con algo de la partida (bioma, jefe, evento). Inicio
   (`startsAt`, 00:00 UTC) en `Data/Seasons`; dura `Config.Season.Days` (30) y deja
   `Config.Season.RestDays` (7) de descanso: la siguiente empieza 37 días después o más tarde.
2. **Premios.** **Uno premium en cada nivel** (todos cosméticos: ~8 grandes en los niveles clave, uno que
   evoluciona por grados y el resto pequeños; uno inmediato en el nivel 1 y el final exclusivo) y ~8
   cosméticos gratis. Con pocos premium la pista se ve vacía y no anima a comprar (21-10-2026); el resto de niveles gratis con Ámbar, tiempo de huevo (con tope) y provisiones,
   que solo se desbloquean con nivel ganado jugando. Nada de la temporada anterior se repite como
   premio final.
3. **Contenido.** Modelos con `modelos-3d-roblox` (de frente y **de espaldas**: el jugador se ve por
   detrás), emotes con `animaciones-roblox` (los publica el usuario y pone los ids), variantes de
   mascota claramente distintas (colores y rasgos nuevos, no un tinte).
4. **Misiones.** Revisar el pool de semanales: alguna nueva ligada al tema o a lo último añadido.
5. **Calculadora.** `informe()` sin alertas: el habitual termina entre los días 20 y 26, el casual
   llega al nivel 12, el intenso no termina antes del día 12; auditoría de pago limpia.
6. **Lobby.** Cartel del pase con el tema y la cuenta atrás; aviso la primera vez que se entra en la
   temporada nueva.
7. **Retirar.** Los exclusivos de la temporada que acaba no vuelven a la tienda.
8. **Documentar.** `docs/GDD.md` (temporada en curso), `docs/LANZAMIENTO.md` (fechas, productos) y la
   línea base de `modelo-economico.md` si cambian los números.
