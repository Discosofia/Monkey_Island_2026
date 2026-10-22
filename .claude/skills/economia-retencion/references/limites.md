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
| Pago | 0 | Nada de Robux da poder, Ámbar, tiempo de huevo, objetos ni algo aleatorio (alerta dura). Se revisa también lo que tiene id 0 ("Próximamente"): se vende en cuanto se crea el producto |

Las alertas de pago no se aceptan con una razón de diseño: se rediseña lo que las dispara.
