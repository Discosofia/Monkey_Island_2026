--!strict
-- Monturas: una clase nueva de mascota que el jugador monta. El modelo está en Shared/MountModels;
-- montarlas, en ServerShared/MountServer y UI/MountRiders.

export type Mount = {
	name: string,
	icon: string,
	rarity: string, -- Data/Rarities
	description: string,
	size: number, -- escala del modelo (1 = tamaño de MountModels)
	speed: number, -- multiplicador de Config.Mounts.Speed
	-- Gesto del botón montado (Y), sin daño: su texto, el marcador de la animación "Gesture" donde sale
	-- el efecto y el efecto (MountModels.gesture): "Spit" escupe y "Roar" ruge con una onda del aura.
	gesture: { label: string, marker: string, effect: string },
	-- Ids publicados de sus animaciones (fuente: ServerStorage.Tools.MonkeyAnimationSpecs.Monturas).
	-- Las vacías no suenan (y sin "Gesture" no hay gesto).
	animations: { Run: string, Idle: string, Gesture: string, Jump: string },
}

local Mounts: { [string]: Mount } = {
	Llama = {
		name = "Llama Andina",
		icon = "🦙",
		rarity = "Rare",
		description = "Una llama de lana blanca y negra con su manta tejida y sus lentes de sol.",
		size = 1,
		speed = 1,
		gesture = { label = "Escupir", marker = "Escupir", effect = "Spit" },
		-- Llama_Run, Llama_Idle, Llama_Spit y Llama_Jump (RBX_ANIMSAVES.Monturas), publicadas el 23-10-2026.
		animations = {
			Run = "rbxassetid://78162262130634",
			Idle = "rbxassetid://101537730193592",
			Gesture = "rbxassetid://76579660778464",
			Jump = "rbxassetid://99877257116286",
		},
	},
	-- Jaguar Albino Esmeralda (T5a, 27-10-2026): pelaje blanco y marfil, ojos esmeralda que brillan,
	-- rosetas de jade, silla azul marino y oro y un aura pastel que gira alrededor del cuerpo.
	Jaguar = {
		name = "Jaguar Albino Esmeralda",
		icon = "🐆",
		rarity = "Legendary",
		description = "Un jaguar albino de ojos esmeralda y rosetas de jade, envuelto en un aura de colores pastel.",
		-- Algo mayor que uno de verdad, para llevar al jinete: lomo a 3,6 studs (la llama, a 3,9) y 10,6 de
		-- largo con la cola.
		size = 1.1,
		speed = 1.1,
		gesture = { label = "Rugir", marker = "Rugido", effect = "Roar" },
		-- Jaguar_Run, Jaguar_Idle, Jaguar_Roar y Jaguar_Jump (RBX_ANIMSAVES.Monturas), publicadas el 27-10-2026.
		animations = {
			Run = "rbxassetid://101523582801556",
			Idle = "rbxassetid://85024378724413",
			Gesture = "rbxassetid://92313145396935",
			Jump = "rbxassetid://72368012436036",
		},
	},
}

return Mounts
