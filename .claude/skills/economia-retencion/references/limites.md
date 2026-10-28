# Límites de la calculadora

Copia de `LIMITES` en `src/island/tools/Economia.luau`: si cambias uno, cambia los dos.

| Límite | Valor | Por qué |
|---|---|---|
| `misionMinutos.Facil` | 3–15 min | Cabe en una sesión corta (Creator Rewards cuenta 10 min al día) |
| `misionMinutos.Media` | 15–35 min | Pide una partida de verdad, no un rato |
| `misionMinutos.Dificil` | 35–90 min | Pide avanzar en la partida (días 3–6), no solo empezarla |
| `diariaMasLarga` | ≥ 35 min | Si la diaria más larga del pool pide menos, todas caen en la primera hora y el jugador se queda sin metas |
| `paseHabitualDia` | día 20–26 | El habitual termina el pase con holgura (no hace falta jugar los 30 días) pero no en dos semanas |
| `paseCasualNivel` | ≥ 12 | El casual ve una buena parte del pase (gratis incluido) |
| `paseIntensoDiaMin` | ≥ día 12 | Quien juega mucho no se lo acaba en una semana (luego vienen los niveles en bucle) |
| `paseMisiones` | 40–70 % | Las misiones guían (variedad) pero jugar normal también avanza |
| `ambarGastado` | ≥ 60 % | El habitual tiene en qué gastar lo que gana; si no, el Ámbar deja de motivar |
| `tiendaHabitualDiaMin` | ≥ día 30 | La tienda de cosméticos en Ámbar no se le acaba al habitual dentro del mes: si lo compra todo, el Ámbar vuelve a sobrar |
| `equipoNivel3Dia` | ≥ día 4 | El nivel 3 de armas y armadura no llega antes del jefe del día 4 |
| `equipoNivel4Dia` | ≥ día 6 | El nivel 4 (Forja volcánica) no llega antes del jefe del día 6 |
| `monturaHabitualDia` | día 12–30 | Las monturas son especiales: el habitual pasa del 50 % de tener una dentro del mes, pero no en la primera semana y media |
| `pionerosTodasDiario` | día 75–110 | Tirada de pioneros: quien entra a diario tiene las 3 monturas (con la mítica) al 50 % en unos 3 meses (decidido el 27-10-2026), no en semanas |
| `parcelaIntensoDiaMin` | ≥ día 40 | Con la parcela desde el día 1, el intenso no tiene las 7 estructuras al III en un mes: es la meta de los meses siguientes (63.000 Ámbar le dan el día 46, decidido el 27-10-2026) |
| `parcelaAmigosDiaMax` | ≤ día 150 | El grupo de amigos que gana las tiene al III en unos meses, no en medio año (con 63.000, el día 105) |
| `parcelaVentajaDia` | ≤ 25 % | Al III, huerto, taller y forja juntos no ahorran más de esta parte de un día de partida de recoger (las ventajas son pequeñas; las decididas en el plan dan el 23 %) |
| Ámbar por minuto del PvP (sin constante: se compara en la sección 2) | Lab ≤ Dunas | El Ámbar por minuto del Laboratorio (partida corta, 7,5 min) no pasa del de Dunas: el shooter no es la vía rápida al Ámbar (se calcula en la sección 2) |
| `ambarPvpDia` | ≤ 700 al día | Los topes diarios de Dunas (400) y del Laboratorio (300) juntos: el PvP no supera lo que se gana en una buena sesión de la Isla |
| Pago | 0 | Nada de Robux da poder, Ámbar, tiempo de huevo, objetos ni algo aleatorio (alerta dura). Se revisa también lo que tiene id 0 ("Próximamente"): se vende en cuanto se crea el producto |

Las alertas de pago no se aceptan con una razón de diseño: se rediseña lo que las dispara.
