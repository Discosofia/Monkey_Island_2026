--!strict
-- Zonas de peligro (Fase 10, C10; Config.Zones): lo que una habilidad deja en el suelo unos segundos.
--   - "Fire": el suelo ardiendo del Meteoro que cierra "Lluvia de estrellas".
--   - "Ice": el hielo de la Nova (ralentiza y resbala).
--   - "Cloud": la nube del Polvo somnífero (a quien entra le entra sueño).
-- Aquí se lleva el tiempo de todas en un solo bucle de Heartbeat: cada una llama a su "onTick" cada
-- "tickSeconds" mientras dura, y quien la crea (AbilityService) decide a quién alcanza y qué le hace
-- (solo a los monos y a los rivales de quien la pone). Todos los clientes la dibujan igual con el efecto
-- "Zone" (AbilityFxController).

local RunService = game:GetService("RunService")

local AbilityFx = require(script.Parent.AbilityFx)

export type Kind = "Fire" | "Ice" | "Cloud"

export type Spec = {
	kind: Kind,
	owner: Player,
	center: Vector3, -- en el suelo
	radius: number,
	seconds: number,
	tickSeconds: number,
	firstTick: number?, -- segundos hasta el primer tick (por defecto, al momento)
	onTick: (zone: Spec) -> (),
}

type Active = { spec: Spec, nextTick: number, endsAt: number }

local Zones = {}

local active: { Active } = {}
local started = false

local function step()
	local clock = os.clock()
	for index = #active, 1, -1 do
		local zone = active[index]
		-- El último tick puede caer justo al final (el fuego: un golpe por segundo durante 3 s).
		while zone.nextTick <= zone.endsAt + 1e-3 and clock >= zone.nextTick do
			zone.nextTick += zone.spec.tickSeconds
			if zone.spec.owner.Parent then
				task.spawn(zone.spec.onTick, zone.spec)
			end
		end
		if clock >= zone.endsAt or not zone.spec.owner.Parent then
			table.remove(active, index)
		end
	end
end

-- Pone una zona y la dibuja en todos los clientes.
function Zones.create(spec: Spec)
	local clock = os.clock()
	table.insert(active, {
		spec = spec,
		nextTick = clock + (spec.firstTick or 0),
		endsAt = clock + spec.seconds,
	})
	AbilityFx.all("Zone", spec.kind, spec.center, spec.radius, spec.seconds)
	step()
end

function Zones.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(step)
end

return Zones
