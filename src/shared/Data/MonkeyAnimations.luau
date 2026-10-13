--!strict
-- Animaciones de los monos y los jefes (las reproduce el servidor: Monkeys/MonkeyAnimator).
-- Se crean en Studio con el Animation Editor sobre el rig de MonkeyModels (ver docs/ANIMACIONES.md)
-- y aquí se pega su ID ("rbxassetid://123…"). Las que estén vacías no se reproducen.

export type Action =
	"Idle" -- quieto (en bucle)
	| "Walk" -- andando (en bucle)
	| "Run" -- corriendo (en bucle; si no hay, se usa Walk más rápido)
	| "Attack" -- mordisco o golpe (también a las piezas del Basecamp)
	| "Pounce" -- salto sobre la presa / embestida del jefe
	| "Roar" -- rugido
	| "Throw" -- lanza una piedra / lluvia de rocas del jefe
	| "Stomp" -- golpe en el pecho o en el suelo
	| "Steal" -- el capuchino roba
	| "Howl" -- el aullador llama a la tropa / el jefe pide refuerzos
	| "Hurt" -- recibe un golpe
	| "Death" -- muere

export type AnimationSet = { [Action]: string }

local MonkeyAnimations = {
	-- Las de todos los monos.
	Default = {
		Idle = "rbxassetid://106080154423465",
		Walk = "rbxassetid://106939439241748",
		Run = "",
		Attack = "rbxassetid://117189969986819",
		Pounce = "rbxassetid://103593054126885",
		Roar = "rbxassetid://82010463726811",
		Throw = "rbxassetid://99953061468087",
		Stomp = "rbxassetid://136583300745014",
		Steal = "rbxassetid://90574954578343",
		Howl = "rbxassetid://133209505717990",
		Hurt = "rbxassetid://86389165852631",
		Death = "rbxassetid://86396540202425",
	} :: AnimationSet,

	-- Cambios por especie (id de Data/Monkeys) o por jefe (id de Data/Bosses): solo las que cambian.
	-- Ejemplo: GorilaAlbino = { Walk = "rbxassetid://…" }
	Overrides = {} :: { [string]: AnimationSet },

	-- Velocidad (studs/s) a la que Walk y Run se reproducen a velocidad normal; más rápido, más deprisa.
	WalkReferenceSpeed = 10,
	RunReferenceSpeed = 20,
	-- A partir de esta velocidad pasa de Walk a Run (si hay Run).
	RunThreshold = 16,
}

return MonkeyAnimations
