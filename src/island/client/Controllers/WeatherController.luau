--!strict
-- Efectos del clima en el cliente (Fase 5): gotas de lluvia alrededor de la cámara, cielo más oscuro
-- con tormenta, destellos de los rayos y un tono rojizo durante la erupción del volcán.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WeatherController = {}

function WeatherController:Start()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WeatherTint"
	tint.Parent = Lighting

	-- Pieza invisible encima de la cámara que suelta las gotas.
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "RainEmitter"
	emitterPart.Size = Vector3.new(80, 1, 80)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Parent = Workspace
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(180, 200, 230))
	rain.Size = NumberSequence.new(0.15)
	rain.Transparency = NumberSequence.new(0.35)
	rain.Lifetime = NumberRange.new(0.8, 1.2)
	rain.Speed = NumberRange.new(70, 90)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.LightEmission = 0.2
	rain.Rate = 0
	rain.Parent = emitterPart

	local function apply()
		local weather = ReplicatedStorage:GetAttribute("Weather")
		local eruption = ReplicatedStorage:GetAttribute("Eruption") == true
		rain.Rate = if weather == "Storm" then 900 elseif weather == "Rain" then 450 else 0
		local goal = {
			Brightness = if weather == "Storm" then -0.12 elseif weather == "Rain" then -0.05 else 0,
			Saturation = if weather == "Clear" or weather == nil then 0 else -0.2,
			TintColor = if eruption then Color3.fromRGB(255, 215, 190) else Color3.new(1, 1, 1),
		}
		TweenService:Create(tint, TweenInfo.new(3), goal):Play()
	end
	ReplicatedStorage:GetAttributeChangedSignal("Weather"):Connect(apply)
	ReplicatedStorage:GetAttributeChangedSignal("Eruption"):Connect(apply)
	apply()

	-- Destello del rayo justo cuando cae.
	ReplicatedStorage:GetAttributeChangedSignal("LightningAt"):Connect(function()
		local at = ReplicatedStorage:GetAttribute("LightningAt")
		if typeof(at) ~= "number" then
			return
		end
		task.wait(math.max(0, at - Workspace:GetServerTimeNow()))
		local flash = Instance.new("ColorCorrectionEffect")
		flash.Brightness = 0.6
		flash.Parent = Lighting
		TweenService:Create(flash, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		task.delay(0.5, function()
			flash:Destroy()
		end)
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
		end
	end)
end

return WeatherController
