--!strict
-- Estados que las habilidades de los roles ponen a los enemigos (monos, jefes, muñecos). Se guardan
-- como atributos del modelo con la hora del servidor en que terminan; la IA de los monos
-- (MonkeyService) y la de los jefes (BossService) los consultan en cada vuelta.
--   - Aturdido ("StunnedUntil"): no se mueve ni ataca. Lo usan aturdir, congelar e inmovilizar.
--     Los jefes se resisten (Config.Abilities.BossControlMultiplier).
--   - Ralentizado ("SlowedUntil" y "SlowFactor"): anda más despacio.
--   - Provocado ("TauntedBy" y "TauntedUntil"): va a por el jugador que le provocó.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Status = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function active(model: Model, attribute: string): boolean
	local untilTime = model:GetAttribute(attribute)
	return typeof(untilTime) == "number" and now() < untilTime
end

-- Contorno de color mientras dura un estado.
local function outline(model: Model, name: string, color: Color3, seconds: number)
	local old = model:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = name
	highlight.FillColor = color
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, seconds)
end

function Status.isBoss(model: Model): boolean
	return model:GetAttribute("Boss") ~= nil
end

-- Aturde (o congela, o inmoviliza). Aturdido lleva un contorno amarillo; el bloque de hielo del
-- congelado y el brillo verde del inmovilizado los dibuja cada cliente (AbilityFxController).
-- Devuelve los segundos que dura de verdad (los jefes se resisten).
function Status.stun(model: Model, seconds: number, look: ("Stun" | "Freeze" | "Root")?): number
	if Status.isBoss(model) then
		seconds *= Config.Abilities.BossControlMultiplier
	end
	local untilTime = now() + seconds
	local current = model:GetAttribute("StunnedUntil")
	if typeof(current) ~= "number" or current < untilTime then
		model:SetAttribute("StunnedUntil", untilTime)
	end
	if look ~= "Freeze" and look ~= "Root" then
		outline(model, "StatusOutline", Color3.fromRGB(255, 230, 90), seconds)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
	return seconds
end

function Status.slow(model: Model, seconds: number, factor: number)
	model:SetAttribute("SlowedUntil", now() + seconds)
	model:SetAttribute("SlowFactor", factor)
end

function Status.taunt(model: Model, player: Player, seconds: number)
	model:SetAttribute("TauntedBy", player.UserId)
	model:SetAttribute("TauntedUntil", now() + seconds)
end

function Status.isStunned(model: Model): boolean
	return active(model, "StunnedUntil")
end

-- Fracción de su velocidad normal con la que anda (1 = normal).
function Status.speedFactor(model: Model): number
	local factor = model:GetAttribute("SlowFactor")
	if active(model, "SlowedUntil") and typeof(factor) == "number" then
		return factor
	end
	return 1
end

-- Jugador vivo que le está provocando, o nil.
function Status.tauntTarget(model: Model): Player?
	local userId = model:GetAttribute("TauntedBy")
	if not active(model, "TauntedUntil") or typeof(userId) ~= "number" then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

return Status
