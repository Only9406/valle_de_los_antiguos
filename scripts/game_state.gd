extends Node
## Estado global (autoload "GameState"): personaje, progreso (nivel, XP, talentos,
## inventario, misiones), guardado en disco y senales para la interfaz.

const ProgressionData = preload("res://scripts/progression_data.gd")
const QuestData = preload("res://scripts/quest_data.gd")
const ItemData = preload("res://scripts/item_data.gd")

const SAVE_PATH := "user://personaje.json"

## Ruta del guardado. Las pruebas automaticas la cambian para no tocar la partida real.
var save_path := SAVE_PATH

signal leveled_up(new_level: int)
signal inventory_changed
signal progress_changed
signal message(text: String)
signal open_dialogue(npc: Dictionary)

## {"name": String, "class": "Knight"..., "look": int, "color": int, "weapon": int}
var character: Dictionary = {}
var kills := 0
var target = null        # ultimo enemigo golpeado
var target_time := 0.0   # segundos (reloj del motor) del ultimo golpe
var ui_open := false     # hay un panel abierto (inventario, talentos, dialogo)

# progreso
var level := 1
var xp := 0
var talent_points := 0
var talents: Dictionary = {}    # id -> rango
var inventory: Dictionary = {}  # id de objeto -> cantidad
var quests: Dictionary = {}     # id de mision -> "active" | "done"


func default_character() -> Dictionary:
	return {"name": "Aventurero", "class": "Knight", "look": 0, "color": 0, "weapon": 0}


## Personaje activo; si no se ha creado ninguno (p. ej. F6 en main.tscn) usa uno por defecto.
func get_character() -> Dictionary:
	if character.is_empty():
		return default_character()
	return character


## Empieza una partida nueva con este personaje (progreso a cero) y la guarda.
func new_game(ch: Dictionary) -> void:
	character = ch.duplicate()
	reset_progress()
	save_character()


func reset_progress() -> void:
	kills = 0
	level = 1
	xp = 0
	talent_points = 0
	talents = {}
	inventory = {}
	quests = {}


## ----------------------------------------------------------------- guardado
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_character() -> void:
	if character.is_empty():
		return # partida de prueba (F6): no pisa el guardado
	var data := character.duplicate()
	data["level"] = level
	data["xp"] = xp
	data["points"] = talent_points
	data["talents"] = talents
	data["inventory"] = inventory
	data["quests"] = quests
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


## Lee el guardado sin modificar el estado actual (para mostrar "Continuar").
func peek_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func load_character() -> bool:
	var data := peek_save()
	if data.is_empty():
		return false
	character = {
		"name": str(data.get("name", "Aventurero")),
		"class": str(data.get("class", "Knight")),
		"look": int(data.get("look", 0)),
		"color": int(data.get("color", 0)),
		"weapon": int(data.get("weapon", 0)),
	}
	reset_progress()
	level = clampi(int(data.get("level", 1)), 1, ProgressionData.MAX_LEVEL)
	xp = int(data.get("xp", 0))
	talent_points = int(data.get("points", 0))
	for k in data.get("talents", {}):
		talents[str(k)] = int(data["talents"][k])
	for k in data.get("inventory", {}):
		inventory[str(k)] = int(data["inventory"][k])
	for k in data.get("quests", {}):
		quests[str(k)] = str(data["quests"][k])
	return true


## ------------------------------------------------------------------ combate
func register_hit(enemy) -> void:
	target = enemy
	target_time = Time.get_ticks_msec() / 1000.0


func on_kill(kind: String) -> void:
	kills += 1
	var base := int(ProgressionData.KILL_XP.get(kind, 20))
	var gained := add_xp(base)
	message.emit("+%d XP" % gained)


## ----------------------------------------------------------- experiencia
func talent_rank(id: String) -> int:
	return int(talents.get(id, 0))


func xp_needed() -> int:
	return ProgressionData.xp_needed(level)


## Suma experiencia (con el bonus de talentos). Devuelve la cantidad real ganada.
func add_xp(amount: int) -> int:
	var real := int(round(float(amount) * (1.0 + 0.08 * talent_rank("sabiduria"))))
	if level < ProgressionData.MAX_LEVEL:
		xp += real
		while level < ProgressionData.MAX_LEVEL and xp >= xp_needed():
			xp -= xp_needed()
			level += 1
			talent_points += 1
			leveled_up.emit(level)
		if level >= ProgressionData.MAX_LEVEL:
			xp = 0
	progress_changed.emit()
	save_character()
	return real


## ---------------------------------------------------------------- talentos
func points_in_branch(branch: int) -> int:
	var total := 0
	for id in ProgressionData.TALENTS:
		if int(ProgressionData.TALENTS[id]["branch"]) == branch:
			total += talent_rank(String(id))
	return total


func can_spend(id: String) -> bool:
	var t: Dictionary = ProgressionData.TALENTS[id]
	if talent_points <= 0 or talent_rank(id) >= int(t["max"]):
		return false
	var need: int = ProgressionData.TIER_REQ[int(t["tier"])]
	return points_in_branch(int(t["branch"])) >= need


func spend_talent(id: String) -> bool:
	if not can_spend(id):
		return false
	talents[id] = talent_rank(id) + 1
	talent_points -= 1
	progress_changed.emit()
	save_character()
	return true


func reset_talents() -> void:
	var spent := 0
	for id in talents:
		spent += int(talents[id])
	talents = {}
	talent_points += spent
	progress_changed.emit()
	save_character()


## --------------------------------------------------------------- inventario
func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n := 1) -> void:
	inventory[id] = count(id) + n
	inventory_changed.emit()
	save_character()


func remove_item(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	inventory[id] = count(id) - n
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	save_character()
	return true


## ----------------------------------------------------------------- misiones
func quest_state(id: String) -> String:
	return String(quests.get(id, ""))


## True si tienes en el inventario todo lo que pide la mision.
func quest_ready(id: String) -> bool:
	for o in QuestData.QUESTS[id]["objectives"]:
		if count(String(o["item"])) < int(o["count"]):
			return false
	return true


func start_quest(id: String) -> void:
	if quest_state(id) != "":
		return
	quests[id] = "active"
	var give: Dictionary = QuestData.QUESTS[id].get("give", {})
	for item in give:
		if count(String(item)) == 0:
			inventory[String(item)] = int(give[item])
	message.emit("Misión aceptada: %s" % QuestData.QUESTS[id]["title"])
	inventory_changed.emit()
	progress_changed.emit()
	save_character()


func complete_quest(id: String) -> bool:
	if quest_state(id) != "active" or not quest_ready(id):
		return false
	var q: Dictionary = QuestData.QUESTS[id]
	for o in q["objectives"]:
		inventory[String(o["item"])] = count(String(o["item"])) - int(o["count"])
		if inventory[String(o["item"])] <= 0:
			inventory.erase(String(o["item"]))
	quests[id] = "done"
	talent_points += int(q.get("reward_points", 0))
	inventory_changed.emit()
	message.emit("Misión completada: %s" % q["title"])
	add_xp(int(q.get("reward_xp", 0)))
	return true
