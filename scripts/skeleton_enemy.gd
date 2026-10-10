extends CharacterBody3D
## Esqueleto hostil: patrulla alrededor de su campamento, persigue al jugador si se
## acerca (o si lo golpea) y vuelve a casa si se aleja demasiado. Tiene vida: recibe
## dano, reacciona al golpe, muere con animacion y reaparece en su campamento.
## No ataca a la Plaza (zona segura). Punto de partida para que el enemigo contraataque.

const CharacterActor = preload("res://scripts/character_actor.gd")
const WorldData = preload("res://scripts/world_data.gd")
const CombatFx = preload("res://scripts/combat_fx.gd")

const HP_BY_KIND := {"Minion": 40, "Rogue": 55, "Mage": 60, "Warrior": 90}
const BAR_W := 1.4
const RESPAWN_TIME := 25.0

@export var kind := "Minion"
@export var display_name := "Esqueleto"
@export var level_text := "Nv. 1"
@export var walk_speed := 1.8
@export var run_speed := 4.6
@export var aggro_range := 14.0
@export var leash_range := 34.0
@export var patrol_radius := 7.0
@export var glow_color := Color(1.0, 0.22, 0.1)

enum State { IDLE, WANDER, CHASE, RETURN }

var state := State.IDLE
var home := Vector3.ZERO
var target_pos := Vector3.ZERO
var timer := 0.0
var stuck_time := 0.0
var actor
var player: Node3D
var rng := RandomNumberGenerator.new()
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var max_hp := 40
var hp := 40
var dead := false
var dead_time := 0.0
var stagger_left := 0.0
var provoked_left := 0.0
var slow_mult := 1.0
var slow_left := 0.0
var dot_dps := 0
var dot_left := 0.0
var dot_tick := 0.0
var col: CollisionShape3D
var name_label: Label3D
var bar_root: Node3D
var bar_fill: MeshInstance3D


func _ready() -> void:
	rng.randomize()
	add_to_group("enemigos")
	home = global_position
	timer = rng.randf_range(0.5, 3.0)
	floor_snap_length = 0.4
	max_hp = int(HP_BY_KIND.get(kind, 40))
	hp = max_hp

	col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	actor = CharacterActor.new()
	add_child(actor)
	if actor.setup(kind, glow_color):
		actor.randomize_phase()
	else:
		actor.queue_free()
		actor = null
		_add_placeholder()

	name_label = Label3D.new()
	name_label.text = "%s\n%s" % [display_name, level_text]
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 36
	name_label.pixel_size = 0.006
	name_label.outline_size = 10
	name_label.modulate = Color(1.0, 0.55, 0.45)
	name_label.position.y = 2.75
	name_label.visibility_range_end = 35.0
	add_child(name_label)
	_build_bar()


## ------------------------------------------------------------------ dano
## reaction=false: dano continuo (veneno), sin retroceso ni animacion de golpe.
func take_damage(amount: int, attacker: Node3D = null, crit := false, reaction := true,
		tint := Color(1, 1, 1)) -> void:
	if dead:
		return
	hp = maxi(hp - amount, 0)
	var scene := get_tree().current_scene
	CombatFx.damage_popup(scene, global_position + Vector3(0, 2.3, 0), amount, crit, tint)
	if reaction:
		CombatFx.burst(scene, global_position + Vector3(0, 1.1, 0), Color(1.0, 0.9, 0.6), 0.7)
	GameState.register_hit(self)
	_update_bar()
	if hp <= 0:
		_die()
		return
	provoked_left = 8.0
	if not reaction:
		return
	stagger_left = maxf(stagger_left, 0.4)
	if attacker != null:
		var d := global_position - attacker.global_position
		d.y = 0.0
		if d.length() > 0.01:
			d = d.normalized()
			velocity.x = d.x * 3.5
			velocity.z = d.z * 3.5
	if actor != null:
		actor.play_action("Hit_A", 1.2)
	if state == State.IDLE or state == State.WANDER:
		state = State.CHASE


func _die() -> void:
	dead = true
	dead_time = 0.0
	remove_from_group("enemigos")
	col.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if actor != null:
		actor.play_action("Death_A", 1.0)
	name_label.visible = false
	bar_root.visible = false
	GameState.on_kill(kind)
	CombatFx.burst(get_tree().current_scene, global_position + Vector3(0, 1.0, 0), Color(0.8, 0.9, 1.0), 1.6)


func _respawn() -> void:
	dead = false
	hp = max_hp
	global_position = home
	velocity = Vector3.ZERO
	state = State.IDLE
	timer = 1.0
	provoked_left = 0.0
	slow_left = 0.0
	dot_left = 0.0
	stagger_left = 1.2 # espera mientras suena la animacion de aparicion
	col.set_deferred("disabled", false)
	add_to_group("enemigos")
	name_label.visible = true
	_update_bar()
	if actor != null:
		actor.visible = true
		actor.play_action("Spawn_Ground", 1.0)


