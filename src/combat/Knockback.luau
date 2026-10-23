--!strict
-- Empujones de los golpes (Fase 10, C2): la Embestida y, desde C4 y C10, el remate de la cadena, el
-- Rompehuesos y el rebote contra muros.
--   - A un mono (lo simula el servidor) se le da la velocidad aquí mismo, con un pequeño salto.
--   - A un jugador lo simula su propio cliente: si el servidor le pusiera la velocidad, su cliente la
--     pisaría. Se le manda el remoto Knockback y lo aplica KnockbackController con Dash.push (fuerza
--     limitada y corte contra las paredes).
-- Los jefes no se empujan. Un jugador lanzado hacia arriba queda "lanzado" ("LaunchedUntil", hora del
-- servidor en que vuelve a caer) y puede salir con el Evasivo (C7, Shared/CombatState.isTrapped).
-- Rebote contra muros (C10, Config.WallBang): si el empujón lo da un jugador, el servidor mira con
-- Hitbox.ray la trayectoria (velocidad × segundos, más el cuerpo). Si hay una pared, una roca o terreno
-- empinado, al llegar (si de verdad llega en ArriveWindowSeconds: no se ha apartado con el Evasivo ni un
-- mono se ha frenado antes) rebota: lo que hace el rebote (daño, aturdido, efecto) lo pone quien lo registra con
-- Knockback.onWallBang (CombatService). Después, ImmunitySeconds sin otro rebote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Hitbox = require(script.Parent.Hitbox)
local Latency = require(script.Parent.Latency)

export type WallBang = (model: Model, attacker: Player, point: Vector3, normal: Vector3) -> ()

local Knockback = {}

-- Velocidad hacia arriba que se suma al empujar a un mono (sale un poco del suelo y no se arrastra).
local ENEMY_LIFT = 20

local onBang: WallBang? = nil
-- Hasta cuándo (hora del servidor) no puede volver a rebotar cada modelo.
local bangImmuneUntil: { [Model]: number } = setmetatable({} :: any, { __mode = "k" })

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Qué hace un rebote (CombatService:Start).
function Knockback.onWallBang(callback: WallBang)
	onBang = callback
end

-- La pared que encontrará "root" empujado en "horizontal" (unitario) "travel" studs, o nil.
local function wallAhead(root: BasePart, horizontal: Vector3, travel: number): RaycastResult?
	local hit = Hitbox.ray(root.Position, horizontal * (travel + Config.WallBang.BodyReach))
	if hit and hit.Normal.Y <= Config.WallBang.MaxNormalY then
		return hit
	end
	return nil
end

-- Si el empujón de "attacker" lleva a "model" contra una pared, rebota al llegar.
local function watchWall(model: Model, attacker: Player, horizontal: Vector3, speed: number, seconds: number)
	local settings = Config.WallBang
	local root = Hitbox.rootOf(model)
	if not (root and onBang) or now() < (bangImmuneUntil[model] or 0) then
		return
	end
	local hit = wallAhead(root, horizontal, speed * seconds)
	if not hit then
		return
	end
	local wait = math.max(0, hit.Distance - settings.BodyReach) / speed
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		-- Su cliente lo mueve cuando le llega el aviso y el servidor lo ve llegar otro ping después.
		wait += 2 * Latency.compensation(victim) + Config.Net.JitterSeconds
	end
	task.delay(wait, function()
		local giveUp = os.clock() + settings.ArriveWindowSeconds
		while true do
			local callback = onBang
			if not (callback and root.Parent and model.Parent) or now() < (bangImmuneUntil[model] or 0) then
				return
			end
			-- Tiene que estar contra la pared (en la línea de su normal).
			if (root.Position - hit.Position):Dot(hit.Normal) <= settings.BodyReach + settings.ArriveSlack then
				bangImmuneUntil[model] = now() + settings.ImmunitySeconds
				callback(model, attacker, hit.Position, hit.Normal)
				return
			end
			if os.clock() >= giveUp then
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Empuja a "model" en "direction" (se aplana) a "speed" studs/s durante "seconds". Con "lift" lo lanza
-- además hacia arriba a esos studs/s (el remate de la cadena dado en el aire). Si lo empuja un jugador
-- ("attacker"), puede rebotar contra un muro.
function Knockback.push(
	model: Model,
	direction: Vector3,
	speed: number,
	seconds: number,
	lift: number?,
	attacker: Player?
)
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.01 or model:GetAttribute("Boss") ~= nil then
		return
	end
	horizontal = horizontal.Unit
	if attacker then
		watchWall(model, attacker, horizontal, speed, seconds)
	end
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		Remotes.Knockback:FireClient(player, horizontal, speed, seconds, lift)
		if lift and lift > 0 then
			-- Lo que tarda en subir y bajar con esa velocidad.
			player:SetAttribute("LaunchedUntil", now() + 2 * lift / Workspace.Gravity)
		end
		return
	end
	local root = model.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = horizontal * speed + Vector3.new(0, lift or ENEMY_LIFT, 0)
	end
end

return Knockback
