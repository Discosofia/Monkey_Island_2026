# Verificación paso a paso (entregas 2.3 a 6.5)

Sigue los bloques en orden. Cada bloque dice **qué hacer**, **qué debe pasar ✅** y **qué hacer si falla ⚠️**.
Marca cada casilla al comprobarla.

> **Cómo avisarme de un fallo:** dime el número del paso (por ejemplo "5.2, paso 4"), qué esperabas y qué pasó, y copia las líneas en **rojo** de la ventana **Salida** de Studio (Vista → Salida). Una captura ayuda mucho.

---

## 0. Preparación (una sola vez)

- [ ] **Actualizar el código:** en VS Code, *Pull* de la rama `claude/monkey-island-roblox-design-ro2mg4` (o en GitHub Desktop, *Fetch origin* → *Pull*).
- [ ] **Reiniciar Rojo:** cierra los dos `rojo serve` y vuelve a lanzarlos:
  - `rojo serve lobby.project.json` (puerto 34872)
  - `rojo serve island.project.json` (puerto 34873)
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
| Correr | Mayús |
| Comer | G |
| Curar | H |
| Beber | F (junto al agua) |
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

1. [ ] Pestaña **Rol**: salen **Guerrero, Cazador, Mago y Médico**, cada uno con su pasiva y sus 4 habilidades. Elige **Médico**.
   ✅ El botón pasa a "Elegido".
   - Si tenías XP con el antiguo **Recolector**, ahora es del **Mago** y sus puntos de talento están libres.
2. [ ] En 🛠️, pulsa **⭐ +300 XP del rol**. Pestaña **Talentos**.
   ✅ "3 puntos libres": aprende un rango de cualquier talento.
3. [ ] En 🛠️, pulsa **✨ +500 Ámbar**. Pestaña **Tienda**: compra **Corazón fuerte** y **Kit de náufrago**.
   ✅ El Ámbar baja y sube el rango (1/3).
4. [ ] **Grupo** (con 2 jugadores): el jugador 1 invita al 2; al 2 le sale **"te invita a su grupo"** y pulsa Aceptar.
   ✅ Los dos ven **"👥 Grupo: …"**. El viaje en grupo solo se puede probar publicado (paso 6.4 final).

## 3.5 Lobby del naufragio

En el place **Lobby**, con ▶ (se construye solo la primera vez; ver [MAPA.md](MAPA.md), Lobby):

1. [ ] Apareces en la arena junto al naufragio, con luz de atardecer.
   ✅ A la izquierda, el carguero **«Esperanza»** encallado y escorado: casco de acero azul y rojo con un **boquete** por el que se ve la bodega (cajas, bidones, bananas y una luz de emergencia), castillo blanco con puente de mando, chimenea y radar, contenedores de colores en cubierta (uno a punto de caer por la borda) y una grúa amarilla. Al fondo, la **isla con el volcán humeando** y ríos de lava.
2. [ ] Pulsa **📜 Ocultar menú** (abajo a la izquierda) y pasea.
   ✅ El panel se pliega y vuelve con **📜 Abrir menú**.
3. [ ] Sube por la **pasarela metálica** a la cubierta y entra por el boquete a la bodega.
   ✅ Se puede andar por la cubierta entre los contenedores, subir por la escalera exterior al techo del primer piso del castillo y entrar en la bodega.
4. [ ] Mira el campamento: hoguera con bancos, tienda de lona azul, contenedores varados (uno abierto con cajas PRIMAL), el ancla con su cadena hasta la proa, el salvavidas y la **Bitácora del capitán** (el tablero junto a la llegada).
   ✅ La bitácora se lee y cuenta el lore (tormenta, la isla, el Proyecto PRIMAL, la lancha).
5. [ ] Ve a la **lancha de rescate** de la orilla (cartel "🚤 A LA ISLA →") y mantén **"Zarpar hacia la isla"**.
   ✅ Hace lo mismo que el botón **Ir a la Isla** (en Studio no viaja; publicado sí).
6. [ ] Intenta alejarte nadando.
   ✅ Un muro invisible te frena a unos 160 studs.

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
   ✅ Solo salen las del rol que llevas; cada una cambia el modelo y el daño del arma.
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
2. [ ] Pulsa **🥚 Huevo**.
   ✅ "¡Ha aparecido un huevo misterioso hacia el …!" y bajo el reloj "🥚 Hay un huevo…".
3. [ ] Encuéntralo: es un **huevo ovalado** color crema con motas turquesa que brilla. Mantén pulsado **"Recoger"**.
   ✅ Lo llevas sobre la cabeza, vas **más lento**, tienes la etiqueta **⚔️ PvP** y los monos cercanos van a por ti.
4. [ ] Deja que te tumben.
   ✅ El huevo **cae al suelo** y se puede volver a recoger.
5. [ ] Llévalo al nido.
   ✅ "¡El huevo está en el nido! Defendedlo 150 s", el huevo queda **en el centro del nido, apoyado en la paja**, llegan monos y bajo el reloj sale la cuenta atrás.
6. [ ] Espera a que eclosione (o pulsa **🐣 Eclosionar ya**).
   ✅ La cáscara **revienta en pedazos** con un destello y "🐣 ¡Ha nacido tu mascota: … Ya te acompaña". La mascota **te sigue al instante** y sus ventajas ya cuentan. Si ya llevabas una más rara, se queda la tuya y la nueva te espera en el Lobby.

## 5.3 Mascotas

1. [ ] **En el Lobby:** pestaña **Mascotas**; con 🛠️ **🥚 Mascota al azar** consigues una sin jugar. Pulsa **Llevar**.
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
2. [ ] En el Lobby, pestaña **Ranking**.
   ✅ Se actualiza cada **5 minutos**: "1. TuNombre — N días".

## 6.3 Analítica

1. [ ] Tras jugar el juego **publicado**, ve a *Creator Hub → tu experiencia → Analítica* (tarda unas horas en verse).
   ✅ Embudo de incorporación con los pasos del tutorial, economía del Ámbar y eventos `MatchVictory`/`MatchDefeat`.

## 6.4 Estilo (cosméticos) y servidores privados

1. [ ] En el Lobby (Studio), pestaña **Estilo**. En Studio los cosméticos son gratis para probar: **Equipar** la Estela dorada, el Título y el Aura.
   ✅ Se ven en tu personaje en el Lobby y en la Isla.
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
   - Vuelve al Lobby: en la pestaña **Ajustes** sigue la disposición elegida.
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

---

## Cuando termines

Si todo va bien, sigue con [LANZAMIENTO.md](LANZAMIENTO.md). Si algo falla, avísame con el número de paso y las líneas rojas de la Salida.
