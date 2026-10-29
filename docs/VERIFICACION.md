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
   ✅ A los 4 s sin recibir daño la vida empieza a subir sola y llega a 100.
3. [x] Dispara cada arma a los muñecos de 15, 50 y 120 studs. (Probado: aciertan todas apuntando con la cruz; falta mirar los colores en movimiento.)
   ✅ Dardos azul claro, banana amarilla con estela, red y bola morada en arco; el arpón no llega a 50 y el lanzadardos no llega a 120.
4. [ ] Con el rifle, mantén el clic derecho.
   ✅ La vista se acerca, el rifle se centra con el visor justo bajo la cruz, y vuelve al soltar; al cambiar de arma, también vuelve.
5. [x] «🏴‍☠️ Cambiar de facción» varias veces, con un arma en la mano.
   ✅ Las armas pasan de blanco y azul (guardianes) a latón y madera (piratas) sin cambiar de casilla, también la de primera persona.

#### 24.2 Con 2 jugadores (Test → Clientes y servidores con 2)

1. [ ] Disparaos con cada arma.
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

1. [ ] Publica el Lobby, el Laboratorio y Dunas (Dunas comparte `ArenaQueueService`), y guarda el place del Lobby (VERSION 16: el aviso de la E del cartel del Laboratorio pasó al poste derecho).
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

1. [ ] Pulsa Play con un jugador, detén la prueba y guarda el place con Archivo → Guardar (sin publicar). Si Rojo se desconecta, vuelve a conectarlo antes de Play.
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

1. [ ] Guarda el place con Archivo → Guardar (sin publicar), con `LabMap` en la versión 3. Si Rojo se desconecta, vuelve a conectarlo antes de Play.
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

1. [ ] Reconstruye el Lobby en modo edición con `require(game.ServerScriptService.Server.World.LobbyBuilder).build()` y guarda el place con Archivo → Guardar (sin publicar). Si Rojo se desconecta, vuelve a conectarlo antes de Play.
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

1. [ ] Publica los cuatro places a la vez (Lobby, Isla, Dunas y Laboratorio) con Archivo → Publicar en Roblox, porque el perfil pasa a la versión 13.
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

1. [ ] Empieza una partida («Empezar ya»), coge la bandera rival de verdad, corre y pulsa Alt izquierdo. (Probado el 28-10-2026 solo con el atributo `CarryingFlag` puesto a mano: no desliza ni gasta estamina; falta con la bandera real.)
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
5. [ ] Ejecuta `PlayerAnimationBuilder.build()` en modo edición, publica la secuencia «Slide» y enlázala como indica la skill `animaciones-roblox`. Después, juega y desliza.
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
3. [ ] Espera la recarga (1,2 s) y encadena 4 esquivas seguidas, mirando el campo de visión.
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

#### 34.5 El tiro a la cabeza (espera a V7, que es quien manda el campo `head`)

1. [ ] Recibe un tiro a la cabeza, con otro jugador o con un muñeco, y compara con un golpe normal del mismo daño.
   ✅ El destello sale más fuerte con la cabeza (opacidad 0,7 frente a 0,45). Hasta V7 nadie manda `head`, así que este paso no se puede probar todavía.

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

#### 35.4 Con 2 jugadores (*Test → Clientes y servidores*, con 2, en la Isla o en Dunas)

1. [ ] Uno anda y corre, y el otro lo mira desde su pantalla.
   ✅ El otro ve los ciclos propios de Walk y Run en ese personaje, al ritmo de la velocidad de su dueño, sin tirones.
2. [ ] Uno corre con un arma en la mano, y el otro lo mira.
   ✅ El otro ve RunArmed, con el brazo derecho sujetando el arma.

## 36. Lo que queda por probar de V7: detección PvP y cabeza (28-10-2026)

Solo está probado con el CI local (stylua, selene, `strings.py` y `rojo build`) y con la calculadora `Equilibrio` (sección 12): con un 30 % de aciertos a la cabeza, los duelos espejo de la arena bajan de 9,4 a 8,6 s (Cazador), de 9,8 a 9,0 s (Mago) y de 28,9 a 22,1 s (Médico), sin alertas nuevas. En el Laboratorio, con un 30 % de aciertos a la cabeza salen 2 alertas nuevas ("Laboratorio con cabezas"): Dardos 1,47 s a 15 studs y Rifle 1,23 s a 50 studs, bajo el mínimo de 1,5 s. Se dejan: son el mejor caso medio (el rifle sigue necesitando 2 aciertos, mínimo ~1 s) y se recalibran en V8 con el cargador y la dispersión. Nada de esto se ha probado en Play ni con dos jugadores. La dirección del disparo todavía no se valida contra la dispersión (eso es V8), así que no se prueba aquí. Empieza por 36.1.

