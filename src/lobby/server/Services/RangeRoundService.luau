--!strict
-- «Ronda de tiro» del campo de tiro del Lobby (Fase 23, World/RangeBuilder). Al activar el aviso
-- "RondaPrompt" empieza la ronda de ese jugador (Config.Range.RoundSeconds): solo cuenta lo que dispara él
-- en ese tiempo. Cada impacto en una diana (modelo con RangeTarget) puntúa según el anillo en que cae, por
-- la distancia del punto de impacto al centro de la diana en su plano (Config.Range.RingPoints); el anillo
-- central cuenta además como crítico. También se cuentan los disparos de arma, para la precisión. Al acabar
-- el tiempo, o si el jugador muere, sale del recinto o se va, se manda el resultado (Remotes.RangeRound) y se
-- guarda el mejor de la sesión del servidor. Es solo práctica: sin Ámbar ni recompensas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local Projectiles = require(ServerScriptService.Combat.Projectiles)

local PROMPT_NAME = "RondaPrompt"
-- Margen sobre el alcance del aviso por el retraso de la red.
local REACH_SLACK = 8
-- Cada cuánto se mira si el jugador sigue vivo y dentro del recinto.
local WATCH_SECONDS = 0.5
-- Lo que se le da de margen al recinto para contar al jugador como dentro.
local INSIDE_SLACK = 2
-- Margen de red tras el final: un disparo ya en el aire todavía puntúa.
local GRACE_SECONDS = 0.4

type Ring = { fraction: number, points: number, crit: boolean }

type Round = {
	endsAt: number, -- hora del servidor (Workspace:GetServerTimeNow)
	points: number,
	hits: number,
	crits: number,
	shots: number,
}

local RangeRoundService = {}

local rounds: { [Player]: Round } = {}
local bestScores: { [Player]: number } = {}
local floorSlab: BasePart? = nil

-- true si "root" está dentro del recinto (la losa del suelo) o no se sabe dónde está.
local function insideRange(root: BasePart): boolean
	local slab = floorSlab
	if not slab then
		return true
	end
	local at = slab.CFrame:PointToObjectSpace(root.Position)
	return math.abs(at.X) <= slab.Size.X / 2 + INSIDE_SLACK and math.abs(at.Z) <= slab.Size.Z / 2 + INSIDE_SLACK
end

local function livingCharacter(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function sendScore(player: Player, round: Round)
	Remotes.RangeRound:FireClient(player, "Score", {
		points = round.points,
		hits = round.hits,
		crits = round.crits,
		shots = round.shots,
	})
end

-- Acaba la ronda de "player" y le manda el resultado. "left": se cortó antes de tiempo.
local function finish(player: Player, round: Round, left: boolean)
	if rounds[player] ~= round then
		return
	end
	rounds[player] = nil
	local previous = bestScores[player] or 0
	local newBest = round.points > previous
	if newBest then
		bestScores[player] = round.points
	end
	if player.Parent then
		Remotes.RangeRound:FireClient(player, "End", {
			points = round.points,
			hits = round.hits,
			crits = round.crits,
			shots = round.shots,
			best = bestScores[player] or 0,
			newBest = newBest,
			left = left,
		})
	end
end

local function start(player: Player)
	local seconds = Config.Range.RoundSeconds
	local round: Round = {
		endsAt = Workspace:GetServerTimeNow() + seconds,
		points = 0,
		hits = 0,
		crits = 0,
		shots = 0,
	}
	rounds[player] = round
	Remotes.RangeRound:FireClient(player, "Start", {
		endsAt = round.endsAt,
		seconds = seconds,
		best = bestScores[player] or 0,
	})
	task.delay(seconds + GRACE_SECONDS, function()
		finish(player, round, false)
	end)
end

-- Los puntos del anillo en que cae "position" en la diana "model", o nil si cae fuera del disco (el
-- poste, el canto). La distancia al centro se mide en el plano del disco: el eje del cilindro del anillo
-- central es el X de su pieza.
local function ringOf(model: Model, position: Vector3): Ring?
	local bullseye = model.PrimaryPart
	local radius = model:GetAttribute("Radius")
	if not (bullseye and typeof(radius) == "number" and radius > 0) then
		return nil
	end
	local at = bullseye.CFrame:PointToObjectSpace(position)
	local ratio = math.sqrt(at.Y * at.Y + at.Z * at.Z) / radius
	local rings = Config.Range.RingPoints
	for index, ring in rings do
		local limit = if index == #rings then ring.fraction * Config.Range.RimTolerance else ring.fraction
		if ratio < limit then
			return ring
		end
	end
	return nil
end

local function onEnemyDamaged(model: Model, attacker: Player?, _amount: number, position: Vector3?, _zone: string?)
	local round = if attacker then rounds[attacker] else nil
	if not (attacker and round and position and model:GetAttribute("RangeTarget") == true) then
		return
	end
	if Workspace:GetServerTimeNow() > round.endsAt + GRACE_SECONDS then
		return
	end
	local ring = ringOf(model, position)
	if not ring then
		return
	end
	round.points += ring.points
	round.hits += 1
	if ring.crit then
		round.crits += 1
	end
	sendScore(attacker, round)
end

-- Quien tiene la ronda en marcha: lo suyo se cuenta; los disparos de habilidades (sin ownerSeq) no.
local function onShot(shooter: Player, ownerSeq: number?)
	local round = rounds[shooter]
	if not round or ownerSeq == nil or Workspace:GetServerTimeNow() > round.endsAt then
		return
	end
	round.shots += 1
	sendScore(shooter, round)
end

local function characterNear(player: Player, prompt: ProximityPrompt): boolean
	local humanoid, root = livingCharacter(player)
	local anchor = prompt.Parent
	if not (humanoid and root and anchor and anchor:IsA("BasePart")) then
		return false
	end
	return (root.Position - anchor.Position).Magnitude <= prompt.MaxActivationDistance + REACH_SLACK
end

local function hook(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == PROMPT_NAME then
		instance.Triggered:Connect(function(player: Player)
			if rounds[player] or not characterNear(player, instance) then
				return
			end
			start(player)
		end)
	end
end

function RangeRoundService:Start()
	CombatService.onEnemyDamaged(onEnemyDamaged)
	Projectiles.onShot(onShot)

	local range = Workspace:WaitForChild("CampoDeTiro", 30)
	local floor = if range then range:WaitForChild("Suelo", 30) else nil
	local slab = if floor then floor:WaitForChild("Losa", 30) else nil
	if slab and slab:IsA("BasePart") then
		floorSlab = slab
	end

	for _, instance in Workspace:GetDescendants() do
		hook(instance)
	end
	Workspace.DescendantAdded:Connect(hook)

	Players.PlayerRemoving:Connect(function(player: Player)
		rounds[player] = nil
		bestScores[player] = nil
	end)

	-- Corta la ronda de quien muere o sale del recinto (RangeService lo saca por el arco trasero).
	task.spawn(function()
		while true do
			task.wait(WATCH_SECONDS)
			for player, round in rounds do
				local humanoid, root = livingCharacter(player)
				if not (humanoid and root) or not insideRange(root) then
					finish(player, round, true)
				end
			end
		end
	end)
end

return RangeRoundService
