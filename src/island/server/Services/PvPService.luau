--!strict
-- PvP opt-in (GDD §12, Fase 5).
--   - Se activa en el tótem del Basecamp. Desactivarlo tarda Config.PvP.DisableDelaySeconds.
--   - Solo se pelea entre jugadores con PvP activo y fuera del Basecamp (CombatService.damagePvP).
--   - Indicador sobre la cabeza ("⚔️ PvP") con la recompensa PvP: cada derribo PvP la sube y
--     quien te derriba la cobra (Ámbar al final de la partida).
--   - Abrir una caja de suministro o cargar el huevo lo activa a la fuerza un rato (forceOn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasecampService = require(script.Parent.BasecampService)

local PvPService = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function refreshIndicator(player: Player)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if not (head and head:IsA("BasePart")) then
		return
	end
	local existing = head:FindFirstChild("PvPIndicator")
	if player:GetAttribute("PvP") ~= true then
		if existing then
			existing:Destroy()
		end
		return
	end
	local billboard = existing :: BillboardGui?
	if not billboard then
		local created = Instance.new("BillboardGui")
		created.Name = "PvPIndicator"
		created.Size = UDim2.fromOffset(110, 26)
		created.StudsOffset = Vector3.new(0, 3.4, 0)
		created.MaxDistance = 120
		created.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 80, 70)
		label.TextStrokeTransparency = 0.2
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.Parent = created
		billboard = created
	end
	local bounty = player:GetAttribute("Bounty")
	local label = (billboard :: BillboardGui):FindFirstChildOfClass("TextLabel") :: TextLabel
	label.Text = if typeof(bounty) == "number" and bounty > 0 then `⚔️ PvP · 💰{bounty}` else "⚔️ PvP"
end

local function setPvP(player: Player, enabled: boolean)
	player:SetAttribute("PvP", enabled)
	player:SetAttribute("PvPDisableAt", nil)
	refreshIndicator(player)
end

-- PvP obligatorio durante "seconds" (caja de suministro, huevo).
function PvPService.forceOn(player: Player, seconds: number, reason: string)
	local wasOn = player:GetAttribute("PvP") == true
	setPvP(player, true)
	local lockedUntil = player:GetAttribute("PvPLockedUntil")
	local current = if typeof(lockedUntil) == "number" then lockedUntil else 0
	player:SetAttribute("PvPLockedUntil", math.max(current, now() + seconds))
	if not wasOn then
		Remotes.Notify:FireClient(player, `⚔️ PvP activado: {reason}`)
	end
end

local function onTotem(player: Player)
	if player:GetAttribute("PvP") ~= true then
		setPvP(player, true)
		Remotes.Notify:FireClient(
			player,
			"⚔️ PvP activado: puedes atacar y ser atacado por otros jugadores con PvP"
		)
		return
	end
	local lockedUntil = player:GetAttribute("PvPLockedUntil")
	if typeof(lockedUntil) == "number" and now() < lockedUntil then
		Remotes.Notify:FireClient(player, `No puedes quitar el PvP aún ({math.ceil(lockedUntil - now())} s)`)
		return
	end
	if player:GetAttribute("PvPDisableAt") ~= nil then
		player:SetAttribute("PvPDisableAt", nil)
		Remotes.Notify:FireClient(player, "Has cancelado la desactivación del PvP")
		return
	end
	local disableAt = now() + Config.PvP.DisableDelaySeconds
	player:SetAttribute("PvPDisableAt", disableAt)
	Remotes.Notify:FireClient(player, `El PvP se desactivará en {Config.PvP.DisableDelaySeconds} s`)
end

local function buildTotem(): Model
	local center = BasecampService.getCenter()
	local spot = center + Config.PvP.TotemOffset
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(spot.X, center.Y + 60, spot.Z), Vector3.new(0, -300, 0), params)
	local ground = if hit then hit.Position else Vector3.new(spot.X, 0, spot.Z)

	local model = Instance.new("Model")
	model.Name = "Tótem PvP"
	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(1.6, 12, 1.6)
	pole.Position = ground + Vector3.new(0, 6, 0)
	pole.Anchored = true
	pole.Color = Color3.fromRGB(95, 60, 35)
	pole.Material = Enum.Material.Wood
	pole.Parent = model
	for i, color in { Color3.fromRGB(200, 40, 40), Color3.fromRGB(240, 200, 60), Color3.fromRGB(40, 40, 40) } do
		local ring = Instance.new("Part")
		ring.Name = "Band"
		ring.Size = Vector3.new(2, 0.8, 2)
		ring.Position = ground + Vector3.new(0, 4 + i * 2.2, 0)
		ring.Anchored = true
		ring.Color = color
		ring.Parent = model
	end
	local banner = Instance.new("Part")
	banner.Name = "Banner"
	banner.Size = Vector3.new(0.2, 3, 4)
	banner.Position = ground + Vector3.new(0, 10, 2.6)
	banner.Anchored = true
	banner.CanCollide = false
	banner.Color = Color3.fromRGB(180, 30, 30)
	banner.Material = Enum.Material.Fabric
	banner.Parent = model
	model.PrimaryPart = pole

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(180, 36)
	sign.StudsOffset = Vector3.new(0, 7.5, 0)
	sign.MaxDistance = 80
	sign.Parent = pole
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "⚔️ Tótem PvP"
	label.TextColor3 = Color3.fromRGB(255, 120, 100)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = sign
	model.Parent = Workspace
	return model
end

function PvPService:Start()
	local totem = Workspace:FindFirstChild("PvPTotem", true) or buildTotem()
	local anchor = if totem:IsA("Model") then totem.PrimaryPart else totem
	if anchor and anchor:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PvPPrompt"
		prompt.ActionText = "Activar / quitar PvP"
		prompt.ObjectText = "Tótem PvP"
		prompt.HoldDuration = 0.8
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(onTotem)
	end

	local function onPlayer(player: Player)
		player:SetAttribute("PvP", false)
		player:SetAttribute("Bounty", 0)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			refreshIndicator(player)
		end)
		player:GetAttributeChangedSignal("Bounty"):Connect(function()
			refreshIndicator(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- Desactivaciones pendientes.
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local disableAt = player:GetAttribute("PvPDisableAt")
			if typeof(disableAt) == "number" and now() >= disableAt then
				setPvP(player, false)
				Remotes.Notify:FireClient(player, "🕊️ PvP desactivado")
			end
		end
	end
end

return PvPService