#### 36.1 En Play, con un jugador, en Dunas y en el Laboratorio (haz antes una copia del perfil en `PlayerData_v1_backups`, y restáurala después)

1. [ ] En Dunas, dispara con el arco, el bastón y la cerbatana varias veces a un muñeco de práctica, y mira la Salida.
   ✅ Todos los disparos salen sin errores ni avisos en la consola, y el daño y los números son los de siempre.
2. [ ] En Dunas, dispara a un muñeco a unos 10 studs y mira de dónde sale cada proyectil.
   ✅ Sale de la punta del cañón o del Handle del arma, no de la cabeza ni de la cadera, y en menos de 0,12 s el proyectil se junta con su trayectoria real.
3. [ ] En el Laboratorio, en primera persona, dispara el rifle y el cañón de suero.
   ✅ El origen del disparo sale de la cámara (del centro de la mira), y el rifle y el cañón de suero siguen acertando donde apuntas.
4. [ ] Desde la consola del cliente, llama a `Remotes.UseWeapon:FireServer(dirección, punto, origen, hora)` con un origen a más de 5 studs de tu cabeza (por ejemplo, 20 studs hacia arriba) y dispara.
   ✅ El servidor no acepta el origen falso: el disparo sale de tu cabeza real y no aparece en el punto que mandaste. No hay error en la Salida.
5. [ ] En la Isla y en el Lobby, dispara el arma a distancia y pega con el arma cuerpo a cuerpo.
   ✅ Disparan y pegan igual que antes de V7, sin errores y sin números de «¡Cabeza!».

#### 36.2 En el Studio de Dunas o del Laboratorio, con 2 jugadores (*Test → Clientes y servidores*, con 2)

1. [ ] A dispara de frente a la cabeza de B con un arma a distancia, sin moverse B.
   ✅ En la pantalla de A y en la de B sale «¡Cabeza!» con el número ×1,5 y estilo de crítico. El destello de los bordes de B (V5) es más fuerte que con un golpe normal del mismo daño.
2. [ ] A dispara al cuerpo de B con el mismo arma, y después a la cabeza.
   ✅ El cuerpo hace el daño normal, sin «¡Cabeza!». La cabeza hace una vez y media ese daño.
3. [ ] A dispara a la cabeza de B con un golpe crítico seguro (pon el atributo `DebugAlwaysCrit` en `workspace`).
   ✅ El daño es ×1,5 y no ×2,025: no se multiplican el crítico y la cabeza. El número sale grande y con «¡Cabeza!».
4. [ ] En Dunas, A dispara con la cerbatana a la cabeza de B.
   ✅ Cuenta como cabeza (×1,5 y «¡Cabeza!») y además entra el veneno morado como siempre.
5. [ ] En el Laboratorio, A dispara el rifle a la cabeza de B.
   ✅ Cuenta como cabeza (×1,5 y «¡Cabeza!»).
6. [ ] En el Laboratorio, A dispara el cañón de suero a la cabeza de B.
   ✅ No sale «¡Cabeza!» ni hay ×1,5: el cañón de suero no tiene cabeza.
7. [ ] Con un retraso simulado de 100–150 ms (*Network Settings*), B se mueve de lado mientras A le dispara.
   ✅ B recibe el disparo donde lo veía A en su pantalla, y no por detrás de una pared.
8. [ ] Con el mismo retraso, A dispara desde detrás de una cobertura (una roca o un muro) a B, que está tras otra.
   ✅ El disparo no atraviesa la cobertura para dar en la cabeza de B.
9. [ ] B bloquea o hace parry a un disparo de A dirigido a la cabeza, y después a un disparo al cuerpo.
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

1. [ ] En el Laboratorio, dispara el rifle o los dardos sin parar y mira la mira, con «Mira dinámica» en Sí y después en No.
   ✅ Hoy no se abre ni tiene anillo de recarga: `setSpread` y `setCooldown` aún no los llama ningún arma. Este paso se prueba en V8.

## 38. Lo que queda por probar de V8: cargador, recarga, automático y mira dinámica (28-10-2026)

Probado en Play, con un jugador, en el Laboratorio (28-10-2026): el cargador y los atributos `LabAmmo` y `ReloadingUntil`; la recarga automática al vaciarse y la de `LabReload`; el relleno al reaparecer y al cambiar de arma; el contador «N / M»; el disparo automático con el clic mantenido (12 balas en 1,5 s, ritmo ≈0,125 s por bala). La tecla R no llegó a `ContextActionService` con el MCP, así que se prueba a mano. Solo están probados también el CI local (stylua, selene, `strings.py` y `rojo build`) y la calculadora `Equilibrio` (sección 12). Con cargador y dispersión siguen 2 alertas con cabezas (Dardos 1,47 s a 15 studs, Rifle 1,23 s a 50, mínimo 1,5 s), solo con un 30 % de aciertos a la cabeza y puntería perfecta: es decisión de diseño, no se han cambiado daños. Con el rifle en movimiento acierta un 30 % a 50 studs y un 5 % a 120. Empieza por 38.1.

