--!strict
-- Semilla de la dispersión (Fase 19, W4; Shared/LabSpread.offset): cada vez que el personaje aparece, el
-- Player recibe el atributo "ShotSeed" (un entero al azar). Con la semilla y el número de disparo
-- (6.º argumento de UseWeapon) el servidor y el cliente sacan el mismo desvío, y así el tirador dibuja su
-- bala al momento ya con la dispersión que luego aplica el servidor.

local Players = game:GetService("Players")

local SEED_MAX = 1_000_000_000

local ShotSeedService = {}

local random = Random.new()

local function reseed(player: Player)
	player:SetAttribute("ShotSeed", random:NextInteger(1, SEED_MAX))
end

local function add(player: Player)
	player.CharacterAdded:Connect(function()
		reseed(player)
	end)
	reseed(player)
end

function ShotSeedService:Start()
	Players.PlayerAdded:Connect(add)
	for _, player in Players:GetPlayers() do
		add(player)
	end
end

return ShotSeedService
