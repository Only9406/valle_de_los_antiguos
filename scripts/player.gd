extends CharacterBody3D
## Jugador en tercera persona (WASD + raton). Usa el personaje creado (clase, arma,
## aspecto, color). Click izquierdo = ataque basico; 1-4 = habilidades; E = hablar con
## NPC o recolectar (hacha/pico/hoz); I = inventario; T = talentos.

const CharacterActor = preload("res://scripts/character_actor.gd")
const ClassData = preload("res://scripts/class_data.gd")
const AttackData = preload("res://scripts/attack_data.gd")
const Projectile = preload("res://scripts/projectile.gd")
const ProgressionData = preload("res://scripts/progression_data.gd")
const CombatAbilities = preload("res://scripts/combat_abilities.gd")
const ItemData = preload("res://scripts/item_data.gd")
const ResourceNode = preload("res://scripts/resource_node.gd")
const CombatFx = preload("res://scripts/combat_fx.gd")

@export var walk_speed := 5.5
@export var sprint_speed := 9.0
@export var jump_velocity := 6.5
@export var mouse_sens := 0.003
## Ejemplo: "res://assets/personaje/personaje.glb" (sustituye al heroe creado)
@export var model_path := ""
## Solo si falla el modelo del heroe: esqueleto de respaldo ("Warrior"...). Vacio = capsula.
@export var skeleton_kind := "Warrior"
## Si tu modelo mira hacia +Z en vez de -Z, pon 180.
@export var model_yaw_offset := 0.0
@export var crit_chance := 0.12

var yaw := 0.0
var pitch := -0.35
var pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var visual: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_point := Vector3.ZERO
var skel_actor
var air_time := 0.0

# personaje y combate
var hero := {}
var class_info := {}
var weapon := {}
var move_mult := 1.0
var attacking := false
var attack_left := 0.0
var hit_left := -1.0
var pending_hit := Callable()
var cooldown_left := 0.0
var combo := 0
var face_yaw := 0.0
var block_attack := false

# habilidades
var abilities: Array = []
var ability_cd: Array = [0.0, 0.0, 0.0, 0.0]
var ability_cd_max: Array = [1.0, 1.0, 1.0, 1.0]
var caster
var buffs := {} # nombre -> {"left", "dmg", "aspd"}

# recoleccion e interaccion
var gathering := false
var gather_left := 0.0
var gather_total := 1.0
var gather_node: Node3D = null
var gather_kind := ""
var swing_left := 0.0
var interact_target = null
var interact_kind := ""
var interact_prompt := ""
var scan_timer := 0.0


