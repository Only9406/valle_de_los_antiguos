extends Node
## Lanza las habilidades de la barra (teclas 1-4): golpes frontales, areas, embestidas,
## mejoras temporales, proyectiles, abanicos de disparos y ataques de zona con retardo.

const CombatFx = preload("res://scripts/combat_fx.gd")
const Projectile = preload("res://scripts/projectile.gd")
const GroundStrike = preload("res://scripts/ground_strike.gd")
const AttackData = preload("res://scripts/attack_data.gd")

var player  # el jugador (CharacterBody3D)

# embestida en curso
var dash_left := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 0.0
var dash_ab: Dictionary = {}
var dash_slot := 0
var dash_hit: Array = []


func setup(p) -> void:
	player = p


## Intenta lanzar la habilidad de la ranura `slot` (0-3).
func try_cast(slot: int) -> void:
	if slot >= player.abilities.size():
		return
	var ab: Dictionary = player.abilities[slot]
	if GameState.level < int(ab["unlock"]):
		GameState.message.emit("%s: se desbloquea en el nivel %d" % [ab["name"], ab["unlock"]])
		return
	if player.ability_cd[slot] > 0.0 or player.attacking or player.gathering or dash_left > 0.0:
		return
	var cd: float = float(ab["cd"]) * player.cooldown_mult(slot)
	player.ability_cd[slot] = cd
	player.ability_cd_max[slot] = cd
	match String(ab["type"]):
		"cone":
			player.begin_action(player.weapon_anim(), 1.3, _cone.bind(ab, slot))
		"aoe_self":
			player.begin_action(player.weapon_anim(), 1.3, _aoe_self.bind(ab, slot))
		"buff":
			player.begin_action("Use_Item", 1.0, Callable())
			_buff(ab)
		"projectile":
			player.begin_action(player.weapon_anim(), 1.3, _projectile.bind(ab, slot))
		"volley":
			player.begin_action(player.weapon_anim(), 1.3, _volley.bind(ab, slot))
		"ground_aoe":
			player.begin_action(player.weapon_anim(), 1.2, _ground.bind(ab, slot))
		"dash":
			_start_dash(ab, slot)


## ---------------------------------------------------------------- efectos
func _extra(ab: Dictionary) -> Dictionary:
	var e := {}
	for k in ["stun", "slow", "dot"]:
		if ab.has(k):
			e[k] = ab[k]
	return e


func _mult(ab: Dictionary, slot: int) -> float:
	return float(ab["mult"]) * player.ability_damage_mult(slot)


func _cone(ab: Dictionary, slot: int) -> void:
	var fwd: Vector3 = player._forward(player.face_yaw)
	var reach := float(ab["range"])
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > reach + 0.5:
			continue
		if d > 0.7 and fwd.dot(to / d) < float(ab["cos"]):
			continue
		player.deal_damage(e, _mult(ab, slot), _extra(ab))
		hits += 1
		if hits >= 6:
			break
	CombatFx.burst(get_tree().current_scene, player.global_position + fwd * 1.5 + Vector3(0, 1.0, 0),
			Color(1.0, 0.85, 0.5), 1.3)


func _aoe_self(ab: Dictionary, slot: int) -> void:
	_aoe_at(player.global_position, float(ab["radius"]), _mult(ab, slot), _extra(ab))


func _aoe_at(center: Vector3, radius: float, mult: float, extra: Dictionary) -> void:
	CombatFx.burst(get_tree().current_scene, center + Vector3(0, 0.8, 0), Color(0.9, 0.95, 1.0), radius * 1.7)
	for e in get_tree().get_nodes_in_group("enemigos"):
		if e.dead:
			continue
		var d := Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length()
		if d <= radius:
			player.deal_damage(e, mult, extra)


