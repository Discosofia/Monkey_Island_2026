--!strict
-- Luces averiadas del carguero «Esperanza» en el Lobby: parpadean, se apagan un rato y vuelven a
-- encenderse a trompicones; algunas están casi muertas y solo dan chispazos. Las piezas llevan la
-- etiqueta Config.Lobby.BrokenLightTag (World/LobbyBuilder). Cada cliente las anima por su cuenta.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

-- Parte de las luces que están casi muertas.
local DYING_CHANCE = 0.25

local ShipLightsController = {}

local rng = Random.new()

local function animate(part: BasePart)
	local onColor = part.Color
	local onMaterial = part.Material
	local offColor = onColor:Lerp(Color3.new(0, 0, 0), 0.75)
	local lights: { Light } = {}
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			table.insert(lights, child)
		end
	end

	local function set(on: boolean)
		part.Color = if on then onColor else offColor
		part.Material = if on then onMaterial else Enum.Material.SmoothPlastic
		for _, light in lights do
			light.Enabled = on
		end
	end

	-- Parpadeo rápido que termina encendida.
	local function stutter(times: number)
		for _ = 1, times do
			set(false)
			task.wait(rng:NextNumber(0.03, 0.12))
			set(true)
			task.wait(rng:NextNumber(0.03, 0.15))
		end
	end

	local dying = rng:NextNumber() < DYING_CHANCE
	while part:IsDescendantOf(Workspace) do
		if dying then
			set(false)
			task.wait(rng:NextNumber(1.5, 6))
			stutter(rng:NextInteger(2, 5))
			task.wait(rng:NextNumber(0.1, 0.6))
		else
			task.wait(rng:NextNumber(0.8, 5))
			if rng:NextNumber() < 0.7 then
				stutter(rng:NextInteger(2, 7))
			else
				-- Se apaga un rato y vuelve con tirones.
				set(false)
				task.wait(rng:NextNumber(0.4, 2.2))
				stutter(rng:NextInteger(1, 3))
			end
		end
	end
end

function ShipLightsController:Start()
	local tag = Config.Lobby.BrokenLightTag
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			task.spawn(animate, instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		if instance:IsA("BasePart") then
			task.spawn(animate, instance)
		end
	end)
end

return ShipLightsController
