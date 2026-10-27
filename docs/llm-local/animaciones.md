# Animaciones (resumen de la skill animaciones-roblox)

<!-- Fuente: .claude/skills/animaciones-roblox/SKILL.md, 26-10-2026. Detalles: references/sistemas-de-animacion.md y docs/ANIMACIONES.md (recetas por acción). -->

## Antes de empezar

- Las animaciones de monos y armas se trabajan en el place de la **Isla**, en Edit.
- Biblioteca `Anim`: manda con `execute_luau` el contenido de `.claude/skills/animaciones-roblox/scripts/animacion.luau` terminado en `_G.Anim = Anim`. Después basta `local Anim = _G.Anim`.
- **Ficha:**
  - qué rig: mono (y especie), jefe, R15 del jugador o mascota;
  - qué acción;
  - si es nueva o un retoque;
  - duración y si va en bucle;
  - el momento fuerte: las acciones duran 0,3–0,8 s y el golpe llega pronto, a los 0,15–0,25 s;
  - qué piezas se mueven y qué no debe cambiar.
- Un cambio en `Default` cambia a **todos** los monos y jefes. Lo propio de una especie va en `Overrides`.

## Formato spec

```lua
local SPEC = {
	name = "Attack", loop = false, priority = "Action",
	easing = "Cubic", direction = "Out",
	keyframes = {
		{ t = 0, reposo = true },
		{ t = 0.12, ["Right Arm"] = { -40, 0, 0 }, Head = { 10, 0, 0 } },
		{ t = 0.22, ["Right Arm"] = { 80, 0, 0 }, Head = { -10, 0, 0 }, marcador = "Golpe" },
		{ t = 0.4, reposo = true },
	},
}
```

- Las poses son `{x, y, z}` en grados de `CFrame.Angles`. Un X positivo lleva el brazo hacia delante y arriba; en la cabeza, X positivo la echa atrás.
- Un fotograma vacío **no** mantiene la pose: para una pausa, repite la pose entera.
- `reposo = true` pone a 0 las piezas que no nombras.
- Easings válidos: `Linear`, `Constant`, `Cubic`, `Elastic`, `Bounce` y `CubicV2`. No existen `Sine` ni `Quad`.
- Los monos usan `Right Arm`, `Torso` y `Head`; el R15 usa `RightUpperArm`… Los simios y el gibón no tienen `Tail`.

## Revisar sin ver

```lua
local rig = Anim.monkeyRig("Gorila")
local ks = Anim.build(SPEC, rig)
return Anim.measure(rig, ks)      -- altura de cada extremidad por instante
```

- `Anim.measure`: un valor negativo es un pie o nudillo que se clava. Hasta -0,15 vale; más, corrígelo. Mide también la altura del golpe y la cola.
- `Anim.show(rig, ks)` monta la tira en `Workspace._VistaAnimacion` y devuelve `avisos`: bucle que no cierra, acción que no empieza en reposo, piezas que no existen. Lee los avisos y pide al usuario que mire la tira.
- Revisa la animación en dos especies si es de `Default`.

## Cerrar

1. `Anim.save(ks, "RigMono")` la guarda en `ServerStorage.RBX_ANIMSAVES`.
2. **La publica el usuario:** clic derecho → *Save to Roblox*, con el mismo dueño que el juego. Después te pasa el id.
3. Pega el id en `src/shared/Data/MonkeyAnimations.luau` o en `Data/WeaponAnimations.luau`.
4. El spec final va a git, en `src/island/tools/MonkeyAnimationSpecs/<lote>.luau`. Las armas viven en `WeaponAnimationBuilder`.
5. `Anim.clear()` cuando el usuario apruebe. Recuérdale que guarde el place.

## Monturas

- Las specs van en `MonkeyAnimationSpecs/Monturas.luau`, con `parents` (la jerarquía de huesos de la montura). Se generan con `MonkeyAnimationBuilder.build("Monturas")` y se enlazan en `Data/Mounts` (`Run`, `Idle`, `Gesture`, `Jump`).
- El gesto (escupir, rugir) lleva un marcador con el nombre de `gesture.marker`: ahí sale el efecto.
- En el galope, mide con `Anim.measure`: un lomo que cabecea mucho clava las manos en el suelo.
