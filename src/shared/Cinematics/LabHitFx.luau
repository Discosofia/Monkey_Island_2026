--!strict
-- La respuesta de un impacto en las cinemáticas del Laboratorio (Fase 25, G13). LabActor la llama cuando llega el proyectil de
-- un labShot con `hit`: repite en local lo que hace el combate al recibir los avisos del servidor, con el mismo código del
-- juego (cada controlador de CombatClient expone una función pública pequeña):
--   - el destello rojo del blanco (como `flash` de CombatService),
--   - el número de daño (CombatTextController.showLocal): amarillo con tu estilo si dispara el avatar, rojo «-N» si no;
--     con `head`, «¡Cabeza!» y crítico; el veneno del cañón son 3 números morados, uno por segundo,
--   - el cómic de impacto (ComicFxController.burstLocal): Hit o, con `ko`, K.O.!,
--   - el hitmarker y su sonido (HitFeedbackController.showLocal), solo si dispara el avatar,
--   - el efecto propio del arma: la red del arpón (Entangled) o el charco del cañón (AcidPuddle).
-- `hit` de un labShot: true (todo por defecto) o { damage?, head?, ko?, poison?, seconds? }. Por defecto, damage es el del arma
-- por la zona (la cabeza, la de LabWeapons) y poison el del arma.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Config = require(script.Parent.Parent.Config)
local LabWeapons = require(script.Parent.Parent.Data.LabWeapons)

local LabHitFx = {}

export type HitSpec = {
	damage: number?, -- el número que sale (por defecto, el daño del arma por la zona)
	head: boolean?, -- golpe a la cabeza: «¡Cabeza!» y crítico
	ko: boolean?, -- derriba: cómic K.O.! y hitmarker de muerte
	poison: number?, -- daño de cada número morado (3, uno por segundo); por defecto el del arma si tiene veneno
	seconds: number?, -- lo que dura la red o el charco
}

export type Info = {
	shooter: Model,
	target: Model,
	weaponId: string,
	point: Vector3, -- dónde cae el proyectil
	hit: HitSpec,
	byAvatar: boolean, -- dispara el avatar (el jugador): el número es daño hecho y sale el hitmarker
	combatModule: (name: string) -> any?,
}

local FLASH_COLOR = Color3.fromRGB(255, 60, 60)
local FLASH_SECONDS = 0.15
local POISON_TICKS = 3

-- El destello rojo del blanco (también lo usa BattleActor para los golpes de las batallas contra jefes).
function LabHitFx.flash(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = FLASH_COLOR
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	Debris:AddItem(highlight, FLASH_SECONDS)
end

-- Un controlador de CombatClient que ya arrancó, o nil si el place no lo carga.
local function controller(info: Info, name: string): any?
	return info.combatModule(name)
end

function LabHitFx.play(info: Info)
	local weapon = LabWeapons.weapons[info.weaponId]
	local target = info.target
	if not (weapon and target.Parent) then
		return
	end
	local hit = info.hit
	local head = hit.head == true
	local zone = if head
			and weapon.zoneMultipliers
			and weapon.zoneMultipliers.Head
		then weapon.zoneMultipliers.Head
		else 1
	local amount: number = hit.damage or math.round(weapon.damage * zone)
	local userId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

	LabHitFx.flash(target)

	local text = controller(info, "CombatTextController")
	if text and text.showLocal then
		text.showLocal({
			target = target,
			amount = amount,
			kind = if info.byAvatar then "Dealt" else "Taken",
			crit = head,
			head = head,
			ko = hit.ko == true,
			by = if info.byAvatar then userId else nil,
		})
		-- El veneno del cañón: números morados, uno por segundo, después del golpe.
		local poison: number? = hit.poison or (if weapon.poison then weapon.poison.dps else nil)
		if poison then
			for tick = 1, POISON_TICKS do
				task.delay(tick, function()
					if target.Parent then
						text.showLocal({
							target = target,
							amount = poison,
							kind = "Poison",
							by = if info.byAvatar then userId else nil,
						})
					end
				end)
			end
		end
	end

	local comic = controller(info, "ComicFxController")
	if comic and comic.burstLocal then
		comic.burstLocal(target, if hit.ko == true then "KO" else "Hit")
	end

	if info.byAvatar then
		local feedback = controller(info, "HitFeedbackController")
		if feedback and feedback.showLocal then
			feedback.showLocal(if hit.ko == true then "Kill" elseif head then "Head" else "Body")
		end
	end

	-- Lo propio del arma: la red del arpón o el charco del cañón.
	local effect = weapon.lab.effect
	local fx = controller(info, "AbilityFxController")
	if fx and effect == "Entangle" then
		fx.play("Entangled", target, hit.seconds or Config.Lab.NetSeconds)
	elseif fx and effect == "AcidBurst" then
		fx.play("AcidPuddle", info.point, Config.Lab.AcidRadius, hit.seconds or Config.Lab.AcidPuddleSeconds)
	end
end

return LabHitFx
