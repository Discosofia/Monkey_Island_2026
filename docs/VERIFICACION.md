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
| Elegir arma o herramienta | 1–5 (machete, honda, hacha, pico, martillo) |
| Usar arma o herramienta | Clic |
| Esquivar | Q |
| Correr | Mayús |
| Comer | C |
| Curar | H |
| Beber | F (junto al agua) |
| Bolsa | B |
| Diario de campo | J |
| Habilidad del rol | G |
| Silenciar música | M |
| Construir con el martillo | Clic coloca · R gira · T cambia de pieza · X quita |

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
2. [ ] Pon **Estacas** justo en el hueco del portón.
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
   ✅ A los **10 s** de estar caído o como Espíritu de noche, la partida termina.

## 2.8 Guardado de datos

1. [ ] Con el acceso a las API activado: en la Isla, termina con **💀 Terminar: derrota**.
   ✅ Aviso **"✨ +N de Ámbar guardado"**.
   ⚠️ Si la Salida dice *"juega con datos temporales"*, falta el acceso a las API (paso 0).
2. [ ] Para (■), abre el place **Lobby** y dale a ▶.
   ✅ Arriba se ve **"✨ Ámbar: N"** con lo que ganaste.

## 3.1 Lobby: rol, talentos, tienda y grupos

En el place **Lobby**, con ▶:

1. [ ] Pestaña **Rol**: elige **Médico**.
   ✅ El botón pasa a "Elegido".
2. [ ] En 🛠️, pulsa **⭐ +300 XP del rol**. Pestaña **Talentos**.
   ✅ "3 puntos libres": aprende un rango de cualquier talento.
3. [ ] En 🛠️, pulsa **✨ +500 Ámbar**. Pestaña **Tienda**: compra **Corazón fuerte** y **Kit de náufrago**.
   ✅ El Ámbar baja y sube el rango (1/3).
4. [ ] **Grupo** (con 2 jugadores): el jugador 1 invita al 2; al 2 le sale **"te invita a su grupo"** y pulsa Aceptar.
   ✅ Los dos ven **"👥 Grupo: …"**. El viaje en grupo solo se puede probar publicado (paso 6.4 final).

## 3.2 Roles en la Isla

El rol elegido en el Lobby llega a la Isla gracias al guardado (paso 0). Para probar cada rol: elígelo en el Lobby, para (■) y dale a ▶ en la Isla.

1. [ ] Al entrar sale **"⛑️ Juegas como Médico: …"** y bajo las barras **"Ungüento en área (G): lista"**.
2. [ ] **Médico:** pulsa **G** herido.
   ✅ Onda verde, te curas y empieza la cuenta atrás de la habilidad.
   - Con 2 jugadores ves la **vida del otro** sobre su cabeza.
   - Reanimas más rápido: el aviso dura 2 s en vez de 4.
3. [ ] **Cazador:** pulsa **G** cerca de monos.
   ✅ Contorno rojo en los monos y "N presas marcadas". La honda les hace más daño.
4. [ ] **Recolector:** los arbustos se recogen más rápido y dan +1. Pulsa **G** y tala un árbol.
   ✅ "¡Recolección frenética!": el hacha avanza el doble.

## 3.3 Talentos y mejoras en la Isla

1. [ ] Con **Corazón fuerte** comprado, al entrar a la Isla tienes **110** de vida máxima (se nota en la barra de vida de Roblox).
2. [ ] Con **Kit de náufrago**, empiezas con **5 de madera, piedra y fibra** (mira la Bolsa con B).

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
   ✅ Diario de campo: las especies que derrotaste salen con descripción y botín; las demás, "???".
4. [ ] Pulsa **B**.
   ✅ Los materiales raros salen en **color** según su rareza (verde, azul, morado, dorado).
5. [ ] En la **forja**, con 🛠️ +50 de todo: **Honda de liana, Hacha de hueso, Pico de hueso, Garrote de colmillo grande y Armadura de plata**.
   ✅ Cada mejora sustituye a la herramienta anterior.
6. [ ] En la Salida, cada 2 minutos sale **"[Rendimiento] … streaming activado/DESACTIVADO"**.

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
3. [ ] Encuéntralo: es una bola blanca que brilla. Mantén pulsado **"Recoger"**.
   ✅ Lo llevas sobre la cabeza, vas **más lento**, tienes la etiqueta **⚔️ PvP** y los monos cercanos van a por ti.
4. [ ] Deja que te tumben.
   ✅ El huevo **cae al suelo** y se puede volver a recoger.
5. [ ] Llévalo al nido.
   ✅ "¡El huevo está en el nido! Defendedlo 150 s", llegan monos y bajo el reloj sale la cuenta atrás.
6. [ ] Espera a que eclosione.
   ✅ "🐣 ¡Ha nacido tu mascota: …!". Con guardado, la verás en el Lobby (pestaña **Mascotas**).

## 5.3 Mascotas

1. [ ] **En el Lobby:** pestaña **Mascotas**; con 🛠️ **🥚 Mascota al azar** consigues una sin jugar. Pulsa **Llevar**.
   ✅ Una bolita con su emoji te sigue flotando.
2. [ ] **En la Isla:** 🛠️ **🐾 Mascota al azar** pone una mascota de prueba.
   - **Combate** (jaguarundí, ocelote, X-7): ✅ los monos cercanos reciben daño cada 2 s.
   - **Rastreo** (tucán, guacamaya): ✅ cada 5 s ves contornos amarillos en los monos cercanos.
   - **Curación** (rana): ✅ recuperas vida sola.
   - Las de apoyo y carga dan sus ventajas cuando se llevan desde el Lobby.

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
   ✅ PvP activado a la fuerza y botín: metal de naufragio, vendas, comida…

## 5.5 Clima y erupción

1. [ ] Pulsa **🌧️ Lluvia** y sal del Basecamp.
   ✅ Caen gotas, el cielo se oscurece un poco y la **sed sube** sola.
2. [ ] Pulsa **⛈️ Tormenta**.
   ✅ Más lluvia y, cada ~20 s, un **rayo** con círculo de aviso y destello.
3. [ ] Pulsa **🌋 Erupción** estando cerca del volcán.
   ✅ Aviso, tono rojizo, y caen **bolas de lava** con círculo rojo de aviso durante 1 minuto.

## 6.1 Baliza y victoria

1. [ ] Con 🛠️ +50 de todo (incluye metal de naufragio), construye la **📡 Baliza de rescate** en el núcleo.
   ✅ Bajo el reloj: "📡 Baliza construida · piezas 0/4".
2. [ ] Pulsa **📡 4 piezas + baliza sin espera**. De **día**, mantén **"Encender baliza"** 3 s.
   ✅ La luz de arriba se pone **roja** y sale "¡… ha encendido la baliza!".
3. [ ] Pulsa **⏩ Saltar fase** (noche).
   ✅ "¡LA GRAN TROPA!": **5 oleadas** del doble de tamaño.
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

1. [ ] Cada aviso suena con un **"ping"** suave.
2. [ ] Pon un ID de música en `src/shared/Data/Sounds.luau` (por ejemplo, en `Day`).
   ✅ Suena con fundido; cambia de noche, en el asedio y cerca de un jefe. **M** la silencia.

---

## Cuando termines

Si todo va bien, sigue con [LANZAMIENTO.md](LANZAMIENTO.md). Si algo falla, avísame con el número de paso y las líneas rojas de la Salida.
