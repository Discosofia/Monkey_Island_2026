--!strict
-- Habilidades activas de los roles (Fase 3), con su tiempo de espera (Data/Roles):
--   - Médico, "Ungüento en área": cura a los aliados vivos cercanos (y a sí mismo).
--   - Cazador, "Marcar presas": resalta los monos cercanos para todos; reciben más daño.
--   - Recolector, "Recolección frenética": el hacha y el pico golpean el doble un rato.
-- El cliente ve cuándo vuelve a estar lista con el atributo "AbilityReadyAt" (hora del servidor).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)

local AbilityService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Onda visible que se expande desde el jugador.
local function pulse(position: Vector3, radius: number, color: Color3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.5
	ring.Size = Vector3.one * 2
	ring.Position = position
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.6), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.7)
end

local function areaHeal(player: Player, root: BasePart)
	local settings = Config.Abilities
	local amount = settings.AreaHealAmount * Progression.perk(player, "HealPower")
	local healed = 0
	for _, other in Players:GetPlayers() do
		local otherRoot = rootOf(other)
		local character = other.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local near = otherRoot and (otherRoot.Position - root.Position).Magnitude <= settings.AreaHealRadius
		if near and humanoid and LifeState.isAlive(other) and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
			healed += 1
		end
	end
	pulse(root.Position, settings.AreaHealRadius, Color3.fromRGB(110, 240, 140))
	Remotes.Notify:FireClient(player, `⛑️ Has curado a {healed} jugador(es)`)
end

local function markPrey(player: Player, root: BasePart)
	local settings = Config.Abilities
	local seconds = Progression.perk(player, "MarkSeconds")
	local bonus = Progression.perk(player, "MarkedBonus")
	local untilTime = Workspace:GetServerTimeNow() + seconds
	local marked = 0
	for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		if enemy:IsA("Model") then
			local distance = (enemy:GetPivot().Position - root.Position).Magnitude
			if distance <= settings.MarkRadius then
				enemy:SetAttribute("MarkedUntil", untilTime)
				enemy:SetAttribute("MarkBonus", bonus)
				local highlight = Instance.new("Highlight")
				highlight.Name = "PreyMark"
				highlight.FillTransparency = 1
				highlight.OutlineColor = Color3.fromRGB(255, 70, 50)
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = enemy
				Debris:AddItem(highlight, seconds)
				marked += 1
			end
		end
	end
	pulse(root.Position, 12, Color3.fromRGB(255, 90, 60))
	Remotes.Notify:FireClient(player, `🏹 {marked} presa(s) marcada(s) durante {seconds} s`)
end

local function frenzy(player: Player, root: BasePart)
	player:SetAttribute("FrenzyUntil", Workspace:GetServerTimeNow() + Config.Abilities.FrenzySeconds)
	pulse(root.Position, 8, Color3.fromRGB(240, 210, 80))
	Remotes.Notify:FireClient(player, `🧺 ¡Recolección frenética durante {Config.Abilities.FrenzySeconds} s!`)
end

local HANDLERS: { [string]: (player: Player, root: BasePart) -> () } = {
	AreaHeal = areaHeal,
	MarkPrey = markPrey,
	Frenzy = frenzy,
}

local function onUseAbility(player: Player)
	local roleId = player:GetAttribute("Role")
	local role = if typeof(roleId) == "string" then Roles[roleId] else nil
	local root = rootOf(player)
	if not (role and root) or not LifeState.isAlive(player) then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("AbilityReadyAt")
	if typeof(readyAt) == "number" and now < readyAt then
		return
	end
	local handler = HANDLERS[role.ability.id]
	if handler then
		player:SetAttribute("AbilityReadyAt", now + role.ability.cooldownSeconds)
		handler(player, root)
	end
end

-- true si el jugador está en "Recolección frenética".
function AbilityService.inFrenzy(player: Player): boolean
	local untilTime = player:GetAttribute("FrenzyUntil")
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

function AbilityService:Start()
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
end

return AbilityService
