--!strict
-- Calendario de 7 días dibujado como casillas (bucle de retención, octubre de 2026): la ventana que
-- sale al entrar al Lobby (CalendarController) y la pestaña Misiones (LobbyUIController) usan esta
-- misma pieza. Dos filas para que se lea en un teléfono: días 1–4 arriba y 5–7 abajo, con el 7 (el
-- del huevo) el doble de ancho y en dorado.
--   - Cobrado: apagado y con ✅.
--   - El de hoy, si se puede cobrar: borde dorado.
--   - El siguiente, si hoy ya se cobró: "Mañana".

local Config = require(script.Parent.Parent.Config)
local Daily = require(script.Parent.Parent.Daily)
local Rewards = require(script.Parent.Parent.Rewards)
local Strings = require(script.Parent.Parent.Strings)
local Widgets = require(script.Parent.Widgets)

local CalendarStrip = {}

local CELL_COLOR = Color3.fromRGB(45, 38, 30)
local BIG_CELL_COLOR = Color3.fromRGB(70, 52, 20)
local GOLD = Color3.fromRGB(242, 178, 36)
local DIM_TEXT = Color3.fromRGB(160, 150, 135)
local TEXT = Color3.fromRGB(230, 220, 200)

export type CellState = "Claimed" | "Today" | "Tomorrow" | "Later"

-- Estado de cada casilla. Si hoy ya se cobró el 7, se ve la semana entera cobrada hasta mañana.
function CalendarStrip.states(state: Daily.LoginState, now: number): { CellState }
	local claimable = Daily.canClaim(state, now)
	local weekDone = not claimable and state.step == 1 and state.lastClaimDay > 0
	local states: { CellState } = {}
	for day = 1, Daily.CALENDAR_DAYS do
		if weekDone or day < state.step then
			states[day] = "Claimed"
		elseif day == state.step then
			states[day] = if claimable then "Today" else "Tomorrow"
		else
			states[day] = "Later"
		end
	end
	return states
end

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function cell(row: Frame, day: number, width: number, cellState: CellState)
	local big = day == Daily.CALENDAR_DAYS
	local frame = Instance.new("Frame")
	frame.Name = `Dia{day}`
	frame.LayoutOrder = day
	frame.Size = UDim2.new(width, -6, 1, 0)
	frame.BackgroundColor3 = if big then BIG_CELL_COLOR else CELL_COLOR
	frame.BackgroundTransparency = if cellState == "Claimed" then 0.55 else 0.1
	frame.Parent = row
	corner(frame, 8)
	if cellState == "Today" or big then
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = if cellState == "Today" then 3 else 1
		stroke.Parent = frame
	end

	local dayText = Strings.t("Día {day}", { day = day })
	local title = Widgets.label(
		if cellState == "Claimed"
			then `✅ {dayText}`
			elseif cellState == "Tomorrow" then Strings.t("Día {day} · mañana", { day = day })
			elseif big then `⭐ {dayText}`
			else dayText,
		frame
	)
	title.Position = UDim2.fromScale(0.05, 0.05)
	title.Size = UDim2.fromScale(0.9, 0.36)
	title.TextColor3 = if cellState == "Today" or big then GOLD else Color3.new(1, 1, 1)

	local reward = Widgets.label(Rewards.compact(Config.Daily.Calendar[day]), frame)
	reward.Position = UDim2.fromScale(0.05, 0.44)
	reward.Size = UDim2.fromScale(0.9, 0.5)
	reward.TextWrapped = true
	reward.TextColor3 = if cellState == "Claimed" then DIM_TEXT else TEXT
end

-- Crea el calendario dentro de "parent" (ocupa todo su tamaño) y lo devuelve.
function CalendarStrip.build(parent: GuiObject, state: Daily.LoginState, now: number): Frame
	local states = CalendarStrip.states(state, now)
	local strip = Instance.new("Frame")
	strip.Name = "Calendario"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromScale(1, 1)
	strip.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = strip

	-- Arriba los días 1 a 4; abajo el resto, con el último del doble de ancho.
	local rows = { { first = 1, last = 4 }, { first = 5, last = Daily.CALENDAR_DAYS } }
	for index, range in rows do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0.5, -3)
		row.Parent = strip
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.Parent = row
		for day = range.first, range.last do
			local width = if day == Daily.CALENDAR_DAYS then 0.5 else 0.25
			cell(row, day, width, states[day])
		end
	end
	return strip
end

return CalendarStrip
