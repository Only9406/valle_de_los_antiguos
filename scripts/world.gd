extends Node3D
## Escena principal: monta el Valle de los Antiguos completo desde codigo.

const WorldData = preload("res://scripts/world_data.gd")
const ValleyTerrain = preload("res://scripts/terrain_generator.gd")
const AncientRuins = preload("res://scripts/ancient_ruins.gd")
const PropScatter = preload("res://scripts/prop_scatter.gd")
const PlayerScript = preload("res://scripts/player.gd")
const DayNight = preload("res://scripts/day_night.gd")
const GameHUD = preload("res://scripts/hud.gd")
const CharacterActor = preload("res://scripts/character_actor.gd")
const SkeletonEnemy = preload("res://scripts/skeleton_enemy.gd")

@export var world_seed := 20260


func _ready() -> void:
	var daynight = _setup_environment()

	var terrain := ValleyTerrain.new()
	terrain.name = "Terreno"
	add_child(terrain)
	terrain.setup(world_seed)
	terrain.build()

	var ruins := AncientRuins.new()
	ruins.name = "RuinasAntiguas"
	add_child(ruins)
	ruins.build(terrain)

	# Cada campamento de esqueletos deja un claro sin arboles ni rocas.
	var clearings: Array = []
	for camp in WorldData.CAMPS:
		var c: Vector2 = camp["center"]
		clearings.append(Vector3(c.x, c.y, WorldData.CAMP_CLEARING_RADIUS))

	var props := PropScatter.new()
	props.name = "Vegetacion"
	add_child(props)
	props.populate(terrain, world_seed, clearings)

	_spawn_npcs()
	_spawn_enemies(terrain, props)

	var player := PlayerScript.new()
	player.name = "Jugador"
	player.spawn_point = WorldData.SPAWN
	add_child(player)
	player.global_position = WorldData.SPAWN

	var hud := GameHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player, daynight)


func _setup_environment():
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.003
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	var dn := DayNight.new()
	dn.name = "CicloDiaNoche"
	add_child(dn)
	dn.setup(sun, env, sky_mat)
	return dn


func _spawn_npcs() -> void:
	for npc in WorldData.NPCS:
		var p: Vector2 = npc["pos"]
		var body := StaticBody3D.new()
		body.name = String(npc["name"]).replace(" ", "_")
		body.position = Vector3(p.x, 0.2, p.y)
		body.add_to_group("npc")
		body.set_meta("npc", npc)

		var cs := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		cs.shape = shape
		cs.position.y = 0.9
		body.add_child(cs)

		# Aventurero aliado (modelo KayKit Adventurers) mirando hacia el altar.
		var actor = CharacterActor.new()
		body.add_child(actor)
		if actor.setup_hero(npc["hero"]):
			actor.rotation.y = atan2(p.x, p.y)
			actor.randomize_phase()
		else:
			actor.queue_free()
			_add_capsule_visual(body, npc["color"])

		var lbl := Label3D.new()
		lbl.text = "%s\n<%s>" % [npc["name"], npc["title"]]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 40
		lbl.modulate = npc["color"]
		lbl.pixel_size = 0.006
		lbl.outline_size = 12
		lbl.position.y = 2.7
		body.add_child(lbl)
		add_child(body)


func _add_capsule_visual(body: Node3D, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	body.add_child(mi)


func _spawn_enemies(terrain, props) -> void:
	var holder := Node3D.new()
	holder.name = "Enemigos"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 99
	var count := 0
	for camp in WorldData.CAMPS:
		var center: Vector2 = camp["center"]
		for kind in camp["kinds"]:
			var info: Dictionary = WorldData.SKELETON_TYPES[kind]
			var e := SkeletonEnemy.new()
			count += 1
			e.name = "Esqueleto_%d" % count
			e.kind = kind
			e.display_name = info["name"]
			e.level_text = camp["level"]
			e.position = _find_spawn(terrain, props, center, WorldData.CAMP_CLEARING_RADIUS - 1.5, rng)
			holder.add_child(e)
	print("[Valle] Esqueletos enemigos: ", count)


## Busca un punto llano y libre de arboles dentro del claro del campamento.
func _find_spawn(terrain, props, center: Vector2, radius: float, rng: RandomNumberGenerator) -> Vector3:
	for i in 30:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var x := center.x + sin(a) * r
		var z := center.y + cos(a) * r
		if terrain.get_slope(x, z) > 0.7 or props.is_blocked(x, z, 1.0):
			continue
		return Vector3(x, terrain.get_height(x, z) + 0.2, z)
	return Vector3(center.x, terrain.get_height(center.x, center.y) + 0.2, center.y)
