# Preparar una temporada del pase

Lista para cada temporada nueva (la Temporada 1 es "El Despertar del Volcán"). El sistema del pase
llega en el grupo G3 de la Fase 9 (`docs/PLAN.md`): ajusta los nombres de archivo si cambian.

1. **Tema y fechas.** Un tema que encaje con algo de la partida (bioma, jefe, evento). Inicio y fin en
   UTC en `Data/Seasons`; 30 días + 7 de descanso antes de la siguiente.
2. **Premios.** ~12 premium (todos cosméticos, uno inmediato en el nivel 1, el final exclusivo) y ~8
   cosméticos gratis; el resto de niveles gratis con Ámbar, tiempo de huevo (con tope) y provisiones,
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
