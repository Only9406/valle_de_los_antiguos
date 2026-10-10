extends GdUnitTestSuite
## Pruebas de GameState (nivel, XP, talentos, inventario, misiones, guardado).
## Usa una instancia propia y un archivo de guardado de prueba: no toca la partida real.

const GameStateScript = preload("res://scripts/game_state.gd")
const TEST_SAVE := "user://test_personaje.json"

var gs
var levels: Array = []


func before_test() -> void:
	gs = auto_free(GameStateScript.new())
	gs.save_path = TEST_SAVE
	levels = []
	gs.leveled_up.connect(func(l): levels.append(l))


func after_test() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)


func test_default_character() -> void:
	var d: Dictionary = gs.default_character()
	assert_str(d["class"]).is_equal("Knight")
	assert_int(d["weapon"]).is_equal(0)
	# sin personaje creado devuelve el de por defecto
	assert_str(gs.get_character()["class"]).is_equal("Knight")


func test_inventory_add_and_remove() -> void:
	gs.add_item("wood", 3)
	gs.add_item("wood", 2)
	assert_int(gs.count("wood")).is_equal(5)
	assert_bool(gs.remove_item("wood", 4)).is_true()
	assert_int(gs.count("wood")).is_equal(1)
	assert_bool(gs.remove_item("wood", 2)).is_false() # no hay suficiente
	assert_int(gs.count("wood")).is_equal(1)
	assert_bool(gs.remove_item("wood", 1)).is_true()
	assert_bool(gs.inventory.has("wood")).is_false() # se borra al llegar a 0


func test_level_up_gives_talent_point() -> void:
	var gained: int = gs.add_xp(50) # el nivel 1 necesita 50
	assert_int(gained).is_equal(50)
	assert_int(gs.level).is_equal(2)
	assert_int(gs.xp).is_equal(0)
	assert_int(gs.talent_points).is_equal(1)
	assert_array(levels).is_equal([2])


func test_xp_bonus_from_wisdom_talent() -> void:
	gs.talents["sabiduria"] = 3 # +24 %
	assert_int(gs.add_xp(100)).is_equal(124)


func test_max_level_is_capped() -> void:
	gs.level = 20
	gs.add_xp(100000)
	assert_int(gs.level).is_equal(20)
	assert_int(gs.xp).is_equal(0)


func test_talent_rows_are_gated_by_branch_points() -> void:
	gs.talent_points = 10
	assert_bool(gs.can_spend("fuerza")).is_true()
	assert_bool(gs.can_spend("precision")).is_false() # fila 2: pide 3 puntos en la rama
	for i in 3:
		assert_bool(gs.spend_talent("fuerza")).is_true()
	assert_int(gs.points_in_branch(0)).is_equal(3)
	assert_bool(gs.can_spend("precision")).is_true()
	assert_int(gs.talent_points).is_equal(7)


func test_talent_max_rank() -> void:
	gs.talent_points = 20
	for i in 5:
		assert_bool(gs.spend_talent("fuerza")).is_true()
	assert_bool(gs.spend_talent("fuerza")).is_false() # maximo 5
	assert_int(gs.talent_rank("fuerza")).is_equal(5)


func test_reset_talents_refunds_points() -> void:
	gs.talent_points = 4
	gs.spend_talent("fuerza")
	gs.spend_talent("fuerza")
	gs.spend_talent("agilidad")
	gs.reset_talents()
	assert_int(gs.talent_points).is_equal(4)
	assert_int(gs.talent_rank("fuerza")).is_equal(0)


func test_quest_full_flow() -> void:
	assert_str(gs.quest_state("materiales")).is_equal("")
	gs.start_quest("materiales")
	assert_str(gs.quest_state("materiales")).is_equal("active")
	# recibe las tres herramientas
	for tool in ["axe", "pickaxe", "sickle"]:
		assert_int(gs.count(tool)).is_equal(1)
	assert_bool(gs.quest_ready("materiales")).is_false()
	assert_bool(gs.complete_quest("materiales")).is_false() # aun no esta todo
	gs.add_item("wood", 10)
	gs.add_item("stone", 9)
	assert_bool(gs.quest_ready("materiales")).is_false()
	gs.add_item("stone", 1)
	assert_bool(gs.quest_ready("materiales")).is_true()
	assert_bool(gs.complete_quest("materiales")).is_true()
	assert_str(gs.quest_state("materiales")).is_equal("done")
	assert_int(gs.count("wood")).is_equal(0)
	assert_int(gs.count("stone")).is_equal(0)
	# 200 XP -> nivel 3 (9 de XP sobrante) y 1 + 2 puntos de talento
	assert_int(gs.level).is_equal(3)
	assert_int(gs.xp).is_equal(9)
	assert_int(gs.talent_points).is_equal(3)
	# no se puede completar dos veces
	assert_bool(gs.complete_quest("materiales")).is_false()


func test_new_game_resets_progress_and_saves() -> void:
	gs.level = 7
	gs.add_item("wood", 3)
	gs.new_game({"name": "Prueba", "class": "Mage", "look": 1, "color": 2, "weapon": 1})
	assert_int(gs.level).is_equal(1)
	assert_int(gs.count("wood")).is_equal(0)
	assert_bool(gs.has_save()).is_true()
	assert_str(gs.peek_save()["class"]).is_equal("Mage")


func test_save_and_load_roundtrip() -> void:
	gs.new_game({"name": "Rita", "class": "Ranger", "look": 1, "color": 3, "weapon": 1})
	gs.add_item("herb", 4)
	gs.talent_points = 2
	gs.spend_talent("fuerza")
	gs.start_quest("materiales")
	var gs2 = auto_free(GameStateScript.new())
	gs2.save_path = TEST_SAVE
	assert_bool(gs2.load_character()).is_true()
	assert_str(gs2.character["name"]).is_equal("Rita")
	assert_str(gs2.character["class"]).is_equal("Ranger")
	assert_int(gs2.character["weapon"]).is_equal(1)
	assert_int(gs2.count("herb")).is_equal(4)
	assert_int(gs2.talent_rank("fuerza")).is_equal(1)
	assert_str(gs2.quest_state("materiales")).is_equal("active")


func test_corrupt_save_is_ignored() -> void:
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("esto no es json {{{")
	f.close()
	assert_bool(gs.load_character()).is_false()
