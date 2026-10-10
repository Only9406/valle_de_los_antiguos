extends GdUnitTestSuite
## Detecta errores de sintaxis: todos los scripts de res://scripts deben cargarse y poder instanciarse.


func test_all_scripts_load() -> void:
	var files := DirAccess.get_files_at("res://scripts")
	assert_int(files.size()).is_greater(10)
	for f in files:
		if not f.ends_with(".gd"):
			continue
		var path := "res://scripts/" + f
		var s = load(path)
		assert_object(s).override_failure_message("No carga: " + path).is_not_null()
		assert_bool(s.can_instantiate()).override_failure_message("Error de script: " + path).is_true()


func test_autoload_game_state_is_registered() -> void:
	assert_bool(ProjectSettings.has_setting("autoload/GameState")).is_true()
