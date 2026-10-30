# Prompts para las portadas e iconos

Cuatro imágenes: **principal** (miniatura 16:9), **icono** (1:1), **Dunas** y **Laboratorio** (16:9).
Cada una usa los modelos reales del juego como referencia: las capturas de `ref/` son lo que se adjunta a
Gemini junto al prompt (los prompts están en inglés porque así los entiende mejor).

## Cómo se usa

1. En Gemini, adjunta **las imágenes que dice cada prompt** (hasta 10 por petición; si no caben, quita las
   de espalda) y pega el prompt completo: primero el bloque de estilo y después el de la imagen.
2. Pide **sin texto**: el título lo pone `titulo.py` encima, para que salga entero y bien escrito.
3. Revisa la lista "Qué comprobar" de la imagen. Si una pieza sale inventada, repite con una frase como:
   *"The archer's bow must be exactly the black obsidian bow with gold bands from the reference, not a
   wooden bow."* y vuelve a adjuntar la ficha de esa pieza.
4. Guarda el resultado en `art/portada/` y ponle el título:
   `python titulo.py principal fondo.png` (o `icono`, `dunas`, `laboratorio`).
   Saca el PNG final a `portada-<preset>-<tamaño>.png`.

Las capturas de `ref/` son del juego en Studio, con luz plana de estudio: cuentan para la **forma y los
colores** de cada pieza, no para la iluminación.

## Bloque de estilo (va al principio de todos los prompts)

```
Create a polished cartoon illustration for a Roblox game thumbnail, in the style of the attached
example image: bold clean outlines, saturated colors, dramatic rim lighting, soft glow on magic and lava,
slightly exaggerated heroic poses. The characters are blocky Roblox-style figures with voxel-like shapes
(chunky square forms, flat color tones) — keep that blocky look, do not make them realistic or smooth.
Reproduce every weapon, armor piece, shoulder pauldron, crown and back ornament EXACTLY as shown in the
reference screenshots: same shapes, same colors, same materials. Do not invent new gear and do not
swap items between characters. No text, no logos, no watermarks, no UI.
```

## 1. Principal — 1920×1080

**Adjunta:** `guerrero-frente`, `cazador-frente`, `mago-frente`, `medico-frente`, `jefe-gorila-de-ceniza-frente`,
`jefe-gorila-albino-frente`, `jefe-chimpance-caudillo-frente`, `jefe-orangutan-del-manglar-frente`, y la
imagen de ejemplo de la portada (la que se quiere imitar).

