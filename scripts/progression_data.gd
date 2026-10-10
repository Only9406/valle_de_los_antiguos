extends RefCounted
## Progresion: experiencia, niveles, arbol de talentos y habilidades de cada clase.

const MAX_LEVEL := 20

## XP que se necesita para pasar de `level` a `level + 1`.
static func xp_needed(level: int) -> int:
	return int(50.0 * pow(float(level), 1.5))


## XP al derrotar a cada tipo de enemigo.
const KILL_XP := {"Minion": 25, "Rogue": 40, "Mage": 45, "Warrior": 65}

## ----------------------------------------------------------------- talentos
const BRANCHES := [
	{"name": "Combate", "color": Color(0.85, 0.3, 0.25)},
	{"name": "Maestría", "color": Color(0.3, 0.5, 0.95)},
	{"name": "Oficio", "color": Color(0.3, 0.75, 0.4)},
]
## Puntos que hay que gastar en una rama para desbloquear cada fila (tier 0, 1, 2).
const TIER_REQ := [0, 3, 6]

const TALENTS := {
	"fuerza": {"branch": 0, "tier": 0, "name": "Fuerza", "max": 5,
		"desc": "+5% de daño por rango."},
	"precision": {"branch": 0, "tier": 1, "name": "Precisión", "max": 5,
		"desc": "+3% de probabilidad de crítico por rango."},
	"devastador": {"branch": 0, "tier": 2, "name": "Golpe devastador", "max": 3,
		"desc": "+20% de daño crítico por rango."},
	"concentracion": {"branch": 1, "tier": 0, "name": "Concentración", "max": 5,
		"desc": "-4% de enfriamiento de las habilidades por rango."},
	"potencia": {"branch": 1, "tier": 1, "name": "Potencia", "max": 5,
		"desc": "+8% de daño de las habilidades por rango."},
	"maestro": {"branch": 1, "tier": 2, "name": "Maestro de la definitiva", "max": 3,
		"desc": "+15% de daño y -5% de enfriamiento de tu 4ª habilidad por rango."},
	"agilidad": {"branch": 2, "tier": 0, "name": "Agilidad", "max": 5,
		"desc": "+4% de velocidad de movimiento por rango."},
	"cosechador": {"branch": 2, "tier": 1, "name": "Cosechador", "max": 5,
		"desc": "-8% de tiempo de recolección y +10% de probabilidad de botín doble por rango."},
	"sabiduria": {"branch": 2, "tier": 2, "name": "Sabiduría", "max": 3,
		"desc": "+8% de experiencia ganada por rango."},
}

