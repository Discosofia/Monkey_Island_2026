# Verificación paso a paso de todas las entregas

Sigue los bloques en orden. Cada bloque dice **qué hacer**, **qué debe pasar ✅** y **qué hacer si falla ⚠️**.
Marca cada casilla al comprobarla.

> **Cómo avisarme de un fallo:** dime el número del paso (por ejemplo "5.2, paso 4"), qué esperabas y qué pasó, y copia las líneas en **rojo** de la ventana **Salida** de Studio (Vista → Salida). Una captura ayuda mucho.

---

## 0. Preparación (una sola vez)

- [ ] **Actualizar el código:** en VS Code, *Pull* de la rama `claude/monkey-island-roblox-design-ro2mg4` (o en GitHub Desktop, *Fetch origin* → *Pull*).
- [ ] **Reiniciar Rojo:** cierra los cuatro `rojo serve` y vuelve a lanzarlos:
  - `rojo serve lobby.project.json` (puerto 34872)
  - `rojo serve island.project.json` (puerto 34873)
  - `rojo serve dunas.project.json` (puerto 34874, para la arena: §8)
  - `rojo serve laboratorio.project.json` (puerto 34875, para el Laboratorio: §24)
- [ ] En Studio, abre el place **Isla** y conecta el plugin de Rojo al puerto **34873**. Haz lo mismo con el **Lobby** en el **34872**, con **Dunas** en el **34874** y con el **Laboratorio** en el **34875**.
- [ ] **Acceso a las API** (para el guardado): *Archivo → Configuración del juego → Seguridad → Habilitar acceso de Studio a los servicios de API*, en **los 4 places**. Publica después de activarlo.
- [ ] **Panel de pruebas:** al darle a ▶ *Jugar* en Studio verás abajo a la izquierda un botón **🛠️ Pruebas**. Despliega órdenes para no tener que esperar días de partida: dar materiales, sacar un jefe, el huevo, una caja, cambiar el clima… Solo existe en Studio: en el juego publicado no aparece.
- [ ] **Dos jugadores** (para PvP, grupos y la vida de los aliados): *Test → Clients and Servers → 2 Players → Start*. Si no lo encuentras, busca "clients" con **Ctrl+Mayús+P**.
- [ ] **Copia del perfil:** antes de probar en Studio, 👑 Admin → 📋 Perfil → 📦 Hacer copia. Así no se pierde tu perfil real (ver §10.0).

**Teclas de la Isla:**

| Acción | Tecla |
|---|---|
| Elegir arma o herramienta | 1–5 (las 2 armas del rol, hacha, pico, martillo) |
| Usar arma o herramienta | Clic |
| Esquivar | Q |
| Guardia (pulsar = parry, mantener = bloqueo) | F · mando: L2 |
| Correr | Mayús |
| Comer | G |
| Curar | H |
| Beber | E (junto al agua) |
| Bolsa | B |
| Diario de campo | J |
| Habilidades del rol | Z, X, C, R y V (la definitiva) · mando: mantén R1 + A, B, X, Y o L1 |
| Silenciar música | M |
| Construir con el martillo | Clic coloca · R gira · T cambia de pieza · F quita |

---

## Índice por modo de prueba (30-10-2026)

Las secciones no se renumeran (PLAN.md, las skills y el código las citan). Este índice dice qué hay en cada bloque y cómo probarlo. **Por dónde empezar con el juego publicado y 2 jugadores: §88**, que ordena los pasos en sesiones.

**Casillas:** `[ ]` pendiente · `[x]` hecho · `[⏭]` superado por un cambio posterior (se conserva el texto, no hay que probarlo) · `(= §N pM)` el mismo paso está repetido en otra sección: al marcar uno, marca los dos.

**Modos:**
- **1J-Studio:** Play en Studio con el panel 🛠️ Pruebas. Casi siempre se puede repetir en el publicado con el panel 👑 Admin (jefes, gigante, clima, luna roja, mascotas, Doble Ámbar, mantenimiento) o jugando de verdad.
- **2J:** hace falta otro jugador. En Studio (*Clientes y servidores*) o, mejor, publicado con 2 cuentas.
- **Pub-1 / Pub-2:** juego publicado, con 1 o 2 jugadores.
- **3J+:** hace falta más de 2 jugadores (queda fuera hasta que haya más gente).
- **Móvil:** teléfono, emulador (*Prueba → Dispositivo*) o mando.
- **Calc:** calculadora (`Economia`, `Equilibrio`, `Rendimiento`) en modo edición, en el Studio de la Isla.
- **Idioma:** inglés u otro idioma de Roblox.
- **Visual:** revisar a ojo modelos, armaduras y animaciones.
- **Solo Studio:** necesita el panel 🛠️ (`SkinKills`, bajas falsas, ⏩ Saltar fase), el lag simulado o la consola.

| Bloque | Secciones | Tema | Pendientes | Modos |
|---|---|---|---|---|
| Base de la Isla | §2.3–§2.8 | forja, ladrones, asedio, fiebre, derrota, guardado | 30 | 1J-Studio (→ Pub-1) |
| Lobby y roles | §3.1–§3.5 | rol, talentos, tutorial, naufragio | 26 | 1J-Studio, 2J |
| Bestiario y mundo | §4–§5.5 | monos, jefes, huevo, mascotas, PvP, clima | 34 | 1J-Studio, 2J |
| Extras | §6.1–§6.6 | baliza, clasificaciones, sonido, números de combate | 33 | 1J-Studio, Pub-1, Pub-2 |
| Retención | §7, §9 | nido, calendario, misiones, menú del Lobby | 27 | 1J-Studio (tiempo real en publicado) |
| Dunas | §8 | arena PvP | 13 | 1J-Studio, 2J, Pub-2, 3J+ |
| Fase 9 | §10 | pase, misiones v2, cosméticos, tiendas | 39 | 1J-Studio |
| Combate v2 | §11 | Isla y Dunas | 30 | 1J-Studio, 2J (casi todo → Pub-1 y Pub-2) |
| Regalos y admin | §12–§13 | propiedad única, panel de admin | 27 | 2J, Pub-2 |
| Monturas y pioneros | §14–§17 | jaguar, quetzal, bienvenida, otra definitiva | 31 | 1J-Studio, 2J, Móvil |
| Fase 12 | §18 | victoria y parcela permanente | 30 | 1J-Studio, 2J, Móvil |
| Inglés | §19–§23 | idioma en el Lobby, la Isla, Dunas y los datos | 30 | Idioma, 2J |
| Laboratorio | §24–§30 | duelo, cola, Rondas, mapas, recompensas, skins | 130 | 2J, Pub-2, 3J+, Móvil |
| Movimiento y combate del Lab | §31–§40 | andar, deslizar, esquiva, daño, miras, espectador | 160 | 1J-Studio, 2J, Móvil, 3J+ |
| Rendimiento | §41–§44 | medición, fusión, LOD, efectos de jefes | 36 | 1J-Studio, 2J, Móvil, Calc |
| Armas del Lab | §45–§48 | Avispa, Escorpión, Kraken, Dragón | 28 | Solo Studio (`SkinKills`), Visual, Calc |
| Fase 18: admin y jefes | §49–§52 | menús en combate, panel, gigante, jefe | 26 | Pub-2 con 👑 Admin |
| Fase 18: Laboratorio | §53–§54 | disparo, puntería, movimiento | 10 | Pub-2, Móvil |
| Fase 18: tiempo | §55–§57 | luz, luna, luna roja | 23 | Pub-1, Pub-2 con 👑 Admin |
| Fase 18: mascotas | §58–§61 | capibara, quetzal, ajolote, clips | 15 | Pub-1 con 👑 Admin, Visual |
| Fase 18: modelos | §62–§73 | armaduras, armas y trajes rehechos | 51 | Visual, Móvil |
| Fase 19: combate a distancia | §74–§87 | líneas, poses, impactos, ADS, miras, killfeed, rig, vista | 184 | Pub-1, Pub-2, Móvil, Calc |
| Tráiler de YouTube | §91 | modo grabación, cámara de tomas, Freecam y montaje | 18 | 1J-Studio, 2J, Pub-1, Visual |
| Fase 22: Shorts con CapCut | §102 | borradores 9:16, exportación sin marca, teléfono | 8 | CapCut, Móvil |

Los totales por sección salen de contar las casillas `[ ]` entre un `## ` y el siguiente. Ahora hay unos 1.020 pendientes (eran 1.055 antes de este reparto), más los 18 de la §91 y los 8 de la §102.

---

## 2.3 Taller del curandero y forja de piedra

1. [ ] Abre la **Isla** y dale a ▶. En **🛠️ Pruebas**, pulsa **🎒 +50 de todo**.
   ✅ A la derecha salen avisos "+50 …" y en la Bolsa (B) aparecen todos los materiales.
2. [ ] Equipa el **martillo** (5). A la derecha aparece la lista de piezas: elige **🏥 Taller del curandero**.
   ✅ Se ve una vista previa transparente que sigue al ratón.
3. [ ] Acércate a la hoguera del centro y ponlo dentro del círculo central (a menos de ~40 studs del centro).
   ✅ La vista previa se ve **verde**; al hacer clic se construye una tienda de lona.
   ⚠️ Si sale roja: algo estorba (bancos, puntos de aparición) o estás fuera del núcleo. Muévete un poco.
4. [ ] Haz lo mismo con la **⚒️ Forja de piedra**.
5. [ ] Acércate al taller: sale el aviso **"Usar · Taller del curandero"**. Pulsa E.
   ✅ Se abre la pantalla con **Ungüento, Vendas (×3) y Antídoto**.
6. [ ] Fabrica un **Ungüento** y un **Antídoto**.
7. [ ] Acércate a la forja (aviso **"Forjar"**) y fabrica:
   - [ ] **Machete afilado**: ✅ el machete de la barra se sustituye por el afilado.
   - [ ] **Armadura de hueso**: ✅ se ve sobre el torso y sustituye al chaleco si lo llevabas.
   - [ ] **Lanza** y **Garrote**: ✅ ahora están en la forja, no en la mesa de trabajo.
8. [ ] Sal del Basecamp, deja que un mono te pegue y pulsa **H**.
   ✅ Te curas: usa la venda si te falta poca vida y el ungüento si te falta mucha.

## 2.4 Capuchinos ladrones y miedo al fuego

1. [ ] De día, sal por cualquier portón y camina por la selva cerca de la empalizada (los capuchinos viven a 120–250 studs del centro). Son **pequeños, marrones y con la cara clara**.
2. [ ] Déjate alcanzar por uno.
   ✅ No te muerde: sale el aviso **"¡Un capuchino te ha robado 3 …!"**, dice "¡JE JE!" y huye.
3. [ ] Persíguelo (corre con Mayús) y derrótalo.
   ✅ Aviso **"Recuperas lo robado: …"**.
4. [ ] Fabrica una **antorcha** en la mesa de trabajo y equípala. Acércate a un grupo de monos ardilla o aulladores.
   ✅ Dicen "🔥 ¡IIH!" y se apartan de ti.

## 2.5 Asedio nocturno

1. [ ] Con materiales (🛠️ **+50 de todo**), equipa el martillo y ve a uno de los **portones** de la empalizada.
2. [ ] Pon **Estacas** justo en el hueco del portón. Son cuadros de 4×4 que pinchan hacia todos los lados: no hace falta girarlos. Ponlos en fila (encajan en la cuadrícula) para cubrir el hueco.
   ✅ Solo se pueden poner en el **perímetro**: entre las parcelas y la empalizada, incluidos los portones.
3. [ ] Cierra el portón: lo más fácil es la **🚧 Barricada de portón**, que mide justo el hueco entre los postes. Céntrala en el hueco y gírala con **R** hasta que quede alineada con la empalizada.
   ✅ Se ve verde y, al colocarla, el portón queda cerrado del todo.
   También puedes usar dos **muros** de 8 studs, pero dejan una rendija a cada lado.
4. [ ] Pulsa **⏩ Saltar fase** para que sea de noche.
   ✅ Aviso **"Cae la noche: los monos asediarán el Basecamp…"**.
5. [ ] Espera unos **30 segundos**.
   ✅ Aviso **"¡Asedio! Oleada 1/3: N monos desde el …"** y bajo el reloj la línea **"⚔️ Asedio: N monos atacan el Basecamp"**.
6. [ ] Ve al portón que dice el aviso.
   ✅ Los monos llegan al portón; al pasar por las estacas pierden vida y golpean los muros con "💥". Si rompen todo, entran y te atacan **aunque estés dentro**.
7. [ ] Pulsa **⏩ Saltar fase** (amanece).
   ✅ Los monos del asedio desaparecen.

## 2.6 Fiebre del mono

1. [ ] En 🛠️, pulsa **🤒 Fiebre a 90**.
   ✅ Aparece una **barra morada** bajo la estamina y la pantalla se ve **borrosa**.
2. [ ] Sal y deja que te muerdan hasta llegar a 100.
   ✅ Pierdes vida poco a poco y sale un aviso de fiebre.
3. [ ] Con un **antídoto** en la bolsa (2.3), pulsa **H**.
   ✅ "💉 La fiebre ha bajado": la barra desaparece y la vista vuelve a ser nítida.
4. [ ] Quédate solo con **carne cruda** como comida y pulsa **G** cuando tengas hambre (🛠️ **Hambre y sed al 10**).
   ✅ Aviso "La carne cruda sube la fiebre" y la barra morada sube.

## 2.7 Dificultad y derrota

1. [ ] En 🛠️, pulsa **💀 Terminar: derrota**.
   ✅ Pantalla de resultados: "El Basecamp ha caído", días, monos, reanimaciones, caídas, jefes y **Ámbar ganado**, con una cuenta atrás.
   ⚠️ En Studio el viaje al Lobby falla (es normal: los viajes solo funcionan publicados). Para seguir probando, para (■) y vuelve a darle a ▶.
2. [ ] **Derrota real (opcional):** de noche, solo, deja que te tumben y no te levantes.
   ✅ A los **10 s** de estar caído de noche, la partida termina.

## 2.8 Guardado de datos

1. [ ] Con el acceso a las API activado: en la Isla, termina con **💀 Terminar: derrota**.
   ✅ Aviso **"✨ +N de Ámbar guardado"**.
   ⚠️ Si la Salida dice *"juega con datos temporales"*, falta el acceso a las API (paso 0).
2. [ ] Para (■), abre el place **Lobby** y dale a ▶.
   ✅ Arriba se ve **"✨ Ámbar: N"** con lo que ganaste.

## 3.1 Lobby: rol, talentos, tienda y grupos

En el place **Lobby**, con ▶:

1. [ ] Ve al cartel **Elige tu rol** y pulsa **E**: salen **Guerrero, Cazador, Mago y Médico**, cada uno con su pasiva y sus habilidades. Elige **Médico**.
   ✅ El botón pasa a "Elegido".
   - Si tenías XP con el antiguo **Recolector**, ahora es del **Mago** y sus puntos de talento están libres.
2. [ ] En 🛠️, pulsa **⭐ +300 XP del rol**. Icono **🌟 Talentos** de la barra (o "Ver talentos" en la ventana de roles, que palpita en rojo).
   ✅ "3 puntos libres": aprende un rango de cualquier talento.
3. [ ] En 🛠️, pulsa **✨ +500 Ámbar**. Icono **🛒 Tienda**: compra **Corazón fuerte** y **Kit de náufrago**.
   ✅ El Ámbar baja y sube el rango (1/3).
4. [ ] **Grupo** (con 2 jugadores): el jugador 1 invita al 2; al 2 le sale **"te invita a su grupo"** y pulsa Aceptar.
   ✅ Los dos ven **"👥 Grupo: …"**. El viaje en grupo solo se puede probar publicado (paso 6.4 final).

## 3.5 Lobby del naufragio

En el place **Lobby**, con ▶ (se construye solo la primera vez; ver [MAPA.md](MAPA.md), Lobby):

1. [ ] Apareces en el borde sur de la **plaza**, un óvalo de arena libre, con luz de atardecer.
   ✅ Dentro solo están la hoguera, el nido de huevos y tres muñecos de práctica (a la izquierda). Los carteles hacen de borde y miran al centro: arriba a la izquierda **🐾 Mascotas** (con el nido delante), arriba la **Bitácora del capitán**, arriba a la derecha **Elige tu rol**, a la derecha el **Ranking** y debajo el de la **🎖️Isla de dunas☠️(PvP)**. Arriba a la izquierda, fuera de la plaza, el carguero **«Esperanza»** encallado y escorado: casco de acero azul y rojo con un **boquete** por el que se ve la bodega (cajas, bidones, bananas y una luz de emergencia), castillo blanco con puente de mando, chimenea y radar, contenedores de colores en cubierta (uno a punto de caer por la borda) y una grúa amarilla. Al fondo, la **isla con el volcán humeando** y ríos de lava.
2. [ ] Mira la interfaz al llegar.
   ✅ El título se va a los 5 s; arriba queda la pastilla del Ámbar. A la izquierda, la barra de iconos (Talentos, Tienda, Misiones, Estilo, Grupo, Diario, Ajustes) y "Invitar amigos" debajo. No hay ventana abierta. Lo comprueba entero la sección 9.
3. [ ] Sube por la **pasarela metálica** a la cubierta y entra por el boquete a la bodega.
   ✅ Se puede andar por la cubierta entre los contenedores, subir por la escalera exterior al techo del primer piso del castillo y entrar en la bodega.
4. [ ] Mira el campamento, abajo a la izquierda fuera de la plaza: tienda de lona azul, contenedores varados (uno abierto con cajas PRIMAL), cajas y bidones. Detrás de la bitácora, el ancla con su cadena hasta la proa.
   ✅ La bitácora se lee y cuenta el lore (tormenta, la isla, el Proyecto PRIMAL, la lancha).
5. [ ] Ve a la **lancha de rescate** de la orilla norte, detrás del cartel de roles (cartel "🚤 A LA ISLA →"), y mantén **"Zarpar a la Isla de monos"**.
   ✅ Hace lo mismo que el botón **🍌 Ir a la Isla de monos 🐒** (en Studio no viaja; publicado sí). El velero del embarcadero, al pie del cartel de la arena, dice **"Zarpar a la Isla de dunas"**.
6. [ ] Intenta alejarte nadando.
   ✅ Un muro invisible te frena a unos 160 studs.
7. [ ] **Probar el rol en la plaza.** Sin ventanas abiertas, saca un arma con 1 o 2 y usa las habilidades (Z X C R V) contra los muñecos.
   ✅ Arriba a la izquierda salen las casillas de las habilidades y de los combos (se esconden con el menú abierto). Los muñecos reciben daño con números, estados y combos, y reaparecen al romperse. La barra de objetos de Roblox sale abajo en el centro, con el botón **🍌 Ir a la Isla de monos 🐒** justo encima; con el menú abierto la barra se esconde y el botón baja.
8. [ ] Cambia de rol en el cartel **Elige tu rol**.
   ✅ Cambian al momento las armas, las casillas y las habilidades, y salen listas.
9. [ ] **Con 2 jugadores** (Prueba → Clientes y servidores → 2 jugadores): el jugador 1 usa todo lo de cada rol sobre el 2 (Torbellino, Embestida, Pisotón, Cepo, Nova de hielo, Rayo, Meteoro, Polvo somnífero, Ungüento, Dardo curativo, Escudo de hojas, Tótem, Grito de guerra) y le dispara con las armas.
   ✅ El 2 ve los efectos pero no recibe daño, curación, escudo, aturdimiento, sueño, ralentizar, marca ni cepo. Practicar no avanza las misiones del día.

## 3.2 Roles en la Isla

El rol elegido en el Lobby llega a la Isla gracias al guardado (paso 0). Para no volver al Lobby, en 🛠️ pulsa **🎭 Siguiente rol** (cambia rol, armas y habilidades) y **⚡ Habilidades listas** (quita los tiempos de espera). Busca un grupo de monos (o el muñeco de práctica) para probarlas.

1. [ ] Al entrar sale **"⚔️ Juegas como Guerrero: …"** (o tu rol) y bajo las barras **5 casillas** (Z, X, C, R, V) que dicen "lista". La V tiene borde dorado.
   - En la barra: las **2 armas del rol** en 1 y 2, el hacha en 3 y el pico en 4.
   - En móvil: un bloque de 5 botones junto al salto, con la cuenta atrás al usarlos.
   - **Combos y conexiones:** cierra un combo (p. ej. guerrero: Embestida → Grito → Torbellino) y sigue con el paso 2 del otro (Embestida → Rompehuesos) sin hacer su paso 1: sale "¡CONEXIÓN! 2 seguidos" y el paso saltado lleva "🔗".
   - Con mando: mantén **R1** y pulsa A, B, X o Y.
2. [ ] **Guerrero** (Garrote de piedra):
   - **Z Torbellino:** giras 2 s entre estelas de viento en círculo y los monos de alrededor reciben varios golpes.
   - **X Embestida:** sales disparado hacia donde apuntas dejando un rastro rojo, dañas y empujas a los monos.
   - **C Grito de guerra:** el personaje echa la cabeza atrás y abre los brazos gritando, brilla en rojo (luego un brillo rojo suave mientras dura) y salen ondas rojas; "N monos van a por ti" y te muerden menos.
   - **V Pisotón:** el suelo se agrieta desde tus pies, saltan piedras, sale polvo y tiembla la cámara; mucho daño y los monos se quedan quietos con contorno amarillo 2 s.
3. [ ] **Cazador** (Arco, empiezas con 20 flechas; se fabrican en la mesa de trabajo):
   - **Z Disparo múltiple:** 5 flechas verdes en abanico con estela verde, sin gastar flechas.
   - **X Marcar presas:** onda roja, contorno rojo y una diana (círculo, círculo interior y cruz) girando sobre cada mono marcado, y "N presas marcadas".
   - **C Cepo:** aparece un cepo de metal oxidado a tus pies; cuando un mono lo pisa, se cierra de golpe y **todos los monos a menos de 8 studs** (prueba con 🐒 Mandril aquí varias veces) quedan atrapados unos 2 s, cada uno con su ⛓️ de combo; un anillo naranja muestra el área. Pon otro **en una ladera**: queda apoyado siguiendo la pendiente (ni enterrado ni flotando) y atrapa también a los monos que están encima pero más arriba o más abajo con un brillo verde suave que aparece y se va. Como mucho 2 cepos.
   - **V Lluvia de proyectiles:** zona roja donde apuntas con una nube gris encima, de la que caen flechas durante 4 s (se quedan clavadas un momento).
4. [ ] **Mago** (Bastón mágico, dispara bolas moradas sin munición):
   - **Z Bola de fuego:** bola roja en llamas que va recta, con tres bolitas que giran a su alrededor dejando una espiral; explota al impactar y daña alrededor.
   - **X Nova de hielo:** aros helados y pinchos de hielo en el suelo; los monos cercanos quedan dentro de un bloque de hielo que se rompe en trozos al acabar, y luego andan más despacio.
   - **C Parpadeo:** donde estabas queda un punto negro que se encoge y apareces con una chispa; no atraviesa paredes ni te lleva al vacío.
   - **V Rayo encadenado:** apunta a un mono y un rayo brillante salta a los de alrededor; al apagarse deja una sombra oscura que se desvanece y los monos alcanzados echan humo. Sin mono a tiro: "No hay ningún mono a tiro" y no se gasta.
   - Las esperas son un 15 % más cortas que las de Data/Roles.
5. [ ] **Médico** (Cerbatana y machete):
   - **Z Ungüento en área:** salen hojas verdes girando en círculo y una onda verde; te curas (y a los aliados cercanos).
   - **X Dardo curativo:** dardo amarillo con cola roja; con 2 jugadores, dispara al otro herido y se cura (hojitas verdes).
   - **C Escudo de hojas:** destello amarillo y una burbuja verde con hojas girando alrededor del aliado más cercano (o de ti); los mordiscos salen como 🛡️ y, al romperse, la burbuja estalla.
   - **V Tótem sanador:** sale del suelo un tótem de madera tallada (caras, alas pintadas al estilo navajo) con una gema verde brillante arriba, sobre un suelo verde con hojas; cada segundo una onda verde cura durante 10 s. Sale **donde apunta el cursor**; si apuntas más lejos de 40 studs, a 40 studs en esa dirección, siempre sobre el suelo.
   - Con 2 jugadores ves la **vida del otro** sobre su cabeza y reanimas más rápido (el aviso dura 2 s en vez de 4).
6. [ ] **Jefes:** contra un jefe (🛠️ 👑), el Pisotón o la Nova le paran solo la mitad de tiempo y el Grito de guerra hace que vaya a por el guerrero.
7. [ ] **PvP** (2 jugadores con PvP activo en el tótem): las habilidades de daño también os hieren, a la mitad.

## 3.3 Talentos y mejoras en la Isla

1. [ ] Con **Corazón fuerte** comprado, al entrar a la Isla tienes **110** de vida máxima (se nota en la barra de vida de Roblox). El guerrero tiene 20 más (130).
2. [ ] Con **Kit de náufrago**, empiezas con **5 de madera, piedra y fibra** (mira la Bolsa con B).
3. [ ] Con un talento aprendido (p. ej. **Andanada** del cazador), la habilidad cambia: el Disparo múltiple lanza 6 flechas.
4. [ ] Con **Manos ágiles** u **Ojo para el botín** (tienda), cualquier rol recoge más rápido o saca +1 material.

## 3.4 Tutorial

1. [ ] Aparece la primera vez que entras a la Isla. Para verlo otra vez, usa una cuenta nueva en el juego publicado (o cambia `Config.Data.StoreName` a `"PlayerData_v2"`: es como empezar de cero).
   ✅ Panel arriba **"Tutorial 1/5: Equipa el hacha…"**. Cada paso pasa solo al hacerlo; también se puede **Saltar**.
2. [ ] Completa los 5 pasos.
   ✅ "¡Listo!" y no vuelve a salir.

## 4. Bestiario, especies y tropas

1. [ ] Recorre los biomas (es lo más largo; tómalo con calma):

   | Zona | Especies |
   |---|---|
   | **Playas** | Mono de cola larga (roba comida) |
   | **Ríos** | Marimonda (salta sobre ti) y Orangután (te agarra) |
   | **Montañas** | Gibón, Babuino (de noche) y Chimpancé (lanza piedras) |
   | **Volcán** | Gorila (golpe en área que aturde) |
   | **Selva** | Tití (enjambres) y Mandril (rugido que intimida) |
   | **Noche, en la selva** | Marteja: con antorcha en la mano **no** te ataca |

2. [ ] Mandriles, babuinos y chimpancés llevan un **👑 alfa**: derrótalo.
   ✅ El resto huye ("😱").
3. [ ] Pulsa **J**.
   ✅ Diario de campo: las especies que derrotaste salen con descripción y botín; las demás, "???". Debajo, **👑 Jefes**: los 4 jefes, con "???" hasta que ayudas a derrotar uno; entonces sale su guarida, descripción, botín y "derrotado: 1" (y el aviso "📖 ¡Nuevo jefe en tu diario de campo!"). El título cuenta especies y jefes.
4. [ ] Pulsa **B**.
   ✅ Los materiales raros salen en **color** según su rareza (verde, azul, morado, dorado).
5. [ ] En la **forja**, con 🛠️ +50 de todo: **Honda de liana, Hacha de hueso, Pico de hueso, Garrote de colmillo grande y Armadura de plata**.
   ✅ Cada mejora sustituye a la herramienta anterior.
6. [ ] En la **forja**, con 🛠️ +50 de todo, mira las mejoras del arma de tu rol (cambia con **🎭 Siguiente rol**):
   - Guerrero: **Maza de hueso → Mazo de hueso grueso** (sustituyen al garrote de piedra).
   - Cazador: **Arco reforzado → Arco de liana** (sustituyen al arco).
   - Mago: **Bastón dorado → Bastón de plata** (sustituyen al bastón mágico).
   - Médico: **Cerbatana de hueso → Cerbatana del chamán** (sustituyen a la cerbatana).
   ✅ Solo salen las del rol que llevas; cada una cambia el modelo y el daño del arma. El nivel 3 (y la Armadura de plata) pide **👑 Corona del caudillo**: "+50 de todo" la da (sin ella, la receta sale bloqueada).
6b. [ ] **Forja volcánica** (Fase 9, G5): construye la **🌋 Forja volcánica** en el núcleo con el martillo (piedra, obsidiana y hueso grueso) y fabrica el nivel 4 de tu rol (**Mazo volcánico, Arco de brasa, Bastón de lava o Cerbatana de azufre**) y la **Armadura volcánica** (pide **💎 Cristal de cueva**).
   ✅ El arma y la armadura cambian de modelo (basalto y obsidiana con grietas de lava); con **🛡️ Siguiente armadura** se ven las 4 versiones por rol. Todas echan humo por los hombros (hombreras con cristales de obsidiana hundidos en lava). De espaldas: volcán en escalones con ríos de lava, humo y corona de cristales (guerrero), capa de ceniza con zarpazos de lava y carcaj con flechas que arden (cazador), sol negro en anillos de fuego con llamas (mago), mochila con cristales de azufre y chimeneas de humo (médico).
6c. [ ] Ve al **volcán** y a la **sala de la cueva**: hay vetas negras de **obsidiana** con grietas de lava (10 y 5). Pícalas con el pico.
   ✅ Dan obsidiana (más con el pico de hueso) y se agotan tras 3 golpes completos; reaparecen a los 4 min.
6d. [ ] Derrota a un jefe (👑 Siguiente jefe + 💔 Jefe al 30 %).
   ✅ "🏆 Botín del jefe: … ×2"; al caer, los tesoros siguen en la Bolsa.
7. [ ] En la Salida, cada 2 minutos sale **"[Rendimiento] … streaming activado/DESACTIVADO"**.

## 5.1 Jefes

1. [ ] En 🛠️, pulsa **👑 Siguiente jefe**.
   ✅ "👑 ¡Orangután del Manglar ha despertado en los ríos!". Cada pulsación saca el siguiente: Chimpancé Caudillo, Gorila Albino, Gorila de Ceniza.
2. [ ] Ve a su guarida (en el mapa, carpeta *GuaridasJefes*).
   ✅ A menos de ~220 studs aparece arriba la **barra de vida del jefe** con su fase.
3. [ ] Pelea.
   ✅ Hace ataques especiales: círculos rojos en el suelo que avisan antes del golpe, rocas que caen, embestidas, agarres.
4. [ ] Pulsa **💔 Jefe al 30 %**.
   ✅ "¡… se enfurece! (fase 3/3)". Con el Gorila de Ceniza, además, empieza una **erupción**.
5. [ ] Derrótalo.
   ✅ Aviso "¡… ha caído! Pieza de la baliza: 1/4" y en la Bolsa su **botín legendario** (perla, corona, cristal o núcleo).

## 5.2 Huevo y nido

1. [ ] Con 🛠️ +50 de todo, construye un **Nido** en el núcleo con el martillo.
2. [ ] Pulsa **🥚 Huevo (rareza siguiente)**. Cada pulsación cambia el huevo del suelo por uno de la rareza siguiente (común → legendario).
   ✅ "¡Ha aparecido un huevo COMÚN hacia el …!" y bajo el reloj "🥚 Hay un huevo común…".
3. [ ] Encuéntralo: es un **huevo ovalado** que brilla con el color de su rareza (común crema con motas pardas, poco común verde, raro azul, épico lila y legendario dorado con motas naranjas). Mantén pulsado **"Recoger"**.
   ✅ Lo llevas sobre la cabeza, vas **más lento**, tienes la etiqueta **⚔️ PvP** y los monos cercanos van a por ti.
4. [ ] Deja que te tumben.
   ✅ El huevo **cae al suelo** y se puede volver a recoger.
5. [ ] Llévalo al nido.
   ✅ "¡El huevo común está en el nido! Defendedlo 150 s", el huevo queda **en el centro del nido**, llegan monos y bajo el reloj sale la cuenta atrás.
6. [ ] Espera a que acabe (o pulsa **🐣 Terminar la defensa del huevo**).
   ✅ La cáscara **revienta** con un destello del color de la rareza y "🥚 ¡Huevo Común a salvo! …": ya se incuba en tu nido del Lobby, está en tu mochila de huevos o queda pendiente si la mochila está llena. **No nace la mascota aquí**: se abre en el Lobby (7.1).

## 5.3 Mascotas

1. [ ] **En el Lobby:** acércate al **nido** y pulsa E (ventana del nido y la colección); con 🛠️ **🥚 Mascota al azar** consigues una sin jugar. Pulsa **Llevar**.
   ✅ Te sigue su **modelo propio**, que se mueve a su manera:
   - **Tucán** (pico naranja enorme) y **guacamaya** (roja con alas amarillas y azules): vuelan batiendo las alas.
   - **Colibrí**: flota junto a tu hombro con las alas zumbando.
   - **Rana dardo** (azul con manchas): va a saltos, más altos si corres.
   - **Tortuga**, **perezoso** (con su hatillo de troncos), **jaguarundí**, **ocelote** (con manchas), **Mono X-7** (casco de cristal y depósito brillante) y **jaguar de cristal** (translúcido, con destellos): andan por el suelo moviendo las patas al correr, y los felinos mueven la cola.
   - **Beagle** (tricolor, con la cola alta negra y la punta blanca), **labrador** (dorado, con la lengua fuera y alforjas verdes) y **pointer inglés** (blanco con la cabeza negra, manchas y moteado): van al trote botando un poco, con las orejas rebotando, y si corres galopan con las orejas hacia atrás. Quieto unos segundos, se sientan (ladean la cabeza, miran a los lados y barren el suelo con la cola) o hacen su pose: el beagle se pone en **exposición** (cabeza alta y la cola tiesa), el labrador se **tumba de lado** golpeando el suelo con la cola y el pointer hace la **muestra** (quieto, con una mano levantada y la cola recta).
2. [ ] **En la Isla:** 🛠️ **🐾 Mascota al azar** pone una mascota de prueba.
   - **Combate** (jaguarundí, ocelote, X-7): ✅ los monos cercanos reciben daño cada 2 s.
   - **Rastreo** (tucán, guacamaya): ✅ cada 5 s ves contornos amarillos en los monos cercanos.
   - **Curación** (rana): ✅ recuperas vida sola.
   - Las de apoyo y carga dan sus ventajas cuando se llevan desde el Lobby.
3. [ ] **Sabuesos** (con 🐾 **Siguiente mascota** hasta cada uno):
   - **Beagle** (común, rastreo): con un 🥚 **Huevo** en el suelo a menos de 300 studs, cada 5 s salen **huellas naranjas** delante de ti hacia el huevo y, encima del huevo, "🐾 🥚 152 studs". Más lejos de 300 o a menos de 12, nada. También resalta los monos como el tucán.
   - **Labrador** (raro, carga): al derrotar monos, de vez en cuando (un 30 % de las veces que sueltan algo) sale una línea aparte con un objeto más y el icono de tu mascota: "+1 🦴 Hueso 🦮".
   - **Pointer inglés** (épico, marca): el mono (o muñeco) más cercano a menos de 25 studs lleva una **huella naranja** encima y recibe un 15 % más de daño de todos (el garrote de piedra: 27 → 31). Con el cazador, "Marcar presas" pone su diana roja encima (20 %) y, al acabarse, vuelve la huella. A un jefe, la mitad (+7,5 %).
   - ⚙️ Ajustes: la línea de la mascota explica cada perro con sus números.

## 5.4 PvP y cajas de suministro

1. [ ] **Con 2 jugadores:** los dos van al **⚔️ Tótem PvP** (al norte de la hoguera) y lo activan.
   ✅ Etiqueta "⚔️ PvP" sobre la cabeza.
2. [ ] **Dentro** del Basecamp, golpéaos.
   ✅ No hay daño (zona segura).
3. [ ] **Fuera** del Basecamp, golpéaos.
   ✅ Hay daño. Al tumbar al otro, la recompensa sube: "⚔️ PvP · 💰1".
4. [ ] Uno de los dos vuelve al tótem para quitarlo.
   ✅ "El PvP se desactivará en 180 s" (pulsar otra vez lo cancela).
5. [ ] Pulsa **📦 Caja de suministro**.
   ✅ "¡Ha llegado una caja… a la playa del …!" y una **columna de luz dorada** en la playa.
6. [ ] Ábrela (mantén 5 s).
   ✅ PvP activado a la fuerza y botín (junto a tu personaje, a la derecha): metal de naufragio, vendas, comida…

## 5.5 Clima y erupción

1. [ ] Pulsa **🌧️ Lluvia** y sal del Basecamp.
   ✅ Caen gotas, el cielo se oscurece un poco y la **sed sube** sola.
2. [ ] Pulsa **⛈️ Tormenta** (o **⚡ Rayo cerca de mí** para verlo enseguida).
   ✅ Más lluvia y, cada ~20 s, un círculo amarillo de aviso y luego un **rayo en zigzag** desde el cielo, con ramas y parpadeo, destello, chispas, **trueno** y el suelo chamuscado un rato.
3. [ ] Pulsa **🌋 Erupción** estando cerca del volcán (o **☄️ Bombas de lava cerca de mí**).
   ✅ Aviso, tono rojizo, y el cráter escupe **bombas de lava** que vuelan **en arco** con fuego, humo y estela; al caer revientan en chispas y dejan un **charco de lava ardiendo** unos segundos. Antes de cada una sale el círculo rojo de aviso.
4. [ ] Ponte **dentro del círculo** de un rayo o de una bomba de lava (también vale dentro del Basecamp).
   ✅ Te quita vida (15 el rayo, 20 la bomba); si sales del círculo antes del impacto, nada.

## 6.1 Baliza y victoria (= §10.8, §18.1)

1. [ ] Con 🛠️ +50 de todo (incluye metal de naufragio), construye la **📡 Baliza de rescate** en el núcleo.
   ✅ Bajo el reloj: "📡 Baliza construida · piezas 0/4".
2. [ ] Pulsa **📡 4 piezas + baliza sin espera**. De **día**, mantén **"Encender baliza"** 3 s.
   ✅ La luz de arriba se pone **roja** y sale "¡… ha encendido la baliza!".
3. [ ] Pulsa **⏩ Saltar fase** (noche).
   ✅ "¡LA GRAN TROPA!": **5 oleadas** antes del amanecer, cada una un 20 % mayor que la anterior:
   1.ª aulladores; 2.ª + macacos; 3.ª + mandriles; 4.ª + orangutanes; 5.ª + gorilas.
   Para probarla sin la baliza: **🌕 La Gran Tropa ya** (de noche empieza al momento; de día salta a la noche; al amanecer no hay rescate).
4. [ ] Sigue en pie y pulsa **⏩ Saltar fase** (amanecer).
   ✅ "¡Llega el rescate!" y pantalla **"🚁 ¡Rescatados!"** con +200 de Ámbar.

## 6.2 Clasificaciones

1. [ ] Necesita datos guardados. En el **juego publicado**, juega una partida hasta perder o ganar.
2. [ ] En el Lobby, cartel **Ranking** (pulsa E).
   ✅ Se actualiza cada **5 minutos**: "1. TuNombre — N días".

## 6.3 Analítica

1. [ ] Tras jugar el juego **publicado**, ve a *Creator Hub → tu experiencia → Analítica* (tarda unas horas en verse).
   ✅ Embudo de incorporación con los pasos del tutorial, economía del Ámbar y eventos `MatchVictory`/`MatchDefeat`.

## 6.4 Estilo (cosméticos) y servidores privados

1. [ ] En el Lobby (Studio), icono **👕 Armario** (y las tiendas de cosméticos, §10.9–§10.10). En Studio los cosméticos sin pase son gratis para probar: **Equipar** la Estela dorada, el Título y el Aura.
   ✅ Se ven en tu personaje en el Lobby y en la Isla. El **Título: Superviviente de la Isla** sale con "Gana una partida" (ni en Studio es gratis; ver 7.6).
2. [ ] En el juego publicado, sin pases creados, los cosméticos de pase salen en 👕 Armario y en las tiendas de cosméticos (§10.9–§10.10) como **"Próximamente"** (normal; ver [LANZAMIENTO.md](LANZAMIENTO.md)).
3. [ ] **Servidores privados** y **grupos viajando juntos**: solo en el juego publicado, tras activar los servidores privados en el Creator Hub.

## 6.5 Sonido

1. [ ] Cada aviso suena con un **clic** suave.
2. [ ] Pulsa **🔊 Probar todos los sonidos**: suenan uno a uno, con su nombre en pantalla.
3. [ ] Juega un poco y escucha:
   - **Armas:** el tajo al atacar, el disparo de la honda y el **golpe** al acertar.
   - **Herramientas:** el hacha contra el árbol, el pico contra la roca, el **árbol al caer**, la roca al romperse y al recoger.
   - **Animales:** los monos **chillan** al recibir un golpe, gritan al morir, el aullador aúlla, el mandril y el gorila rugen, el capuchino se ríe al robar; los jefes rugen al despertar, al enfurecerse y al morir; tu mascota ataca con un chillido.
   - **Tú:** quejido al recibir daño, "oof" al caer, al reanimarte, al curarte, al comer y al beber.
   - **Base:** al construir y cuando los monos destruyen una pieza; al fabricar.
   > Roblox ya solo trae 11 sonidos de serie: los efectos usan esos con distintos tonos. Los de animales y algunos más son **provisionales**: para que suenen de verdad, pon IDs del Creator Store (ver [LANZAMIENTO.md](LANZAMIENTO.md), Sonido).
4. [ ] Pon un ID de música en `src/shared/Data/Sounds.luau` (por ejemplo, en `Day`).
   ✅ Suena con fundido; cambia de noche, en el asedio y cerca de un jefe. **M** la silencia.

## 6.6 Números de combate, críticos y combos

1. [ ] Pega al **muñeco de práctica** con el arma: salen números **amarillos** sobre su cabeza, en una columna de 4 que sube y se desvanece.
2. [ ] Pulsa **🎯 Críticos al 100 %** y vuelve a pegar: los números salen un **35 % más grandes** (multiplicador 1,35 de `Config.Crit`), con "!" y un temblor. Púlsalo otra vez para volver a lo normal.
3. [ ] **Torbellino** contra el muñeco: los golpes muy seguidos se suman en un número.
4. [ ] Pulsa **🐒 Mandril aquí**: sus mordiscos salen en **rojo a la izquierda de tu cabeza**; algunos (≈15 %) son críticos y más grandes. Con el **Escudo de hojas** sale 🛡️.
5. [ ] **Curaciones:** come o usa una venda (o sé médico): salen en **verde a la derecha**. Las vendas nunca son críticas.
6. [ ] **Mascotas:** con **🐾 Mascota al azar** (una de combate o de curación), sus números salen **más pequeños** que los tuyos.
7. [ ] **⚙️ Ajustes** (bajo "Volver al Lobby"):
   - Ves tu personaje girando, con tu mascota al lado, y números de ejemplo.
   - Cambia entre **Junto a la cabeza**, **Columna del alto del jugador** y **Fijos en la pantalla**: el ejemplo y los números de verdad cambian al momento.
   - El panel dice el daño y el crítico de tu arma (Machete 5 %; tras forjar el Machete afilado, 10 %) y coincide con el número amarillo normal contra el muñeco.
   - Vuelve al Lobby: en **⚙️ Ajustes** sigue la disposición elegida.
8. [ ] **Recargas nuevas:** Z, X y C tardan lo de la tabla del GDD §6.3 (el mago, un 15 % menos).
9. [ ] **Combos** (con monos cerca; 🐒 Mandril aquí sirve). Al usar el primer paso sobre un mono, sale su icono encima (⛓️ ❄️ 💫 o 💚 en el aliado), un recuadro "Combo 1/3" bajo las habilidades y la casilla del siguiente paso se resalta en azul:
   - **Cazador:** Cepo (que lo pise un mono) → Marcar presas (el atrapado se queda sujeto otra vez) → Disparo múltiple (2 proyectiles más).
   - **Mago:** Nova → Parpadeo → Bola de fuego (el hielo estalla en esquirlas).
   - **Guerrero:** Embestida → Grito (los desequilibrados se quedan aturdidos 1 s) → Torbellino (gira 1 s más).
   - **Médico:** Dardo a un aliado (o a un mono) → Escudo → Ungüento.
   ✅ Los pasos 2 y 3 hacen críticos a los marcados, la V baja 10 s por paso, sale "¡COMBO!" con un aro dorado y la racha sube (x2…). Tras 8 s sin pegar ni curar, la racha se pierde. Con más de 6 s entre pasos, el combo vuelve a empezar.
10. [ ] Con **2 jugadores**: el daño que hace el otro se ve más pequeño y tenue; su daño recibido no se ve. En Ajustes, "Daño de los aliados: No" lo quita.
11. [ ] **Lo que recoges:** golpea un árbol varias veces seguidas.
   ✅ Sale "+1 🌲 Madera" a la derecha, **debajo de la columna de curación**, y sube a "+2", "+3"… en la misma línea. Mata un mono: su botín sale igual (sin aviso arriba). En las tres disposiciones no se pisa con las curaciones; en Ajustes, "Lo que recoges: No" lo quita.
12. [ ] Abre la **Forja de piedra** (o la mesa de trabajo): cada arma termina su descripción con "🎯 Crítico 10 %" en amarillo; las mejoras dicen de cuánto a cuánto sube ("🎯 Crítico 10 → 15 %"). El hacha y el pico no lo llevan.
13. [ ] Deja que te tumbe el 🐒 Mandril y pulsa **💚 Revivir**: te levantas al momento con toda la vida, donde estabas. Vivo, solo avisa.
14. [ ] Pulsa **🗡️ Expositor de armas**: las 23 armas salen en círculo a tu alrededor, de perfil y con su nombre. Cada mejora se ve más grande o mejor que la anterior y lleva sus materiales (piedra, hueso, colmillos, liana, oro, plata). Empuña algunas (hacha, arco, bastón, honda): la mano queda en la empuñadura y el filo o la punta miran hacia delante. Pulsa otra vez para quitarlas.
15. [ ] Pulsa **🛡️ Siguiente armadura** varias veces: chaleco de pelaje (rojo, abierto por delante, ribete dorado y cordones) → armadura de hueso (costillas y hombreras de hueso con púas) → armadura de plata (manto plateado, placas de hueso en cruz y medallón) → sin armadura. Ninguna atraviesa los brazos ni la cabeza de forma rara.
16. [ ] Abre **⚙️ Ajustes**: tu personaje sale con la armadura puesta y el arma en la mano (la que empuñas o, con las manos vacías, la de tus números de combate, con el brazo levantado). En el Lobby, el arma inicial del rol.
   ✅ "Tus números de combate": el arma en una línea (daño, veneno en morado con la cerbatana y crítico), una casilla por habilidad en el orden del HUD (Z X C R V) con su número (daño en amarillo, curación en verde con "+"), una línea por combo ("Cepo → Marcar → Múltiple · remate") y lo que hace tu mascota con sus números (rastreo: "resalta los monos a menos de 60 studs cada 5 s"; apoyo: "+5 % de daño a distancia"…). Con la ventana abierta, 🎭 Siguiente rol, 🐾 Siguiente mascota o cambiar de arma la rehacen al momento.
17. [ ] Como **médico** (🎭 Siguiente rol): empiezas con la **Cerbatana** (y el machete). Dispara dardos verdes sin gastar munición. Con un aliado herido cerca (o tú mismo herido), cada dardo que acierta a un mono le cura (+2; +3 con la de hueso y +5 con la del chamán, en verde). Al disparar, el médico se lleva la cerbatana a la boca (el brazo izquierdo la sujeta), sopla con una bocanada de aire y vuelve a su postura.
18. [ ] **Animaciones de armas a distancia** (R15; Shared/Data/WeaponAnimations):
   - En Studio, **sin pulsar Play**, en la barra de comandos: `require(game.ServerStorage.Tools.WeaponAnimationBuilder).build()`.
     ✅ Sale "[WeaponAnimationBuilder] Listo" y en ReplicatedStorage aparece **WeaponAnimations** con Hold, Stone, Arrow, Spell y Dart.
   - Play: con el **arco** en la mano, el brazo derecho cuelga junto al cuerpo **sin temblar**; al disparar sube, apunta, suelta y vuelve. Al andar, las piernas se mueven normal. Igual con la **honda**, el **bastón** (destello del cristal) y la **cerbatana** (bocanada). Disparando seguido no se corta ningún movimiento. Con un arma cuerpo a cuerpo, el brazo va hacia delante como siempre.
   - Publicar: clic derecho en cada secuencia de ReplicatedStorage.WeaponAnimations > **Save to Roblox** (con el mismo dueño que el juego) y pegar cada id en `src/shared/Data/WeaponAnimations.luau`. Repetir la prueba.
   - Con 2 jugadores (Test > Clients and Servers), el otro ve la animación, la bocanada y el destello.
19. [ ] Con **🎯 Críticos al 100 %**, los números amarillos son un **35 %** mayores que los normales (un 14 pasa a 19); en Ajustes pone "(+35 %)" junto al crítico del arma.

## 7. Bucle de retención: huevos, calendario y misiones

Los botones de prueba del Lobby: 🥚 Huevo (rareza siguiente), 🐣 Huevo del nido listo, ⏩ Reloj +1 h, 🎒 Provisiones de prueba, 📅 Día siguiente (calendario) y 🏝️ Título Superviviente (sí/no). En la Isla: 🥚 Huevo guardado, 🎯 Cumplir las misiones del día y 🚁 Terminar: victoria. Las partidas terminadas con el panel **no cuentan** para el récord, los rescates ni el ranking.

### 7.1 Nido del Lobby

1. [ ] Pulsa **🥚 Huevo (rareza siguiente)** cinco veces.
   ✅ El primero entra en el **nido de la plaza** (delante del cartel 🐾 Mascotas), tres van a la mochila y el quinto queda **pendiente**. En el nido ves **tu** huevo con su color; el cartel dice "⏳ 7 h 59 min", la mochila 3/3 y "⚠️ 1 esperando sitio".
2. [ ] Acércate al nido y pulsa **E**.
   ✅ Se abre la ventana del nido, con la colección a la derecha y a la izquierda el nido: el huevo con su barra ("jugando le has quitado 0 s de 4 h 00 min"), **Puede salir** (las mascotas de esa rareza, ✅ las que ya tienes), la **mochila 3/3** y "⚠️ Mochila llena" con el pendiente.
3. [ ] **Descartar** un huevo de la mochila (pide una segunda pulsación, "¿Seguro?").
   ✅ +Ámbar según su rareza y el pendiente sube a la mochila.
4. [ ] **⏩ Reloj +1 h**.
   ✅ El cartel de las mascotas y la barra restan una hora.
5. [ ] **🐣 Huevo del nido listo** y pulsa **🐣 Abrir**.
   ✅ La ventana se cierra, el huevo **tiembla cada vez más**, estalla y sube la mascota girando con "🐣 ¡Ha nacido …!". Si es más rara que la tuya, te acompaña. El nido queda vacío y puedes poner otro (**Al nido**).

### 7.2 Aceleración jugando

1. [ ] En la Isla, con un huevo incubando: **⏩ Saltar fase** dos veces (noche → día).
   ✅ "🌅 Noche superada: tu huevo … del nido, −1 h 00 min".
2. [ ] **🚁 Terminar: victoria**.
   ✅ En los resultados, la **ruleta** "🥚 Tirada del rescate" pasa por los premios y se para en uno; debajo, lo que se le ha quitado al huevo. Si se pasa del tope del 50 %, dice "llegó al tope de lo que se acelera jugando".
3. [ ] Con el huevo listo (7.1 paso 5 sin abrirlo), entra en la Isla y espera 30 s.
   ✅ "🐣 ¡Tu huevo … está listo! Ábrelo en el nido del Lobby", una sola vez.

### 7.3 Provisiones

1. [ ] En el Lobby, **🎒 Provisiones de prueba**.
   ✅ Encima de "Ir a la Isla": "🎒 Te llevas a la Isla: 2 ➕ Venda, 5 🍌 Banano, 1 💉 Antídoto".
2. [ ] Entra en la Isla.
   ✅ "🎒 Tus provisiones: …" y están en la Bolsa. Al volver al Lobby la línea ya no sale.

### 7.4 Calendario de 7 días

1. [ ] Entra en el Lobby (con **📅 Día siguiente** si ya cobraste hoy y vuelves a entrar).
   ✅ Sale la ventana **📅 Premio diario · día N de 7**: días 1–4 arriba, 5–7 abajo (el 7 doble y dorado), el de hoy con borde dorado y lo que da.
2. [ ] **Cobrar**.
   ✅ "🎉 ¡Día N cobrado! …", la casilla pasa a ✅ y la ventana se cierra sola a los 5 s.
3. [ ] Icono **🎯 Misiones**.
   ✅ El calendario, "Mañana, día N+1" con la cuenta atrás ("En 19 h 29 min") y tus provisiones.
4. [ ] Repite **📅 Día siguiente** + **Cobrar** hasta el día 7.
   ✅ El 3 y el 6 quitan tiempo al huevo del nido (sin huevo, dan Ámbar); el 7 da un **huevo raro o mejor** y 500 de Ámbar; después vuelve al día 1.

### 7.5 Misiones diarias (en parte = §10.4)

Desde la Fase 9 son las misiones v2 (una fácil, una media del rol y una difícil): las semanales y el cambio gratis se prueban en el §10.4.

1. [ ] Entra en la Isla (en PC).
   ✅ Debajo de las habilidades, el rastreador de misiones con 3 líneas (la fácil, la de tu rol y la difícil) y, debajo, las semanales.
2. [ ] Cumple una de verdad (por ejemplo, fabrica 2 vendas en la mesa de trabajo, si te ha tocado la fácil de fabricar).
   ✅ El contador sube en pocos segundos y al cumplirla "🎯 ¡Misión cumplida! …" con 40 ✨ Ámbar, −15 min a tu huevo y la XP del pase; la línea pasa a ✅.
3. [ ] **🎯 Cumplir las misiones del día**.
   ✅ Las demás se cumplen con su aviso y su premio.
4. [ ] En el Lobby, icono **🎯 Misiones**; cambia de rol en el cartel **Elige tu rol**.
   ✅ Solo cambia la misión del rol (salvo que ya estuviera cumplida). Con **📅 Día siguiente**, salen 3 nuevas.

### 7.6 Título "Superviviente de la Isla"

1. [ ] Gana una partida **de verdad** (baliza → La Gran Tropa → amanecer; 6.1). La victoria del panel no lo da.
   ✅ En los resultados: "🏝️ ¡Nuevo título: Superviviente de la Isla!". En el Lobby, icono **👕 Armario** → 🏷️ Títulos, se puede **Equipar** y se ve en naranja sobre la cabeza.
2. [ ] Para ver solo cómo queda: **🏝️ Título Superviviente (sí/no)** en el Lobby (y otra vez para quitarlo).

---

## 8. Isla de Dunas (arena PvP)

Abre el place **Isla de Dunas** en Studio y conecta Rojo al puerto **34874**. Si el mapa no es el de las ruinas mayas, se reconstruye solo al darle a ▶ *Jugar* (o con `require(game.ServerScriptService.Server.World.ArenaBuilder).build()` en la barra de comandos, en edición; después **guarda el place**). En Studio no llega nadie del Lobby: el **🛠️ Pruebas** de la arena tiene "🧪 Empezar ya", "👥 Siguiente formato", "🚩 Ir a la bandera rival", "🎯 Rival de práctica" y "✨ +500 Ámbar".

### 8.1 Un jugador (▶ Jugar)

1. [x] Al entrar.
   ✅ Apareces en lo alto de la pirámide central con la ventana **Elige tu equipo** (equipos, roles, equipamiento) y el marcador arriba.
2. [x] Elige **Jaguar**, un rol y pulsa **¡Listo!**; después **🧪 Empezar ya**.
   ✅ Apareces en la baldosa naranja de tu base, con la cámara detrás de ti mirando a la puerta. Cuenta atrás y la puerta se abre.
3. [x] **🚩 Ir a la bandera rival**, tócala y vuelve con ella a tu pedestal.
   ✅ "¡Llevas la bandera!", vas más lento y sin Parpadeo ni Embestida; al llegar, captura y el marcador sube.
4. [x] Cae con la bandera encima (o suéltala) y espera.
   ✅ La bandera se queda en el suelo y vuelve sola a su pedestal a los 15 s; reapareces en tu base a los 8 s.
5. [x] Compra una variante en la ventana (con **✨ +500 Ámbar** si hace falta) y equípala.
   ✅ Baja el Ámbar, queda "Puesto" y se nota (vida, velocidad o recarga según la variante).
6. [x] Esquiva (Q) y Embestida contra una pared, también saltando.
   ✅ Te paras en la pared, de pie; nunca sales volando ni dando vueltas.
7. [ ] Con **🎯 Rival de práctica**, golpéalo con críticos.
   ✅ Salen los números y los estallidos de cómic (BAM!, POW!, K.O.!) según tus Ajustes del Lobby.
8. [x] Deja que se acabe el tiempo o llega a 3 capturas.
   ✅ Resultados con **🔁 Revancha** y **🏝️ Volver al Lobby**; la revancha empieza sola en el mismo servidor.

### 8.2 Varios jugadores (*Test → Local Server*, 2–4 clientes)

1. [ ] Cada uno elige base; con el formato 1v1, el segundo no cabe en un equipo lleno. En 4v4/5v5, no se pueden elegir 3 del mismo rol.
2. [ ] Pelead entre rivales.
   ✅ Daño, veneno (morado), ralentizar, marcas y combos funcionan contra el rival; un duelo entre roles iguales dura unos 8–10 s. El aviso "⚔️ … derriba a …" lleva los nombres de los jugadores.
3. [ ] El médico cura a un aliado y a un rival.
   ✅ Solo cura al aliado. El Grito con el **Peto de escamas de ámbar** protege también a los aliados.
4. [ ] Un rival suelta tu bandera; tócala con un aliado.
   ✅ Vuelve a tu pedestal al momento.
5. [ ] Con tu bandera robada, llega a tu pedestal con la rival.
   ✅ No puntúas hasta que tu bandera vuelve a casa.
6. [ ] Que todos los de un equipo se vayan.
   ✅ Gana el otro equipo; quien se fue no cobra.
7. [ ] Al terminar, mira el Ámbar cobrado.
   ✅ Victoria 60, empate 30, derrota 20, +15 por captura, +2 por baja (tope 20 por bajas), y no más de 400 al día.

### 8.3 Publicado (Studio no viaja entre places)

Antes: guarda los places del Lobby y de Dunas y **publica los 4 places a la vez** (el perfil, en la versión actual: 13, ver `PlayerData.luau` en `src/serverShared`).

1. [ ] En el Lobby, toca el velero **Zarpar a las Dunas**.
   ✅ Se abre la ventana de la arena con formato, cola y equipamiento por rol (también con el cartel de la Isla de dunas).
2. [ ] Con 2 cuentas, entrad en la cola de 1v1.
   ✅ Os juntan y viajáis al mismo servidor de Dunas, cada uno en un equipo.
3. [ ] Con un grupo de 2, entrad en la cola de 2v2 (y otros 2 en otra cuenta o grupo).
   ✅ El grupo llega junto, en el mismo equipo.
4. [ ] Al terminar, **🏝️ Volver al Lobby**.
   ✅ Vuelves al Lobby con el Ámbar cobrado; el cartel de la arena (victorias y banderas capturadas) se actualiza.
5. [ ] Entra en Dunas solo y espera 60 s.
   ✅ Sin rival, se cancela y vuelves al Lobby.

---

## 9. Menú del Lobby por estaciones (20-10-2026)

En el place **Lobby**, con ▶. Para el móvil, elige un teléfono en *Prueba → Dispositivo* antes del ▶.

1. [ ] **Guía de la primera vez** (si ya la hiciste, en 🛠️ pulsa **🧭 Repetir la guía**).
   ✅ Un aviso arriba y un rastro dorado desde tus pies hasta **Elige tu rol**, con su icono más grande y con aro rojo. Al usar el cartel, el rastro va al **nido**. Al usar el nido: "✅ ¡Listo!" y no vuelve a salir al volver a entrar.
2. [ ] **Iconos de las estaciones**: ⚔️ sobre los roles, 🏆 sobre el ranking, 🎖️ sobre la Isla de dunas y 🥚 sobre el nido.
   ✅ Se ven desde lejos y suben y bajan. "!" en ⚔️ con puntos de talento libres y en 🥚 con el huevo listo o con huevos y el nido vacío; "⏳" en 🎖️ buscando partida.
3. [ ] Acércate a un cartel con aviso o al nido.
   ✅ Un contorno dorado lo rodea mientras el aviso está a la vista.
4. [ ] Usa el aviso de cada estación.
   ✅ Roles → ventana de roles (con "Ver talentos" palpitando en rojo si hay puntos); nido → nido y colección; cartel de la Isla de dunas y su velero → la arena; ranking → las cuatro clasificaciones con "Tú". Al alejarte, la ventana se cierra sola.
5. [ ] Barra de iconos: abre cada una (y otra vez para cerrarla).
   ✅ En PC ninguna necesita desplazarse (Diario y Ajustes en columnas). Punto rojo en Talentos con puntos libres y en Misiones con el premio del calendario por cobrar. Con una ventana abierta no están el botón de viaje ni "Invitar amigos".
6. [ ] **Móvil**: la barra va en fila arriba a la derecha con 📨 para invitar, y la pastilla del Ámbar tras los botones de Roblox.
   ✅ Las ventanas ocupan toda la pantalla y se reparten en columnas; la arena en dos columnas. Con una ventana abierta no se ven el joystick, el salto ni los botones de combate.
7. [ ] Mira los carteles.
   ✅ **🐾 Mascotas**: tu huevo con su tiempo y barra, qué puede salir, la mochila y quién te acompaña. **🎖️Isla de dunas☠️(PvP)**: tus victorias y banderas, el Ámbar de hoy y los jugadores en cola por formato. **Ranking**: supervivencia y arena, solo nombres (sin los jugadores de prueba de Studio).

---

## 10. Fase 9: pase, misiones v2, mitad de partida y cosméticos (21-10-2026)

Casi todo se prueba en el **Lobby**; la partida (10.5–10.8), en la **Isla**. El panel 🛠️ del Lobby tiene: ⭐ +500 XP de pase, ⭐ Siguiente nivel del pase, 🌋 Premium del pase (sí/no), 📆 Reloj del pase +7 días, 🧾 Compra de prueba (siguiente producto), 🔁 Repetir el último recibo, 🎁 Dar/quitar el siguiente cosmético, 🛒 Tienda de cosméticos: día siguiente, 📆 Cumplir las semanales y 📆 Semana siguiente. El de la Isla: 📆 Cumplir las semanales, 📜 Cumplir el paso del contrato, 📜 Siguiente contrato, 📅 Días de los eventos de esta partida, ☣️ Lluvia tóxica ya, 🔧 Noche de macacos saboteadores, 🎖️ Erupción preliminar con cajas militares y 🌕 La Gran Tropa ya.

### 10.0 Antes: copia de tu perfil

> Más fácil: 👑 Admin → 📋 Perfil → 📦 Hacer copia (ver §0).

▶ *Jugar* en Studio **escribe tu perfil de verdad** (el mismo que el del juego publicado). Antes de probar, en la barra de comandos de Studio (en edición, con el acceso a las API activado) pon tu número de usuario y ejecuta:

```lua
local DS = game:GetService("DataStoreService")
local clave = "u_" .. 0 -- ← tu UserId
DS:GetDataStore("PlayerData_v1_backups"):SetAsync(clave .. "_antesFase9", (DS:GetDataStore("PlayerData_v1"):GetAsync(clave)))
```

Al terminar, para dejarlo como estaba, con el Play parado, restaura la copia (lee de `PlayerData_v1_backups` con la clave `.. "_antesFase9"` y guarda en `PlayerData_v1` con `clave`):

```lua
local DS = game:GetService("DataStoreService")
local clave = "u_" .. 0 -- ← tu UserId
DS:GetDataStore("PlayerData_v1"):SetAsync(clave, (DS:GetDataStore("PlayerData_v1_backups"):GetAsync(clave .. "_antesFase9")))
```

Los paréntesis alrededor de `GetAsync` son necesarios: `GetAsync` devuelve dos valores y, sin ellos, el segundo entra en `SetAsync` y falla con «Unable to cast Instance to Array».

### 10.1 Calculadora

1. [ ] En el Studio de la **Isla**, en edición:
   ```lua
   local m = game.ServerStorage.Tools.Economia:Clone(); print(require(m).informe()); m:Destroy()
   ```
   ✅ En la Salida, las secciones 1–6. En "4. Pase", el habitual termina el **día 23** y el casual llega al **13**. En "5. Reglas de pago", 18 productos, todos ✅ (los que tienen "falta" en Id son los que aún no has creado, §LANZAMIENTO 3). En "6. Alertas": **✅ Todo dentro de los límites**.

### 10.2 Compras de prueba (Lobby)

1. [ ] **🧾 Compra de prueba** hasta que salga el **pase premium** (va pasando por los productos).
   ✅ Aviso de compra; en la ventana del pase (🌋) la pista premium se abre y los cosméticos premium de los niveles que ya tenías pasan a ser tuyos (entrega retroactiva).
2. [ ] **🔁 Repetir el último recibo**.
   ✅ Dice que ya estaba entregado; no cambia nada.
3. [ ] En la ventana del pase, con premium.
   ✅ Ya no salen los botones de la premium ni del pack (+10 niveles); sí el de +1 nivel.
4. [ ] Quita la premium (**🌋 Premium del pase**) y haz la **🧾** del pack.
   ✅ Premium y 10 niveles más, pero el Ámbar, el tiempo de huevo y las provisiones de esos niveles salen con "🔒 Gánalo jugando"; los cosméticos sí se reclaman.
5. [ ] En el nivel 30, o con el **📆 Reloj del pase** en el descanso.
   ✅ No sale el botón de +1 nivel.

### 10.3 Pase de temporada (Lobby)

1. [ ] Mira el **cartel volcánico del pase** en la plaza y el icono 🌋 sobre él.
   ✅ La temporada "El Despertar del Volcán", la cuenta atrás, tu nivel y los próximos premios. Con algo por reclamar, "!" en el icono y punto rojo en 🌋 de la barra.
2. [ ] Abre el pase (cartel o 🌋) en PC.
   ✅ Dos pistas sincronizadas, gratis abajo y premium arriba, con la imagen voxel de cada premio y el sello premium; un premio premium en **cada** nivel. Al tocar un premio, su detalle.
3. [ ] **⭐ Siguiente nivel del pase** varias veces y **Reclamar todo**.
   ✅ Se cobran los de la pista gratis (Ámbar, huevo, provisiones, cosméticos) y, con premium, los de arriba. El N20 gratis da un **huevo Raro**.
4. [ ] **📆 Reloj del pase +7 días** tres veces (última semana) y **⭐ +500 XP de pase**.
   ✅ La cabecera dice ×2 y suben 1.000.
5. [ ] Otra vez **📆 +7 días** (fin de la temporada).
   ✅ Lo que no habías reclamado se entrega solo; durante el descanso no se gana XP.
6. [ ] En la Isla, termina una partida (🚁 o 💀).
   ✅ En los resultados, la línea de XP del pase y su barra.
7. [ ] **Móvil** (*Prueba → Dispositivo*).
   ✅ La ventana del pase ocupa la pantalla y se lee.

### 10.4 Misiones v2

1. [ ] Lobby, icono **🎯 Misiones**, pestaña **Hoy**.
   ✅ Calendario y 3 misiones: fácil, media (de tu rol) y difícil, cada una con su premio (Ámbar, huevo y XP del pase).
2. [ ] **Cambiar** una misión.
   ✅ Sale otra de la misma dificultad; el botón ya no deja cambiar otra hoy. Con **📅 Día siguiente**, vuelve.
3. [ ] Pestaña **Semana**.
   ✅ 5 semanales (como mucho una de Dunas) y el extra por cumplir las 5; un cambio a la semana. **📆 Cumplir las semanales** las da todas con el extra; **📆 Semana siguiente** saca 5 nuevas.
4. [ ] En la Isla.
   ✅ El rastreador enseña las diarias y las semanales y se pliega al tocar su cabecera (se recuerda al volver). En el **móvil**, fichas en la franja de la barra de Roblox.
5. [ ] En Dunas, gana o captura una bandera con una semanal de Dunas.
   ✅ Avanza.

### 10.5 Equipo ligado a los jefes (Isla) (= §4 pasos 5–6b)

1. [ ] **🎒 +50 de todo** y abre la Forja de piedra.
   ✅ El nivel 3 de las armas de rol y la Armadura de plata piden la **Corona del caudillo**.
2. [ ] **👑 Siguiente jefe** hasta el Chimpancé Caudillo y derrótalo.
   ✅ Cada participante recibe **2** coronas y ya se puede fabricar el nivel 3.
3. [ ] Construye la **Forja volcánica** (25 piedra, 8 obsidiana, 2 huesos gruesos) y pica una veta de obsidiana del volcán.
   ✅ El nivel 4 (Mazo volcánico, Arco de brasa, Bastón de lava, Cerbatana de azufre, Armadura volcánica) pide obsidiana y el **Cristal de cueva** (jefe del día 6).

### 10.6 Contratos de expedición (Isla)

1. [ ] Empieza una partida.
   ✅ Bajo el rastreador de misiones, la tarjeta del contrato (📜 en el móvil) con el paso 1 y su día.
2. [ ] Cumple el paso de verdad (por ejemplo, construye 3 piezas en el Campamento del náufrago) o con **📜 Cumplir el paso del contrato**.
   ✅ Todos los de la partida reciben Ámbar, XP del pase y su objeto; el paso siguiente se abre en su día. **📜 Siguiente contrato** cambia de contrato.
3. [ ] Deja pasar el día del paso sin cumplirlo (⏩ Saltar fase).
   ✅ El paso se pierde al abrirse el siguiente.
4. [ ] Termina la partida.
   ✅ En los resultados, la línea del contrato.

### 10.7 Eventos de mitad de partida (Isla)

1. [ ] **📅 Días de los eventos de esta partida**.
   ✅ El día de la lluvia tóxica (3 o 4), la noche de los saboteadores (5) y la erupción preliminar (7). La víspera de cada uno, al anochecer, sale el aviso.
2. [ ] **☣️ Lluvia tóxica ya** y bebe del río.
   ✅ Línea de estado en el HUD; el agua y los mordiscos dan fiebre. El agua hervida de la hoguera no; el médico recibe 2 antídotos y su Ungüento baja la fiebre.
3. [ ] **🔧 Noche de macacos saboteadores** (de noche).
   ✅ Parte de cada oleada son macacos que van a por estacas, muros, barricadas y estaciones, no a por la baliza ni las camas.
4. [ ] **🎖️ Erupción preliminar con cajas militares** (de día: de noche el volcán tiene gorilas y el asedio pega dentro del campamento).
   ✅ Piroclastos en las zonas altas y 2 cajas militares con babuinos; abrir una (8 s) activa el PvP y da obsidiana, vendas, antídoto, comida y una esquirla de jefe. El paso "Asegurar" del contrato se cumple.

### 10.8 La Gran Tropa, la baliza y el tótem (Isla) (= §6.1)

1. [ ] Construye el **tótem guardián** (pide una Perla del río) y unas **antorchas de pie**.
   ✅ A 25 studs las piezas reciben menos daño y se reparan de noche.
2. [ ] **📡 4 piezas + baliza sin espera**, enciéndela y **🌕 La Gran Tropa ya**.
   ✅ Parte de los mandriles, orangutanes y gorilas va a por la baliza (16.000 de vida); los demás monos la rodean. Las antorchas espantan a los aulladores y se gastan.
3. [ ] Deja que la derriben.
   ✅ Se corta la señal: esa noche no hay rescate. Al amanecer se repara y se puede volver a encender.

### 10.9 Cosméticos y Armario (Lobby)

1. [ ] **🎁 Dar/quitar el siguiente cosmético** unas cuantas veces y abre **👕 Armario**.
   ✅ Avatar 3D que gira y pestañas Trajes, Armas, Efectos, Títulos, Mascotas, Marcos, Emotes y Estilos, con borde de rareza (el mítico por encima del legendario). La vista previa junta lo elegido en cada hueco.
2. [ ] Equipa un traje y un arma de la Temporada 1 y de los míticos, en cada rol.
   ✅ Se ven en el Lobby y en Dunas enteros, y en la Isla crecen con el nivel de la armadura y del arma. Míralos **de espaldas**: el motivo de la espalda se ve.
3. [ ] Equipa una skin de mascota (Tortuga de Lava, Jaguar de Magma, Perro pirata), un marco, una estela, unos números, un estallido y una decoración del nido.
   ✅ La mascota cambia sin perder su ayuda; el marco sale en el ranking, la ventana Grupo y los resultados; los números y estallidos, al pegar a los muñecos; la decoración, alrededor de tu nido (solo la ves tú).
4. [ ] Mantén **"."** (o 😀) y suelta sobre un emote.
   ✅ Lo hace; los de la temporada con sus efectos (Grito de gorila, Danza del fuego en bucle, Erupción). Moverse lo para; en combate no deja.

### 10.10 Tiendas de cosméticos (Lobby)

1. [ ] **Tienda** → pestaña **🎨 Cosméticos**.
   ✅ 4 en Ámbar (de lo que aún no tienes), 3 sueltos de Robux de la semana y, debajo, los Game Passes. Ningún premio de la temporada en curso.
2. [ ] Compra uno en Ámbar (**✨ +500 Ámbar** si hace falta; pide dos pulsaciones).
   ✅ Se descuenta, sale en el Armario y no vuelve a la oferta. **🛒 Tienda de cosméticos: día siguiente** cambia los 4.
3. [ ] Un suelto de Robux con **🧾 Compra de prueba** (o el botón, que en Studio es de prueba).
   ✅ Se entrega una sola vez (🔁 no lo duplica).

Al terminar, restaura tu perfil (10.0).

## 11. Fase 10: Combate v2 (22-10-2026)

Lo nuevo de §6.5 del GDD. Casi todo se prueba con un jugador en la Isla, junto a los **muñecos de práctica** y el **muñeco de sparring** del Basecamp (al este de la hoguera; en el Lobby, en la plaza). Antes, haz la copia de tu perfil (10.0): Play escribe el perfil de verdad.

### 11.1 Un jugador (▶ Jugar, en la Isla)

1. [ ] **Cadena de golpes:** con el garrote, pega seguido a un muñeco.
   ✅ Cuatro tajos distintos; el 4.º (remate) pega más (~×1,4), tiembla la cámara y bajo tus pies se llenan **4 rombos** (el 4.º, dorado, late antes del remate). Si paras 1,2 s, vuelve al primero. Hacha y pico, golpe suelto.
2. [ ] **Disparo de remate:** con el arco (o la honda, el bastón, la cerbatana), dispara seguido.
   ✅ El 4.º disparo es más grande y de color, con una chispa en el arma; el del arco atraviesa al muñeco y da al de detrás, el del bastón estalla. Disparando cada 2 s no sale.
3. [ ] **Guardia:** ponte delante del muñeco de sparring (te pega cada 1,8 s con un "!" encima) y mantén **F**.
   ✅ La barra de guardia (a la derecha de la estamina) baja con cada golpe, suena madera contra piedra y no pierdes vida. Si se vacía: "¡GUARDIA ROTA!" naranja y quedas aturdido un momento.
4. [ ] **Parry:** pulsa **F** justo cuando el "!" va a acabar.
   ✅ "¡PARRY!" dorado, un tintineo, la guardia sube y el sparring se tambalea. Tu siguiente golpe saca "¡CONTRA!".
5. [ ] **Amago:** pulsa **Z** (o pega) y, antes de que salga, **F**.
   ✅ Bocanada de humo gris; la habilidad no sale y se recarga en 1,5 s (gasta 15 de estamina). El golpe del arma se amaga gratis una vez por segundo.
6. [ ] **Preparación de los monos:** pulsa **🐒 Mandril aquí** fuera del Basecamp.
   ✅ Antes de morder se para y avisa con "!" (0,5 s). Si te apartas o esquivas en ese momento, falla. Un gorila avisa el pisotón con **"‼" naranja**: no se puede bloquear.
7. [ ] **Evasivo:** deja que un orangután te agarre (o que un gorila te tumbe) y pulsa **Q**.
   ✅ Te suelta con una ráfaga blanca y azul, y el icono 💨 baja como una cortina durante 25 s. Atrapado y en recarga, Q no hace nada.
8. [ ] **Control decreciente:** como mago, congela al mismo mandril con la Nova cada vez que esté lista.
   ✅ Cada congelación dura menos y a la cuarta o la quinta sale "INMUNE".
9. [ ] **Paredes:** con una roca entre tú y un muñeco, usa el Torbellino o el garrote.
   ✅ No le das. Sin la roca, sí.
10. [ ] **Proyectiles:** dispara a un mandril que corre de lado.
   ✅ La piedra (o la flecha) vuela de verdad: apuntando casi encima, la ayuda la adelanta; apuntando entre dos monos, pasa entre ellos. Una pared la para.
11. [ ] **Rebote contra muros:** con el guerrero, Embestida a un mono pegado a una roca.
   ✅ Grietas en la roca, polvo, un golpe sordo y el mono aturdido medio segundo.
12. [ ] **Zonas:** como mago, Nova en el suelo; como médico, Polvo somnífero.
   ✅ Baldosas de hielo azul (3 s, ralentiza) y nube lila (3 s). Bola de fuego → Nova → Meteoro deja el suelo ardiendo.
13. [ ] **⚙️ Ajustes:** "Tus números" enseña la cadena del arma (o el disparo de remate) y la guardia; hay "🎮 Controles del combate" (PC, mando y móvil) y "📳 Temblor de la cámara" (Encendido, Suave o Apagado; apagado, el remate ya no mueve la cámara).
14. [ ] **Bloqueo de cámara:** pulsa **Ctrl** (no hace falta tocar el menú de Roblox).
   ✅ La cámara queda detrás del hombro; Mayús sigue siendo correr.
15. [ ] En la **Salida**, ninguna línea roja nueva.

### 11.2 Dunas (▶ Jugar, en el place de Dunas)

1. [ ] **🧪 Empezar ya**. Junto a una estela, usa habilidades de daño.
   ✅ Se agrieta (a dos tercios y a un tercio), cae en trozos y vuelve a los 45 s; rota, se pasa a través.
2. [ ] **⛩️ Encender el altar ya y subir a él**.
   ✅ En 6 s lo tomas (haz y gemas del color de tu equipo, línea en el HUD bajo la fase) y tu V se carga el doble durante 30 s. En los resultados, "⛩️ Altares".
3. [ ] Desde el patio de la base, intenta subir por la cara del templo y salir por detrás.
   ✅ No se puede (barreras invisibles).

### 11.3 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en Dunas)

Por el MCP solo hay un jugador: esto solo lo puedes probar tú. Dime qué pasa en cada paso.

1. [ ] **Duelo espejo** (los dos del mismo rol, sin defenderse): cuenta los segundos hasta que cae uno. (= §8.2 p2)
   ✅ 8–10 s el guerrero, el cazador y el mago (el médico tarda mucho más, a propósito). Defendiéndose bien, hasta ~12 s.
2. [ ] **Parry entre jugadores:** uno pega con el garrote y el otro pulsa F justo antes.
   ✅ "¡PARRY!" sobre el que para, el atacante se tambalea y el primer golpe del que paró saca "¡CONTRA!".
3. [ ] **Amago contra parry:** el atacante amaga (F durante el tajo) y vuelve a pegar.
   ✅ Quien paró por reflejo gasta su ventana y recibe el segundo golpe.
4. [ ] **Guardia contra habilidades:** uno mantiene F y el otro le hace un Torbellino entero.
   ✅ La guardia baja **una vez** por el Torbellino (25), no por cada vuelta. El Rompehuesos y el Pisotón la rompen.
5. [ ] **Grito de guerra en PvP:** el guerrero usa el Grito y el otro le pega.
   ✅ Le quita un 15 % menos (no el 40 % de contra los monos).
6. [ ] **Combo sin escape:** el guerrero abre con el Pisotón y sigue pegando.
   ✅ El otro, aturdido, pulsa Q (Evasivo) y sale; sin Evasivo, tras el Pisotón no pierde más de un tercio de la vida.
7. [ ] **Escalado:** muchos golpes seguidos al mismo rival.
   ✅ Desde el 4.º, cada uno quita un poco menos. Los controles seguidos duran menos cada vez.
8. [ ] **Proyectiles contra un jugador:** dispara a un rival que se aparta de lado.
   ✅ Si se aparta a tiempo, falla (contra jugadores la ayuda no adelanta). Bloqueado o parado, como un golpe.
9. [ ] **Rebote:** Embestida a un rival pegado a una pared.
   ✅ Grietas y un aturdido corto (0,25 s).
10. [ ] **Altar disputado:** los dos equipos en el altar a la vez.
   ✅ La barra se para; cuando uno se va, el otro primero vacía la del rival y luego llena la suya.
11. [ ] **Cura doble de la cerbatana** (en la Isla, 2 clientes): el médico dispara seguido a un mono con el aliado herido cerca.
   ✅ El 4.º dardo cura el doble al aliado.
12. [ ] **Rendimiento** (en la Isla, 5 clientes): pelead todos juntos contra un grupo de monos.
   ✅ El servidor sigue a ~60 FPS (la línea "[Rendimiento]" de la Salida) y nadie nota tirones.

Al terminar, restaura tu perfil (10.0).

## 12. Propiedad única y regalos (T3, 26-10-2026)

Antes, la copia de tu perfil (§10.0): la migración cambia tus mascotas repetidas por Ámbar.

### 12.1 Mascotas: una de cada (Lobby, ▶ Jugar)

1. [⏭] Entra con un perfil que tenga mascotas repetidas (versión 8). ⏭️ Superado: necesita un perfil v8 que ya no existe.
   ✅ A los pocos segundos, "🐾 Ahora tienes una mascota de cada: tus repetidas te dieron +N ✨ Ámbar". En la ventana del nido, la colección ya no enseña "×N".
2. [ ] **🥚 Huevo**, **Al nido** y **🐣 Huevo del nido listo** hasta que salga una mascota que ya tienes; **🐣 Abrir**.
   ✅ "🐣 ¡Otra vez …!" y "Ya la tenías: +N ✨ Ámbar" (el doble del descarte de su rareza). La colección no cambia.
3. [ ] Pon en el nido un huevo de una rareza de la que tienes todas las mascotas.
   ✅ La ficha "Puede salir" dice "ya tienes todas · te dará +N ✨ Ámbar" (o que aún puede salir una montura).

### 12.2 No volver a pagar (Lobby)

1. [ ] Con un cosmético de Robux que ya tienes, pulsa su compra desde el Armario o la tienda.
   ✅ "✅ Ya tienes …" y no se abre la ventana de Roblox. Con la premium del pase, "Ya tienes el pase premium…".
2. [ ] Pulsa dos veces seguidas la compra de algo que no tienes.
   ✅ Solo se abre una ventana de compra.

### 12.3 Regalar (*Test → Clientes y servidores*, 2 clientes, en el Lobby)

1. [ ] El jugador 1 abre la tienda (🎨 Cosméticos) y pulsa 🎁 en una tarjeta de Robux.
   ✅ La barra de abajo cambia a "🎁 Regalar … a:" con el jugador 2 (no salen los que ya lo tienen). ✕ la cierra.
2. [ ] Elige al jugador 2 (en Studio, sin id, es una compra de prueba).
   ✅ El 1 recibe "🎁 Le regalaste … a …"; el 2, "🎁 ¡… te regaló …! Está en tu 👕 Armario", y lo tiene en el Armario.
3. [ ] Vuelve a pulsar 🎁 en ese cosmético.
   ✅ El jugador 2 ya no sale en la lista.
4. [ ] Publicado: regala a alguien y que salga del servidor justo antes de pagar.
   ✅ El que paga ve "lo recibirá al entrar"; el otro lo recibe al entrar a cualquier place.

## 13. Lo que queda por probar de T2 y T4 (27-10-2026)

Lo demás de estas tandas ya se probó en Studio al hacerlas. Antes, la copia de tu perfil (§10.0; o, siendo administrador, 👑 Admin → 🛡️ en tu fila → 📋 Perfil → 📦 Hacer copia).

### 13.1 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] **Isla**: coge el martillo (T2).
   ✅ Arriba en el centro, a 4 px de la barra de Roblox, la ficha de la pieza elegida con ◀ ▶ (300 × 52). Se lee y los botones se pulsan.
2. [ ] **Lobby**: con el panel 👑 Admin → 🎉 Eventos, lanza dos eventos en «Este servidor» (por ejemplo, 💰 Doble Ámbar y 🍀 Suerte de huevo) (T4b).
   ✅ La franja de la barra de Roblox enseña dos pastillas con icono y tiempo ("💰 14:59") sin tapar los iconos del menú del Lobby. Tocar una explica el evento.
3. [ ] Lo mismo en la **Isla** y en **Dunas**.
   ✅ Las pastillas no tapan las fichas de las misiones (Isla) ni el marcador de banderas (Dunas).

### 13.2 Dos jugadores (*Test → Clientes y servidores*, 2 clientes)

El jugador 1 es el administrador (en Studio, el dueño del juego); el 2, un jugador normal.

1. [ ] **Lobby**, 👑 Admin → 👥 Jugadores → 🛡️ en la fila del jugador 2 → 🔇 5 min (T4c).
   ✅ El 2 recibe "🔇 Un administrador te ha silenciado…" y no puede escribir en el chat; 🔊 Quitar lo devuelve.
2. [ ] ❄️ Congelar y 🔥 Descongelar al jugador 2.
   ✅ El 2 no se puede mover hasta descongelarlo; si se resetea congelado, reaparece congelado.
3. [ ] 📍 Ir hasta y 👁 Espiar al jugador 2.
   ✅ El 1 aparece junto al 2; con Espiar, su cámara sigue al 2 hasta "Dejar de espiar" o cerrar la ventana.
4. [ ] 📋 Perfil del jugador 2 → 🗑️ Quitar una mascota (dos toques).
   ✅ El 2 deja de tenerla en la ventana de mascotas.
5. [ ] 👢 Expulsar al jugador 2 con un motivo (dos toques).
   ✅ El 2 sale con "Te ha expulsado un administrador. Motivo: …".
6. [ ] **Isla**, los dos en la partida, fuera del Basecamp. El 1: 🎉 Eventos → «Este servidor» → 👹 Ser gigante (T4e).
   ✅ El 1 crece con su corona; la barra de jefe dice "👹 …, el gigante · fase 1/3" y su vida es 3600 × 1,75 = 6300.
7. [ ] El 1 usa 🦶 Pisotón (I), 🌊 Ola (O) y 📣 Rugido (P) con el 2 dentro de los avisos naranjas.
   ✅ El 2 pierde 35, 25 y 10 y queda aturdido 1 s y 1,5 s; dentro del Basecamp no le pasa nada. El 1 también le puede pegar con su rol.
8. [ ] Que el gigante tumbe al 2.
   ✅ El 2 queda caído (como en el PvP) y el gigante no cobra recompensa.
9. [ ] El 2 pega al gigante hasta derribarlo (para ir rápido, el 1 se baja la vida desde la Salida del servidor: `game.Players.<nombre>.Character.Humanoid.Health = 50`).
   ✅ "👹 ¡El gigante ha caído! Premio para …"; el 2 recibe el título «👹 Matagigantes» (en el Armario) y un huevo legendario; el 1 vuelve a su tamaño.

### 13.3 En el juego publicado (con 2 servidores abiertos o un amigo en otro servidor)

1. [ ] 👑 Admin → 📢 Todos → anuncio en «🌍 Todos los servidores» (T4a).
   ✅ El cartel "📢 Anuncio · …" sale en los dos servidores, también en la Isla y en Dunas.
2. [ ] «🌍 Elegir · todos» → un huevo común (dos toques).
   ✅ Los jugadores de los dos servidores lo reciben; en 📜 Registro sale una sola vez.
3. [ ] 🎉 Eventos → «🌍 Todos» → 💰 Doble Ámbar en +5 min.
   ✅ En todos los servidores sale "⏳ … en 4:59"; un servidor que se abre después también lo ve; ⏹ Parar lo quita en todos.
4. [ ] 🏝️ Ahora en la Isla → «🌍 Todos» → ⛈️ Tormenta desde el Lobby.
   ✅ Llueve en las partidas de la Isla que estén abiertas.
5. [ ] 🖥️ Servidor → 🔄 Actualizar.
   ✅ Sale cada servidor con su place, jugadores, FPS y tiempo encendido.
6. [ ] ⛔ Banear 1 h a una **cuenta de pruebas** desde 🛡️ (dos toques), y luego ✅ Quitar baneo con su nombre (T4c).
   ✅ La cuenta sale y no puede entrar a ningún place, con el motivo; tras quitarlo, entra.
7. [ ] 🛠️ Mantenimiento en 1 min (dos toques), justo antes de publicar una actualización (T4d).
   ✅ Anuncio y cuenta atrás en todos los servidores; al acabar, los jugadores salen con "🛠️ El juego está en mantenimiento…" y durante 10 min no pueden entrar (tú sí). Se cancela con ⏹ en 🎉 Eventos.

## 14. Lo que queda por probar de T5a: Jaguar Albino Esmeralda y perro pirata (27-10-2026)

Probado en Studio (Isla, 1 jugador): montar el jaguar, reposo y galope, el aura (despacio parado y deprisa al galopar), el rugido (animación, cubitos y ojos) y la velocidad montado (33). Para tener el jaguar: 👑 Admin → dar la montura «Jaguar Albino Esmeralda», y llevarla desde el cartel de Mascotas del Lobby.

### 14.1 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Monta el jaguar y mira los botones de abajo a la derecha.
   ✅ Sale el botón «Rugir» (con la llama sale «Escupir»); al tocarlo, el jaguar ruge.

### 14.2 Dos jugadores (*Test → Clientes y servidores*, 2 clientes)

1. [ ] El 1 monta el jaguar, galopa y ruge (Y); el 2 lo mira.
   ✅ El 2 ve el galope, el aura girando y la onda de cubitos pastel con los ojos encendidos al rugir.
2. [ ] El 1 ruge varias veces seguidas.
   ✅ Solo ruge una vez cada 3 s.

### 14.3 En el Lobby (▶ Jugar)

1. [ ] Monta el jaguar y salta.
   ✅ Galopa, salta con su animación (se estira en el aire) y el jinete va sentado sobre la silla azul marino.

### 14.4 En el juego publicado

1. [ ] Monta el jaguar en la Isla publicada.
   ✅ Las cuatro animaciones cargan (si el jaguar va rígido, las animaciones no son del dueño del juego).

## 15. Lo que queda por probar de T5b: Quetzalcóatl (27-10-2026)

Probado en Studio (Isla, 1 jugador): montar el Quetzalcóatl, sus cinco animaciones (quieto, avanzar, saltar, planear y silbar), los remolinos, las plumas que caen, la sombra, el silbido (soplo y ráfaga de 18 plumas) y el planeo (desde 45 studs baja a unos 8,8 studs/s, no te baja de la montura y quita la animación al tocar el suelo). Para tenerlo: 👑 Admin → dar la montura «Quetzalcóatl, la Serpiente Emplumada», y llevarla desde el cartel de Mascotas del Lobby.

### 15.1 En el Lobby (▶ Jugar)

1. [ ] Abre la ventana de Mascotas sin tener el Quetzalcóatl.
   ✅ Sale «🔒 Quetzalcóatl · Mítico» en rojo mítico y el botón gris «Pioneros · Huevo mítico», legible en PC.
2. [ ] Con el Quetzalcóatl, sube a un tejado o una tarima alta del Lobby y salta montado.
   ✅ Abre el penacho y los abanicos, baja despacio y deja de planear al llegar al suelo.

### 15.2 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Abre la ventana de Mascotas sin tenerlo.
   ✅ El texto del botón «Pioneros · Huevo mítico» se lee.
2. [ ] Montado, mira los botones de abajo a la derecha.
   ✅ Sale «Silbar»; al tocarlo, silba con la ráfaga de plumas.

### 15.3 Dos jugadores (*Test → Clientes y servidores*, 2 clientes)

1. [ ] El 1 monta el Quetzalcóatl, avanza, silba y salta desde alto; el 2 lo mira.
   ✅ El 2 ve la onda al avanzar, los remolinos, las plumas, el silbido y el planeo con el plumaje abierto.

### 15.4 En el juego publicado

1. [ ] Monta el Quetzalcóatl en la Isla publicada.
   ✅ Las cinco animaciones cargan (si va rígido, las animaciones no son del dueño del juego).

## 16. Lo que queda por probar de T6: bienvenida de pioneros (27-10-2026)

Probado en Studio (Lobby, 1 jugador, con las 3 monturas):
- **El perfil:** al entrar queda marcado como pionero (atributo `Pioneer`).
- **La ventana:** sale aunque hoy ya se haya cobrado, con «Tirada de pioneros: en 7 cobros» y las probabilidades.
- **La tirada:** con 🛠️ Pruebas → «🌟 Calendario: cobrar el día 7» y Cobrar, sale. Una Llama repetida dio +120 de Ámbar y «cycles» pasó a 1. No hubo errores en la Salida.
- **Los visores:** el huevo de pioneros y las tres monturas se encuadraron bien en modo edición.

Lo que falta: ver la animación entera en pantalla (la captura de Studio en Play no dibuja los visores 3D), una montura **nueva**, quien no es pionero y el teléfono.

### 16.1 En el Lobby (▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia) (= §7.4)

1. [ ] Pulsa 🛠️ Pruebas → «🌟 Calendario: cobrar el día 7» y, en la ventana (o en la pestaña Misiones), Cobrar.
   ✅ En la ventana, el huevo azul marino con motas de oro tiembla cada vez más, destella del color de la rareza y sale la montura girando, con su nombre y su rareza.
2. [ ] Repite el paso 1 hasta que salga una montura que ya tienes.
   ✅ La montura se ve velada y tachada, con «Ya la tenías: +N ✨ Ámbar», y el Ámbar sube.
3. [ ] Con 👑 Admin → 📋 Perfil, quítate el Jaguar y repite el paso 1 hasta que salga.
   ✅ Sale sin tachar, aparece en la ventana de Mascotas y se puede montar.
4. [ ] Cierra la ventana, sal y vuelve a entrar antes de una hora.
   ✅ Si no hay nada que cobrar, la bienvenida no vuelve a salir. Pasada una hora, sí.
5. [ ] Restaura la copia del perfil.

### 16.2 Quien no es pionero (con una cuenta nueva y la fecha de la T1 ya pasada)

1. [ ] Entra con una cuenta sin perfil cuando ya haya terminado la Temporada 1 (o mueve `startsAt` de la T1 al pasado en una copia del place).
   ✅ No queda marcado como pionero: la ventana solo sale si hay premio, con el título «📅 Premio diario», y el día 7 no tiene tirada.

### 16.3 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Entra al Lobby como pionero.
   ✅ Se leen el agradecimiento, «Tirada de pioneros: …» y la línea de probabilidades, sin solaparse con el calendario.
2. [ ] Cobra el día 7 (paso 16.1.1).
   ✅ La montura cabe en el visor y su nombre no tapa la cabeza.

### 16.4 En el juego publicado

1. [ ] Publica los **4 places a la vez** (el perfil pasa a la versión actual: 13, ver `PlayerData.luau` en `src/serverShared`) y entra al Lobby.
   ✅ Sale la bienvenida de pioneros y el perfil no se pierde al ir a la Isla o a Dunas y volver.

## 17. Lo que queda por probar de T7: la otra definitiva de cada rol (27-10-2026)

Probado en Studio (1 jugador, por remotos y con la tecla V, contra los muñecos):
- **Isla:** el Salto del gorila vuela 40 studs en arco y cae a 2 studs del muñeco al que apuntas (289 e inmovilizado); el Disparo certero hace 420 con la flecha blanca y dorada; el Haz volcánico da sus 10 golpes de 27 (con 2 rangos de Tormenta) y un aturdimiento lo corta a los 3; el Resurgir cura 70 y quita el veneno y el agarre. Cada uno empieza su recarga de 90 s.
- **Lobby:** en la ventana de Talentos salen las dos V debajo de los talentos, sin desplazamiento en PC; «Elegir» guarda la V en el perfil, cambia los botones y la casilla V del HUD pasa a «Salto».
- **Perfil:** pasa a la versión 11 con `ultimates`, sin perder nada.

Lo que falta: dos jugadores (la arena y las curas a otros), los efectos vistos en pantalla, el teléfono y el juego publicado.

### 17.1 Los efectos (Isla, ▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia)

1. [ ] En el Lobby, ventana Talentos, elige la otra V de cada rol que pruebes. Entra a la Isla, usa 🛠️ Pruebas → «🎭 Siguiente rol» y «⚡ Habilidades listas», y pulsa V delante de los muñecos.
   ✅ Guerrero: mientras salta, una sombra oscura con un aro ámbar marca dónde cae, y al caer el suelo se agrieta.
   ✅ Cazador: mientras carga sale una línea dorada fina hacia donde apuntas y después una flecha blanca y dorada con estela.
   ✅ Mago: un rayo de lava naranja con núcleo amarillo une el bastón con el muñeco durante 2 s, con chispas donde da.
   ✅ Médico: una columna verde sube del médico y salen tres coronas de hojas.
2. [ ] Restaura la copia del perfil.

### 17.2 Con dos jugadores (*Prueba → Clientes y servidores*, 2 jugadores; en Dunas, «🧪 Empezar ya»)

1. [ ] En Dunas, un cazador apunta con el Disparo certero al otro jugador.
   ✅ El apuntado ve la línea dorada antes del disparo; le quita unos 38 de 100 y, si bloquea, menos y gasta guardia.
2. [ ] Un guerrero salta con el Salto del gorila sobre el otro jugador, que está en guardia.
   ✅ Le rompe la guardia, le quita unos 38 y le deja quieto un momento (puede salir con el Evasivo).
3. [ ] Un mago lanza el Haz volcánico al otro, que bloquea de frente.
   ✅ Le gasta la guardia una sola vez aunque el haz pegue varias veces.
4. [ ] Un médico con Resurgir: el otro jugador, de su equipo, está envenenado y aturdido.
   ✅ En Dunas solo se le quita el veneno (sigue aturdido); en la Isla se le quitan los dos y se cura.
5. [ ] En Dunas, el Salto, el Disparo y el Haz contra una estela.
   ✅ La rompen de un golpe.
6. [ ] En Dunas, con la bandera rival a cuestas, pulsa V con el Salto del gorila.
   ✅ No salta y sale el aviso de la bandera.

### 17.3 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] En el Lobby abre Talentos.
   ✅ Se ven las dos filas de la V con su descripción y el botón, sin cortarse.
2. [ ] En la Isla, con el Salto elegido, mira los botones junto al salto.
   ✅ El de la V pone «Salto» y al pulsarlo salta hacia donde mira la cámara.

### 17.4 En el juego publicado

1. [ ] Publica los **4 places a la vez** (el perfil pasa a la versión actual: 13, ver `PlayerData.luau` en `src/serverShared`) y elige otra V en el Lobby.
   ✅ Al ir a la Isla y a Dunas lleva la V elegida, y al volver al Lobby sigue elegida.

## 18. Lo que queda por probar de la Fase 12: Victoria y parcela permanente (27-10-2026)

### P1. Seguir sobreviviendo

Probado en Studio (1 jugador, con 🛠️ Pruebas → «🚁 Terminar: victoria (rescate)» y «💀 Terminar: derrota», que son de prueba y no cuentan para el récord):
- **Rescate:** la ventana sale con «♾️ Seguir sobreviviendo», «Volver al Lobby» y «Si no eliges, vuelves al Lobby en N s», y cabe entera en la pantalla. Da +200 de Ámbar y suma 1 partida.
- **Seguir:** después de pulsar el botón, a los 30 s sigues en la partida y el estado de la baliza dice «♾️ Seguir sobreviviendo».
- **Jefes:** el día 10, sin haberlo derrotado, el Orangután vuelve con su vida normal (2205). Con las 4 piezas, el día 12 el Chimpancé sale más fuerte (4030 = 3100 × 1,3).
- **Final:** la ventana dice «♾️ Fin de la supervivencia: 9 días después del rescate» y da solo lo extra: +90 de Ámbar y +540 de XP del pase. No vuelve a contar la partida.

Lo que falta: una victoria de verdad (con la baliza), dos jugadores y el juego publicado.

#### 18.1 Una victoria de verdad (Isla, ▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia) (= §6.1)

1. [ ] Usa 🛠️ Pruebas → «📡 4 piezas + baliza sin espera», construye la baliza, enciéndela de día, salta a la noche y después al amanecer sin caer.
   ✅ Sale «¡Rescatados!» con los dos botones; en el Lobby, los rescates suben en 1.
2. [ ] Pulsa «♾️ Seguir sobreviviendo», salta un par de días y deja que te derroten de noche.
   ✅ Sale «Fin de la supervivencia» y el récord de días (cartel 🏆 Ranking del Lobby) cuenta todos los días, no solo hasta el rescate. Los rescates no vuelven a subir.
3. [ ] Después del rescate, intenta encender otra vez la baliza.
   ✅ Sale «Ya los rescataron» y la baliza sigue apagada.

#### 18.2 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] Ganen. Uno pulsa «Seguir sobreviviendo» y el otro no pulsa nada.
   ✅ A los 30 s el que no eligió vuelve al Lobby y el otro sigue en la partida, con el aviso «¡A seguir sobreviviendo!».
2. [ ] Ganen y que los dos pulsen «Volver al Lobby», o ninguno pulse nada.
   ✅ Los dos vuelven al Lobby, como antes de la Fase 12.

#### 18.3 En el juego publicado

1. [ ] Gana una partida y elige seguir. Desde otra cuenta, intenta entrar en ese servidor (Unirse desde un amigo).
   ✅ Sale «Esta partida ha terminado: volviendo al Lobby» y te devuelve al Lobby.

### P2. Desbloqueo y 5 huecos

Probado en Studio (1 jugador):
- **Huecos:** hay 5 parcelas de 24×24 entre el núcleo y la empalizada. Ninguna pisa el camino de un portón.
- **Migración:** un perfil v11 con `rescues = 1` pasa a v12 con la parcela desbloqueada. Su hueco sale como «🏡 Parcela de …», con el borde más grueso, de piedra y oro. La bienvenida sale en la Isla y en el Lobby (aquí, después del calendario) y no se repite.
- **Victoria:** con la parcela sin desbloquear, «🚁 Terminar: victoria (rescate)» la desbloquea. El cartel cambia enseguida y la bienvenida espera a que se cierre la ventana de resultados.
- **Volver a entrar:** «🏡 Parcela: desbloquear y subir sus estructuras un nivel» levanta en su sitio la forja, el taller, el nido y la cama. Al salir y volver a entrar, la parcela vuelve con ellas. El servidor no deja derribarlas.

Lo que falta: el asedio contra las estructuras de la parcela y dos jugadores.

#### 18.4 El asedio contra la parcela (Isla, ▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia)

1. [ ] Pulsa «🏡 Parcela: desbloquear y subir sus estructuras un nivel», salta a la noche y deja que los monos golpeen la forja de tu parcela hasta dejarla a 0.
   ✅ La forja no desaparece: sigue en su sitio, rota. Al repararla o al amanecer vuelve a tener vida.

#### 18.5 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] El jugador 1 pulsa «🏡 Parcela: desbloquear y subir sus estructuras un nivel». El jugador 2 va a la parcela del 1 y se acerca a su forja y a su taller.
   ✅ El 2 ve la parcela, el cartel con el nombre del 1 y las estructuras, pero no le sale el aviso para usar la forja ni el taller. Al 1 sí le sale.
2. [ ] El jugador 2 intenta construir dentro de la parcela del 1 o derribar algo suyo.
   ✅ No le deja: «solo en tu parcela…» o «Esta pieza es de …».
3. [ ] Con el nido de la parcela del 1 puesto, construid el nido del Basecamp en el núcleo.
   ✅ Se puede: el nido de la parcela no cuenta para el límite de uno por servidor.
4. [ ] El jugador 1 sale de la partida.
   ✅ Su parcela queda libre («Parcela libre», borde de madera) y sus estructuras desaparecen.

### P3. Estructuras que se mejoran

Probado en Studio (1 jugador, con el perfil restaurado después):
- **Ventana «🏡 Tu parcela»:** sale con el aviso «Mejorar» del cartel de tu hueco y enseña las 7 estructuras sin desplazarse (en PC, una columna; en el tamaño de un teléfono, dos).
- **Mejorar:** cada nivel cobra el Ámbar y los materiales justos. Si falta algo, no cobra nada. Al volver a entrar, la parcela sale con sus niveles.
- **Forja III:** tiene los dos avisos (forja y forja volcánica) y las recetas piden un 30 % menos (redondeado, nunca menos de 1).
- **Rota:** sin descuento, sus avisos se esconden y sale «Reparar (🌲 10 ⛰️ 6)». Reparada, vuelve todo. Al amanecer vuelve con toda la vida.
- **Amanecer:** el taller I da 1 venda y el huerto I, 1 banano y 1 plátano.
- **Cama III:** junto a ella se recuperan 3 de vida por segundo más.

Lo que falta: el asedio de verdad, caer con la cama, dos jugadores y el teléfono real.

#### 18.6 La parcela en la partida (Isla, ▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia)

1. [ ] Pulsa «🎒 +50 de todo», ve al cartel de tu parcela y construye la cama en la ventana «🏡 Tu parcela». Después cae (deja que te peguen los monos) y no te rindas.
   ✅ La cuenta atrás de Caído empieza en 50 s, no en 60, y reapareces en tu cama.
2. [ ] Salta a la noche y deja que los monos golpeen el taller de tu parcela hasta romperlo.
   ✅ Sale «💥 Han roto tu Taller del curandero…». No puedes abrir sus recetas, pero sí «Reparar». Si no lo reparas, al amanecer no te da vendas y vuelve con toda la vida.
3. [ ] Con la forja a medio romper, mejórala.
   ✅ La forja nueva sale con la misma parte de vida que le quedaba (no se repara al mejorarla).

#### 18.7 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] El jugador 1 tiene la parcela y su forja está rota. El jugador 2 se acerca a ella.
   ✅ Al 2 le sale «Reparar» y, si la repara, le cuesta a él la madera y la piedra. Lo que no le sale es el aviso para usar la forja.
2. [ ] El jugador 2 se acerca al cartel de la parcela del 1.
   ✅ No le sale «Mejorar»: la ventana solo la abre el dueño desde su cartel.

#### 18.8 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Abre «🏡 Tu parcela».
   ✅ Ocupa toda la pantalla libre, con las estructuras en dos columnas. Se lee todo sin desplazarse y los botones se pulsan bien.

### P4. Cofre con parte privada y compartida

Probado en Studio (1 jugador, con el perfil restaurado después):
- **Guardar:** «Abrir» en el cofre enseña tu Bolsa (solo lo que se puede guardar: ni la antorcha ni los tesoros de jefe) y el cofre. Guardar en lo privado o en lo compartido, de 1, de 10 o todo.
- **Casillas:** al llenarse (6 en el cofre I, de 50 cada una), solo completa la casilla empezada de ese objeto y avisa «📦 El cofre está lleno».
- **Trampas:** diez clics seguidos guardan una sola vez. El servidor rechaza los objetos no guardables y las cantidades falsas.
- **Sacar** de lo privado y de lo compartido (el dueño), a la Bolsa.
- **Mejoras:** el cofre II cobró la madera y la piedra de lo privado del cofre y el metal de la Bolsa.
- **Perder la partida y volver a entrar:** lo guardado sigue ahí.
- **Roto:** se apaga «Abrir», sale «Reparar», la ventana se cierra y no se puede guardar ni sacar.

Lo que falta: coger de lo compartido con otro jugador, salir del juego de verdad y el teléfono.

#### 18.9 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] El jugador 1 tiene el cofre construido y guarda 10 maderas en «🤝 Compartido» y 5 en «🔒 Privado». El jugador 2 abre su cofre.
   ✅ Al 2 la ventana le dice «📦 Cofre de …» y solo le enseña lo compartido (las 10 maderas), sin su Bolsa ni lo privado.
2. [ ] El jugador 2 pulsa la madera con «Todo».
   ✅ Las maderas llegan a su Bolsa un momento después (se espera a que se guarde el perfil del 1). Al 1 le sale «📦 … ha cogido 🌲 10 Madera de tu cofre compartido» y su cofre ya no las tiene.
3. [ ] El jugador 2 pulsa la madera muchas veces seguidas.
   ✅ Nunca coge más de las que había. Si pulsa mientras espera, le sale «📦 Espera: aún se está guardando lo anterior».
4. [ ] El jugador 1 sale de la partida con la ventana del 2 abierta.
   ✅ La ventana del 2 se cierra y el cofre desaparece con la parcela.

#### 18.10 En el juego publicado

1. [ ] Guarda algo en el cofre, pulsa «Volver al Lobby» y entra otra vez en la Isla.
   ✅ Lo guardado sigue ahí (al salir se guarda el perfil; en Studio no llega ese guardado).

#### 18.11 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Con unos 15 objetos distintos en la Bolsa, abre tu cofre.
   ✅ Ocupa toda la pantalla, con la Bolsa a la izquierda y el cofre a la derecha, sin desplazarse. Las casillas, los botones 1 / 10 / Todo y «🔒 Privado / 🤝 Compartido» se pulsan bien. Con la Bolsa muy llena (más de unos 20 objetos), la columna de la Bolsa se desplaza.

### P5. Incubadora, nido de la parcela y soltar el huevo

Probado en Studio (1 jugador, con el perfil restaurado después):
- **Soltar el huevo:** al recogerlo sale «Soltar huevo» (K, R3 en el mando y botón táctil). Al pulsarlo, el huevo queda en el suelo, el botón desaparece y cualquiera puede recogerlo.
- **Dos nidos:** con un nido de la partida a 8 studs del de la parcela, el huevo va al de la parcela de quien lo encontró. Solo con el otro a mano, va al otro.
- **Nido roto con huevo:** el huevo se pierde («💔 Los monos han destrozado el nido…»).
- **Mejorar durante la defensa:** el nido no se deja mejorar («🥚 Tu nido defiende un huevo…»). Construir el cofre en plena defensa no toca el nido ni pierde el huevo.
- **El nido de la parcela desaparece (como si su dueño se fuera):** el huevo cae a su lado y se puede llevar a otro nido.
- **Incubadora III:** el huevo defendido entra en el segundo hueco del nido, con el 70 % del tiempo. La incubadora de la parcela enseña los dos huevos con el color de su rareza.
- **Mejorar la incubadora de I a II:** lo que les falta a los huevos del nido baja en 0,70 / 0,85.
- **Lobby:** dos huevos uno al lado del otro en el nido. La ventana enseña los dos huecos, se abre cada uno por separado y «Al nido» llena el hueco libre.

Lo que falta: que se vaya el dueño de verdad, otro jugador que suelte o coja el huevo, la subida de rareza (es al azar), el teléfono y el juego publicado.

#### 18.12 En la Isla (▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia)

1. [ ] Sube la parcela al nivel III con «🏡 Parcela» del panel de pruebas y defiende varios huevos en tu nido («🥚 Huevo», «🐣 Terminar la defensa»).
   ✅ Más o menos 1 de cada 7 sale con «✨ ¡El nido de … ha mejorado el huevo: ahora es …!» y un grado más de rareza. Un huevo legendario nunca sube.

#### 18.13 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] El jugador 2 lleva un huevo al nido de la parcela del jugador 1 y, durante la defensa, el jugador 1 sale de la partida.
   ✅ El huevo cae junto al sitio del nido, sale «🥚 … se ha ido: el huevo ha caído junto a su nido. ¡Llévalo a otro!», y el 2 lo puede recoger y llevar a su nido.
2. [ ] El jugador 1 recoge el huevo y lo suelta («Soltar huevo»). El jugador 2 lo recoge.
   ✅ El 2 lo lleva, con el PvP activado; el 1 sigue con el PvP activado hasta que acaba su minuto.
3. [ ] El jugador 1 encuentra el huevo y el 2 lo lleva al lado del nido de la parcela del 1, que tiene otro nido cerca.
   ✅ El huevo se incuba en el nido de la parcela del 1, que fue quien lo encontró.

#### 18.14 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Recoge un huevo en la Isla.
   ✅ El botón «Soltar huevo» sale junto a los demás, sin tapar el salto, y se pulsa bien.
2. [ ] Con la incubadora III y dos huevos en el nido, abre el nido del Lobby.
   ✅ Se leen los dos huecos con sus barras y sus botones «Abrir» / «Incubando».

#### 18.15 En el juego publicado

1. [ ] Con la incubadora III, deja dos huevos en el nido del Lobby y vuelve al cabo de unas horas.
   ✅ Los dos han avanzado sin jugar, cada uno con el 70 % de su tiempo, y el cartel de mascotas del nido resume el segundo («2.º: …»).

## 19. Lo que queda por probar de I1a: la base del inglés (27-10-2026)

Probado en Studio (1 jugador, Lobby e Isla): el selector 🌐 Idioma de Ajustes se guarda en el perfil y cambia al momento el panel de Ajustes (que sigue cabiendo sin desplazarse en PC), el Armario, el pase y la tienda de cosméticos; las herramientas de la mochila de la Isla dicen su daño en inglés; `[Strings] sin inglés` solo sale para nombres de `Data` (I1e) y avisos del servidor de las tandas que faltan. Hasta la I1e, en inglés quedan en español los nombres de armas, monos, cosméticos y rarezas, y los textos propios del Lobby, la Isla y Dunas.

#### 19.1 Con otra cuenta (o cambiando el idioma de tu cuenta de Roblox)

1. [ ] Entra con una cuenta en inglés que no haya tocado el selector (Ajustes → 🌐 en «Automático»).
   ✅ El panel de Ajustes, el Armario y el pase salen en inglés sin elegir nada.
2. [ ] Lo mismo con una cuenta en español.
   ✅ Todo sale en español.
3. [ ] Con una cuenta en francés (o portugués), en el juego publicado y después de la I1e (con la tabla subida a Creator Hub).
   ✅ Los textos salen en francés, también los que llevan números («Jour 3 sur 30…»); si alguno no está traducido, sale en inglés, nunca en español.

#### 19.2 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] Pon a un jugador en English y al otro en Español, y haz que les llegue un aviso a los dos (por ejemplo, el de amago sin estamina, o un anuncio de administrador).
   ✅ Cada uno lo lee en su idioma; el texto del anuncio sale tal cual lo escribiste.

#### 19.3 En el teléfono (emulador de Studio, apaisado)

1. [ ] Abre Ajustes, Armario y pase con el idioma en English.
   ✅ Los textos caben en sus botones y tarjetas (el inglés no corta palabras ni se sale).

## 20. Lo que queda por probar de I1b: la Isla en inglés (27-10-2026)

Probado en Studio (1 jugador, Isla), en English y en Español y cambiando de uno a otro en plena partida: el reloj, el indicador y la vida del campamento, las líneas de estado (asedio, huevo, baliza), los avisos del servidor (huevo, caja de suministro, jefe, hambre, sed, fiebre, noche, La Gran Tropa con su lista de monos, caído), el cofre, la Bolsa, los resultados y los carteles del mundo (campamento, parcelas, tótem PvP, aviso del cofre con el nombre del dueño). Hasta la I1e, en inglés quedan en español los nombres de `Data` (monos, jefes, objetos, rarezas, estaciones, contratos, eventos) y los avisos del panel de pruebas, que se quedan en español a propósito. No se pudo abrir por teclado la ventana de la parcela ni la de fabricar: sus textos en inglés son más cortos que los españoles.

#### 20.1 Con 2 jugadores (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] Pon a un jugador en English y al otro en Español. Saca un huevo (🛠️ → Huevo), que uno lo recoja y lo lleve al nido.
   ✅ Cada uno lee en su idioma «… lleva el huevo», la línea del huevo arriba y el aviso del huevo a salvo, con el nombre del otro jugador tal cual.
2. [ ] Que uno caiga y el otro lo reanime (con y sin kit).
   ✅ «Has reanimado a…» / «You revived…» y «… te ha reanimado» / «… revived you», cada uno en su idioma; el cartel 🆘 sobre la cabeza del caído sale en el idioma de quien lo mira.
3. [ ] Que el inglés guarde algo en lo compartido de su cofre y el español lo coja.
   ✅ El aviso de proximidad dice «📦 Cofre de …» / «📦 …'s chest» según quien lo mira, y al dueño le llega «… took … from your shared chest» con los objetos.
4. [ ] Activa el PvP en los dos (tótem) y que uno derribe al otro con recompensa.
   ✅ El cartel «⚔️ PvP · 💰…» sobre cada uno y el aviso de la recompensa salen en el idioma de quien los ve.
5. [ ] Con un mono alfa cerca (🛠️ → panel de administración → tropa con alfa), mira su nombre.
   ✅ Sale «… alfa» en español y «Alpha …» en inglés (el nombre de la especie, en español hasta la I1e).

## 21. Lo que queda por probar de I1c: el Lobby y lo compartido en inglés (27-10-2026)

Probado en Studio (1 jugador, Lobby), en English y en Español y cambiando de uno a otro con una ventana abierta: la pastilla del Ámbar, el botón de viaje, la barra del menú, las ventanas Misiones, Talentos, Grupo, Rol, Mascotas, Arena y Ranking, los carteles de la plaza (bitácora, mascotas, roles, ranking, arena, pase), la cola de la arena con sus avisos y el cambio de misión (también el aviso «⚠️ …» cuando ya no quedan cambios). Hasta la I1e, en inglés quedan en español los nombres de `Data` (rarezas, mascotas, monturas, roles, habilidades, talentos, mejoras, misiones, objetos); hasta la I1d, las ventajas de los roles y las ranuras de la arena. Los avisos que el panel de administración y la moderación mandan al administrador se quedan en español a propósito.

#### 21.1 Con 2 jugadores en el Lobby (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] Pon a un jugador en English y al otro en Español. Que uno invite al otro al grupo desde la ventana Grupo, y que el invitado acepte. (= §3.1 p4)
   ✅ La ventana de invitación, «Invitación enviada a …» / «Invite sent to …» y «… se ha unido al grupo» / «… joined the party» salen en el idioma de cada uno, con el nombre tal cual.
2. [ ] Con el grupo hecho, que el que no es líder pulse el botón de viaje.
   ✅ «Tu grupo viaja cuando … (líder) presione "🍌 Ir a la Isla de monos 🐒"» en español y «Your party travels when … (leader) presses "🍌 Go to Monkey Island 🐒"» en inglés.
3. [ ] Que el líder entre en la cola de la arena con el grupo y después el otro salga del Lobby.
   ✅ Al que queda le llega «… se fue: salen de la cola de la arena» / «… left: the party leaves the arena queue».

#### 21.2 En el juego publicado

1. [ ] Con una cuenta en inglés, regala un cosmético a un jugador con la cuenta en español (y al revés).
   ✅ El que paga lee «🎁 You gave … to …» y el que lo recibe «🎁 ¡… te regaló …! Está en tu 👕 Armario», cada uno en su idioma.
2. [ ] Desde el panel de administración, expulsa a una cuenta de prueba en inglés y a otra en español.
   ✅ La ventana de Roblox dice «An admin has kicked you. Reason: …» o «Te ha expulsado un administrador. Motivo: …» según el idioma de la cuenta (o su ajuste); el motivo sale tal cual se escribió.
3. [ ] Programa un mantenimiento de 1 minuto con jugadores en los dos idiomas.
   ✅ El cartel del anuncio dice «📢 Announcement · Maintenance» y el texto del mantenimiento en inglés a unos, y en español a los otros; al cerrarse, la ventana de Roblox explica el mantenimiento en el idioma de cada uno.
4. [ ] Lanza una lluvia de huevos (evento en vivo) con jugadores en los dos idiomas y recoge un huevo.
   ✅ El aviso del huevo («🥚 Huevo …» / «🥚 … Egg»), el de empezar y terminar el evento y «🥚 ¡Huevo … recogido! Está en el nido» salen en el idioma de cada uno.
5. [ ] Cobra el día 7 del calendario con una cuenta pionera en inglés.
   ✅ La ventana dice «🎉 Day 7 claimed! …» con cada premio en inglés y la tirada «🎁 Pioneer roll: …».

## 22. Lo que queda por probar de I1d: Dunas y el combate en inglés (27-10-2026)

Probado en Studio (1 jugador, Dunas, con el panel de pruebas), en English y en Español: la ventana «Antes de la batalla» (estado, «¡Listo!» y su espera), la línea de la fase en la espera, la cuenta atrás, la partida y los resultados, el estado de las banderas bajo el marcador, la reaparición, la línea y el cartel del altar (apagado, encendido, tomándolo y la ventaja), los avisos de equipo, empezar, robar, soltar, volver sola y capturar la bandera, el altar encendido y el ganador, y la ventana de resultados (sin texto cortado en el PC). Hasta la I1e, en inglés quedan en español los nombres de `Data` (roles y sus ventajas, habilidades, armas, el equipo de la arena y sus ranuras «Armadura» y «Amuleto»). Jaguar y Quetzal se escriben igual en los dos idiomas.

#### 22.1 En el emulador de teléfono (Studio, Dunas, en English)

1. [ ] Con un teléfono apaisado, mira la ventana «Antes de la batalla» y los resultados.
   ✅ Las dos columnas de la ventana siguen sin desplazamiento y «⏳ Waiting… (cancel Ready)» cabe en su botón; en los resultados, «Rematch starts in … s with whoever stays» cabe en una línea.

#### 22.2 En la Isla y el Lobby (1 jugador, en English)

1. [ ] En la Isla, usa el grito de guerra con monos cerca, marca presas con el cazador y usa el tótem y Resurgir con el médico.
   ✅ «⚔️ 3 monkeys are coming for you! …» (con uno, «A monkey is coming for you!»), «🏹 2 prey marked for … s», «⛑️ Healing totem for … s» y «⛑️ Resurgence! You healed and cleansed 1 player».
2. [ ] Dispara un arma a distancia sin munición.
   ✅ «You need … to use: …» (los nombres, en español hasta la I1e).
3. [x] En el Lobby, mira los muñecos de práctica (probado en la I1e).
   ✅ Sobre la cabeza, «Practice dummy» y «Sparring dummy».

#### 22.3 Con 2 jugadores en Dunas (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] Pon a uno en English y al otro en Español, uno en cada equipo, y que uno derribe al otro.
   ✅ «⚔️ 🐆 … knocks out 🦜 …» a uno y «⚔️ 🐆 … derriba a 🦜 …» al otro.
2. [ ] Que los dos elijan el mismo rol cuando el formato solo admite uno, y que uno intente entrar en un equipo lleno.
   ✅ «Your team already has too many of this role: …» / «Ya hay demasiados … en tu equipo» y «Team … is already full» / «El equipo … ya está completo», cada uno en su idioma.
3. [ ] Con el médico, lanza el escudo de hojas a tu compañero.
   ✅ Al que lo recibe, «🍃 … shields you for …» o «🍃 … te protege con un escudo de …»; al médico, «🍃 … shield on …» o «🍃 Escudo de … para …».

## 23. Lo que queda por probar de I1e: el contenido de Data en inglés (27-10-2026)

Probado en Studio (1 jugador, en English): en el Lobby, los botones de las habilidades, el calendario de pioneros (con la tirada «🦙 Llama · 🐆 Jaguar · 🐍 Quetzalcoatl»), Talentos, Tienda (mejoras y cosméticos), Misiones, el pase entero, el Armario, el Diario (monos, jefes y botín) y Nido y mascotas (huevos, rarezas, mascotas y sus tipos); en Dunas, la ventana «Antes de la batalla» con los cuatro roles, sus ventajas y las tres ranuras del equipo de la arena del guerrero y del médico. Sin texto cortado en el PC y la consola sin `[Strings] sin inglés`. Arreglado en la prueba: la interfaz que se construye al entrar salía en el idioma de la cuenta si el perfil llegaba tarde; ahora el cliente espera hasta 3 s a los ajustes. Las claves de la tabla de la nube (`Strings.key`) salen iguales en Luau y en Python.

#### 23.1 En la Isla (1 jugador, en English)

1. [ ] Abre la mesa de trabajo, la hoguera, el taller del curandero y las dos forjas.
   ✅ Los nombres y las descripciones de las recetas en inglés, con su daño («Upgrades the bow: … damage, …»), y la armadura con el nombre de tu rol («Hunter's armor», «Rune robe»…).
2. [ ] Mira la Bolsa, el menú Construir y la ventana Parcela.
   ✅ Objetos y sus notas, construcciones y sus descripciones, y cada nivel de la parcela en inglés; el cofre dice «… slots of …, private or shared».
3. [ ] Acércate a un árbol, una roca, un helecho y una mata de banano, y a una estación.
   ✅ Los ProximityPrompt dicen «Chop / Tree», «Mine / Rock», «Gather / Fern», «Harvest / Banana plant», «Use / Workbench».
4. [ ] Juega hasta el contrato y un evento de mitad de partida (o lánzalos desde el panel de pruebas), y mira las misiones del HUD.
   ✅ El contrato, sus pasos, la víspera, el aviso y la línea del evento («☣️ Toxic rain: …») y las misiones («Survive 3 nights on Monkey Island») en inglés.
5. [ ] Que llegue la Gran Tropa y que aparezca un jefe.
   ✅ La mezcla de monos de la oleada sale «(Baboon ×5, Macaque ×3)», y «👑 Mangrove Orangutan · phase 1/3» sobre la barra del jefe; los monos y el jefe, con su nombre en inglés sobre la cabeza.

#### 23.2 En el emulador de teléfono (Studio, en English)

1. [ ] En el Lobby, abre el pase, el Armario y Nido y mascotas; en Dunas, la ventana «Antes de la batalla».
   ✅ Las descripciones largas (cosméticos del pase, mascotas, equipo de la arena) caben en sus tarjetas, y «Resurgence» cabe en su botón.

#### 23.3 En el juego publicado

1. [x] (Probado por el usuario el 27-10-2026, con francés, alemán y portugués.) Tras subir los `build/localization_*.csv` a Creator Hub (idioma de origen: inglés, con la traducción automática), entra con una cuenta en francés o en portugués.
   ✅ Los nombres de `Data` (armas, monos, cosméticos…) salen traducidos desde el inglés, y los textos con números siguen bien formados.

## 24. Lo que queda por probar de L1: el Laboratorio en ruinas (27-10-2026)

Probado en el Studio de Dunas (las armas del Laboratorio, dadas desde el servidor, contra el rival de práctica): los dardos ralentizan del 4 % al 20 % y ahí se paran; la red enreda (−35 %, 1 s) y no se renueva antes de 3 s; el suero sube en arco por encima de un muro de 3 studs a 36, cae junto al blanco, hace su daño y envenena, y deja el charco; el arco de Dunas sigue igual (12 por disparo, 18 el remate). La calculadora (sección 12) da las tablas de LABORATORIO.md §2.2 sin alertas. La primera persona (FirstPersonController) también se probó en Dunas: la mira en el centro, el arma de cada facción con las manos abajo a la derecha y centrada con la vista acercada. En el Studio del Laboratorio (place 106219409395860, 27-10-2026) se probó por MCP lo marcado abajo y, con un solo jugador, la reaparición: a los 3 s, con la vida llena, las 4 armas y la protección, que se pierde al disparar.

#### 24.1 En el Studio del Laboratorio (`rojo serve laboratorio.project.json`, puerto 34875)

1. [x] Crea el place `🧪Laboratorio en ruinas🏴‍☠️(PvP)` en la experiencia (SETUP.md, paso 5), pon su ID en `Config.PlaceIds.Laboratorio`, ábrelo en Studio, conecta Rojo y pulsa Play.
   ✅ Sale la sala de pruebas (suelo de hormigón, dos coberturas oxidadas y cuatro muñecos delante), apareces en su punto de salida y tienes las 4 armas en la mochila (teclas 1–4). No hay botones de habilidad, ni barra de guardia, ni marcas de cadena. En la Salida no hay errores.
   ✅ Juegas en primera persona: la cruz blanca en el centro (sin cursor) y el arma en la mano abajo a la derecha. Al disparar, el arma retrocede un poco y el disparo sale hacia la cruz.
   ⚠️ Con la primera persona fija el ratón no sale del centro, así que el panel de pruebas no se puede pulsar con el ratón. Para estas pruebas, pon `game.Players.LocalPlayer.CameraMode` a `Classic` desde la barra de comandos del cliente. La L2, con su selector de arma, tendrá que soltar el ratón en los menús.
2. [x] Con el panel de pruebas, «💔 Vida a 30».
   ✅ A los 4 s sin recibir daño la vida empieza a subir sola y llega a 100 (ahora 144, §85).
3. [x] Dispara cada arma a los muñecos de 15, 50 y 120 studs. (Probado: aciertan todas apuntando con la cruz; falta mirar los colores en movimiento.)
   ✅ Dardos azul claro, banana amarilla con estela, red y bola morada en arco; el arpón no llega a 50 y el lanzadardos no llega a 120.
4. [⏭] Con el rifle, mantén el clic derecho. ⏭️ Superado por §81/§84: el clic derecho del rifle ahora es apuntar (ADS).
   ✅ La vista se acerca, el rifle se centra con el visor justo bajo la cruz, y vuelve al soltar; al cambiar de arma, también vuelve.
5. [x] «🏴‍☠️ Cambiar de facción» varias veces, con un arma en la mano.
   ✅ Las armas pasan de blanco y azul (guardianes) a latón y madera (piratas) sin cambiar de casilla, también la de primera persona.

#### 24.2 Con 2 jugadores (Test → Clientes y servidores con 2)

1. [⏭] Disparaos con cada arma. ⏭️ Superado por §80 y §85: el rifle hace 48, el arpón 36 y las zonas cambian los números.
   ✅ Los números son los de LABORATORIO.md §2.1 (dardo 10, banana 45, red 35, suero 30 + veneno morado 6/s): nadie bloquea ni hace parry, los dardos ralentizan hasta un 20 %, la red no se repite antes de 3 s y nadie se queda quieto.
2. [ ] Mata al otro.
   ✅ «⚔️ … derriba a …», reaparece a los 3 s y durante 1,5 s no recibe daño, salvo si dispara antes.

#### 24.3 En el emulador de teléfono

1. [ ] Equipa el rifle.
   ✅ Sale el botón «Mira» encima de esquivar: un toque acerca la vista y otro la aleja. El suero cae donde mira el centro de la cámara.
2. [ ] Dispara tocando la pantalla y mueve la cámara arrastrando.
   ✅ En primera persona se apunta y se dispara con comodidad; el arma no tapa los botones ni la cruz.

## 25. Lo que queda por probar de L2: el Laboratorio central y el duelo por equipos (27-10-2026)

Probado en el Studio del Laboratorio por MCP con un jugador:
- `LabBuilder.build()` monta el mapa.
- Apareces en la zona de tu bando con el selector abierto, y el arma elegida llega a la mano y a la primera persona.
- «Empezar ya» abre las compuertas.
- Al morir sale el selector con la cuenta atrás, y reapareces con el arma nueva y la protección.
- El derrumbe cierra el invernadero en 1v1 y 2v2.
- La barrera de los Guardianes para a un pirata en su boca (x = 63,7) y deja entrar al pirata en la suya.
- Los resultados salen sin Ámbar ni 🚩 y con el ratón suelto.
- La revancha reparte los bandos otra vez y conserva el arma.

La sala de pruebas de la L1 ya no existe: los muñecos salen con «🎯 Muñecos delante» del panel. Para pulsar el panel, Ctrl (no Alt: en Studio, Alt enciende la vista del esqueleto del personaje).

#### 25.1 En el Studio del Laboratorio, con el ratón de verdad

1. [ ] Play. Con el selector abierto, mueve el ratón y pulsa una tarjeta.
   ✅ El cursor se ve y se mueve libre (sin la cruz), la tarjeta se marca en dorado y el arma cambia. Al plegar con «—», el ratón vuelve al centro y aparece «Cambiar de arma».
2. [ ] Pulsa Ctrl, abre «🛠️ Pruebas» y pulsa una orden. Pulsa Ctrl otra vez.
   ✅ Con Ctrl se suelta el ratón y abajo pone «Ctrl: volver a apuntar». El segundo Ctrl cierra la lista y vuelves a apuntar con la cruz. Con el selector de arma o los resultados abiertos, Ctrl no bloquea el ratón y el aviso no sale.
3. [ ] Recorre el mapa: la pasarela por sus dos escaleras, los tres carriles y las dos zonas.
   ✅ No se sube a ningún muro ni se sale del mapa (techo invisible). Los disparos pasan entre los barrotes de las jaulas y por las plataneras del invernadero, y los paran los bancales, los tanques y las cajas.
4. [ ] En el Studio de Dunas: «Empezar ya» y «Saltar fase» hasta los resultados.
   ✅ La ventana de resultados es la de siempre, con 🚩, los altares y la línea del Ámbar (la ventana pasó a `Shared/UI/MatchResults`).

#### 25.2 Con 2 jugadores (Test → Clientes y servidores con 2)

1. [ ] Play con 2 jugadores, los dos «¡Listo!».
   ✅ Cada uno sale en un bando y empieza la cuenta atrás de 10 s. Durante la espera nadie sale de su zona.
2. [ ] Disparaos en plena partida, también desde dentro de una zona de salida y a alguien que está dentro de la suya.
   ✅ Fuera de las zonas el daño entra. Dentro de una zona ni se hace ni se recibe daño. A los del mismo bando no se les hace daño (con 3 jugadores).
3. [ ] Intenta entrar en la zona del rival.
   ✅ Su barrera te para; la tuya te deja pasar en los dos sentidos.
4. [ ] Mata al otro 10 veces (1v1).
   ✅ Cada baja suma 1 al marcador de tu bando. A las 10 sale «🏆 ¡Gana el bando …!», con los resultados para los dos (victoria para uno y derrota para el otro).
5. [ ] Deja que acaben los 6 min empatados.
   ✅ «⚡ ¡Empate! Muerte súbita», y la siguiente baja gana.
6. [ ] Que uno se vaya en plena partida.
   ✅ Gana el bando que queda.

#### 25.3 En el emulador de teléfono

1. [ ] Abre el selector en un teléfono apaisado.
   ✅ Las 4 tarjetas caben en una fila sin desplazarse, más bajas y sin la descripción. Se pulsa con el dedo, y «¡Listo!» y el marcador no se tapan.

#### 25.4 En el juego publicado

1. [ ] Entra solo en el Laboratorio (sin rival) y espera 60 s.
   ✅ «No llegó el otro bando: vuelven al Lobby», y viajas al Lobby.
2. [ ] En los resultados, «🏝️ Volver al Lobby».
   ✅ Viajas al Lobby.

## 26. Lo que queda por probar de L3: cola del Laboratorio, embarcadero y cartel (28-10-2026)

Probado en el Studio del Lobby por MCP con un jugador: el cartel TablaLab en la plaza, el muelle y el velero pirata hechos y capturados, la cola del Laboratorio en Play con `ArenaQueue` `game="Lab"`, una sola cola por jugador, las entradas inválidas rechazadas, los textos nuevos y los 4 `rojo build`.

Lo que queda necesita los places publicados y varias cuentas: la cola entre servidores, los grupos y la revancha. Empieza por 26.1, porque el resto depende de la publicación.

#### 26.1 En el juego publicado (los 3 places subidos; el Lobby guardado en VERSION 16)

1. [⏭] Publica el Lobby, el Laboratorio y Dunas (Dunas comparte `ArenaQueueService`), y guarda el place del Lobby (VERSION 16: el aviso de la E del cartel del Laboratorio pasó al poste derecho). ⏭️ Superado por §29.1 y §86: la VERSION 16 ya no es la última.
   ✅ Los tres places abren sin errores en la Salida. El Lobby publicado muestra el embarcadero, el velero pirata y el cartel TablaLab.
2. [ ] Dos cuentas distintas, cada una en un servidor del Lobby, buscan «Duelo por equipos» en 1v1.
   ✅ Se emparejan, viajan al Laboratorio y caen en bandos opuestos (Piratas y Guardianes). El formato 1v1 pone 10 bajas.
3. [ ] Con un jugador en cola en un servidor, mira el 👤 por formato del cartel TablaLab y de la ventana del Laboratorio desde otro servidor.
   ✅ El contador sube en unos 10 s con los jugadores en cola de todos los servidores.

#### 26.2 Con 2 jugadores (*Test → Clientes y servidores* con 2)

1. [ ] Un jugador busca en la cola del Laboratorio y pulsa salir de la cola.
   ✅ Sale de la cola y su búsqueda se cancela.
2. [ ] Un grupo de 2 busca 2v2 y uno de los dos se va del servidor.
   ✅ Sale el mensaje «se fue: salen de la cola del Laboratorio» y el grupo entero sale de la cola.
3. [ ] Un jugador busca en la cola del Laboratorio, cambia a la cola de Dunas y busca 1v1 de Dunas.
   ✅ El ticket del Laboratorio se retira. La búsqueda de Dunas funciona igual que antes, y el cartel de Dunas cuenta su cola y no la del Laboratorio.
4. [ ] Un seguidor de un grupo pulsa buscar.
   ✅ Sale «Lo elige tu líder» y no entra en la cola.

#### 26.3 Con 4 jugadores (*Test → Clientes y servidores* con 4, para 2v2)

1. [ ] Un grupo de 2 busca 2v2 con otros 2 jugadores.
   ✅ Los dos del grupo llegan al mismo bando (LabParty). Tras la «revancha», los dos siguen juntos en un bando.
2. [ ] Un grupo de 3 busca 2v2.
   ✅ Sale el aviso «Tu grupo es de 3…» y el grupo no entra en la cola.

#### 26.4 En el Studio del Lobby (▶ Jugar, un jugador)

El MCP no puede abrir la ventana (solo sale con el evento real del aviso), así que `renderLab` no se ha ejecutado nunca: esto es lo primero que hay que probar.

1. [x] Acércate al cartel TablaLab y pulsa E.
   ✅ Se abre la ventana «🧪Laboratorio en ruinas🏴‍☠️(PvP)» con «Duelo por equipos», los botones 1v1…5v5 con «— 👤», «⚔️ Buscar partida» y una frase debajo. Cabe entera sin desplazar y no hay errores en la Salida.
2. [ ] Elige 3v3 y pulsa «⚔️ Buscar partida».
   ✅ El botón pasa a «✖ Salir de la cola», el 3v3 queda resaltado y la línea dice «⏳ Buscando partida 3v3… m:ss» y avanza cada segundo. Al salir, vuelve a la frase.
3. [ ] Pulsa el prompt «Zarpar a la Ciudad Perdida» del velero pirata.
   ✅ Abre la misma ventana del Laboratorio (modo, 5 formatos, buscar).
4. [ ] Mira el velero desde el punto de aparición (spawn).
   ✅ El velero no tapa ni choca con el carguero ni con el arrecife.

#### 26.5 En el emulador de teléfono

1. [x] Abre la ventana del Laboratorio (modo, 5 formatos, buscar).
   ✅ Se ve entera sin desplazar. Los botones se pulsan con el dedo. (Vista en el emulador apaisado: cabe entera; falta pulsar con el dedo en un teléfono real.)
2. [ ] Mira el cartel TablaLab en la plaza, y después la ventana del Laboratorio en PC.
   ✅ El cartel se lee bien en el teléfono. La ventana entera se ve sin desplazar también en PC.

#### 26.6 En el Creator Hub

1. [ ] Sube la tabla de textos nueva, la que sale de `python tools/strings.py --csv`, con las 8 frases nuevas del Lobby.
   ✅ Las 8 frases tienen su inglés en la tabla y se ven en inglés con el juego en inglés.

## 27. Lo que queda por probar de L4a: Todos contra todos y Rondas (28-10-2026)

Probado en el Studio del Laboratorio por MCP con un jugador: el duelo igual que antes; Todos contra todos (formato 10, sin bando, aparece en `SpawnsLibres`, y al llegar a 15 bajas gana con `place = 1`; las barreras de las bases chocan con el grupo `Default`); Rondas (la alarma, el fin por tiempo, `LabOut` al morir en plena ronda, la Intermission de 8 s con cambio de arma, el cambio de lado tras la 3.ª ronda con barreras y colores, 4 rondas que dan los resultados y la limpieza al acabar); y `LabMap` reconstruido a VERSION 2 con 12 marcadores en `SpawnsLibres`. El place no está guardado ni publicado.

Con capturas de Play en el Studio del Laboratorio (un jugador, textos en inglés) ya se vieron: el HUD de Todos contra todos, el de Rondas (rondas, reloj, «En pie», cuenta atrás de la alarma y alarma), la Intermission con el selector de arma, el aviso «Eliminado» con la vista fija desde arriba del espectador sin compañeros (con `LabOut` puesto a mano) y los resultados de Todos contra todos con el puesto. En el Studio del Lobby se vieron la ventana con los tres modos (formatos y frases de cada uno), y por MCP la validación de la cola (rechaza el formato 3 en Todos contra todos, el 10 en el duelo y el 7 en Rondas; acepta el 10 en Todos contra todos y se sale bien). La captura de Play no dibuja el cartel TablaLab: solo se leyeron sus textos.

Lo que queda necesita 2 o más jugadores (daño entre todos, espectador con compañeros, contorno de la alarma y desempates), el cartel y la ventana vistos de verdad, el teléfono real y el juego publicado. Empieza por 27.1: el mapa v2 tiene que quedar guardado antes de publicar.

#### 27.1 En el Studio del Laboratorio, con un jugador (`rojo serve laboratorio.project.json`, puerto 34875)

1. [⏭] Pulsa Play con un jugador, detén la prueba y guarda el place con Archivo → Guardar (sin publicar). ⏭️ Superado por §28.1: se guarda con LabMap v3. Si Rojo se desconecta, vuelve a conectarlo antes de Play.
   ✅ Al reabrir el place, `SpawnsLibres` sigue con 12 marcadores y la Salida no muestra errores.
2. [x] Con «🎮 Siguiente modo» hasta Todos contra todos y «Empezar ya», mira el HUD de arriba.
   ✅ Dos casillas neutras, «Tú 0» y «🥇 0», y debajo «Gana el primero a 15 bajas · vas 1.º». No aparece ningún color de bando.
3. [x] Con «🎮 Siguiente modo» hasta Rondas y «Empezar ya», mira el HUD durante la ronda.
   ✅ Las casillas muestran las rondas ganadas y el reloj; debajo, «Ronda 1 · gana el primero a 4» y «🧍 En pie: N · M».
4. [x] Espera a los 30 s de la ronda sin acabarla.
   ✅ Antes de la alarma, la línea dice «🔔 Alarma en 30 s» (la cuenta baja), y a los 30 s pasa a «¡Alarma! …».
5. [x] Pulsa «Saltar fase» hasta que acabe la ronda por tiempo.
   ✅ Sale la Intermission con «Ronda 2 en 8 s · puedes cambiar de arma» y se abre el selector de arma.
6. [x] Con «🎮 Siguiente modo» hasta Todos contra todos, «Empezar ya» y «➕ Punto para mí» hasta 15.
   ✅ Salen los resultados con el título «Puesto 1 de …», tu fila con el puesto delante y «🥇 tu nombre · 15 bajas». Sin columna de Ámbar ni 🚩.
7. [ ] En el Studio de Dunas, «Empezar ya» y «Saltar fase» hasta los resultados (Dunas igual).
   ✅ La ventana de resultados de Dunas es la de siempre, con 🚩, los altares y la línea del Ámbar.

#### 27.2 Con 2 jugadores (*Test → Clientes y servidores* con 2)

1. [ ] Con los dos en Todos contra todos, dispara al otro.
   ✅ El daño entra entre los dos (no hay bandos) y cada baja suma 1 a la casilla de quien la hizo.
2. [ ] Mata al otro varias veces y fíjate dónde reaparece cada vez.
   ✅ Reaparece lejos del rival, mirando al centro del mapa, y nunca al lado del que lo mató.
3. [ ] Al reaparecer, dispara en el primer segundo.
   ✅ Al disparar, quien reaparece pierde la protección y recibe daño como cualquiera.
4. [ ] Deja los dos a 14 bajas (cada uno pulsa «➕ Punto para mí» 14 veces) y pulsa «Saltar fase» hasta acabar el tiempo.
   ✅ Sale el aviso de muerte súbita, sin cuenta atrás. Gana el primero que se pone por delante y se queda solo en cabeza.
5. [ ] En plena partida de Todos contra todos, uno de los dos sale del servidor.
   ✅ El que queda gana: salen los resultados con «Puesto 1 de 2» y su fila con 🥇.
6. [ ] En Rondas 1v1, mata al otro en la primera ronda.
   ✅ La ronda la gana el que queda en pie, sube su marcador de rondas en 1 y sale la Intermission de 8 s.
7. [ ] Muere en plena ronda (Battle).
   ✅ Sale «💀 Eliminado: vuelves en la siguiente ronda». No reapareces hasta la siguiente Intermission.
8. [ ] Con la vida igual en los dos, deja que llegue el tiempo de la ronda (45 s) sin tocaros.
   ✅ La ronda es nula: no suma punto a nadie y empieza la Intermission.
9. [ ] Con el marcador de rondas igualado (1-1), adelanta `LabMatchEndsAt` (atributo en `ReplicatedStorage`) a unos segundos vista, según lo que lea `Modes/Rounds.luau`, y deja que la ronda acabe por tiempo sin tocaros.
   ✅ La partida no acaba con el empate: la siguiente ronda decide, y al ganarla salen los resultados.
10. [ ] En Rondas 1v1, uno de los dos sale del servidor en plena ronda (Battle).
    ✅ El que queda gana la ronda; si llega a 4 rondas, salen los resultados. No se queda colgado.
11. [ ] Repite el abandono, esta vez durante la Intermission de 8 s.
    ✅ La partida no se queda parada en la Intermission: sigue para el que queda o termina con su resultado, sin errores en la Salida.

#### 27.3 Con 4 jugadores (*Test → Clientes y servidores* con 4, Rondas 2v2)

1. [ ] Muere en Battle mientras tu compañero sigue vivo.
   ✅ La cámara pasa a tercera persona sobre tu compañero, con «Viendo a {name}», y los botones ◀ ▶ cambian a otro compañero vivo.
2. [ ] Pon `CameraMode` en primera persona fija (`LockFirstPerson`) y muere cuando tu compañero siga vivo.
   ✅ El espectador va en tercera persona aunque tengas la primera persona fija.
3. [ ] Muere cuando tu compañero ya esté muerto.
   ✅ No hay compañero que seguir: la vista es fija desde arriba y no sale «Viendo a …».
4. [ ] Espera a la siguiente Intermission y mira la cámara al reaparecer.
   ✅ Vuelve la primera persona con la cruz en el centro y el selector de arma se abre.
5. [ ] Con 30 s de ronda, en Classic, mira tu personaje y el de tu compañero.
   ✅ Sale «¡Alarma! …»; los compañeros y rivales vivos tienen un contorno del color de su bando, y el tuyo no.
6. [ ] Deja a un bando sin nadie en pie sin rellenar su vida, con la vida sumada igual a la del otro bando.
   ✅ Gana la ronda el bando que deja al otro sin jugadores en pie, aunque la vida sumada sea igual.
7. [ ] Juega hasta la 3.ª ronda (las nulas cuentan) y espera la Intermission.
   ✅ Las barreras cambian de color y cada bando ocupa la base del otro. Tu bando sigue siendo el mismo.
8. [ ] Tras el cambio de lado, camina con tu personaje hacia la barrera de la base rival y después sal de tu base nueva.
   ✅ La barrera de la base rival te para en su boca y no te deja entrar. La de tu base nueva te deja salir.
9. [ ] En Battle, uno de tu bando sale del servidor.
   ✅ La ronda sigue para los demás sin errores; si tu bando se queda sin nadie en pie, el otro gana la ronda.
10. [ ] Con «➕ Punto para mí» (o jugando), llega un bando a 4 rondas.
    ✅ Salen los resultados con el puesto de cada jugador delante de su fila.

#### 27.4 En el Studio del Lobby (▶ Jugar, un jugador)

1. [x] Acércate al cartel TablaLab y pulsa E.
   ✅ La ventana muestra los tres modos: «Duelo por equipos», «Todos contra todos» y «Rondas». En Todos contra todos aparece «10 jugadores». Cabe sin desplazar y no hay errores en la Salida.
2. [x] Elige «Todos contra todos» y después «Duelo por equipos».
   ✅ Cada modo muestra sus formatos: en Todos contra todos solo «10 jugadores»; en el duelo, de 1v1 a 5v5. Hay una frase que explica el modo.
3. [ ] En el duelo, elige 3v3. Cambia a «Rondas», elige 2v2 y vuelve a «Duelo por equipos».
   ✅ El duelo sigue con 3v3 marcado: el formato se recuerda por modo.
4. [ ] En Rondas 2v2, pulsa «⚔️ Buscar partida».
   ✅ Sale «⏳ Buscando partida de 4 jugadores…» y el botón pasa a «✖ Salir de la cola». Al salir, vuelve «⚔️ Buscar partida» y la frase del modo.
5. [ ] Mira las tres tarjetas del cartel TablaLab desde la plaza.
   ✅ Hay una tarjeta por modo con el número que espera. El nombre «Todos contra todos» se lee entero, sin cortarse ni salirse de la tarjeta.
6. [ ] Entra en la cola de Rondas y mira la insignia de la cola (y que el aviso de la E sale en el poste derecho y no tapa los formatos).
   ✅ La insignia de la cola muestra el modo elegido.

#### 27.5 En el emulador de teléfono

1. [ ] En Rondas, con el teléfono apaisado, mira el HUD durante la ronda.
   ✅ Las casillas, «Ronda N · gana el primero a 4», «🧍 En pie» y la línea de la alarma se leen sin acercarse y no tapan los botones de esquivar ni el joystick.
2. [ ] En 2v2, muere con un compañero vivo y usa ◀ ▶ con el dedo.
   ✅ Los botones del espectador no chocan con los controles táctiles, y se pulsan sin fallar.
3. [ ] Abre la ventana de resultados de Todos contra todos.
   ✅ El título «Puesto N de M», los puestos y las filas se leen sin desplazar. El texto pequeño es legible.
4. [ ] Abre la ventana del Laboratorio desde el cartel TablaLab.
   ✅ Se ven los tres modos enteros sin desplazar, y los botones se pulsan con el dedo.

#### 27.6 En el juego publicado

1. [ ] Con el Laboratorio guardado con LabMap v2, publica los tres places (Lobby, Laboratorio y Dunas, que comparte `ArenaQueueService`) con Archivo → Publicar en Roblox.
   ✅ Los tres abren sin errores en la Salida, y el duelo por equipos del Laboratorio sigue igual.
2. [ ] Diez cuentas en servidores del Lobby buscan Todos contra todos. (Si tienes menos cuentas, baja `FreeForAllPlayers` en `Config` solo para la prueba y vuélvelo a 10 antes del commit.)
   ✅ Se juntan en una sola sala del Laboratorio sin bandos: las casillas del HUD son neutras y cada uno sale con una facción al azar, que solo cambia el aspecto.
3. [ ] Un grupo de 2 busca Todos contra todos con otros jugadores.
   ✅ Los dos del grupo entran en la misma partida, sin bando.
4. [ ] Dos cuentas distintas buscan Rondas 1v1.
   ✅ Se emparejan, caen en bandos opuestos y empieza la Ronda 1.
5. [ ] Un grupo de 2 busca Rondas 2v2 con otros 2 jugadores.
   ✅ Los dos del grupo llegan al mismo bando. En la revancha siguen juntos en un bando.
6. [ ] Con un jugador en cola de Rondas en un servidor, mira el cartel TablaLab desde otro servidor.
   ✅ El 👤 de Rondas sube en unos 10 s con los jugadores de todos los servidores, y el de Todos contra todos también.
7. [ ] Durante las pruebas de cola, mira en la consola de desarrollo (F9) si sale algún aviso de MemoryStore.
   ✅ No sale ningún aviso de límite ni error de cuota. El cupo es de 16 lecturas por ciclo de 10 s y servidor: si se acerca, anota el número y avísame.

## 28. Lo que queda por probar de L4b: mapas Azotea y Alcantarillas y votación de mapa (28-10-2026)

Probado en el Studio del Laboratorio por MCP con un jugador: la reconstrucción limpia de `LabMap` con los tres mapas (Central 1823 piezas, Azotea 1853 y Alcantarillas 1427, sin avisos de `checkFreeSpawns`); la iluminación de cada mapa y su vuelta al Central; los derrumbes, que cierran en 1v1 (cascotes de 8,8 a 14 de alto, que el salto de 7,2 no pasa) y se abren en los formatos mayores; las caídas por los huecos y tramos laterales de la Azotea (muerte sin baja, y los bordes cerrados bloquean); la rampa y las escaleras sin resbalar; los disparos del grupo `Disparo` (cruzan barreras, la barandilla del escalón y los barrotes, pero no paredes, aparatos ni la Barrier de una zona) y un disparo real con una barrera en medio que daña; los personajes sin atravesar nada; el agua de las Alcantarillas sin frenar (velocidad 16, sin nadar); las rutas de las Alcantarillas de 4 studs o más; 22 apariciones en Todos contra todos sobre suelo; y la votación: se abre con 10 s, se cierra al votar, cambia de mapa y reaparece en él, y después sale el selector de arma. Los votos inválidos se ignoran, con 0 votos sortea entre los tres, «Solo», «Saltar fase» y «🗳️ Cerrar la votación ya» la cierran, y la revancha la vuelve a abrir. Las tres maquetas se distinguen (capturas de la sesión principal). El place no está guardado ni publicado con `LabMap` v3.

Lo que queda necesita 2 o más jugadores (el empate de votos, el cierre con votos parciales, las caídas con crédito, el espectador en los tres mapas y el cambio de lado en la Azotea y las Alcantarillas), el ratón real (la primera persona), el teléfono, el juego publicado y cinco observaciones de diseño. Empieza por 28.1: el `LabMap` v3 tiene que quedar guardado antes de publicar.

#### 28.1 En el Studio del Laboratorio, con un jugador (`rojo serve laboratorio.project.json`, puerto 34875)

1. [⏭] Guarda el place con Archivo → Guardar (sin publicar), con `LabMap` en la versión 3. ⏭️ Superado por §86: el place ya se guardó con LabMap v3 antes. Si Rojo se desconecta, vuelve a conectarlo antes de Play.
   ✅ Al reabrir el place, `LabMap` tiene `Version` 3 y los tres Models (`Central`, `Azotea` y `Alcantarillas`), y la Salida no muestra errores.
2. [x] Con «🏙️ Siguiente mapa» pasa por los tres mapas y mira cada uno desde el suelo.
   ✅ Cada mapa tiene sus piezas (1823, 1853 y 1427) y su luz, y al volver al Central vuelve la luz del Central. No sale ningún aviso de `checkFreeSpawns`.
3. [x] Con 1v1 y con 5v5, mira los derrumbes de la Azotea y de las Alcantarillas.
   ✅ En 1v1 se cierran (los cascotes de 8,8 a 14 de alto frenan el salto de 7,2) y en 5v5 quedan abiertos.
4. [x] Cae a pie por uno de los huecos de la Azotea y por uno de los tramos laterales, y después pulsa «🪂 Caerme del mapa».
   ✅ Cada caída te devuelve a reaparecer sin dar baja a nadie (sin atacante, es una muerte sin baja). Los bordes cerrados te paran y no se cae por ellos.
5. [x] Sube y baja a pie la escalera de la Azotea y la rampa de la grúa.
   ✅ Subes y bajas sin resbalar ni atravesar la pieza.
6. [x] Dispara a un muñeco del panel de pruebas con una barrera invisible en medio (la de la barandilla o la de los barrotes). Después dispara contra una pared, un aparato y la Barrier de una zona de salida.
   ✅ El disparo cruza la barrera invisible y el muñeco recibe daño. La pared, el aparato y la Barrier de la zona paran el disparo.
7. [x] Camina contra un muro invisible, contra un barrote y contra la Barrier de una zona de salida.
   ✅ El personaje no los atraviesa.
8. [x] Camina por el agua de las Alcantarillas.
   ✅ Se anda a velocidad normal (16), sin nadar y sin frenar.
9. [x] Recorre el túnel norte, el túnel sur y el paso a la sala de bombas de las Alcantarillas.
   ✅ Todas las rutas miden 4 studs de ancho o más (la observación del paso norte y sur está en 28.6).
10. [x] En Todos contra todos, deja que reaparezcas varias veces.
   ✅ Cada aparición cae sobre el suelo.
11. [x] Al llegar, deja que la votación se cierre sola a los 10 s, sin votar.
   ✅ Sale un mapa al azar entre los tres, reapareces en él y después se abre el selector de arma.
12. [x] Vota una tarjeta y después otra.
   ✅ Al votar se cierra al momento y cambia al mapa elegido. Un voto con un mapa que no existe se ignora.
13. [x] Con la ventana de votación abierta, pulsa «🗳️ Cerrar la votación ya», y después repite con «🎮 Solo» y con «Saltar fase».
   ✅ Cada una cierra la votación y deja el mapa que toque, sin que la ventana se quede abierta.
14. [x] Acaba una partida y espera a la revancha.
   ✅ La votación vuelve a abrirse antes de elegir arma.
15. [x] Mira las tres maquetas de la ventana de votación en PC.
   ✅ Cada mapa se distingue a primera vista: el Central, la torre de la Azotea y el corte de las Alcantarillas.
16. [ ] Con el ratón, apunta a través de un muro invisible al primer intento, justo después de entrar en la partida.
   ✅ La línea de puntería cruza el muro igual que el disparo. Si el primer apuntado se para en el muro, se anota en 28.6.
17. [ ] Con el ratón, salta desde el suelo a la tapa de un depósito.
   ✅ Subes a la tapa sin atascarte.
18. [ ] Con el ratón, camina hasta el pretil de la Azotea y dispara por encima.
   ✅ El personaje no pasa el pretil, y el disparo lo cruza sin frenarse.

#### 28.2 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio)

1. [ ] En Rondas 1v1, cada uno vota un mapa distinto y deja que se acabe el tiempo.
   ✅ Sale uno de los dos mapas votados, al azar, y los dos reaparecen en él. El mapa que nadie votó no sale.
2. [ ] En Rondas 1v1, vota solo uno de los dos y deja que se acabe el tiempo.
   ✅ La votación se cierra a los 10 s con el voto que hay, y el mapa de ese voto es el que se juega.
3. [ ] Vota un mapa con uno de los dos y el otro vota otro. Antes de que se cierre la votación, el que votó sale del servidor.
   ✅ Su voto no cuenta: el mapa lo decide el voto del que queda, y la Salida no muestra errores.
4. [ ] En la Azotea, dispara al otro hasta herirle y haz que caiga al vacío en los 10 s siguientes (por un hueco o un tramo lateral).
   ✅ Sale «🪂 {tu nombre} tira a {nombre} al vacío», tu `ArenaKills` sube en 1 y el que cae reaparece.
5. [ ] Envenena al otro con el cañón de suero ácido y haz que caiga al vacío dentro de los 10 s, con el veneno todavía activo.
   ✅ La baja cuenta para quien lo envenenó, como si lo hubiera golpeado.
6. [ ] Hiere al otro y espera más de 10 s sin tocarle. Después haz que caiga al vacío.
   ✅ Muere sin aviso de caída y sin baja para nadie.
7. [ ] En Rondas 1v1, dispara a la barrera de la zona de salida del rival, y pídele que intente cruzarla a pie.
   ✅ El disparo se para en la barrera, y el personaje del rival no la cruza.
8. [ ] En Rondas 1v1, en cada uno de los tres mapas (Central, Azotea y Alcantarillas), muere en plena ronda y mira la vista desde arriba.
   ✅ La vista fija enseña el mapa entero desde arriba. En las Alcantarillas se ven los túneles (la cuestión del relleno está en 28.6).
9. [ ] En Todos contra todos, en la Azotea y luego en las Alcantarillas («🏙️ Siguiente mapa»), mata al otro varias veces y mira dónde reapareces.
   ✅ Reapareces lejos del rival, mirando al centro del mapa, como en 27.2.
10. [ ] En Rondas 1v1, en la Azotea y luego en las Alcantarillas, juega hasta la 3.ª ronda (las nulas cuentan) y espera la Intermission.
   ✅ Las bases cambian de dueño en el mapa que se juega: cada uno sigue en su bando y las barreras cambian de color.

#### 28.3 Con 4 jugadores (*Test → Clientes y servidores* con 4, Rondas 2v2)

1. [ ] En Rondas 2v2 en la Azotea, muere con tu compañero vivo.
   ✅ La cámara sigue al compañero en tercera persona con «Viendo a {name}», y ◀ ▶ cambian a otro compañero vivo.
2. [ ] Lo mismo en las Alcantarillas, con el compañero dentro de un túnel.
   ✅ La cámara sigue al compañero sin que el techo tape la vista (el `Techo` queda oculto para el espectador).
3. [ ] En Rondas 2v2, mira los derrumbes de la Azotea y de las Alcantarillas.
   ✅ Se cierran como en 1v1: las escaleras y la rampa de la Azotea, y el túnel sur de las Alcantarillas.

#### 28.4 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Con el teléfono apaisado, abre la votación de mapa.
   ✅ Las tres tarjetas caben sin desplazar. En compacto (tarjetas de 132 px) no sale la línea de la distancia, y el nombre y los votos se leen sin acercarse.
2. [ ] Vota con el dedo y mira el selector de arma que sale después.
   ✅ El selector se abre solo cuando se cierra la votación, y sus botones se pulsan con el dedo.
3. [ ] En las Alcantarillas, mira la iluminación (22 focos).
   ✅ Se ven los túneles sin ir a ciegas, y los focos no deslumbran. Si queda oscuro, se ajusta la luz de las Alcantarillas.
4. [ ] Con los tres mapas cargados, juega una ronda en cada uno y mira el rendimiento al cambiar de mapa.
   ✅ No hay tirones claros al cambiar de mapa. Si los hay (unas 5100 piezas en el place), el plan B es aparcar los mapas inactivos en `ServerStorage`.
5. [ ] Abre las maquetas de la votación en el teléfono.
   ✅ Las tres se distinguen en pantalla pequeña.

#### 28.5 En el juego publicado

1. [ ] Con `LabMap` v3 guardado, publica el Laboratorio con Archivo → Publicar en Roblox y abre una partida.
   ✅ Abre sin errores en la Salida, y la votación sale con las tres maquetas.
2. [ ] Entra por la cola del Lobby (el embarcadero) en Rondas, con cola real, y vota al llegar.
   ✅ La votación se abre al llegar, y el mapa votado es el que se juega.
3. [ ] Deja que llegue el arranque automático de 60 s con la votación abierta, sin pulsar nada.
   ✅ Al cerrarse la votación arranca la partida en el mapa elegido, sin que la votación quede colgada.
4. [ ] En la revancha, con un mapa lejano elegido (la Azotea está a 2000 studs), mira dónde apareces.
   ✅ Apareces en el mapa nuevo. Si tarda en llegar, se anota cuánto (el cliente recibe el mapa con un retraso).
5. [ ] Al cerrarse la votación, mira la Salida por si sale el aviso «🗳️ Mapa: …».
   ✅ Sale el aviso con el nombre del mapa elegido. (En la prueba anterior no se vio.)
6. [ ] Al abrir el place, mira la consola de desarrollo (F9) por el aviso de `rbxassetid://203785492`.
   ✅ Si sale, es el aviso de antes de L4b (×3 en el Studio); se anota y no se arregla en esta fase.

#### 28.6 Para decidir (observaciones de diseño, sin prueba de juego)

1. [ ] Alcantarillas: las líneas rectas de 46 a 61 studs, desde las bocas de los colectores en diagonal hacia el túnel principal (lo esperado es ≲35). Decide si se cortan con una pieza o se aceptan.
   ✅ Queda anotada la decisión en `docs/LABORATORIO.md` §4.
2. [ ] Alcantarillas: el paso norte y el sur miden justo 4,0 de ancho. Decide si se ensanchan o se quedan así.
   ✅ Queda anotada la decisión, con dos personajes cruzándose en el paso para comprobarlo.
3. [ ] Alcantarillas: el rincón de las esquinas de los colectores (36 celdas). Decide si se rellena o se deja.
   ✅ Queda anotada la decisión.
4. [ ] Alcantarillas: desde arriba (`OverheadHeight` 120, `OverheadBack` 0 y el `Techo` oculto), el relleno tapa hasta el 59 % del suelo del túnel norte y del sur. Decide si se sube la altura de la vista o se aparta el relleno.
   ✅ Queda anotada la decisión.
5. [ ] Panel de pruebas: los muñecos («Dummies») salen a y = 196 y 168 en el Laboratorio. No es de L4b. Decide si se corrige en `LabDebugService` aparte.
   ✅ Queda anotada la decisión.

## 29. Lo que queda por probar de L5a: recompensas del Laboratorio (28-10-2026)

Ya probado en Play en el Studio del Laboratorio con un jugador (28-10-2026): los resultados de los tres modos con Ámbar, tope y XP, el tope de 300 con recorte, la partida de prueba sin cobro y el título con 49 → 50 victorias forzadas. Las bajas se pusieron a mano en `ArenaKills`, porque el comando «Punto para mí» no pasa por `onKnockedOut`. Lo que queda necesita 2 o más jugadores, perfiles con partidas y días acumulados, el teléfono real y el juego publicado. Empieza por 29.1: el Lobby v17 tiene que quedar guardado antes de publicar, y el perfil v13 se publica junto con los otros tres places (29.5).

#### 29.1 En el Studio del Lobby (`rojo serve lobby.project.json`, puerto 34872)

1. [⏭] Reconstruye el Lobby en modo edición con `require(game.ServerScriptService.Server.World.LobbyBuilder).build()` y guarda el place con Archivo → Guardar (sin publicar). ⏭️ Superado: el rebuild v17 ya no aplica. Si Rojo se desconecta, vuelve a conectarlo antes de Play.
   ✅ El Lobby queda en la versión 17 y la Salida no muestra errores. Al reabrir el place, el cartel del Ranking sigue con sus tres bloques.
2. [ ] Mira el cartel del Ranking desde la plaza, en PC.
   ✅ Se leen los tres bloques (supervivencia, arena y 🧪 LABORATORIO) con sus columnas, sin cortarse ni salirse del cartel de 26 studs.
3. [ ] Abre la ventana de Ranking desde el Lobby.
   ✅ Sale el grupo del Laboratorio con sus dos clasificaciones, y tus cifras del Laboratorio aparecen en él.

#### 29.2 Con 2 jugadores en el Laboratorio (*Test → Clientes y servidores* con 2; el paso 5, con 3)

1. [ ] En Todos contra todos, deja que acabe la partida con las bajas de uno por encima de las del otro (con 15 bajas o al acabar el tiempo).
   ✅ Sale «Puesto 1 de 2» para el primero y «Puesto 2 de 2» para el otro. Cada uno ve su línea de Ámbar y de XP: el 1.º, 45 de Ámbar más una por baja (hasta 15) y 60 de XP; el 2.º, 30 más una por baja y 30 de XP.
2. [ ] Con armas distintas, cada uno mata al otro varias veces en Duelo por equipos 1v1, y mira `profile.lab.weaponKills` del servidor al acabar.
   ✅ Las bajas de cada uno suman en la casilla de su arma, una por baja real, y las muertes propias no suman a ninguna.
3. [ ] Cambia de arma en la Intermission (con el selector), mata al otro con la nueva, y en la siguiente partida vuelve a la anterior y mata con ella.
   ✅ Cada baja suma en la casilla del arma con la que se hizo, y la casilla de la otra arma no cambia.
4. [ ] En Rondas 1v1, gana uno la partida (4 rondas) y el otro pierde.
   ✅ El ganador cobra 45 de Ámbar más sus bajas y 60 de XP; el perdedor, 15 de Ámbar y 20 de XP.
5. [ ] Con 3 jugadores en Todos contra todos, deja que dos de ellos acaben empatados detrás del primero (con las mismas bajas).
   ✅ Los dos empatados cobran 30 de Ámbar y 30 de XP cada uno. Si hay un 4.º, cobra 15 de Ámbar y 20 de XP.

#### 29.3 Con el perfil real, en Play (copia de `PlayerData_v1` en `PlayerData_v1_backups` antes, y restaurada después)

1. [ ] Con `lab.stats.winsPirates` en 49 (o con 50 victorias reales), gana una partida de Duelo por equipos con los piratas.
   ✅ Sale «⚓ Saqueador del PRIMAL» como título ganado, y el Armario lo tiene en la lista de títulos.
2. [ ] Con 50 victorias con los guardianes ya guardadas en el perfil (antes de la L5a, o forzadas), entra en el Lobby.
   ✅ «🧬 Guardián del Suero» aparece como ganado al entrar, sin jugar otra partida.
3. [ ] Con `lab.daily` de hoy en 300, juega una partida del Laboratorio. Después pon `lab.daily.day` en el día anterior (o espera al cambio de día de `Daily`) y juega otra.
   ✅ En la primera no cobras Ámbar y los resultados dicen que el tope diario está lleno. En la segunda, el tope empieza de nuevo desde 0 y el Ámbar se cobra otra vez.

#### 29.4 En el emulador de teléfono

1. [ ] Mira el cartel del Ranking del Lobby desde la plaza, con el emulador de teléfono.
   ✅ Los tres bloques se leen sin acercarse, y el bloque 🧪 LABORATORIO se lee entero.
2. [ ] Abre la ventana de Ranking con el teléfono apaisado.
   ✅ Los tres bloques (supervivencia, arena y Laboratorio) caben sin desplazar, y los botones se pulsan con el dedo.

#### 29.5 En el juego publicado

1. [⏭] Publica los cuatro places a la vez (Lobby, Isla, Dunas y Laboratorio) con Archivo → Publicar en Roblox, porque el perfil pasa a la versión 13. ⏭️ Superado: el perfil v13 ya se publicó.
   ✅ Los cuatro abren sin errores en la Salida. Un perfil ya existente se carga sin perder Ámbar, XP ni títulos, y los campos nuevos empiezan vacíos.
2. [ ] Con cola real desde el Lobby, dos cuentas buscan Rondas 1v1, juegan una partida y una la gana (sin «🏁 Ganar de verdad», que es solo de Studio).
   ✅ La que gana cobra Ámbar y XP de victoria, y la que pierde, Ámbar y XP de derrota. Tras el refresco del ranking, el bloque del Laboratorio muestra la victoria (se anota cuánto tarda).
3. [ ] Con el evento «Doble Ámbar» activo en vivo, juega una partida en el Laboratorio.
   ✅ El Ámbar de la partida sale doble antes del tope, y el tope diario sigue en 300.
4. [ ] Con la semana nueva (empieza el lunes a las 00:00 UTC), mira las misiones semanales en el Lobby.
   ✅ «⚗️ Gana 3 partidas en el Laboratorio en ruinas» sale entre las semanales de la rotación, y ganar una partida la suma 1 de 3. Si esta semana no sale, se anota y se mira en la siguiente.
5. [ ] Con el mismo perfil, juega en la Isla y en Dunas el mismo día hasta acercarte a 1.200 XP de partidas, y después juega una partida en el Laboratorio.
   ✅ La XP del Laboratorio se recorta al resto del tope de 1.200, compartido con la Isla y Dunas, y el pase suma solo lo que queda.

## 30. Lo que queda por probar de L5b: skins del Laboratorio por bajas (28-10-2026)

Probado en Play en el Studio del Laboratorio, con un jugador y con copia y restauración del perfil (28-10-2026): la entrega por umbral (con los umbrales de entonces, 100 → I, 500 → II y 2.000 → III; hoy son 50, 250 y 1.000 y el mecanismo es el mismo), la publicación de «<arma>Skin» y el cambio de la Tool sin reaparecer, el cambio de bando que mantiene la skin, quitar y volver a poner la skin, un hueco independiente para cada arma, las 12 skins construidas en los dos bandos y la consola limpia. Los 12 modelos están revisados con capturas de perfil y desde atrás. Lo que queda necesita 2 o más jugadores, la vista en el Studio y en el teléfono, la calculadora `Economia` en el Studio de la Isla y el juego publicado. Empieza por 30.1.

#### 30.1 En el Studio, con un jugador (Lobby y Laboratorio; haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [ ] En el Lobby, con las bajas que tenga la cuenta de prueba (o con `lab.weaponKills` puesto a mano en el perfil), abre el Armario, pestaña de armas, y pulsa el botón «🧪 Laboratorio».
   ✅ Sale el chip «🧪 Laboratorio» en la pestaña de armas y la lista con las skins de las cuatro armas, una tarjeta por línea.
2. [ ] Lee el texto de progreso de las tarjetas del lanzarredes y del cañón, que son los nombres más largos.
   ✅ «Bajas con <arma>: n/objetivo» se lee entero, sin cortarse con el nombre del arma, y el número coincide con `weaponKills`.
3. [ ] Pon una skin desde el visor del Armario y después quítala.
   ✅ El visor enseña el arma con su skin al ponerla, y el arma base del bando al quitarla, sin cambiar de pestaña.
4. [ ] En el selector de arma del Laboratorio, con una skin puesta, mira la tarjeta de esa arma.
   ✅ La tarjeta enseña la skin de la arma con el bando activo, y se lee sin cortes.
5. [ ] En el Laboratorio, en primera persona, mira el arma con la skin III del lanzadardos y la del cañón, apuntando y sin apuntar.
   ✅ Las piezas de espalda (`LabBack`) y las partículas se esconden, y las antenas, los cuernos y los tentáculos no tapan la mira.
6. [ ] Mira la imagen de una skin en su tarjeta del Armario y en una ventana de recompensa.
   ✅ La imagen enseña su arma con la skin (no el machete) y con el bando correcto.

#### 30.2 En el Studio de la Isla, en modo edición: la calculadora

1. [x] En la barra de comandos, ejecuta `local m = game.ServerStorage.Tools.Economia:Clone(); print(require(m).informe()); m:Destroy()`.
   ✅ La salida tiene la línea «Skins del Laboratorio» con los días para llegar a cada grado (50, 250 y 1.000 bajas con una sola arma): habitual 9 · 44 · 175; intenso 3 · 11 · 42; grupo de amigos 6 · 28 · 110. Repartidas entre las cuatro armas, los días salen cuatro veces más.
2. [x] Lee la sección «Alertas» de esa misma salida.
   ✅ No aparece ninguna alerta nueva por las skins. Si sale una, se compara con la alerta aceptada de la tienda de Ámbar (`docs/LABORATORIO.md` §5) antes de tocar nada.

#### 30.3 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en el Laboratorio)

1. [ ] En Todos contra todos, cada uno con su arma, mata al otro varias veces y mira `profile.lab.weaponKills` del servidor al acabar.
   ✅ Cada baja suma una sola vez en la casilla de su arma (aunque haya varios rivales), y las muertes propias no suman a ninguna.
2. [ ] Con el comando «SkinKills» del panel del Laboratorio (+100 bajas con tu arma, que ya dan el grado I) en uno de los dos, y después alguna baja real con esa arma, acaba una partida de Todos contra todos o de Duelo.
   ✅ Al cerrar la partida, la skin I de esa arma queda entregada, con su aviso de cosmético ganado, y se pone sola si el hueco estaba vacío.
3. [ ] Desde el cliente del otro jugador, mira el arma que tienes en la mano.
   ✅ El otro jugador ve tu arma con la skin, la misma que ves tú.
4. [ ] En Rondas 1v1, al cambiar de lado a la mitad, mira el arma en la mano de los dos.
   ✅ El cuerpo y el acento cambian con el bando, y la skin se mantiene.

#### 30.4 En el emulador de teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] Abre el Armario del Lobby con el teléfono apaisado y pulsa el chip «🧪 Laboratorio» con el dedo.
   ✅ El chip se pulsa, las tarjetas se leen y el texto «Bajas con …» se lee entero, sin cortes.
2. [ ] Pon una skin desde el visor con el dedo y después quítala.
   ✅ El visor cambia al instante en los dos casos, y el botón se pulsa sin dar a otra tarjeta.
3. [ ] En el selector de arma del Laboratorio y en primera persona, con una skin III.
   ✅ La tarjeta del arma muestra la skin, y las piezas de espalda y las partículas no tapan la mira.

#### 30.5 En el juego publicado

1. [ ] Publica los cuatro places a la vez (Archivo → Publicar en Roblox). El perfil sigue en la versión 13, así que no cambia, pero el código sí.
   ✅ Los cuatro abren sin errores en la Salida, y un perfil existente se carga sin perder nada.
2. [ ] Con una cuenta de prueba, juega en el Laboratorio hasta llegar a 50 bajas con un arma (o parte de 49 y gana una baja real con esa arma).
   ✅ Llega el aviso de cosmético ganado al conseguir el grado I, y la skin se pone sola si el hueco estaba vacío.
3. [ ] Con una cuenta que ya tenga bajas guardadas de antes de la L5b (de la L5a), entra en el Lobby sin jugar.
   ✅ Los grados que le tocan aparecen como ganados en el Armario al entrar, sin jugar otra partida. Una cuenta sin `lab.weaponKills` guardado no tiene grados retroactivos.

## 31. Lo que queda por probar de V1: movimiento unificado (28-10-2026)

Probado en Studio con un jugador, con copia y restauración del perfil (28-10-2026): en la Isla, andar 18, correr 26 con gasto de estamina, aturdido 0, ralentizado ×0,5, guardia 10,8 sin correr, gateo a 4 (poniendo `LifeState` a «Downed» a mano) y vuelta a 18, y huevo ×0,9 con Guerrero; en el Lobby, las reglas publicadas, 18/26, correr sin gastar estamina, montura (Jaguar) 33 y vuelta a 18, y aturdido 0; en Dunas, las reglas publicadas, 18/26 con gasto de estamina, aturdido, ralentizado, guardia 10,8 sin correr, bandera 15,3 (poniendo `CarryingFlag` a mano) y `MoveSpeed` ×1,08 (con `Perk_MoveSpeed` a mano); en el Laboratorio, las reglas publicadas (`Dash`), 18/26, vaciar la estamina (el cliente baja a 18 con unos 8 de estamina, por ir por delante del servidor), aturdido y ralentizado (a mano y con `Status.entangle`). Lo que queda necesita caer de verdad, la bandera y una pieza de la arena reales, un dardo o red de un rival, el teléfono, 2 jugadores o el juego publicado. Empieza por 31.1.

#### 31.1 En el Studio de la Isla, con un jugador (haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [ ] Cae de verdad: deja que el hambre llegue a cero o recibe un golpe mortal (sin poner ningún atributo a mano). Mientras gateas, mira la velocidad del personaje; después reanímate o reaparece.
   ✅ Al caer la velocidad baja a 4. Al reanimarte o reaparecer vuelve a 18 (o a 26 si corres), sin tocar nada. `humanoid:GetAttribute("NormalWalkSpeed")` da nil.
2. [ ] Con un rol que no sea Guerrero, recoge un huevo del nido y anda, y después corre.
   ✅ Anda a unos 13,5 (18 × 0,75) y corre a unos 19,5 (26 × 0,75).
3. [ ] Ralentiza a tu personaje con un mono o una habilidad real (un dardo, la Nova o el Polvo somnífero, según tu rol) y mide la velocidad mientras dura.
   ✅ Anda más despacio mientras dura el efecto (`SlowedUntil`), y vuelve a 18 al acabar.
4. [ ] Con hambre o sed bajas, gasta la estamina corriendo hasta cero y mide cuánto tarda en volver a 100. Repite con las necesidades cubiertas.
   ✅ Con hambre o sed bajas se recupera a la mitad de velocidad.

#### 31.2 En el Studio de Dunas, con un jugador

1. [ ] Empieza una partida («Empezar ya»), coge la bandera rival de verdad y anda y corre con ella.
   ✅ La velocidad es 18 × min(1; 0,85 + CarrySpeed), o sea 15,3 sin ventaja de CarrySpeed. Sin `MovementController` en el cliente, la pone `LocomotionController`.
2. [ ] Equípate una pieza de la arena con `MoveSpeed` (por ejemplo, la de +0,08 de `Data/ArenaGear`) y mide la velocidad andando y corriendo.
   ✅ La velocidad sube en ese factor sobre 18 y sobre 26, y vuelve a lo normal al quitártela.

#### 31.3 En el Studio del Laboratorio, con un jugador

1. [ ] Recibe un dardo o una red de un rival real (hacen falta 2 jugadores), y mide la velocidad mientras dura.
   ✅ Anda más despacio mientras dura el efecto, y vuelve a 18 al acabar.

#### 31.4 En el emulador de teléfono y con mando (elige un dispositivo en *Prueba → Dispositivo* antes del ▶)

1. [ ] En la Isla, pulsa el botón «Correr» una vez, anda un poco y vuelve a pulsarlo, sin mantener el dedo.
   ✅ La primera pulsación pone a correr y gasta estamina; la segunda vuelve a andar.
2. [ ] Con un mando, pulsa L3 para correr y L3 otra vez para parar.
   ✅ Alterna igual que el botón táctil, y mientras corres gasta estamina.

#### 31.5 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en la Isla o en Dunas)

1. [ ] Uno de los dos se monta en una montura y corre, y el otro lo mira desde su pantalla.
   ✅ Se ve el movimiento normal en las dos pantallas, sin tirones ni paradas de velocidad. El servidor no escribe la velocidad: el `WalkSpeed` que se ve es el que manda el cliente de ese jugador.

## 32. Lo que queda por probar de V2: deslizamiento (28-10-2026)

Probado en Studio con un jugador, en el Lobby y en el Laboratorio (28-10-2026): el pico de velocidad, unos 35,5 studs/s, que baja en línea recta a unos 18 en 0,75 s; el cooldown de 1 s; andando no desliza; en el Lobby no gasta estamina; el salto deslizado conserva unos 0,89 de la velocidad; en el Laboratorio la cámara baja 1,5 en unos 0,1 s. Consola sin errores. En la Isla también (28-10-2026): coste de 15 de estamina (91 → 75, con el gasto de correr), cooldown (no a 0,72 y 0,92 s, sí a 1,08 y 1,43 s), con 7 de estamina no desliza y con hambre y sed a 10 el pico es 30,1 (0,85 × 36) y el final 15,3. En Dunas (28-10-2026): sin bandera desliza (pico 35,4, estamina −15) y con `CarryingFlag` no desliza. Lo que queda necesita la bandera real en Dunas, el teléfono, el mando, el juego publicado (con la pose) o 2 jugadores. Empieza por 32.1.

#### 32.1 En el Studio de la Isla, con un jugador (haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [x] Con la estamina llena, corre y pulsa Alt izquierdo. Mira la estamina antes y después del deslizamiento.
   ✅ Al deslizar, la estamina baja de golpe unos 15 puntos (de 100 a unos 85), sin contar la regeneración de ese momento.
2. [x] Gasta la estamina corriendo hasta quedarte justo por debajo de 15 (unos 14) y pulsa Alt izquierdo.
   ✅ No desliza: sigue corriendo o anda, y la estamina no baja de golpe.
3. [x] Con hambre o sed bajas (deja que baje una de las dos o pon el valor que usa `Survival.isWeak`), desliza y mide el pico de velocidad. Compáralo con un deslizamiento con las necesidades cubiertas.
   ✅ Con hambre o sed bajas el pico es unas 0,85 veces el normal: unos 30 studs/s en vez de 35,5 (medido: 30,1).

#### 32.2 En el Studio de Dunas, con un jugador

1. [ ] Empieza una partida («Empezar ya»), coge la bandera rival de verdad, corre y pulsa Alt izquierdo. (Probado el 28-10-2026 solo con el atributo `CarryingFlag` puesto a mano: no desliza ni gasta estamina; falta con la bandera real.) (= §31.2 p1)
   ✅ No desliza mientras llevas la bandera: no hay impulso ni coste de estamina.
2. [x] Suelta la bandera y pulsa Alt izquierdo corriendo. (Probado quitando el atributo: pico 35,4.)
   ✅ Vuelve a deslizar con el mismo impulso y coste que en la Isla.

#### 32.3 En el Studio del Laboratorio, con un jugador

1. [ ] Con la estamina llena, corre y pulsa C dos veces, con 0,8 s entre una pulsación y otra.
   ✅ Solo desliza la primera. La segunda no hace nada, porque el cooldown es de 1 s.
2. [ ] Igual que el paso anterior, pero con 1,1 s entre las dos pulsaciones.
   ✅ Desliza las dos veces: la segunda empieza al acabar el cooldown.
3. [ ] Con la estamina justo por debajo de 15 (unos 14), pulsa C corriendo.
   ✅ No desliza. Con 15 o más sí.

#### 32.4 En el emulador de teléfono y con mando (elige un dispositivo en *Prueba → Dispositivo* antes del ▶)

1. [ ] En la Isla, corre con el botón «Correr» y mira el botón mientras corres.
   ✅ El botón dice «Deslizar» mientras corres, y vuelve a «Correr» al parar.
2. [ ] Corriendo, pulsa el botón «Deslizar».
   ✅ Desliza con el mismo impulso y coste que con Alt izquierdo.
3. [ ] Pon el correr con el botón «Correr» y no muevas el joystick.
   ✅ Tras unos 0,3 s sin mover el joystick, el correr táctil se apaga y el botón vuelve a «Correr».
4. [ ] Con un mando, corre y pulsa R3.
   ✅ Desliza igual que con Alt izquierdo.
5. [ ] Con un mando y una montura equipada, a pie, pulsa R3.
   ✅ Hoy R3 hace Montar y no desliza. Decisión pendiente: si se acepta así, se anota aquí; si no, el deslizamiento tiene prioridad sobre Montar.
6. [ ] Con un mando y un huevo a cuestas, pulsa R3.
   ✅ Hoy R3 hace Soltar huevo y no desliza. Decisión pendiente, igual que el paso anterior.

#### 32.5 En el juego publicado (con la pose `Slide` publicada)

1. [ ] En Windows, con el juego publicado en la Isla, Dunas y el Lobby, pulsa Alt izquierdo mientras corres.
   ✅ Desliza, y no se abre el menú de la ventana ni del navegador.
2. [ ] En los mismos tres places, pulsa Alt izquierdo sin correr y, con Alt pulsado, haz clic para atacar.
   ✅ Ni Alt ni el clic se pisan: el clic de arma funciona igual y no sale ningún menú.
3. [ ] En la Isla y en el Lobby, con el bloqueo de cámara (Ctrl) encendido, desliza.
   ✅ El personaje no da tirones de giro ni pelea con la cámara, y al acabar sigue igual que sin bloqueo.
4. [ ] Desliza hacia una pared de la Isla o de Dunas.
   ✅ Se frena en la pared y no la atraviesa.
5. [⏭] Ejecuta `PlayerAnimationBuilder.build()` en modo edición, publica la secuencia «Slide» y enlázala como indica la skill `animaciones-roblox`. Después, juega y desliza. ⏭️ Superado por §35.3: el id de la pose Slide ya está pegado.
   ✅ Al deslizar se ve la pose de agachado, y al acabar el personaje se levanta. Antes de publicarla, el id está vacío y no hay pose.

#### 32.6 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en la Isla o en Dunas)

1. [ ] Uno de los dos desliza y el otro lo mira desde su pantalla (con la pose publicada).
   ✅ El otro ve la pose de agachado y el deslizamiento a la misma velocidad que tú, sin tirones. El servidor no escribe la velocidad: el deslizamiento se ve como lo mueve el cliente de ese jugador.

## 33. Lo que queda por probar de V3: esquiva con efecto (28-10-2026)

Probado en Studio con un jugador, en el Lobby y en la Isla (28-10-2026): la esquiva recorre entre 13,4 y 14,2 studs en el Lobby y 13,9 en la Isla (en teoría, 55 × 0,2 s más el 40 % que se apaga en 0,2 s: unos 13,2; el Evasivo, unos 14,4); el campo de visión vuelve exacto al valor de antes; la invulnerabilidad dura 0,35 s; contra una pared no queda ninguna velocidad colgando; con el ajuste de cámara "cameraShake" en Apagado no hay empujón de FOV y en Suave es de unos 2,7°; la Embestida recorre 21 studs con el empujón de FOV y su estela de carga; esquivar deslizando funciona; consola sin errores; la calculadora `Equilibrio` no da alertas nuevas. En el Laboratorio también (un jugador, primera persona): la cámara se inclina 7,7° hacia el lado de la esquiva (D a la derecha, A a la izquierda, 0 con W o S), el arma de la vista se aparta 0,6 al lado contrario, el FOV vuelve exacto también con el rifle acercado, no se reproduce DodgeRoll ni DodgeBack y esquivar deslizando con C lo deja todo limpio. Queda por mirar a ojo lo del Laboratorio, el sonido y la estela, el teléfono, 2 jugadores y el juego publicado. Empieza por 33.1.

#### 33.1 En el Studio del Laboratorio, con un jugador (haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [ ] Mira al frente, mantén D y pulsa Q (o B con el mando) y mira la cámara.
   ✅ A ojo se ve bien: la parte de arriba de la pantalla se va hacia la derecha y en unos 0,25 s vuelve recta. (Medido: D baja el lado derecho 7,7°; si a ojo se siente al revés, se cambia el signo en `DodgeFeel.tilt`.)
2. [ ] Con el arma sin acercar, esquiva hacia la derecha y mira el arma en la mano.
   ✅ Se aparta hacia la izquierda sin tapar la mira y vuelve a su sitio en unos 0,25 s.
3. [ ] Si tienes un segundo cliente (ver 33.4), mira tu personaje desde fuera al esquivar en el Laboratorio.
   ✅ No hace la voltereta ni el salto atrás: la esquiva es solo un empujón.

#### 33.2 En el Studio de la Isla o de Dunas, con un jugador

1. [ ] Esquiva con Q y escucha.
   ✅ Se oye un sonido de aire corto. Es provisional: el definitivo se hará aparte.
2. [ ] Esquiva con Q y mira los pies. Si tienes equipado un cosmético con estela, quítalo para verla sola.
   ✅ Sale una estela fina blanco-azulada pegada al cuerpo que se apaga enseguida, y una bocanada de polvo claro a los pies hacia atrás. Es más discreta que la del Evasivo.
3. [⏭] Espera la recarga (1,2 s) y encadena 4 esquivas seguidas, mirando el campo de visión. ⏭️ Superado por §74: el empujón de FOV cambió.
   ✅ En cada esquiva el campo de visión sube unos 6° y vuelve en 0,25 s. Revisa a ojo la 3.ª y la 4.ª: si el empujón salta de golpe en vez de subir suave, anota el número de la esquiva y cómo se ve (no está confirmado).
4. [ ] Pon dos piezas en el suelo separadas 13 studs y esquiva hacia ellas. Luego, aturdido (con un mono o con un muñeco que te aturda), pulsa Q en cuanto puedas para el Evasivo.
   ✅ La esquiva pasa la segunda pieza, y se para cerca de los 13 studs (en el Lobby se midió entre 13,4 y 14,2). El Evasivo llega a unos 14 studs, con el empuje que sigue al salto.
5. [ ] Pon un muro a unos 5 studs delante de ti y esquiva hacia él.
   ✅ No lo atraviesa. Si parece que no se mueve nada, anótalo: no se sabe todavía si pasaba ya antes de V3.
6. [ ] Haz una Embestida contra un muñeco de práctica.
   ✅ Recorre unos 21 studs con el campo de visión subiendo y bajando, y con la estela de carga. Sin estela de esquiva.

#### 33.3 En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶)

1. [ ] En la Isla, toca el botón «Esquivar».
   ✅ Esquiva igual que con Q: mismo empuje, mismo sonido, misma estela y mismo empujón de campo de visión.
2. [ ] En el Laboratorio, con el rifle acercado, toca «Esquivar».
   ✅ La cámara se inclina y el arma se aparta igual que en PC, y el zoom vuelve exacto al acabar.
3. [ ] Toca «Esquivar» varias veces seguidas, sin esperar.
   ✅ Cada esquiva espera la recarga, y al acabar el campo de visión vuelve a su valor normal.

#### 33.4 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en la Isla o en Dunas)

1. [ ] Uno esquiva y el otro lo mira desde su pantalla.
   ✅ El otro ve la estela y el polvo de la esquiva, y los dos se oyen con el sonido de aire.
2. [ ] Uno hace una Embestida y el otro lo mira.
   ✅ El otro ve la Embestida con su estela de carga, pero no la estela de esquiva (ese efecto solo se ve en el que lo hace).
3. [ ] Uno queda aturdido y pulsa Q (Evasivo); el otro lo mira.
   ✅ El otro ve el Evasivo, y se distingue a simple vista del de la Embestida y de la esquiva normal.
4. [ ] En el Laboratorio, uno esquiva y el otro lo mira.
   ✅ El que esquiva ve la inclinación y el arma en su pantalla; el otro solo ve a su personaje sin voltereta, con la estela y el polvo.

#### 33.5 En el juego publicado

1. [ ] Publicado, en la Isla, esquiva con Q varias veces seguidas con sonido activado.
   ✅ Se oye el sonido de aire en cada esquiva, sin tirones de audio.
2. [ ] Publicado, en Dunas, con varias esquivas y Embestidas seguidas en una partida, mira las estadísticas de rendimiento de Roblox.
   ✅ Los FPS no caen de forma notable con la estela y el polvo activos. (Anota el valor antes y después si se nota.)

## 34. Lo que queda por probar de V5: feedback de daño (28-10-2026)

Probado en el Studio de la Isla (28-10-2026): los bordes salen en rojo con un golpe crítico y con uno de al menos el 15 % de la vida máxima (con la vida máxima en 150, el umbral son 22,5); el pulso con salud baja tiene una transparencia de 0,70–0,88 (opacidad 0,12–0,30); el arco se mide a ±90° y a 0° según el lado del atacante; con el ajuste apagado no sale nada. A ojo, el destello se ve bien y el pulso es tenue a propósito. Queda por probar con 2 jugadores (en Dunas o el Laboratorio), en el teléfono, el ajuste en el Lobby y en PC, el pulso con la vida baja de verdad, y el tiro a la cabeza, que espera a V7. Empieza por 34.1.

#### 34.1 En el Studio de Dunas o del Laboratorio, con 2 jugadores (*Test → Clientes y servidores*, con 2)

1. [ ] A pega o dispara a B desde un lado mientras B mira su pantalla sin mover la cámara.
   ✅ En la pantalla de B sale un arco rojo en el anillo alrededor del centro, apuntando hacia A.
2. [ ] B gira la cámara a la derecha y luego a la izquierda, con A quieto.
   ✅ El arco gira con la cámara y sigue apuntando a A, sin quedarse atrás más de un instante.
3. [ ] A pega a B por el lado contrario y B mira hacia el otro lado.
   ✅ El arco cambia de lado y apunta a A, no al lado de siempre.
4. [ ] En el Laboratorio, A dispara a B desde lejos con el rifle y B está quieto.
   ✅ El arco sale hacia A aunque esté lejos, y se apaga en unos 0,8 s.
5. [ ] Un bot o un muñeco de práctica pega a B.
   ✅ B ve los números y el destello si el golpe es fuerte, pero no sale ningún arco.

#### 34.2 En el teléfono o el emulador (elige uno en *Prueba → Dispositivo* antes del ▶, a 844 × 390)

1. [ ] En la Isla, deja que un mono te pegue fuerte y mira la pantalla.
   ✅ El destello de los bordes se ve y no tapa la barra de vida ni el mapa.
2. [ ] En Dunas, deja que un bot te pegue desde un lado.
   ✅ El arco cabe entero en la pantalla y no tapa el HUD ni los botones de combate.
3. [ ] Mientras el destello o el pulso están activos, toca los botones de la esquina y los del borde (el salto, la acción, el joystick).
   ✅ Cada toque llega al botón. Los bordes no bloquean los toques.

#### 34.3 En el ajuste, con un jugador (Studio de la Isla y del Lobby)

1. [ ] Abre Ajustes y apaga «Pantalla roja al recibir daño». Recibe un golpe crítico y, en Dunas, un golpe de otro jugador.
   ✅ No sale ni destello, ni arco, ni pulso, pero los números de daño siguen.
2. [ ] Con el interruptor apagado, cambia de place (de la Isla al Lobby o al revés) y vuelve a abrir Ajustes. Después, enciéndelo, cambia de place y vuelve a mirar.
   ✅ Sigue apagado en el primer caso y encendido en el segundo. Se guarda en los dos sentidos.
3. [ ] En PC, abre Ajustes en el Lobby y mira la fila nueva.
   ✅ Todas las filas se ven sin desplazarse, y «Pantalla roja al recibir daño» cabe entera.

#### 34.4 Pulso con salud baja de verdad, en el Studio de la Isla, con un jugador

1. [ ] Deja que un mono o un muñeco te pegue hasta caer por debajo del 25 % de la vida, y mira la pantalla sin tocar nada durante 10 s.
   ✅ Los bordes laten despacio, cada 1,2 s, con un rojo tenue. No molesta para leer el HUD ni para jugar.
2. [ ] Cúrate por encima del 25 %.
   ✅ El pulso se funde a cero en unos 0,4 s.

#### 34.5 El tiro a la cabeza (V7 ya manda el campo `head`)

1. [ ] Recibe un tiro a la cabeza, con otro jugador o con un muñeco, y compara con un golpe normal del mismo daño.
   ✅ El destello sale más fuerte con la cabeza (opacidad 0,7 frente a 0,45). V7 y W6 ya están hechos: el paso se puede probar.

## 35. Lo que queda por probar de V4: animaciones de andar, correr y deslizar (28-10-2026)

Probado en Studio, en la Isla (28-10-2026): ciclos de Walk, Run y RunArmed generados, medidos (los pies no bajan de −0,10) y revisados en tira; en Play, Walk suena a 18 studs/s y se para al quedarse quieto. Ids publicados el 28-10-2026 y pegados. Lo que queda necesita verse a ojo en los cuatro places, el teléfono, 2 jugadores y el juego publicado, con los ids ya pegados. Empieza por 35.1.

#### 35.1 En el Studio de la Isla, del Lobby, de Dunas y del Laboratorio, con un jugador (haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [ ] En cada uno de los cuatro places, anda y después corre a 26 studs/s con la estamina llena.
   ✅ Anda con Walk a unos 18 studs/s y corre con Run a unos 26. El cambio de uno a otro es limpio: no parpadea ni se corta dos veces seguidas (el umbral está en 22 studs/s).
2. [ ] Coge un arma y corre.
   ✅ Sale RunArmed: piernas y tronco con el ciclo de correr, y el brazo derecho sigue sujetando el arma sin moverse con la animación.
3. [ ] Anda o corre y salta.
   ✅ El ciclo se para en el aire, y vuelve a sonar al tocar el suelo si sigues moviéndote.
4. [ ] Monta una montura (el Jaguar, en el Lobby o en la Isla) y mueve al personaje.
   ✅ El ciclo de andar o correr se para, y manda la pose de montado.
5. [ ] Cae de verdad (deja que el hambre llegue a cero o recibe un golpe mortal, como en 31.1) y mira las piernas mientras gateas.
   ✅ El ciclo de andar se para: manda la pose de gateo.
6. [ ] Corre y pulsa Alt izquierdo (C en el Laboratorio) para deslizar. Mira el balanceo del tronco.
   ✅ Se para el ciclo de correr y se ve la pose de deslizar, con el tronco balanceándose y sin mezclarse con las piernas de correr. Al acabar, vuelve Walk o Run según la velocidad.
7. [ ] Con hambre o sed bajas, o con un muñeco de práctica que te ralentice, anda y compara el ritmo de las piernas con andar sin ralentizar.
   ✅ El ritmo de las piernas baja con la velocidad real, y los pies no patinan sobre el suelo.

#### 35.2 En el teléfono y con mando (elige un dispositivo en *Prueba → Dispositivo* antes del ▶)

1. [ ] En la Isla, corre con el botón «Correr» y mira las piernas, después para.
   ✅ Se lee igual que en PC: Run al correr, Walk al andar y parado sin ciclo, sin parpadeos.
2. [ ] Con un mando, corre con L3 y mira las piernas.
   ✅ Mismo resultado que en el teléfono y en PC.

#### 35.3 En el juego publicado (con los ids pegados)

1. [ ] Los cuatro ids (Walk, Run, RunArmed y Slide) ya están pegados en `src/shared/Data/PlayerAnimations.luau`. Publica el juego con Rojo sincronizado y mira la Salida al andar.
   ✅ No avisa de ninguna animación que no cargue (si alguna falla, suele ser un id de otro dueño).
2. [ ] Si cambias un ciclo en `PlayerAnimationBuilder`, vuelve a publicarlo y pega el id nuevo.
   ✅ El id nuevo queda como `rbxassetid://…` y el ciclo nuevo suena en el juego publicado.
3. [ ] En la Isla, el Lobby, Dunas y el Laboratorio publicados, anda, corre, corre armado y desliza.
   ✅ Suenan Walk, Run, RunArmed y Slide en los cuatro places, con el mismo ritmo y la misma pose que en Studio.

#### 35.4 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en la Isla o en Dunas) (= §32.6)

1. [ ] Uno anda y corre, y el otro lo mira desde su pantalla.
   ✅ El otro ve los ciclos propios de Walk y Run en ese personaje, al ritmo de la velocidad de su dueño, sin tirones.
2. [ ] Uno corre con un arma en la mano, y el otro lo mira.
   ✅ El otro ve RunArmed, con el brazo derecho sujetando el arma.

## 36. Lo que queda por probar de V7: detección PvP y cabeza (28-10-2026)

Solo está probado con el CI local (stylua, selene, `strings.py` y `rojo build`) y con la calculadora `Equilibrio` (sección 12): con un 30 % de aciertos a la cabeza, los duelos espejo de la arena bajan de 9,4 a 8,6 s (Cazador), de 9,8 a 9,0 s (Mago) y de 28,9 a 22,1 s (Médico), sin alertas nuevas. En el Laboratorio, con un 30 % de aciertos a la cabeza salen 2 alertas nuevas ("Laboratorio con cabezas"): Dardos 1,47 s a 15 studs y Rifle 1,23 s a 50 studs, bajo el mínimo de 1,5 s. Se dejan: son el mejor caso medio (el rifle sigue necesitando 2 aciertos, mínimo ~1 s) y se recalibran en V8 con el cargador y la dispersión. Nada de esto se ha probado en Play ni con dos jugadores. La dirección del disparo todavía no se valida contra la dispersión (eso es V8), así que no se prueba aquí. Empieza por 36.1.

#### 36.1 En Play, con un jugador, en Dunas y en el Laboratorio (haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [ ] En Dunas, dispara con el arco, el bastón y la cerbatana varias veces a un muñeco de práctica, y mira la Salida.
   ✅ Todos los disparos salen sin errores ni avisos en la consola, y el daño y los números son los de siempre.
2. [ ] En Dunas, dispara a un muñeco a unos 10 studs y mira de dónde sale cada proyectil. (ver §78 (bala inmediata))
   ✅ Sale de la punta del cañón o del Handle del arma, no de la cabeza ni de la cadera, y en menos de 0,12 s el proyectil se junta con su trayectoria real.
3. [ ] En el Laboratorio, en primera persona, dispara el rifle y el cañón de suero.
   ✅ El origen del disparo sale de la cámara (del centro de la mira), y el rifle y el cañón de suero siguen acertando donde apuntas.
4. [ ] Desde la consola del cliente, llama a `Remotes.UseWeapon:FireServer(dirección, punto, origen, hora)` con un origen a más de 5 studs de tu cabeza (por ejemplo, 20 studs hacia arriba) y dispara.
   ✅ El servidor no acepta el origen falso: el disparo sale de tu cabeza real y no aparece en el punto que mandaste. No hay error en la Salida.
5. [ ] En la Isla y en el Lobby, dispara el arma a distancia y pega con el arma cuerpo a cuerpo.
   ✅ Disparan y pegan igual que antes de V7, sin errores y sin números de «¡Cabeza!».

#### 36.2 En el Studio de Dunas o del Laboratorio, con 2 jugadores (*Test → Clientes y servidores*, con 2)

1. [⏭] A dispara de frente a la cabeza de B con un arma a distancia, sin moverse B. ⏭️ Superado por §80: cada arma tiene su multiplicador de cabeza.
   ✅ En la pantalla de A y en la de B sale «¡Cabeza!» con el número ×1,5 y estilo de crítico. El destello de los bordes de B (V5) es más fuerte que con un golpe normal del mismo daño.
2. [⏭] A dispara al cuerpo de B con el mismo arma, y después a la cabeza. ⏭️ Superado por §80: cada arma tiene su multiplicador de cabeza.
   ✅ El cuerpo hace el daño normal, sin «¡Cabeza!». La cabeza hace una vez y media ese daño.
3. [ ] A dispara a la cabeza de B con un golpe crítico seguro (pon el atributo `DebugAlwaysCrit` en `workspace`).
   ✅ El daño es ×1,5 y no ×2,025: no se multiplican el crítico y la cabeza. El número sale grande y con «¡Cabeza!».
4. [ ] En Dunas, A dispara con la cerbatana a la cabeza de B.
   ✅ Cuenta como cabeza (×1,5 y «¡Cabeza!») y además entra el veneno morado como siempre.
5. [⏭] En el Laboratorio, A dispara el rifle a la cabeza de B. ⏭️ Superado por §80: el rifle hace ×2 en la cabeza.
   ✅ Cuenta como cabeza (×1,5 y «¡Cabeza!»).
6. [⏭] En el Laboratorio, A dispara el cañón de suero a la cabeza de B. ⏭️ Superado por §80: el cañón de suero no tiene zonas.
   ✅ No sale «¡Cabeza!» ni hay ×1,5: el cañón de suero no tiene cabeza.
7. [⏭] Con un retraso simulado de 100–150 ms (*Network Settings*), B se mueve de lado mientras A le dispara. ⏭️ Superado por §80: rebobinado de pose (pasos 7–8).
   ✅ B recibe el disparo donde lo veía A en su pantalla, y no por detrás de una pared.
8. [⏭] Con el mismo retraso, A dispara desde detrás de una cobertura (una roca o un muro) a B, que está tras otra. ⏭️ Superado por §80: rebobinado de pose (pasos 7–8).
   ✅ El disparo no atraviesa la cobertura para dar en la cabeza de B.
9. [⏭] B bloquea o hace parry a un disparo de A dirigido a la cabeza, y después a un disparo al cuerpo. ⏭️ Superado por §80: bloqueo y zonas (pasos 4–5).
   ✅ El parry lo para igual en los dos casos, y el bloqueo reduce el daño en la misma proporción. Si el número de la cabeza no cuadra con eso, avísame.
10. [ ] En Dunas, A coge la bandera y B le dispara a la cabeza.
   ✅ El disparo a la cabeza cuenta igual con la bandera encima, y ni la captura ni la recogida cambian por V7.
11. [ ] Con un jugador en R15 escalado (más alto o más ancho), A dispara al pecho de B.
   ✅ La cápsula del cuerpo sigue a los pies y al cuello, y el disparo al pecho acierta igual que con la escala normal.

#### 36.3 Revisión visual (en Studio, con un jugador; en el teléfono, a 844 × 390 con *Prueba → Dispositivo*)

1. [ ] Por cada arma a distancia (arco, bastón, cerbatana, rifle, cañón de suero), mira de cerca la punta en *Explorer*. Busca el Attachment «Muzzle» o el Handle.
   ✅ El proyectil sale de la punta del cañón. Si el Handle está lejos del cañón, añade un Attachment llamado «Muzzle» en la punta del modelo del arma y repite la prueba.
2. [ ] En el teléfono, en Dunas, recibe un disparo a la cabeza mientras hay otros números de combate en pantalla.
   ✅ «¡Cabeza!» se lee sin solaparse con los números de daño, de curación ni con el HUD, y no tapa la barra de vida.
3. [ ] En PC, en Dunas, recibe dos golpes seguidos: uno al cuerpo y otro a la cabeza.
   ✅ Los dos números salen separados, y el de la cabeza lleva «¡Cabeza!» sin pisar al otro.
4. [ ] En el teléfono, mira el destello de los bordes tras un disparo a la cabeza.
   ✅ Se ve más fuerte que con un golpe normal, y no bloquea los botones de combate (como en 34.2).

## 37. Fase 15 V6: ajustes de arena y mira (28-10-2026)

Probado en Play, con un jugador, en el Laboratorio y en Dunas (28-10-2026): el ⚙️ queda a la izquierda del 😀 sin solaparse (hueco de 6 px); la ventana tiene la sección 🎯 Mira y ya no sale «Dónde salen tus números»; con la ventana abierta y el ratón libre en el Laboratorio, la mira se esconde; los 5 estilos, 5 colores, 3 tamaños y 3 grosores se dibujan sin errores; con `setSpread(20)` la mira se abre de 31 a 71 px; el inglés se lee bien; en Dunas la mira aparece con un arma a distancia en la mano y el icono del sistema se oculta. El perfil se restauró después. Lo que queda: el teléfono, el mando, el ratón real en Dunas y en el Laboratorio, el idioma con la ventana abierta, el desplazamiento de la ventana en PC y la mira dinámica con disparos reales, que llega con V8. Empieza por 37.1.

#### 37.1 En el emulador de teléfono (elige un dispositivo en *Prueba → Dispositivo* antes del ▶, a 844 × 390)

1. [ ] En el Laboratorio, mira la esquina de arriba a la derecha, bajo el marcador.
   ✅ El ⚙️ está a la izquierda del 😀, a unos 6 px, y ninguno de los dos pisa la línea de la fase ni los botones táctiles.
2. [ ] En Dunas, mira la misma esquina, bajo las banderas.
   ✅ Igual que en el Laboratorio: el ⚙️ queda a la izquierda del 😀 y no tapa el marcador ni la línea de la fase.
3. [ ] Abre el ⚙️ en el Laboratorio y deja la ventana de Ajustes a pantalla casi completa.
   ✅ La ventana ocupa casi todo el ancho y el alto. `ActionButtons` y `TouchGui` siguen visibles: el joystick y el salto pueden quedar por encima o por debajo de la ventana. Si alguno tapa una fila que hay que tocar, anótalo: se decide si se esconde como en el Lobby.
4. [ ] Con la ventana abierta, toca «Estilo» y prueba Círculo y después T. Cierra con la X.
   ✅ Cada toque llega a su fila. La X cierra la ventana y la mira vuelve al centro.
5. [ ] Con la ventana cerrada, en el Laboratorio, mira la mira del centro. Si al empezar sale abierta la ventana de selección de arma (LabLoadout, con 1 jugador en la espera), plégala primero: con ella abierta la mira no se ve.
   ✅ Está centrada y tiene la forma elegida. No sigue ningún toque, porque en el teléfono no hay ratón (`MouseEnabled` false).

#### 37.2 Con mando (en el Laboratorio y en Dunas)

1. [ ] Con un mando, selecciona el ⚙️ de la pantalla, ábrelo y muévete por sus filas hasta la X.
   ✅ Se llega a las filas y a la X con el mando. Si no, anótalo: es la navegación del mando, no la mira.
2. [ ] En el Laboratorio, con un mando, apunta con el arma.
   ✅ La mira está en el centro y se ve igual que en el teléfono.
3. [ ] En Dunas, equipa un arma a distancia y apunta con el mando.
   ✅ La mira sale en el centro y no se mueve con el mando.

#### 37.3 En PC con ratón real, en Dunas (un jugador, con un rol de arma a distancia, como el arquero o la honda)

1. [ ] Equipa el arco o la honda, entra en la partida y mueve el ratón por la pantalla.
   ✅ La mira sigue al cursor y el icono del sistema se oculta mientras el cursor está sobre el juego.
2. [ ] Pon el cursor sobre el ⚙️ y después sobre la ventana «Antes de la batalla».
   ✅ Vuelve el icono del sistema, y se pueden pulsar el ⚙️ y los botones de la ventana.
3. [ ] Con el cursor fuera de las ventanas, pulsa Ctrl para bloquear la cámara y mueve el ratón.
   ✅ La mira va al centro de la pantalla y se queda ahí mientras la cámara gira.
4. [ ] Guarda el arma a distancia o cambia a una de cuerpo a cuerpo.
   ✅ La mira desaparece y vuelve el icono del sistema.

#### 37.4 En PC con ratón real, en el Laboratorio (un jugador)

1. [ ] Con el ratón suelto, abre el ⚙️ y mantén Ctrl pulsado unos segundos.
   ✅ Ctrl no quita el ratón a la ventana de Ajustes: sigue pudiendo pulsar sus filas.
2. [ ] Cierra la ventana con la X.
   ✅ La mira vuelve a salir en el centro, como antes de abrir Ajustes.

#### 37.5 Idioma con la ventana abierta (en el Laboratorio o en Dunas, con un jugador)

1. [ ] Abre Ajustes con el idioma en Español y cámbialo a English sin cerrar la ventana.
   ✅ Los textos de la ventana y de la sección de la mira cambian al momento. La mira no se reinicia ni cambia de forma.
2. [ ] Lee la sección de la mira en inglés.
   ✅ Sale «🎯 Crosshair» con «Style», «Color», «Size» y «Thickness», y los nombres en inglés de las formas (Cross, Dot, Circle, Cross and dot, T), de los colores (White, Yellow, Cyan, Magenta, Light red), de los tamaños (Small, Normal, Large) y de los grosores (Thin, Normal, Thick).
3. [ ] Vuelve a Español.
   ✅ Todo vuelve en español, sin frases mezcladas.

#### 37.6 PC: la ventana de Ajustes de la arena (en Dunas y en el Laboratorio, con un jugador)

1. [ ] Abre el ⚙️ con la ventana a tamaño normal y baja con la rueda del ratón hasta el final.
   ✅ La ventana se desplaza en una sola columna, y al bajar se ve todo lo que queda, sin filas cortadas. Es la excepción a «sin desplazamiento»: confirma con el usuario si quiere columnas como en el Lobby antes de cambiarlo.

#### 37.7 Pendiente de V8 (disparos reales con la mira dinámica)

1. [⏭] En el Laboratorio, dispara el rifle o los dardos sin parar y mira la mira, con «Mira dinámica» en Sí y después en No. ⏭️ Superado por §38.1 pasos 5–7.
   ✅ Hoy no se abre ni tiene anillo de recarga: `setSpread` y `setCooldown` aún no los llama ningún arma. Este paso se prueba en V8.

## 38. Lo que queda por probar de V8: cargador, recarga, automático y mira dinámica (28-10-2026)

Probado en Play, con un jugador, en el Laboratorio (28-10-2026): el cargador y los atributos `LabAmmo` y `ReloadingUntil`; la recarga automática al vaciarse y la de `LabReload`; el relleno al reaparecer y al cambiar de arma; el contador «N / M»; el disparo automático con el clic mantenido (12 balas en 1,5 s, ritmo ≈0,125 s por bala). La tecla R no llegó a `ContextActionService` con el MCP, así que se prueba a mano. Solo están probados también el CI local (stylua, selene, `strings.py` y `rojo build`) y la calculadora `Equilibrio` (sección 12). Con cargador y dispersión siguen 2 alertas con cabezas (Dardos 1,47 s a 15 studs, Rifle 1,23 s a 50, mínimo 1,5 s), solo con un 30 % de aciertos a la cabeza y puntería perfecta: es decisión de diseño, no se han cambiado daños. Con el rifle en movimiento acierta un 30 % a 50 studs y un 5 % a 120. Empieza por 38.1.

#### 38.1 En PC, en el Laboratorio, con ratón y teclado (un jugador)

1. [ ] Con un arma con cargador en la mano y el cargador a medias, pulsa R.
   ✅ Empieza la recarga: sale la barra bajo la mira con «Recargando… N,N», se llena al acabar y no sale ningún error en la Salida.
2. [ ] Con el cargador lleno, pulsa R.
   ✅ No empieza ninguna recarga ni cambia el contador.
3. [⏭] Con el rifle, mantén el clic derecho para acercar la vista y dispara quieto y después corriendo. ⏭️ Superado por §81: el clic derecho es ahora apuntar (ADS).
   ✅ Con zoom no hay dispersión: la mira no se abre ni al correr y cada disparo sale al centro.
4. [ ] Con el rifle, corre sin parar y mira la mira. Después quédate quieto.
   ✅ La mira se abre al moverte y vuelve a cerrarse en un segundo más o menos al quedarte quieto.
5. [ ] Con los dardos, salta y dispara en el aire. Después, quieto en el suelo, dispara 5 dardos seguidos.
   ✅ En el aire la mira se abre más que en el suelo, y con cada dardo se abre un poco más hasta el tope de 3 disparos.
6. [ ] Pon «Mira dinámica» en No (Ajustes, ⚙️) y repite el paso 5.
   ✅ La mira no se abre ni cambia de tamaño con los disparos.
7. [ ] Con el arpón o el rifle, dispara y mira el anillo alrededor de la mira mientras espera el siguiente disparo. Repite con el ácido.
   ✅ El anillo se cierra desde las 12 en sentido horario y se llena cuando se puede disparar otra vez. Sale en las tres armas.
8. [ ] Pulsa el clic mientras el cargador está recargando, o con el cargador vacío y la recarga ya pedida.
   ✅ No se dispara y suena el clic de vacío (provisional, el sonido de «Pickup»). No sale error.
9. [ ] Abre una ventana (Ajustes o la de elegir arma) mientras llevas el arma con cargador.
   ✅ El contador de balas y la barra de recarga se esconden, y vuelven al cerrarla.
10. [ ] En la sala de espera, cambia de arma con cargador y mira el contador.
   ✅ El cargador sale lleno al cambiar de arma, también en la sala.
11. [ ] Desliza (Alt izquierdo o C) y dispara con el arma a distancia.
   ✅ Dispara con la dispersión de moverse (no con la de quieto) y el disparo no se queda sin salir.

#### 38.2 Con mando, en el Laboratorio (un jugador)

1. [ ] Pulsa X para recargar con el cargador a medias.
   ✅ Igual que R (38.1.1): empieza la recarga y sale la barra bajo la mira.
2. [ ] Con los dardos, mantén R2 pulsado.
   ✅ Dispara solo, al ritmo de los dardos, hasta vaciar el cargador, y después recarga sola.
3. [ ] Con el rifle, mantén R2 pulsado.
   ✅ Dispara un tiro por pulsación, sin automático.

#### 38.3 En el emulador de teléfono (844 × 390, con *Prueba → Dispositivo*)

1. [ ] Equipa un arma con cargador en el Laboratorio y mira el contador «N / M» con los botones de combate.
   ✅ El contador está arriba a la derecha, bajo el 😀, y no pisa el salto, los botones de acción ni la línea de la fase.
2. [ ] Toca «Recargar» con el cargador a medias.
   ✅ Empieza la recarga, sale la barra bajo la mira con los segundos, y el botón no tapa el salto ni los demás botones.
3. [ ] Con los dardos, mantén el dedo en la pantalla sobre el botón de disparo.
   ✅ Dispara solo mientras mantienes el toque, y vacía el cargador y recarga sola.
4. [ ] Con el arpón o el rifle, dispara con toques seguidos y mira el anillo.
   ✅ El anillo se ve bien en la pantalla pequeña y se cierra entre disparos.
5. [ ] Abre el ⚙️ y baja hasta «Controles del combate».
   ✅ Sale la fila «Recargar» con «R · X en el mando · «Recargar» en el móvil» y la nota de Laboratorio, sin tapar otras filas.

#### 38.4 Ajustes del Laboratorio y de Dunas (un jugador)

1. [ ] En Dunas, abre el ⚙️ y lee «Controles del combate».
   ✅ No sale la fila de recargar (Dunas no tiene cargador). El resto de filas está igual que antes.
2. [ ] En el Laboratorio, abre el ⚙️ y lee la misma sección.
   ✅ Sale la fila «Recargar» con su nota «solo en el Laboratorio, con un arma con cargador». Está entre «Pegar o disparar» y «Habilidades».
3. [ ] Cambia el idioma a English con la ventana abierta y lee la fila.
   ✅ Sale «Reload: R · X on the gamepad · “Reload” on mobile (Laboratory only, with a weapon that has a magazine)».

#### 38.5 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en el Laboratorio)

1. [⏭] A corre hacia B a 50 studs y dispara el rifle 20 veces seguidas, con B quieto. ⏭️ Superado por §81 y §85: apuntar (ADS) y el combate 1,5 veces más largo cambian los tiros.
   ✅ Acierta cerca del 30 % de los tiros, como predice `Equilibrio` (sección 12), y no el 100 %. Al vaciar el cargador, A recarga sola.
2. [ ] A dispara el rifle quieto a B a 50 studs, 5 tiros seguidos.
   ✅ Los 5 salen al punto (la dispersión quieta es 0 y el primer disparo es exacto).
3. [⏭] A dispara el rifle con zoom (clic derecho) mientras corre hacia B a 50 studs. ⏭️ Superado por §81: el zoom es ahora apuntar (ADS).
   ✅ Sale sin dispersión y acierta como con el arma quieta. Si en el servidor el tiro no se acepta por la dirección, avísame con el número de paso.
4. [⏭] A mantiene el zoom (clic derecho) mientras dispara dos tiros corriendo, y después suelta el zoom y dispara otros dos. ⏭️ Superado por §81: el zoom es ahora apuntar (ADS).
   ✅ Los dos tiros con zoom salen sin dispersión, y los dos sin zoom salen con la dispersión de correr. El servidor usa el `zoomed` que manda el cliente en cada tiro.
5. [ ] Con 150 ms de latencia en A (*Network Settings*), pulsa R y dispara justo cuando acaba la barra.
   ✅ Puede rechazarse un tiro, sin daño y sin error en la Salida. Al terminar, el contador y la barra de A coinciden con el servidor, sin balas de más.
6. [⏭] Mide el TTK del rifle y de los dardos de A a B a 15 y 50 studs (quieto y corriendo). ⏭️ Superado por §85: el combate dura 1,5 veces más.
   ✅ Los tiempos son del orden de lo que predice `Equilibrio` (sección 12). Si el TTK baja de 1,5 s solo con tiros al cuerpo, avísame: sería una alerta nueva.

## 39. Lo que queda por probar de V9: poses, fogonazo, retroceso y sonidos del Laboratorio (28-10-2026)

Probado en Play, con un jugador, en el Laboratorio (28-10-2026): `Config`, `Sounds` y `WeaponAnimations` cargan; el `Muzzle` existe en la vista; el fogonazo dura 0,16–0,28 s y no deja luces; el retroceso del rifle va de −3,77 a −3,23 y vuelve a −3,75 en 0,43 s; la recarga baja unos 0,47 studs, vuelve y rellena el cargador; sacar el arma sube 0,79 studs en 0,33 s; y no sale ningún error de V9 en la consola. Las tres poses nuevas se vieron en tira en el Studio de la Isla y se leen bien. Lo que no se ha probado: las poses dentro del Laboratorio (sus ids están vacíos hasta publicarlas), el fogonazo y la pose de otro jugador, el teléfono y los sonidos definitivos. Los sonidos son provisionales (ids de serie de Roblox; el rifle y el cañón comparten BOOM, y la recarga y el cargador vacío comparten CLICK). Empieza por 39.1.

#### 39.1 En el Studio de la Isla, con el dueño del juego (publicar las tres poses)

1. [⏭] Ejecuta `WeaponAnimationBuilder.build()` en modo edición (con un `require` limpio, no el de la caché). ⏭️ Superado por §86: las poses ya están publicadas. Después haz clic derecho sobre `ReplicatedStorage.WeaponAnimations.LabRifle`, `LabHarpoon` y `LabCannon` > *Save to Roblox*, con el dueño del juego. Pega los tres ids en `Data/WeaponAnimations` y guarda el place de la Isla.
   ✅ Salen tres ids `rbxassetid://…` (no vacíos) en `LabRifle`, `LabHarpoon` y `LabCannon`, y el place se guarda sin errores en la Salida.
2. [ ] Abre el Laboratorio con Play y un jugador. Aleja la cámara a tercera persona y dispara cada arma (dardos, rifle, arpón y cañón) contra un muro.
   ✅ Cada arma tiene su pose: el rifle, con la culata al hombro y la cabeza ladeada, y un respingo al disparar; el arpón, al costado con una mano delante, y el torso que se echa atrás al disparar; el cañón, a la cadera, y el cuerpo que se echa atrás. Los dardos siguen con su pose `Dart`.

#### 39.2 En el Laboratorio, con ratón y teclado (un jugador)

1. [ ] Dispara un tiro con cada arma, en el orden dardos, rifle, arpón y cañón.
   ✅ El retroceso cambia con el arma: casi nulo con los dardos, y más fuerte con el rifle, el arpón y el cañón, cada uno con su giro. El giro de la boca alterna de lado en cada disparo.
2. [ ] Con el rifle, mantén el clic derecho para acercarlo y dispara quieto. Después camina y dispara otra vez.
   ✅ Con el rifle acercado, el golpe de cámara es la mitad que sin zoom, y el arma no se balancea al andar.
3. [ ] Con el cargador a medias, pulsa R con el rifle y después con el lanzarredes.
   ✅ El arma baja, se inclina con la boca arriba y hace un vaivén. Hacia la mitad el cargador entra con un golpe corto. Después vuelve a su sitio, el contador llega al lleno y suena el clic de cargador listo.
4. [ ] Con el cargador lleno, pulsa R.
   ✅ No empieza ninguna recarga y el arma no se mueve.
5. [ ] Cambia del rifle al cañón y de ahí a los dardos.
   ✅ Al sacar cada arma (0,35 s) sube desde abajo con un giro, y suena el sonido de sacar.
6. [ ] Pon el ajuste de temblor de cámara a 0 en Ajustes, cierra y dispara el rifle.
   ✅ La cámara no sube con el disparo, pero el arma sigue retrocediendo.
7. [ ] Dispara el arpón contra una pared cercana, de frente y de lado.
   ✅ El disco de red del impacto queda pegado a la pared y no se ve de canto ni tapa el impacto. Si queda feo, avisa con el número de paso.
8. [ ] Mira la Salida mientras haces los pasos anteriores.
   ✅ No sale ningún error de V9. Si sale «ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type» (3 veces), no es de V9: anota qué objeto lo pide para buscarlo aparte.

#### 39.3 Sonidos del Laboratorio (un jugador)

1. [ ] Dispara cada arma con la vista quieta, uno después de otro.
   ✅ Cada arma suena distinta: los dardos, un «pfft» agudo; el rifle, un disparo seco con graves; el arpón, un golpe con cuerda; el cañón, un bloop grave. El rifle y el cañón suenan parecidos (comparten BOOM). Anota qué sonidos cambiar por audios del Creator Store.
2. [ ] Pulsa R con el cargador a medias, espera a que acabe la recarga y después pulsa el clic con el cargador vacío.
   ✅ Suenan el clic de recarga, el de cargador listo y el de vacío. Los tres comparten CLICK y se oyen parecidos: anota cuáles cambiar.

#### 39.4 Con 2 jugadores (*Test → Clientes y servidores*, en el Laboratorio)

1. [⏭] B se queda quieto a 20 studs de A y mira a A, mientras A dispara cada arma (dardos, rifle, arpón y cañón). ⏭️ Superado por §53.2, §75 y §78: misma prueba.
   ✅ B ve el fogonazo en la boca del arma de A: cian con los dardos, amarillo con humo con el rifle, bocanada beige con el arpón y goterón morado con el cañón. B también ve la pose de disparo del arma de A (39.1.2).
2. [⏭] Con B quieto, A dispara el rifle y después el cañón a 50 studs y luego a 120 studs. ⏭️ Superado por §53.2, §75 y §78: misma prueba.
   ✅ B oye cada disparo con el sonido de su arma. El rifle se oye hasta unos 160 studs y el cañón hasta unos 120; más allá no se oye.

#### 39.5 En el emulador de teléfono (844 × 390, con *Prueba → Dispositivo*)

1. [ ] Equipa un arma del Laboratorio y dispara con toques seguidos.
   ✅ Se ve el retroceso y el arma no tapa el disparo, el salto ni los demás botones de combate.
2. [ ] Toca «Recargar» con el cargador a medias.
   ✅ La vista baja, hace el vaivén y el cargador entra con su golpe. Ningún botón queda tapado por el arma.
3. [ ] Cambia de arma con el selector de armas del Laboratorio y mira la animación de sacar.
   ✅ El arma sube desde abajo en 0,35 s y no tapa los botones.

## 40. Lo que queda por probar de V10: espectador y killcam (28-10-2026)

Probado en Play, con un jugador, en Dunas y en el Laboratorio (equipos, Todos contra todos y Rondas en parte): entra el espectador, aparece la vista cenital, se restaura la cámara y se borran `KilledBy` y `KilledWith` al reaparecer. La killcam necesita un asesino, así que no se ha podido probar con un solo jugador. Todo lo que sigue va con 2 o más jugadores o en el emulador de teléfono. Empieza por 40.1.

#### 40.1 En Dunas, con 2 jugadores (A y B, sin aliados salvo donde se indica)

1. [ ] B mata a A con un arma a distancia y A queda derribado.
   ✅ Sale la ficha 1,5 s abajo al centro con «Te derribó B» y «con {arma}», la barra roja de vida de B con «{hp} PV». La cámara de A mira a B.
2. [ ] Con 3 jugadores (A, un aliado C y el asesino B), B mata a A y C sigue en pie. Espera a que acabe la ficha.
   ✅ Sale la barra ◀ ▶ con «Viendo a {nombre}» sobre C, y la cámara sigue a C.
3. [ ] Con 4 jugadores (A, dos aliados C y D, y el asesino B), B mata a A y C y D siguen en pie.
   ✅ ◀ y ▶ cambian de aliado (C, D, C…) y el texto «Viendo a {nombre}» cambia con ellos.
4. [ ] Con 2 jugadores (A y B), B mata a A cuando A no tiene aliados.
   ✅ La cámara pasa a la vista cenital (0, 190, 0) sobre el centro de la arena, y no sale ninguna barra ◀ ▶.
5. [ ] A reaparece.
   ✅ La cámara vuelve a la normal y desaparecen la ficha, la barra y la vista cenital.
6. [ ] B mata a A con veneno o con daño de área, con el arma de A guardada.
   ✅ Sale la ficha «Te derribó B» sin la línea «con {arma}».
7. [ ] B mata a A y B muere antes de 1,5 s (hace falta un tercer jugador que lo mate, o que caiga al vacío).
   ✅ La cámara de A sigue el cuerpo de B hasta cumplirse 1,5 s, y después pasa a la ficha.

#### 40.2 En el Laboratorio, con 2 o 3 jugadores

1. [ ] Duelo por equipos: B derriba a A y A tiene un compañero C en pie.
   ✅ Sale la killcam con la cámara en B, y después la barra ◀ ▶ sobre C como en 40.1.2.
2. [ ] Todos contra todos (3 jugadores): B derriba a A. Al acabar la killcam, pulsa ◀ ▶.
   ✅ Puedes seguir a cualquier jugador vivo (no solo a aliados) con ◀ ▶.
3. [ ] Caída al vacío con crédito: B empuja a A al vacío.
   ✅ La killcam muestra a B, quien te tiró, y no la vista cenital.
4. [ ] Caída al vacío sin crédito: A cae solo, sin que nadie le haya empujado hace poco (por ejemplo, saltando del borde).
   ✅ No hay killcam: pasa directo a la cámara cenital o a la de aliados.
5. [ ] Rondas con un compañero C en pie: A muere en la ronda.
   ✅ La killcam dura los primeros 1,5 s de LabOut y después pasa a C.
6. [ ] Rondas: acaba la ronda y empieza la pausa mientras miras a C.
   ✅ El espectador se cierra al empezar la pausa y vuelve la cámara normal.
7. [ ] Rondas: pon la vista cenital (sin aliados en pie) y mira el techo del mapa. Sal del espectador.
   ✅ El techo queda oculto en la vista cenital y vuelve al salir.

#### 40.3 En PC, en el Laboratorio, con el selector de armas abierto (2 jugadores)

1. [ ] Con el selector LabLoadout abierto (arriba), B derriba a A y sale la killcam.
   ✅ La ficha (abajo al centro, 300 × 88, a 44 px del borde) no se solapa con el selector. «Reapareces en» se lee bien.
2. [ ] Durante la killcam, pulsa ◀ ▶ con el ratón.
   ✅ Los botones son de 48 px y responden al clic. El ratón está suelto mientras dura la killcam.
3. [ ] Durante la killcam, pulsa Ctrl.
   ✅ Ctrl vuelve a apuntar con el ratón, como en el resto de la partida.

#### 40.4 En el emulador de teléfono (844 × 390, con *Prueba → Dispositivo*) y con mando

1. [ ] En el Laboratorio, con el selector LabLoadout abierto (arriba), mira la killcam de 40.3.1.
   ✅ La ficha no se solapa con el selector en pantalla baja. «Reapareces en» sigue legible.
2. [ ] Toca ◀ y ▶ en la killcam de Dunas (con 3 o 4 jugadores) y después en el Laboratorio (con 3 jugadores).
   ✅ Los botones de 48 px responden al toque y cambian de jugador sin errores en la Salida.
3. [ ] Con el joystick táctil de movimiento visible, mira si ◀ ▶ lo tapa.
   ✅ El botón no tapa el joystick, en Dunas ni en el Laboratorio.
4. [ ] Con mando conectado, mira la killcam en Dunas (2 jugadores).
   ✅ La ficha y la barra ◀ ▶ se ven bien en la pantalla y no tapan nada importante.

#### 40.5 Idioma (2 jugadores, en Dunas)

1. [ ] Cambia el idioma a English y repite el derribo de 40.1.1 con un arma a distancia.
   ✅ Salen «Knocked out by {name}», «with {weapon}» y «{hp} HP», con el nombre y el arma en su sitio. No sale ninguna frase en español.

## 41. Lo que queda por probar de R2: medición en vivo del rendimiento (28-10-2026)

Probado solo en la Isla, en Studio. Las cifras de FPS de Studio no valen: salió 15 porque la ventana no tenía el foco, y la memoria del cliente coincidió con la del servidor. Todo lo que sigue va con 2 jugadores, en un móvil real o en los places publicados. Empieza por 41.1.

#### 41.1 En el Studio de la Isla, con 2 jugadores (*Test → Clientes y servidores*)

1. [ ] Con B sin permisos de admin, mira si B ve la pestaña «📈 Rendimiento» del panel y si recibe cifras del remoto AdminPerf.
   ✅ B no ve la pestaña y no recibe cifras. Si el servidor recibe una suscripción de B, la rechaza sin errores en la Salida.
2. [ ] Con A y B admins, los dos abren la pestaña «📈 Rendimiento» a la vez.
   ✅ Los dos reciben cifras cada 5 s, y ambas pestañas se actualizan sin errores en la Salida.
3. [ ] Con A y B admins y la pestaña abierta en los dos, A sale de la partida (cierra su cliente de Studio o detén su prueba).
   ✅ B sigue recibiendo cifras cada 5 s. El servidor no da errores al perder a A: si intenta enviarle datos después de salir, falla PlayerRemoving al limpiar el suscriptor.

#### 41.2 Con la ventana de Studio en primer plano o en un móvil real

1. [ ] Con la ventana de Studio en primer plano (el cliente tiene el foco), abre la pestaña «📈 Rendimiento» y deja correr un minuto. Si puedes, repite en un móvil real dentro de la Isla.
   ✅ El FPS del cliente es el de la pantalla y no sale 15 por falta de foco. La memoria del cliente y la del servidor son cifras distintas. Los draw calls y los triángulos muestran cifras reales.

#### 41.3 En el emulador de teléfono (844 × 390, con *Prueba → Dispositivo*)

1. [ ] Abre el panel de administración y mira sus 6 botones de pestaña.
   ✅ Los 6 se leen (el texto se ajusta solo con TextScaled) y ninguno queda fuera de la pantalla.
2. [ ] Toca cada una de las 6 pestañas y vuelve a «📈 Rendimiento».
   ✅ Cada pestaña abre sin errores en la Salida. La medición solo corre mientras «Rendimiento» está abierta.

#### 41.4 En los places publicados (Lobby, Dunas, Laboratorio e Isla)

1. [ ] Con admin, abre la pestaña «Rendimiento» en el Lobby, en Dunas y en el Laboratorio.
   ✅ Sale la pestaña con cifras en los tres places, y en el móvil los 6 botones se leen.
2. [ ] Con el juego publicado, la Isla llena (unas 36.000 piezas) y la pestaña «Rendimiento» abierta, camina y combate mientras corre el conteo cada 5 s.
   ✅ No se notan tirones en el móvil ni en PC cada vez que se cuenta, y la Salida no muestra avisos de Performance.

## 42. Lo que queda por probar de R3: fusión de lo estático (28-10-2026)

Hecho en Studio: calculadora `Rendimiento` sin alertas, soldaduras y volumen iguales con y sin fusión en 38 armas y aspectos, 6 armaduras y trajes, 33 construibles y estructuras de parcela, las armas del Laboratorio y las imágenes de `RewardModels`. Falta lo que pide Play, ver el aspecto o más de un jugador.

#### 42.1 En Play en la Isla (haz copia de tu perfil en `PlayerData_v1_backups` antes)

1. [ ] Equipa una arma de la forja de nivel 4 y un aspecto de arma, golpea a un mono y cambia de aspecto en el Armario con el arma en la mano.
   ✅ El arma se ve igual que antes de R3, el golpe funciona y al cambiar de aspecto se rehace sin piezas sueltas.
2. [ ] Ponte una armadura de rango IV y un traje mítico, y míralos de frente y por detrás.
   ✅ Se ven igual que antes (sin huecos ni piezas desplazadas) y siguen al personaje al correr y saltar.
3. [ ] Construye una baliza, un nido, una hoguera y un tótem de guerra, y en la parcela una incubadora con huevos.
   ✅ La baliza enciende su luz roja, la incubadora pinta cada huevo con su rareza y el nido se puede usar.

#### 42.2 En Play en el Laboratorio

1. [ ] Equipa un arma con skin de bajas y mírala en primera persona y desde fuera.
   ✅ Se ve igual que antes; en primera persona no tapa la mira.

#### 42.3 En el Lobby y el pase

1. [ ] Abre el pase, las tiendas de cosméticos y la decoración del nido, y mira las imágenes de Ámbar, tiempo de huevo, provisiones, estilos de números y de estallidos.
   ✅ Las imágenes se ven completas, sin cortes ni piezas que falten.

#### 42.4 Con el juego publicado

1. [ ] Con admin, compara la pestaña «Rendimiento» de la Isla antes y después de construir varios edificios.
   ✅ Las piezas de estructuras suben menos que antes de R3 por edificio.

## 43. Lo que queda por probar de R5: LOD de detalle (28-10-2026)

Hecho en Studio con la calculadora `Rendimiento` (sección 8: Lobby con 20 jugadores, con y sin LOD). El LOD quita las piezas pequeñas (etiqueta Detalle, lado mayor menor de 0,35) de los personajes de los demás a más de 65 studs, y las devuelve a menos de 55. Falta lo que pide Play con varios jugadores, el teléfono y el juego publicado. Empieza por 43.1.

#### 43.1 En el Studio de la Isla, en modo edición (calculadora)

1. [ ] Ejecuta `Rendimiento` (`local m = game.ServerStorage.Tools.Rendimiento:Clone()`, `print(require(m).informe()); m:Destroy()`) y lee la sección 8.
   ✅ Lobby con 20 jugadores: cosméticos de 21.500 piezas sin LOD a 17.168 con LOD (ahorro del 20 %). La sección "Alertas" no tiene ninguna. Mascotas y monturas no se fusionan y no llevan piezas Detalle, así que sus cifras no cambian.

#### 43.2 Un jugador (▶ Jugar, en el Lobby o la Isla; haz antes una copia del perfil en `PlayerData_v1_backups`)

1. [ ] Equipa una armadura o traje y un arma. Mira tu personaje de cerca y aleja la cámara todo lo que puedas.
   ✅ Tu personaje conserva todas sus piezas pequeñas a cualquier distancia. Nada desaparece en tu propia pantalla.

#### 43.3 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Lobby o la Isla)

1. [ ] A lleva armadura o traje y arma equipados. B se queda a menos de 55 studs de A y mira su aspecto. Después B se aleja a más de 65 studs.
   ✅ Las piezas pequeñas de A (Detalle) desaparecen en la pantalla de B y el resto de su aspecto sigue igual.
2. [ ] B se mueve despacio entre 55 y 65 studs de A, de ida y vuelta durante unos 20 s.
   ✅ Sin parpadeo: las piezas no aparecen ni desaparecen al cruzar esa franja.
3. [ ] B vuelve a acercarse a menos de 55 studs de A.
   ✅ Las piezas pequeñas de A reaparecen.
4. [ ] B se queda a más de 65 studs. A cambia de arma y después de traje, sin acercarse a B.
   ✅ Las piezas nuevas respetan el estado: en la pantalla de B no aparecen piezas Detalle. Al acercarse B, sí aparecen.
5. [ ] B se queda a menos de 55 studs de A. A muere y reaparece.
   ✅ Tras la reaparición no queda ninguna pieza invisible de A: se ve el aspecto completo.
6. [ ] Si A tiene mascota o montura, B se aleja a más de 65 studs de A.
   ✅ La mascota y la montura de A se ven igual a cualquier distancia: no pierden piezas.

#### 43.4 En el teléfono, con el juego publicado (20 jugadores en el Lobby)

1. [ ] Entra en el Lobby publicado en el teléfono con 20 jugadores dentro, y camina entre ellos.
   ✅ No hay tirones al entrar los jugadores. El objetivo es 30 FPS estables en un móvil de gama baja.

## 44. Lo que queda por probar de R6: efectos de los jefes (28-10-2026)

Hecho en Studio: la calculadora `Rendimiento` (sección 9: pico de cada jefe en las tres calidades, sin alertas) y una prueba en Play en la Isla con el Orangután: llegan su pisotón real y 3 bombas de LavaBomb, con pico 36 en Medio, sin errores en la consola. El aspecto de las firmas solo se vio en el pisotón del Gorila Albino, porque las capturas caen en la fase de aviso y el jugador tapa el efecto. Falta lo que sigue. Empieza por 44.1.

#### 44.1 En el Studio de la Isla, con un jugador (▶ Jugar; haz antes una copia del perfil en `PlayerData_v1_backups`)

1. [ ] Abre los ajustes, busca «Efectos de los jefes» y mira la fila en PC y en el móvil. Prueba Auto, Bajo, Medio y Alto.
   ✅ La fila sale sin obligar a desplazarse, ni en PC ni en móvil. Cada opción se marca al elegirla.
2. [ ] Abre los ajustes en el Lobby.
   ✅ La fila nueva entra en las columnas del Lobby sin obligar a desplazarse.
3. [ ] Pelea contra el Orangután: su pisotón de barro y su agarre con lianas, en Bajo, Medio y Alto.
   ✅ Se dibujan los dos efectos en las tres calidades, con el mismo radio y la misma duración de daño.
4. [ ] Pelea contra el Chimpancé: lluvia de rocas grises y polvo, y embestida con estela, en las tres calidades.
   ✅ Las rocas caen donde cae el daño, y la estela se ve en las tres calidades.
5. [ ] Pelea contra el Gorila Albino: pisotón cian con esquirlas, rugido que apaga las luces con una ola oscura, y embestida, en las tres calidades.
   ✅ El rugido apaga las luces y su ola oscura se ve en las tres calidades. Las esquirlas del pisotón salen en cada una.
6. [ ] Pelea contra el Gorila de Ceniza: lluvia de bombas de lava con charco, pisotón con grietas de lava y brasas, y embestida con brasas, en las tres calidades.
   ✅ Las bombas caen con su charco en el sitio del daño, y las grietas y las brasas se ven en las tres calidades.
7. [ ] En Bajo, mira el disco rojo de peligro de los cuatro jefes.
   ✅ El disco se sigue viendo con su radio y su duración reales. La calidad Baja quita efectos, no el aviso.
8. [ ] Haz seguidas las cuatro peleas, en Medio, y compara sus efectos.
   ✅ Se distinguen a primera vista por su efecto de pisotón y de ataque.
9. [ ] Con el Gorila de Ceniza, espera la erupción del volcán y mira la pestaña «Rendimiento» del panel de administración.
   ✅ Los picos de dibujo no pasan de `Config.Budgets.Vfx` y la pestaña no marca ninguna alerta.

#### 44.2 En el teléfono, con los places publicados (gama baja)

1. [ ] Entra en el asedio final con jefe en el juego publicado, con la opción «Efectos de los jefes» en Auto.
   ✅ En Auto sale Bajo y el juego se mantiene a 30 FPS estables durante el asedio.
2. [ ] Esquiva el área de peligro del jefe, y después quédate dentro de ella.
   ✅ Fuera del disco no recibes daño. Dentro, el daño llega en el mismo momento y en el mismo sitio que el efecto dibujado.

#### 44.3 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en la Isla)

1. [ ] A y B se quedan cerca del jefe, y mira la lluvia de rocas y las bombas de lava.
   ✅ Los dos ven las rocas y las bombas en el mismo sitio y a la vez que el daño.
2. [ ] B se aleja a más de 250 studs del jefe mientras A pelea con él.
   ✅ B no dibuja las rocas ni las bombas de ese ataque. No hay errores en la Salida.

## 45. Lo que queda por probar de W1: Lanzadardos y Avispa (28-10-2026)

Hecho en Studio: las 8 versiones (base y Avispa I/II/III, de los dos bandos) se vieron en el Laboratorio, con las superficies que se pisaban corregidas. Piezas tras fusionar contadas en la vista previa: Guardianes 38 · 60 · 91 · 148 y Piratas 45 · 67 · 98 · 155 (topes 45 y 200). Falta lo que pide Play, la calculadora con módulos limpios o ver el arma en movimiento.

#### 45.1 Calculadora (Studio de la Isla, modo edición, tras reabrir el place para vaciar la caché de `require`)

1. [ ] Ejecuta `Rendimiento` y mira la sección 6 y las Alertas.
   ✅ El Lanzadardos de los dos bandos queda en 45 piezas o menos como base y en 200 o menos con cada grado de la Avispa, y las Alertas dicen «Todo dentro de los límites».

#### 45.2 En Play en el Laboratorio (haz copia de tu perfil en `PlayerData_v1_backups` antes)

1. [ ] Elige el Lanzadardos en cada bando y míralo en primera persona, disparando y recargando.
   ✅ El tambor, el cargador y la funda se ven bien, no tapan la mira y no hay piezas sueltas.
2. [ ] Con el comando de depuración `SkinKills`, equipa la Avispa I, II y III y cambia de una a otra con el arma en la mano.
   ✅ Cada grado se distingue del anterior a primera vista, el cambio rehace el arma sin piezas sueltas y la Salida no da errores.
3. [ ] Con la Avispa III en la mano, mueve la cámara y gira alrededor del arma en tercera persona.
   ✅ Ninguna superficie parpadea ni se pisa con otra, y por detrás se ven las alas grandes con sus partículas.
4. [ ] En primera persona, con la Avispa III, mira el lado derecho y la parte de arriba del arma.
   ✅ Se ven las alas abiertas, la jaula de panal y el aguijón. Las alas grandes de la espalda no aparecen.

#### 45.3 En el Lobby y el Armario

1. [ ] Abre el Armario, la pestaña del Laboratorio, y el selector de arma del Laboratorio.
   ✅ Las imágenes del Lanzadardos y de las skins se ven completas, sin cortes ni piezas que falten.

#### 45.4 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio)

1. [ ] A equipa la Avispa III y B la mira de lejos y de cerca.
   ✅ B ve el arma entera, y de lejos desaparecen solo las piezas pequeñas sin que cambie la silueta.

## 46. Lo que queda por probar de W2: Rifle de bananas y Escorpión (28-10-2026)

Hecho en Studio: las 8 versiones (base y Escorpión I/II/III, de los dos bandos) se vieron en el Laboratorio, también por detrás, desde arriba y con la cola de `LabBack` quitada para simular la primera persona. `Rendimiento` (filtro "Lab", con el módulo clonado) dio 0 alertas. Piezas tras fusionar: Guardianes 38 · 71 · 112 · 136 y Piratas 45 · 78 · 119 · 143 (topes 45 y 200). Falta lo que pide Play, la calculadora con módulos limpios o ver el arma en movimiento.

#### 46.1 Calculadora (Studio de la Isla, modo edición, tras reabrir el place para vaciar la caché de `require`)

1. [ ] Ejecuta `Rendimiento` y mira la sección 6 y las Alertas.
   ✅ El Rifle de los dos bandos queda en 45 piezas o menos como base y en 200 o menos con cada grado del Escorpión, y las Alertas dicen «Todo dentro de los límites».

#### 46.2 En Play en el Laboratorio (haz copia de tu perfil en `PlayerData_v1_backups` antes)

1. [ ] Elige el Rifle en cada bando y míralo en primera persona, disparando y recargando.
   ✅ La mira, el cargador de banana y el bípode se ven bien, no tapan el punto de mira y no hay piezas sueltas.
2. [ ] Con el comando de depuración `SkinKills`, equipa el Escorpión I, II y III y cambia de uno a otro con el arma en la mano.
   ✅ Cada grado se distingue del anterior a primera vista, el cambio rehace el arma sin piezas sueltas y la Salida no da errores.
3. [ ] Con el Escorpión III en la mano, mueve la cámara y gira alrededor del arma en tercera persona.
   ✅ Ninguna superficie parpadea ni se pisa con otra, y por detrás se ve la cola arqueada con el aguijón y su goteo.
4. [ ] En primera persona, con el Escorpión III, mira el lado derecho y la parte de arriba del arma.
   ✅ Se ven el caparazón, las púas, los sacos de veneno y las pinzas. La cola no aparece.

#### 46.3 En el Lobby y el Armario

1. [ ] Abre el Armario, la pestaña del Laboratorio, y el selector de arma del Laboratorio.
   ✅ Las imágenes del Rifle y de las skins se ven completas, sin cortes ni piezas que falten.

#### 46.4 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio)

1. [ ] A equipa el Escorpión III y B lo mira de lejos y de cerca.
   ✅ B ve el arma entera con la cola, y de lejos desaparecen solo las piezas pequeñas sin que cambie la silueta.

## 47. Lo que queda por probar de W3: Lanzarredes y Kraken (28-10-2026)

#### 47.1 Medir (Studio de la Isla, tras reabrir el place por la caché de `require`)

1. [ ] Ejecuta `Rendimiento` y mira la sección 6, "Armas del Laboratorio" (filtro `"Lab"`).
   ✅ El Lanzarredes de cada bando tiene 45 piezas o menos, cada skin Kraken 200 o menos y no hay alertas.

#### 47.2 En Play en el Laboratorio (haz copia de tu perfil en `PlayerData_v1_backups` antes)

1. [ ] Elige el Lanzarredes en cada bando y míralo en primera persona, disparando y recargando.
   ✅ El fardo de red y la boca cuadrada se ven bien, no tapan el punto de mira y no hay piezas sueltas.
2. [ ] Con el comando de depuración `SkinKills`, equipa el Kraken I, II y III y cambia de uno a otro con el arma en la mano.
   ✅ Cada grado se distingue del anterior a primera vista, el cambio rehace el arma sin piezas sueltas y la Salida no da errores.
3. [ ] Con el Kraken III, mueve la cámara y gira alrededor del arma en tercera persona.
   ✅ Ninguna superficie parpadea y por detrás se ven los ojos grandes, las burbujas y el tentáculo largo.
4. [ ] En primera persona, con el Kraken III, mira el lado derecho y la parte de arriba del arma.
   ✅ Se ven los tentáculos con ventosas que brillan, el manto y los ojos. Lo de la espalda no aparece.

#### 47.3 En el Lobby y el Armario

1. [ ] Abre el Armario, la pestaña del Laboratorio, y el selector de arma del Laboratorio.
   ✅ Las imágenes del Lanzarredes y de las skins Kraken se ven completas, sin cortes ni piezas que falten.

#### 47.4 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio)

1. [ ] A equipa el Kraken III y B lo mira de lejos y de cerca.
   ✅ B ve el arma entera con los tentáculos de atrás, y de lejos desaparecen solo las piezas pequeñas sin que cambie la silueta.

## 48. Lo que queda por probar de W4: Cañón de suero y Dragón (28-10-2026)

#### 48.1 Medir (Studio de la Isla, tras reabrir el place por la caché de `require`)

1. [ ] Ejecuta `Rendimiento` y mira la sección 6, "Armas del Laboratorio" (filtro `"Lab"`).
   ✅ El Cañón de cada bando tiene 45 piezas o menos, cada skin Dragón 200 o menos y no hay alertas.

#### 48.2 En Play en el Laboratorio (haz copia de tu perfil en `PlayerData_v1_backups` antes)

1. [ ] Elige el Cañón de suero en cada bando y míralo en primera persona, disparando y recargando.
   ✅ El depósito morado y la campana se ven bien, no tapan el punto de mira y no hay piezas sueltas.
2. [ ] Con el comando de depuración `SkinKills`, equipa el Dragón I, II y III y cambia de uno a otro con el arma en la mano.
   ✅ Cada grado se distingue del anterior a primera vista, el cambio rehace el arma sin piezas sueltas y la Salida no da errores.
3. [ ] Con el Dragón III, gira alrededor del arma en tercera persona.
   ✅ Ninguna superficie parpadea y por detrás se ve la cola larga.
4. [ ] En primera persona, con el Dragón III, mira el lado derecho y la parte de arriba del arma.
   ✅ Se ven las alas abiertas, los cuernos y las brasas y el humo por la boca. La cola no aparece.

#### 48.3 En el Lobby y el Armario

1. [ ] Abre el Armario, la pestaña del Laboratorio, y el selector de arma del Laboratorio.
   ✅ Las imágenes del Cañón y de las skins Dragón se ven completas, sin cortes ni piezas que falten.

#### 48.4 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio)

1. [ ] A equipa el Dragón III y B lo mira de lejos y de cerca.
   ✅ B ve el arma entera con la cola, y de lejos desaparecen solo las piezas pequeñas sin que cambie la silueta.

## 49. Lo que queda por probar de A1: menús en combate y golpe del gigante (29-10-2026)

#### 49.1 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en la Isla)

1. [ ] A se convierte en el gigante desde el panel de admin (Eventos → Gigante) y B se queda de pie en campo abierto. A golpea a B con su arma cuerpo a cuerpo desde varios lados.
   ✅ Los espadazos de A le dan a B (ya no pasan por encima de su cabeza) y B pierde vida.
2. [ ] B golpea a A (el gigante) con un arma cuerpo a cuerpo.
   ✅ Sigue dándole, igual que antes.

#### 49.2 Con la parcela y los cofres (Isla, un jugador)

1. [ ] Junto a un cofre de la parcela y junto al cartel de la parcela, recibe un golpe de un mono e intenta abrirlos en los 4 s siguientes.
   ✅ No se abren. Pasados los 4 s sin combate, sí.

#### 49.3 Textos

1. [ ] Abre el Diario del naturalista y el contrato Campamento del náufrago.
   ✅ Dicen «Recolecten…» y «Levanten…» (sin «Recolectad» ni «Levantad»), y con el juego en inglés siguen traducidos. Hay que subir `build/localization_nuevas.csv` a Creator Hub.

## 50. Fase 18 A2: panel de admin (29-10-2026)

#### 50.1 Con el juego publicado y 2 servidores (admin en uno, otro jugador en otro)

1. [ ] Como admin, pulsa 👑 Jefe con «Todos».
   ✅ En tu servidor sale junto a ti y en todos los servidores llega el aviso «👑 ¡X ha aparecido en la Isla, servidor Y!». En los demás servidores de la Isla sale en su guarida.
2. [ ] Programa un mantenimiento en 5 min con «Todos» y mira la pestaña Servidor desde el otro servidor. Después intenta programar otro.
   ✅ Aparece la fila con quién lo programó y cuánto falta. El segundo intento se rechaza.
3. [ ] Cancela el mantenimiento desde la pestaña Servidor.
   ✅ Todos los servidores reciben «Mantenimiento cancelado» y nadie es expulsado al llegar la hora.

#### 50.2 Dos jugadores (2 clientes, uno admin y otro no admin)

1. [ ] Programa un mantenimiento de 1 min con «Todos» y deja que empiece. Con el mantenimiento en marcha, cancélalo desde la pestaña Servidor.
   ✅ El no admin sale con el mensaje y el admin sigue dentro. Tras cancelar, el no admin puede volver a entrar.

#### 50.3 Interfaz (clic real en el panel de PC y de teléfono)

1. [ ] En la pestaña Eventos, mira en «Ahora en el juego» el botón de lo que está en marcha (👑 Jefe, lluvia, tormenta, erupción o gigante) y apágalo con otro toque. Repite con «Todos».
   ✅ El botón en marcha se ve azul con texto blanco y vuelve al dorado al apagarlo con otro toque. Con «Todos» pide el segundo toque.
2. [ ] En la pestaña Servidor, mira la fila del mantenimiento programado y pulsa ✖ Cancelar.
   ✅ La fila cabe sin desplazar la ventana y el botón ✖ Cancelar se lee.

## 51. Fase 18 A3: gigante en los 4 places (29-10-2026)

#### 51.1 Un jugador (admin) en cada place publicado

1. [ ] En el Lobby, en Dunas y en el Laboratorio, abre el panel, pestaña Eventos, y pulsa «👹 Ser gigante» con «Este servidor». Pulsa otra vez para deshacerlo.
   ✅ Creces, sale la corona y la barra de jefe «el gigante» arriba, y aparecen los tres botones (I, O, P) a la derecha. Al deshacerlo vuelves a tu tamaño y tu vida de antes. El botón del tablero se ve en marcha mientras eres gigante.
2. [ ] En el Laboratorio, mira que los tres golpes funcionan con las teclas I, O y P aunque no haya habilidades.
   ✅ Sale el aviso naranja en el suelo y luego el daño.

#### 51.2 Dos jugadores (uno admin y otro no)

1. [ ] En el Lobby, el admin se hace gigante y el otro jugador está en la plaza. Los dos se pegan.
   ✅ El gigante daña al otro con el arma y los golpes (la zona segura no lo protege) y el otro puede dañar al gigante. Al caer el gigante, el otro recibe el título «Matagigantes» y un huevo legendario.
2. [ ] En Dunas y en el Laboratorio, con los dos jugadores en equipos distintos y en el mismo, el admin se hace gigante.
   ✅ El gigante daña a los dos equipos y los dos equipos le dañan a él. Quien cae reaparece en su base.
3. [ ] Con el gigante activo, entra y sale un tercer jugador cerca y lejos (más de 200 studs) del gigante.
   ✅ En unos 3 s su vida máxima sube o baja (3600 con 1 activo, ×1,75 con 2…) sin cambiar el % que le queda.
4. [ ] Con «Todos los servidores», el admin pulsa «Ser gigante» estando en el Lobby.
   ✅ Solo se hace gigante el admin, en su servidor.

#### 51.3 Pendiente de revisar más adelante

1. [ ] En Play en la Isla sale tres veces en la Salida «ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type». Averigua qué lo carga (se vio al probar A3, pero no parece de A3).
   ✅ Ninguna línea roja de ese asset al arrancar, o se sabe de quién es.

## 52. Fase 18 A4: jefe en los 4 places (29-10-2026)

Probado en Studio con 1 jugador en el Lobby, en Dunas y en la Isla. Lo que sigue va por cómo se prueba.

#### 52.1 Un jugador en Studio (Isla, Dunas, Laboratorio y Lobby)

1. [ ] En la Isla, invoca un jefe desde el panel de admin, mantén la partida hasta el final con el jefe invocado y mira el Ámbar que te da la partida.
   ✅ Al acabar la partida el Ámbar incluye el AmberPerBoss por el jefe invocado.
2. [ ] Con el jefe en la Isla, Dunas o el Laboratorio, mira los efectos visuales del jefe y su barra de vida arriba (BossHUD).
   ✅ Salen los efectos de BossFxController y la barra de vida del jefe, en cada uno de esos places y en el Lobby.
3. [ ] En el Laboratorio, con munición dentro de una partida, dispara al jefe hasta matarlo.
   ✅ Al matarlo, quien le hizo daño cobra 50 Ámbar y 50 XP una sola vez.
4. [ ] Abre el panel de admin, fila «Jefe», elige «Al azar» e invócalo. Repite con cada uno de los 4 jefes.
   ✅ Sale el jefe elegido. Con «Al azar» sale uno de los 4.
5. [ ] Con el gigante activo, pulsa para invocar un jefe. Después, con un jefe vivo, pulsa «Ser gigante».
   ✅ Las dos cosas se rechazan mientras la otra esté activa.
6. [ ] Invoca el jefe en Dunas y en el Laboratorio y mira sus pies (ya salió apoyado en Studio en Lobby, Dunas y Laboratorio).
   ✅ El jefe toca el suelo y no flota.

#### 52.2 Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en Dunas y en el Laboratorio)

1. [ ] Con los dos jugadores en equipos distintos, invoca el jefe y deja que ataque a los dos equipos. Los ataques tumban con el knockOut del place. Repite en el Laboratorio.
   ✅ El jefe es neutral contra los dos equipos. Los ataques tumban con el knockOut del place.
2. [ ] Haz daño al jefe con los dos jugadores hasta que caiga.
   ✅ Todos los que le hicieron daño cobran 50 Ámbar y 50 XP (Config.Bosses.OutsideReward) una sola vez.

#### 52.3 Con el juego publicado y 2 servidores

1. [ ] Con el jefe en la fase 2 y luego en la fase 3, fuera de la Isla (Dunas, Lobby o el Laboratorio), y con otro jugador en otro place o servidor.
   ✅ Las fases 2 y 3 se ven en el place. El aviso global (Announce) llega a los otros servidores y places, con el nombre del place y del servidor.

## 53. Fase 18 L1: Laboratorio, disparo y puntería (29-10-2026)

#### 53.1 Un jugador (Play en el Laboratorio, con munición)

1. [ ] Quieto, dispara el primer tiro del lanzadardos y del lanzarredes a un muñeco lejano con la mira en su centro.
   ✅ El primer tiro da justo en el centro (dispersión 0). Al mantener el gatillo del lanzadardos, la mira se abre y los tiros se esparcen; al soltar, se cierra.
2. [ ] Dispara moviéndote y en el aire.
   ✅ La mira se abre más y los tiros se desvían.
3. [⏭] Acierta a otro jugador (o a un muñeco con vida). ⏭️ Superado por §76: los hitmarkers cambiaron de color y de tamaño.
   ✅ Salen cuatro rayas blancas en diagonal alrededor de la mira durante unos 0,2 s. Con un golpe a la cabeza son rojas.
4. [⏭] Dispara el lanzadardos y el rifle de bananas. ⏭️ Superado por §79: el aro ya no existe.
   ✅ Las trazadoras se ven gruesas y brillantes, el fogonazo del arma es más grande y el impacto lanza chispas y anillo visibles.

#### 53.2 Dos jugadores

1. [ ] Mira desde fuera cómo dispara el otro jugador. (= §78 p1)
   ✅ Ves su fogonazo en la boca del arma y la trazadora gruesa hasta el impacto.

#### 53.3 Poses de disparo del rifle, el arpón y el cañón (publicadas)

1. [⏭] En el juego publicado, equipa cada arma del Laboratorio y dispara mirando a otro jugador desde fuera (o desde el espectador). ⏭️ Superado por §75: las poses de apuntar del rifle, el arpón y el cañón cambiaron.
   ✅ El arma apunta al frente, no al cielo: el rifle a la altura del pecho y el arpón y el cañón a la cadera. Al disparar, el cuerpo se echa atrás y la boca sube un poco.
2. [⏭] Dispara el lanzadardos. ⏭️ Superado por §75: el lanzadardos tiene su propia pose de apuntar (LabDart).
   ✅ Sigue con su pose de siempre (cerbatana) sin cambios.

#### 53.4 Cabeza quieta al andar (pista HeadSteady, publicada con el id 102631425550136)

1. [ ] En el juego publicado, en cada place (Lobby, Isla, Dunas y Laboratorio), camina y corre con y sin arma en la mano, a mano y en el móvil.
   ✅ La cabeza no cabecea ni tiembla al andar. Al empezar a correr con arma se inclina un poco hacia delante (6°) y se queda así, sin oscilar.
2. [ ] Haz un gesto (esquivar, deslizar, comer, caer) y vuelve a andar.
   ✅ El gesto manda sobre la cabeza mientras dura, y al acabar vuelve a quedar quieta.

## 54. Fase 18 L2: Laboratorio, movimiento (29-10-2026)

#### 54.1 Dos jugadores

1. [ ] Un jugador se desliza (con C, andando y corriendo) mientras el otro lo mira. (= §32.6 y §35.4)
   ✅ El que mira ve el cuerpo agachado y echado hacia atrás mientras dura el deslizamiento, sin que se quede en esa pose después.
2. [ ] Un jugador esquiva (Q) cerca del otro. (= §33.4)
   ✅ El rival ve la estela, el polvo en los pies y oye el aire. El que esquiva no ve su propia estela, solo el polvo y el sonido.

#### 54.2 Teléfono y mando

1. [ ] En el teléfono, corre y pulsa el botón que dice «Deslizar». (en parte = §32.4 p2)
   ✅ Se desliza y no sale el aviso «C · Deslizar» abajo a la izquierda.
2. [ ] Con mando, pulsa R3 andando. (en parte = §32.4 p4)
   ✅ Se desliza con la versión corta.

#### 54.3 Sensación (a ojo)

1. [ ] En PC, esquiva, desliza (andando y corriendo) y corre en el Laboratorio.
   ✅ Salen líneas blancas finas hacia los bordes: fuertes al esquivar, medias al deslizar y suaves al correr. No tapan la mira ni el cargador.
2. [⏭] Pon el ajuste de sacudida de cámara en «apagado». ⏭️ Superado por §74: apagar la sacudida ya no quita las líneas (ajuste «Líneas de velocidad»).
   ✅ No salen líneas blancas.

## 55. Fase 18 B1: luz del día y de la noche (29-10-2026)

Se prueba en la Isla publicada, con una partida entera (17 min) o saltando fases.

1. [ ] Mira el cielo del amanecer al atardecer y de la noche al amanecer.
   ✅ El reloj del juego corre a la misma velocidad de día y de noche: no hay un salto al cambiar de fase.
2. [ ] En el amanecer y el atardecer, mira el cielo y el suelo.
   ✅ Tonos rosas y naranjas, sin apagón. La noche es azul y se distingue el terreno sin linterna.
3. [ ] Con lluvia, tormenta o erupción, a cualquier hora.
   ✅ El tono del clima se suma a la luz de la hora, sin pelearse con ella.
4. [ ] Los carteles, la linterna y los avisos, de día y de noche.
   ✅ Se leen igual en todas las horas.

## 56. Fase 18 B2: ciclo lunar (29-10-2026)

Se prueba en la Isla publicada. La fase cambia cada 2 días de partida: Nueva (días 1-2), Creciente (3-4), Llena (5-6), Menguante (7-8).

1. [ ] Mira el icono de la luna a la izquierda del reloj (arriba a la derecha), en PC y en el teléfono, y tócalo o pasa el ratón.
   ✅ Se ve pegado al texto del reloj, no tapa el aviso del Basecamp y enseña el nombre y el efecto de la fase unos 5 s. Nueva: círculo oscuro con contorno; creciente y menguante: media luna a cada lado; llena: círculo entero.
2. [ ] Con 2 jugadores, comprueba que los dos ven la misma fase.
   ✅ El icono y su texto coinciden.
3. [ ] De noche con luna nueva y con luna llena, compara la luz.
   ✅ Con la nueva es más oscura (un 15 %) y con la llena algo más clara (un 8 %); de día no hay diferencia.
4. [ ] Mira la luna del cielo en cada fase.
   ✅ Pequeña con la nueva, mediana con creciente y menguante, grande con la llena, y cada una con su imagen (disco apagado, gajo a la derecha, llena, gajo a la izquierda). Si alguna sale vacía o con otra imagen, el id de `Config.Moon` está mal o falta que Roblox la apruebe.
5. [ ] Luna nueva: acércate a un mono desde lejos.
   ✅ Te detecta desde un 15 % menos de distancia.
6. [ ] Luna creciente: cosecha una mata de banano o un helecho y espera.
   ✅ Reaparece un 15 % antes (90 s pasan a unos 78 s; 180 s a unos 157 s). Árboles y rocas no cambian.
7. [ ] Luna llena: deja que un mono te muerda y mata a varios.
   ✅ Pega un 10 % más y suelta un 15 % más de botín (nunca Ámbar).
8. [ ] Luna menguante: mide cuánto tarda en bajar el hambre y la sed.
   ✅ Un 10 % más despacio.

## 57. Fase 18 B3: luna roja (29-10-2026)

Evento en vivo global que se lanza desde el tablero «🎮 Ahora en el juego» del panel de admin (botón 🩸 Luna roja, con el alcance elegido). Dura 30 min (`Config.LiveEvents.RedMoon.DefaultMinutes`); otro toque lo apaga. Los números están en `Config.LiveEvents.RedMoon`.

**Con 2 jugadores o en el juego publicado (varios servidores):**

1. [ ] Como admin, elige el alcance **🌍 Todos los servidores** en el tablero y pulsa **🩸 Luna roja**. Con los dos jugadores en servidores distintos, mirad el cielo los dos.
   ✅ El cielo se tiñe de rojo en los dos servidores en unos 3 s, y a los dos les sale el aviso **"🩸 ¡Empieza Luna roja! …"** con su hora.
2. [ ] Con la luna roja en marcha, haz que entre un jugador nuevo (o sal del juego y vuelve a entrar).
   ✅ Ve el cielo rojo desde el primer momento, sin esperar al aviso.
3. [ ] Pulsa **🩸 Luna roja** otra vez.
   ✅ En los dos servidores el cielo vuelve a la normal en unos 3 s.

**En el Lobby, Dunas y el Laboratorio (Studio, un place cada vez): solo cambia el cielo.**

4. [ ] Abre cada uno de los tres places y, con la luna roja en marcha, mira el cielo. Compáralo con el mismo place sin el evento.
   ✅ El cielo tira a rojo (tinte suave, sin apagar la luz) en unos 3 s. Ventanas, vida y combate no cambian.
5. [ ] En cada place, mira en **Lighting** si hay un objeto **Sky**. No está en el repositorio: depende de cada place.
   ✅ Si lo hay, la luna del cielo se pone roja. Si no, solo se tiñe el cielo, y eso es lo correcto. Anota en qué places hay Sky.

**En la Isla (partida con la luna roja en marcha):**

6. [ ] Llega la noche con la luna roja activa (**⏩ Saltar fase**) y compara la oleada con una noche sin el evento.
   ✅ La oleada sale 1,5 veces mayor, también cuando la normal ya llega al tope de monos.
7. [ ] Mira la vida y el daño de un mono que nazca con la luna roja y compáralos con uno de antes del evento.
   ✅ Vida +25 % y daño +20 %. Pasa todo el tiempo que dure el evento, de día también, no solo de noche.
8. [ ] Mata monos con la luna roja y cuenta el botín que sueltan, y compáralo con un rato sin el evento.
   ✅ Cada objeto del botín cae el doble de veces (lo que ya era seguro no puede pasar de seguro). Ningún objeto del botín es Ámbar.
9. [ ] Termina una partida con la luna roja en marcha y mira el Ámbar de la partida. Repite con **Doble Ámbar** activo también.
   ✅ Con la luna roja sola, el Ámbar de la partida sale ×2. Con la luna roja y Doble Ámbar a la vez sigue ×2, no ×4: no se apilan.
10. [ ] Con la luna roja en marcha, mira el icono de la fase junto al reloj (B2) y su efecto, por ejemplo la luna nueva (detección −15 %).
   ✅ La fase sigue activa debajo: el efecto es el mismo. La luna roja solo cambia el color del disco de la luna.

**En el panel de admin (en cualquier place):**

11. [ ] Mira el botón 🩸 **Luna roja** del tablero «🎮 Ahora en el juego» apagado y después encendido. (= §50.3 p1)
   ✅ Apagado, dorado. Encendido, azul. Otro toque lo apaga y vuelve a dorado.

## 58. Fase 18 M1: capibara (29-10-2026)

Mascota Poco común nueva (🐹, +15 de vida máxima). Entra sola al sorteo Uncommon de los huevos normales.

**En Play (Isla o Lobby), con la mascota dada desde el panel de admin:**

1. [ ] Dale la **Capibara** desde el panel de admin, equípala en el nido del Lobby y entra a la Isla.
   ✅ Te sigue andando con las cuatro patas en diagonal, sin atravesar el suelo ni quedarse flotando, y su tamaño se parece al del Perezoso.
2. [ ] Con la capibara equipada, mira tu vida máxima antes y después de equiparla.
   ✅ Sube 15 puntos; al guardarla en el nido vuelve a lo de antes.
3. [ ] Mírala de frente, de lado y por detrás.
   ✅ Naranja-marrón con el lomo claro, hocico romo y oscuro con dos fosas, orejitas oscuras y patas oscuras. Se distingue de la Tortuga y del Perezoso a primera vista.

**Con muchos huevos:**

4. [ ] Abre huevos normales hasta que salga alguna Poco común (o mira el panel de probabilidades del nido).
   ✅ La Capibara aparece entre las Poco comunes junto a la Guacamaya y el Perezoso. Su nombre y su descripción salen traducidos al cambiar el idioma a inglés.

## 59. Fase 18 M2: quetzal (29-10-2026)

Mascota Mítica nueva (🦚). Lleva `origin = "HuevoMitico"`: ningún huevo normal la da. Se da desde el panel de admin y entrará con el huevo mítico (Fase 14, D5).

**En Play (Isla o Lobby), con la mascota dada desde el panel de admin:**

1. [ ] Dale el **Quetzal** desde el panel de admin (Dar mascota), equípalo en el nido del Lobby y entra a la Isla.
   ✅ Vuela siguiéndote, con las alas abiertas aleteando y las dos plumas largas de la cola moviéndose detrás, sin atravesar suelo ni paredes.
2. [ ] Mira tu estamina al correr con el quetzal y sin él, y el daño de la honda o el arco.
   ✅ Correr gasta un 25 % menos y el daño a distancia sube un 8 %.
3. [ ] Míralo de frente, de lado y por detrás.
   ✅ Esmeralda con el pecho carmesí, pico amarillo, cresta y la cola larga; de espaldas se ve la capa en filas y la banda blanca. No se confunde con la Guacamaya ni con el Tucán.

**Con muchos huevos:**

4. [ ] Abre muchos huevos normales de todas las rarezas (o mira el panel de probabilidades del nido).
   ✅ El Quetzal no sale nunca ni aparece en la lista de mascotas posibles de ningún huevo.
5. [ ] En el panel de admin, mira la lista de mascotas.
   ✅ El Quetzal aparece como Mítico y se puede dar a un jugador. Su nombre y su descripción salen traducidos al inglés.

## 60. Fase 18 M3: ajolote y animaciones de las mascotas nuevas (29-10-2026)

Ajolote: mascota Mítica nueva (🦎), con `origin = "HuevoMitico"` (no sale de huevos normales; se da desde el panel de admin). Cura 2 de vida cada 2 s. Esta tanda también añade clips a la Capibara (`IdleGraze`, `IdleShake`, `Run`), al Ajolote (`IdleGills`, `IdleWag`, `Run`) y al Quetzal (`Glide` con la cola ondulando).

**En Play (Isla o Lobby), con las mascotas dadas desde el panel de admin:**

1. [ ] Dale el **Ajolote**, equípalo y entra a la Isla. Herido, quédate quieto un rato.
   ✅ Te sigue andando como una salamandra (patas en diagonal, cola que ondea). Te sube 2 de vida cada 2 s y aparece el «+2» verde.
2. [ ] Con el Ajolote, quédate quieto unos 10–20 s y espera sus rutinas.
   ✅ A veces abre las branquias como un abanico y las agita (`IdleGills`) y otras mueve la cola de lado a lado mirando a los lados (`IdleWag`). Al moverte vuelve a andar sin saltos.
3. [ ] Corre con el Ajolote.
   ✅ Serpentea con el cuerpo, la cola y la cabeza al galopar (`Run`).
4. [ ] Con la Capibara, quédate quieto 10–20 s y luego corre.
   ✅ Baja la cabeza y mordisquea (`IdleGraze`) o se sacude entera (`IdleShake`). Al correr trota con la cabeza y el lomo subiendo y bajando.
5. [ ] Con el Quetzal, mira cómo planea (con el dueño andando y quieto).
   ✅ En los momentos de planeo las alas quedan quietas y las dos plumas de la cola ondulan y la cabeza se ladea un poco. La vuelta sobre el dueño quieto sigue funcionando.
6. [ ] Abre muchos huevos normales y mira el panel de admin.
   ✅ El Ajolote no sale nunca de un huevo normal y aparece como Mítico en el panel. Su nombre y su descripción salen en inglés al cambiar el idioma.

## 61. Fase 18 M4: clips de las mascotas antiguas (29-10-2026)

Ahora todas las mascotas tienen rutinas de reposo (`Idle…`) y las de suelo, `Run`. Nuevos: aves (`IdleLook`, `IdleFlutter`: Tucán, Guacamaya y Quetzal), Colibrí (`IdleLook`, `IdleTilt`), Rana (`IdleCroak`, `IdleLook`, `IdleStretch`), Tortuga (`IdleLook`, `IdleStretch`), Perezoso (`IdleYawn`, `IdleScratch`, `IdleLook`, `Run`) y Mono X-7 (`IdleChest`, `IdleLook`). Los felinos, los perros, el Jaguar de cristal, la Capibara y el Ajolote ya los tenían.

**En Play (Isla o Lobby), con cada mascota equipada. Se prueba quedándote quieto unos 10–20 s (las rutinas empiezan a los 2,5 s y cada 2,5–5 s):**

1. [x] Tucán, Guacamaya y Quetzal: quédate quieto.
   ✅ Mientras giran sobre ti, a veces miran a un lado y a otro con la cabeza y la cola, y a veces sacuden las alas un momento. No se cortan ni saltan al empezar o acabar.
2. [x] Colibrí: quédate quieto.
   ✅ Gira la cabeza muy rápido a los lados con la cola agitándose, o la ladea a uno y otro lado.
3. [x] Rana dardo: quédate quieto.
   ✅ Croa (cuerpo inclinado con la garganta que late), mira a los lados girando el cuerpo o estira una pata de atrás.
4. [x] Tortuga: quédate quieto.
   ✅ Gira la cabeza a un lado y a otro, o estira las aletas hacia fuera con la cabeza levantada.
5. [x] Perezoso: quédate quieto y luego corre.
   ✅ Bosteza con la cabeza hacia arriba, se rasca con un brazo levantado o mira a los lados; al correr se bambolea.
6. [x] Mono X-7: quédate quieto.
   ✅ Se golpea el pecho con los dos puños alternándolos con la cabeza echada atrás, o mira a los lados.
7. [x] Con cualquiera de ellas en reposo, muévete.
   ✅ La rutina se deshace sin saltos y la mascota vuelve a seguirte con su modo de siempre.

## 62. Fase 18 R1: armaduras de Pelaje rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Fabrica el chaleco de pelaje con cada rol (Guerrero, Cazador, Mago, Médico) y míralo desde atrás con la cámara del juego, quieto y corriendo.
   ✅ La espalda se ve llamativa: huella dorada, abanico de hojas con carcaj, atrapasueños y manojo de hierbas. Nada flota ni atraviesa el cuerpo al andar, apuntar o golpear.
2. [ ] Ponte un traje mítico encima del chaleco (grado 1).
   ✅ El traje se ve entero, sin piezas del chaleco asomando.
3. [ ] Prueba con un avatar R6.
   ✅ Las hombreras no flotan ni se hunden.

## 63. Fase 18 R2: armaduras de Hueso rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Fabrica la armadura de hueso con cada rol y mírala desde atrás con la cámara del juego, quieto y corriendo.
   ✅ La espalda se ve llamativa: cráneo de trofeo sobre costillas, manto de hojas con carcaj, sello de runas y mochila con frascos. Nada flota ni atraviesa el cuerpo al andar, apuntar o golpear.
2. [ ] Con el guerrero, mira las hombreras de cerca.
   ✅ Las puntas de pelaje rojo no atraviesan los cráneos.
3. [ ] Ponte un traje mítico encima de la armadura de hueso (grado 2).
   ✅ El traje se ve entero, sin piezas de la armadura asomando.
4. [ ] Prueba con un avatar R6.
   ✅ Las hombreras no flotan ni se hunden.

## 64. Fase 18 R3: armaduras de Plata rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Fabrica la armadura de plata con cada rol y mírala desde atrás con la cámara del juego, quieta y corriendo.
   ✅ La espalda se ve llamativa: cabeza de gorila plateado de ojos rojos, carcaj con flechas plateadas sobre hojas, corona de cristales y tótem sanador. Nada flota ni atraviesa el cuerpo al andar, apuntar o golpear.
2. [ ] Mira de cerca las hojas de las esquinas y las orejas de la capucha del cazador, y los frascos junto al tótem del médico.
   ✅ Nada se atraviesa ni asoma mal.
3. [ ] Ponte un traje mítico encima de la armadura de plata (grado 3).
   ✅ El traje se ve entero, sin piezas de la armadura asomando.
4. [ ] Prueba con un avatar R6.
   ✅ Las hombreras no flotan ni se hunden.

## 65. Fase 18 R4: armaduras Volcánicas rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Fabrica la armadura volcánica con cada rol y mírala desde atrás con la cámara del juego, quieta y corriendo.
   ✅ La espalda se ve llamativa: volcán con cráter, carcaj de obsidiana con flechas que arden, sol de fuego con corona de cristales y racimo de azufre con chimeneas. Nada flota ni atraviesa el cuerpo al andar, apuntar o golpear.
2. [ ] Mira de cerca las hombreras, la corona del guerrero y las chimeneas del médico.
   ✅ Ninguna punta atraviesa la llama, el cráneo ni otra pieza.
3. [ ] En un teléfono (o el emulador), míralas con varios jugadores cerca. (el mismo paso que §65 p3, §69 p4, §71 p5, §72 p5 y §73 p5: hacerlos juntos)
   ✅ El humo y las brasas no bajan los FPS de forma notable.
4. [ ] Ponte un traje mítico encima de la armadura volcánica (grado 4).
   ✅ El traje se ve entero, sin piezas de la armadura asomando.
5. [ ] Prueba con un avatar R6.
   ✅ Las hombreras no flotan ni se hunden.

## 66. Fase 18 S1: armas de la forja de rango I rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Equipa cada arma inicial (Machete, Honda, Garrote de piedra, Arco, Cerbatana, Bastón mágico) y míralas en la mano con la cámara del juego, quietas, corriendo y atacando.
   ✅ Se ven más ricas que antes (fibra, pelaje, plumas, pintura) sin piezas sueltas ni atravesadas, y la pose de agarre no cambia.
2. [ ] Dispara el arco y la cerbatana, lanza con la honda y golpea con el garrote y el machete.
   ✅ Las poses (AnimationTrack) siguen alineadas con el arma; los proyectiles salen de la punta correcta.
3. [ ] Mejora cada arma al rango II. (= §67 p1)
   ✅ El rango II se ve claramente más rico y con hueso; el rango I se ve primitivo (sin hueso).
4. [ ] Pon un aspecto de arma (Sulfurado) sobre el Machete y el Arco.
   ✅ El aspecto se dibuja entero, sin piezas del arma base.

## 67. Fase 18 S2: armas de la forja de rango II rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Mejora cada arma al rango II (Machete afilado, Honda de liana, Maza de hueso, Arco reforzado, Cerbatana de hueso, Bastón dorado) y míralas en la mano, quietas, corriendo y atacando. (= §66 p3)
   ✅ Se ven más ricas que las de rango I, con hueso, y sin piezas sueltas ni atravesadas (colmillos de la guarda y de la cerbatana, púas de la maza, colgantes del bastón). La pose de agarre no cambia.
2. [ ] Dispara el arco y la cerbatana, lanza con la honda y golpea con la maza y el machete.
   ✅ Las poses (AnimationTrack) siguen alineadas con el arma y los proyectiles salen de la punta correcta.
3. [ ] Mira la Maza de hueso desde atrás y de cerca.
   ✅ La calavera colgante y el collar de colmillos no atraviesan el mango.

## 68. Fase 18 S3: armas de la forja de rango III rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Mejora cada arma al rango III (Maza de hueso gruesa, Arco de liana, Cerbatana de chamán, Bastón de plata) y míralas en la mano, quietas, corriendo y atacando.
   ✅ Se ven más ricas que las de rango II, con plata, liana y plumas de colores, y sin piezas sueltas ni atravesadas (anillos de la cabeza de la maza, hojas y colgantes del bastón, remates del arco). La pose de agarre no cambia.
2. [ ] Dispara el arco y la cerbatana, y golpea con la maza y el bastón.
   ✅ Las poses (AnimationTrack) siguen alineadas con el arma y los proyectiles salen de la punta correcta.
3. [ ] Compara los rangos I, II, III y IV de cada rol uno al lado del otro.
   ✅ Cada rango se ve más rico que el anterior y comparten motivos; el III es claramente más simple que el volcánico.

## 69. Fase 18 S4: armas de la forja de rango IV rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Mejora cada arma al rango IV (Maza volcánica, Arco de ascuas, Cerbatana de azufre, Bastón de lava) y míralas en la mano, quietas, corriendo y atacando.
   ✅ Se ven más ricas que las de rango III, con obsidiana, grietas de lava, azufre y brasas, sin piezas sueltas ni atravesadas (grietas y cristales de la maza, plumas del arco, amuleto de la cerbatana, gotas del bastón). La pose de agarre no cambia.
2. [ ] Dispara el arco y la cerbatana, y golpea con la maza y el bastón.
   ✅ Las poses (AnimationTrack) siguen alineadas con el arma y los proyectiles salen de la punta correcta.
3. [ ] Pon un aspecto de temporada (Sulfurado) y uno mítico sobre cada arma de rango IV.
   ✅ El aspecto se ve distinto y más rico que el arma base, sin piezas del arma base asomando.
4. [ ] En un teléfono (o el emulador), míralas con varios jugadores cerca. (el mismo paso que §65 p3, §69 p4, §71 p5, §72 p5 y §73 p5: hacerlos juntos)
   ✅ Los destellos y brasas no bajan los FPS de forma notable.

## 70. Fase 18 K1: skins de temporada de arma (Azufre) rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Equipa cada skin Sulfur (Maza, Arco, Bastón, Cerbatana, Machete) sobre el arma de cada rango (1 a 4) y míralas en la mano, quietas, corriendo y atacando.
   ✅ Cada skin se ve más rica que el arma base de su rango y distinta de ella (cristales de azufre amarillo, carbón y pómez; llama azul desde el nivel 3 o 4, nada de lava naranja). No hay piezas sueltas ni atravesadas. La pose de agarre no cambia.
2. [ ] Dispara el arco y la cerbatana con la skin puesta, y golpea con la maza, el bastón y el machete.
   ✅ Las poses (AnimationTrack) siguen alineadas y los proyectiles salen de la punta correcta; los cristales del arco que salen por delante no tapan la mira.
3. [ ] Con el arco, mira el colgante del lado izquierdo de la empuñadura mientras apuntas.
   ✅ No se cruza con el brazo ni con el cordón de plumas.
4. [ ] Afila el machete (nivel 2) con la skin Sulfurado.
   ✅ Aparecen los dientes y las brasas azules del filo y se ve más rico que en el nivel 1.
5. [⏭] Compara las skins míticas con las de Azufre de nivel 4. ⏭️ Superado por §71: K2 ya subió las skins míticas.
   ✅ Las míticas deberían verse por encima; hoy miden 84-108 piezas frente a 119-123 de las épicas, y K2 las subirá.

## 71. Fase 18 K2: skins míticas de arma rehechas (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Equipa cada skin mítica (Maza del Rey Gorila, Arco del Jaguar Espectral, Bastón de la Serpiente Emplumada, Cerbatana de la Ceiba) sobre el arma de cada rango (1 a 4) y míralas en la mano, quietas, corriendo y atacando.
   ✅ Cada una se ve más rica que la skin Sulfur y que el arma base de su rango, con su tema (piedra y jade con calavera de gorila; espíritu de jaguar; plumas y escamas de quetzal; árbol de vida) y crece con el nivel. No hay piezas sueltas ni atravesadas. La pose de agarre no cambia.
2. [ ] Mira cada skin desde atrás y de cerca.
   ✅ La espalda también se lee bien (calavera y aro de sol del Titán, glifos del Jaguar, cola y cuello de la Serpiente, raíces y lianas de la Ceiba) y nada queda dentro de otra pieza (calavera entre aro y cristales, colmillos y manchas del Jaguar, plumas del cuello y cuernos de la Serpiente, lianas y flor de la Ceiba).
3. [ ] Dispara el arco y la cerbatana, y golpea con la maza y el bastón con la skin puesta.
   ✅ Las poses (AnimationTrack) siguen alineadas y los proyectiles salen de la punta correcta; las plumas de cola de la Serpiente no rozan el suelo con el brazo bajo.
4. [ ] Pon el traje mítico del mismo tema junto con su arma. (= §73 p4)
   ✅ Paleta y motivos encajan (jade, oro y ojos de jade; espectral; plumas de quetzal; savia).
5. [ ] En un teléfono (o el emulador), míralas con varios jugadores cerca. (el mismo paso que §65 p3, §69 p4, §71 p5, §72 p5 y §73 p5: hacerlos juntos)
   ✅ Los destellos y el humo no bajan los FPS de forma notable.

## 72. Fase 18 T1: trajes legendarios del pase (Fuego Azul) rehechos (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Ponte cada traje del Fuego Azul (Guardián, Acechador, Invocador, Sanador) en los grados 1, 2, 3 y 4 y míralo desde atrás con la cámara del juego, quieto y corriendo.
   ✅ Cada grado se ve más rico que el anterior y la espalda es vistosa (marco con escudo de azufre en llamas, capa y carcaj con flechas azules, aro de piedra, incensario). Nada flota ni atraviesa el cuerpo al andar, apuntar o golpear.
2. [ ] Pónlos sobre la armadura de cada rango (I a IV).
   ✅ El traje encaja con las cuatro armaduras sin piezas de ellas asomando ni cruzadas.
3. [ ] Mira de cerca los flecos del manto y los frascos del Sanador, las gotas bajo el disco del Guardián, el cristal del muslo y las borlas del Invocador.
   ✅ Ninguna punta atraviesa otra pieza ni la armadura.
4. [ ] Compáralos con la armadura volcánica naranja y con los trajes míticos.
   ✅ Se distinguen a primera vista (azufre y fuego azul, no lava naranja ni jade y oro).
5. [ ] En un teléfono (o el emulador), míralos con varios jugadores cerca. (el mismo paso que §65 p3, §69 p4, §71 p5, §72 p5 y §73 p5: hacerlos juntos)
   ✅ Las brasas, el humo y las llamas no bajan los FPS de forma notable.
6. [ ] Prueba con un avatar R6.
   ✅ Las hombreras y la espalda no flotan ni se hunden.

## 73. Fase 18 T2: trajes míticos rehechos (29-10-2026)

**Con la Isla en Play (un jugador)**

1. [ ] Ponte cada traje mítico (Rey Gorila, Jaguar Espectral, Serpiente Emplumada, Ceiba de la Vida) en los grados 1, 2, 3 y 4 y míralo desde atrás con la cámara del juego, quieto y corriendo.
   ✅ Cada grado se ve más rico que el anterior y que el traje legendario del pase del mismo grado; la espalda es vistosa. Nada flota ni atraviesa el cuerpo al andar, apuntar o golpear.
2. [ ] Pónlos sobre la armadura de cada rango (I a IV) y mira de cerca los muslos y las púas de muñeca del Titán, la liana del peto y los frascos de la Ceiba, y las líneas de zarpazos y las rosetas del Jaguar.
   ✅ El traje encaja con las cuatro armaduras, sin piezas asomando ni cruzadas.
3. [ ] Mira de cerca el espíritu del Jaguar (aura, volutas y manchas) y el halo del grado 4 de la Serpiente.
   ✅ Nada atraviesa la cabeza ni el hombro; el halo y los colgantes del Titán no cuelgan en el aire por detrás de la capa.
4. [ ] Equipa el traje mítico junto con su arma mítica (Maza del Rey Gorila, Arco del Jaguar Espectral, Bastón de la Serpiente Emplumada, Cerbatana de la Ceiba). (= §71 p4)
   ✅ Paleta y motivos encajan; las runas y bolas de neón no deslumbran en los grados 3 y 4.
5. [ ] En un teléfono (o el emulador), míralos con varios jugadores cerca. (el mismo paso que §65 p3, §69 p4, §71 p5, §72 p5 y §73 p5: hacerlos juntos)
   ✅ Los destellos, las estrellas y las luciérnagas no bajan los FPS de forma notable.
6. [ ] Prueba con un avatar R6.
   ✅ Las hombreras (ahora losas y discos planos) no flotan ni se hunden.

## 74. Fase 19 W1: líneas blancas, FOV y sacudida (29-10-2026)

**En Studio de la Isla, Dunas y el Lobby (un place cada vez, con un jugador):**

1. [ ] En la Isla, esquiva y deslízate con el ajuste por defecto y mira la pantalla.
   ✅ Se ven líneas blancas fuertes alrededor de la pantalla (transparencia mínima 0,40) y un empujón de FOV. La esquiva las mantiene unos 0,46 s.
2. [ ] Repite lo mismo en Dunas.
   ✅ Mismo resultado que en la Isla.
3. [ ] Repite lo mismo en el Lobby.
   ✅ Las líneas blancas aparecen también en el Lobby, con la misma fuerza.

**En la Isla o Dunas, en campo abierto:**

1. [ ] Desliza en línea recta durante varios segundos, lejos de cualquier recinto de aparición.
   ✅ Las líneas duran todo el deslizamiento y se apagan al terminar. (En el Laboratorio el recinto de aparición lo cortó.)

**Ajuste "Líneas de velocidad" en Ajustes (Isla, Dunas y Lobby):**

1. [ ] Pon "Líneas de velocidad" en Apagado y esquiva y desliza en la Isla.
   ✅ No aparecen líneas ni empujón de FOV.
2. [ ] Pon "Líneas de velocidad" en Suave y repite.
   ✅ Las líneas y el empujón se ven a la mitad de fuerza que con Encendido.
3. [ ] Pon "Líneas de velocidad" en Encendido, apaga "Sacudida de cámara" y repite.
   ✅ Las líneas siguen apareciendo: la sacudida apagada ya no las apaga.
4. [ ] Repite el paso 1 en Dunas y en el Lobby.
   ✅ El ajuste se respeta igual en los tres places.

**Ventana de Ajustes en el PC (Isla, Dunas o Lobby):**

1. [ ] Abre Ajustes y mira la ventana con las filas nuevas de "Líneas de velocidad" (Encendido, Suave, Apagado).
   ✅ Todo cabe sin desplazamiento; la ventana no gana una barra de scroll respecto a antes. El panel del Laboratorio (ArenaSettings) ya tenía desplazamiento de antes y no cuenta.

**En un teléfono (emulador y real), en la Isla:**

1. [ ] Esquiva y desliza con varios jugadores cerca.
   ✅ Las líneas se leen sin esfuerzo y no tapan el HUD (barras, botones ni mira).
2. [ ] Esquiva y desliza seguido durante un rato.
   ✅ Los FPS son estables y no caen de forma notable al aparecer las líneas.

**Embestida del Guerrero, con un jugador en Play (un place con roles: Isla o Dunas):**

1. [ ] Embiste con el Guerrero varias veces en campo abierto.
   ✅ Hay un empujón de FOV y una sacudida corta al cargar. Se siente bien: ni molesta ni marea, y la vibración para al terminar la embestida.

## 75. Fase 19 W2: pose de apuntar visible para todos (29-10-2026)

**Publicar (lo hace el usuario, en el Studio de la Isla):**

1. [⏭] Ejecuta `require(game.ServerStorage.Tools.WeaponAnimationBuilder).build()` (con la copia fresca si hace falta). En `ReplicatedStorage.WeaponAnimations`, clic derecho > *Save to Roblox*, con el mismo dueño que el juego, en estas 16: AimStone, AimBow, AimSpell, AimBlowgun, AimDartGun, AimRifle, AimHarpoon, AimCannon, LabDart, y vuelve a publicar Stone, Arrow, Spell, Dart, LabRifle, LabHarpoon y LabCannon (empiezan y acaban en la pose de apuntar). Pega los 16 ids en `src/shared/Data/WeaponAnimations.luau` y guarda el place. ⏭️ Superado por §86: los ids ya están pegados.
   ✅ Los 16 ids quedan pegados; los Aim* y LabDart ya no están vacíos. Mientras alguno esté vacío, fuera de Studio se usa Hold, y LabDart cae en Dart.

**2 jugadores en Studio (Clients and Servers) o publicado:**

1. [ ] Con el otro jugador mirando, equipa cada arma a distancia (Honda, Arco, Bastón, Cerbatana y las 4 del Laboratorio) y quédate quieto.
   ✅ Se le ve con el arma al frente todo el tiempo, en la pose de apuntar de cada una.
2. [ ] Corre con el arma equipada.
   ✅ El arma baja (Hold, brazo colgando) mientras corres.
3. [ ] Para de correr.
   ✅ El arma vuelve al frente en unos 0,15 s.
4. [ ] Desequipa el arma, cae o muere con ella en la mano.
   ✅ No queda ninguna pose en el personaje: el brazo vuelve al cuerpo.
5. [ ] Dispara varias veces con cada arma a distancia.
   ✅ Cada disparo se ve con su animación en el otro jugador, una sola vez: no se duplica (una sola pista por id).
6. [ ] Dispara con el lanzadardos del Laboratorio.
   ✅ Se ve su disparo corto propio, distinto del de la cerbatana.

**Un jugador, en Play:**

1. [ ] En la Isla y en Dunas, equipa un arma a distancia y anda (tercera persona). Dispara.
   ✅ La pose de apuntar se mantiene también andando; el disparo sale de ella y vuelve a ella.
2. [⏭] En el Laboratorio (primera persona), equipa cada arma y dispara. ⏭️ Superado por §84 y §87: el rig de brazos y los modelos de apuntado cambian la vista.
   ✅ No cambia lo que ves respecto a antes de W2.

**Publicado:**

1. [ ] Abre el juego publicado y equipa las armas a distancia.
   ✅ Los ids cargan (mismo dueño): las poses se reproducen.
2. [ ] Apunta con cada arma en tercera persona.
   ✅ El brazo no sale colgando al apuntar.
3. [ ] Mira la consola mientras usas las armas.
   ✅ El aviso `ContentId: rbxassetid://203785492 failed … Asset type does not match requested type` (salió 3 veces, de origen desconocido y quizá anterior a W2) no aparece al usar las armas. Si sigue saliendo, se anota aparte: no es de W2.

Nota: el disparo real (clic) no se pudo lanzar desde el MCP. Hay que probarlo a mano en los pasos de disparo de arriba.

## 76. Fase 19 W3: confirmación de impacto (29-10-2026)

**2 jugadores en Studio (Clients and Servers) o publicado, con el tirador y el otro jugador en Dunas, la Isla y el Laboratorio:**

1. [ ] Como tirador, dispara con un arma a distancia a un cuerpo del otro jugador (en Dunas y la Isla, con la ayuda de puntería; en el Laboratorio, con el lanzadardos o el rifle).
   ✅ Aparece un hitmarker blanco en la mira (en la Isla, sin mira, en el centro de la pantalla) y se apaga en unos 0,3 s. Suena «tac».
2. [ ] Como tirador, dispara a la cabeza del otro jugador.
   ✅ El hitmarker sale amarillo-naranja y más grande (unas 1,3 veces). Suena «dink», más fuerte que el «tac».
3. [ ] Como tirador, mata al otro jugador de un disparo.
   ✅ Sale la marca de muerte más grande (unas 1,6 veces) y dura más (unos 0,45 s), con un «pop» más largo que los otros dos.
4. [ ] Como tirador, dispara a alguien que tiene la guardia levantada (Dunas y la Isla).
   ✅ El hitmarker sale gris azulado, no blanco.
5. [ ] Mira al otro jugador mientras le das con varios disparos.
   ✅ No oye los «tac», «dink» ni «pop» de tus aciertos: son solo para el tirador.
6. [ ] Con lag simulado de 150 ms (Network Simulation de Studio), dispara a un cuerpo y a la cabeza.
   ✅ La marca aparece al llegar la confirmación del servidor, sin agrupar con otras y sin esperar al lote de 0,1 s de `CombatText`.
7. [ ] Dispara una ráfaga de dardos sostenida contra un jugador durante unos 3 s.
   ✅ Como mucho sale un aviso cada 0,05 s por tirador. Una muerte sí se ve aunque caiga dentro de ese intervalo.

**Muñecos de práctica, un jugador en Play (Lobby, Isla, Laboratorio o Dunas):**

1. [ ] En el Lobby, dispara con un arma a distancia a un muñeco de práctica.
   ✅ La marca sale en el centro de la pantalla (no hay mira) y suena «tac».
2. [ ] En la Isla, repite con un arma a distancia contra un muñeco de práctica.
   ✅ Mismo resultado que en el Lobby: marca en el centro y «tac». Ya se puede probar la cabeza (§80), así que el amarillo-naranja también se prueba aquí.
3. [ ] En el Laboratorio o en Dunas, dispara a un blanco con un arma a distancia y mira dónde aparece la marca.
   ✅ La marca sale en la mira, no en el centro de la pantalla.
4. [ ] Pega con el arma de cuerpo a cuerpo a un muñeco y usa una habilidad que hace daño.
   ✅ No aparece marca ni suena «tac», «dink» ni «pop». Solo avisan los disparos a distancia.

Nota: lo ya probado en Studio (cliente del Laboratorio: marcador en el centro, colores y escala correctos para Body, Head, Kill y Blocked; sin errores en consola) no se repite aquí.

Nota: los sonidos «tac», «dink» y «pop» son provisionales (ids de serie). Están pendientes de reemplazar y no se juzga su calidad hasta entonces.

## 77. Fase 19: arma del Laboratorio al derecho en tercera persona (29-10-2026)

**2 jugadores en Studio o publicado, en el Laboratorio:**

1. [ ] Con el otro jugador mirando, equipa cada arma del Laboratorio (lanzadardos, rifle, lanzarredes y cañón) en cada bando y quédate quieto.
   ✅ El arma se ve con la mira, el tambor o la funda arriba y el cargador abajo, también al correr (Hold) y al disparar.
2. [ ] Mira tu propia arma en tercera persona (aleja la cámara) y en primera persona.
   ✅ En tercera persona se ve al derecho; en primera persona no cambia.
3. [ ] Mira una skin con piezas a un solo lado (alas, antenas, cordón).
   ✅ Se ve bien aunque el arma esté girada 180° sobre el cañón.
4. [ ] Abre el Armario o el preview de ajustes con el arma puesta.
   ✅ El arma se ve igual que antes (el giro solo es del agarre de la mano).

## 78. Fase 19 W4: bala inmediata del tirador (29-10-2026)

**Un jugador en Play con 150 ms de lag (*Test → Incoming/Outgoing replication lag*, en el Laboratorio, la Isla, Dunas y el Lobby):**

1. [ ] En el Laboratorio, dispara el lanzadardos y el rifle a una pared con el lag puesto.
   ✅ Cada bala sale al apretar el disparo. No se duplica ni da un salto visible al llegar la confirmación del servidor.
2. [ ] En la Isla, dispara con un arma a distancia (honda o arco) a un muñeco de práctica o a un mono con el lag puesto.
   ✅ La bala sale al instante, una por disparo. Si la ayuda de puntería corrige la trayectoria, lo hace en unos 0,08 s y sin salto visible.
3. [ ] En Dunas, dispara con un arma a distancia a un muñeco de práctica con el lag puesto, apuntando cerca de un enemigo o de un blanco.
   ✅ Igual que en la Isla: una bala, sin duplicado y con corrección suave de 0,08 s cuando actúa la ayuda de puntería.
4. [ ] En el Lobby, dispara con un arma a distancia a un muñeco de práctica con el lag puesto.
   ✅ Una bala por disparo, sin duplicado, y sale al instante.

**Un jugador en Play (Laboratorio, sin lag):**

1. [ ] Dispara varias veces con el rifle con la mira acercada, y después con el lanzadardos corriendo y en el aire, a un blanco fijo.
   ✅ La bala que ves y el impacto real casi siempre coinciden. El ajuste del servidor (ProjectileAck) casi nunca cambia la trayectoria que ya se ve.
2. [ ] Dispara justo al reaparecer tras morir, y después con el arma sin cargador o con la cadencia rechazada.
   ✅ No hay duplicados graves. Puede salir una bala local sin daño que vuela hasta su alcance; se tolera.
3. [ ] Dispara el cañón de suero (en arco), pega con el cuerpo a cuerpo y usa una habilidad.
   ✅ Siguen como antes: el cañón hace su arco de caída, el cuerpo a cuerpo y la habilidad no añaden una bala local.
4. [ ] Dispara con el lanzadardos en primera persona y mira la trazadora.
   ✅ La trazadora es más gruesa que antes (TracerWidthFP 0,5) y sale de la boca del arma.

**Isla y Dunas, un jugador en Play (sin lag):**

1. [ ] En la Isla, dispara la honda, el arco y el bastón a un muñeco de práctica o a un mono, y mira de dónde sale la bala. Después, en Dunas, haz lo mismo con la cerbatana y sus remates.
   ✅ La bala sale de la boca o del mango del arma, en el mismo sitio donde se ve el arma, sin saltar a otro punto.
2. [ ] Pega el muzzle de un arma a distancia a una pared y dispara.
   ✅ La bala sale de la boca del arma y no se para en la pared, aunque esté pegada.

**Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio o en Dunas):**

1. [ ] Con el otro jugador mirando, dispara un arma a distancia a una pared o al suelo. (= §53.2 p1)
   ✅ El otro jugador ve volar el proyectil y el fogonazo (WeaponShotFx) de tu disparo, una sola vez por disparo.
2. [ ] Dispara a un cuerpo del otro jugador con el lag puesto en tu cliente.
   ✅ Tú ves una sola bala y el otro jugador ve una sola bala y un solo fogonazo; no aparecen dos proyectiles ni dos fogonazos.

Nota: lo ya probado en Studio (un jugador en el Laboratorio: la bala local sale en el mismo instante del disparo y es una sola por disparo; el servidor manda ProjectileAck con el número de disparo; sin errores) no se repite aquí.

## 79. Fase 19 W5: marcas de impacto, chispas, polvo y pulpa (29-10-2026)

**Un jugador en Play (▶ Jugar, en el Laboratorio):**

1. [ ] Dispara el rifle y el lanzadardos a una pared y al suelo, y mira la marca, las chispas y el polvo de cada impacto.
   ✅ Las marcas son oscuras, están pegadas a la pared y al suelo, tienen el tono de la pieza y se apagan a los 8 s. Las chispas son amarillas y cuadradas, y salen hacia fuera de la superficie. El polvo tiene el color del material, en el suelo y en la pared.
2. [ ] Mira de cerca las chispas y el polvo tras unos cuantos impactos.
   ✅ Se ven como cuadrados de color y desaparecen solos al acabar. Si no se ven, o no desaparecen, hay que poner una textura blanca en `ImpactFx.newEmitter`.
3. [ ] Dispara el lanzadardos y el rifle de bananas contra una pared.
   ✅ Ya no aparece el aro plano en la pared ni en el suelo, y cada impacto sigue sacando sus 5 chispas.
4. [ ] Dispara el cañón de suero (en arco) y el lanzarredes contra una pared o el suelo.
   ✅ El cañón hace su arco de caída y la red sale como antes, con sus efectos de siempre.
5. [ ] Dispara a una pared curva o a un terreno irregular, si el mapa tiene alguno.
   ✅ La marca se pega a la superficie: no flota ni se ve rara.
6. [ ] Con el juego en Play y un impacto ya hecho, borra la carpeta `AbilityFx` del cliente (la de efectos) y dispara de nuevo.
   ✅ Si el juego vuelve a crear la carpeta, los emisores de chispas y polvo se recrean con ella y el impacto vuelve a salir con chispas y polvo, sin errores en consola.

**Un jugador en Play (Isla, Dunas y Lobby):**

1. [ ] En la Isla, dispara la honda o el arco a un mono.
   ✅ Salen 3, 6 o 10 cubitos amarillos según la calidad de efectos (Ajustes), que salen hacia fuera del tirador, es decir, en la dirección de la bala. Desaparecen en menos de 0,9 s y no queda ninguna marca ni chispa sobre el mono.
2. [ ] En la Isla, usa una habilidad y pega con un arma a distancia a un jefe o a un muñeco de práctica.
   ✅ Las habilidades y los jefes conservan sus efectos de siempre. La habilidad no deja marca ni chispas de bala.
3. [ ] Haz una ráfaga de dardos contra una pared y el suelo, con la calidad de efectos en Bajo, después en Medio y en Alto (Ajustes), en la Isla, en Dunas, en el Lobby y en el Laboratorio.
   ✅ Como mucho 15 marcas en Bajo, 35 en Medio y 60 en Alto a la vez en cada cliente. Al llegar al tope, las marcas nuevas reemplazan a las más viejas y no se crean piezas nuevas. Sin errores en consola.

**Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio):**

1. [ ] Con el otro jugador delante, dispara un arma a distancia a su cuerpo.
   ✅ Salen cubitos amarillos de pulpa del cuerpo alcanzado, en la dirección de la bala, alejándose del tirador. No quedan marcas ni chispas sobre el cuerpo.

**En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶):**

1. [ ] Con 10 tiradores disparando a ráfaga contra una pared, con la calidad de efectos en Alto, mira los FPS.
   ✅ Los FPS se mantienen estables durante la ráfaga, sin caídas sostenidas.

Nota: lo ya probado en Studio (Laboratorio, un jugador: 12 disparos contra una pared dan 12 marcas, un solo grupo de emisores y ninguna pieza «Ring» (antes unas 28 por impacto); sin errores en consola; la pulpa sale en 3/6/10 cubitos amarillos por calidad y desaparece en menos de 0,9 s sin marcas ni chispas en cuerpos; `Rendimiento` sección 10: 36/56/81 piezas frente a topes 40/90/160, sin alertas) no se repite aquí.

## 80. Fase 19 W6: zonas por piezas, rebobinado de pose y ayuda de puntería (29-10-2026)

**Dos jugadores (*Test → Clientes y servidores*, 2 clientes, en el Laboratorio y en Dunas):**

1. [ ] Con el otro jugador quieto delante, dispara el lanzadardos a su cabeza, a su torso y a un brazo.
   ✅ La cabeza sale con el aviso Head y ×1,3, el torso con Body y ×1, y el brazo con Limb y ×0,8.
2. [ ] Dispara el rifle a su cabeza y a su torso.
   ✅ La cabeza hace el doble (×2) con el aviso Head, y el torso sale con Body y ×1.
3. [ ] Dispara el cañón de suero (en arco) a su cabeza y a su brazo.
   ✅ Sin zonas: el mismo daño en la cabeza que en el brazo, y no sale ni Head ni Limb.
4. [ ] Derriba al otro jugador de un disparo a la cabeza.
   ✅ Aparece el aviso Kill y el otro jugador cae.
5. [ ] Con el otro jugador en guardia o en parry, dispara a su cuerpo.
   ✅ Aparece el aviso Blocked y el golpe queda anulado. Si en el Laboratorio no hay guardia, pruébalo en la Isla (grupo siguiente).
6. [ ] En Dunas, dispara el arpón a la cabeza del otro jugador y después a un brazo.
   ✅ La cabeza hace ×1,5 con el aviso Head. El brazo hace el daño normal (×1) con el aviso Limb, no ×0,8.
7. [ ] Con el lag simulado en tu cliente (*Test → Incoming replication lag*, 150 ms), haz que el otro jugador corra en círculo y dispara a su cabeza donde estaba hace 0,15 a 0,3 s.
   ✅ El golpe cuenta en la cabeza donde estaba al disparar, con el aviso Head, aunque en tu pantalla ya no esté allí.
8. [ ] Con el mismo lag, el otro jugador corre a un lado y tú disparas a su brazo tal como lo ves.
   ✅ El impacto cuenta con la pose que él tenía al disparar, sin fallar por la pose actual.
9. [ ] El otro jugador apunta con el arma (manos extendidas, pose de apuntar) y tú disparas a sus manos.
   ✅ El golpe cuenta como brazo (aviso Limb). La pose de apuntar es alcanzable: las manos no quedan fuera de la hitbox.

**Dos jugadores en la Isla (*Test → Clientes y servidores*, 2 clientes, PvP opt-in activado en los dos):**

1. [ ] Con la honda o el arco, dispara a la cabeza del otro jugador y después a su cuerpo.
   ✅ El rival recibe daño con normalidad: la cabeza con el aviso Head y ×1,5, y el cuerpo con Body y ×1.
2. [ ] Con el otro jugador en guardia o en parry, dispara a su cuerpo con la honda o el arco.
   ✅ Aparece el aviso Blocked y el golpe queda anulado.

**Un jugador en Play (Laboratorio, muñecos de práctica):**

1. [ ] Apunta el rifle o el lanzadardos a un punto justo al lado de la cabeza de un muñeco, sin tocarla, y dispara.
   ✅ La bala va donde apuntas. En el Laboratorio no hay ayuda de puntería y el disparo no se corrige hacia la cabeza.

**Un jugador en Play (muñeco de sparring):**

1. [ ] Deja el palo en reposo junto al brazo derecho del muñeco, después golpéalo con el palo.
   ✅ El palo no choca con el brazo derecho, ni en reposo ni al golpear.

**Un jugador en Play (Isla y Dunas, con ayuda de puntería):**

1. [ ] Con la honda o el arco, apunta a un lado del cuerpo de un mono, sin tocar la cabeza, y dispara.
   ✅ La bala engancha al punto del mono más cercano a la línea de tiro, y no se va a la cabeza.
2. [ ] Apunta justo entre dos monos (o dos muñecos) separados, y dispara.
   ✅ La bala pasa entre ellos y no engancha a ninguno.
3. [ ] En Dunas, repite el paso 1 con un muñeco de práctica.
   ✅ Igual que en la Isla: engancha al punto más cercano y no se come la cabeza.

**Un jugador en Play (Isla, monos y habilidades):**

1. [ ] Con la honda, dispara a la cabeza de un mono, después a su cuerpo y después a una pata.
   ✅ La cabeza suma ×1,5. El cuerpo cuenta ×1, y la pata también ×1: nunca cuenta como extremidad.
2. [ ] Dispara a la cabeza de monos distintos con el arco, el bastón y la cerbatana.
   ✅ Cabeza ×1,75 con el arco, ×1,25 con el bastón y ×1,3 con la cerbatana.
3. [ ] Usa una habilidad contra un mono y pega cuerpo a cuerpo a su cabeza.
   ✅ Ni la habilidad ni el golpe cuerpo a cuerpo usan zonas: el daño es el de siempre, sin multiplicador de cabeza.

**Un jugador en Play (Lobby, muñecos del Lobby):**

1. [ ] Dispara el lanzadardos a la cabeza de un muñeco del Lobby.
   ✅ Sale el aviso Head.

**Un jugador en Play (Isla, jefes):**

1. [ ] Ataca al Orangután en la gema azul bajo la barbilla.
   ✅ Sale el aviso Weak y el golpe hace ×1,5. La gema se ve de frente y de lejos en todas las fases.
2. [ ] Ataca al Chimpancé en el medallón dorado.
   ✅ Sale el aviso Weak y el golpe hace ×1,5. El medallón se ve de frente y de lejos en todas las fases.
3. [ ] Ataca al Gorila Albino en el cristal cian del pecho.
   ✅ Sale el aviso Weak y el golpe hace ×1,5. El cristal es cian (antes era rojo) y se ve de frente y de lejos en todas las fases.
4. [ ] Ataca al Gorila de Ceniza en su núcleo de lava blanco incandescente.
   ✅ Sale el aviso Weak y el golpe hace ×1,5. El núcleo se ve de frente y de lejos en todas las fases.
5. [ ] En la fase 3 del jefe con la gema de garganta, mira la gema (ThroatGem) mientras el jefe mueve la barba.
   ✅ La gema no flota y no se corta con la barba.
6. [ ] Mira el medallón (Medallion) del Chimpancé cerca del collar y de la pintura.
   ✅ El medallón no choca con el collar ni con la pintura.
7. [ ] Mira el núcleo de lava (LavaCore) del Gorila de Ceniza junto a las grietas de la arena.
   ✅ El núcleo no se confunde con las grietas.

**En el juego publicado (con amigos y ping real):**

1. [ ] Con un amigo en otra conexión, dispara a su cabeza mientras corre, con tu ping real de siempre.
   ✅ El golpe acierta donde estaba su cabeza al disparar, sin salto visible al llegar la confirmación.
2. [ ] En el Laboratorio, con 12 jugadores, 40 monos y 30 proyectiles en vuelo, mide `Projectiles.step` con el Microprofiler (*Ver → Microprofiler*).
   ✅ `Projectiles.step` tarda menos de 0,5 ms.
3. [ ] Tras publicar, en el Studio de la Isla, ejecuta `Equilibrio` y `Rendimiento` con las calculadoras de CLAUDE.md. (= §86 p1)
   ✅ Ninguna de las dos muestra alertas nuevas.
4. [ ] Tras jugar publicado, mira en *Creator Hub → tu experiencia → Analítica* los eventos `LimbShots` y `Headshots` (tarda unas horas, como en §6.3). (= §86 p2)
   ✅ Cuentan también los golpes a monos, jefes y muñecos de práctica, no solo a jugadores.

Nota: lo ya probado en Studio (Laboratorio, un jugador: `Hitbox.sweepBodies` da Head, Torso, Limb o Weak por pieza —cabeza, torso, brazos, manos, piernas y pies—, con y sin rebobinado; el rebobinado acierta la cabeza donde estaba hace 0,15-0,3 s y sin rebobinar falla; un dardo contra muñeco hace 7 al torso, 9 a la cabeza (×1,3) y 6 al brazo (×0,8), con el ×0,7 de daño a no jugadores, y el tirador recibe el aviso Head, Limb o Body; `Equilibrio` secciones 12 y 14 sin alertas nuevas; `Rendimiento` sin alertas: jefes con 35, 27, 24 y 30 piezas frente a topes de 35, 30, 30 y 30) no se repite aquí.

## 81. Fase 19 W7: apuntar de verdad (ADS) y cámara al hombro (29-10-2026)

**Un jugador en Play (Isla y Dunas, en PC, con arco, bastón o cerbatana en la mano):**

1. [ ] Mantén el clic derecho.
   ✅ El FOV baja a 55 en unos 0,15 s y la cámara pasa al hombro derecho. El ratón queda bloqueado en el centro de la pantalla y el personaje mira al centro.
2. [ ] Suelta el clic derecho.
   ✅ Todo vuelve: FOV normal, cámara detrás del personaje y ratón libre.
3. [ ] Mantén el clic derecho y muere.
   ✅ Al morir, todo vuelve a la normalidad (FOV, cámara, ratón y giro del personaje). Al reaparecer no quedas apuntando.
4. [ ] Mantén el clic derecho y desequipa el arma.
   ✅ Todo vuelve a la normalidad.
5. [ ] Mantén el clic derecho y abre el menú de Roblox (Esc).
   ✅ Todo vuelve a la normalidad mientras el menú está abierto.
6. [ ] Mantén el clic derecho y abre un TextBox (el chat de Roblox).
   ✅ Todo vuelve a la normalidad mientras escribes.
7. [ ] Pon el zoom de la rueda al máximo (primera persona) y mantén el clic derecho.
   ✅ No hay desplazamiento de cámara al apuntar.
8. [ ] Siéntate, o móntate en una montura en la Isla, y mantén el clic derecho.
   ✅ La cámara al hombro no se activa mientras estás sentado o montado.

**Un jugador en Play (Isla y Dunas, disparo a la cadera y apuntando):**

1. [ ] Sin apuntar, dispara varias veces con el arco a un mismo punto a 15 o 30 studs.
   ✅ Los impactos se reparten en un cono de unos 1,5°. La bala que ves es la misma que cuenta en el servidor, y no aparece ninguna corrección visible al llegar la confirmación.
2. [ ] Mantén el clic derecho y dispara varias veces al mismo punto.
   ✅ Sin dispersión: todos los disparos caen en el mismo punto, sin corrección visible al llegar la confirmación.
3. [ ] Apunta con la mira en el centro a un mono o a un muñeco de práctica a poca distancia, y dispara.
   ✅ La bala converge donde marca la mira, sin desviarse hacia otro lado.
4. [ ] Haz un remate de cadena.
   ✅ La cámara tiembla como antes (ahora con `CameraShake.play`).

**En el teléfono (elige uno en *Prueba → Dispositivo* antes del ▶):**

1. [ ] En la Isla, Dunas y el Lobby, busca el botón «Mira» en la casilla (0,3) de la rejilla de botones.
   ✅ Está en esa casilla sin chocar con otros botones. Tocarlo entra en el apuntado y tocarlo otra vez sale.
2. [ ] En el Laboratorio, busca el botón «Mira».
   ✅ Sigue en la casilla (0,1) y funciona igual.
3. [ ] Con un mando conectado, mantén L2 en la Isla y en el Laboratorio.
   ✅ Apunta igual que con el clic derecho (FOV y, en la Isla y Dunas, cámara al hombro) y vuelve al soltar.

**Un jugador en Play (Laboratorio):**

1. [ ] Apunta con cada una de las 4 armas del Laboratorio y mira el FOV.
   ✅ Cada arma baja a su FOV de apuntado: 55, 30, 60 y 60 (comprueba el valor de cada una en `Data/LabWeapons`).
2. [⏭] Con el arma en primera persona, apunta y suelta. ⏭️ Superado por §87: la posición del arma al apuntar cambió.
   ✅ La posición del arma cambia hacia el centro al apuntar y vuelve al soltar, con la misma transición de siempre (`aimAlpha`).
3. [ ] Apunta con el rifle exacto y dispara a un muñeco a distancia.
   ✅ La bala sale justo donde marca la mira, sin dispersión.
4. [ ] Apunta con los dardos y con el arpón, y dispara varias veces al mismo punto.
   ✅ Los impactos caen mucho más juntos que a la cadera (`adsSpreadFactor` 0,35).
5. [ ] Apunta y suelta con la mira dinámica y el cargador a la vista.
   ✅ La mira y el cargador responden al apuntar y vuelven al soltar (`LabAmmoHUD` usa `isAiming`).
6. [ ] Apunta con cualquier arma.
   ✅ La cámara no se va al hombro: el Laboratorio no carga `ShoulderAimController`.

**Un jugador en Play (comprobación de seguridad, aceptada):**

1. [ ] Con un cliente que dice apuntar siempre (`zoomed = true`), dispara a la cadera varias veces al mismo punto.
   ✅ La dispersión es 0, igual que con el rifle. Es el comportamiento aceptado.

**Calculadora `Equilibrio` (Studio de la Isla, modo edición):**

1. [ ] Ejecuta `Equilibrio` con el informe por defecto.
   ✅ En la sección 14, la tabla «Dispersión a la cadera» tiene 12 armas: 100 % de acierto a 15 y 30 st, 58 % a 60 st y 21 % a 100 st. La sección «Alertas» no muestra nada nuevo.
2. [ ] Ejecuta `Equilibrio` con `informe({ secciones = { laboratorio = true } })`.
   ✅ En la sección 12, la tabla «Precisión apuntando» aparece para las armas del Laboratorio, con los dardos y el arpón multiplicados por `adsSpreadFactor`, y no hay alertas nuevas.

Nota: lo ya probado en Studio (solo carga y `Equilibrio`: la tabla «Dispersión a la cadera» de la sección 14 salió sin alertas) no se repite aquí.

## 82. Fase 19 W8: miras por tipo de arma (29-10-2026)

**Un jugador en Play (Isla y Dunas, con ratón, arco, cerbatana, bastón y honda):**

1. [ ] Con el arco, mantén el clic derecho.
   ✅ Aparece la mira de hierro: un poste y una muesca, separados unos 10 px. Al soltar vuelve la mira normal.
2. [ ] Con la cerbatana, mantén el clic derecho.
   ✅ Aparece la misma mira de hierro (poste y muesca, 10 px de separación).
3. [ ] Con el bastón, mantén el clic derecho y apunta a un muñeco de práctica o a un mono a poca distancia.
   ✅ Aparece una recta que llega hasta el punto donde cae el remate, y un anillo de radio 6 studs alrededor de ese punto.
4. [ ] Con la honda, sin apuntar.
   ✅ Se ve la mira normal, con el tamaño y el estilo que tengas en *Ajustes del jugador*.
5. [ ] Con la honda, mantén el clic derecho.
   ✅ Aparece el punto rojo en el centro (mira RedDot) y la mira normal desaparece.
6. [ ] Con la honda, suelta el clic derecho.
   ✅ El punto rojo desaparece y vuelve la mira normal con el mismo ajuste del paso 4.

**Un jugador en Play (Isla y Dunas, cursor libre, sin bloqueo de cámara):**

1. [ ] Con el ratón libre, mantén el clic derecho con un arma a distancia.
   ✅ La transición de apuntado (`aimAlpha`) sube hasta el final y la mira del arma aparece donde apunta `Aim` (parámetro `center`), no necesariamente en el centro de la pantalla.

**Un jugador en Play (Isla y Lobby, sin apuntar):**

1. [ ] En la Isla y en el Lobby, lleva un arma a distancia en la mano sin apuntar.
   ✅ Aparece la mira del arma y el icono del ratón queda oculto.
2. [ ] En el Lobby, acércate a los muñecos de práctica con el arma a distancia y apunta hacia ellos.
   ✅ La mira no tapa ni estorba a los muñecos, y los disparos y clics llegan igual. Si la mira molesta, anótalo.
3. [ ] En la Isla, guarda el arma.
   ✅ La mira desaparece y vuelve el icono del ratón.

**En el teléfono y con mando (Isla o Dunas, arco o honda):**

1. [ ] En el teléfono (*Prueba → Dispositivo*), con un arma a distancia en la mano, mira la pantalla.
   ✅ La mira está en el centro de la pantalla.
2. [ ] En el teléfono, toca «Mira».
   ✅ Entra en el apuntado con la mira del arma en el centro. Tocarlo otra vez sale.
3. [ ] Con un mando, mantén L2.
   ✅ Aparece la mira del arma en el centro, y al soltar vuelve la mira normal.

**Un jugador en Play (Laboratorio, con las 4 armas):**

1. [ ] Con el rifle, mantén el clic derecho (o L2, o «Mira» en el teléfono).
   ✅ Aparece la mira de visor (Scope): viñeta a opacidad 0,85 alrededor de un hueco circular. El arma de la vista se esconde mientras apuntas, y el hueco es circular, sin recortes en las esquinas. Si el `UIStroke` grande falla y el hueco se recorta, aplica el plan B (franjas con cuerdas).
2. [ ] Con el lanzadardos, mantén el clic derecho.
   ✅ Aparece el punto rojo (RedDot).
3. [ ] Con el arpón, mantén el clic derecho.
   ✅ Aparece la mira de hierro (Iron): poste y muesca, 10 px de separación.
4. [ ] Con el cañón, mantén el clic derecho y dispara a un punto lejano.
   ✅ La mira Arc dibuja la parábola y la bola real del servidor cae donde marca la parábola. El cliente parte de la boca de la herramienta y el servidor de `Aim.origin`: si hay un desvío visible, anótalo con la distancia aproximada.
5. [ ] Con cualquier arma del Laboratorio, apunta con la mira de arma y acierta a un muñeco.
   ✅ El hitmarker sale donde se apunta, también con la mira de arma. Si no sale, revisa el atributo `SightCovers` del `ScreenGui` «Mira».

**Un jugador en Play (rendimiento del arco):**

1. [ ] Con el arco, apunta y dispara varias veces seguidas, y mira el MicroProfiler.
   ✅ La mira del arco usa un pool fijo de 16 `Frame`. El número no sube al apuntar ni al disparar, y no hay `Instance.new` por fotograma en la mira.

Nota: lo ya probado en Studio (solo la honda en la Isla: punto rojo al apuntar con clic derecho, FOV 55, cámara al hombro y todo vuelve al soltar) no se repite aquí.

## 83. Fase 19 W9: killfeed (29-10-2026)

**Un jugador en Play (Dunas, con el botón «☠️ Bajas falsas en el registro» del panel de pruebas):**

1. [ ] En Dunas, pulsa el botón de bajas falsas sin argumento.
   ✅ Salen 3 filas arriba a la derecha, debajo del marcador de Dunas y del emote, sin tapar nada ni chocar con `ArenaHUDController`. La primera es tu baja en la cabeza sobre «Rival», la segunda es «Rival» te mata con el icono genérico y la tercera dice que derrotas a Gorila Plateado.

**Un jugador en Play (Laboratorio, con las 4 armas):**

1. [ ] En el Laboratorio, con el rifle en la mano, pulsa el botón de bajas falsas.
   ✅ Salen las 3 filas debajo del marcador y del emote, sin chocar con `LabHUDController`. La fila de la baja en la cabeza lleva el icono del rifle en el `ViewportFrame` de 28 px, reconocible y sin cortarse.
2. [ ] Repite con el lanzadardos, el arpón y el cañón, una vez con cada uno.
   ✅ Cada fila muestra su arma (no el icono genérico) en el `ViewportFrame` de 28 px, con la orientación de la mano. Si alguno sale cortado o del revés, anota el nombre del arma.

**Dos jugadores (*Test → Clientes y servidores*, 2 clientes):**

1. [ ] En Dunas, mata a tu rival en PvP.
   ✅ La baja sale en el registro de los dos clientes, con el nombre del asesino y de la víctima. En cada cliente, la fila donde ese jugador es asesino o víctima sale resaltada en tono cálido, y las demás no. Los nombres salen con el color de su equipo (`Player.Team`).
2. [ ] En el Laboratorio, mata a tu rival por equipos.
   ✅ La baja sale en los dos clientes, con el mismo resaltado del paso anterior. Los nombres deberían salir con el color de su equipo; en el Laboratorio puede salir blanco, anótalo.
3. [ ] En la Isla, con el PvP activado (opt-in), mata a tu rival.
   ✅ La baja sale en los dos clientes.
4. [ ] Desde los dos clientes a la vez, pulsa bajas falsas con `spam` (paso 3 de «Con argumento», en la Isla).
   ✅ Llegan al registro como máximo 10 avisos por segundo y el resto se descarta. Anota cuántas filas ves en el primer segundo.
5. [ ] Tras cualquier baja, no toques nada y espera.
   ✅ Cada fila se desvanece a los 5 s y desaparece.

**Baja de jefe real (Isla, 2 jugadores):**

1. [ ] Con 2 jugadores, A y B golpean al mismo jefe y A le da el último golpe. Cuando cae, mira el registro en los dos clientes.
   ✅ Sale una fila con A como asesino y el nombre del jefe como víctima, en los dos clientes. El asesino es quien dio el último golpe (`BossService.lastAttacker`).
2. [ ] Con A dando el último golpe, cierra el cliente de A antes de que caiga el jefe.
   ✅ La fila sale en el cliente de B como «<jefe> ha caído», sin asesino.

**En el teléfono (Isla, *Prueba → Dispositivo*):**

1. [ ] Pulsa bajas falsas sin argumento y deja que se acumulen filas.
   ✅ Las filas son compactas: icono al 75 % y texto de 13. La columna se desplaza 170 px.
2. [ ] Con el reloj y los avisos de la Isla en pantalla, y el panel de pruebas abierto, mira la columna.
   ✅ La columna no choca con el reloj, con los avisos ni con el panel de pruebas.

**Un jugador en Play (Isla, con las armas de la Isla):**

1. [ ] Con el arco en la mano, pulsa bajas falsas sin argumento.
   ✅ La fila de la baja en la cabeza lleva el icono del arco, reconocible.
2. [ ] Repite con el bastón, la cerbatana y la melé, una vez con cada una.
   ✅ Cada arma se reconoce en su icono, y las cuatro se distinguen entre sí. Si una se confunde con otra, anótalo.

**Con argumento (Isla, consola de Play; el botón no manda argumento):**

1. [ ] Dispara `Remotes.DebugCommand:FireServer("FakeKill", "head")`.
   ✅ Sale una sola fila: tu baja en la cabeza sobre «Rival».
2. [ ] Dispara `Remotes.DebugCommand:FireServer("FakeKill", "boss")`.
   ✅ Sale una sola fila de jefe: tu nombre y «derrota a Gorila Plateado».
3. [ ] Dispara `Remotes.DebugCommand:FireServer("FakeKill", "spam")`.
   ✅ Salen 5 filas (el tope de la columna), no 6.

Nota: las muertes por mono o por entorno no salen en el registro (decisión de diseño). Lo ya probado en Studio (solo la Isla con 1 jugador: `FakeKill` sin argumento muestra 3 filas, y «spam» deja 5 filas, el tope) no se repite aquí.

## 84. Fase 19 W10: rig de brazos en primera persona del Laboratorio (29-10-2026)

**Publicación (el usuario, en el Studio de la Isla):**

1. [x] (Hecho el 29-10-2026: los 20 ids están pegados en `Data/ViewModelAnimations`; en Play en el Lab cargan Aim y Fire con peso 1 al disparar.) Guarda el place de la Isla y publica las 20 secuencias `<Arma>_<Clave>` (LabDartGun, LabBananaRifle, LabNetHarpoon y LabAcidCannon, cada una con Aim, Fire, Reload, Sprint y Equip) con el mismo dueño que el juego (clic derecho → Guardar en Roblox). Pasa los 20 ids para pegarlos en `src/shared/Data/ViewModelAnimations.luau`.
   ✅ Las 20 secuencias tienen id publicado. Hasta pegarlos, el retroceso, la recarga y el desenfundado siguen funcionando por código, y Aim y Sprint no hacen nada.

**En el Studio de la Isla (modo edición, revisión a ojo):**

1. [ ] Revisa las 20 tiras del `ViewModelAnimationBuilder` con la skill `animaciones-roblox`, y mira sobre todo la mano izquierda de Fire y Reload.
   ✅ La mano izquierda sigue sujeta al arma en Fire y en Reload. Si se separa, anota la tira y el arma.

**Un jugador en Play (Laboratorio, con los ids publicados y las 4 armas):**

1. [ ] Mantén el clic derecho con cada arma.
   ✅ La pose de apuntar entra con el peso de `aimAlpha`. En las 4 armas se ve la pose de Aim (capturas).
2. [ ] Mantén el clic derecho y dispara sin soltar, sobre todo con el lanzadardos.
   ✅ Los codos no saltan al pasar de Aim a Fire. Si saltan, anota el arma y la distancia del salto.
3. [ ] Dispara con el lanzadardos en ráfaga.
   ✅ La pista Fire dura como mucho la cadencia del arma (0,12 s en dardos) y no se corta a medias (capturas).
4. [ ] Recarga cada arma con cargador.
   ✅ La pista Reload dura lo que `reloadSeconds` de cada arma (se estira la pista), y al acabar vuelve la pose normal.
5. [ ] Corre con Shift y suelta.
   ✅ Sprint entra con un fundido de 0,15 s al empezar a correr (capturas).
6. [ ] Mientras corres, mantén el clic derecho con el rifle, y después recarga mientras corres.
   ✅ Sprint se corta al apuntar con el visor y al recargar, y pasa a la pose que toque.
7. [ ] Saca el arma con la tecla de equipar, o cambia de arma.
   ✅ Al sacar el arma se ve la pista Equip una vez, y no hay un salto de pose al terminar.
8. [ ] Dispara con cada arma, con su pista Fire ya publicada, y mira el retroceso.
   ✅ El retroceso se ve una sola vez. No se suma el retroceso por código al de la pista: si se ve doble, anótalo.
9. [ ] Con cada skin de bajas equipada en cada arma, mira las piezas de la mano mientras disparas y recargas.
   ✅ Las piezas de skin siguen en su sitio (WeldConstraint conservadas, recolocadas con delta) en las 4 armas y en cada skin, sin descolocarse al animar.
10. [ ] Dispara y mira el fogonazo.
    ✅ MuzzleSource y el fogonazo salen de la boca del arma (el `Muzzle` dentro del rig), no de otro punto.
11. [ ] Con el rifle, mantén el clic derecho para entrar en el visor.
    ✅ El visor esconde todo el rig (brazos y arma), y en el hueco del visor no se ve ningún brazo.

**En el teléfono (Laboratorio, *Prueba → Dispositivo*):**

1. [ ] Con un arma en la mano, dispara en ráfaga y recarga, con el rig animado en pantalla.
   ✅ No hay caídas de fotogramas apreciables al disparar ni al recargar. Si las hay, anota los fps y el arma.

Nota: lo ya probado en Studio no se repite aquí. En Play en el Lab: el rig se monta (`ArmaEnPrimeraPersona` con `AnimationController`, Motor6D RightShoulder, RightElbow, RightHand, LeftShoulder, LeftElbow, LeftHand y WeaponGrip, 97 descendientes con el arma), sin errores. En el Studio de la Isla: `ViewModelAnimationBuilder.build()` generó las 20 `KeyframeSequence` en `ReplicatedStorage.ViewModelAnimations`, y la tira de LabBananaRifle_Fire se ve bien (retroceso de 0,2 s). Rendimiento: «Brazos de la vista» 9 piezas de 40, sin alertas.
Nota (29-10-2026): con los ids pegados se comprobó en Play en el Lab que Aim (peso 0 sin apuntar) y Fire (peso 1 al disparar con el lanzadardos) cargan y suenan. Sin ver todavía: Reload, Sprint, Equip y las otras 3 armas.

## 85. Laboratorio: el combate dura 1,5 veces más (29-10-2026)

Cambio: vida 100 → 144 (`Config.Lab.Health`), regeneración 20 → 29 por segundo (`RegenPerSecond`, de 0 a llena en 5 s), rifle 45 → 48 de daño y arpón 35 → 36 (`Data/LabWeapons`). Con `Equilibrio` (sección 12) el tiempo medio de una pelea 1 contra 1 pasa de 2,285 s a 3,381 s (×1,48); sin alertas del Laboratorio con el nuevo objetivo de 2,25–4,5 s.

**Un jugador en Play (Laboratorio):**

1. [ ] Aparece con la barra de vida llena y mira cuánto vale (`humanoid.MaxHealth`).
   ✅ MaxHealth 144 y la barra de vida llena sin desbordar ni quedarse corta.
2. [ ] Hazte daño con los muñecos o el panel de pruebas y espera sin recibir daño.
   ✅ Empieza a curar a los 4 s y llega a llena en unos 5 s.

**Dos jugadores (un duelo de verdad, en Studio con 2 clientes o publicado):**

1. [ ] Duelo 1 contra 1 con la misma arma en las dos manos, a su distancia, hasta que uno cae.
   ✅ Una pelea dura de media unos 3,4 s (entre 2,5 y 4,5 s a la distancia buena del arma), no 2,3 s como antes. Anota la media de 10 duelos.
2. [ ] Repite con el rifle, el lanzadardos, el arpón y el cañón.
   ✅ El rifle sigue matando en 3 disparos al torso, el arpón en 4, y ninguna arma se siente inútil ni pesada de más frente a las demás.
3. [ ] Mira si, con peleas de 3,4 s, retirarse y curarse sigue valiendo.
   ✅ Con 29 de regeneración por segundo tras 4 s sin recibir daño, escapar vale la pena; si no, sube la regeneración o baja `RegenDelaySeconds`.

## 86. Fase 19 W11: ruta de la prueba publicada (29-10-2026)

Esta sección no añade pasos nuevos: ordena los de §74–§85 por sesión de prueba, para recorrerlos de una vez con el juego publicado. Marca cada paso en su sección de origen y anota aquí lo que falle (arma, place, dispositivo, número) para ajustar después.

**Antes de empezar (el usuario):**

1. [ ] Guarda los 4 places con Rojo sincronizado y publícalos. Los ids de `Data/WeaponAnimations` (22) y de `Data/ViewModelAnimations` (20) ya están pegados.
   ✅ El juego publicado carga sin avisos de `ContentId … failed` al usar las armas (§75, «Publicado», paso 3).
2. [ ] Haz copia del perfil en `PlayerData_v1_backups` si vas a probar en Studio.
   ✅ Copia hecha.

**Sesión A: 2 a 10 jugadores, publicado (un grupo en el Laboratorio, otro en Dunas y la Isla):**

- Pose replicada, disparo sin duplicar y arma al derecho: §75 («2 jugadores»), §77.
- Hitmarkers, «tac», «dink», «pop» y ráfaga con tope de avisos: §76.
- Bala inmediata, un solo proyectil y un solo fogonazo para el otro jugador: §78 («Dos jugadores»).
- Pulpa en el cuerpo alcanzado: §79 («Dos jugadores»).
- Zonas, rebobinado con tu ping real y la prueba con 12 jugadores (`Projectiles.step` < 0,5 ms): §80 («Dos jugadores» y «Publicado»).
- Killfeed en los dos clientes, jefe real y límite de 10 avisos por segundo: §83.
- Duelos del Laboratorio (anota la media de 10): §85 («Dos jugadores»).

**Sesión B: un jugador, publicado:**

- Líneas blancas, ajuste «Líneas de velocidad» y embestida: §74.
- ADS, cámara al hombro y dispersión a la cadera (Isla y Dunas): §81.
- Miras por arma (Isla, Dunas, Laboratorio): §82.
- Rig de brazos con las 5 pistas de las 4 armas (Aim, Fire, Reload, Sprint y Equip) y las skins: §84.
- Vida 144 y regeneración 29 del Laboratorio: §85 («Un jugador»).
- Modelos de apuntado y vista a 0,7 (lanzadardos, lanzarredes y cañón, cada bando, skins): §87.

**Sesión C: teléfono (real o emulador) y mando:**

- Líneas y FPS: §74; botón «Mira» y L2: §81; mira en el centro y L2: §82; FPS con 10 tiradores: §79; killfeed compacto: §83; FPS del rig: §84; modelos de apuntado en el teléfono: §87.

**Al terminar (Studio de la Isla, modo edición):**

1. [ ] Ejecuta `Equilibrio` y `Rendimiento` con las calculadoras de CLAUDE.md. (= §80 p3)
   ✅ Ninguna muestra alertas nuevas.
2. [ ] Pasadas unas horas, mira `LimbShots` y `Headshots` en *Creator Hub → Analítica* (§80). (= §80 p4)
   ✅ Cuentan también monos, jefes y muñecos.

**Ratón fijo en el centro (corregido tras la prueba publicada):**

1. [ ] En el Lobby, la Isla y Dunas, con un arma a distancia, apunta con el clic derecho y cambia el bloqueo de cámara con Ctrl (o desde el menú de Roblox) varias veces, con el clic derecho mantenido y soltado.
   ✅ Al soltar el clic derecho el ratón queda libre o bloqueado según el bloqueo de cámara (Ctrl), nunca fijo en el centro sin poder soltarlo.

**Vigilar (visto en la prueba publicada, sin causa conocida):**

1. [ ] El lanzadardos no hizo daño en una partida publicada del Laboratorio (ni con mira ni sin ella) y después volvió a funcionar sin cambios de código. Si vuelve a pasar, anota el hitmarker (¿sale?), el blanco (jugador o muñeco), la consola del servidor (F9) y si el servidor era recién abierto o venía de una versión anterior.
   ✅ El lanzadardos hace daño siempre, en servidores nuevos y antiguos.
2. [⏭] En primera persona del Laboratorio, mira cuánto se ve de cada arma con la mira y el rig de brazos. ⏭️ Superado por §87: vista a 0,7 y modelos de apuntado.
   ✅ El lanzadardos, el lanzarredes y el cañón se ven tanto como el rifle; si tapan la vista, ajusta la escala o la posición de la vista (W10).

**Qué se ajusta según lo que falle (dónde se toca):**

- Dispersión o FOV de apuntar: `Data/LabWeapons` (`adsSpreadFactor`, FOV) y `Config` de combate a distancia.
- Líneas, FOV y sacudida: los valores de W1 en `Config`.
- Marcas, polvo y pulpa en el teléfono: topes por calidad en `Config.Budgets` (15, 35 y 60 marcas).
- Combate del Laboratorio (duración, regeneración): `Config.Lab.Health`, `RegenPerSecond`, `RegenDelaySeconds` y el daño en `Data/LabWeapons`; remide con `Equilibrio`, sección 12.
- Una pose o una pista del rig que falle: se rehace con la skill `animaciones-roblox` y el usuario la vuelve a publicar.


## 87. Fase 19 W11: modelos de apuntado y vista más pequeña en primera persona (29-10-2026)

Cambio tras la prueba publicada (las armas se veían como un bloque enorme al apuntar): el lanzadardos, el lanzarredes y el cañón tienen un segundo modelo para apuntar (`Shared/LabAimModels`: cajón escalonado, placa trasera con la calavera de los Piratas o la franja azul de los Guardianes, visor, tambor, red, depósito), con las skins Avispa, Kraken y Dragón. El rifle sigue igual (visor). Las armas y los brazos de la vista miden `Config.Lab.ViewScale` = 0,7. Al apuntar ya no hay balanceo al andar ni la respiración de la pista Aim (parada en su primer fotograma), y la altura de la mira es `Config.Lab.AimViewOffset`.

**Un jugador en Play (Laboratorio, cada bando, con las 3 armas):**

1. [ ] Mantén el clic derecho con el lanzadardos, el lanzarredes y el cañón, y mira la vista.
   ✅ Se funde del arma de perfil al modelo de apuntado (a partir de un tercio del acercado) y se reconoce un arma real: cajón escalonado, visor, cañón y adornos del bando. Ya no sale un bloque enorme tapando la pantalla.
2. [ ] Con el lanzadardos apuntando, mira el marco del visor y el punto rojo.
   ✅ El punto rojo cae dentro del marco, en el centro de la pantalla.
3. [ ] Con el lanzarredes y el cañón apuntando, mira la boca del arma y la línea de la mira.
   ✅ Nada del arma cruza el centro de la pantalla (los pesos de la boca y la campana quedan por debajo de la mira).
4. [ ] Apunta andando, corriendo y esquivando.
   ✅ El arma no se mueve: ni balanceo, ni respiración, ni empujón de la esquiva. Sin apuntar, el balanceo al andar sigue.
5. [ ] Suelta el clic derecho.
   ✅ Vuelve el arma de perfil sin saltos.
6. [ ] En la vista de cadera, mira cada arma (también el rifle).
   ✅ Se ven un 30 % más pequeñas que antes y siguen bien sujetas por las dos manos. Si alguna pista (Fire, Reload, Equip, Sprint) se ve rara por la escala, anota cuál.
7. [ ] Con una skin de bajas de cada una (Avispa, Kraken, Dragón, grados I a III) y en cada bando, apunta.
   ✅ Se ven las bandas de colores y los adornos de la skin (ojos y alas de la Avispa, ventosas y tentáculos del Kraken, brasas, cuernos y alas del Dragón), y cada grado suma algo. Anota si la skin se confunde con la base.
8. [ ] Dispara apuntando y mira la trazadora y el fogonazo.
   ✅ Salen de la boca del arma de perfil (que no se ve), a pocos centímetros de la boca del modelo de apuntado.

**En el teléfono (Laboratorio, *Prueba → Dispositivo*):**

1. [ ] Apunta con las 3 armas.
   ✅ El modelo de apuntado se lee bien y no tapa la mira ni el botón «Mira».

**Calculadora `Rendimiento` (Studio de la Isla, sección 6):**

1. [ ] Ejecuta `Rendimiento` con la sección del Laboratorio.
   ✅ Las filas «apuntando» salen entre 28 y 50 piezas frente al tope `LabAimModel` (60), sin alertas.

Nota: lo ya probado en Studio (Play en el Laboratorio, Guardianes y Piratas: lanzadardos, lanzarredes y cañón apuntando con el modelo nuevo; la escala 0,7 aplicada al rig; `Rendimiento` sin alertas; vista previa de las skins Avispa III, Kraken III y Dragón III) no se repite aquí. Las poses de los brazos al apuntar no se han ajustado: son las de la pista Aim ya publicada, congelada.

## 88. Ruta de la prueba publicada con 2 jugadores (30-10-2026)

Esta sección no añade pasos: ordena los de las demás por sesión, para recorrerlos con el juego publicado y **2 cuentas** (A = tú, admin; B = el otro jugador, sin admin). Cada punto remite a la sección de origen (`§25 p1–6` = pasos 1 a 6 de §25). Marca los pasos allí, no aquí. Se saltan los `[⏭]`. Lo que falle se apunta en la tabla del final.

**Antes de empezar (A):**

- Guarda y publica los **4 places** con Rojo sincronizado (Lobby, Isla, Dunas, Laboratorio). Los ids de animaciones ya están pegados (§86).
- En 👑 Admin → 📋 Perfil → 📦 Hacer copia, en las dos cuentas si B es tuya.
- B, si puede, con Roblox en inglés y sin 👑 Admin: así salen los pasos de idioma (§19–§23) y los de «quien no es admin». Si B juega desde un teléfono, haz a la vez la fila «Móvil» de cada sesión.
- El panel 🛠️ Pruebas no existe en el publicado. Para jefes, gigante, clima, luna roja, mascotas, Doble Ámbar y mantenimiento usa 👑 Admin (§50).

**Sesión 1: Lobby y viajes (A y B, ~45 min)**

- Grupo, viaje juntos y servidores privados: §3.1 p4 (= §21.1 p1), §6.4 p3, §21.1.
- Cola 1v1 de Dunas y del Laboratorio con el contador 👤: §8.3, §26.1, §27.6 p4 y p6, §28.5 p2.
- Panel de admin sobre otro jugador y entre servidores (abre un segundo servidor): §13.2, §13.3, §50.1–§50.2, §41.1.
- Monturas vistas por el otro: §14.2, §15.3. LOD de lo de los demás: §43.3.
- Avisos y textos en dos idiomas: §19.2, §21.2 (el regalo con Robux de §12.3 p4 y §21.2 p1 es opcional: cuesta Robux reales).

**Sesión 2: Laboratorio 1v1 (~60 min)**

- Duelo por equipos y Rondas: §25.2, §27.2 p6–p11, votación de mapa y caída al vacío §28.2, recompensas y bajas por arma §29.2 p3–p4, §29.5 p2, §30.3.
- Lo que ve el otro jugador: pose, disparo, fogonazo y pulpa §75, §77, §78 («Dos jugadores»), §79 («Dos jugadores»), §53.2; deslizar, esquivar y andar §54.1, §32.6, §33.4, §35.4.
- Hitmarkers, zonas de daño y rebobinado con tu ping real: §76, §80 («Dos jugadores» y «Publicado» p1).
- Killfeed, killcam y espectador: §83, §40.1, §40.3. Arco de daño §34.1, §34.5. Ralentizar §31.3.
- **10 duelos con vida 144** y su media: §85 («Dos jugadores»).

**Sesión 3: Dunas 1v1 (~30 min)**

- Partida real: §8.2 p2–p7, §11.2, §11.3 p1–p11, §17.2. Bandera: §31.2, §32.2, §36.2 p10. Espectador: §40.1 p1, p4–p6. Montura: §31.5.
- Idioma: §22.3, §40.5.

**Sesión 4: Isla cooperativa, 2 de 5 (~60 min)**

- Roles y médico: §3.2 p7. PvP y cajas: §5.4, §80 («Isla PvP»).
- Parcela, cofre, huevo y «seguir sobreviviendo» con 2 jugadores: §18 (P1–P5, las partes de 2 jugadores), §18.3 (unirse a una partida terminada).
- Gigante y jefe (con 👑 Admin, alcance «Este servidor» y «Todos»): §49.1, §51.2 p1–p2, §52.2, §83 («Jefe real»), §44.3.
- Luna roja y fase lunar: §57 p1–p3, §56 p2. Idioma: §20.1.

**Sesión 5: cada uno por su cuenta, publicado (Pub-1; en paralelo o en otro momento)**

- Cámara, ADS, miras, rig de brazos, modelos de apuntado y vista a 0,7: la sesión B de §86 y §87.
- Ratón fijo en el centro: §86 («Ratón fijo»). Luz y luna: §55, §56. Mascotas nuevas con 👑: §58–§60.
- Combate de la Isla con monos reales: §11.1, §6.6. Lobby: §9, §3.5.
- Sin avisos `ContentId … failed` en la consola F9: §51.3 (= §75 «Publicado» p3), §35.3.
- Armaduras, armas y trajes rehechos (Visual): §62–§73, a ojo, con un avatar R6.

**Sesión 6: teléfono o mando (B o A, ~45 min)**

- La fila «Móvil» de cada bloque, sobre todo §74, §81, §82, §84, §87 (apuntar con «Mira» y L2), §32.4 (= §54.2), §28.4, §37.1–§37.2. Los pasos de «teléfono con varios jugadores cerca» (§65 p3, §69 p4, §71 p5, §72 p5, §73 p5) se hacen juntos con B cerca.

**Fuera de alcance con 2 jugadores (no se pueden probar ahora):**

- Más de 2: §8.2 p1, §11.3 p12, §25.2 p2 (fuego amigo), §26.3, §27.3, §27.6 p2, p3 y p5, §28.3, §29.2 p5, §40.1 p2, p3 y p7, §40.2 p1, p2, p5 y p6, §40.4 p2, §43.4, §51.2 p3, §79 («Teléfono», 10 tiradores), §80 («Publicado» p2, 12 jugadores).
- Solo Studio (panel 🛠️, atributos a mano, lag simulado, consola): `SkinKills` y bajas falsas (§45–§48 pasos 2–4, §83), el lag de §78, §81 «Seguridad», §57 p5 (Sky en Lighting), ⏩ Saltar fase. Quedan para una tanda de Studio con el `probador-studio`.
- Tiempo real: calendario de 7 días (§7.4 = §16.1), nido de 4–8 h (§7.1), analítica de Creator Hub (§6.3, §80 «Publicado» p4).

**Al terminar:** `Equilibrio` y `Rendimiento` en el Studio de la Isla (§86 «Al terminar»), y pásame la tabla. Los ajustes de números van por `Equilibrio` o `Economia`, y el dónde se toca está al final de §86.

**Registro de fallos** (copia una fila por fallo):

| § y paso | Place | Cuenta | Dispositivo | Qué esperabas / qué pasó | Consola (F9) |
|---|---|---|---|---|---|
| | | | | | |

## 89. El huevo mítico (30-10-2026)

Agrupado por cómo se prueba. Hace falta el Studio de la Isla abierto con Rojo en el 34873 (la parte A se midió el 30-10-2026 y pasó; quedan B y C) y, para lo último, el juego publicado.

**A. Studio de la Isla, modo edición** (clona la carpeta `Shared` antes de hacer `require`):

1. [x] 200.000 tiradas de `PetRoll.rollRarity(Random.new(1))`.
   ✅ Sale cada rareza cerca de común 55 · poco común 25 · raro 13 · épico 5,8 · legendario 1 · mítico 0,2 %. Con `Config.LiveEvents.EggLuckWeights`, el mítico sale cerca del 1 %.
2. [x] `PetRoll.petsOfRarity("Mythic")`, `PetRoll.rollPet("Mythic", Random.new(2))` y `PetRoll.mountsOfRarity("Mythic")`.
   ✅ Dan el Quetzal y el Ajolote, una de las dos, y el Quetzalcóatl. `petsOfRarity("Legendary")` sigue igual que antes.
3. [x] `PetRoll.rollMount("Mythic", {}, rng)` muchas veces.
   ✅ Sale el Quetzalcóatl la mitad de las veces (`Config.Mounts.EggChance`); la otra mitad, `nil` (sale mascota).
4. [x] `Config.Egg.HatchHours.Mythic`, `Config.Egg.DiscardAmber.Mythic` y `EggModel.palette("Mythic")`.
   ✅ 36, 500 y una paleta distinta de la común.
5. [x] Ejecuta `Economia` (`informe()`).
   ✅ No falla, la sección "Alertas" no tiene nada nuevo por el huevo mítico y el nido de la parcela no sube ningún huevo a mítico.

**B. Play en Studio** (haz copia del perfil antes, como en §0):

6. [ ] En 👑 Admin, regala un huevo Mítico y ponlo en el nido del Lobby.
   ✅ El huevo se ve rosa carmesí, la ficha del nido dice 36 h y, al abrirlo, sale el Quetzalcóatl o el Quetzal o el Ajolote. Si ya tienes lo que sale, recibes 1.000 de Ámbar.
7. [ ] Descarta un huevo mítico.
   ✅ Da 500 de Ámbar.

**C. Juego publicado, con 2 jugadores** (el mítico es de 0,2 %: usa "Suerte de huevo" o el panel para forzarlo):

8. [ ] En la Isla, un huevo mítico aparece con su aviso global en rosa carmesí y otro jugador lo ve igual.
   ✅ Se puede coger, cargar y defender como los demás.
9. [ ] En la lluvia de huevos del Lobby, con el evento activo.
   ✅ Puede caer un huevo mítico y cada jugador recoge el suyo.

## 90. Portadas e iconos con el equipo real (30-10-2026)

Hechas: la portada principal, el icono, Dunas y el Laboratorio (`art/portada/`, ver su README). Las fuentes: `src/island/tools/Portada.luau`, las fichas de `art/portada/ref/`, `prompts.md` y `titulo.py`. La escena grupal de `Portada.build("principal")` (volcán, cielo y rayos) está sin pulir y no se usa.

**A. En Creator Hub** (en tu cuenta):

1. [ ] Sube `portada-principal-1920x1080.png` como primera miniatura de la experiencia y `icono-512.png` como icono.
   ✅ En la página del juego el título se lee entero y el icono se reconoce en la lista de resultados y en el móvil.
2. [ ] Sube `portada-dunas-1920x1080.png` y `portada-laboratorio-1920x1080.png` como miniatura de sus places, si Creator Hub deja una por place.
   ✅ Cada una enseña su cinta ("DUNES ISLAND · PvP", "RUINED LAB · PvP").

**B. En Studio de la Isla, modo edición** (opcional, si cambias algún equipo):

3. [ ] `local P = require(game.ServerStorage.Tools.Portada:Clone()); P.ficha("Cazador")` y una captura con `P.vista("frente")`.
   ✅ El jugador se ve entero, con su arma de pie en la mano derecha; `P.clear()` lo quita y deja la iluminación como estaba.

## 91. Tráiler de YouTube: modo grabación y cámara de tomas (30-10-2026)

Herramientas del vídeo: el guion y la guía de grabación en `docs/videos/` (README y `trailer.md`, en español e inglés), `src/island/tools/Trailer.luau` (escenas `roles`, `jefes`, `huevo`, `mascotas`, `monturas` e `isla`), `src/island/tools/TrailerCamara.luau` (caminos y órbitas, sin dependencias del juego) y los botones **🎬 Modo grabación**, **🐵 Capuchino ladrón aquí**, **🌇 Time-lapse al atardecer** y **🌅 Time-lapse al amanecer** del panel 🛠️ Pruebas. Ya probado en el Studio de la Isla en modo edición: las escenas montan, la cámara avanza en edición y `Trailer.limpiar()` deja todo igual. También probado en Play: 🌇 Time-lapse (3 s de aviso, el reloj sube de 5,4 h a 19,1 h en 12 s y los atributos de la fase se restauran), 🌅 Time-lapse al amanecer (3 s de aviso, el reloj visual sube de 4,2 h a 7,6 h en 12 s con luz naranja, y vuelve a su hora; es solo visual: la fase real, los monos y el asedio no se tocan) y el modo grabación en la Isla, Dunas y el Laboratorio durante la grabación del 30-10-2026. Lo que sigue no se ha podido probar.

**A. Play en el Studio de la Isla** (con el panel 🛠️ Pruebas):

1. [ ] Entra en Play, abre 🛠️ Pruebas y pulsa 🎬 Modo grabación (sí).
   ✅ Desaparecen el HUD (también las líneas de estado como «Hay un huevo común en la isla»), la barra de Roblox y el cursor del ratón. El botón 🛠️ Pruebas sigue en pantalla y se puede pulsar aunque no se vea el cursor (abajo a la izquierda): en el montaje se recorta, no se oculta.
2. [ ] Con el modo activo, usa un botón del panel que haga aparecer un aviso del juego (por ejemplo 👑 Siguiente jefe).
   ✅ El aviso no se ve mientras dura el modo grabación.
3. [ ] Pulsa 🎬 Modo grabación otra vez.
   ✅ Vuelve todo como estaba: el HUD, la barra de Roblox y el aviso, que se ve si el juego lo quiere visible. Sin errores rojos en la Salida.

**B. Dunas y el Laboratorio** (cada place, con partidas reales y amigos):

4. [ ] Pega `TrailerCamara` por MCP en el Studio de Dunas y en el del Laboratorio, en modo edición. Después `local C = require(game.ServerStorage.Tools.TrailerCamara:Clone())`, `C.guia(true)`, un `C.camino({...}, 8, { cuentaAtras = 3 })` corto y `C.parar()`.
   ✅ La guía 9:16 aparece, la cámara recorre el camino en edición y `C.parar()` la deja en Fixed. El módulo carga sin errores en los dos places.
5. [ ] Graba con OBS, en una partida real de Dunas y otra del Laboratorio, al menos una toma con la cámara por camino (con la guía apagada).
   ✅ La toma sale a 1920×1080 sin el recuadro, sin texto de depuración y con los jugadores en el cuadro en el momento previsto. Si la cámara entra en una pared, ajusta los puntos del camino.

**C. Juego publicado** (Pub-1, después de publicar):

6. [ ] Pulsa Shift+P para activar la Freecam de Roblox y mueve la cámara.
   ✅ La cámara libre se mueve y la interfaz del juego (HUD, botones y carteles) se esconde.
7. [ ] Pulsa Shift+P otra vez.
   ✅ Vuelve la cámara del personaje y la interfaz, tal como estaba.

**D. Revisión a ojo** (Visual, en edición y en Run):

8. [ ] `Trailer.toma("mascotas")` en edición: mira el desfile en el travelling.
   ✅ Cada mascota se ve de frente en el plano. Si sale de lado, anótalo: hay que valorar girarlas (no es un fallo del código).
9. [ ] `Trailer.toma("isla")`: mira el vuelo bajo entre árboles.
   ✅ El tramo bajo pasa entre los árboles sin atravesar troncos ni copas. Si no cabe, sube el punto de cámara de la escena `isla` en `Trailer.luau`.
10. [ ] `Trailer.toma("monturas")`.
    ✅ El Quetzalcóatl y las demás monturas se ven enteras en el encuadre. Si una queda cortada o tapada, ajusta sus puntos de cámara.
11. [ ] `Trailer.toma("huevo")` en edición.
    ✅ Se ve el destello de `EggModel.burst`, pero no la cáscara que se abre (en edición no sale).
12. [ ] Repite `Trailer.toma("huevo")` en Run (F8).
    ✅ La cáscara se ve al romperse el huevo, con el destello.

**E. Montaje** (fuera de Roblox):

13. [ ] Graba la voz en español y en inglés de cada plano y monta las dos versiones con las mismas tomas.
    ✅ Las dos voces duran lo mismo que el montaje, y cada frase cae en su plano.
14. [ ] Recorta el 🛠️ Pruebas en las tomas de Studio y revisa la lista de comprobación de `docs/videos/README.md`.
    ✅ No se ve ningún botón, texto de depuración ni HUD de pruebas en el vídeo final.

**F. Botones de grabación de la Isla** (Play, 1J-Studio):

15. [ ] Pulsa 🐵 Capuchino ladrón aquí con una mascota activa y plátanos en la mochila, fuera del Basecamp.
    ✅ La mascota desaparece de la partida (no del perfil: al volver al Lobby sigue activa) y a los 2 s sale un capuchino ladrón a 14–45 studs, que va a por ti, te roba algo y huye. Dentro del Basecamp sale el aviso de que no hay sitio.
16. [ ] Pulsa 🌇 Time-lapse al atardecer de noche, y otra vez con uno ya en marcha.
    ✅ Sale el aviso "solo funciona de día y de uno en uno" y no cambia el reloj.

17. [ ] En el Laboratorio, pulsa 🎯 Muñecos delante en cada uno de los tres mapas (Laboratorio central, Azotea y Alcantarillas), con tu bando en cada lado.
    ✅ Los muñecos (15, 50 y 120 studs; si no cabe, más cerca) quedan sobre suelo y a unos pocos studs de tu altura: ninguno en el aire ni encima de la barrera invisible del borde, de la caseta ni de un saliente alto. Vuelve a pulsar y desaparecen. En las islas de la Isla, el Lobby y Dunas los muñecos de práctica siguen en el suelo como antes.

18. [ ] En Play de noche, pulsa 🌅 Time-lapse al amanecer, y otra vez con uno ya en marcha. Pulsa también ⏩ Saltar fase (Studio) o espera a que cambie la fase mientras corre.
    ✅ Tras 3 s el cielo pasa de noche azul a amanecer naranja y mañana en 12 s y vuelve a la hora real; el reloj del HUD y los monos no cambian. Con uno en marcha sale «El time-lapse ya está en marcha». Al volver, el atributo `DebugClock` del jugador desaparece (Explorer) y la luz sigue la partida.

## 92. Apuntar con la cámara libre (30-10-2026)

Se prueba en Play, con un arma a distancia, en la Isla y en Dunas (y en el Lobby con los muñecos).

1. [ ] Con la cámara sin bloquear, mantén el clic derecho y mueve el ratón.
   ✅ La cámara gira como siempre: sin zoom, sin cámara al hombro y el cursor no salta al centro. El personaje se vuelve hacia donde apunta el cursor y se ve la pose de apuntar. Al soltar, el personaje vuelve a girar solo.
2. [ ] Con el clic derecho mantenido, dispara con el clic izquierdo.
   ✅ Solo dispara el izquierdo, hacia el cursor (con la dispersión de cadera).
3. [ ] Bloquea la cámara (Ctrl) y mantén el clic derecho.
   ✅ Apunta como antes: zoom, cámara al hombro y ratón al centro. En el Laboratorio, igual que antes.

## 93. La mira en los Ajustes de la Isla y el Lobby (30-10-2026)

Se prueba en Play, en el Lobby (pestaña Ajustes) y en la Isla (botón ⚙️).

1. [ ] Abre Ajustes en el Lobby y baja hasta 🎯 Mira. Cambia estilo, color, tamaño, grosor y mira dinámica.
   ✅ La sección sale entre las estadísticas y las opciones; la vista previa cambia al momento y la mira del juego (con un arma a distancia) también.
2. [ ] Repite en el ⚙️ de la Isla.
   ✅ Lo mismo. La ventana cabe y, en el Lobby, se reparte en columnas sin cortar la sección.

## 94. Fase 20 Q1: calculadora de monos y precalentado de plantillas (03-11-2026)

Se prueba en Play en la Isla, con una copia de `PlayerData_v1` (como en §10.0). Los pasos de 94.2 van en un teléfono real o con 2 jugadores, y los de 94.3 en Studio, sin jugar.

### 94.1 En Play, en la Isla

1. [x] Antes de Play, copia `PlayerData_v1` en `PlayerData_v1_backups`. Pulsa ▶ Jugar en la Isla y mira la Salida desde el arranque hasta unos segundos después de `Start()`.
   ✅ No sale ningún aviso `[MonkeyModels]`, ni de "No se pudo precalentar".
2. [ ] Tras unos segundos, deja que aparezca el primer grupo de monos de una especie y, después, el de otra especie.
   ✅ La primera aparición de cada grupo no da tirón: `MonkeyModels.prewarm` ha llenado las plantillas. La Salida sigue sin avisos `[MonkeyModels]`.
3. [ ] En los primeros segundos tras `Start()`, mientras aún se llenan las plantillas, deja que aparezcan monos de varias especies y mira cómo se portan.
   ✅ `MonkeyService` sigue funcionando: los monos aparecen, se mueven y se pueden cazar sin errores. Si una plantilla se construye dos veces, no pasa nada: la Salida no muestra errores por ello.
4. [ ] Con el Play en marcha, abre Explorer, ve a `Workspace` › `Monos` y elige un mono real (no uno de práctica). Mira sus atributos.
   ✅ Tiene `DesignBlocks` (un número entero mayor que 0: los bloques de diseño antes de unir) y `UnionMs` (un número mayor que 0: los milisegundos que tardó la unión).
5. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`, como en §10.0.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 94.2 En teléfono o con 2 jugadores

1. [ ] En un teléfono real, o con 2 jugadores, entra en la Isla con unos 110 monos cerca del jugador y mide los FPS y la memoria con las estadísticas de Studio o del teléfono.
   ✅ Anota FPS y memoria como línea base de R7. No hay cifra de referencia todavía (la fija R7, pendiente), y no hay caídas ni errores en la Salida.
2. [ ] En el teléfono, dentro de la Isla, mira con las estadísticas de render cuántos triángulos dibuja el Terrain (el terreno) con la cámara en la vista del jugador.
   ✅ Queda anotada la cifra. `Rendimiento` no cuenta el Terrain, así que no hay tope: el dato sirve para fijar R7.
3. [ ] Con 2 jugadores en la Isla, invoca un jefe desde el panel de admin (fila «Jefe») mientras el otro jugador se mueve y ataca monos. Mide con un cronómetro cuánto tarda en aparecer el jefe desde que lo invocas.
   ✅ Aparece tras lo que tarde su unión: hoy 0,3–0,6 s. Mientras tanto, el otro jugador sigue moviéndose sin tirones y la Salida no muestra errores. Tras Q2 (jefe de 2.000 bloques de diseño) hay que repetirlo: se espera ~2 s, y los demás jugadores siguen sin congelarse.
4. [ ] En Dunas, con 2 o más jugadores (10 si se puede) y todos los trajes cerca de la cámara, mira los FPS y el recuento real de triángulos con Ctrl+Shift+F2 («Triangles»).
   ✅ Anota los FPS y los triángulos. Con los topes concedidos la estimación es ~810.000 y el tope de la escena es 650.000 (GDD §19.4). Si el recuento real pasa de 650.000, queda anotado para decidir el LOD de Dunas antes de seguir con Q6 y Q7.

### 94.3 Calibración de triángulos (en Studio, sin jugar)

Se prueba en Studio, en modo edición y en un place vacío, con la cámara mirando las piezas de frente. Cada cifra sale de las estadísticas de render (Ctrl+Shift+F2, «Triangles»): se anota con la escena vacía y con las 100 piezas en pantalla, y la diferencia entre las dos, dividida entre 100, son los triángulos por pieza. Si el modo edición no muestra el recuento, se hace en Play con la cámara quieta.

1. [ ] Pon 100 `Part` con forma de Ball (esfera) en pantalla, separadas para que no se toquen.
   ✅ Cada pieza queda a menos del 25 % de 224 (`LIMITES.triangulos.bola`). Si no, se ajusta esa constante en `Rendimiento.luau` y el valor medido se anota aquí.
2. [ ] Pon 100 `Part` con forma de Cylinder en pantalla, separados.
   ✅ Cada pieza queda a menos del 25 % de 64 (`LIMITES.triangulos.cilindro`). Si no, se ajusta la constante y se anota aquí.
3. [ ] Pon 100 bloques de 4x4x4 (`Part` Block) en pantalla, separados.
   ✅ Cada pieza queda a menos del 25 % de 12 (`LIMITES.triangulos.bloque`). Si no, se ajusta la constante y se anota aquí.
4. [ ] Pon 100 `WedgePart` (cuñas) en pantalla, separadas.
   ✅ Cada pieza queda a menos del 25 % de 8 (`LIMITES.triangulos.cuna`). Si no, se ajusta la constante y se anota aquí.
5. [ ] Pon 100 `CornerWedgePart` (cuñas de esquina) en pantalla, separadas.
   ✅ Cada pieza queda a menos del 25 % de 6 (`LIMITES.triangulos.cunaEsquina`). Si no, se ajusta la constante y se anota aquí.
6. [ ] Pon 100 bloques con un `SpecialMesh` de tipo Sphere en pantalla, separados.
   ✅ Cada pieza queda a menos del 25 % de 224 (`LIMITES.triangulos.mallaEspecial`). Si no, se ajusta la constante y se anota aquí.

## 95. Fase 20 Q2: Gorila de Ceniza con más calidad (03-11-2026)

Se prueba en Play en la Isla, con una copia de `PlayerData_v1` (como en §10.0). El jefe se invoca desde el panel de admin (fila «Jefe»). Las ascuas, el humo y la luz del pecho se quedan naranjas en las tres fases (solo cambian de color los bloques de lava y la cara): si desentonan en la fase 3, se recolorean en un grupo siguiente.

### 95.1 En Play, en la Isla (1 jugador)

1. [ ] Antes de Play, copia `PlayerData_v1` en `PlayerData_v1_backups`. Pulsa ▶ Jugar, invoca el Gorila de Ceniza y mide con un cronómetro cuánto tarda en aparecer.
   ✅ La primera vez tarda lo que su unión (~0,5 s) sin errores en la Salida; las siguientes veces aparece al instante (sale de la plantilla).
2. [ ] Pelea con él y bájale la vida hasta que pase a la fase 2 y luego a la 3.
   ✅ En cada fase cambia la cara (ceño, ojos con pupila y lágrimas, colmillos, rugido en la 3) y el color pasa de naranja (fase 1) a naranja rojizo (fase 2) y a rojo (fase 3) en las venas, las hombreras, el volcán y la piel de la cara. En la fase 3 el volcán del lomo entra en erupción. El color cambia sin parpadeos.
3. [ ] Rodéalo y míralo por detrás en las tres fases.
   ✅ Se ve el volcán de obsidiana con su cráter y coladas, las espinas del lomo, las placas de basalto y las venas de la espalda; la fase 3 se distingue de la 1 a primera vista.
4. [ ] Dispara o golpea el núcleo del pecho (`LavaCore`) y la cabeza.
   ✅ El pecho sigue siendo el punto débil y la cabeza cuenta como cabeza: los cuernos, las hombreras y los bloques nuevos no cambian las zonas de daño.
5. [ ] Mira cómo anda, embiste y pisa (`charge`, `stomp`).
   ✅ Los cuernos, las hombreras con pinchos, los brazales, las rodilleras y las garras se mueven con su parte, sin piezas sueltas ni flotando.
6. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`, como en §10.0.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 95.2 En teléfono o con 2 jugadores

1. [ ] Con 2 jugadores, invoca el Gorila de Ceniza mientras el otro se mueve y ataca monos, y repite el paso 1 de 95.1.
   ✅ Los demás jugadores no se congelan al construirse el jefe (~0,5 s), y los dos ven el mismo color en cada fase.
2. [ ] En un teléfono, mira al jefe a unos 30 studs en las tres fases.
   ✅ Los FPS no caen de forma apreciable frente a antes de Q2 (10.200–11.100 triángulos el jefe, antes 4.202). La fase 3 se sigue distinguiendo de la 1 a esa distancia.

## 96. Fase 20 Q3a: Gorila Albino con más calidad (03-11-2026)

Se prueba en Play en la Isla, con una copia de `PlayerData_v1` (como en §10.0). El jefe se invoca desde el panel de admin (fila «Jefe»). La luz y las chispas rojas de `BOSS_EXTRAS` no cambian de color con la fase.

### 96.1 En Play, en la Isla (1 jugador)

1. [ ] Antes de Play, copia `PlayerData_v1` en `PlayerData_v1_backups`. Pulsa ▶ Jugar, invoca el Gorila Albino y mide cuánto tarda en aparecer.
   ✅ La primera vez tarda lo que su unión (~0,5 s) sin errores en la Salida; las siguientes aparece al instante.
2. [ ] Pelea con él hasta la fase 2 y luego la 3.
   ✅ Los cristales de rubí crecen (pocos y apagados en la 1, racimos grandes en la 2, corona enorme en la 3); en la 2 salen venas de rubí desde el corazón y en la 3 también por flancos y espalda. Los ojos lechosos tienen la pupila de rubí cada vez más viva y la cara pasa de rosada a rojiza.
3. [ ] Rodéalo y míralo por detrás en las tres fases.
   ✅ Se ve la cordillera de roca y cristal del lomo, y la fase 3 se distingue de la 1 a primera vista.
4. [ ] Dispara o golpea el corazón cian (`CrystalCore`) y la cabeza.
   ✅ El pecho sigue siendo el punto débil y la cabeza cuenta como cabeza; las estalactitas, estalagmitas y cristales nuevos no cambian las zonas.
5. [ ] Mira cómo anda, embiste, pisa y ruge (`extinguish`).
   ✅ Las hombreras con estalactitas, los puños con estalagmitas y las garras se mueven con su parte, sin piezas sueltas.
6. [ ] Mira de cerca los ojos de la fase 1.
   ✅ Se leen pálidos (lechosos) con la pupila de rubí; si se ven demasiado rojos, se aclara el color de `ALBINO_EYE_COLORS`.
7. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 96.2 En teléfono o con 2 jugadores

1. [ ] Con 2 jugadores, invoca el Gorila Albino mientras el otro se mueve y ataca monos.
   ✅ Nadie se congela al construirse el jefe (~0,5 s), y los dos ven lo mismo en cada fase.
2. [ ] En un teléfono, mira al jefe a unos 30 studs en las tres fases.
   ✅ Los FPS no caen de forma apreciable (~13.200 triángulos sumando las tres fases, antes 1.664) y la fase 3 se distingue de la 1.

## 97. Fase 21 M1: Gorila Albino con mallas con textura (03-11-2026)

Las seis partes del cuerpo del Albino (torso, cabeza, brazos y piernas) son `MeshPart` con textura (`Data/BossMeshes`); el cristal, las venas, la cara y los ojos siguen siendo uniones. Se prueba en Play en la Isla, con una copia de `PlayerData_v1` (como en §10.0). Para invocar al Albino, el panel de pruebas tiene la fila «Jefe» (rota Orangután, Chimpancé, Albino, Ceniza: son 3 pulsaciones desde el principio).

### 97.1 En Play, en la Isla (1 jugador)

1. [ ] Antes de Play, copia `PlayerData_v1` en `PlayerData_v1_backups`. Invoca al Albino y mide cuánto tarda en aparecer.
   ✅ La primera vez tarda ~0,4–0,5 s y sin errores ni avisos «No se pudo cargar la malla» en la Salida; las siguientes veces sale al instante (plantilla).
2. [ ] Míralo de frente, por detrás y de lado en las tres fases (baja su vida con «Jefe herido»).
   ✅ El pelaje blanco tiene las manchas de los mechones pintadas (sin relieve), los cristales y las venas de rubí siguen creciendo por fase y la fase 3 se distingue de la 1 a primera vista, también por detrás.
3. [ ] Compara con el Gorila de Ceniza (aún con bloques) y con el Albino de antes.
   ✅ A 20–30 studs la textura se lee como pelo con manchas, sin verse borrosa ni a cuadros; de cerca (5–10 studs) se aprecia el difuminado del filtrado, que no molesta.
4. [ ] Mira cómo anda, embiste, pisa y ruge.
   ✅ Las seis mallas se mueven con su articulación sin piezas sueltas ni flotando; los cristales de los hombros y los puños caen sobre las hombreras y las estalagmitas de los brazos (señal de que el giro de la malla es el correcto en el brazo derecho y en el izquierdo).
5. [ ] Dispara o golpea el corazón cian (`CrystalCore`) y la cabeza.
   ✅ El pecho sigue siendo el punto débil y la cabeza cuenta como cabeza.
6. [ ] En el Studio, quita un id de `BossMeshes.luau` (por ejemplo el de la cabeza) y vuelve a invocarlo.
   ✅ Esa parte sale con bloques como antes y el resto con malla; sin errores. Devuelve el id.
7. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 97.2 En el juego publicado, con 2 jugadores y en teléfono

1. [ ] Publica la Isla y, con la opción de la experiencia de las APIs de malla e imagen **desactivada** (Game Settings → Security), invoca al Albino.
   ✅ Las mallas cargan igual (`CreateMeshPartAsync` con un id no depende de esa opción). Si no cargan, salen los bloques de antes y la Salida avisa: entonces la opción hay que dejarla activada.
2. [ ] Con 2 jugadores, uno de ellos entra después de que el Albino ya esté vivo.
   ✅ El segundo ve las seis mallas con su textura (no un patrón de cuadros) y los dos ven lo mismo.
3. [ ] En un teléfono, mira al Albino a unos 30 studs en las tres fases.
   ✅ Los FPS no caen frente al Albino de antes (3.800–5.900 triángulos visibles frente a ~9.000–11.000) y la textura no se ve a cuadros.

### 97.3 Gorila de Ceniza con mallas, y el Albino con la textura de 0,05 (Fase 21 M2)

Las seis partes del cuerpo del Ceniza son `MeshPart` (`Data/BossMeshes`); la lava, la piel de la cara y los ojos, que cambian con la fase, siguen siendo uniones. Mismo procedimiento que 97.1 (copia del perfil, Play en la Isla; el cuarto jefe de la rotación del botón «Jefe» es el Ceniza).

1. [ ] Invoca al Ceniza y míralo de frente y por detrás en las tres fases.
   ✅ El cuerpo oscuro con las manchas de ceniza pintadas, el volcán de obsidiana del lomo y los cuernos están; la lava (venas, grietas, cráter y cara) pasa de naranja a rojo con las fases y en la fase 3 el volcán entra en erupción, como antes de las mallas.
2. [ ] Mira de cerca (5–10 studs) los puños y los pies.
   ✅ Los guanteletes de obsidiana son casi negros y las garras negras, sin tinte azul ni rosa. (Si se ven rosa o azul comprueba que el jugador no lleva el escudo `ForceField` de pruebas: lo tiñe.)
3. [ ] Repite 97.1 con el Albino.
   ✅ Con la textura de 0,05 studs por texel las manchas se ven más nítidas que con 0,1 y sin cuadros ni bandas; sin errores en la Salida.
4. [ ] En un teléfono, con el Ceniza y el Albino a unos 30 studs, y con 2 jugadores.
   ✅ Los FPS y la memoria no se resienten por las texturas de 1024×1024 (la de cada torso pesa ~4 MB sin comprimir). Si en el teléfono se nota, se vuelve a 0,1 studs por texel (`--texel 0.1`) y se reimportan.

## 98. Fase 20 Q3b: Chimpancé Caudillo con malla (03-11-2026)

El Caudillo se rehízo como jefe tribal (manto de leopardo con rosetas y cola, hombreras y brazaletes de hueso, bandolera, cinturón con trofeos, melena canosa, abanico de plumas en la espalda) y sus seis partes del cuerpo son `MeshPart` con textura (`Data/BossMeshes`, 2.478 triángulos en las mallas y ~6.200 / 6.400 / 6.500 visibles por fase con las uniones que quedan). El tocado, la cara, los ojos, el collar, el medallón, la pintura de guerra, el erizado, las cicatrices, los jirones y el abanico de la espalda siguen siendo uniones por fase. Se prueba en Play en la Isla con una copia de `PlayerData_v1` (como en §97.1); el segundo jefe de la rotación del botón «Jefe» es el Caudillo.

### 98.1 En Play, en la Isla (1 jugador)

1. [ ] Copia `PlayerData_v1` en `PlayerData_v1_backups`, invoca al Caudillo y míralo de frente, de lado y por detrás.
   ✅ Sin errores ni avisos «No se pudo cargar la malla»; el manto se lee como piel de leopardo (rosetas oscuras con el centro ocre, borde crema, cola con anillos), la melena y el lomo son canosos, el abanico de la espalda se ve entero, y los trofeos cuelgan del cinturón a los lados.
2. [ ] Baja su vida con «Jefe herido» y míralo en las fases 2 y 3, de frente y por detrás.
   ✅ Fase 2: pintura de guerra y el abanico más abierto. Fase 3: pelo erizado, abanico roto, cicatrices en el pecho, jirones del manto con agujeros y ojos encendidos; se distingue de la 1 a primera vista, también por detrás.
3. [ ] Déjalo atacar (lluvia de rocas, llamada a la tropa y embestida) y míralo andar.
   ✅ Las seis mallas siguen a sus articulaciones sin piezas sueltas ni flotando; las hombreras caen sobre los hombros y los brazaletes sobre los antebrazos en los dos lados (señal de que el giro de la malla es el correcto en el brazo derecho y en el izquierdo).
4. [ ] Dispara al medallón dorado del pecho y a la cabeza.
   ✅ El medallón sigue siendo el punto débil y la cabeza cuenta como cabeza.
5. [ ] En el Studio, quita un id de `BossMeshes.luau` (por ejemplo el de la cabeza) y vuelve a invocarlo.
   ✅ Esa parte sale con bloques como antes y el resto con malla; sin errores. Devuelve el id.
6. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 98.2 En el juego publicado, con 2 jugadores y en teléfono

1. [ ] Con 2 jugadores, uno de ellos entra después de que el Caudillo ya esté vivo.
   ✅ El segundo ve las seis mallas con su textura (no un patrón de cuadros) y los dos ven lo mismo.
2. [ ] En un teléfono, mira al Caudillo a unos 30 studs en las tres fases.
   ✅ Los FPS no caen frente al Caudillo de antes y las rosetas y el pelo no se ven a cuadros ni borrosos.

## 99. Fase 20 Q3c: Orangután del Manglar con malla (03-11-2026)

El Orangután del Manglar se rehízo como señor del pantano (cortina de pelo largo por la espalda y los brazos, musgo y lianas con capullos, conchas y cangrejos en los hombros y el lomo, raíces del manglar que crecen con las fases y flores abiertas en la fase 3) y sus seis partes del cuerpo son `MeshPart` con textura (`Data/BossMeshes`, 2.256 triángulos en las mallas y ~3.200 / 4.200 / 5.800 visibles por fase con las uniones que quedan). La cara, los ojos, el saco de la garganta con la gema, el barro, las raíces, las flores, los hongos y el musgo con material siguen siendo uniones por fase. Se prueba en Play en la Isla con una copia de `PlayerData_v1` (como en §97.1); el primer jefe de la rotación del botón «Jefe» es el Orangután.

### 99.1 En Play, en la Isla (1 jugador)

1. [ ] Copia `PlayerData_v1` en `PlayerData_v1_backups`, invoca al Orangután y míralo de frente, de lado y por detrás.
   ✅ Sin errores ni avisos «No se pudo cargar la malla»; por detrás, la cortina de pelo en tres tonos de naranja, las lianas con hojas y capullos rosas, el musgo del lomo, y las conchas y los cangrejos azul grisáceo sobre los hombros y el lomo.
2. [ ] Baja su vida con «Jefe herido» y míralo en las fases 2 y 3, de frente y por detrás.
   ✅ Fase 2: barro y el saco de la garganta medio hinchado, con más raíces. Fase 3: raíces grandes (también sobre los hombros), hongos luminosos, flores blancas con el centro dorado, saco hinchado y ojos encendidos; se distingue de la 1 a primera vista, también por detrás.
3. [ ] Déjalo atacar (agarre, pisotón y llamada a las marimondas) y míralo andar.
   ✅ Las seis mallas siguen a sus articulaciones sin piezas sueltas ni flotando; los brazos caen sobre los hombros en los dos lados (señal de que el giro de la malla es el correcto).
4. [ ] Dispara a la gema azul de la garganta y a la cabeza.
   ✅ La gema sigue siendo el punto débil, sobresale del saco en las tres fases y la cabeza cuenta como cabeza.
5. [ ] En el Studio, quita un id de `BossMeshes.luau` (por ejemplo el de la cabeza) y vuelve a invocarlo.
   ✅ Esa parte sale con bloques como antes y el resto con malla; sin errores. Devuelve el id.
6. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 99.2 En el juego publicado, con 2 jugadores y en teléfono

1. [ ] Con 2 jugadores, uno de ellos entra después de que el Orangután ya esté vivo.
   ✅ El segundo ve las seis mallas con su textura (no un patrón de cuadros) y los dos ven lo mismo.
2. [ ] En un teléfono, mira al Orangután a unos 30 studs en las tres fases.
   ✅ Los FPS no caen frente al Orangután de antes y la cortina de pelo y el musgo no se ven a cuadros ni borrosos.

## 100. Fase 20 Q4: Llama Andina con malla (03-11-2026)

La Llama Andina (Rara) es ahora 15 mallas con textura, una por hueso (`Data/MountMeshes`, 1.774 triángulos frente al tope de 4.100; 31 piezas frente a 260), con más detalle: rizos de lana, grecas y rombos en la manta, pompones por detrás, bigotes, pestañas y dientes. Está comprobada solo en Edit y en captura; las monturas solo se usan en el Lobby.

### 100.1 En el Studio del Lobby, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`, clave `_antesQ4`)

1. [ ] Concede la Llama Andina a tu perfil (con el panel de administración: dar una montura), equípala y móntala.
   ✅ Sin avisos «No se pudo cargar la malla»; la llama se ve con su textura (no a cuadros), con la manta de marcos y rombos, y por detrás la grupa negra con motas y los pompones bajo la manta.
   Comprobado el 03-11-2026 en Play (Studio de la Isla): una sola llama montada y las mallas de las patas a su sitio respecto a su hueso (ver el fallo de las patas sueltas, arreglado con un `Weld` de desfase explícito).
2. [ ] Camina, galopa, salta y planea con ella; usa el gesto de escupir.
   ✅ Las 15 mallas siguen a sus huesos (cuello, cabeza, mandíbula, orejas, cola y las cuatro patas con sus cañas) sin piezas sueltas ni flotando; la mandíbula se abre al escupir y el jinete se queda sentado sobre la manta.
3. [ ] Mírala de cerca de frente: boca y gafas.
   ✅ La boca está cerrada (labios y raya de la boca visibles), con los dientes asomando y el brillo doble en las gafas.
4. [ ] Mira la llama en el nido y en las vitrinas del Lobby y en la ventana de recompensas (`RewardModels`, `ViewportFrame`).
   ✅ Se ve con su textura en las tres.
5. [ ] En el Studio, quita un id de `MountMeshes.luau` (por ejemplo `Head`) y vuelve a montarla.
   ✅ Esa parte sale con bloques como antes y el resto con malla, sin errores. Devuelve el id.
6. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 100.2 En el juego publicado, con 2 jugadores y en teléfono

1. [ ] Con 2 jugadores, uno monta la llama y el otro la mira (también uno que entra después).
   ✅ El otro ve las 15 mallas con su textura y se mueve igual que en el que monta.
2. [ ] En un teléfono, mira la llama a unos 10 studs.
   ✅ Los FPS no caen y la manta no se ve borrosa ni a cuadros.

## 101. Fase 20 Q4b: Jaguar Albino Esmeralda con malla (03-11-2026)

El Jaguar Albino Esmeralda (Legendaria) es ahora 17 mallas con textura, una por hueso (`Data/MountMeshes`, 4.168 triángulos frente al tope de 5.900; unas 62 piezas visibles frente a 375). Diseño con más músculo (hombros en dos escalones, pectorales, dorsal, glúteos, antebrazos, cuádriceps y pantorrillas), melena y gorguera, arnés más rico (peto, hebillas, borlas), garras, cicatriz en el hombro izquierdo y una cara con saltos más tenues. Se queda suelto lo de oro (metal), los ojos y esmeraldas (neón y brillo) y el aura. Comprobado solo en Edit con captura (construye con las 17 mallas y su textura); falta Play. Tras la primera prueba del usuario se corrigió: pupila y reflejo de los ojos como piezas sueltas (en la malla eran geometría oscura delante del ojo de neón), mandíbula más alta y adelantada con barba y labio, y tramos de unión y solape en la cola. Además, las piezas sueltas (ojos, oro, esmeraldas, aura) se quedaban en el origen en Play: ahora se sueldan con `Weld` explícito. Comprobado en Play el 03-11-2026: los ojos a 0,5 studs de la cabeza y la cola sin huecos al caminar.

### 101.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`, clave `_antesQ4b`)

1. [ ] Concede el Jaguar a tu perfil (panel de administración: dar una montura), equípalo y móntalo.
   ✅ Sin avisos «No se pudo cargar la malla»; se ve con su textura (no a cuadros), una sola montura y sin patas flotando.
2. [ ] Camina, galopa, salta y usa el gesto de rugir.
   ✅ Las 17 mallas siguen a sus huesos (cuello, cabeza, mandíbula que se abre al rugir, orejas, cola en tres tramos y las cuatro patas); el jinete queda sentado sobre la silla; el aura gira alrededor.
3. [ ] Míralo de espaldas y de frente.
   ✅ Por detrás se ven las rosetas de la grupa, los glúteos y la cola con anillos de jade, sin escalones blancos entre sus tramos al moverse; de frente, la cara con los ojos de neón brillantes y su pupila, las pestañas, los colmillos, la gorguera y la mandíbula como pieza aparte bajo el hocico (se abre al rugir).
4. [ ] Míralo en el nido y las vitrinas del Lobby y en la ventana de recompensas (`RewardModels`).
   ✅ Se ve con su textura en las tres.
5. [ ] Quita un id de `MountMeshes.luau` (por ejemplo `Head`) y vuelve a montarlo.
   ✅ Esa parte sale con bloques y el resto con malla, sin errores. Devuelve el id.
6. [ ] Monta también el Quetzalcóatl y la Llama (y míralos en el nido del Lobby).
   ✅ Se ven igual que antes: el aura, las grecas y el plumero del Quetzalcóatl, y las gafas de la Llama. Las piezas sueltas de `MountModels.build` ahora van con `Weld` de desfase explícito en lugar de `WeldConstraint` (antes se quedaban en el origen al mover la montura con las mallas cargadas).
7. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 101.2 En el juego publicado, con 2 jugadores y en teléfono

1. [ ] Un jugador monta el Jaguar y otro lo mira (también uno que entra después).
   ✅ El otro ve las 17 mallas con su textura y se mueve igual.
2. [ ] En un teléfono, mira el jaguar a unos 10 studs.
   ✅ Los FPS no caen y el pelaje no se ve borroso ni a cuadros.

## 102. Fase 22: Shorts con CapCut (03-11-2026)

Los Shorts 9:16 se preparan como borradores de CapCut con `tools/video/short.py`; el usuario los abre, los revisa y exporta. Lo que el agente no puede probar solo (abrir en CapCut, exportar, ver en teléfono, subir) va aquí. Plan en `docs/PLAN.md` Fase 22. Esta sección se completa y se ajusta al cerrar cada grupo (V0–V4).

### 102.1 En CapCut 9.7 de escritorio (con CapCut cerrado al generar y una copia de los borradores)

1. [ ] Abre el borrador del spike V0 (`Spike V0 … v1`).
   ✅ Abre sin avisos de «borrador dañado» ni de recursos que faltan; se ven los 3 trozos de la toma, el texto y la música en su sitio.
2. [ ] Cierra CapCut y mira `draft_content.json` del borrador (el agente lo comprueba con un script).
   ✅ Sigue siendo texto plano que empieza por `{`; CapCut 9.7 no lo ha cifrado.
3. [ ] Exporta el borrador a 1080×1920, 30 o 60 fps.
   ✅ El vídeo sale sin marca de agua. Si algo del proyecto está marcado Pro, apunta qué es: no se vuelve a usar.
4. [ ] Abre `Short jefes es v1` y `Short jefes en v1` (V2).
   ✅ Los tiempos y los textos coinciden con `docs/videos/shorts.md`; el texto cae en el tercio central; el gancho está en el primer segundo y el cierre es la portada.
5. [ ] Retoca lo que haga falta, exporta y apunta los minutos en `docs/videos/shorts.md`.
   ✅ Menos de 10 minutos por Short; 7 de cada 10 sin retoques de fondo.

### 102.2 En el teléfono y en las plataformas (los sube el usuario)

1. [ ] Mira un Short exportado en el teléfono, a pantalla completa.
   ✅ El texto se lee y no lo tapan los botones de YouTube Shorts ni de TikTok; la acción cae en el recuadro central.
2. [ ] Sube uno como privado a YouTube Shorts y otro a TikTok.
   ✅ La música no recibe reclamación de derechos; el vídeo se reproduce sin cortes.
3. [ ] Comprueba que el vídeo no enseña Robux, «gana dinero», sangre ni texto de depuración.
   ✅ Cumple las reglas de contenido de `docs/videos/README.md`.

## 103. Fase 22 V0: spike del borrador 9:16 con pyCapCut (03-11-2026)

El borrador de prueba lo crea `tools/video/spike_v0.py` en `build/videos/borradores/V0-spike-<fecha>/` (fuera de CapCut; no toca ningún borrador existente ni `root_meta_info.json`). Tiene 3 trozos de 4 s de `O:/2026-10-30 10-42-16.mkv` (a los 5, 15 y 28 s, ampliados para llenar 1080×1920), el texto «PRIMAL BANANA ISLANDS» (fuente Alegreya, no Pro) y un tono de prueba de 12 s (`build/videos/tono_prueba.mp3`, no es música real). Las §102.1 pasos 1-3 se hacen con este borrador. Con CapCut cerrado:

### 103.1 Abrir el borrador en CapCut 9.7 (hecho el 03-11-2026: aparece en la lista, abre sin avisos, `draft_content.json` sigue en texto plano con `new_version` 191.0.0)

1. [x] Copia la carpeta `V0-spike-<fecha>` a `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft\` (es una carpeta nueva; no sustituye nada) y abre CapCut.
   ✅ El borrador aparece en la lista de proyectos. Si no aparece, CapCut necesita que `root_meta_info.json` lo liste: apúntalo, es el fallo principal del spike.
2. [x] Ábrelo.
   ✅ Sin aviso de «borrador dañado» ni de archivos que faltan; 3 clips seguidos, el texto durante los 12 s y el audio debajo. Apunta si el encuadre llena la pantalla o salen franjas.
3. [x] Cierra CapCut. Avísame y compruebo `draft_content.json` (texto plano, sin cifrar) y que CapCut 9.7 no ha reescrito el borrador.
   ✅ Empieza por `{`.

### 103.2 Exportar (hecho el 03-11-2026: MP4 1080×1920, 30 fps, 12 s, sin marca de agua, en `P:\VIDEO\Primal banana islands\Trailer\`)

1. [x] Exporta a 1080×1920, 30 fps, sin tocar nada más.
   ✅ Sin marca de agua. Si sale con marca, mira en la línea de tiempo qué recurso lleva el icono Pro y apúntalo.
2. [x] Mira el vídeo exportado.
   ✅ Los trozos coinciden con los tiempos (5-9 s, 15-19 s, 28-32 s de la toma) y el texto se lee en el tercio central.
3. [x] Mira la toma `O:/2026-10-30 10-42-16.mkv` entera.
   ✅ Decidido el 03-11-2026: las tomas son la ventana entera de Studio, así que en el recuadro central 9:16 se cuela su barra de herramientas. No se descartan: V1/V2 las recortan o escalan para ajustarlas (el tramo del segundo 28 no está oscuro; era solo la miniatura de CapCut).

## 104. Fase 22 V1: lista de cortes del tráiler y fotogramas con guía 9:16 (03-11-2026)

`python -I tools/video/borrador.py "build/videos/copias/2026-11-03/trailer esp" --json build/videos/cortes/trailer-esp.json --md build/videos/cortes/trailer-esp.md` saca los 39 cortes (toma, desde, duración, lugar en la línea, escala y desplazamiento) y los textos. `python -I tools/video/fotogramas.py build/videos/cortes/trailer-esp.json --hoja` deja un fotograma por corte con la guía 9:16 en `build/videos/fotogramas/trailer-esp/` (`hoja.jpg` los junta). Ya comprobado por el script: las 39 tomas existen en `O:/` y ningún corte se sale de su toma, en ES y EN. Falta tu ojo en CapCut:

### 104.1 Cinco cortes contra CapCut (con el borrador `trailer esp` abierto en CapCut, sin tocarlo)

1. [ ] Mira en la línea de tiempo los cortes 1, 7, 19, 27 y 39 de `build/videos/cortes/trailer-esp.md`.
   ✅ Cada uno cae en el segundo de la columna «Línea», es de la toma indicada, empieza en el segundo de «Desde» y dura lo de «Dura» (margen de un fotograma). El 39 es la portada de 5 s.
2. [ ] Abre `build/videos/fotogramas/trailer-esp/hoja.jpg`.
   ✅ Cada casilla enseña lo mismo que ves en CapCut en ese corte. Apunta los números de corte donde el rectángulo verde (9:16) corta la acción (candidatos: 1, 7, 23, 26-28) para decidir recuadro en V2.

## 105. Fase 22 V2: primer Short, «Ladrones y jefes» (03-11-2026)

`build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/jefes.json` crea `jefes-es-v1` y `jefes-en-v1` en `build/videos/borradores/` (1080×1920, 30 fps, 15,99 s, 5 cortes: capuchinos ladrones, los 4 jefes a ×3, Gorila de Ceniza en el volcán, lluvia de rocas y la portada de 3 s; sin música). Ya comprobado por el script: las tomas existen, ningún corte se sale de su toma, los textos caen entre -0,33 y 0,33 de altura (tercio central) y acaban antes del vídeo; el JSON de cada borrador tiene los tiempos y textos del guion. `--solo-vista` saca `build/videos/shorts/jefes/hoja.jpg` con el recuadro de cada corte (el script recorta la barra de herramientas y la franja de Studio). Falta CapCut:

### 105.1 Abrir los dos borradores

1. [ ] Con CapCut cerrado, copia `jefes-es-v1` y `jefes-en-v1` a `%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft\` y abre CapCut.
   ✅ Los dos aparecen y abren sin avisos: 5 clips seguidos y, encima, los textos (el del pie del cierre va en su propia pista).
2. [ ] Mira cada corte.
   ✅ El sujeto queda centrado como en `hoja.jpg`: no sale la barra de Studio ni la franja de abajo, ni franjas negras (salvo arriba y abajo de la portada, a propósito). Apunta qué corte se ve movido de sitio: el sentido de `transform_y` (positivo = sube la imagen) es la suposición por probar.
3. [ ] Mira los textos de los dos idiomas.
   ✅ Se leen con el borde negro, la fuente Anton no lleva icono Pro y nada se sale del ancho. Si «Derrota a los jefes de la isla.» o el texto chico del cierre se parten mal, apunta cuál.

### 105.2 Exportar y apuntar el tiempo de retoque

1. [ ] Ajusta lo que haga falta, añade música de la biblioteca de YouTube o TikTok y exporta a 1080×1920, 30 fps, en ES y EN.
   ✅ Sin marca de agua. Apunta **los minutos de retoque** de cada idioma (objetivo: 10 min o menos) y qué retocaste (recuadros, textos, tiempos).
2. [ ] Mira el vídeo exportado.
   ✅ Hay movimiento y texto en el primer segundo, ningún HUD de pruebas en cuadro y no sale Robux ni «gana dinero».

## 106. Fase 22 V3: Shorts 2-4, «Mascotas y monturas», «Elige tu rol» y «Arenas PvP» (03-11-2026)

`build/videos/.venv/Scripts/python -I tools/video/short.py docs/videos/shorts/<id>.json` creó `mascotas` (17,7 s, 5 cortes), `roles` (14,1 s, 6 cortes) y `pvp` (15,2 s, 7 cortes), cada uno en ES y EN (`<id>-<idioma>-v1` en `build/videos/borradores/`, ya copiados a la lista de proyectos de CapCut). Ya comprobado por el script: las tomas existen, ningún corte se sale de su toma y los textos caen en el tercio central y acaban antes del vídeo. Las vistas están en `build/videos/shorts/<id>/hoja.jpg`; el recuadro de cada corte se eligió mirándolas (el primer intento del Short «roles» enseñaba el panel de Studio y el del «pvp» una mira oscura: corregidos). Falta CapCut:

### 106.1 Abrir los 6 borradores y exportar

**Resultado de `pvp-en-v1` (03-11-2026): 15 min 29 s de retoque, por encima de los 10 min del objetivo.** Qué retocó el usuario: cambió tiempos de los cortes 2 y 3 para que mostraran más movimiento; centró esos dos cortes (el personaje salía muy a un lado); añadió el filtro «escritorio retro» (intensidad 30, ajustado a la duración del vídeo), un texto a voz en inglés con la voz «hype guy» (16 dB), y música de la biblioteca (-10 dB). Para V4: los cortes 2-3 del guion de `pvp` y el centrado (`cx`) fallan; el filtro, la voz y la música son pasos fijos que se pueden poner en el guion o en la skill. Faltan los otros 5 borradores.

**Resultado de `mascotas-es-v1` (03-11-2026): 9 min 30 s de retoque, dentro del objetivo.** Hizo lo mismo que en `pvp` (filtro retro, voz generada a cada frase —texto a voz «Narrador» en la captura—, música «REVENGE» de la biblioteca, ajuste de volúmenes); el vídeo queda de 18,02 s con un corte de mascotas de unos 3 s y la Quetzalcóatl de 4,25 s. Exportado en `P:\VIDEO\Primal banana islands\Trailer\`. Cuentan hasta ahora: `mascotas-es` ✅ (9:30), `pvp-en` ❌ (15:29); faltan `jefes` (§105), `roles` y los otros idiomas.

**Resultado de `roles-es-v1` (03-11-2026): 3 min 40 s de retoque, dentro del objetivo.** Solo recortó y reemplazó el tercer corte (la habilidad de lava de `11-05-57.mkv`, que llevaba el aviso «¡2 monos van a por ti!» y el texto «Hay un huevo común en la isla» tapando la acción), más el filtro «Now Gen2 niebla» a lo largo del vídeo (el filtro de escritorio retro de `pvp` no es obligatorio), voz «Narrador Cálido» y música «MONTAGEM ALQUIMIA». Exportado a la misma ruta. Cuenta: **2 de 4 en 10 min o menos** (`mascotas-es`, `roles-es`); con uno más (`jefes` o un `pvp` mejor) se cumple el criterio de V3. Para V4: el corte 3 de `roles.json` tiene que empezar en otro segundo de la toma o ampliarse (el aviso del juego tapa la acción en los cortes 3-5).

**Resultado de `jefes-en-v2` en inglés (03-11-2026): 3 min 15 s de retoque, dentro del objetivo.** Mismo proceso fijo de siempre (filtro, voz generada, música, volúmenes, exportar), sin cambios de fondo en los cortes. Cuenta: **3 de 4 en 10 min o menos** (`mascotas-es`, `roles-es`, `jefes-en`); el objetivo de §106.2 se cumple. El tiempo ya es casi todo el proceso fijo, así que el siguiente ahorro está en automatizarlo (ver «Receta fija» en la skill `video-capcut`).

1. [ ] Abre CapCut y mira `mascotas-es-v1`, `roles-es-v1` y `pvp-es-v1` (y los `-en-`).
   ✅ Abren sin avisos; cada corte tiene el sujeto centrado como en su `hoja.jpg`. Apunta cortes mal encuadrados: en `roles` los cortes 3-5 llevan avisos del juego arriba («Hay un huevo común en la isla»); en `pvp` los cortes 1-3 llevan el cartel de la bandera.
2. [ ] Ajusta, añade música de la biblioteca de YouTube o TikTok y exporta a 1080×1920, 30 fps.
   ✅ Sin marca de agua. Apunta **los minutos de retoque** de cada Short (objetivo: 10 min o menos, al menos 3 de los 4 Shorts incluido «jefes») y qué retocaste.
3. [ ] Decide si `roles` (14,1 s) se alarga a 15 s o más.
   ✅ Los Shorts de YouTube admiten desde 1 s; el objetivo de 15-30 s era orientativo.
4. [ ] Mira los vídeos exportados.
   ✅ Hay movimiento y texto en el primer segundo, ningún HUD de pruebas ni Robux ni «gana dinero» en cuadro (en `pvp`, la lista de jugadores no se ve).

## 107. Fase 22 V4: skill `video-capcut` y textos de publicación (03-11-2026)

`.claude/skills/video-capcut/SKILL.md` explica cómo hacer un Short (guion, recuadro, borrador, verificación) y los pasos fijos del usuario en CapCut; su resumen es `docs/llm-local/video.md` (preset «Monos – Vídeo»). Títulos, descripciones y etiquetas de los 4 Shorts, en ES y EN, están al final de `docs/videos/shorts.md`.

### 107.1 Probar la skill en una pestaña nueva

1. [x] En una pestaña nueva de Claude Code, di solo: «Haz el Short de jefes en inglés.»
   ✅ Usa la skill, regenera el borrador (`jefes-en-v2`, sin sobrescribir `v1`) con CapCut cerrado y lo apunta en VERIFICACION. No pregunta lo que está en el guion.
2. [x] Lee los títulos y descripciones de `shorts.md`.
   ✅ Sin Robux ni «gana dinero»; el título cabe en 100 caracteres. Retoca lo que no te guste antes de subirlos.
3. [x] Termina los medidos: `jefes-es-v1` y los `-en` de `mascotas` y `roles`, o los `-es` de `pvp`, y apunta los minutos en §106.1.
   ✅ Al menos 3 de los 4 Shorts en 10 minutos o menos.

**Cerrado el 03-11-2026:** el usuario hizo la prueba con «Haz el Short de jefes en inglés» (`jefes-en-v2`, 3 min 15 s). Con `mascotas-es`, `roles-es` y `jefes-en`, 3 de 4 Shorts quedan en 10 min o menos.

## 108. Fase 23b: campo de tiro, acceso y recinto (03-11-2026)

El campo de tiro es una zona aparte del Lobby (`Workspace.CampoDeTiro`, sobre el mar, detrás de la isla del volcán, en (850, 1,5, -1150)). Se entra por el arco junto a la plaza, al oeste de los muñecos de práctica, y se sale por el arco trasero del recinto con «Volver al Lobby». Se construye al arrancar el Lobby (VERSION 18 de `LobbyBuilder`; el recinto, VERSION 2 de `RangeBuilder`). En 23b solo hay recinto y acceso: las dianas, las marcas de las pantallas y la ronda llegan en 23c.

### 108.1 En Play, en el Lobby (1 jugador)

1. [ ] Antes de Play, copia `PlayerData_v1` en `PlayerData_v1_backups`. Entra en Play en el Lobby, camina hasta el arco junto a la plaza y cruza el arco.
   ✅ Apareces sobre la losa detrás de la línea de tiro, sin caer ni atravesar el suelo.
2. [ ] Desde la losa, sal por el arco trasero con el prompt «Volver al Lobby».
   ✅ Vuelves al Lobby junto a la plaza, sin caer y sin quedar atrapado entre los arcos.
3. [ ] Mira el arco de entrada desde la plaza y desde la entrada del campo.
   ✅ El icono 🔭 no tapa la diana del arco.
4. [ ] Vuelve a entrar. Pulsa el prompt de entrada y, en menos de 1,5 s, pulsa otra vez el mismo prompt; espera luego a que pase el cooldown y pulsa de nuevo.
   ✅ La pulsación rápida no hace nada; la del final funciona. Sin errores en la Salida.
5. [ ] Entra en el campo y quédate allí dos minutos sin pulsar nada.
   ✅ El Lobby no te devuelve a la plaza ni te mueve: sigues en la losa.
6. [ ] Para Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba.

### 108.2 En Play, con 2 jugadores

1. [ ] Los dos entran a la vez por el arco.
   ✅ Los dos aparecen sobre la losa, cada uno en su sitio, sin encimarse ni caer.
2. [ ] Repartíos a lo ancho de la losa y camina cada uno a su lado.
   ✅ Se mueven a lo ancho sin atravesarse ni quedarse atascados en las paredes del recinto.

### 108.3 En el teléfono o el emulador

1. [ ] Entra en el campo con el emulador de teléfono y mira las pantallas y los números del suelo desde la línea de tiro, en vertical y en horizontal.
   ✅ Se leen sin acercarse; el texto no se corta ni se ve a cuadros.
2. [ ] Con el Studio abierto, cuenta las instancias de UI de una pantalla (`SurfaceGui.Pantalla`, en el Explorador).
   ✅ Unas 290 instancias por pantalla. Al mirarlas en el teléfono no hay tirones.

### 108.4 En el juego publicado

1. [ ] En el place del Lobby, mira que `StreamingEnabled` esté apagado en `Workspace`, guarda el place y publícalo.
   ✅ Está apagado; el juego publicado arranca sin errores.
2. [ ] Abre el Lobby publicado, que en el primer arranque reconstruye el Lobby (VERSION 18) y crea `Workspace.CampoDeTiro`. Busca `CampoDeTiro` en el Explorador. Luego repite 108.1 pasos 1 y 2 en el juego publicado.
   ✅ `CampoDeTiro` existe tras el primer arranque y no aparece dos veces en un segundo arranque. La entrada y la salida funcionan igual que en Play.

### 108.5 Rendimiento en el Lobby con jugadores

1. [ ] Con varios jugadores en el Lobby, mide los FPS en PC y en teléfono, con y sin gente dentro del campo.
   ✅ El campo (unas 510 piezas, tope de 6.000 en `Config.Budgets.Matches.RangeParts`) no baja los FPS del Lobby de forma apreciable.

## 109. Fase 23c: dianas, pantallas y ronda (03-11-2026)

Las dianas del campo son combatientes: cada una tiene un `Humanoid` de 1e6 de vida que se restaura tras cada golpe, el tag `Enemy` y la zona `Head` en el anillo `Bullseye`. Las emergentes pierden el tag mientras están bajadas. Las pantallas enseñan las marcas de cada disparo (solo a quien dispara) y el Readout. La ronda de tiro dura 60 s, puntúa por anillo y no da Ámbar. En Studio, en 23c, se comprobaron 10 dianas con `Humanoid`, tag y zonas; las móviles, las emergentes y la giratoria se mueven; y un disparo real con el Arco a una diana fija hizo 26 de daño y la vida volvió al máximo.

### 109.1 En Play, con 1 jugador: pantallas

1. [ ] Antes de Play, copia `PlayerData_v1` en `PlayerData_v1_backups`. Entra en el campo, equípate el Arco y dispara a las pantallas desde tres distancias (cerca, media y lejos), unos 10 tiros a cada una.
   ✅ Cada impacto deja una marca blanca con borde negro, y la última es naranja y más grande. Las marcas caen donde impacta la flecha.
2. [ ] Mira la línea naranja de cada pantalla tras los últimos 10 tiros.
   ✅ Sale desde el centro hacia el desvío medio de esos tiros, recta y sin torcerse.
3. [ ] Lee el Readout de las dos pantallas.
   ✅ Dice «Δx … Δy … studs (…°) · dispersión … · tiros N». Tanto en la pantalla corta como en la larga, dx positivo es a la derecha de quien mira y dy positivo es hacia arriba. Los signos cuadran con dónde caen las marcas.
4. [x] Pulsa `BorrarMarcasPrompt`.
   ✅ Se vacían las marcas y la línea de las dos pantallas a la vez.
5. [ ] Con la ayuda de puntería activada, apunta a las dianas del campo, sobre todo a sus bordes.
   ✅ La ayuda no engancha las dianas: el disparo va donde apuntas.

### 109.2 En Play, con 1 jugador: dianas

6. [ ] Dispara al centro del `Bullseye` mientras se mueve (raíl y giratoria) y luego a uno de sus anillos exteriores.
   ✅ Los impactos en el centro son críticos (×1,5) y sale el número de daño sobre el impacto.
7. [ ] Dispara a una diana emergente mientras está bajada y luego cuando sube.
   ✅ Bajada no recibe daño. Al subir, sí.

### 109.3 En Play, con 1 jugador: ronda de tiro

8. [x] Pulsa `RondaPrompt` en el campo. Anota tu Ámbar antes de la ronda.
   ✅ Empieza la ronda: aparece el panel arriba en el centro con el tiempo (60 s) y los puntos.
9. [x] Dispara durante la ronda y mira cómo suben los puntos según el anillo (10, 7, 5 o 3).
   ✅ El panel suma los puntos del anillo que tocas y el tiempo baja.
10. [ ] Pulsa `RondaPrompt` otra vez mientras la ronda sigue.
    ✅ No pasa nada: la ronda no se reinicia ni suma puntos extra.
11. [ ] Deja que acabe el tiempo.
    ✅ Sale la tarjeta final con la precisión y los puntos. Si superas el mejor de la sesión, pone «¡Nuevo récord!». El Ámbar no ha cambiado respecto al paso 8.
12. [ ] Haz otra ronda y consigue menos puntos que la mejor.
    ✅ La tarjeta no muestra «¡Nuevo récord!» y el mejor de la sesión se mantiene.
13. [ ] Para Play y vuelve a entrar al campo.
    ✅ El récord de la sesión anterior no aparece: el mejor se guarda solo en memoria.
14. [ ] Empieza una ronda y sal del recinto por el arco con «Volver al Lobby».
    ✅ La ronda se corta: el panel desaparece y no llega la tarjeta final.
15. [ ] Empieza otra ronda y aléjate del recinto a pie, sin usar el arco ni los prompts.
    ✅ La ronda se corta al salir del recinto.
16. [ ] Empieza otra ronda y muere (pon la vida del personaje a 0 desde el Explorador de Play).
    ✅ La ronda se corta y no sale la tarjeta final. Sin errores en la Salida.

### 109.4 En Play, con 2 jugadores

1. [ ] Cada uno dispara a las pantallas: el jugador A a la pantalla corta y el B a la larga.
   ✅ Cada uno ve solo sus marcas y su línea. Las marcas del otro no aparecen en su pantalla.
2. [ ] Los dos empiezan su ronda de tiro a la vez.
   ✅ Las dos rondas corren por separado: cada panel tiene su tiempo y sus puntos, y los disparos no se mezclan.

### 109.5 En el teléfono o el emulador

1. [ ] Con el emulador de teléfono, empieza una ronda y dispara mientras miras el panel del tiempo y los puntos.
   ✅ El panel no tapa los botones de combate ni el joystick, y se lee el tiempo y los puntos.
2. [ ] Mira el Readout de las pantallas desde la línea de tiro, en vertical y en horizontal.
   ✅ Se lee sin acercarse: el texto no se corta ni se ve a cuadros.

### 109.6 En el juego publicado

1. [ ] Publica el place del Lobby y, en el juego publicado, dispara a las dianas móviles y a la giratoria.
   ✅ Los impactos aciertan donde se ve la diana, aunque haya retraso del servidor, y las dianas no saltan de sitio a tirones.
2. [ ] Con ping alto (una conexión lenta o una simulación de red en el emulador), juega una ronda completa.
   ✅ Los disparos siguen acertando donde se ve la diana, el panel de la ronda no se queda congelado y la tarjeta final sale al acabar el tiempo.

## 110. Fase 23d: cañón de pelotas, rebotes y dianas de pared (03-11-2026)

### 110.1 En Play, con el panel del cañón

1. [ ] Sube a la plataforma (rampa a la derecha de la línea de tiro) y acércate al cañón: activa «Ajustar el cañón».
   ✅ Se abre el panel a la derecha, con elasticidad, gravedad, tamaño y velocidad y los valores 0,8 / 196 / 2,0 / 90.
2. [ ] Pulsa «+» y «−» en cada fila hasta los extremos.
   ✅ Cada pulsación cambia el valor un paso y se queda quieto en el mínimo y el máximo (elasticidad 0–1, gravedad 0–300, tamaño 1–6, velocidad 20–200).
3. [ ] Pulsa «Disparar pelota» con elasticidad 1 y luego con 0.
   ✅ Con 1 la pelota rebota varias veces en el suelo y las paredes del foso; con 0 se queda en el suelo. Con gravedad 0 vuela recta, y más grande o más rápida se nota.
4. [ ] Dispara muchas pelotas seguidas (más de 30) y espera 20 segundos.
   ✅ Las más viejas desaparecen al pasar de 30 y todas se borran solas a los 20 s.
5. [ ] Aléjate del cañón con el panel abierto.
   ✅ El panel se cierra solo.

### 110.2 En Play, el mapa

1. [ ] Mira el campo desde la línea de tiro.
   ✅ No hay faroles en la línea de tiro. Las dianas de 8, 16, 28 y ~36 de altura cuelgan del muro izquierdo, sin poste, de frente a la línea de tiro, con su cartel encima; no se mueven.
2. [ ] Dispara a cada una con una ronda de tiro en marcha.
   ✅ Puntúan por anillos igual que las demás. La giratoria (ahora más cerca de la línea, z = 4) sigue girando sin chocar con la diana de 8.

### 110.3 Con 2 jugadores

1. [ ] Cada uno ajusta el cañón con valores distintos y dispara.
   ✅ Cada pelota sale con los ajustes de quien la lanza y los dos ven las mismas pelotas. Las pelotas empujan al jugador con el que chocan (no hay grupo de colisión); si molesta, avísalo.

### 110.4 Sin arma que lo use

1. [ ] `bounces` en `Projectiles.fire` aún no lo usa ningún arma. Cuando se use, comprueba que el proyectil rebota en las paredes y que el cliente lo dibuja sin saltos.
   ✅ Cada rebote es un tramo nuevo y el último termina donde cae.

## 111. Fase 23e: depuración del campo de tiro (03-11-2026)

Todo esto es solo Studio: las órdenes salen en el panel «🛠️ Pruebas» del Lobby.

### 111.1 Hitbox visibles

1. [ ] En el campo de tiro, pulsa «📦 Campo de tiro: hitbox visibles» y mira las dianas, un muñeco y a otro jugador.
   ✅ Cada pieza sale teñida por zona (cabeza rosa, torso azul, miembro amarillo, punto débil blanco), con la esfera de la cabeza y una cápsula celeste del cuerpo. No hay verde, morado ni rojo.
2. [ ] Dispara a la cabeza y al borde de la cápsula de un muñeco.
   ✅ Acierta (daño de cabeza) cuando la bala entra en la esfera rosa o la cápsula, y falla fuera de ellas.
3. [ ] Mira las tres dianas emergentes mientras suben y bajan.
   ✅ Sus hitbox se quedan dibujadas también cuando están hundidas, sin desaparecer y volver a salir.
4. [ ] Pulsa la orden otra vez y aléjate a más de 160 studs.
   ✅ Los dibujos desaparecen; lejos no hay lag al activarlos.

### 111.2 Trazas de disparo

1. [ ] Pulsa «📐 Campo de tiro: trazas de disparo» y dispara con un arma a distancia a una diana lejana.
   ✅ Al acabar el disparo aparece una línea naranja (servidor) y otra celeste (tu puntería), un punto en el impacto y un cartel con ping, grados de ayuda y segundos rebobinados. Todo se borra a los 4 s.
2. [ ] Apunta justo a un mono o muñeco y luego entre dos.
   ✅ Con ayuda de puntería la línea naranja se desvía unos grados de la celeste; entre dos blancos, no.
3. [ ] Lo mismo con ping alto, con un cliente remoto o en el juego publicado (en Studio el ping del servidor es 0 aunque se simule retraso en el cliente, así que no vale).
   ✅ El cartel enseña el ping y el rebobinado sube con él, con tope de `Config.Net.MaxCompensationSeconds`.

### 111.3 Estación de efectos

1. [ ] Ve al muro de materiales (pared derecha) y pulsa «💥 Campo de tiro: siguiente efecto» varias veces.
   ✅ Cada pulsación enseña un paso: marcas de impacto en madera, piedra, metal y arena; impacto en un cuerpo; y un crítico por cada estilo de estallido (el primero sin estilo). El mensaje de la consola dice cuál. Al acabar la lista vuelve al principio.
2. [ ] Repite con el efecto de calidad bajo y alto en Ajustes.
   ✅ La calidad baja usa menos marcas y partículas, sin errores.

## 112. Campo de tiro: tres muñecos (fijo, lateral y de profundidad) (03-11-2026)

1. [x] En Play, mira desde la línea de tiro: un muñeco quieto a la derecha (a 36 studs), otro que va de lado a lado a 66 studs y otro que se acerca y se aleja por el centro-izquierda (de 16 a 56 studs). Los dos móviles tienen un raíl en el suelo.
   ✅ Se ven los tres, los móviles se mueven suave y a la vez para todos los jugadores, y ninguno atraviesa obstáculos, la plataforma ni el foso.
2. [x] Dispárales con un arma a distancia a la cabeza, al torso y al brazo.
   ✅ Salen números de daño; la cabeza pega más que el torso y el brazo menos. No caen nunca ni hacen «¡puf!».
3. [x] Activa las hitbox de depuración (§111.1) y mira los tres muñecos.
   ✅ Se ven la esfera de la cabeza y la cápsula, que siguen al muñeco al moverse.
4. [ ] Apunta cerca de un muñeco sin apuntarle.
   ✅ La ayuda de puntería no los elige (como las dianas): el disparo sale donde apuntas.
5. [ ] Corre con la ronda de tiro en marcha y dispara a un muñeco.
   ✅ No suma puntos (solo puntúan las dianas con anillos); la ronda no se rompe.
6. [x] Intenta caminar entre los muñecos móviles (el usuario lo probó el 04-11-2026: no se podía pasar y así se queda).
   ✅ Los muñecos no te lanzan ni te atrapan al moverse.

## 113. Fase 20 Q4c: Quetzalcóatl Mítico a máximo detalle con malla (04-11-2026)

El Quetzalcóatl (Mítica) se rehízo a máximo detalle y es ahora 11 mallas con textura (`Data/MountMeshes`, 3.754 triángulos las mallas y 5.388 en total frente al tope de 17.200; 468 piezas frente a 560). Se subieron los topes de la Mítica en `Config.Budgets` (piezas 410 → 560, triángulos 8.600 → 17.200). Cambios de diseño: hocico y mandíbula en escalones que se estrechan, aletas de la nariz, párpado oscuro sobre cada ojo, bigotes de oro y jade (dos por lado en lo alto del hocico y uno por lado bajo el mentón) y perilla de plumas, aletas de plumas en las mejillas, penacho delantero curvo, cintas largas del penacho trasero y de la cola, y escamas (una fila en relieve, dos pintadas, escudos del vientre y púas de oro en el lomo). `Rendimiento` sin alertas. Comprobado el 04-11-2026 en Edit (construye con las 11 mallas) y en Play en la Isla (montado, con las 11 mallas y el jinete sobre la silla, sin avisos). Tras la primera prueba del usuario se rehízo la mandíbula inferior (era más baja y corta que el hocico y la tapaba la perilla): ahora tiene tres escalones como el hocico, escamas y cresta de oro en el costado y la perilla y los bigotes de la barbilla salen de debajo del mentón; mallas y cajas coinciden en tamaño y se reimportó solo `Quetzalcoatl_Jaw`. Después se vio la mandíbula corta y con un hueco bajo los dientes (boca abierta −14° de fábrica): se subió y ensanchó (3,2 celdas de alto) y el reposo pasó a −7°. La causa del hueco que seguía era un error del volcado: había cajas llamadas `Jaw` y `Tongue` como los huesos, y `FindFirstChild("Jaw")` devolvía una caja, así que la malla de la mandíbula (y la de la lengua) salía ~0,6 studs atrás y arriba. Se renombraron las cajas (`JawBlock`, `TongueBlock`) y se midió que la malla coincide con las cajas en todos los huesos (mandíbula z −9,09…−6,62 frente a −9,09…−6,63). Comprobado en Play el 04-11-2026 de lado en reposo (la mandíbula llega a la barbilla y las barbas cuelgan de ella). El Jaguar tenía el mismo choque de nombres (`Jaw`, `Tail`, `Neck`) y sus mallas de mandíbula, cuello y cola salían desplazadas hasta ~0,4 studs: corregido el 04-11-2026 (cajas renombradas, offsets nuevos en `MountMeshes`; las formas no cambian, no hizo falta reimportar). Falta lo de abajo, sobre todo el silbido (la mandíbula se abre sin atravesar el hocico).

### 113.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`, clave `_antesQ4c`)

1. [ ] Móntalo y camina, salta desde lo alto (planeo) y usa el gesto de silbar.
   ✅ Las mallas siguen a sus huesos (cuello, cabeza, mandíbula que se abre al silbar y los cinco tramos de la cola); sin huecos entre tramos al ondular; los abanicos se abren al planear; el aura y los remolinos siguen en su sitio.
2. [ ] Mira las grecas de oro mientras camina.
   ✅ Las grecas pulsan recorriendo la serpiente (siguen sueltas, no pintadas).
3. [ ] Míralo de frente, de lado y de espaldas.
   ✅ Hocico afilado con colmillos, párpado sobre los ojos, bigotes sin cruzarse, penacho delantero curvo, cintas detrás y plumero de la cola; escamas visibles.
4. [ ] Míralo en el nido y las vitrinas del Lobby y en la ventana de recompensas (`RewardModels`, tope 300 piezas del `ViewportFrame`).
   ✅ Se ve con su textura en las tres (si la ventana no lo carga entero por el tope, anótalo).
5. [ ] Monta por primera vez al entrar en la partida y mira sobre el jinete (sobre todo en el teléfono y con red lenta).
   ✅ Mientras carga sale un anillo de puntos dorados que gira, con «Preparando montura…» debajo (en inglés, «Getting your mount ready…»); lo ven también los demás jugadores; se quita solo al aparecer la montura. Al montar otra vez (o con las mallas ya cargadas) no sale ni parpadea. Comprobado el 04-11-2026 solo por datos en Play (aparece a los 0,27 s y desaparece al terminar; la captura de Studio no dibuja los carteles del mundo), falta verlo con ojos. Frase nueva para la tabla de Creator Hub (`tools/strings.py --csv-nuevas`).
6. [ ] Mide cuánto tarda la primera montura de la sesión en el juego publicado.
   ✅ Las 11 mallas se piden a la vez y se guardan para las siguientes (antes, una a una: ~3,3 s en Play de Studio, ahora ~0,4 s); en el juego publicado depende de la red.
7. [ ] Para el Play y restaura `PlayerData_v1` desde `PlayerData_v1_backups`.
   ✅ El perfil vuelve a ser el de antes de la prueba (ya restaurado tras la prueba del 04-11-2026).

### 113.2 En el juego publicado, con 2 jugadores y en teléfono

1. [ ] Un jugador monta el Quetzalcóatl y otro lo mira (también uno que entra después).
   ✅ El otro ve las 11 mallas con su textura y las plumas, y se mueve igual.
2. [ ] En un teléfono, mira el Quetzalcóatl a unos 10 studs y con varias monturas cerca.
   ✅ Los FPS no caen y la textura no se ve borrosa ni a cuadros.

## 114. Fase 20 Q5a: mascotas con malla; piloto la Capibara (04-11-2026)

Las mascotas se pueden montar con malla (Fase 21): `PetModels.build(petId, skinId, boxesOnly)` agrupa las piezas por articulación (cabeza, cada pata y `Static` para lo fijo) y cada grupo con id en `Data/PetMeshes` pasa a ser una `MeshPart` con la misma articulación. Con skin, o si las mallas aún no han cargado, la mascota usa bloques (y `PetFollowers.start` las pide al arrancar). Volcado: `ServerStorage.Tools.Mallas.volcarMascota(id, <clon de Shared>)`, luego `python tools/mallas.py tools/mallas/<Mascota>.txt --del-log` y `--jefe <Mascota> --escala 1 --fino 0.035 --texel 0.01 --espejo FL=FR …`. Piloto: la Capibara rehecha (grupa redondeada en escalones, ojo con capas, carrillos, pelo fino pintado): 6 mallas con 1.204 triángulos (tope 2.800), 7 piezas en juego (antes 195). Comprobado el 04-11-2026 en Edit (mallas y bloques con el mismo tamaño) y en Play (las patas se mueven con su articulación). Sin probar: lo de abajo. `Rendimiento` aún no cuenta las mallas (M4): una mascota con malla sale con bloques.

### 114.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa la Capibara (panel de pruebas o Lobby) y camina, párate y gira.
   ✅ Ves la versión de malla con textura (no bloques) pegada a ti; las patas andan; la cabeza oscila; sin piezas sueltas ni huecos.
2. [ ] Míra la desde atrás y de cerca.
   ✅ Grupa redondeada con flequillo y rabo bajo; el pelo se lee pintado sin pixelarse demasiado.
3. [ ] Pon una skin de mascota que valga para la Capibara (si existe) y quítala.
   ✅ Con skin sale con bloques y su paleta; sin ella, con malla.
4. [ ] Míra la en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Se ve con su textura (si el `ViewportFrame` la saca de bloques la primera vez, anótalo).

### 114.2 En el juego publicado

1. [ ] Equipa la Capibara al entrar y mide cuándo aparece la malla.
   ✅ Primero puede salir en bloques un instante y pasa a malla en la siguiente equipación; sin errores en la Salida.

## 115. Fase 20 Q5b: Tucán con malla (04-11-2026)

El Tucán se rehízo en bloques (barriga que engrosa en cuatro escalones, plumas pintadas en el babero, el manto, las alas y la cola, ojo con capas, pico con dientes de sierra, cola en escalones con rabadilla blanca y punta roja) y es ahora 5 mallas con textura (`Data/PetMeshes`: `Static`, `Head`, `WingL`, `WingR`, `Tail`; 1.502 triángulos frente al tope de 2.800; 6 piezas en juego, antes 212). Comprobado el 04-11-2026 en Edit (mallas y bloques con el mismo tamaño) y en Play (las alas baten a la vez y en espejo, la cola y la cabeza se mueven, el cuerpo queda quieto). Sin probar lo de abajo.

### 115.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa el Tucán y camina, párate y salta.
   ✅ Vuela a su altura con la malla (no bloques); las alas baten a la vez sin separarse del cuerpo; la cola se mueve; sin piezas sueltas.
2. [ ] Míralo de espaldas y de cerca.
   ✅ Rabadilla blanca, franja roja bajo la cola y punta de cola roja; las plumas se leen pintadas.
3. [ ] Míralo en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Se ve con su textura.
4. [ ] Pon la skin de mascota que valga para el Tucán (si existe) y quítala.
   ✅ Con skin, bloques con su paleta; sin skin, malla.

## 117. Skill de vídeo v2: guion, storyboard y borrador de Short, Reel y YouTube (04-11-2026)

Con CapCut cerrado, en los borradores `quetzalcoatl-mejora-es-v1` y `quetzalcoatl-mejora-en-v1` (ya instalados en CapCut; guion `docs/videos/shorts/quetzalcoatl-mejora.json`, tomas de «Upgrading Quetzaqatl»):

1. [ ] Abre el borrador vertical (Short) en CapCut.
   ✅ Abre sin avisos; hay pistas de vídeo, música (si el guion la pidió), título, pie y `voz`; las tomas de Studio no suenan.
2. [ ] Mira los encuadres de los cortes de Studio (`studio` y `visor`).
   ✅ No se ven la cinta de Studio, el Explorador ni la barra de abajo; el sujeto está centrado.
3. [ ] Genera la voz con el texto a voz sobre las frases de la pista `voz`.
   ✅ Las frases caben en su escena (sin cortes ni solapes).
4. [ ] Haz un borrador con `"formato": "youtube"` y ábrelo.
   ✅ El lienzo es 1920×1080, abre sin avisos y los textos quedan dentro del cuadro.
5. [ ] Añade una pista a `docs/videos/musica/` con su fila en el registro de licencias y ponla en `"musica"`.
   ✅ El borrador trae la música a volumen 0,3 y no pasa del final del vídeo.
6. [ ] Mide los minutos de retoque hasta exportar.
   ✅ 5 min o menos (objetivo).

## 116. Fase 20 Q5c: tanda A de mascotas con malla (Colibrí, Guacamaya y Quetzal) (04-11-2026)

Las tres aves se rehicieron en bloques y son ahora 5 mallas cada una (`Static`, `Head`, `WingL`, `WingR`, `Tail`; `Data/PetMeshes`). Triángulos de las mallas: Colibrí 1.094, Guacamaya 1.978 y Quetzal 2.598 (topes 2.800 las dos estándar y 5.600 el Quetzal, que es mítica y tiene su excepción en `Config.Budgets.Exceptions`: 320 piezas, 150 animadas, 5.600 triángulos); 6 piezas en juego cada una. Cambios de diseño: las colas pasaron de vigas inclinadas a escalones de bloques (ayudante `voxelStairs`) y las plumas se pintan en filas (`voxelScales`); Colibrí y Guacamaya con la barriga que engrosa en escalones; el Colibrí un 22 % más estrecho; el Quetzal un 16 % más estrecho, con las dos plumas largas con estandarte y la punta bifurcada, collar y hombreras doradas y mechones en la cresta; el hueco entre el pecho y la barriga de la Guacamaya, corregido. Tras la primera prueba del usuario se arreglaron las patas del Quetzal (los dedos de 0,4 quedaban en 0,34 con su factor de anchura y se pintaban sobre la pata: ahora 0,5, y la malla del cuerpo pasó a 2.742 triángulos, reimportada solo `Quetzal_Static`). Comprobado el 04-11-2026 en Edit (las mallas y los bloques miden lo mismo) y en Play (alas, cola y cabeza se mueven con su articulación y el cuerpo queda fijo). Sin probar lo de abajo. Papeleo con `tools/mascota.py`. Tras la primera prueba del usuario en Play se vio que la mascota equipada salía en bloques: `PetFollowers` la construye al entrar, antes de que lleguen las mallas, y no la rehacía. Ahora `PetModels.onMeshesReady` avisa al cargar las mallas de su especie y `PetFollowers` la reconstruye (atributo `Meshed` del modelo); comprobado en Play con el Quetzal equipado.

### 116.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa cada una (panel de pruebas) y camina, párate y salta.
   ✅ Vuela a su altura con la malla (no bloques); las alas baten a la vez sin separarse del cuerpo; la cola se mueve; sin piezas sueltas.
2. [ ] Míralas de frente con buena luz.
   ✅ Colibrí: gorguera magenta, pecho lila y antifaz; Guacamaya: cara blanca con líneas rojas, pico claro y mandíbula negra, sin hueco entre pecho y barriga; Quetzal: peto en escamas, cresta con mechones.
3. [ ] Míralas de espaldas y de cerca.
   ✅ Colibrí con el abanico de plumas separadas; Guacamaya con la cola roja y azul en escalones; Quetzal con las dos plumas largas con estandarte y la horquilla en las puntas.
4. [ ] Mide `Rendimiento` con las mallas cargadas (M4 aún no las cuenta) y mira que el Quetzal no dé alerta con su excepción.
   ✅ Sin alertas nuevas de mascotas.
5. [ ] Míralas en el nido y las vitrinas del Lobby, el Armario y `RewardModels`, y pon la skin de mascota que valga para cada una.
   ✅ Con malla y textura; con skin, bloques con su paleta.

## 117. Fase 20 Q5d: tanda B de mascotas con malla (Rana, Tortuga y Perezoso) (04-11-2026)

Las tres se rehicieron en bloques y son ahora mallas con textura (`Data/PetMeshes`): Rana 5 mallas (`Static`, `BL`, `BR`, `FL`, `FR`; 1.254 triángulos), Tortuga 6 (`Static`, `Head`, `FL`, `FR`, `BL`, `BR`; 1.206) y Perezoso 6 (`Static`, `Head`, `FL`, `FR`, `BL`, `BR`; 1.972), todas bajo el tope de 2.800. En juego son 6 o 7 piezas cada una. Cambios de diseño: los dedos de la Rana y los brazos del Perezoso dejaron de ser vigas inclinadas y son escalones de bloques (ayudantes `voxelFlat` y `voxelLimb`); escudos del borde, costuras, ojo con capas y escamas pintadas en la Tortuga; hebras de pelo pintadas en el Perezoso; saco vocal, motitas de piel mojada y párpado en la Rana. El Perezoso pasa de las 240 piezas de bloques (268): excepción en `Config.Budgets.Exceptions` (300). Comprobado el 04-11-2026 en Edit (mallas y bloques con el mismo tamaño y el mismo aspecto) y en Play (las patas, las aletas y los brazos se mueven con su articulación). Sin probar lo de abajo. Los brazos del Perezoso se leen como escaleras de cerca.

### 117.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa cada una y camina, párate y gira (la Rana a saltos).
   ✅ Se ven con malla y textura; la Rana patalea al saltar; la Tortuga rema con las aletas; el Perezoso mueve brazos y patas; sin piezas sueltas ni huecos.
2. [ ] Míralas de frente y de espaldas con buena luz.
   ✅ Rana con sus motas y el saco vocal; Tortuga con los escudos del borde y la cabeza con el ojo; Perezoso con la cara, la mochila y el pelo pintado por detrás.
3. [ ] Pon la skin de la Tortuga (Tortuga de Lava) y las que valgan para las otras, y quítalas.
   ✅ Con skin, bloques con su paleta; sin skin, malla.
4. [ ] Mide `Rendimiento` con las mallas cargadas y mira que el Perezoso no alerte con su excepción.
   ✅ Sin alertas nuevas de mascotas.
5. [ ] Míralas en el nido y las vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Con su textura.

## 118. Fase 24 grupo 24a: vistas unificadas (04-11-2026)

Lobby, Isla y Dunas quedan solo en tercera persona (zoom libre de 2,5 a 128 studs, `Config.View`); la primera persona la gestiona `CombatClient/ViewMode` y la usan el Laboratorio y, desde 24b, el modo shooter del campo de tiro. `FirstPersonController` pasó a `CombatClient/Controllers` y solo actúa en "First". Comprobado el 04-11-2026 en Play en el Lobby y en la Isla (modo, zoom mínimo y máximo, una sola `Mira`, consola limpia, cámara a 2,52 studs sin pasar a primera persona; perfil restaurado). Tras la primera prueba del usuario se arregló la cara del Labrador (con el cráneo redondeado la cara quedaba más estrecha que sus ojos y el brillo caía fuera): opciones `faceEdge` y `skullChamfer` de `DogOptions` solo para él, y se reimportó solo `Labrador_Head` (1.138 triángulos en total). Sin probar lo de abajo.

### 118.1 En el Studio de Dunas, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Entra a una partida y acerca la cámara con la rueda hasta el máximo.
   ✅ La cámara se queda a unos 2,5 studs y el personaje se sigue viendo; no pasa a primera persona. Ctrl sigue bloqueando la cámara.

### 118.2 En el Studio del Laboratorio, en Play

1. [ ] Entra a una partida con cada arma.
   ✅ Primera persona como antes: arma con brazos, mira en el centro, retroceso, recarga y fogonazo; sin errores de `FirstPersonController` ni `ViewMode` en la Salida.
2. [ ] Abre el selector de arma, los resultados y los Ajustes (⚙️), y pulsa Ctrl.
   ✅ El ratón se suelta con cada ventana y Ctrl lo suelta y lo vuelve a bloquear, como antes.
3. [ ] Muere y mira el espectador.
   ✅ Sin el arma delante de la cámara; el espectador sigue funcionando.

### 118.3 Cambio en caliente (se prueba con 24b en el campo de tiro)

1. [ ] Equipa un arma de la pared del campo y suéltala.
   ✅ Al equipar pasa a primera persona (la mira y el cursor de la vista); al soltarla vuelve la tercera persona con la mira, el apuntado al hombro y Ctrl del bloqueo de cámara.

## 118. Fase 20 Q5e: tanda C de mascotas con malla (Beagle, Labrador y Pointer) (04-11-2026)

Los tres perros comparten `voxelDog` y se rehicieron una vez: pelo pintado en filas de mechones (lomo, costados, grupa, pecho, patas, cabeza, hocico y cuello), cruz, grupa y pecho en relieve, ojo con anillo, párpado, ceja y segundo brillo, carrillos, fosas, puntos de bigote, gorguera, uñas y un **cráneo redondeado** (bóveda ancha con aristas en dos escalones, nuca achaflanada, cúpula de dos escalones y cara más estrecha; antes era un cubo). El Pointer ganó contraste en la cara (hocico gris pardo, iris ámbar, puntos canela sobre los ojos, en la mejilla y en el hocico, barbilla clara y lista blanca más ancha). Todo eso solo en el perro sin skin; con skin se queda el modelo de siempre. Son 12 mallas por perro (`Static`, `J1` la cadera fija, `Hip` la cadera que se dobla al girar, `Head` y las 8 patas `FL`, `FL2`, `FR`, `FR2`, `BL`, `BL2`, `BR`, `BR2`): Beagle 900, Labrador 1.126 y Pointer 812 triángulos (tope 2.800), y unas 19 piezas en juego (12 mallas y, sueltas, las orejas y los tramos de cola). El montaje con malla admite desde ahora la cadera que se dobla (`rig.bend`, grupo `Hip`). `tools/mascota.py` detecta los pares `FL2`/`FR2` y saltarse grupos con `--sin Ear* Tail*`. Excepciones de `Config.Budgets` para la versión de bloques (la que sale mientras cargan las mallas y la de las skins): Beagle, Labrador, Pointer, Perezoso y Quetzal. Comprobado el 04-11-2026 en Edit (mallas y bloques con el mismo tamaño) y en Play (con giro simulado la cadera `Hip` y `J1` se mueven a la vez, las patas y la cabeza se mueven con su articulación, la cola y las orejas siguen sueltas); `Rendimiento` sin alertas. Sin probar lo de abajo.

### 118.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa cada perro y camina, corre, gira en círculos cerrados y párate.
   ✅ Se ve con malla y textura; la cadera se dobla al girar sin separarse del cuerpo ni dejar huecos; las patas andan; la cola y las orejas se mueven; sin piezas sueltas.
2. [ ] Míralos de frente, de lado y de espaldas con buena luz (sobre todo la cabeza).
   ✅ Cráneo redondeado y no cuadrado; Pointer con la cara legible (ojos con iris, trufa oscura sobre el hocico claro, marcas canela); Beagle con la cola en bandera negra y blanca; Labrador con las bolsas y la cola de nutria.
3. [ ] Siéntalos y túmbalos (clips de reposo) y mira la cadera y las patas.
   ✅ Sin piezas atravesadas ni huecos al sentarse.
4. [ ] Pon la skin de perro pirata (vale para los tres) y quítala.
   ✅ Con skin, bloques con su paleta (sin el pelo pintado); sin skin, malla.
5. [ ] Míralos en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Con su textura.

## 119. Fase 24 grupo 24b: Armero y modo shooter del campo de tiro (04-11-2026)

El campo de tiro (v9) tiene un Armero en el muro derecho de la zona de preparación con las cuatro armas del Laboratorio colgadas en horizontal (boca hacia las dianas), cada una con su nombre debajo y a 8 studs de la siguiente, y un aviso «Dejar arma» al final. Equipar una pasa a primera persona con cargador, recarga y dispersión del Laboratorio (`Combat/LabMagazine`), sin habilidades ni guardia (`CombatRules.abilities` y `guard` aceptan ahora una función por jugador); soltarla, salir del campo o morir devuelve la tercera persona y las armas del rol. Comprobado el 04-11-2026 en Play en el Lobby, con el personaje teletransportado junto al Armero: atributos, mano y mochila, primera persona, cargador (5 → 4 al disparar, recarga a 5), cambio a los dardos (24), soltar, salir y morir. Sin probar lo de abajo. El rediseño del Armero (v9) se vio en edición, no en Play.

### 119.1 En el Studio del Lobby, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Entra al campo por el arco del Lobby (`CampoPrompt`), no por teletransporte, y camina hasta el Armero.
   ✅ Los avisos de cada arma salen al mirarla; se equipa la que miras, no la de al lado.
2. [ ] Equipa el rifle, apunta a una diana a 60 studs y dispara.
   ✅ Primera persona con el arma y los brazos; la bala daña la diana y sale el número de daño y el marcador de impacto; el contador de balas baja y recarga con R.
3. [ ] Prueba cada arma del Armero (dardos, rifle, arpón, ácido).
   ✅ Cada una con su cargador, su recarga y su dispersión; sin habilidades (Z/X/C/R/V), ni guardia (F), ni barra de combos.
4. [ ] Pulsa Ctrl con un arma equipada, y otra vez.
   ✅ El ratón se suelta y se vuelve a bloquear; en tercera persona, Ctrl vuelve a bloquear la cámara como antes.
5. [ ] Equipa un arma y mira el teléfono (emulador): botones de disparo, recarga y mira.
   ✅ El contador de balas no tapa ningún botón; «Mira» y recargar funcionan.

### 119.2 Con dos jugadores

1. [ ] Uno equipa el rifle y el otro lo mira desde fuera.
   ✅ El segundo ve el arma en la mano del primero con sus animaciones, y no se hacen daño.

### 119.3 Armas del rol (regresión)

1. [ ] Sin tocar el Armero, prueba en el campo el arco, el bastón y la cerbatana, y las habilidades del rol.
   ✅ Como antes del 24b: tercera persona, habilidades y guardia disponibles.

## 120. Fase 24 grupo 24c: ayuda de puntería solo para el táctil (04-11-2026)

`CombatService.aimShot` solo ayuda al jugador cuyo último control es táctil (`AimInputService`, avisado por `InputReporter` con `Remotes.ReportInput`); PC y mando apuntan a mano. Excepción: el Dardo curativo sigue enganchando a aliados con cualquier control. Números en `Config.AimAssist` (Touch: monos 3,5 studs / 3°, jugadores 2 / 1,5°; Lab: jugadores 1,5 / 1°). Los hechizos de cono (Rayo en cadena y Rayo de lava) no cambian. Comprobado el 04-11-2026 en Play en el Lobby, avisando por remoto: el atributo `AimInput` cambia y rechaza valores no válidos; con ratón, un disparo a 4 studs del eje del muñeco a 30 studs falla, y con táctil le da hasta unos 4,2 studs y falla a 5 y 6. Sin probar lo de abajo.

### 120.1 En el emulador de teléfono de Studio (Isla o Lobby, en Play)

1. [ ] Entra con el emulador de teléfono y mira el atributo `AimInput` del jugador en el Explorador.
   ✅ Vale "Touch" al tocar la pantalla; al mover el ratón o pulsar una tecla (en el emulador) pasa a "Mouse", sin saltar a "Mouse" solo por el ratón simulado justo después de un toque.
2. [ ] Cambia de ratón a táctil y dispara de inmediato contra un mono con la línea de tiro a unos 3 studs de él.
   ✅ Durante el primer medio segundo no hay ayuda (el disparo pasa de largo); después, sí.
3. [ ] Con táctil, dispara a un mono desde lejos (60 studs) y desde muy cerca (5 studs, por encima del hombro).
   ✅ Le da con la ayuda; apuntando entre dos monos el disparo pasa entre ellos.

### 120.2 Con dos jugadores (Dunas o Laboratorio)

1. [ ] Uno con teléfono y otro con PC se disparan con la misma arma, desde 30 y 60 studs.
   ✅ Solo el del teléfono recibe ayuda (más estrecha en el Laboratorio: 1,5 studs / 1°); ni el uno ni el otro se hacen daño en el Lobby.
2. [ ] Con el rol Médico en PC, lanza el Dardo curativo apuntando a un aliado que se mueve.
   ✅ Sigue enganchando al aliado; no engancha a monos ni rivales.

### 120.3 Habilidades (regresión)

1. [ ] Con ratón, usa el Disparo múltiple, la Flecha perforante y la Bola de fuego contra un mono.
   ✅ Salen hacia donde miras, sin centrarse solos; el Rayo en cadena y el Rayo de lava siguen con su cono de 25°.

## 121. Fase 20 Q5f: tanda D de mascotas con malla (Jaguarundí y Ocelote) (04-11-2026)

Los dos felinos comparten `voxelCat` y se rehicieron como los perros: cráneo redondeado (bóveda con aristas en dos escalones, nuca cortada y cara plana al ancho de la bóveda; antes un cubo), pelo pintado en filas de mechones (lomo, costados, grupa, pecho, cabeza, hocico, cuello y patas), grupa en relieve, ojo con anillo, párpado y brillo, ceja en relieve, fosas, puntos de bigote, brillo de la nariz y uñas. Las manchas del Ocelote se pintan sobre el pelo. Las orejas son ahora grupos propios (`EarL` y `EarR`, con un temblor leve al andar) y se quedan en bloques, igual que la cola. Solo en el felino sin skin y sin cristal: con skin y el **Jaguar de cristal se quedan en bloques** como antes. 12 mallas por felino (`Static`, `J1`, `Hip`, `Head` y las 8 patas): 836 triángulos cada uno y 11 (Jaguarundí) y 15 (Ocelote) piezas sueltas. Excepciones de `Config.Budgets` para la versión de bloques: Jaguarundí (`PetAnimated` 150) y Ocelote (`PetTotal` 380, `PetAnimated` 220, `PetTriangles` 4.600). Lección: una placa fina tiene que tocar la cara del bloque grueso o `tools/mallas.py` no la pinta (los ojos desaparecieron); el pelo pintado va más fino (0,06) que las placas. Comprobado el 04-11-2026 en Edit: mallas y bloques con el mismo tamaño (≤ 0,017 studs por grupo), vistas de frente y de espaldas. **No probado en Play** (ni el andar ni los clips); `Rendimiento` solo mide la versión de bloques y avisa por eso.

### 121.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa el Jaguarundí y el Ocelote, camina, corre, gira en círculos cerrados y párate.
   ✅ Se ven con malla y textura; la cadera se dobla al girar sin huecos; las patas andan; la cola y las orejas se mueven; sin piezas sueltas.
2. [ ] Míralos de frente, de lado y de espaldas con buena luz.
   ✅ Cráneo redondeado; ojos legibles (Jaguarundí amarillo, Ocelote verde) con pupila en rendija; manchas, anillos de la cola y rayas de la mejilla del Ocelote encima del pelo.
3. [ ] Haz que ataquen a un mono (clips `Jaguarundi` y `Ocelote`), siéntalos y túmbalos.
   ✅ Sin piezas atravesadas ni huecos; las orejas siguen a la cabeza.
4. [ ] Pon la skin de jaguar de lava (familia Felino) y quítala; mira también el Jaguar de cristal.
   ✅ Con skin y el de cristal, bloques con su paleta (sin pelo pintado); sin skin, malla.
5. [ ] Míralos en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Con su textura.

## 121. Fase 24 grupo 24d: calibración del tiro en el campo (04-11-2026)

El campo de tiro (v13) mide el tiro de armas y habilidades, también las cuatro del Laboratorio. `Projectiles.Shot.source` dice qué arma o habilidad es cada proyectil; las pantallas colorean cada marca por `source` y su lectura trae el vuelo medio. Una tercera consola «Calibración» (en el lado derecho de la línea de tiro) abre un panel con una fila por arma o habilidad usada y tres columnas de distancia (Cerca ≤30, Media 31–99, Lejos ≥100); el panel tiene los controles que colocan el muñeco de calibración a 10/30/60/100/130 studs, quieto o de lado a lado, y un botón «Borrar datos» (el único aviso de la consola es «Abrir»). Ese muñeco no es `RangeTarget`, así que la ayuda del táctil puede engancharlo y se mide. Comprobado el 04-11-2026 en Play en el Lobby (v10, con tres avisos), con el personaje teletransportado y disparando por remoto (`UseWeapon` y `UseAbility`): el muñeco se coloca a cada distancia y oscila ±8; el Bastón mágico a 30 studs da vuelo medio 0,24 s con 5 de 5 aciertos; la Bola de fuego y el rifle del Laboratorio llegan a las pantallas con su `source` y su vuelo; el panel se abre y se cierra y «Borrar marcas» lo vacía; salir del campo lo cierra. El usuario probó el 04-11-2026 el panel con un solo aviso y controles (v11) con el Bastón mágico quieto: a 30 studs 10 tiros, 100 %, vuelo 0,29 s; a 60, 20 tiros, 100 %, 0,41 s; a 100, 0 % (alcance del bastón) y un muñeco lateral del campo se cruzaba. Retoque posterior (v12): panel a la derecha y de 500 px de ancho (antes 749; celdas de tres columnas por línea con el texto repartido, controles que llenan la fila; medido en Play: 498×344 px, 0 etiquetas con texto cortado), acierto solo sobre el muñeco de calibración, distancia real en cada celda, `NearMax` 40 y el muñeco en un carril libre (x = -32, único pasillo de 135 studs sin obstáculos según un barrido con esfera; vaivén ±3 a 1,3 rad/s; rótulo «CARRIL DE CALIBRACIÓN»), sin probar en Play: sin probar lo de abajo.

### 121.1 En el Studio del Lobby, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

0. [ ] Guarda el place con el campo v13 (`require(game.ServerScriptService.Server.World.RangeBuilder).build()` en edición) o deja que el servidor lo reconstruya al arrancar, y mira la consola «Calibración».
   ✅ Solo hay un aviso («Abrir»); el panel sale a la derecha y no tapa los avisos de arriba a la derecha (PC de 1167 px de ancho) ni los botones de disparo en teléfono. En el panel, los botones 10/30/60/100/130 colocan el muñeco, «Quieto» / «De lado a lado» lo mueven, el activo va en dorado y «Borrar datos» vacía las filas y las marcas de las pantallas. Con dos jugadores, el cambio de distancia o movimiento de uno lo ve el otro en su panel.

1. [ ] Entra por el arco del Lobby (no por teletransporte), abre el panel de «Calibración» y míralo en PC.
   ✅ Se lee todo sin desplazamiento (hasta 6 filas y los controles); las celdas Cerca / Media / Lejos con tiros, % de acierto, vuelo y desvío no se solapan; los colores de las filas son los de las marcas.
2. [ ] Abre el panel con el emulador de teléfono (ancho 464 px en `compact`, no medido).
   ✅ Compacto (hasta 3 filas y dos filas de controles); sin texto cortado en las celdas de 112 px ni en la leyenda (5 líneas), con los botones y el texto legibles y sin tapar los botones de disparo.
3. [ ] Dispara con clic real a la pantalla corta y a la larga con una arma de cada tipo (honda, arco, bastón, cerbatana) y con las habilidades (Disparo múltiple, Flecha perforante, Bola de fuego, Tiro certero, Dardo curativo).
   ✅ Cada marca sale del color de su arma o habilidad; la lectura dice su nombre, el vuelo y la media solo de ese `source`. Un abanico del Disparo múltiple o una Flecha perforante pinta una sola marca (por `MarkMinInterval`) pero el panel cuenta todos los proyectiles.
4. [ ] Dispara al muñeco de calibración a 10, 30, 60, 100 y 130 studs, quieto y de lado a lado, con arma de rol y con táctil (emulador).
   ✅ El % de acierto baja con la distancia y el movimiento; con táctil, la columna de ayuda (°) tiene valores y con ratón no.
5. [ ] Equipa cada arma del Armero y dispara a las pantallas y al muñeco; después «Dejar arma».
   ✅ Cada una con su fila y su dispersión configurada; el arpón y el cañón de ácido (arco) dibujan su caída; «Dejar arma» devuelve las armas del rol.
6. [ ] Con el rifle del Armero equipado (primera persona), abre el panel con E, usa el ratón y ciérralo con Ctrl y con ✕.
   ✅ El cursor sale al abrir y vuelve a bloquearse al cerrar; la mira no estorba (hoy sigue visible con el panel abierto).
7. [ ] Colócate en el carril de calibración (franja cian junto a la línea de tiro, x = -32) y pon el muñeco a 10 studs en movimiento.
   ✅ El vaivén (±3) no toca ninguna caja, diana ni el muro.
8. [ ] Dispara al muñeco a 100 y 130 studs desde el carril, quieto y de lado a lado.
   ✅ Ningún otro muñeco ni obstáculo se cruza; el acierto solo cuenta lo que da al muñeco de calibración y los tiros a las pantallas no bajan el %.
   Nota: el bastón tiene alcance 100, así que a 100 y 130 studs falla por alcance, no por puntería (hace falta el Bastón de lava, 140).
9. [ ] Dispara la Bola de fuego a la pantalla larga (135 studs).
   ✅ Llega a la pantalla larga o, si su alcance máximo (≈100) no llega, el panel lo cuenta como tiro sin impacto en pantalla.
10. [ ] Con 2 jugadores en el campo, dispara los dos a la vez.
    ✅ Cada uno ve solo sus marcas y su panel; las estadísticas no se mezclan.
11. [ ] En Studio, pulsa «Exportar» del panel.
    ✅ Aparece `ServerStorage.CalibracionExportada` con el JSON de la sesión; se usará en 24f.
12. [ ] Repite la calibración APUNTANDO con la mira (clic derecho, zoom y mira de cada arma: honda, arco, bastón, cerbatana y las cuatro del Laboratorio con su visor, punto rojo o mira de hierro).
    ✅ La dispersión a la cadera (1,5° en bastón y arco) baja a 0 al apuntar (`Config.Aim.AdsSpreadDegrees`); el rifle del Laboratorio con zoom es exacto (`zoomExact`); el desvío en pantallas y el acierto mejoran frente a disparar sin apuntar.
    Medido el 04-11-2026 por remoto (`aiming=true` enviado a mano, sin el clic derecho real): bastón, arco y cerbatana dan 0,8–1,1° a la cadera y 0,00–0,03° apuntando, a 45 y a 99–129 studs (el ángulo no cambia con la distancia); el rifle con zoom parado y andando, y el arpón y los dardos apuntando, bajan como se espera. Falta probarlo con el clic derecho real y con las miras dibujadas.
13. [ ] Calibra disparando EN EL AIRE (salta y dispara) y corriendo, con armas del rol y del Laboratorio.
    ✅ El Laboratorio suma la dispersión en el aire (`air`, p. ej. 5° en el rifle) y en movimiento (`moving`, 2,5°); las armas del rol no cambian. El panel muestra más desvío y menos acierto que quieto.
    Medido el 04-11-2026 con el personaje andando y saltando por programa: coincide con lo teórico (RMS = 0,7 × el cono) en las cuatro armas del Laboratorio. Las armas del rol no cambian con el movimiento ni el aire. Dos cosas no cuadran y están en los pasos 14 y 15.
14. [ ] Dispara saltando (en el ascenso y en el descenso) con el bastón, el arco y la cerbatana, con ping normal y con 150 ms de latencia simulada.
    ✅ Los tiros salen por donde miras. Hoy, con la velocidad vertical alta, la cabeza del cliente va 2,5–6 studs por delante de la del servidor y a veces `acceptedOrigin` (tolerancia 5 studs) descarta el origen y el tiro sale de la cabeza del servidor, paralelo y desplazado 3–9 studs en vertical. Si pasa, hay que arreglarlo en el 24e (tolerancia según velocidad vertical y lag).
15. [ ] Con el lanzadardos del Armero, dispara una ráfaga larga (10 tiros) parado.
    ✅ Hoy cada tiro sale exacto: la dispersión que se acumula (`perShot` 0,35° hasta `maxShots` 3) se recupera (`recover` 6°/s) antes del tiro siguiente a 0,15 s, así que no pesa nunca. Decide si se sube `perShot` o se baja `recover` (< 2,3°/s).


## 122. Fase 20 Q5g: Ajolote con malla (04-11-2026)

El Ajolote (mítica, +100 %) se rehízo para la malla. Sus branquias (3 plumas por lado con tallo en degradado y 4 pares de filamentos), la cola, los brazos, las patas y los dedos eran vigas inclinadas (69 piezas sueltas) y pasan a **escalones de bloques alineados** (`voxelSteps`, ayudante nuevo): ya no queda ninguna pieza suelta. Cabeza **aplanada y ovalada**: la más ancha y alta en la base del cráneo y las mejillas (a ras del lomo) y cada vez más estrecha y baja hacia el hocico, con la frente subiendo suave y la **trompa larga** en dos escalones; los ojos van encima de la frente, en un bulto con anillo, iris violeta, pupila y brillos pintados; rubor en el costado del hocico, fosas encima y la sonrisa en la punta; piel pintada con mechones de tres tonos de rosa perlado en lomo, costados, cola y coronilla. 9 mallas (`Static`, `Tail`, `Head`, `GillL`, `GillR`, `FL`, `FR`, `BL`, `BR`) con **4.732 triángulos** (1.506 cada branquia, que es lo que más pesa; la cabeza 182). Excepción de `Config.Budgets` para la versión de bloques (`PetTotal` 420, `PetAnimated` 340, `PetTriangles` 4.900), que es la que mide `Rendimiento` (402 piezas y 4.812 triángulos, sin alertas). Comprobado el 04-11-2026 en Edit: la malla mide lo mismo que los bloques (diferencia de 0,036 studs en el largo, la punta de la cola), vistas de frente, de 3/4 y de espaldas. **No probado en Play** (ni las branquias abriéndose ni la cola ondeando).

### 122.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa el Ajolote, camina, corre, gira y párate.
   ✅ Se ve con malla y textura; las branquias se abren y cierran sin separarse de la cabeza; la cola ondea sin rendijas entre tramos; las patas andan; sin piezas sueltas.
2. [ ] Míralo de frente, de lado, de espaldas y desde arriba con buena luz.
   ✅ Cabeza plana y ovalada que sube suave hacia la nuca, con la trompa larga; ojos encima de la frente, legibles, con iris violeta; lunares perlados en el lomo; branquias carmesí con degradado.
3. [ ] Haz que cure (clip `Ajolote`: abre las branquias y las agita), siéntalo y túmbalo.
   ✅ Branquias y cola siguen su hueso; sin piezas atravesadas.
4. [ ] Míralo en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Con su textura; sin tirones al cargar (4.732 triángulos, cerca del tope de 4.900).

## 123. Fase 20 Q5h: Mono X-7 con malla (04-11-2026)

La última mascota de la tanda E (legendaria) se rehízo para la malla. Las 24 vigas inclinadas de las mangueras pasan a escalones alineados (`voxelSteps`) con tres abrazaderas de cobre cada una. El neón pequeño (venas de los brazos, luces de los grilletes y niveles de los depósitos) se pinta en la malla con un cian vivo; **siguen sueltos y brillando** el cartel X-7 (18 píxeles), la antena (punta y halo), el vial de suero y su cristal, las chispas, los pilotos de la mochila, los ojos del visor y el visor reflectante. Más detalle: pelo azul pintado en cuatro tonos (joroba, lomo, costados, grupa, brazos y piernas), casco con costuras y tornillos y rayones en el aro de cobre, y la mochila con marco en el panel, tornillos y bandas de cobre en los depósitos. **El aura** (dos emisores de partículas) colgaba de `Body` y `Pack`, que la malla destruye: ahora cuelga de dos piezas invisibles, `AuraBody` y `AuraPack`. 7 mallas (`Static` 1.558, `Head` 366, `J1` la antena, `ArmL`, `ArmR`, `LegL` y `LegR`) con **2.884 triángulos** (tope 6.200) y 40 piezas sueltas en juego (antes 69); la textura de `Static` es de 1024×1024. Excepción de `Config.Budgets` para la versión de bloques, que mide `Rendimiento` (`PetTotal` 500, `PetAnimated` 230). Comprobado el 04-11-2026 en Edit: las mallas se ven como el diseño, de frente y de espaldas, con el aura saliendo del cuerpo; el ancho difiere 0,06 studs (los músculos finos de los antebrazos ahora van pintados). **No probado en Play.**

### 123.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa el Mono X-7, camina, corre, gira y párate.
   ✅ Se ve con malla y textura; los brazos y las piernas andan; la antena se balancea; el aura azul sale del cuerpo y de la mochila; sin piezas sueltas.
2. [ ] Míralo de frente, de lado, de espaldas y de cerca con buena luz.
   ✅ Pelo azul con mechones; casco con costuras y el visor con los ojos cian; cartel X-7 brillando a la espalda; mangueras con abrazaderas; venas y luces de los grilletes en cian vivo (pintadas, sin brillo propio).
3. [ ] Haz que ataque a un mono y que cure (clip `X7`), siéntalo y túmbalo.
   ✅ Sin piezas atravesadas; la antena y las mangueras siguen al cuerpo.
4. [ ] Míralo en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Con su textura; sin tirones al cargar (3 texturas de 1024 de ancho).

## 124. Fase 20 Q5i: rediseño del Jaguar de cristal, en bloques (04-11-2026)

El Jaguar de cristal se queda **en bloques** (el vidrio y el neón no entran en la malla), pero se rehízo: cuerpo de vidrio azul profundo (antes blanco translúcido) con un **núcleo de neón** dentro del pecho, la cadera, el cráneo, las patas y la cola, tira oscura opaca por el lomo, gema de neón en dos capas engastada en un marco oscuro en el pecho, cabeza con el cráneo redondeado, ceño oscuro opaco sobre los ojos, hocico y barbilla de azul oscuro opaco y nariz de neón, zarpas oscuras con las rendijas de los dedos en neón y anillos oscuros en la rodilla. **Cristales** más grandes y el doble (22): cresta de siete por el lomo, racimos de tres por hombro y dos por cadera, cuerno en la frente con dos más pequeños y un colmillo de cristal en cada mejilla (giran con la cabeza); la cola acaba en un cristal de tres escalones con núcleo. **El brillo que emite va a la mitad**: el neón (núcleos, gema, garras, nariz, manchas y cristales) usa el color a medio valor, la luz del corazón baja de 1,2 a 0,6 y los destellos (`Sparkles`) a media intensidad; los ojos siguen igual. Con skin (la de Magma y las de la familia Felino) se conserva el cuerpo de la skin, pero lleva los cristales nuevos. 219 piezas y 2.828 triángulos (antes 138): excepción de `Config.Budgets` (`PetAnimated` 140, `PetTriangles` 3.200); `Rendimiento` sin alertas (la skin de Magma, 108 piezas animadas de 110). Comprobado el 04-11-2026 en Edit: vistas de frente, 3/4 y de espaldas. **No probado en Play** (andar, cola, cristales de la cabeza girando, destellos).

### 124.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Equipa el Jaguar de cristal, camina, corre, gira y párate.
   ✅ Núcleo cian visible a través del vidrio sin cegar; la cola y las patas andan; los cristales de la cabeza giran con ella; sin piezas sueltas ni cristales atravesando el cuerpo.
2. [ ] Míralo de frente, de lado y de espaldas con buena luz y por la noche.
   ✅ Se lee como cristal facetado, no blanco; la gema del pecho y las garras brillan a media intensidad (más suave que antes); los destellos no tapan el modelo.
3. [ ] Ponle la skin de jaguar de lava y quítala.
   ✅ Con skin, su cuerpo y sus colores con los cristales nuevos; sin skin, el de cristal.
4. [ ] Míralo en el nido y vitrinas del Lobby, el Armario y `RewardModels`.
   ✅ Sin tirones al cargar (219 piezas).

## 125. Fase 24 grupo 24e: balística (04-11-2026)

`Data/Ballistics` + `Shared/Ballistics`: caída suave (≤ 3 studs al alcance en honda, bastón y Bola de fuego), frenado del aire, daño según la distancia (solo armas, hasta ~80-85 % al alcance), empuje a monos (`Config.Ballistics`, `PushScale` 25 desde 24f), ayuda táctil estrechada de 60 a 100 studs (`FarDegrees` 1,8), adelanto táctil hasta 1,3 s, `recover` del lanzadardos a 1,5 y tolerancia del origen mayor en el aire (+9 studs, tope 16). Las habilidades proyectil usan `rewind`/`lead` con el ping (sin origen ni número del cliente, sin zonas: quedan pendientes). Medido en Lobby (Play): sin errores; caídas y falloff dentro de lo previsto.

### 125.1 En el Studio del Lobby, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Dispara bastón, honda y Bola de fuego a un blanco lejano con ratón.
   ✅ La bala cae un poco al final (≤ 3 studs) y se ve igual que donde da; arco y cerbatana siguen rectos.
2. [ ] Salta y dispara 10 veces (con latencia real si puedes).
   ✅ Los disparos salen de donde se ve el arma, sin saltos de 3-9 studs.
3. [ ] Con el emulador táctil, apunta con desvíos de 1 a 5 studs del muñeco a 30, 60 y 100 studs.
   ✅ A 30 y 60 enganchan hasta ~3; a 100 hasta ~3 (antes ~5).
4. [ ] En la Isla, dispara la Bola de fuego en táctil a un mono que corre a 100 studs.
   ✅ Acierta bastante más que sin ayuda (el adelanto no se pudo medir con el muñeco anclado).
5. [ ] En la Isla, dispara a un Titi, un Mandril y un Gorila con bastón y cerbatana.
   ✅ El pequeño se echa atrás un poco; el Gorila y los jefes casi nada; nunca a un jugador. Si todos salen volando o ninguno, ajusta `Config.Ballistics.PushScale`.
6. [ ] Lanzadardos en ráfaga de 10 tiros parado.
   ✅ Los primeros tiros son exactos y luego se abre algo (cono hasta ~1,65°).

## 126. Fase 20 Q6a: Chaleco de pelaje del Guerrero con malla (04-11-2026)

Primera armadura con malla: `Data/ArmorMeshes` (Armor.FurVest.Guerrero), `ArmorModels.wear` (grupos `<Anclaje>_<Soft|Hard>`, escala por `ancla.Size / ref`), `Mallas.volcarArmadura` y `tools/armadura.py`. 8 mallas (solo Soft: tela y cuero) y 14 piezas sueltas (colmillos, plátano, collar) en lugar de 166 de bloques; 1.238 triángulos. Probado en Edit con tres avatares (bloques, malla y uno 0,8×1,1×1,3): la malla coincide con los bloques de espaldas. Sin probar en Play, en cliente, en el Armario ni con las mallas aún sin cargar.

### 126.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Fabrica el Chaleco de pelaje con un Guerrero y mírate desde atrás y de cerca.
   ✅ Se ve la huella de mano dorada con el manto de pelaje encima y el bajo en mechones; sin parpadeos ni piezas fuera de sitio. Sin errores de `CreateMeshPartAsync` en la Salida.
2. [ ] Recién entrado en la partida, mira la armadura en los primeros segundos.
   ✅ Primero aparece en bloques y se cambia sola a malla al cargar, sin quedarse a medias.
3. [ ] Camina, corre, salta y golpea con un arma.
   ✅ La armadura sigue el cuerpo y los brazos sin separarse ni atravesarlos.
4. [ ] Con un segundo jugador (otro tamaño de avatar), míralo de cerca.
   ✅ El chaleco le queda ajustado al torso y los brazos; no flota ni lo atraviesa.
5. [ ] Cambia de rol (Cazador, Mago, Médico) y vuelve al Guerrero con el Chaleco puesto.
   ✅ Los otros roles siguen en bloques sin cambios; el Guerrero vuelve a malla sin duplicar piezas.
6. [ ] Abre el Armario y la vista previa del traje y de la armadura; cambia varias veces.
   ✅ No se queda ninguna armadura antigua encima ni se rompe la vista previa.
7. [ ] Mide con `Rendimiento` tras M4 (cuando cuente las mallas).
   ✅ El Guerrero con malla: 22 piezas y ~1.250 triángulos. Hoy mide la versión de bloques (excepción `FurVest_Guerrero` en `Config.Budgets`).

## 127. Fase 24 grupo 24f: sección «Distancia» de Equilibrio (04-11-2026)

`Equilibrio` tiene la sección **15. Distancia** (`secciones.distancia`): caída, vuelo a 30/60/100 st, daño al alcance y empuje (Titi, Mandril, Gorila) de cada proyectil; alcance de la ayuda táctil; y, si existe `ServerStorage.CalibracionExportada`, lo medido frente a lo previsto. Alertas nuevas en `LIMITES` (caída, daño mínimo, ayuda a 100 st, desvío del vuelo). Ejecutada en el Studio de la Isla: sin errores y sin alertas de «Distancia». `Config.Ballistics.PushScale` queda en 25 (Titi 16, Mandril 8-9, Gorila 0-6 según el proyectil).

### 127.1 En el Studio del Lobby, en Play, y después en el de la Isla

1. [ ] En el Lobby, abre el panel «Calibración», dispara las armas a 30, 60 y 100 st y pulsa «Exportar».
   ✅ Aparece `ServerStorage.CalibracionExportada`.
2. [ ] En el Studio de la Isla (edición), copia ese valor en un `StringValue` `CalibracionExportada` de `ServerStorage` y ejecuta `Equilibrio`.
   ✅ La sección 15 trae la tabla de calibración con el desvío del vuelo por arma y distancia; sin alertas de «Distancia» (si salen, el vuelo real no coincide con `Data/Ballistics`).

## 128. Fase 24: revisión de la calibración con la cámara bloqueada (04-11-2026)

Ctrl enciende y apaga el bloqueo de cámara propio del juego (`CombatClient/CameraLock`). El de Roblox queda desactivado con `EnableMouseLockOption` en false en `lobby`, `island` y `dunas.project.json`, así que hace falta reconectar Rojo y publicar. Con el bloqueo, el ratón va al centro, el personaje mira hacia la mira y la cámara va al hombro (`Config.Aim.LockOffset`); al apuntar pasa al hombro de siempre. La mira del bastón marca con un punto dónde cae el tiro de verdad y con un anillo fino el área del remate. La calibración separa las filas por arma y vista (`Data/AimViews`: Libre, Bloqueo, Bloqueo + mira, 1.ª persona, Táctil y Mando). Probado en Studio (Lobby e Isla, Play, un jugador): Ctrl enciende y apaga el bloqueo (ratón al centro, `CameraOffset` 1,75, `AutoRotate` false y vuelta a lo normal); apuntando con bloqueo, el rayo del centro de la cámara y el del disparo dan en el mismo punto; la calibración separa «MagicStaff|Lock» de «MagicStaff|LockAim»; la mira nueva se dibuja (punto de 6 px y anillo fino). Sin probar lo de abajo.

### 128.1 En los places publicados (tras reconectar Rojo, guardar y publicar Lobby, Isla y Dunas)

1. [ ] Entra en el Lobby, la Isla y Dunas, y pulsa Ctrl sin abrir el menú de Roblox.
   ✅ Ctrl bloquea y desbloquea la cámara; el icono del ratón es la mirilla de bloqueo.
2. [ ] Con un arma a distancia en cada place, pulsa Ctrl y clic derecho, y dispara a un blanco de cerca (10 studs) y de lejos.
   ✅ Apunta y el tiro va al punto de la mira, también a 10 studs.

### 128.2 En Studio, en Play, con un jugador (Lobby e Isla; copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Abre el menú de Roblox, escribe en un cuadro de texto y abre una ventana del juego; ciérralo todo.
   ✅ Mientras está abierto, el bloqueo se suelta; al cerrar, vuelve.
2. [ ] Pon el bloqueo con Ctrl, muere y reaparece; después vuelve a pulsar Ctrl.
   ✅ La cámara no se queda pegada tras reaparecer y Ctrl sigue funcionando.
3. [ ] Con el bloqueo puesto, siéntate en un asiento (si hay) y levántate.
   ✅ La cámara no se queda atascada ni al sentarse ni al levantarse.
4. [ ] Con el bloqueo puesto, cambia de arma.
   ✅ La cámara y la mira no dan saltos; el arma nueva apunta con Ctrl y clic derecho.
5. [ ] Con el mismo arma (p. ej. el Bastón mágico), mide con la consola «Calibración» las vistas Libre (sin Ctrl), Bloqueo (Ctrl) y Bloqueo + mira (Ctrl y clic derecho), con los botones de distancia del panel en 30 y en 100 studs.
   ✅ El panel tiene una fila «arma · vista» por cada vista y el desvío Δ coincide entre Libre, Bloqueo y Bloqueo + mira a cada distancia.
6. [ ] Dispara hasta que el siguiente tiro sea el remate (el anillo de la mira lo indica) y luego un tiro normal.
   ✅ El anillo se marca (más grueso y claro) cuando el siguiente tiro es el remate y vuelve a su tono tenue después.
7. [ ] Con el Bastón mágico (y con los de otras rarezas y los aspectos míticos de bastón), apunta con Ctrl y clic derecho a un muñeco a unos 30 studs y dispara, de frente y de lado, con la cámara cerca y lejos.
   ✅ El hechizo nace en el cristal de la punta del bastón (no en la mano ni en el centro de la empuñadura) y llega al punto de la mira. Las habilidades del mago siguen saliendo de sus manos.
8. [ ] Con el ratón físico, Ctrl puesto y el clic derecho mantenido, pulsa «Borrar marcas» en el campo de tiro, apunta a la pantalla corta (a unos 50 studs), sin mover el ratón dispara una vez y mira la consola «Calibración» (fila «Bastón mágico · Bloqueo + mira», columna Media).
   ✅ La marca cae sobre el punto de la mira y el Δ es de décimas de studs (antes salía unos 4,7 studs, 5°, por encima: el punto de la mira se dibujaba 58 px más abajo por la barra superior de Roblox, `Sights`; hay que probarlo con la barra superior visible, que es como lo ve un jugador). Repítelo manteniendo el clic izquierdo (disparo automático) y moviendo el ratón entre tiros: ningún tiro se desvía del punto de la mira.

### 128.3 Campo de tiro con 2 jugadores (Lobby, en Play)

1. [ ] Cada jugador abre su panel «Calibración» y dispara con las vistas Libre y Bloqueo.
   ✅ Cada uno ve solo sus filas por vista y el panel enseña «arma · vista».
2. [ ] Mira el panel en PC y en el emulador de teléfono con las filas llenas.
   ✅ Se lee todo sin desplazamiento: hasta 6 filas en PC y 3 en teléfono (`MAX_ROWS`), aunque ahora hay más filas por arma.

### 128.4 Teléfono, emulador y mando

1. [ ] Con un teléfono real o el emulador, dispara con el control táctil y mira el panel de calibración.
   ✅ La vista Táctil aparece en el panel; la mira del bastón (punto y anillo) se lee bien.
2. [ ] Con un mando, dispara en el campo de tiro y mira el panel.
   ✅ La vista Mando aparece en el panel.

### 128.5 Laboratorio y modo shooter del campo (primera persona, Play)

1. [ ] En el Laboratorio, pulsa Ctrl con el cursor libre.
   ✅ Ctrl sigue siendo del cursor y no activa el bloqueo de cámara.
2. [ ] En el modo shooter del campo de tiro (primera persona), pulsa Ctrl.
   ✅ Ctrl no activa el bloqueo de cámara.

### 128.6 Equilibrio con una exportación nueva (Studio de la Isla, edición)

Una exportación anterior a esta fase no tiene sufijo de vista, así que `Equilibrio` solo ve las filas por vista con una nueva.

1. [ ] Exporta el panel «Calibración» del Lobby (con las vistas), copia el JSON en un `StringValue` `CalibracionExportada` de `ServerStorage` y ejecuta `Equilibrio`.
   ✅ La sección «Distancia» trae las filas por arma y vista; sin alertas nuevas de «Distancia».

## 129. Fase 20 Q6b: Guerrero de hueso, plata y volcánica con malla (04-11-2026)

Los tres rangos que faltan del Guerrero con malla (`Data/ArmorMeshes`, `Mallas.volcarArmadura`): hueso (16 mallas, 2.998 triángulos, 0 sueltas), plata (16 mallas, 2.874 + 1.096 sueltos) y volcánica (8 mallas, 2.582 + 3.134 sueltos, 139 piezas sueltas de neón y obsidiana con brillo). Cambios de diseño: escalones en lugar de piezas giradas, calaveras de mono con ceja, fosas nasales y dientes, gorila de plata con ceño, y la volcánica con hombreras (brasero, faldones, púas, remaches), pectorales, vientre, clavícula y espalda (laderas, rocas, brasas) con más detalle. Topes de triángulos crecientes (`ArmorTriangles` IV pasa de 10.800 a 21.000) y excepciones de piezas para los tres (`BoneArmor_Guerrero` 220, `SilverArmor_Guerrero` 250, `VolcanicArmor_Guerrero` 510, que miden la versión de bloques). Probado en Edit con cuatro rangos, un avatar 0,8×1,1×1,3 y los bloques al lado: la forma coincide. Sin probar en Play, en cliente ni en el Armario.

### 129.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Consigue cada armadura de Guerrero (hueso, plata y volcánica) y mírate de espaldas y de frente.
   ✅ Se ven con malla (hueso 16 piezas, plata ~47, volcánica ~137) y sin parpadeos ni piezas fuera de sitio.
2. [ ] Mira la volcánica con luz de día y de noche.
   ✅ El neón y las llamas se ven bien; el basalto de la malla sale algo más cálido y claro que el de bloques (la malla no puede usar el material Basalt). Si molesta, hay que oscurecer los colores de la malla de la volcánica.
3. [ ] Mira de cerca la espalda de la volcánica (laderas, rocas del pie, brasas sobre el cráter) y las hombreras (brasero con la llama, faldones, púas).
   ✅ Nada se corta ni parpadea (z-fighting) y la llama sigue echando humo y chispas.
4. [ ] Mira de cerca el gorila de plata y las calaveras de las hombreras del hueso y de la plata.
   ✅ El gorila tiene el ceño fruncido; las calaveras tienen fosas nasales y dientes.
5. [ ] Camina, corre, salta y golpea con las tres armaduras puestas, y con otro jugador de distinto tamaño.
   ✅ La armadura sigue el cuerpo y los brazos sin separarse ni atravesarlos, y le queda ajustada al otro avatar.
6. [ ] Recién entrado, mira la armadura en los primeros segundos (con las mallas sin cargar).
   ✅ Sale en bloques y pasa sola a malla al cargar, sin quedarse a medias.
7. [ ] Comprueba que los otros roles (Cazador, Mago, Médico) con estas armaduras siguen igual.
   ✅ Siguen en bloques, salvo las calaveras de runas del Mago y el faldón de la volcánica, que cambian un poco (calavera de bloques; sin inclinación de 0,1).
8. [ ] Mide con `Rendimiento` tras M4 (cuando cuente las mallas).
   ✅ Guerrero con malla: hueso ~3.000, plata ~4.000 y volcánica ~5.700 triángulos en juego; sin alertas de piezas.

## 130. Fase 20 Q6c: Cazador de los cuatro rangos con malla (05-11-2026)

Capa de rastreador (11 mallas, 2.634 triángulos), armadura de cazador (15, 3.816), manto plateado (15, 3.940 + 372 sueltos) y manto de brasa (15, 3.416 + 1.640 sueltos). Los ayudantes compartidos (hoja, carcaj, correa, abanico, estrella, capucha, manto plateado) usan escalones solo si lo que se viste tiene malla (`STEPS` en `ArmorModels`); sin malla conservan su versión de pocas piezas, así que Mago y Médico no cambian. Probado en Edit con un avatar normal y otro ancho. Sin probar en Play.

### 130.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Consigue cada armadura de Cazador y mírate de espaldas y de frente.
   ✅ Se ven con malla (carcaj en diagonal con flechas, abanico de hojas, capucha) y sin parpadeos ni piezas fuera de sitio.
2. [ ] Dispara el arco y corre con las cuatro.
   ✅ El carcaj y las hojas siguen el cuerpo sin separarse ni estorbar al brazo del arco.
3. [ ] Mira la volcánica del Cazador de noche.
   ✅ Las plumas de las flechas y el aro del carcaj brillan; la llama de la boca del carcaj sigue ardiendo.
4. [ ] Entra y mira la armadura en los primeros segundos.
   ✅ Sale en bloques (versión de pocas piezas) y pasa sola a malla al cargar.
5. [ ] Comprueba Mago y Médico con las mismas armaduras.
   ✅ Siguen igual que antes.

## 131. Fase 20 Q6d: Mago de los cuatro rangos con malla (05-11-2026)

Manto de amuletos (14 mallas, 2.650 triángulos), túnica de runas (12, 1.922 + ~2.330 sueltos de neón), manto de cristal (9, 1.866 + ~1.120 sueltos) y túnica de lava (16, 2.068 + ~2.160 sueltos). Con malla, el constructor convierte bolas, cilindros, óvalos y colmillos alineados en bloques (`STEPS`), los aros que no son de neón van en píxeles y todos llevan detalle pintado (`mageDetail`: costuras, bandas, flecos, hombreras con rayas y remaches, anillos en los antebrazos). La volcánica usa las hombreras ricas del Guerrero. Las calaveras de las hombreras del hueso miran hacia atrás. El neón y el cristal (runas, sellos, cristales) siguen sueltos. Probado en Edit con un avatar normal y otro ancho. Sin probar en Play.

### 131.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Consigue cada armadura de Mago y mírate de espaldas y de frente.
   ✅ Se ven con malla (atrapasueños, sello de runas, corona de cristales, sol de lava) y sin parpadeos ni piezas fuera de sitio.
2. [ ] Lanza habilidades con las cuatro puestas, de día y de noche.
   ✅ El neón de las runas y los cristales brilla y sigue el cuerpo; la llama de las hombreras de la volcánica echa humo.
3. [ ] Mira de cerca las hombreras del hueso (calaveras) y de la volcánica (brasero, faldones, púas).
   ✅ Las calaveras muestran la cara hacia atrás con ojos que brillan; nada parpadea.
4. [ ] Entra y mira la armadura en los primeros segundos.
   ✅ Sale en bloques y pasa sola a malla al cargar.
5. [ ] Comprueba Guerrero, Cazador y Médico con estas armaduras.
   ✅ Guerrero y Cazador igual que antes (con malla); Médico en bloques sin cambios.

## 132. Fase 20 Q6e: Médico de los cuatro rangos con malla (05-11-2026)

Bandolera de curandero (12 mallas, 3.370 triángulos), peto de curandero (16, 2.054), manto de sanador (14, 3.776) y manto de azufre (16, 3.334); sueltos: frascos de vidrio, gemas de neón y los cristales de azufre. Con malla, las vendas de los antebrazos, las correas de la mochila, el tótem sanador y el abanico de hierbas van sin giros, y llevan el detalle pintado del Mago (`mageDetail`); la volcánica usa las hombreras ricas. Con esto **las 16 armaduras de rol tienen malla**. Probado en Edit con un avatar normal y otro ancho. Sin probar en Play.

### 132.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Consigue cada armadura de Médico y mírate de espaldas y de frente.
   ✅ Se ven con malla (hierbas, mochila con frascos, tótem sanador, racimo de azufre) y sin parpadeos ni piezas fuera de sitio.
2. [ ] Cura a un compañero con las cuatro puestas, de noche.
   ✅ Los frascos y las gemas brillan en verde (la curación); el azufre brilla en amarillo y la llama de las hombreras echa humo.
3. [ ] Entra y mira la armadura en los primeros segundos.
   ✅ Sale en bloques y pasa sola a malla al cargar.
4. [ ] Comprueba que las 16 armaduras de rol (4 roles × 4 rangos) se ven bien con otro jugador de distinto tamaño.
   ✅ Le quedan ajustadas al torso, brazos y muslos; nada flota ni atraviesa.

## 133. Fase 20 Q6f: los 4 trajes de Fuego azul con malla (05-11-2026)

Hombreras de la temporada rediseñadas (tres láminas escalonadas, cresta de carbón con la llama, corona de cristales, cuerno de azufre y aleta trasera) y cuerpos rediseñados de los cuatro trajes: Guardián (coraza en placas, lomo con costillas a los lados y llamarada), Acechador (jubón cosido, esclavina en escalones y capa con flecos), Invocador (halo con disco de sol y la llama coronándolo) y Sanador (tótem grande con cara y alas, abanico de hierbas, sin verde). Con malla solo el **grado 4** (6, 8, 7 y 8 mallas; 2.306, 1.872, 1.454 y 2.754 triángulos); los grados 0 a 3 siguen en bloques. Sueltos: llamas, neón, cristales de azufre y gotas. Tres trajes tienen excepción de piezas (`ArmorPieces` = 370) porque la versión de bloques mide 367. Probado en Edit con un avatar normal y otro ancho y hondo (`WidthScale` 0,8, `HeightScale` 1,1, `DepthScale` 1,3); con ese avatar, las llamas y la cruz del pecho se adelantaron 0,08 a 0,1 studs para que no queden enterradas. Sin probar en Play.

### 133.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Consigue los cuatro trajes (`GrantCosmetic`) y mírate de frente y de espaldas con cada uno, en grado 4.
   ✅ Se ven con malla, sin parpadeos ni piezas fuera de sitio; las llamas de la espalda y del pecho se ven y la del Guardián sobrepasa la cabeza.
2. [ ] Mira el Sanador de espaldas de cerca.
   ✅ Se ve el abanico de hierbas detrás del tótem (en edición no se pudo ver); no hay verde en el traje.
3. [ ] Entra y mira el traje en los primeros segundos.
   ✅ Sale en bloques y pasa solo a malla al cargar.
4. [ ] Pon los cuatro trajes a un jugador de otro tamaño.
   ✅ Le quedan ajustados al torso, brazos y muslos; las llamas del pecho no quedan hundidas ni flotando demasiado lejos.
5. [ ] En la Isla, sube la armadura de debajo del grado 0 al 4 con cada traje.
   ✅ Los grados 0 a 3 (bloques) y el 4 (malla) se parecen en forma y color; cada grado añade algo visible también desde atrás.
6. [ ] Con otro jugador, míralo de lejos y de cerca, de noche.
   ✅ El fuego azul brilla y echa humo en el grado 4; con Lod a más de 60 studs se ocultan los detalles sin saltos feos.

## 134. Fase 20 Q6g: los 4 trajes Míticos con malla y esferas de luz (05-11-2026)

Hombreras propias rediseñadas y cuerpos rediseñados de los cuatro Míticos, todo en bloques sin giros: Rey Gorila (losas de piedra con cabeza de gorila, ídolo con corona y aro solar), Jaguar espectral (cabeza de jaguar con rosetas, espíritu azul espectral con silueta oscura y luna plateada sin disco), Serpiente emplumada (cabeza de serpiente en la hombrera, serpiente esmeralda con escamas turquesa y rombos de oro sobre la capa añil, cabeza con más detalle y, en el grado 4, el abanico de siempre alrededor de la cabeza: dieciséis plumas largas como alas con raquis de oro y punta de jade que brilla, rayos de oro entre ellas, una fila corta amarilla arriba y un aro de runas turquesa) y Ceiba de la Vida (tronco oscuro con horquilla, copas pequeñas en las puntas y peto de corteza oscura con el glifo en oro). Con malla solo el **grado 4** (12, 15, 12 y 16 mallas; 6.802, 4.976, 4.754 y 5.238 triángulos); los grados 0 a 3 siguen en bloques. Piezas en bloques al grado 4 (la versión de respaldo, con los escalones sin giro de la malla): 558, 555, 578 y 557 (tope 570; la Serpiente tiene excepción de 590 por las plumas). Las plumas del abanico de la Serpiente van giradas y quedan sueltas: el traje tiene 444 bloques en malla y 135 piezas sueltas, sin excepciones nuevas. **Puntos de luz** (bolitas pequeñas de neón sin halo, 11 piezas sueltas): en el grado 4 de los cuatro Míticos, en dorado pálido, y en la armadura volcánica (rango IV) de cada rol, naranja el Guerrero, turquesa el Cazador, violeta el Mago y verde el Médico; por ellos subieron 10 piezas los topes de `VolcanicArmor_<rol>` en `Config.Budgets.Exceptions`. Probado en Edit con un avatar normal y otro ancho y hondo (`WidthScale` 0,8, `HeightScale` 1,1, `DepthScale` 1,3): malla y bloques coinciden. Sin probar en Play.

### 134.1 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

1. [ ] Consigue los cuatro trajes (`GrantCosmetic`) y mírate de frente y de espaldas con cada uno, en grado 4.
   ✅ Se ven con malla, sin parpadeos ni piezas fuera de sitio; los puntos de luz dorados flotan junto al cuello, los hombros, la espalda y los brazos.
2. [ ] Mira el Jaguar espectral de espaldas, de día y de noche.
   ✅ El espíritu azul y la luna plateada se leen sobre cualquier fondo; la niebla no tapa la silueta.
3. [ ] Mira la Serpiente emplumada de espaldas, de cerca.
   ✅ Se ve la serpiente esmeralda con escamas y la cabeza con dientes y púas, y alrededor de la cabeza el abanico de plumas verde azulado con rayos de oro y el aro turquesa que brilla; ninguna pluma queda sin dibujar.
4. [ ] Mira la Ceiba de espaldas y de frente.
   ✅ Se lee el tronco con la horquilla y las copas en las puntas; el peto oscuro con el glifo dorado se ve de frente.
5. [ ] Entra y mira cada traje en los primeros segundos.
   ✅ Sale en bloques y pasa solo a malla al cargar.
6. [ ] Pon los cuatro trajes a un jugador de otro tamaño.
   ✅ Le quedan ajustados; las piezas del pecho no quedan enterradas ni flotando.
7. [ ] Equipa la armadura volcánica de cada rol.
   ✅ Cada rol lleva sus puntos de luz de su color (naranja, turquesa, violeta y verde); no hay esferas rojas.
8. [ ] En el móvil o con la calidad gráfica baja, mira los trajes con puntos de luz.
   ✅ No bajan los fotogramas; con Lod a más de 60 studs los detalles se ocultan sin saltos feos.
9. [ ] Sube la armadura de debajo del grado 0 al 4 con cada traje, en la Isla.
   ✅ Los grados 0 a 3 (bloques) y el 4 (malla) se parecen en forma y color; cada grado añade algo visible también desde atrás.
10. [ ] Entra con un avatar de brazos finos o de proporciones distintas a las de referencia (en Play, con el tuyo: brazo de 0,57 × 1,09 × 0,78) y mira cada traje y cada armadura con malla de espaldas y de cerca.
   ✅ Las piezas sueltas (ojos del ídolo del Rey Gorila, ojos y garras del Jaguar, plumas de la Serpiente, puntos de luz) siguen pegadas a la malla, sin separarse, enterrarse ni dejar huecos en las hombreras. (`wear` diseña contra el tamaño de referencia y escala las piezas sueltas con el mismo factor que la malla; se probó en Edit con esas medidas.)

## 135. Fase 20 Q7a: las 4 armas de forja de rango IV con malla (05-11-2026)

Piloto de armas con malla. El Bastón de lava (rango IV de la forja del Mago) se rehízo con escalones: asta de basalto con nudos, empuñadura de cuero con vueltas de cuerda, púas de obsidiana en escalones, garras en cruz y púas diagonales, sin cuñas ni cilindros. Con malla van 69 bloques (`Handle_Hard` 61 y `Handle_Soft` 8, 1.260 triángulos); las 57 piezas que arden (grietas, bandas, gotas, gemas, anillo de fuego, cristal) siguen sueltas. Herramientas nuevas: `Mallas.volcarArma`, `tools/arma.py`, `Data/WeaponMeshes` y `Meshing` en `WeaponTools` (carga asíncrona; la herramienta sale en bloques y se reconstruye al llegar la malla, soltándola y volviéndola a coger si va en la mano). Probado en Edit: malla y bloques coinciden de frente y de espaldas, y con dos avatares con el arma en la mano (fino 0,8 × 1,1 × 1,0 y ancho 1,3 × 1,0 × 1,3) la reconstrucción mantiene el arma equipada. Sin probar en Play.

También con malla y rediseñadas con escalones (cuñas y cilindros pasan a bloques; el neón sigue suelto): la **Maza volcánica** (117 bloques en malla, 1.532 triángulos; 149 piezas pasan a 34), el **Arco de brasas** (114 bloques, 1.440 triángulos; 158 a 46) y la **Cerbatana de azufre** (106 bloques, 1.596 triángulos; 141 a 37; los cristales de azufre ya son opacos con la punta que brilla). Probado en Edit: malla y bloques coinciden de frente, de espaldas y de perfil, y con dos avatares (0,8 × 1,1 × 1,0 y 1,3 × 1,0 × 1,3) la reconstrucción al llegar la malla mantiene cada arma equipada. `Rendimiento` sigue midiendo la versión de bloques hasta M4.

### Se prueba en Play, en la Isla
1. [ ] Fabrica (o dátelas con los comandos de depuración) y equipa las cuatro armas de rango IV: Bastón de lava (Mago), Maza volcánica (Guerrero), Arco de brasas (Cazador) y Cerbatana de azufre (Médico).
   ✅ Cada una sale con la forma escalonada y, en unos segundos, pasa a malla sin soltarse de la mano; no queda un instante sin arma.
2. [ ] Míralas de frente, de espaldas y de cerca.
   ✅ Se leen las garras y púas escalonadas, las grietas de lava, el marco y los tachones de la Maza, las palas escalonadas del Arco y los racimos de azufre de la Cerbatana; el neón queda pegado al arma, sin separarse.
3. [ ] Juega con un avatar de brazos finos (0,57 × 1,09 × 0,78) y otro ancho y hondo.
   ✅ Cada arma sale de la mano en el mismo sitio que antes y no atraviesa el brazo.
4. [ ] Pega y dispara con cada una (el arco y la cerbatana salen de su punta) y cambia de arma varias veces nada más entrar.
   ✅ Sin parpadeos, sin armas duplicadas en la mochila ni errores en la Salida.
5. [ ] Mira las armas en el Armario y en la tienda (vista previa) y en el Lobby con `WeaponLook`.
   ✅ Se ve con la forma nueva, en bloques o malla, sin errores.

## 136. Fase 21 M4: Rendimiento cuenta las mallas (05-11-2026)

La calculadora `Rendimiento` pide las mallas de todas las `Data/*Meshes` (armas, armaduras, trajes, mascotas y monturas), espera hasta 90 s y avisa con «Malla sin cargar» de las que no cargan. Los triángulos de cada malla salen del campo `triangles` de su entrada, así que ya no cuenta 12 por pieza. Los topes de `Config.Budgets` bajan a lo medido (armas de forja de rango IV, armaduras, trajes, jefes, monturas y excepciones de piezas de armaduras y trajes; las mascotas pierden casi todas sus excepciones salvo el Jaguar de cristal). Con `informe({ mallas = false })` mide los bloques de respaldo y da alertas, lo esperado. Probado en el Studio de la Isla: sin alertas con las mallas cargadas. Sin probar en Play (§136.2).

### 136.1 En el Studio de la Isla, en edición (con el Clone de Rendimiento)

1. [ ] Ejecuta en la barra de comandos `local m = game.ServerStorage.Tools.Rendimiento:Clone(); print(require(m).informe()); m:Destroy()` y espera hasta que termine (puede tardar más de un minuto mientras carga las mallas).
   ✅ La sección 0 «Mallas con textura» lista las mallas de armas, armaduras, trajes, mascotas y monturas, sin ninguna «Malla sin cargar», y el informe acaba en la sección Alertas con «Todo dentro de los límites».
2. [ ] Vuelve a ejecutar con otro Clone: `local m = game.ServerStorage.Tools.Rendimiento:Clone(); print(require(m).informe({ mallas = false })); m:Destroy()`.
   ✅ Salen alertas de piezas solo en los modelos que se miden con bloques de respaldo (armas, armaduras, trajes, mascotas y monturas), y ninguna de triángulos de malla. Ningún error rojo en la Salida.

### 136.2 En el Studio de la Isla, en Play (copia antes `PlayerData_v1` en `PlayerData_v1_backups`)

3. [ ] Dale a ▶ en la Isla, consigue un arma de forja de rango IV y una armadura de rol de rango IV (con los comandos de depuración), equípalas y mira a tu mascota y a una montura si las tienes.
   ✅ Las mallas siguen cargando como antes: en unos segundos el arma, la armadura, la mascota y la montura pasan de bloques a malla; no sale ningún «Malla sin cargar» ni error de `Meshing` en la Salida, y el juego no cambia (daño, precio y aspecto igual que antes de la Fase 21 M4).

## 137. Fase 25 G1: cinemáticas, motor (05-11-2026)

Motor de cinemáticas en tiempo real: `src/shared/Cinematics/*` (`CameraPath`, `Sequencer`, `Presentation`, `Actors`, `CinematicClient`), `UI/HudHider`, `Data/Cinematics` con la escena «Prueba» (un maniquí y el avatar), `CinematicLock` (congela el combate mientras dura la escena), `CinematicService` de la Isla, `CinematicController` del Lobby y de la Isla, el ajuste «Cinemáticas» y el campo `cinematicsSeen` del perfil (sin subir la versión). Ya probado en el Studio de la Isla con copia del perfil: «🎬 Cinemática de prueba» lanza la escena, la cámara y el HUD vuelven al terminar, el botón Saltar sale en la segunda vez, con el ajuste apagado no se ve nada y el doble disparo no se apila. Esta sección es lo que falta.

### 137.1 Con 2 jugadores en la Isla

1. [ ] Con dos cuentas en la Isla, cada una lanza «🎬 Cinemática de prueba» desde su panel de pruebas y una salta la escena a mitad.
   ✅ Cada uno ve y salta solo su propia escena; al otro no le cambian la cámara, el HUD ni los controles.
2. [ ] Con la escena de prueba en marcha, entra el segundo jugador en la Isla.
   ✅ Recibe la escena desde el punto en que va (`seek`), sin repetir los carteles ya pasados, y está protegido (`InvulnerableUntil` de la audiencia) mientras dura.
3. [ ] Deja que una escena acabe en un jugador y se salte en el otro.
   ✅ El servidor cierra la escena cuando los dos han mandado `CinematicDone`, o como mucho al cumplirse su duración; la del que no ha terminado no se corta antes.

### 137.2 En el juego publicado

4. [ ] Publica el place de la Isla y lanza la escena de prueba en el servidor público.
   ✅ Durante la escena no responden los controles del jugador (caminar, saltar, mover la cámara) y vuelven al terminar. En Studio no se desactivan porque `PlayerScripts` no tiene `PlayerModule`; en el publicado sí debe pasar.
5. [ ] Mira el maniquí R15 de la escena de prueba.
   ✅ Sale vestido igual que en Studio, con el equipo y los cosméticos del juego.
6. [ ] Mira la Salida al crear el maniquí.
   ✅ `CreateHumanoidModelFromDescription` funciona en el cliente publicado: no sale el aviso «no se puede crear el maniquí R15» y el maniquí se borra al terminar la escena.

### 137.3 Una sola persona en Play

7. [ ] En el móvil emulado, con la zona segura 9:16 de la guía, lanza la escena de prueba y mírala entera.
   ✅ Las franjas negras arriba y abajo; el cartel «Escena de prueba», el subtítulo y el fundido final se leen dentro de la zona segura y no se cortan.
8. [ ] Lo mismo en PC, con la guía 9:16 de la grabación.
   ✅ El cartel, el subtítulo y el fundido se ven igual que en el móvil y no tapan la zona segura.
9. [ ] Cuando haya una escena con freeze real (G2), pon a tu personaje cerca de un peligro del mapa (módulo `Hazards`) y prueba un `TakeDamage` directo durante la escena.
   ✅ Nadie pierde vida durante la escena, ni por el peligro ni por el daño directo; al terminar, los peligros vuelven a actuar. Esto no se puede probar con la escena de G1.
10. [ ] Mira la Salida durante la escena de prueba por el aviso `ContentId rbxassetid://203785492 failed due to: Asset type does not match requested type`.
   ✅ Si sale también sin lanzar ninguna escena, ya existía antes de G1 y no es de la cinemática. Si solo sale al lanzarla, se anota aparte. Este aviso ya salió en pruebas de otras fases (V9, A3, W2) sin identificar: su origen sigue sin saberse.

## 139. Fase 25 G2: apariciones de los jefes (05-11-2026)

Cada jefe tiene su escena de aparición (`Boss_<id>` en `Data/Cinematics`, 6 s): la cámara llega de frente a la cara del jefe, sale el cartel con su nombre y un subtítulo en el tercio de abajo, el rugido suena a 1,0 s (evento de servidor `bossRoar`) y la escena acaba con un fundido a negro. El jefe queda congelado mientras dura para todos; la primera vez se ve entera y después se puede saltar. La lanza `IslandBossHooks.spawnBoss`, que usan el reloj de partida y «👑 Siguiente jefe». El «🎬 Plató» monta el decorado del tráiler con un jefe quieto y lanza la escena solo para quien pulsa. Ya probado en el Studio de la Isla con copia del perfil: los cuatro jefes con «Siguiente jefe» (congelado y sin perder vida, rugido a 1,0 s y no al aparecer, cartel con nombre y subtítulo, `cinematicsSeen` guarda los cuatro), la cámara de frente hacia t≈3,6 s en los cuatro, Saltar en la segunda vez, el ajuste «Cinemáticas» apagado y el Plató con Caudillo, Albino y Orangután. Esta sección es lo que falta.

### 139.1 Con 2 jugadores en la Isla

1. [ ] Con dos cuentas en la Isla, pulsa «👑 Siguiente jefe» y deja que la escena de aparición se vea entera en las dos.
   ✅ Las dos ven la escena con su cartel y, al acabar, recuperan el HUD, la cámara y los controles.
2. [ ] Mientras se ve la escena, uno de los dos pulsa Saltar a mitad y el otro sigue mirando.
   ✅ Cada uno ve o salta solo su propia escena: al que salta no le cambia nada la del otro, y al otro no le tocan la cámara, el HUD ni los controles.
3. [ ] Sigue al jefe mientras uno de los dos todavía ve la escena y el otro ya ha saltado.
   ✅ El jefe sigue inmóvil y sin perder vida hasta que la escena acaba para todos.
4. [ ] Con un jugador que ya vio la escena de ese jefe y otro que no, pulsa «👑 Siguiente jefe» con los dos conectados.
   ✅ Al que ya la vio le aparece Saltar desde el principio; al que no la vio se la muestra entera. Cada uno tiene su propio `cinematicsSeen`.
5. [ ] Con el jefe ya en su escena, entra el segundo jugador a mitad.
   ✅ Recibe la escena desde el punto en que va (`seek`), sin repetir los carteles ni el rugido ya pasados, y el jefe sigue congelado también para él hasta que acaba.

### 139.2 Una persona en Play (visual)

6. [ ] En el móvil emulado, con la zona 9:16 de la guía, pulsa «👑 Siguiente jefe» con el Orangután del Manglar, el Chimpancé Caudillo, el Gorila Albino y el Gorila de Ceniza, y mira cada escena entera.
   ✅ Franjas negras arriba y abajo, HUD oculto, la cámara llega de frente a la cara hacia t≈3,6 s, el cartel sale en el tercio de abajo y el fundido cierra la escena; después vuelven el HUD y la cámara.
7. [ ] En el Chimpancé Caudillo, el Gorila Albino y el Gorila de Ceniza, mira si la cabeza del jefe se corta con la franja de arriba cuando la cámara está de frente.
   ✅ La cabeza entera queda por debajo de la franja. Si se corta en algún instante, se anota el jefe y el segundo (`bossScene` en `Data/Cinematics`).
8. [ ] Con los mismos tres jefes, mira si el cartel tapa la cara.
   ✅ El cartel (nombre y subtítulo) queda en el tercio de abajo y no cubre la cara en ningún instante. Si la cubre, se anota el jefe.
9. [ ] Con los nombres largos, sobre todo el Orangután del Manglar y el subtítulo «Espectro de las cuevas», mira el cartel en el móvil emulado.
   ✅ El nombre se parte en dos líneas sin salirse de la zona segura ni cortar palabras, se lee sin acercar la vista y el subtítulo queda debajo sin solaparse.
10. [ ] Mira las escenas en la guarida real de cada jefe, donde hay árboles, rocas o paredes: la cámara va de frente y puede quedar delante de ellos.
    ✅ Se anota qué jefe y qué tapa al jefe en cada escena. Algo que cruza el plano un instante no es fallo; la cámara dentro de un árbol o de una roca, sí.
11. [ ] Con el Gorila de Ceniza, mira la escena con la erupción del volcán al fondo.
    ✅ La erupción no tapa el cartel ni la cara del jefe, y el subtítulo «Furia del volcán» se lee sobre el brillo. Si no se lee, se anota.

### 139.3 Plató y grabación

12. [ ] En Play, pulsa «🎬 Plató» para cada uno de los cuatro jefes, incluido el Gorila de Ceniza (que no se ha medido en el Plató), y espera a que se limpie.
    ✅ Aparece `Workspace.Plato` con el decorado del tráiler y un jefe quieto; la escena se lanza solo para quien pulsa, sin congelar a nadie, y el Plató se borra unos 1 s después. Pulsar dos veces seguidas no apila dos.
13. [ ] Mira el fondo del Plató en los planos en contrapicado, con el Orangután del Manglar y el Gorila de Ceniza.
    ✅ El fondo se ve como decorado. Si la cámara enseña el vacío o el borde de detrás, se anota y se decide si hace falta girar el decorado (`Trailer.decorar`).
14. [ ] Mira la luz del Plató en pantalla y después de limpiarlo.
    ✅ El jefe se lee bien iluminado, sin zonas quemadas ni negras, y al limpiarse la luz vuelve como estaba (`Trailer.devolverLuz`).
15. [ ] Graba en OBS a 1080p60 una escena de Plató con la guía 9:16 y el Modo grabación activados.
    ✅ Sin HUD de pruebas ni barra de Roblox en cuadro, el cartel cae dentro del recuadro 9:16 central y el vídeo va a 60 fps sin tirones.

### 139.4 Casos límite

16. [ ] Quita al jefe justo al aparecer, en el primer segundo de su escena, con «👑 Jefe» del panel de administrador (lo quita si está vivo).
    ✅ `roar()` no hace nada: no suena el rugido, no sale ningún error en la Salida y la escena acaba con normalidad.
17. [ ] Con una escena de jefe en marcha, haz que salga otro jefe (el reloj de partida o «👑 Siguiente jefe»).
    ✅ El jefe nuevo solo ruge: no se lanza una segunda cámara ni se rompe el congelado de la primera escena, y esta acaba normal.
18. [ ] Como administrador, saca un jefe con «👑 Jefe» del panel. Eso llama a `BossService.spawn` directamente (`onAdminBoss`, `BossService.luau` ~línea 944).
    ✅ El jefe aparece sin cinemática (sin franjas ni cartel) y con su rugido al aparecer, como antes de G2. Es lo previsto; si se quiere escena también aquí, se decide aparte.
19. [ ] Con el sonido del cliente activado, lanza un jefe con «👑 Siguiente jefe» y escucha el rugido.
    ✅ Se oye el rugido real a 1,0 s de la escena y no al aparecer el jefe. Hoy solo se ha comprobado el track de animación, no el sonido en el cliente: si no suena, se anota.
20. [ ] En el juego publicado, pulsa «👑 Siguiente jefe» con cada uno de los cuatro jefes, y repite uno después de reconectar.
    ✅ Las cuatro escenas se ven, saltan y acaban igual que en Studio; tras reconectar, el jefe ya muestra Saltar porque `cinematicsSeen` quedó guardado.

## 138. Fase 20 Q7b-1 a Q7b-3: armas del Guerrero, el Cazador y el Mago de rangos I a III con malla (05-11-2026)

Guerrero: el **Garrote de piedra** (I), la **Maza de hueso** (II) y el **Mazo de hueso grueso** (III). Cazador: el **Arco** (I), el **Arco reforzado** (II) y el **Arco de liana** (III). Mago: el **Bastón mágico** (I), el **Bastón dorado** (II) y el **Bastón de plata** (III). Todos se rehicieron con escalones (sin bolas, cilindros ni cuñas; las bolas son capas apiladas con `blob`, nuevo en `stepKit`; las palas de los arcos se curvan en tramos desplazados, como el Arco de brasas) y pasan a malla: 522, 1.384 y 1.398 triángulos el Guerrero, 916, 1.114 y 1.352 el Cazador, 768, 1.002 y 1.480 el Mago, de 35 a 96 piezas a 3 (6 el Arco de liana, cuyos cristales y gema son de cristal y quedan sueltos; 8, 4 y 4 los bastones, que dejan suelto el cristal de neón). El detalle sube por rango: el I es lo más limpio (pintura, ataduras, borlas), el II lleva hueso, placas y púas, y el III plata, liana, hojas y gemas. Probado en Edit: malla y bloques coinciden por pares y con un avatar de brazos finos (0,8 × 1,1 × 1,0) y otro ancho (1,3 × 1,0 × 1,3); construidas antes de que lleguen las mallas salen en bloques y se reconstruyen a las mallas; `Rendimiento` sin alertas. Sin probar en Play. Se quitó el código muerto de las ramas `lava` y `volcanic` del arco.

Los metales (oro y plata) se ven algo más claros en la malla que en los bloques, porque la malla es de plástico liso. Aviso para las armas siguientes: las piezas con alguna dimensión menor de 0,07 studs que sobresalen de un bloque grueso se pierden en la malla sin avisar (la cuerda, las plumas, los cordones y las hojas desaparecían); las que deben ir pintadas (grietas, costuras, grabados) sí van finas, y las que tienen que verse, a 0,08 o más.

### Se prueba en Play, en la Isla
1. [ ] Fabrica (o dátelas con los comandos de depuración) y equipa las armas de rangos I a III del Guerrero (Garrote de piedra, Maza de hueso, Mazo de hueso grueso) del Cazador (Arco, Arco reforzado, Arco de liana) y del Mago (Bastón mágico, Bastón dorado, Bastón de plata).
   ✅ Cada una sale con su forma escalonada y en unos segundos pasa a malla sin soltarse de la mano; no queda un instante sin arma.
2. [ ] Míralas de frente, de espaldas y de cerca, con un avatar de brazos finos y otro ancho.
   ✅ Se leen las lascas y cinturones rojos del Garrote, las púas y el collar de la Maza, los cóndilos, la plata y la liana del Mazo, y en los arcos las bandas pintadas, las placas de hueso, las vueltas de liana y la cuerda, y en los bastones las garras en cruz, las bandas de oro, las vueltas de liana y el colmillo; salen de la mano en el mismo sitio que antes y no atraviesan el brazo.
3. [ ] Pega con cada una y cambia de arma varias veces nada más entrar.
   ✅ Sin parpadeos, sin armas duplicadas en la mochila ni errores en la Salida.
4. [ ] Mira las tres en el Armario, en la tienda y en el Lobby con `WeaponLook`.
   ✅ Se ven con la forma nueva, sin errores.

## 140. Fase 25 G2b: estilo cómic de las cinemáticas (05-11-2026)

Versión cómic de la aparición del Orangután del Manglar (`Boss_OrangutanDelManglar_Comic` en `Data/Cinematics`, sin franjas negras): viñetas poligonales con borde y fondos (`flat`, `halftone` y `speed`), cartel de título en caja amarilla, bocadillos con cola que sigue al jefe y onomatopeyas con explosión. Motor en `src/shared/Cinematics/Comic.luau` (nuevo, `Comic.install(Sequencer)` desde `CinematicClient`; `Presentation.letterbox` no dibuja si hay capa cómic). Se lanza solo con «🎬 Plató cómic», para grabar: no sale en el juego. Ya probado en el Studio de la Isla, en Play, con capturas a cámara lenta: viñeta con borde y halftone, narración, onomatopeya con explosión, líneas de velocidad fuera de la ventana tras la transición, degradado, caja de título con su padding y bocadillo con la cola a la cara sin pisar el título. Sin versión cómic de Caudillo, Albino ni Ceniza: solo el Orangután. Esta sección es lo que falta.

### 140.1 Una persona en Play (visual)

1. [ ] En el Studio de la Isla, en Play, pulsa «🎬 Plató cómic» y mira `Boss_OrangutanDelManglar_Comic` a velocidad real, en el móvil emulado.
   ✅ Las viñetas cambian al ritmo del guion (panel `diagLeft` con la narración, rugido con «¡ROAAAR!», panel `diagRight` con líneas de velocidad, panel `tallSlant`, título y bocadillo final, fundido) sin cortes antes de tiempo ni pausas bruscas.
2. [ ] Lee el cartel de título y el bocadillo «¡Fuera de mi manglar!» a velocidad real, sin acercar la vista.
   ✅ El nombre y el subtítulo se leen en la caja amarilla sin tapar la cara del jefe, y el bocadillo se lee entero.
3. [ ] Mira la cola del bocadillo mientras el jefe se mueve.
   ✅ La cola apunta a la cara del jefe (cae en el mentón o la gema) y la sigue al moverse; no se queda en el suelo ni en el borde de la pantalla.
4. [ ] Mira la onomatopeya «¡ROAAAR!» en el momento del rugido (1,0 s).
   ✅ Sale arriba a la izquierda con su explosión amarilla detrás, se lee y no tapa la cara del jefe.
5. [ ] Mira los puntos del `halftone` (panel `diagLeft`, verde azulado y crema) y las líneas de velocidad fuera de la ventana.
   ✅ Los puntos se ven nítidos y las líneas no entran en la ventana 3D; tras la transición se ven gruesas, no finas.
6. [ ] Mira el degradado del panel `tallSlant` y las uniones entre los rectángulos del fondo (`flat`, `halftone` y `speed`).
   ✅ No se ven costuras, líneas finas de color entre rectángulos ni huecos en las esquinas del fondo.
7. [ ] Con el emulador de teléfono y el contador de FPS de Studio (Estadísticas), mira el ritmo mientras corren el `halftone` (hasta 600 piezas) y las líneas de velocidad (48 cuñas), y compáralo con una escena normal como `Boss_OrangutanDelManglar`.
   ✅ El cómic no baja los FPS por debajo de la escena normal. Si cae, se anota el fotograma, el dispositivo y el número de piezas en pantalla.

### 140.2 Tamaños de pantalla

8. [ ] Con la escena en marcha, rota el emulador de teléfono de vertical a horizontal y vuelve a vertical.
   ✅ El panel, el fondo y los bocadillos se reajustan a la nueva forma sin saltos bruscos ni cajas fuera de pantalla.
9. [ ] Cambia el tamaño de la ventana de Studio (más estrecha y más ancha) durante la escena, o empieza el Play con una ventana pequeña.
   ✅ Las viñetas, el `halftone` y la onomatopeya se escalan con el lado corto; ningún texto se corta ni se sale del marco.
10. [ ] Con la guía 9:16 (tercio central, x de 0,34 a 0,66) activada, mira los paneles `wide`, `diagLeft`, `diagRight` y `tallSlant` en su momento de máxima ocupación.
    ✅ En los cuatro, la franja central cae dentro de la ventana 3D en toda su altura: ni el borde del panel ni el fondo la cortan, y el jefe no se sale de ella.
11. [ ] En un teléfono real (o el emulador con la barra de Roblox visible), mira dónde cae la cola del bocadillo respecto a la cabeza del jefe.
    ✅ La cola cae en el mentón o la gema, como en Studio. En Studio `ComicBubbles.AbsolutePosition` vale (0, -58) y lo compensa `project()`; si en el dispositivo vale (0, 0), la cola quedará unos 58 px más arriba, en la cabeza. Se anota el valor que sale y dónde cae.

### 140.3 Grabación

12. [ ] Graba en OBS a 1080p60 la escena de «🎬 Plató cómic» con la guía 9:16 y el Modo grabación activados.
    ✅ Sin HUD de pruebas, sin barra de Roblox ni de Studio en el cuadro, y el vídeo va a 60 fps sin tirones en los paneles con `halftone` y líneas de velocidad.
13. [ ] Mira el recorte 9:16 central del vídeo grabado.
    ✅ El cartel de título y el bocadillo caen dentro del recuadro 9:16 central.
14. [ ] Mira el texto del cómic (fuente Bangers) en el vídeo a 1080p, sin reescalar, y en el recorte de Shorts.
    ✅ Los trazos se ven nítidos, sin borrones ni contornos rotos; las onomatopeyas grandes no pierden la forma.

### 140.4 Casos límite

15. [ ] Con «🎬 Plató cómic» pulsa hasta que la rotación traiga un jefe sin versión cómic (Caudillo, Albino o Ceniza).
    ✅ Sale el aviso «aún no hay versión cómic» con el nombre del jefe, no se monta el decorado ni se lanza ninguna escena, y no sale ningún error en la Salida.
16. [ ] Con el bocadillo del jefe en pantalla, quita el jefe del Plató (borra su modelo) o sácalo de plano.
    ✅ El bocadillo no da error ni queda flotando sobre el vacío: se oculta o se queda donde estaba, y la escena acaba normal con su fundido. Se anota lo que hace.
17. [ ] Pulsa «🎬 Plató cómic» con un jefe cuya escena cómic está en marcha, y otra vez mientras corre la primera.
    ✅ Se borra el decorado anterior y el nuevo empieza limpio; no quedan dos Plató ni dos escenas superpuestas.
18. [ ] Con un panel `tri` (solo ese preset) en el Plató, mira qué parte del recorte 9:16 queda dentro de la viñeta.
    ✅ Solo queda limpio el 66 % de abajo (desde y ≈ 0,34): el ápice de arriba queda fuera del recorte, así que los carteles y bocadillos deben ir abajo.
19. [ ] Con el juego en inglés (como en §20), lanza «🎬 Plató cómic» y mira el cartel y el bocadillo.
    ✅ El nombre y el subtítulo en inglés caben en la caja amarilla (se parten en dos líneas sin salirse), y el bocadillo largo no sale de la pantalla ni tapa la cara del jefe.

## 141. Fase 25 G2c: jefes en su sitio, habilidades en la toma y luz (05-11-2026)

Los jefes de la Isla aparecen donde dice `Data/BossStages` (cima de la montaña, sala de la cueva mirando a la boca, borde del cráter por el lado del Basecamp y orilla del manglar) y vuelven ahí; «🎬 Plató» y «🎬 Plató cómic» ya no montan un decorado falso: ponen al jefe en su sitio real del mapa. Las 8 escenas de aparición enseñan una habilidad real del jefe, solo visual (evento de servidor `bossSkill` → `BossService.demo`): pisotón del Orangután, lluvia de rocas del Caudillo, rugido que apaga las antorchas del Albino, erupción y bombas de lava de Ceniza. Cámara más rápida (de frente a los 2,0 s; Ceniza 2,4 s), escena de 7,5 s. Tres versiones cómic nuevas (Caudillo, Albino y Ceniza). `CinematicService` renueva cada segundo `RequestStreamAroundAsync` mientras dura la escena (el jefe y el decorado se descargaban hacia los 5 s). Luz de relleno en Orangután, Caudillo y Albino (eventos `light` con `follow` y `exposure`, `Cinematics/SceneLight`). **La sala de la cueva del Albino se agrandó en el terreno del place** (esfera de radio 48, suelo plano a y≈13; `MapBuilder.carveCave` hace lo mismo al regenerar). Ya probado: el Plató cómic sale en los 4 sitios sin errores, el jefe sigue cargado a los 8 s, la cámara del Albino no toca roca y ve siempre su cara (muestreo cada 0,25 s), la lámpara sigue a la cámara a ~3,5 studs, y el empujón de imagen se quita al acabar. Con la hoja de contacto del vídeo se vio que los jefes ya no desaparecen. Esta sección es lo que falta.

### 141.1 Guardar y publicar

1. [ ] Guarda el place de la Isla en Studio y publícalo (la sala nueva de la cueva está en el terreno, no en el repo).
   ✅ Al reabrir el place, la sala del Albino sigue grande (≈75 studs de diámetro, suelo plano) y el túnel entra a su altura sin escalón.

### 141.2 Una persona en Play (visual, con vídeo)

2. [ ] Graba «🎬 Plató cómic» con los 4 jefes y revisa con una hoja de contacto (un fotograma por segundo).
   ✅ El jefe se ve de principio a fin en las 4 escenas; en cada una se lee la habilidad (pisotón con su onda, rocas cayendo alrededor del jefe, rugido con las antorchas apagándose, bombas de lava con la erupción detrás).
3. [ ] Mira el principio y el final de las escenas del Orangután y del Caudillo (con la luz que sigue a la cámara).
   ✅ La exposición es pareja: no arranca a oscuras ni se quema al acercarse la cámara. Si sale oscuro o quemado, se anota el segundo y se ajusta `brightness` (2) o `range` (5 alturas) en `bossLights` de `Data/Cinematics`.
4. [ ] Mira la escena del Albino de principio a fin.
   ✅ La cueva se ve (no arranca en negro), la cámara no atraviesa paredes ni techo y el jefe mira a la cámara con la boca del túnel detrás de ella.
5. [ ] Mira la escena de Ceniza con la erupción.
   ✅ Las bombas salen del cráter, que queda detrás del jefe; el jefe está en el borde, no en el foso de lava.
6. [ ] Mira la primera toma de cada escena (cámara detrás del jefe).
   ✅ La cámara llega de frente al jefe antes de la habilidad; se ve de frente más tiempo que de costado.

### 141.3 En la Isla de verdad

7. [ ] Con «👑 Siguiente jefe» saca los 4 jefes de uno en uno y mira dónde nacen.
   ✅ Orangután en su orilla mirando al Basecamp, Caudillo en la cima, Albino en el centro de la sala mirando a la boca y Ceniza en el borde del cráter; ninguno nace dentro de la roca ni cae al foso.
8. [ ] Deja a un jefe sin objetivo (aléjate) y mira adónde vuelve.
   ✅ Vuelve a su sitio de `BossStages` (cima, sala, borde), no al centro de la montaña ni al foso.
9. [ ] Con dos jugadores, uno en el Basecamp y otro cerca del jefe, deja que corra una escena de aparición completa.
   ✅ Los dos ven al jefe de principio a fin (el streaming se renueva para cada espectador), y las antorchas del Albino vuelven a encenderse solas tras la escena.
10. [ ] Pasa una partida hasta el jefe de las antorchas (Albino) con las antorchas de la cueva encendidas.
    ✅ El rugido de la escena apaga las antorchas solo mientras dura el efecto y no deja a los monos ni a los jugadores sin ellas más tiempo del normal.

### 141.4 Casos límite

11. [ ] Regenera el mapa con `MapBuilder.build({ islandRadius = 950 })` en un place de prueba (nunca en el de producción) y mira la cueva.
    ✅ La sala sale con el tamaño nuevo y no rompe el techo de la montaña; los puntos de `BossStages` siguen cayendo en la cima, la sala y el borde (si no, hay que volver a medirlos).
12. [ ] Salta (Saltar) cada escena a mitad.
    ✅ No queda la lámpara de la cámara ni el empujón de imagen (`CinematicLift` en `Lighting`) después de saltar.
13. [ ] Lanza una escena de jefe con el ajuste «Cinemáticas» desactivado.
    ✅ El jefe sale en su sitio y ruge al momento, sin escena, y no queda luz añadida.
14. [ ] Con el inglés puesto, mira las 3 versiones cómic nuevas.
    ✅ Las citas («This mountain is mine!», «Nobody leaves my cave…», «Everything will burn!») y las narraciones caben en los bocadillos sin salirse.

## 142. Fase 25 G3a: eclosión del huevo como escena local EggHatch (05-11-2026)

La ceremonia del huevo del Lobby (`NestController.playCeremony`) es ahora la escena local `EggHatch` (`Data/Cinematics`, se reproduce con `CinematicClient.playLocal`) con los eventos `eggShake`, `eggBurst`, `petReveal` y `eggAnnounce`, registrados en `NestController`. Dura 7 s, solo la ve quien abre el huevo y no bloquea nada. Saltar siempre visible. El letrero («Ha nacido…») sale a los 2,6 s dentro del ScreenGui de la cinemática y dura 4 s. Si el ajuste «Cinemáticas» está apagado o hay otra cinemática de servidor en marcha, hay una versión rápida sin cámara (estallido, letrero y subida de 2,2 s). Si se salta, el huevo estalla igual, se limpia todo y el letrero sale unos 4 s con el HUD ya devuelto.

Ya probado: en Play en el Studio del Lobby, disparando `Remotes.EggHatched` desde el servidor: la cámara pasa a Scriptable, el HUD se oculta, el huevo desaparece a los ~2,2 s, sale el letrero, se borra a los 4 s, la escena acaba a los 7 s, HUD y cámara se restauran y `ceremony` queda en false. Encuadres revisados en modo edición con capturas. Esta sección es lo que falta.

### 142.1 Con el juego publicado: huevos de verdad

1. [ ] Con el Lobby publicado, abre en el nido un huevo listo para abrir y mira la escena entera.
   ✅ La cámara pasa a la escena, el huevo tiembla y estalla, sale la mascota, el letrero «Ha nacido…» aparece a los 2,6 s y se borra a los 4 s después, y a los 7 s la escena acaba y el HUD y la cámara vuelven.
2. [ ] Abre en el nido un huevo de montura.
   ✅ La montura sale a escala 0,45 entera dentro del encuadre y el letrero no la tapa.
3. [ ] Abre un huevo cuya mascota ya tienes.
   ✅ El letrero dice «Otra vez…» y se suma el Ámbar que da la repetida; la escena tiene el mismo ritmo que la de una mascota nueva.

### 142.2 Saltar

4. [ ] Pulsa Saltar a mitad de la escena.
   ✅ El huevo estalla igual, la mascota de la escena desaparece, no queda ningún huevo ni mascota suelta en pantalla, el letrero sale unos 4 s y el HUD vuelve.

### 142.3 Ajuste «Cinemáticas» apagado

5. [ ] Desactiva «Cinemáticas» en los ajustes y abre un huevo.
   ✅ No hay cámara de escena: el huevo estalla, sale el letrero y la subida dura unos 2,2 s; el HUD vuelve y la cámara no queda en Scriptable.

### 142.4 Dos huevos (incubadora III)

6. [ ] Con la incubadora III, ten dos huevos listos y ábrelos.
   ✅ Nace el del hueco 1 o el del 2, y se anota cuánto se desvía el encuadre (se espera ±1,3 u) y si la mascota se corta.

### 142.5 Pantallas e idioma

7. [ ] Con el emulador de teléfono, abre un huevo y mira el letrero.
   ✅ El letrero, entre 0,30 y 0,35 de la altura de la pantalla, no tapa la mascota ni se corta.
8. [ ] En PC, con la ventana de Studio o del juego pequeña, abre un huevo y mira el letrero.
   ✅ El letrero no tapa la mascota ni se corta, igual que en el teléfono.
9. [ ] Con el juego en inglés (como en §20), abre un huevo.
   ✅ El letrero en inglés cabe entero en pantalla, no se corta y no tapa la mascota, en el teléfono y en el PC.

### 142.6 Casos límite

10. [ ] Abre un segundo huevo justo después del primero.
    ✅ No quedan dos escenas ni dos mascotas a la vez. Si el segundo se encola o se salta, se anota lo que hace.
11. [ ] Abre un huevo mientras llega otra cinemática del servidor (por ejemplo, la de un jefe).
    ✅ Sale la versión rápida sin cámara, la cinemática en marcha no se corta ni se pisa, y el HUD vuelve al acabar. Se anota lo que pasa.

### 142.7 Perfil real

12. [ ] Antes de probar en Play, haz la copia del perfil de §10.0 y, con el Play parado, restáurala al terminar.
    ✅ Tras restaurar, el perfil real (`PlayerData_v1`) coincide con la copia, y el Ámbar, los huevos y las mascotas son los de antes del Play.

## 143. Fase 25 G3b: rescate con el helicóptero voxel (05-11-2026)

El rescate es la escena de servidor `Rescue` (`Data/Cinematics`, 19 s, para todos, congela a los jugadores) con un helicóptero voxel de 60 piezas, cabina hueca con la puerta derecha abierta, asientos y banco (`Shared/HelicopterModel`, tope `Config.Budgets.Models.Helicopter` = 65; las hélices son `Motor6D` que giran en `animate`). Hacia 9,6 s sube la tripulación (`Shared/Cinematics/RescueCrew`): un piloto con mono naranja y casco blanco con visera al volante, y como pasajeros una copia pequeña (escala 0,42) del personaje de cada jugador, hasta 6, sentados y saludando; los personajes reales se ocultan solo en cada cliente y vuelven al acabar o al saltar. Al amanecer del rescate, con la baliza encendida, `BeaconService.startRescue` la lanza sobre la base de la baliza y, al acabar, apaga la lámpara y llama a `MatchService.endMatch("Victory")`. Si otra escena con bloqueo ocupa la cinemática, reintenta cada 0,5 s hasta 15 s y luego cierra sin escena. Mientras dura, nadie puede volver a encender la baliza. La orden de administrador «🚁 Rescate» (`CineRescue`) lanza solo la escena para quien la pulsa, sin congelar ni cerrar la partida.

Ya probado: Rendimiento mide el helicóptero en 60 piezas antes y después de fusionar, con tope 65, 708 triángulos y sin alertas. En Play en el Studio de la Isla, «🚁 Rescate» sin baliza (20 studs delante del jugador): la cámara pasa a Scriptable, el helicóptero entra y flota, sale el cartel, la tripulación aparece a 9,6 s (piloto y copia del jugador como pasajero), el personaje real se oculta y se restaura al final, la escena acaba a los ~19 s y se restauran HUD y cámara; capturas de la cabina en Play. Se arreglaron dos fallos al probar: los personajes actuales usan `AnimationConstraint` en vez de `Motor6D`, y la unión de R15 se llama «Root». Los encuadres de la versión anterior se revisaron en modo edición con capturas. Esta sección es lo que falta.

### 143.1 Guardar, publicar y traducción

1. [ ] Guarda el place de la Isla en Studio y publícalo. Después, con el juego publicado, lanza «🚁 Rescate» desde el panel de administración.
   ✅ La escena se ve sin errores en la Salida y el juego sigue después de acabar.
2. [ ] Sube a Creator Hub las frases nuevas de G1–G3b: `python tools/strings.py --csv-nuevas build/localization_nuevas.csv`, el archivo (o los `_1`, `_2`… si pasa de 90) y luego `python tools/strings.py --marcar-subidas`.
   ✅ Creator Hub acepta el CSV sin errores, `tools/strings_subidas.txt` queda con las claves nuevas y `python tools/strings.py` no avisa de frases sin inglés.

### 143.2 Rescate de verdad

3. [ ] Enciende la baliza, aguanta la noche final y espera al amanecer.
   ✅ Al amanecer arranca la escena sobre la baliza real (no sobre el sitio de la orden), el helicóptero entra desde el cielo y flota sobre ella, y la partida no termina antes de que acabe la escena.
4. [ ] Al acabar la escena (19 s), mira el resumen de la partida.
   ✅ La partida termina en victoria justo al acabar la escena, con el resumen y el pago de Ámbar; la lámpara de la baliza se apaga y el HUD y la cámara vuelven.
5. [ ] Mientras corre la escena, intenta volver a encender la baliza.
   ✅ No se enciende: nadie puede volver a encenderla durante la escena.

### 143.3 Cámara y helicóptero en el Basecamp

6. [ ] Enciende la baliza en 3 sitios distintos del Basecamp (al menos uno pegado a edificios y a un árbol) y mira la cámara de 0 a 6 s (a unos 30–38 studs de la baliza hacia el Basecamp).
   ✅ La cámara no atraviesa edificios, árboles ni terreno en ninguno de los 3 sitios. Si lo hace, se anota el segundo y el sitio.
7. [ ] Mira el helicóptero desde dentro del campamento durante la escena.
   ✅ Se ve entero, con proporciones correctas, y no lo tapa nada importante del campamento.
8. [ ] Mira el helicóptero por detrás, con la cola a la vista.
   ✅ La cola se lee bien, el emblema es un plátano amarillo en la aleta y no hay nada verde (el verde es solo para la curación).
9. [ ] En el emulador de teléfono de gama baja, mira las hélices.
   ✅ Giran de forma fluida, sin saltos ni parones.
10. [ ] Acerca al jugador al helicóptero mientras flota sobre la baliza.
    ✅ No hay colisión: el jugador atraviesa el helicóptero sin empujes ni tropiezos (CanCollide en false).

### 143.4 Saltar

11. [ ] Pulsa Saltar a mitad de la escena. Si el juego deja saltarla la primera vez, anótalo; si no, prueba otra vez después de verla entera.
    ✅ Llega la victoria igualmente (resumen y Ámbar), no queda el helicóptero ni el HUD oculto y la cámara vuelve.

### 143.5 Ajuste «Cinemáticas» apagado

12. [ ] Desactiva «Cinemáticas» en los ajustes y espera al amanecer con la baliza encendida.
    ✅ No hay escena; la victoria llega al acabar el margen igualmente y la cámara no queda en Scriptable.

### 143.6 Jefe en marcha

13. [ ] Lanza un jefe con «👑 Siguiente jefe» y haz que el amanecer del rescate caiga mientras su escena de aparición corre.
    ✅ El rescate espera su turno (reintenta cada 0,5 s) y empieza al acabar la escena del jefe, no a la vez.
14. [ ] Si la escena del jefe sigue con el bloqueo más de 15 s, mira qué pasa al cumplirse ese tiempo.
    ✅ El rescate cierra sin escena y no deja la cámara ni el HUD ocultos. Se anota si la victoria llega.

### 143.7 Modo sin fin (Fase 12)

15. [ ] En modo sin fin, tras la primera Victoria sigue jugando y enciende la baliza otra vez para el siguiente amanecer.
    ✅ La partida sigue tras la Victoria, y el segundo rescate vuelve a lanzar la escena (`rescuing` vuelve a false).

### 143.8 Dos jugadores

16. [ ] Con dos jugadores, uno en el Basecamp y otro lejos o muerto, espera al amanecer con la baliza encendida.
    ✅ Los dos ven la escena entera sobre la baliza real, también quien está muerto o lejos, y la partida termina en victoria para los dos al acabar.

### 143.9 Orden de administrador

17. [ ] Con la baliza construida, pulsa «🚁 Rescate» en el panel de administración.
    ✅ La escena sale con el helicóptero sobre la base de la baliza (+Z hacia el Basecamp), solo la ve quien la pulsa, y no congela ni cierra la partida.
18. [ ] Sin baliza construida, pulsa «🚁 Rescate».
    ✅ La escena sale con el helicóptero 20 studs delante del jugador, sin congelar ni cerrar la partida.

### 143.10 Pantallas e idioma

19. [ ] Con el juego en inglés (como en §20), enciende la baliza y espera al amanecer en el emulador de teléfono (9:16).
    ✅ «Rescue!» y «You made it» caben en la zona segura y no se cortan.
20. [ ] Con el juego en español, mira el cartel en el teléfono y en el PC con la ventana pequeña.
    ✅ «¡Rescate!» y «Lo lograron» caben enteros y no se cortan, en los dos.

### 143.11 Tripulación y cabina

21. [ ] Con dos jugadores en la partida, espera al amanecer con la baliza encendida y mira la escena en cada cliente.
    ✅ Los dos se ven como pasajeros sentados en el helicóptero, cada uno con su propia armadura y aspecto; cada cliente se ve a sí mismo primero, junto a la puerta; los personajes reales de los dos desaparecen en el corte y reaparecen al acabar.
22. [ ] Con seis jugadores o más en la partida, espera al amanecer con la baliza encendida.
    ✅ Suben hasta seis pasajeros; los que no caben no suben, pero tampoco quedan en pantalla en el suelo.
23. [ ] Con un jugador muerto y el resto vivos, espera al amanecer con la baliza encendida.
    ✅ El muerto no sube, pero tampoco queda en pantalla en el suelo; los vivos suben como siempre.
24. [ ] Mira la postura de los pasajeros de cerca, desde dentro de la cabina, entre 9,6 y 11 s.
    ✅ Las piernas dobladas a 90° no atraviesan el suelo de la cabina (tolerancia de unos 0,1); el piloto lleva las manos en el volante; el casco blanco se distingue sobre el fuselaje; los pasajeros saludan con el brazo derecho sin cortarse con la pared.
25. [ ] Mira la cámara de la segunda parte (9,7 a 19 s): la puerta derecha abierta, el plano de tres cuartos del piloto y la grúa hacia atrás con el helicóptero alejándose.
    ✅ La cámara no atraviesa el rotor principal (radio 6,5) ni la cola durante la grúa final.
26. [ ] Mira el rótulo «¡Rescate!» entre 9,7 y 11 s, con la tripulación en pantalla.
    ✅ El rótulo no tapa a la tripulación. Si molesta, se anota y se baja su duración.
27. [ ] En el emulador de teléfono de gama baja, mira la escena entera (9,6 a 19 s), con piloto, pasajeros y rotores a la vez.
    ✅ Sin tirones ni parones.
28. [ ] Con el juego en inglés y luego en español, mira el rótulo «Everyone is safe!» y «¡Todos a salvo!» en el teléfono (9:16), de 11 a 15 s.
    ✅ Cabe en la zona segura y no se corta, en los dos idiomas.
29. [ ] Pulsa Saltar después de 9,6 s, con la tripulación ya subida.
    ✅ Los personajes reales vuelven a verse, no queda ni helicóptero ni piloto ni copias de pasajeros, la cámara y el HUD vuelven y la victoria llega igual.
30. [ ] Con un avatar de otro tipo (R6, o personalizado sin los `Motor6D` estándar), espera al amanecer con la baliza encendida.
    ✅ La escena no se rompe: el personaje sube igualmente, de pie sobre el cojín.

### 143.12 Perfil real

31. [ ] Antes de probar en Play, haz la copia del perfil de §10.0 y, con el Play parado, restáurala al terminar.
    ✅ Tras restaurar, el perfil real (`PlayerData_v1`) coincide con la copia, y el Ámbar, los huevos y las mascotas son los de antes del Play.

## 144. Fase 25 G4: llegada a la isla (05-11-2026)

La llegada es la escena `Arrival` (`Data/Cinematics`, 13 s, sin botón Saltar la primera vez) y `ArrivalShort` (3 s, saltable). `island/server/Services/ArrivalService` la lanza al entrar cada jugador: si la escena larga ya corre para otro, reintenta cada 0,5 s hasta 40 s. Mientras suena, el personaje real espera oculto y quieto en la playa (anchor 0, 3, 946, 45 studs al costado de la tripulación) y vuelve al Basecamp al acabar. La orden de administrador «🏝️ Llegada» (`CineArrival`) lanza la escena solo para quien la pulsa, aunque ya la haya visto. El tutorial espera a que acabe la cinemática (`HudHider.isHidden`), y `CinematicClient` espera hasta 4 s a que el suelo de la playa esté cargado (`waitTerrain`). Los gestos `Point`, `LookAround` y `Cheer` de `PlayerAnimations` tienen id vacío: en Studio suenan las secuencias generadas de `ReplicatedStorage.PlayerAnimations`, y en el juego publicado no se reproducen hasta pegar sus ids.

### 144.1 Gestos publicados

1. [ ] `Point`, `LookAround`, `Cheer` y `WeaponCarry` (el arma en la mano de los maniquíes) ya tienen su id pegado en `src/shared/Data/PlayerAnimations.luau`. Publica el place de la Isla.
   ✅ El juego publicado no da avisos de animación en la Salida.
2. [ ] Con el juego publicado, entra a la Isla y mira a los maniquíes de la llegada: señalan, miran a los lados y saludan.
   ✅ Los maniquíes hacen `Point`, `LookAround` y `Cheer` en su momento, y no se quedan de pie.

### 144.2 Juego publicado: primera vez y segunda

3. [ ] Con una cuenta nueva en el juego publicado, entra a la Isla desde el Lobby.
   ✅ Ve `Arrival` entera (13 s) sin botón Saltar; al acabar, el personaje vuelve al Basecamp y el tutorial empieza después.
4. [ ] Mira `Arrival` hasta el final, sal de la Isla y vuelve a entrar con la misma cuenta.
   ✅ Ahora sale `ArrivalShort` (3 s) con el botón Saltar. El perfil guarda `cinematicsSeen.Arrival` solo tras verla entera.
5. [ ] Con otra cuenta nueva, sal de la Isla a mitad de `Arrival` (sin que acabe) y vuelve a entrar.
   ✅ Sale `Arrival` entera otra vez: la escena cortada no quedó marcada como vista.

### 144.3 Dos a cinco amigos

6. [ ] Con 2 amigos que nunca hayan visto `Arrival`, entrad a la Isla a la vez.
   ✅ Cada uno ve su `Arrival` entera, en cola: el segundo espera a que acabe el primero (unos 13 s) y no se pisan. Mientras esperan, ambos están en la playa y vuelven al Basecamp al acabar.
7. [ ] Con 5 amigos que nunca hayan visto `Arrival`, entrad a la Isla a la vez.
   ✅ Cada uno ve su escena en cola, de una en una (peor caso unos 15 s por persona). Si el 4.º o el 5.º no llega a verla, el límite de 40 s la corta: se anota quién y en qué segundo se rinde, para decidir si se sube el límite (`MAX_WAIT_SECONDS` en `ArrivalService`).
8. [ ] Con 5 amigos que ya hayan visto `Arrival`, entrad a la Isla a la vez.
   ✅ Cada uno ve `ArrivalShort` en cola (3 s cada una) y todos entran sin esperas largas.

### 144.4 Emulador de teléfono

9. [ ] En el emulador de teléfono (9:16), mira el cartel y los subtítulos de `Arrival` y de `ArrivalShort`.
   ✅ Cartel y subtítulos caben dentro de la zona segura 9:16: no se cortan ni quedan debajo de los controles del teléfono.

### 144.5 Ajuste «Cinemáticas» apagado

10. [ ] Desactiva «Cinemáticas» en los ajustes, entra a la Isla con una cuenta que no haya visto `Arrival` y, con el ajuste apagado, pulsa «🏝️ Llegada» en el panel de administración.
    ✅ No sale escena ni cartel, el tutorial arranca al entrar y el personaje no se queda en la playa. El servidor manda el personaje a la playa aunque el cliente no reproduzca la escena (`ArrivalService.play` → `moveToBeach`) y lo devuelve cuando llega la respuesta `CinematicDone(false)`: se anota si se ve un tirón o un parpadeo, y si lo hay, se avisa.

    Desde el cambio de la espera: con el ajuste apagado, el cliente suelta la tarjeta de espera al recibir la escena, y el personaje espera 2,5 s en la playa antes de que el servidor la lance. ✅ La tarjeta de espera no queda puesta más de unos segundos.
10b. [ ] Entra a la Isla en el juego publicado y mira los primeros segundos de la llegada.
    ✅ Se ve la tarjeta de espera (fondo azul noche, «Primal Banana Islands», «Preparando la isla…», tres puntos que laten y el consejo de abajo) desde que entras y unos 2,5 s más mientras el personaje espera oculto en la playa; la escena empieza con un fundido: sin arena tapando, sin HUD ni el personaje en pantalla. Con la conexión lenta, la tarjeta no pasa de 25 s (tope de seguridad). En inglés salen «Preparing the island…» y el consejo traducido.

10c. [ ] Entra a la Isla en el juego publicado y, al acabar la escena, mira el regreso al Basecamp.
    ✅ Vuelve la tarjeta de espera con «Volviendo al Basecamp…» (como mínimo 1,6 s) hasta que el cliente confirma suelo cargado bajo el personaje (remoto `ArrivalGround`, tope de 15 s en el servidor) y el personaje reaparece de pie en el Basecamp, sin caer por el vacío ni recibir el viñeteo rojo de daño. Si el personaje se ve flotando en el aire o cae, se anota.
10d. [ ] Con una mascota activa, mira `Arrival`, `ArrivalShort` y una aparición de jefe, y la eclosión del huevo en el Lobby.
    ✅ Ninguna mascota (la tuya ni las de los demás) sale en las cinemáticas, y todas vuelven al terminar (carpeta `Workspace.Mascotas`). En la eclosión del Lobby se sigue viendo la mascota nueva que sale del huevo.

### 144.6 Casos límite

11. [ ] Con una cuenta que ya haya visto `Arrival`, pulsa Saltar a mitad de `ArrivalShort`.
    ✅ El personaje vuelve al Basecamp visible y puede moverse, el cartel se quita y el HUD vuelve.
12. [ ] Con una cuenta que no haya visto `Arrival`, muere durante la escena (en Studio, pon la vida a 0 desde la consola de la prueba) y mira qué pasa al reaparecer.
    ✅ Reaparece en el Basecamp visible y con control, la cámara y el HUD vuelven, y la escena no queda a medias en pantalla. La próxima entrada vuelve a sacar `Arrival` entera.
13. [ ] Con una cuenta de primera vez, entra a la Isla, mira `Arrival` hasta el final y, al acabar, mira cuándo empieza el tutorial.
    ✅ El tutorial empieza solo al acabar la escena, no antes, y sus pasos salen normales.

### 144.7 Avatares R6

14. [ ] Con un avatar R6, entra a la Isla con una cuenta de primera vez.
    ✅ La escena corre sin errores en la Salida: el personaje espera oculto y quieto en la playa y vuelve al Basecamp al acabar. Si los gestos no se ven bien con R6, se anota; no deben romper la escena.

### 144.8 Mapa regenerado

15. [ ] Regenera el mapa de la Isla con `island/tools/MapBuilder` (`build({ islandRadius = 950 })`, que borra el terreno) y vuelve a medir el suelo de la playa en el anchor (0, 3, 946).
    ✅ El suelo queda donde espera `ArrivalService` y la escena: el personaje y los maniquíes quedan sobre la arena, sin hundirse ni flotar. Si la altura o la pendiente han cambiado, se anotan y se corrigen el anchor y `BEACH_SLOPE` antes de publicar.

### 144.9 Perfil real

16. [ ] Antes de probar en Play, haz la copia del perfil de §10.0 y, con el Play parado, restáurala al terminar.
    ✅ Tras restaurar, el perfil real (`PlayerData_v1`) coincide con la copia, y el Ámbar, los huevos y las mascotas son los de antes del Play.

## 145. Fase 25 G4b: travesía en lancha antes de la llegada (05-11-2026)

La travesía es la escena `Voyage` (`Data/Cinematics`, 12 s, sin botón Saltar la primera vez): la tripulación va sentada en la lancha voxel nueva (`Shared/LifeboatModel`, 20 piezas, tope `Config.Budgets.Models.Lifeboat` = 25) con oleaje y espuma en la proa, y el cartel «Rumbo a la Isla de monos». Después suena la tarjeta «Preparando la isla…» y `Arrival`; las siguientes veces, `ArrivalShort`. `ArrivalService` ya no tiene candado `busy`: cada jugador tiene su ejecución y su hueco de espera en la playa (`waitSlot`). La orden de administrador «🚤 Travesía» (`CineVoyage`) lanza la travesía. Se probó en Play en el Studio de la Isla con un jugador (capturas y la orden); lo que sigue sin probar es esto.

### 145.1 Juego publicado y primera visita

1. [ ] Con una cuenta que no haya visto `Arrival` (perfil sin `cinematicsSeen.Arrival`; si hace falta, restáurala con §10.0), entra a la Isla desde el Lobby en el juego publicado.
   ✅ Se ve `Voyage` entera (12 s) sin botón Saltar; al acabar, aparece la tarjeta «Preparando la isla…» y encadena con `Arrival` entera (13 s).
2. [ ] Cuando acabe `Arrival`, sal de la Isla y vuelve a entrar con la misma cuenta.
   ✅ Va directa a `ArrivalShort` (3 s, con Saltar) y no sale la travesía.

### 145.2 Dos a cinco amigos

3. [ ] Con 2 amigos que nunca hayan visto `Arrival`, entrad a la Isla a la vez.
   ✅ Cada uno ve su propia `Voyage` y su `Arrival` sin esperar a que acabe la del otro. Esperan en huecos distintos de la playa y nadie ve los maniquíes del otro.
4. [ ] Con 5 amigos que nunca hayan visto `Arrival`, entrad a la Isla a la vez.
   ✅ Cada uno ve su travesía y su llegada sin esperas por los demás. Si el límite de espera (`MAX_WAIT_SECONDS` en `ArrivalService`) corta a alguno, se anota quién y en qué segundo.
5. [ ] Con 2 jugadores: uno ve una escena con congelación (la aparición de un jefe o «🚁 Rescate») y el otro entra a la Isla a la vez.
   ✅ La escena con congelación sigue siendo una a la vez: la segunda no arranca encima de la primera. La llegada del segundo se ve sin congelar a nadie.
6. [ ] Con 2 o más jugadores entrando a la vez, mira la Salida de Studio o del servidor del juego publicado.
   ✅ La llamada repetida a `RequestStreamAroundAsync` no da errores en la Salida.

### 145.3 Móvil y emulador de teléfono

7. [ ] En el emulador de teléfono (9:16), mira la travesía: el cartel «Rumbo a la Isla de monos» en dos líneas y los subtítulos «Al amanecer, con el mar en calma» y «Ya se ve la isla a lo lejos…».
   ✅ Cartel y subtítulos caben dentro de la zona segura 9:16: no se cortan ni quedan debajo de los controles del teléfono.
8. [ ] En el emulador, mira el plano cercano de la lancha.
   ✅ La cara de los maniquíes se ve bien iluminada, sin quemarse por el bloom y sin amarillear.
9. [ ] En un móvil real o en el emulador, mira la travesía con la calidad gráfica en High, Medium y Low, con la espuma de la proa.
   ✅ Sin tirones perceptibles. La espuma usa unas 91 partículas como máximo en High, y menos en Low y Medium.

### 145.4 Avatares

10. [ ] Con un avatar R6, entra a la Isla con una cuenta de primera vez.
    ✅ No aparece copia del avatar en el bote, la travesía corre sin errores en la Salida y la lancha no se ve rara.
11. [ ] Con un avatar R15 con skin y armadura, entra a la Isla con una cuenta de primera vez.
    ✅ El personaje se ve sentado delante en la lancha, y al acabar la escena la lancha queda limpia, sin copias del avatar.

### 145.5 Oleaje y espuma en vídeo

12. [ ] Graba «🚤 Travesía» con OBS a 1080p60 y mira la lancha durante la escena.
    ✅ La lancha sube y baja con el oleaje, y las salpicaduras salen a los lados en cada bajada de proa.

### 145.6 Ajuste «Cinemáticas» apagado

13. [ ] Desactiva «Cinemáticas» en los ajustes y entra a la Isla con una cuenta que no haya visto `Arrival`.
    ✅ No suena `Voyage` ni `Arrival` ni sale cartel. El cliente responde `CinematicDone(false)` a cada escena sin mostrarla, así que el personaje va a la playa, espera unos 2,5 s y vuelve al Basecamp, y el tutorial arranca. Se anota si hay tirón o parpadeo al volver.

### 145.7 Tabla de Creator Hub

14. [ ] En la carpeta del proyecto, ejecuta `python tools/strings.py --csv-nuevas build/localization_nuevas.csv`, sube ese archivo a Creator Hub y luego ejecuta `python tools/strings.py --marcar-subidas`.
    ✅ El CSV trae las 3 frases nuevas («Rumbo a la Isla de monos», «Al amanecer, con el mar en calma» y «Ya se ve la isla a lo lejos…»). Tras `--marcar-subidas`, `tools/strings_subidas.txt` las incluye y `strings.py` no avisa de frases sin inglés.

### 145.8 Mar y lancha desde lejos

15. [ ] Durante el travelling del plano lejano (el mar frente a la playa, a unos 150 studs de la cámara), mira el mar.
    ✅ No se ven facetas ni el borde del mar generado, y la lancha no se hunde ni atraviesa el agua.
16. [ ] Mira al Guerrero, al Cazador y al Médico sentados en la lancha desde varios ángulos (de frente, de lado y por detrás).
    ✅ Ninguno sobresale del borde (tubo) de la lancha desde esos ángulos.

## 146. Fase 26 26a: modos en Dunas y cola por modo (05-11-2026)

La bandera pasa a `Modes/CaptureFlag` (la misma interfaz que el Laboratorio), la cola de Dunas es `ArenaQueue_<modo>_<formato>` con `mode` y `format` en `TeleportData`, y el Lobby reparte los contadores de `ArenaQueueCounts` como `{ [modo] = { [formato] = n } }`. Se probó en Studio con un jugador y solo el modo de bandera: fases, marcador, muerte súbita, revancha y formatos. Lo que sigue sin probar es esto.

### 146.1 Cola real Lobby → Dunas (juego publicado, 2 jugadores)

1. [ ] Con dos cuentas en el Lobby del juego publicado, ponte en la cola de Dunas con el modo «Captura la bandera» y el formato 1 (1 contra 1), y que las dos entren en la misma cola.
   ✅ Las dos cuentas aparecen en `ArenaQueue_CaptureFlag_1` y pasan juntas a Dunas.
2. [ ] Al llegar a Dunas, mira el `TeleportData` que recibe el servidor y el atributo `Workspace.ArenaMode`.
   ✅ `TeleportData` trae `mode` y `format` con los valores elegidos, y `Workspace.ArenaMode` vale `"CaptureFlag"`.

### 146.2 Cartel de la Isla de dunas y ventana del Lobby (2 cuentas)

3. [ ] Con una cuenta en el Lobby, mira el cartel de la Isla de dunas con la cola vacía y después mientras otra cuenta se pone en cola.
   ✅ El cartel sigue mostrando los contadores de la cola, leídos de `ArenaQueueCounts` en el formato nuevo, y los números cuadran con quién está en cada formato.
4. [ ] Abre la ventana de Dunas desde el Lobby en el PC y en el teléfono.
   ✅ Se ve igual que antes de la 26a, sin selector de modo, y todo cabe sin desplazamiento.

### 146.3 Partido de bandera con 2 jugadores

5. [ ] Con las dos cuentas en Dunas, pasad por equipos y «Listo», y capturad la bandera del rival hasta sumar un punto.
   ✅ La captura suma en el marcador de los dos, la bandera vuelve a su base y el flujo de equipos y «Listo» funciona igual que en Studio.

### 146.4 Final y vuelta al Lobby

6. [ ] Termina una partida entera con 2 jugadores y espera a que acaben los resultados (`ResultsSeconds`) sin cerrar el juego.
   ✅ Los resultados se ven completos durante todo su tiempo y después el juego vuelve al Lobby solo, fuera de Studio.

### 146.5 Tickets de la cola anterior

7. [ ] Antes de desplegar, pon a una cuenta en la cola vieja `ArenaQueue_<formato>` (sin modo). Tras desplegar, mira si esa cuenta entra en alguna partida.
   ✅ Los tickets de la cola vieja caducan y se pierden: nadie es emparejado con ellos. Quien estuviera esperando tiene que volver a ponerse en la cola nueva.

## 147. Fase 25 G5a: batalla montada de la tripulación contra una manada (05-11-2026)

La batalla es la escena `Battle_Pack` (14 s): la tripulación (Guerrero, Cazador, Mago y Médico) lanza sus habilidades reales contra Mandril, Babuino, Macaco y AulladorRojo. Los monos son instancias del servidor sin IA (`CinematicMonkeyService`) que se borran al acabar la escena, y los efectos salen de `Shared/Cinematics/AbilityShow` con el gobernador de picos. La versión para vídeo es `Battle_Pack_Comic`. Se probó en Play en el Studio de la Isla con un jugador (capturas de ambas versiones, sin errores de Luau). Lo que sigue sin probar es esto.

### 147.1 Play en el Studio de la Isla con las órdenes

1. [ ] En Play, lanza «🥊 Batalla» desde el panel de pruebas y mira la escena entera.
   ✅ Dura unos 14 s, cada habilidad sale con su efecto y, al acabar, no queda ningún mono de la escena (los que llevan el atributo `CinematicActor`).
2. [ ] Con la escena en marcha, mira al Cazador y al Guerrero en las posturas de arma `Aim*` y `Hold`.
   ✅ El arma sigue en la mano y no se queda en la cara ni vertical a la altura de la cabeza. Si una postura sale mal, se anota su nombre (trampa 6 de G4).
3. [ ] Mira las flechas del Cazador (MultiShot y ArrowRain) y la bola de fuego del Mago.
   ✅ Las flechas y la bola atraviesan a los monos. Es lo esperado hoy (no hay `ProjectileEnd`), así que se anota y no se toma por fallo. Nada se queda parado en el aire.
4. [ ] Mira la nova de hielo del Mago y el Smash del Guerrero.
   ✅ Los efectos se ven completos y ninguno tapa la cámara.
5. [ ] Mira el movimiento de los monos durante la escena.
   ✅ Se mueven de forma continua. Si hay saltos (se mueven desde el servidor a ~20 Hz), se graba y se anota el segundo.
6. [ ] Mira si entra en cuadro algún mono ambiental de la isla.
   ✅ Ninguno. Si se cuela uno, se anota el plano (ver la trampa 5).
7. [ ] Con «🥊 Batalla cómic», mira los paneles, los 4 bocadillos, las 4 onomatopeyas y la narración.
   ✅ Cada bocadillo que apunta a un mono señala a ese mono y no al aire, y ninguno tapa la cara de un maniquí.
8. [ ] Lanza «🥊 Batalla» dos veces seguidas, la segunda al acabar la primera.
   ✅ La segunda arranca limpia: no quedan monos ni efectos de la primera, y la Salida no muestra errores de Luau.

### 147.2 Calidad de efectos: Low, Medium y High

Se cambia el ajuste «Efectos de los jefes» (`fxQuality`) antes de cada prueba.

9. [ ] Con «Efectos de los jefes» en High, lanza «🥊 Batalla» y anota el pico de piezas de efectos en el momento de más habilidades a la vez (Meteoro, lluvia de flechas y bola de fuego).
   ✅ El pico no supera 160 piezas (`Config.Budgets.Vfx.High`). La estimación era de unas 100 piezas, no confirmada, así que se anota el pico real. No hay más de dos efectos grandes vivos a la vez, ni dos grandes con menos de 0,4 s entre ellos.
10. [ ] Con «Efectos de los jefes» en Medium, lanza «🥊 Batalla».
    ✅ Las habilidades se ven con sus efectos, algo menos que en High, y el pico no supera 90 piezas (`Config.Budgets.Vfx.Medium`).
11. [ ] Con «Efectos de los jefes» en Low, lanza «🥊 Batalla» y mira el Meteoro y la lluvia de flechas.
    ✅ Salen en su versión `fallback`, sin el efecto grande. La escena no se queda vacía y el pico no supera 40 piezas (`Config.Budgets.Vfx.Low`).

### 147.3 Vídeo grabado

12. [ ] Graba «🥊 Batalla» con OBS a 1080p60 en 16:9 y mira el encuadre con la guía 9:16.
    ✅ Los maniquíes y los monos caen dentro de la zona segura 9:16 en los planos principales, y no se corta ninguna habilidad.
13. [ ] Graba «🥊 Batalla cómic» y recorta el 9:16 central en CapCut.
    ✅ El recorte conserva los bocadillos, las onomatopeyas y la narración. Ninguna viñeta queda a medias y ningún texto se corta.
14. [ ] En la grabación de «🥊 Batalla», mira el plano del Médico (AreaHeal) y el Meteoro del final.
    ✅ Ningún plano queda a oscuras ni quemado por el bloom, y la cara del Médico se ve bien iluminada.

### 147.4 Dos o más jugadores

15. [ ] Con 2 jugadores en la Isla, la cuenta de administrador lanza «🥊 Batalla» y mira la pantalla del otro jugador.
    ✅ Los monos y los maniquíes se ven igual en los dos clientes, porque son instancias del servidor visibles a todos. Se anota si el otro jugador ve la escena o queda congelado.
16. [ ] Con 2 jugadores, uno lanza «🥊 Batalla» mientras el otro entra a la Isla (llegada).
    ✅ Las dos escenas no se pisan: la escena con congelación sigue siendo una a la vez, y los monos de la batalla no aparecen en la llegada del otro.
17. [ ] Con 2 jugadores, que cada cuenta lance «🥊 Batalla» a la vez.
    ✅ Cada batalla borra solo sus monos (`CinematicOwner`), ninguna se queda sin monos a mitad y la Salida no da errores.

### 147.5 Juego publicado

18. [ ] Publica la Isla y, con una cuenta de administrador, lanza «🥊 Batalla» desde el panel de pruebas (si la cuenta lo tiene disponible en el juego publicado).
    ✅ Se ve igual que en Studio, sin errores en la Salida del servidor ni del cliente.
19. [ ] Con una cuenta sin permisos de administrador, juega una partida normal de la Isla.
    ✅ No aparece ninguna batalla ni orden de batalla durante la partida.

## 148. Fase 26 26b: la cancha de Dunas (05-11-2026)

La cancha (`Workspace.Cancha`, generada por `World/CourtBuilder` con `CourtGeometry` como fuente de medidas) se probó en Studio de Dunas por MCP con un jugador: layout 1, 3 y 5 (suelo de 56, 88 y 120 studs; 222, 238 y 248 piezas, 2 a 3 ms), apariciones por equipo, `TeamBarrier` en el grupo `CourtBarrier` (choca con el suelo y no con `Disparo`), bandera igual que antes con `setMode("CaptureFlag")`, y capturas de vista general, desde dentro y de cerca del aro. Lo que sigue sin probar es esto.

### 148.1 Piezas de la cancha (Studio de Dunas, a mano)

`Rendimiento` solo existe en el Studio de la Isla y no mide `Workspace.Cancha`, así que el recuento se hace a mano. Añadir la línea de `CourtParts` a `Rendimiento` queda pendiente.

1. [ ] Con el place de Dunas en modo edición, deja la cancha en 5v5 con `require(game.ServerScriptService.Server.World.CourtBuilder).layout(5)` y cuenta las piezas de `Workspace.Cancha` en la barra de comandos: `local n = 0; for _, d in workspace.Cancha:GetDescendants() do if d:IsA("BasePart") then n += 1 end end; print(n)`.
   ✅ Sale 248 piezas, por debajo del tope de 800 (`Config.Budgets.Matches.CourtParts`). Si sale otro número, se anota el formato que había puesto.

### 148.2 Juego publicado

2. [ ] Publica el place de Dunas con la cancha guardada en el place y entra con una cuenta. En el Explorer, mira `Workspace.Cancha` y su atributo `Version`.
   ✅ Existe `Workspace.Cancha` con `Version` = 4 desde el primer momento.
3. [ ] Espera unos 30 s en Dunas y vuelve a mirar `Workspace.Cancha` (mismo `Court` y mismo número de piezas).
   ✅ La cancha no cambia: el servidor no la regenera con retraso ni aparece una segunda `Court`.

### 148.3 Dos jugadores (muro de equipo, espera y rayos)

Hasta 26e el modo Ballgame no sale en la cola, así que se activa a mano con `ArenaWorldService.setMode("Ballgame")` en el servidor, con la cancha montada.

4. [ ] Pon a las dos cuentas en equipos distintos (una Jaguar, otra Quetzal). Que cada una intente cruzar el muro de equipo (x = 0) desde su lado y desde el contrario, andando y saltando.
   ✅ Ninguna lo cruza: el muro bloquea a los dos equipos desde los dos lados.
5. [ ] Con las dos cuentas en `Cancha/EsperaSpawn` (sin equipo), que salgan de la espera hacia la cancha, vuelvan y lo repitan cambiando de equipo.
   ✅ Nadie queda atascado en la espera ni dentro del muro, y cada cuenta aparece en su `Spawn_<equipo>`.
6. [ ] Con el arco del Cazador o el bastón del Mago, dispara a la otra cuenta a través del muro de equipo.
   ✅ El rayo atraviesa el muro y el impacto llega como en el resto del mapa. Si el muro lo para, se anota: sería un fallo de la matriz de colisión.

### 148.4 Móvil y PC: banqueta, talud y plaza

7. [ ] En el teléfono (emulador o móvil) y en PC, camina por la banqueta y sube el talud (unos 51°) hasta el paramento, a los dos lados de la línea central.
   ✅ Se anda sin trabarse en la banqueta ni en el cambio de pendiente, sin saltar ni hundirse, y se llega arriba del talud sin caerse.
8. [ ] Sube a la plaza superior (y = 20) y camina hasta el borde exterior, y después hasta el borde interior, sobre la cancha.
   ✅ Nadie cae por el borde exterior. Por el borde interior sí se puede caer a la cancha: es a propósito, no hay barandilla.

### 148.5 Aspecto con la iluminación del place

9. [ ] Mira la cancha desde la plaza y desde la espera, con la iluminación real del place (no la de edición).
   ✅ Se leen el suelo, las bandas, las cabeceras y los aros. Si el patio se ve oscuro, se añaden luces antes de dar el aspecto por bueno.
10. [ ] Mira de cerca las rayas `FloorStripe_<equipo>` y el tlécotl (`Court/Decor`), desde el suelo y desde la plaza, moviendo la cámara.
    ✅ No parpadean (z-fighting) con el suelo, que están a 0,06 studs. Si parpadean, se anota el sitio y se sube su altura.

## 149. Fase 25 G5a (reel): versión vertical con estilo cómic de la batalla (05-11-2026)

La versión reel es la escena `Battle_Pack_Reel` (15 s: 14 s más `REEL_TAIL_SECONDS` = 1 s extra, para que el cartel de cierre con el nombre del juego dure 1,7 s). Usa el modo reel de `Comic`: una banda central 9:16 calculada con `Comic.reelBand` sobre el viewport real, relleno liso fuera de la banda y dos líneas finas en su borde. La orden es «🥊 Batalla reel». Se probó en Play en el Studio de la Isla con un jugador (capturas de varios cortes; dura 14,8 s medidos). Lo que sigue sin probar es esto.

### 149.1 Play en el Studio de la Isla con «🥊 Batalla reel»

1. [ ] En Play, lanza «🥊 Batalla reel» desde el panel de pruebas y mira la escena entera.
   ✅ Dura unos 15 s. Se ve solo la banda central 9:16 y el relleno liso a los lados, con sus dos líneas finas en el borde.
2. [ ] Mira las viñetas, los bocadillos y las onomatopeyas de los 15 cortes.
   ✅ Cada corte tiene su encuadre y ninguna habilidad queda cortada. El bocadillo del Guerrero no tapa su cara. Nunca hay dos onomatopeyas vivas a la vez (¡ROAAAR!, ¡FUM!, ¡WHOOSH!, ¡CRASH!, ¡BUM!) y se leen en las esquinas.
3. [ ] Mira el gancho del mandril al empezar.
   ✅ Se entiende que es el mandril. Ya se sabe que sale pequeño: si no se lee, se anota el corte.
4. [ ] Mira el Meteoro y la lluvia de flechas dentro de la banda.
   ✅ Se ven completos dentro de la banda y no se salen por los lados. Esto no se ha visto todavía en la banda: si algo se corta, se anota el plano.
5. [ ] Mira la nova de hielo del Mago.
   ✅ Se distingue la forma del hielo. Ya se sabe que sale casi blanca: si se confunde con el fondo, se anota.
6. [ ] Llega al último plano, con el cartel de cierre y el fundido.
   ✅ El cartel con el nombre del juego dura 1,7 s y cae dentro de la zona segura. El fundido termina la escena sin cortes bruscos. Esto no se ha visto todavía: si la captura del MCP no llega a tiempo, se anota (ver la trampa 6 de G5a en `docs/PLAN.md`).
7. [ ] Lanza «🥊 Batalla reel» dos veces seguidas, la segunda al acabar la primera.
   ✅ La segunda arranca limpia y dura lo mismo. La Salida no muestra errores de Luau.

### 149.2 Grabación con OBS y recorte en CapCut

8. [ ] Graba «🥊 Batalla reel» con OBS a 1080p60 en 16:9 y pon la guía 9:16 sobre la escena.
   ✅ La franja central de 608×1080 (desde x = 656) contiene a los maniquíes, los monos y las onomatopeyas.
9. [ ] En CapCut, recorta 608×1080 desde x = 656 y escala a 1080×1920.
   ✅ El resultado es 1080×1920, sin relleno liso a los lados ni bordes negros, y las dos líneas finas no se ven en el encuadre final.
10. [ ] Revisa en el vídeo final que el texto está dentro de la zona segura: 12 % arriba y 22 % abajo.
    ✅ Ningún texto (cartel, bocadillos, onomatopeyas) pasa de esas líneas.
11. [ ] Mira el cartel de cierre y el fundido en la grabación.
    ✅ El cartel dura 1,7 s y el fundido se ve completo, sin cortarse en el último segundo.

### 149.3 Otras relaciones de aspecto y tamaños de ventana

12. [ ] Con la ventana de Studio en 1280×720, lanza «🥊 Batalla reel».
    ✅ La banda se recorta 406×720 desde x = 437 y se escala a la pantalla. Las dos líneas finas quedan en su borde.
13. [ ] Cambia el tamaño de la ventana de Studio a una relación distinta de 16:9 (por ejemplo, cuadrada) con la escena en marcha, o vuelve a lanzarla.
    ✅ La banda se recalcula con el nuevo viewport y sigue centrada. Se anota si el resultado es raro al cambiar el tamaño en mitad de la escena.
14. [ ] En un emulador de teléfono (vertical y horizontal) o en el móvil, lanza «🥊 Batalla reel».
    ✅ La banda se calcula con el viewport real y sigue centrada. El texto se queda dentro de la zona segura y no se corta el cartel.

### 149.4 Hora del día

15. [ ] Con el ciclo de día parado en noche, graba «🥊 Batalla reel».
    ✅ La escena se ve con la luz calibrada: ni oscura ni quemada por el bloom.
16. [ ] Con el ciclo de día parado en atardecer, repite.
    ✅ Igual que en noche, y sin tintes naranja que tapen la imagen.
17. [ ] Con el ciclo de día parado en día (sol alto), repite.
    ✅ Ya se sabe que el sol quema el fondo. Se anota el plano afectado y la grabación se hace de noche o con la hora fijada en la escena.

### 149.5 Calidad de efectos: Low, Medium y High

Se cambia el ajuste «Efectos de los jefes» (`fxQuality`) antes de cada prueba.

18. [ ] Con «Efectos de los jefes» en Low, lanza «🥊 Batalla reel» y mira el Meteoro y la lluvia de flechas.
    ✅ Salen en su versión `fallback`, la escena no se queda vacía y dura 15 s.
19. [ ] Con «Efectos de los jefes» en Medium, y después en High, lanza «🥊 Batalla reel» y mira la nova de hielo y el Meteoro dentro de la banda.
    ✅ Se ven completos y no se salen de la banda. El pico de piezas no supera 90 (Medium) ni 160 (High) (`Config.Budgets.Vfx`).

### 149.6 Inglés

20. [ ] Con el idioma del juego en inglés, lanza «🥊 Batalla reel».
    ✅ Los textos salen en inglés, con ¡BUM! como «BOOM!» y el resto de onomatopeyas. Los bocadillos caben en su sitio y el cartel de cierre se lee bien. En Studio se ve así; en el juego publicado, la frase «¡BUM!» depende de que esté subida a la tabla de Creator Hub (pendiente, junto con las de G5a).

### 149.7 Dos o más jugadores y juego publicado

21. [ ] Con 2 jugadores en la Isla, la cuenta de administrador lanza «🥊 Batalla reel» y mira la pantalla del otro jugador.
    ✅ El otro cliente ve la escena igual, o se anota si queda congelado (como en 147.4).
22. [ ] Publica la Isla y, con una cuenta de administrador, lanza «🥊 Batalla reel» desde el panel de pruebas (si la cuenta lo tiene disponible en el juego publicado).
    ✅ Se ve como en Studio, con su cartel de cierre, sin errores en la Salida del servidor ni del cliente.

## 150. Fase 25: las escenas fijan su propia hora (05-11-2026)

Cada escena lleva un campo `hour` en `Data/Cinematics` y `SceneLight` lo escribe en `Lighting` (`CinematicClockTime`). `LightingController` dibuja esa hora con un desfase de reloj: 0,4 s al entrar y 0,8 s al salir, sin tocar el ciclo real. `WeatherController` trata el clima como despejado mientras dura una escena con hora propia. Horas: 18,8 (llegadas, batallas, jefes y sus versiones cómic), 17,5 (Gorila de Ceniza y su cómic), 5,95 (`Voyage`, amanecer, con luces más bajas), 6,1 (`Rescue`) y 14 (`Prueba`). `EggHatch` no tiene hora.

Probado en Play en el Studio de la Isla con `Voyage` y el ciclo forzado a mediodía (`DebugClock` = 12): sale con su hora, y al acabar el atributo se borra y el reloj vuelve a 12. Lo que sigue sin probar es esto.

### 150.1 Play en la Isla: cada escena en su hora

1. [ ] Con el ciclo forzado a mediodía (`DebugClock` = 12), lanza «🚤 Travesía» y mira la escena entera.
   ✅ Sale con la luz de amanecer (5,95) y no con la del mediodía. Al acabar, el reloj vuelve a 12.
2. [ ] Con el ciclo forzado a medianoche (`DebugClock` = 0), repite «🚤 Travesía».
   ✅ Sale igual que en el paso 1: la hora de la escena manda sobre la del ciclo.
3. [ ] Con `DebugClock` = 12, lanza «🏝️ Llegada» y mira la playa.
   ✅ Sale al atardecer (18,8). Si la primera vez ya se vio, la versión corta sale a la misma hora.
4. [ ] Con `DebugClock` = 0, lanza «🥊 Batalla», «🥊 Batalla cómic» y «🥊 Batalla reel», una tras otra.
   ✅ Las tres salen a 18,8, ni de noche cerrada ni a pleno día, y vuelven al ciclo al acabar.
5. [ ] Con `DebugClock` = 12, lanza «👑 Siguiente jefe» (o «🎬 Plató») hasta ver el Orangután del Manglar, el Caudillo y el Albino, y sus versiones cómic.
   ✅ Los cuatro salen a 18,8.
6. [ ] Con `DebugClock` = 0, lanza el Gorila de Ceniza y su versión cómic.
   ✅ Salen a 17,5, un poco antes que los otros jefes, y el cambio de hora no se nota a mitad de la escena.
7. [ ] Con `DebugClock` = 12, lanza «🚁 Rescate».
   ✅ Sale a 6,1 (amanecer temprano). Al llegar a la victoria, el reloj vuelve a 12.
8. [ ] Con `DebugClock` = 12, lanza «🎬 Cinemática de prueba».
   ✅ Sale a 14 (tarde) y vuelve a 12 al acabar.
9. [ ] En el Lobby, mira la eclosión del huevo en el nido (`EggHatch`).
   ✅ Sale con la hora del Lobby (17,6), que fija `LobbyBuilder`. No hay barrido ni parpadeo, porque el Lobby no tiene controlador de ciclo.

### 150.2 Sin parpadeo al entrar y salir

10. [ ] Con `DebugClock` = 12, entra y sal de «🚤 Travesía» tres veces seguidas mirando el cielo y el mar en la transición.
    ✅ El barrido de 0,4 s al entrar y el de 0,8 s al salir se ven suaves, sin parpadeos ni saltos de luz.
11. [ ] Con `DebugClock` = 0, repite el paso 10 con «🥊 Batalla reel».
    ✅ Igual que el paso 10.

### 150.3 Saltar la escena restaura la hora

12. [ ] Con `DebugClock` = 12, lanza «👑 Siguiente jefe» y pulsa Saltar a los 2 segundos.
    ✅ La hora vuelve a 12 con el barrido de salida, sin quedarse en 18,8. En Studio, Lighting ya no tiene `CinematicClockTime` ni `CinematicClockSeconds`.
13. [ ] Con `DebugClock` = 0, lanza «🥊 Batalla» y pulsa Saltar en mitad de la escena (si la deja saltar).
    ✅ Igual que el paso 12, hacia la medianoche.

### 150.4 Clima y luna roja durante una escena

14. [ ] Con el clima de tormenta activo, lanza «🥊 Batalla» y «🏝️ Llegada».
    ✅ La escena se ve con cielo despejado, sin lluvia ni erupción en el fondo. Al acabar, vuelve el clima de tormenta.
15. [ ] Con la luna roja activa (§57), lanza «🥊 Batalla» y «👑 Siguiente jefe».
    ✅ La escena mantiene su hora y su luz. Si la luna roja se nota dentro de la escena, se anota el plano: no está decidido si debe quedar tapada.

### 150.5 Voyage más clara

16. [ ] Con `DebugClock` = 12, lanza «🚤 Travesía» con las luces nuevas (exposure lejano 0,8, sol 2,0, relleno 0,7, brightness cercano 0,6, exposure cercano 0,2) y mira la lancha y el mar en tres momentos.
    ✅ Se distinguen la lancha, la tripulación y la línea del mar, y se ve más claro que antes del cambio de luces. Si sigue casi negro, se anota y se valora subir la hora a unas 6,3 y reajustar las luces.
17. [ ] En el emulador de teléfono, mira «🚤 Travesía» en vertical.
    ✅ Se lee la lancha y el cartel «Rumbo a la Isla de monos», sin mar negro.

### 150.6 Dos jugadores con escenas a la vez

18. [ ] Con 2 jugadores en la Isla, uno lanza «🚤 Travesía» y el otro «🥊 Batalla» o «👑 Siguiente jefe» a la vez.
    ✅ Cada uno ve su escena a su hora. Cuando acaba una, la otra no pierde su hora. Si las horas se pisan (ambas escenas escriben en `Lighting`), se anota.
19. [ ] Con 2 jugadores, la cuenta de administrador lanza «🚤 Travesía» mientras el otro entra al Basecamp por la llegada.
    ✅ Sin errores de Luau en la Salida, y ninguna escena deja a la otra con la hora de la anterior.

### 150.7 Juego publicado

20. [ ] Publica la Isla y, con una cuenta, lanza «🚤 Travesía» a mediodía y después una escena de jefe.
    ✅ Salen a 5,95 y 18,8 (o 17,5 con Ceniza), y el reloj vuelve al real al acabar. Sin errores en la Salida del servidor ni del cliente.

## 151. Fase 26 26c: la pelota de Dunas (05-11-2026)

La pelota (`Shared/BallSim`, `BallService` y `BallController`) se probó en Studio de Dunas con un jugador: `BallSim` en modo edición (11 pruebas: botes, talud, paramento, `out`, muro del fondo, `ringPass`, rodar, alta velocidad, determinismo y fuzz), y en Play la pelota y la sombra en el cliente, el desvío cliente-servidor, el reposo con reenvío, la desaparición tras `out`, los comandos de depuración, el `ringPass` en los dos lados y el cambio de formato. Lo que sigue sin probar es esto.

### 151.1 Dos jugadores y latencia real

Con 2 clientes en Dunas (*Prueba → Clientes y servidores*), activa la pelota con «🏀 Pelota: activar» y saca con «🏀 Pelota: saque».

1. [ ] Mira la pelota en los dos clientes durante un saque y varios botes.
   ✅ Está en el mismo sitio en los dos (diferencia de unos pocos studs como mucho) y los botes coinciden.
2. [ ] Simula 100 ms y después 200 ms de ping en uno de los clientes (la red simulada del Studio si la hay, o dos cuentas en redes distintas sobre el juego publicado) y repite un saque y un tiro con «🏀 Pelota: tiro al aro (alterna lado)».
   ✅ La pelota se mueve sin saltos bruscos en los dos lados. Un desvío se disuelve en unos 0,15 s y solo salta de golpe si pasa de 8 studs. Si se ve un salto mayor, se anota el ping y el momento.
3. [ ] Con 200 ms de ping, deja la pelota parada en el suelo durante 10 s y después saca otra vez.
   ✅ Parada, se queda quieta en los dos clientes, sin desaparecer ni moverse sola. El saque siguiente se ve en los dos.

### 151.2 Profiler del servidor

4. [ ] Con la pelota activa y un saque en marcha durante 30 s y 2 clientes, mira el coste de `BallService` en el profiler del servidor (el de Studio en modo Play, con cliente y servidor).
   ✅ Su coste queda por debajo de 0,3 ms por fotograma.
5. [ ] Cuando 26e tenga un oyente de servidor (`BallService.onEvent`), conecta uno que cuente los eventos `bounce` y `rest` de un partido con la pelota activa, y mide el coste otra vez con el profiler.
   ✅ El coste total sigue por debajo de 0,3 ms por fotograma, y el oyente recibe cada evento una vez y en orden. Se hace al cerrar 26e, no antes.

### 151.3 Juego publicado

6. [ ] Publica el place de Dunas, entra con una cuenta y mira la Salida del cliente y la del servidor al cargar la partida.
   ✅ No hay errores de `BallController` ni de `BallService`.
7. [ ] Con la cuenta de administrador, pulsa «🏀 Pelota: activar» y después «🏀 Pelota: saque».
   ✅ Aparecen la pelota y su sombra en el cliente. La sombra cae sobre la cancha y se aclara al subir la pelota.

### 151.4 En el teléfono

Elige un teléfono en *Prueba → Dispositivo* antes del ▶.

8. [ ] Activa la pelota con «🏀 Pelota: activar», saca con «🏀 Pelota: saque» y mira la pelota desde la cámara de la Dunas.
   ✅ La pelota se ve nítida sobre la arena, y su sombra se lee en el suelo sin confundirse con la pelota.
9. [ ] Lanza «🏀 Pelota: tiro al aro (alterna lado)» y sigue la pelota hasta el aro.
   ✅ Se distingue el aro y su agujero, y la pelota se sigue viendo al pasar por él.

### 151.5 Roce del aro

El roce con el borde del aro usa un umbral de 0,6 studs. Está sin ajustar: se prueba al jugar y se corrige en 26d o 26e, no antes.

10. [ ] Con 1 o 2 jugadores, lanza «🏀 Pelota: tiro al aro (alterna lado)» varias veces y mira los roces con el borde y los pases por el agujero.
    ✅ Un roce con el borde rebota a la vista, y un pase limpio por el agujero se lee como pase, sin quedarse pegado en el aro. Si un roce cuenta como pase o al revés, se anota el tiro.
11. [ ] Cuando 26d permita golpear, juega varias jugadas de aro a 3 o 4 distancias del aro y di si el roce se siente justo.
    ✅ Un roce que toca el borde se lee como roce y un pase limpio como pase. Si no se siente justo, se anota el valor que se probó: el ajuste se hace en 26d o 26e.

## Cuando termines

Si todo va bien, sigue con [LANZAMIENTO.md](LANZAMIENTO.md). Si algo falla, avísame con el número de paso y las líneas rojas de la Salida.