func _ready() -> void:
	_ensure_input()
	add_to_group("jugador")
	hero = GameState.get_character()
	class_info = ClassData.info(String(hero.get("class", "Knight")))
	weapon = ClassData.weapon_of(hero)
	move_mult = float(class_info["speed"])
	abilities = ProgressionData.abilities_of(String(hero.get("class", "Knight")))
	caster = CombatAbilities.new()
	caster.name = "Habilidades"
	add_child(caster)
	caster.setup(self)
	GameState.leveled_up.connect(_on_level_up)

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	visual = Node3D.new()
	add_child(visual)
	_build_visual()

	var tag := Label3D.new()
	tag.text = String(hero.get("name", "Aventurero"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 36
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.modulate = Color(0.7, 0.95, 1.0)
	tag.position.y = 2.55
	add_child(tag)

	pivot = Node3D.new()
	pivot.position.y = 1.6
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 6.0
	var ball := SphereShape3D.new()
	ball.radius = 0.3
	spring.shape = ball
	spring.add_excluded_object(get_rid())
	pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 600.0
	spring.add_child(cam)
	cam.current = true

	floor_snap_length = 0.4
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	block_attack = true


func _exit_tree() -> void:
	if GameState.leveled_up.is_connected(_on_level_up):
		GameState.leveled_up.disconnect(_on_level_up)


func _build_visual() -> void:
	if model_path != "" and ResourceLoader.exists(model_path):
		var scn := load(model_path) as PackedScene
		visual.add_child(scn.instantiate())
		return
	var actor = CharacterActor.new()
	visual.add_child(actor)
	if actor.setup_hero(ClassData.actor_options(hero)):
		skel_actor = actor
		return
	actor.queue_free()
	if skeleton_kind != "":
		var fallback = CharacterActor.new()
		visual.add_child(fallback)
		if fallback.setup(skeleton_kind, Color(0.3, 0.85, 1.0)):
			skel_actor = fallback
			return
		fallback.queue_free()
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.45, 0.85)
	mi.material_override = m
	visual.add_child(mi)
	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 0.5)
	nose.mesh = bm
	nose.position = Vector3(0, 1.4, -0.4)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(1.0, 0.85, 0.2)
	nose.material_override = m2
	visual.add_child(nose)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sens
		pitch = clampf(pitch - event.relative.y * mouse_sens, -1.3, 0.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring.spring_length = clampf(spring.spring_length - 0.6, 2.0, 14.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring.spring_length = clampf(spring.spring_length + 0.6, 2.0, 14.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
				and not GameState.ui_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			block_attack = true # ese click solo recupera el raton, no ataca
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		# Volver a la creacion de personaje
		GameState.save_character()
		GameState.ui_open = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/character_creation.tscn")
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not gathering:
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	var speed := (sprint_speed if Input.is_action_pressed("sprint") else walk_speed) * speed_mult_now()
	if attacking:
		speed *= 0.2 # al atacar casi no avanzas
	if gathering:
		speed = 0.0
	var accel := 30.0 if is_on_floor() else 8.0
	var dashing: bool = caster.apply_dash(delta)
	if not dashing:
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	move_and_slide()
	var moving := input.length() > 0.1
	_tick_combat(delta)
	_tick_gather(delta, moving)
	_tick_interaction(delta)
	_update_animation(moving, delta)

	pivot.rotation = Vector3(pitch, yaw, 0.0)
	if attacking or gathering:
		visual.rotation.y = lerp_angle(visual.rotation.y, face_yaw + deg_to_rad(model_yaw_offset),
				clampf(delta * 25.0, 0.0, 1.0))
	elif moving:
		var target := atan2(-dir.x, -dir.z) + deg_to_rad(model_yaw_offset)
		visual.rotation.y = lerp_angle(visual.rotation.y, target, clampf(delta * 12.0, 0.0, 1.0))

	# Limite del mapa y reaparicion
	var flat := Vector2(position.x, position.z)
	if flat.length() > 122.0:
		flat = flat.normalized() * 122.0
		position.x = flat.x
		position.z = flat.y
	if position.y < -30.0:
		position = spawn_point
		velocity = Vector3.ZERO


## Elige la animacion segun el estado: parado, andando, corriendo o en el aire.
func _update_animation(moving: bool, delta: float) -> void:
	if skel_actor == null or attacking or gathering:
		return
	air_time = 0.0 if is_on_floor() else air_time + delta
	if air_time > 0.15:
		skel_actor.play("Jump_Idle", 0.1)
	elif moving:
		skel_actor.play("Running_A" if Input.is_action_pressed("sprint") else "Walking_A", 0.15)
	else:
		skel_actor.play("Idle_A", 0.2)


## ------------------------------------------------------ estadisticas
func buff_total(key: String) -> float:
	var t := 0.0
	for b in buffs.values():
		t += float(b[key])
	return t


## Multiplicador total de dano: nivel, talentos y mejoras temporales.
func damage_mult() -> float:
	return (1.0 + 0.04 * float(GameState.level - 1)) \
			* (1.0 + 0.05 * float(GameState.talent_rank("fuerza"))) * (1.0 + buff_total("dmg"))


func crit_chance_now() -> float:
	return crit_chance + 0.03 * float(GameState.talent_rank("precision"))


func crit_mult_now() -> float:
	return 1.8 + 0.2 * float(GameState.talent_rank("devastador"))


func cooldown_mult(slot := -1) -> float:
	var m := 1.0 - 0.04 * float(GameState.talent_rank("concentracion"))
	if slot == 3:
		m -= 0.05 * float(GameState.talent_rank("maestro"))
	return maxf(m, 0.3)


func ability_damage_mult(slot: int) -> float:
	var m := 1.0 + 0.08 * float(GameState.talent_rank("potencia"))
	if slot == 3:
		m += 0.15 * float(GameState.talent_rank("maestro"))
	return m


func speed_mult_now() -> float:
	return move_mult * (1.0 + 0.04 * float(GameState.talent_rank("agilidad")))


## ------------------------------------------------------------------ combate
func cooldown_ratio() -> float:
	return 1.0 - clampf(cooldown_left / maxf(float(weapon.get("cooldown", 1.0)), 0.01), 0.0, 1.0)


func weapon_anim() -> String:
	var anims = weapon["attack"]
	var n: String = anims if anims is String else String(anims[0])
	return "Attack_" + n


func _tick_combat(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	for i in ability_cd.size():
		ability_cd[i] = maxf(float(ability_cd[i]) - delta, 0.0)
	for k in buffs.keys():
		buffs[k]["left"] = float(buffs[k]["left"]) - delta
		if float(buffs[k]["left"]) <= 0.0:
			buffs.erase(k)
	if not Input.is_action_pressed("attack"):
		block_attack = false
	if attacking:
		attack_left -= delta
		if hit_left >= 0.0:
			hit_left -= delta
			if hit_left < 0.0:
				if pending_hit.is_valid():
					pending_hit.call()
		if attack_left <= 0.0:
			attacking = false
	var can_act := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not GameState.ui_open
	if can_act:
		for i in 4:
			if Input.is_action_just_pressed("ability_%d" % (i + 1)):
				if gathering:
					_end_gather()
				caster.try_cast(i)
		if Input.is_action_pressed("attack") and not block_attack and cooldown_left <= 0.0 \
				and not attacking and not gathering:
			_start_attack()


## Inicia una accion (ataque o habilidad): anima, fija el momento del golpe y la direccion.
func begin_action(anim_name: String, spd: float, hit_cb: Callable, face := INF) -> void:
	attacking = true
	pending_hit = hit_cb
	face_yaw = _attack_facing() if face == INF else face
	var dur := 0.4
	if skel_actor != null:
		dur = skel_actor.play_action(anim_name, spd)
	attack_left = maxf(dur * 0.95, 0.15)
	hit_left = -1.0
	if hit_cb.is_valid():
		var hit_t := 0.3
		var base := anim_name.trim_prefix("Attack_")
		if AttackData.ATTACKS.has(base):
			hit_t = float(AttackData.ATTACKS[base]["hit"])
		hit_left = hit_t / spd


func _start_attack() -> void:
	var anims = weapon["attack"]
	var anim_name: String = anims if anims is String else String(anims[combo % anims.size()])
	combo += 1
	var data: Dictionary = AttackData.ATTACKS[anim_name]
	var length := float(data["length"])
	# La cadencia sube con mejoras de velocidad de ataque; la animacion se ajusta a ella
	var cd := float(weapon["cooldown"]) / (1.0 + buff_total("aspd"))
	var spd := clampf(length / maxf(cd * 0.95, 0.1), 0.8, 2.6)
	cooldown_left = cd
	begin_action("Attack_" + anim_name, spd, _resolve_hit)


func _forward(yaw_angle: float) -> Vector3:
	return Vector3(-sin(yaw_angle), 0.0, -cos(yaw_angle))


## Hacia donde mira el ataque: la camara, o el enemigo cercano si hay uno delante.
func _attack_facing() -> float:
	var best = null
	var best_d := INF
	var reach := float(weapon["range"]) * (1.6 if weapon["kind"] == "melee" else 0.0)
	if reach > 0.0:
		var cam_fwd := _forward(yaw)
		for e in get_tree().get_nodes_in_group("enemigos"):
			if e.dead:
				continue
			var to: Vector3 = e.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d < reach and d > 0.05 and cam_fwd.dot(to / d) > 0.0 and d < best_d:
				best_d = d
				best = to
	if best != null:
		return atan2(-best.x, -best.z)
	return yaw


func _resolve_hit() -> void:
	if weapon["kind"] == "melee":
		_melee_hit()
	else:
		_fire()


func _melee_hit() -> void:
	var fwd := _forward(face_yaw)
	var reach := float(weapon["range"])
	var hits: Array = []
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > reach + 0.5:
			continue
		if d > 0.7 and fwd.dot(to / d) < 0.25:
			continue
		hits.append([d, e])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(int(weapon["targets"]), hits.size()):
		deal_damage(hits[i][1])


func _fire() -> void:
	var proj_info: Dictionary = weapon["proj"]
	var muzzle := muzzle_position()
	var p := Projectile.new()
	p.kind = String(proj_info["kind"])
	p.color = proj_info["color"]
	p.speed = float(proj_info["speed"])
	p.life = float(weapon["range"]) / p.speed
	p.shooter = self
	p.direction = aim_direction(muzzle)
	get_tree().current_scene.add_child(p)
	p.global_position = muzzle


## De donde salen los proyectiles: la mano del arma (o delante del pecho).
func muzzle_position() -> Vector3:
	if skel_actor != null:
		return skel_actor.hand_position(String(weapon.get("muzzle", "r")))
	return global_position + Vector3(0, 1.3, 0) + _forward(face_yaw) * 0.6


## Direccion del disparo: hacia la mira (centro de pantalla), con una pequena
## ayuda para enganchar al enemigo mas cercano a ella.
func aim_direction(muzzle: Vector3) -> Vector3:
	var cam_origin := cam.global_position
	var cam_fwd := -cam.global_transform.basis.z
	var best = null
	var best_ang := deg_to_rad(9.0)
	var reach := float(weapon["range"]) + 8.0
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead:
			continue
		var c: Vector3 = e.global_position + Vector3(0, 1.0, 0)
		var to := c - cam_origin
		if to.length() > reach:
			continue
		var ang := cam_fwd.angle_to(to)
		if ang < best_ang:
			best_ang = ang
			best = c
	var target: Vector3 = cam_origin + cam_fwd * 80.0
	if best != null:
		target = best
	else:
		var q := PhysicsRayQueryParameters3D.create(cam_origin + cam_fwd * 2.0, target, 1)
		q.exclude = [get_rid()]
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			target = r["position"]
	var d := target - muzzle
	if d.length() < 0.5:
		return cam_fwd
	return d.normalized()


## Punto del suelo bajo la mira, limitado a `max_range` metros del jugador.
func ground_target(max_range: float) -> Vector3:
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin + fwd * 2.0, origin + fwd * 100.0, 1)
	q.exclude = [get_rid()]
	var r := space.intersect_ray(q)
	var p: Vector3 = global_position + _forward(yaw) * max_range
	if not r.is_empty():
		p = r["position"]
	var flat := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
	if flat.length() > max_range:
		p = global_position + flat.normalized() * max_range
	var q2 := PhysicsRayQueryParameters3D.create(p + Vector3(0, 40, 0), p + Vector3(0, -60, 0), 1)
	q2.exclude = [get_rid()]
	var r2 := space.intersect_ray(q2)
	if not r2.is_empty():
		p = r2["position"]
	return p


## Aplica dano a un enemigo con el arma equipada. `mult` multiplica el dano (habilidades);
## `extra` puede traer "stun": s, "slow": [factor, s], "dot": [mult/s, s].
func deal_damage(e, mult := 1.0, extra := {}) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var dmg: Array = weapon["dmg"]
	var base := float(randi_range(int(dmg[0]), int(dmg[1])))
	var crit := randf() < crit_chance_now()
	var amount := int(round(base * mult * damage_mult() * (crit_mult_now() if crit else 1.0)))
	e.take_damage(maxi(amount, 1), self, crit)
	if e.dead:
		return
	if extra.has("stun"):
		e.apply_stun(float(extra["stun"]))
	if extra.has("slow"):
		var sl: Array = extra["slow"]
		e.apply_slow(float(sl[0]), float(sl[1]))
	if extra.has("dot"):
		var dt: Array = extra["dot"]
		var avg := (float(dmg[0]) + float(dmg[1])) * 0.5
		e.apply_dot(int(avg * float(dt[0]) * damage_mult()), float(dt[1]))


func _on_level_up(lvl: int) -> void:
	var scene := get_tree().current_scene
	CombatFx.burst(scene, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.4), 4.5)
	CombatFx.text_popup(scene, global_position + Vector3(0, 2.9, 0), "¡NIVEL %d!" % lvl, Color(1.0, 0.9, 0.3))
	GameState.message.emit("¡Has subido al nivel %d! +1 punto de talento (T)" % lvl)


## ------------------------------------------- interaccion y recoleccion
func _tick_interaction(delta: float) -> void:
	if gathering:
		interact_prompt = ""
		return
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.15
		_scan_interactables()
	if Input.is_action_just_pressed("interact") and not GameState.ui_open \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_interact()


func _scan_interactables() -> void:
	interact_target = null
	interact_kind = ""
	interact_prompt = ""
	var pp := global_position
	var best_d := 3.6
	for n in get_tree().get_nodes_in_group("npc"):
		var d: float = pp.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			interact_target = n
			interact_kind = "npc"
	if interact_target != null:
		interact_prompt = "[E] Hablar con %s" % interact_target.get_meta("npc")["name"]
		return
	best_d = 3.0
	for n in get_tree().get_nodes_in_group("recolectable"):
		if not n.visible or not ResourceNode.has_charges(n):
			continue
		if absf(n.global_position.y - pp.y) > 3.5:
			continue
		var d: float = Vector2(pp.x - n.global_position.x, pp.z - n.global_position.z).length()
		if d < best_d:
			best_d = d
			interact_target = n
			interact_kind = "resource"
	if interact_target != null:
		var kind := String(interact_target.get_meta("gather"))
		var info: Dictionary = ItemData.GATHER[kind]
		var tool_id := String(info["tool"])
		if GameState.count(tool_id) > 0:
			interact_prompt = "[E] %s (%s)" % [info["label"], ItemData.item_name(tool_id)]
		else:
			interact_prompt = "%s: necesitas %s" % [info["label"], ItemData.item_name(tool_id)]


func _interact() -> void:
	if interact_target == null or not is_instance_valid(interact_target):
		return
	if interact_kind == "npc":
		GameState.open_dialogue.emit(interact_target.get_meta("npc"))
	elif interact_kind == "resource":
		_start_gather(interact_target)


func _start_gather(node: Node3D) -> void:
	if attacking:
		return
	var kind := String(node.get_meta("gather"))
	var info: Dictionary = ItemData.GATHER[kind]
	var tool_id := String(info["tool"])
	if GameState.count(tool_id) <= 0:
		GameState.message.emit("Necesitas: %s" % ItemData.item_name(tool_id))
		return
	gathering = true
	gather_node = node
	gather_kind = kind
	gather_total = float(info["time"]) * maxf(1.0 - 0.08 * float(GameState.talent_rank("cosechador")), 0.4)
	gather_left = gather_total
	swing_left = 0.0
	var to := node.global_position - global_position
	face_yaw = atan2(-to.x, -to.z)
	if skel_actor != null:
		skel_actor.show_tool(tool_id)


func _tick_gather(delta: float, moving: bool) -> void:
	if not gathering:
		return
	if moving or not is_on_floor() or not is_instance_valid(gather_node) \
			or not ResourceNode.has_charges(gather_node):
		_end_gather()
		return
	gather_left -= delta
	swing_left -= delta
	if swing_left <= 0.0:
		swing_left = 0.55
		if skel_actor != null:
			skel_actor.play_action("Attack_Slash", 1.45)
		get_tree().create_timer(0.22).timeout.connect(_gather_impact)
	if gather_left <= 0.0:
		_finish_gather()


## Fragmentos al golpear el arbol/roca/hierba.
func _gather_impact() -> void:
	if gathering and is_instance_valid(gather_node):
		var info: Dictionary = ItemData.GATHER[gather_kind]
		CombatFx.burst(get_tree().current_scene, gather_node.global_position + Vector3(0, 1.0, 0),
				info["chip"], 0.7)


func _finish_gather() -> void:
	var info: Dictionary = ItemData.GATHER[gather_kind]
	var y: Array = info["yield"]
	var n := randi_range(int(y[0]), int(y[1]))
	if randf() < 0.1 * float(GameState.talent_rank("cosechador")):
		n *= 2
	GameState.add_item(gather_kind, n)
	GameState.message.emit("+%d %s" % [n, ItemData.item_name(gather_kind)])
	ResourceNode.harvest(gather_node)
	_end_gather()


func _end_gather() -> void:
	gathering = false
	gather_node = null
	if skel_actor != null:
		skel_actor.hide_tool()
		skel_actor.current = ""


## 0..1 del progreso de la recoleccion en curso (para la barra del HUD).
func gather_progress() -> float:
	if not gathering:
		return 0.0
	return 1.0 - clampf(gather_left / maxf(gather_total, 0.01), 0.0, 1.0)


## ------------------------------------------------------------------- input
func _ensure_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"ability_1": [KEY_1],
		"ability_2": [KEY_2],
		"ability_3": [KEY_3],
		"ability_4": [KEY_4],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)
