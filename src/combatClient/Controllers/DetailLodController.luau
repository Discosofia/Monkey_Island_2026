--!strict
-- LOD de detalle de los cosméticos de los otros jugadores (Fase 16, R5). VoxelMerge marca con la etiqueta
-- "Detalle" las piezas de armas y armaduras con el lado mayor por debajo de Config.Budgets.Lod.DetailMaxSize.
-- A más de DetailDistance studs de la cámara esas piezas se vuelven invisibles solo para este cliente
-- (LocalTransparencyModifier = 1): se siguen contando para la física pero no se dibujan. Hay histéresis de
-- 5 studs a cada lado para que no parpadeen en el límite. El personaje propio se ve siempre completo.
-- Revisa unos 2 personajes por fotograma y cada uno cada CheckSeconds, no todos a la vez.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local VoxelMerge = require(ReplicatedStorage.Shared.VoxelMerge)

local Lod = Config.Budgets.Lod
local HYSTERESIS = 5 -- studs a cada lado de DetailDistance
local PER_FRAME = 2 -- personajes revisados por fotograma como máximo

type Entry = {
	character: Model,
	parts: { BasePart },
	dirty: boolean,
	hidden: boolean,
	nextCheck: number,
	connections: { RBXScriptConnection },
}

local DetailLodController = {}

local entries: { Entry } = {}
local byCharacter: { [Model]: Entry } = {}
local cursor = 1

local function collect(entry: Entry)
	local parts: { BasePart } = {}
	for _, descendant in entry.character:GetDescendants() do
		if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, VoxelMerge.DETAIL_TAG) then
			table.insert(parts, descendant)
		end
	end
	entry.parts = parts
	entry.dirty = false
end

local function apply(entry: Entry)
	local value = if entry.hidden then 1 else 0
	for _, part in entry.parts do
		if part.LocalTransparencyModifier ~= value then
			part.LocalTransparencyModifier = value
		end
	end
end

local function release(character: Model)
	local entry = byCharacter[character]
	if not entry then
		return
	end
	byCharacter[character] = nil
	local index = table.find(entries, entry)
	if index then
		table.remove(entries, index)
	end
	for _, connection in entry.connections do
		connection:Disconnect()
	end
end

local function track(character: Model)
	release(character)
	local entry: Entry = {
		character = character,
		parts = {},
		dirty = true,
		hidden = false,
		nextCheck = 0,
		connections = {},
	}
	local function markDirty()
		entry.dirty = true
	end
	table.insert(entry.connections, character.DescendantAdded:Connect(markDirty))
	table.insert(entry.connections, character.DescendantRemoving:Connect(markDirty))
	table.insert(
		entry.connections,
		character.Destroying:Connect(function()
			release(character)
		end)
	)
	byCharacter[character] = entry
	table.insert(entries, entry)
end

local function watch(player: Player)
	if player == Players.LocalPlayer then
		return
	end
	player.CharacterAdded:Connect(track)
	player.CharacterRemoving:Connect(release)
	if player.Character then
		track(player.Character)
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	local total = #entries
	if not camera or total == 0 then
		return
	end
	local now = os.clock()
	local eye = camera.CFrame.Position
	local show = Lod.DetailDistance - HYSTERESIS
	local hide = Lod.DetailDistance + HYSTERESIS
	local checked = 0
	for _ = 1, total do
		if checked >= PER_FRAME then
			break
		end
		if cursor > total then
			cursor = 1
		end
		local entry = entries[cursor]
		cursor += 1
		if entry and now >= entry.nextCheck then
			checked += 1
			entry.nextCheck = now + Lod.CheckSeconds
			if entry.dirty then
				collect(entry)
				apply(entry)
			end
			local root = entry.character.PrimaryPart
			if root then
				local distance = (root.Position - eye).Magnitude
				local hidden = entry.hidden
				if hidden and distance < show then
					hidden = false
				elseif not hidden and distance > hide then
					hidden = true
				end
				if hidden ~= entry.hidden then
					entry.hidden = hidden
					apply(entry)
				end
			end
		end
	end
end

function DetailLodController:Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	RunService.Heartbeat:Connect(update)
end

return DetailLodController
