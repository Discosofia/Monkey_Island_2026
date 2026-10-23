--!strict
-- Monturas: una clase nueva de mascota que el jugador monta. Por ahora solo el modelo
-- (Shared/MountModels); cómo se consiguen y cómo se montan está por decidir.

export type Mount = {
	name: string,
	icon: string,
	rarity: string, -- Data/Rarities
	description: string,
	size: number, -- escala del modelo (1 = tamaño de MountModels)
	speed: number, -- multiplicador de Config.Mounts.Speed
	-- Ids publicados de sus animaciones (fuente: ServerStorage.Tools.MonkeyAnimationSpecs.Monturas).
	-- Spit lleva el marcador "Escupir", donde se llama a MountModels.spit.
	animations: { Run: string, Idle: string, Spit: string?, Jump: string },
}

local Mounts: { [string]: Mount } = {
	Llama = {
		name = "Llama Andina",
		icon = "🦙",
		rarity = "Rare",
		description = "Una llama de lana blanca y negra con su manta tejida y sus gafas de sol.",
		size = 1,
		speed = 1,
		-- Llama_Run, Llama_Idle, Llama_Spit y Llama_Jump (RBX_ANIMSAVES.Monturas), publicadas el 23-10-2026.
		animations = {
			Run = "rbxassetid://78162262130634",
			Idle = "rbxassetid://101537730193592",
			Spit = "rbxassetid://76579660778464",
			Jump = "rbxassetid://99877257116286",
		},
	},
}

return Mounts
