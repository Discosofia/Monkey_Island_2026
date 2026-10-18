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
	| "Invoke" -- invoca con los brazos en alto (en bucle; el jefe la para): lluvia de lava del Gorila de Ceniza
	| "Hurt" -- recibe un golpe
	| "Death" -- muere

export type AnimationSet = { [Action]: string }
export type PhaseSet = { [number]: AnimationSet }

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
		Invoke = "",
		Hurt = "rbxassetid://86389165852631",
		Death = "rbxassetid://86396540202425",
	} :: AnimationSet,

	-- Cambios por especie (id de Data/Monkeys) o por jefe (id de Data/Bosses): solo las que cambian.
	-- Ejemplo: GorilaAlbino = { Walk = "rbxassetid://…" }. Las vacías se ignoran (se queda la de debajo).
	-- Las de los huecos con nombre (Titi_Run, Cenizo_Attack2…) salen de
	-- src/island/tools/MonkeyAnimationBuilder (specs en MonkeyAnimationSpecs): build() las deja en
	-- ServerStorage.RBX_ANIMSAVES.<lote> para publicarlas.
	Overrides = {
		-- Monos pequeños (categoría 1), lote MonosPequenos: <Especie>_Walk, _Run y _Attack. Ojo: van a su
		-- walkSpeed (casi todos ≥ RunThreshold), así que lo normal es verlos correr; Walk sale ralentizados.
		MonoArdilla = {
			Walk = "rbxassetid://91102553322630",
			Run = "rbxassetid://87863631331872",
			Attack = "rbxassetid://125201088242496",
		},
		AulladorRojo = {
			Walk = "rbxassetid://80807531679641",
			Run = "rbxassetid://71610806838671",
			Attack = "rbxassetid://125119051376171",
		},
		CapuchinoLadron = {
			Walk = "rbxassetid://72915708375912",
			Run = "rbxassetid://91922807351935",
			Attack = "rbxassetid://138188397454577",
		},
		Marimonda = {
			Walk = "rbxassetid://137647552205837",
			Run = "rbxassetid://101449187641065",
			Attack = "rbxassetid://116091204837404",
		},
		Titi = {
			Walk = "rbxassetid://133691696023716",
			Run = "rbxassetid://75327254205792",
			Attack = "rbxassetid://74189177700526",
		},
		Marteja = {
			Walk = "rbxassetid://76763024197386",
			Run = "rbxassetid://82499778433196",
			Attack = "rbxassetid://80408054113937",
		},
		-- Medianos y grandes (categorías 2 y 3), lote MonosMedianosYGrandes. Los jefes heredan los de su
		-- especie base (Gorila → Albino y Ceniza, Chimpance → Caudillo, Orangutan → Manglar).
		Mandril = {
			Walk = "rbxassetid://111988503860734",
			Run = "rbxassetid://81221277660692",
			Attack = "rbxassetid://117557680089674",
		},
		Macaco = {
			Walk = "rbxassetid://129344763516346",
			Run = "rbxassetid://123770699892259",
			Attack = "rbxassetid://140291103715623",
		},
		Gibon = {
			Walk = "rbxassetid://106321641330575",
			Run = "rbxassetid://134119982512185",
			Attack = "rbxassetid://88726827708091",
			Pounce = "rbxassetid://96284638591803", -- Gibon_Pounce
		},
		Babuino = {
			Walk = "rbxassetid://75905017386485",
			Run = "rbxassetid://137179308161694",
			Attack = "rbxassetid://93290458726609",
		},
		ColaLarga = {
			Walk = "rbxassetid://82543144862763",
			Run = "rbxassetid://81237357559620",
			Attack = "rbxassetid://89150966421456",
		},
		Chimpance = {
			Walk = "rbxassetid://93106510234819",
			Run = "rbxassetid://87517143704615",
			Attack = "rbxassetid://82994969619082",
		},
		Orangutan = {
			Walk = "rbxassetid://98631430463147",
			Run = "rbxassetid://131353002163202",
			Attack = "rbxassetid://80946064091284",
		},
		Gorila = {
			Walk = "rbxassetid://78875181494332",
			Run = "rbxassetid://114813484955697",
			Attack = "rbxassetid://71774470299136",
			Stomp = "rbxassetid://81890039402783", -- Gorila_Stomp
		},
		-- Jefes con pisotón: hacen el daño a 0,9 s (BossService), como el pisotón de fase 2 del de Ceniza.
		-- Va el mismo id que Cenizo_Stomp2 (encaja en los rigs del gorila y del orangután).
		GorilaAlbino = { Stomp = "rbxassetid://119579840176466" }, -- Cenizo_Stomp2
		OrangutanDelManglar = { Stomp = "rbxassetid://119579840176466" }, -- Cenizo_Stomp2
		-- Fase 1 del Gorila de Ceniza, lote GorilaDeCeniza (Cenizo_*).
		GorilaDeCeniza = {
			Walk = "rbxassetid://96699914862411", -- Cenizo_Walk1: andar pesado sobre los nudillos
			Attack = "rbxassetid://85047826967078", -- Cenizo_Attack1: puñetazo bajo que se extiende y se recoge bajando
		},
	} :: { [string]: AnimationSet },

	-- Cambios de un jefe según su fase (2 al 66 % de vida, 3 al 33 %), encima de Overrides. Se suman: la
	-- fase 3 hereda lo de la 2 que no cambie. Las vacías se ignoran.
	Phases = {
		GorilaDeCeniza = {
			[2] = {
				Walk = "rbxassetid://95704746421249", -- Cenizo_Walk2: zancada más larga y cabeza baja
				Attack = "rbxassetid://93854315716288", -- Cenizo_Attack2: puñetazo bajo con el cuerpo detrás
				Stomp = "rbxassetid://119579840176466", -- Cenizo_Stomp2: pisotón como el del guerrero (impacto a 0,9 s, con la onda)
			},
			[3] = {
				Walk = "rbxassetid://117386466514250", -- Cenizo_Walk3: furioso, cabeza baja y brazos abiertos
				Attack = "rbxassetid://130822284171133", -- Cenizo_Attack3: dos puñetazos bajos seguidos
				Stomp = "rbxassetid://70992010578345", -- Cenizo_Stomp3: se alza más y remata con un segundo golpe de puños
				Invoke = "rbxassetid://71207683733658", -- Cenizo_Invoke3: brazos en alto llamando a la lava
			},
		},
	} :: { [string]: PhaseSet },

	-- Velocidad (studs/s) a la que Walk y Run se reproducen a velocidad normal; más rápido, más deprisa.
	WalkReferenceSpeed = 10,
	RunReferenceSpeed = 20,
	-- A partir de esta velocidad pasa de Walk a Run (si hay Run).
	RunThreshold = 16,
}

return MonkeyAnimations