#### 38.1 En PC, en el Laboratorio, con ratón y teclado (un jugador)

1. [ ] Con un arma con cargador en la mano y el cargador a medias, pulsa R.
   ✅ Empieza la recarga: sale la barra bajo la mira con «Recargando… N,N», se llena al acabar y no sale ningún error en la Salida.
2. [ ] Con el cargador lleno, pulsa R.
   ✅ No empieza ninguna recarga ni cambia el contador.
3. [ ] Con el rifle, mantén el clic derecho para acercar la vista y dispara quieto y después corriendo.
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

1. [ ] A corre hacia B a 50 studs y dispara el rifle 20 veces seguidas, con B quieto.
   ✅ Acierta cerca del 30 % de los tiros, como predice `Equilibrio` (sección 12), y no el 100 %. Al vaciar el cargador, A recarga sola.
2. [ ] A dispara el rifle quieto a B a 50 studs, 5 tiros seguidos.
   ✅ Los 5 salen al punto (la dispersión quieta es 0 y el primer disparo es exacto).
3. [ ] A dispara el rifle con zoom (clic derecho) mientras corre hacia B a 50 studs.
   ✅ Sale sin dispersión y acierta como con el arma quieta. Si en el servidor el tiro no se acepta por la dirección, avísame con el número de paso.
4. [ ] A mantiene el zoom (clic derecho) mientras dispara dos tiros corriendo, y después suelta el zoom y dispara otros dos.
   ✅ Los dos tiros con zoom salen sin dispersión, y los dos sin zoom salen con la dispersión de correr. El servidor usa el `zoomed` que manda el cliente en cada tiro.
5. [ ] Con 150 ms de latencia en A (*Network Settings*), pulsa R y dispara justo cuando acaba la barra.
   ✅ Puede rechazarse un tiro, sin daño y sin error en la Salida. Al terminar, el contador y la barra de A coinciden con el servidor, sin balas de más.
6. [ ] Mide el TTK del rifle y de los dardos de A a B a 15 y 50 studs (quieto y corriendo).
   ✅ Los tiempos son del orden de lo que predice `Equilibrio` (sección 12). Si el TTK baja de 1,5 s solo con tiros al cuerpo, avísame: sería una alerta nueva.

## 39. Lo que queda por probar de V9: poses, fogonazo, retroceso y sonidos del Laboratorio (28-10-2026)

Probado en Play, con un jugador, en el Laboratorio (28-10-2026): `Config`, `Sounds` y `WeaponAnimations` cargan; el `Muzzle` existe en la vista; el fogonazo dura 0,16–0,28 s y no deja luces; el retroceso del rifle va de −3,77 a −3,23 y vuelve a −3,75 en 0,43 s; la recarga baja unos 0,47 studs, vuelve y rellena el cargador; sacar el arma sube 0,79 studs en 0,33 s; y no sale ningún error de V9 en la consola. Las tres poses nuevas se vieron en tira en el Studio de la Isla y se leen bien. Lo que no se ha probado: las poses dentro del Laboratorio (sus ids están vacíos hasta publicarlas), el fogonazo y la pose de otro jugador, el teléfono y los sonidos definitivos. Los sonidos son provisionales (ids de serie de Roblox; el rifle y el cañón comparten BOOM, y la recarga y el cargador vacío comparten CLICK). Empieza por 39.1.

#### 39.1 En el Studio de la Isla, con el dueño del juego (publicar las tres poses)

1. [ ] Ejecuta `WeaponAnimationBuilder.build()` en modo edición (con un `require` limpio, no el de la caché). Después haz clic derecho sobre `ReplicatedStorage.WeaponAnimations.LabRifle`, `LabHarpoon` y `LabCannon` > *Save to Roblox*, con el dueño del juego. Pega los tres ids en `Data/WeaponAnimations` y guarda el place de la Isla.
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

1. [ ] B se queda quieto a 20 studs de A y mira a A, mientras A dispara cada arma (dardos, rifle, arpón y cañón).
   ✅ B ve el fogonazo en la boca del arma de A: cian con los dardos, amarillo con humo con el rifle, bocanada beige con el arpón y goterón morado con el cañón. B también ve la pose de disparo del arma de A (39.1.2).
2. [ ] Con B quieto, A dispara el rifle y después el cañón a 50 studs y luego a 120 studs.
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

## Cuando termines

Si todo va bien, sigue con [LANZAMIENTO.md](LANZAMIENTO.md). Si algo falla, avísame con el número de paso y las líneas rojas de la Salida.
