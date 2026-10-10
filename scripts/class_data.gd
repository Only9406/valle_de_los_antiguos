extends RefCounted
## Clases jugables, armas, aspectos y colores. Todo el contenido de la creacion de
## personaje esta aqui: anade clases o armas editando estos diccionarios.
##
## Armas: "right"/"left" = archivo de assets/kaykit_adventurers/props (sin .gltf).
##   attack: animacion de ataque (o lista que se alterna). kind: "melee" o "ranged".
##   dmg: [min, max]. range: metros. cooldown: segundos. targets: enemigos golpeados a la vez.
##   proj (solo ranged): kind "arrow" | "bolt" | "orb", color, speed. muzzle: mano de la que sale.

const ORDER := ["Knight", "Barbarian", "Mage", "Rogue", "Ranger"]

## Colores de prenda (capa, sombrero...). hue = tono 0..1 (-1 = el original).
const COLORS := [
	{"name": "Original", "hue": -1.0, "sat": 1.0, "val": 1.0, "chip": Color(0.78, 0.78, 0.78)},
	{"name": "Rojo", "hue": 0.0, "sat": 1.0, "val": 1.0, "chip": Color(0.85, 0.2, 0.2)},
	{"name": "Naranja", "hue": 0.07, "sat": 1.0, "val": 1.0, "chip": Color(0.95, 0.5, 0.15)},
	{"name": "Dorado", "hue": 0.13, "sat": 1.0, "val": 1.0, "chip": Color(0.95, 0.78, 0.2)},
	{"name": "Verde", "hue": 0.33, "sat": 1.0, "val": 1.0, "chip": Color(0.25, 0.75, 0.3)},
	{"name": "Turquesa", "hue": 0.5, "sat": 1.0, "val": 1.0, "chip": Color(0.2, 0.75, 0.75)},
	{"name": "Azul", "hue": 0.6, "sat": 1.0, "val": 1.0, "chip": Color(0.2, 0.4, 0.9)},
	{"name": "Violeta", "hue": 0.76, "sat": 1.0, "val": 1.0, "chip": Color(0.6, 0.3, 0.85)},
	{"name": "Rosa", "hue": 0.92, "sat": 1.0, "val": 1.0, "chip": Color(0.95, 0.4, 0.65)},
	{"name": "Sombra", "hue": -1.0, "sat": 0.15, "val": 0.45, "chip": Color(0.22, 0.22, 0.25)},
	{"name": "Marfil", "hue": -1.0, "sat": 0.12, "val": 1.5, "chip": Color(0.95, 0.94, 0.88)},
]

