extends RefCounted
## Datos del mundo: zonas, NPCs, enemigos y punto de aparicion.
## Pensado para migrarse luego a un servidor / base de datos.

const WORLD_NAME := "Valle de los Antiguos"

const ZONES := [
	{"id": "plaza", "name": "Plaza de los Antiguos", "r0": 0.0, "r1": 32.0, "level": "Nv. 1"},
	{"id": "bosque", "name": "Bosque Susurrante", "r0": 32.0, "r1": 88.0, "level": "Nv. 1-5"},
	{"id": "cumbres", "name": "Cumbres Olvidadas", "r0": 88.0, "r1": 99999.0, "level": "Nv. 5-10"},
]

## hero = opciones de CharacterActor.setup_hero (modelo Adventurers + armas). color = color del nombre.
const NPCS := [
	{"id": "anciano", "quest": "materiales", "name": "Anciano Guardián", "title": "Maestro de misiones", "pos": Vector2(-11, -6),
		"color": Color(0.7, 0.5, 1.0),
		"hero": {"model": "Mage", "right": "staff", "left": "spellbook_closed"}},
	{"id": "mercader", "name": "Mercader Orlan", "title": "Comerciante", "pos": Vector2(12, -5),
		"color": Color(0.95, 0.8, 0.3),
		"hero": {"model": "Rogue_Hooded", "right": "mug_full", "left": ""}},
	{"id": "capitana", "name": "Capitana Brisa", "title": "Entrenadora de combate", "pos": Vector2(11, 9),
		"color": Color(0.4, 0.9, 0.5),
		"hero": {"model": "Knight", "right": "sword_1handed", "left": "shield_badge"}},
]

## Tipos de enemigo (por modelo de esqueleto).
const SKELETON_TYPES := {
	"Minion": {"name": "Esqueleto Siervo"},
	"Warrior": {"name": "Esqueleto Guerrero"},
	"Rogue": {"name": "Esqueleto Pícaro"},
	"Mage": {"name": "Esqueleto Mago"},
}

## Campamentos de esqueletos (todos fuera de la Plaza, que es zona segura).
## Cada campamento limpia un claro de 7 m de arboles y rocas.
const CAMPS := [
	{"name": "Camino Maldito", "center": Vector2(12, 50), "level": "Nv. 1-2",
		"kinds": ["Minion", "Minion", "Minion"]},
	{"name": "Claro del Hueso", "center": Vector2(-46, 34), "level": "Nv. 2-3",
		"kinds": ["Minion", "Minion", "Rogue"]},
	{"name": "Hondonada Gris", "center": Vector2(44, -36), "level": "Nv. 3-4",
		"kinds": ["Warrior", "Minion", "Rogue"]},
	{"name": "Bosque Oscuro", "center": Vector2(-28, -62), "level": "Nv. 4-5",
		"kinds": ["Warrior", "Rogue", "Mage"]},
	{"name": "Paso de las Cumbres", "center": Vector2(20, -66), "level": "Nv. 5",
		"kinds": ["Mage", "Warrior", "Warrior"]},
]
const CAMP_CLEARING_RADIUS := 7.0

const SPAWN := Vector3(0, 0.5, 12)


static func zone_at(p: Vector3) -> Dictionary:
	var r := Vector2(p.x, p.z).length()
	for z in ZONES:
		if r >= z["r0"] and r < z["r1"]:
			return z
	return ZONES[ZONES.size() - 1]
