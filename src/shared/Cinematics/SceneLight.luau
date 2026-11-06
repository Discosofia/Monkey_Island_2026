--!strict
-- Luces de relleno de las cinemáticas (Fase 25). Evento clock { hour, seconds? } y campo de escena hour: hora fija del
-- día (ver LightingController). Evento exposure { value } y evento light { pos, follow?, offset?, color?,
-- brightness?, range?, seconds? } (con follow = true la luz sigue a la cámara, desplazada offset en su espacio):
-- una PointLight local (solo la ve quien reproduce la escena) en pos, relativa al anchor. Sirve para las tomas
-- que caen de noche o al amanecer, donde el jefe sale oscuro. Se borran al acabar la escena; con seconds se
-- apagan solas con un fundido.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SceneLight = {}

local DEFAULT_COLOR = Color3.fromRGB(255, 226, 190)
local FADE_OUT_SECONDS = 0.4

local active: { Part } = {}
-- Luces que siguen a la cámara (follow = true): se recolocan cada cuadro, siempre a la misma distancia del jefe.
local followers: { { part: Part, offset: Vector3 } } = {}
local followConnection: RBXScriptConnection? = nil
-- Efecto de corrección de color de la escena (nil si no la tocó). LightingController reescribe Lighting.Exposure-
-- Compensation en cada cuadro, así que la subida va en un efecto aparte.
local lift: ColorCorrectionEffect? = nil

local function stopFollowing()
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	table.clear(followers)
end

-- Bloom de Lighting tocado por la escena, con sus valores originales para devolverlo al acabar.
local bloomSaved: { effect: BloomEffect, intensity: number, threshold: number }? = nil

local function restoreBloom()
	local saved = bloomSaved
	if saved then
		if saved.effect.Parent then
			saved.effect.Intensity = saved.intensity
			saved.effect.Threshold = saved.threshold
		end
		bloomSaved = nil
	end
end

local function clear()
	stopFollowing()
	restoreBloom()
	Lighting:SetAttribute("CinematicBrightnessScale", nil)
	Lighting:SetAttribute("CinematicClockTime", nil)
	Lighting:SetAttribute("CinematicClockSeconds", nil)
	if lift then
		lift:Destroy()
		lift = nil
	end
	for _, part in active do
		part:Destroy()
	end
	table.clear(active)
end

-- Pone las luces "follow" en la posición actual de la cámara más su desplazamiento.
local function placeFollowers()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	for _, follower in followers do
		follower.part.CFrame = CFrame.new(camera.CFrame:PointToWorldSpace(follower.offset))
	end
end

local function build(event: any, anchor: CFrame)
	local part = Instance.new("Part")
	part.Name = "CinematicLight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(anchor:PointToWorldSpace(event.pos or Vector3.zero))
	if event.follow == true then
		table.insert(followers, { part = part, offset = event.offset or Vector3.zero })
		if not followConnection then
			followConnection = RunService.PreRender:Connect(placeFollowers)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = event.color or DEFAULT_COLOR
	light.Brightness = event.brightness or 3
	light.Range = event.range or 40
	light.Shadows = false
	light.Parent = part
	part.Parent = Workspace
	table.insert(active, part)
	local seconds = event.seconds
	if typeof(seconds) == "number" and seconds > 0 then
		task.delay(math.max(seconds - FADE_OUT_SECONDS, 0), function()
			if part.Parent then
				TweenService:Create(light, TweenInfo.new(FADE_OUT_SECONDS), { Brightness = 0 }):Play()
				Debris:AddItem(part, FADE_OUT_SECONDS + 0.1)
			end
		end)
	end
end

-- Evento exposure { value, tint? }: levanta la imagen de quien ve la escena (solo brillo), sin quemar
-- a nadie con una luz cercana. value 0,5 ≈ brillo +0,09. Se quita sola al acabar.
local function setExposure(event: any)
	local value: number = event.value or 0.5
	local effect = lift
	if not effect then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "CinematicLift"
		effect.Parent = Lighting
		lift = effect
	end
	local grade = effect :: ColorCorrectionEffect
	grade.Brightness = value * 0.18
	-- tint (opcional): tinte de pantalla, por ejemplo cálido para un amanecer. Sin él, la imagen no se tiñe.
	grade.TintColor = event.tint or Color3.new(1, 1, 1)
end

-- Evento bloom { intensity?, threshold? }: rebaja el BloomEffect de Lighting mientras dura la escena (el halo sobre
-- lo claro o Neon quema los planos cercanos). Se guardan los valores de antes y se devuelven al acabar.
local function setBloom(event: any)
	local effect = Lighting:FindFirstChildOfClass("BloomEffect")
	if not effect then
		return
	end
	if not bloomSaved then
		bloomSaved = { effect = effect, intensity = effect.Intensity, threshold = effect.Threshold }
	end
	effect.Intensity = event.intensity or effect.Intensity
	effect.Threshold = event.threshold or effect.Threshold
end

-- Pone la hora fijada (LightingController la lee solo en la Isla; en los demás places no hace nada).
local function setClock(hour: any, seconds: any)
	if typeof(hour) ~= "number" then
		return
	end
	Lighting:SetAttribute("CinematicClockTime", hour % 24)
	Lighting:SetAttribute("CinematicClockSeconds", if typeof(seconds) == "number" then seconds else nil)
end

function SceneLight.install(sequencer: any)
	local built: { [any]: boolean } = {}
	-- Evento brightness { scale }: multiplica por scale (0..1) el brillo del mundo que escribe LightingController
	-- (solo en la Isla; en los demás places no hace nada). Se quita al acabar.
	sequencer.registerHandler("brightness", function(event: any)
		Lighting:SetAttribute("CinematicBrightnessScale", event.scale or 1)
	end)
	-- Evento clock { hour, seconds? }: fija la hora del día (0-24) que dibuja LightingController mientras dura
	-- la escena; seconds = duración del fundido hacia esa hora (0,4 s por defecto). Se quita al acabar.
	sequencer.registerHandler("clock", function(event: any)
		setClock(event.hour, event.seconds)
	end)
	sequencer.registerHandler("bloom", function(event: any)
		setBloom(event)
	end)
	sequencer.registerHandler("light", function(event: any, ctx: any)
		if built[event] then
			return -- un seek no repite la luz
		end
		built[event] = true
		build(event, ctx.anchor or CFrame.identity)
	end)
	sequencer.registerHandler("exposure", function(event: any)
		setExposure(event)
	end)
	sequencer.addHooks({
		start = function(scene: any)
			table.clear(built)
			clear()
			-- Campo hour de la escena: equivale a un evento clock a t = 0.
			if typeof(scene.hour) == "number" then
				setClock(scene.hour, nil)
			end
		end,
		finish = function()
			table.clear(built)
			clear()
		end,
	})
end

return SceneLight