```
[style block]

16:9 landscape. Composition: in the FRONT row, four heroes standing side by side in confident poses,
facing the viewer, roughly 3/4 of the image height. From left to right:

1. WARRIOR — "Titan King of the Gorillas" mythic armor: carved grey stone (132,138,122) plated with gold
   (232,182,64), royal-red (138,34,34) breastplate with gold studs and a stone gorilla-face medallion on
   the chest, jade-green (44,158,126) gems, a gold crown with a golden sun-ring halo behind the head,
   large gold-rimmed shoulder pauldrons with small stone idols on top. Weapon: a huge war mace whose head
   is a stone gorilla fist with gold knuckles and jade inlays, red-lacquered shaft, held up over the
   right shoulder.
2. HUNTER (slightly forward, center-left) — volcanic armor "Ember Mantle": black basalt and obsidian
   (62,58,60 / 30,24,38) with glowing lava-orange (255,110,30) edges, big square shoulder pauldrons with
   orange rims and black obsidian spikes, an obsidian quiver full of burning arrows on the back. Weapon:
   a tall black obsidian recurve bow with spiked limbs, gold bands and a glowing yellow string, held
   upright in front.
3. MAGE (center-right) — Season 1 "Blue Fire Invoker": charcoal-black robe, silver pumice-grey mantle and
   shoulder plates, cyan blue flames burning on both shoulders, a glowing cyan rune medallion on the
   chest with gold dots, small sulfur-yellow crystal spikes. Weapon: a staff with a black-and-white
   banded shaft and a sulfur-yellow crystal head wrapped in a cyan ring and a blue flame, raised high.
4. MEDIC (right) — "Ceiba of Life" mythic: tan bark-and-linen tunic (140,150,122), a big collar and
   shoulder fans of green leaves with pink orchid flowers, jade-green gem on the chest, healing green glow.
   Weapon: a vine-wrapped blowgun with a flowered tip, held up.

BEHIND them, in the middle ground, the four island bosses as huge blocky gorillas and apes, towering over
the heroes, glaring at the viewer:
- far left: ORANGUTAN of the Mangrove — rust-orange body (150,60,22), dark brown face with big cheek
  pads and long dark mane, glowing yellow eyes, a cyan gem on the throat, green vines and moss on the
  shoulders;
- left-center: ALBINO GORILLA — white-grey fur, mauve face with red glowing eyes and a dark horned brow,
  tall dark-red ruby crystal spikes along the back, thin glowing red veins on the arms;
- CENTER and the biggest: ASH GORILLA — charcoal-black fur with grey ash patches, volcanic rock plates,
  lava-orange face (255,110,30), hands and feet, fire eyes, fanged mouth, lava cracks, embers;
- far right: CHIEF CHIMPANZEE — near-black fur, pink face with yellow eyes and a red war-paint band, a
  feather headdress (orange, yellow, blue feathers) on a beaded wooden band, a bead-and-tooth necklace.

BACKGROUND: a huge erupting volcano right behind the Ash Gorilla, glowing lava rivers and a tall fiery
eruption column with dark smoke, lava bombs falling as burning meteors, several jagged white-blue
lightning bolts striking down from a violent night sky (deep purple #14062e at the top to magenta to
fiery orange at the horizon), dark jungle palm silhouettes and big leaves in the bottom corners.

IMPORTANT: leave the top-left area (about x 0–45%, y 3–45% of the image) free of characters, as calm
sky and smoke, because the game title will be added there later. Nothing may overlap that area.
```

**Qué comprobar:** las armas coinciden con las fichas (mazo de puño de piedra, arco de obsidiana con cuerda
amarilla, bastón con cristal de azufre y fuego azul, cerbatana con flor); cada jefe tiene su rasgo (cristales
rubí, penacho de plumas, gema cian en la garganta, cara de lava); la esquina superior izquierda está libre; el
fuego azul es solo del Mago y el verde solo del Médico (verde = curación; el daño y la lava, naranja).

## 2. Icono — 512×512 (1:1)

**Adjunta:** `guerrero-frente`, `jefe-gorila-de-ceniza-frente` y la portada principal ya hecha como guía
de color.

```
[style block]

Square 1:1 icon. One hero and one boss, very readable at small size, strong silhouette, high contrast.
The WARRIOR in "Titan King of the Gorillas" mythic armor (carved grey stone with gold trim, red
breastplate, gold crown with a golden sun-ring behind the head, jade gems) holds the huge stone-gorilla-
fist mace over the shoulder, in the lower-left of the square, big, about 55% of the height.
Behind him, towering to the right, the ASH GORILLA boss (charcoal-black with lava-orange face, hands and
feet, lava cracks, fire eyes). Behind both, an erupting volcano and one big white-blue lightning bolt in a
purple-to-orange night sky, lava bombs falling.
Keep the bottom 35% of the image darker and simple (dark ground and shadows, no important details), because
the game title will be added there. No text.
```

**Qué comprobar:** se reconoce a 128 px (la silueta del mazo y la cabeza del gorila); el tercio inferior
está limpio y oscuro para el título.

## 3. Isla de Dunas (PvP) — 1920×1080

**Adjunta:** `fondo-dunas-arena`, `dunas-base-jaguar`, `dunas-base-quetzal`, y las fichas frontales de los
cuatro roles.

