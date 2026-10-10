extends RefCounted
## Misiones y dialogos de los NPC.

const QUESTS := {
	"materiales": {
		"title": "Materiales para los Antiguos",
		"intro": "Las ruinas necesitan reparaciones y yo ya no tengo edad para cargar troncos. "
			+ "Toma estas herramientas: un hacha, un pico y una hoz. Tráeme 10 maderas de los "
			+ "árboles del bosque y 10 piedras de las rocas. Te recompensaré con experiencia "
			+ "y un punto de talento.",
		"progress": "Aún no tienes todo. Corta árboles con el hacha y pica rocas con el pico "
			+ "(acércate y pulsa E).",
		"ready": "¡Estupendo, ya lo tienes todo! Entrégamelo y recibirás tu recompensa.",
		"done": "Gracias por los materiales. Las ruinas volverán a brillar. Que los Antiguos te guíen.",
		"objectives": [{"item": "wood", "count": 10}, {"item": "stone", "count": 10}],
		"give": {"axe": 1, "pickaxe": 1, "sickle": 1},
		"reward_xp": 200,
		"reward_points": 1,
	},
}

## Frases de los NPC sin mision.
const LINES := {
	"mercader": [
		"Pronto tendré mercancía nueva. Por ahora, tus materiales valen más en manos del Anciano.",
		"Las hierbas que cortes con la hoz se venderán bien... cuando abra mi tienda.",
	],
	"capitana": [
		"Practica tus habilidades (teclas 1-4) con los esqueletos del bosque. ¡Cada nivel desbloquea más!",
		"Gasta tus puntos de talento (tecla T). Un buen guerrero nunca deja puntos sin usar.",
	],
}
