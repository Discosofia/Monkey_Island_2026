--!strict
-- Mascotas que siguen a su dueño (Fase 5), en el Lobby y en la Isla. Cada cliente dibuja las de todos
-- los jugadores (atributo "ActivePet"), así se mueven suaves sin cargar al servidor. Las de rastreo,
-- además, resaltan a su dueño los monos cercanos cada pocos segundos.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)
local PetModels = require(script.Parent.Parent.PetModels)
local Pets = require(script.Parent.Parent.Data.Pets)

local TRACK_EVERY = 5
local TRACK_RADIUS = 60

local PetFollowers = {}

type Follower = { petId: string, model: Model }

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
				followers[player] = { petId = petId, model = model }
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

	-- Sigue al dueño: detrás y a un lado, flotando un poco.
	RunService.RenderStepped:Connect(function(deltaTime: number)
		local bob = math.sin(os.clock() * 3) * 0.3
		for player, follower in followers do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				local goal = root.CFrame * CFrame.new(2.5, 0.5 + bob, 2.5)
				local current = follower.model:GetPivot()
				local alpha = math.clamp(deltaTime * 6, 0, 1)
				follower.model:PivotTo(current:Lerp(goal, alpha))
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
