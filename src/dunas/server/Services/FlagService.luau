--!strict
-- Banderas de la arena (captura la bandera), con las reglas clásicas:
--   - Cada equipo tiene la suya en el pedestal de su base ("FlagStand").
--   - Un rival que la toca se la lleva a la espalda: va más lento (Config.Arena.CarrierSpeedMultiplier,
--     lo aplica LocomotionController), no puede usar Parpadeo ni Embestida ("MovementLocked") y todos
--     lo ven resaltado del color de la bandera, también a través de las paredes.
--   - Para puntuar, el portador la lleva a su propio pedestal mientras su bandera está en casa.
--   - Si el portador cae (o se va), la bandera queda en el suelo: un aliado del equipo dueño la
--     devuelve al tocarla y, si nadie la toca, vuelve sola tras Config.Arena.FlagReturnSeconds. Un
--     rival puede volver a cogerla.
--   - Fuera de la partida (espera, cuenta atrás, resultados), las dos están en casa.
-- El estado va en atributos de ReplicatedStorage para el HUD: "ArenaFlag_<equipo>" ("Home" |
-- "Carried" | "Dropped"), "ArenaFlagCarrier_<equipo>" (UserId) y "ArenaFlagReturnAt_<equipo>" (hora
-- del servidor). En el portador: "CarryingFlag" (equipo de la bandera que lleva) y "MovementLocked".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Sfx = require(ReplicatedStorage.Shared.Sfx)

local later = Strings.later
local FlagModel = require(script.Parent.Parent.World.FlagModel)
local ArenaMatchService = require(script.Parent.ArenaMatchService)
local ArenaWorldService = require(script.Parent.ArenaWorldService)
local RespawnService = require(script.Parent.RespawnService)

local TICK_SECONDS = 0.1
-- Cada cuánto se le recuerda al portador que su bandera no está en casa.
local HINT_SECONDS = 4
-- A la espalda: un poco por encima de los hombros, inclinada hacia un lado.
local CARRY_OFFSET = CFrame.new(0.4, 1.6, 0.75) * CFrame.Angles(0, 0, math.rad(-12))
local HIGHLIGHT_NAME = "FlagCarrier"

type State = "Home" | "Carried" | "Dropped"
type Flag = {
	teamId: string,
	model: Model,
	pole: BasePart,
	state: State,
	carrier: Player?,
	carrierCharacter: Model?,
	weld: WeldConstraint?,
	returnAt: number?,
}

local FlagService = {}

local flags: { [string]: Flag } = {}
local lastPosition: { [Player]: Vector3 } = {}
local hintedAt: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function teamText(teamId: string): string
	local team = Config.Arena.Teams[teamId]
	return `{team.icon} {team.name}`
end

local function publish(flag: Flag)
	ReplicatedStorage:SetAttribute(`ArenaFlag_{flag.teamId}`, flag.state)
	ReplicatedStorage:SetAttribute(`ArenaFlagCarrier_{flag.teamId}`, if flag.carrier then flag.carrier.UserId else nil)
	ReplicatedStorage:SetAttribute(`ArenaFlagReturnAt_{flag.teamId}`, flag.returnAt)
end

local function standOf(teamId: string): BasePart
	return ArenaWorldService.base(teamId):FindFirstChild("FlagStand") :: BasePart
end

-- Quita la bandera de la espalda de su portador (sin decidir adónde va).
local function release(flag: Flag)
	if flag.weld then
		flag.weld:Destroy()
		flag.weld = nil
	end
	local carrier = flag.carrier
	if carrier then
		carrier:SetAttribute("CarryingFlag", nil)
		carrier:SetAttribute("MovementLocked", nil)
		local highlight = flag.carrierCharacter and flag.carrierCharacter:FindFirstChild(HIGHLIGHT_NAME)
		if highlight then
			highlight:Destroy()
		end
	end
	flag.carrier = nil
	flag.carrierCharacter = nil
end

-- Deja la bandera quieta con la base del mástil en "ground".
local function standAt(flag: Flag, ground: Vector3)
	flag.pole.Anchored = true
	flag.model:PivotTo(CFrame.new(ground + Vector3.new(0, FlagModel.POLE_HEIGHT / 2, 0)))
end

local function sendHome(flag: Flag, message: string?, args: { [string]: any }?)
	release(flag)
	local stand = standOf(flag.teamId)
	standAt(flag, stand.Position + Vector3.new(0, stand.Size.Y / 2, 0))
	flag.state = "Home"
	flag.returnAt = nil
	publish(flag)
	if message then
		Remotes.Notify:FireAllClients(message, args)
		Sfx.play("Pickup", flag.pole)
	end
end

local function pickUp(flag: Flag, player: Player, character: Model)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	flag.pole.Anchored = false
	flag.model:PivotTo(torso.CFrame * CARRY_OFFSET)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = flag.pole
	weld.Parent = flag.pole
	flag.weld = weld
	flag.carrier = player
	flag.carrierCharacter = character
	flag.state = "Carried"
	flag.returnAt = nil
	player:SetAttribute("CarryingFlag", flag.teamId)
	player:SetAttribute("MovementLocked", true)
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.FillTransparency = 1
	highlight.OutlineColor = Config.Arena.Teams[flag.teamId].color
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	publish(flag)
	Sfx.play("Pickup", flag.pole)
	Remotes.Notify:FireAllClients(
		"🚩 ¡{name} se lleva la bandera {team}!",
		{ name = player.DisplayName, team = teamText(flag.teamId) }
	)
