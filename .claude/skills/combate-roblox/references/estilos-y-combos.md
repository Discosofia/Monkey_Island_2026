# Estilos de juego y combos

Qué es cada rol cuando pelea, cómo se construye un combo y qué no puede pasar nunca. Sirve para
diseñar o revisar un rol, una habilidad, un combo o una variante de equipo. Los números concretos
están en `equilibrio.md` y en la calculadora; aquí están las reglas.

## 1. Arquetipos de los roles

Cada rol tiene que **ganar en su escenario y perder en otro**. Si un rol es el mejor en todo, sobra
otro; si no es el mejor en nada, nadie lo elige. La calculadora lo mide (§4).

| Rol | Arquetipo | Gana cuando… | Pierde cuando… | Su combo típico |
|---|---|---|---|---|
| ⚔️ Guerrero | Presión directa y control cercano ("rushdown"): cierra distancias, aguanta y agrupa | El enemigo está cerca o agrupado; protege a otros con el Grito | Le mantienen a distancia (cazador, mago con Parpadeo) | Embestida → Grito → Torbellino · Grito → Embestida → Rompehuesos |
| 🏹 Cazador | Control del espacio ("zoner"): trampas, marcas y daño desde lejos | Hay distancia y pasillos (cepos en el camino); el equipo aprovecha su marca | Le alcanzan cuerpo a cuerpo sin cepo preparado | Cepo → Marcar → Disparo múltiple · Marcar → Cepo → Flecha perforante |
| 🔮 Mago | Daño en área y movilidad ("buster"): congela, se recoloca y detona | Grupos quietos o congelados; peleas de zona (bandera, altar) | Le pillan sin Parpadeo; un objetivo suelto y móvil | Nova → Parpadeo → Bola de fuego · Bola de fuego → Nova → Meteoro |
| ⛑️ Médico | Apoyo y desgaste: cura, protege, duerme y envenena | Peleas largas en grupo; el equipo pelea junto a él | Solo contra un rol de daño (duelo espejo ~30 s: decidido así el 20-10-2026) | Dardo → Escudo → Ungüento · Escudo → Dardo → Polvo somnífero |

Estilos que el **jugador** elige dentro de su rol (horizontales, nunca mejores sin más): talentos
(`Data/Talents`) y, en Dunas, las variantes de equipo (`Data/ArenaGear`). Una variante cambia cómo se
juega (más daño a cambio de más recarga, más área a cambio de menos alcance), y su duelo no se aleja
más de ±12 % del básico.

## 2. Estructura de un combo

Un combo bien hecho tiene tres partes:

1. **Abre** (paso 1): una habilidad que toca y marca (cepo, hielo, embestida, dardo). Si falla, deja al
   que la usó expuesto (recarga o hueco), para que abrir sea una decisión y no un reflejo.
2. **Extiende** (paso 2): mantiene al objetivo a tiro o lo recoloca (Grito que atrae, Parpadeo,
   Marcar que vuelve a sujetar). Sus golpes contra lo marcado son críticos seguros.
3. **Remata** (paso 3): el golpe grande, con su efecto extra (`finisher` en `Data/Combos`).

Conexión: el remate deja abierto el otro combo del rol en su paso 1 (A → B → A…), y la racha premia
encadenar. Reglas de los combos de habilidades: ninguno usa la definitiva (V), la ventana entre pasos
es de 6 s (desde que el siguiente esté listo) y el premio tiene tope (`UltRefundMaxSeconds`,
`damageBonus` por rol).

**Cadena de golpes con el arma (Fase 10, C4).** Es otro nivel, más corto: 4 golpes con el arma
cuerpo a cuerpo en ~2 s, y el 4.º remata (empuja o lanza). Sirve para "ganar el cambio de golpes"
y para preparar una habilidad; no sustituye a los combos de habilidades.

## 3. Lo que no puede pasar

1. **Combo sin escape que mate.** Si una secuencia deja al objetivo sin poder actuar todo el rato,
   tiene que acabarse antes de quitarle el límite de vida de `equilibrio.md` §3 (~35 %). Defensas:
   inmunidad al soltarse (`Status`), rendimientos decrecientes, escalado del combo en PvP y Evasivo.
2. **Opción sin respuesta.** Cada opción fuerte tiene su contra:

   | Opción | Respuesta |
   |---|---|
   | Bloquear siempre | La guardia se gasta; imbloqueables y rotura de guardia |
   | Parry | Amago (empezar un golpe y cancelarlo) |
   | Combo largo | Evasivo |
   | Imbloqueable | Preparación larga y visible; castigo si falla |
   | Huir con la bandera | Cepos, Nova, la velocidad reducida del portador |
   | Control desde lejos | Esquiva (invulnerable), coberturas |

3. **Algo que obligue a todos a lo mismo.** Si enlazar combos da más del +35 % (límite), quien no los
   hace (móvil, principiantes) se queda atrás; si da menos del +5 %, nadie aprende a hacerlos.
4. **Ventaja por dispositivo o por ping.** Las ventanas y los números son los mismos para todos.

## 4. Cómo se mide un estilo

- **Escenarios de la calculadora**: 1 objetivo, grupo (`grupo = 4`), jefe, duelo de la arena
  (sección 6) y duelos cruzados. Cada rol de daño tiene que ser el mejor o el segundo en al menos uno.
- **Reparto**: entre guerrero, cazador y mago, ±20 % en grupo y ±30 % a un objetivo.
- **Combo**: el valor de enlazar en 180 s (+5 % a +35 %) y el hueco entre combos.
- **Telemetría** (al publicar): `AbilityUses`, `AbilityLinked`, `ComboCompleted`, `DamageBySource`
  por rol, y desde la Fase 10 los contadores de guardia, parry, Evasivo, amagos y remates.

## 5. Amagos y lectura (Fase 10, C8 ✅)

- El amago se hace pulsando la guardia durante la preparación de un golpe (gratis, como mucho uno
  por segundo) o de una habilidad (15 de estamina y 1,5 s de recarga en vez de la entera). La
  guardia se pone en ese momento: amagar y parar en la misma pulsación es una opción (y cancelar tu
  habilidad para defenderte de algo que viene, otra).
- Cada habilidad tiene su preparación (0,15–0,35 s; al momento las de defensa y huida): es la
  ventana para leerla y para amagarla. Las imbloqueables se ven venir al menos `Config.Reaction`
  (preparación + lo que tarda en caer: el Meteoro, con su aviso rojo).
- Tiene que **verse** que es un amago (humo corto), para que un buen jugador pueda leerlo: el amago
  engaña al reflejo, no a la vista.
- Lo mismo vale para todo: preparación visible antes de lo fuerte, sonido distinto para golpe,
  bloqueo, parry y rotura, y número y cómic que cuenten qué ha pasado.
