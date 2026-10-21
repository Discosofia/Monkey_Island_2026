--!strict
-- Estado público del contrato de expedición de la partida (Fase 9, G6; Data/Contracts). El servidor
-- (ContractService) lo escribe como JSON en el atributo "Contract" de ReplicatedStorage y los clientes
-- lo leen para la tarjeta del HUD y la pantalla de resultados.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(script.Parent.Data.Contracts)

local ATTRIBUTE = "Contract"

export type Status = "locked" | "active" | "done" | "failed"

export type StepState = {
	status: Status,
	progress: number,
	target: number, -- ya con el tamaño del grupo
}

export type State = {
	id: string,
	index: number, -- el paso abierto (o el último que se abrió)
	steps: { StepState },
}

local Contract = {}

Contract.ATTRIBUTE = ATTRIBUTE

-- Solo el servidor debe llamarla.
function Contract.write(state: State)
	ReplicatedStorage:SetAttribute(ATTRIBUTE, HttpService:JSONEncode(state))
end

-- Devuelve nil si aún no hay contrato (o el que hay no existe en Data/Contracts).
function Contract.read(): State?
	local raw = ReplicatedStorage:GetAttribute(ATTRIBUTE)
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or typeof(decoded) ~= "table" or not Contracts[decoded.id] or typeof(decoded.steps) ~= "table" then
		return nil
	end
	return decoded :: State
end

-- Texto del paso con su objetivo ("Construid 3 piezas").
function Contract.stepText(step: Contracts.Step, target: number): string
	return (string.gsub(step.text, "{target}", tostring(target)))
end

-- Días en que está abierto el paso "index" ("días 3–4", "día 7").
function Contract.daysText(contract: Contracts.Contract, index: number): string
	local step = contract.steps[index]
	local nextStep = contract.steps[index + 1]
	if nextStep and nextStep.day - 1 > step.day then
		return `días {step.day}–{nextStep.day - 1}`
	end
	return `día {step.day}`
end

-- Pasos cumplidos.
function Contract.doneCount(state: State): number
	local done = 0
	for _, step in state.steps do
		if step.status == "done" then
			done += 1
		end
	end
	return done
end

return Contract