## ------------------------------------------------------------------- IA
func _physics_process(delta: float) -> void:
	if dead:
		_tick_dead(delta)
		return
	if player == null:
		player = get_tree().get_first_node_in_group("jugador") as Node3D
	if not is_on_floor():
		velocity.y -= gravity * delta
	provoked_left = maxf(provoked_left - delta, 0.0)
	_tick_status(delta)
	if dead:
		return

	if stagger_left > 0.0:
		stagger_left -= delta
		if actor != null and actor.current == "":
			actor.play("Idle_B")
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		move_and_slide()
		return

	var dist_player := INF
	var player_hunted := false
	if player != null:
		dist_player = _flat_dist(global_position, player.global_position)
		# La Plaza de los Antiguos es zona segura: no te persiguen dentro.
		player_hunted = WorldData.zone_at(player.global_position)["id"] != "plaza"
	var dist_home := _flat_dist(global_position, home)
	var wants_chase := player_hunted and dist_home < leash_range \
			and (dist_player < aggro_range or provoked_left > 0.0)

	match state:
		State.IDLE:
			_stop()
			_play("Idle_A")
			timer -= delta
			if wants_chase:
				state = State.CHASE
			elif timer <= 0.0:
				var a := rng.randf() * TAU
				var r := sqrt(rng.randf()) * patrol_radius
				target_pos = home + Vector3(sin(a) * r, 0.0, cos(a) * r)
				timer = 8.0
				stuck_time = 0.0
				state = State.WANDER
		State.WANDER:
			_steer(target_pos, walk_speed * slow_mult, delta)
			_play("Walking_A")
			timer -= delta
			if wants_chase:
				state = State.CHASE
			elif _flat_dist(global_position, target_pos) < 0.8 or timer <= 0.0 or _is_stuck(delta):
				state = State.IDLE
				timer = rng.randf_range(2.0, 5.0)
		State.CHASE:
			if not player_hunted or dist_home > leash_range \
					or (dist_player > aggro_range * 1.8 and provoked_left <= 0.0):
				state = State.RETURN
			elif dist_player < 1.8:
				_stop()
				_face(player.global_position, delta)
				_play("Idle_B")
			else:
				_steer(player.global_position, run_speed * slow_mult, delta)
				_play("Running_A")
		State.RETURN:
			_steer(home, run_speed * slow_mult, delta)
			_play("Running_A")
			if dist_home < 1.5:
				state = State.IDLE
				timer = rng.randf_range(1.0, 3.0)

	move_and_slide()


## ------------------------------------------------------------- estados
## Aturdimiento: se queda quieto durante `t` segundos.
func apply_stun(t: float) -> void:
	if dead:
		return
	stagger_left = maxf(stagger_left, t)
	provoked_left = 8.0
	if actor != null:
		actor.play_action("Hit_B" if actor.has_anim("Hit_B") else "Hit_A", 1.0)


## Ralentizacion: se mueve a `factor` de su velocidad durante `t` segundos.
func apply_slow(factor: float, t: float) -> void:
	if dead:
		return
	slow_mult = clampf(factor, 0.1, 1.0)
	slow_left = maxf(slow_left, t)
	provoked_left = 8.0


## Veneno: `dps` de dano por segundo durante `t` segundos.
func apply_dot(dps: int, t: float) -> void:
	if dead:
		return
	dot_dps = maxi(dps, 1)
	dot_left = maxf(dot_left, t)
	dot_tick = 0.0
	provoked_left = 8.0


func _tick_status(delta: float) -> void:
	if slow_left > 0.0:
		slow_left -= delta
		if slow_left <= 0.0:
			slow_mult = 1.0
	if dot_left > 0.0:
		dot_left -= delta
		dot_tick += delta
		if dot_tick >= 1.0:
			dot_tick -= 1.0
			take_damage(dot_dps, null, false, false, Color(0.5, 1.0, 0.4))


## Cadaver: se queda tumbado unos segundos, se hunde, desaparece y reaparece en su campamento.
func _tick_dead(delta: float) -> void:
	dead_time += delta
	if dead_time > 5.0 and actor != null and actor.visible:
		actor.position.y -= 0.5 * delta
		if dead_time > 8.0:
			actor.visible = false
			actor.position.y = 0.0
	if dead_time >= RESPAWN_TIME:
		_respawn()


func _play(anim_name: String) -> void:
	if actor != null:
		actor.play(anim_name)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _steer(point: Vector3, speed: float, delta: float) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() < 0.05:
		_stop()
		return
	d = d.normalized()
	velocity.x = d.x * speed
	velocity.z = d.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))


func _face(point: Vector3, delta: float) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.05:
		d = d.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))


## Si va andando pero casi no se mueve (choca con un arbol), se considera atascado.
func _is_stuck(delta: float) -> bool:
	if get_real_velocity().length() < 0.3:
		stuck_time += delta
	else:
		stuck_time = 0.0
	return stuck_time > 1.2


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## ---------------------------------------------------------- barra de vida
func _bar_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m


func _build_bar() -> void:
	bar_root = Node3D.new()
	bar_root.position.y = 2.35
	bar_root.visible = false
	add_child(bar_root)
	var bg := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(BAR_W, 0.17)
	bg.mesh = bq
	bg.material_override = _bar_material(Color(0.04, 0.04, 0.05))
	bar_root.add_child(bg)
	bar_fill = MeshInstance3D.new()
	bar_fill.mesh = QuadMesh.new()
	bar_fill.material_override = _bar_material(Color(0.9, 0.15, 0.1))
	bar_root.add_child(bar_fill)
	_update_bar()


func _update_bar() -> void:
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var full := BAR_W - 0.06
	var w := maxf(full * ratio, 0.001)
	var q := bar_fill.mesh as QuadMesh
	q.size = Vector2(w, 0.11)
	# alineada a la izquierda y ligeramente por delante del fondo (en el espacio del billboard)
	q.center_offset = Vector3(-(full - w) * 0.5, 0.0, 0.01)
	bar_root.visible = hp < max_hp and not dead


func _add_placeholder() -> void:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.position.y = 0.9
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.85, 0.8)
	mi.material_override = m
	add_child(mi)