```
[style block]

16:9 landscape, bright desert afternoon (no volcano, no night). Setting: a sunlit sandstone canyon arena
with a stepped pyramid in the center, orange-red cliffs, small cacti and tall stone totem pillars, exactly
like the attached arena screenshot. Two team bases at opposite ends: on the LEFT the JAGUAR base — tan
adobe wall with an orange band, orange banners with a white diamond, and a big blocky orange jaguar
face with yellow eyes on top; on the RIGHT the QUETZAL base — the same wall with a cyan-blue band, blue
banners with a white diamond, and a blocky green-and-blue quetzal bird with a red chest and yellow beak.
Capture-the-flag battle: an orange flag and a blue flag planted in front of each base.

Foreground: two teams of two heroes charging at each other, mid-action, with team color accents (orange
sashes and banners for Jaguar, cyan-blue for Quetzal):
- JAGUAR team (left): the WARRIOR in "Titan King" mythic stone-and-gold armor with the stone-gorilla-fist
  mace raised, and the HUNTER in black obsidian volcanic armor with lava-orange edges drawing the
  obsidian bow with a glowing yellow string.
- QUETZAL team (right): the MAGE in charcoal robe and silver pumice mantle with cyan fire on the
  shoulders casting from the sulfur-crystal staff, and the MEDIC in the leafy bark "Ceiba of Life" outfit
  with pink flowers and the vine blowgun.
Reproduce each character's gear exactly as in the reference screenshots.
Leave the top-left area (x 0–45%, y 3–45%) free (sky and canyon wall) for the game title.
```

**Qué comprobar:** los dos tótems (jaguar naranja, quetzal verde y azul) se distinguen; los equipos se
reconocen por el color (naranja contra azul) y no por la armadura; sin volcán; zona del título libre.

## 4. Laboratorio en ruinas (PvP) — 1920×1080

**Adjunta:** `fondo-lab-central`, `lab-barco-pirata`, `lab-lanzadardos-piratas-guardianes`,
`lab-rifle-platanos-piratas-guardianes`, `lab-arpon-piratas-guardianes`, `lab-canon-acido-piratas-guardianes`.

```
[style block]

16:9 landscape, moody blue-grey misty daylight. Setting: ruined overgrown laboratory in a flooded city —
tall blue-grey skyscrapers with stripes fading into fog, a low concrete lab compound with vines hanging
from its walls, and a small pirate ship with a black sail and glowing yellow lights docked at the edge of
the water, like the attached screenshots.

Foreground: a shooter showdown between two teams of blocky Roblox-style characters in plain avatars
(no fantasy armor), 2 per team, aiming their weapons at each other:
- PIRATES (left, gold accents #eac250, dark wood, rope, bandanas): a dart gun and a banana rifle in
  olive-gold metal with dark-wood grips, exactly as the "Pirates" versions in the weapon references.
- GUARDIANS (right, white lab coats with blue #2873d7 stripes and glowing cyan details): a net harpoon
  and an acid cannon (with a purple acid barrel) in white-and-blue, exactly as the "Guardians" versions
  in the weapon references.
Show the glowing cyan tranquilizer darts, a banana bullet and a flying net mid-air to give motion.
Do not use green, purple or red for the teams (purple only inside the acid barrel).
Leave the top-left area (x 0–45%, y 3–45%) free for the game title.
```

**Qué comprobar:** las armas coinciden con las capturas de su bando (dorado y madera contra blanco y
azul); no hay armaduras de fantasía ni volcán; el barco y los rascacielos están en el fondo; zona del
título libre.

## Cuando se cambie el equipo del juego

Las capturas de `ref/` salen de `src/island/tools/Portada.luau` (en el Studio de la Isla, en modo edición:
`Portada.ficha("Guerrero")` y `Portada.vista("frente")`). El equipo de cada rol está en la tabla `EQUIPOS`
del archivo; si cambias un traje o un arma, cambia ahí el id, vuelve a capturar la ficha y actualiza la
descripción del prompt. Las armas del Laboratorio y los fondos de Dunas y del Laboratorio se capturaron a mano
en sus Studios (sin herramienta).
