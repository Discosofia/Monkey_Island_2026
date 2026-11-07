--!strict
-- Efectos de fiesta compartidos (confeti de bloquecitos y cohetes). Los usan la fiesta del Lobby
-- (lobby/PartyController) y la celebración del aro del Juego de pelota (dunas/BallReplayController). Todo se dibuja en
-- el cliente con Parts ancladas sin colisión; la paleta y los puntos de salida y de caída los pone quien llama. Solo cliente.

local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)

local PartyFx = {}

local rng = Random.new()

-- Paleta de la fiesta del Lobby (sin verde, morado ni rojo: curación, veneno y daño).
PartyFx.PARTY_COLORS = {
	Color3.fromRGB(255, 205, 70), -- oro
	Color3.fromRGB(120, 230, 255), -- cian
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 50), -- naranja
	Color3.fromRGB(90, 160, 255), -- azul
}

local function anchor(position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(6, 1, 6)
	part.Position = position
	part.Parent = parent
	return part
end

export type ConfettiOptions = {
	size: Vector3?, -- por defecto 0,35 × 0,08 × 0,35
	linger: number?, -- segundos que se queda en el suelo tras caer (por defecto 3)
}

-- Un bloquecito de color que cae girando de "from" a "to" en "seconds" y se queda un momento. Devuelve la pieza
-- (se destruye sola), para que quien llama pueda contar las vivas.
function PartyFx.confettiPiece(
	folder: Instance,
	from: Vector3,
	to: Vector3,
	palette: { Color3 },
	seconds: number,
	options: ConfettiOptions?
): Part
	local opts = options or {}
	local piece = anchor(from, folder)
	piece.Size = opts.size or Vector3.new(0.35, 0.08, 0.35)
	piece.Transparency = 0
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = palette[rng:NextInteger(1, #palette)]
	piece.CFrame = CFrame.new(from) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
	TweenService:Create(
		piece,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(to) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) }
	):Play()
	task.delay(seconds + (opts.linger or 3), function()
		piece:Destroy()
	end)
	return piece
end

-- Un cohete que sube "height" studs desde "from" y estalla en un color de la paleta.
function PartyFx.firework(folder: Instance, from: Vector3, palette: { Color3 }, height: number)
	local color = palette[rng:NextInteger(1, #palette)]
	local rocket = anchor(from, folder)
	rocket.Size = Vector3.new(0.5, 0.5, 0.5)
	rocket.Transparency = 0
	rocket.Material = Enum.Material.Neon
	rocket.Color = color
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(color)
	trail.Size = NumberSequence.new(0.3, 0)
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(0.4)
	trail.Speed = NumberRange.new(0)
	trail.LightEmission = 1
	trail.Parent = rocket
	local rise = TweenService:Create(
		rocket,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = from + Vector3.new(0, height, 0) }
	)
	rise.Completed:Connect(function()
		trail.Enabled = false
		rocket.Transparency = 1
		local burst = Instance.new("ParticleEmitter")
		burst.Color = ColorSequence.new(color)
		burst.Size = NumberSequence.new(0.6, 0)
		burst.Lifetime = NumberRange.new(1, 1.6)
		burst.Speed = NumberRange.new(18, 26)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 2.5
		burst.Acceleration = Vector3.new(0, -8, 0)
		burst.LightEmission = 1
		burst.Rate = 0
		burst.Parent = rocket
		burst:Emit(70)
		Sfx.play("Firework", rocket.Position)
		task.delay(2, function()
			rocket:Destroy()
		end)
	end)
	rise:Play()
end

return PartyFx
