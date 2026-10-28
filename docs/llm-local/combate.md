# Combate y equilibrio (resumen de la skill combate-roblox)

<!-- Fuente: .claude/skills/combate-roblox/SKILL.md, 28-10-2026. Detalles: references/sistema-de-habilidades.md, sistema-de-combate.md, estilos-y-combos.md y equilibrio.md (§2 medidas, §3 límites, §4 línea base, §6 palancas). -->

**Regla: se mide antes de escribir.** Cada propuesta pasa por la calculadora `Equilibrio`, se compara con la línea base y los límites, y solo entonces se implementa.

## Calculadora (place de la Isla, Edit, Rojo conectado)

```lua
local m = game.ServerStorage.Tools.Equilibrio:Clone()
_G.Equilibrio = require(m); m:Destroy()
return _G.Equilibrio.informe({ soloRol = "Cazador" })
```

- **Opciones:** `soloRol`, `talentos = "max"`, `grupo = 6`, `critico = 0.15`, `dias = {1, 12}`, `segundosCombo = 240`, `jugadoresJefe = {1, 4}` y `armasPorDia`.
- **Propuesta (segundo argumento):** cambia los datos solo para ese informe.
  ```lua
  return _G.Equilibrio.informe({ soloRol = "Cazador" }, {
  	config = { Abilities = { BoomerangDamage = 14 } },
  	datos = { Weapons = { Bow = { damage = 20 } } },
  })
  ```
- El informe es largo. Para leer solo las alertas:
  ```lua
  local r = _G.Equilibrio.informe(); local i = r:find("Alertas", 1, true); return r:sub(i)
  ```
- Mira también con `talentos = "max"`.
- **Laboratorio** (Fase 13, sin roles): `informe({ secciones = { laboratorio = true } })` mide el tiempo para matar de las 4 armas de `Data/LabWeapons` a 15, 50 y 120 studs y quién gana cada cruce (objetivo: 1,5–2,5 s en la distancia de cada arma).
- Enseña al usuario una tabla **antes → después**: recarga, segundos de arma, DPS en grupo, control y alertas.

## Ficha de diseño

- **Quién:** rol y hueco (Z/X/C/R, o V la definitiva), mono, jefe o mascota.
- **Fantasía y familia:** daño a uno, daño en área, control, defensa, curación, movilidad o apoyo.
- **Combo:** prepara, enlaza o remata. La ventana es de 6 s y ninguna definitiva entra en combos.
- **Lectura y respuesta:** cómo se ve venir y cómo se esquiva. En PvP, el daño y el control van ×0,5.
- **Movilidad:** correr 18/26; deslizar (Alt izquierdo, C en el Laboratorio, R3 en mando; 15 de estamina, cooldown 1 s, de 36 a 18 studs/s en 0,75 s, sin invulnerabilidad; ×0,85 con hambre o sed bajas).
- **Móvil:** apunta hacia donde mira la cámara. El texto corto del botón tiene unas 9 letras.
- **Números:** parte del pariente más cercano que ya existe.

## Dónde se implementa una habilidad del jugador

1. `src/shared/Data/Roles.luau`: `id`, `name`, `short`, `description`, `cooldownSeconds`, `castSeconds` (0,15–0,35) y `guardDamage` (o `unblockable`).
2. `src/shared/Config.luau` → `Abilities`: sus números, cada uno con su comentario de unidades.
3. `src/combat/Services/AbilityService.luau`: el handler, con las piezas comunes (`targetsAround`, `castShot`, `hurt`, `control`, `heal`, `Projectiles.fire`, `Zones.create`, `Knockback.push`) y su entrada en `HANDLERS`.
4. Efecto en `AbilityFxController` (`EFFECTS`), gesto en `Data/PlayerAnimations` y número visible en `UI/SettingsPanel` → `ABILITY_INFO`.
5. Talento en `Data/Talents` y `Data/Perks`, y combo en `Data/Combos`.
6. Su modelo en `MODELOS` de `src/island/tools/Equilibrio.luau`.
7. Documentación en `docs/GDD.md` §6.3 y §6.4.

## Equidad (repásala antes de dar algo por bueno)

- **Entre roles:** ±20 % en grupo y ±30 % a un objetivo. Cada rol gana en su escenario.
- **Entre dispositivos:** las mismas ventanas y números en PC, móvil y mando. Los avisos se ven sin sonido.
- **Sin salida:** todo control sobre un jugador pasa por `Status` (inmunidad al soltarse) y tiene respuesta (Evasivo).
- **Detección:** con `Combat/Hitbox` (rayo, esfera, caja). Nunca `.Touched`.
- **Colores:** verde curación, morado veneno, rojo daño recibido, dorado parry y naranja con grietas para la guardia rota.
- **Pago:** nada de Robux da poder.

## Verificar

`stylua src`, `selene src` y `rojo build island.project.json --output build/island.rbxl`. Repite el informe sin propuesta: tiene que salir igual que la propuesta aprobada. Lo que necesite dos jugadores (PvP, vida de los jefes) lo prueba el usuario.