func _buff(ab: Dictionary) -> void:
	var key := String(ab["name"])
	player.buffs[key] = {"left": float(ab["duration"]), "dmg": float(ab.get("dmg", 0.0)),
			"aspd": float(ab.get("aspd", 0.0))}
	CombatFx.burst(get_tree().current_scene, player.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.3), 2.2)
	GameState.message.emit("%s activado" % key)


func _make_projectile(ab: Dictionary, slot: int, dir: Vector3, muzzle: Vector3, mult: float) -> void:
	var p := Projectile.new()
	p.kind = String(ab["kind"])
	p.color = ab["color"]
	p.speed = float(ab["speed"])
	p.life = float(ab["range"]) / p.speed
	p.shooter = player
	p.direction = dir
	p.dmg_mult = mult
	p.explode = float(ab.get("explode", 0.0))
	p.extra = _extra(ab)
	get_tree().current_scene.add_child(p)
	p.global_position = muzzle


func _projectile(ab: Dictionary, slot: int) -> void:
	var muzzle: Vector3 = player.muzzle_position()
	_make_projectile(ab, slot, player.aim_direction(muzzle), muzzle, _mult(ab, slot))


func _volley(ab: Dictionary, slot: int) -> void:
	var muzzle: Vector3 = player.muzzle_position()
	var base: Vector3 = player.aim_direction(muzzle)
	var n := int(ab["count"])
	var spread := deg_to_rad(float(ab["spread"]))
	for i in n:
		var t := 0.0 if n <= 1 else (float(i) / float(n - 1) - 0.5)
		var dir := base.rotated(Vector3.UP, t * spread)
		_make_projectile(ab, slot, dir, muzzle, _mult(ab, slot))


func _ground(ab: Dictionary, slot: int) -> void:
	var target: Vector3 = player.ground_target(float(ab["range"]))
	var g := GroundStrike.new()
	g.radius = float(ab["radius"])
	g.delay = float(ab["delay"])
	g.color = ab["color"]
	g.mult = _mult(ab, slot)
	g.extra = _extra(ab)
	g.fall = bool(ab.get("fall", false))
	g.shooter = player
	get_tree().current_scene.add_child(g)
	g.global_position = target


## ------------------------------------------------------------- embestida
func _start_dash(ab: Dictionary, slot: int) -> void:
	var fwd: Vector3 = player._forward(player.yaw)
	dash_dir = fwd * float(ab["dir"])
	dash_speed = float(ab["speed"])
	dash_left = float(ab["distance"])
	dash_ab = ab
	dash_slot = slot
	dash_hit = []
	player.begin_action(player.weapon_anim(), 1.4, Callable(), player.yaw)
	if bool(ab.get("leap", false)):
		player.velocity.y = 7.0
	CombatFx.burst(get_tree().current_scene, player.global_position + Vector3(0, 0.4, 0), Color(0.9, 0.9, 0.9), 1.4)


## Lo llama el jugador en cada frame fisico: si hay embestida, fija su velocidad.
func apply_dash(delta: float) -> bool:
	if dash_left <= 0.0:
		return false
	player.velocity.x = dash_dir.x * dash_speed
	player.velocity.z = dash_dir.z * dash_speed
	dash_left -= dash_speed * delta
	var mult := float(dash_ab.get("mult", 0.0))
	if mult > 0.0:
		for e in get_tree().get_nodes_in_group("enemigos"):
			if e.dead or dash_hit.has(e):
				continue
			var d := Vector2(e.global_position.x - player.global_position.x,
					e.global_position.z - player.global_position.z).length()
			if d < 1.6:
				dash_hit.append(e)
				player.deal_damage(e, mult * player.ability_damage_mult(dash_slot), _extra(dash_ab))
	if dash_left <= 0.0:
		dash_left = 0.0
		if dash_ab.has("land_radius"):
			_aoe_at(player.global_position, float(dash_ab["land_radius"]),
					float(dash_ab["land_mult"]) * player.ability_damage_mult(dash_slot), _extra(dash_ab))
	return true
