--!strict
-- Mascotas que siguen a su dueño (Fase 5), en el Lobby y en la Isla. Cada cliente dibuja las de todos
-- los jugadores (atributo "ActivePet"), así se mueven suaves sin cargar al servidor. Las de rastreo,
-- además, resaltan a su dueño los monos cercanos cada pocos segundos. Las de combate, cuando el
-- servidor avisa de un ataque (Remotes.PetAttack), corren hasta el mono, cogen impulso, saltan sobre
-- él justo cuando llega el daño (Config.Pets.StrikeDelaySeconds) y vuelven con su dueño.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local PetModels = require(script.Parent.Parent.PetModels)
local Pets = require(script.Parent.Parent.Data.Pets)
local Remotes = require(script.Parent.Parent.Remotes)

local TRACK_EVERY = 5
local TRACK_RADIUS = 60
-- Duración total de un ataque (ir, golpear y empezar a volver).
local ATTACK_SECONDS = 0.85

local PetFollowers = {}

type Attack = { target: Model, startedAt: number, standOff: number }
-- "clock": tiempo de su animación, que corre más deprisa mientras ataca.
type Follower = { petId: string, model: Model, attack: Attack?, clock: number }

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

function PetFollowers.start()
	local followers: { [Player]: Follower } = {}
	local localPlayer = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "Mascotas"
	folder.Parent = Workspace

	local function sync(player: Player)
		local petId = player:GetAttribute("ActivePet")
		local current = followers[player]
		if current and current.petId == petId then
			return
		end
		if current then
			current.model:Destroy()
			followers[player] = nil
		end
		if typeof(petId) == "string" then
			local model = PetModels.build(petId)
			if model then
				model.Parent = folder
				followers[player] = { petId = petId, model = model, attack = nil, clock = 0 }
			end
		end
	end

	local function watch(player: Player)
		player:GetAttributeChangedSignal("ActivePet"):Connect(function()
			sync(player)
		end)
		sync(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local current = followers[player]
		if current then
			current.model:Destroy()
			followers[player] = nil
		end
	end)

	-- Sigue al dueño, detrás y a un lado: las que andan o saltan van por el suelo, las que vuelan
	-- un poco por encima, y todas mueven sus partes (PetModels.animate).
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	local function groundBelow(position: Vector3, fallback: number, extra: Instance?): number
		local ignore: { Instance } = { folder }
		if extra then
			table.insert(ignore, extra)
		end
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		groundParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), groundParams)
		return if hit then hit.Position.Y else fallback
	end

	Remotes.PetAttack.OnClientEvent:Connect(function(player: Player, target: Model)
		local follower = followers[player]
		if follower and typeof(target) == "Instance" and target:IsA("Model") then
			local size = target:GetExtentsSize()
			follower.attack = {
				target = target,
				startedAt = os.clock(),
				standOff = math.max(size.X, size.Z) * 0.3 + 1.5,
			}
		end
	end)

	-- Ataque: delante del mono, de cara a él. Coge impulso echándose atrás con el morro arriba y
	-- luego salta sobre él con el morro abajo.
	local function attackPose(model: Model, attack: Attack, now: number, lift: number): CFrame
		local target = attack.target:GetPivot().Position
		local current = model:GetPivot().Position
		local flat = (current - target) * Vector3.new(1, 0, 1)
		local away = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
		local t = now - attack.startedAt
		local strikeAt = Config.Pets.StrikeDelaySeconds
		local windup = smoothstep(strikeAt - 0.2, strikeAt, t) * (1 - smoothstep(strikeAt, strikeAt + 0.08, t))
		local strike = smoothstep(strikeAt, strikeAt + 0.08, t) * (1 - smoothstep(strikeAt + 0.2, ATTACK_SECONDS, t))
		local stand = target + away * (attack.standOff + windup * 0.8 - strike * attack.standOff * 0.6)
		local motion = model:GetAttribute("Motion")
		local y = if motion == "Fly" or motion == "Hover"
			then target.Y + 1
			else groundBelow(stand, target.Y - 2, attack.target) + lift + strike * 0.8
		local position = Vector3.new(stand.X, y, stand.Z)
		return CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
			* CFrame.Angles(math.rad(25) * windup - math.rad(20) * strike, 0, 0)
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		local now = os.clock()
		for player, follower in followers do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				local model = follower.model
				local motion = model:GetAttribute("Motion")
				local height = model:GetAttribute("Height")
				local velocity = root.AssemblyLinearVelocity
				local moving = math.clamp(Vector3.new(velocity.X, 0, velocity.Z).Magnitude / 12, 0, 1)
				local lift = if typeof(height) == "number" then height else 0.6
				local attack = follower.attack
				if attack and (now - attack.startedAt > ATTACK_SECONDS or not attack.target.Parent) then
					follower.attack = nil
					attack = nil
				end
				local goal: CFrame
				if attack then
					goal = attackPose(model, attack, now, lift)
				elseif motion == "Fly" then
					goal = root.CFrame * CFrame.new(2.8, 2 + math.sin(now * 3) * 0.4, 2.2)
				elseif motion == "Hover" then
					goal = root.CFrame * CFrame.new(1.8, 1.2 + math.sin(now * 5) * 0.25, 1.2)
				else
					local beside = root.CFrame * CFrame.new(2.5, 0, 2.5)
					local floor = groundBelow(beside.Position, root.Position.Y - 3)
					local hop = if motion == "Hop" then math.abs(math.sin(now * 6)) * (0.15 + moving * 0.8) else 0
					goal = beside.Rotation + Vector3.new(beside.X, floor + lift + hop, beside.Z)
				end
				local current = model:GetPivot()
				-- Al atacar va mucho más deprisa y mueve patas, alas y brazos a toda velocidad.
				local alpha = math.clamp(deltaTime * (if attack then 14 else 6), 0, 1)
				model:PivotTo(current:Lerp(goal, alpha))
				follower.clock += deltaTime * (if attack then 2.2 else 1)
				PetModels.animate(model, follower.clock, if attack then 1 else moving)
			end
		end
	end)

	-- Rastreo: resalta los monos cercanos al dueño (solo él los ve).
	task.spawn(function()
		while true do
			task.wait(TRACK_EVERY)
			local petId = localPlayer:GetAttribute("ActivePet")
			local pet = if typeof(petId) == "string" then Pets[petId] else nil
			local character = localPlayer.Character
			if pet and pet.tracks and character then
				local position = character:GetPivot().Position
				for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
					if enemy:IsA("Model") and (enemy:GetPivot().Position - position).Magnitude <= TRACK_RADIUS then
						local highlight = Instance.new("Highlight")
						highlight.FillTransparency = 1
						highlight.OutlineColor = Color3.fromRGB(255, 220, 90)
						highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						highlight.Parent = enemy
						Debris:AddItem(highlight, 3)
					end
				end
			end
		end
	end)
end

return PetFollowers
