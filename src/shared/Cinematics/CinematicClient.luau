--!strict
-- Lado cliente de las cinemáticas del juego (Fase 25, G1b), común a la Isla y al Lobby. Cada
-- CinematicController es una línea que llama a CinematicClient.start(place).
--
-- Escucha Remotes.Cinematic: ("Play", id, startServerTime, args?) y ("Stop", id). Con el ajuste «Cinemáticas»
-- apagado responde enseguida CinematicDone(id, false) y no enseña nada. Si no: apaga los controles, oculta el
-- HUD (menos el ScreenGui de la cinemática), reproduce la escena con el Sequencer (con seek si llega tarde) y
-- al acabar (+0,4 s) lo devuelve todo y avisa al servidor con CinematicDone(id, vista_entera).
-- El botón «Saltar» sale si la escena ya está en cinematicsSeen del atributo Progress, o si es skippable.
--
-- Maniquí: Actors ya crea el rig R15 con Players:CreateHumanoidModelFromDescription (no es de uso restringido
-- y también corre en el cliente). La fábrica que se registra aquí es solo la salida de emergencia: si existe
-- una plantilla "CinematicDummy" (Model R15) en ReplicatedStorage.Shared la clona; si no, devuelve nil y
-- Actors sigue con su camino normal.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(script.Parent.Actors)
local Comic = require(script.Parent.Comic)
local Cinematics = require(script.Parent.Parent.Data.Cinematics)
local HudHider = require(script.Parent.Parent.UI.HudHider)
local Presentation = require(script.Parent.Presentation)
local Remotes = require(script.Parent.Parent.Remotes)
local Sequencer = require(script.Parent.Sequencer)
local Settings = require(script.Parent.Parent.Settings)
local Strings = require(script.Parent.Parent.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local T = Strings.t

local CinematicClient = {}

local END_DELAY = 0.4 -- espera antes de devolver el HUD, para que un fundido final no se corte de golpe
local TEMPLATE_NAME = "CinematicDummy"

type Active = {
	id: string,
	handle: Sequencer.Handle,
	stoppedByServer: boolean,
}

local active: Active? = nil

-- Escenas ya vistas por el jugador (cinematicsSeen del JSON de Progress; lista o mapa, tolerante).
local function hasSeen(id: string): boolean
	local player = Players.LocalPlayer
	local raw = player:GetAttribute("Progress")
	if typeof(raw) ~= "string" then
		return false
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not (ok and typeof(decoded) == "table") then
		return false
	end
	local seen = decoded.cinematicsSeen
	if typeof(seen) ~= "table" then
		return false
	end
	return seen[id] == true or table.find(seen, id) ~= nil
end

local function setControls(enabled: boolean)
	pcall(function()
		-- Sin esperas: la escena no puede retrasarse (el servidor la da por acabada a duration + margen).
		local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then
			return
		end
		local controls = (require(module :: ModuleScript) :: any):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

-- Dónde se ancla la escena: args.anchor, o el jefe si scene.anchor = "boss", o los pies del personaje.
local function resolveAnchor(scene: Cinematics.Scene, args: { [string]: any }): CFrame
	if typeof(args.anchor) == "CFrame" then
		return args.anchor
	end
	if scene.anchor == "boss" then
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Model") then
				local boss = descendant:GetAttribute("Boss")
				if boss ~= nil and (args.bossId == nil or boss == args.bossId) then
					local cf, size = descendant:GetBoundingBox()
					return CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z) * cf.Rotation
				end
			end
		end
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local lift = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
		return CFrame.new(root.Position - Vector3.new(0, lift, 0)) * root.CFrame.Rotation
	end
	return CFrame.identity
end

local function play(id: string, startServerTime: number, args: { [string]: any }?)
	local params = args or {}
	local scene = Cinematics[id]
	if not scene then
		warn(`CinematicClient: escena desconocida ({id})`)
		Remotes.CinematicDone:FireServer(id, false)
		return
	end
	if not Settings.get().cinematics then
		Remotes.CinematicDone:FireServer(id, false)
		return
	end
	if active then
		active.handle.stop()
	end

	local entry: Active? = nil
	local gui = Presentation.gui()
	HudHider.hide(if gui then { gui } else nil)
	setControls(false)

	local finished = false
	local function onFinished(completed: boolean)
		if finished then
			return
		end
		finished = true
		local mine = entry
		task.delay(END_DELAY, function()
			HudHider.restore()
			setControls(true)
			if mine and active == mine then
				active = nil
			end
			if not (mine and mine.stoppedByServer) then
				Remotes.CinematicDone:FireServer(id, completed)
			end
		end)
	end

	local handle = Sequencer.play(scene :: any, { anchor = resolveAnchor(scene, params), onFinished = onFinished })
	entry = { id = id, handle = handle, stoppedByServer = false }
	active = entry

	-- Botón Saltar (abajo a la derecha, dentro del ScreenGui de la cinemática: se borra solo al terminar).
	if gui and handle.isPlaying() and (hasSeen(id) or (scene :: any).skippable == true) then
		local skip = Widgets.button(T("Saltar"), gui)
		skip.Name = "Skip"
		skip.AnchorPoint = Vector2.new(1, 1)
		skip.Position = UDim2.new(1, -24, 1, -24)
		skip.Size = UDim2.fromOffset(160, 48)
		skip.ZIndex = 20
		skip.Activated:Connect(function()
			skip.Visible = false
			handle.skip()
		end)
	end

	-- Llega tarde (entró a mitad de escena o hubo retraso): salta al tiempo que le toca.
	local late = workspace:GetServerTimeNow() - startServerTime
	if late > 0.1 and handle.isPlaying() then
		handle.seek(late)
	end
end

-- "place" solo sirve para los avisos; los dos places cargan CombatClient, así que el animador es el mismo.
function CinematicClient.start(place: string)
	Presentation.install(Sequencer)
	Actors.install(Sequencer)
	Comic.install(Sequencer)

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	Actors.setDummyFactory(function()
		local template = if shared then shared:FindFirstChild(TEMPLATE_NAME) else nil
		if template and template:IsA("Model") then
			return template:Clone()
		end
		return nil
	end)

	local combatClient = ReplicatedStorage:FindFirstChild("CombatClient")
	local bodyModule = if combatClient then combatClient:FindFirstChild("BodyAnimations") else nil
	if bodyModule and bodyModule:IsA("ModuleScript") then
		local BodyAnimations = require(bodyModule) :: any
		Actors.setAnimator(function(actor, action, event)
			BodyAnimations.playOn(actor, action, event.seconds or 2)
		end)
	else
		warn(`CinematicClient({place}): sin CombatClient; los eventos anim no harán nada`)
	end

	Remotes.Cinematic.OnClientEvent:Connect(function(kind: string, id: string, startServerTime: number?, args: any?)
		if kind == "Play" then
			play(id, startServerTime or workspace:GetServerTimeNow(), args)
		elseif kind == "Stop" then
			local current = active
			if current and current.id == id then
				current.stoppedByServer = true
				current.handle.stop()
			end
		end
	end)
end

return CinematicClient