end

local function drop(flag: Flag, position: Vector3)
	local carrier = flag.carrier
	release(flag)
	-- El suelo, sin contar la bandera ni los personajes (el del portador caído sigue ahí).
	local ignore: { Instance } = { flag.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), params)
	-- Si cae fuera del mapa (al vacío), vuelve a casa.
	if not hit then
		sendHome(flag, later("↩️ La bandera {team} vuelve a su base"), { team = teamText(flag.teamId) })
		return
	end
	standAt(flag, hit.Position)
	flag.state = "Dropped"
	flag.returnAt = now() + Config.Arena.FlagReturnSeconds
	publish(flag)
	if carrier then
		Remotes.Notify:FireAllClients(
			"💥 ¡{name} ha soltado la bandera {team}!",
			{ name = carrier.DisplayName, team = teamText(flag.teamId) }
		)
	end
end

local function capture(player: Player, flag: Flag, ownTeam: string)
	local captures = player:GetAttribute("ArenaCaptures")
	player:SetAttribute("ArenaCaptures", (if typeof(captures) == "number" then captures else 0) + 1)
	sendHome(flag)
	ArenaMatchService.addCapture(ownTeam)
	Remotes.Notify:FireAllClients("🏆 ¡{name} captura la bandera {team}! {score}", {
		name = player.DisplayName,
		team = teamText(flag.teamId),
		score = `{Config.Arena.Teams.Jaguar.icon} {Arena.score("Jaguar")} · {Arena.score("Quetzal")} {Config.Arena.Teams.Quetzal.icon}`,
	})
end

-- Todas a casa (al cambiar de fase).
local function resetAll()
	for _, flag in flags do
		sendHome(flag)
	end
end

local function near(a: Vector3, b: Vector3, radius: number): boolean
	local offset = a - b
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= 6
end

local function tick()
	if not Arena.inBattle() then
		return
	end
	local settings = Config.Arena
	-- Portadores que ya no están (se fueron o cambiaron de personaje sin caer): la sueltan. Si caen,
	-- la suelta RespawnService.onDied, después de que este haya visto que la llevaban (reaparecen
	-- más tarde).
	for _, flag in flags do
		local carrier = flag.carrier
		if flag.state == "Carried" and carrier then
			if carrier.Parent == nil or carrier.Character ~= flag.carrierCharacter then
				drop(flag, lastPosition[carrier] or flag.pole.Position)
			end
		elseif flag.state == "Dropped" and flag.returnAt and now() >= flag.returnAt then
			sendHome(flag, later("↩️ La bandera {team} vuelve a su base"), { team = teamText(flag.teamId) })
		end
	end

	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if teamId and character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local position = root.Position
			lastPosition[player] = position
			local carrying = player:GetAttribute("CarryingFlag")
			for _, flag in flags do
				local flagBase = flag.pole.Position - Vector3.new(0, FlagModel.POLE_HEIGHT / 2, 0)
				if flag.state ~= "Carried" and near(position, flagBase, settings.FlagTouchRadius) then
					if flag.teamId ~= teamId and carrying == nil then
						pickUp(flag, player, character)
						carrying = flag.teamId
					elseif flag.teamId == teamId and flag.state == "Dropped" then
						sendHome(
							flag,
							later("↩️ {name} devuelve la bandera {team}"),
							{ name = player.DisplayName, team = teamText(flag.teamId) }
						)
					end
				end
			end
			-- Captura: con la rival a cuestas en el pedestal propio y la propia en casa.
			local carried = if typeof(carrying) == "string" then flags[carrying] else nil
			local stand = standOf(teamId)
			if carried and near(position, stand.Position, settings.CaptureRadius) then
				if flags[teamId].state == "Home" then
					capture(player, carried, teamId)
				elseif now() - (hintedAt[player] or 0) >= HINT_SECONDS then
					hintedAt[player] = now()
					Remotes.Notify:FireClient(player, "🚩 Tu bandera no está en casa: recupérala para puntuar")
				end
			end
		end
	end
end

function FlagService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Banderas"
	folder.Parent = Workspace
	for _, teamId in Arena.TEAM_IDS do
		local model = FlagModel.build(teamId)
		model.Parent = folder
		local flag: Flag = { teamId = teamId, model = model, pole = model.PrimaryPart :: BasePart, state = "Home" }
		flags[teamId] = flag
		sendHome(flag)
	end
	-- Fuera de la partida (y al empezarla) las dos en casa; en la muerte súbita se sigue igual.
	ReplicatedStorage:GetAttributeChangedSignal("ArenaPhase"):Connect(function()
		if Arena.phase() ~= "SuddenDeath" then
			resetAll()
		end
	end)
	RespawnService.onDied(function(player, position)
		for _, flag in flags do
			if flag.carrier == player then
				drop(flag, position)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, flag in flags do
			if flag.carrier == player then
				drop(flag, lastPosition[player] or flag.pole.Position)
			end
		end
		lastPosition[player] = nil
		hintedAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return FlagService
