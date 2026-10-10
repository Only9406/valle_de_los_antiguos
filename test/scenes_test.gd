extends GdUnitTestSuite
## Escenas principales: la creacion de personaje y el mundo se montan sin errores,
## y el combate basico (dano y muerte de un esqueleto) funciona.


func after_test() -> void:
	GameState.reset_progress() # no dejar XP ni bajas de la prueba en el autoload


func test_character_creation_scene_builds() -> void:
	var runner := scene_runner("res://scenes/character_creation.tscn")
	await runner.simulate_frames(5)
	var scene = runner.scene()
	assert_object(scene).is_not_null()
	assert_int(scene.class_row.get_child_count()).is_equal(5)
	assert_object(scene.preview_actor).is_not_null()
	# cambiar de clase rellena sus armas
	scene._on_class("Mage")
	assert_str(scene.ch["class"]).is_equal("Mage")
	assert_int(scene.weapon_box.get_child_count()).is_equal(2)


func test_main_scene_builds_world() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(5)
	var scene = runner.scene()
	assert_object(scene.get_node_or_null("Jugador")).is_not_null()
	assert_object(scene.get_node_or_null("Terreno")).is_not_null()
	assert_int(scene.get_tree().get_nodes_in_group("enemigos").size()).is_equal(15)
	assert_int(scene.get_tree().get_nodes_in_group("npc").size()).is_equal(3)
	assert_int(scene.get_tree().get_nodes_in_group("recolectable").size()).is_greater(100)


func test_enemy_takes_damage_and_dies() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(5)
	var enemies: Array = runner.scene().get_tree().get_nodes_in_group("enemigos")
	assert_int(enemies.size()).is_greater(0)
	var e = enemies[0]
	var hp0: int = e.hp
	e.take_damage(10)
	assert_int(e.hp).is_equal(hp0 - 10)
	assert_bool(e.dead).is_false()
	var kills0: int = GameState.kills
	e.take_damage(99999)
	assert_bool(e.dead).is_true()
	assert_int(e.hp).is_equal(0)
	assert_int(GameState.kills).is_equal(kills0 + 1)
	assert_int(GameState.level).is_greater_equal(1)