## --------------------------------------------------------------- habilidades
## type: cone | aoe_self | dash | buff | projectile | volley | ground_aoe
## unlock: nivel necesario. cd: enfriamiento (s). mult: multiplicador del dano del arma.
## Efectos: stun (s), slow [factor, s], dot [mult por segundo, s].
const ABILITIES := {
	"Knight": [
		{"name": "Golpe de escudo", "desc": "Golpe frontal que aturde 1,5 s.", "unlock": 1, "cd": 6.0,
			"type": "cone", "range": 3.2, "cos": 0.3, "mult": 1.3, "stun": 1.5},
		{"name": "Carga", "desc": "Embistes hacia delante aturdiendo a quien atraviesas.", "unlock": 2, "cd": 10.0,
			"type": "dash", "dir": 1.0, "distance": 9.0, "speed": 22.0, "mult": 1.2, "stun": 0.8},
		{"name": "Grito de guerra", "desc": "+30% de daño durante 8 s.", "unlock": 4, "cd": 20.0,
			"type": "buff", "duration": 8.0, "dmg": 0.3, "aspd": 0.0},
		{"name": "Juicio divino", "desc": "Onda de luz a tu alrededor que aturde.", "unlock": 6, "cd": 18.0,
			"type": "aoe_self", "radius": 5.5, "mult": 2.2, "stun": 1.2},
	],
	"Barbarian": [
		{"name": "Tajo brutal", "desc": "Hachazo frontal de gran daño.", "unlock": 1, "cd": 7.0,
			"type": "cone", "range": 3.4, "cos": 0.2, "mult": 2.0},
		{"name": "Torbellino", "desc": "Giras con el hacha golpeando alrededor.", "unlock": 2, "cd": 9.0,
			"type": "aoe_self", "radius": 4.2, "mult": 1.4},
		{"name": "Furia", "desc": "+40% de daño y +25% de velocidad de ataque 8 s.", "unlock": 4, "cd": 22.0,
			"type": "buff", "duration": 8.0, "dmg": 0.4, "aspd": 0.25},
		{"name": "Salto sísmico", "desc": "Saltas y aplastas el suelo aturdiendo.", "unlock": 6, "cd": 16.0,
			"type": "dash", "dir": 1.0, "distance": 8.0, "speed": 14.0, "mult": 0.0, "leap": true,
			"land_radius": 5.0, "land_mult": 2.4, "stun": 1.5},
	],
	"Mage": [
		{"name": "Bola de fuego", "desc": "Proyectil que explota al impactar.", "unlock": 1, "cd": 5.0,
			"type": "projectile", "kind": "orb", "color": Color(1.0, 0.45, 0.1), "speed": 20.0,
			"range": 30.0, "mult": 2.2, "explode": 3.0},
		{"name": "Nova de hielo", "desc": "Onda gélida que ralentiza a los enemigos.", "unlock": 2, "cd": 12.0,
			"type": "aoe_self", "radius": 6.5, "mult": 1.2, "slow": [0.4, 4.0]},
		{"name": "Parpadeo", "desc": "Te teletransportas hacia delante.", "unlock": 4, "cd": 9.0,
			"type": "dash", "dir": 1.0, "distance": 10.0, "speed": 45.0, "mult": 0.0},
		{"name": "Meteoro", "desc": "Un meteoro cae donde apuntas y aturde.", "unlock": 6, "cd": 24.0,
			"type": "ground_aoe", "range": 28.0, "radius": 5.0, "mult": 3.5, "delay": 1.0,
			"color": Color(1.0, 0.4, 0.1), "fall": true, "stun": 1.0},
	],
	"Rogue": [
		{"name": "Puñalada venenosa", "desc": "Golpe que envenena al objetivo.", "unlock": 1, "cd": 6.0,
			"type": "cone", "range": 2.8, "cos": 0.3, "mult": 1.5, "dot": [0.4, 4.0]},
		{"name": "Paso sombrío", "desc": "Te desplazas rápidamente hacia delante.", "unlock": 2, "cd": 8.0,
			"type": "dash", "dir": 1.0, "distance": 8.0, "speed": 32.0, "mult": 0.0},
		{"name": "Lluvia de dagas", "desc": "Lanzas 5 dagas en abanico.", "unlock": 4, "cd": 10.0,
			"type": "volley", "kind": "bolt", "color": Color(0.85, 0.85, 0.9), "speed": 36.0,
			"range": 22.0, "count": 5, "spread": 36.0, "mult": 0.7},
		{"name": "Frenesí", "desc": "+20% de daño y +50% de velocidad de ataque 8 s.", "unlock": 6, "cd": 22.0,
			"type": "buff", "duration": 8.0, "dmg": 0.2, "aspd": 0.5},
	],
	"Ranger": [
		{"name": "Disparo potente", "desc": "Flecha de gran daño y largo alcance.", "unlock": 1, "cd": 6.0,
			"type": "projectile", "kind": "arrow", "color": Color(1.0, 0.9, 0.6), "speed": 50.0,
			"range": 45.0, "mult": 2.6, "explode": 0.0},
		{"name": "Salto atrás", "desc": "Saltas hacia atrás para ganar distancia.", "unlock": 2, "cd": 9.0,
			"type": "dash", "dir": -1.0, "distance": 8.0, "speed": 26.0, "mult": 0.0},
		{"name": "Tiro múltiple", "desc": "Disparas 5 flechas en abanico.", "unlock": 4, "cd": 14.0,
			"type": "volley", "kind": "arrow", "color": Color(1.0, 0.9, 0.6), "speed": 40.0,
			"range": 30.0, "count": 5, "spread": 28.0, "mult": 1.0},
		{"name": "Lluvia de flechas", "desc": "Cae una lluvia de flechas que ralentiza.", "unlock": 6, "cd": 22.0,
			"type": "ground_aoe", "range": 34.0, "radius": 6.0, "mult": 3.2, "delay": 0.8,
			"color": Color(0.95, 0.85, 0.5), "fall": false, "slow": [0.5, 3.0]},
	],
}


static func abilities_of(class_id: String) -> Array:
	return ABILITIES.get(class_id, ABILITIES["Knight"])
