# Verificación paso a paso (entregas 2.3 a 6.5, la arena de Dunas, las Fases 9 y 10 y los pedidos del 26-10-2026)

Sigue los bloques en orden. Cada bloque dice **qué hacer**, **qué debe pasar ✅** y **qué hacer si falla ⚠️**.
Marca cada casilla al comprobarla.

> **Cómo avisarme de un fallo:** dime el número del paso (por ejemplo "5.2, paso 4"), qué esperabas y qué pasó, y copia las líneas en **rojo** de la ventana **Salida** de Studio (Vista → Salida). Una captura ayuda mucho.

---

## 0. Preparación (una sola vez)

- [ ] **Actualizar el código:** en VS Code, *Pull* de la rama `claude/monkey-island-roblox-design-ro2mg4` (o en GitHub Desktop, *Fetch origin* → *Pull*).
- [ ] **Reiniciar Rojo:** cierra los dos `rojo serve` y vuelve a lanzarlos:
  - `rojo serve lobby.project.json` (puerto 34872)
  - `rojo serve island.project.json` (puerto 34873)
  - `rojo serve dunas.project.json` (puerto 34874, para la arena: §8)
- [ ] En Studio, abre el place **Isla** y conecta el plugin de Rojo al puerto **34873**. Haz lo mismo con el **Lobby** en el **34872**.
- [ ] **Acceso a las API** (para el guardado): *Archivo → Configuración del juego → Seguridad → Habilitar acceso de Studio a los servicios de API*, en **los dos** places. Publica después de activarlo.
- [ ] **Panel de pruebas:** al darle a ▶ *Jugar* en Studio verás abajo a la izquierda un botón **🛠️ Pruebas**. Despliega órdenes para no tener que esperar días de partida: dar materiales, sacar un jefe, el huevo, una caja, cambiar el clima… Solo existe en Studio: en el juego publicado no aparece.
- [ ] **Dos jugadores** (para PvP, grupos y la vida de los aliados): *Test → Clients and Servers → 2 Players → Start*. Si no lo encuentras, busca "clients" con **Ctrl+Mayús+P**.

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

## 2.3 Taller del curandero y forja de piedra

1. [ ] Abre la **Isla** y dale a ▶. En **🛠️ Pruebas**, pulsa **🎒 +50 de todo**.
   ✅ A la derecha salen avisos "+50 …" y en la Bolsa (B) aparecen todos los materiales.
2. [ ] Equipa el **martillo** (5). A la derecha aparece la lista de piezas: elige **🌿 Taller del curandero**.
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
4. [ ] Quédate solo con **carne cruda** como comida y pulsa **C** cuando tengas hambre (🛠️ **Hambre y sed al 10**).
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

1. [ ] Aparece la primera vez que entras a la Isla. Para verlo otra vez, cambia `Config.Data.StoreName` a `"PlayerData_v2"`: es como empezar de cero.
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

## 6.1 Baliza y victoria

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

1. [ ] En el Lobby (Studio), icono **🎨 Estilo**. En Studio los cosméticos sin pase son gratis para probar: **Equipar** la Estela dorada, el Título y el Aura.
   ✅ Se ven en tu personaje en el Lobby y en la Isla. El **Título: Superviviente de la Isla** sale con "Gana una partida" (ni en Studio es gratis; ver 7.6).
2. [ ] En el juego publicado, sin pases creados, salen como **"Próximamente"** (normal; ver [LANZAMIENTO.md](LANZAMIENTO.md)).
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
2. [ ] Pulsa **🎯 Críticos al 100 %** y vuelve a pegar: los números salen un **25 % más grandes**, con "!" y un temblor. Púlsalo otra vez para volver a lo normal.
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

### 7.5 Misiones diarias

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

Antes: guarda los places del Lobby y de Dunas y **publica los tres a la vez** (perfil v4).

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

▶ *Jugar* en Studio **escribe tu perfil de verdad** (el mismo que el del juego publicado). Antes de probar, en la barra de comandos de Studio (en edición, con el acceso a las API activado) pon tu número de usuario y ejecuta:

```lua
local DS = game:GetService("DataStoreService")
local clave = "u_" .. 0 -- ← tu UserId
DS:GetDataStore("PlayerData_v1_backups"):SetAsync(clave .. "_antesFase9", DS:GetDataStore("PlayerData_v1"):GetAsync(clave))
```

Al terminar, para dejarlo como estaba, cambia el orden (lee de `PlayerData_v1_backups` con la clave `.. "_antesFase9"` y guarda en `PlayerData_v1` con `clave`), con el Play parado.

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

### 10.5 Equipo ligado a los jefes (Isla)

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

### 10.8 La Gran Tropa, la baliza y el tótem (Isla)

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
14. [ ] **Bloqueo de cámara:** en el menú de Roblox enciende "Shift Lock" y pulsa **Ctrl**.
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

1. [ ] **Duelo espejo** (los dos del mismo rol, sin defenderse): cuenta los segundos hasta que cae uno.
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

1. [ ] Entra con un perfil que tenga mascotas repetidas (versión 8).
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

### 16.1 En el Lobby (▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia)

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

1. [ ] Publica los **3 places a la vez** (el perfil pasa a la versión 10) y entra al Lobby.
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

1. [ ] Publica los **3 places a la vez** (el perfil pasa a la versión 11) y elige otra V en el Lobby.
   ✅ Al ir a la Isla y a Dunas lleva la V elegida, y al volver al Lobby sigue elegida.

## 18. Lo que queda por probar de la Fase 12: Victoria y parcela permanente (27-10-2026)

### P1. Seguir sobreviviendo

