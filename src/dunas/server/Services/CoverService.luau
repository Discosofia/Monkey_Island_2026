--!strict
-- Coberturas que se rompen (Fase 10, C11): las estelas y las columnas de pie de la arena (los modelos con
-- la etiqueta Config.Combat.DestructibleTag, que pone World/ArenaBuilder). El combate dice qué las
-- alcanza (Combat/Destructibles: una habilidad de daño, una definitiva, el remate de la cadena o el
-- disparo de remate) y aquí se les quita la piedra de Config.Arena.Covers.Damage. Sin piedra se rompen:
-- dejan de verse, de chocar y de tapar (las áreas y los disparos pasan) y vuelven
-- Config.Arena.Covers.RespawnSeconds después, en cuanto no hay nadie dentro. Solo durante la partida; al
-- empezar una, todas enteras.
-- El servidor decide y lo publica en atributos del modelo; cada cliente lo dibuja (CoverController: las
-- grietas, los trozos que caen y el polvo):
--   "CoverHealth", "CoverMaxHealth"  piedra que le queda y la de entera
--   "CoverBroken"                    true mientras está rota

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local Destructibles = require(ServerScriptService.Combat.Destructibles)

-- Cada cuánto se vuelve a mirar si una rota ya puede volver (s).
local RETRY_SECONDS = 1
-- Margen alrededor de la cobertura en el que un personaje impide que vuelva (studs).
local INSIDE_MARGIN = 1.5

type Original = { transparency: number, canCollide: boolean, canQuery: boolean, canTouch: boolean }
type Cover = { model: Model, parts: { [BasePart]: Original }, ticket: number }

local CoverService = {}

local covers: { [Model]: Cover } = {}

local function settings()
	return Config.Arena.Covers
end

-- true si algún personaje está dentro de la cobertura (volver le dejaría atrapado).
local function occupied(model: Model): boolean
	local frame, size = model:GetBoundingBox()
	local half = size / 2 + Vector3.one * INSIDE_MARGIN
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local offset = frame:PointToObjectSpace(root.Position)
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local function restore(cover: Cover)
	cover.ticket += 1
	for part, original in cover.parts do
		part.Transparency = original.transparency
		part.CanCollide = original.canCollide
		part.CanQuery = original.canQuery
		part.CanTouch = original.canTouch
	end
	cover.model:SetAttribute("CoverHealth", settings().Health)
	cover.model:SetAttribute("CoverBroken", nil)
end

-- Vuelve en cuanto no haya nadie dentro (salvo que antes se rompa otra vez o se reinicie).
local function restoreWhenClear(cover: Cover)
	local ticket = cover.ticket
	task.spawn(function()
		while cover.ticket == ticket and occupied(cover.model) do
			task.wait(RETRY_SECONDS)
		end
		if cover.ticket == ticket then
			restore(cover)
			Sfx.play("Build", cover.model:GetPivot().Position)
		end
	end)
end

local function breakCover(cover: Cover, attacker: Player)
	cover.ticket += 1
	local ticket = cover.ticket
	for part in cover.parts do
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	cover.model:SetAttribute("CoverHealth", 0)
	cover.model:SetAttribute("CoverBroken", true)
	Sfx.play("RockBreak", cover.model:GetPivot().Position)
	CombatRules.get().telemetry.mechanic(attacker, "CoversBroken")
	task.delay(settings().RespawnSeconds, function()
		if cover.ticket == ticket then
			restoreWhenClear(cover)
		end
	end)
end

local function onHit(model: Model, kind: Destructibles.Kind, attacker: Player)
	local cover = covers[model]
	if not (cover and Arena.inBattle()) or model:GetAttribute("CoverBroken") == true then
		return
	end
	local health = model:GetAttribute("CoverHealth")
	local left = (if typeof(health) == "number" then health else settings().Health) - settings().Damage[kind]
	if left <= 0 then
		breakCover(cover, attacker)
	else
		model:SetAttribute("CoverHealth", left)
		Sfx.play("StructureHitStone", model:GetPivot().Position)
	end
end

-- Todas enteras (al empezar la partida y al volver a esperar): las que tienen a alguien dentro, en cuanto
-- se aparte.
local function restoreAll()
	for _, cover in covers do
		if cover.model:GetAttribute("CoverBroken") == true then
			cover.ticket += 1
			restoreWhenClear(cover)
		else
			restore(cover)
		end
	end
end

function CoverService:Start()
	local arena = Workspace:WaitForChild("Arena")
	for _, instance in CollectionService:GetTagged(Config.Combat.DestructibleTag) do
		if instance:IsA("Model") and instance:IsDescendantOf(arena) then
			local parts: { [BasePart]: Original } = {}
			for _, part in instance:GetDescendants() do
				if part:IsA("BasePart") then
					parts[part] = {
						transparency = part.Transparency,
						canCollide = part.CanCollide,
						canQuery = part.CanQuery,
						canTouch = part.CanTouch,
					}
				end
			end
			instance:SetAttribute("CoverMaxHealth", settings().Health)
			local cover: Cover = { model = instance, parts = parts, ticket = 0 }
			covers[instance] = cover
			restore(cover)
		end
	end
	Destructibles.onHit(function(model, kind, attacker)
		onHit(model, kind, attacker)
	end)
	ReplicatedStorage:GetAttributeChangedSignal("ArenaPhase"):Connect(function()
		local phase = Arena.phase()
		if phase == "Battle" or phase == "Waiting" then
			restoreAll()
		end
	end)
end

return CoverService
