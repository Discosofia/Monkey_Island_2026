--!strict
-- Altar de la cima de la pirámide (Fase 10, C11): cómo se ve en este cliente lo que decide AltarService
-- (atributos "Altar…" de ReplicatedStorage, ver su cabecera):
--   - Apagado: gemas y glifo de piedra, sin haz; el cartel dice cuánto falta para que se encienda.
--   - Encendido: gemas, glifo y un haz de luz blancos que se ven desde toda la arena (blanco y no dorado:
--     el dorado se confunde con el naranja del Jaguar). Mientras un equipo lo toma, todo pasa del blanco a
--     su color según su barra; disputado, parpadea entre los dos.
--   - Encima, un cartel con el estado y la barra de la captura.
-- La ventaja del equipo que lo toma se ve en el HUD (ArenaHUDController) y en la casilla de la V.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local NEUTRAL = Color3.fromRGB(250, 245, 230)
local STONE = Color3.fromRGB(150, 132, 104)
local GLYPH_OFF = Color3.fromRGB(110, 94, 72)
local BAR_BACK = Color3.fromRGB(30, 24, 18)
local BEAM_TRANSPARENCY = 0.55
-- El glifo encendido, un poco transparente para que no deslumbre a quien está encima.
local GLYPH_TRANSPARENCY = 0.35

local AltarController = {}

local function attribute(name: string): any
	return ReplicatedStorage:GetAttribute(name)
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function teamColor(teamId: any): Color3?
	return if Arena.isTeam(teamId) then Config.Arena.Teams[teamId :: string].color else nil
end

function AltarController:Start()
	local altar = Workspace:WaitForChild("Arena"):WaitForChild("Altar") :: Model
	local capture = altar:WaitForChild("Captura") :: BasePart
	local beam = altar:WaitForChild("Haz") :: BasePart
	local glyph = altar:WaitForChild("Glifo") :: BasePart
	local gems: { BasePart } = {}
	for _, child in altar:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Gema" then
			table.insert(gems, child)
		end
	end

	-- Cartel con el estado y la barra.
	local sign = Instance.new("BillboardGui")
	sign.Name = "AltarSign"
	sign.Adornee = capture
	sign.Size = UDim2.fromOffset(170, 46)
	sign.StudsOffset = Vector3.new(0, 9, 0)
	sign.MaxDistance = 260
	sign.LightInfluence = 0
	sign.Parent = capture
	local title = Widgets.label("", sign)
	title.Size = UDim2.new(1, 0, 0, 24)
	title.TextStrokeTransparency = 0.2
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0.1, 0, 0, 28)
	back.Size = UDim2.new(0.8, 0, 0, 12)
	back.BackgroundColor3 = BAR_BACK
	back.BackgroundTransparency = 0.25
	back.Parent = sign
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 6)
	backCorner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	RunService.RenderStepped:Connect(function()
		local state = attribute("AltarState")
		local active = state == "Active" and Arena.inBattle()
		local progress = attribute("AltarProgress")
		local amount = if typeof(progress) == "number" then progress else 0
		local owner = attribute("AltarTeam")
		local contested = attribute("AltarContested") == true
		local color = NEUTRAL
		local ownerColor = teamColor(owner)
		if contested then
			-- Parpadea entre los colores de los dos equipos.
			local first = os.clock() % 0.6 < 0.3
			color = Config.Arena.Teams[if first then "Jaguar" else "Quetzal"].color
		elseif ownerColor then
			color = NEUTRAL:Lerp(ownerColor, math.clamp(amount, 0, 1))
		end
		for _, gem in gems do
			gem.Color = if active then color else STONE
		end
		glyph.Color = if active then color else GLYPH_OFF
		glyph.Transparency = if active then GLYPH_TRANSPARENCY else 0
		-- El haz respira un poco para que se note desde lejos.
		beam.Transparency = if active then BEAM_TRANSPARENCY + 0.1 * math.sin(os.clock() * 3) else 1
		beam.Color = color

		sign.Enabled = Arena.inBattle()
		back.Visible = active
		fill.Size = UDim2.fromScale(math.clamp(amount, 0, 1), 1)
		fill.BackgroundColor3 = ownerColor or NEUTRAL
		if not active then
			local readyAt = attribute("AltarReadyAt")
			local left = if typeof(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
			title.Text = Strings.t("⛩️ Altar en {time}", { time = clock(left) })
		elseif contested then
			title.Text = Strings.t("⛩️ ⚔️ ¡Disputado!")
		elseif ownerColor then
			title.Text = `⛩️ {Config.Arena.Teams[owner].icon} {math.floor(amount * 100)} %`
		else
			title.Text = Strings.t("⛩️ ¡Tómalo!")
		end
	end)
end

return AltarController