Probado en Studio (1 jugador, con 🛠️ Pruebas → «🚁 Terminar: victoria (rescate)» y «💀 Terminar: derrota», que son de prueba y no cuentan para el récord):
- **Rescate:** la ventana sale con «♾️ Seguir sobreviviendo», «Volver al Lobby» y «Si no eliges, vuelves al Lobby en N s», y cabe entera en la pantalla. Da +200 de Ámbar y suma 1 partida.
- **Seguir:** después de pulsar el botón, a los 30 s sigues en la partida y el estado de la baliza dice «♾️ Seguir sobreviviendo».
- **Jefes:** el día 10, sin haberlo derrotado, el Orangután vuelve con su vida normal (2205). Con las 4 piezas, el día 12 el Chimpancé sale más fuerte (4030 = 3100 × 1,3).
- **Final:** la ventana dice «♾️ Fin de la supervivencia: 9 días después del rescate» y da solo lo extra: +90 de Ámbar y +540 de XP del pase. No vuelve a contar la partida.

Lo que falta: una victoria de verdad (con la baliza), dos jugadores y el juego publicado.

#### 18.1 Una victoria de verdad (Isla, ▶ Jugar; haz antes una copia del perfil: 👑 Admin → 📋 Perfil → 📦 Hacer copia)

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

1. [ ] Pon a un jugador en English y al otro en Español. Que uno invite al otro al grupo desde la ventana Grupo, y que el invitado acepte.
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

Sin probar en Studio: la tanda se aprobó con la comprobación de `tools/strings.py`, stylua, selene y los tres `rojo build`. Hasta la I1e, en inglés quedan en español los nombres de `Data` (roles, habilidades, armas, objetos). Jaguar y Quetzal se escriben igual en los dos idiomas.

#### 22.1 En el Studio de Dunas (1 jugador, panel de pruebas para empezar solo)

1. [ ] Pon el ajuste de idioma en English y entra en Dunas.
   ✅ La ventana «Antes de la batalla» dice «🛡️ Team and role», «✅ Ready!», «Pick a team to start» y, al pulsar Listo, «⏳ Waiting… (cancel Ready)» y «Ready: 1/2». En el teléfono, las dos columnas siguen sin desplazamiento.
2. [ ] Elige equipo y empieza una partida de prueba.
   ✅ La línea de la fase dice «⚔️ The battle starts in …» y después llega el aviso «⚔️ Let the battle begin! …»; bajo el marcador, «🏠 At base»; la línea del altar, «⛩️ Altar in 0:45», y el cartel sobre el altar, lo mismo.
3. [ ] Roba la bandera rival, muere con ella y captúrala después.
   ✅ «🚩 You have the flag! …», «🏃 Stolen!», «⏳ Dropped 12», «Respawning in 4» y los avisos «🚩 … takes the 🦜 Quetzal flag!», «💥 … dropped …» y «🏆 … captures the … flag! 🐆 1 · 0 🦜».
4. [ ] Súbete a lo alto de la pirámide cuando se encienda el altar.
   ✅ «⛩️ The pyramid altar is lit! …», «⛩️ 🐆 taking the altar 40%», «⛩️ Take it!» en el cartel y, al tomarlo, «⛩️ Team 🐆 Jaguar takes the altar! …».
5. [ ] Termina la partida.
   ✅ Los resultados dicen «🧪 Test match», «Doesn't count for Amber or the leaderboard», «⛩️ Altars: 🐆 1 · 0 🦜», «Rematch starts in … s with whoever stays», «🔁 Rematch» y «🏝️ Back to Lobby», sin texto cortado. La consola, sin `[Strings] sin inglés`.
6. [ ] Vuelve a ponerlo en Español y repite el paso 1.
   ✅ Todo sale como antes de la I1d.

#### 22.2 En la Isla y el Lobby (1 jugador, en English)

1. [ ] En la Isla, usa el grito de guerra con monos cerca, marca presas con el cazador y usa el tótem y Resurgir con el médico.
   ✅ «⚔️ 3 monkeys are coming for you! …» (con uno, «A monkey is coming for you!»), «🏹 2 prey marked for … s», «⛑️ Healing totem for … s» y «⛑️ Resurgence! You healed and cleansed 1 player».
2. [ ] Dispara un arma a distancia sin munición.
   ✅ «You need … to use: …» (los nombres, en español hasta la I1e).
3. [ ] En el Lobby, mira los muñecos de práctica.
   ✅ Sobre la cabeza, «Practice dummy» y «Sparring dummy».

#### 22.3 Con 2 jugadores en Dunas (Prueba → Clientes y servidores → 2 jugadores)

1. [ ] Pon a uno en English y al otro en Español, uno en cada equipo, y que uno derribe al otro.
   ✅ «⚔️ 🐆 … knocks out 🦜 …» a uno y «⚔️ 🐆 … derriba a 🦜 …» al otro.
2. [ ] Que los dos elijan el mismo rol cuando el formato solo admite uno, y que uno intente entrar en un equipo lleno.
   ✅ «Your team already has too many of this role: …» / «Ya hay demasiados … en tu equipo» y «Team … is already full» / «El equipo … ya está completo», cada uno en su idioma.
3. [ ] Con el médico, lanza el escudo de hojas a tu compañero.
   ✅ Al que lo recibe, «🍃 … shields you for …» o «🍃 … te protege con un escudo de …»; al médico, «🍃 … shield on …» o «🍃 Escudo de … para …».

## Cuando termines

Si todo va bien, sigue con [LANZAMIENTO.md](LANZAMIENTO.md). Si algo falla, avísame con el número de paso y las líneas rojas de la Salida.