const CLASSES := {
	"Knight": {
		"name": "Caballero", "role": "Tanque cuerpo a cuerpo",
		"desc": "Armadura pesada y mucha vida. Aguanta el frente y golpea con firmeza.",
		"hp": 160, "speed": 0.92, "tint": ["Cape"],
		"looks": [
			{"name": "Casco cerrado", "model": "Knight", "hide": []},
			{"name": "Sin casco", "model": "Knight", "hide": ["Helmet"]},
			{"name": "Sin casco ni capa", "model": "Knight", "hide": ["Helmet", "Cape"]},
		],
		"weapons": [
			{"name": "Espada y escudo", "desc": "Cortes rápidos y equilibrados.",
				"right": "sword_1handed", "left": "shield_badge", "attack": "Slash", "kind": "melee",
				"dmg": [13, 19], "range": 2.8, "cooldown": 0.65, "targets": 1},
			{"name": "Espadón a dos manos", "desc": "Golpe lento y devastador; alcanza a 2 enemigos.",
				"right": "sword_2handed", "left": "", "attack": "Chop", "kind": "melee",
				"dmg": [26, 36], "range": 3.3, "cooldown": 1.15, "targets": 2},
		],
	},
	"Barbarian": {
		"name": "Bárbaro", "role": "Bruto de daño en área",
		"desc": "Fuerza salvaje. Sus hachas golpean fuerte y su ataque pesado arrasa a varios enemigos.",
		"hp": 150, "speed": 1.0, "tint": ["BearHat"],
		"looks": [
			{"name": "Gorro de oso", "model": "Barbarian", "hide": []},
			{"name": "Sin gorro", "model": "Barbarian", "hide": ["BearHat"]},
		],
		"weapons": [
			{"name": "Hacha y escudo", "desc": "Ataque ágil con defensa.",
				"right": "axe_1handed", "left": "shield_round_barbarian", "attack": "Slash", "kind": "melee",
				"dmg": [14, 21], "range": 2.8, "cooldown": 0.7, "targets": 1},
			{"name": "Gran hacha", "desc": "Hachazo en área: hasta 3 enemigos.",
				"right": "axe_2handed", "left": "", "attack": "Chop", "kind": "melee",
				"dmg": [28, 40], "range": 3.4, "cooldown": 1.25, "targets": 3},
		],
	},
	"Mage": {
		"name": "Mago", "role": "Daño mágico a distancia",
		"desc": "Frágil pero letal desde lejos. Lanza proyectiles arcanos hacia donde apuntas.",
		"hp": 90, "speed": 1.0, "tint": ["Cape", "Hat"],
		"looks": [
			{"name": "Con sombrero", "model": "Mage", "hide": []},
			{"name": "Sin sombrero", "model": "Mage", "hide": ["Hat"]},
			{"name": "Sin sombrero ni capa", "model": "Mage", "hide": ["Hat", "Cape"]},
		],
		"weapons": [
			{"name": "Bastón arcano", "desc": "Orbe violeta potente y de largo alcance.",
				"right": "staff", "left": "", "attack": "Cast", "kind": "ranged",
				"dmg": [17, 25], "range": 26.0, "cooldown": 0.9, "targets": 1,
				"proj": {"kind": "orb", "color": Color(0.65, 0.35, 1.0), "speed": 24.0}},
			{"name": "Varita y libro", "desc": "Chispas de fuego muy rápidas.",
				"right": "wand", "left": "spellbook_closed", "attack": "Cast", "kind": "ranged",
				"dmg": [9, 14], "range": 22.0, "cooldown": 0.5, "targets": 1,
				"proj": {"kind": "orb", "color": Color(1.0, 0.55, 0.15), "speed": 30.0}},
		],
	},
	"Rogue": {
		"name": "Pícaro", "role": "Ágil y letal de cerca",
		"desc": "El más veloz. Dagas gemelas de ataque rapidísimo o ballesta ligera.",
		"hp": 100, "speed": 1.12, "tint": ["Cape", "Mask"],
		"looks": [
			{"name": "Sin capucha", "model": "Rogue", "hide": []},
			{"name": "Encapuchado", "model": "Rogue_Hooded", "hide": []},
			{"name": "Sin capa", "model": "Rogue", "hide": ["Cape"]},
		],
		"weapons": [
			{"name": "Dagas gemelas", "desc": "Puñaladas alternas muy rápidas.",
				"right": "dagger", "left": "dagger", "attack": ["Stab", "StabL"], "kind": "melee",
				"dmg": [7, 11], "range": 2.4, "cooldown": 0.36, "targets": 1},
			{"name": "Ballesta ligera", "desc": "Virotes rápidos a media distancia.",
				"right": "crossbow_1handed", "left": "", "attack": "Aim1", "kind": "ranged",
				"dmg": [15, 21], "range": 30.0, "cooldown": 0.85, "targets": 1,
				"proj": {"kind": "bolt", "color": Color(0.9, 0.9, 0.7), "speed": 38.0}},
		],
	},
	"Ranger": {
		"name": "Explorador", "role": "Arquero de largo alcance",
		"desc": "Precisión a gran distancia. Arco largo o ballesta pesada.",
		"hp": 105, "speed": 1.05, "tint": ["Cape"],
		"looks": [
			{"name": "Con capa", "model": "Ranger", "hide": []},
			{"name": "Sin capa", "model": "Ranger", "hide": ["Cape"]},
		],
		"weapons": [
			{"name": "Arco largo", "desc": "Flechas certeras a gran distancia.",
				"right": "", "left": "bow", "attack": "Bow", "kind": "ranged", "muzzle": "l",
				"dmg": [16, 23], "range": 34.0, "cooldown": 0.95, "targets": 1,
				"proj": {"kind": "arrow", "color": Color(1.0, 0.9, 0.6), "speed": 34.0}},
			{"name": "Ballesta pesada", "desc": "Disparo lento pero muy potente.",
				"right": "crossbow_2handed", "left": "", "attack": "Aim2", "kind": "ranged",
				"dmg": [28, 38], "range": 38.0, "cooldown": 1.5, "targets": 1,
				"proj": {"kind": "bolt", "color": Color(0.95, 0.85, 0.6), "speed": 44.0}},
		],
	},
}


static func info(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, CLASSES["Knight"])


static func look_of(ch: Dictionary) -> Dictionary:
	var looks: Array = info(ch.get("class", "Knight"))["looks"]
	return looks[clampi(int(ch.get("look", 0)), 0, looks.size() - 1)]


static func weapon_of(ch: Dictionary) -> Dictionary:
	var ws: Array = info(ch.get("class", "Knight"))["weapons"]
	return ws[clampi(int(ch.get("weapon", 0)), 0, ws.size() - 1)]


static func color_of(ch: Dictionary) -> Dictionary:
	return COLORS[clampi(int(ch.get("color", 0)), 0, COLORS.size() - 1)]


## Opciones para CharacterActor.setup_hero() a partir de un personaje.
static func actor_options(ch: Dictionary) -> Dictionary:
	var look := look_of(ch)
	var w := weapon_of(ch)
	var c := color_of(ch)
	return {
		"model": look["model"], "hide": look["hide"], "tint": info(ch.get("class", "Knight"))["tint"],
		"hue": c["hue"], "sat": c["sat"], "val": c["val"],
		"right": w["right"], "left": w["left"],
	}
