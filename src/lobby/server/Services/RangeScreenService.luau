--!strict
-- Marcas de las pantallas de ajuste del campo de tiro (Fase 23, World/RangeBuilder). Cuando un proyectil
-- acaba contra una pantalla (pieza con el atributo RangeScreen), el servidor calcula dónde: en studs desde
-- el centro, hacia la derecha de quien mira (dx) y hacia arriba (dy), y la distancia del tirador al
-- centro, más qué lo disparó y cuánto voló (Fase 24d). Se lo manda solo al tirador (Remotes.RangeShot); su cliente dibuja la marca y la media
-- (RangeScreenController). Las marcas son locales de cada jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Projectiles = require(ServerScriptService.Combat.Projectiles)
local RangeScreenMath = require(script.Parent.Parent.World.RangeScreenMath)

-- Lo más lejos del centro de la pantalla a lo que se acepta a un tirador (el recinto mide 182 studs).
local MAX_SHOOTER_DISTANCE = 300

local RangeScreenService = {}

local lastSent: { [Player]: number } = {}

local function livingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function onImpact(
	shooter: Player,
	position: Vector3,
	instance: Instance?,
	_model: Model?,
	info: Projectiles.ImpactInfo?
)
	if not instance then
		return
	end
	local screenId, dx, dy = RangeScreenMath.locate(instance, position)
	if not screenId then
		return
	end
	local root = livingRoot(shooter)
	if not root or (root.Position - (instance :: BasePart).Position).Magnitude > MAX_SHOOTER_DISTANCE then
		return
	end
	local now = os.clock()
	if now - (lastSent[shooter] or -math.huge) < Config.Range.MarkMinInterval then
		return
	end
	lastSent[shooter] = now
	local distance = (root.Position - (instance :: BasePart).Position).Magnitude
	-- Qué lo disparó (el arma o la habilidad; sin él, cómo se ve) y los segundos que voló, para colorear la marca.
	local source = if info then info.source or info.look else ""
	Remotes.RangeShot:FireClient(shooter, screenId, dx, dy, distance, source, if info then info.elapsed else 0)
end

function RangeScreenService:Start()
	Projectiles.onImpact(onImpact)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSent[player] = nil
	end)
end

return RangeScreenService
