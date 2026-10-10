extends GdUnitTestSuite
## Integridad de los datos de clases, armas, habilidades, talentos y animaciones.

const ClassData = preload("res://scripts/class_data.gd")
const ProgressionData = preload("res://scripts/progression_data.gd")
const AttackData = preload("res://scripts/attack_data.gd")
const ItemData = preload("res://scripts/item_data.gd")
const QuestData = preload("res://scripts/quest_data.gd")
const WorldData = preload("res://scripts/world_data.gd")

const REQUIRED := {
	"cone": ["range", "cos", "mult"],
	"aoe_self": ["radius", "mult"],
	"dash": ["dir", "distance", "speed", "mult"],
	"buff": ["duration", "dmg", "aspd"],
	"projectile": ["kind", "color", "speed", "range", "mult"],
	"volley": ["kind", "color", "speed", "range", "count", "spread", "mult"],
	"ground_aoe": ["range", "radius", "mult", "delay", "color"],
}


func test_five_classes_in_order() -> void:
	assert_array(ClassData.ORDER).is_equal(["Knight", "Barbarian", "Mage", "Rogue", "Ranger"])
	for id in ClassData.ORDER:
		assert_bool(ClassData.CLASSES.has(id)).is_true()


func test_classes_have_looks_weapons_and_stats() -> void:
	for id in ClassData.ORDER:
		var c: Dictionary = ClassData.CLASSES[id]
		assert_int(int(c["hp"])).is_greater(0)
		assert_float(float(c["speed"])).is_greater(0.0)
		assert_int((c["looks"] as Array).size()).is_greater(0)
		assert_int((c["weapons"] as Array).size()).is_greater_equal(2)


func test_character_models_exist() -> void:
	for id in ClassData.ORDER:
		for look in ClassData.CLASSES[id]["looks"]:
			var path := "res://assets/kaykit_adventurers/characters/%s.glb" % look["model"]
			assert_bool(FileAccess.file_exists(path)).override_failure_message("Falta " + path).is_true()


func test_weapon_models_and_animations_exist() -> void:
	for id in ClassData.ORDER:
		for w in ClassData.CLASSES[id]["weapons"]:
			for side in ["right", "left"]:
				var prop := String(w[side])
				if prop == "":
					continue
				var path := "res://assets/kaykit_adventurers/props/%s.gltf" % prop
				assert_bool(FileAccess.file_exists(path)).override_failure_message("Falta " + path).is_true()
			var anims = w["attack"]
			var names: Array = [anims] if anims is String else anims
			for n in names:
				assert_bool(AttackData.ATTACKS.has(n)).override_failure_message(
						"Ataque inexistente: %s (%s)" % [n, w["name"]]).is_true()
			assert_float(float(w["cooldown"])).is_greater(0.0)
			assert_int(int(w["dmg"][0])).is_less_equal(int(w["dmg"][1]))
			if w["kind"] == "ranged":
				assert_bool(w.has("proj")).is_true()


func test_each_class_has_four_ascending_abilities_with_required_fields() -> void:
	for id in ClassData.ORDER:
		var list: Array = ProgressionData.abilities_of(id)
		assert_int(list.size()).is_equal(4)
		var last := 0
		for ab in list:
			assert_int(int(ab["unlock"])).is_greater_equal(last)
			last = int(ab["unlock"])
			assert_bool(REQUIRED.has(ab["type"])).is_true()
			for k in REQUIRED[ab["type"]]:
				assert_bool(ab.has(k)).override_failure_message(
						"%s: a %s le falta '%s'" % [id, ab["name"], k]).is_true()
			assert_float(float(ab["cd"])).is_greater(0.0)


func test_xp_curve_is_increasing() -> void:
	var prev := 0
	for l in range(1, ProgressionData.MAX_LEVEL):
		var n := ProgressionData.xp_needed(l)
		assert_int(n).is_greater(prev)
		prev = n


func test_talent_tree_is_consistent() -> void:
	for id in ProgressionData.TALENTS:
		var t: Dictionary = ProgressionData.TALENTS[id]
		assert_int(int(t["branch"])).is_between(0, ProgressionData.BRANCHES.size() - 1)
		assert_int(int(t["tier"])).is_between(0, ProgressionData.TIER_REQ.size() - 1)
		assert_int(int(t["max"])).is_greater(0)


func test_attack_animation_data_is_valid() -> void:
	assert_int(AttackData.ATTACKS.size()).is_equal(8)
	for nm in AttackData.ATTACKS:
		var d: Dictionary = AttackData.ATTACKS[nm]
		assert_float(float(d["hit"])).is_less(float(d["length"]))
		for bone in d["tracks"]:
			var arr: Array = d["tracks"][bone]
			assert_int(arr.size() % 5).is_equal(0)
			var prev_t := -1.0
			for k in range(0, arr.size(), 5):
				assert_float(float(arr[k])).is_greater(prev_t)
				prev_t = float(arr[k])
				var q := Quaternion(arr[k + 1], arr[k + 2], arr[k + 3], arr[k + 4])
				assert_float(q.length()).is_equal_approx(1.0, 0.01)


func test_item_gather_and_quest_data() -> void:
	for kind in ItemData.GATHER:
		assert_bool(ItemData.ITEMS.has(kind)).is_true() # el recurso es un objeto
		assert_bool(ItemData.ITEMS.has(ItemData.GATHER[kind]["tool"])).is_true()
	for qid in QuestData.QUESTS:
		for o in QuestData.QUESTS[qid]["objectives"]:
			assert_bool(ItemData.ITEMS.has(o["item"])).is_true()
		for item in QuestData.QUESTS[qid]["give"]:
			assert_bool(ItemData.ITEMS.has(item)).is_true()


func test_world_zones_npcs_and_camps() -> void:
	assert_str(WorldData.zone_at(Vector3(0, 0, 0))["id"]).is_equal("plaza")
	assert_str(WorldData.zone_at(Vector3(50, 0, 0))["id"]).is_equal("bosque")
	assert_str(WorldData.zone_at(Vector3(100, 0, 0))["id"]).is_equal("cumbres")
	var ids := []
	for npc in WorldData.NPCS:
		assert_bool(ids.has(npc["id"])).is_false()
		ids.append(npc["id"])
		if npc.has("quest"):
			assert_bool(QuestData.QUESTS.has(npc["quest"])).is_true()
	for camp in WorldData.CAMPS:
		var c: Vector2 = camp["center"]
		# los campamentos (con su claro) quedan fuera de la plaza segura
		assert_float(c.length() - WorldData.CAMP_CLEARING_RADIUS).is_greater(32.0)
		for k in camp["kinds"]:
			assert_bool(WorldData.SKELETON_TYPES.has(k)).is_true()
